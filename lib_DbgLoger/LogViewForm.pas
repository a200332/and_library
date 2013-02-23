unit LogViewForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, ComCtrls, Menus;

type
  TForm4 = class(TForm)
    ListBox1: TListBox;
    Memo1: TMemo;
    Splitter1: TSplitter;
    Panel1: TPanel;
    StatusBar1: TStatusBar;
    DateTimePicker1: TDateTimePicker;
    DateTimePicker2: TDateTimePicker;
    Splitter2: TSplitter;
    Panel2: TPanel;
    Panel3: TPanel;
    ComboBox1: TComboBox;
    Panel4: TPanel;
    Panel5: TPanel;
    Panel6: TPanel;
    Panel7: TPanel;
    Panel8: TPanel;
    Panel9: TPanel;
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    N71: TMenuItem;
    N31: TMenuItem;
    N11: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    N4: TMenuItem;
    Email1: TMenuItem;
    N5: TMenuItem;
    N151: TMenuItem;
    N6: TMenuItem;
    DbgLogerDLLdll1: TMenuItem;
    N7: TMenuItem;
    ViewTime: TMenuItem;
    ViewProcess: TMenuItem;
    ViewProcessID: TMenuItem;
    ViewModule: TMenuItem;
    SaveDialog1: TSaveDialog;
    DateTimePicker3: TDateTimePicker;
    DateTimePicker4: TDateTimePicker;
    procedure DbgLogerDLLdll1Click(Sender: TObject);
    procedure N4Click(Sender: TObject);
    procedure N2Click(Sender: TObject);
    procedure N11Click(Sender: TObject);
    procedure N31Click(Sender: TObject);
    procedure N71Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure N151Click(Sender: TObject);
    procedure ViewTimeClick(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure Panel7DblClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    DaysOfAutoClear: Integer;
    procedure ConfigureToUi;
    procedure UiToConfigure;
  end;

var
  Form4: TForm4;

implementation

{$R *.dfm}

uses DateUtils, LogDatabaseUnit;

procedure TForm4.ComboBox1Change(Sender: TObject);
var
  ItemIndex: integer;
  FromTime: TDateTime;
  LogTypeSL: TStringList;
begin
  FromTime := Now;
  ItemIndex := ComboBox1.ItemIndex;
  case ItemIndex of
  0: FromTime := IncDay (FromTime, -1);  //1��
  1: FromTime := IncDay (FromTime, -3);  //3��
  2: FromTime := IncDay (FromTime, -7);  //7��
  3: FromTime := 0;  //N��
  Else Exit;
  end;

  LogTypeSL := GetActiveType (FromTime);
  LogTypeSL.Insert(0, 'AnyType');
  ListBox1.Items := LogTypeSL;
  LogTypeSL.Free;
end;


procedure TForm4.UiToConfigure;
begin
  SetConfigure (ViewTime.Checked,ViewProcess.Checked,ViewProcessID.Checked,ViewModule.Checked,DaysOfAutoClear);
  self.N151.Caption := '�Զ����'+IntToStr(DaysOfAutoClear)+'��ǰ����־';
end;


procedure TForm4.ConfigureToUi;
var
  IsViewTime,IsViewProcess,IsViewProcessID,IsViewModule: BOOL;
begin
  GetConfigure (IsViewTime,IsViewProcess,IsViewProcessID,IsViewModule,DaysOfAutoClear);
  ViewTime.Checked := IsViewTime;
  ViewProcess.Checked := IsViewProcess;
  ViewProcessID.Checked := IsViewProcessID;
  ViewModule.Checked := IsViewModule;
  self.N151.Caption := '�Զ����'+IntToStr(DaysOfAutoClear)+'��ǰ����־';
end;


procedure TForm4.DbgLogerDLLdll1Click(Sender: TObject);
var
  MsgSL: TStringList;
begin
  MsgSL := TStringList.Create;
  MsgSL.Add('��1������log.dll����ĳ���Ŀ¼�¡�');
  MsgSL.Add('');
  MsgSL.Add('��2����������2���������������');
  MsgSL.Add(#9'Procedure LOG (LogType: PChar; LogText: PChar; LogMode: Integer); Stdcall;');
  MsgSL.Add(#9'Function LogFile (LogType: PChar; FormTime, ToTime: TDateTime; OutFile: PChar): BOOL; Stdcall;');
  MsgSL.Add('');
  MsgSL.Add('��3��LogModeѡ���¼ģʽ��');
  MsgSL.Add(#9'LOG_REAL_MODE = 0;'#9'//ֱ��д�����ݿ⣬�ʺ���־���Ƚ��ٵ��������Ϊ���ݿ���������ƿ����');
  MsgSL.Add(#9'LOG_PROXY_MODE = 1;'#9'//ʹ����־�ػ�����DbgLoger.exe��������д����־�����ܽϺ�');
  MsgSL.Add(#9'LOG_CACHE_PROXY_MODE = 2;'#9'//��LOG_PROXY_MODE����������һ���������');
  MsgSL.Add(#9'LOG_SYNC_REAL_MODE = 3;'#9#9'//��LOG_REAL_MODE�����������첽�������¿��ػ��߳�д�����ݿ�');
  MsgSL.Add(#9'LOG_SYNC_PROXY_MODE = 4;'#9'//��LOG_PROXY_MODE�����������첽����������õ�ģʽ���Ƽ�');

  ShowMessage (MsgSL.Text);

  MsgSL.Free;
end;

procedure TForm4.N151Click(Sender: TObject);
var
  DaysOfAutoClearStr: String;
  GetValue: Integer;
begin
  DaysOfAutoClearStr := InputBox ('�����Զ������־ʱ��', '������һ�����֣���λΪ�죺', '15');
  if TryStrToInt (DaysOfAutoClearStr, GetValue) then
  begin
    DaysOfAutoClear := GetValue;
    UiToConfigure;
  end;
end;

Procedure DeleteHistoryReocrd (DaysBefore: Integer);
var
  ToTime: TDateTime;
begin
  ToTime := Now;
  IncDay (ToTime, -DaysBefore);
  DeleteHistory (ToTime);
end;

procedure TForm4.N11Click(Sender: TObject);
begin
  DeleteHistoryReocrd (1);
end;

procedure TForm4.N2Click(Sender: TObject);
begin
  DeleteHistory (Now);
end;


procedure TForm4.N31Click(Sender: TObject);
begin
  DeleteHistoryReocrd (3);
end;

procedure TForm4.N4Click(Sender: TObject);
begin
  self.SaveDialog1.DefaultExt := 'LOG';
  self.SaveDialog1.Title := '����дҪ������ļ�����';
  self.SaveDialog1.Filter := '��־�ļ�(*.LOG)|*.LOG';

  if Memo1.Lines.Count > 0 then
    if self.SaveDialog1.Execute then
      Memo1.Lines.SaveToFile(self.SaveDialog1.FileName);
end;

procedure TForm4.N71Click(Sender: TObject);
begin
  DeleteHistoryReocrd (7);
end;

procedure TForm4.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  UiToConfigure;
end;

procedure TForm4.FormShow(Sender: TObject);
var
  IniFrom, IniTo: TDateTime;
begin
  IniTo := NOW;
  IniFrom := IncHour (IniTo, -1);

  self.StatusBar1.SimplePanel := True;
  self.DateTimePicker1.DateTime := DateOf (IniFrom);
  self.DateTimePicker3.DateTime := TimeOf (IniFrom);

  self.DateTimePicker2.DateTime := DateOf (IniTo);
  self.DateTimePicker4.DateTime := TimeOf (IniTo);
  self.ComboBox1.ItemIndex := 1;
  self.ComboBox1Change(nil);
  ConfigureToUi;
end;

procedure TForm4.ListBox1Click(Sender: TObject);
var
  index: integer;
  LogType: String;
  FromTime, ToTime: TDateTime;
  LogTextSL: TStringList;
  PrintTypes: TPrintTypes;
begin
  Memo1.Clear;
  self.StatusBar1.SimpleText := '';

  Index := self.ListBox1.ItemIndex;
  if Index = -1 then Exit;
  LogType := self.ListBox1.Items[Index];

  if LogType = 'AnyType' then
    self.StatusBar1.SimpleText := '������ʾ���������ڸ�ʱ��ε���־����������'
  else
    self.StatusBar1.SimpleText := '������ʾ����'+LogType+'���͵���־';

  PrintTypes := [];
  if ViewTime.Checked then
    Include (PrintTypes, ptTime);   
  if ViewProcess.Checked then
    Include (PrintTypes, ptProcess);
  if ViewProcessID.Checked then
    Include (PrintTypes, ptProcessID);
  if ViewModule.Checked then
    Include (PrintTypes, ptModule);

  FromTime := DateOf(self.DateTimePicker1.DateTime) + TimeOf(self.DateTimePicker3.DateTime);
  ToTime := DateOf(self.DateTimePicker2.DateTime) + TimeOf(self.DateTimePicker4.DateTime);

  LogTextSL := LogPrinter (LogType, FromTime, ToTime, PrintTypes);     
  Memo1.Lines := LogTextSL;
  LogTextSL.Free;
end;


procedure TForm4.Panel7DblClick(Sender: TObject);
begin
  self.DateTimePicker2.DateTime := NOW;
  self.DateTimePicker4.DateTime := NOW;
end;

procedure TForm4.ViewTimeClick(Sender: TObject);
var
  MenuItem: TMenuItem absolute Sender;
begin
  MenuItem.Checked := not MenuItem.Checked;
end;

end.
