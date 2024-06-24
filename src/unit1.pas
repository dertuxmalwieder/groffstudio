unit Unit1;

{
  The contents of this file are subject to the terms of the
  Common Development and Distribution License, Version 1.1 only
  (the "License").  You may not use this file except in compliance
  with the License.

  See the file LICENSE in this distribution for details.
  A copy of the CDDL is also available via the Internet at
  https://spdx.org/licenses/CDDL-1.1.html

  When distributing Covered Code, include this CDDL HEADER in each
  file and include the contents of the LICENSE file from this
  distribution.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls,
  ExtCtrls, Buttons, ExtendedNotebook, SynEdit, fphttpclient, RegExpr, LCLIntf,
  LCLType, IniPropStorage, ComboEx, Process, Helpers, fileinfo,
{$IF DEFINED(WINDOWS)}
  winpeimagereader, opensslsockets,
{$ELSEIF DEFINED(DARWIN)}
  machoreader, ssockets, sslsockets, sslbase, opensslsockets,
{$ELSEIF DEFINED(LINUX)}
  elfreader,
{$ENDIF}
  BuildOutputWindow;

type

  { TMainForm }

  TMainForm = class(TForm)
    btnSaveGroff: TButton;
    btnLoadGroff: TButton;
    btnBuild: TButton;
    btnDownloadGroffWindows: TButton;
    btnSaveSettings: TButton;
    chkKeepPostscriptFile: TCheckBox;
    chkUseGhostscript: TCheckBox;
    chkBoxExtras: TCheckComboBox;
    chkBoxPreprocessors: TCheckComboBox;
    chkUpdateCheckOnStart: TCheckBox;
    chkLogFile: TCheckBox;
    chkAutoSaveBuildSettings: TCheckBox;
    cmbMacro: TComboBox;
    edtGroffInstalledVersion: TEdit;
    edtGroffstudioInstalledVersion: TEdit;
    edtGhostscriptInstalledVersion: TEdit;
    edtOnlineGroffVersionWindows: TEdit;
    ExtendedNotebook1: TExtendedNotebook;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    iniStorage: TIniPropStorage;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    lblGithubRepo: TLabel;
    lblFossilRepo: TLabel;
    lblWebsite: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    lblAboutProductName: TLabel;
    lblTroffCommandNotFound: TLabel;
    Label9: TLabel;
    MainStatusBar: TStatusBar;
    mLicense: TMemo;
    odOpenGroffFile: TOpenDialog;
    rdPdf: TRadioButton;
    rdPs: TRadioButton;
    sdSaveGroffFile: TSaveDialog;
    SynEdit1: TSynEdit;
    tsEdit: TTabSheet;
    tsAbout: TTabSheet;
    tsGroff: TTabSheet;
    tsSettings: TTabSheet;
    procedure btnBuildClick(Sender: TObject);
    procedure btnDownloadGroffWindowsClick(Sender: TObject);
    procedure btnLoadGroffClick(Sender: TObject);
    procedure btnSaveGroffClick(Sender: TObject);
    procedure btnSaveSettingsClick(Sender: TObject);
    procedure chkUseGhostscriptChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure lblFossilRepoClick(Sender: TObject);
    procedure lblGithubRepoClick(Sender: TObject);
    procedure lblWebsiteClick(Sender: TObject);
    procedure SynEdit1Change(Sender: TObject);
{$IFDEF DARWIN}
    procedure GetSocketHandler(Sender: TObject; const UseSSL: Boolean; out AHandler: TSocketHandler);
{$ENDIF}
  private
  var
    currentGroffFilePath: string;
    currentGroffFileName: string;
    unsavedChanges: boolean;
{$IFDEF WINDOWS}
    latestGroffWindowsUrl: String;
{$ENDIF}
    // Settings:
    storeBuildSettings: boolean;
    updateCheck: boolean;
  public

  end;

  TDetectGroffThread = class(TThread)
  private
    procedure UpdateUI;
  protected
    procedure Execute; override;
  end;

var
  MainForm: TMainForm;
  BuildWindow: TBuildStatusWindow;
  hasGroff: boolean;
  hasGhostscript: boolean;
  GroffOutputVersion: string;
  ps2pdfOutput: string;
  GhostscriptOutputVersion: string;

implementation

{$R *.lfm}

procedure TDetectGroffThread.UpdateUI;
begin
  // Try to find groff:
  if pos('GNU', GroffOutputVersion) = 0 then
  begin
    ShowMessage('groffstudio thinks that your installed version of troff is not GNU troff.'
      + LineEnding + 'If this is correct, you are advised to fix this before continuing.'
      + LineEnding +
      'If it is an error, please tell me so I can improve this detection.');
    hasGroff := False;
    MainForm.edtGroffInstalledVersion.Text := 'n/a';
    MainForm.lblTroffCommandNotFound.Visible := True;
  end
  else
  begin
    hasGroff := True;
    MainForm.edtGroffInstalledVersion.Text := GroffOutputVersion;
  end;

  // Try to find ps2pdf:
  if pos('ps2pdf', ps2pdfOutput) = 0 then
  begin
{$IFDEF WINDOWS}
    // ps2pdf is mandatory on Windows.
    ShowMessage('On Windows, for creating PDF files, you need Ghostscript installed.'
    + LineEnding + 'Sadly, groffstudio could not find ps2pdf.bat in your %PATH%, so '
    + 'writing PDF files will not be supported. Please install Ghostscript and make sure '
    + 'that the folder that contains ps2pdf.bat is in your %PATH%.');
    MainForm.rdPdf.Enabled := False;
{$ENDIF}
    hasGhostscript := False;
    MainForm.chkUseGhostscript.Checked := False;
    MainForm.chkUseGhostscript.Enabled := False;
  end
  else
  begin
    hasGhostscript := True;
{$IFDEF WINDOWS}
    MainForm.rdPdf.Enabled := True;
    MainForm.chkUseGhostscript.Checked := True;
{$ENDIF}
    MainForm.chkUseGhostscript.Enabled := True;
  end;

  // Try to find Ghostscript, just for displaying the version:
  if hasGhostscript then
    MainForm.edtGhostscriptInstalledVersion.Text := GhostscriptOutputVersion
  else
    MainForm.edtGhostscriptInstalledVersion.Text := 'n/a';
end;

procedure TDetectGroffThread.Execute;
begin
  FreeOnTerminate := True;

{$IFDEF WINDOWS}
  RunCommand('cmd', ['/c', 'troff --version'], GroffOutputVersion, [], swoHIDE);
  RunCommand('cmd', ['/c', 'gs --version'], GhostscriptOutputVersion, [], swoHIDE);
  RunCommand('cmd', ['/c', 'ps2pdf'], ps2pdfOutput, [], swoHIDE);
{$ELSE}
  RunCommand('/bin/sh', ['-c', 'troff --version'], GroffOutputVersion,
    [], swoHIDE);
  RunCommand('/bin/sh', ['-c', 'gs --version'], GhostscriptOutputVersion,
    [], swoHIDE);
  RunCommand('/bin/sh', ['-c', 'ps2pdf'], ps2pdfOutput, [], swoHIDE);
{$ENDIF}
  Synchronize(@UpdateUI);
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  OnlineVersionsFile: string;
{$IFDEF WINDOWS}
  reGroffVersion: TRegExpr;
{$ENDIF}
  reGroffStudioVersion: TRegExpr;
  FileVerInfo: TFileVersionInfo;
  HasVersionUpdate: integer;
  GroffHelpers: TGroffHelpers;
  ResStream: TResourceStream;
{$IFDEF DARWIN}
  HTTPClient: TFPHttpClient;
{$ENDIF}
begin
  // What's the current running groff version?
  TDetectGroffThread.Create(False);

  // Default file name
  currentGroffFileName := '[unsaved file]';

  // Embed the license
  ResStream := TResourceStream.Create(HInstance, 'LICENSE', RT_RCDATA);
  try
    mLicense.Lines.LoadFromStream(ResStream);
  finally
    ResStream.Free;
  end;

{$IFNDEF WINDOWS}
  // Ghostscript is not optional on Windows.
  // On other platforms, let's use the stored setting.
  chkUseGhostscript.Checked := iniStorage.ReadBoolean('UseGhostscript', False);
{$ENDIF}

  // Restore the settings
  iniStorage.Restore;
  storeBuildSettings := iniStorage.ReadBoolean('AutoSaveBuildSettings', False);
  chkAutoSaveBuildSettings.Checked := storeBuildSettings;

{$IF DEFINED(LINUX) OR DEFINED(BSD)}
  // On platforms which probably use a package manager (currently, Linux and
  // BSDs), the "update check" checkbox is disabled.
  chkUpdateCheckOnStart.Enabled := False;
{$ELSE}
  updateCheck := iniStorage.ReadBoolean('UpdateCheckOnStart', False);
  chkUpdateCheckOnStart.Checked := updateCheck;
{$ENDIF}

  if storeBuildSettings then
  begin
    chkLogFile.Checked := iniStorage.ReadBoolean('BuildLogFile', False);
    cmbMacro.Text := iniStorage.ReadString('BuildChosenMacro', '[ select ]');
    chkBoxPreprocessors.Checked[0] := iniStorage.ReadBoolean('BuildUseChem', False);
    chkBoxPreprocessors.Checked[1] := iniStorage.ReadBoolean('BuildUseEqn', False);
    chkBoxPreprocessors.Checked[2] := iniStorage.ReadBoolean('BuildUseGrn', False);
    chkBoxPreprocessors.Checked[3] := iniStorage.ReadBoolean('BuildUsePic', False);
    chkBoxPreprocessors.Checked[4] := iniStorage.ReadBoolean('BuildUseRefer', False);
    chkBoxPreprocessors.Checked[5] := iniStorage.ReadBoolean('BuildUseTbl', False);
    chkBoxExtras.Checked[0] := iniStorage.ReadBoolean('BuildUseHdtbl', False);
    chkBoxExtras.Checked[1] := iniStorage.ReadBoolean('BuildUsePdfMark', False);
    rdPs.Checked := iniStorage.ReadBoolean('BuildToPostscript', False);
    rdPdf.Checked := iniStorage.ReadBoolean('BuildToPDF', False);
  end;

  // What's the latest available version?
  FileVerInfo := TFileVersionInfo.Create(nil);

  try
    FileVerInfo.ReadFileInfo;
    edtGroffStudioInstalledVersion.Text :=
      FileVerInfo.VersionStrings.Values['FileVersion'];
    lblAboutProductName.Caption :=
      FileVerInfo.VersionStrings.Values['ProductName'] + ' ' +
      FileVerInfo.VersionStrings.Values['FileVersion'];
    MainStatusBar.Panels[2].Text := '';

{$IFDEF WINDOWS}
    if updateCheck then
    begin
      OnlineVersionsFile := TFPCustomHTTPClient.SimpleGet('https://groff.tuxproject.de/updates/versions.txt');

      // 1. groff update check
      reGroffVersion := TRegExpr.Create('groff-win ([\d\.]+) (.*)$');
      reGroffVersion.ModifierM := True;
      if reGroffVersion.Exec(OnlineVersionsFile) then
      begin
        edtOnlineGroffVersionWindows.Text := reGroffVersion.Match[1];
        latestGroffWindowsUrl := reGroffVersion.Match[2];
      end else begin
        edtOnlineGroffVersionWindows.Text := 'error';
        btnDownloadGroffWindows.Enabled := False;
      end;

      // 2. groffstudio update check
      reGroffStudioVersion := TRegExpr.Create('studio-win ([\d\.]+) (.*)$');
      reGroffStudioVersion.ModifierM := True;
      if reGroffStudioVersion.Exec(OnlineVersionsFile) then
      begin
        // Compare the two versions - ours and the online one:
        GroffHelpers.VerStrCompare(reGroffStudioVersion.Match[1], FileVerInfo.VersionStrings.Values['FileVersion'], HasVersionUpdate);
        if HasVersionUpdate > 0 then
          MainStatusBar.Panels[2].Text := 'update ' + reGroffStudioVersion.Match[1] + ' available';
      end;
    end else begin
        edtOnlineGroffVersionWindows.Text := 'n/a';
        btnDownloadGroffWindows.Enabled := False;
    end;
{$ELSE}
    // Non-Windows platforms won't need some of that.
    {$IFDEF DARWIN}
    // What's the latest available version?
    try
      if updateCheck then
      begin
        HTTPClient := TFPHTTPClient.Create(Nil);
        HTTPClient.OnGetSocketHandler := @GetSocketHandler;
        OnlineVersionsFile := HTTPClient.SimpleGet('https://groff.tuxproject.de/updates/versions.txt');

        reGroffStudioVersion := TRegExpr.Create('studio-macos ([\d\.]+) (.*)$');
        reGroffStudioVersion.ModifierM := True;
        if reGroffStudioVersion.Exec(OnlineVersionsFile) then
        begin
          // Compare the two versions - ours and the online one:
          GroffHelpers.VerStrCompare(reGroffStudioVersion.Match[1], FileVerInfo.VersionStrings.Values['FileVersion'], HasVersionUpdate);
          if HasVersionUpdate > 0 then
            MainStatusBar.Panels[2].Text := 'update ' + reGroffStudioVersion.Match[1] + ' available';
        end;
      end else begin
        edtOnlineGroffVersionWindows.Text := 'n/a';
        btnDownloadGroffWindows.Enabled := False;
      end;
    finally
      if updateCheck then HTTPClient.Free;
    end;
    {$ENDIF}
    edtOnlineGroffVersionWindows.Text := 'n/a';
    btnDownloadGroffWindows.Enabled := False;
{$ENDIF}
  finally
    FileVerInfo.Free;
  end;

  // Loaded file display
  MainStatusBar.Panels[0].Text := '';

  // Groff build status
  MainStatusBar.Panels[1].Text := '';
end;

procedure TMainForm.lblFossilRepoClick(Sender: TObject);
begin
  OpenURL('https://code.rosaelefanten.org/groffstudio');
end;

procedure TMainForm.lblGithubRepoClick(Sender: TObject);
begin
  OpenURL('https://github.com/dertuxmalwieder/groffstudio');
end;

procedure TMainForm.lblWebsiteClick(Sender: TObject);
begin
  OpenURL('https://groff.tuxproject.de');
end;

procedure TMainForm.SynEdit1Change(Sender: TObject);
begin
  // Set the "Changed" mark:
  MainStatusBar.Panels[0].Text := '* ' + currentGroffFileName;
  unsavedChanges := True;
end;

procedure TMainForm.btnDownloadGroffWindowsClick(Sender: TObject);
begin
{$IFDEF WINDOWS}
   // On other systems, the button is disabled anyway.
   OpenURL(latestGroffWindowsUrl);
{$ENDIF}
end;

procedure TMainForm.btnBuildClick(Sender: TObject);
var
  buildSuccess: boolean;
  buildOpts: string;
  logFileName: string = '';
  outputFileName: string;
begin
  // Reset status display:
  MainStatusBar.Panels[1].Text := '';

  BuildWindow := TBuildStatusWindow.Create(Application);
  BuildWindow.Show;

  // Build the parameters:
  buildOpts := 'groff';

  // - Macro:
  if LeftStr(cmbMacro.Text, 1) = 'm' then buildOpts := buildOpts + ' -' + cmbMacro.Text;

  // - Enforce UTF-8:
  buildOpts := buildOpts + ' -Kutf8';

  // - Preprocessors:
  if chkBoxPreprocessors.Checked[0] then  buildOpts := buildOpts + ' -chem';
  if chkBoxPreprocessors.Checked[1] then  buildOpts := buildOpts + ' -eqn';
  if chkBoxPreprocessors.Checked[2] then  buildOpts := buildOpts + ' -grn';
  if chkBoxPreprocessors.Checked[3] then  buildOpts := buildOpts + ' -pic';
  if chkBoxPreprocessors.Checked[4] then  buildOpts := buildOpts + ' -refer';
  if chkBoxPreprocessors.Checked[5] then  buildOpts := buildOpts + ' -tbl';

  if chkBoxExtras.Checked[0] then  buildOpts := buildOpts + ' -mhdtbl';

  // - PDF-specifics:
{$IFNDEF WINDOWS}
  // On Windows, we use a two-step program:
  // 1) Output to PostScript,
  // 2) ps2pdf to PDF.
  // This is because there is no pdfroff.exe. Requires Ghostscript.
  if rdPdf.Checked and not chkUseGhostscript.Checked then
  begin
    buildOpts := buildOpts + ' -Tpdf';
    if chkBoxExtras.Checked[1] then buildOpts := buildOpts + ' -mpdfmark';
    outputFileName := currentGroffFilePath + '.pdf';
  end
  else
{$ENDIF}
    outputFileName := currentGroffFilePath + '.ps';

  // - Input file:
  buildOpts := buildOpts + ' ' + currentGroffFilePath;
  buildOpts := buildOpts + ' > ' + outputFileName;

  // - Log file:
  if chkLogFile.Checked then logFileName := currentGroffFilePath + '.log';

  // Build:
  buildSuccess := BuildWindow.BuildDocument(buildOpts, logFileName);

{$IFDEF WINDOWS}
  if buildSuccess and hasGhostscript and rdPdf.Checked then
{$ELSE}
  // On non-Windows systems, Ghostscript is entirely optional.
  if buildSuccess and hasGhostscript and chkUseGhostscript.Checked and rdPdf.Checked then
{$ENDIF}
  begin
    // Invoke ps2pdf:
    buildOpts := 'ps2pdf';
    // outputFileName is still the .ps file. Just use it as the input name.
    buildOpts := buildOpts + ' ' + outputFileName;
    buildSuccess := BuildWindow.BuildDocument(buildOpts, logFileName);

    if buildSuccess and not chkKeepPostscriptFile.Checked then
       DeleteFile(outputFileName); // get rid of the .ps file
  end;

  if buildSuccess then
    MainStatusBar.Panels[1].Text := 'build successful'
  else
    MainStatusBar.Panels[1].Text := 'build problem';

  FreeAndNil(BuildWindow);
end;

procedure TMainForm.btnLoadGroffClick(Sender: TObject);
var
  Reply, BoxStyle: integer;
begin
  // If the current file has unsaved changes, ask first.
  if unsavedChanges then with Application do
    begin
      BoxStyle := MB_ICONQUESTION + MB_YESNO;
      Reply := MessageBox('Do you want to save the document first?',
        'UnsavedChanges', BoxStyle);
      if Reply = idYes then SynEdit1.Lines.SaveToFile(currentGroffFilePath);
      unsavedChanges := False;
    end;

  if odOpenGroffFile.Execute then
  begin
    if FileExists(odOpenGroffFile.FileName) then
    begin
      currentGroffFilePath := odOpenGroffFile.FileName;
      currentGroffFileName := ExtractFileName(odOpenGroffFile.FileName);
      SynEdit1.Lines.LoadFromFile(odOpenGroffFile.FileName);

      if hasGroff then
      begin
        btnBuild.Enabled := True;
        chkLogFile.Enabled := True;
      end;

      // Display the current file:
      MainStatusBar.Panels[0].Text := currentGroffFileName;
    end;
  end;
end;

procedure TMainForm.btnSaveGroffClick(Sender: TObject);
begin
  if FileExists(currentGroffFilePath) then
    // We don't need to open the Save As box every time.
    SynEdit1.Lines.SaveToFile(currentGroffFilePath)
  else if sdSaveGroffFile.Execute then
  begin
    currentGroffFilePath := sdSaveGroffFile.FileName;
    currentGroffFileName := ExtractFileName(currentGroffFilePath);
    SynEdit1.Lines.SaveToFile(sdSaveGroffFile.FileName);

    if hasGroff then
    begin
      btnBuild.Enabled := True;
      chkLogFile.Enabled := True;
    end;
  end;

  // Remove the "Changed" mark:
  MainStatusBar.Panels[0].Text := currentGroffFileName;
  unsavedChanges := False;
end;

procedure TMainForm.btnSaveSettingsClick(Sender: TObject);
begin
  // Store the build settings:
  iniStorage.WriteString('BuildChosenMacro', cmbMacro.Text);
  iniStorage.WriteBoolean('BuildLogFile', chkLogFile.Checked);
  iniStorage.WriteBoolean('BuildUseChem', chkBoxPreprocessors.Checked[0]);
  iniStorage.WriteBoolean('BuildUseEqn', chkBoxPreprocessors.Checked[1]);
  iniStorage.WriteBoolean('BuildUseGrn', chkBoxPreprocessors.Checked[2]);
  iniStorage.WriteBoolean('BuildUsePic', chkBoxPreprocessors.Checked[3]);
  iniStorage.WriteBoolean('BuildUseRefer', chkBoxPreprocessors.Checked[4]);
  iniStorage.WriteBoolean('BuildUseTbl', chkBoxPreprocessors.Checked[5]);
  iniStorage.WriteBoolean('BuildUseHdtbl', chkBoxExtras.Checked[0]);
  iniStorage.WriteBoolean('BuildUsePdfMark', chkBoxExtras.Checked[1]);
  iniStorage.WriteBoolean('BuildToPostscript', rdPs.Checked);
  iniStorage.WriteBoolean('BuildToPDF', rdPDF.Checked);

  // Store the IDE settings:
  iniStorage.WriteBoolean('AutoSaveBuildSettings', chkAutoSaveBuildSettings.Checked);
  iniStorage.WriteBoolean('AutoUpdateCheck', chkUpdateCheckOnStart.Checked);

  // Store the PDF settings:
  iniStorage.WriteBoolean('UseGhostscript', chkUseGhostscript.Checked);
  iniStorage.WriteBoolean('KeepPsFile', chkKeepPostscriptFile.Checked);

  iniStorage.Save;
end;

procedure TMainForm.chkUseGhostscriptChange(Sender: TObject);
begin
  chkKeepPostscriptFile.Enabled := chkUseGhostscript.Checked;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  Reply, BoxStyle: integer;
begin
  // If the current file has unsaved changes, ask first.
  if unsavedChanges then
    with Application do
    begin
      BoxStyle := MB_ICONQUESTION + MB_YESNO;
      Reply := MessageBox('Do you want to save the document first?',
        'UnsavedChanges', BoxStyle);
      if Reply = idYes then btnSaveGroffClick(Sender);
    end;
end;

{$IFDEF DARWIN}
// Fix HTTPS on macOS:
procedure TMainForm.GetSocketHandler(Sender: TObject; const UseSSL: Boolean; out AHandler: TSocketHandler);
begin
  if UseSSL then begin
    AHandler := TSSLSocketHandler.Create;
    TSSLSocketHandler(AHandler).SSLType := stTLSv1_2;
  end else AHandler := TSocketHandler.Create;
end;
{$ENDIF}

end.
