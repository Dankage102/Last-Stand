// * ------------------ *
// |      Players       |
// * ------------------ *

// This is a part of {LS} Last Stand. Player related stuff.

unit Players;

interface

uses
	Misc,
	Raycast,
	Globals,
	Stacks,
	PlacePlayer;

type
	tPos = record
		active: boolean;
		x, y: single;
	end;	
	
	tResistance = record
		General,
		Explosion,
		Heat,
		Wires,
		Shotgun,
		SentryGun,
		Helicopter,
		HolyWater,
		ExoMagic: single;
	end;
	
	tLSPlayer = record
		// Basic player info
		Status: shortint;		// -2: dead-zombie-player; -1 zombie-player; 0: not-playing/zombie-bot; 1: alive-player; 2: temp-infected-player;
		Participant: shortint;	// -1: zombie team (human player); 0: bot or something; 1: human team.
		
		// Equipment
		Waves, mre, Mines, Charges, Wires, Sentrys, SentryAmmo, Molotovs, Statguns, Scarecrows, HolyWater: word;
		
		// Health, damage related stuff;
		Resistance: tResistance;
		DamageFactor: single;
		Health: single;
		DamagePerSec: single;
		MaxDamagePerSec: single;
		MaxDamagePerHit: single;
		HeadShootBonus: single;
		ChainsawDamageFactor: double;
		
		// Mechanic
		WrenchCooldown: byte;
		
		// Priest
		SprinkleNum, SprinkleCooldown, ShowerCooldown: byte;
		ExoTimer: smallint;
		
		// DemoMan
		DetonationQueue: tStack8;
		DetonationsNum: shortint;
		
		// Kamikaze
		KamiDetonate: byte;
		KamiKiller: byte;
		
		SpecTimer, VotedMap, VotedMode: integer;
		FlakTime: cardinal;
		HurtTime, TicksAtSpawn, BossPlayTime, ZombiePlayTime, RespawnTime: longint;
		X, Y, sx, BossDmg: single;
		KickTimer, Jumping, Jump, Task,
		pri, LastShooter,  ReloadTime, AfkSpawnTimer, AfkSpawnNum: byte;
		VoteReady, ModeReady, JustResp, GetX,
		Zombie, frozen, AttackReady, Respawned, AZSS_DontObserve,
		bitten, voted, justjoined, kicked, ReloadMode, AutoVote, StoreAutoVote, ShowTaskinfo, played, 
		AntiBlockProtection, RespawnPlayer, Admin, GodMode, Boss: boolean;
		
		SpawnTimer: smallint;
		ActiveWeapons: array[1..15] of boolean;
		TempActiveWeapons: array[1..15] of boolean;
		kills, civkills, survkills, zombdamage: integer;
		PunishmentZombie: record
			Active: boolean;
			Time: cardinal;
			Reason: string;
		end;
		StuckCD: byte;
		LastPos: tPos;
		
		// Mouse
		LastMouseX,
		LastMouseY: single;
		MousePointTime: integer;
	end;
	
	tMedic = record
		x, y: single;
		HealSpeed: smallint;
		ID: shortint;
	end;
		
	tCop = record
		ID: shortint;
		SupplyPoints: single;
		SingleOrders: word;
		Shop: record
			Active: boolean;
			Timer, Status, Nades, Ammo, SecAmmo, Pri, Sec, JustBought: byte;
			HP, Vest: Single;
			//BuyTime, RespTime: cardinal;
			X, Y: single;
		end;
	end;
		
	tDemoMan = record
		ID: shortint;
	end;

var
	player:      array[1..MAX_UNITS] of tLSPlayer;
	Medic: tMedic;
	Cop: tCop;
	DemoMan: tDemoMan;
	Mechanic: byte;
	Priest: byte;
	Sharpshooter: byte;
		
procedure Resistance_FillMissingIn(var Res: TResistance; DefaultRes: single);
		
function Players_IDByTask(Task: byte): integer;
	
function Players_ZombieIDByTask(Task: byte): integer;

function Players_OnGround(ID: byte; RC_CheckPlayerOnlyCollide: boolean; range: single): smallint;

// parial cleanup, excluding variables that matter between game rounds
procedure Players_Clear(ID: Byte);

// total cleanup
procedure Players_ClearX(ID: byte);

procedure Players_ClearStats(ID: byte);

function Players_HumanNum: byte;

function Players_StatusNum(status: shortint): byte;

function Players_ParticipantNum(participant: shortint): byte;

function Players_SpecNum(): byte;

function Players_MostKills(): integer;

implementation

procedure Resistance_FillMissingIn(var Res: TResistance; DefaultRes: single);
begin
	if Res.General = 0.0 then Res.General := DefaultRes;
	if Res.Explosion = 0.0 then Res.Explosion := DefaultRes;
	if Res.Heat = 0.0 then Res.Heat := DefaultRes;
	if Res.Wires = 0.0 then Res.Wires := DefaultRes;
	if Res.Shotgun = 0.0 then Res.Shotgun := DefaultRes;
	if Res.SentryGun = 0.0 then Res.SentryGun := DefaultRes;
	if Res.Helicopter = 0.0 then Res.Helicopter := DefaultRes;
	if Res.HolyWater = 0.0 then Res.HolyWater := DefaultRes;
	if Res.ExoMagic = 0.0 then Res.ExoMagic := DefaultRes;
end;

function Players_MostKills(): integer;
var i: integer;
	max: integer;
begin
	max := -1;
	for i := 1 to MaxID do
	if player[i].kills > max then
	begin
		max := player[i].kills;
		Result := i;
	end;
end;

function Players_HumanNum: byte;
begin
	Result := NumPlayers-NumBots;
end;

function Players_StatusNum(status: shortint): byte;
var i: byte;
begin
	Result := 0;
	for i := 1 to MaxID do
		if player[i].Status = status then
			Result := Result + 1;
end;

function Players_ParticipantNum(participant: shortint): byte;
var i: byte;
begin
	Result := 0;
	for i := 1 to MaxID do
		if player[i].Participant = participant then
			Result := Result + 1;
end;

function Players_SpecNum(): byte;
var i: byte;
begin
	Result := 0;
	for i := 1 to MaxID do
		if Players[i].Active then
		if Players[i].Human then
		if (player[i].Status = 0) then
			Result := Result + 1;
end;

function Players_IDByTask(Task: byte): integer;
var i: integer;
begin
	for i := 1 to MaxID do
		if player[i].Status > 0 then
		if player[i].Task = Task then begin
			result := i;
			break;
		end;
end;
	
function Players_ZombieIDByTask(Task: byte): integer;
var i: integer;
begin
	for i := 1 to MaxID do
		if player[i].Zombie then
		if player[i].Task = Task then begin
			result := i;
			break;
		end;
end;

procedure Players_Clear(ID: Byte);
var i: byte;
begin
	player[ID].JustResp := false;
	player[ID].bitten := false;
	player[ID].Zombie := false;
	player[ID].ShowTaskinfo := false;
	player[ID].Respawned := false;
	player[ID].SpecTimer := 0;
	player[ID].KickTimer := 0;
	player[ID].boss := false;	
	player[ID].jumping := 0;
	player[ID].jump := 0;
	player[ID].pri := WTYPE_NOWEAPON;
	player[ID].Status := 0;
	player[ID].Frozen := false;
	player[ID].AttackReady := false;
	Player[ID].Task := 0;
	player[ID].SpawnTimer := 0;
	player[ID].TicksAtSpawn := 0;
	player[ID].AfkSpawnTimer := 0;
	player[ID].AfkSpawnNum := 0;
	player[ID].ReloadTime := 0;
	player[ID].BossDmg := 0;
	player[ID].Waves := 0;
	player[ID].mre := 0;
	player[ID].Mines := 0;
	player[ID].Wires := 0;
	player[ID].Molotovs := 0;
	player[ID].Sentrys := 0;
	player[ID].SentryAmmo := 0;
	player[ID].charges := 0;
	player[ID].Scarecrows  := 0;
	player[ID].HolyWater := 0;
	player[ID].ExoTimer := 0;
	player[ID].SprinkleNum := 0;
	player[ID].SprinkleCooldown := 0;
	player[ID].ShowerCooldown := 0;
	player[ID].Resistance.General := 0;
	player[ID].Resistance.Explosion := 0;
	player[ID].Resistance.Heat := 0;
	player[ID].Resistance.Shotgun := 0;
	player[ID].Resistance.Wires := 0;
	player[ID].Resistance.ExoMagic := 0;
	player[ID].statguns := 0;
	player[ID].AntiBlockProtection := false;
	player[ID].LastPos.Active := false;
	Player[ID].RespawnPlayer := False;
	player[ID].StuckCD := 0;
	player[ID].AZSS_DontObserve := false;
	player[ID].MaxDamagePerSec := 0;
	player[ID].DamagePerSec := 0;
	player[ID].MaxDamagePerHit := 0
	player[ID].HeadShootBonus := 0;
	player[ID].KamiDetonate := 0;
	player[ID].KamiKiller := 0;
	player[ID].FlakTime := 0;
	player[ID].LastMouseX := 0;
	player[ID].LastMouseY := 0;
	player[ID].MousePointTime := 0;
	for i := 1 to 15 do begin
		player[ID].ActiveWeapons[i] := false;
		player[ID].TempActiveWeapons[i] := false;
	end;
	stack8_clear(player[ID].DetonationQueue);
	player[ID].DetonationsNum := 0;
	player[ID].WrenchCooldown := 0;
end;

// total cleanup
procedure Players_ClearX(ID: byte);
begin
	player[ID].Admin := false;
	player[ID].ReloadMode := false;
	player[ID].VoteReady := false;
	player[ID].ModeReady := false;
	player[ID].AutoVote := false;
	player[ID].StoreAutoVote := false;
	player[ID].Participant := 0;
	player[ID].GodMode := false;
	Players_Clear(ID);
end;

procedure Players_ClearStats(ID: byte);
begin
	player[ID].kills := 0;
	player[ID].zombdamage := 0;	
end;

function Players_OnGround(ID: byte; RC_CheckPlayerOnlyCollide: boolean; range: single): smallint;
var x, y: single;
begin
	// i guess it could be simplified now, since we have extended raycast
	if (not RC_CheckPlayerOnlyCollide) then begin
		GetPlayerXY(ID, x, y);
		if RayCast(x, y, x, y + range, false, false, false) then Result := -1 else Result := 1;
	end else begin
		if Players[ID].OnGround then Result := 1 else begin
			GetPlayerXY(ID, x, y);
			if not RayCast(x, y, x, y + range, true, false, false) then Result := 1;
		end;
	end;
end;

end.
