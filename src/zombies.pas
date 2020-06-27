unit Zombies;

interface

uses
	{$ifdef FPC}
		Scriptcore,
  {$endif}
	Botwizard,
	Constants,
	Globals,
	LSPlayers,
  MersenneTwister,
  Misc,
	maths,
	gamemodes,
  PlacePlayer;

const
	MAX_POWERS = 3; //Max powers that can be done at one time (not counting "quick powers")
	FF_MAXTRAPS = 3;
    FF_MAXHEATITEMS = 32;
	
type
	tPower = record
		CountDown, Victim, InUse, Var1, Var2: byte;
		X, Y: single;
		Progress: word;
		Spawns: array of smallint;
	end;
	
	tBoss = record
		Outro: boolean;
		ID, bID, CountDown, Intro, PwID: byte;
		TempDmgInputFactor: single;
		Power: array [0..MAX_POWERS] of tPower;
	end;
	
	tFF = record
		Trap: array [1..FF_MAXTRAPS] of record
			InProgress: boolean;
			ID: byte;
		end;
        ScheduledHeatItem: array[1..FF_MAXHEATITEMS] of record
            ItemType: byte;
            ItemID: byte;
            CountdownTicks: integer;
            Amount: longint;
            ItemX, ItemY: single;
        end;
        ActiveHeatItems: byte;
		TrapSlot: byte;
		Trail: record
			X,Y: single;
		end;
	end;
	
	tSatan = record
		ArtifactID: byte;
		DoFireworks, Shadows, Artifact: boolean;
		Minions: array of record
			X, Y: single;
			time: integer;
			spawned: boolean;
		end;
	end;
	
	tPlague = record
		ID: Byte;
		MinionTimer, MinionLimit, MinionCounter, MinionStorage: byte;
		Minions: array [1..MAX_UNITS] of record
			ID: byte;
			X, Y: single;
			dead, blown: boolean;
		end;
	end;

var
	BurningRef: byte;
	Boss: tBoss;
	zombiesLeft, AliveZombiesInGame: byte;
	Firefighter: tFF;
	Satan: tSatan;
	Plague: tPlague;
	Butcher, zomPriest: byte;
	AutoBrain: boolean;


function Zombies_Respawn(ID: byte; ForcePosition: boolean; X, Y: single): boolean;

// decides who will be spawned as a boss now
function Zombies_GetBossCandidate(JustCheck: boolean): byte;

// tells us if there is a human-zombie ready to spawn
function Zombies_GetZombieCandidate(var ID: byte; AllowPunishmentZombie: boolean): boolean;

function Zombies_SpawnOne(hp, dmg: single; playerZomb, style: byte; x1, y1: single; ForcePos: boolean; param: byte): byte;

procedure InfectedDeath(ID: Byte);

function RandZombieText(s: byte): string;

implementation

// when a human-zombie "dies"
procedure InfectedDeath(ID: Byte);
var i: byte; modifier: single;
begin
	PerformProgressCheck := true;
	player[ID].Respawned := false;
	player[ID].Status := -2;
	player[ID].KickTimer := 0;
	if Player[ID].SpawnTimer < 0 then begin // decide how long he will have to wait for spawn
		player[ID].ZombiePlayTime := Timer.Value; // save time of "death"
		for i := 1 to MaxID do
			if Players[i].Active then
				case player[i].Status of
				1: modifier := modifier - 0.2;
				2: modifier := modifier + 0.2;
				-1: modifier := modifier + 0.2;
			end;
		modifier := 7.0 + modifier*5.0 + SurvPwnMeter*5.0;
		//i := NameToID('tk');
		//if i > 0 then
		//	writeconsole(i, 'result: ' + floatToStr(modifier) + ';  spm: ' + floatToStr(SurvPwnMeter), ORANGE);
		if Modes.CurrentMode = 2 then begin // vs
			Player[ID].SpawnTimer := ToRangeI(4, Round(modifier), 16);
		end else // inf
			Player[ID].SpawnTimer := ToRangeI(6, Round(modifier), 16);	
	end;
	player[ID].task := 0;
	player[ID].AfkSpawnTimer := 0;
	player[ID].AfkSpawnNum := 0;
	if Players[ID].Team <> 5 then SetTeam(5, ID, true);
end;

function RandZombieText(s: byte): string;
begin
	case s of
		0: case RandInt_(4) of
			1: Result := 'Now I will eat you!';
			2: Result := 'Roar!';
			3: Result := 'Fear me!';
			4: Result := 'Grrhhr!';
			0: Result := 'Arrggh!'; 
			end;
		1: case RandInt_(4) of
			1: Result := 'Bluhhhr!';
			2: Result := 'Mlearhh!';
			3: Result := 'Prhhh!';
			4: Result := 'Ulhrr!';
			0: Result := 'Blurhh!'; 
		end;
		6: case RandInt_(5) of
			1: Result := 'Mlearh!';
			2: Result := 'Grrrhr!';
			3: Result := 'Roar.';
			4: Result := 'Mrrrh';
			5: Result := 'Brrhhg';
			0: Result := 'Arghhr!';
		end;
		2: case RandInt_(4) of
			1: Result := 'Boom!';
			2: Result := 'Kaboom!';
			3: Result := 'BANG!';
			4: Result := 'Kablam!';
			0: Result := 'KABOOM!';
		end;
		3: case RandInt_(2) of
			1: Result := 'You shall burn in hell!';
			2: Result := 'Burn!';
			0: Result := 'Die!!!';
		end;
		4: case RandInt_(1) of
			1: Result := 'Hellrain!';
			0: Result := 'Come, oh hellrain!';
		end;
		5: case RandInt_(2) of
			1: Result := 'Rise again!';
			2: Result := 'Rise, zombies!';
			0: Result := 'Get up, minions!';
		end;
	end;
end;

function Zombies_Respawn(ID: byte; ForcePosition: boolean; X, Y: single): boolean;
begin
	if Players[ID].Active then begin
		player[ID].Status := -1;
		player[ID].AfkSpawnTimer := 3;
		player[ID].AfkSpawnNum := 0;
		if ForcePosition then begin
			PutPlayer(ID, ZOMBIETEAM, X, Y, false);
		end else
			SetTeam(ZOMBIETEAM, ID, true);
		SetScore(ID, player[ID].kills);
		Result := true;
	end;
end;

// decides who will be spawned as a boss now
function Zombies_GetBossCandidate(JustCheck: boolean): byte;
var i: byte; max: longint;
begin
	max := Timer.Value;
	for i := 1 to MaxID do
		if player[i].Status < 0 then begin // if he's a dead human-zombie
			if player[i].BossPlayTime < max then begin // choose the one who has been waiting for the longest time
				max := player[i].BossPlayTime;
				Result := i;
			end;
		end;
	if (not JustCheck) and (Result > 0) then begin
		player[Result].BossPlayTime := Timer.Value;
	end;
end;

// tells us if there is a human-zombie ready to spawn
function Zombies_GetZombieCandidate(var ID: byte; AllowPunishmentZombie: boolean): boolean;
var i: byte; max: longint;
begin
	max := Timer.Value;
	Result := false;
	for i := 1 to MaxID do
		if player[i].Status = -2 then begin // if he's a dead human-zombie
			if player[i].SpawnTimer = 0 then begin // if his wait time to spawn is over
				if player[i].ZombiePlayTime < max then begin // choose the one who has been waiting for the longest time
					if (not player[i].PunishmentZombie.Active) or (AllowPunishmentZombie and player[i].PunishmentZombie.Active) then begin
						max := player[i].ZombiePlayTime;
						ID := i;
						Result := true;
					end;
				end;
			end;
		end;
end;

function Zombies_RandomVSTask(): byte;
var a: byte; b: integer; tryagain: boolean;
label up;
begin
	if NumberOfWave = 1 then begin // wave 1
		if RandInt_(2) = 0 then begin
			Result := 200;
		end else
			Result := 2;
	end else
	// choosing zombie's species depending on the number of wave, we wouldn't like to have 3 kamikazes in wave #1
	if NumberOfWave < 4 then begin // waves 2, 3
		b := RandInt_(10);
		if b <= 1 then Result := 200 else // 2/11
		if b <= 6 then Result := 2 else // 5/11
		if b <= 10 then Result := 4; // 4/11
	end else begin // waves 4+
		// decide if normal zombie should be spawned instead special one including some aspects
		b := RandInt_(1);
		for a := 1 to MaxID do // count zombies in game (weighted)
			if Players[a].Alive then begin
				if player[a].Status = -1 then begin
					case player[a].Task of
						1, 31: b := b + 4;
						2, 4: b := b + 2;
						200: b := b - 1;
						else b := b + 1;
					end;
				end else
				if player[a].Status = 2 then // if there are some dying survivors in game
					b := b + 3;
			end;
		if b >= 10 then begin
			Result := 200;
		end else begin
			up:
			if NumberOfWave <= 5 then begin // waves 4, 5
				b := RandInt_(14);
				if b <= 2 then Result := 1 else // 3/15
				if b <= 7 then Result := 2 else // 5/15
				if b <= 11 then Result := 4 else // 4/15
				if b <= 14 then Result := 31; // 3/15
			end else begin // waves 6+
				b := RandInt_(9);
				if b <= 1 then Result := 1 else // 2/10
				if b <= 4 then Result := 2 else // 3/10
				if b <= 7 then Result := 4 else // 3/10
				if b <= 9 then Result := 31; // 2/10
			end;
			if not tryagain then begin
				for a := 1 to MaxID do
					if player[a].Status = -1 then
						if player[a].Task = Result then begin
							tryagain := true; // if such zombie is already in game then try to randomize once more (for diversity of zombie team)
							break;
						end;
				if tryagain then goto up;
			end;
		end;
	end;
end;


// Calculate all resistances from given HP factor
procedure Zombies_Resistance(var Res: TResistance; style: byte; hp: single);
begin
	// Default, if not specified below
	Res.General    := hp;
	Res.Heat       := hp;
	Res.Explosion  := hp;
	Res.Wires      := math.Pow(hp, 0.90);
	Res.Shotgun    := math.Pow(hp, 0.80);
	Res.SentryGun  := math.Pow(hp, 0.80);
	Res.Helicopter := math.Pow(hp, 0.80);
	Res.HolyWater  := math.Pow(hp, 0.78);
	Res.ExoMagic   := hp*0.1;
			
	case style of
		200: begin // versus spawn mode
			Res.Wires      := math.Pow(hp, 0.92);
			Res.Shotgun    := math.Pow(hp, 0.85);
			Res.SentryGun  := math.Pow(hp, 0.85);
			Res.Helicopter := math.Pow(hp, 0.85);
			Res.HolyWater  := math.Pow(hp, 0.85);
		end;
		
		0, 91: begin
			Res.ExoMagic   := hp*0.02 + 0.10; // make them vunerable to exorcism
		end;
		
		2: begin
			Res.ExoMagic   := hp*0.1 + 0.4;
		end;
		
		4: begin // burnings
			Res.Heat       := 5.0 * hp;
			Res.Explosion  := 4.0 * hp;
			Res.ExoMagic   := hp*0.1 + 0.4;
		end;

		12: begin	// berserker/tank
			Res.ExoMagic   := hp*0.10 + 0.70;
		end;
		
		1: begin // kami
			Res.Explosion  := hp*0.80;
			Res.Heat       := hp*0.80;
			Res.ExoMagic   := hp*0.1 + 0.80;
		end;
	
		3: begin // butcher
			Res.Shotgun    := math.Pow(hp, 0.83);
			Res.SentryGun  := math.Pow(hp, 0.86);
			Res.Helicopter := math.Pow(hp, 0.91);
			Res.HolyWater  := math.Pow(hp, 0.91);
			Res.ExoMagic   := hp*0.80;
		end;
	
		31: begin // parts
			Res.Explosion  := hp*0.8;
			Res.ExoMagic   := hp*0.002 + 0.90;
		end;
		
		5: begin // priest
			Res.Shotgun    := math.Pow(hp, 0.83);
			Res.SentryGun  := math.Pow(hp, 0.86);
			Res.Helicopter := math.Pow(hp, 0.91);
			Res.HolyWater  := math.Pow(hp, 0.91)*10.0;
			Res.ExoMagic   := hp*0.80;
		end;
		
		11: begin // kamikaze boss
			Res.Explosion  := hp*0.80;
			Res.Heat       := hp*0.80;
			Res.Shotgun    := math.Pow(hp, 0.82);
			Res.SentryGun  := math.Pow(hp, 0.86);
			Res.Helicopter := math.Pow(hp, 0.91);
			Res.HolyWater  := math.Pow(hp, 0.91);
			Res.ExoMagic   := hp*0.90;
		end;
		
		51: begin // servers
			Res.Explosion  := hp*0.80;
			Res.Heat       := hp*0.80;
			Res.ExoMagic   := hp*0.002 + 0.90;
			Res.HolyWater  := math.Pow(hp, 0.80)*2.0;
		end;
		
		6: begin // firefighter
			Res.Explosion  := hp*2.00;
			Res.Heat       := hp*10.00;
			Res.Shotgun    := math.Pow(hp, 0.83);
			Res.SentryGun  := math.Pow(hp, 0.86);
			Res.Helicopter := math.Pow(hp, 0.91);
			Res.HolyWater  := math.Pow(hp, 0.91);
			Res.ExoMagic   := hp*0.90;
		end;
		
		61: begin // firefighter's minions
			Res.Explosion  := hp*2.00;
			Res.Heat       := hp*10.0;
			Res.ExoMagic   := hp*0.002 + 0.90;
		end;
		
					
		62: begin // firefighter's trap
			Res.Explosion  := hp * 0.50;
			Res.Wires      := 99999.0;
			Res.HolyWater  := 99999.0;
			Res.ExoMagic   := 99999.0;
		end;
		
		71: begin // minion
			Res.ExoMagic   := hp*0.002 + 0.90;
		end;
		
		81: begin // artifact
			Res.ExoMagic   := hp*0.90; 
		end;
		
		7, 8: begin // satan
			Res.Explosion  := hp*1.50;
			Res.Heat       := hp*1.50;
			Res.Shotgun    := math.Pow(hp, 0.83);
			Res.SentryGun  := math.Pow(hp, 0.86);
			Res.Helicopter := math.Pow(hp, 0.91);
			Res.HolyWater  := math.Pow(hp, 0.91);
			Res.ExoMagic   := hp*0.90;
		end;
			
		9: begin // plague
			Res.Explosion  := hp*1.50;
			Res.Heat       := hp*1.50;
			Res.Shotgun    := math.Pow(hp, 0.83);
			Res.SentryGun  := math.Pow(hp, 0.86);
			Res.Helicopter := math.Pow(hp, 0.91);
			Res.HolyWater  := math.Pow(hp, 0.91);
			Res.ExoMagic   := hp*0.90;
		end;
	end;
end;

function Zombies_SpawnOne(hp, dmg: single; playerZomb, style: byte; x1, y1: single; ForcePos: boolean; param: byte): byte;
var
	ID, a: byte;
	NewPlayer: TNewPlayer;
	Res: TResistance;
begin
	if ZombiesInGame >= MAX_ZOMBIES then exit;
	PerformProgressCheck := true; // count number fo zombies left
	if playerZomb=0 then begin
		case style of
			200: begin // versus spawn mode
				if Zombies_GetZombieCandidate(ID, false) then begin
					if not Zombies_Respawn(ID, ForcePos, x1, y1) then exit;
					style := Zombies_RandomVSTask();
					case style of
						31: begin
							hp := 4 + 0.7 * hp;
							dmg := 1 + dmg / 8;
							player[ID].pri := WTYPE_CHAINSAW;
						end;
						200: begin
							hp := 5 + 0.7 * hp;
							dmg := 2 + dmg / 4;
							player[ID].pri := WTYPE_NOWEAPON;
						end;
						else begin
							hp := 5 + 0.7 * hp;
							dmg := math.Pow(dmg, 0.7);
							player[ID].pri := WTYPE_NOWEAPON;
							if style = 4 then begin
								Res.Heat := hp * 5;
							end;
						end;
					end;
					player[ID].ShowTaskinfo := true;
				end else begin
					NewPlayer := BW_CreateNormalZombie(HackermanMode);
					NewPlayer.Team := ZOMBIETEAM;
					try
						if ForcePos then begin
							ID := PutBot(NewPlayer, x1, y1, ZOMBIETEAM).ID;
						end else
							ID := Players.Add(NewPlayer, TJoinSilent).ID;
					finally
						NewPlayer.Free;
					end;
					player[ID].pri := WTYPE_NOWEAPON;
				end;
				player[ID].charges := 0; // timers
				player[ID].mines := 0; // timers
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH+1;
				player[ID].MaxDamagePerHit := MAXHEALTH+1;
				player[ID].HeadShootBonus := 2.5;
			end;
			
			0,2,4,91: begin // normal, vomiting, flame
				if Zombies_GetZombieCandidate(ID, style = 0) then begin
					if not Zombies_Respawn(ID, ForcePos, x1, y1) then exit;
					if player[ID].PunishmentZombie.Active then begin // if he's a punishment zombie
						hp := Sqrt(hp);
						dmg := 1.0;
						player[ID].charges := 0; // we will use htese as tmp variables
						player[ID].mines := 0;
						player[ID].wires := 0;
					end else begin
						hp := 6.0 + 0.70 * hp;
						if style = 4 then
							hp := hp * 1.8;
						dmg := 2.0 + math.Pow(dmg, 0.75);
					end;
				end else begin
					case style of
						2: NewPlayer := BW_CreateVomitingZombie(HackermanMode);
						4: NewPlayer := BW_CreateBurningZombie(HackermanMode);
						else NewPlayer := BW_CreateNormalZombie(HackermanMode);
					end;
					NewPlayer.Team := ZOMBIETEAM;
					try
						if ForcePos then begin
							ID := PutBot(NewPlayer, x1, y1, ZOMBIETEAM).ID;
						end else
							ID := Players.Add(NewPlayer, TJoinSilent).ID;
					finally
						NewPlayer.Free;
					end;
					if style = 4 then
						hp := hp * 2.5;
				end;
				if style > 0 then begin
					player[ID].ShowTaskinfo := true;
					player[ID].charges := 2;
					if style = 4 then begin
						if burningRef = 0 then
							burningRef := ID;
					end;
				end;
				player[ID].jumping := 0;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH+1;
				player[ID].MaxDamagePerHit := MAXHEALTH+1;
				player[ID].HeadShootBonus := 3.0;
			end;

			12: begin	// berserker/tank
				NewPlayer := BW_CreateNormalZombie(HackermanMode);
				NewPlayer.Team := ZOMBIETEAM;
				try
					if ForcePos then begin
						ID := PutBot(NewPlayer, x1, y1, ZOMBIETEAM).ID;
					end else
						ID := Players.Add(NewPlayer, TJoinSilent).ID;
				finally
					NewPlayer.Free;
				end;
				player[ID].jumping := 0;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].MaxDamagePerSec := MAXHEALTH+1;
				player[ID].MaxDamagePerHit := MAXHEALTH+1;
				player[ID].HeadShootBonus := 2.0;
				hp := hp * (7.0 + 0.5*Players_HumanNum);
			end;
			
			1: begin // kami
				if Zombies_GetZombieCandidate(ID, false) then begin
					if not Zombies_Respawn(ID, false, 0, 0) then exit;
					hp := 6 + 0.70 * hp;
					dmg := math.Pow(dmg, 0.7);
					player[ID].ShowTaskinfo := true;
				end else begin
					NewPlayer := BW_CreateKamikazeZombie(HackermanMode);
					NewPlayer.Team := ZOMBIETEAM;
					try
						ID := Players.Add(NewPlayer, TJoinSilent).ID;
					finally
						NewPlayer.Free;
					end;
				end;
				player[ID].jumping := 2;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].charges := 2;
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH+1;
				player[ID].MaxDamagePerHit := MAXHEALTH+1;
				player[ID].HeadShootBonus := 2.5;
			end;
		
			3: begin // butcher
				NewPlayer := BW_CreateButcher(HackermanMode);
				NewPlayer.Team := ZOMBIETEAM;
				try
					ID := Players.Add(NewPlayer, TJoinSilent).ID;
				finally
					NewPlayer.Free;
				end;
 				Butcher := ID;
				Boss.ID := ID;
				Boss.bID := 3;
				player[ID].jumping := 2;
				player[ID].pri := WTYPE_CHAINSAW;
				player[ID].boss := true;
				player[ID].charges := 6;
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH / 6;
				player[ID].MaxDamagePerHit := MAXHEALTH / 7;
				player[ID].HeadShootBonus := 1.5;
			end;
		
			31: begin // parts
				NewPlayer := BW_CreateButcherPart(param - 1, HackermanMode);
				try
					ID := PutBot(NewPlayer, X1 - 12 + param*4, Y1, ZOMBIETEAM).ID;
				finally
					NewPlayer.Free;
				end;
				player[ID].jumping := 4;
				player[ID].pri := WTYPE_CHAINSAW;
				player[ID].MaxDamagePerSec := MAXHEALTH+1;
				player[ID].MaxDamagePerHit := MAXHEALTH+1;
				player[ID].HeadShootBonus := 2.5;
			end;
			
			5: begin // priest
				ID := Zombies_GetBossCandidate(false);
				if ID > 0 then begin
					if not Zombies_Respawn(ID, false, 0, 0) then begin
						NewPlayer := BW_CreatePriest(HackermanMode);
						NewPlayer.Team := ZOMBIETEAM;
						try
							ID := Players.Add(NewPlayer, TJoinSilent).ID;
						finally
							NewPlayer.Free;
						end;
						AutoBrain := true;
					end else AutoBrain := false;
				end else begin
					NewPlayer := BW_CreatePriest(HackermanMode);
					NewPlayer.Team := ZOMBIETEAM;
					try
						ID := Players.Add(NewPlayer, TJoinSilent).ID;
					finally
						NewPlayer.Free;
					end;
					AutoBrain := true;
				end;
				Boss.ID := ID;
				Boss.bID := 5;	
				Boss.CountDown := 3;
				zomPriest := ID;	
				player[ID].jumping := 0;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].boss := true;					
				player[ID].Mines := Players_StatusNum(1) + 2;
				player[ID].AntiBlockProtection := true;
				player[ID].ShowTaskinfo := true;
				player[ID].MaxDamagePerSec := MAXHEALTH / 5;
				player[ID].MaxDamagePerHit := MAXHEALTH / 7;
				player[ID].HeadShootBonus := 1.5;
			end;
			
			11: begin // kamikaze boss
				ID := Zombies_GetBossCandidate(false);
				if ID > 0 then begin
					if not Zombies_Respawn(ID, false, 0, 0) then begin
						NewPlayer := BW_CreateKamikazeBoss(HackermanMode);
						NewPlayer.Team := ZOMBIETEAM;
						try
							ID := Players.Add(NewPlayer, TJoinSilent).ID;
						finally
							NewPlayer.Free;
						end;
						AutoBrain := true;
					end else AutoBrain := false;
				end else begin
					NewPlayer := BW_CreateKamikazeBoss(HackermanMode);
					NewPlayer.Team := ZOMBIETEAM;
					try
						ID := Players.Add(NewPlayer, TJoinSilent).ID;
					finally
						NewPlayer.Free;
					end;
					AutoBrain := true;
				end;
				player[ID].jumping := iif(AutoBrain, 1, 0);
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].Charges := 0;
				player[ID].AntiBlockProtection := true;
				if not AutoBrain then begin
					player[ID].ShowTaskinfo := true;
				end;
				player[ID].MaxDamagePerSec := MAXHEALTH / 2;
				player[ID].MaxDamagePerHit := MAXHEALTH / 2;
				player[ID].HeadShootBonus := 1.5;
			end;
			
			51: begin // servers
				NewPlayer := BW_CreateAltarServer(HackermanMode);
				try
					ID := PutBot(NewPlayer, X1, Y1, ZOMBIETEAM).ID;
				finally
					NewPlayer.Free;
				end;
				player[ID].jumping := 0;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH+1;
				player[ID].MaxDamagePerHit := MAXHEALTH+1;
				player[ID].HeadShootBonus := 2.0;
			end;
			
			6: begin // firefighter
				ID := Zombies_GetBossCandidate(false);
				if ID > 0 then begin
					if not Zombies_Respawn(ID, false, 0, 0) then begin
						NewPlayer := BW_CreateFirefighter(HackermanMode);
						NewPlayer.Team := ZOMBIETEAM;
						try
							ID := Players.Add(NewPlayer, TJoinSilent).ID;
						finally
							NewPlayer.Free;
						end;
						AutoBrain := true;
					end else begin
						AutoBrain := false;
						hp := hp * 0.6;
					end;
				end else begin
					NewPlayer := BW_CreateFirefighter(HackermanMode);
					NewPlayer.Team := ZOMBIETEAM;
					try
						ID := Players.Add(NewPlayer, TJoinSilent).ID;
					finally
						NewPlayer.Free;
					end;
					AutoBrain := true;
				end;
				player[ID].jumping := 0;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].boss := true;
				Boss.ID := ID;
				Boss.bID := 6;
				Boss.Intro := 2;
				if not AutoBrain then begin
					player[ID].ShowTaskinfo := true;
					player[ID].task := style;
				end;
				player[ID].AttackReady := true;
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH / 12;
				player[ID].MaxDamagePerHit := MAXHEALTH / 10;
				player[ID].HeadShootBonus := 0.9;
			end;
			
			61: begin // firefighter's minions
				NewPlayer := BW_CreateFlame(HackermanMode);
				try
					ID := PutBot(NewPlayer, X1, Y1, ZOMBIETEAM).ID;
				finally
					NewPlayer.Free;
				end;
				player[ID].jumping := 0;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].Mines := 2; // spawn kit countdown
				GiveBonus(ID, 6);
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH+1;
				player[ID].MaxDamagePerHit := MAXHEALTH+1;
				player[ID].HeadShootBonus := 2.0;
			end;
			
						
			62: begin // firefighter's trap
				NewPlayer := BW_CreateTrap(HackermanMode);
				try
					ID := PutBot(NewPlayer, X1, Y1, ZOMBIETEAM).ID;
				finally
					NewPlayer.Free;
				end;
				player[ID].jumping := 0;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].MaxDamagePerSec := MAXHEALTH+1;
				player[ID].MaxDamagePerHit := (MAXHEALTH+1)/sqrt(Players_StatusNum(1));
				player[ID].HeadShootBonus := 0.0;
			end;
			
			71: begin // minion
				NewPlayer := BW_CreateMinion(HackermanMode);
				try
					ID := PutBot(NewPlayer, X1, Y1, ZOMBIETEAM).ID;
				finally
					NewPlayer.Free;
				end;
				player[ID].jumping := 4;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].charges := 6;
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH+1;
				player[ID].MaxDamagePerHit := MAXHEALTH+1;
				player[ID].HeadShootBonus := 2.0;
			end;
			
			81: begin // artifact
				NewPlayer := BW_CreateArtifact(HackermanMode);
				try
					ID := PutBot(NewPlayer, X1, Y1, ZOMBIETEAM).ID;
				finally
					NewPlayer.Free;
				end;
				Satan.ArtifactID := ID;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH+1;
				player[ID].MaxDamagePerHit := MAXHEALTH / 15;
				player[ID].HeadShootBonus := 2.0;
			end;
			
			107: begin
				Boss.Intro := 9;
				Boss.bID := 7;
				Result := 255;
				exit;
			end;
			108: begin
				Boss.bID := 8;
				Boss.Intro := 2;
				Result := 255;
				exit;
			end;
			
			7, 8: begin // satan
				ID := Zombies_GetBossCandidate(false);
				if ID > 0 then begin
					if not Zombies_Respawn(ID, false, 0, 0) then begin
						NewPlayer := BW_CreateSatan(HackermanMode);
						NewPlayer.Team := ZOMBIETEAM;
						try
							ID := Players.Add(NewPlayer, TJoinSilent).ID;
						finally
							NewPlayer.Free;
						end;
						AutoBrain := true;
					end else begin
						AutoBrain := false;
						hp := hp * 0.5;
					end;
				end else begin
					NewPlayer := BW_CreateSatan(HackermanMode);
					NewPlayer.Team := ZOMBIETEAM;
					try
						ID := Players.Add(NewPlayer, TJoinSilent).ID;
					finally
						NewPlayer.Free;
					end;
					AutoBrain := true;
				end;
				player[ID].jumping := 1;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].boss := true;
				Boss.ID := ID;
				Boss.Countdown := 5;
				if not AutoBrain then begin
					player[ID].task := style;
					player[ID].ShowTaskinfo := true;
				end;
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH / 11;
				player[ID].MaxDamagePerHit := MAXHEALTH / 15;
				player[ID].HeadShootBonus := 0.9;
			end;
			
			9: begin // plague
				ID := Zombies_GetBossCandidate(false);
				
				if ID > 0 then begin
					if not Zombies_Respawn(ID, false, 0, 0) then begin
						NewPlayer := BW_CreatePlague(HackermanMode);
						NewPlayer.Team := ZOMBIETEAM;
						try
							ID := Players.Add(NewPlayer, TJoinSilent).ID;
						finally
							NewPlayer.Free;
						end;
						AutoBrain := true;
					end else begin
						AutoBrain := false;
						hp := hp * 0.5;
					end;
				end else begin
					NewPlayer := BW_CreatePlague(HackermanMode);
					NewPlayer.Team := ZOMBIETEAM;
					try
						ID := Players.Add(NewPlayer, TJoinSilent).ID;
					finally
						NewPlayer.Free;
					end;
					AutoBrain := true;
				end;
				player[ID].jumping := 4;
				player[ID].pri := WTYPE_NOWEAPON;
				player[ID].boss := true;				
				Boss.ID := ID;
				Boss.bID := 9;	
				Plague.ID := ID;
				Plague.MinionLimit := 10 + BRAVOPLAYERS * 3 div 2;
				if Plague.MinionLimit > 32 then Plague.MinionLimit := 32;
				Plague.MinionTimer := 1;
 
				//Fill minion array with zombies left
				Plague.MinionCounter := 1;
				for a := 1 to MaxID do 
					if Players[a].Alive then
						if player[a].Zombie then begin // zombies
							Plague.Minions[Plague.MinionCounter].ID := a;
							Plague.Minions[Plague.MinionCounter].Dead := False;
							Plague.Minions[Plague.MinionCounter].Blown := False;
							Plague.MinionCounter := Plague.MinionCounter + 1;
						end;
				player[ID].task := style;				
				player[ID].ShowTaskinfo := true;
				player[ID].AntiBlockProtection := true;
				player[ID].MaxDamagePerSec := MAXHEALTH / 10;
				player[ID].MaxDamagePerHit := MAXHEALTH / 15;
				player[ID].HeadShootBonus := 0.9;
				
			end;
		end;
		Weapons_Force(ID, player[ID].pri, WTYPE_NOWEAPON, 0, 0);
	end else begin
		NewPlayer := BW_CreateFromPlayer(Players[playerZomb], HackermanMode);
		try
			ID := PutBot(NewPlayer, X1, Y1, ZOMBIETEAM).ID;
		finally
			NewPlayer.Free;
		end;
		BW_RandZombChat(ID, BW_PlayerInfected, 0.5);
		player[ID].pri := WTYPE_NOWEAPON;
		Weapons_Force(ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
		player[ID].MaxDamagePerSec := MAXHEALTH+1;
		player[ID].MaxDamagePerHit := MAXHEALTH+1;
		player[ID].HeadShootBonus := 3.5;
	end;
	Zombies_Resistance(Res, style, hp);
	Player[ID].Resistance := Res;
	player[ID].Zombie := true;
	player[ID].DamageFactor := dmg;
	if player[ID].PunishmentZombie.Active then begin
		player[ID].task := 201;
	end else begin
		player[ID].task := style;
	end;
	if ID > MaxID then MaxID := ID;
	Result := ID;
end;

end.
