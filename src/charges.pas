//  * ------------- *
//  |    Charges    |
//  * ------------- *

// This is a part of {LS} Last Stand. 

unit Charges;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Ballistic,
	Bigtext,
	Constants,
  Damage,
	Fire,
	Globals,
  ClusterBombs,
	lsplayers,
	maths,
	Misc,
	MersenneTwister,
	Stacks,
	Raycasts;

const
	MAX_CHARGES = 20;
	
type
	tCharge = record
		x, y: single;
		timer: byte;
		owner: byte;
		placed, remote: boolean;
	end;

var
	charge: array[0..MAX_CHARGES-1] of tCharge;
	Charges_MaxID: integer;
	
function Charges_InGameInfo(p: integer): string;

procedure Charges_TryPlace(ID: byte; chargeTime: integer; _remote: boolean);

procedure Charges_Process();

procedure Charges_Activate(ID: byte; a: smallint);

procedure Charges_SelectChargeAt(ID: integer; X, Y: single);

procedure Charges_Clear(a: byte);

procedure Charge_Explosion(x, y: single; step: word; amount, owner: byte);

implementation

const
	CHAR_COL = $CC1100;
	CHAR_NEXT_COL = $EEAA99;
	CHAR_MARK_X_OFFSET = 5.0;
	CHAR_MOUSE_RANGE = 50.0;

// I haven't finished this shit yet.....
procedure Expl(x, y: single; step: word; explosion_angle, direction_angle, min_penetration: single; var amount: byte; var vec: array of tTVector);
var ang, ang2, ang3, angle, vx, vy, rc, h, high: single; extend_array, element_used: boolean; i, j, arrheight, index, n: byte;
begin
// step 1: the first ring
	angle := ANGLE_60;
	n := Trunc(explosion_angle / angle + 0.9); // get the number of branches in based on explosion_angle
	ang := direction_angle + RandFlt(-angle, angle)/2; // calc the starting angle
	extend_array := true;
	arrheight := Length(vec);
	for i := 1 to n do begin
		ang := ang + angle; // calc the main casting angle for each iteration
		ang2 := ang + RandFlt(-0.15, 0.15) * angle;
		ang3 := ang2 - angle / 2;
		if extend_array then begin
			index := arrheight;
			arrheight := arrheight + 1;
      {$ifndef FPC}
			SetLength(vec, arrheight);
      {$endif}
			extend_array := false;
			element_used := false;
		end;
		high := -1;
		for j := 0 to 5 do begin // find the best position around this angle
			vx := cos(ang3) * step;
			vy := sin(ang3) * step;
			rc := RayCast3(x, y, x + vx, y + vy, 5, 5); // mearsure how much the point is visible
			h := rc - Abs(ang2 - ang3) / angle / 2;
			if rc >= min_penetration then begin
				if h > high then begin // pick the best vector
					high := h;
					vec[index].vx := vx;
					vec[index].vy := vy;
					vec[index].X := x + vx;
					vec[index].Y := y + vy;
					extend_array := true;
				end;
			end;
			ang3 := ang3 + angle / 6; 
		end;
		if extend_array then begin
			element_used := true;
			index := index + 1;
			//if amount > 0 then amount := amount - 1 else exit;
		end;
	end;
	// remove the last array element if it hasn't been used anyway
  {$ifndef FPC}
	if not element_used then SetLength(vec, index); // index = length - 1
  {$endif}
end;

procedure Charge_Explosion(x, y: single; step: word; amount, owner: byte);
var vec: array of tTVector; vec2: array of tTVector; i, j, l: smallint; rd: single; s: byte; elements: tStack8;
begin
	CreateBulletX(x, y, 0, 0, 50, 4, owner);
	Expl(x, y, step, ANG_2PI, 0, 0.39, amount, vec); // first step, get vectors through reference
	l := Length(vec);
	for i := 0 to l - 1 do begin // extend explosion in all directions, get more vectors through reference
		if not RayCast(vec[i].X, vec[i].Y, vec[i].X, vec[i].Y + 10, true, false, false) then s := 4 else
			if RandBool then s := 4 else s := 2;
		CreateBulletX(vec[i].X, vec[i].Y, 0, 0, 50, s, owner);
		Expl(vec[i].X, vec[i].Y, step, ANG_2PI / 6, math.arctan2(vec[i].vy, vec[i].vx), 0.59, amount, vec2);
		if amount = 0 then exit; // if reached the bullet limit then exit;
	end;
	l := 0;
	for i := 0 to Length(vec2) - 1 do begin
		CreateBulletX(vec2[i].X, vec2[i].Y, 0, 0, 50, 4, owner);
		if amount = 0 then exit;
		rd := math.arctan2(vec2[i].vy, vec2[i].vx);
		if (Abs(rd) < ANGLE_45) or (Abs(pi - rd) < ANGLE_45) then begin
			stack8_push(elements, i);
			//vec2[i].p := rd;
		end;
	end;
	for i := 0 to elements.length - 1 do begin
		j := elements.arr[i];
		CreateBulletX(vec2[j].X, vec2[j].Y, 0, 0, 50, 4, owner);
		amount := amount - 1;
		if amount = 0 then exit;
	end;
end;

function Charges_InGameInfo(p: integer): string;
var i, n: byte; first: boolean;
begin
	for i := 0 to Charges_MaxID do
		if p <> i then
			if (charge[i].placed) and (charge[i].remote) then begin
				Result := Result + iif(first, ', ', '') + IntToStr(i+1);
				first := true;
				n := n + 1;
		end;
	if n > 0 then Result := '{' + Result + '}' else Result := 'None';
end;

// Charge marking
procedure Charges_Mark(CID: integer; col: cardinal);
var i: byte;
begin
	// repeat two times (packetloss)
	for i := 0 to 1 do begin
		BigText_DrawMapX(WTL_CHARGES+CID, charge[CID].owner, '[' + IntToStr(CID+1) + ']', 99999999, col, 0.04, Trunc(charge[CID].X+CHAR_MARK_X_OFFSET), Trunc(charge[CID].Y));					
	end;
end;

procedure Charges_Unmark(CID: integer);
var i: byte;
begin
	// repeat two times (packetloss)
	for i := 0 to 1 do begin
		BigText_DrawMapX(WTL_CHARGES+CID, charge[CID].owner, '', 1, 0, 1, 0, 0);
	end;
end;

// Detonation order handling.
// Pop the next charge to detonate
function Charges_Pop(var s: tStack8): integer;
begin
	Assert(s.Length > 0, 'Charges_Pop');
	Result := stack8_pop(s, s.Length - 1);
	Charges_Unmark(Result);
	if s.Length > 0 then begin
		Charges_Mark(s.arr[s.length-1], CHAR_NEXT_COL);
	end;	
end;

// Move the specified charge to the top of the detonation queue
procedure Charges_Bubble(CID: integer; var s: tStack8);
var i: integer;
begin
	if CID = s.arr[s.length-1] then exit;
	Assert(s.Length > 0, 'Charges_Bubble');
	Charges_Mark(s.arr[s.length-1], CHAR_COL);
	for i := 0 to s.length - 1 do
		if s.arr[i] = CID then begin
			stack8_pop(s, i);
			break;
		end;
	stack8_push(s, CID);
	Charges_Mark(s.arr[s.length-1], CHAR_NEXT_COL);
end;

// Add a charge to the queue
procedure Charges_Push(CID: integer; var s: tStack8);
begin
	if s.Length > 0 then
		Charges_Mark(s.arr[s.length-1], CHAR_COL);
	Charges_Mark(CID, CHAR_NEXT_COL);
	stack8_push(s, CID);
end;

// Find a charge at (X, Y) and select it (move to the top of the detonation queue)
procedure Charges_SelectChargeAt(ID: integer; X, Y: single);
var 
	i: integer;
	choice: integer;
	d, max: single;
begin
	if player[ID].DetonationQueue.length = 0 then exit;
	choice := -1;
	max := CHAR_MOUSE_RANGE*CHAR_MOUSE_RANGE;
	for i:=0 to Charges_MaxID do begin
		if (charge[i].placed) and (charge[i].remote) then
		if charge[i].owner = ID then begin
			d := SqrDist(X, Y, charge[i].X-CHAR_MARK_X_OFFSET, charge[i].Y);
			if d < max then begin
				max := d;
				choice := i;
			end;
		end;
	end;
	if choice >= 0 then
	if choice <> player[ID].DetonationQueue.arr[player[ID].DetonationQueue.length-1] then begin
		Charges_Bubble(choice, player[ID].DetonationQueue);
		WriteConsole(ID, 'Charge [' + IntToStr(choice+1) + '] marked', GREEN);
	end;
end;

procedure Charges_TryPlace(ID: byte; chargeTime: integer; _remote: boolean);
var
	i: byte; b: boolean;
	found: integer;
begin
	if Players[ID].Alive then begin
		case Players_OnGround(ID, false, 20) of
			1: 	if (player[ ID ].task = 2) then begin
					if (player[ ID ].charges > 0) then begin
						if (_remote) or ((chargeTime >= 1) and (chargeTime <= 60)) then begin
							for found := 0 to MAX_CHARGES-1 do
								if not charge[found].placed then
								begin
									b:=true;
									break;
								end;
							if b then
							begin
								GetPlayerXY(ID, charge[found].X, charge[found].Y );
								RayCast2(0, 4, 20, charge[found].X, charge[found].Y);
								charge[found].Y:=charge[found].Y-5;
								charge[found].placed := true;
								charge[found].remote := _remote;
								if chargeTime >= 2 then begin // lower it due to latency of cluster bomb explosion
									if chargeTime >= 4 then
										chargeTime := chargeTime - 2 else
										chargeTime := chargeTime - 1;
								end;
								charge[found].timer := chargeTime;						
								charge[found].owner := ID;
								player[ ID ].charges := player[ ID ].charges - 1;
								if found > Charges_MaxID then Charges_MaxID := found;
								if _remote then begin
									Charges_Push(found, player[ID].DetonationQueue);
									for i := 1 to MaxID do
										if Players[i].Alive then
											if Players[i].Human then
												if i <> ID then
													WriteConsole( i, 'Demolition Expert ' + Players[ID].Name + ' has placed a remote charge', GREEN) else
													WriteConsole( i, 'Charge with ID ' + IntToStr(found) + ' placed. Charges in game: ' + Charges_InGameInfo(-1), GREEN);
									WriteConsole(ID, 'Type /act (Default Alt+4) to detonate the last charge(s)', GREEN);
									WriteConsole(ID, IntToStr(player[ID].charges) + ' charges left', GREEN);
								end else WriteConsole(ID, 'Time charge placed ('+IntToStr(player[ID].charges)+' left)! Get away from it!', GREEN);
							end else WriteConsole(ID, 'Maximal number of charges in game exceeded', RED);
						end else WriteConsole(ID, 'Invalid time argument, use values 1-60', RED);
					end else WriteConsole(ID, 'You do not have any charges left', RED);
				end else WriteConsole(ID, 'You are not the demolition expert', RED);
			-1: WriteConsole(ID, 'You have to be on the solid ground to place a charge', RED);
			else WriteConsole(ID, 'You have to be on the ground to place a charge', RED);
		end;
	end else WriteConsole(ID, 'You have to be alive to place a charge', RED);
end;

procedure Charges_Process();
var
	a, i, n: byte;
begin
	for a := 0 to Charges_MaxID do begin
		if charge[a].placed then begin
			if not charge[a].remote then begin
				BigText_DrawMapX(WTL_CHARGES+a, charge[a].owner, IntToStr(charge[a].timer+1), 80, YELLOW, 0.04, Trunc(charge[a].X)-5, Trunc(charge[a].Y));
				charge[a].timer := charge[a].timer - 1;
			end;
			if charge[a].timer = 0 then begin
				if charge[a].remote then begin
					if n < 2 then n := n + 1 else
						continue;
					Fire_CreateBurningArea(charge[a].X, charge[a].Y, 15, 200, 12, 6, charge[a].owner);
					Charge_Explosion(charge[a].X, charge[a].Y, 40, 20, charge[a].owner);
					for i:=0 to 3 do
						CreateBulletX(charge[a].X, charge[a].Y, RandFlt(-7,7), -RandFlt(3,4), 99, 10, charge[a].owner);
					Damage_ZombiesAreaDamage(charge[a].owner, charge[a].X, charge[a].Y, 40, 175, 4000, Explosion);
					Charges_Unmark(a);
				end else begin
					ClusterBomb_Spread(charge[a].X, charge[a].Y, 6, charge[a].owner, 2, 10, true);
				end;
				charge[a].placed := false;
				if a = Charges_MaxID then begin
					while Charges_MaxID > 0 do begin
						if charge[Charges_MaxID].placed then break;
						Charges_MaxID := Charges_MaxID - 1;
					end;
				end;
			end;
		end;
	end;
end;

procedure Charges_Hint(ID: byte);
begin
	player[ID].DetonationsNum := player[ID].DetonationsNum + 1;
	if player[ID].DetonationsNum >= 5 then begin
		WriteConsole(ID, 'HINT: Charge detonation:', HINTCOL);
		WriteConsole(ID, '"/act 0" to detonate all remote charges, "/act ID" for a charge with specified ID', HINTCOL);
		WriteConsole(ID, 'You can also point a charge with your mouse to make it detonate next.', HINTCOL);
		player[ID].DetonationsNum := -2;
	end;
end;

const ERR_NORCH = 'There are no remote charges placed!';
procedure Charges_Activate(ID: byte; a: smallint);
var i: smallint; n: byte;
begin
	// All
	if a = -1 then begin
		for i:=0 to Charges_MaxID do begin
			if (charge[i].placed) and (charge[i].remote) then
			begin
				charge[i].timer := 0;
				n := n + 1;
			end;
		end;
		if n > 0 then begin
			WriteConsole(ID, IntToStr(n) + ' charge'+iif(n > 1, 's', '') + ' activated!', GREEN);
			Charges_Hint(ID);
		end else
			WriteConsole(ID, ERR_NORCH, RED);
		stack8_clear(player[ID].DetonationQueue);
	end else begin
		// The first in queue
		if a = $FF then begin
			if player[ID].DetonationQueue.length > 0 then begin
				a := Charges_Pop(player[ID].DetonationQueue);
			end else begin
				WriteConsole(ID, ERR_NORCH, RED);
				exit;
			end;
			Charges_Hint(ID);
		//Specific one
		end else begin
			Charges_Bubble(a, player[ID].DetonationQueue);
			Charges_Pop(player[ID].DetonationQueue);
		end;
		if (charge[a].placed) and (charge[a].remote) then begin
			charge[a].timer := 0;
			WriteConsole(ID, 'Charge['+IntToStr(a+1)+'] activated! Placed charges left: ' + Charges_InGameInfo(a), GREEN);
		end else WriteConsole(ID, 'There is no charge with ID ' + IntToStr(a+1), RED);
	end;
end;

procedure Charges_Clear(a: byte);
var
	owner, i: integer;
begin
	owner := charge[a].owner;
	if owner > 0 then
	if Players[owner].Active then begin
		for i := 0 to player[owner].DetonationQueue.length - 1 do
			if a = player[owner].DetonationQueue.arr[i] then begin
				Charges_Bubble(a, player[owner].DetonationQueue);
				Charges_Pop(player[owner].DetonationQueue);
				break;
			end;
		Charges_Unmark(a);
	end;
	charge[a].X := 0;
	charge[a].Y := 0;
	charge[a].placed := false;
	charge[a].remote := false;
	charge[a].owner := 0;
	charge[a].timer := 0;
end;

end.
