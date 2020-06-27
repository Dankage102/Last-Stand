// * ------------------ *
// |       Utils        |
// * ------------------ *

// This is a part of {LS} Last Stand. Miscellaneous functions with dependencies to LS.

unit Utils;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	LSPlayers,
	Misc,
	maths,
	Raycasts;

function lookForTarget(ID: byte; X, Y, MinDistance, MaxDistance: Single; UsingRaycast: boolean): byte;

function lookForTarget2(ID: Byte; MinDistance, MaxDistance, MaxAngleDiff: single; UseRC: boolean; var FoundInRange: boolean): byte;

function PlayersDist(A, B: tActivePlayer): single;

implementation

function PlayersDist(A, B: tActivePlayer): single;
begin
	result := Distance(A.X, A.Y, B.X, B.Y);
end;

function lookForTarget(ID: byte; X, Y, MinDistance, MaxDistance: Single; UsingRaycast: boolean): byte;
var
	i: Shortint; X2, Y2, Vx,Vy, DistSqr: single; Team: boolean;
begin
	MaxDistance := MaxDistance * MaxDistance;
	MinDistance := MinDistance * MinDistance;
	Result:=0;
	Team := player[ID].Zombie;
	Y := Y - 10;
	for i:=1 to MaxID do
		if i <> ID then
		if Players[i].Alive then
		if not Players[i].Dummy then
		if player[i].Zombie <> Team then begin
			GetPlayerXY(i,X2,Y2);
			Vx:=X2-X;
			Vy:=Y2-Y;
			DistSqr:=Vx*Vx+Vy*Vy;
			if DistSqr < MaxDistance then
				if DistSqr >= MinDistance then begin
					if UsingRayCast then begin
						if not RayCast(X, Y, X2, Y2-10, false, true, false) then continue;
					end;
					Result:=i;
					MaxDistance:=DistSqr;
				end;
		end;
end;

function lookForTarget2(ID: Byte; MinDistance, MaxDistance, MaxAngleDiff: single; UseRC: boolean; var FoundInRange: boolean): byte;
var
	i: Shortint; A, X, Y, X2, Y2, Vx, Vy, DistSqr: single; Team: boolean;
begin
	GetPlayerXY(ID, X, Y);
	Y := Y - 10;
	MaxDistance := MaxDistance * MaxDistance;
	MinDistance := MinDistance * MinDistance;
	Result:=0;
	Team := player[ID].Zombie;
	if Players[ID].Direction = -1 then A := ANG_PI; // <- or ->
	for i:=1 to MaxID do
		if i <> ID then
		if Players[i].Alive then
		if player[i].Zombie <> Team then 
		if not player[i].JustResp then begin
			GetPlayerXY(i,X2,Y2);
			Vx:=X2-X; Vy:=Y2-Y;
			DistSqr:=Vx*Vx+Vy*Vy;
			if DistSqr < MaxDistance then begin
				if DistSqr >= MinDistance then begin
					if UseRC then begin
						if not RayCast(X, Y, X2, Y2-10, false, true, false) then continue;							
					end;
					FoundInRange := true;
					if Math.Abs(ShortenAngle(Math.arctan2(Vy, Vx) - A)) > MaxAngleDiff then continue;
					Result := i;
					MaxDistance := DistSqr;
				end;
			end;
		end;
end;

end.
