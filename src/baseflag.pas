//  * -------------- *
//  |       Base     |
//  * -------------- *

// This is a part of {LS} Last Stand. Survivor base represented as flag.

unit BaseFlag;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Constants,
	Globals;

type
	tBase = record
		X, Y: single; Found: boolean;
	end;

var
	Base: tBase;

procedure Base_ReturnFlag();

procedure Base_OnMapChange();

implementation

procedure Base_ReturnFlag();
var i: byte;
begin
	for i := 1 to MAX_OBJECTS do //return flag
		if Map.Objects[i].Style = HUMANTEAM then begin
			Map.Objects[i].Kill();
			break;
		end;
end;

procedure Base_OnMapChange();
var i: integer;
begin
	Base.Found := false;
	for i := 1 to MAX_SPAWNS do
		if Map.Spawns[i].style = 6 then //Bravo Flag
		begin
			Base.X := Map.Spawns[i].x;
			Base.Y := Map.Spawns[i].y;
			Base.Found := true;
			break;
		end;
end;

begin
end.
