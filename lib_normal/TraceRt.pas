unit TraceRt;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, winsock2;

procedure TraceRouter (SelfIP, RemoteIP: String);

implementation

const
  PACKET_SIZE     = 32;
  MAX_PACKET_SIZE = 512;
  TRACE_PORT      = 34567;
  LOCAL_PORT      = 5555;

type
  s32     = Integer;
  u32     = DWORD;
  u8      = Byte;
  u16     = word;       PU16 = ^U16;

  //
  //IP Packet Header
  //
  PIPHeader = ^YIPHeader;
  YIPHeader = record
    u8verlen    : u8;//4bits ver, 4bits len, len*4=true length
    u8tos       : u8;//type of service, 3bits ����Ȩ(�����Ѿ�������), 4bits TOS, ���ֻ����1bitΪ1
    u16totallen : u16;//����IP���ݱ��ĳ��ȣ����ֽ�Ϊ��λ��
    u16id       : u16;//��ʶ�������͵�ÿһ�����ݱ���
    u16offset   : u16;//3bits ��־��13bitsƬƫ��
    u8ttl       : u8;//����ʱ���ֶ����������ݱ����Ծ��������·��������
    u8protol    : u8;//Э�����ͣ�6��ʾ�������TCPЭ�顣
    u16checksum : u16;//�ײ�����͡�
    u32srcaddr  : u32;//ԴIP��ַ�����ǡ�xxx.xxx.xxx.xxx��������Ŷ
    u32destaddr : u32;//Ŀ��IP��ַ��ͬ��
  end;

  //
  //ICMP Packet Header
  //
  PICMPHeader = ^YICMPHeader;
  YICMPHeader = record
    u8type      : u8;
    u8code      : u8;
    u16chksum   : u16;
    u16id       : u16;
    u16seq      : u16;
  end;

function DecodeIcmpReply( pbuf: PChar; var seq: s32 ): string;
var
  pIpHdr   : PChar;
  pIcmphdr : PICMPHeader;
  sip      : string;
  ttl      : integer;
begin
  pIpHdr := pbuf;
  sip := inet_ntoa( TInAddr( PIPHeader(pIpHdr)^.u32srcaddr ) );
  ttl := PIPHeader(pIpHdr)^.u8ttl;

  Inc( pIpHdr, (PIPHeader(pIpHdr)^.u8verlen and $0F) * 4 );
  pIcmpHdr := PICMPHeader(pIpHdr);

  result := '';
  if pIcmpHdr^.u8type = 3 then  //Ŀ�Ĳ��ɴ���Ϣ��Trace���
     seq := 0;
  if pIcmpHdr^.u8type = 11 then  //��ʱ��Ϣ������Trace
     result := Format( '%4d%32s%8d', [seq, sip, ttl] );
end;

procedure ErrMsg( msg: string );
begin
  MessageBox( 0, PChar(msg), 'Ping Program Error', MB_ICONERROR );
end;

procedure InitialWinSocket;
var
  wsa : TWSAData;
begin
  if WSAStartup( $0202, wsa ) <> 0 then
     ErrMsg( 'Windows socket is not responed.' );
end;

procedure FinallyWinSocket;
begin
  if WSACleanup <> 0 then
     ErrMsg( 'Windows socket can not be closed.' );
end;

procedure TraceRouter (SelfIP, RemoteIP: String);
const
  SIO_RCVALL = IOC_IN or IOC_VENDOR or 1;
var
  rawsock  : TSocket;
  pRecvBuf : PChar;
  FromAdr  : TSockAddr;
  FromLen  : s32;
  fd_read  : TFDSet;
  timev    : TTimeVal;
  sReply   : string;
  udpsock  : TSocket;
  ret      : s32;
  DestAdr  : TSockAddr;
  pSendBuf : PChar;
  ttl, opt : s32;
  pHost    : PHostEnt;
begin
  //����һ��RAWSOCK���ջ�ӦICMP��
  rawsock := socket( AF_INET, SOCK_RAW, IPPROTO_ICMP );

  FromAdr.sin_family := AF_INET;
  FromAdr.sin_port := htons(0);
  FromAdr.sin_addr.S_addr := inet_addr(PChar(SelfIP));  //�������IP

  //�����bind���޷����հ���~~~��Ϊ���滹Ҫ����һ��UDPSOCK
  bind( rawsock, @FromAdr, SizeOf(FromAdr) );

  Opt := 1;
  WSAIoctl( rawsock, SIO_RCVALL, @Opt, SizeOf(Opt), nil, 0, @ret, nil, nil );

  //����ICMP��Ӧ���Ļ�����
  pRecvBuf := AllocMem( MAX_PACKET_SIZE );

  //����һ��UDPSOCK����̽���
  udpsock := socket( AF_INET, SOCK_DGRAM, IPPROTO_UDP );

  //Ҫ���͵�UDP����
  pSendBuf := AllocMem( PACKET_SIZE );
  FillChar( pSendBuf^, PACKET_SIZE, 'C' );

  FillChar( DestAdr, sizeof(DestAdr), 0 );
  DestAdr.sin_family := AF_INET;
  DestAdr.sin_port := htons( TRACE_PORT );
  DestAdr.sin_addr.S_addr := inet_addr( PChar(RemoteIP) );

  //���edit1.text����IP��ַ�����Խ�������
  if DestAdr.sin_addr.S_addr = INADDR_NONE then
  begin
    pHost := gethostbyname( PChar(RemoteIP) );
    if pHost <> nil then
    begin
      move( pHost^.h_addr^^, DestAdr.sin_addr, pHost^.h_length );
      DestAdr.sin_family := pHost^.h_addrtype;
      DestAdr.sin_port := htons( TRACE_PORT );
      OutputDebugString(PChar( RemoteIP +'IP��ַ->'+ inet_ntoa(DestAdr.sin_addr) ));
    end else
    begin
      OutputDebugString(PChar( '��������: ' + RemoteIP + '����' ));
      closesocket( rawsock );
      closesocket(udpsock);
      FreeMem( pSendBuf );
      FreeMem( pRecvBuf );
      exit;
    end;
  end;

  OutputDebugString(PChar( 'Trace route ' + RemoteIP + '......' ));

  //��ʼTrace!!!
  ttl := 1;
  while True do
  begin
    //����TTL��ʹ���Ƿ��͵�UDP����TTL�����ۼ�
    setsockopt( udpsock, IPPROTO_IP, IP_TTL, @ttl, sizeof(ttl) );
    //����UDP����HOST
    sendto( udpsock, pSendBuf^, PACKET_SIZE, 0, DestAdr, sizeof(DestAdr) );

    FD_ZERO( fd_read );
    FD_SET( rawsock, fd_read );
    timev.tv_sec  := 5;
    timev.tv_usec := 0;

    if select( 0, @fd_read, nil, nil, @timev ) < 1 then
       break;

    if FD_ISSET( rawsock, fd_read ) then
    begin
      FillChar( pRecvBuf^, MAX_PACKET_SIZE, 0 );
      FillChar( FromAdr, sizeof(FromAdr), 0 );
      FromAdr.sin_family := AF_INET;
      FromLen := sizeof( FromAdr );
      recvfrom( rawsock, pRecvBuf^, MAX_PACKET_SIZE, 0, FromAdr, FromLen );

      sReply := DecodeIcmpReply( pRecvBuf, ttl );
      if sReply <> '' then
      begin
        OutputDebugString(PChar( sReply ));
      end;
      if ttl = 0 then //����յ�Ŀ����������Ӧ����DecodeIcmpReply���ttl==0
         break;
    end;

    Inc( ttl );
    Sleep( 110 );
  end; //while not bStop do

  OutputDebugString( '׷��·����ɡ�' );
  OutputDebugString( ' ' );

  closesocket( rawsock );
  closesocket(udpsock);
  FreeMem( pSendBuf );
  FreeMem( pRecvBuf );
end;

end.


