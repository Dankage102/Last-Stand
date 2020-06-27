// * ------------------ *
// |      Scarecrow     |
// * ------------------ *

// This is a part of {LS} Last Stand. Explosive decoy luring zombies.

unit scarecrows;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Botwizard,
	Constants,
	Damage,
	Debug,
	Dummy,
	Globals,
	LSPlayers,
	MersenneTwister,
	Misc,
	PlacePlayer,
	Raycasts;

type
	tScarecrow = record
		ID, owner: byte;
		hp, LastHP, LureNum: integer;

	end;
	
var
	Scarecrow: tScarecrow;
	
procedure Scarecrow_TryPlace(ID: byte);

procedure Scarecrow_TryDetonate();

procedure Scarecrow_OnDamage(dmg: byte);

procedure Scarecrow_Process(maincall, call10: boolean);

procedure Scarecrow_Clear();

procedure Scarecrow_Kaboom();

implementation
	
var
	DetonateScarecrow: boolean;

function Scarecrow_TryPlaceX(ID: byte; xoffset: single; errors: boolean): boolean;
var
	b: boolean; i: byte; x, x2: single; sY: array[0..1] of single;
	NewPlayer: TNewPlayer;
begin
  x := Players[ID].X + xoffset;
  sY[0] := Players[ID].Y;
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
      Result := true;
  	end else
    	if errors then
    		WriteConsole(ID, 'You cannot build the scarecrow here, ground is too steep',RED);
  end else begin
  	if errors then
    	WriteConsole(ID, 'You cannot build the scarecrow on an edge', RED);
  end;
end;

procedure Scarecrow_TryPlace(ID: byte);
var i: integer;
begin
	if player[ID].Task = 4 then begin
		if Players[ID].Alive then begin
			if Players_OnGround(ID, true, 10) > 0 then begin
				if player[ ID ].task = 4 then begin
					if (player[ ID ].Scarecrows > 0) then begin
						if scarecrow.ID = 0 then begin
              for i := 1 to 5 do begin
              	if Scarecrow_TryPlaceX(ID, i, false) then exit;
                if Scarecrow_TryPlaceX(ID, -i, false) then exit;
              end;
              Scarecrow_TryPlaceX(ID, 0.1, true);
						end else WriteConsole(ID, 'There is one scarecrow in game', RED);
					end else WriteConsole(ID, 'You do not have any scarecrows left', RED);
				end else WriteConsole(ID, 'You are not the farmer ', RED);
			end else WriteConsole(ID, 'You have to be on the ground to place a scarecrow', RED);
		end else WriteConsole(ID, 'You have to be alive to place a scarecrow', RED);
	end else WriteConsole(ID, 'You are not the farmer', RED);	
end;

procedure Scarecrow_NailBomb(X, Y, v: single; n, style, owner: integer);
var
	i: integer;
begin
  for i := 1 to n do begin
    CreateBulletX(X, Y, v*RandFlt(-1, -0.33), v*RandFlt(-0.2, -0.6), -10, style, owner);
    CreateBulletX(X, Y, v*RandFlt(0.33, 1),   v*RandFlt(-0.2, -0.6), -10, style, owner);
  end;
end;

procedure Scarecrow_UnlureZombie(ID: integer);
begin
  player[ID].LuredByScarecrow := false;
  players[ID].Dummy := false;
end;

procedure Scarecrow_UnlureAll();
var i: integer;
begin
  for i := 1 to MaxID do begin
    if player[i].LuredByScarecrow then begin
       Scarecrow_UnlureZombie(i);
    end;
  end;
end;

procedure Scarecrow_Kaboom();
var
  x, y: single;
  owner: integer;
begin
  owner := scarecrow.owner;
	X := Players[scarecrow.ID].X;
	Y := Players[scarecrow.ID].Y-10;
	Damage_ZombiesAreaDamage(scarecrow.owner, x, y, 5, 100, 1000, Explosion);
	CreateBulletX(X, Y, 0, 0, 10, 4, scarecrow.owner);
  CreateBulletX(X+RandFlt(-15, 15), Y+5, 0, 0, 10, 4, scarecrow.owner);
  //Fire_CreateBurningArea(x, y, 8, 80, 8, 4, scarecrow.owner);
	player[scarecrow.ID].kicked := true;
	Players[scarecrow.ID].Kick(TKickSilent);
  Scarecrow_NailBomb(X, Y, 5.0,  2, 14, owner);
  Scarecrow_NailBomb(X, Y, 10.0, 3, 1,  owner);
  Scarecrow_NailBomb(X, Y, 18.0, 2, 3,  owner);
  Scarecrow_UnlureAll();
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

// 6 Hz
procedure Scarecrow_Process(maincall, call10: boolean);
var
  X, Y, X2, Y2, r, dx, dy: single;
  i, lured: integer;
  dmg: boolean;
begin
	if scarecrow.ID > 0 then begin
		if DetonateScarecrow then begin
			DetonateScarecrow := false;
			Scarecrow_Kaboom();
			WriteConsole(0, 'The farmer has detonated a scarecrow', GREEN);
      exit;
		end;

		if call10 then begin
			CheckDummyOnFlag(scarecrow.ID);
		end;
		X := Players[scarecrow.ID].X;
		Y := Players[scarecrow.ID].Y-10.0;
    lured := scarecrow.LureNum;
    scarecrow.LureNum := 0;
		for i := 1 to MaxID do begin
			//if Players[i].Active then
			if Players[i].Alive then
			if player[i].Zombie then
      if player[i].ScarecrowLureImmunity = 0 then begin
        X2 := Players[i].X;
        Y2 := Players[i].Y-10.0;
        dx := X2 - X;
				r := Math.Abs(dx);
				if r < 100.0 then begin
        	dy := Y2 - Y;
          if Math.Abs(dy) < 50.0 then begin
            if RayCast(X, Y, X2, Y2, true, false, false) then begin
					    if not player[i].Boss then begin
                scarecrow.LureNum := scarecrow.LureNum + 1;
                if player[i].Task <> 0 then
                  scarecrow.LureNum := scarecrow.LureNum + 2;

                // make it lure the zombies
                if player[i].LuredByScarecrow = false then begin
                  player[i].LuredByScarecrow := true;
                  players[i].Dummy := true;
             	    Players[i].KeyUp := false;
            	    Players[i].KeyJetpack := false;
                  Players[i].KeyShoot := true;
                end;

                // spontaneous unlure
                if lured > 8 then
                if RandInt_(2000) < lured then begin
                  if player[i].Task = 0 then begin
                    player[i].ScarecrowLureImmunity := RandInt(2, 14);
                  end else begin
                    player[i].ScarecrowLureImmunity := RandInt(5, 17);
                  end;
                end;

						    players[i].MouseAimX := Trunc(X);
						    players[i].MouseAimY := Trunc(Y);
                if RandFlt_()-0.2 > r/20.0 then begin
                	Players[i].KeyLeft := false;
                  Players[i].KeyRight := false;
                end else begin
                  if Players[i].X > X then begin
                    Players[i].KeyLeft := true;
                    Players[i].KeyRight := false;
                  end else begin
                    Players[i].KeyLeft := false;
                    Players[i].KeyRight := true;
          	      end;
                end;
                if not dmg then
						    if r < 20.0 then begin
							    Scarecrow_OnDamage(1 + lured div 6);
							    dmg := true;
						    end;

                // If zombie is getting away from the scare and is being shot
                // distract it from the scarecrow
                if r > 10.0 then
                if player[i].HurtTime + 2 >= Timer.Value then begin
                  player[i].ScarecrowLureImmunity := RandInt(2, 15);
                end
					    end;
            end else begin
            	if player[i].LuredByScarecrow then
              	Scarecrow_UnlureZombie(i);
            end;
          end else begin
          	if player[i].LuredByScarecrow then
            	Scarecrow_UnlureZombie(i);
          end;
        end else begin
          if player[i].LuredByScarecrow then
            Scarecrow_UnlureZombie(i);
        end;
      end else begin
        player[i].ScarecrowLureImmunity := player[i].ScarecrowLureImmunity - 1;
        if player[i].LuredByScarecrow then
          Scarecrow_UnlureZombie(i);
      end
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
    scarecrow.LureNum := 0;
		Scarecrow_UnlureAll();
  end;
end;

end.
