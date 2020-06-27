//  * -------------- *
//  |      Dummy     |
//  * -------------- *

// This is a part of {LS} Last Stand. Handles a dummy bot used for sentry or scarecrow.

unit Dummy;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Ballistic,
	BaseFlag,
  maths,
	MersenneTwister,
  PlacePlayer,
	Raycasts;

procedure CheckDummyOnFlag(ID: byte);

implementation

const DUMMY_FLAG_SQRDIST = 60 * 60;

procedure CheckDummyOnFlag(ID: byte);
var x, y, rd: single; a: single; n, m, k: byte;
	bx, by: array [0..7] of single;
	vec: tTVector;
begin
	if ID > 0 then begin
		GetPlayerXY(ID, x, y);
		if SqrDist(x, y-15, Map.BlueFlag.X, Map.BlueFlag.Y) < 1600 then begin
			Base_ReturnFlag();
			if SqrDist(x, y, Base.X, Base.Y) < DUMMY_FLAG_SQRDIST then begin
				y := y - 10;
				while n < 9 do begin
					n := n + 1;
					if n = 5 then continue;
					if n < 5 then a := RandFlt(-1.04, 0) else a := RandFlt(-ANG_PI, -2.09);
					rd := RandFlt(10, 30);
					vec.vx := cos(a)*rd;
					vec.vy := sin(a)*rd;
					vec.t := Trunc(320/rd + 1);
					if not BallisticCast(x, y, 5, vec, true, false) then
						if SqrDist(vec.X, vec.Y, Base.X, Base.Y) > DUMMY_FLAG_SQRDIST then begin
							if not RayCast(vec.X, vec.Y, vec.X, vec.Y + 15, true, false, false) then begin
								bx[m] := vec.X; by[m] := vec.Y;
								m := m + 1;
							end;
						end;
				end;
				if m > 0 then begin
					rd :=250000;
					n := 0;
					while n < m do begin
						a := SqrDist(x, y, bx[n], by[n]);
						if a < rd then begin
							rd := a;
							k := n;
						end;
						n := n + 1;
					end;
					PutPlayer(ID, Players[ID].Team, bx[k], by[k], false);
				end;
			end;
		end;
	end;
end;

begin
end.
