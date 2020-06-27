unit Fire;
//  * --------------------- *
//  |         Fires         |
//  * --------------------- *

/// The unit handles flames and burning areas on the map.
/// By tk.

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
  Misc,
  MersenneTwister,
  maths,
  Ballistic,
  raycasts;

const
	MAX_FIRES = 40;
	FLAMEDMG = -20;

type Fires_InFireCallback = procedure(ID, owner: byte);

/// Creates a single flame
/// @param X Coords
/// @param Y Coords
/// @param duration Time of burning 
/// @param owner owner
procedure Fire_CreateSingleFlame(X, Y: single; duration: integer; owner: byte);

/// Creates burning area consisiting of multiple flames.
/// @param X Coords
/// @param Y Coords
/// @param duration Time of burning [s] 
/// @param N number of flames
/// @param owner owner
procedure Fire_CreateBurningArea(X, Y, ParticleVel, CastingRange: single; duration, n: integer; owner: byte);
	
/// Creates burning area consisiting of multiple flames from tVector;
/// @param flame Array of vectors
/// @param duration Time of burning 
/// @param owner owner
procedure Fire_CreateFromVector(var flame: array of tTVector; duration: integer; owner: byte);

procedure Fire_Process();

/// Initializes the unit
/// @param Fires_InFireCallback Function "pointer" to user in-fire event.
procedure Fire_Initialise(InFireCallback: Fires_InFireCallback);
	
/// Clears ith fire from the map
/// @param Fire id
procedure Fire_Clear(i: byte);

/// Clears all fire from the map
procedure Fire_ClearAll();

/// Clears all fire for specified owner
/// @param Owner ID
procedure Fire_ClearByOwner(ID: byte);

	
implementation
	
type
	tFire = record
		t, c: integer;
		x, y: single;
		owner: byte;
	end;
	
var
	Fires: array [0..MAX_FIRES] of tFire;
	MaxFireID: integer;
	FireCallback: Fires_InFireCallback;
	CallNum: integer;
	
procedure Fire_CreateSingleFlame(X, Y: single; duration: integer; owner: byte);
var i: integer;
begin
	for i:=1 to MAX_FIRES do
		if Fires[i].t = 0 then begin
			Fires[i].x := X;
			Fires[i].y := Y;
			Fires[i].t := duration*7;
			Fires[i].owner := owner;
			if (i > MaxFireID) then MaxFireID := i;
			break;
		end;
end;

procedure Fire_CreateBurningArea(X, Y, ParticleVel, CastingRange: single; duration, n: integer; owner: byte);
var i, num: integer; Vel, ang: single; vec: tTVector; NotInRange: boolean;
begin
	// Loop to 2n in case some casts are unsuccesful
	num := n;
  i := 1;
	while i < n*2 do begin
		if i mod 2 = 0 then ang := RandFlt(-ANG_PI, -ANGLE_110) else ang := RandFlt(-ANGLE_70, 0);
		// Do some casting
		Vel := RandFlt(ParticleVel * 0.7, ParticleVel * 1.2);
		vec.vx := cos(ang)*Vel*1.2;
		vec.vy := sin(ang)*Vel*0.8;
		vec.t := Trunc(CastingRange/Vel + 1.0);
		NotInRange := BallisticCast(X, Y, 4, vec, false, true);
		// If a collsion point was found
		if not NotInRange then begin
			if not PointNotInPoly(vec.X, vec.Y, true, true, true) then begin
				if PointNotInPoly(vec.X, vec.Y-10.0, true, true, true) then begin
					vec.Y := vec.Y - 10.0;
				end else if PointNotInPoly(vec.X, vec.Y+10.0, true, true, true) then begin
					vec.Y := vec.Y + 10.0;
				end;
			end;
			// Find the next free slot
			while (i <= MAX_FIRES) do begin
				if Fires[i].t = 0 then begin
					break;
				end;
				i := i + 1;
			end;
			if i > MAX_FIRES then break;
			Fires[i].x := vec.X;
			Fires[i].y := vec.Y;
			Fires[i].t := duration*7+RandInt(-7, 7);
			Fires[i].owner := owner;
			if (i > MaxFireID) then MaxFireID := i;
			num := num - 1;
			if (num <= 0) then begin
				break;
			end;
		end;
    i := i + 1;
	end;
	//PlaySound(0, 'onfire.wav', X, Y);
end;

procedure Fire_CreateFromVector(var flame: array of tTVector; duration: integer; owner: byte);
var i, j: integer;
begin
	for j:=0 to Length(flame)-1 do begin
		// Find the next free slot
		while (i <= MAX_FIRES) do begin
			if Fires[i].t = 0 then begin
				Fires[i].x := flame[j].X;
				Fires[i].y := flame[j].Y;
				Fires[i].t := duration*7;
				Fires[i].owner := owner;
				if (i > MaxFireID) then MaxFireID := i;
				break;
			end;
			i := i + 1;
		end;
	end;
	//PlaySound(0, 'onfire.wav', X, Y);
end;

procedure Fire_RefreshMaxID();
begin
	while MaxFireID > 0 do begin
		if Fires[MaxFireID].t > 0 then begin
			break;
		end;
		MaxFireID := MaxFireID - 1;
	end;
end;

procedure Fire_Process();
var i, j: integer; owner: byte;
begin
	CallNum := CallNum + 1;
	i := CallNum mod 3;
	CallNum := i;
	while (i <= MaxFireID) do begin
		if Fires[i].t > 0 then begin
			if Fires[i].c > 0 then begin
				Fires[i].c := Fires[i].c - 1;
			end else begin
				Fires[i].c := RandInt(1, 4);
				owner := Fires[i].owner;
				if Fires[i].t > RandInt(0, 26) then begin // last 4 seconds or so the fire is lowering
					for j:=1 to MaxID do
					if Players[j].Active then
					if Players[j].Team <> Players[owner].Team then
					if Distance(Players[j].X, Players[j].Y, Fires[i].X, Fires[i].Y) < 25.0 then
					if Players[j].Alive then begin
						FireCallback(j, owner);
					end;
					Map.CreateBullet(Fires[i].X+RandFlt(-3.0, 3.0), Fires[i].Y, 0, RandFlt(-0.7, -0.3), FLAMEDMG, 5, Players[owner]);
				end;
			end;
			Fires[i].t := Fires[i].t - 1;
			if Fires[i].t = 0 then begin
				Fire_RefreshMaxID();
			end;
		end;
		i := i + 3;
	end;
end;

procedure Fire_Initialise(InFireCallback: Fires_InFireCallback);
begin
	FireCallback := InFireCallback;
end;

procedure Fire_Clear(i: byte);
begin
	Fires[i].t := 0;
	Fire_RefreshMaxID();
end;

procedure Fire_ClearAll();
var i: byte;
begin
	for i := 0 to MAX_FIRES do
		Fires[i].t := 0;
	MaxFireID := 0;
end;

procedure Fire_ClearByOwner(ID: byte);
var i: integer;
begin
	for i := 1 to MaxID do
		if Fires[i].Owner = ID then Fires[i].t := 0;
	Fire_RefreshMaxID();
end;

begin
end.
