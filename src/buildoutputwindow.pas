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
    Label1: TLabel;
  private

  public
    function BuildDocument(CommandLine: String; LogFile: String): Boolean;

  end;

var
  OutputText: String;

implementation

{$R *.lfm}

function TBuildStatusWindow.BuildDocument(CommandLine: String; LogFile: String): Boolean;
var
  p: TProcess;
  n: LongInt;
  str: String;
  lh: TextFile;
begin
  p := TProcess.Create(nil);
  p.Options := p.Options + [poUsePipes, poStderrToOutPut];

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

  if LogFile <> '' then
  begin
    AssignFile(lh, LogFile);
    Rewrite(lh);

    while p.Running do
    begin
      n := p.Output.Read(str, 2048);
      if n > 0 then
      begin
        writeln(lh, str);
      end
      else Sleep(100);
    end;

    { We might have some buffer contents left. }
    repeat
      n := p.Output.Read(str, 2048);
      if n > 0 then
      begin
        writeln(lh, str);
      end;
    until n <= 0;

    CloseFile(lh);
  end;

  result := p.ExitStatus > 0;
  p.Free;

  { Close the status window: }
  Close;
end;

end.

