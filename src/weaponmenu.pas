unit WeaponMenu;

// Player's weapon menu enhanced handler.
// The module provides functions controling players weapon menu and ensures that
// he always selects only allowed weapon after spawn.
// It also ensures that packets will be sent twice, and not all at once to reduce chance of packetloss.

// by tk

interface
uses
	{$ifdef FPC}
		Scriptcore,
  {$endif}
  Misc;

type WeaponMenu_WeaponChoiceCallback = procedure(ID, Pri, Sec: Byte);

// Enable or disable weapon for the player
procedure WeaponMenu_SwitchWeapon(ID, Weap: byte; State: boolean);

// Is the player currently in menu getting weapon?
function WeaponMenu_IsGettingWeapon(ID: byte): boolean;

// Restores/updates all weapons in menu
procedure WeaponMenu_RefreshAll(ID: byte);

// Activates all weapons in menu
procedure WeaponMenu_EnableAll(ID: byte);

// Init the module
// @param WeaponTakenCallback for the TookWeapon function
// @param interval WeaponMenu_OnTick() will be called with
procedure WeaponMenu_Init(WeaponTakenCallback: WeaponMenu_WeaponChoiceCallback; OnTickInterval: integer);

// Events, these must be called from the main script by user.
procedure WeaponMenu_OnPlayerRespawn(ID: byte);
procedure WeaponMenu_OnTick();
procedure WeaponMenu_OnWeaponChange(ID, Primary, Secondary: byte);


implementation

const
	WEAPONMENU_SEND_REPEATS_NUM = 2;
	MAXOBJ = 50;  // for now

type
	tWMWeap = record
		Enabled: boolean;
		Refreshn: integer;
	end;
	
	tWMPlayer = record
		Weapons: array[1..14] of tWMWeap;
		RX: single;
		FirstToUpdate: integer;
		Updating: boolean;
		GettingWeapon: boolean;
		Respawning: boolean;
	end;
	
var
	WMP: array[1..32] of tWMPlayer;
	WeapTakenCB: WeaponMenu_WeaponChoiceCallback;
	Working: boolean;
	UpdatesPerCycle: integer;

function WeaponMenu_UpdateCycle(ID: byte): boolean;
var i, j: integer; max_iter: integer;
begin
	if (ID < 1) or (ID > 32) then begin
		writeln('wm exit: uc');
		exit;
	end;
	max_iter := UpdatesPerCycle;
	// Roll through players menu
	i := WMP[ID].FirstToUpdate;
	for j := 1 to 14 do begin
		if (WMP[ID].Weapons[i].Refreshn > 0) then begin
			WMP[ID].Weapons[i].Refreshn := WMP[ID].Weapons[i].Refreshn - 1;
			// Remember if there is still something left to update
			result := (WMP[ID].Weapons[i].Refreshn > 0) or result;
			// Send SetWeaponActive packet
			//writeconsole(0, 'swa ' + inttostr(i) + ' ' + iif(WMP[ID].Weapons[i].Enabled, 't', 'f'), $ffffff);
			Players[ID].WeaponActive[i] := WMP[ID].Weapons[i].Enabled;
			max_iter := max_iter - 1;
		end;
		i := i mod 14;
		i := i + 1;
		if max_iter <= 0 then break;
	end;
	WMP[ID].FirstToUpdate := i;
end;
	
procedure WeaponMenu_SwitchWeapon(ID, Weap: byte; State: boolean);
begin
	if (ID < 1) or (ID > 32) then begin
		writeln('wm exit: re');
		exit;
	end;
	if (Weap < 1) or (Weap > 14) then begin
		writeln('wm exit: re2');
		exit;
	end;
	WMP[ID].Weapons[Weap].Enabled := State;
	WMP[ID].Weapons[Weap].Refreshn := WEAPONMENU_SEND_REPEATS_NUM;
	WMP[ID].Updating := true;
	WMP[ID].FirstToUpdate := Weap;
	Working := true;
end;

procedure WeaponMenu_EnableAll(ID: byte);
var i: byte;
begin
	if (ID < 1) or (ID > 32) then begin
		writeln('wm exit: ea');
		exit;
	end;
	for i := 1 to 14 do begin
		WMP[ID].Weapons[i].Refreshn := WEAPONMENU_SEND_REPEATS_NUM;
		WMP[ID].Weapons[i].Enabled := true;
	end;
	WMP[ID].FirstToUpdate := 1;
	WMP[ID].Updating := true;
end;

function WeaponMenu_IsGettingWeapon(ID: byte): boolean;
begin
	if (ID < 1) or (ID > 32) then begin
		writeln('wm exit: igw');
		exit;
	end;
	result := WMP[ID].GettingWeapon;
end;

procedure WeaponMenu_EnforceWeapon(ID: byte);
begin
	if (ID < 1) or (ID > 32) then begin
		writeln('wm exit: ew');
		exit;
	end;
	WeaponMenu_OnWeaponChange(ID, Players[ID].Primary.WType, Players[ID].Secondary.WType);
	WMP[ID].GettingWeapon := false;
  {$ifndef FPC}
  if WeapTakenCB <> nil then
		WeapTakenCB(ID, Players[ID].Primary.WType, Players[ID].Secondary.WType);
  {$endif}
end;

procedure WeaponMenu_RefreshAll(ID: byte);
var i: byte;
begin
	if (ID < 1) or (ID > 32) then begin
		writeln('wm exit: ra');
		exit;
	end;
	for i := 1 to 14 do begin
		WMP[ID].Weapons[i].Refreshn := WEAPONMENU_SEND_REPEATS_NUM;
	end;
	WMP[ID].FirstToUpdate := 1;
	WMP[ID].Updating := true;
	Working := true;
end;

function WeaponMenu_GetAllowedWeapon(ID, Weap: byte): byte;
var menu_weap, i: byte;
begin
	result := WTYPE_NOWEAPON;
	try
		menu_weap := weap2menu(Weap);
	except
		exit;
	end;
	if (menu_weap >= 1) and (menu_weap <= 10) then begin
		if WMP[ID].Weapons[menu_weap].Enabled then begin
			result := weap;
		end else begin
			for i := 1 to 10 do begin
				if WMP[ID].Weapons[menu_weap].Enabled then begin
					result := menu2weap(i);
					break;
				end;
			end;
		end;
	end else
	if (menu_weap >= 11) and (menu_weap <= 14) then begin
		if WMP[ID].Weapons[menu_weap].Enabled then begin
			result := weap;
		end else begin
			for i := 11 to 14 do begin
				if WMP[ID].Weapons[menu_weap].Enabled then begin
					result := menu2weap(i);
					break;
				end;
			end;
		end;
	end;
	// If he chose disabled weapon, refresh it in menu
	if Weap <> result then begin
		WMP[ID].Weapons[menu_weap].Refreshn := WEAPONMENU_SEND_REPEATS_NUM;
		WMP[ID].Updating := true;
		WMP[ID].FirstToUpdate := menu_weap;
		Working := true;
	end;
end;

procedure WeaponMenu_Init(WeaponTakenCallback: WeaponMenu_WeaponChoiceCallback; OnTickInterval: integer);
begin
	WeapTakenCB := WeaponTakenCallback;
	UpdatesPerCycle := OnTickInterval;
end;

procedure WeaponMenu_OnPlayerRespawn(ID: byte);
begin
	if (ID < 1) or (ID > 32) then begin
		writeln('wm exit: opr');
		exit;
	end;
	WMP[ID].GettingWeapon := true;
	WMP[ID].Respawning := true;
end;

procedure WeaponMenu_OnTick();
var i: integer;
begin
	
	// If there are still some players with menus to update
	if Working then begin
		Working := false;
		for i := 1 to MaxID do begin
			if WMP[i].Updating then begin
				WMP[i].Updating := WeaponMenu_UpdateCycle(i);
			end;
			if WMP[i].GettingWeapon then begin
				if WMP[i].Respawning then begin
					WMP[i].Respawning := false;
					WMP[i].RX := Players[i].X;
				end else
				if Abs(WMP[i].RX-Players[i].X) > 33.0 then begin
					WeaponMenu_EnforceWeapon(i);
				end;
			end;
			Working := (Working) or (WMP[i].Updating) or (WMP[i].GettingWeapon);
		end;
	end;
end;

procedure WeaponMenu_OnWeaponChange(ID, Primary, Secondary: byte);
var p, s, i: byte;
begin
	if (ID < 1) or (ID > 32) then begin
		writeln('wm exit: owc');
		exit;
	end;
	if WMP[ID].GettingWeapon then begin
		// Protection against throwing weapon on spawn
		if (Primary = WTYPE_NOWEAPON) then begin
			if (Players[ID].Secondary.WType = Secondary) and (Players[ID].Primary.WType <> WTYPE_NOWEAPON) then
			begin
				//Kill the weapon he dropped
				for i := 1 to MAXOBJ do
				if Map.Objects[i].Active then
				if Distance(Map.Objects[i].X, Map.Objects[i].Y, Players[ID].X, Players[ID].Y) <= 50.0 then
				try
					if obj2weap(Map.Objects[i].Style) = Players[ID].Primary.WType then
					begin
						Map.Objects[i].Kill();
						break;
					end;
				except
				end;
				//Give it back to him
				Weapons_Force(ID, Players[ID].Primary.Wtype, Secondary, Players[ID].Primary.Ammo, 255);
			end;

		end else begin
			p := WeaponMenu_GetAllowedWeapon(ID, Primary);
			s := WeaponMenu_GetAllowedWeapon(ID, Secondary);
			//writeconsole(0, 'WeaponMenu_OnWeaponChange ' + inttostr(primary) + '>' + inttostr(p) + ' ' +inttostr(secondary) + '>' + inttostr(s) + ' ', $ffffff);
			if (p <> Primary) or (s <> Secondary) then begin
				Weapons_Force(ID, p, s, 255, 255);
			end;
		end;
	end;
end;

begin
end.
