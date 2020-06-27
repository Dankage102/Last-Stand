//  * ------------- *
//  |  Mode System  |
//  * ------------- *
unit gamemodes;

interface

uses
	{$ifdef FPC}
		Scriptcore,
  {$endif}
  Bigtext,
	Globals,
	LSPlayers,
  Constants,
	Configs,
  Debug,
  MersenneTwister,
  Misc,
  BaseWeapons,
  Weapons;

const
	Z_W_HPINC =     17; // zombie wave health percent increase
	Z_W_HPINIT = 295.0;
	Z_W_DMGINC =    30; // zombie wave damage percent increase
	
	V_Z_W_HPINC =     22; // zombie wave health percent increase
	V_Z_W_HPINIT = 295;

type
	tGameMode = record
		Name, WeaponPath: string;
		ModeType, SpecialWaveDelay, Maxplayers, MaxSG, KillsForClusts, KillsForNades, RespawnTime, MinRespawnTime, MaxRespawnTime: byte;
		Color: integer;
		SpawnMode, Enabled, WeaponSys, AZSS, Sentry, BurningsEat, AZSS_Hard, DefaultReloadMode: boolean;
		ScoreExponent, SPTimeFactor: single;
		Difficulty: word;
	end;
	
	tModes = record
		DifficultyPercent: word;
		SpecialWaveDelay: byte;
		ScoreExponent: single;
		RealCurrentMode: byte;
		CurrentMode: byte;
	end;
	
var
	Mode: array [1..MAX_MODES] of tGameMode;
	Modes: tModes;
	startMode, checkModeVote: boolean;

function Modes_VotedPlayersNum(): byte;

procedure Modes_ResetVotes();

procedure Modes_Set(RealMode: byte; Verbose: boolean);

procedure Modes_CheckVotes();

procedure Modes_OnVote(ID, modeID: byte);

procedure Modes_OnUnvote(ID: byte);

procedure Modes_ShowModeList(ID: byte);

procedure Modes_ApplyConfig();

implementation

function Modes_VotedPlayersNum(): byte;
var
	i: byte;
begin
	Result:= 0;
	for i := 1 to MaxID do
		if Players[i].Active then
		if Players[i].Human then
		if player[i].ModeReady then
			Result := Result + 1;
end;

procedure Modes_ResetVotes();
var i: byte;
begin
	for i:=1 to MaxID do begin
		player[i].ModeReady:=false;
		player[i].VotedMode:=0;
	end;	
end;

procedure Modes_ApplyConfig();
var i: byte;
begin
	if (not Config.Loaded) then begin
		WriteDebug(10, 'Modes_Set: CONFIG IS NOT LOADED');
	end;
	for i := 1 to MAX_MODES do begin
		Mode[i].Maxplayers := Config.Mode[i].MaxPlayers;
		Mode[i].Enabled := Config.Mode[i].Enabled;
		Mode[i].WeaponSys := Config.Mode[i].WeaponSys;
		Mode[i].WeaponPath := Config.Mode[i].WeaponPath;
	end;
	Modes_Set(Config.DefaultGameMode, false);
end;

procedure Modes_Set(RealMode: byte; Verbose: boolean);
begin
	Modes.DifficultyPercent := Round(Mode[RealMode].Difficulty*DIFFICULTYPERCENT/100);
	Modes.RealCurrentMode := RealMode;
	Modes.CurrentMode := Mode[RealMode].ModeType;
	Modes.ScoreExponent := Mode[RealMode].ScoreExponent;	
	Modes.SpecialWaveDelay := Mode[RealMode].SpecialWaveDelay;
	BaseWeapons_Init(Mode[Modes.RealCurrentMode].WeaponSys);
	Weapons_Init(Mode[Modes.RealCurrentMode].WeaponPath);
	Command('/loadwep ' + Mode[Modes.RealCurrentMode].WeaponPath);
	Command('/minrespawntime ' + IntToStr(Mode[Modes.RealCurrentMode].MinRespawnTime));
	Command('/respawntime ' + IntToStr(Mode[Modes.RealCurrentMode].RespawnTime));
	Command('/maxrespawntime ' + IntToStr(Mode[Modes.RealCurrentMode].MaxRespawnTime));
	
	ZombieDmgInc := Z_W_DMGINC;
	ZombieHpInc := Z_W_HPINC;

	if Modes.RealCurrentMode = 2 then
	begin
		ZombieDmgInc := Z_W_DMGINC;
		ZombieHpInc := V_Z_W_HPINC;
		ZombieHpInit := V_Z_W_HPINIT;
	end;
	
	if Verbose then begin
		WriteDebug(5, 'Switching to '+Mode[RealMode].Name+ ' mode');
		WriteConsole(0, 'Server mode changed to ' + IntToStr(RealMode) + ': ' + Mode[RealMode].Name, Mode[Modes.RealCurrentMode].Color); //+' (difficulty: '+IntToStr(Modes.DifficultyPercent)+'%)'
	end;
	if Game.MaxPlayers <>  Mode[RealMode].Maxplayers then begin
		Command('/MAXPLAYERS ' + IntToStr( Mode[RealMode].Maxplayers));
		if Verbose then
			WriteConsole(0, 'Maximal number of players set to ' + IntToStr( Mode[RealMode].Maxplayers), YELLOW);
	end;
end;

procedure Modes_CheckVotes();
var a, h, i, k, ready: byte; m: smallint; b: boolean; occ, n: array[0..MAX_MODES] of byte; str: string;
begin
	for i := 1 to MaxID do begin
		if player[i].ModeReady then begin
			if player[i].VotedMode > 0 then begin
				incB(n[player[i].VotedMode], 1);
				ready := ready + 1;
			end;
		end else
			n[0] := n[0] + 1;
	end;
	if ready = 0 then exit;
	m := Players_HumanNum();
	b := m = ready; // if everybody voted...
	if not b then begin // or...
		for i := 1 to MAX_MODES do begin
			if 1.0 * n[i] >= 0.01 * m * MINVOTEMODEPERCENT then begin
				b := true; // if found an option with minimal percentage of votes...
				break;
			end;
		end;
	end;
	if not b then exit;
	// ...then set a new mode
	for i := 1 to MAX_MODES do begin
		if n[i] > 0 then str := str + Mode[i].Name + ': ' + IntToStr(n[i]) + '/' + IntToStr(m) + ' = ' + IntToStr(100 * n[i] div m) + '%' + #13#10;
		if n[i] > h then begin
			h := n[i];
			k := 1;
			occ[k] := i;
		end else
		if n[i] = h then begin
			k := k + 1;
			occ[k] := i;
		end;
	end;
	if k > 0 then
		if k > 1 then a := occ[RandInt(1, k)]
		else a := occ[1];
	str := str + #13#10 + 'Mode changed to: ' + Mode[a].Name;
	BigText_DrawScreenX(DTL_NOTIFICATION, 0, str, 360, Mode[a].Color, 0.08, 20, 360 - m * 15);
	startMode := false;
	Modes_Set(a, true);
	Modes_ResetVotes();
end;

procedure Modes_OnUnvote(ID: byte);
begin
	if GameRunning then begin
		WriteConsole(ID, 'You can''t vote during a round. Please wait.', INFORMATION); 
		exit;
	end;
	// if the vote got started
	if startMode then 
		if player[ID].ModeReady then 
		begin						
			player[ID].VotedMode := 0;
			player[ID].ModeReady := false;
			WriteConsole(0, Players[ID].Name + ' removed his vote for changing gamemode', MODEVOTE);
		end;
end;

procedure Modes_ShowModeList(ID: byte );
var i: byte;
begin
	//WriteConsole(ID, 'There are '+IntToStr(MAX_MODES)+' modes available', GREEN);
	WriteConsole(ID, 'Use /mode ID to make your vote.', GREEN);
	for i:=1 to MAX_MODES do
		if Mode[i].Enabled then
			WriteConsole(ID, ' ID '+IntToStr(i)+':   '+Mode[i].Name, Mode[i].Color);
	WriteConsole(ID, 'To see help about choosen mode do /modehelp <ModeID>, i.e: /modehelp 1', GREEN);
end;

procedure Modes_OnVote(ID, modeID: byte);
var str: string;
begin
	if (GameRunning) then begin
		WriteConsole(ID, 'You can''t vote during a round. Please wait until the game ends', INFORMATION); 
		exit;
	end;
	if Config.ForceMode then begin
		WriteConsole(ID, 'Can''t change the game mode, feature disabled on this server', INFORMATION); 
		exit;
	end;
	// check if the vote option exists
	if (modeID > 0) and (modeID <= MAX_MODES) then begin
		if Mode[modeID].Enabled then begin
			if Players_HumanNum <= Mode[modeID].MaxPlayers then begin
				// if the vote got started
				if startMode then begin
					// if the vote got started
					if not player[ID].ModeReady then begin						
						player[ID].VotedMode := modeID;
						player[ID].ModeReady := true;
						str := Players[ID].Name + ' has voted for the ' + Mode[modeID].Name + ' mode [' + IntToStr(Modes_VotedPlayersNum()) + '/' + IntToStr(Players_HumanNum) + ']';
						WriteDebug(5, str);
						WriteConsole(0, str, MODEVOTE);
					end else  begin	
						WriteConsole(ID, 'Your vote has already been counted, type /unmode to cancel your vote', INFORMATION );
						exit;
					end;
				end else begin
					startMode := true;
					player[ID].VotedMode := modeID;
					player[ID].ModeReady := true;
					WriteConsole(0, Players[ID].Name + ' voted to change mode to ' + Mode[modeID].Name+ ' [' + IntToStr(Modes_VotedPlayersNum()) + '/' + IntToStr(Players_HumanNum) + ']', MODEVOTE);
					WriteConsole(0, 'Use /modehelp for more information', MODEVOTE ); 
				end;
				// if all players voted, get all votes and calculate the new difficulty
				checkModeVote:=true;
			end else WriteConsole(ID, 'Can''t vote this mode, there are too many players in game (' + Mode[modeID].Name + ' max players is ' + IntToStr(Mode[modeID].MaxPlayers) + ')' , MODEVOTE);
		end else WriteConsole(ID, 'Can''t vote this mode, ' + Mode[modeID].Name + ' is disabled on this server' , MODEVOTE );
	end else WriteConsole(ID, 'That vote option does not exits', MODEVOTE);
end;

initialization
	Mode[1].Maxplayers := MAXPLAYERS_SURVIVAL;
	Mode[1].Name := 'Survival';
	Mode[1].SpecialWaveDelay := 1;
	Mode[1].ScoreExponent := 1.085;
	Mode[1].ModeType := 1; // survival
	Mode[1].Difficulty := SURVIVAL_DP;
	Mode[1].Color := $E11A1A;
	Mode[1].Enabled := true;
	Mode[1].WeaponSys := false;
	Mode[1].WeaponPath := WEAPONSINI;
	Mode[1].AZSS := true;
	Mode[1].MaxSG := MAX_STATS;
	Mode[1].Sentry := True;
	Mode[1].BurningsEat := True;
	Mode[1].SPTimeFactor := 1;
	Mode[1].AZSS_Hard := False;
	Mode[1].KillsForClusts := 10;
	Mode[1].KillsForNades := 8;
	Mode[1].DefaultReloadMode := False;
	Mode[1].RespawnTime := 5;
	Mode[1].MaxRespawnTime := 6;
	Mode[1].MinRespawnTime := 2;

	Mode[2].Maxplayers := MAXPLAYERS_VETERAN;
	Mode[2].Name := 'Survival - Veteran';
	Mode[2].SpecialWaveDelay := 1;
	Mode[2].ScoreExponent := 1.04;
	Mode[2].ModeType := 1; // survival
	Mode[2].Difficulty := SURVIVAL_V_DP;
	Mode[2].Color := $EE9A00;
	Mode[2].Enabled := true;
	Mode[2].WeaponSys := true;
	Mode[2].WeaponPath := V_WEAPONSINI;
	Mode[2].AZSS := true;
	Mode[2].MaxSG := V_MAX_STATS;
	Mode[2].Sentry := False;
	Mode[2].BurningsEat := False;
	Mode[2].SPTimeFactor := 1.5;
	Mode[2].AZSS_Hard := True;
	Mode[2].KillsForClusts := 18;
	Mode[2].KillsForNades := 15;
	Mode[2].DefaultReloadMode := False;
	Mode[2].RespawnTime := 0;
	Mode[2].MaxRespawnTime := 1;
	Mode[2].MinRespawnTime := 0;
	
	Mode[3].Maxplayers := MAXPLAYERS_VERSUS;
	Mode[3].Name := 'Versus';
	Mode[3].SpecialWaveDelay := 1;
	Mode[3].ScoreExponent := 1.070;
	Mode[3].ModeType := 2; // vs
	Mode[3].Difficulty := VERSUS_DP;
	Mode[3].Color := $FFFFFF;
	Mode[3].Enabled := true;
	Mode[3].WeaponSys := true;
	Mode[3].WeaponPath := WEAPONSINI;
	Mode[3].AZSS := true;
	Mode[3].MaxSG := MAX_STATS;
	Mode[3].Sentry := False;
	Mode[3].BurningsEat := True;
	Mode[3].SPTimeFactor := 1;
	Mode[3].AZSS_Hard := False;
	Mode[3].KillsForClusts := 10;
	Mode[3].KillsForNades := 8;
	Mode[3].DefaultReloadMode := False;
	Mode[3].RespawnTime := 5;
	Mode[3].MaxRespawnTime := 6;
	Mode[3].MinRespawnTime := 2;
	
	Mode[4].Maxplayers := MAXPLAYERS_INFECTION;
	Mode[4].Name := 'Infection';
	Mode[4].SpecialWaveDelay := 1;
	Mode[4].ScoreExponent := 1.070;
	Mode[4].ModeType := 3; // infection
	Mode[4].Difficulty := INFECTION_DP;
	Mode[4].Color := $B2CC33;
	Mode[4].Enabled := true;
	Mode[4].WeaponSys := true;
	Mode[4].WeaponPath := WEAPONSINI;
	Mode[4].AZSS := false;
	Mode[4].MaxSG := MAX_STATS;
	Mode[4].Sentry := True;
	Mode[4].BurningsEat := True;
	Mode[4].SPTimeFactor := 1;
	Mode[4].AZSS_Hard := False;
	Mode[4].KillsForClusts := 10;
	Mode[4].KillsForNades := 8;
	Mode[4].DefaultReloadMode := False;
	Mode[4].RespawnTime := 5;
	Mode[4].MaxRespawnTime := 6;
	Mode[4].MinRespawnTime := 2;
	
	Mode[5].Maxplayers := MAXPLAYERS_BUTCHERY;
	Mode[5].Name := 'Butchery';
	Mode[5].SpecialWaveDelay := 0;
	Mode[5].ScoreExponent := 0;
	Mode[5].ModeType := 4; // Boss butchery
	Mode[5].Difficulty := 100;
	Mode[5].Color := $CC6699;
	Mode[5].Enabled := false; // disabled for now, not done yet
	Mode[5].WeaponSys := false;
	Mode[5].WeaponPath := WEAPONSINI;
	Mode[5].AZSS := false;
	Mode[5].MaxSG := MAX_STATS;
	Mode[5].Sentry := True;
	Mode[5].BurningsEat := True;
	Mode[5].BurningsEat := True;
	Mode[5].SPTimeFactor := 1;
	Mode[5].AZSS_Hard := False;
	Mode[5].KillsForClusts := 10;
	Mode[5].KillsForNades := 8;
	Mode[5].DefaultReloadMode := False;
	Mode[5].RespawnTime := 5;
	Mode[5].MaxRespawnTime := 6;
	Mode[5].MinRespawnTime := 2;
end.
