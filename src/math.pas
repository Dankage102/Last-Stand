unit Math;

interface

const
	PX_PER_METER = 14.0;	// Number of soldat distance units per one "meter"
	
	ANG_PI   = 3.14159265;
	DEG_2_RAD = ANG_PI / 180;
	ANGLE_5 = DEG_2_RAD * 5;
	ANGLE_10 = DEG_2_RAD * 10;
	ANGLE_15 = ANG_PI / 12;
	ANGLE_30 = ANG_PI / 6;
	ANGLE_40 = DEG_2_RAD * 40;
	ANGLE_45 = ANG_PI / 4;
	ANGLE_60 = ANG_PI / 3;
	ANGLE_70 = DEG_2_RAD * 70;
	ANGLE_80 = DEG_2_RAD * 80;
	ANGLE_90 = ANG_PI / 2;
	ANGLE_100= DEG_2_RAD * 100;
	ANGLE_110= DEG_2_RAD * 110;
	ANG_2PI  = ANG_PI * 2;

function ShortenAngle(x: single): single;

//function arctan2(X, Y: single): single; external 'arctan2@SCE.dll cdecl'; 

//function arccos(X: single): single; external 'arccos@SCE.dll cdecl';

//function power(Base, Exponent: double): double; external 'power@SCE.dll cdecl';

function sqr(x: single): single;

function dot(x1, y1, x2, y2: single): single;

function ToRangeI(min, x, max: integer): integer;

function ToRangeB(min, x, max: byte): byte;

function ToRangeF(min, x, max: single): single;

function IsBetween(a, b, c: integer): boolean;

function absi(x: smallint): smallint;

function sgn(x: single): shortint;
	
implementation

function sqr(x: single): single;
begin
	Result := x * x;
end;

function ShortenAngle(x: single): single;
begin
	while x > ANG_PI do
		x := x - ANG_2PI;
	while x < - ANG_PI do
		x := x + ANG_2PI;
	Result := x;
end;

function ToRangeI(min, x, max: integer): integer;
begin
	if x < min then Result:=min else
	if x > max then Result:=max else
		Result:=x;
end;

function ToRangeB(min, x, max: byte): byte;
begin
	if x < min then Result:=min else
	if x > max then Result:=max else
		Result:=x;
end;

function ToRangeF(min, x, max: single): single;
begin
	if x < min then Result:=min else
	if x > max then Result:=max else
		Result:=x;
end;

function IsBetween(a, b, c: integer): boolean;
begin
	Result := (a <= b) = (c >= b);
end;

function absi(x: smallint): smallint;
begin
	if x >= 0 then Result := x else Result := -x;
end;

function sgn(x: single): shortint;
begin
	if x > 0 then Result := 1 else
	if x < 0 then Result := -1 else
	Result := 0;
end;

function dot(x1, y1, x2, y2: single): single;
begin
	result := x1 * x2 + y1 * y2;
end;

begin
end.
