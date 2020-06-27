unit RayCast;

interface

{$ifdef FPC}
  uses Scriptcore;
{$endif}

function SqrDist(x, y, x2, y2: single): single;

function RayCast(P1X, P1Y, P2X, P2Y: single; CheckPlayerOnly, CheckBulletOnly, CheckColliders: boolean): boolean;

function PointNotInPoly(x, y: single; CheckPlayerOnly, CheckBulletOnly, CheckColliders: boolean): boolean;

function PointsInRange(X, Y, X2, Y2, R: Single; visible: boolean): Boolean;

function IsInRange(ID: Byte; X, Y, R: single; visible: boolean): Boolean;

function PlayersInRange(A, B: Byte; R: single; visible: boolean): Boolean;

function PlayersInRangeX(A, B: Byte; Dist: single): Boolean;

function RayCast2(vx, vy, range: single; var x, y: single): boolean;

 // returns value 0 - 1 (1 is 100% clearance)
function RayCast3(X1, Y1, X2, Y2: single; NumberOfCasts: integer; MaxFails: integer): single;

implementation

function SqrDist(x, y, x2, y2: single): single;
begin
	x := x - x2;
	y := y - y2;
	Result := x*x + y*y;
end;

function RayCast(P1X, P1Y, P2X, P2Y: single; CheckPlayerOnly, CheckBulletOnly, CheckColliders: boolean): boolean;
begin
	Result := not Map.RayCast(P1X, P1Y, P2X, P2Y, CheckPlayerOnly, false, CheckBulletOnly, CheckColliders, 0);
end;

function PointNotInPoly(x, y: single; CheckPlayerOnly, CheckBulletOnly, CheckColliders: boolean): boolean;
begin
	Result := not Map.RayCast(x, y, x+0.01, y+0.01, CheckPlayerOnly, false, CheckBulletOnly, CheckColliders, 0);
end;

function PointsInRange(X, Y, X2, Y2, R: Single; visible: boolean): Boolean;
begin
	if SqrDist(X, Y, X2, Y2) <= R*R then begin
		if visible then
			Result := not Map.RayCast(x, y, x2, y2, false, false, false, false, 0)
		else
			Result := true;
	end;
end;

function IsInRange(ID: Byte; X, Y, R: single; visible: boolean): Boolean;
var X2, Y2: single;
begin
	GetPlayerXY(ID, X2, Y2);
	Result:=PointsInRange(X, Y, X2, Y2, R, visible);
end;

function PlayersInRange(A, B: Byte; R: single; visible: boolean): Boolean;
var X, Y, X2, Y2: single;
begin
	GetPlayerXY(A, X, Y);
	GetPlayerXY(B, X2, Y2);
	Y := Y - 10;
	Y2 := Y2 - 10;
	Result:=PointsInRange(X, Y, X2, Y2, R, visible);
end;

function PlayersInRangeX(A, B: Byte; Dist: single): Boolean;
begin
	Result :=  Abs(Players[A].X - Players[B].X) <= Dist;
end;

function RayCast2(vx, vy: single; range: single; var x, y: single): boolean;
var n: integer; d,x2,y2: single;
begin
	d:=Sqrt(vx*vx + vy*vy);
	x2 := x; y2 := y;
	n := Trunc(1 + range/d);
	while n >= 1 do begin
		n := n - 1;
		x2 := x2 + vx; y2 := y2 + vy;
		if Map.RayCast(x, y, x2, y2, true, false, false, false, 0) then
			exit;
		x := x2; y := y2;
	end;
	Result := true;
end;

function RayCast3(X1, Y1, X2, Y2: single; NumberOfCasts: integer; MaxFails: integer): single; // returns value 0 - 1 (1 is 100% clearance)
var Vx, Vy: single; n, Casts: word;
begin
	Vx := (X2 - X1) / NumberOfCasts;
	Vy := (Y2 - Y1) / NumberOfCasts;
	X2 := X1;
	Y2 := Y1;
	n := NumberOfCasts;
	while n >= 1 do begin
		n := n - 1;
		X1 := X1 + Vx;
		Y1 := Y1 + Vy;
		if not Map.RayCast(X1, Y1, X2, Y2, true, false, false, false, 0) then Casts := Casts + 1 else MaxFails := MaxFails - 1;
		if MaxFails <= 0 then begin
			Result := 0;
			exit;
		end;
		X2 := X1;
		Y2 := Y1;
	end;
	Result := Casts / NumberOfCasts;
end;

end.
