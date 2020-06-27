// * ------------------ *
// |      Scarecrow     |
// * ------------------ *

// This is a part of {LS} Last Stand. Explosive decoy luring zombies.

unit Scarecrow;

interface

uses
	Constants,
	Dummy,
	Raycast,
	Players,
	Globals,
	Charges,
	Damage;

type
	tScarecrow = record
		ID, owner: byte;
		hp, LastHP: smallint;
	end;
	
var
	Scarecrow: tScarecrow;
	
procedure Scarecrow_TryPlace(ID: byte);

procedure Scarecrow_TryDetonate();

procedure Scarecrow_OnDamage(dmg: byte);

procedure Scarecrow_Process();

procedure Scarecrow_Clear();

implementation
	
var
	DetonateScarecrow: boolean;

procedure Scarecrow_TryPlace(ID: byte);
var
	b: boolean; i: byte; x, x2: single; sY: array[0..1] of single;
	NewPlayer: TNewPlayer;
begin
	if player[ID].Task = 4 then begin
		if Players[ID].Alive then begin
			if Players_OnGround(ID, true, 10) > 0 then begin
				if player[ ID ].task = 4 then begin
					if ( player[ ID ].Scarecrows > 0 ) then begin
						if scarecrow.ID = 0 then
						begin
							GetPlayerXY(ID, x, sY[0] );
							RayCast2(0, 2.5, 10, x, sY[0]);
							sY[0] := sY[0] - 10;
							sY[1] := sY[0];
							for i := 0 to 1 do begin
								x2 := x - (2*i - 1) * 10;
								b := (b) or (RayCast2(0, 2, 30, x2, sY[i]));
							end;
							if not b then begin
								if Abs(sY[0] - sY[1]) <= 13 then begin
									NewPlayer := BW_CreateScarecrow(HackermanMode);
									try
										scarecrow.ID := PutBot(NewPlayer, x, sY[0] + 5, 3).ID;
									finally
										NewPlayer.Free;
									end;
									if scarecrow.ID > MaxID then MaxID := scarecrow.ID;
									scarecrow.owner := ID;
									scarecrow.hp := SCARECROW_HITPOINTS;
									scarecrow.LastHP := 0;
									DetonateScarecrow := false;
									player[ID].Scarecrows := player[ ID ].Scarecrows - 1;
									Weapons_Force(scarecrow.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
									WriteDebug(3, 'scarecrow placed');
									WriteConsole( 0, 'Farmer ' + Players[ID].Name + ' has placed a scarecrow', GREEN);
									WriteConsole(ID, 'Type /act (default Alt+4) to detonate the scarerow', GREEN);
									WriteConsole(ID, IntToStr(player[ID].Scarecrows) + ' scarecrows left', GREEN);
								end else WriteConsole(ID, 'You cannot build the scarecrow here, ground is too steep',RED);
							end else begin
								WriteConsole(ID, 'You cannot build the scarecrow on an edge', RED);
								b := false;
							end;
						end else WriteConsole(ID, 'There is one scarecrow in game', RED);
					end else WriteConsole(ID, 'You do not have any scarecrows left', RED);
				end else WriteConsole(ID, 'You are not the farmer ', RED);
			end else WriteConsole(ID, 'You have to be on the ground to place a scarecrow', RED);
		end else WriteConsole(ID, 'You have to be alive to place a scarecrow', RED);
	end else WriteConsole(ID, 'You are not the farmer', RED);	
end;

procedure Scarecrow_Kaboom();
var x, y: single;
begin
	X := Players[scarecrow.ID].X;
	Y := Players[scarecrow.ID].Y;
	Damage_ZombiesAreaDamage(scarecrow.owner, x, y, 40, 175, 4000, Explosion);
	Charge_Explosion(x, y, 40, 9, scarecrow.owner);
	Fire_CreateBurningArea(x, y, 15, 120, 11, 6, scarecrow.owner);
	player[scarecrow.ID].kicked := true;
	Players[scarecrow.ID].Kick(TKickSilent);
end;

procedure Scarecrow_OnDamage(dmg: byte);
var
	hp: smallint;
begin
	scarecrow.hp := scarecrow.hp - dmg;
	if scarecrow.hp <= 0 then begin
		Scarecrow_Kaboom();
		WriteConsole(0, 'Zombies have destroyed a scarecrow', RED);
	end else begin
		hp := Trunc(5.0 * scarecrow.hp / SCARECROW_HITPOINTS + 0.99);
		if hp <> scarecrow.LastHP then begin
			scarecrow.LastHP := hp;
			Botchat(scarecrow.ID, '^'+StringOfChar('=', hp) + StringOfChar('-', 5 - hp));
		end;
	end;
end;

procedure Scarecrow_TryDetonate();
begin
	if scarecrow.ID > 0 then begin
		DetonateScarecrow := true;
	end;
end;

procedure Scarecrow_Process();
var X, Y, r: single; i: byte; dmg: boolean;
begin
	if scarecrow.ID > 0 then begin
		if DetonateScarecrow then begin
			DetonateScarecrow := false;
			Scarecrow_Kaboom();
			WriteConsole(0, 'The farmer has detonated a scarecrow', GREEN);
		end else
		
		if scarecrow.ID > 0 then begin
			if (Timer.Value div 60) mod 10 = 1 then begin
				CheckDummyOnFlag(scarecrow.ID);
			end;
			X := Players[scarecrow.ID].X;
			Y := Players[scarecrow.ID].Y;
			for i := 1 to MaxID do begin
				if Players[i].Active then
				if Players[i].Alive then
				if player[i].Zombie then begin
					r := Distance(Players[i].X, Players[i].Y, X, Y);
					if r < 100.0 then
					if not player[i].Boss then begin
						// make it lure the zombies
						players[i].Damage(scarecrow.ID, 1);
						players[i].MouseAimX := Trunc(X);
						players[i].MouseAimY := Trunc(Y);
						if not dmg then
						if r < 20.0 then begin
							Scarecrow_OnDamage(1);
							dmg := true;
						end;
					end;
				end;
			end;
		end;
	end;
end;

procedure Scarecrow_Clear();
begin
	if scarecrow.ID > 0 then begin
		player[scarecrow.ID].kicked := true;
		Players[scarecrow.ID].Kick(TKickSilent);
		scarecrow.ID := 0;
		scarecrow.owner := 0;
		scarecrow.hp := 0;
	end;
end;
