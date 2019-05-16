unit ufrmHookMsg;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, tlhelp32, StdCtrls;

type
  TfrmHookMsg = class(TForm)
    EditName: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    EditDll: TEdit;
    Inject: TButton;
    procedure InjectClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmHookMsg: TfrmHookMsg;

implementation

{$R *.dfm}

{ �оٽ��� }
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

{ ����Ȩ�� }
function EnabledDebugPrivilege(const Enabled : Boolean) : Boolean;
var
  hTk : THandle; { �����ƾ�� }
  rtnTemp : Dword; { ����Ȩ��ʱ���ص�ֵ }
  TokenPri : TOKEN_PRIVILEGES;
const
  SE_DEBUG = 'SeDebugPrivilege'; { ��ѯֵ }
begin
  Result := False;
  { ��ȡ�������ƾ��,����Ȩ�� }
  if (OpenProcessToken(GetCurrentProcess(),TOKEN_ADJUST_PRIVILEGES,hTk)) then
  begin
    TokenPri.PrivilegeCount := 1;
    { ��ȡLuidֵ }
    LookupPrivilegeValue(nil,SE_DEBUG,TokenPri.Privileges[0].Luid);

    if Enabled then
      TokenPri.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED
    else
      TokenPri.Privileges[0].Attributes := 0;

    rtnTemp := 0;
    { �����µ�Ȩ�� }
    AdjustTokenPrivileges(hTk,False,TokenPri,sizeof(TokenPri),nil,rtnTemp);

    Result := GetLastError = ERROR_SUCCESS;
    CloseHandle(hTk);

  end;
end;

{ ���Ժ��� }
procedure OutPutText(var CH:PChar);
var
  FileHandle: TextFile;
Begin
  AssignFile(FileHandle,'zztest.txt');
  Append(FileHandle);
  Writeln(FileHandle,CH);
  Flush(FileHandle);
  CloseFile(FileHandle);
END;

{ ע��Զ�̽��� }
function InjectTo(const Host, Guest: string; const PID: DWORD = 0): DWORD;
var
  { ��ע��Ľ��̾��,����ID}
  hRemoteProcess: THandle;
  dwRemoteProcessId: DWORD;
  { д��Զ�̽��̵����ݴ�С }
  memSize: DWORD;
  { д�뵽Զ�̽��̺�ĵ�ַ }
  pszLibFileRemote: Pointer;
  iReturnCode: Boolean;
  TempVar: DWORD;
  { ָ����LoadLibraryW�ĵ�ַ }
  pfnStartAddr: TFNThreadStartRoutine;
  { dllȫ·��,��Ҫд��Զ�̽��̵��ڴ���ȥ }
  pszLibAFilename: PwideChar;
begin
  Result := 0;
  { ����Ȩ�� }
  EnabledDebugPrivilege(True);

  { Ϊע���dll�ļ�·�������ڴ��С,����ΪWideChar,��Ҫ��2 }
  Getmem(pszLibAFilename, Length(Guest) * 2 + 1);
  StringToWideChar(Guest, pszLibAFilename, Length(Guest) * 2 + 1);

  { ��ȡ����ID }
  if PID > 0 then
     dwRemoteProcessID := PID
  else
     GetMyProcessID(Host, False, dwRemoteProcessID);

  { ȡ��Զ�̽��̾��,����д��Ȩ��}
  hRemoteProcess := OpenProcess(PROCESS_CREATE_THREAD + {����Զ�̴����߳�}
      PROCESS_VM_OPERATION + {����Զ��VM����}
      PROCESS_VM_WRITE, {����Զ��VMд}
      FALSE, dwRemoteProcessId);

  { �ú���VirtualAllocex��Զ�̽��̷���ռ�,����WriteProcessMemory��д��dll·�� }
  memSize := (1 + lstrlenW(pszLibAFilename)) * sizeof(WCHAR);
  pszLibFileRemote := PWIDESTRING(VirtualAllocEx(hRemoteProcess, nil, memSize, MEM_COMMIT, PAGE_READWRITE));
  TempVar := 0;
  iReturnCode := WriteProcessMemory(hRemoteProcess, pszLibFileRemote, pszLibAFilename, memSize, TempVar);
  if iReturnCode then
  begin
    pfnStartAddr := GetProcAddress(GetModuleHandle('Kernel32'), 'LoadLibraryW');
    TempVar := 0;
    { ��Զ�̽���������dll }
    Result := CreateRemoteThread(hRemoteProcess, nil, 0, pfnStartAddr, pszLibFileRemote, 0, TempVar);
  end;
  { �ͷ��ڴ�ռ� }
  Freemem(pszLibAFilename);
end;

{ ���� }
procedure TfrmHookMsg.InjectClick(Sender: TObject);
var
  DllPath: string;
begin
  DllPath :=  EditDll.Text;
  if (not FileExists(DllPath)) or (ExtractFilePath(DllPath) = '') then
     DllPath := ExtractFilePath(ParamStr(0))  + EditDll.Text;
  if FileExists(DllPath)  then
    ShowMessage(IntToStr(InjectTo(EditName.Text, DllPath)))

end;

end.
