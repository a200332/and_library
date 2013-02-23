unit   FileMap;   
    
  interface   
    
  uses   
      Windows,Messages,SysUtils,Classes,Graphics,Controls,Forms,StdCtrls,Dialogs;   
    
  type
      TFileMap=class(TComponent)   
      private   
          FMapHandle:THandle;                   //�ڴ�ӳ���ļ����   
          FMutexHandle:THandle;               //������   
          FMapName:string;                         //�ڴ�ӳ�����   
          FSynchMessage:string;               //ͬ����Ϣ   
          FMapStrings:TStringList;         //�洢ӳ���ļ���Ϣ   
          FSize:DWord;                                 //ӳ���ļ���С   
          FMessageID:DWord;                       //ע�����Ϣ��   
          FMapPointer:PChar;                     //ӳ���ļ���������ָ��   
          FLocked:Boolean;                         //����   
          FIsMapOpen:Boolean;                   //�ļ��Ƿ��   
          FExistsAlready:Boolean;           //�Ƿ��Ѿ�������ӳ���ļ�   
          FReading:Boolean;                       //�Ƿ����ڶ�ȡ�ڴ��ļ�����   
          FAutoSynch:Boolean;                   //�Ƿ�ͬ��   
          FOnChange:TNotifyEvent;           //���ڴ����������ݸı�ʱ   
          FFormHandle:Hwnd;                       //�洢�����ڵĴ��ھ��   
          FPNewWndHandler:Pointer;   
          FPOldWndHandler:Pointer;   
          procedure   SetMapName(Value:string);   
          procedure   SetMapStrings(Value:TStringList);   
          procedure   SetSize(Value:DWord);   
          procedure   SetAutoSynch(Value:Boolean);   
          procedure   EnterCriticalSection;   
          procedure   LeaveCriticalSection;   
          procedure   MapStringsChange(Sender:TObject);   
          procedure   NewWndProc(var   FMessage:TMessage);   
      public   
          constructor   Create(AOwner:TComponent);override;   
          destructor   Destroy;override;   
          procedure   OpenMap;   
          procedure   CloseMap;   
          procedure   ReadMap;   
          procedure   WriteMap;   
          property   ExistsAlready:Boolean   read   FExistsAlready;   
          property   IsMapOpen:Boolean   read   FIsMapOpen;   
      published   
          property   MaxSize:DWord   read   FSize   write   SetSize;   
          property   AutoSynchronize:Boolean   read   FAutoSynch   write   SetAutoSynch;   
          property   MapName:string   read   FMapName   write   SetMapName;   
          property   MapStrings:TStringList   read   FMapStrings   write   SetMapStrings;   
          property   OnChange:TNotifyEvent   read   FOnChange   write   FOnChange;   
      end;   
  implementation   
    
  //���캯��   
  constructor   TFileMap.Create(AOwner:TComponent);   
  begin   
      inherited   Create(AOwner);   
      FAutoSynch:=True;   
      FSize:=4096;   
      FReading:=False;   
      FMapStrings:=TStringList.Create;   
      FMapStrings.OnChange:=MapStringsChange;   
      FMapName:='Unique   &   Common   name';   
      FSynchMessage:=FMapName+'Synch-Now';   
      if   AOwner   is   TForm   then   
      begin   
          FFormHandle:=(AOwner   as   TForm).Handle;   
          //�õ����ڴ�����̵ĵ�ַ   
          FPOldWndHandler:=Ptr(GetWindowLong(FFormHandle,GWL_wNDPROC));   
          FPNewWndHandler:=MakeObjectInstance(NewWndProc);   
          if   FPNewWndHandler=nil   then   
              raise   Exception.Create('������Դ');   
          //���ô��ڴ�����̵��µ�ַ   
          SetWindowLong(FFormHandle,GWL_WNDPROC,Longint(FPNewWndHandler));   
      end   
      else   raise   Exception.Create('�����������Ӧ����TForm');   
  end;   
    
  //��������   
  destructor   TFileMap.Destroy;   
  begin   
      CloseMap;   
      //��ԭWindows������̵�ַ   
      SetWindowLong(FFormHandle,GWL_WNDPROC,Longint(FPOldWndHandler));   
      if   FPNewWndHandler<>nil   then   
          FreeObjectInstance(FPNewWndHandler);   
      //�ͷŶ���   
      FMapStrings.Free;   
      FMapStrings:=nil;   
      inherited   destroy;   
  end;

//���ļ�ӳ�䣬��ӳ�䵽���̿ռ�   
  procedure   TFileMap.OpenMap;   
  var   
      TempMessage:array[0..255]   of   Char;   
  begin   
      if   (FMapHandle=0)   and   (FMapPointer=nil)   then   
      begin   
          FExistsAlready:=False;   
          //�����ļ�ӳ�����   
          FMapHandle:=CreateFileMapping($FFFFFFFF,nil,PAGE_READWRITE,0,FSize,PChar(FMapName));   
          if   (FMapHandle=INVALID_HANDLE_VALUE)   or   (FMapHandle=0)   then   
              raise   Exception.Create('�����ļ�ӳ�����ʧ��!')   
          else   
          begin   
          //�ж��Ƿ��Ѿ������ļ�ӳ����   
              if   (FMapHandle<>0)   and   (GetLastError=ERROR_ALREADY_EXISTS)   then   
                  FExistsAlready:=True;   //����Ѿ������Ļ���������ΪTRUE��   
              //ӳ���ļ���ʹͽ�����̵ĵ�ַ�ռ�   
              FMapPointer:=MapViewOfFile(FMapHandle,FILE_MAP_ALL_ACCESS,0,0,0);   
              if   FMapPointer=nil   then   
                  raise   Exception.Create('ӳ���ļ�����ͼ�����̵ĵ�ַ�ռ�ʧ��')   
              else   
              begin   
                  StrPCopy(TempMessage,FSynchMessage);   
                  //��WINDOWS��ע����Ϣ����   
                  FMessageID:=RegisterWindowMessage(TempMessage);   
                  if   FMessageID=0   then   
                      raise   Exception.Create('ע����Ϣʧ��')   
              end   
          end;   
          //�������������д�ļ�ӳ��ռ�ʱ�õ������Ա�������ͬ��   
          FMutexHandle:=Windows.CreateMutex(nil,False,PChar(FMapName+'.Mtx'));   
          if   FMutexHandle=0   then   
              raise   Exception.Create('�����������ʧ��');   
          FIsMapOpen:=True;   
          if   FExistsAlready   then   //�ж��ڴ��ļ�ӳ���Ƿ��Ѵ�   
              ReadMap   
          else   
              WriteMap;   
      end;   
  end;   
    
  //����ļ���ͼ���ڴ�ӳ��ռ�Ĺ�ϵ�����ر��ļ�ӳ��   
  procedure   TFileMap.CloseMap;   
  begin   
      if   FIsMapOpen   then   
      begin   
          //�ͷŻ������   
          if   FMutexHandle<>0   then   
          begin   
              CloseHandle(FMutexHandle);   
              FMutexHandle:=0;   
          end;   
          //�ر��ڴ����   
          if   FMapPointer<>nil   then   
          begin   
          //����ļ���ͼ���ڴ�ӳ��ռ�Ĺ�ϵ   
              UnMapViewOfFile(FMapPointer);   
              FMapPointer:=nil;   
          end;   
          if   FMapHandle<>0   then   
          begin   
          //���ر��ļ�ӳ��   
              CloseHandle(FMapHandle);   
              FMapHandle:=0;   
          end;   
          FIsMapOpen:=False;   
      end;   
  end;   
    
  //��ȡ�ڴ��ļ�ӳ������   
  procedure   TFileMap.ReadMap;   
  begin   
      FReading:=True;   
      if(FMapPointer<>nil)   then   FMapStrings.SetText(FMapPointer);   
  end;   
    
  //���ڴ�ӳ���ļ���д   
  procedure   TFileMap.WriteMap;   
  var   
      StringsPointer:PChar;   
      HandleCounter:integer;   
      SendToHandle:HWnd;   
  begin   
      if   FMapPointer<>nil   then   
      begin   
          StringsPointer:=FMapStrings.GetText;   
          //���뻥��״̬����ֹ�����߳̽���ͬ���������   
          EnterCriticalSection;   
          if   StrLen(StringsPointer)+1<=FSize   
              then   System.Move(StringsPointer^,FMapPointer^,StrLen(StringsPointer)+1)   
          else   
              raise   Exception.Create('д�ַ���ʧ�ܣ��ַ���̫��');   
          //�뿪����״̬   
          LeaveCriticalSection;   
          //�㲥��Ϣ����ʾ�ڴ�ӳ���ļ������Ѿ��޸�   
          SendMessage(HWND_BROADCAST,FMessageID,FFormHandle,0);   
          //�ͷ�StringsPointer   
          StrDispose(StringsPointer);   
      end;   
  end;   
    
  //��MapStringsֵ�ı�ʱ   
  procedure   TFileMap.MapStringsChange(Sender:TObject);   
  begin   
      if   FReading   and   Assigned(FOnChange)   then   
          FOnChange(Self)   
      else   if   (not   FReading)   and   FIsMapOpen   and   FAutoSynch   then   
          WriteMap;   
  end;   
    
  //����MapName����ֵ   
  procedure   TFileMap.SetMapName(Value:string);   
  begin   
      if   (FMapName<>Value)   and   (FMapHandle=0)   and   (Length(Value)<246)   then   
      begin   
          FMapName:=Value;   
          FSynchMessage:=FMapName+'Synch-Now';   
      end;   
  end;   
    
  //����MapStrings����ֵ   
  procedure   TFileMap.SetMapStrings(Value:TStringList);   
  begin   
      if   Value.Text<>FMapStrings.Text   then   
      begin   
          if   Length(Value.Text)<=FSize   then   
              FMapStrings.Assign(Value)   
          else   
              raise   Exception.Create('д��ֵ̫��');   
      end;   
  end;   
    
  //�����ڴ��ļ���С   
  procedure   TFileMap.SetSize(Value:DWord);   
  var   
      StringsPointer:PChar;   
  begin   
      if   (FSize<>Value)   and   (FMapHandle=0)   then   
      begin   
          StringsPointer:=FMapStrings.GetText;   
          if   (Value<StrLen(StringsPointer)+1)   then   
              FSize:=StrLen(StringsPointer)+1   
          else   FSize:=Value;   
          if   FSize<32   then   FSize:=32;   
          StrDispose(StringsPointer);   
      end;   
  end;   
    
  //�����Ƿ�ͬ��   
  procedure   TFileMap.SetAutoSynch(Value:Boolean);   
  begin   
      if   FAutoSynch<>Value   then   
      begin   
          FAutoSynch:=Value;   
          if   FAutoSynch   and   FIsMapOpen   then   WriteMap;   
      end;   
  end;   
    
  //���뻥�⣬ʹ�ñ�ͬ���Ĵ��벻�ܱ�����̷߳���   
  procedure   TFileMap.EnterCriticalSection;   
  begin   
      if     (FMutexHandle<>0)   and   not   FLocked   then   
      begin   
          FLocked:=(WaitForSingleObject(FMutexHandle,INFINITE)=WAIT_OBJECT_0);   
      end;   
  end;   
    
  //��������ϵ�����Խ��뱣����ͬ��������   
  procedure   TFileMap.LeaveCriticalSection;   
  begin   
      if   (FMutexHandle<>0)   and   FLocked   then   
      begin   
          ReleaseMutex(FMutexHandle);   
          FLocked:=False;   
      end;   
  end;   

  //��Ϣ�������   
  procedure   TFileMap.NewWndProc(var   FMessage:TMessage);   
  begin   
      with   FMessage   do   
      begin   
          if   FIsMapOpen   then     //�ڴ��ļ���   
          {�����Ϣ��FMessageID,��WParam����FFormHandle���͵���   
            ReadMapȥ��ȡ�ڴ�ӳ���ļ������ݣ���ʾ�ڴ�ӳ���ļ���   
            �����ѱ�}   
              if   (Msg=FMessageID)   and   (WParam<>FFormHandle)   then   
                  ReadMap;   
          Result:=CallWindowProc(FPOldWndHandler,FFormHandle,Msg,wParam,lParam);   
      end;   
  end;   
    
  end.   

