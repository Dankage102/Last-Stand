// * -------------- *
// |    Objects     |
// * -------------- *

// Enhanced object spawner.

unit Objects;

interface

uses
{$ifdef FPC}
	Scriptcore,
  {$endif}
	MersenneTwister,
	Raycasts,
	Misc,
	Kits;

function Objects_SpawnX(ID, style, n: shortint): boolean;

implementation

function Objects_SpawnX(ID, style, n: shortint): boolean;
var x, x2, y: single; i: shortint;
begin
	GetPlayerXY(ID, x, y);
	y := y - 20;
	if style > 15 then begin
		if Players[ID].Direction = 1 then begin
			RayCast2(4, 0, 30, x, y);
			x := x - 5;
		end else begin
			RayCast2(-4, 0, 30, x, y);
			x := x + 5;
		end;
		RayCast2(0, 5, 30, x, y);
		RayCast2(0, 2, 5, x, y);
	end;
	Result := true;
	for i := 1 to n do begin
		if n > 0 then begin
			 x2 := x + RandFlt(n+2*i-4, 4-n+2*i);
		end else x2 := x;
		if style = 16 then Result := Kits_Spawn(x2, y-3*i, 16, 240) else
		if style = 17 then Result := Kits_Spawn(x2, y-3*i, 17, 240) else
		Objects_Spawn(x2, y, style);
		if not Result then break;
	end;
	if not Result then WriteConsole( 0, 'Limit of kits in game exceeded', $FF1111);
end;

end.
