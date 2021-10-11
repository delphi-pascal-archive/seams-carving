unit UMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ExtDlgs, ComCtrls, Jpeg, Spin;

type
  TFrmDemoMain = class(TForm)
    Panel1: TPanel;
    btnDoOpenBMP: TButton;
    GroupBox1: TGroupBox;
    Panel2: TPanel;
    Splitter1: TSplitter;
    ScrollBox1: TScrollBox;
    imgOriginal: TImage;
    ScrollBox2: TScrollBox;
    imgResized: TImage;
    OpenPictureDialog1: TOpenPictureDialog;
    Button1: TButton;
    GroupBox2: TGroupBox;
    Label1: TLabel;
    ERadius: TEdit;
    Label2: TLabel;
    ETheta: TEdit;
    GroupBox3: TGroupBox;
    Label3: TLabel;
    Label4: TLabel;
    Button2: TButton;
    SaveDialog1: TSaveDialog;
    EHeight: TSpinEdit;
    EWidth: TSpinEdit;
    ComboBox1: TComboBox;
    procedure btnDoOpenBMPClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  FrmDemoMain: TFrmDemoMain;

implementation

uses USeamCarving;

{$R *.dfm}

var
  aBmp: TBitmap;

procedure TFrmDemoMain.btnDoOpenBMPClick(Sender: TObject);
var
 name:string;
 jpg:tjpegimage;
begin
  if not OpenPictureDialog1.Execute then exit;
  name:=OpenPictureDialog1.FileName;

  if lowercase(extractfileext(name))='.bmp' then
    imgOriginal.Picture.Bitmap.LoadFromFile(Name);
  if lowercase(extractfileext(name))='.jpg' then
   begin
    jpg:=tjpegimage.Create;
    jpg.LoadFromFile(name);

    imgOriginal.Picture.Bitmap.Assign(jpg);
    jpg.Free;
   end;
end;

procedure TFrmDemoMain.Button1Click(Sender: TObject);
var
 theta:single;
 radius:integer;
 l,h:integer;
 cw,ch:integer;
begin
 if not trystrtoint(ERadius.Text,radius) then exit;
 if not trystrtoFloat(ETheta.Text,theta) then exit;

 if not trystrtoint(EWidth.Text,cw) then exit;
 if not trystrtoint(EHeight.Text,ch) then exit;
 imgResized.Canvas.FillRect(imgResized.ClientRect);
 SeamCarving(imgOriginal.Picture.Bitmap,imgResized.Picture.Bitmap,radius,theta,cw,ch,ComboBox1.ItemIndex);
 imgResized.Invalidate;
end;

procedure TFrmDemoMain.Button2Click(Sender: TObject);
var
 name:string;
 jpg:tjpegimage;
begin
  if not SaveDialog1.Execute then exit;
  name:=SaveDialog1.FileName;

  if lowercase(extractfileext(name))='.bmp' then
    imgResized.Picture.Bitmap.SaveToFile(Name);
  if lowercase(extractfileext(name))='.jpg' then
   begin
    jpg:=tjpegimage.Create;
    jpg.Assign(imgResized.Picture.Bitmap);
    jpg.SaveToFile(name);
    jpg.Free;
   end;
end;

procedure TFrmDemoMain.ComboBox1Change(Sender: TObject);
begin
 Button1Click(nil);
end;

end.
