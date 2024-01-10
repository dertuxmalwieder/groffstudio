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
  Classes, SysUtils, Forms, StdCtrls, Process, Dialogs;

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
  str: String;
  lh: TextFile;
  ret: Boolean;
begin
{$IFDEF WINDOWS}
  ret := RunCommand('cmd', ['/c', CommandLine], str, [], swoHIDE);
{$ELSE}
  ret := RunCommand('sh', ['-c', CommandLine], str, [], swoHIDE);
{$ENDIF}

  if LogFile <> '' then
  begin
    AssignFile(lh, LogFile);
    try
      ReWrite(lh);
      Write(lh, str);
    finally
      CloseFile(lh);
    end;
  end;

  { Close the status window: }
  Close;

  Result := ret;
end;

end.

