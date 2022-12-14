unit Unit1;

{$DEFINE USESAFEMASK}

{$DEFINE WIPEONSTART} // Uncomment to wipe Python on start
// {$DEFINE PYTHON37} // Pick only one - default = 3.10
// {$DEFINE PYTHON38} // Pick only one - default = 3.10
 {$DEFINE PYTHON39} // Pick only one - default = 3.10

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Rtti, System.Generics.Collections, System.TypInfo,
  System.Threading, System.IOUtils, Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo.Types,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,
  PythonEngine, PyCommon, PyModule, PyEnvironment,
  PyPackage, PyEnvironment.Embeddable,
  PyEnvironment.Embeddable.Res,
  {$IF DEFINED(PYTHON37)}
  PyEnvironment.Embeddable.Res.Python37,
  {$ELSEIF DEFINED(PYTHON38)}
  PyEnvironment.Embeddable.Res.Python38,
  {$ELSEIF DEFINED(PYTHON39)}
  PyEnvironment.Embeddable.Res.Python39,
  {$ELSE}
  PyEnvironment.Embeddable.Res.Python310,
  {$ENDIF}
  Boto3,
  H5Py,
  Keras,
  Matplotlib,
  MoviePy,
  NLTK,
  NumPy,
  ONNXRuntime,
  OpenCV,
  OpenCVContrib,
  Pandas,
  Pillow,
  PSUtil,
  PyQT5,
  PyTorch,
  TorchVision,
  RemBG,
  ScikitLearn,
  SciPy,
  TensorFlow,
  FMX.PythonGUIInputOutput, FMX.StdCtrls;

type
  TPyClasses = TArray<TPyManagedPackage>;

  TP4DClass = record
    FName: String;
    FClass: TObject;
  end;

  TForm1 = class(TForm)
    mmLog: TMemo;
    Panel1: TPanel;
    btnTest: TButton;
    btnPython: TButton;
    procedure FormCreate(Sender: TObject);
    procedure PackageBeforeInstall(Sender: TObject);
    procedure PackageAfterInstall(Sender: TObject);
    procedure PackageInstallError(Sender: TObject; AException: Exception; var AAbort: Boolean);
    procedure PackageAfterImport(Sender: TObject);
    procedure PackageBeforeImport(Sender: TObject);
    procedure PackageBeforeUnInstall(Sender: TObject);
    procedure PackageAfterUnInstall(Sender: TObject);
    procedure PackageUnInstallError(Sender: TObject; AException: Exception; var AAbort: Boolean);
    procedure PackageAddExtraUrl(APackage: TPyManagedPackage; const AUrl: string);
    procedure btnTestClick(Sender: TObject);
    procedure btnPythonClick(Sender: TObject);
  private
    { Private declarations }
    FTask: ITask;
    Code: TStringlist;
    PyComps: TArray<TPyManagedPackage>;

    PyIO: TPythonGUIInputOutput;
    PyEng: TPythonEngine;
    {$IF DEFINED(PYTHON37)}
    PyEmbed: TPyEmbeddedResEnvironment37;
    {$ELSEIF DEFINED(PYTHON38)}
    PyEmbed: TPyEmbeddedResEnvironment38;
    {$ELSEIF DEFINED(PYTHON39)}
    PyEmbed: TPyEmbeddedResEnvironment39;
    {$ELSE}
    PyEmbed: TPyEmbeddedResEnvironment310;
    {$ENDIF}

    function ModuleAsVariant(const I: Integer): Variant;
    procedure Log(const AMsg: String);
    procedure SetupPackage(APackage: TPyManagedPackage);
    procedure SetupSystem;
    procedure ThreadedSetup;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  FPUMASK: TArithmeticExceptionMask;

const
  {$IF DEFINED(PYTHON37)}
  pyver = '3.7';
  {$ELSEIF DEFINED(PYTHON38)}
  pyver = '3.8';
  {$ELSEIF DEFINED(PYTHON39)}
  pyver = '3.9';
  {$ELSE}
  pyver = '3.10';
  {$ENDIF}
  pypath = 'python';
  appname = 'PythonSink';

function EscapeBackslashForPython(const AStr: String): String;
procedure SafeMaskFPUExceptions(ExceptionsMasked : boolean;
  MatchPythonPrecision : Boolean = True);

implementation

{$R *.fmx}
uses
  PyPackage.Manager.Pip,
  PyPackage.Manager.Defs.Pip;

function EscapeBackslashForPython(const AStr: String): String;
begin
  Result := StringReplace(AStr, '\', '\\', [rfIgnoreCase, rfReplaceAll]);
end;

procedure SafeMaskFPUExceptions(ExceptionsMasked : boolean;
  MatchPythonPrecision : Boolean);
begin
  {$IFDEF USESAFEMASK}
  {$IF Defined(CPUX86) or Defined(CPUX64)}
  if ExceptionsMasked then
    begin
    FPUMASK := GetExceptionMask;
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
      exOverflow, exUnderflow, exPrecision]);
    end
  else
    SetExceptionMask(FPUMASK);
  {$WARN SYMBOL_PLATFORM OFF}
  {$IF Defined(FPC) or Defined(MSWINDOWS)}
  if MatchPythonPrecision then
      SetPrecisionMode(pmDouble)
    else
      SetPrecisionMode(pmExtended);
  {$WARN SYMBOL_PLATFORM ON}
  {$IFEND}
  {$IFEND}
  {$ELSE}
    MaskFPUExceptions(ExceptionsMasked, MatchPythonPrecision);
  {$IFEND}
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  btnTest.Enabled := False;
  btnPython.Enabled := False;
  PyComps := [
              TPyManagedPackage(TBoto3),
              TPyManagedPackage(TH5Py),
              TPyManagedPackage(TKeras),
              TPyManagedPackage(TMatplotlib),
              TPyManagedPackage(TMoviePy),
              TPyManagedPackage(TNLTK),
              TPyManagedPackage(TNumPy),
              TPyManagedPackage(TONNXRuntime),
              TPyManagedPackage(TOpenCV),
              TPyManagedPackage(TOpenCVContrib),
              TPyManagedPackage(TPandas),
              TPyManagedPackage(TPillow),
              TPyManagedPackage(TPSUtil),
              TPyManagedPackage(TPyQT5),
              TPyManagedPackage(TPyTorch),
              TPyManagedPackage(TTorchVision),
              TPyManagedPackage(TRemBG),
              TPyManagedPackage(TScikitLearn),
              TPyManagedPackage(TSciPy)
//              TPyManagedPackage(TTensorFlow) Skip TF
              ];

  mmLog.Lines.Add('Module Count = ' + IntToStr(Length(PyComps)));
  SetupSystem;

end;

procedure TForm1.Log(const AMsg: String);
begin
  if TThread.CurrentThread.ThreadID <> MainThreadID then
    TThread.Synchronize(nil,
      procedure()
      begin
        mmLog.Lines.Add('* ' + AMsg);
        mmLog.GoToTextEnd;
        mmLog.Repaint;
        Application.ProcessMessages;
      end
      )
  else
    begin
      mmLog.Lines.Add(AMsg);
      mmLog.GoToTextEnd;
      mmLog.Repaint;
      Application.ProcessMessages;
    end;
end;

procedure TForm1.PackageAddExtraUrl(APackage: TPyManagedPackage; const AUrl: string);
var
  popts: TPyPackageManagerDefsPip;
begin
  popts := TPyPackageManagerDefsPip(APackage.Managers.Pip);
  popts.InstallOptions.ExtraIndexUrl := AUrl;
end;

procedure TForm1.PackageBeforeInstall(Sender: TObject);
begin
  Log('Installing ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageAfterInstall(Sender: TObject);
begin
  Log('Installed ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageInstallError(Sender: TObject; AException: Exception; var AAbort: Boolean);
begin
  Log('Error for ' + TPyPackage(Sender).PyModuleName + ' : ' + AException.Message);
end;

procedure TForm1.PackageBeforeUnInstall(Sender: TObject);
begin
  Log('UnInstalling ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageAfterUnInstall(Sender: TObject);
begin
  Log('UnInstalled ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageUnInstallError(Sender: TObject; AException: Exception; var AAbort: Boolean);
begin
  Log('Error for ' + TPyPackage(Sender).PyModuleName + ' : ' + AException.Message);
end;

procedure TForm1.PackageBeforeImport(Sender: TObject);
begin
  Log('Importing ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.PackageAfterImport(Sender: TObject);
begin
  Log('Imported ' + TPyPackage(Sender).PyModuleName);
end;

procedure TForm1.SetupPackage(APackage: TPyManagedPackage);
begin
  APackage.PythonEngine := PyEng;
  APackage.PyEnvironment := PyEmbed;

  APackage.AutoImport := False;
  APackage.AutoInstall := False;

  APackage.BeforeInstall := PackageBeforeInstall;
  APackage.AfterInstall := PackageAfterInstall;
  APackage.OnInstallError := PackageInstallError;
  APackage.BeforeImport := PackageBeforeImport;
  APackage.AfterImport := PackageAfterImport;
  APackage.BeforeUnInstall := PackageBeforeUnInstall;
  APackage.AfterUnInstall := PackageAfterUnInstall;
  APackage.OnUnInstallError := PackageUnInstallError;
end;

procedure TForm1.SetupSystem;
var
  I: Integer;
  HomePath: String;
begin
  // MacOSX with X64 CPU
  {$IF DEFINED(MACOS64) AND DEFINED(CPUX64)}
{
  HomePath := IncludeTrailingPathDelimiter(
              IncludeTrailingPathDelimiter(
              System.IOUtils.TPath.GetLibraryPath) +
              appname) +
              pypath;
}
  HomePath := pypath;
  // MacOSX with ARM64 CPU (M1 etc)
  {$ELSEIF DEFINED(MACOS64) AND DEFINED(CPUARM64)}
{
  HomePath := IncludeTrailingPathDelimiter(
              IncludeTrailingPathDelimiter(
              System.IOUtils.TPath.GetLibraryPath) +
              appname) +
              pypath;
 }
  HomePath := pypath;
  // Windows X64 CPU
  {$ELSEIF DEFINED(WIN64)}
  HomePath := IncludeTrailingPathDelimiter(
              IncludeTrailingPathDelimiter(
              System.IOUtils.TPath.GetHomePath) +
              appname) +
              pypath;
  // Windows 32 bit
  {$ELSEIF DEFINED(WIN32)}
  HomePath := IncludeTrailingPathDelimiter(
              IncludeTrailingPathDelimiter(
              System.IOUtils.TPath.GetHomePath) +
              appname  + '-32')+
              pypath;
  // Linux X64 CPU
  {$ELSEIF DEFINED(LINUX64)}
  HomePath := IncludeTrailingPathDelimiter(
              IncludeTrailingPathDelimiter(
              System.IOUtils.TPath.GetHomePath) +
              appname) +
              pypath;
  // Android (64 CPU)Not presently working)
  {$ELSEIF DEFINED(ANDROID)}
  HomePath := IncludeTrailingPathDelimiter(
              IncludeTrailingPathDelimiter(
              System.IOUtils.TPath.GetHomePath) +
              appname) +
              pypath;
  {$ELSE}
  raise Exception.Create('Need to set HomePath for this build');
  {$ENDIF}

  {$IFDEF WIPEONSTART}
  if DirectoryExists(IncludeTrailingPathDelimiter(HomePath) + pyver) then
    TDirectory.Delete(IncludeTrailingPathDelimiter(HomePath) + pyver, True);
  {$ENDIF}

  PyIO  := TPythonGUIInputOutput.Create(Self);
  PyIO.Output := mmLog;
  PyEng := TPythonEngine.Create(Self);
  PyEng.AutoLoad := False;
  PyEng.IO := PyIO;
  PyEng.RedirectIO := True;
  {$IF DEFINED(PYTHON37)}
  PyEmbed := TPyEmbeddedResEnvironment37.Create(Self);
  {$ELSEIF DEFINED(PYTHON38)}
  PyEmbed := TPyEmbeddedResEnvironment38.Create(Self);
  {$ELSEIF DEFINED(PYTHON39)}
  PyEmbed := TPyEmbeddedResEnvironment39.Create(Self);
  {$ELSE}
  PyEmbed := TPyEmbeddedResEnvironment310.Create(Self);
  {$ENDIF}
  PyEmbed.PythonEngine := PyEng;
  PyEmbed.PythonVersion := pyver;
//  PyEmbed.EnvironmentPath := HomePath;

  for I := 0 to Length(PyComps) - 1 do
    begin
      case I of
         0: PyComps[I] := TBoto3.Create(Self);
         1: PyComps[I] := TH5Py.Create(Self);
         2: PyComps[I] := TKeras.Create(Self);
         3: PyComps[I] := TMatplotlib.Create(Self);
         4: PyComps[I] := TMoviePy.Create(Self);
         5: PyComps[I] := TNLTK.Create(Self);
         6: PyComps[I] := TNumPy.Create(Self);
         7: PyComps[I] := TONNXRuntime.Create(Self);
         8: PyComps[I] := TOpenCV.Create(Self);
         9: PyComps[I] := TOpenCVContrib.Create(Self);
        10: PyComps[I] := TPandas.Create(Self);
        11: PyComps[I] := TPillow.Create(Self);
        12: PyComps[I] := TPSUtil.Create(Self);
        13: PyComps[I] := TPyQT5.Create(Self);
        14: PyComps[I] := TPyTorch.Create(Self);
        15: PyComps[I] := TTorchVision.Create(Self);
        16: PyComps[I] := TRemBG.Create(Self);
        17: PyComps[I] := TScikitLearn.Create(Self);
        18: PyComps[I] := TSciPy.Create(Self);
        19: PyComps[I] := TTensorFlow.Create(Self);
      end;
      SetupPackage(PyComps[I]);
      Log('Created ' + PyComps[I].ClassName);
    end;

{ Skip this bit for testing
//  PackageAddExtraUrl(Torch, 'https://download.pytorch.org/whl/cu116');
}

  Log('Python path = ' + PyEmbed.EnvironmentPath);
  //  Call Setup
  FTask := TTask.Run(ThreadedSetup);

end;

procedure TForm1.ThreadedSetup;
begin
    try
      PyEmbed.Setup(PyEmbed.PythonVersion);
      FTask.CheckCanceled();

      TThread.Synchronize(nil, procedure() begin
        var act: Boolean := PyEmbed.Activate(PyEmbed.PythonVersion);
        if act then
          begin
            Log('Python Activated');

            TThread.Queue(nil, procedure() begin
              try
                var I: Integer;
                for I := 0 to Length(PyComps) - 1 do
                  begin
                    SafeMaskFPUExceptions(True);
                    PyComps[I].Install();
                    SafeMaskFPUExceptions(False);
                    FTask.CheckCanceled();
                  end;
              except
                on E: Exception do begin
                  TThread.Synchronize(nil, procedure() begin
                    Log('Unhandled Exception');
                    Log('Class : ' + E.ClassName);
                    Log('Error : ' + E.Message);
                  end);
                end;
              end;
            end);

            TThread.Queue(nil, procedure() begin
              try
                try
                  var I: Integer;
                  for I := 0 to Length(PyComps) - 1 do
                    begin
                      SafeMaskFPUExceptions(True);
                      PyComps[I].Import();
                      SafeMaskFPUExceptions(False);
                    end;
                except
                  on E: Exception do begin
                    TThread.Synchronize(nil, procedure() begin
                      Log('Unhandled Exception');
                      Log('Class : ' + E.ClassName);
                      Log('Error : ' + E.Message);
                    end);
                  end;
                end;
              finally
                btnTest.Enabled := True;
                btnPython.Enabled := True;
              end;
              Log('All done!');
            end);

          end
        else
          Log('Python Activation failed');
      end);
      FTask.CheckCanceled();
    except
      on E: Exception do begin
        TThread.Synchronize(nil, procedure() begin
          Log('Unhandled Exception');
          Log('Class : ' + E.ClassName);
          Log('Error : ' + E.Message);
        end);
      end;
    end;
end;

function TForm1.ModuleAsVariant(const I: Integer): Variant;
begin
      case I of
         0: Result := TBoto3(PyComps[I]).boto3;
         1: Result := TH5Py(PyComps[I]).h5py;
         2: Result := TKeras(PyComps[I]).keras;
         3: Result := TMatplotlib(PyComps[I]).matplot;
         4: Result := TMoviePy(PyComps[I]).moviepy;
         5: Result := TNLTK(PyComps[I]).nltk;
         6: Result := TNumPy(PyComps[I]).np;
         7: Result := TONNXRuntime(PyComps[I]).onnx;
         8: Result := TOpenCV(PyComps[I]).cv2;
         9: Result := TOpenCVContrib(PyComps[I]).cv2;
        10: Result := TPandas(PyComps[I]).pandas;
        11: Result := TPillow(PyComps[I]).PIL;
        12: Result := TPSUtil(PyComps[I]).psutil;
        13: Result := TPyQT5(PyComps[I]).qt5;
        14: Result := TPyTorch(PyComps[I]).torch;
        15: Result := TTorchVision(PyComps[I]).torchvision;
        16: Result := TRemBG(PyComps[I]).rembg;
        17: Result := TScikitLearn(PyComps[I]).sklearn;
        18: Result := TSciPy(PyComps[I]).scipy;
        19: Result := TTensorFlow(PyComps[I]).tf;
      end;
end;

procedure TForm1.btnPythonClick(Sender: TObject);
var
  Shim: TStringList;
  HomePath: String;
begin
  HomePath := GetCurrentDir;
  Shim := Nil;
  try
    Shim := TStringList.Create;
    Shim.Add('import os');
    Shim.Add('import sys');
    Shim.Add('for p in sys.path:');
    Shim.Add('    print(p)');
    Shim.Add('__embedded_python__ = True');

    SafeMaskFPUExceptions(True);
    PyEng.ExecStrings(Shim);
    SafeMaskFPUExceptions(False);
  finally
    if not(Shim = Nil) then
      Shim.Free;
  end;
end;

procedure TForm1.btnTestClick(Sender: TObject);
var
  I: Integer;
  GoodImports: Integer;
  version: Variant;
begin
  GoodImports := 0;
  mmLog.Lines.Clear;
  for I := 0 to Length(PyComps) - 1 do
    begin
      if PyComps[I].IsImported then
        begin
          try
            SafeMaskFPUExceptions(True);
            version := ModuleAsVariant(I).__version__;
            SafeMaskFPUExceptions(False);
          except
            version := 'NO VERSION AVAILABLE';
          end;
          Log(PyComps[I].PyModuleName + ' imported OK as version ' + version);
          Inc(GoodImports);
        end
      else
          Log(PyComps[I].PyModuleName + ' FAILED TO IMPORT');
    end;
    Log(GoodImports.ToString + ' out of ' + Length(PyComps).ToString + ' succesful imports');
    Log('Not all modules are for import so imported may be less than total');
end;

end.
