program groffstudio;

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

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces,
  Forms, lazcontrols, Unit1, Helpers, BuildOutputWindow, Splashscreen;

{$R *.res}

var
  Splash: TSplashscreenWindow;

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  
  { Load the loading screen }
  Splash := TSplashscreenWindow.Create(Application);
  Splash.Show;
  Splash.Update;
  Application.ProcessMessages;
  
  Application.CreateForm(TMainForm, MainForm);
  
  Splash.Close;
  Application.Run;
end.

