// * ------------------ *
// |    Barbed wires    |
// * ------------------ *

// This is a part of {LS} Last Stand. Implements barbed wires;

unit BarbedWires;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
  BigText,
	Debug,
	Constants,
	LSPlayers,
  MersenneTwister,
	Misc,
  Raycasts,
	Damage;

const
	MAX_WIRES = 3;

type
	tBarbedWire = record
		active: boolean;
		x1, x2, a, b, c, d: single;
		bundle: array[0..1] of record
			x, y: single;
			barb: array [0..4] of boolean;
		end;
		LastDamagedBundle: boolean;
		DestructionStage: byte;
		hp, owner, t: byte;
	end;

var
	wire:        array[1..MAX_WIRES] of tBarbedWire;

procedure Wires_TryPlace(owner: byte);

procedure Wires_ClearWire(a: byte);

procedure Wires_Damage(i: byte; dmg: smallint);

procedure Wires_Process(MainCall: boolean);

function Wires_InfoAt(ID: integer; X, Y: single): integer;

implementation

function Wires_TryPlaceX(owner: byte; xoffset: single; errors: boolean): boolean;
var i, j, a: byte; x2, Y2: array[0..1] of single; X, Y: single; B: Boolean; z: shortint;
begin
	for i:=1 to MAX_WIRES do
		if not wire[i].Active then begin
			a:=i;
			break;
		end;
	if a = 0 then begin
		if errors then
    	WriteConsole(owner, 'Maximum number of barbed wires in game', RED);
		exit;
	end;
	GetPlayerXY(owner, X, Y);
  X := X + xoffset;
	for i:=1 to MAX_WIRES do
		if wire[i].Active then
		if Distance((wire[i].x1+wire[i].x2)*0.5, (wire[i].bundle[0].y + wire[i].bundle[1].y)*0.5, X, Y) < 10.0 then begin
  		if errors then
     		WriteConsole(owner, 'Can''t place two wires at each other', RED);
			exit;
		end;
	RayCast2(0, 2.5, 15, X, Y); // move point closer to the ground
	for i := 0 to 1 do begin
		X2[i] := X; Y2[i] := Y - 4;
	end;
	z := 1;
	for j := 0 to 1 do begin
		for i := 0 to 4 do begin
			X2[j] := X2[j] + 5*z;
			if not RayCast(X2[j], Y2[j], X2[j] - 4*z, Y2[j], true, false, false) then Y2[j] := Y2[j] - 2 else B := true;
			if not B then if not RayCast(X2[j], Y2[j], X2[j] - 2*z, Y2[j] + 2, true, false, false) then Y2[j] := Y2[j] + 4 else B := true;
			if not B then if not RayCast(X2[j], Y2[j], X2[j] - 2*z, Y2[j] - 2, true, false, false) then begin
    		if errors then
        	WriteConsole(owner, '`Ground is too uneven to place a barbed wire', RED);
				exit;
			end;
		end;
		z := -1;
	end;
	for i := 0 to 1 do begin
		if (not RayCast(X2[i], Y2[i], X2[i], Y2[i], false, false, false)) or (RayCast2(0, 2, 22, X2[i], Y2[i])) then begin
      if errors then
      	WriteConsole(owner, 'Ground is too uneven to place a barbed wire', RED);
			exit;
		end;
		RayCast2(0, 0.5, 2, X2[i], Y2[i]);
		wire[a].bundle[i].x := X2[i];
		wire[a].bundle[i].y := Y2[i];
		for j := 0 to 4 do begin
			wire[a].bundle[i].barb[j] := true;
		end;
	end;
	// borders of the wire damage range
	wire[a].x1 := wire[a].bundle[0].x + 27;
	wire[a].x2 := wire[a].bundle[1].x - 27;
	// calc line corossing two bundles, Ax + By + C = 0
	wire[a].a := wire[a].bundle[0].y - wire[a].bundle[1].y;
	wire[a].b := wire[a].bundle[1].x - wire[a].bundle[0].x;
	wire[a].c := wire[a].bundle[0].x * (wire[a].bundle[1].y-13) - (wire[a].bundle[0].y-13) * wire[a].bundle[1].x;
	wire[a].d := Sqrt(wire[a].a*wire[a].a + wire[a].b*wire[a].b);
	wire[a].owner := owner;
	wire[a].Active := true;
	wire[a].DestructionStage := 4; // there are 5 hp destruction stages, in each one one barb is removed (just cosmetics)
	wire[a].hp := WIREHITPOINTS div 5;
	player[owner].Wires := player[owner].Wires - 1;
	WriteConsole(0, 'Mechanic ' + Players[owner].Name + ' has placed a barbed wire', GREEN);
	WriteConsole(owner, IntToStr(player[owner].Wires) + ' left', GREEN);
	Result := true;
end;

procedure Wires_TryPlace(owner: byte);
var i: integer;
begin
	if player[owner].task = 1 then begin
		if Players[owner].Alive then begin
			case Players_OnGround(owner, false, 15) of
				1:
        	if player[owner].Wires > 0 then begin
            if Wires_TryPlaceX(owner, 0.0, false) then exit;
            for i := 1 to 7 do begin
        	    if Wires_TryPlaceX(owner,  1.1*i, false) then exit;
              if Wires_TryPlaceX(owner, -1.1*i, false) then exit;
            end;
        		Wires_TryPlaceX(owner, 0.1, true);
					end else WriteConsole(owner, 'You don''t have any barbed wires left', RED);
				-1: WriteConsole(owner, 'You have to be on the solid ground to place a barbed wire', RED);
				else WriteConsole(owner, 'You have to be on the ground to place a barbed wire', RED);
			end;
		end else WriteConsole(owner, 'You are already dead', RED);
	end else WriteConsole(owner, 'You are not the mechanic', RED);
end;

procedure Wires_ClearWire(a: byte);
begin
	wire[a].Active := false;
	wire[a].owner := 0;
end;

procedure Wires_Damage(i: byte; dmg: smallint);
var
	b, j: byte;
	d: smallint;
	effect: boolean;
begin
	while dmg > 0 do begin
		d := WIREHITPOINTS div 5;
		if dmg < d then d := dmg;
		if d > wire[i].hp then d := wire[i].hp;
		wire[i].hp := wire[i].hp - d;
		if wire[i].hp <= 0 then begin
			if wire[i].DestructionStage = 0 then begin
				Wires_ClearWire(i);
				WriteConsole(0, 'Zombies have destroyed a barbed wire', RED);
				exit;
			end else begin
				wire[i].DestructionStage := wire[i].DestructionStage - 1;
				wire[i].hp := WIREHITPOINTS div 5;
				wire[i].LastDamagedBundle := not wire[i].LastDamagedBundle; // once destroy a barb from one bundle, once from the second
				if wire[i].LastDamagedBundle then j := 0 else j := 1;
				if not effect then begin
					for b := 0 to 2 do // spawn active barbs of the wire
						CreateBulletX(wire[i].bundle[j].x, wire[i].bundle[j].y-4, RandFlt(-3.0, 3.0), RandFlt(-3.0, -1.0), 0, 7, wire[i].owner);
					effect := true;
				end;
				b := RandInt_(4); // choose a random barb to destroy
				if not wire[i].bundle[j].barb[b] then
					repeat
						b := b + 1;
						if b >= 10 then break;
					until wire[i].bundle[j].barb[b mod 5];
				wire[i].bundle[j].barb[b mod 5] := false;
			end;
		end;
		dmg := dmg - d;
	end;
end;

procedure Wires_Process(MainCall: boolean);
var i, j, m: byte;
  ZombieOn: boolean;
	k: single;
	n: array[1..32] of integer;
  p: TActivePlayer;
begin
  // Iterate through wires in random order, so destruction speed of
  // overlapping wires is more or less equal
  i := RandInt_(MAX_WIRES-1);
  for m := 0 to MAX_WIRES-1 do begin
    i := i + 1;
    if i > MAX_WIRES then i := 1;
		if wire[i].Active then begin
			wire[i].Active := Players[wire[i].owner].Active;
			if not wire[i].Active then continue;
			for j := 1 to MaxID do begin// hurt all zombies in wire range
        p := Players[j];
      	if p.Alive then
				if player[j].Zombie then begin
					if p.x <= wire[i].x1 then
					if p.x >= wire[i].x2 then
					if Abs(wire[i].a*p.x + wire[i].b*p.y + wire[i].c) / wire[i].d < 25 then begin
            if n[j] = 0 then begin
              ZombieOn := true;
            	Damage_DoRelative(j, wire[i].owner, WIREDMG, Wires);
            end;
            n[j] := n[j] + 1;
					end;
				end;
      end;
      if MainCall then begin
				if ZombieOn then begin // if some zombie was in wire range
					Wires_Damage(i, 1);
					ZombieOn := false;
				end;
        wire[i].t := wire[i].t + 1;
				if wire[i].t > 4 then wire[i].t := 0;
				//if (wire[i].t = 0) then begin
				//	BigText_DrawMap(0, '#', 360, $111111, 0.08, trunc(wire[i].bundle[0].x)-4, trunc(wire[i].bundle[0].y)-11);
				//	BigText_DrawMap(0, '#', 360, $111111, 0.08, trunc(wire[i].bundle[1].x)-4, trunc(wire[i].bundle[1].y)-11);
				//end;
				for j := 0 to 1 do // spawn active barbs of the wire
					if wire[i].bundle[j].barb[wire[i].t] then
						CreateBulletX(wire[i].bundle[j].x, wire[i].bundle[j].y, wire[i].t*0.25 - 0.50, 0.5, 0, 7, wire[i].owner);
			end;
		end;
  end;
  for j := 1 to MaxID do
	  if n[j] > 0 then begin // hurt all zombies in wire range
      k := 0.5 / n[j];
      p := Players[j];
      p.SetVelocity(p.VelX*k, p.VelY*k);
    end;
end;

function Wires_InfoAt(ID: integer; X, Y: single): integer;
var
	i: integer;
	d, max, hp: single;
begin
	max := 50.0*50.0;
	for i := 1 to MAX_WIRES do begin
		if ID = wire[i].owner then
		if wire[i].active then begin
			d := SqrDist(X, Y, (wire[i].x1+wire[i].x2)*0.5, (wire[i].bundle[0].y+wire[i].bundle[1].y)*0.5);
			if d < max then begin
				max := d;
				Result := i;
			end;
		end;
	end;
	if Result > 0 then begin
		hp := (single(integer(wire[Result].hp)) + single(integer(wire[Result].DestructionStage))*WIREHITPOINTS/5.0)/WIREHITPOINTS;
		BigText_DrawMap(ID,
			'Wire: ' + IntToStr(Round(hp*100.0)) + '%',
			180, $88000000 + RG_Gradient(hp, 0.5), 0.04, Trunc(wire[Result].bundle[1].X)-5, Trunc((wire[Result].bundle[0].Y + wire[Result].bundle[1].Y)*0.5+3.0)
		);
	end;
end;

end.

