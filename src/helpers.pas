unit Helpers;

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
  Classes, SysUtils;

type
  TGroffHelpers = class
  public
    procedure VerStrCompare(newVersion, oldVersion: String; out comp: Integer);
end;

implementation

procedure TGroffHelpers.VerStrCompare(newVersion, oldVersion: String; out comp: Integer);
var
  nE1, nE2, nV1, nV2: Integer;

begin
 if (Length(newVersion) > 0) or (Length(oldVersion) > 0) then begin
  nE1 := Pos('.', newVersion + '.');
  nE2 := Pos('.', oldVersion + '.');
  if nE1 > 1 then
    nV1 := StrToInt(Copy(newVersion,1,(nE1-1)))
  else
    nV1 := 0;

  if nE2 > 1 then
    nV2 := StrToInt(Copy(oldVersion,1,(nE2-1)))
  else
    nV2 := 0;

  if nV1 = nV2 then
    VerStrCompare(Copy(newVersion, nE1 + 1, Length(newVersion)), Copy(oldVersion, nE2 + 1, Length(oldVersion)), comp)
  else if nV1 > nV2 then
    comp := 1
  else if nV1 < nV2 then
    comp := -1;
 end
 else
   comp := 0;
end;

end.

