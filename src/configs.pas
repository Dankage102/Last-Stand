unit configs;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Constants,
	Debug,
	INI,
  Globals,
	Misc;

const
	MAX_MODES = 5;

	MAXPLAYERS_SURVIVAL =  6; // default, if not set in config
	MAXPLAYERS_VETERAN =  4;
	MAXPLAYERS_VERSUS =   10;
	MAXPLAYERS_INFECTION = 6;
	MAXPLAYERS_BUTCHERY  = 6;
	
	WEAPONSINI = 'weapons_realistic';//default, path to used weapons.ini, if not set in config
	V_WEAPONSINI = 'weapons_veteran';

type
	tNews = record
		Active: boolean;
		Max, Last: byte;
		Time: word;
		FilePath: string;
		Msg: array of record
			Color: longint;
			Style: byte;
			Text: array of string;
			Height: shortint;
		end;
	end;


	tLSMap = record
		CurrentNum, DifficultyPercent, DeathTimer: word;
		CivsName, StartText, EndText: string;
		Settings: record
			Path: string;
			Ini: tINI;
			Loaded: boolean;
		end;
	end;
	
	tConfig = record
		Mode: array [1..MAX_MODES] of record
			WeaponPath: string;
			Maxplayers: byte;
			Enabled, WeaponSys: boolean;
		end;	
		ForceMode: boolean;
		DefaultGameMode: byte;
		Loaded: boolean;
	end;
	
var
	News: tNews;
	LSMap: tLSMap;
	Config: tConfig;

procedure Config_LoadNews();
procedure Config_LoadLSSettings();
procedure Config_ApplyMapSettings(Map: string);

implementation

const DEFAULT_END_TEXT = 'GAME OVER';

procedure Config_ApplyMapSettings(Map: string);
var str: string; changed, FoundKey, enabled: boolean;
begin
	
	if not LSMap.Settings.Loaded then begin
		LSMap.DeathTimer := DEATH_TIMER;
		LSMap.CivsName := 'Civilians';
		LSMap.StartText := '';
		LSMap.EndText := DEFAULT_END_TEXT;
		LSMap.DifficultyPercent := 100;
		exit;
	end;
	
	str := INI_Get(LSMap.Settings.Ini, Game.CurrentMap, 'Enabled', '', FoundKey);
	if str <> '' then begin
		enabled := str = '1';
	end else if not FoundKey then begin
		INI_Set(LSMap.Settings.Ini, Game.CurrentMap, 'Enabled', '0', changed);
	end;
	
	LSMap.DeathTimer := DEATH_TIMER;
	str := INI_Get(LSMap.Settings.Ini, Game.CurrentMap, 'DeathTimer', '', FoundKey);
	if str <> '' then begin
		if enabled then
			try
				LSMap.DeathTimer := StrToInt(str);
			except
			end;
	end else if not FoundKey then begin
		INI_Set(LSMap.Settings.Ini, Game.CurrentMap, 'DeathTimer', '', changed);
	end;
	
	LSMap.CivsName := 'Civilians';
	str := INI_Get(LSMap.Settings.Ini, Game.CurrentMap, 'CivsName', '', FoundKey);
	if str <> '' then begin
		if enabled then
			LSMap.CivsName := str;
	end else if not FoundKey then begin
		INI_Set(LSMap.Settings.Ini, Game.CurrentMap, 'CivsName', '', changed);
	end;
	
	LSMap.DifficultyPercent := 100;
	str := INI_Get(LSMap.Settings.Ini, Game.CurrentMap, 'Difficulty%', '', FoundKey);
	if str <> '' then begin
		if enabled then
			try
				LSMap.DifficultyPercent := StrToInt(str);
			except
			end;
	end else if not FoundKey then begin
		INI_Set(LSMap.Settings.Ini, Game.CurrentMap, 'Difficulty%', '', changed);
	end;
	
	LSMap.StartText := '';
	str := INI_Get(LSMap.Settings.Ini, Game.CurrentMap, 'StartText', '', FoundKey);
	if str <> '' then begin
		if enabled then
			LSMap.StartText := str;
	end else if not FoundKey then begin
		INI_Set(LSMap.Settings.Ini, Game.CurrentMap, 'StartText', '', changed);
	end;
	
	str := INI_Get(LSMap.Settings.Ini, Game.CurrentMap, 'EndText', '', FoundKey);
	if str <> '' then begin
		if enabled then begin
			LSMap.EndText := str;
		end else
			LSMap.EndText := DEFAULT_END_TEXT
	end else begin
		LSMap.EndText := DEFAULT_END_TEXT;
		if not FoundKey then begin
			INI_Set(LSMap.Settings.Ini, Game.CurrentMap, 'EndText', '', changed);
		end;
	end;
	
	if changed then
		INI_Save(LSMap.Settings.Ini, LSMap.Settings.Path);
end;

procedure Config_LoadLSSettings();
var
	ConfigPath: string;
	n: smallint;
	ini: tINI;
	b, changed, CreateFile: boolean;
begin
	LSMap.Settings.Path := Script.Dir + 'mapsettings.ini';
	if FileExists(LSMap.Settings.Path) then begin
		INI_Clear(LSMap.Settings.Ini);
		LSMap.Settings.Loaded := INI_Load(LSMap.Settings.Ini, LSMap.Settings.Path);
	end;
	
	ConfigPath := Script.Dir + 'config.ini';
	Config.Mode[1].Maxplayers := MAXPLAYERS_SURVIVAL;
	Config.Mode[2].Maxplayers := MAXPLAYERS_VETERAN;
	Config.Mode[3].Maxplayers := MAXPLAYERS_VERSUS;
	Config.Mode[4].Maxplayers := MAXPLAYERS_INFECTION;
	Config.Mode[5].Maxplayers := MAXPLAYERS_INFECTION;
	Config.Mode[1].Enabled := true;
	Config.Mode[2].Enabled := true;
	Config.Mode[3].Enabled := true;
	Config.Mode[4].Enabled := true;
	Config.Mode[5].Enabled := false;
	Config.Mode[1].WeaponSys := true;
	Config.Mode[2].WeaponSys := true;
	Config.Mode[3].WeaponSys := false;
	Config.Mode[4].WeaponSys := false;
	Config.Mode[5].WeaponSys := false;
	Config.Mode[1].WeaponPath := WEAPONSINI;
	Config.Mode[2].WeaponPath := V_WEAPONSINI;
	Config.Mode[3].WeaponPath := WEAPONSINI;
	Config.Mode[4].WeaponPath := WEAPONSINI;
	Config.Mode[5].WeaponPath := WEAPONSINI;
	Config.ForceMode := false;
	Config.DefaultGameMode := 1;
	
	if FileExists(ConfigPath) then begin
		if INI_Load(ini, ConfigPath) then begin
			try
				Config.Mode[1].Maxplayers := StrToInt(INI_Get(ini, 'MAXPLAYERS', 'SurvivalHard', '', b));
			except
				INI_Set(ini, 'MAXPLAYERS', 'SurvivalHard', IntToStr(MAXPLAYERS_SURVIVAL), changed);
			end;
			try
				Config.Mode[2].Maxplayers := StrToInt(INI_Get(ini, 'MAXPLAYERS', 'SurvivalVeteran', '', b));
			except
				INI_Set(ini, 'MAXPLAYERS', 'SurvivalVeteran', IntToStr(MAXPLAYERS_VETERAN), changed);
			end;
			try
				Config.Mode[3].Maxplayers := StrToInt(INI_Get(ini, 'MAXPLAYERS', 'Versus', '', b));
			except
				INI_Set(ini, 'MAXPLAYERS', 'Versus', IntToStr(MAXPLAYERS_VERSUS), changed);
			end;
			try
				Config.Mode[4].Maxplayers := StrToInt(INI_Get(ini, 'MAXPLAYERS', 'Infection', '', b));
			except
				INI_Set(ini, 'MAXPLAYERS', 'Infection', IntToStr(MAXPLAYERS_INFECTION), changed);
			end;
			try
				Config.Mode[5].Maxplayers := StrToInt(INI_Get(ini, 'MAXPLAYERS', 'Butchery', '', b));
			except
				INI_Set(ini, 'MAXPLAYERS', 'Butchery', IntToStr(MAXPLAYERS_BUTCHERY), changed);
			end;
			
			Config.Mode[1].Enabled := INI_Get(ini, 'MODE_ENABLED', 'SurvivalHard', '1', b) = '1';
			if not b then INI_Set(ini, 'MODE_ENABLED', 'SurvivalHard', '1', changed);
			Config.Mode[2].Enabled := INI_Get(ini, 'MODE_ENABLED', 'Veteran', '1', b) = '1';
			if not b then INI_Set(ini, 'MODE_ENABLED', 'Veteran', '1', changed);
			Config.Mode[3].Enabled := INI_Get(ini, 'MODE_ENABLED', 'Versus', '1', b) = '1';
			if not b then INI_Set(ini, 'MODE_ENABLED', 'Versus', '1', changed);
			Config.Mode[4].Enabled := INI_Get(ini, 'MODE_ENABLED', 'Infection', '1', b) = '1';
			if not b then INI_Set(ini, 'MODE_ENABLED', 'Infection', '1', changed);
			//Config.Mode[5].Enabled := INI_Get(ini, 'MODE_ENABLED', 'Butchery', '1', b) = '1';
			//if not b then INI_Set(ini, 'MODE_ENABLED', 'Butchery', '1', changed);
			
			Config.Mode[1].WeaponSys := INI_Get(ini, 'WEAPON_SYSTEM', 'SurvivalHard', '0', b) = '1';
			if not b then INI_Set(ini, 'WEAPON_SYSTEM', 'SurvivalHard', '0', changed);
			Config.Mode[2].WeaponSys := INI_Get(ini, 'WEAPON_SYSTEM', 'Veteran', '1', b) = '1';
			if not b then INI_Set(ini, 'WEAPON_SYSTEM', 'Veteran', '1', changed);
			Config.Mode[3].WeaponSys := INI_Get(ini, 'WEAPON_SYSTEM', 'Versus', '0', b) = '1';
			if not b then INI_Set(ini, 'WEAPON_SYSTEM', 'Versus', '0', changed);
			Config.Mode[4].WeaponSys := INI_Get(ini, 'WEAPON_SYSTEM', 'Infection', '0', b) = '1';
			if not b then INI_Set(ini, 'WEAPON_SYSTEM', 'Infection', '0', changed);
			
			Config.Mode[1].WeaponPath := INI_Get(ini, 'WEAPON_PATH', 'SurvivalHard', WEAPONSINI, b);
			if not b then INI_Set(ini, 'WEAPON_PATH', 'SurvivalHard', WEAPONSINI, changed);
			Config.Mode[2].WeaponPath := INI_Get(ini, 'WEAPON_PATH', 'Veteran', V_WEAPONSINI, b);
			if not b then INI_Set(ini, 'WEAPON_PATH', 'Veteran', V_WEAPONSINI, changed);
			Config.Mode[3].WeaponPath := INI_Get(ini, 'WEAPON_PATH', 'Versus', WEAPONSINI, b);
			if not b then INI_Set(ini, 'WEAPON_PATH', 'Versus', WEAPONSINI, changed);
			Config.Mode[4].WeaponPath := INI_Get(ini, 'WEAPON_PATH', 'Infection', WEAPONSINI, b);
			if not b then INI_Set(ini, 'WEAPON_PATH', 'Infection', WEAPONSINI, changed);
			//Config.Mode[5].WeaponSys := INI_Get(ini, 'WEAPON_SYSTEM', 'Butchery', '1', b) = '1';
			//if not b then INI_Set(ini, 'WEAPON_SYSTEM', 'Butchery', '1', changed);

			try
				n := StrToInt(INI_Get(ini, 'GENERAL', 'DefaultMode', '', b));
				if (n<1) or (n>MAX_MODES) then begin
					n := 1;
					INI_Set(ini, 'GENERAL', 'DefaultMode', '1', changed);
				end;
			except;
				INI_Set(ini, 'GENERAL', 'DefaultMode', '1', changed);
				n := 1;
			end;
			Config.DefaultGameMode := n;
			Config.ForceMode := INI_Get(ini, 'GENERAL', 'ForceDefaultMode', '', b) = '1';
			if not b then begin
				INI_Set(ini, 'GENERAL', 'ForceDefaultMode', '0', changed);
			end;
			
			if changed then INI_Save(ini, ConfigPath);
		end else begin
			CreateFile := true;
		end;
	end else begin
		CreateFile := true;
	end;
	
	if CreateFile then begin
		WriteFile(ConfigPath,
			'[GENERAL]' + #13#10 +
			'DefaultMode=1' + #13#10 +
			'ForceDefaultMode=0' + #13#10 +
			#13#10 +
			'[MODE_ENABLED]' + #13#10 +
			'Survival=1' + #13#10 +
			'SurvivalHard=1' + #13#10 +
			'Versus=1' + #13#10 +
			'Infection=1' + #13#10 +
			#13#10 +
			'[MAXPLAYERS]' + #13#10 +
			'SurvivalHard=' + IntToStr(MAXPLAYERS_SURVIVAL) + #13#10 +
			'SurvivalVeteran=' + IntToStr(MAXPLAYERS_VETERAN) + #13#10 +
			'Versus=' + IntToStr(MAXPLAYERS_VERSUS) + #13#10 +
			'Infection=' + IntToStr(MAXPLAYERS_INFECTION) + #13#10 +
			'Butchery=' + IntToStr(MAXPLAYERS_BUTCHERY) + #13#10 +
			#13#10 +
			'[WEAPON_SYSTEM]' + #13#10 +
			'Survival=0'  + #13#10 +
			'SurvivalHard=1' + #13#10 +
			'Versus=0' + #13#10 +
			'Infection=0' + #13#10 +
			'Butchery=0'
		);
		CreateFile := false;
	end;
	
	Config.Loaded := true;
end;
	
procedure Config_LoadNews();
var
	CreateFile, b: boolean;
	ini: tINI;
	n: smallint; 
	Text: string;
begin
	News.FilePath := Script.Dir + 'news.ini';
	if FileExists(News.FilePath) then begin
		INI_Clear(ini);
		if INI_Load(ini, News.FilePath) then begin
			try
				n := StrToInt(INI_Get(ini,'NEWS','NumberOfNews','0',b));
			except
				exit;
			end;
			if n > 0 then begin
				b := true;
			end else begin
				exit;
			end;
			SetLength(News.Msg, n);
			News.Max := n - 1;
			repeat
				n := n - 1;
				Text := INI_Get(ini, 'TEXT' + IntToStr(n+1),'Text','',b);
				if Text = '' then exit;
				try
					News.Msg[n].Color := StrToInt(INI_Get(ini,'TEXT' + IntToStr(n+1),'Color','$FFFFFF',b));
				except
					News.Msg[n].Color := WHITE;
				end;
				News.Msg[n].Style := StrToIntDef(INI_Get(ini,'TEXT' + IntToStr(n+1),'Type','1',b), 1);
				News.Msg[n].Text := Explode2(Text, '\', false);
				News.Msg[n].Height := GetArrayLength(News.Msg[n].Text) - 1;
				if News.Msg[n].Height < 0 then exit;
			until n = 0;
			News.Active := true;
			try
				News.Time := StrToInt(INI_Get(ini,'NEWS','Time','360',b));
			except
				News.Time := 360;
			end;
			WriteDebug(5, 'News loaded');
		end else begin
			CreateFile := true;
			News.Active := false;
		end;
	end else begin
		CreateFile := true;
		News.Active := false;
	end;
	
	if CreateFile then
		WriteFile(News.FilePath,
			'[NEWS]' + #13#10 +
			'NumberOfNews=1' + #13#10 +
			'Time=360' + #13#10 + #13#10 +
			'[TEXT1]' + #13#10 +
			'Text=' + #13#10 +
			'Color=$FFFFFF' + #13#10 +
			'Type=1'
		);
end;

begin
end.
