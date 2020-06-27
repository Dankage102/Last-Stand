//  * -------------- *
//  |      Tasks     |
//  * -------------- *

// This is a part of {LS} Last Stand. Task related stuff.

unit Tasks;

interface

uses
	{$ifdef FPC}
		Scriptcore,
  {$endif}
  Constants,
	lsplayers,
  WeaponMenu,
  Globals,
  Misc;

const
	MAX_TASKS =		7;
	
function TaskToName(task: byte; zomb: boolean): string;

function TaskToShortName(task: byte; zomb: boolean): string;

procedure TaskInfo(ID: byte);

function SwitchTask(ID: byte; task: shortint): boolean;

function TaskStrToInt(s: string): byte;
	
implementation

function TaskToName(task: byte; zomb: boolean): string;
begin
	//if task >= 0 then begin
		if zomb then begin
			case task of
			0, 200: Result := 'Normal zombie';
			1: Result := 'Kamikaze zombie';
			2: Result := 'Vomiting zombie';
			3: Result := 'Undead Butcher';
			31: Result := 'Butcher part';
			4: Result := 'Burning zombie';
			5: Result := 'Perished Priest';
			6: Result := 'Firefighter';
			7: Result := 'Satan I';
			8: Result := 'Satan II';
			9: Result := 'Plague';
			11: Result := 'Kamikaze Boss';
			else Result := 'Unknown';
			end;
		end else begin
			case task of
			0: Result := 'None';
			1: Result := 'Mechanic';
			2: Result := 'Demolition Expert';
			3: Result := 'Doctor';
			4: Result := 'Farmer';
			5: Result := 'Sharpshooter';
			6: Result := 'Police Officer';
			7: Result := 'Priest';
			else Result := 'Unknown';
			end;
		end;
	//end;
end;

function TaskToShortName(task: byte; zomb: boolean): string;
begin
	//if task >= 0 then begin
		if zomb then begin
			case task of
			0, 200: Result := 'Zom';
			1: Result := 'Kami';
			2: Result := 'Vom';
			3: Result := 'Butch';
			31: Result := 'Part';
			4: Result := 'Burn';
			5: Result := 'PP';
			6: Result := 'FF';
			7: Result := 'S1';
			8: Result := 'S2';
			9: Result := 'Plag';
			11: Result := 'KB';
			else Result := 'Unknown';
			end;
		end else begin
			case task of
			0: Result := 'None';
			1: Result := 'Mech';
			2: Result := 'Demo';
			3: Result := 'Doc';
			4: Result := 'Farm';
			5: Result := 'Sharp';
			6: Result := 'Cop';
			7: Result := 'Pri';
			else Result := 'Unknown';
			end;
		end;
	//end;
end;

procedure TaskInfo(ID: byte);
begin
	if player[ID].Zombie then begin
		Case player[ID].task of			
			0: begin
				WriteConsole(ID, 'You are now a zombie', $FF6666);
			end;
			200: begin
				WriteConsole(ID, 'You are now a zombie', $FF6666);
				WriteConsole(ID, 'You regenerate while not moving', $FF6666);
			end;
			1: begin
				WriteConsole(ID, 'You are now a Kamikaze zombie. HOLD the [Grenade] key to explode', $FF3728);
			end;
			2: begin
				WriteConsole(ID, 'You are now a Vomiting zombie. HOLD the [Shoot] key to vomit', $99CC33 );
				WriteConsole(ID, 'HOLD the [Grenade] key to jump', $99CC33 );
			end;
			3: begin
				WriteConsole(ID, 'You are now the Undead Butcher', B_RED);
			end;
			31: begin
				WriteConsole(ID, 'You are now a little Butcher part', B_RED);
			end;
			4: begin
				WriteConsole(ID, 'You are now a Burning zombie. HOLD the [Shoot] key to breathe', $FF7830);
			end;
			5: begin
				WriteConsole(ID, 'You are now the Perished Priest. HOLD the [Grenade] key to attack a near enemy', $A070E0);
			end;
			6: begin
				WriteConsole(ID, 'You''re now the Undead Firefighter! Hold the key or type the command:', ORANGE);
				WriteConsole(ID, ' [Shoot] - cast the Heat', WHITE);
				WriteConsole(ID, ' [Grenade],  /cc1, /trap - creates a Trap', WHITE);
				WriteConsole(ID, ' [Reload], /cc3, /fire - creates the Groundfire', WHITE);
				WriteConsole(ID, 'To switch to automatic mode, use /auto', GREEN);
			end;
			7: begin
				WriteConsole(ID, 'You''re now Satan! Hold the key or type the command:', B_RED);
				WriteConsole(ID, ' [Shoot],   /cc1, /met - calls a meteor', WHITE);
				WriteConsole(ID, ' [Grenade], /cc2, /des - casts Desecration', WHITE);
				WriteConsole(ID, ' [Reload],  /cc3, /min - summons minions', WHITE);
				WriteConsole(ID, ' [Throw],   /cc4, /par - paralyses near target', WHITE);
				WriteConsole(ID, 'To switch to automatic mode, use the /auto command', GREEN);
			end;
			8: begin
				WriteConsole(ID, 'You''re now Satan! Hold the key or type the command:', B_RED);
				WriteConsole(ID, ' [Shot] - Casts the HellShower', WHITE);
				WriteConsole(ID, ' [Reload],     /cc1, /ring  - casts the Ring of Death', WHITE);
				WriteConsole(ID, ' [Throw],      /cc2, /arr   - casts the Arrow', WHITE);
				WriteConsole(ID, ' [ChangeWeap], /cc3  /rain  - casts the Hell Rain', WHITE);
				WriteConsole(ID, ' [Grenade],    /cc4, /burn  - burns near enemies', WHITE);
				WriteConsole(ID, 'To switch to automatic mode, use /auto command', GREEN);
			end;
			9: begin
				WriteConsole(ID, 'You''re now the Plague!', INFORMATION);
				WriteConsole(ID, ' Hold the [Change Weapon] key near dead zombies to revive them',INFORMATION);
				WriteConsole(ID, ' Hold the [Grenade] key to spawn a minion',INFORMATION);
				WriteConsole(ID, 'To switch to automatic mode, use /auto command', GREEN);
			end;
			11: begin
				WriteConsole(ID, 'You are now a Kamikaze Boss', $FF3728);
				WriteConsole(ID, ' HOLD the [Grenade] key to detonate yourself',INFORMATION);
			end;
			12: begin
				WriteConsole(ID, 'You are now a Veteran Zombie', $FF3728);
				WriteConsole(ID, 'Those bullets only scratch you little.',INFORMATION);
			end;
		end;
	end else
		Case player[ID].task of			
			1: begin
				WriteConsole(ID, 'You are now the Mechanic', WHITE );
				WriteConsole(ID, 'Type /mre   (default Alt+1) to eat your meal ready to eat',   INFORMATION );	
				WriteConsole(ID, 'Type /wire  (default Alt+2) to place a barbed wire', INFORMATION );
				WriteConsole(ID, 'Type /build (default Alt+3) to build a statgun, /get (Alt+4) to pick one up', INFORMATION );						
				WriteConsole(ID, 'Type /sentry to place a sentry gun, /get to pick one up', INFORMATION );						
			end;
			2: begin
				WriteConsole(ID, 'You are now the Demolition Expert', WHITE );
				WriteConsole(ID, 'Type /mine (default Alt+1) to place a landmine if you have one', INFORMATION );
				WriteConsole(ID, 'Type /place <time> to place a timed charge', INFORMATION );	
				WriteConsole(ID, 'Type /rch  (default Alt+2)to place a remote charge', INFORMATION );		
			end;
			3: begin
				WriteConsole(ID, 'You are now the Doctor',                         WHITE );				
				WriteConsole(ID, 'You can heal and revive dead players by switching weapons', INFORMATION );
				WriteConsole(ID, 'You autoheal if you do not move          ', INFORMATION );
			end;
			4: begin
				WriteConsole(ID, 'You are now a Farmer',                 WHITE );
				WriteConsole(ID, 'You have the highest resistance in your team',   INFORMATION );	;	
				WriteConsole(ID, 'Type /mre   (default Alt+1) to eat your meal ready to eat', INFORMATION );
				WriteConsole(ID, 'Type /scare (default Alt+3) to place a scarecrow (a decoy for zombies)', INFORMATION);
			end;
			5: begin
				WriteConsole(ID, 'You are now the Sharpshooter',                WHITE );
				WriteConsole(ID, 'You can throw Molotov cocktails (knifes)', INFORMATION );
				WriteConsole(ID, 'Type /mre (default Alt+1) to eat your meal ready to eat',   INFORMATION );	
			end;
			6: begin
				WriteConsole(ID, 'You are now the Police Officer',                        WHITE );
				WriteConsole(ID, 'You are the leader of the group. Your task is to order supplies',INFORMATION );
				WriteConsole(ID, 'Type /supply for a list of supplies you can order', INFORMATION );
				WriteConsole(ID, 'Type /mre to eat your meal ready to eat',      INFORMATION );	
			end;
			7: begin
				WriteConsole(ID, 'You are now the Priest',                        WHITE );
				WriteConsole(ID, 'You can use your holy water to destroy zombies.', INFORMATION );
				WriteConsole(ID, 'Type /shw (default Alt+2) to drop holy shower.', INFORMATION );
				WriteConsole(ID, 'Type /exo (default Alt+3) to start an exorcism.', INFORMATION );
			end;
		end;
end;

function SwitchTask(ID: byte; task: shortint): boolean;
var
	i: byte;
	Res: tResistance;
begin  
	player[ID].task := task;
	for i := 1 to 15 do
		player[ID].Activeweapons[i] := false;
		
	Case task of	
		1: begin // mechanic
			player[ID].mre := 1;
			player[ID].Wires := 3;
			player[ID].statguns := 1;
			player[ID].Activeweapons[1] := true;
			player[ID].Activeweapons[2] := true;
			player[ID].Activeweapons[15] := true; // flamer
			player[ID].DamageFactor := 1.0;
			Res.General := 1.4;
			mechanic := ID;
		end;
		2: begin // demo
			player[ID].Mines := 14;
			player[ID].charges := 8;				
			player[ID].Activeweapons[1] := true;
			player[ID].Activeweapons[7] := true;
			player[ID].Activeweapons[11] := true;
			player[ID].Activeweapons[14] := true;
			player[ID].DamageFactor := 1.0;
			Res.General := 1.4;
			DemoMan.ID := ID;
		end;
		3: begin // doc
			Medic.ID := ID;
			player[ID].Activeweapons[2] := true;
			player[ID].Activeweapons[3] := true;
			player[ID].Activeweapons[4] := true;			
			player[ID].Activeweapons[11] := true;
			player[ID].Activeweapons[14] := true;
			player[ID].DamageFactor := 1.1;
			Res.General := 3.0;
		end;
		4: begin  // farmer
			player[ID].mre := 2;
			player[ID].Scarecrows := 3;
			player[ID].Activeweapons[3] := true;
			player[ID].Activeweapons[5] := true;
			player[ID].Activeweapons[6] := true;
			player[ID].Activeweapons[13] := true;
			player[ID].DamageFactor := 1.4;
			Res.General := 2.5;
		end;
		5: begin // sharpshooter
			player[ID].mre := 1;
			player[ID].Activeweapons[8] := true;
			player[ID].Activeweapons[6] := true;
			player[ID].Activeweapons[11] := true;
			player[ID].Activeweapons[12] := true;
			player[ID].DamageFactor := 1.5;
			Res.General := 1.4;
			sharpshooter := ID;
			player[ID].Molotovs := 8;
		end;
		6: begin // police officer
			player[ID].mre := 2;
			player[ID].Activeweapons[3] := true;
			player[ID].Activeweapons[5] := true;
			player[ID].Activeweapons[9] := true;
			player[ID].Activeweapons[11] := true;
			player[ID].DamageFactor := 1.1;
			Res.General := 1.6;
			Cop.ID := ID;
		end;
		7: begin // priest
			player[ID].mre := 0;
			player[ID].Activeweapons[1] := true;
			player[ID].Activeweapons[3] := true;
			player[ID].Activeweapons[6] := true;
			player[ID].Activeweapons[11] := true;
			player[ID].DamageFactor := 1.0;
			Res.General := 1.4;
			Priest := ID;
			player[ID].HolyWater := 1000;
			player[ID].ExoTimer := 0;
		end;
	end;
	// Just set all missing resistances, for the sake of formality
	// Some of them may be used.
	Resistance_FillMissingIn(Res, Res.General);
	player[ID].Resistance := Res;
	for i := 1 to 14 do begin
		WeaponMenu_SwitchWeapon(ID, i, player[ID].Activeweapons[i]);
	end;
	// Make sure whole menu is updated
	WeaponMenu_RefreshAll(ID);
	Result := true;
end;

function TaskStrToInt(s: string): byte;
begin
	{$ifndef FPC}
  case LowerCase(Copy(s, 1, 3)) of
		'mec': Result := 1;
		'dem': Result := 2;
		'doc', 'med': Result := 3;
		'far': Result := 4;
		'sha', 'sni': Result := 5;
		'pol', 'lea', 'cop': Result := 6;
		'pri': Result := 7;
		'ran': Result := 255;
		else try
			Result := StrToInt(s);
			if Result > MAX_TASKS then Result := 0;
		except;
		end;
	end;
  {$else}
  	Result := 0;
	{$endif}
end;

end.
