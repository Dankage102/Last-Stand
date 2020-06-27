//  * --------------- *
//  |  Cluster bombs  |
//  * --------------- *

// This is a part of {LS} Last Stand. 

unit ClusterBombs;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Ballistic,
	maths,
	Misc,
	MersenneTwister,
	Raycasts,
	Fire,
	Damage;

const
	MAX_BOMBS =    5;

type
	tClusterBomb = record
		Fragment: array of tTVector;
		Timer, Owner, Style: byte;
		Active: boolean;
	end;
	
var
	Bomb:        array[1..MAX_BOMBS] of tClusterBomb;
	
function ClusterBomb_Spread(X, Y, Spread: single; Owner: byte; Time: word; N: byte; CastingCharge: boolean): boolean;

procedure ClusterBomb_Clear(a: byte);

procedure ClusterBomb_Process();
	
implementation

function ClusterBomb_Spread(X, Y, Spread: single; Owner: byte; Time: word; N: byte; CastingCharge: boolean): boolean;
var
	found: boolean;
	i, a, r: byte;
	g, d, x2, y2: single;
begin
	for a := 1 to MAX_BOMBS do
		if not Bomb[a].Active then begin
			found := true;
			break;
		end;
	if found then begin
		Bomb[a].Active := true;
		Bomb[a].Owner := Owner;
		Bomb[a].Timer := Time;
		Time := Time * 60 + 60 - (Game.TickCount + 1) mod 60 - 1;
		SetLength(Bomb[a].Fragment, N);
		g := -G_BUL * Game.Gravity / DEFAULTGRAVITY;
		if CastingCharge then
			if not IsInRange(owner, X, Y, 50, false) then
				if not Raycast(X, Y, X, Y + 15, false, true, true) then
					CreateBulletX(X, Y, 3, 0, 0, 10, owner);
		// if point of spread is not clear, try to find a better one around
		if not (Raycast(x, y+3, x, y-8,  false, true, true) and Raycast(x-8, y, x+8, y, false, true, true)) then begin
			found := false;
			for r := 1 to 3 do begin
				d := ANGLE_15 / 3 * r;
				for i := 0 to 11 do begin
					x2 := x + cos(d) * 6*r;
					y2 := y + sin(d) * 6*r;
					if Raycast(x2, y2-8, x2, y2+3, false, true, true) then
						if Raycast(x2-8, y2, x2+8, y2, false, true, true) then begin
							found := true;
							break;
						end;
					d := d - ANGLE_15;
				end;
				if found then break;
			end;
			if found then begin // replace the spread point with a found, better one
				x := x2;
				y := y2;
			end;
		end;
		for i := 0 to N - 1 do begin
			if i mod 2 = 0 then begin
				Bomb[a].Fragment[i].vx := RandFlt(-Spread*1.2, -Spread*0.8) * ((i+1.0)/n);
			end else begin
				Bomb[a].Fragment[i].vx := RandFlt(Spread*0.8, Spread*1.2) * ((i+1.0)/n);
			end;
			// if some bomblet is gonna hit the ground in the place of spread, try casting it in x-opposite direction
			d := (Spread+RandFlt(10, 15)) / Sqrt(Bomb[a].Fragment[i].vx*Bomb[a].Fragment[i].vx + Bomb[a].Fragment[i].vy*Bomb[a].Fragment[i].vy);
			if not Raycast(x, y, x + Bomb[a].Fragment[i].vx*d, y + Bomb[a].Fragment[i].vy*d,  false, true, true) then
				if RandBool then begin
					Bomb[a].Fragment[i].vx := -Bomb[a].Fragment[i].vx;
				end else
					Bomb[a].Fragment[i].vx := Bomb[a].Fragment[i].vx / 2;
			Bomb[a].Fragment[i].vy := RandFlt(-Spread*0.7, -Spread*0.3);
			Bomb[a].Fragment[i].t := Time;
			CreateBulletX(X, Y, Bomb[a].Fragment[i].vx, Bomb[a].Fragment[i].vy, 0, 7, Owner);
			BallisticCast(X, Y, g, Bomb[a].Fragment[i], false, true);
			Bomb[a].Fragment[i].x := Bomb[a].Fragment[i].x - Bomb[a].Fragment[i].vx;
			Bomb[a].Fragment[i].y := Bomb[a].Fragment[i].y - Bomb[a].Fragment[i].vy;
			//CreateBulletX(Bomb[a].Fragment[i].x, Bomb[a].Fragment[i].y, 0, 0, 0, 5, Owner);
		end;
		//if a > MaxBombID then MaxBombID := a;
		Result := true;
	end else begin // if all ids in use, spam with bullets in classic way
		for i := 1 to N do
			CreateBulletX(X, Y, RandFlt(-Spread, Spread), RandFlt(-Spread*0.6, -Spread*0.2), 0.1, 4, Owner);
	end;
end;

procedure ClusterBomb_Clear(a: byte);
begin
	Bomb[a].Active := false;
	Bomb[a].Owner := 0;
	Bomb[a].Timer := 0;
	SetLength(Bomb[a].Fragment, 0);
end;

procedure ClusterBomb_Process();
var
	i, j: byte;
begin
	for i := 1 to MAX_BOMBS do
		if Bomb[i].Active then
			if Bomb[i].Timer >= 1 then
				IncB(Bomb[i].Timer, -1) else begin
					for j := 0 to Length(Bomb[i].Fragment) - 1 do begin
						CreateBulletX(Bomb[i].Fragment[j].x, Bomb[i].Fragment[j].y, Bomb[i].Fragment[j].vx, Bomb[i].Fragment[j].vy, -10, 4, Bomb[i].Owner);
						Damage_ZombiesAreaDamage(Bomb[i].Owner, Bomb[i].Fragment[j].x, Bomb[i].Fragment[j].y, 5, 90, 4000, Explosion);
					end;
					Fire_CreateFromVector(Bomb[i].Fragment, 5, Bomb[i].Owner);
					ClusterBomb_Clear(i);
				end;
end;

begin
end.
