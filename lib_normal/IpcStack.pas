unit IpcStack;

interface

uses
  windows, SysUtils, Dialogs, SyncObjs, Classes;

type
  PMappingInfo = ^TMappingInfo;
  TMappingInfo = packed   record
    Time: TDateTime;//���洴����ʱ��
    ProCount: LongInt;
    //��ǰ�����˼���ʵ��,������ʹ�����һ��ҪFree   ����������ֵ���ܲ�׼
  end;

  TFileMappingObj = class
  private
    FMutexName: String;           //����������
    FMutexHandle: THandle;        //������
    FMapHandle: THandle;          //ӳ������
    FMapBuf: Pointer;             //ӳ���ļ�������
    FMappingSize: LongInt;        //ӳ���ļ���С
    FMappingInfo: PMappingInfo;   //ͷ��Ϣ
    FMaptingName: String;         //ӳ���ļ���
  protected
    property MutexHandle: THandle read FMutexHandle;
    procedure OnCreateMapping; virtual;//ÿһ�δ���ʱ����
    procedure OnOpenMapping;           //ӳ���Ѵ���,��ʱ����
  public
    constructor Create(AMappingName: String; ASize: LongInt);//override;
    destructor Destroy; override;
    function GetMapBuf: Pointer;
    function GetMappingName: String;
    function GetMappingSize: LongInt;
    function GetProCount: LongInt;
    function GetTime: TDateTime;
  published
  end;


  PMapStackInfo = ^TMapStackInfo;
  TMapStackInfo = packed   record
    ItemSize: Integer;   //�б���Ԫ�صĴ�С
    MaxCount: Integer;   //Ԫ�ص�������
    Count: Integer;      //��ǰԪ�ص��ܸ���
    TopPoint: Integer;   //ջͷ
    EndPoint: Integer;   //ջ��
  end;

  //����ʱ���ԭ��������
  TStackNotifyEvent = procedure(Value: Pointer) of object;

  TMapCustomStack = class(TFileMappingObj)
  private
    FMapStackInfo: PMapStackInfo;
    FDateBuf: Pointer;
    FOnPopEndEvent: TStackNotifyEvent;    //��ջ�ɹ����������ʱ����
    FOnPushEndEvent: TStackNotifyEvent;   //ѹջ�ɹ������
  protected
    procedure PopClear(Value: Pointer); virtual;
  public
    constructor Create(AMappingName: String; AItemSize, AMaxCount: Integer);

    destructor Destroy; override;
    //ѹջ
    function Push(const Item): Integer; virtual; abstract;
    //��ջ
    function Pop(var Item): Integer; virtual; abstract;
    function GetCount: Integer;
    function GetMaxCount: Integer;
    function GetItemSize: Integer;
    //����������ŷ���ָ��,���ܸ�����λ��û��ֵ
    function GetItem(Index: Integer): Pointer;
    procedure Clear;
  published
    property OnPopEnd: TStackNotifyEvent read FOnPopEndEvent write FOnPopEndEvent;
    property OnPushEnd: TStackNotifyEvent read FOnPushEndEvent write FOnPushEndEvent;
  end;

  //���ڴ�ӳ��ʵ�ֵ�ջ,����ȳ�
  TMapStack = class(TMapCustomStack)
  private
  protected
  public
    //ѹջ   ,�����������ڵ�λ��   С��0û�гɹ�   �������ֵջ��
    function Push(const Item): Integer; override;
    //��ջ   С��0��ջ����ʧ��
    function Pop(var Item): Integer; override;
  published

  end;

  //���ڴ�ӳ��ʵ�ֵ�ջ,�Ƚ��ȳ�
  TMapQueue = class(TMapCustomStack)
  private
  protected
  public
    //ѹջ
    function Push(const Item): Integer; override;
    //��ջ
    function Pop(var Item): Integer; override;
  published

  end;

  //++++++++++++++++++�ڴ�ӳ��ʵ�ֵ��б�,����ͬһ�ֽṹ��֧�ֶ��߳�ͬ��,
  //һ�η������ռ�

  //�ú���ȳ��Ķ�ջʵ��,��ջ�б�����пռ��λ��,
  //�������б����߼���ź�������ŵĶ�Ӧ��ϵ
  //��������ӳ���ļ�,һ����������ʵ�ʵ�����,
  //��һ���û���������ķ�����Ϣ

  //����һ���б�,���Զ��̲߳���
  //������ӳ���ļ�ʵ��,һ���û����������ͷ��Ϣ,��һ����������
  //������չ��ϡ���ύ���ļ���ʽ

  PMappingListIndex = ^TMappingListIndex;
  TMappingListIndex = array of Integer;

  TMappingList = class(TFileMappingObj)
  private
    FItemSize: PInteger;
    FListIndexArr: PMappingListIndex;
    FListHeadStack: TMapStack;
    FListDataBuf: Pointer;//�б����ݵ�λ��
  protected
    procedure OnCreateMapping; override;
    procedure OnStackPopEnd(Value: Pointer);
  public
    constructor Create(AMappingName: String; AItemSize, AMaxCount: Integer);

    destructor Destroy; override;
    function Add(const Data): Integer;
    procedure Delete(Index: Integer);
    procedure ShowStackInfo(var AStrList: TStringList);
    procedure ShowDataInfo(var AStrList: TStringList);
    procedure Clear;
    function GetCount: Integer;
    function GetItem(Index: Integer): Pointer;
  published

  end;

implementation

  {   TFileMappingObj   }

function TFileMappingObj.GetProCount: LongInt;
begin
  Result := FMappingInfo.ProCount;
end;

constructor TFileMappingObj.Create(AMappingName: String; ASize: LongInt);
begin
  inherited   Create;
  FMaptingName := AMappingName;
  FMutexName := FMaptingName + '_Mutex';
  FMappingSize := ASize + Sizeof(TMappingInfo);
  //     +SEC_RESERVE

  FMutexHandle := CreateMutex(nil, False, PChar(FMutexName));
  case GetLastError of
    0:   //û�г�������   ��һ�δ���
      begin
        //ӳ�䵽�Լ��ĵ�ַ�ռ�
        case WaitForSingleObject(FMutexHandle, INFINITE) of
          WAIT_OBJECT_0:
            begin
              FMapHandle := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0, FMappingSize, PChar(FMaptingName));
              if FMapHandle <> 0 then
              begin
                FMappingInfo := MapViewOfFile(FMapHandle, FILE_MAP_ALL_ACCESS, 0, 0, FMappingSize);
                if FMappingInfo <> nil then
                begin
                  FMapBuf := Pointer(Integer(FMappingInfo) + Sizeof(TMappingInfo));
                  FMappingInfo.ProCount := 1;
                  ZeroMemory(FMapBuf, FMappingSize);
                  //��ʼ��Ϊ0
                  FMappingInfo.Time := Now;
                  OnCreateMapping;
                end;           
              end;
              ReleaseMutex(FMutexHandle);
            end;
          WAIT_TIMEOUT:;
          WAIT_FAILED:;
        end;
      end;
    ERROR_ALREADY_EXISTS://�����Ծ�����
      begin
        CloseHandle(FMutexHandle);
        FMutexHandle := OpenMutex(MUTEX_ALL_ACCESS, False, PChar(FMutexName));
        case WaitForSingleObject(FMutexHandle, INFINITE) of
          WAIT_ABANDONED:
            ShowMessage('OK');
          WAIT_OBJECT_0:
            begin
              FMapHandle :=
                OpenFileMapping(FILE_MAP_WRITE, False, PChar(FMaptingName));
              if FMapHandle <> 0 then
              begin
                FMappingInfo :=
                  MapViewOfFile(FMapHandle, FILE_MAP_ALL_ACCESS, 0,
                  0, FMappingSize);
                if FMappingInfo <> nil then
                begin
                  FMapBuf :=
                    Pointer(Integer(FMappingInfo) + Sizeof(TMappingInfo));
                  InterlockedIncrement(FMappingInfo.ProCount);
                  //���������1
                  OnOpenMapping;
                end;
              end;
              ReleaseMutex(FMutexHandle);
            end;
          WAIT_TIMEOUT:;
          WAIT_FAILED:;
        end;
      end;
    ERROR_INVALID_HANDLE:;//�������ں˶���ͬ��
  end;
end;

destructor TFileMappingObj.Destroy;
begin
  FMappingInfo.ProCount := FMappingInfo.ProCount - 1;
  CloseHandle(FMapHandle);
  //�ͷŻ������
  CloseHandle(FMutexHandle);
  inherited;
end;

function TFileMappingObj.GetMapBuf: Pointer;
begin
  Result := FMapBuf;
end;

function TFileMappingObj.GetMappingName: String;
begin
  Result := FMaptingName;
end;

function TFileMappingObj.GetMappingSize: LongInt;
begin
  Result := FMappingSize;
end;

function TFileMappingObj.GetTime: TDateTime;
begin
  Result := FMappingInfo.Time;
end;

procedure TFileMappingObj.OnCreateMapping;
begin
end;

procedure TFileMappingObj.OnOpenMapping;
begin
end;

  {   TMappingList   }

constructor TMappingList.Create(AMappingName: String;
  AItemSize, AMaxCount: Integer);
var
  i, L: Integer;
begin
  //�б���ܵ�ռ�ÿռ�Ĵ�С   ǰ�����������Ϣ,�󲿱�������
  FListHeadStack := TMapStack.Create(GetMappingName + '_HeadStack',
    Sizeof(Integer), AMaxCount);
  FListHeadStack.OnPopEnd := OnStackPopEnd;
  inherited   Create(AMappingName,
    Sizeof(Integer) +//�����û����ݴ�С
    Sizeof(Integer) * AMaxCount +//�����Ӧ������б�
    AItemSize * AMaxCount);
  FItemSize := GetMapBuf;
  CopyMemory(FItemSize, @AItemSize, Sizeof(Integer));
  FListIndexArr := Pointer(Integer(FItemSize) + Sizeof(Integer));
  FListDataBuf := Pointer(Integer(FListIndexArr) + Sizeof(Integer) * AMaxCount);


  //��һ�δ���ʱ�����еĿ�λ��ѹջ
  L := FListHeadStack.GetMaxCount - 1;
  for   i := L downto 0 do
    TMappingListIndex(FListIndexArr)[i] := -1;
end;

function TMappingList.Add(const Data): Integer;
var
  APopIndex: Integer;
  ANewPoint: Pointer;
begin
  Result := -1;
  //���һ����¼,���ҳ�һ���յ�λ�ñ���,��ӵ�λ�ò���һ�������һ��.
  if FListHeadStack.Pop(APopIndex) >= 0 then
  begin
    case WaitForSingleObject(MutexHandle, INFINITE) of
      WAIT_OBJECT_0:
        begin
          ANewPoint := Pointer(Integer(FListDataBuf) + APopIndex * FItemSize^);
          //���û����ݱ��浽ӳ���ļ�
          CopyMemory(ANewPoint, @Data, FItemSize^);
          //���������ڵ�����λ�ñ���
          Result := FListHeadStack.GetMaxCount - FListHeadStack.GetCount - 1;
          TMappingListIndex(FListIndexArr)[Result] := APopIndex;
          ReleaseMutex(MutexHandle);
        end;
      WAIT_TIMEOUT:;
      WAIT_FAILED:;
    end;
  end;
end;

procedure TMappingList.Delete(Index: Integer);
var
  ADataIndex: Integer;
  AItemPointer: Pointer;
  i, L: Integer;
begin
  //ɾ������λ�õ�ֵ       ���������û���ӵ����
  //����ʱ�����Ǳ����ڶ�Ӧ������λ��
  //��ջ�еĶ�Ӧ��Index   �б�����Ƕ�Ӧ������λ��
  //���ҵ���������ű���������ռ�����
  if (Index >= 0) and (Index < FListHeadStack.GetMaxCount) then
  begin
    //����Ƿ��Ѿ�ɾ������.
    ADataIndex := TMappingListIndex(FListIndexArr)[Index];
    //FListHeadStack.GetItem(Index);
    AItemPointer := Pointer(Integer(FListDataBuf) + ADataIndex * FItemSize^);

    //����ǰɾ����λ����Ϣ����
    FListHeadStack.Push(ADataIndex);
    //ջ�Ĵ��ϵ��µ���Ŷ�Ӧ�û����ݵ����
    //�û����ݵ���������ƶ�һλ
    L := GetCount;
    for   i := Index to L do
      TMappingListIndex(FListIndexArr)[i] :=
        TMappingListIndex(FListIndexArr)[i + 1];
    TMappingListIndex(FListIndexArr)[L] := -1;
    //ɾ���б��е�����
    ZeroMemory(AItemPointer, FItemSize^);
  end;
end;


procedure TMappingList.OnCreateMapping;
var
  i, L: Integer;
begin
  inherited;
  //��һ�δ���ʱ�����еĿ�λ��ѹջ
  L := FListHeadStack.GetMaxCount - 1;
  for   i := L downto 0 do
  begin
    FListHeadStack.Push(i);
  end;
end;

procedure TMappingList.ShowStackInfo(var AStrList: TStringList);
var
  i, L: Integer;
  m: PInteger;
begin
  L := FListHeadStack.GetMaxCount - 1;
  for   i := 0 to L do
  begin
    m := FListHeadStack.GetItem(i);

    AStrList.Add(Format('%p   %d=%d',
      [m, m^, TMappingListIndex(FListIndexArr)[i]]));
  end;
end;

procedure TMappingList.Clear;
var
  i, L: Integer;
begin
  //������е�����
  FListHeadStack.Clear;
  ZeroMemory(FListDataBuf, FItemSize^ * FListHeadStack.GetMaxCount);
  //��һ�δ���ʱ�����еĿ�λ��ѹջ
  L := FListHeadStack.GetMaxCount - 1;
  for   i := L downto 0 do
  begin
    FListHeadStack.Push(i);
  end;
  L := FListHeadStack.GetMaxCount - 1;
  for   i := L downto 0 do
    TMappingListIndex(FListIndexArr)[i] := -1;
end;

destructor TMappingList.Destroy;
begin
  FListHeadStack.Free;
  inherited;
end;

function TMappingList.GetCount: Integer;
begin
  Result := FListHeadStack.GetMaxCount - FListHeadStack.GetCount;
end;

procedure TMappingList.ShowDataInfo(var AStrList: TStringList);
var
  i, L: Integer;
  m: PInteger;
begin
  L := FListHeadStack.GetMaxCount - 1;
  for   i := 0 to L do
  begin
    m := Self.GetItem(i);
    AStrList.Add(Chr(m^) + '=' + IntToStr(i));
  end;
end;

function TMappingList.GetItem(Index: Integer): Pointer;
begin
  if (Index >= 0) and (Index < FListHeadStack.GetMaxCount) then
    Result := Pointer(Integer(FListDataBuf) + Index * FItemSize^)
  else
    Result := nil;
end;

procedure TMappingList.OnStackPopEnd(Value: Pointer);
var
  ANullIndex: Integer;
begin
  ANullIndex := -1;
  CopyMemory(Value, @ANullIndex, Sizeof(Integer));
end;

  {   TMapStack   }

function TMapCustomStack.GetCount: Integer;
begin
  Result := FMapStackInfo.Count;
end;

function TMapCustomStack.GetMaxCount: Integer;
begin
  Result := FMapStackInfo.MaxCount;
end;

function TMapStack.Pop(var Item): Integer;
var
  AFirstPointer: Pointer;
begin
  //��ջ,����ȳ�
  case WaitForSingleObject(MutexHandle, INFINITE) of
    WAIT_OBJECT_0:
      begin
        if FMapStackInfo.Count = 0 then
          Result := -1
        else
        begin
          AFirstPointer :=
            Pointer(Integer(FDateBuf) + (FMapStackInfo.Count - 1) * GetItemSize);
          CopyMemory(@Item, AFirstPointer, GetItemSize);
          Result := FMapStackInfo.MaxCount - FMapStackInfo.Count;
          //���ص�����λ��
          FMapStackInfo.Count := FMapStackInfo.Count - 1;
          FMapStackInfo.TopPoint := FMapStackInfo.TopPoint - 1;
          PopClear(AFirstPointer);//������,�������
          if Assigned(OnPopEnd) then
            OnPopEnd(AFirstPointer);
        end;
        ReleaseMutex(MutexHandle);
      end;
    WAIT_TIMEOUT: Result := -2;
    WAIT_FAILED:  Result := -3;
    ELSE          Result := -4;
  end;
end;

function TMapStack.Push(const Item): Integer;
var
  ANewPointer: Pointer;
begin
  //   ѹջ,���һ���µ�����,����ռ䲻��,�����½��з���     ����ȳ�
  case WaitForSingleObject(MutexHandle, INFINITE) of
    WAIT_OBJECT_0:
      begin
        if FMapStackInfo.Count = FMapStackInfo.MaxCount then
          Result := FMapStackInfo.MaxCount
            //���ջ�����򷵻�����ֵ
        else
        begin
          ANewPointer := Pointer(Integer(FDateBuf) +
            (FMapStackInfo.TopPoint) * GetItemSize);
          CopyMemory(ANewPointer, @Item, GetItemSize);
          Result := FMapStackInfo.Count;   //���ص�ǰ���ڵ�λ��
          FMapStackInfo.Count := FMapStackInfo.Count + 1;
          FMapStackInfo.TopPoint := FMapStackInfo.TopPoint + 1;
          if Assigned(OnPushEnd) then
            OnPushEnd(ANewPointer);
        end;
        ReleaseMutex(MutexHandle);
      end;
    WAIT_TIMEOUT: Result := -2;
    WAIT_FAILED:  Result := -3;
    ELSE          Result := -4;
  end;
end;

  {   TMapCustomStack   }

constructor TMapCustomStack.Create(AMappingName: String;
  AItemSize, AMaxCount: Integer);
begin
  inherited   Create(AMappingName, AItemSize * AMaxCount + Sizeof(TMapStackInfo));

  FMapStackInfo := GetMapBuf;
  FDateBuf := Pointer(Integer(FMapStackInfo) + Sizeof(TMapStackInfo));
  FMapStackInfo.ItemSize := AItemSize;
  FMapStackInfo.MaxCount := AMaxCount;
  FMapStackInfo.TopPoint := 0;//��ǰ��ջ��
  FMapStackInfo.EndPoint := 0;
end;

destructor TMapCustomStack.Destroy;
begin
  inherited;
end;

function TMapCustomStack.GetItem(Index: Integer): Pointer;
begin
  //ѹջʱ��һ��ѹ�����ջ��,���һ����ջ��
  //�ڷ���ռ��б���ʱ�ȱ��浽��0
  //������   Index   ��ָջ��λ��,��ʹ����0��ջ��   MaxCount
  //����һ�������λ��,����ָ��
  if (Index >= 0) and (Index < FMapStackInfo.MaxCount) then
    Result := Pointer(Integer(FDateBuf) + (GetMaxCount - Index -1)
      * GetItemSize)
  else
    Result := nil;
end;

procedure TMapCustomStack.PopClear(Value: Pointer);
begin
  ZeroMemory(Value, GetItemSize);
end;

procedure TMapCustomStack.Clear;
begin
  FMapStackInfo.Count := 0;
  FMapStackInfo.TopPoint := 0;//��ǰ��ջ��
  FMapStackInfo.EndPoint := 0;
  ZeroMemory(FDateBuf, GetItemSize * GetMaxCount);
end;

function TMapCustomStack.GetItemSize: Integer;
begin
  Result := FMapStackInfo.ItemSize;
end;

  {   TMapStack_2   }

function TMapQueue.Pop(var Item): Integer;
var
  AFirstPointer: Pointer;
begin
  //��ջ   �Ƚ��ȳ�
  Result := -1;
  case WaitForSingleObject(MutexHandle, INFINITE) of
    WAIT_OBJECT_0:
      begin
        if FMapStackInfo.Count = 0 then     //û������

        else
        begin
          //���ȵ�������ջ��
          AFirstPointer :=
            Pointer(Integer(FDateBuf) + (FMapStackInfo.EndPoint) * GetItemSize);
          CopyMemory(@Item, AFirstPointer, GetItemSize);
          Result := FMapStackInfo.EndPoint;   //���ص�����λ��
          FMapStackInfo.Count := FMapStackInfo.Count - 1;
          if FMapStackInfo.EndPoint = FMapStackInfo.MaxCount - 1 then   
            FMapStackInfo.EndPoint := 0
          else     //����û�м��Ͷ���λ��,��Count������
            FMapStackInfo.EndPoint := FMapStackInfo.EndPoint + 1;

          //   FMapStackInfo.TopPoint   :=FMapStackInfo.TopPoint-1;
          PopClear(AFirstPointer);
          if Assigned(OnPopEnd) then
            OnPopEnd(AFirstPointer);
        end;
        ReleaseMutex(MutexHandle);
      end;
    WAIT_TIMEOUT:;
    WAIT_FAILED:;
  end;
end;

function TMapQueue.Push(const Item): Integer;
var
  ANewPointer: Pointer;
begin       //ѹջ   �Ƚ��ȳ�
            //   ѹջ,���һ���µ�����,����ռ䲻��,�����½��з���
  Result := -1;
  case WaitForSingleObject(MutexHandle, INFINITE) of
    WAIT_OBJECT_0:
      begin
        //if   FMapStackInfo.Count=FMapStackInfo.MaxCount   then     //ջ����
        if (FMapStackInfo.TopPoint = FMapStackInfo.EndPoint) and
          (FMapStackInfo.Count > 0) then
          Result := FMapStackInfo.MaxCount
            //���ջ�����򷵻�����ֵ
        else
        begin
          //�µ�λ��,����ջͷ��λ��
          ANewPointer := Pointer(Integer(FDateBuf) +
            (FMapStackInfo.TopPoint) * GetItemSize);
          CopyMemory(ANewPointer, @Item, GetItemSize);
          Result := FMapStackInfo.Count;   //���ص�ǰ���ڵ�λ��
          FMapStackInfo.Count := FMapStackInfo.Count + 1;
          //ջ�������б�����һ�������»ص�0
          if FMapStackInfo.TopPoint = FMapStackInfo.MaxCount - 1 then    
            FMapStackInfo.TopPoint := 0
          else
            FMapStackInfo.TopPoint := FMapStackInfo.TopPoint + 1;

          if Assigned(OnPushEnd) then
            OnPushEnd(ANewPointer);
        end;
        ReleaseMutex(MutexHandle);
      end;
    WAIT_TIMEOUT:;
    WAIT_FAILED:;
  end;
end;


  end.

