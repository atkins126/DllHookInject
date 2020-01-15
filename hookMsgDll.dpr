library hookMsgDll;

uses
  SysUtils,
  Windows,
  Classes,
  unitHook in 'unitHook.pas';

{$R *.res}

const
  HOOK_MEM_FILENAME = 'tmp.hkt';

var
  hhk: HHOOK;
  Hook: array[0..4] of TNtHookClass;

  //�ڴ�ӳ��
  MemFile: THandle;
  startPid: PDWORD;   //����PID

{--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--}

//���� MessageBoxA

function NewMessageBoxA(_hWnd: HWND; lpText, lpCaption: PAnsiChar; uType: UINT): Integer; stdcall;
type
  TNewMessageBoxA = function(_hWnd: HWND; lpText, lpCaption: PAnsiChar; uType: UINT): Integer; stdcall;
begin
  lpText := PAnsiChar('�Ѿ������� MessageBoxA');
  Hook[0].UnHook;
  Result := TNewMessageBoxA(Hook[0].BaseAddr)(_hWnd, lpText, lpCaption, uType);
  Hook[0].Hook;
end;

//���� MessageBoxW
function NewMessageBoxW(_hWnd: HWND; lpText, lpCaption: PWideChar; uType: UINT): Integer; stdcall;
type
  TNewMessageBoxW = function(_hWnd: HWND; lpText, lpCaption: PWideChar; uType: UINT): Integer; stdcall;
begin
  lpText := '�Ѿ������� MessageBoxW';
  Hook[2].UnHook;
  Result := TNewMessageBoxW(Hook[2].BaseAddr)(_hWnd, lpText, lpCaption, uType);
  Hook[2].Hook;
end;

procedure NewGetLocalTime(var lpSystemTime: TSystemTime); stdcall;
begin
  Hook[4].UnHook;
  GetLocalTime(lpSystemTime);
  lpSystemTime.wYear := lpSystemTime.wYear - 3;
  Hook[4].Hook;
end;

//���� MessageBeep
function NewMessageBeep(uType: UINT): BOOL; stdcall;
type
  TNewMessageBeep = function(uType: UINT): BOOL; stdcall;
begin
  Result := True;
end;

//���� OpenProcess , ��ֹ�ر�
function NewOpenProcess(dwDesiredAccess: DWORD; bInheritHandle: BOOL; dwProcessId: DWORD): THandle; stdcall;
type
  TNewOpenProcess = function(dwDesiredAccess: DWORD; bInheritHandle: BOOL; dwProcessId: DWORD): THandle; stdcall;
begin
  if startPid^ = dwProcessId then
  begin
    result := 0;
    Exit;
  end;
  Hook[3].UnHook;
  Result := TNewOpenProcess(Hook[3].BaseAddr)(dwDesiredAccess, bInheritHandle, dwProcessId);
  Hook[3].Hook;
end;

{--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--}

//��װAPI Hook
procedure InitHook;
begin

  Hook[0] := TNtHookClass.Create('user32.dll', 'MessageBoxA', @NewMessageBoxA);
  Hook[1] := TNtHookClass.Create('user32.dll', 'MessageBeep', @NewMessageBeep);
  Hook[2] := TNtHookClass.Create('user32.dll', 'MessageBoxW', @NewMessageBoxW);
  Hook[3] := TNtHookClass.Create('kernel32.dll', 'OpenProcess', @NewOpenProcess);

  Hook[4] := TNtHookClass.Create('kernel32.dll', 'GetLocalTime', @NewGetLocalTime);
end;

//ɾ��API Hook
procedure UninitHook;
var
  I: Integer;
begin
  for I := 0 to High(Hook) do
  begin
    FreeAndNil(Hook[I]);
  end;
end;

{--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--}

//�ڴ�ӳ�乲��
procedure MemShared();
begin
  MemFile := OpenFileMapping(FILE_MAP_ALL_ACCESS, False, HOOK_MEM_FILENAME);
//���ڴ�ӳ���ļ�
  if MemFile = 0 then
  begin  //��ʧ�����_c2���ڴ�ӳ���ļ�
    MemFile := CreateFileMapping($FFFFFFFF, nil, PAGE_READWRITE, 0, 4, HOOK_MEM_FILENAME);
  end;
  if MemFile <> 0 then
//ӳ���ļ�������
    startPid := MapViewOfFile(MemFile, FILE_MAP_ALL_ACCESS, 0, 0, 0);
end;

//������Ϣ

function HookProc(code: Integer; wparam: WPARAM; lparam: LPARAM): LRESULT; stdcall;
begin
  Result := CallNextHookEx(hhk, code, wParam, lParam);
end;

//��ʼHOOK
procedure StartHook(pid: DWORD); stdcall;
begin
  startPid^ := pid;
  hhk := SetWindowsHookEx(WH_CALLWNDPROC, HookProc, hInstance, 0);
end;

//����HOOK
procedure EndHook; stdcall;
begin
  if hhk <> 0 then
    UnhookWindowsHookEx(hhk);
end;

//��������
procedure DllEntry(dwResaon: DWORD);
begin
  case dwResaon of
    DLL_PROCESS_ATTACH:
      InitHook;   //DLL����
    DLL_PROCESS_DETACH:
      UninitHook; //DLLɾ��
//    DLL_THREAD_ATTACH:
//      InitHook;   //DLL����
//    DLL_THREAD_DETACH:
//      UninitHook; //DLLɾ��
  end;
end;

exports
  StartHook,
  EndHook;

begin
  MemShared;
  { ����DLL���� DllProc ���� }
  DllProc := @DllEntry;
  { ����DLL���ش��� }
  DllEntry(DLL_PROCESS_ATTACH);
end.

