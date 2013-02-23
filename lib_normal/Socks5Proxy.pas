unit Socks5Proxy; 
{ 
Write By Wenjinshan. 
} 
interface 

uses 
  Windows, SysUtils, Classes, ExtCtrls, ScktComp, Forms, 
  StdCtrls,winsock ,MYNMUDP,math; 


const 
  //MAXurl=255; 
  VER=#5;
  IsServer=$40000000; 
  DefaultPort=1080; 
  StartPort=4000; 
  
type 
  PCharArray = ^TCharArray; 
  TCharArray = array[0..32767] of Char; 

  session_record=record 
    Valid:boolean; //�Ƿ���Ч 
    Close:boolean; 
    step:integer;//���Ӳ��� 

    UdpClient:TMYNMUDP; //�ͻ���udp 
    UdpSite:TMYNMUDP; //��վ��udp 

    TcpSite:TClientSocket; //��վ��tcp 
    TcpClient:TCustomWinSocket; //�ͻ���tcp 

    ListenServer:TServerSocket; //Listen�ķ����� 
    ListenOneThread:TCustomWinSocket; 

    LastError:integer; 
  end;

  TSocks5Proxy = class 
  private 
    ServerSocket1: TServerSocket; 
    TimerRefresh: TTimer;
    NMUDP1: TMYNMUDP; 
    FPort: Integer; 
    Fuser: String; 
    Fpass: String; 
    
    function GetSock5Host(buf:pchar;var p:integer):string; 
    procedure DataReceived(Sender: TComponent; NumberBytes: Integer; FromIP: String; Port: Integer);
    procedure FindMyPort(udp:TMYNMUDP;MyIP:string;var Start_Port:integer); 

    procedure ServerSocket1ClientConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure ServerSocket1ClientDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure ServerSocket1ClientError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure ServerSocket1ClientRead(Sender: TObject; Socket: TCustomWinSocket);

    procedure ClientSocket1Connect(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientSocket1Disconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientSocket1Error(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure ClientSocket1Read(Sender: TObject; Socket: TCustomWinSocket);

    procedure TimerRefreshTimer(Sender: TObject);
    procedure NMUDP1DataReceived(Sender: TComponent; NumberBytes: Integer; FromIP: String; Port: Integer);
    procedure ListenServerClientConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure ListenServerClientDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure ListenServerClientError(Sender: TObject;  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure ListenServerClientRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure SetPort(const Value: Integer); 
    procedure SetUser(const Value: String); 
    procedure SetPass(const Value: String); 
    { Private declarations } 
  public 
    constructor Create;
    destructor Destroy; override; 
    procedure StopServer;
    procedure StartServer; 

    property User: String read FUser write SetUser; 
    property Pass: String read FPass write SetPass; 
    property Port: Integer read FPort write SetPort; 
  end; 

var 
    session:array of session_record; 
    LastPort:integer;  //���һ��ʹ�õĶ˿� 
implementation

function WordToS(w:word):string; 
begin 
  setlength(result,sizeof(word)); 
  pword(@result[1])^:=w; 
end; 

function LongWordToS(w:Longword):string; 
begin 
  setlength(result,sizeof(Longword)); 
  pLongword(@result[1])^:=w; 
end; 

function CharToAIISC(buf:pchar;len:integer):string;//���ַ�ȫ��ʮ�����Ƶ�"xx "����ʽ��ʾ���� 
var 
  i:integer; 
begin 
  result:=''; 
  for i:=0 to len-1 do 
  begin 
    result:=result+format('%2.2X ',[ord(Buf[i])]); 
  end; 
end; 

function CharToString(Buf:pchar;length:integer):string;//charת���string 
var 
  s:string; 
begin 
  setlength(s,length); 
  move(Buf[0],s[1],length); //������strcopy 
  result:=s; 
end; 

procedure TSocks5Proxy.DataReceived(Sender: TComponent; 
  NumberBytes: Integer; FromIP: String; Port: Integer); 
var 
  buf:array[0..3]of char; 
begin 
  if NumberBytes <>sizeof(buf) then exit; 
  (Sender as TMYNMUDP).ReadBuffer(buf, NumberBytes); 
  if pinteger(@buf)^=Port then (Sender as TMYNMUDP).tag:=1; //��Ч�� 
end; 

procedure TSocks5Proxy.FindMyPort(udp:TMYNMUDP;MyIP:string;var Start_Port:integer); 
var 
  buf:array[0..3]of char; 
  t:dword; 
begin 
      {��������������Ч��udp�˿�} 
      udp.Tag:=0; //��Ч�� 
      udp.RemoteHost:= MyIP; //�Լ������Լ� 
      udp.OnDataReceived:=DataReceived; 

      udp.LocalPort:=4000; 
      udp.RemotePort:=udp.LocalPort; 
      pinteger(@buf)^:=udp.LocalPort; 
      udp.SendBuffer(buf,sizeof(buf)); 
      t:=gettickcount; 
      while (udp.tag=0)and(gettickcount-t <50)do 
        application.ProcessMessages; 

      while udp.tag=0 do //�˿ڲ��Ϸ����ı�˿��ٷ� 
      begin 
        udp.LocalPort:=Start_Port; 
        inc(Start_Port); 
        if Start_Port=MAXWORD then Start_Port:=StartPort; 
        udp.RemotePort:=udp.LocalPort; 
        pinteger(@buf)^:=udp.LocalPort; 
        udp.SendBuffer(buf,sizeof(buf)); 
        t:=gettickcount; 
        while (udp.tag=0)and(gettickcount-t <50)do 
            application.ProcessMessages; 
      end; 
end; 

function TSocks5Proxy.GetSock5Host(buf:pchar;var p:integer):string; 
var 
  s:string; 
  ip:longword; 
begin 
  result:=''; 
  case buf[p] of 
  #1:begin 
        ip:=Plongword(@buf[p+1])^; 
        if ip <>0 then 
            result:=string(inet_ntoa(Tinaddr(ip))); 
        inc(p,5); 
      end; 
  #3:begin 
        setlength(s,ord(buf[p+1])); 
        move(buf[p+2],s[1],ord(buf[p+1])); 
        result:=s;  //GetIP(s); 
        inc(p,ord(buf[p+1])+2); 
      end; 
  end; 
end; 


constructor TSocks5Proxy.Create; 
  procedure InitProxyServer; 
  begin 
    with ServerSocket1 do 
    begin 
      OnClientConnect := ServerSocket1ClientConnect; 
      OnClientDisconnect := ServerSocket1ClientDisconnect; 
      OnClientRead := ServerSocket1ClientRead; 
      OnClientError :=ServerSocket1ClientError 
    end; 
  end; 

  procedure InitLookupTimer; 
  begin 
    with TimerRefresh do 
    begin 
      Interval := 200; 
      Enabled := False; 
      OnTimer := TimerRefreshTimer; 
    end; 
  end; 
begin 
  LastPort:=StartPort;//���һ��ʹ�õ�udp�˿�,����Ϊ����ֵ 
  ServerSocket1 := TServerSocket.Create(nil); 
  InitProxyServer; 
  TimerRefresh := TTimer.Create(nil); 
  InitLookupTimer; 
  NMUDP1:= TMYNMUDP.Create(nil); 
end;

destructor TSocks5Proxy.Destroy; 
begin 
  TimerRefresh.Free; 
  ServerSocket1.Free; 
  NMUDP1.Free; 
  inherited; 
end; 

procedure TSocks5Proxy.StopServer; 
begin 
  TimerRefresh.Enabled := False; 
  ServerSocket1.Active := False; 
end; 

procedure TSocks5Proxy.StartServer; 
begin 
try 
  ServerSocket1.Port := FPort; 
  ServerSocket1.Active := True; 
except 
end; 
end; 

procedure TSocks5Proxy.SetPort(const Value: Integer); 
begin 
  if not ServerSocket1.Active then 
  begin 
    FPort := Value; 
  end; 
end; 

procedure TSocks5Proxy.SetUser(const Value: String); 
begin 
    FUser := Value; 
end; 

procedure TSocks5Proxy.SetPass(const Value: String); 
begin 
    FPass := Value; 
end; 

procedure TSocks5Proxy.ServerSocket1ClientConnect(Sender: TObject; 
  Socket: TCustomWinSocket); 
var 
  i,j:integer; 
begin 
  j:=-1; 
  //�ӿͻ��ˣ��������������վ�˹�ϵ��¼��������һ�����߼�¼ 
  for i:=0 to length(session)-1 do 
  begin 
      if (not session[i].Valid)then 
      begin 
        j:=i; 
        session[j].Valid:=true; 
        session[j].close:=false; 
        break;//�ҵ����˳� 
      end; 
  end; 
  if j=-1 then //���û���ҵ����߼�¼���½�һ����¼ 
  begin 
      j:=length(session); 
      setlength(session,j+1); //�������ü�¼���� 
      session[j].Valid:=true; 
      session[j].close:=false; 
  end; 
//  session[j].ClientS:=socket; //�ͻ��˿� 
  socket.Data:=pointer(j);    //�Ựָ�� 
  session[j].step:=0;//��0�� 
  session[j].UdpSite:=nil; 
  session[j].UdpClient:=nil; 
  session[j].TcpSite:=nil; 
  session[j].TcpClient:=nil; 
  session[j].ListenServer:=nil; 
end; 

procedure TSocks5Proxy.ServerSocket1ClientDisconnect(Sender: TObject; 
  Socket: TCustomWinSocket); 
var 
  i:integer; 
begin 
  i:=integer(Socket.data); 
  session[i].TcpClient:=nil; 
  session[i].close:=true; 
  if session[i].ListenServer <>nil then 
      if session[i].ListenServer.Active then 
        session[i].ListenServer.Active:=false; 
  TimerRefresh.Enabled:=true; 
end; 

procedure TSocks5Proxy.ServerSocket1ClientError(Sender: TObject; 
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; 
  var ErrorCode: Integer); 
begin 
  errorcode:=0; 
  if Socket.Connected then Socket.close; 
  ServerSocket1ClientDisconnect(Sender,Socket); 
end; 

procedure wait(ticks:dword); 
var 
  t:dword; 
begin 
  t:=gettickcount; 
  while gettickcount-t <ticks do application.ProcessMessages; 
end;

{�ͻ�����Ϣ����ʱ} 
procedure TSocks5Proxy.ServerSocket1ClientRead(Sender: TObject; 
  Socket: TCustomWinSocket); 
const 
  MaxBuf=10240; 
var 
  i,p,ReceiveBufLength:integer; 
  sendtext:string; 
  ReceiveBuf:array[0..MaxBuf-1]of char; 
  siteHost:string;          
  IP:string; 
  user,pass:string; 
begin 
  i:=integer(Socket.data);//�Ựָ�� 
  ReceiveBufLength:=min(MaxBuf,socket.ReceiveLength); 
  socket.ReceiveBuf(ReceiveBuf, ReceiveBufLength); 

  if (session[i].step=0) then 
  begin 
      if (plongword(@ReceiveBuf)^ and $00FFFFFF = $00000105)or 
        (plongword(@ReceiveBuf)^ and $00FFFFFF = $00000205) then //�ͻ���ѯ�ʴ�����Ƿ�������������� 
      begin 
        //���߿ͻ��˿������� 
        if Fuser='' then 
        begin 
            sendtext:=VER+#0; 
            inc(session[i].step,2); 
            Socket.SendText(sendtext) ; 
        end; 
        {���� 
        >> '00' ����֤���� 
      ��>> '01' ͨ�ð�ȫ����Ӧ�ó���ӿ�(GSSAPI) 
    ����>> '02' �û���/����(USERNAME/PASSWORD) 
    ����>> '03' �� X'7F' IANA ����(IANA ASSIGNED) 
    ����>> '80' �� X'FE' ˽�˷�������(RESERVED FOR PRIVATE METHODS) 
      ��>> 'FF' �޿ɽ��ܷ���(NO ACCEPTABLE METHODS) } 
      end 
      else if (plongword(@ReceiveBuf)^ and $00FFFFFF = $00020105)or 
              (plongword(@ReceiveBuf)^ and $00FFFFFF = $00020205) then //�ͻ���ѯ�ʴ�����Ƿ�������������� 
      begin 
        if Fuser <>'' then 
        begin    //������ 
            sendtext:=VER+#2; 
            inc(session[i].step); 
            Socket.SendText(sendtext) ; 
        end; 
      end; 
  end 
  else if (session[i].step=1) then 
  begin 
      if(ReceiveBufLength <3)then exit; 
      if(ReceiveBuf[0]=#1)then 
      begin 
        p:=1; 
        setlength(user,ord(ReceiveBuf[p])); 
        move(ReceiveBuf[p+1],user[1],ord(ReceiveBuf[p])); 
        inc(p, ord(ReceiveBuf[p])+1); 

        setlength(pass,ord(ReceiveBuf[p])); 
        move(ReceiveBuf[p+1],pass[1],ord(ReceiveBuf[p])); 
        if(user=Fuser)and(pass=Fpass)then 
        begin 
            inc(session[i].step); 
            Socket.SendText(#1#0); 
        end 
        else begin 
            session[i].step:=0; 
            Socket.SendText(#1#$2); 
        end; 
      end; 
  end 
  else if (session[i].step=2) then 
  begin 
      if(ReceiveBufLength <4)then exit; 
      case plongword(@ReceiveBuf)^ and $00FFFFFF of 
      $00000305: 
      begin //�ͻ��˰��Լ���udp�˿ڸ��ߴ���� 
        p:=3; 
        siteHost:=GetSock5Host(@ReceiveBuf,p); 
        if siteHost='' then 
        begin 
            session[i].udpClient:=TMYNMUDP.Create(nil); //����һ���µ�udp�������Ժ����ӿͻ� 
            FindMyPort(session[i].udpClient,ServerSocket1.Socket.LocalHost,Lastport); 
            session[i].udpClient.Tag:=i; //�Ựָ��,��ʾ�ͻ� 
            session[i].udpClient.OnDataReceived:=NMUDP1DataReceived; 
            session[i].udpClient.RemotePort:= ntohs( pword(@ReceiveBuf[p])^ ); 
            session[i].udpClient.RemoteHost:= string(inet_ntoa(Socket.RemoteAddr.sin_addr)); 
            inc(p,2); 

            session[i].udpSite:=TMYNMUDP.Create(nil); //����һ���µ�udp�������Ժ�������վ 
            FindMyPort(session[i].udpSite,ServerSocket1.Socket.LocalHost,Lastport); 
            session[i].udpSite.Tag:=i or IsServer; //�Ựָ  ��,IsServer��ʾ��վ 
            session[i].udpSite.OnDataReceived:=NMUDP1DataReceived; 

            setlength(IP,4); 
            plongword(@IP[1])^:=inet_addr(pchar(socket.LocalAddress)); 
            sendtext:=VER+#0#0#1+ IP + WordToS(htons(session[i].udpClient.LocalPort));//sock5�������Ķ˿�,htons�ߵ�λ���� 
            inc(session[i].step); 
            Socket.SendText(sendtext); 
        end; 
      end; 
      $00000105: 
      begin //�ͻ��˰��Լ���connect�˿ڸ��ߴ���� 
        p:=3; 
        siteHost:=GetSock5Host(@ReceiveBuf,p); 
        if siteHost <>'' then 
        begin 
//            session[i].ConnectOrListen:=true; //�ͻ���Connect 
            session[i].TcpClient:=socket; 
            session[i].TcpSite:=TClientSocket.Create(nil); 
            session[i].TcpSite.Host:=siteHost; 
            session[i].TcpSite.Port:=ntohs( pword(@ReceiveBuf[p])^ );  //Ҫconnect�Ķ˿�, ntohs�ߵ�λ���� 
            inc(p,2); 
            session[i].TcpSite.Tag:=i; 
            session[i].TcpSite.OnError:=ClientSocket1Error; 
            session[i].TcpSite.OnDisconnect:=ClientSocket1Disconnect; 
            session[i].TcpSite.OnRead:=ClientSocket1Read; 
            session[i].LastError:=0; 
            try 
              session[i].TcpSite.Active:=true; 
            except 
            end; 
            while(session[i].LastError=0)and(session[i].TcpSite <>nil)and(not session[i].TcpSite.Active) do 
                application.ProcessMessages; 
            if session[i].TcpSite=nil then exit; 
            inc(session[i].step); 
            if not session[i].TcpSite.Active then 
            begin 
              socket.SendText(VER+chr(session[i].LastError)); 
            end 
            else socket.SendText(VER+#0#0#1+ LongwordToS(inet_addr(pchar(socket.LocalAddress))) + WordToS(htons(socket.LocalPort))); 
//            caption:=inttostr(socket.LocalPort); 
        end; 
      end; 
      $00000205: 
      begin //�ͻ��˰��Լ���Listen�˿ڸ��ߴ���� 
        p:=3; 
        siteHost:=GetSock5Host(@ReceiveBuf,p); 
//        if siteHost <>'' then 
        begin 
//            session[i].ConnectOrListen:=true; //�ͻ���Connect 
            session[i].TcpClient:=socket; 
            session[i].ListenServer:=TServerSocket.Create(nil); 
            session[i].ListenServer.OnClientConnect:=ListenServerClientConnect; 
            session[i].ListenServer.OnClientDisconnect:=ListenServerClientDisconnect; 
            session[i].ListenServer.OnClientError:=ListenServerClientError; 
            session[i].ListenServer.OnClientRead:=ListenServerClientRead; 

            session[i].ListenServer.Port:=ntohs( pword(@ReceiveBuf[p])^ ); 
            try 
              session[i].ListenServer.Active:=true; 
            except 
            end; 
            if not session[i].ListenServer.Active then 
            for p:=0 to 10000 do 
            begin 
              session[i].ListenServer.Port:=LastPort; 
              inc(LastPort); 
              if LastPort=MAXWORD then LastPort:=StartPort; 
              try 
                  session[i].ListenServer.Active:=true; 
                  break; 
              except 
              end; 
            end; 
            session[i].ListenServer.Socket.Data:=pointer(i); 
            inc(session[i].step); 
            socket.SendText(VER+#0#0#1+ LongwordToS(inet_addr(pchar(socket.LocalAddress))) + WordToS(htons(session[i].ListenServer.Port))); 
        end; 
      end; 
      end; 
  end 
  else if (session[i].step=3) then 
  begin 
      if (session[i].TcpSite <>nil)then 
      begin 
        if (session[i].TcpSite.Active) then 
        begin 
            while (not session[i].close)and(session[i].TcpSite.Socket.SendBuf(ReceiveBuf,ReceiveBufLength)=-1) do 
              sleep(100);        
        end 
        else socket.Close; 
      end 
      else if (session[i].ListenOneThread <>nil)then 
      begin 
        if session[i].ListenOneThread.Connected then 
        begin 
            while (not session[i].close)and(session[i].ListenOneThread.SendBuf(ReceiveBuf,ReceiveBufLength)=-1) do 
              sleep(100); 
        end; 
      end; 
  end; 
end;

procedure TSocks5Proxy.ClientSocket1Connect(Sender: TObject; 
  Socket: TCustomWinSocket); 
begin 
// 
end; 

procedure TSocks5Proxy.ClientSocket1Disconnect(Sender: TObject; 
  Socket: TCustomWinSocket); 
var 
  i:integer; 
begin 
  i:=(sender as TClientsocket).tag; 
  session[i].close:=true; 
  if session[i].LastError=0 then 
      session[i].LastError:=-1; 
  TimerRefresh.Enabled:=true; 
end; 

procedure TSocks5Proxy.ClientSocket1Error(Sender: TObject; 
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; 
  var ErrorCode: Integer); 
begin 
  session[(Sender as TClientSocket).tag].LastError:=ErrorCode; 
  errorcode:=0; 
  if Socket.Connected then Socket.close; 
  ClientSocket1Disconnect(Sender,Socket); 
end; 

procedure TSocks5Proxy.ClientSocket1Read(Sender: TObject; 
  Socket: TCustomWinSocket); 
var 
  i:integer; 
  Rectext:string; 
begin 
  i:=(sender as TClientsocket).tag; 
  if session[i].close then exit; 
  Rectext:=socket.ReceiveText; 
  if session[i].TcpClient.Connected then 
      while (not session[i].close)and(session[i].TcpClient.SendText(Rectext)=-1)do //�������� 
        sleep(100); 
end; 

procedure TSocks5Proxy.TimerRefreshTimer(Sender: TObject); 
var 
  i:integer; 
begin 
  TimerRefresh.Enabled:=false; 
  for i:=length(Session)-1 downto 0 do 
  begin 
      if session[i].close then 
      begin 
        if (session[i].TcpClient <>nil) then 
        begin 
            if (session[i].TcpClient.Connected) then 
              session[i].TcpClient.Close; 
            //����free 
            session[i].TcpClient:=nil; 
        end; 
        if (session[i].TcpSite <>nil) then 
        begin 
            if (session[i].TcpSite.Active) then 
              session[i].TcpSite.Close; 
            session[i].TcpSite.free; 
            session[i].TcpSite:=nil; 
        end; 
        if session[i].UdpSite <>nil then 
        begin 
            session[i].UdpSite.Free;//�ͷ�udp�˿� 
            session[i].UdpSite:=nil; 
        end; 
        if session[i].UdpClient <>nil then 
        begin 
            session[i].UdpClient.Free;//�ͷ�udp�˿� 
            session[i].UdpClient:=nil; 
        end; 
        if (session[i].ListenServer <>nil) then 
        begin 
            if session[i].ListenServer.Active then 
                session[i].ListenServer.Active:=false; 
            session[i].ListenServer:=nil; 
        end; 
        session[i].Valid:=false; 
      end; 
  end; 
end; 

procedure TSocks5Proxy.NMUDP1DataReceived(Sender: TComponent; 
  NumberBytes: Integer; FromIP: String; Port: Integer); 
type 
  TCharArray1024=array[0..2048] of char; 
  PCharArray1024=^TCharArray1024; 
var 
    p,i:integer; 
    siteHost:string; 
    buffer:array[0..2048] of char; 
//    s:string; 
begin 
    i:=(Sender as TMYNMUDP).Tag and (not IsServer); //������� 
    NumberBytes:=min(sizeof(buffer),NumberBytes); 
    if ((Sender as TMYNMUDP).Tag and IsServer) <>0 then 
    begin //��ʾ������վ�������� 
      (Sender as TMYNMUDP).ReadBuffer(PCharArray1024(@buffer[10])^, NumberBytes); 
      plongword(@buffer)^:=$01000000; 
      pdword(@buffer[4])^ := inet_addr(pchar(FromIP)); 
      pword(@buffer[8])^:= htons(Port); 
      if session[i].UdpClient <>nil then 
          session[i].UdpClient.SendBuffer(buffer,NumberBytes+10); 
    end 
    else begin //��ʾ�ͻ��������� 
      if (NumberBytes>=4)then 
      begin 
          session[i].udpClient.RemotePort:=Port;      
          (Sender as TMYNMUDP).ReadBuffer(buffer, NumberBytes); 
          if(session[i].UdpSite <>nil) and (pdword(@buffer)^ and $00ffffff=$00000000)then //��IP v4��ʽ��IP��ַ������ 
          begin 
            p:=3; 
            siteHost:=GetSock5Host(@Buffer,p); 
            if siteHost <>'' then 
            begin 
                session[i].UdpSite.RemoteHost:= siteHost; 
                session[i].UdpSite.RemotePort:= ntohs( pword(@Buffer[p])^ ); 
                inc(p,2); 
                session[i].UdpSite.SendBuffer(PCharArray1024(@buffer[p])^,NumberBytes- p); 
            end 
          end; 
      end; 
    end; 
end; 

procedure TSocks5Proxy.ListenServerClientConnect(Sender: TObject; 
      Socket: TCustomWinSocket); 
var 
  i:integer; 
begin 
  if (Sender as TServerWinSocket).ActiveConnections>1 then 
  begin 
      Socket.Data:=pointer(-1); 
      Socket.Close; 
      exit; 
  end; 
  i:=integer((Sender as TServerWinSocket).Data); 
  Socket.Data:=pointer(i); 
  session[i].ListenOneThread:=Socket; 
  session[i].TcpClient.SendText(VER+#0#0#1+ LongwordToS(Longword(socket.RemoteAddr.sin_addr)) + WordToS(ntohs(Socket.RemotePort))); 
end; 

procedure TSocks5Proxy.ListenServerClientDisconnect(Sender: TObject; 
      Socket: TCustomWinSocket); 
var 
  i:integer; 
begin 
  i:=integer(Socket.data); 
  if i=-1 then exit; 
  session[i].close:=true; 
//  if session[i].ListenServer.Active then 
//      session[i].ListenServer.Active:=false; 
  TimerRefresh.Enabled:=true; 
end; 

procedure TSocks5Proxy.ListenServerClientError(Sender: TObject; 
      Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; 
      var ErrorCode: Integer); 
begin 
  ErrorCode:=0; 
  ListenServerClientDisconnect(Sender,Socket); 
end; 

procedure TSocks5Proxy.ListenServerClientRead(Sender: TObject; 
      Socket: TCustomWinSocket); 
var 
  i:integer; 
begin 
  i:=integer(Socket.data); 
  if i=-1 then exit; 
  if (not session[i].close)and(session[i].TcpClient <>nil)and(session[i].TcpClient.Connected) then 
  begin 
      while (not session[i].close)and(session[i].TcpClient.SendText(Socket.ReceiveText)=-1)do 
        sleep(100); 
  end; 
end; 

end. 

