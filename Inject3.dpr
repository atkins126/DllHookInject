program Inject3;
{$APPTYPE CONSOLE}
{$IF CompilerVersion >= 21.0}
{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$IFEND}

uses
  tlhelp32,
  SysUtils,
  Windows;

type
  NtCreateThreadExProc = function(var hThread: THandle; Access: DWORD; Attributes: Pointer; hProcess: THandle; pStart: Pointer; pParameter: Pointer; Suspended: BOOL; StackSize, u1, u2: DWORD; Unknown: Pointer): DWORD; stdcall;
var
  hhk: HHOOK;
function CheckOs(): Boolean;
var
  lpVersionInformation: TOSVersionInfoW;
begin
  Result := False;
  if GetVersionExW(lpVersionInformation) then
  begin
    if lpVersionInformation.dwPlatformId = VER_PLATFORM_WIN32_NT then
    begin
      if (lpVersionInformation.dwMajorVersion < 6) then
      begin
        Result := True;
      end;
    end;
  end;
end;

function EnableDebugPrivilege(): Boolean;
var
  hToKen: THandle;
  TokenPri: TTokenPrivileges;
begin
  Result := False;
  if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, hToKen)) then
  begin
    TokenPri.PrivilegeCount := 1;
    if LookupPrivilegeValueW(Nil, 'SeDebugPrivilege', TokenPri.Privileges[0].Luid) then
    begin
      TokenPri.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
      Result := AdjustTokenPrivileges(hToKen, False, TokenPri, SizeOf(TTokenPrivileges), Nil, PDWORD(Nil)^);
    end
    else
      Writeln('LookupPrivilege Error');
    CloseHandle(hToKen);
  end;
end;

function RemoteThread(hProcess: THandle; pThreadProc: Pointer; pRemote: Pointer): THandle;
label
  NtCreate, Create;
var
  pFunc: Pointer;
  hThread: THandle;
begin
  hThread := 0;
  if not CheckOs() then //����ϵͳ�汾��ѡ��ʹ�õ�API
  begin
  NtCreate:
      pFunc := GetProcAddress(LoadLibraryW('ntdll.dll'), 'NtCreateThreadEx');
      if pFunc = Nil then
        goto Create;
      NtCreateThreadExProc(pFunc)(hThread, $1FFFFF, Nil, hProcess, pThreadProc, pRemote, False, 0, 0, 0, Nil);
      if hThread = 0 then
        goto Create;
  end
  else
  begin
  Create:
      hThread := CreateRemoteThread(hProcess, Nil, 0, pThreadProc, pRemote, 0, PDWORD(Nil)^);
  end;
  Writeln('RemoteThread Ok!');
  Result := hThread;
end;

procedure GetMyProcessID(const AFilename: string; const PathMatch: Boolean; var ProcessID: DWORD);
var
  lppe: TProcessEntry32;
  SsHandle: Thandle;
  FoundAProc, FoundOK: boolean;
begin
  ProcessID :=0;
  { ����ϵͳ���� }
  SsHandle := CreateToolHelp32SnapShot(TH32CS_SnapProcess, 0);

  { ȡ�ÿ����еĵ�һ������ }
  { һ��Ҫ���ýṹ�Ĵ�С,���򽫷���False }
  lppe.dwSize := sizeof(TProcessEntry32);
  FoundAProc := Process32First(Sshandle, lppe);
  while FoundAProc do
  begin
    { ����ƥ�� }
    if PathMatch then
      FoundOK := AnsiStricomp(lppe.szExefile, PChar(AFilename)) = 0
    else
      FoundOK := AnsiStricomp(PChar(ExtractFilename(lppe.szExefile)), PChar(ExtractFilename(AFilename))) = 0;
    if FoundOK then
    begin
      ProcessID := lppe.th32ProcessID;
      break;
    end;
    { δ�ҵ�,������һ������ }
    FoundAProc := Process32Next(SsHandle, lppe);
  end;
  CloseHandle(SsHandle);
end;


//������Ϣ
function HookProc(code: Integer; wparam: WPARAM; lparam: LPARAM): LRESULT stdcall;
begin
  Result := CallNextHookEx(hhk, code, wParam, lParam);
end;

//��ʼHOOK
procedure StartHook(pid: DWORD); stdcall;
begin
  hhk := SetWindowsHookEx(WH_CALLWNDPROC, HookProc, hInstance, 0);
end;

procedure EndHook; stdcall;
begin
  if hhk <> 0 then
    UnhookWindowsHookEx(hhk);
end;

function InjectDll2Pid(szPath: PWideChar; uPID: DWORD): Boolean;
var
  hProcess: THandle;
  hThread: THandle;
  szRemote: PWideChar;
  uSize: Cardinal;
  uWrite: THandle;
  pStartAddr: Pointer;
begin
  Result := False;
  if EnableDebugPrivilege then
  begin //�������½��̵�Ȩ��
    hProcess := OpenProcess(PROCESS_ALL_ACCESS, false, uPID);
    if hProcess > 0 then
    begin
      uSize := lstrlenW(szPath) * 2 + 4;
      szRemote := VirtualAllocEx(hProcess, Nil, uSize, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
      if WriteProcessMemory(hProcess, szRemote, szPath, uSize, uWrite) and (uWrite = uSize) then
      begin
        pStartAddr := GetProcAddress(LoadLibrary('Kernel32.dll'), 'LoadLibraryW');
        hThread := RemoteThread(hProcess, pStartAddr, szRemote);
        Result := hThread <> 0;
        CloseHandle(hThread);
      end
      else
      begin
        Writeln('WriteMemory Error');
      end;
    end;
  end;
end;

function StrToInt(S: string): Integer;
var
  E: Integer;
begin
  Val(S, Result, E);
end;

var
  Pid: DWORD;
  sRead: string;
begin
  Pid := StrToIntDef(ParamStr(1), 0);
  if Pid <> 0 then
    InjectDll2Pid(PWideChar(ParamStr(2)), Pid)
  else
  begin
    GetMyProcessID(ParamStr(1), False, Pid);
    if Pid <> 0  then
      InjectDll2Pid(PWideChar(ParamStr(2)), Pid);
  end;
  StartHook(Pid);
  Writeln('�����������Hook!');
  Readln(sRead);
end.

