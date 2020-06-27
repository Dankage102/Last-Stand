// * ------------------ *
// |    Base weapons    |
// * ------------------ *

// This is a part of {LS} Last Stand. The unit is responsible for Advanced Weapon System.

unit BaseWeapons;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Bigtext,
	Constants,
	lsplayers,
	Misc,
	Globals,
	Weapons,
	BaseFlag,
	Tasks,
	Raycasts,
	WeaponMenu;

type
	tLSWeapon = record
		Num, Cost: integer;
		Used, Buyable: boolean;
	end;
	
	tWeaponSystem = record
		Enabled: boolean;
	end;
	
var
	Weapon: array[1..15] of tLSWeapon;
	WeaponSystem: tWeaponSystem;

// Generate a list of weapons that the player may use at this moment
// It will later be used to configure his weaponmenu.
procedure BaseWeapons_RefreshActive();

procedure BaseWeapons_AddTaskWeapons(ID: byte);
							
procedure BaseWeapons_Refresh(OnStart: boolean);

procedure BaseWeapons_Add(Weap: byte; Num: integer; Owner: byte);	//Owner should not be told of "new weapon in base" -> call with 0 if no owner

// This must be called from OnWeaponChange event.
procedure BaseWeapons_OnWeaponChange(ID, PrimaryNum, SecondaryNum: byte);

// This must be called from OnPlayerRespawn event.
procedure BaseWeapons_OnPlayerRespawn(ID: byte);

// Kills weapon objects in base
procedure BaseWeapons_ClearBase();
	
// Called from WeaponMenu unit as a callback.
procedure Baseweapons_OnWeaponTake(ID, Primary, Secondary: byte);

// If a player /gets a weapon from base
procedure BaseWeapons_Get(ID: byte);

// Called on player from AppOnIdle
procedure BaseWeapons_ProcessPlayer(ID: byte);

procedure BaseWeapons_Init(Enabled: boolean);

implementation

const 	BASE_RANGE = 75.0;

// Generate a list of weapons that the player may use at this moment
// It will later be used to configure his weaponmenu.
procedure BaseWeapons_RefreshActive();
var i, j: byte;
	other_menus: array [1..14] of byte;
	task_weap: array [1..14] of boolean;
	has_something: boolean;
begin
	// Count weapons that might be taken out of menu, at this moment, by other players.
	for j := 1 to MaxID do begin
		if player[j].Participant = 1 then begin
			if (WeaponMenu_IsGettingWeapon(j)) or (player[j].Status = 2) then begin
				for i := 1 to 14 do begin
					if player[j].ActiveWeapons[i] then
						other_menus[i] := other_menus[i] + 1;
				end;
			end;
			// Is the weapon associated with particular task?
			for i := 1 to 14 do begin
				if player[j].ActiveWeapons[i] then
					task_weap[i] := true;
			end;
		end;
	end;
	// Let the player take other task weapon only if there are more such than one.
	for i := 1 to 14 do begin
		if other_menus[i] = 0 then other_menus[i] := 1;
	end;
	for j := 1 to MaxID do begin
		if player[j].Participant = 1 then begin
			has_something := false;
			for i := 1 to 14 do begin
					player[j].TempActiveWeapons[i] := 
						((not task_weap[i]) and (Weapon[i].Num > 0)) or
						(player[j].ActiveWeapons[i] and ((Weapon[i].Num > 0) or (Weapon[i].Num = -1))) or 
						(Weapon[i].Num > other_menus[i]);
					has_something := has_something or player[j].TempActiveWeapons[i];
			end;
			// If for some reason he's got no weapon to choose, give him a socom
			// not to block his menu.
			if has_something = false then
				player[j].TempActiveWeapons[11] := true;
		end;
	end;
end;

procedure BaseWeapons_AddTaskWeapons(ID: byte);
var i: byte;
begin
	for i := 1 to 14 do
		if Player[ID].ActiveWeapons[i] then begin
			if Weapon[i].Num > -1 then
				Weapon[i].Num := Weapon[i].Num + 1;
			Weapon[i].Used := true;
		end;
end;
						
procedure BaseWeapons_Refresh(OnStart: boolean);
var i, j: byte;
begin // decide what weapons are for all, what only for certain tasks
 	if OnStart then begin
		for i := 1 to 14 do
			if Weapon[i].Num > -1 then begin
				Weapon[i].Num := 0;
			end;
		for j := 1 to MaxID do begin
			if player[j].Participant = 1 then
				BaseWeapons_AddTaskWeapons(j);
		end;
	end else
		for i := 1 to 14 do begin	
			Weapon[i].Used := false;
			for j := 1 to MaxID do
				if player[j].Participant = 1 then
					if Player[j].ActiveWeapons[i] then begin
						Weapon[i].Used := true;
						break;
					end;
		end;
	BaseWeapons_RefreshActive();
end;

procedure BaseWeapons_Add(Weap: byte; Num: integer; Owner: byte);	//Owner should not be told of "new weapon in base" -> call with 0 if no owner
var i: byte; was_zero: boolean;
begin
	was_zero := (Weapon[Weap].Num = 0);
	Weapon[Weap].Num := Weapon[Weap].Num + Num;
	if Weapon[Weap].Num <= 0 then Weapon[Weap].Num := 0;
	BaseWeapons_RefreshActive();
	if Num > 0 then begin
		for i := 1 to MaxID do 
			if player[i].Status = 1 then
			if player[i].TempActiveWeapons[Weap] then begin
				WeaponMenu_SwitchWeapon(i, Weap, true);
				if i <> Owner then
				if was_zero then
				if not WeaponMenu_IsGettingWeapon(i) then
					WriteConsole(i, 'New weapon (' + WeaponName(menu2weap(Weap)) + ') in base, go to the base flag to /get it', NWSCOL);
			end;
	end else
		if Weapon[Weap].Num <= 0 then
		for i := 1 to MaxID do // update if someone has menu open at the moment
			if player[i].Status = 1 then
			if not player[i].TempActiveWeapons[Weap] then begin
				WeaponMenu_SwitchWeapon(i, Weap, false);
			end;
end;

//|| Dropping a weapon close to base -> putting it in
procedure BaseWeapons_OnWeaponChange(ID, PrimaryNum, SecondaryNum: byte);
var X, Y: single; i, tmp: byte;
begin
	//writeconsole(0, 'Baseweapons_Weapons_OnWeaponChange(' + inttostr(ID) + ' ' + inttostr(primarynum) + ' ' + inttostr(secondarynum) + ') ' + inttostr(ServerForceWeapon), orange);//asdasd
	if Base.Found then
	if PrimaryNum = WTYPE_NOWEAPON then
	if SecondaryNum = Players[ID].Secondary.WType then
	if Weapons_IsRegular(Players[ID].Primary.Wtype) then
	if Players[ID].Primary.Wtype <> WTYPE_MINIGUN then
	if not WeaponMenu_IsGettingWeapon(ID) then
	begin
		GetPlayerXY(ID, X, Y);
		if Distance(X, Y, Base.X, Base.Y) <= BASE_RANGE then
		begin
			if not Player[ID].JustResp then
			begin
				BaseWeapons_Add(weap2menu(Players[ID].Primary.WType), 1, ID);
				WriteConsole(ID, WeaponName(Players[ID].Primary.WType) + ' put back into base.', NWSCOL);
			end;
		
			//Kill the weapon he's about to drop
			for i := 1 to MAX_OBJECTS do begin
				if Map.Objects[i].Active then
				if PointsInRange(Map.Objects[i].X, Map.Objects[i].Y, X, Y, 50, false) then
				try
					tmp := obj2weap(Map.Objects[i].Style);
					if Players[ID].Primary.WType = tmp then
					begin
						Map.Objects[i].Kill();
						break;
					end;
				except
				end;
			end;
		end;
	end;
end;

procedure BaseWeapons_OnPlayerRespawn(ID: byte);
var i, t: byte; str: string;
begin
	if WeaponSystem.Enabled then begin
		BaseWeapons_RefreshActive();
		for i := 1 to 14 do begin
			WeaponMenu_SwitchWeapon(ID, i, player[ID].TempActiveweapons[i]);
		end;
	
		t := 0;
		str := 'Weapons in base:'+ #13#10;
		for i := 1 to 14 do
			//if Weapon[i].Num > -1 then
			if Weapon[i].Num > 0 then begin
				if player[ID].TempActiveWeapons[i] then begin
					str := str + IntToStr(Weapon[i].Num) + 'x ' + WeaponName(menu2weap(i)) + #13#10;
					t := t + 1;
				end;
			end;
		if t = 0 then begin
			t := 1;
			str := 'You have no weapons';
			if ID = Cop.ID then begin
				str := str + #13#10 + 'Type /weaps to buy some';
			end else begin
				str := str + #13#10 + 'Ask the Police Officer to buy some';
			end;
		end;
		BigText_DrawScreenX(DTL_WEAPONLIST, ID, str, 150, NWSCOL, 0.08 - 0.002*t, 20, 370 - 10*t);
	end;
end;

procedure BaseWeapons_ClearBase();
var i, style: byte;
begin
	for i := 1 to MAX_OBJECTS do
		if Map.Objects[i].Active then
		if Distance(Map.Objects[i].x, Map.Objects[i].y, Base.X, Base.Y) <= BASE_RANGE then begin
			//Is it a weapon?
			style := Map.Objects[i].Style;
			if ((style > 3) and (style < 27)) then
			if ((style < 15) or (style > 23)) then
			begin
				Map.Objects[i].Kill();
			end;
		end;
end;
	
// Called from WeaponMenu unit
procedure Baseweapons_OnWeaponTake(ID, Primary, Secondary: byte);
var po, so, i: byte; pr, sr: boolean; str: string;
begin
	if player[ID].Status <> 1 then exit;
	
	// If he's the mechanic, give him a flamer
	if Player[ID].ActiveWeapons[15] then begin
		if (Players[ID].Secondary.WType = WTYPE_NOWEAPON) then begin
			Weapons_Force(ID, Players[ID].Primary.WType, WTYPE_FLAMER, Players[ID].Primary.Ammo, 255);
		end else 
		if (Players[ID].Primary.WType = WTYPE_NOWEAPON) then begin
			Weapons_Force(ID, WTYPE_FLAMER, Players[ID].Secondary.WType, 255, players[ID].Secondary.Ammo);
		end else
		if (Players[ID].Secondary.WType = WTYPE_USSOCOM) then begin
			Weapons_Force(ID, Players[ID].Primary.WType, WTYPE_FLAMER, Players[ID].Primary.Ammo, 255);
		end
	end;
	
	//|| Take Weapons out of base
	if WeaponSystem.Enabled then
	begin
		pr := false;
		if (Primary <> WTYPE_NOWEAPON) then begin
			po := weap2menu(Primary);
			if (po > 0) and (po < 15) then
				pr := (Weapon[po].Num > -1);
			if pr then BaseWeapons_Add(po, -1, 0);
		end;
		sr := false;
		if (Secondary <> WTYPE_NOWEAPON) then begin
			so := weap2menu(Secondary);
			if (so > 0) and (so < 15) then
				sr := (Weapon[so].Num > -1); // -1 is inf
			if sr then BaseWeapons_Add(so, -1, 0);
		end;
		
		if (pr) or (sr) then
		begin
			str := '';
			if (pr) then str := str + IntToStr(Weapon[po].Num) + 'x ' + WeaponName(Primary);
			if (pr) and (sr) then str := str + ', ';
			if (sr) then str := str + IntToStr(Weapon[so].Num) + 'x ' + WeaponName(Secondary);
			WriteConsole(ID, str + ' left in Base.', NWSCOL);
		end;
		
		if Cop.ID > 0 then begin
			for i := 1 to 10 do
				if Weapon[i].Num > 0 then
					if player[ID].TempActiveWeapons[i] then
						exit;
			if ID = Cop.ID then begin
				WriteConsole(Cop.ID, 'You have run out of weapons!', NWSCOL);
			end else begin
				WriteConsole(Cop.ID, TaskToName(Player[ID].Task, false) + ' ' + Players[ID].Name + ' has run out of weapons!', NWSCOL);
			end;
			str := 'Type "/buy';
			for i := 1 to 10 do
				if player[ID].ActiveWeapons[i] then
					str := str + ' ' + ShortWeapName(i);
			str := str + '" to buy weapons';
			WriteConsole(Cop.ID, str, NWSCOL);
		end;
	end;		
end;

procedure BaseWeapons_Get(ID: byte);
var b, c: boolean;
begin
	if IsInRange(ID, Base.X, Base.Y, 110, false) then
	if not Player[ID].JustResp then
	begin
		b := Weapons_IsRegular(Players[ID].Primary.Wtype) and (Players[ID].Primary.Wtype <> WTYPE_MINIGUN);
		c := Weapons_IsRegular(Players[ID].Secondary.Wtype) and (Players[ID].Secondary.Wtype <> WTYPE_MINIGUN);
		if (b) or (c) then 
			WriteConsole(ID, iif(b, WeaponName(Players[ID].Primary.WType), '')
					+ iif((b) and (c), ' and ', '')
					+ iif(c, WeaponName(Players[ID].Secondary.WType), '')
					+ ' put back into base.', NWSCOL);
		if b then
			BaseWeapons_Add(weap2menu(Players[ID].Primary.WType), 1, ID);
		if c then
			BaseWeapons_Add(weap2menu(Players[ID].Secondary.WType), 1, ID);

		BaseWeapons_ClearBase();
		Weapons_Force(ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
		Player[ID].RespawnPlayer := True;
	end;
end;

procedure BaseWeapons_DrawWeaponList(ID: byte; AdditionalInfo: boolean; X, Y, incr: integer);
var str, str2: string;
	i, t: integer;
	scale: single;
begin
	for i := 1 to 14 do begin
		if (Weapon[i].Num > 0) then begin
			if (player[ID].TempActiveWeapons[i]) then begin
				str := str + IntToStr(Weapon[i].Num) + 'x ' + WeaponName(menu2weap(i)) + #13#10;
				str2 := str2 + #13#10;
			end else begin
				str2 := str2 + IntToStr(Weapon[i].Num) + 'x ' + WeaponName(menu2weap(i)) + #13#10;
				str := str + #13#10;
			end;
			t := t + 1;
		end;
	end;
	if AdditionalInfo then begin
		str := str + #13#10 + 'Type "/get" to pick new weapons';
		if player[ID].task = 6 then
			str := str + #13#10 + 'Type "/weap" to buy weapons for your team'; 
	end;
	Y := Y + incr*t;
	scale := 0.07 - 0.0015*t;
	BigText_DrawScreenX(DTL_WEAPONLIST, ID, str, 150, NWSCOL, scale, X, Y);
	BigText_DrawScreenX(DTL_WEAPONLIST2, ID, str2, 150, NWSCOL_INACT, scale, X, Y);
end;

procedure BaseWeapons_ProcessPlayer(ID: byte);
var InBase: boolean;
begin
	if (Base.Found) then begin
		InBase := (SqrDist(Players[ID].X, Players[ID].Y, Base.X, Base.Y) < 5625);
		if (InBase) or (WeaponMenu_IsGettingWeapon(ID)) then
		if not ((ID = Cop.ID) and (Cop.Shop.Active)) then begin
			if InBase then begin
				BaseWeapons_DrawWeaponList(ID, true, 20, 360, -10);
			end else begin
				BaseWeapons_DrawWeaponList(ID, false, 250, 60, 0);
			end;
		end;
	end;
end;

procedure BaseWeapons_Init(Enabled: boolean);
begin
	WeaponSystem.Enabled := Enabled;
	if WeaponSystem.Enabled then begin
		BaseWeapons_Refresh(true);
		Weapon[1].Cost := 1;
		Weapon[1].Buyable := true;
		 Weapon[2].Cost := 1;
		 Weapon[2].Buyable := true;
		Weapon[3].Cost := 2;
		Weapon[3].Buyable := true;
		 Weapon[4].Cost := 2;
		 Weapon[4].Buyable := true;
		Weapon[5].Cost := 3;
		Weapon[5].Buyable := true;
		 Weapon[6].Cost := 1;
		 Weapon[6].Buyable := true;
		Weapon[7].Cost := 2;
		Weapon[7].Buyable := true;
		 Weapon[8].Cost := 4;
		 Weapon[8].Buyable := false;
		Weapon[9].Cost := 2;
		Weapon[9].Buyable := true;
		 Weapon[10].Cost := 5;
		 Weapon[10].Buyable := true;
		Weapon[11].Cost := 0;
		Weapon[11].Buyable := false;
		Weapon[11].Num := -1;
		 Weapon[12].Cost := 0;
		 Weapon[12].Buyable := false;
		 Weapon[12].Num := -1;
		Weapon[13].Cost := 2;
		Weapon[13].Buyable := false;
		 Weapon[14].Cost := 2;
		 Weapon[14].Buyable := true;
		Weapon[15].Cost := 0;
		Weapon[15].Buyable := false;
	end else begin
		Weapon[1].Cost := 2;
		Weapon[1].Buyable := true;
		 Weapon[2].Cost := 2;
		 Weapon[2].Buyable := true;
		Weapon[3].Cost := 3;
		Weapon[3].Buyable := true;
		 Weapon[4].Cost := 3;
		 Weapon[4].Buyable := true;
		Weapon[5].Cost := 5;
		Weapon[5].Buyable := true;
		 Weapon[6].Cost := 2;
		 Weapon[6].Buyable := true;
		Weapon[7].Cost := 5;
		Weapon[7].Buyable := true;
		 Weapon[8].Cost := 4;
		 Weapon[8].Buyable := false;
		Weapon[9].Cost := 4;
		Weapon[9].Buyable := true;
		 Weapon[10].Cost := 5;
		 Weapon[10].Buyable := true;
		Weapon[11].Cost := 0;
		Weapon[11].Buyable := false;
		 Weapon[12].Cost := 0;
		 Weapon[12].Buyable := false;
		Weapon[13].Cost := 0;
		Weapon[13].Buyable := false;
		 Weapon[14].Cost := 5;
		 Weapon[14].Buyable := true;
		Weapon[15].Cost := 0;
		Weapon[15].Buyable := false;
	end;
end;

begin
end.
