program SeamsCarving;

uses
  Forms,
  UMain in 'UMain.pas' {FrmDemoMain},
  USeamCarving in 'USeamCarving.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFrmDemoMain, FrmDemoMain);
  Application.Run;
end.
