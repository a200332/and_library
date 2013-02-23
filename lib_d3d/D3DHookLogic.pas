unit D3DHookLogic;

interface
uses  Windows, SysUtils, Direct3D8, D3DX8, Classes, D3DHook;

procedure StartView;
procedure ViewText (Device: IDirect3DDevice8);
procedure StopView;

var
  TrigerTime: DWORD = 0;
  IsViewText: BOOL = False;
  D3DPrintMSG: TStringList;

implementation

uses
  D3DX81ab, CmdHandler;

var
  m_Font: ID3DXFont;
  IsInit: BOOL = false;
  hFort: THandle;
  LogFont: TLogFontA;
  TextRect: TRect;
  PrintStr: String;

var
  StartTime: DWORD = 0;
  LastHandleTime: DWORD = 0;


procedure StartView;
begin
  if IsInit then
    m_Font.OnResetDevice;
end;

procedure StopView;
begin
  if IsInit then
    m_Font.OnLostDevice;
end;

var
  D3DXCreateFont : function (pDevice: IDirect3DDevice8; hFont: HFONT; out ppFont: ID3DXFont): HResult; stdcall;

procedure ViewText (Device: IDirect3DDevice8);
var
  TmpTime, Hour, Min, Second: DWORD;
  pViewport: TD3DViewport8;
begin
    if not IsInit then
    begin
      LogFont.lfHeight := 14;              {����߶�}
      LogFont.lfWidth:= 0;                 {����ƽ�����}
      LogFont.lfEscapement:= 0;            {�Ƕ�, ��λ�� 1/10 ��}
      LogFont.lfOrientation:= 0;           {���߽Ƕ�}
      LogFont.lfWeight:= 0;                {����, ȡֵ: 0-1000}
      LogFont.lfItalic:= 0;                {б��}
      LogFont.lfUnderline:= 0;                    {�»���}
      LogFont.lfStrikeOut:= 0;                    {ɾ����}
      LogFont.lfCharSet:= GB2312_CHARSET;         {�ַ���}
      LogFont.lfOutPrecision:= OUT_CHARACTER_PRECIS; {�������}
      LogFont.lfClipPrecision:= 0;                {���þ���}
      LogFont.lfQuality:= ANTIALIASED_QUALITY;    {�������}
      LogFont.lfPitchAndFamily:= 0;               {��༰����}
      LogFont.lfFaceName:= '����';                {��������}
      hFort := CreateFontIndirect (LogFont);

      D3DXCreateFont := D3DX81abDLL.FindExport ('D3DXCreateFont');
      D3DXCreateFont(Device, hFort, m_Font);
      IsInit := True;
      StartTime := GetTickCount;

      D3DPrintMSG:= TStringList.Create;
    end;
    
    if (TrigerTime > 0) and (TrigerTime > StartTime) then
    begin
      if LastHandleTime <> TrigerTime then
      begin
        LastHandleTime := TrigerTime;
        TmpTime := TrigerTime - StartTime;
        Hour := TmpTime div 3600000;
        Min :=  (TmpTime mod 3600000) div 60000;
        Second := TmpTime mod 60000 div 1000;
        PrintStr := Format ('�������� %dСʱ %d���� %d��', [Hour, Min, Second]);
        if D3DPrintMSG.Count > 0 then
          PrintStr := PrintStr + #13#10 + D3DPrintMSG.Text;

        Device.GetViewport(pViewport);
        TextRect := Rect(10,pViewport.Height div 3,100,100);
      end;

      if IsViewText then
      begin
        m_Font._Begin;
        m_Font.DrawTextA(PChar(PrintStr),Length(PrintStr),TextRect,DT_LEFT or DT_NOCLIP, D3DCOLOR_RGBA($7f, $7f, $7f, $7f));
        m_Font._End;
      end;

    end;
end;


end.
