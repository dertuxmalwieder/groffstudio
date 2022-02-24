unit BuildOutputWindow;

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

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Process;

type

  { TBuildStatusWindow }

  TBuildStatusWindow = class(TForm)
    mBuildOutput: TMemo;
  private

  public
    function BuildDocument(CommandLine: String): Boolean;

  end;

var
  OutputText: String;
  BuildStatusWindow: TBuildStatusWindow;

implementation

{$R *.lfm}

function TBuildStatusWindow.BuildDocument(CommandLine: String): Boolean;
var
  p: TProcess;
  AStringList: TStringList;
begin
  p := TProcess.Create(nil);
  p.Options := p.Options + [poWaitOnExit, poUsePipes];

  AStringList := TStringList.Create;
{$IFDEF WINDOWS}
  p.Executable := 'cmd';
  p.Parameters.Add('/c');
{$ENDIF}
{$IFDEF UNIX}
  p.Executable := 'sh';
  p.Parameters.Add('-c');
{$ENDIF}
  p.Parameters.Add(CommandLine);
  p.Execute;

  AStringList.LoadFromStream(p.Output);
  p.Free;

  mBuildOutput.Text := AStringList.Text;
  AStringList.Free;

  if Length(mBuildOutput.Text) = 0 then begin
    // We don't have any output. We can close the window.
    BuildStatusWindow.Close;
    result := True
  end
  else begin
    // There was some output. Chances are that warnings occurred.
    // Keep it shown.
    // TODO: This does not always work well...
    result := False
  end;
end;

end.

