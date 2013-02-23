unit DragUnit;

interface
uses
  windows,classes,forms ,shellapi;


//�õ��Ϸŵ��ļ�����
function GetDragFileCount(hDrop: Cardinal): Integer;

//�õ��Ϸŵ��ļ�����ͨ��FileIndex��ָ���ļ���ţ�Ĭ��Ϊ��һ���ļ� 
function GetDragFileName(hDrop: Cardinal; FileIndex: Integer = 1): string;

implementation 


function GetDragFileCount(hDrop: Cardinal): Integer; 
const 
  DragFileCount=High(Cardinal); 
begin 
  Result:= DragQueryFile(hDrop, DragFileCount, nil, 0); 
end; 

function GetDragFileName(hDrop: Cardinal; FileIndex: Integer = 1): string; 
const 
  Size=255; 
var 
  Len: Integer; 
  FileName: string; 
begin 
  SetLength (FileName, Size); 
  Len:= DragQueryFile(hDrop, FileIndex-1, PChar(FileName), Size); 
  SetLength (FileName, Len); 
  Result:= FileName; 
end; 

end. 

