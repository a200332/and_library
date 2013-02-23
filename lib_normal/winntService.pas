unit winntService;

interface

uses
Windows,WinSvc,WinSvcEx;

function InstallService(const strServiceName,strDisplayName,strDescription,strFilename: string):Boolean;
//eg:InstallService('��������','��ʾ����','������Ϣ','�����ļ�');
procedure UninstallService(strServiceName:string);
implementation

function StrLCopy(Dest: PChar; const Source: PChar; MaxLen: Cardinal): PChar; assembler;
asm
PUSH EDI
PUSH ESI
PUSH EBX
MOV ESI,EAX
MOV EDI,EDX
MOV EBX,ECX
XOR AL,AL
TEST ECX,ECX
JZ @@1
REPNE SCASB
JNE @@1
INC ECX
@@1: SUB EBX,ECX
MOV EDI,ESI
MOV ESI,EDX
MOV EDX,EDI
MOV ECX,EBX
SHR ECX,2
REP MOVSD
MOV ECX,EBX
AND ECX,3
REP MOVSB
STOSB
MOV EAX,EDX
POP EBX
POP ESI
POP EDI
end;

function StrPCopy(Dest: PChar; const Source: string): PChar;
begin
Result := StrLCopy(Dest, PChar(Source), Length(Source));
end;

function InstallService(const strServiceName,strDisplayName,strDescription,strFilename: string):Boolean;
var
//ss : TServiceStatus;
//psTemp : PChar;
hSCM,hSCS:THandle;

srvdesc : PServiceDescription;
desc : string;
//SrvType : DWord;

lpServiceArgVectors:pchar;
begin
Result:=False;
//psTemp := nil;
//SrvType := SERVICE_WIN32_OWN_PROCESS and SERVICE_INTERACTIVE_PROCESS;
hSCM:=OpenSCManager(nil,nil,SC_MANAGER_ALL_ACCESS);//���ӷ������ݿ�
if hSCM=0 then Exit;//MessageBox(hHandle,Pchar(SysErrorMessage(GetLastError)),'������������',MB_ICONERROR+MB_TOPMOST);


hSCS:=CreateService( //����������
hSCM, // ������ƹ�����
Pchar(strServiceName), // ��������
Pchar(strDisplayName), // ��ʾ�ķ�������
SERVICE_ALL_ACCESS, // ��ȡȨ��
SERVICE_WIN32_OWN_PROCESS or SERVICE_INTERACTIVE_PROCESS,// �������� SERVICE_WIN32_SHARE_PROCESS
SERVICE_AUTO_START, // ��������
SERVICE_ERROR_IGNORE, // �����������
Pchar(strFilename), // �������
nil, // ���������
nil, // ���ʶ
nil, // �����ķ���
nil, // ���������ʺ�
nil); // �����������
if hSCS=0 then Exit;//MessageBox(hHandle,Pchar(SysErrorMessage(GetLastError)),Pchar(Application.Title),MB_ICONERROR+MB_TOPMOST);

if Assigned(ChangeServiceConfig2) then
begin
desc := Copy(strDescription,1,1024);
GetMem(srvdesc,SizeOf(TServiceDescription));
GetMem(srvdesc^.lpDescription,Length(desc) + 1);
try
StrPCopy(srvdesc^.lpDescription, desc);
ChangeServiceConfig2(hSCS,SERVICE_CONFIG_DESCRIPTION,srvdesc);
finally
FreeMem(srvdesc^.lpDescription);
FreeMem(srvdesc);
end;
end;
lpServiceArgVectors := nil;
if not StartService(hSCS, 0, lpServiceArgVectors) then //��������
Exit; //MessageBox(hHandle,Pchar(SysErrorMessage(GetLastError)),Pchar(Application.Title),MB_ICONERROR+MB_TOPMOST);
CloseServiceHandle(hSCS); //�رվ��
Result:=True;
end;

procedure UninstallService(strServiceName:string);
var
SCManager: SC_HANDLE;
Service: SC_HANDLE;
Status: TServiceStatus;
begin
SCManager := OpenSCManager(nil, nil, SC_MANAGER_ALL_ACCESS);
if SCManager = 0 then Exit;
try
Service := OpenService(SCManager, Pchar(strServiceName), SERVICE_ALL_ACCESS);
ControlService(Service, SERVICE_CONTROL_STOP, Status);
DeleteService(Service);
CloseServiceHandle(Service);
finally
CloseServiceHandle(SCManager);
end;
end;

end.
