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
  ExtCtrls, Buttons, ExtendedNotebook, SynEdit, fphttpclient, opensslsockets,
  RegExpr, LCLIntf, LCLType, IniPropStorage, Process, Helpers, fileinfo,
  {$IF DEFINED(WINDOWS)}
  winpeimagereader,
  {$ELSEIF DEFINED(DARWIN)}
  machoreader, ssockets, sslsockets, sslbase,
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
    chkLogFile: TCheckBox;
    chkAutoSaveBuildSettings: TCheckBox;
    chkPdfMark: TCheckBox;
    chkRefer: TCheckBox;
    chkChem: TCheckBox;
    chkGrn: TCheckBox;
    chkTbl: TCheckBox;
    chkPic: TCheckBox;
    chkEqn: TCheckBox;
    cmbMacro: TComboBox;
    edtGroffInstalledVersion: TEdit;
    edtGroffstudioInstalledVersion: TEdit;
    edtOnlineGroffVersionWindows: TEdit;
    ExtendedNotebook1: TExtendedNotebook;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    iniStorage: TIniPropStorage;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
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
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure lblFossilRepoClick(Sender: TObject);
    procedure lblGithubRepoClick(Sender: TObject);
    procedure lblWebsiteClick(Sender: TObject);
    procedure rdPdfChange(Sender: TObject);
    procedure rdPsChange(Sender: TObject);
    procedure SynEdit1Change(Sender: TObject);
{$IFDEF DARWIN}
    procedure GetSocketHandler(Sender: TObject; const UseSSL: Boolean; out AHandler: TSocketHandler);
{$ENDIF}
  private
    var currentGroffFilePath: String;
    var currentGroffFileName: String;
    var hasGroff: Boolean;
    var unsavedChanges: Boolean;
{$IFDEF WINDOWS}
    var latestGroffWindowsUrl: String;
{$ENDIF}
    var storeBuildSettings: Boolean;
  public

  end;

var
  MainForm: TMainForm;
  BuildWindow: TBuildStatusWindow;

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  GroffOutputVersion: String;
  OnlineVersionsFile: String;
  {$IFDEF WINDOWS}
  reGroffVersion: TRegExpr;
  {$ENDIF}
  reGroffStudioVersion: TRegExpr;
  FileVerInfo: TFileVersionInfo;
  HasVersionUpdate: Integer;
  GroffHelpers: TGroffHelpers;
  ResStream: TResourceStream;
  {$IFDEF DARWIN}
  HTTPClient: TFPHttpClient;
  {$ENDIF}
begin
  // What's the current running groff version?
  if RunCommand('troff', ['--version'], GroffOutputVersion) then
  begin
    edtGroffInstalledVersion.Text := GroffOutputVersion;
    hasGroff := True;
  end else begin
    edtGroffInstalledVersion.Text := 'n/a';
    hasGroff := False;
    lblTroffCommandNotFound.Visible := True;
  end;

  // Default file name
  currentGroffFileName := '[unsaved file]';

  // Embed the license
  ResStream:= TResourceStream.Create(HInstance, 'LICENSE', RT_RCDATA);
  try
    mLicense.Lines.LoadFromStream(ResStream);
  finally
    ResStream.Free;
  end;

  // Restore the settings
  iniStorage.Restore;
  storeBuildSettings := iniStorage.ReadBoolean('AutoSaveBuildSettings', False);
  chkAutoSaveBuildSettings.Checked := storeBuildSettings;

  if storeBuildSettings then
  begin
       chkLogFile.Checked := iniStorage.ReadBoolean('BuildLogFile', False);
       cmbMacro.Text := iniStorage.ReadString('BuildChosenMacro', '[ select ]');
       chkChem.Checked := iniStorage.ReadBoolean('BuildUseChem', False);
       chkEqn.Checked := iniStorage.ReadBoolean('BuildUseEqn', False);
       chkGrn.Checked := iniStorage.ReadBoolean('BuildUseGrn', False);
       chkPic.Checked := iniStorage.ReadBoolean('BuildUsePic', False);
       chkRefer.Checked := iniStorage.ReadBoolean('BuildUseRefer', False);
       chkTbl.Checked := iniStorage.ReadBoolean('BuildUseTbl', False);
       chkPdfMark.Checked := iniStorage.ReadBoolean('BuildUsePdfMark', False);
       rdPs.Checked := iniStorage.ReadBoolean('BuildToPostscript', False);
       rdPdf.Checked := iniStorage.ReadBoolean('BuildToPDF', False);
  end;

  // What's the latest available version?
  FileVerInfo := TFileVersionInfo.Create(nil);

  try
    FileVerInfo.ReadFileInfo;
    edtGroffStudioInstalledVersion.Text := FileVerInfo.VersionStrings.Values['FileVersion'];
    lblAboutProductName.Caption := FileVerInfo.VersionStrings.Values['ProductName'] + ' ' + FileVerInfo.VersionStrings.Values['FileVersion'];
    MainStatusBar.Panels[2].Text := '';

    {$IFDEF WINDOWS}
    OnlineVersionsFile := TFPCustomHTTPClient.SimpleGet('https://groff.tuxproject.de/updates/versions.txt');
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

    reGroffStudioVersion := TRegExpr.Create('studio-win ([\d\.]+) (.*)$');
    reGroffStudioVersion.ModifierM := True;
    if reGroffStudioVersion.Exec(OnlineVersionsFile) then
    begin
      // Compare the two versions - ours and the online one:
      GroffHelpers.VerStrCompare(reGroffStudioVersion.Match[1], FileVerInfo.VersionStrings.Values['FileVersion'], HasVersionUpdate);
      if HasVersionUpdate > 0 then
        MainStatusBar.Panels[2].Text := 'update ' + reGroffStudioVersion.Match[1] + ' available';
    end;
    {$ELSE}
    // Non-Windows platforms won't need some of that.
    {$IFDEF DARWIN}
    // What's the latest available version?
    try
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
          MainStatusBar.Panels[2].Text := 'update ' + reGroffStudioVersion.Match[1] + ' available'
        else
          MainStatusBar.Panels[2].Text := IntToStr(HasVersionUpdate);
      end;
    finally
      HTTPClient.Free;
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

procedure TMainForm.rdPdfChange(Sender: TObject);
begin
  chkPdfMark.Enabled := True;
end;

procedure TMainForm.rdPsChange(Sender: TObject);
begin
  chkPdfMark.Enabled := False;
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
   OpenURL(latestGroffWindowsUrl);
   {$ENDIF}
end;

procedure TMainForm.btnBuildClick(Sender: TObject);
var
  buildSuccess: Boolean;
  buildOpts: String;
  logFileName: String = '';
  outputFileName: String;
begin
  // Reset status display:
  MainStatusBar.Panels[1].Text := '';

  BuildWindow := TBuildStatusWindow.Create(Application);
  BuildWindow.Show;

  // Build the parameters:
  buildOpts := 'groff';

  // - Macro:
  if cmbMacro.SelText <> '' then buildOpts := buildOpts + ' -' + cmbMacro.SelText;

  // - Enforce UTF-8:
  buildOpts := buildOpts + ' -Kutf8';

  // - Preprocessors:
  if chkChem.Checked then   buildOpts := buildOpts + ' -chem';
  if chkEqn.Checked then    buildOpts := buildOpts + ' -eqn';
  if chkGrn.Checked then    buildOpts := buildOpts + ' -grn';
  if chkPic.Checked then    buildOpts := buildOpts + ' -pic';
  if chkRefer.Checked then  buildOpts := buildOpts + ' -refer';
  if chkTbl.Checked then    buildOpts := buildOpts + ' -tbl';

  // - PDF-specifics:
  if rdPdf.Checked then begin
    buildOpts := buildOpts + ' -Tpdf';
    if chkPdfMark.Checked then buildOpts := buildOpts + ' -mpdfmark';
    outputFileName := currentGroffFilePath + '.pdf';
  end
  else outputFileName := currentGroffFilePath + '.ps';

  // - Input file:
  buildOpts := buildOpts + ' ' + currentGroffFilePath;
  buildOpts := buildOpts + ' > ' + outputFileName;

  // - Log file:
  if chkLogFile.Checked then logFileName := currentGroffFilePath + '.log';

  // Build:
  buildSuccess := BuildWindow.BuildDocument(buildOpts, logFileName);
  if buildSuccess then
    MainStatusBar.Panels[1].Text := 'build successful'
  else
    MainStatusBar.Panels[1].Text := 'build problem';

  FreeAndNil(BuildWindow);
end;

procedure TMainForm.btnLoadGroffClick(Sender: TObject);
var
  Reply, BoxStyle: Integer;
begin
  // If the current file has unsaved changes, ask first.
  if unsavedChanges then with Application do begin
    BoxStyle := MB_ICONQUESTION + MB_YESNO;
    Reply := MessageBox('Do you want to save the document first?', 'UnsavedChanges', BoxStyle);
    if Reply = IDYES then SynEdit1.Lines.SaveToFile(currentGroffFilePath);
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

    if hasGroff then begin
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
  iniStorage.WriteBoolean('BuildUseChem', chkChem.Checked);
  iniStorage.WriteBoolean('BuildUseEqn', chkEqn.Checked);
  iniStorage.WriteBoolean('BuildUseGrn', chkGrn.Checked);
  iniStorage.WriteBoolean('BuildUsePic', chkPic.Checked);
  iniStorage.WriteBoolean('BuildUseRefer', chkRefer.Checked);
  iniStorage.WriteBoolean('BuildUseTbl', chkTbl.Checked);
  iniStorage.WriteBoolean('BuildUsePdfMark', chkPdfMark.Checked);
  iniStorage.WriteBoolean('BuildToPostscript', rdPs.Checked);
  iniStorage.WriteBoolean('BuildToPDF', rdPDF.Checked);

  // Store the IDE settings:
  iniStorage.WriteBoolean('AutoSaveBuildSettings', chkAutoSaveBuildSettings.Checked);

  iniStorage.Save;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  Reply, BoxStyle: Integer;
begin
  // If the current file has unsaved changes, ask first.
  if unsavedChanges then
  with Application do begin
    BoxStyle := MB_ICONQUESTION + MB_YESNO;
    Reply := MessageBox('Do you want to save the document first?', 'UnsavedChanges', BoxStyle);
    if Reply = IDYES then SynEdit1.Lines.SaveToFile(currentGroffFilePath);
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

