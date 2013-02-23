unit SearchFileUnit;

interface

uses Windows, SysUtils, Classes;

Type
  TEmuProceLocals  = Procedure (Sender: Pointer; FileName: PChar); stdcall;

procedure EnumerateFile(Sender: Pointer; Path:string; EumPro: TEmuProceLocals; BaseRoot: String = '');
function SearchFile(sFileName, sRootDir: string; bFileOnly, bRecurse: boolean): TStringList;

implementation


function SearchFile(sFileName, sRootDir: string; bFileOnly, bRecurse: boolean): TStringList;
//��Ƕ�ļ����ҵݹ����
  procedure DoSearchFile(sFileName, sRootDir: string; bFileOnly, bRecurse: boolean; var FileList: TStringList);
  var
    Found: integer;
    SearchRec: TSearchRec;
  begin
    //��ʼ����
    Found := FindFirst(sRootDir + '\*.*', faAnyFile, SearchRec);
    while Found = 0 do
    begin
      //������Ŀ¼ʱȷ���Ƿ������Ŀ¼���Ƿ񽫷�����������Ŀ¼������ҽ��
      if (SearchRec.Attr = faDirectory) and (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        if (AnsiCompareText(sFileName, SearchRec.Name) = 0) and not bFileOnly then
          FileList.Add(sRootDir + '\' + SearchRec.Name);
        if bRecurse then
          DoSearchFile(sFileName, sRootDir + '\' + SearchRec.Name, bFileOnly, bRecurse, FileList);
      end
      //�ҵ������������ļ�ʱ������ҽ��
      else if AnsiCompareText(sFileName, SearchRec.Name) = 0 then
        FileList.Add(sRootDir + '\' + SearchRec.Name);
      Found := FindNext(SearchRec);
    end;
    FindClose(SearchRec);
  end;
var
  FileList: TStringList;
begin
  FileList := TStringList.Create;
  FileList.Clear;
  DoSearchFile(sFileName, sRootDir, bFileOnly, bRecurse, FileList);
  Result := FileList;
end;


procedure EnumerateFile(Sender: Pointer; Path:string; EumPro: TEmuProceLocals; BaseRoot: String = '');
var
  SearchRec:TSearchRec;
  found:integer;
  FileName, DirName: String;
  UpperFile: String;
begin
  if not DirectoryExists(Path) then exit;
  BaseRoot := UpperCase (BaseRoot);
  
  found:=FindFirst(path+'*.*', faAnyFile, SearchRec);
  while found=0 do
  begin
    sleep(1);
    if (SearchRec.Name<>'.') and (SearchRec.name<>'..') and (SearchRec.Attr = faDirectory) then
    begin
      DirName := Path + SearchRec.Name + '\';
      EnumerateFile(Sender, DirName, EumPro, BaseRoot);
    end else
    begin
      FileName := Path + SearchRec.Name;
      if FileExists(FileName) then
      begin
        if BaseRoot = '' then
          EumPro (Sender, @FileName[1])
        else begin
          UpperFile := UpperCase(FileName);
          if CompareMem(@BaseRoot[1], @UpperFile[1], Length(BaseRoot)) then
            EumPro(Sender, @FileName[Length(BaseRoot)+1]);
        end;
      end;
    end;
    found:=FindNext(SearchREc);
  end;
  FindClose(SearchRec);
end;

end.