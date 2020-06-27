//  * -------------- *
//  |   Bot wizard   |
//  * -------------- *

// This is a part of {LS} Last Stand. Responsible for bot dynamic generation.

unit botwizard;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	MersenneTwister;

const
	BW_DEFAULT_CHAT_FREQUENCY = 3000;
	BW_FILE_PATH = '~/bots.ini';

type
	tBW_ZombieRecord = record
		Name: string;
		CustomDefinitionIndex: integer;
	end;

	tBW_ZombieDefinition = record
		Name: string;
		Color1, Color2, SkinColor, HairColor: longword;
		Hair, Headgear, Chain, ChatFrequency: byte;
		ChatKill, ChatDead, ChatDmg, ChatSee, ChatWin: string;
		ShootDead, Dummy: boolean;
    end;

procedure BW_LoadFile(path: string);
procedure BW_Shuffle(hax, force: boolean);
procedure BW_Reset(hax: boolean);
function BW_CreateNormalZombie(hax: boolean): TNewPlayer;
function BW_CreateVomitingZombie(hax: boolean): TNewPlayer;
function BW_CreateBurningZombie(hax: boolean): TNewPlayer;
function BW_CreateKamikazeZombie(hax: boolean): TNewPlayer;
function BW_CreateButcherPart(index: integer; hax: boolean): TNewPlayer;
function BW_CreateSatan(hax: boolean): TNewPlayer;
function BW_CreateFirefighter(hax: boolean): TNewPlayer;
function BW_CreateButcher(hax: boolean): TNewPlayer;
function BW_CreatePriest(hax: boolean): TNewPlayer;
function BW_CreatePlague(hax: boolean): TNewPlayer;
function BW_CreateTrap(hax: boolean): TNewPlayer;
function BW_CreateFlame(hax: boolean): TNewPlayer;
function BW_CreateMinion(hax: boolean): TNewPlayer;
function BW_CreateAltarServer(hax: boolean): TNewPlayer;
function BW_CreateArtifact(hax: boolean): TNewPlayer;
function BW_CreateKamikazeBoss(hax: boolean): TNewPlayer;
function BW_CreateScarecrow(hax: boolean): TNewPlayer;
function BW_CreateSentry(hax: boolean): TNewPlayer;
function BW_CreateFromPlayer(Player: TPlayer; hax: boolean): TNewPlayer;
procedure BW_RandZombChat(ID: byte; TextsArray: array of string; chance: single);

var
  BW_PlayerInfected, BW_ButcherTauntsMadness, BW_PlagueTauntsRevive, BW_PriestTauntsTeleport,
  BW_TickingTauntsTauntsExplode, BW_TickingTauntsExplodeClose, BW_VomitingTauntsVomit,
  BW_SatanTauntsPenta, BW_SatanTauntsHellRain, BW_SatanTauntsExplosion, BW_SatanTauntsLightning,
  BW_SatanTauntsMinions, BW_SatanTauntsArrow, BW_FirefighterTauntsPortal,
  BW_FirefighterTauntsTrap, BW_FirefighterTauntsHeat: array of string;

implementation


var
	BW_NormalZombies, BW_VomitingZombies, BW_BurningZombies, BW_KamikazeZombies, BW_ButcherPartZombies, 
	BW_HaxNormalZombies, BW_HaxVomitingZombies, BW_HaxBurningZombies, BW_HaxKamikazeZombies, BW_HaxButcherPartZombies: array of tBW_ZombieRecord;
	BW_CustomZombies: array of tBW_ZombieDefinition;
	BW_NormalTauntsKill, BW_NormalTauntsDie, BW_NormalTauntsDmg, BW_NormalTauntsSee, BW_NormalTauntsWin,
	BW_VomitingTauntsKill, BW_VomitingTauntsDie, BW_VomitingTauntsDmg, BW_VomitingTauntsSee, BW_VomitingTauntsWin,
	BW_BurningTauntsKill, BW_BurningTauntsDie, BW_BurningTauntsDmg, BW_BurningTauntsSee, BW_BurningTauntsWin,
	BW_KamikazeTauntsKill, BW_KamikazeTauntsDie, BW_KamikazeTauntsDmg, BW_KamikazeTauntsSee, BW_KamikazeTauntsWin,
	BW_PartTauntsKill, BW_PartTauntsDie, BW_PartTauntsDmg, BW_PartTauntsSee, BW_PartTauntsWin,
	BW_HaxNormalTauntsKill, BW_HaxNormalTauntsDie, BW_HaxNormalTauntsDmg, BW_HaxNormalTauntsSee, BW_HaxNormalTauntsWin,
	BW_HaxVomitingTauntsKill, BW_HaxVomitingTauntsDie, BW_HaxVomitingTauntsDmg, BW_HaxVomitingTauntsSee, BW_HaxVomitingTauntsWin,
	BW_HaxBurningTauntsKill, BW_HaxBurningTauntsDie, BW_HaxBurningTauntsDmg, BW_HaxBurningTauntsSee, BW_HaxBurningTauntsWin,
	BW_HaxKamikazeTauntsKill, BW_HaxKamikazeTauntsDie, BW_HaxKamikazeTauntsDmg, BW_HaxKamikazeTauntsSee, BW_HaxKamikazeTauntsWin,
	BW_HaxPartTauntsKill, BW_HaxPartTauntsDie, BW_HaxPartTauntsDmg, BW_HaxPartTauntsSee, BW_HaxPartTauntsWin: array of string;
	BW_Firefighter, BW_Satan, BW_Butcher, BW_Priest, BW_Plague, BW_Trap, BW_Flame, 
	BW_Minion, BW_AltarServer, BW_Artifact, BW_KamikazeBoss, BW_Scarecrow, BW_Sentry,
	BW_HaxFirefighter, BW_HaxSatan, BW_HaxButcher, BW_HaxPriest, BW_HaxPlague, BW_HaxTrap, BW_HaxFlame, 
	BW_HaxMinion, BW_HaxAltarServer, BW_HaxArtifact, BW_HaxKamikazeBoss, BW_HaxScarecrow, BW_HaxSentry: tBW_ZombieDefinition;
	BW_CurrentNormalZombieIndex, BW_CurrentVomitingZombieIndex, BW_CurrentBurningZombieIndex, BW_CurrentKamikazeZombieIndex: Integer;
	BW_NeedShuffleNormalZombies, BW_NeedShuffleVomitingZombies, BW_NeedShuffleBurningZombies, BW_NeedShuffleKamikazeZombies: Boolean;

procedure BW_RandZombChat(ID: byte; TextsArray: array of string; chance: single);
begin
	if RandFlt_() < chance then
	if Length(TextsArray) > 0 then 
		Players[ID].Say(TextsArray[RandInt_(Length(TextsArray)-1)]);
end;
	
function BW_RandomGreen(): longword;
begin
	Result := random( $10, $70 ) or (random( $40, $99 ) shl 8) or (random( $10, $70 ) shl 16);
end;

function BW_RandomHairColor(): longword;
begin
	case Random(1,11) of
		1: Result := $808080;
		2: Result := $999999;
		3: Result := $CCCC99;
		4: Result := $663300;
		5: Result := $999966;
		6: Result := $333300;
		7: Result := $330000;
		8: Result := $545454;
		9: Result := $660033;
		10: Result := $4F4F2f;
	end;
end;

function BW_RanomBotDefinition(name: string; tauntsKill, tauntsDead, tauntsDmg, tauntsSee, tauntsWin: array of string): tBW_ZombieDefinition;
//var
	//arrKill, arrDead, arrDmg, arrSee, arrWin: array of string;
begin
	Result.Name := name;
	Result.Color1 := BW_RandomGreen();
	Result.Color2 := BW_RandomGreen();
	Result.SkinColor := BW_RandomGreen();
	Result.HairColor := BW_RandomHairColor();
	Result.Hair := RandInt(0, 6);
	Result.Headgear := 0;
	Result.Chain := 0;
	Result.ChatFrequency := BW_DEFAULT_CHAT_FREQUENCY;
	Result.ChatKill := tauntsKill[RandInt(0, GetArrayLength(tauntsKill) - 1)];
	Result.ChatDead := tauntsDead[RandInt(0, GetArrayLength(tauntsDead) - 1)];
	Result.ChatDmg := tauntsDmg[RandInt(0, GetArrayLength(tauntsDmg) - 1)];
	Result.ChatSee := tauntsSee[RandInt(0, GetArrayLength(tauntsSee) - 1)];
	Result.ChatWin := tauntsWin[RandInt(0, GetArrayLength(tauntsWin) - 1)];
	Result.ShootDead := True;
	Result.Dummy := False;
end;

procedure BW_LoadCustomBot(ini: TIniFile; name: string; var definition: tBW_ZombieDefinition);
begin
{$ifndef FPC}
  definition.Name := ini.ReadString(name, 'Name', name);
	definition.Color1 := ini.ReadInteger(name, 'Color1', $000000FF);
	definition.Color2 := ini.ReadInteger(name, 'Color2', $000000FF);
	definition.SkinColor := ini.ReadInteger(name, 'Skin_Color', $000000FF);
	definition.HairColor := ini.ReadInteger(name, 'Hair_Color', $000000FF);
	definition.Hair := Byte(ini.ReadInteger(name, 'Hair', 4));
	definition.Headgear := Byte(ini.ReadInteger(name, 'Headgear', 0));
	definition.Chain := Byte(ini.ReadInteger(name, 'Chain', 0));
	definition.ChatFrequency := Byte(ini.ReadInteger(name, 'ChatFrequency', BW_DEFAULT_CHAT_FREQUENCY));
	definition.ChatKill := ini.ReadString(name, 'Chat_Kill', '');
	definition.ChatDead := ini.ReadString(name, 'Chat_Dead', '');
	definition.ChatDmg := ini.ReadString(name, 'Chat_Lowhealth', '');
	definition.ChatSee := ini.ReadString(name, 'Chat_SeeEnemy', '');
	definition.ChatWin := ini.ReadString(name, 'Chat_Winning', '');
	definition.ShootDead := ini.ReadBool(name, 'Shoot_Dead', True);
	definition.Dummy := ini.ReadBool(name, 'Dummy', False);
{$endif}
end;

procedure BW_LoadBots(ini: TIniFile; name: string; var recordArr: array of tBW_ZombieRecord);
{$ifndef FPC}
var
    values: TStringList;
    i, j: integer;
    zombieRecord: tBW_zombieRecord;
{$endif}
begin
  {$ifndef FPC}
	values := File.CreateStringList();
	ini.ReadSection(name, values);
	SetArrayLength(recordArr, values.Count);
	for i := 0 to values.Count - 1 do
	begin
		zombieRecord.Name := values[i];
		if ini.ReadInteger(name, values[i], 0) = 1 then
		begin
		j := GetArrayLength(BW_CustomZombies);
		SetArrayLength(BW_CustomZombies, j + 1);
		BW_LoadCustomBot(ini, values[i], BW_CustomZombies[j])
		zombieRecord.CustomDefinitionIndex := j;
		end
		else
		zombieRecord.CustomDefinitionIndex := -1;
		recordArr[i] := zombieRecord;
	end;
  {$endif}
end;

procedure BW_LoadTaunts(ini: TIniFile; name: string; var tauntsArr: array of string);
{$ifndef FPC}
var
	values: TStringList;
	i: integer;
{$endif}
begin
  {$ifndef FPC}
	values := File.CreateStringList();
	try
		ini.ReadSectionRaw(name, values);
		SetArrayLength(tauntsArr, values.Count);
		for i := 0 to values.Count - 1 do
		tauntsArr[i] := values[i];
	finally
		values.Free;
	end;
  {$endif}
end;

procedure BW_ConditionalLoadBots(ini: TIniFile; name: string; var value, backup: array of tBW_ZombieRecord);
begin
  {$ifndef FPC}
	if ini.SectionExists(name) then
		BW_LoadBots(ini, name, value)
	else
		value := backup;
  {$endif}
end;

procedure BW_ConditionalLoadTaunts(ini: TIniFile; name: string; var value, backup: array of string);
begin
  {$ifndef FPC}
  if ini.SectionExists(name) then
		BW_LoadTaunts(ini, name, value)
	else
		value := backup;
  {$endif}
end;

procedure BW_ConditionalLoadCustomBot(ini: TIniFile; name: string; var value, backup: tBW_ZombieDefinition);
begin
  {$ifndef FPC}
  if ini.SectionExists(name) then
		BW_LoadCustomBot(ini, name, value)
	else
		value := backup;
  {$endif}
end;

procedure BW_LoadFile(path: string);
{$ifndef FPC}
var
	BotFile: TIniFile;
  tmp: array of string;
{$endif}
begin
	{$ifndef FPC}
  if not File.Exists(path) then
	begin
		WriteDebug(10, 'bots.ini file not found, bot wizard cannot continue. Unloading.')
		Script.Unload();
	end;
	BotFile := File.CreateIni(path);
	try
		BW_LoadBots(BotFile, 'Zombies', BW_NormalZombies);
		BW_LoadBots(BotFile, 'Parts', BW_ButcherPartZombies);
	
		BW_ConditionalLoadBots(BotFile, 'Burning', BW_BurningZombies, BW_NormalZombies);		
		BW_ConditionalLoadBots(BotFile, 'Vomiting', BW_VomitingZombies, BW_NormalZombies);
		BW_ConditionalLoadBots(BotFile, 'Kamikaze', BW_KamikazeZombies, BW_NormalZombies);
		
		BW_ConditionalLoadBots(BotFile, 'HaxZombies', BW_HaxNormalZombies, BW_NormalZombies);
		BW_ConditionalLoadBots(BotFile, 'HaxBurning', BW_HaxBurningZombies, BW_BurningZombies);
		BW_ConditionalLoadBots(BotFile, 'HaxVomiting', BW_HaxVomitingZombies, BW_VomitingZombies);
		BW_ConditionalLoadBots(BotFile, 'HaxKamikaze', BW_HaxKamikazeZombies, BW_KamikazeZombies);		
		BW_ConditionalLoadBots(BotFile, 'HaxParts', BW_HaxButcherPartZombies, BW_ButcherPartZombies);


		BW_LoadTaunts(BotFile, 'TauntsKill', BW_NormalTauntsKill);
		BW_LoadTaunts(BotFile, 'TauntsDie', BW_NormalTauntsDie);
		BW_LoadTaunts(BotFile, 'TauntsDmg', BW_NormalTauntsDmg);
		BW_LoadTaunts(BotFile, 'TauntsWin', BW_NormalTauntsWin);
		BW_LoadTaunts(BotFile, 'TauntsSee', BW_NormalTauntsSee);

		BW_ConditionalLoadTaunts(BotFile, 'TauntsKill_Vomiting', BW_VomitingTauntsKill, BW_NormalTauntsKill);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsDie_Vomiting', BW_VomitingTauntsDie, BW_NormalTauntsDie);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsDmg_Vomiting', BW_VomitingTauntsDmg, BW_NormalTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsWin_Vomiting', BW_VomitingTauntsWin, BW_NormalTauntsWin);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsSee_Vomiting', BW_VomitingTauntsSee, BW_NormalTauntsSee);

		BW_ConditionalLoadTaunts(BotFile, 'TauntsKill_Burning', BW_BurningTauntsKill, BW_NormalTauntsKill);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsDie_Burning', BW_BurningTauntsDie, BW_NormalTauntsDie);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsDmg_Burning', BW_BurningTauntsDmg, BW_NormalTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsWin_Burning', BW_BurningTauntsWin, BW_NormalTauntsWin);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsSee_Burning', BW_BurningTauntsSee, BW_NormalTauntsSee);

		BW_ConditionalLoadTaunts(BotFile, 'TauntsKill_Kamikaze', BW_KamikazeTauntsKill, BW_NormalTauntsKill);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsDie_Kamikaze', BW_KamikazeTauntsDie, BW_NormalTauntsDie);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsDmg_Kamikaze', BW_KamikazeTauntsDmg, BW_NormalTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsWin_Kamikaze', BW_KamikazeTauntsWin, BW_NormalTauntsWin);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsSee_Kamikaze', BW_KamikazeTauntsSee, BW_NormalTauntsSee);

		BW_ConditionalLoadTaunts(BotFile, 'TauntsKill_Part', BW_PartTauntsKill, BW_NormalTauntsKill);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsDie_Part', BW_PartTauntsDie, BW_NormalTauntsDie);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsDmg_Part', BW_PartTauntsDmg, BW_NormalTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsWin_Part', BW_PartTauntsWin, BW_NormalTauntsWin);
		BW_ConditionalLoadTaunts(BotFile, 'TauntsSee_Part', BW_PartTauntsSee, BW_NormalTauntsSee);

		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsKill', BW_HaxNormalTauntsKill, BW_NormalTauntsKill);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsDie', BW_HaxNormalTauntsDie, BW_NormalTauntsDie);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsDmg', BW_HaxNormalTauntsDmg, BW_NormalTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsWin', BW_HaxNormalTauntsWin, BW_NormalTauntsWin);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsSee', BW_HaxNormalTauntsSee, BW_NormalTauntsSee);

		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsKill_Vomiting', BW_HaxVomitingTauntsKill, BW_VomitingTauntsKill);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsDie_Vomiting', BW_HaxVomitingTauntsDie, BW_VomitingTauntsDie);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsDmg_Vomiting', BW_HaxVomitingTauntsDmg, BW_VomitingTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsWin_Vomiting', BW_HaxVomitingTauntsWin, BW_VomitingTauntsWin);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsSee_Vomiting', BW_HaxVomitingTauntsSee, BW_VomitingTauntsSee);

		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsKill_Burning', BW_HaxBurningTauntsKill, BW_BurningTauntsKill);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsDie_Burning', BW_HaxBurningTauntsDie, BW_BurningTauntsDie);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsDmg_Burning', BW_HaxBurningTauntsDmg, BW_BurningTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsWin_Burning', BW_HaxBurningTauntsWin, BW_BurningTauntsWin);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsSee_Burning', BW_HaxBurningTauntsSee, BW_BurningTauntsSee);

		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsKill_Kamikaze', BW_HaxKamikazeTauntsKill, BW_KamikazeTauntsKill);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsDie_Kamikaze', BW_HaxKamikazeTauntsDie, BW_KamikazeTauntsDie);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsDmg_Kamikaze', BW_HaxKamikazeTauntsDmg, BW_KamikazeTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsWin_Kamikaze', BW_HaxKamikazeTauntsWin, BW_KamikazeTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsSee_Kamikaze', BW_HaxKamikazeTauntsSee, BW_KamikazeTauntsDmg);

		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsKill_Part', BW_HaxPartTauntsKill, BW_PartTauntsKill);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsDie_Part', BW_HaxPartTauntsDie, BW_PartTauntsDie);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsDmg_Part', BW_HaxPartTauntsDmg, BW_PartTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsWin_Part', BW_HaxPartTauntsWin, BW_PartTauntsDmg);
		BW_ConditionalLoadTaunts(BotFile, 'HaxTauntsSee_Part', BW_HaxPartTauntsSee, BW_PartTauntsDmg);

    tmp := ['Now I will eat you!', 'Roar!', 'Fear me!', 'Grrhhr!', 'Arrggh!']; 
		BW_ConditionalLoadTaunts(BotFile, 'TauntsInfection_Player', BW_PlayerInfected, tmp);
		
		tmp := ['Rise again!','Rise, zombies!', 'Get up, minions!'];
    BW_ConditionalLoadTaunts(BotFile, 'TauntsRevive_Plague', BW_PlagueTauntsRevive, tmp);
		
    tmp := ['Roar!'];
    BW_ConditionalLoadTaunts(BotFile, 'TauntsMadness_Butcher', BW_ButcherTauntsMadness, tmp);

    tmp := [];
    BW_ConditionalLoadTaunts(BotFile, 'TauntsTeleport_Priest', BW_PriestTauntsTeleport, tmp);
		
		tmp := ['Tick, tick, TICK!'];
    BW_ConditionalLoadTaunts(BotFile, 'TauntsExplode_TickingBomb', BW_TickingTauntsTauntsExplode, tmp);
		
		tmp := ['ALLAHU AKBAR!'];
    BW_ConditionalLoadTaunts(BotFile, 'TauntsExplodeClose_TickingBomb', BW_TickingTauntsExplodeClose, tmp);
		
		tmp := ['Bluhhhr!', 'Mlearhh!', 'Prhhh!', 'Ulhrr!', 'Blurhh!', 'Brrhhg', 'Arghhr!'];   
		BW_ConditionalLoadTaunts(BotFile, 'TauntsVomit_Vomiting', BW_VomitingTauntsVomit, tmp);
		
		tmp := ['You shall burn in hell!', 'Burn!', 'Die!!!'];
		BW_ConditionalLoadTaunts(BotFile, 'TauntsPenta_Satan', BW_SatanTauntsPenta, tmp);

		tmp := ['You shall burn in hell!', 'Burn!', 'Die!!!'];
		BW_ConditionalLoadTaunts(BotFile, 'TauntsExplosion_Satan', BW_SatanTauntsExplosion, tmp);

    tmp := ['Hellrain!', 'Come, oh hellrain!'];
		BW_ConditionalLoadTaunts(BotFile, 'TauntsHellRain_Satan', BW_SatanTauntsHellRain, tmp);

    tmp := [];
		BW_ConditionalLoadTaunts(BotFile, 'TauntsLightning_Satan', BW_SatanTauntsLightning, tmp);

    tmp := [];
		BW_ConditionalLoadTaunts(BotFile, 'TauntsMinions_Satan', BW_SatanTauntsMinions, tmp);

    tmp := ['This arrow shall bring death!'];
		BW_ConditionalLoadTaunts(BotFile, 'TauntsArrow_Satan', BW_SatanTauntsArrow, tmp);

    tmp := [];
		BW_ConditionalLoadTaunts(BotFile, 'TauntsPortal_Firefighter', BW_FirefighterTauntsPortal, tmp);

    tmp := [];
		BW_ConditionalLoadTaunts(BotFile, 'TauntsTrap_Firefighter', BW_FirefighterTauntsTrap, tmp);

    tmp := ['I am the god of hellfire, and i bring you FIRE!  '];
		BW_ConditionalLoadTaunts(BotFile, 'TauntsTrap_Firefighter', BW_FirefighterTauntsHeat, tmp);

		BW_LoadCustomBot(BotFile, 'Firefighter', BW_Firefighter);
		BW_LoadCustomBot(BotFile, 'Satan', BW_Satan);
		BW_LoadCustomBot(BotFile, 'Butcher', BW_Butcher);
		BW_LoadCustomBot(BotFile, 'Priest', BW_Priest);
		BW_LoadCustomBot(BotFile, 'Plague', BW_Plague);
		BW_LoadCustomBot(BotFile, 'Trap', BW_Trap);
		BW_LoadCustomBot(BotFile, 'Flame', BW_Flame);
		BW_LoadCustomBot(BotFile, 'Minion', BW_Minion);
		BW_LoadCustomBot(BotFile, 'AltarServer', BW_AltarServer);
		BW_LoadCustomBot(BotFile, 'Artifact', BW_Artifact);
		BW_LoadCustomBot(BotFile, 'KamikazeBoss', BW_KamikazeBoss);
		BW_LoadCustomBot(BotFile, 'Scarecrow', BW_Scarecrow);
		BW_LoadCustomBot(BotFile, 'Sentry', BW_Sentry);

		BW_ConditionalLoadCustomBot(BotFile, 'HaxFirefighter', BW_HaxFirefighter, BW_Firefighter);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxSatan', BW_HaxSatan, BW_Satan);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxButcher', BW_HaxButcher, BW_Butcher);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxPriest', BW_HaxPriest, BW_Priest);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxPlague', BW_HaxPlague, BW_Plague);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxTrap', BW_HaxTrap, BW_Trap);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxFlame', BW_HaxFlame, BW_Flame);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxMinion', BW_HaxMinion, BW_Minion);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxAltarServer', BW_HaxAltarServer, BW_AltarServer);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxArtifact', BW_HaxArtifact, BW_Artifact);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxKamikazeBoss', BW_HaxKamikazeBoss, BW_KamikazeBoss);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxScarecrow', BW_HaxScarecrow, BW_Scarecrow);
		BW_ConditionalLoadCustomBot(BotFile, 'HaxSentry', BW_HaxSentry, BW_Sentry);
	finally
		BotFile.Free;
	end;
	WriteDebug(10, 'Bot file parsed successfuly');
  {$endif}
end;

procedure BW_ShuffleZombieArray(var arr: array of tBW_ZombieRecord);
var
	i, a, b: Integer;
	temp: tBW_ZombieRecord;
begin
	for i := 0 to Length(arr) - 1 do
	begin
		a := RandInt(0, Length(arr) - 1);
		b := RandInt(0, Length(arr) - 1);
		temp := arr[a];
		arr[a] := arr[b];
		arr[b] := temp;
	end;
end;

procedure BW_Reset(hax: boolean);
begin
	BW_Shuffle(hax, True);
end;

procedure BW_Shuffle(hax, force: boolean);
begin
	if force or BW_NeedShuffleNormalZombies then
	begin
		if hax then
			BW_ShuffleZombieArray(BW_HaxNormalZombies)
		else
			BW_ShuffleZombieArray(BW_NormalZombies);
		BW_NeedShuffleNormalZombies := False;
		BW_CurrentNormalZombieIndex := 0;
	end;

	if force or BW_NeedShuffleVomitingZombies then
	begin
		if hax then
			BW_ShuffleZombieArray(BW_HaxVomitingZombies)
		else
			BW_ShuffleZombieArray(BW_VomitingZombies);
		BW_NeedShuffleVomitingZombies := False;
		BW_CurrentVomitingZombieIndex := 0;
	end;

	if force or BW_NeedShuffleBurningZombies then
	begin
		if hax then
			BW_ShuffleZombieArray(BW_HaxBurningZombies)
		else
			BW_ShuffleZombieArray(BW_BurningZombies);
		BW_NeedShuffleBurningZombies := False;
		BW_CurrentBurningZombieIndex := 0;
	end;

	if force or BW_NeedShuffleKamikazeZombies then
	begin
		if hax then
			BW_ShuffleZombieArray(BW_HaxKamikazeZombies)
		else
			BW_ShuffleZombieArray(BW_KamikazeZombies);
		BW_NeedShuffleKamikazeZombies := False;
		BW_CurrentKamikazeZombieIndex := 0;
	end;
end;

function BW_DefinitionToPlayer(definition: tBW_ZombieDefinition): TNewPlayer;
begin
	Result := TNewPlayer.Create();
	Result.Name := definition.Name;
	Result.ShirtColor := definition.Color1;
	Result.PantsColor := definition.Color2;
	Result.SkinColor := definition.SkinColor;
	Result.HairColor := definition.HairColor;
	Result.ShootDead := definition.ShootDead;
	Result.Camping := False;
	Result.HairStyle := definition.Hair;
	Result.Headgear := definition.Headgear;
	Result.Chain := definition.Chain;
	Result.ChatFrequency := definition.ChatFrequency;
	Result.ChatKill := definition.ChatKill;
	Result.ChatDead := definition.ChatDead;
	Result.ChatLowHealth := definition.ChatDmg;
	Result.ChatSeeEnemy := definition.ChatSee;
	Result.ChatWinning := definition.ChatWin;
	Result.Dummy := definition.Dummy;
end;

function BW_CreateNormalZombie(hax: boolean): TNewPlayer;
var
	zombieRecord: tBW_ZombieRecord;
	zombieArray: array of tBW_ZombieRecord;
	definition: tBW_ZombieDefinition;
begin
	if hax then
		zombieArray := BW_HaxNormalZombies
	else
		zombieArray := BW_NormalZombies;

	zombieRecord := zombieArray[BW_CurrentNormalZombieIndex];
	BW_CurrentNormalZombieIndex := BW_CurrentNormalZombieIndex + 1;
	if BW_CurrentNormalZombieIndex >= Length(zombieArray) then
	begin
		BW_NeedShuffleNormalZombies := True;
		BW_CurrentNormalZombieIndex := 0;
	end;


	if zombieRecord.CustomDefinitionIndex = -1 then
	begin
		if hax then
			definition := BW_RanomBotDefinition(zombieRecord.Name, BW_HaxNormalTauntsKill, BW_HaxNormalTauntsDie, BW_HaxNormalTauntsDmg, BW_HaxNormalTauntsSee, BW_HaxNormalTauntsWin)
		else
			definition := BW_RanomBotDefinition(zombieRecord.Name, BW_NormalTauntsKill, BW_NormalTauntsDie, BW_NormalTauntsDmg, BW_NormalTauntsSee, BW_NormalTauntsWin);
	end
	else
		definition := BW_CustomZombies[zombieRecord.CustomDefinitionIndex];

	Result := BW_DefinitionToPlayer(definition);
end;

function BW_CreateVomitingZombie(hax: boolean): TNewPlayer;
var
	zombieRecord: tBW_ZombieRecord;
	zombieArray: array of tBW_ZombieRecord;
	definition: tBW_ZombieDefinition;
begin
	if hax then
		zombieArray := BW_HaxVomitingZombies
	else
		zombieArray := BW_VomitingZombies;

	zombieRecord := zombieArray[BW_CurrentVomitingZombieIndex];
	BW_CurrentVomitingZombieIndex := BW_CurrentVomitingZombieIndex + 1;
	if BW_CurrentVomitingZombieIndex >= Length(zombieArray) then
	begin
		BW_NeedShuffleVomitingZombies := True;
		BW_CurrentVomitingZombieIndex := 0;
	end;


	if zombieRecord.CustomDefinitionIndex = -1 then
	begin
		if hax then
			definition := BW_RanomBotDefinition(zombieRecord.Name, BW_HaxVomitingTauntsKill, BW_HaxVomitingTauntsDie, BW_HaxVomitingTauntsDmg, BW_HaxVomitingTauntsSee, BW_HaxVomitingTauntsWin)
		else
			definition := BW_RanomBotDefinition(zombieRecord.Name, BW_VomitingTauntsKill, BW_VomitingTauntsDie, BW_VomitingTauntsDmg, BW_VomitingTauntsSee, BW_VomitingTauntsWin);
	end
	else
		definition := BW_CustomZombies[zombieRecord.CustomDefinitionIndex];

	Result := BW_DefinitionToPlayer(definition);
end;

function BW_CreateBurningZombie(hax: boolean): TNewPlayer;
var
	zombieRecord: tBW_ZombieRecord;
	zombieArray: array of tBW_ZombieRecord;
	definition: tBW_ZombieDefinition;
begin
	if hax then
		zombieArray := BW_HaxBurningZombies
	else
		zombieArray := BW_BurningZombies;

	zombieRecord := zombieArray[BW_CurrentBurningZombieIndex];
	BW_CurrentBurningZombieIndex := BW_CurrentBurningZombieIndex + 1;
	if BW_CurrentBurningZombieIndex >= Length(zombieArray) then
	begin
		BW_NeedShuffleBurningZombies := True;
		BW_CurrentBurningZombieIndex := 0;
	end;


	if zombieRecord.CustomDefinitionIndex = -1 then
	begin
		if hax then
			definition := BW_RanomBotDefinition(zombieRecord.Name, BW_HaxBurningTauntsKill, BW_HaxBurningTauntsDie, BW_HaxBurningTauntsDmg, BW_HaxBurningTauntsSee, BW_HaxBurningTauntsWin)
		else
			definition := BW_RanomBotDefinition(zombieRecord.Name, BW_BurningTauntsKill, BW_BurningTauntsDie, BW_BurningTauntsDmg, BW_BurningTauntsSee, BW_BurningTauntsWin);
	end
	else
		definition := BW_CustomZombies[zombieRecord.CustomDefinitionIndex];

	Result := BW_DefinitionToPlayer(definition);
end;

function BW_CreateKamikazeZombie(hax: boolean): TNewPlayer;
var
	zombieRecord: tBW_ZombieRecord;
	zombieArray: array of tBW_ZombieRecord;
	definition: tBW_ZombieDefinition;
begin
	if hax then
		zombieArray := BW_HaxKamikazeZombies
	else
		zombieArray := BW_KamikazeZombies;

	zombieRecord := zombieArray[BW_CurrentKamikazeZombieIndex];
	BW_CurrentKamikazeZombieIndex := BW_CurrentKamikazeZombieIndex + 1;
	if BW_CurrentKamikazeZombieIndex >= Length(zombieArray) then
	begin
		BW_NeedShuffleKamikazeZombies := True;
		BW_CurrentKamikazeZombieIndex := 0;
	end;


	if zombieRecord.CustomDefinitionIndex = -1 then
	begin
		if hax then
			definition := BW_RanomBotDefinition(zombieRecord.Name, BW_HaxKamikazeTauntsKill, BW_HaxKamikazeTauntsDie, BW_HaxKamikazeTauntsDmg, BW_HaxKamikazeTauntsSee, BW_HaxKamikazeTauntsWin)
		else
			definition := BW_RanomBotDefinition(zombieRecord.Name, BW_KamikazeTauntsKill, BW_KamikazeTauntsDie, BW_KamikazeTauntsDmg, BW_KamikazeTauntsSee, BW_KamikazeTauntsWin);
	end
	else
		definition := BW_CustomZombies[zombieRecord.CustomDefinitionIndex];

	Result := BW_DefinitionToPlayer(definition);
end;

function BW_CreateButcherPart(index: integer; hax: boolean): TNewPlayer;
var
	zombieRecord: tBW_ZombieRecord;
	definition: tBW_ZombieDefinition;
begin
	if hax then
		zombieRecord := BW_HaxButcherPartZombies[index]
	else
		zombieRecord := BW_ButcherPartZombies[index];

	if zombieRecord.CustomDefinitionIndex = -1 then
	begin
		if hax then
			definition := BW_RanomBotDefinition(zombieRecord.Name, BW_HaxPartTauntsKill, BW_HaxPartTauntsDie, BW_HaxPartTauntsDmg, BW_HaxPartTauntsSee, BW_HaxPartTauntsWin)
		else
			definition := BW_RanomBotDefinition(zombieRecord.Name, BW_PartTauntsKill, BW_PartTauntsDie, BW_PartTauntsDmg, BW_PartTauntsSee, BW_PartTauntsWin);
	end
	else
		definition := BW_CustomZombies[zombieRecord.CustomDefinitionIndex];

	Result := BW_DefinitionToPlayer(definition);
end;

function BW_CreateSatan(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxSatan)
else
	Result := BW_DefinitionToPlayer(BW_Satan);
end;

function BW_CreateFirefighter(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxFirefighter)
else
	Result := BW_DefinitionToPlayer(BW_Firefighter);
end;

function BW_CreateButcher(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxButcher)
else
	Result := BW_DefinitionToPlayer(BW_Butcher);
end;

function BW_CreatePriest(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxPriest)
else
	Result := BW_DefinitionToPlayer(BW_Priest);
end;

function BW_CreatePlague(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxPlague)
else
	Result := BW_DefinitionToPlayer(BW_Plague);
end;

function BW_CreateTrap(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxTrap)
else
	Result := BW_DefinitionToPlayer(BW_Trap);
end;

function BW_CreateFlame(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxFlame)
else
	Result := BW_DefinitionToPlayer(BW_Flame);
end;

function BW_CreateMinion(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxMinion)
else
	Result := BW_DefinitionToPlayer(BW_Minion);
end;

function BW_CreateAltarServer(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxAltarServer)
else
	Result := BW_DefinitionToPlayer(BW_AltarServer);
end;

function BW_CreateArtifact(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxArtifact)
else
	Result := BW_DefinitionToPlayer(BW_Artifact);
end;

function BW_CreateKamikazeBoss(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxKamikazeBoss)
else
	Result := BW_DefinitionToPlayer(BW_KamikazeBoss);
end;

function BW_CreateScarecrow(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxScarecrow)
else
	Result := BW_DefinitionToPlayer(BW_Scarecrow);
end;

function BW_CreateSentry(hax: boolean): TNewPlayer;
begin
if hax then
	Result := BW_DefinitionToPlayer(BW_HaxSentry)
else
	Result := BW_DefinitionToPlayer(BW_Sentry);
end;

function BW_CreateFromPlayer(Player: TPlayer; hax: boolean): TNewPlayer;
var
	arrKill, arrDead, arrDmg, arrSee, arrWin: array of string;
begin
	if hax then
	begin
		arrKill := BW_NormalTauntsKill;
		arrDead := BW_NormalTauntsDie;
		arrDmg := BW_NormalTauntsDmg;
		arrSee := BW_NormalTauntsSee;
		arrWin := BW_NormalTauntsWin;
	end
	else
	begin
		arrKill := BW_HaxNormalTauntsKill;
		arrDead := BW_HaxNormalTauntsDie;
		arrDmg := BW_HaxNormalTauntsDmg;
		arrSee := BW_HaxNormalTauntsSee;
		arrWin := BW_HaxNormalTauntsWin;    
	end;
	Result := TNewPlayer.Create;
	Result.Name := Player.Name;
	Result.ShirtColor := Player.ShirtColor;
	Result.PantsColor := Player.PantsColor;
	Result.SkinColor := BW_RandomGreen();
	Result.HairColor := Player.HairColor;
	Result.ShootDead := False;
	Result.Camping := False;
	Result.HairStyle := Player.HairStyle;
	Result.Headgear := Player.Headgear;
	Result.Chain := Player.Chain;
	Result.ChatFrequency := BW_DEFAULT_CHAT_FREQUENCY;
	Result.ChatKill := arrKill[RandInt(0, Length(arrKill) - 1)];
	Result.ChatDead := arrDead[RandInt(0, Length(arrDead) - 1)];
	Result.ChatLowHealth := arrDmg[RandInt(0, Length(arrDmg) - 1)];
	Result.ChatSeeEnemy := arrSee[RandInt(0, Length(arrSee) - 1)];
	Result.ChatWinning := arrWin[RandInt(0, Length(arrWin) - 1)];
	Result.Dummy := False;
end;


initialization 
	BW_LoadFile(BW_FILE_PATH);
	BW_Reset(True);
	BW_Reset(False);
end.
