unit Main;
{

  888       .d8888b.
  888      d88P  Y88b
  888      Y88b.
  888       "Y888b.
  888          "Y88b.
  888            "888
  888      Y88b  d88P
  88888888  "Y8888P"

  The Last Stand - Soldat, zombie survival mod by tk and others
  
  Version 1.5
  
  Main author, general maintaining: tk
  
  Coding: 
    tk, Falcon, TheOne
    Saike, Spkka
    MetalWarrior, Gizd
  
  Idea (original authors): Saike, Spkka
  
  
  This is a private script, do not use or modify without my permission.
 
  Info, contact:
    http://eat-that.org
    #soldat.eat-this! @ Quakenet
    tk7077@gmail.com
}
{$ifdef FPC}
  interface
{$endif}

uses
{$ifdef FPC}
  Scriptcore,
{$endif}
  AZSS, 
  Ballistic, 
  BaseFlag, 
  BaseWeapons, 
  Benchmark, 
  BigText, 
  Bosses, 
  BotWizard, 
  Charges, 
  ClusterBombs, 
  Configs, 
  Constants,
  Damage, 
  Debug,
  EarthQuake, 
  ExceptionHandler, 
  Fire, 
  FlashMSG, 
  Globals, 
  Hax, 
  INI, 
  Kits, 
  MapsList, 
  MapRecords, 
  MapVotes, 
  maths,
  MersenneTwister, 
  LandMines, 
  Misc, 
  GameModes, 
  Objects, 
  PlacePlayer, 
  LSPlayers, 
  Raycasts, 
  Scarecrows, 
  SentryGun, 
  Spawner, 
  Stacks, 
  Statguns, 
  Strikes, 
  Tasks,
  TaskMedic,
  TaskPolice,
  Utils, 
  WeaponMenu, 
  Weapons, 
  BarbedWires,
  Zombies;
    
const
  // do not touch \/
  MAX_S_WAVES = 5;

type
  tBlockedPlayer = record
    HWID: string;
    Name: string;
    Ip: array [0..3] of byte;
  end;
  
  tSpraySyst = record
    Active: boolean;
    N: byte;
    Spray: array of record
      Active: boolean;
      vFactor, v0: single;
      t: word;
      Target, Owner: integer;
    end;
  end;
  
var
  SpecialWave: array[1..MAX_S_WAVES] of boolean;
  cmmd:        array[0..2] of word;
  Score:       array[1..2] of array[1..2] of Cardinal;
  TaskAvailable: array[1..MAX_TASKS] of byte;
  BlockedPlayers: array of tBlockedPlayer;
  SpraySyst: tSpraySyst;
  
  SurvivalSlotsNum,
  UPCountDown, StartGameCountdown,
  molotovOwner, molotovsInGame, LastJoinedID, ShowVersusStats: byte;
  
  FarmerMRECD, SlotInfoCountdown: word;
  VersusRound: shortint;

  HumDamageTaken, HumHealthMax: Single;
  
  ScoreAntifloodTime,
  RulesAntiflood, ScorePlayers: integer;
  
    PerformReset, MapChange,
  RespSG,
  CheckNumPlayers, SatanCame, FFCame, PlagueCame: boolean;
  VSStats: Array[1..14] of integer;
  //1: Pts Team[1] |2: Pts Team[2] 
  //3: Waves round 1 4: Waves round 2 
  //5: Time r1/2 
  //7: LastSurv r1/2 
  //9: bestkiller 10: maxkills 11: besteater 12: maxcivs 13: bestzombie 14: maxsurvkills
  CrossAddressMsg: string;
  PlayerPause: boolean;
  
  WaveMessages: array of string;
  MAXWAVEMESSAGES: byte;

{$ifdef FPC}
  implementation
{$endif}

procedure DisplayException(Func: string);
begin
  WriteDebug(10, '[ERROR] '+Func+': '+ExceptionToString(ExceptionType, ExceptionParam));
end;

function RandomPlayer(_not: byte; human: boolean): byte;
var a: array[0..MAX_UNITS] of byte; i,x: byte;
begin
  x:=0;
  for i:=1 to MaxID do
    if Players[i].Active then
    if i <> _not then 
    if Players[i].Human = human then
    begin
      a[x]:=i;
      x:=x+1;
    end;
  if x > 0 then
    Result := a[RandInt(0,x-1)] else
    Result := 0;
end;

procedure RandMap();
begin
  Command('/map ' + MapList.List[RandInt_(MapList.Length-1)]);
end;
  
function Spray(X, Y: single; Speed, Damage, Range: single; Style: byte; ID: byte; RC: boolean): byte;
var
  InRange: boolean;
  i: byte;
  X2, Y2, angle: single;
  shooter: TActivePlayer;
begin
  shooter := Players[ID];
  for i := 1 to MaxID do
    if Players[i].Alive then
      if player[i].Zombie <> player[ID].Zombie then begin
        GetPlayerXY(i, X2, Y2);
        Y2 := Y2 - 10;
        if PointsInRange(X, Y, X2, Y2, Range, RC) then begin
          //angle := BallisticAim(X, Y, X2, Y2, Speed, Game.Gravity, InRange);
          angle := BallisticAimX2(shooter, players[i], Speed, 0.8, InRange);
          if InRange then begin
            //InRange := false;
            CreateBulletX(X, Y,
              cos(angle)*Speed + shooter.VelX*0.8,
              sin(angle)*Speed + shooter.VelY*0.8, Damage, Style, ID);
            Result := Result + 1;
          end;
        end;
      end;
end;

// * -------------- *
// |     Weapons    |
// * -------------- *

procedure BurnZombie(ID: byte); forward;

// Give molotov to a player in place of no weapon (either primary or secondary)
procedure Weapons_GiveMolotov(PrimaryNum, SecondaryNum, ID: byte);
var  Ammo: byte;
begin  
  // If he's already got a molotov in hands, just exit.
  if PrimaryNum = WTYPE_KNIFE then exit;
  if SecondaryNum = WTYPE_KNIFE then exit;

  if (SecondaryNum = WTYPE_NOWEAPON) then begin
    // Considering the fact that we call this function in OnWeaponChange_ event
    // we can use Players[ID].Primary/Secondary (which hold weapons) to dermine
    // amount of ammo to set in the non-molotov weapon
    if PrimaryNum = Players[ID].Primary.WType then begin
      Ammo := Players[ID].Primary.Ammo;
    end else if PrimaryNum = Players[ID].Secondary.WType then begin
      Ammo := Players[ID].Secondary.Ammo;
    end;
    Weapons_Force(ID, PrimaryNum, WTYPE_KNIFE, Ammo, 1);
    Players[ID].BigText(DTL_MOLOTOV, 'Molotovs left: '+IntToStr(player[ID].Molotovs), 200, RGB(230,100,30), 0.1, 20, 370);
  end; { else uncoment in 1.7.1
  if PrimaryNum = WTYPE_NOWEAPON then begin
    if SecondaryNum = Players[ID].Primary.WType then begin
      Ammo := Players[ID].Primary.Ammo;
    end else if SecondaryNum = Players[ID].Secondary.WType then begin
      Ammo := Players[ID].Secondary.Ammo;
    end;
    Weapons_Force(ID, WTYPE_KNIFE, SecondaryNum, 1, Ammo);
    BigText_DrawScreenX(DTL_MOLOTOV, ID, 'Molotovs left: '+IntToStr(player[ID].Molotovs), 200, RGB(230,100,30), 0.1, 20, 370);
  end; }
end;

// If someone has molotovs, called from OnWeaponChange_ event
procedure Weapons_OnMolotovWeaponChange(ID, PrimaryNum, SecondaryNum: byte);
begin
  case PrimaryNum of
    WTYPE_KNIFE: begin
      // picked some molotov? (had nothing, got molotov, secondat stayed the same)
      if (Players[ID].Primary.WType = WTYPE_NOWEAPON) and (Players[ID].Secondary.WType = SecondaryNum) then begin
        player[ID].Molotovs := player[ID].Molotovs + 1;
      end;
    end;
    
    // If primary weapon just changed
    else begin
      // Check if knife has been thrown (had knife, has nothing, secondary stayed the same)
      if (Players[ID].Primary.WType = WTYPE_KNIFE) and (Players[ID].Secondary.WType = SecondaryNum) then begin
        molotovOwner := ID;
        molotovsInGame := molotovsInGame+1;
        if player[ID].Molotovs > 0 then begin
          player[ID].Molotovs := player[ID].Molotovs-1;
          if player[ID].Molotovs = 0 then begin
            BigText_DrawScreenX(DTL_MOLOTOV, ID, 'No more molotovs left', 100, RGB(230,30,30), 0.1, 20, 370);
          end;
        end;
      end else if (PrimaryNum = WTYPE_NOWEAPON) or (SecondaryNum = WTYPE_NOWEAPON) then begin
        Weapons_GiveMolotov(PrimaryNum, SecondaryNum, ID);
      end;
    end;
  end;
end;

procedure OnWeaponChange_(Pl: TActivePlayer; Primary, Secondary: TPlayerWeapon);
var
  ID, PrimaryNum, SecondaryNum: byte;
begin
  TimeStats_Start('OnWeaponChange_');
  
  ID := Pl.ID;
  PrimaryNum := Primary.Wtype;
  SecondaryNum := Secondary.Wtype;
  
  if Players[ID].Alive = false then 
  begin
    writeconsole(0, 'alive exit', white);
    TimeStats_End('OnWeaponChange_');
    exit;
  end;

  // Zombie changes weapon
  if player[ID].Zombie then begin
    if PrimaryNum = WTYPE_KNIFE then begin
      BurnZombie(ID);
    end else
    if (PrimaryNum <> player[ID].pri) and (PrimaryNum <> WTYPE_NOWEAPON) then begin
      Weapons_Force(ID, WTYPE_NOWEAPON, SecondaryNum, 0, 0);
    end;
  
  // Dummy changes weapon
  end else if (Players[ID].Dummy) and (not Players[ID].Human) then begin
    if ID = Sentry.ID then begin
      Weapons_Force(ID, WTYPE_BOW, WTYPE_NOWEAPON, 1, 0);
    end else if ID = ScareCrow.ID then begin
      Weapons_Force(ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 1, 0);
    end;
    
  // Human changes weapon
  end else 
  if Players[ID].Human then begin
  //writeconsole(0, 'hwc(' + inttostr(ID) + ' ' + inttostr(players[id].primary.wtype) + '->' + inttostr(primarynum) + '  ' + inttostr(players[id].secondary.wtype) + '->' +  inttostr(secondarynum) + ') ' + inttostr(ServerForceWeapon), white);
    if ID = Medic.ID then begin
      TaskMedic_OnWeaponChange(PrimaryNum, SecondaryNum);
    end;
    
    if ID = Cop.ID then begin
      TaskPolice_OnWeaponChange(PrimaryNum, SecondaryNum);
    end;
    
    // if he's got molotovs
    if player[ID].Molotovs > 0 then begin
      Weapons_OnMolotovWeaponChange(ID, PrimaryNum, SecondaryNum);
    end else
    
    // if he's got a molotov (in some other way, picked it?)
    if (PrimaryNum = WTYPE_KNIFE) or (players[ID].Primary.Wtype = WTYPE_KNIFE) then begin
      Weapons_OnMolotovWeaponChange(ID, PrimaryNum, SecondaryNum);
    end;

    //No two flaks
    if PrimaryNum = SecondaryNum then
    if PrimaryNum = WTYPE_MINIGUN then
    begin
      Weapons_Force(ID, WTYPE_NOWEAPON, WTYPE_MINIGUN, 255, Players[ID].Primary.Ammo);
    end;
    
    if WeaponSystem.Enabled then begin
      BaseWeapons_OnWeaponChange(ID, PrimaryNum, SecondaryNum);
    end;
    WeaponMenu_OnWeaponChange(ID, PrimaryNum, SecondaryNum);
  end;
  TimeStats_End('OnWeaponChange_');
end;



function CalculatePoints(): Integer;
var fac: single;
begin
  // x - average number of players during the entire match
  // score = (ZombiesKilled ^ Modes.ScoreExponent) * (x ^ 0.6)
  fac := Math.Pow(1.0 * Game.MAXPLAYERS / ScorePlayers * NumberOfWave, 0.6);
  if fac < 1 then fac := 1;
  Result := Trunc(
    Math.Pow(Score[1][1], Modes.ScoreExponent) * fac
  );
end;



function RandSpecialWave(WaveDelayFactor, WaveDelayDivisor: word): byte;
var c: byte;
begin
  if NumberOfWave mod Modes.SpecialWaveDelay = 0 then begin
    if NumberOfWave > 12 * WaveDelayFactor div WaveDelayDivisor then begin
      if NumberOfWave = 13 * WaveDelayFactor div WaveDelayDivisor then SatanCame := false;
      if not SatanCame then // Satan 2
        if (RandInt(1, 1000) <= 333 * WaveDelayDivisor div WaveDelayFactor) or (NumberOfWave = 15 * WaveDelayFactor div WaveDelayDivisor) then begin
          Result := 8;
          SatanCame := true;
        end;
    end else
    if NumberOfWave > 10 * WaveDelayFactor div WaveDelayDivisor then begin
      if not PlagueCame then // Plague
        if (RandInt(1, 1000) <= 333 * WaveDelayDivisor div WaveDelayFactor) or (NumberOfWave = 12 * WaveDelayFactor div WaveDelayDivisor) then begin
          Result := 9;  
          PlagueCame := true;
        end;
    end else
    if NumberOfWave > 8 * WaveDelayFactor div WaveDelayDivisor then begin
      if not FFCame then // Firefighter
        if (RandInt(1, 1000) <= 333 * WaveDelayDivisor div WaveDelayFactor) or (NumberOfWave = 10 * WaveDelayFactor div WaveDelayDivisor) then begin
          Result := 6;  
          FFCame := true;
        end;
    end else
    if (NumberOfWave > 5 * WaveDelayFactor div WaveDelayDivisor) and (NumberOfWave <= 8 * WaveDelayFactor div WaveDelayDivisor) then begin
      if not SatanCame then // Satan 1
        if (RandInt(1, 1000) <= 333 * WaveDelayDivisor div WaveDelayFactor) or (NumberOfWave = 8 * WaveDelayFactor div WaveDelayDivisor) then begin
          Result := 7;
          SatanCame := true;
        end;
    end;
    if (Result < 6) or (Result > 9) then
      if (NumberOfWave = 5) or (NumberOfWave = 7) or (NumberOfWave >= 9) then begin
        Result := RandInt(1, MAX_S_WAVES);
        if SpecialWave[Result] then repeat
          Result:=Result+1;
          c:=c+1;
          if Result>MAX_S_WAVES then Result:=1;
          if c>MAX_S_WAVES then for c := 1 to MAX_S_WAVES do SpecialWave[c] := false;
        until not SpecialWave[Result];
        SpecialWave[Result] := true;
      end;
  end;
end;

procedure NextWave(Style: byte);
var
  points: integer;
  i: integer;
  n: integer;
begin
  ResetBoss();
  Spawn_ClearAllZombies();
  TaskPolice_OnNextWave();
    
  NumberOfWave := NumberOfWave + 1;
  ScorePlayers := ScorePlayers + Players_StatusNum(1);
  Spawn_Reset();
  BW_Shuffle(HackermanMode, False);
  ZombieFightTime := Timer.Value;
  for i := 1 to MaxID do
    if Players[i].Active then
    if player[i].Participant = 1 then
      player[i].Waves := player[i].Waves + 1;
  
  BigText_DrawScreenX(DTL_NOTIFICATION, 0, 'Wave #' + IntToStr( NumberOfWave ) + br + WaveMessages[RandInt(0, MAXWAVEMESSAGES)], 300, Mode[Modes.RealCurrentMode].Color, 0.07, 20, 380);
  if Style = 0 then begin
    if Modes.CurrentMode = 2 then begin
      if NumberOfWave < 15 then n := 9 + 11 * NumberOfWave div 2 else n := 90;
    end else
      if Modes.RealCurrentMode = 2 then  
        if NumberOfWave < 11 then n := (3 + 2*Players_HumanNum) * NumberOfWave 
        else n := (3 + 2*Players_HumanNum) * 11 
      else if NumberOfWave < 15 then n := 6 * NumberOfWave else n := 90;
    // choose different delays between waves with special bosses for each mode
    case Modes.RealCurrentMode of
      1: Style := RandSpecialWave(2, 1); // -> Delay Factor = 2/1 = 2.00
      2: Style := RandSpecialWave(3, 2);
      //2: Style := RandSpecialWave(4, 3); // -> Delay Factor = 4/3 = 1.33
      3: Style := RandSpecialWave(5, 6); // -> Delay Factor = 5/6 = 0.83
      4: Style := RandSpecialWave(5, 3); // -> Delay Factor = 5/3 = 1.66
    end;
    if Style >= 7 then n := n div 2;
    Spawn_AddZombies(n, 0);    
  end;
  if Style > 0 then
    if (NumberOfWave mod 5 <> 0) or (NumberOfWave < 10) or (Style >= 6) then
      case Style of
        1: begin
          Spawn_AddZombies(22, 1);
          if (RandBool()) or (SurvPwnMeter <= 0.01) then
            Spawn_AddZombies(1, 11);
        end;
        2: Spawn_AddZombies(27, 2);
        3: Spawn_AddZombies(1, 3);
        4: Spawn_AddZombies(15, 4);
        5: Spawn_AddZombies(1, 5);
        6: Spawn_AddZombies(1, 6);
        7: Spawn_AddZombies(1, 107);
        8: Spawn_AddZombies(1, 108);
        9: Spawn_AddZombies(1, 9);
        11: begin
          Spawn_AddZombies(22, 1);
          Spawn_AddZombies(1, 11);
        end;
      end;
  
  case Modes.CurrentMode of
    1: begin
      points := CalculatePoints();
      if NumberOfWave > 1 then WriteConsole( 0, 'Zombies killed: ' + IntToStr( zombiesKilled ) + ' (score: '+IntToStr(points)+')', $CCCC99 );
      if points > MapRecord.Survival.Value then
      if MapRecord.Survival.Value > 0 then begin
        MapScore_UpdateRecord(points, not MapRecord.Survival.Shown);
        if not MapRecord.Survival.Shown then begin
          MapRecord.Survival.Shown := true;
          WriteConsole(0, 'Your team has managed to beat the high score, congratulations!', WHITE );
          MapScore_Display(0);
        end;
      end;
    end;
    2: if NumberOfWave > 1 then begin
        if VersusRound = 1 then WriteConsole( 0, 'Score - [Team 1]: '+IntToStr(Score[1][1])+'  [Team 2]: '+IntToStr(Score[2][1]), $CCCC99 )
          else
        WriteConsole( 0, 'Score - [Team 2]: '+IntToStr(Score[2][2]+ Score[2][1]) + ' (' +IntToStr(Score[2][2]) + ')'+
                     '  [Team 1]: '+IntToStr(Score[1][2]+ Score[1][1]) + '('+IntToStr(Score[1][2])+')', $CCCC99 );
    end;
    {3: if NumberOfWave > 1 then begin
      points := CalculatePoints();
      WriteConsole( 0, 'Score - [Survivors]: '+IntToStr(points)+'  [Zombies]: '+IntToStr(Score[2][1]), $CCCC99 )
    end;}
  end;
  WriteConsole( 0, 'Wave #' + IntToStr( NumberOfWave )+' (zombies'' hp: '+IntToStr(Spawn.Wave[1].ZombieHp)+ '%, zombies'' damage: '+IntToStr(Spawn.Wave[1].ZombieDmg)+'%)', Mode[Modes.RealCurrentMode].Color);
  WriteDebug(4, 'wave '+IntToStr( NumberOfWave ));
end;

procedure CheckProgress();
var i: word;
begin
  if Spawn.CurrentWave > 0 then begin
    if Spawn.Wave[Spawn.CurrentWave].Active then begin
      ZombiesLeft := Spawn.Wave[Spawn.CurrentWave].Counter;
    end else
      ZombiesLeft := 0;
  end else
    ZombiesLeft := 0;
    
//writeconsole(0, 'wave: ' + inttostr(zombiesleft), green);
  
  AliveZombiesInGame := 0;
  ZombiesInGame := 0;
  for i := 1 to MaxID do
    if player[i].Zombie then begin
      if Players[i].Alive then begin
        AliveZombiesInGame := AliveZombiesInGame + 1;
      end;
      ZombiesInGame := ZombiesInGame + 1;
    end;
    
  ZombiesLeft := AliveZombiesInGame + ZombiesLeft;    
//writeconsole(0, inttostr(AliveZombiesInGame) + '  (' + inttostr(ZombiesInGame) + ')  sum: ' + inttostr(ZombiesLeft), orange);

  if (not Spawn.Active) and (not StartGame) then
    if Boss.Intro = 0 then
      if ZombiesLeft = 0 then begin
        case Modes.CurrentMode of
          2: if (civilians > 0) and (Players_StatusNum(1) > 0) then begin
            i:= VSPOINTSFORWAVE;
            if (HumHealthMax > 0) and (HumDamageTaken < HumHealthMax) then i:= i + Round( (HumHealthMax - HumDamageTaken) / HumHealthMax * VSPOINTSFORHEALTH );
            Score[VersusRound][VersusRound]:= Score[VersusRound][VersusRound] + i;
          end;
        end;
        NextWave(0);
      end;
end;

procedure TickFlak(Victim, Shooter: byte; damage: single);
var x, y, x2, y2, d: single;
begin
  GetPlayerXY(Victim, x, y);
  GetPlayerXY(Shooter, x2, y2);
  x2 := x - x2;
  y2 := y - y2;
  d := Sqrt(x2*x2 + y2*y2);
  if d > 8.0 then begin // normalize
    x2 := x2 / d * 6.0;
    y2 := y2 / d * 6.0;
  end;
  CreateBullet(x-x2, y-10.0-y2, x2+Players[Victim].VelX,
  y2+Players[Victim].VelY, damage,10,Shooter);
end;

procedure BurnZombie(ID: byte);
var x, y: single; i: byte;
begin
  if not Players[molotovOwner].Active then exit;
  GetPlayerXY(ID, x, y);
  CreateBulletX(x, y, 0, 0, 99, 4, molotovOwner);
  CreateBulletX(x+10, y-10, 1, 0, 99, 10, molotovOwner);
  CreateBulletX(x-10, y-5, 0, -1, 99, 10, molotovOwner);
  for i:=1 to 5 do
    CreateBulletX( x, y - 5, RandInt(-70,70)/10, -RandInt(1,13)/4, 60, 5, molotovOwner );
  Fire_CreateBurningArea(x, y, 12, 180, 6, 6, molotovOwner);
end;

procedure Fires_OnPlayerInFire(ID, owner: byte);
begin
  if player[ID].Zombie then
  if ID <> Boss.ID then begin
    if players[ID].Health > AREADMG then begin
      Damage_DoRelative(ID, owner, -AREADMG, Heat);
    end else begin
      Damage_DoRelative(ID, owner, -Trunc(AREADMG - players[ID].Health - 1), Heat);  // "-" is here just to filter out negative dmg in OPD
    end;
  end;
  Map.CreateBullet(Players[ID].X, Players[ID].Y+RandFlt(-12.0, -2.0), 0.5*Players[ID].VelX, 0.5*Players[ID].VelY, FLAMEAREADMG, 5, Players[ID]);
end;

// * ------------------ *
// |       Priest       |
// * ------------------ *

procedure Priest_TryOperation(ID: byte; _type: byte);
var
  i: byte;
  a: smallint;
  X, Y: single;
begin
  if Priest = ID then begin
    case _type of
      2:
      if player[ID].holyWater >= EXOCOST then begin
        if player[ID].ExoTimer > 0 then begin
          WriteConsole(ID, 'Wait '+IntToStr(player[ID].ExoTimer) + ' seconds to do an exorcism', RED);
          exit;
        end;
        if player[ID].ExoTimer < 0 then begin
          WriteConsole(ID, 'Already in progress', RED);
          exit;
        end;  
        player[ID].ExoTimer := -5;
        player[ID].HolyWater := player[ID].HolyWater - EXOCOST;
        WriteConsole(0,Players[ID].Name+' has started an exorcism!',BLUE);
        if Spawn.CurrentWave > 0 then
          if Spawn.Wave[Spawn.CurrentWave].Style <> 0 then
            WriteConsole(ID, 'Warning: Zombies in this wave may be resistant to exorcism', BLUE);
        WriteConsole(ID,'Holy water left: '+IntToStr(player[ID].HolyWater)+' ml',BLUE);
      end else WriteConsole(ID, 'Not enough holy water to do an exorcism', RED);
    
      1:
      if player[ID].HolyWater >= SHOWERCOST then begin
        if player[ID].ShowerCooldown = 0 then begin
          player[ID].HolyWater := player[ID].HolyWater - SHOWERCOST;
          player[ID].ShowerCooldown := SHWDELAY;
          WriteConsole(ID, 'Holy water left: '+IntToStr(player[ID].HolyWater)+' ml', GREEN);
          a := -90;
          GetPlayerXY(ID, X, Y);
          Y := Y - 15;
          Spray(X, Y, 8.0, a, 300, 3, ID, false);
          for i := 0 to 5 do begin
            CreateBulletX(X, Y, RandFlt(-9,-4), RandFlt(-4,-0.5), a, 3, ID);
            CreateBulletX(X, Y, RandFlt(4,9), RandFlt(-4,-0.5), a, 3, ID);
          end;
        end else WriteConsole(ID, 'Shower is not ready yet. Wait '+IntToStr(player[ID].ShowerCooldown)+' seconds', RED);
      end else WriteConsole(ID, 'Not enough water to drop shower', RED);
    end;
  end else WriteConsole(ID, 'You are not the priest', RED);
end;

// ---

// Stops the match, clears vars
procedure Reset();
var
  c: byte;
begin
  WriteDebug(6, 'Reset()');
  FMSG.Active := false;
  TaskPolice_Reset();
  TaskMedic_Reset();
  DemoMan.ID := 0;
  mechanic := 0;
  sharpshooter := 0;
  priest := 0;
  Boss.ID := 0;
  Boss.Countdown := 0;
  Boss.Intro := 0;
  ScorePlayers := 0;
  NumberOfWave := 0;
  SatanCame := false;
  FFCame := false;
  PlagueCame := false;
  SG.BuildTimer := 0;
  Timer.Value := 0;
  ZombiesKilled := 0;
  Civilians := 25;
  SurvPwnMeter := 0.0;
  AvgSurvPwnMeter := 0.0;
  FarmerMRECD := FARMER_MRE_TIME;
  SetLength(MapRecord.Survival.GonePlayers, 0);
  MapRecord.Survival.Shown := false;
  SetLength(BlockedPlayers, 0);
  if Modes.CurrentMode = 1 then Score[1][1] := 0;
  for c := 1 to MAX_UNITS do
    if Players[c].Active then begin
      if Players[c].Human then
      if Players[c].Team < 5 then
      begin
        ServerSetTeam := true;
        command('/setteam5 ' + IntToStr(c) );
      end;
      Players_Clear(c);
    end;
  ResetBoss();
  Modes_ResetVotes();
  EarthQuake_Reset();
  GetMaxID();    
  Spawn_Reset();
  Spawn_ClearAllZombies();
  Scarecrow_Clear();
  Statguns_Reset();
  Statguns_Clear();
  Strike_Reset();
  Strike_ResetMarker();
  Sentry_Clear(true);
  AZSS_Reset();
  for c := 0 to MAX_CHARGES-1 do
    Charges_Clear(c);
  for c := 1 to MAX_MINES do
    Mines_Clear(c);
  for c := 1 to MAX_WIRES do
    Wires_ClearWire(c);
  for c := 1 to MAX_KITS do
    Kits_Kill(c);
  for c := 1 to MAX_BOMBS do
    ClusterBomb_Clear(c);
  for c := 1 to MAX_S_WAVES do
    SpecialWave[c] := false;
  for c := 1 to 90 do 
    Map.Objects[c].kill();
  Fire_ClearAll();
  if GameRunning then begin
    WriteDebug(4, 'cmmd:' + IntToStr(cmmd[0]) + ' cc:' + IntToStr(cmmd[1]) + ' hex:' + IntToStr(cmmd[2]));
    for c := 0 to 2 do cmmd[c] := 0;
  end;
  GameRunning := false;
  BW_Reset(HackermanMode);
end;

procedure DisplayVersus();
var i: byte;
  a, winTeam: shortint;
  str, timestr, timestr2: String;
begin
  if ShowVersusStats = 1 then
  begin
    VSStats[1]:= Score[1][1] + Score[1][2];  //Points Team 1 (first survivor, then zombie)
    VSStats[2]:= Score[2][2] + Score[2][1]; //Points Team 2 (first zombie, then survivor)
  end;  

  if VSStats[1] > VSStats[2] then a := -1 else a := 1; //a = winnerparticipant; at the end of game, team 1 is zombie team and team 2 is surivor team
  if a = -1 then winTeam := 1 else winTeam := 2;
  
  //Calculate Who's best
  if ShowVersusStats = 1 then
  begin  
    for i := 1 to MaxID do
    begin
      if Players[i].Active then begin
        if player[i].kills > VSStats[10] then
        if Players[i].Human then      
        begin
          VSStats[10] := player[i].kills;
          VSStats[9] := i;
        end;    
        if Player[i].civkills > VSStats[12] then
        if Players[i].Human then      
        begin
          VSStats[12] := Player[i].civkills;
          VSStats[11] := i;
        end;  
        if Player[i].survkills > VSStats[14] then
        if Players[i].Human then
        begin
          VSStats[14] := Player[i].survkills;
          VSStats[13] := i;
        end;
      end;  
    end;

    if VSStats[1] <> VSStats[2] then 
    begin 
      str := 'Team ' + IntToStr(winTeam) + ' won!';
      for i := 1 to MaxID do
        if Players[i].Active then
        if player[i].Participant = a then
          str := str + br + ' ' + Players[i].Name ;
    end else str := 'It''s a Tie!';
    BigText_DrawScreenX(DTL_NOTIFICATION,  0, str , 400, GREEN, iif(VSStats[1] <> VSStats[2], 0.08, 0.12), 30, 320 );      
  end;
  
  if ShowVersusStats > 1 then begin
    for i := 1 to MaxID do
    if Players[i].Active then
    case ShowVersusStats of    
      2:  begin
        if VSStats[1] <> VSStats[2] then
        if Player[i].Participant <> 0 then
          if Player[i].Participant = a then WriteConsole(i, 'Congratulations, Your team has won with ' + IntToStr(VSStats[winTeam]) + ' Points.', GREEN)
          else WriteConsole(i, 'Your team has lost with ' + iif(winTeam = 1, IntToStr(VSStats[2]), IntToStr(VSStats[1])) + ' points.', RED);                  
      end;
      3:   begin
        WriteConsole(i, '------------------------------------------------', INFORMATION);                        
        if VSStats[1] <> VSStats[2] then
          if Player[i].Participant <> 0 then
            str := 'The other team ' + iif(Player[i].Participant = a, 'lost', 'won') + ' with '
              + iif(Player[i].Participant = a, iif(winTeam = 1, IntToStr(VSStats[2]), IntToStr(VSStats[1])), IntToStr(VSStats[winTeam])) + ' points.'
          else str := 'Team ' + IntToStr(winTeam) + 'won with ' + IntToStr(VSStats[winTeam])
               + ' points over Team ' + iif(winTeam = 1, '2', '1') + ' (' + iif(winTeam = 1, IntToStr(VSStats[2]), IntToStr(VSStats[1]))
        else str := 'It''s a tie!';
        WriteConsole(i, str, INFORMATION);  
      end;
      4:   begin
        timestr := IntToStr( VSStats[5] div 60) + ':' + iif(VSStats[5] mod 60 <= 9,'0','') + IntToStr( VSStats[5] mod 60);
        timestr2 := IntToStr( VSStats[6] div 60) + ':' + iif(VSStats[6] mod 60 <= 9,'0','') + IntToStr( VSStats[6] mod 60);    
        
        if VSStats[5] > VSStats[6] then winTeam := 1 else winTeam := 2;
        if VSStats[5] <> VSStats[6] then
        str := 'Longest Time survived: ' + iif(winTeam = 1, timestr, timestr2) + ' by '
          + iif(Player[i].Participant = 0, 'Team ' + IntToStr(winTeam), iif(Player[i].Participant = a, 'your team ', 'the enemy team'))
          + ' (' + iif(Player[i].Participant = 0, 'Team ' + iif(winTeam = 1, '2: ', '1: '), iif(Player[i].Participant = a, 'Enemy Team: ', 'Your Team: '))
          + iif(winTeam = 1, timestr2, timestr) + ')'
        else str := 'Both Teams survived ' + timestr + ' minutes';
        WriteConsole(i, str, BLUE);  
        
        if VSStats[3] <> VSStats[4] then
          str := 'Most Waves survived: ' + IntToStr(iif(VSStats[3] > VSStats[4], VSStats[3], VSStats[4])) 
          + ' by ' + iif(Player[i].Participant = 0, 'Team ' + iif(VSStats[3] > VSStats[4], '1', '2'), iif(Player[i].Participant = iif(VSStats[3] > VSStats[4], -1, 1),
          'your team.', 'the enemy team.'))
        else str := 'Both teams survived ' + IntToStr(VSStats[3]) + ' waves.';  
        WriteConsole(i, str, BLUE);              
      end;  
      5:  if VSStats[10] <> 0 then
        WriteConsole(i, 'Most Zombies killed by ' + Players[VSStats[9]].Name + ': ' + IntToStr(VSStats[10]) + iif(i = VSStats[9], '', ' (You killed ' + IntToStr(Player[i].kills) + ')'), BLUE);                
          
      6: begin
        if VSStats[12] <> 0 then
          WriteConsole(i, 'Most Civilians eaten by ' + Players[VSStats[11]].Name + ': ' + IntToStr(VSStats[12]) + iif(i = VSStats[11], '', ' (You ate ' + IntToStr(Player[i].civkills) + ')'), $FF6666);                            
        if VSStats[14] <> 0 then
          WriteConsole(i, 'Most Survivors killed by ' + Players[VSStats[13]].Name + ': ' + IntToStr(VSStats[14]) + iif(i = VSStats[13], '', ' (You killed ' + IntToStr(Player[i].survkills) + ')'), $FF6666);            
      end;
    end;
  end;
  if ShowVersusStats = 5 then
  begin        
    i := 0;
    if VSStats[5] > VSStats[6] then begin 
      if VSStats[7] = 0 then i := VSStats[8] else i := VSStats[7];
    end else
      if VSStats[8] <> 0 then i := VSStats[8] else i := VSStats[7];
    if i <> 0 then

    if Players[i].Active then
      WriteConsole(0, 'Last Survivor standing the longest: ' + Players[i].Name, BLUE);    
  end;    
  
  if ShowVersusStats >= 7 then 
  begin
    for a := 1 to MAX_UNITS do
      player[a].Participant := 0;
    WriteConsole( 0, 'Use /vote ID or /vote <name> to make your choice. Type /votehelp for more info.', INFORMATION );    
    ShowVersusStats := 0
  end  else ShowVersusStats := ShowVersusStats + 1;
end;  


procedure EndGame();
var
  a: shortint;
  points, bestp, kills: integer;
begin
  WriteDebug(6, 'EndGame()');
  case Modes.CurrentMode of
    1: begin
      bestP := Players_MostKills();
      points := CalculatePoints();
      if Players_StatusNum(1) = 0 then WriteConsole( 0, 'Battle over, the base has been overrun!', RED);
      WriteConsole( 0, 'Score:            ' + IntToStr( points ), GREEN); 
      WriteConsole( 0, 'Waves survived:   ' + IntToStr( NumberOfWave ), GREEN); 
      WriteConsole( 0, 'Zombies Killed:   ' + IntToStr( zombiesKilled ), GREEN);
      WriteConsole( 0, 'Civilians Alive:  ' + IntToStr( civilians ), GREEN);
      WriteConsole( 0, 'Time Survived:    ' + IntToStr( (Timer.Value div 60) div 60) + ':' + iif((Timer.Value div 60) mod 60 <= 9,'0','') + IntToStr( (Timer.Value div 60) mod 60), GREEN);
      if bestP > 0 then begin
        kills := player[bestp].kills;
        WriteConsole( 0, 'Most kills by '+ Players[ bestP ].Name +': ' + IntToStr( kills ), GREEN);
        WriteConsole( 0, 'Most kills: ' + IntToStr( kills ), GREEN);
      end;
      if points > MapRecord.Survival.Value then begin
        WriteConsole( 0, 'Your team has managed to beat the high score, congratulations!', INFORMATION );
        MapScore_UpdateRecord(points, true);
        SendScoreMsg_IC(CurrentMap2, NumberOfWave, points);
      end;
      BigText_DrawScreenX(DTL_NOTIFICATION,  0, LSMap.EndText, 180, RGB(50,50,255), 0.2, 20, 370 );
    end;
    2: begin
      if VersusRound = 2 then
      begin
        VSStats[4] := NumberOfWave;
        VSStats[6] := (Timer.Value div 60);
        ShowVersusStats := 1;
      end;
      MapScore_UpdateTopPlayers('v');
    end;
    3: begin
      if Players_StatusNum(1) = 0 then WriteConsole( 0, 'Battle over, the base has been overrun!', RED);
      points := CalculatePoints();
      WriteConsole( 0, 'Survivors Score:  ' + IntToStr( points ), GREEN); 
      WriteConsole( 0, 'Infected Score:   ' + IntToStr( Score[2][1] ), GREEN); 
      WriteConsole( 0, 'Waves survived:   ' + IntToStr( NumberOfWave ), GREEN); 
      WriteConsole( 0, 'Zombies Killed:   ' + IntToStr( zombiesKilled ), GREEN);
      WriteConsole( 0, 'Civilians Alive:  ' + IntToStr( civilians ), GREEN);
      WriteConsole( 0, 'Time Survived:    ' + IntToStr( (Timer.Value div 60) div 60) + ':' + iif((Timer.Value div 60) mod 60 <= 9,'0','') + IntToStr( (Timer.Value div 60) mod 60), GREEN);
      if bestP > 0 then begin
        WriteConsole( 0, 'Most kills by '+ Players[ bestP ].Name +': ' + IntToStr( kills ), GREEN);
        WriteConsole( 0, 'Most kills: ' + IntToStr( kills ), GREEN);
      end;
      BigText_DrawScreenX(DTL_NOTIFICATION,  0, LSMap.EndText, 180, RGB(50,50,255), 0.2, 20, 370 );
      MapScore_UpdateTopPlayers('i');
    end;
  end;
  PerformReset := true;
  StartGame := false;
  StartGameCountdown := 0;
  if not Modes.CurrentMode = 2 then
  begin
    for a := 1 to MAX_UNITS do begin
      player[a].Participant := 0;
    end;
    WriteConsole( 0, 'Use /vote ID or /vote <name> to make your choice. Type /votehelp for more info.', INFORMATION );    
  end;
end;

procedure CreateUnit(ID, task: byte; team: shortint); // team 1/-1 (versus)
var
  Res: tResistance;
begin
  Players_Clear(ID);
  SetScore(ID, 0);
  player[ID].Participant := team;
  if team > 0 then begin
    SwitchTask(ID, task);
    player[ID].Status := 2;
    Player[ID].ReloadMode := Mode[Modes.RealCurrentMode].DefaultReloadMode;
    player[ID].ReloadTime := 0;
    
  end else begin
    player[ID].Status := -2;
    player[ID].Zombie := true;
    player[ID].task := task;
    player[ID].BossPlayTime := Timer.Value;
    player[ID].ZombiePlayTime := player[ID].BossPlayTime;
    Player[ID].SpawnTimer := 5;
    Resistance_FillMissingIn(Res, 2.0);
    Player[ID].Resistance := Res;
    WeaponMenu_EnableAll(ID);
    
    if player[ID].PunishmentZombie.Active then begin
      WriteConsole(0, Players[ID].Name + ' has been convicted for "' + player[ID].PunishmentZombie.Reason + '"', B_RED);
      WriteConsole(0, 'He has ' + FormatTime(player[ID].PunishmentZombie.Time) + ' to do as a Penitential Zombie', B_RED);
      WriteConsole(0, 'Don''t spare him!', B_RED);
    end;
  end;
  player[ID].played := true;
end;

procedure BlockPlayer(ID: byte);
var l: smallint; i: byte; IP: string;
begin
  l := Length(BlockedPlayers);
  SetLength(BlockedPlayers, l + 1);
  BlockedPlayers[l].Name := Players[ID].Name;
  BlockedPlayers[l].HWID := IDToHW(ID);
  IP := IDToIP(ID);
  for i := 0 to 3 do
    BlockedPlayers[l].IP[i] := StrToInt(GetPiece(IP, '.', i));
end;

function PlayerBlocked(ID: byte; message, admmessage: boolean): boolean;
var i: smallint; IP: array [0..3] of byte; Name: string;
begin
  Name := Players[ID].Name;
  for i := 0 to 3 do
    IP[i] := StrToInt(GetPiece(IDToIP(ID), '.', i));
  for i := 0 to Length(BlockedPlayers) - 1 do
    if (BlockedPlayers[i].HWID = IDToHW(ID)) then begin
      if admmessage then
        WriteDebug(5, Name + ' - HWID blocked');
      Result := true;
    end else
    if BlockedPlayers[i].IP[0] = IP[0] then
      if BlockedPlayers[i].IP[1] = IP[1] then begin
        if (IP[2] = BlockedPlayers[i].IP[2]) and (IP[3] = BlockedPlayers[i].IP[3]) then begin
          if admmessage then
            WriteDebug(5, Name + ' - IP blocked (static)');
          Result := true;
          break;
        end else if BlockedPlayers[i].Name = Name then begin
          Result := true;
          if admmessage then
            WriteDebug(5, Name + ' - IP blocked (dynamic)');
          break;
        end else begin // in this case don't block, only warn
          if message then begin
            message := false;
            WriteConsole(ID, 'Changing your IP/HWID to rejoin the game after death, with different task or team will result in a ban (!rules)', RED);
          end;
          if admmessage then
            WriteDebug(5, Name + ' - IP warning');
          break;
        end;
      end;
end;

function FreeTasks(): tStack8;
var i,j: byte; b: boolean;
begin
  stack8_alloc(Result, MAX_TASKS);
  for j := 1 to MAX_TASKS do begin
    b := false;
    for i := 1 to MAX_UNITS do
      if player[i].Status > 0 then
        if player[i].task = j then begin
          b := true;
          break;
        end;
    if not b then stack8_push(Result, j);
  end;
end;

function FreeTasksString(full: boolean): String;
var tasks: tStack8; i, n: byte;
begin
  tasks := FreeTasks();
  if tasks.length > 0 then begin
    n := tasks.length - 1;
    for i := 0 to n do begin
      if full then Result := Result + TaskToName(tasks.arr[i], false) else Result := Result + TaskToShortName(tasks.arr[i], false);
      if i < n then Result := Result + ', ';
    end;
  end;
end;

function RandomTask(): byte;
var tasks: tStack8;
begin
  tasks := FreeTasks();
  if tasks.length > 0 then Result := tasks.arr[RandInt(0, tasks.length-1)] else Result := 4;
end;

procedure TryJoinSurvivors(ID: byte);
var a, i, z, w: integer;
begin
  //if Modes.CurrentMode <> 1 then begin
  if not GameRunning then begin
    WriteConsole(ID, 'The game is not running at the moment', RED);
    Exit;
  end;
  if player[ID].Status <> 0 then begin
    WriteConsole(ID, 'Only spectators are allowed to join teams', RED);
    Exit;
  end;
  if PlayerBlocked(ID, true, true) then begin
    WriteConsole(ID, 'You''ve already played in this round', RED);
    Exit;
  end;
  if ID > 12 then begin
    WriteConsole(ID, 'Please rejoin in order to play, your id is too high -' + IntToStr(ID), RED);
    Exit;
  end;

  case Modes.CurrentMode of
    1: if SurvivalSlotsNum = 0 then begin
      WriteConsole(ID, 'There are no free slots in this game left, please wait until the round ends', RED);
      exit;
    end else begin
      i := 1 + RandInt_(MAX_TASKS-1);
      z := MAX_TASKS mod 2;
      w := MAX_TASKS-2;
      repeat
        a := 1 + RandInt_(w); // find random step for the second loop
        if MAX_TASKS mod a = 0 then continue;
      until z <> a mod 2; // which doesn't get stuck on the same positions
      w := 0;
      while TaskAvailable[i] = 0 do begin
        w := w + 1;
        if w > MAX_TASKS then begin
          WriteConsole(ID, 'There are no free slots in this game left, please wait until the round ends', RED);
          SurvivalSlotsNum := 0;
        end;
        i := i + a;
        if i > MAX_TASKS then i := i - MAX_TASKS;
      end;
    end;
    2: begin
      w := Players_ParticipantNum(1);
      if w >= Game.MAXPLAYERS - Game.MAXPLAYERS div 2 then begin
        WriteConsole(ID, 'There are no free slots in the survivors team', RED);
        exit;
      end else
      if w > Players_ParticipantNum(-1) then begin
        WriteConsole(ID, 'There are fewer players in the zombie team. Try joining it instead (/joinZ)', RED);
        exit;
      end;
    end;
    //3:
  end;
  if i = 0 then begin
    if Cop.ID = 0 then
      w := 6
    else if Medic.ID = 0 then
      w := 3
    else
      w := RandomTask();
  end else begin
    w := i;
    if TaskAvailable[i] > 0 then
      TaskAvailable[i] := TaskAvailable[i] - 1
    else
      w := RandomTask();
    SurvivalSlotsNum := 0;
    for i := 1 to MAX_TASKS do // update number of remaining free slots
      SurvivalSlotsNum := SurvivalSlotsNum + TaskAvailable[i];
  end;
  CreateUnit(ID, w, 1);
  if WeaponSystem.Enabled then begin
    BaseWeapons_AddTaskWeapons(ID);
    BaseWeapons_Refresh(false);
  end;
  player[ID].Status := 1;
  SetTeam(HUMANTEAM, ID, true);
  player[ID].ShowTaskinfo := true;
  WriteConsole(0, Players[ID].Name + ' has joined the surivors team as a ' + TaskToName(w, false), WHITE);
  WriteDebug(5, Players[ID].Name + ' has joined as a ' + TaskToName(w, false));
  //end else WriteConsole(ID, 'Joining teams is possible only in Versus and Infection mode', RED);
end;

procedure TryJoinZombies(ID: byte);
var w: integer;
begin
  if Modes.CurrentMode <> 1 then begin
    if GameRunning then begin
      if player[ID].Status = 0 then begin
        if not PlayerBlocked(ID, true, true) then begin
          w := Players_ParticipantNum(-1);
          if (w < Game.MAXPLAYERS div 2) or (Modes.CurrentMode = 3) then begin
            if (Players_ParticipantNum(1) >= w) or (Modes.CurrentMode = 3) then begin
              CreateUnit(ID, -1, -1);
              Player[ID].SpawnTimer := round(15 * ((randInt(1, 9) - 5) / 10 + 1));
              WriteConsole(0, Players[ID].Name + ' has joined the game as a zombie', WHITE);
              WriteConsole(ID, 'You will be spawned soon', GREEN);
              WriteDebug(5, Players[ID].Name + ' has joined as a zombie');
            end else WriteConsole(ID, 'There are fewer players in survivors team. Try joining survivors team instead (/joinS)', RED);
          end else WriteConsole(ID, 'There are no free slots left in the zombie team', RED);
        end else WriteConsole(ID, 'You''ve already played in this round', RED);
      end else WriteConsole(ID, 'Only spectators are allowed to join teams', RED);
    end else WriteConsole(ID, 'The game is not running at the moment', RED);
  end else WriteConsole(ID, 'Joining zombie team is possible only in Versus and Infection mode', RED);
end;

procedure StartMatch(first: boolean);
var
  i, hn, m1, m2: shortint;
  specs, inf, hum, tasks: tStack8;
begin
  WriteDebug(6, 'StartMatch()');
  GetMaxID();
  // Switch advanced spawn system
  AZSS_Switch(Mode[Modes.RealCurrentMode].AZSS, Mode[Modes.RealCurrentMode].AZSS_Hard);
  if (Modes.CurrentMode = 2) and (first) then
    for i := 1 to 14 do VSStats[i] := 0;
  if (Modes.CurrentMode <> 2) or (first) then
    for i := 1 to MaxID do Players_ClearStats(i);
  
  for i:=1 to MaxID do
    if Players[i].Active then
    if not Players[i].Human then begin
      player[i].kicked := true;
      Players[i].Kick(TKickSilent);
    end;

  case Modes.CurrentMode of
    1: begin
      for i := 1 to MaxID do // create humans stack
        if Players[i].Active then
        if Players[i].Human then
        if not player[i].PunishmentZombie.Active then begin
          hn := hn + 1;
          stack8_push(hum, i);
        end else begin
          CreateUnit(inf.arr[i], 201, -1);
        end;
      SetLength(MapRecord.Survival.GonePlayers, 0);
    end;
    2: begin
      if not first then begin
        for i := 1 to MaxID do
          if Players[i].Human then begin
          if Players[i].Active then
            case player[i].Participant of
              1: stack8_push(inf, i);
              -1: stack8_push(hum, i);
              else stack8_push(specs, i);
            end;
          end;
      end else
        for i := 1 to MaxID do
          if Players[i].Human then
          if Players[i].Active then
            stack8_push(specs, i);    
      while specs.length > 0 do
        if inf.length < hum.length then stack8_push(inf, stack8_pop(specs, RandInt(0, specs.length-1))) else
          stack8_push(hum, stack8_pop(specs, RandInt(0, specs.length-1)));
        hn := hum.length;

      if inf.length > 0 then
        for i := 0 to inf.length-1 do
          CreateUnit(inf.arr[i], -1, -1);        
    end;
    3: begin
      for i := 1 to MaxID do // create humans stack
        if Players[i].Active then
        if Players[i].Human then begin
          hn := hn + 1;
          stack8_push(hum, i);
        end;
    end;
  end;


  if hum.length > MAX_TASKS then // if more players than tasks add farmers
    for i := 1 to hum.length - MAX_TASKS do
      stack8_push(tasks, 4);
  for i := 1 to MAX_TASKS do // create tasks stack
    if (i <> 6) and ((Modes.RealCurrentMode <> 1) or ((i <> 6) and (i <> 1))) and ((i <> 3) or (hum.length < 3)) then  // <> doc; <> cop; <> mech
      stack8_push(tasks, i);
  case hum.length of
    1,2: CreateUnit(stack8_pop(hum, RandInt(0, hum.length-1)), 6, 1);
    else begin
      CreateUnit(stack8_pop(hum, RandInt(0, hum.length-1)), 6, 1);
      CreateUnit(stack8_pop(hum, RandInt(0, hum.length-1)), 3, 1);
      if Modes.RealCurrentMode = 1 then
        CreateUnit(stack8_pop(hum, RandInt(0, hum.length-1)), 1, 1);
    end;
  end;
  while hum.length > 0 do
    CreateUnit(stack8_pop(hum, RandInt(0, hum.length-1)), stack8_pop(tasks, RandInt(0, tasks.length-1)), 1);

  if (Modes.CurrentMode = 2) then begin // versus
    m2 := Game.MAXPLAYERS div 2;
    m1 := m2 + Game.MAXPLAYERS mod 2;
    if first then begin
      VersusRound := 1;
      Score[1][1] := 0;
      Score[1][2] := 0;
      Score[2][2] := 0;
      Score[2][1] := 0;
    end else begin
      VersusRound := 2;
    end;
  end else begin // limited slots for survival
    for i := 1 to MAX_TASKS do
      TaskAvailable[i] := 1;
    if Game.MAXPLAYERS > MAX_TASKS then
      TaskAvailable[4] := Game.MAXPLAYERS - (MAX_TASKS - 1); // farmers
    SurvivalSlotsNum := 0;
    for i := 1 to MAX_UNITS do
      if Players[i].Active then
      if Players[i].Human then
      if player[i].Status = 2 then
        if TaskAvailable[player[i].Task] > 0 then begin
          incB(TaskAvailable[player[i].Task], -1);
        end;
    for i := 1 to MAX_TASKS do // count remaining slots
      SurvivalSlotsNum := SurvivalSlotsNum + TaskAvailable[i];
  end;
  //||Reset Weapons in Base
  if WeaponSystem.Enabled then begin
    BaseWeapons_Refresh(true);
  end;
  AZSS_Switch(Mode[Modes.RealCurrentMode].AZSS, Mode[Modes.RealCurrentMode].AZSS_Hard);
  StartGame := true;
  StartGameCountdown := 0;
end;
  
procedure VersusSwapTeams();
var i: byte;
begin
  i := Players_ParticipantNum(0); // get the number of "spectators" who didn't play in any team
  if (Players_HumanNum <= 1) or (Players_ParticipantNum(1) + i = 0) or (Players_ParticipantNum(-1) + i = 0) then begin
    WriteConsole(0, 'There are no players to form two teams and start the second Versus round', WHITE);
    EndGame();
  end else begin
    MapScore_UpdateTopPlayers('v');
    VSStats[5] := (Timer.Value div 60);
    VSStats[3] := NumberOfWave;
    Reset();
    BigText_DrawScreenX(DTL_NOTIFICATION, 0, 'GAME OVER!', 180, RGB(50,50,255), 0.15, 20, 370);
    StartMatch(false);
  end;
end;


procedure Untask(ID: byte; Stuff: boolean);
var i: byte;
begin
  player[ID].Task := 0;
  if ID = sharpshooter then sharpshooter := 0;
  if ID = Cop.ID then Cop.ID := 0;
  if ID = Medic.ID then Medic.ID := -1;
  if ID = DemoMan.ID then DemoMan.ID := 0;
  if ID = mechanic then mechanic := 0;
  if ID = priest then priest := 0;
  if ID = scarecrow.owner then if Stuff then Scarecrow_Clear();
  if ID = Sentry.Owner then if Stuff then Sentry_Clear(true);
  
  for i := 1 to MAX_WIRES do
    if Wire[i].Owner = ID then Wires_ClearWire(i);
  for i := 1 to MAX_MINES do 
    if Mines.Mine[i].Owner = ID then Mines_Clear(i);
  for i := 0 to MAX_CHARGES-1 do 
    if Charge[i].Owner = ID then Charges_Clear(i);  
end;

procedure ProcessMolotovExplosion();
var i,j: byte; x, y: single;
begin
  if molotovOwner = 0 then exit;
  if molotovsInGame <= 0 then exit;
  for i:=1 to MAX_OBJECTS do
    if Map.Objects[i].Active then
      if Map.Objects[i].Style = 24 then begin
        x:=Map.Objects[i].X;
        y:=Map.Objects[i].Y;
        CreateBulletX(x, y, 0, 5, 99, 4, molotovOwner);
        KillObject(i);
        Damage_ZombiesAreaDamage(molotovOwner, x, y, 45, 80, 4000, Heat);
    //  procedure Fire_CreateBurningArea(X, Y: single; ParticleVel: single; casting_rng: word; duration, n, owner: byte);
        if RayCast(x, y - 60, x, y - 60, false, true, false) then begin
          if RayCast(x, y, x, y + 40, false, true, false) then
            if not RayCast(x, y - 60, x, y + 40, false, true, false) then y := y - 60;
        end;
        CreateBulletX(x + RandInt(-20,20), y, RandFlt(-2,2), 5, 99, 8, molotovOwner );
        for j:=0 to 5 do
          CreateBulletX(x, y, RandInt(-90,90)/10, -RandInt(-10,30)/10, -5, 5, molotovOwner );
        Fire_CreateBurningArea(x, y, 12, 120, 12, 7, molotovOwner);
        if molotovsInGame > 0 then molotovsInGame:=molotovsInGame-1 else break;
      end;
end;

// [Bullet sprays]

procedure Spray_Start(ID, T: integer; v0: single);
var  i, l: smallint;
  found: boolean;
begin
  l := Length(SpraySyst.Spray);
  for i := 0 to l - 1 do
    if not SpraySyst.Spray[i].Active then begin
      found := true;
      l := i;
      break;
    end;
  if not found then begin
    SetLength(SpraySyst.Spray, l + 1);
  end;
  SpraySyst.Spray[l].Active := true;
  SpraySyst.Spray[l].t := 8;
  SpraySyst.Spray[l].Target := T;
  SpraySyst.Spray[l].Owner := ID;
  SpraySyst.Spray[l].v0 := v0;
  SpraySyst.Spray[l].vFactor := 1.3;
  SpraySyst.Active := true;
  SpraySyst.N := l;
end;

procedure Spray_Tick(n: byte);
var  X, Y, X2, Y2, vx, vy, Vax, D: single;
begin
  SpraySyst.Spray[n].T := SpraySyst.Spray[n].T - 1;
  if SpraySyst.Spray[n].Target > 0 then begin
    GetPlayerXY(SpraySyst.Spray[n].Target, X2, Y2);
  end else begin
    X2 := Players[SpraySyst.Spray[n].Owner].MouseAimX;
    Y2 := Players[SpraySyst.Spray[n].Owner].MouseAimY;
  end;
  GetPlayerXY(SpraySyst.Spray[n].Owner, X, Y);
  Y := Y - 15;
  Y2 := Y2 - 15;
  Vx := X2 - X;
  Vy := Y2 - Y;
  D := Sqrt(Vx * Vx + Vy * Vy) / SpraySyst.Spray[n].vFactor / SpraySyst.Spray[n].v0;
  if SpraySyst.Spray[n].Target > 0 then
    Vax := Abs(Vx)*0.02;
  Vx := Vx / D + Players[SpraySyst.Spray[n].Owner].VelX * 0.5;
  Vy := Vy / D + Players[SpraySyst.Spray[n].Owner].VelY * 0.5 - Vax;
  CreateBulletX(X, Y, vx + RandFlt(-1, 1), vy + RandFlt(-2, 2) * (1-SpraySyst.Spray[n].vFactor), 1, 3, SpraySyst.Spray[n].Owner);
  SpraySyst.Spray[n].vFactor := SpraySyst.Spray[n].vFactor * 0.90;
end;

procedure Spray_Process();
var  i: byte;
  Active: boolean;
begin
  if SpraySyst.Active then begin
    for i := 0 to SpraySyst.N do
      if SpraySyst.Spray[i].Active then begin
        if SpraySyst.Spray[i].T > 0 then begin
          Active := true;
          Spray_Tick(i);
        end else begin
          SpraySyst.Spray[i].Active := false;
        end;
      end;
    SpraySyst.Active := Active;
  end;
end;

// support for two AOI modes
procedure Vomit(ID, T: integer; v0: single);
begin
  Spray_Start(ID, T, v0);
  if player[ID].Status = 0 then
    BW_RandZombChat(ID, BW_VomitingTauntsVomit, 0.10);
  if T > 0 then
  if Players[T].Dummy then begin
    if T = Scarecrow.ID then Scarecrow_OnDamage(20) else
    if T = Sentry.ID then Sentry_OnDamage(1);
  end;
end;

procedure KamiKaboom(ID: byte; r: single); // IgnitionBulletOwner should be different than kamikaze's id because bullets don't collide with owner's body. If 0, it will search for ir.
var
  i: byte;
  k: word;
  x, y, x2, y2, d: single;
  IgnitionBulletOwner: byte;
begin
  GetPlayerXY(ID, x, y);
  for i := 1 to MaxID do
    if Players[i].Dummy then begin
      GetPlayerXY(i, x2, y2);
      d := SqrDist(x, y, x2, y2);
      if d < r*r then begin
        k := (Trunc(r-RayCast3(x, y-8, x2, y2-8, 4, 4)*d)) div 2;
        if i = Scarecrow.ID then Scarecrow_OnDamage(k) else
        if i = Sentry.ID then Sentry_OnDamage(k);
      end;
    end;
  for i := 1 to (SG.Num - 1) do
    if SqrDist(X, Y, statgun[i].X, statgun[i].Y) <= r*r/4 then begin
      Statguns_DestroySG(i, false);
      CreateBulletX(statgun[i].X - 10, statgun[i].Y, 0, 0, 0, 5, ID);
      WriteConsole(0, 'Kamikaze zombie has destroyed a stationary gun', RED);
    end;
  for i := 1 to MAX_WIRES do
    if wire[i].Active then begin
      d := SqrDist(X, Y, (wire[i].bundle[0].x + wire[i].bundle[1].x)/2, (wire[i].bundle[0].y + wire[i].bundle[1].y)/2);
      if d <= r*r then begin
        k := Trunc(Sqrt(d)/100.0 * 15.0);
        Wires_Damage(i, k);
      end;
    end;
  
  // Find an ID for a detonating bullet.
  // It can't be the same as the ozmbie's one, because it won't collide on body.
  IgnitionBulletOwner := player[ID].KamiKiller;
  if IgnitionBulletOwner = 0 then begin
    for i := 1 to MaxID do
      if ID <> i then
      if Players[i].Active then begin
        if player[i].Zombie then begin
          IgnitionBulletOwner := i;
          break;
        end;
        IgnitionBulletOwner := i;
      end;
  end;
  if player[ID].Task = 11 then begin
    y := y - 10.0;
    Charge_Explosion(x, y, 40, 9, ID);
    CreateBulletX(x, y, 0, 0, 0, 4, IgnitionBulletOwner); // detonating bullet
    // x, y, speed, dmg, rng, style, owner, raycast
    k := Spray(x, y, 8.0, 5, 400, 8, ID, false);
    if k > 5 then k := 5;
    //procedure nova_3(X,Y,dir_x,dir_y,r,speedmin,speedmax,power,cutoff,start: single; n: word; style, id: byte);
    nova_3(x, y, 0, 0, 10,5,8,1,ANG_PI,ANG_PI,5-k,8,ID);
  end else begin
    CreateBulletX(x + RandFlt(-20, -15), y + RandFlt(-1, 5), -1, 0, 10, 4, ID);
    CreateBulletX(x + RandFlt(15, 20), y + RandFlt(-1, 5), 1, 0, 10, 4, ID);
    CreateBulletX(x + RandFlt(-3, 3), y + RandFlt(-20, -10), 0, -1, 10, 4, ID);
    if Players[ID].Human then begin
      d := Players[ID].Ping / 16.7;
      if d > 6.0 then D := 6.0;
      X := X + Players[ID].VELX * d;
      Y := Y + Players[ID].VELY * d;
    end;
    CreateBulletX(x, y-10, 0, 0, 0, 4, IgnitionBulletOwner); // detonating bullet
    nova_3(x, y, 0, 0, 20,2.5,5,0,ANG_PI,ANG_PI,5,14,ID);
  end;
  Damage_DoAbsolute(ID, iif(player[ID].KamiKiller = 0, ID, player[ID].KamiKiller), MaxHealth);
  if player[ID].Status < 0 then player[ID].Status := -2;
  player[ID].KickTimer := 2;
end;

procedure BurningBreath(ID: integer; x2, y2: single; dmg: integer);
var x, y, a, vx, vy, dist, close_dist, angle_diff, d: single; i: integer;
begin
  GetPlayerXY(ID, x, y);
  vx := x2-x;
  vy := y2-y;
  dist := Sqrt(vx*vx + vy*vy);
  close_dist := dist;
  if close_dist > 14 then close_dist := 14; // keep start distance from shooter not to set him on fire
  x := x + vx / dist * close_dist;
  y := y + vy / dist * close_dist;
  a := Math.arctan2(vy, vx);
  //Shoot(x, y, Angle, add_vx, add_vy, vmin, vmax, Spread, Accuracy, Damage: single; Style, ID, n: byte);
  vx := Players[ID].VELX/2;
  vy := Players[ID].VELY/2;
  Shoot(x, y, a, vx, vy, 5, 6, 0.4, 0.05, 0, 5, ID, 5);
  Shoot(x, y, a, vx, vy, 4, 4.5, 0, 0, 0, 5, ID, 1);
  
  // Hurt targets in range of fire, with dmg depending on distance and angle difference
  for i := 1 to MaxID do
  if Players[i].Alive then
  if Players[i].Active then begin
    dist := Distance(x, y, Players[i].X, Players[i].Y);
    if dist < 210.0 then begin
      angle_diff := Math.abs(ShortenAngle(Math.arctan2(Players[i].Y-y, Players[i].X-x) - a));
      if angle_diff < ANGLE_30 then begin
        angle_diff := 1.0 - angle_diff / ANGLE_30;
        dist := 1.0 - dist / 210.0;
        d := Math.pow(dist, 0.8) * angle_diff;
        if player[i].Status = 1 then begin      
          Damage_DoRelative(i, ID, Trunc(d * dmg), Heat);
        end else
        if Players[i].Dummy then begin
          if i = Scarecrow.ID then Scarecrow_OnDamage(Round(40.0*d)) else
          if i = Sentry.ID then Sentry_OnDamage(Round(3.0*d));
        end;
      end;
    end;
  end;
end;

procedure ProcessStarting();
var i: byte;
  str: string;
begin
  case Modes.CurrentMode of
    1: begin
      case StartGameCountdown of
        0: begin
          BigText_DrawScreenX(DTL_NOTIFICATION, 0, 'The Last Stand - ' + Mode[Modes.RealCurrentMode].Name, 450, Mode[Modes.RealCurrentMode].Color, 0.1, 20, 370 );
          MapVotes_Reset();
        end;
        2: begin
          if Players_HumanNum = 0 then begin
            Reset();
            StartGameCountdown := 0;
            StartGame := false;
            exit;
          end;
          for i := 1 to MAX_UNITS do
            if player[i].Participant = 1 then
            if player[i].Status = 2 then begin // anti packet loss
              player[i].Status := 1;
              SetTeam(HUMANTEAM, i, true);
              SetTeam(HUMANTEAM, i, true);
              StartGameCountdown := StartGameCountdown - 1;
              break;
            end;
          GameRunning := true;  
        end;
        
        3: begin
        end;

        4: begin
          WriteConsole( 0, 'Tasks:', ORANGE  );
          for i := 1 to MAX_UNITS do
            if player[i].Participant = 1 then
            begin
              WriteConsole( 0, ' ' + taskToName( player[ i ].task, false) + ': ' + Players[ i ].Name, WHITE  );
              BigText_DrawScreenX(DTL_NOTIFICATION, i, 'You are the ' + taskToName( player[ i ].task, false), 400, RGB(255,255,100), 0.08, 20, 370 );
            end;
          WriteConsole( 0, '------', ORANGE  );
        end;
        6: begin
          for i := 1 to MAX_UNITS do
          if player[i].Participant <> 0 then begin
            taskInfo(i);
          end;
          StartGame := false;
          StartGameCountdown := 0;
          NumberOfWave := 0;
          NextWave(0);
        end;

      end;
      StartGameCountdown := StartGameCountdown + 1;
    end;
    2: begin
      case StartGameCountdown of
        0: begin
          BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'The Last Stand - Versus' + br + 'Round: ' + IntToStr(VersusRound) + '/2', 450, Mode[3].Color, 0.1, 20, 370 );
          if VersusRound = 1 then MapVotes_Reset();
          if Players_ParticipantNum(-1) + Players_ParticipantNum(1) = 1 then StartGameCountdown := 6;
        end;
        2: if (Players_ParticipantNum(-1) > 0) then if (Players_ParticipantNum(1) > 0) then begin
          for i := 1 to MAX_UNITS do
            if player[i].Participant = 1 then
              str := str + ' ' + Players[i].Name + br;
          BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'Team ' + IntToStr(VersusRound) + ' - Survivors' + br + str , 220, WHITE, 0.1, 30, 320 );
        end else StartGameCountdown := 6;
        5: begin
          WriteConsole( 0, 'Survivors:', ORANGE  );
          for i := 1 to MAX_UNITS do
            if player[i].Participant = 1 then
            begin
              WriteConsole( 0, ' ' + taskToName( player[ i ].task, false) + ': ' + Players[ i ].Name, WHITE  );
            end;
          WriteConsole( 0, 'Zombies:', ORANGE  );
          for i := 1 to MAX_UNITS do
            if player[i].Participant = -1 then
            begin
              WriteConsole( 0, ' ' + Players[ i ].Name, $FF6666  );
            end;
          BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'vs', 220, $FFFF64, 0.15, 40, 330 );
        end;
        6: if (Players_ParticipantNum(-1) > 0) then if (Players_ParticipantNum(1) > 0) then begin
          for i := 1 to MAX_UNITS do
            if player[i].Participant = -1 then
              str := str + ' ' + Players[i].Name + br;
          BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'Team ' + IntToStr(VersusRound mod 2 + 1) + ' - Zombies' + br + str , 330, $FF6666, 0.1, 30, 320 );
        end;
        8: begin
          if Players_HumanNum =0 then begin
            Reset();
            StartGameCountdown := 0;
            StartGame := false;
            exit;
          end;
          for i := 1 to MAX_UNITS do
            if player[i].Participant = 1 then
              if player[i].Status = 2 then begin // anti packet loss
                player[i].Status := 1;
                SetTeam(HUMANTEAM, i, true);
                SetTeam(HUMANTEAM, i, true);
                StartGameCountdown := StartGameCountdown - 1;
                break;
              end;
          GameRunning := true;
        end;
        
        9: begin
          for i := 1 to MAX_UNITS do
            if player[i].Participant = 1 then
              begin
                BigText_DrawScreenX(DTL_NOTIFICATION,  i, 'You are the ' + taskToName( player[ i ].task, false), 400, $FFFF64, 0.1, 20, 370 );
              end;
            end;

        10: begin
          for i := 1 to MAX_UNITS do
          if player[i].Participant <> 0 then begin
            taskInfo(i);
          end;
          StartGame := false;
          StartGameCountdown := 0;
          NumberOfWave := 0;
          NextWave(0);
        end;
        //else begin
        //  WriteConsole( 0, '...' + IntToStr(4 - StartGameCountdown), $CCCC99 );
        //end;
      end;
      StartGameCountdown := StartGameCountdown + 1;
    end;
    3: begin
      case StartGameCountdown of
        0: begin
          BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'The Last Stand - ' + Mode[4].Name, 450, Mode[4].Color, 0.1, 20, 370 );
          MapVotes_Reset();
        end;
        2: begin
          if Players_HumanNum = 0 then begin
            Reset();
            StartGameCountdown := 0;
            StartGame := false;
            exit;
          end;
          for i := 1 to MAX_UNITS do
            if player[i].Participant = 1 then
            if player[i].Status = 2 then begin // anti packet loss
              player[i].Status := 1;
              SetTeam(HUMANTEAM, i, true);
              SetTeam(HUMANTEAM, i, true);
              StartGameCountdown := StartGameCountdown - 1;
              break;
            end;
          GameRunning := true;
        end;
        
        3: begin

        end;

        4: begin
          WriteConsole( 0, 'Tasks:', ORANGE  );
          for i := 1 to MAX_UNITS do
            if player[i].Participant = 1 then
            begin
              WriteConsole( 0, ' ' + taskToName( player[ i ].task, false) + ': ' + Players[ i ].Name, WHITE  );
              BigText_DrawScreenX(DTL_NOTIFICATION,  i, 'You are the ' + taskToName( player[ i ].task, false), 400, RGB(255,255,100), 0.08, 20, 370 );
            end;
          WriteConsole( 0, '------', ORANGE  );
        end;
        6: begin
          for i := 1 to MAX_UNITS do
          if player[i].Participant <> 0 then begin
            taskInfo(i);
          end;
          StartGame := false;
          StartGameCountdown := 0;
          NumberOfWave := 0;
          NextWave(0);
        end;

      end;
      StartGameCountdown := StartGameCountdown + 1;
    end;
  
    4: begin
      case StartGameCountdown of
        0: begin
          BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'The Last Stand - ' + Mode[5].Name, 450, Mode[5].Color, 0.1, 20, 370 );
          MapVotes_Reset();
        end;
        2: begin
          if Players_HumanNum = 0 then begin
            Reset();
            StartGameCountdown := 0;
            StartGame := false;
            exit;
          end;
          for i := 1 to MAX_UNITS do
            if player[i].Participant = 1 then
              if player[i].Status = 2 then begin // anti packet loss
                player[i].Status := 1;
                SetTeam(HUMANTEAM, i, true);
                SetTeam(HUMANTEAM, i, true);
                StartGameCountdown := StartGameCountdown - 1;
                break;
              end;
        end;
        
        3: begin
          GameRunning := true;
        end;

        4: begin
          WriteConsole( 0, 'Tasks:', ORANGE  );
          for i := 1 to MAX_UNITS do
            if player[i].Participant = 1 then
            begin
              WriteConsole( 0, ' ' + taskToName( player[ i ].task, false) + ': ' + Players[ i ].Name, WHITE  );
              BigText_DrawScreenX(DTL_NOTIFICATION,  i, 'You are the ' + taskToName( player[ i ].task, false), 400, RGB(255,255,100), 0.08, 20, 370 );
            end;
          WriteConsole( 0, '------', ORANGE  );
        end;
        6: begin
          for i := 1 to MAX_UNITS do
          if player[i].Participant <> 0 then begin
            taskInfo(i);
          end;
          StartGame := false;
          StartGameCountdown := 0;
          NumberOfWave := 0;
          NextWave(0);
        end;

      end;
      StartGameCountdown := StartGameCountdown + 1;
    end;
  end;
  if StartGameCountdown = 1 then begin
    if LSMap.StartText <> '' then
      WriteConsole(0, LSMap.StartText, WHITE);
    if LSMap.DifficultyPercent <> 100 then
      WriteConsole(0, ' Map difficulty: ' + IntToStr(LSMap.DifficultyPercent) + '%', WHITE);
    if weaponsystem.enabled then begin
      WriteConsole(0, 'Advanced weapon system is currently ON', NWSCOL);
    end else
      WriteConsole(0, 'Advanced weapon system is currently OFF', NWSCOL);  
  end;
end;

// this function protects from results of packetloss on player zombies
// respawning them again if they don't move after spawn
procedure CheckPlayers(); // I'll make sth more sophisticated later
var i: byte; x, y: single;
begin
  //if not Spawn.Active then
    if Timer.Value mod 180 = 0 then
      for i := 1 to MaxID do
        if Players[i].Alive then
        if player[i].Status = -1 then begin
          if player[i].AfkSpawnTimer > 0 then begin
            if player[i].GetX then continue;
            GetPlayerXY(i, x, y);
            if Abs(player[i].sx - x) < 50 then begin
              incB(player[i].AfkSpawnTimer, -1);
              if player[i].AfkSpawnTimer = 0 then begin
                if i = Boss.ID then begin
                  if player[i].AfkSpawnNum < 2 then begin
                    incB(player[i].AfkSpawnNum, 1);
                    player[i].AfkSpawnTimer := 3;
                    SetTeam(ZOMBIETEAM, i, true);
                  end else begin
                    if Players_ParticipantNum(-1) > 1 then begin
                      WriteDebug(3, IntToStr(i) + ' trying another boss player');
                      InfectedDeath(i);
                      Spawn_AddZombies(1, Boss.bID);
                    end;
                  end;
                end else begin
                  if player[i].AfkSpawnNum = 0 then begin
                    player[i].AfkSpawnNum := 1;
                    player[i].AfkSpawnTimer := 3;
                    SetTeam(ZOMBIETEAM, i, true);
                  end else begin
                    WriteDebug(3, IntToStr(i) + ' moved to spec');
                    InfectedDeath(i);
                  end;
                end;
              end;
            end else begin
              player[i].AfkSpawnTimer := 0;
              player[i].AfkSpawnNum := 0;
            end;
          end;
        end;
end;

//  * ----------------------------------------------------------------------- *
//  |                            Main player loop                             |
//  * ----------------------------------------------------------------------- *

// This code loops through all players serveral times a second and
// executes certain program cycles in each iteration.

// --------------------------------- Zombies ----------------------------------
// 1 Hz process for every alive zombie player.
procedure Process_Zombie(ID: integer);
var pri, t: byte; h: single; p: tActivePlayer;
begin
  p := Players[ID];
  pri := p.Primary.WType;
  if player[ID].JustResp then begin // if just spawned
    if player[ID].GetX then begin // get player's position after spawn
      if ({$IFDEF FPC}AZSS.{$ENDIF}AZSS.Active) and (player[ID].Status = 0) then
        AZSS_OnZombieResp(ID);
      player[ID].sx := p.X;
      player[ID].GetX := false;
    end else
    if Abs(p.X-player[ID].sx) > 20 then begin // if moved from spawn
      player[ID].JustResp := false;
      if not ((pri = player[ID].pri) or (p.Secondary.WType = player[ID].pri)) then // if zombie doesnt have it's task specific weapon (ie butcher & saw) then force it
        Weapons_Force(ID, WTYPE_NOWEAPON, player[ID].pri, 0, 0);
    end;
  end;
  
  // if zombie picks up a weapon in game and it's not detected by OWC (happens sometimes)
  if pri <> player[ID].pri then
  if pri <> WTYPE_NOWEAPON then begin
    if p.Secondary.WType = player[ID].pri then begin
      Weapons_Force(ID, WTYPE_NOWEAPON, player[ID].pri, 0, 255);
    end else
      Weapons_Force(ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
  end;
  
  if player[ID].AntiBlockProtection then begin // [opt]
    if RayCast(p.x, p.y - 5, p.x, p.y - 10, true, false, false) then begin
      player[ID].LastPos.Active := true;
      player[ID].LastPos.X := p.x;
      player[ID].LastPos.Y := p.y;
      player[ID].StuckCD := 0;
    end else
    if player[ID].LastPos.Active then
    if player[ID].StuckCD < 4 then player[ID].StuckCD := player[ID].StuckCD + 1 else begin
      player[ID].StuckCD := 0;
      h := Players[ID].Health;
      PutPlayer(ID, ZOMBIETEAM, player[ID].LastPos.X, player[ID].LastPos.Y, false);
      Damage_SetHealth(ID, Trunc(h + 1.0), 0);
    end;
  end;

{   if player[ID].jumping > 0 then begin
    if player[ID].jump < player[ID].jumping then begin
      player[ID].jump := player[ID].jump + 1;
    end else begin
      player[ID].jump := 1;
      t := lookForTarget(ID, p.x, p.y, ZOMBIETHROWRANGE div 4, ZOMBIETHROWRANGE, true);
      if t > 0 then begin
        ThrowZombie(ID, t, 8, 9, (Boss.ID = ID));
      end;
    end;
  end; }
  player[ID].DamagePerSec := 0.0;
end;

// 1 Hz process for every dead zombie player.
procedure Process_DeadZombie(ID: integer);
begin
  if player[ID].KickTimer > 0 then begin
    player[ID].KickTimer := player[ID].KickTimer - 1;
    if player[ID].KickTimer = 0 then begin
      if player[ID].Status < 0 then begin
        InfectedDeath(ID);
      end else
        Spawn_TryKickZombie(ID, false);
    end;
  end;
  if Player[ID].Status = -2 then begin // if he's a dead human-zombie player waiting for spawn
    if player[ID].SpawnTimer > 0 then begin
      Player[ID].SpawnTimer := Player[ID].SpawnTimer - 1;
      if Player[ID].SpawnTimer > 0 then begin
        if (Player[ID].SpawnTimer < 5) or (Player[ID].SpawnTimer mod 5 = 0) then
        BigText_DrawScreenX(DTL_COUNTDOWN, ID, 'Ready to spawn in ' + IntToStr(Player[ID].SpawnTimer) + ' second'+pl(Player[ID].SpawnTimer), 100, RGB(255,80,80), 0.1, 20, 370);
      end else begin
        BigText_DrawScreenX(DTL_COUNTDOWN, ID, 'Ready to spawn', 200, RGB(255,80,80), 0.1, 20, 370);
      end;
    end;
  end;
end;

// 4 Hz
procedure Process_KamikazeZombie_Bot(ID: integer; MainCall: boolean);
var
  i: byte;
begin
  if player[ID].KamiDetonate > 0 then begin
    KamiKaboom(ID, 100);
    player[ID].KamiDetonate := 0;
  end else
  if MainCall then
    for i := 1 to MaxID do
      if (player[i].Status = 1) or (Players[i].Dummy) then
      if PlayersInRange(i, ID, 30, false) then begin
        if RandFlt_ < 0.5 then
          Players[ID].Say(Players[ID].ChatKill);
        KamiKaboom(ID, 100);
        break;
      end;
end;

// 4 Hz
procedure Process_KamikazeZombie_Human(ID: integer);
var
  p: tActivePlayer;
begin
  p := Players[ID];
  if (p.KeyGrenade) or (player[ID].KamiDetonate > 0) then begin
    KamiKaboom(ID, 100);
    player[ID].KamiDetonate := 0;
  end;
end;

procedure VomitingZombie_Jump(ID: integer);
var
  jump: boolean;
  d, h: single; p: tActivePlayer;
begin
  p := Players[ID];
  if p.Human then begin // if zombie is a real player, direction of jump is controlled by velocity
    d := p.VELX * 5;
    jump := d > 0;  // set direction of jump

  end else // for bot player d var was set before
    if d < 0 then begin  // set direction of jump
      d := d / -20;
      jump := false;
    end else begin
      d := d / 20;
      jump := true;
    end;

  if d > 17 then d := 17 else
  if d < 4 then d := 4;
  h := RandFlt(45, 50) - d/2;
  
  if jump then begin // jump in right side
    if PointNotInPoly(p.x - d, p.y + h, false, true, true) then begin
      if p.Human then
        BigText_DrawScreenX(DTL_ZOMBIE_UI, ID, 'You need to be on the ground', 100, RED, 0.1, 20, 370);
      exit; // check if there's ground for bullet under the zombie
    end;
    if not p.Human then
    if not RayCast(p.x, p.y-10, p.x+80, p.y-120, true, false, false) then
      exit; // if there is space over the zombie
    player[ID].charges := ZOMBIE_JUMP_COOLDOWN; // start cooldown
    CreateBulletX(p.x - d, p.y + h, 0, 0, 0, 4, ID);
    
  end else begin // left
    if PointNotInPoly(p.x + d, p.y + h, false, true, true) then begin
      if p.Human then
        BigText_DrawScreenX(DTL_ZOMBIE_UI, ID, 'You need to be on the ground', 100, RED, 0.1, 20, 370);
      exit;
    end;
    if not p.Human then
    if not RayCast(p.x, p.y-10, p.x-80, p.y-120, true, false, false) then
      exit;
    player[ID].charges := ZOMBIE_JUMP_COOLDOWN; // start cooldown
    CreateBulletX(p.x + d, p.y + h, 0, 0, 0, 4, ID);
  end;
  
  case Round(d / 4) of // very important code, choose the proper "weee" depending on jump power
    2: if RandInt_(3) = 0 then BotChat(ID, 'Weee!');
    3: if RandInt_(2) = 0 then BotChat(ID, 'Weeeee!');
    4: BotChat(ID, 'Weeeeeeee!!!');
  end;
end;

// 1 Hz
procedure Process_VomitingZombie_Bot(ID: integer);
var
  i, t: integer;
  b: boolean;
  x, y, d: single; p: tActivePlayer;
begin
  p := Players[ID];
  
  // Vomit at nearby targets
  if player[ID].mines > 0 then begin
    player[ID].mines := player[ID].mines - 1;
  end else begin // bot
    t := lookForTarget2(ID, 50, 133, ANGLE_40, true, b);
    if t > 0 then begin
      Vomit(ID, t, 6.0);
      player[ID].mines := 3;
    end;
  end;
  
  // Process jump countdown
  if player[ID].charges > 0 then begin
    player[ID].charges := player[ID].charges - 1;
    exit;
  end;

  if Timer.Value - player[ID].HurtTime > 300 then exit; // zombie can jump only for up to 5 seconds after being attacked
  x := p.X;
  y := p.Y;

  for i := 1 to MaxID do
    if ID <> i then // if there are other players close then cancel
    if Players[i].Active then
    if Players[i].Alive then
    if IsInRange(i, x, y, 50, false) then begin
      exit;
    end;
          
  for i := 1 to MaxID do
    if player[i].Status = 1 then begin
      d := SqrDist(Players[i].X, Players[i].Y, x, y);
      if RandInt_(10)+1 <= VOMIT_JUMP_CHANCE then
      if d < 160000 then // 400^2
      if d > 10000 then // 100^2
      if RayCast(x, y-15, Players[i].X, Players[i].Y-15, true, false, false) then begin // if target visible
        d := x - Players[i].X;
        if (d > 0) = (p.VELX > 0) then exit; // jump only if the zombie is getting towards it's target
        VomitingZombie_Jump(ID);
        break;
      end;
    end;
end;

// 4 Hz
procedure Process_VomitingZombie_Human(ID: integer; MainCall: boolean);
var
  p: tActivePlayer;
begin
  p := Players[ID];
  
  // Process countdowns
  if MainCall then begin
    if player[ID].mines > 0 then begin
      player[ID].mines := player[ID].mines - 1;
      if player[ID].mines = 0 then begin
        WriteConsole(ID, 'Stomach charged! HOLD the [Shoot] key to vomit', $99CC33 );
      end;
    end;
    
    if player[ID].charges > 0 then begin
      player[ID].charges := player[ID].charges - 1;
      if player[ID].charges = 0 then begin
        WriteConsole(ID, 'Ready to jump, (hold [Grenade] key)', $FF6666);
      end else begin
        if p.KeyGrenade then begin
          BigText_DrawScreenX(DTL_ZOMBIE_UI, ID, 'Unready, wait ' + IntToStr(player[ID].charges) + ' seconds', 100, RED, 0.1, 20, 370);
        end;
      end;
    end;
  end;
  
  // Vomit when he presses the key
  if p.KeyShoot then
  if player[ID].mines = 0 then begin
    Vomit(ID, -1, 7.0);
    player[ID].mines := 3;
  end;
    
  // Jump when he presses the key
  if p.KeyGrenade then
  if player[ID].charges = 0 then begin
    VomitingZombie_Jump(ID);
  end;
end;

// 1 Hz
procedure Process_BurningZombie_Bot(ID: integer);
var
  t: byte;
  b: boolean; p: tActivePlayer;
begin
  p := Players[ID];
  if player[ID].charges > 0 then begin
    player[ID].charges := player[ID].charges - 1;
  end else begin
    t := lookForTarget2(ID, 50, BURNING_RANGE, ANGLE_40, true, b);
    if t > 0 then begin
      BurningBreath(ID, Players[t].X, Players[t].Y, 50);
      player[ID].charges := 2;
    end;
  end;
end;

// 4 Hz
procedure Process_BurningZombie_Human(ID: integer; MainCall: boolean);
var
  p: tActivePlayer;
begin
  p := Players[ID];
  if player[ID].charges > 0 then begin
    if (MainCall) then begin
      player[ID].charges := player[ID].charges - 1;
      if player[ID].charges = 0 then
        WriteConsole(ID, 'Burning breath is ready! HOLD the [Shoot] key to breathe', $FF7830);
    end;
  end else begin
    if p.KeyShoot then begin
      BurningBreath(ID, Players[ID].MouseAimX, Players[ID].MouseAimY, 50);
      player[ID].charges := 2;
    end;
  end;
end;

// 1 Hz
procedure Process_HealingZombie(ID: integer);
var rd: single; p: tActivePlayer;
begin
  p := Players[ID];
  if Timer.Value - player[ID].HurtTime > 180 then begin
    if players[ID].Health < MAXHEALTH then begin
      rd := Distance(p.X, p.Y, player[ID].X, player[ID].Y);
      player[ID].X := p.X;
      player[ID].Y := p.Y;
      if rd < 100 then begin
        rd := 1.0 - rd * 0.01;
        Damage_Heal(ID, rd * 10.0);
      end;
    end;
  end;
end;

// 1 Hz
procedure Process_PunishmentZombie(ID: integer);
var i: byte; p: tActivePlayer;
begin
  p := Players[ID];
  if players[ID].Health < MAXHEALTH then begin
    player[ID].X := p.X;
    player[ID].Y := p.Y;
    if Distance(p.X, p.Y, player[ID].X, player[ID].Y) < 100.0 then begin
      if player[ID].mines < 8 then player[ID].mines := player[ID].mines + 1; // healing speed
      if player[ID].mines = 6 then begin
        WriteConsole(ID, 'Move! Decent zombies do not camp!', B_RED);
      end else
      if player[ID].mines = 8 then begin
        Damage_DoAbsolute(ID, ID, MaxHealth / 6);
      end;
    end else
      player[ID].mines := player[ID].mines * 2 div 3;
      
    if player[ID].charges = 0 then begin
      for i := 1 to MaxID do
        if player[i].Status = 1 then
          if PlayersInRange(ID, i, 300, false) then begin
            //Botchat(ID, '^' + RandZombieText(6));
            player[ID].charges := 10;
            player[ID].wires := player[ID].wires div 2;
            break;
          end;
      if i > MaxID then begin
        player[ID].wires := player[ID].wires + 1;
        if player[ID].wires = 30 then begin
          WriteConsole(ID, 'Zombies do not run away from survivors!', B_RED);
        end else
        if player[ID].wires >= 30 then begin
          Damage_DoAbsolute(ID, ID, MaxHealth / 6);
        end;
      end;
    end else
      player[ID].charges := player[ID].charges - 1;
  end;
end;

procedure Process_TickingBombExplosion(ID: integer);
var t, i: integer; p: tActivePlayer;
begin
  if player[ID].KamiDetonate > 0 then begin
    player[ID].KamiDetonate :=  player[ID].KamiDetonate - 1;
    if player[ID].KamiDetonate = 0 then begin // explode
      BotChat(ID, Players[ID].ChatKill);
      KamiKaboom(ID, 200);
    end else begin
      p := Players[ID];
      if player[ID].KamiDetonate = 1 then begin
        t := 0;
        for i := 1 to MaxID do begin
          if player[i].Status = 1 then  
          if SqrDist(Players[i].X, Players[i].Y, p.X, p.Y) < 40000.0 then begin // 200^2
            t := t + 1;
          end;
        end;
        if (t >= 2) then begin
          BW_RandZombChat(ID, BW_TickingTauntsExplodeClose, 1.0);
        end else begin
          BW_RandZombChat(ID, BW_TickingTauntsTauntsExplode, 1.0);
        end;
      end else
        Botchat(ID, '^Tick, tick, tick!');
    end;
  end;
end;

// 4 Hz
procedure Process_TickingBombZombie_Human(ID: integer; MainCall: boolean);
begin
  if MainCall then
    Process_TickingBombExplosion(ID);
    
  if player[ID].KamiDetonate = 0 then
  if Players[ID].KeyGrenade then begin
    player[ID].KamiDetonate := TICKING_BOMB_TIME;  // detonate!
    CreateBulletX(Players[ID].X, Players[ID].Y, 0, 0, 0, 5, ID);
  end;
end;

// 1 Hz
procedure Process_TickingBombZombie_Bot(ID: integer);
var i: byte;
begin
  Process_TickingBombExplosion(ID);
  
  if player[ID].KamiDetonate = 0 then begin
    for i := 1 to MaxID do
      if (player[i].Status = 1) then
      if PlayersInRange(i, ID, 150, false) then begin
        player[ID].KamiDetonate := TICKING_BOMB_TIME;  // detonate!
        CreateBulletX(Players[ID].X, Players[ID].Y, 0, 0, 0, 5, ID);
        break;
      end;
  end;
end;

// 4 Hz
procedure Process_ButcherZombie(ID: integer);
var i: integer; p: tActivePlayer; d: single;
begin
  if Players_OnGround(ID, true, 15) = 1 then begin
    p := Players[ID];
    for i := 1 to MaxID do begin
      if player[i].Status = 1 then begin
        d := Distance(Players[i].X, Players[i].Y, p.X, p.Y);
        if d < 330.0 then
        if dot(Players[i].X-p.X, Players[i].Y-p.Y, p.VelX, p.VelY) > 0 then // if butcher is getting towards it's victim
        if RayCast(Players[i].X, Players[i].Y-15, p.X, p.Y-15, true, false, false) then begin
          //p.KeyUp := true;
          p.SetVelocity(p.VelX*1.16,p.VelY*1.05-0.1);
          if d < 200.0 then
          if Timer.Value > player[ID].ZombChatTime + 480 then
          if p.VelX*p.VelX + p.VelY*p.VelY > 16.0 then begin // 4^2
            BW_RandZombChat(ID, BW_ButcherTauntsMadness, 0.5);
            player[ID].ZombChatTime := Timer.Value;
          end;
          break;
        end;
      end;
    end;
  end;
end;

// 1 Hz
procedure Process_FlameZombie(ID: integer);
var p: tActivePlayer;
begin
  if player[ID].charges > 0 then begin
    player[ID].charges := player[ID].charges - 1;
    if player[ID].charges = 0 then begin
      p := Players[ID];
      if lookForTarget(ID, p.X, p.Y, 0, 50, false) = 0 then begin
        Kits_Spawn(p.X + iif(p.Direction = 1, 10, -10), p.Y, 18, 1);
        player[ID].task := 4; // becomes a burning zombie
      end else player[ID].charges := 1;
    end;
  end;
end;

// 1 Hz
procedure Process_BerserkerZombie(ID: integer);
begin
  if player[ID].charges > 0 then begin
    player[ID].charges := player[ID].charges - 1;
    if player[ID].charges = 0 then
    begin
      GiveBonus(ID, 2);
      player[ID].charges := 13;
    end;
  end;
end;

// ------------------------------- Survivors ----------------------------------
// 1 Hz
procedure Process_ReloadingInfo(ID: integer);
var
  MateNear: boolean;
  ZombNear, i: integer; 
  r: single; p: tActivePlayer;
  text: string;
begin
  p := Players[ID];
  if player[ID].ReloadTime > 0 then begin
    incB(player[ID].ReloadTime, -1);
  end else begin
    if (p.Primary.WType = WTYPE_LAW) then exit;
    if (p.Primary.WType = WTYPE_M79) then exit; 
    if (p.Primary.WType = WTYPE_NOWEAPON) then exit; 
    if (p.Primary.WType = WTYPE_SPAS12) then exit;
    if p.Primary.Ammo > 0 then exit;
    MateNear := false;
    for i := 1 to MaxID do begin
      if MateNear then
        if not player[i].Zombie then continue;
      if Players[i].Alive then begin
        r := Distance(Players[i].x, Players[i].y, p.x, p.y);
        if player[i].Zombie then begin
          if r < 550 then
            if RayCast3(Players[i].x, Players[i].y-15.0, p.x, p.y-15.0, 5, 3) > 0.5 then begin
              ZombNear := ZombNear + 1;
            end;
        end else begin
          if r < 600 then
            MateNear := true;
        end;
      end;
    end;
    if MateNear then
    if ZombNear > 0 then begin
      player[ID].ReloadTime := 20;
      if p.Primary.WType = 10 then begin
        BotChat(ID, 'Out of ammo!');
      end else
      case ZombNear of
        1, 2: if RandBool() then
            text := 'Reloading...'
          else
            text := 'Reloading!';
        3: text := 'Reloading!';
        else
          if RandBool then
            text := 'Cover me, reloading!'
          else
            text := 'Reloading!!!';
      end;
      BotChat(ID, text);
    end;
  end;
end;

// 1 Hz process for every alive Survivor player.
procedure Process_Survivor(ID: integer);
var H, V: Single;
  G: byte;
begin
  // If just respawned
  if player[ID].JustResp then begin  
    if player[ID].GetX then begin // get player's position after spawn
      player[ID].sx := Players[ID].X;
      player[ID].GetX := false;
    end;

    if Abs(Players[ID].X-player[ID].sx) > 20.0 then begin // if player moved from his spawn position
      player[ID].JustResp := false;
      if player[ID].Status < 0 then
        if player[ID].pri <> WTYPE_NOWEAPON then 
          Weapons_Force(ID, WTYPE_NOWEAPON, player[ID].pri, 0, 0);
    end else begin
    end;
  end;
  
  // If must be respawned
  if Player[ID].RespawnPlayer then begin
    H := Players[ID].Health;
    V := Players[ID].Vest;
    G := Players[ID].Grenades;
    PutPlayer(ID, HUMANTEAM, Players[ID].X + 5, Players[ID].Y, false);
    Damage_SetHealth(ID, H, V);
    if G > 0 then 
      if Player[ID].Task <> 2 then GiveBonus(ID, 4)
      else GiveBonus(ID, 5);
    Player[ID].RespawnPlayer := False;
    Player[ID].GetX := False;
    Player[ID].sx := Players[ID].X + 5;
    Player[ID].JustResp := True;
  end;
end;

// 1 Hz process for every dead Survivor player.
procedure Process_DeadSurvivor(ID: integer);
begin
  if player[ID].SpecTimer > 0 then begin
    player[ID].SpecTimer := player[ID].SpecTimer - 1;        
    if player[ID].SpecTimer = 0 then begin
      case Modes.CurrentMode of
        1, 2: begin
          if player[ID].bitten then begin
            if Zombies_SpawnOne((Sqrt(NumberOfWave + 1)) * 10 * ZombieHpInc/100, (NumberOfWave+1)*ZombieDmgInc/100, ID, 0, player[ID].X, player[ID].Y, true, 0) > 0 then begin
              WriteConsole( 0, Players[ID].Name + ' has turned into a zombie!', RED);
            end else
                WriteConsole( 0, Players[ID].Name + ' cannot be revived anymore.', RED);
          end else WriteConsole( 0, Players[ID].Name + ' cannot be revived anymore.', RED);
          player[ID].Status := 0;
        end;
        3: begin
          CreateUnit(ID, -1, -1);
          Player[ID].SpawnTimer := round(15 * ((randInt(1, 9) - 5) / 10 + 1));
          WriteConsole(ID, 'You will be spawned as soon as possible', WHITE);
          Untask(ID, True);
          if Zombies_SpawnOne((Sqrt(NumberOfWave + 1)) * 10 * ZombieHpInc/100, (NumberOfWave+1)*ZombieDmgInc/100, ID, 0, player[ID].X, player[ID].Y, true, 0) > 0 then begin
            WriteConsole( 0, Players[ID].Name + ' has turned into a zombie!', RED);
          end else
            WriteConsole( 0, Players[ID].Name + ' cannot be revived anymore.', RED);;
        end;
      end;
      BigText_DrawScreenX(DTL_NOTIFICATION, 0, Players[ID].Name + ' perished!',180, $FF3232, 0.1, 20, 370);
      if Modes.CurrentMode <> 3 then SetTeam(5, ID, true);
      //if Modes.CurrentMode <> 1 then
      BlockPlayer(ID);
    end;
  end;
end;

// 4 Hz
procedure Process_Mechanic(ID: integer);
var target, n: byte; b: boolean; x, y, vx, vy, dist: single;
begin
  if player[ID].WrenchCooldown = 0 then begin
    if not player[ID].Frozen then
    if Players[ID].Primary.Wtype = WTYPE_NOWEAPON then
    if Players[ID].KeyShoot then begin
      //if BulCount >= MAX_BPS then exit;
      target:=lookForTarget2(ID, 0, 40, ANGLE_90, true, b);
      if target>0 then begin
        WriteConsole(ID, 'Zombie hit with a wrench!', GREEN);
        GetPlayerXY(ID, x, y);
        GetPlayerXY(target, vx, vy);
        y := y - 10;
        vx := vx - x;
        vy := vy-10 - y;
        dist := Sqrt(vx*vx + vy*vy);
        vx := vx / dist * 13;
        vy := vy / dist * 13;
        for n := 0 to 4 do begin
          y := y - 1;
          CreateBulletX(x, y, vx, vy, -5-NumberOfWave/2, 6, ID);
        end;
        for n := 1 to MaxID do
          if Players[n].Alive then
          if Player[n].Zombie then
          if PlayersInRange(ID, n, 40, false) then begin
            vx := Players[n].x - x;
            vy := Players[n].y - y;
            dist := sqrt(vx*vx + vy*vy);
            Players[n].SetVelocity(
              Players[n].VelX + vx/dist*4.0,
              Players[n].VelY + vy/dist*2.5
            );
          end;
        player[ID].WrenchCooldown := 3;
      end;
    end;
  end else
    player[ID].WrenchCooldown := player[ID].WrenchCooldown - 1;
    
  if player[ID].MousePointTime = 60 then begin
    Wires_InfoAt(ID, player[ID].LastMouseX, player[ID].LastMouseY);
    player[ID].MousePointTime := -60;
  end;
end;

// 4 Hz
procedure Process_Demoman(ID: integer);
begin
  if player[ID].MousePointTime = 30 then begin
    Charges_SelectChargeAt(ID, player[ID].LastMouseX, player[ID].LastMouseY);
  end;
end;

// 4 Hz
procedure Process_Priest(ID: integer; MainCall: boolean);
var
  x, y, ang, v: single;
begin
  if MainCall then begin
    if player[ID].ShowerCooldown > 0 then begin
      player[ID].ShowerCooldown := player[ID].ShowerCooldown - 1;
      if player[ID].ShowerCooldown = 0 then WriteConsole(ID, 'Holy shower ready, (/shw)', BLUE);
    end;
    
    if player[ID].ExoTimer > 0 then begin
      player[ID].ExoTimer := player[ID].ExoTimer - 1;
      if player[ID].ExoTimer = 0 then WriteConsole(ID,'Exorcism ready, (/exo)',BLUE);
    end else
    if player[ID].ExoTimer < 0 then begin
      player[ID].ExoTimer := player[ID].ExoTimer + 1;
      
      if player[ID].ExoTimer < 0 then begin
        if Players[ID].Alive then begin 
          BigText_DrawScreenX(DTL_COUNTDOWN, ID, 'Exorcism ['+IntToStr(-player[ID].ExoTimer)+']', 200, BLUE, 0.1, 20, 370);
        end else begin
          BigText_DrawScreenX(DTL_COUNTDOWN, ID, 'Exorcism failed.',100, DT_FAIL, 0.1, 20, 370);
          player[ID].ExoTimer := 0;
        end;
      end else begin
        player[ID].ExoTimer := EXODELAY;
        GetPlayerXY(ID,x,y);
        WriteDebug(1, 'exo');
        WriteConsole(0,'Exorcism complete!',BLUE);
        Damage_ZombiesAreaDamage(ID, x, y, EXO_RANGE1, EXO_RANGE2, MaxHealth, ExoMagic);
        y:=y-30;
        //draw cross
        CreateBulletX(x,y   ,0,0,0,5,ID);
        CreateBulletX(x,y-15,0,0,0,5,ID);
        CreateBulletX(x,y-30,0,0,0,5,ID);
        CreateBulletX(x,y-45,0,0,0,5,ID);
        CreateBulletX(x,y-60,0,0,0,5,ID);
        y:=y-45;
        CreateBulletX(x-15,y,0,0,0,5,ID);
        CreateBulletX(x+15,y,0,0,0,5,ID);
        nova_2(x, y + 45, 0, 0, 40,30,0,ANG_2PI,0,24,14,ID);
        case RandInt(1,4) of
          1: BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'Go back to hell!',200, EXO_COL, 0.12, 20,370 );
          2: BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'Amen!',200, EXO_COL, 0.12, 20,370 );
          3: BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'For God''s sake!',240, EXO_COL, 0.12, 20,370 );
          4: BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'Curse you!',200, EXO_COL, 0.12, 20,370 );
        end;
        //end else BigText_DrawScreenX(DTL_COUNTDOWN,  ID, 'Exorcism failed',100, DT_FAIL, 0.1, 20,370 );
      end;
    end;
    
  end;  // </- MainCall
  
  if player[ID].SprinkleCooldown > 0 then begin
    player[ID].SprinkleCooldown := player[ID].SprinkleCooldown - 1;
  end else begin
    if players[ID].KeyGrenade then
    if not player[ID].Frozen then
    if players[ID].Grenades = 0 then begin
      if player[ID].HolyWater > SPRINKLECOST then begin
        GetPlayerXY(ID, x, y);
        y := y - 10;
        ang := Math.arctan2(Players[ID].MouseAimY-y, Players[ID].MouseAimX-x);
        v := 8;
        //procedure Shoot(x, y, Angle, add_vx, add_vy, vmin, vmax, Spread, Accuracy, Damage: single; Style, ID, n: byte);
        Shoot(x, y, ang, Players[ID].VELX/2, Players[ID].VELY/2,
          v-1.5, v+1.5, 0.26, 0.05, -SPRINKLE_DAMAGE, 3, ID, 8);
        player[ID].SprinkleNum := (player[ID].SprinkleNum + 1) mod 10;
        player[ID].HolyWater := player[ID].HolyWater - SPRINKLECOST;
        player[ID].SprinkleCooldown := 3;
        if player[ID].SprinkleNum = 0 then
          WriteConsole(ID,IntToStr(player[ID].HolyWater)+' ml left', BLUE);
      end else begin
        WriteConsole(ID, 'No holy water left', RED);
        player[ID].SprinkleCooldown := 7;
      end;
    end;
  end;
end;

// ------------------------------------ All -----------------------------------
// Counts for how much time player stopped his mouse.
// 4 Hz
procedure Process_Mouse(ID: integer);
var
  p: tActivePlayer; 
begin
  p := Players[ID];
  if Distance(P.MouseAimX, P.MouseAimY, player[ID].LastMouseX,  player[ID].LastMouseY) < 10.0 then begin
    player[ID].MousePointTime := player[ID].MousePointTime + 15;
  end else begin
    player[ID].LastMouseX := P.MouseAimX;
    player[ID].LastMouseY := P.MouseAimY;
    player[ID].MousePointTime := 0;
  end;  
end;

// ---------------------------- Main player loop ------------------------------
// This is called 4 times per second.
// Originally all subroutines were written to work with 1Hz AppOnIdle.
// However since fast AOI is available, we can now use it to make a better use of
// GetKey, for Human-Zombies processing subroutines. That's why we split it and it
// looks like this.
var MainPlayerLoopCall: integer;
procedure ProcessMainPlayerLoop();
var
  i: integer;
  MainCall: boolean;
begin
  // Count to 4 and reset
  MainPlayerLoopCall := MainPlayerLoopCall + 1;
  MainPlayerLoopCall := MainPlayerLoopCall and 3;
  
  for i := 1 to MaxID do
  if Players[i].Active then begin
    
    // Although everything is called 4 times per second, this will help to filter out 1hz frequency,
    // with diferent phase for different IDs. The point is not to process ie 20 kamikaze zombies at
    // one call since we can split it.
    MainCall := ((i and 3) = MainPlayerLoopCall);
    
    if Players[i].Alive then begin
      if player[i].ShowTaskinfo then begin
        TaskInfo(i);
        player[i].ShowTaskinfo := false;
      end;
      
      Process_Mouse(i);
            
      if player[i].Zombie then begin // zombies
        // 1Hz general subroutine for all zombies
        if MainCall then begin
          Process_Zombie(i);
        end;
        
        if player[i].task > 0 then
        if Players[i].Human then begin
          // Human-Zombies, like in VS mode. 4Hz subroutines
          case player[i].task of 
            1: Process_KamikazeZombie_Human(i);
            2: Process_VomitingZombie_Human(i, MainCall);
            3: Process_ButcherZombie(i);
            4: Process_BurningZombie_Human(i, MainCall);
            11: Process_TickingBombZombie_Human(i, MainCall);  
          end;
          
          // Human-Zombies, 1Hz subroutines
          if MainCall then
          case player[i].task of 
            12: Process_BerserkerZombie(i);
            61: Process_FlameZombie(i);            
            200: Process_HealingZombie(i);
            201: Process_PunishmentZombie(i);
          end;
          
        end else begin
          // Bot-Zombies, 4Hz subroutines
          case player[i].task of 
            1: Process_KamikazeZombie_Bot(i, MainCall);
            3: Process_ButcherZombie(i);
          end;
          
          // Bot-Zombies, 1Hz subroutines
          if MainCall then
          case player[i].task of 
            2: Process_VomitingZombie_Bot(i);
            4: Process_BurningZombie_Bot(i);
            12: Process_BerserkerZombie(i);
            200: Process_HealingZombie(i);
            201: Process_PunishmentZombie(i);
            61: Process_FlameZombie(i);
            11: Process_TickingBombZombie_Bot(i);
          end;
        end;
      
      end else if Player[i].Status = 1 then begin// if not player.zombie

        // Call OnWeaponChange_ on player if he's got fists only, but is using the ChangeWeapon key
        if Players[i].Primary.WType = Players[i].Secondary.WType then
        if Players[i].KeyChangeWeap then begin
          OnWeaponChange_(Players[i], Players[i].Primary, Players[i].Primary);
        end;
        
        if player[i].ChainsawDamageFactor < 1.0 then begin
          player[i].ChainsawDamageFactor := player[i].ChainsawDamageFactor + 0.125;
          if player[i].ChainsawDamageFactor > 1.0 then
            player[i].ChainsawDamageFactor := 1.0;
        end;
        
        // 1 Hz subroutines
        if MainCall then begin
          Process_Survivor(i);

          // Display available weapons near Flag
          if WeaponSystem.Enabled then begin
            BaseWeapons_ProcessPlayer(i);
          end;
          
          // Display Reloading! message when he's reloading
          if player[i].ReloadMode then begin
            Process_ReloadingInfo(i);
          end;  
        end;
        
        case player[i].task of
          1: Process_Mechanic(i);
          2: Process_Demoman(i);
          7: Process_Priest(i, MainCall);
        end;
      end;

    end else begin// <- /player alive
      if MainCall then begin
        if Player[i].Status > 1 then begin
          Process_DeadSurvivor(i);
        end else
        if player[i].Zombie then begin
          Process_DeadZombie(i);
        end;
      end;
    end;
  end;
end;

procedure ProcessINFTable();
begin
  if Game.Teams[1].Score <> ZombiesLeft then
    Game.Teams[1].Score := ZombiesLeft;
  if Game.Teams[2].Score <> Civilians then
    Game.Teams[2].Score := Civilians;
end;

// it's just an experiment..
procedure CastPitchfork(var X, Y: single; Vx, Vy, Damage, Scale: single; Owner: byte);
var
  ik, d, shift, Ux, Uy: single;
begin
  d := Sqrt(Vx*Vx + Vy*Vy);
  CreateBulletX(X, Y, Vx, Vy, Damage, 7, Owner);
  shift := Scale/d;
  ik := Math.Pow(K_AIR, shift);
  Ux := Vx*shift;
  Uy := (Vy + G_BUL*Game.Gravity/DEFAULTGRAVITY)*shift;
  CreateBulletX(X + Ux, Y+Uy, Vx*ik, Vy*ik, Damage, 3, Owner);
  CreateBulletX(X + Ux - Uy/8, Y + Uy + Ux/8, Vx*ik, Vy*ik, Damage, 3, Owner);
  CreateBulletX(X + Ux + Uy/8, Y + Uy - Ux/8, Vx*ik, Vy*ik, Damage, 3, Owner);
end;

procedure Sht(ID, s: byte);
var X1, Y1, X2, Y2, a, V: single; t: byte; b: boolean;
begin
  GetPlayerXY(ID, X1, Y1);
  t := lookForTarget(ID, X1, Y1, 0, 2000, true);
  if t > 0 then begin
    GetPlayerXy(t, X2, Y2);
    Y1 := Y1 - 10;
    Y2 := Y2 - 10;
    V := 15 + Distance(X1, Y1, X2, Y2) / 100;
    if s = 4 then V := V * 0.9 else
    if s = 6 then V := 15;
    //a := BallisticAim(X1, Y1, X2, Y2, V, Game.Gravity, b);
    a := BallisticAimX(X1, Y1, V, players[t], b);
    if not b then exit;
    //procedure Shoot(x, y, Angle, add_vx, add_vy, vmin, vmax, Spread, Accuracy, Damage: single; Style, ID, n: byte);
    case s of
      1: Shoot(X1, Y1, a, 0, 0, v-1, v+1, 0.1, 0.01, 10, 14, ID, 5);
      2: begin
        Shoot(X1, Y1, a, 0, 0, v*0.95, v*1.05, 0.15, 0.05, 10, 10, ID, 5);
        Shoot(X1, Y1, a, 0, 0, v*0.90, v*1.10, 0.15, 0.05, 10, 7, ID, 6);
      end;
      3: Shoot(X1, Y1, a, 0, 0, v-5, v+5, 0.3, 0, 10, 2, ID, 5);
      4: Shoot(X1, Y1, a, 0, 0, v-0.1, v+0.1, 0.06, 0, 100, 3, ID, 3);
      5: Shoot(X1, Y1, a, 0, 0, v, v, 0.06, 0, 100, 3, ID, 14);
      6: CastPitchfork(X1, Y1, V*cos(a), V*sin(a), 40, 50, ID);
    end;
  end;
end;

procedure Seppuku(ID: byte; Forced: boolean);
var px, py: single; i: byte;
begin
  GetPlayerXY(ID,px,py);
  py:=py-10;
  Damage_ZombiesAreaDamage(ID, px, py, 200, 400, 1000, General);
  nova_2(px,py,0,-2,30,10,90,4, 1.7, 15, 4, ID);
  Sleep(100);
  nova_2(px,py,0,-2,10,10,90,ANG_2PI, 0, 14, 10, ID);
  Sleep(100);
  nova_3(px,py,0,-2,20,-19,-14,90,ANG_2PI, 0, 10, 8, ID);
  nova_3(px,py,0,-2,20, 14, 19,90,ANG_2PI, ANG_2PI/20, 10, 12, ID);
  Sleep(100);
  BigText_DrawScreenX(DTL_NOTIFICATION,  0, 'Seppuku!',240,  RGB(255,200,155), 0.15, 20,370 );
  Sleep(300);
  Damage_DoAbsolute(ID, ID, 200);
  if not Forced then begin
    for i := 1 to MAX_UNITS do player[i].Status := 2;
    CheckNumPlayers := true;
  end;
end;

procedure DisplayScore(ID: byte);
var i, x, y: byte;
begin
  case Modes.CurrentMode of
    1, 3: MapScore_Display(ID);
    2: begin
      if GameRunning then begin
        if ID = 0 then begin
          x := 1;
          y := MaxID;
        end else begin
          x := ID;
          y := ID;
        end;
        if VersusRound = 1 then begin
          for i := x to y do
            if Players[i].Active then
              if player[i].Participant = 1 then begin
                WriteConsole(i, '[Team 1](You): ' + IntToStr(Score[1][1]), WHITE);
                WriteConsole(i, '[Team 2]:      ' + IntToStr(Score[2][1]), SILVER);
              end else begin
                WriteConsole(i, '[Team 1]:      ' + IntToStr(Score[1][1]), SILVER);
                WriteConsole(i, '[Team 2](You): ' + IntToStr(Score[2][1]), WHITE);
              end;
        end else begin
          for i := x to y do
            if Players[i].Active then
              if player[i].Participant = 1 then begin
                WriteConsole(i, '[Team 1]:      Current: ' + IntToStr(Score[1][2]) + '; Total: ' + IntToStr(Score[1][1]+Score[1][2]), SILVER);
                WriteConsole(i, '[Team 2](You): Current: ' + IntToStr(Score[2][2]) + '; Total: ' + IntToStr(Score[2][1]+Score[2][2]), WHITE);
              end else begin
                WriteConsole(i, '[Team 1](You): Current: ' + IntToStr(Score[1][2]) + '; Total: ' + IntToStr(Score[1][1]+Score[1][2]), WHITE);
                WriteConsole(i, '[Team 2]:      Current: ' + IntToStr(Score[2][2]) + '; Total: ' + IntToStr(Score[2][1]+Score[2][2]), SILVER);
              end;
        end;
      end else begin
        MapScore_Display(ID);
      end;
    end;
  end;
end;

procedure WriteInfo(ID, style: byte);
var a: byte; stri: string; l: byte; c: integer;
begin
  case style of
    2:
    begin
      WriteConsole(ID, 'Available commands:', GREEN);
      WriteConsole(ID, ' /task      - Shows your current task and task-specific commands.', WHITE);
      WriteConsole(ID, ' /list      - Shows a list of players with their tasks.', WHITE);
      WriteConsole(ID, ' /vote      - Makes a vote for starting the game or changing the map', WHITE);
      WriteConsole(ID, ' /votehelp  - Shows a list of available vote options.', WHITE);
      WriteConsole(ID, ' /mode <ID> - Makes a vote for changing game mode.', WHITE);
      WriteConsole(ID, ' /modehelp  - Shows a list of available game modes.', WHITE);
      case Modes.CurrentMode of
        1: begin
          WriteConsole(ID, ' !score    - Shows the high score for the current map.', WHITE)
        end;
        2, 3: begin
          WriteConsole(ID, ' /t <text> - Versus, Infection teamchat.', WHITE);
          WriteConsole(ID, ' /joinS, /joinZ - Join survivors/infected team.', WHITE);  
          WriteConsole(ID, ' !score     - Shows team scores', WHITE)
        end;
      end;
      WriteConsole(ID, ' /advanced  - Shows a list of all advanced commands.', WHITE);
      WriteConsole(ID, ' /credits   - Shows a list of authors and credits', WHITE);
      WriteConsole(ID, 'Join us @ www.eat-that.org, #soldat.eat-this! @ Quakenet', RED);
    end;
    4: begin
      WriteConsole(ID, 'Advanced commands:', GREEN);
      WriteConsole(ID, ' !fixsg      - Fixes all broken stationary guns.', WHITE);
      WriteConsole(ID, ' !sbug, !spect - Moves you in game if you have the "spectator bug"', WHITE);
      if Modes.CurrentMode <> 2 then
        WriteConsole(ID, ' !pause      - Pauses a game. (!unpause to cancel the pause)', WHITE);
      WriteConsole(ID, ' /bug <text> - Use this command to report a bug', WHITE);
      WriteConsole(ID, ' /quick      - Shows a list of quick, task-specific commands', SHORTCOMMAND);
      WriteConsole(ID, ' /table      - Shows a table of quick commands for all tasks', SHORTCOMMAND);
      WriteConsole(ID, ' /eqp        - Shows your equipment', WHITE);
      WriteConsole(ID, ' /autovote   - Makes you vote automatically after the game ends', WHITE);
      WriteConsole(ID, ' /reload     - Toggles reloading info mode', WHITE);
      WriteConsole(ID, ' !status     - Shows game status', WHITE);
      if IC.Active then begin
        WriteConsole(ID, ' !msg <text> - Sends message to all the servers', $ADFF2F);
        WriteConsole(ID, ' /servers    - Shows a list of connected servers and commands', $ADFF2F);
      end;
      WriteConsole(ID, 'Join us @ www.eat-that.org, #soldat.eat-this! @ Quakenet', RED);
    end;
    3:if GameRunning then begin
      case Modes.CurrentMode of 
        1: begin
    // SURVIVAL
          for a := 1 to MaxID do
            if Players[a].Human then begin
              stri := Copy(Players[ a ].Name, 1, 20) + ': ' + taskToName( player[ a ].task, false);
              l := Length(stri);
              stri := stri + StringOfChar(' ', 35 - l);
              if player[a].Status = 2 then stri := stri + ' [ INFECTED ]' else stri := stri + '             ';
              
              //Tried this part with iifs, but it failed in a weird way
              if player[a].VoteReady then 
              begin
                stri := stri + ' [ VOTED ';
                if Player[a].VotedMap <> LSMap.CurrentNum then
                begin
                  stri := stri + '{';
                  if Player[a].VotedMap = VOTE_RANDOM then stri := stri + 'Random'
                  else stri := stri + MapList.List[player[a].VotedMap] + '(' + IntToStr(Player[a].VotedMap + 1) + ')';
                  stri := stri + '} ';
                end;
                stri := stri + ']';
              end;
              WriteConsole(ID, stri, iif(player[a].Status > 0, $6B6BFF, $969696));
            end;
        end;
        2, 3: begin
    // VERSUS
          WriteConsole(ID, iif(Modes.CurrentMode = 2, 'Team ' + IntToStr(VersusRound)+' - ', '') + 'Survivors:', WHITE);
          for a := 1 to MaxID do
            if Players[a].Human then
              if player[a].Participant = 1 then begin // human team
                stri := ' ' + Copy(Players[ a ].Name, 1, 20) + ': ' + taskToName( player[ a ].task, false);
                l := Length(stri);
                stri := stri + StringOfChar(' ', 35 - l);
                if player[a].Status = 1 then begin
                  c := $6B6BFF;
                  stri := stri + '             ';
                end else
                if player[a].Status = 2 then begin
                  stri := stri + ' [ INFECTED ]';
                  c := $B482AA;
                end else begin
                  stri := stri + ' [ DEAD ]    ';
                  c := $505096;
                end;
                if player[a].VoteReady then 
                begin
                  stri := stri + ' [ VOTED ';
                  if Player[a].VotedMap <> LSMap.CurrentNum then
                  begin
                    stri := stri + '{';
                    if Player[a].VotedMap = VOTE_RANDOM then stri := stri + 'Random'
                    else stri := stri + MapList.List[player[a].VotedMap] + '(' + IntToStr(Player[a].VotedMap + 1) + ')';
                    stri := stri + '} ';
                  end;
                  stri := stri + ']';
                end;
                WriteConsole(ID, stri, c);
              end;
          if Players_ParticipantNum(-1) > 0 then begin
            WriteConsole(ID, iif(Modes.CurrentMode = 2, 'Team ' + IntToStr(VersusRound mod 2 + 1)+' - ', '') + 'Zombies:', WHITE);
            for a := 1 to MaxID do
              if Players[a].Human then
                if player[a].Participant = -1 then begin
                  if player[a].Status = -1 then begin
                    stri := ' ' + Copy(Players[a].Name, 1, 17) + ': ' + TaskToName(player[a].Task, true);
                  end else
                    stri := ' ' + Copy(Players[a].Name, 1, 20);
                  l := Length(stri);
                  stri := stri + StringOfChar(' ', 35 - l);
                  
                  if player[a].Status = -2 then begin
                    stri := stri + ' [ SPAWNING ]';
                    c := $A04946;
                  end else begin
                    c := $FF6964;
                    stri := stri + '             ';
                  end;
              
                  if player[a].VoteReady then 
                  begin
                    stri := stri + ' [ VOTED ';
                    if Player[a].VotedMap <> LSMap.CurrentNum then
                    begin
                      stri := stri + '{';
                      if Player[a].VotedMap = VOTE_RANDOM then stri := stri + 'Random'
                      else stri := stri + MapList.List[player[a].VotedMap] + '(' + IntToStr(Player[a].VotedMap + 1) + ')';
                      stri := stri + '} ';
                    end;
                    stri := stri + ']';
                  end;
                    
                  WriteConsole(ID, stri, c);
                  Sleep(1);
                end;
          end;
          //if Players_SpecNum > 0 then begin
          {if Spectators > 0 then begin
            WriteConsole(ID, 'Spectators:', WHITE  );
            for a := 1 to MaxID do
              if Players[a].Human then
                if player[a].Status = 0 then begin
                  stri := ' ' + Copy(Players[a].Name, 1, 20);
                  l := Length(stri);
                  stri := stri + StringOfChar(' ', 35 - l);
                  if player[a].VoteReady then stri := stri + ' [ READY ]'  else stri := stri + '          ';
                  if player[a].Status = 1 then stri := stri + ' [ INFECTED ]';
                  WriteConsole(ID, stri, $969696);
                  Sleep(1);
                end;
          end;}
        end;
      end;
    end else
  // NONE
      for a := 1 to MaxID do
          if Players[a].Human then begin
            stri := Players[ a ].Name;
            l := Length(stri);
            stri := stri + StringOfChar(' ',  23 - l);
            if player[a].ModeReady then stri := stri + ' [ MODE ' + IntToStr(player[a].VotedMode) + ' ]' else stri := stri + '           ';

            if player[a].VoteReady then 
            begin
              stri := stri + ' [ VOTED ';
              if Player[a].VotedMap <> LSMap.CurrentNum then
              begin
                stri := stri + '{';
                if Player[a].VotedMap = VOTE_RANDOM then stri := stri + 'Random'
                else stri := stri + MapList.List[player[a].VotedMap] + '(' + IntToStr(Player[a].VotedMap + 1) + ')';
                stri := stri + '} ';
              end;
              stri := stri + ']';
            end;
                        
            WriteConsole(ID, stri, iif( player[a].VoteReady, $6B6BFF, $D13838));
          end;
    5: begin
      WriteConsole(ID, 'Rules:', WHITE);
      WriteConsole(ID, ' Do not spam', WHITE);
      WriteConsole(ID, ' Do not teamkill', WHITE);
      WriteConsole(ID, ' Do not cheat', WHITE);
      WriteConsole(ID, ' Do not abuse bugs, report them', WHITE);
      //if Modes.CurrentMode <> 1 then
        WriteConsole(ID, ' Do not change your IP to rejoin the game after death, with different task or team', WHITE);
      WriteConsole(ID, ' Do not go AFK for longer time', WHITE);
      WriteConsole(ID, ' Do not force alive players to vote', WHITE);
      WriteConsole(ID, ' Do not abuse !irc', WHITE);
      WriteConsole(ID, ' Do not call an admin without a proper reason', WHITE);
      WriteConsole(ID, 'Always remember, that this is a TEAMGAME.', WHITE);
      WriteConsole(ID, 'Play together, insulting will not help much.', WHITE);
      WriteConsole(ID, 'Respect admins and their decisions.', WHITE);
    end;
    7, 8: begin
      WriteConsole(ID, 'Survival mode:', GREEN);
      WriteConsole(ID, ' All players start as Survivors', WHITE);
      WriteConsole(ID, ' Your task is to survive as many waves as possible', WHITE);
      WriteConsole(ID, ' The best highscore is saved', WHITE);
    end;
    9: begin
      WriteConsole(ID, 'Versus mode:', GREEN);
      WriteConsole(ID, ' Half of players start as Survivors, half as Zombies.', WHITE);
      WriteConsole(ID, ' Survivors'' task is to survive as many waves as possible', WHITE);
      WriteConsole(ID, ' Zombies have to kill them or eat all civilians', WHITE);
      WriteConsole(ID, ' When Survivors are finally defeated, teams are swapped and the second round begins.', WHITE);
      WriteConsole(ID, ' After two rounds game ends. The team with more points wins', WHITE);
    end;
    10: begin
      WriteConsole(ID, 'Infection mode:', GREEN);
      WriteConsole(ID, ' All players start as Survivors. When survivor dies, he joins the Zombie team. ', WHITE);
      WriteConsole(ID, ' The game ends when all Survivors die or Zombies eat all civilians', WHITE);
    end;
    11: begin
      WriteConsole(ID, 'Butchery mode:', GREEN);
      WriteConsole(ID, '  Random player becomes a boss, others have to defeat him', WHITE);
    end;
    20: begin
      WriteConsole(ID, 'The Last Stand v' + S_VERSION + ' by tk and others:', WHITE);
      WriteConsole(ID, ' Coding: tk, Falcon, TheOne, Saike, Spkka, MetalWarrior, Gizd', WHITE);
      WriteConsole(ID, ' Idea (original authors): Saike, Spkka', WHITE);
      WriteConsole(ID, '', WHITE);
      WriteConsole(ID, ' Special thanks to:', WHITE);
      WriteConsole(ID, '  BombSki, dnmr, Falcon for the servers', WHITE);
      WriteConsole(ID, '  Horo, MetalWarrior, Monsteri, Falcon, TheOne, L[0ne]R, Steppenwo1f for the maps', WHITE);
      WriteConsole(ID, '  breach for The Infection weapon mod', WHITE);
      WriteConsole(ID, '  ... and the entire Eat This community for support and ideas', WHITE);
      WriteConsole(ID, 'Join us @ ' + ADV_SITE + ', #soldat.eat-this! @ Quakenet', WHITE);
    end;
    
    // Help
    22: begin
      WriteConsole(ID, 'Welcome to Last Stand, a zombie survival gamemode.', WHITE);
      if (GameRunning) or (StartGame) then begin
        if Player[ID].Participant <> 0 then begin
          WriteConsole(ID, ' /task      - Shows your current task and task-specific commands.', WHITE);
          WriteConsole(ID, ' /list      - Shows a list of players with their tasks.', WHITE);  
        end else begin
          WriteConsole(ID, ' /joinS, /joinZ - Join survivors/infected team.', WHITE);  
        end;
      end else begin
        WriteConsole(ID, ' /vote      - Makes a vote for starting the game or changing the map', WHITE);
      end;
      WriteConsole(ID, ' For more comands type /commands', WHITE);
    end;
  end;
end;

function Cmmd2RealCmmd(T, N: byte): string;
begin
  case N of
    1: Case T of
      1: Result := '/mre';
      2: Result := '/mine';
      3: Result := '/revive';
      4: Result := '/mre';
      5: Result := '/mre';
      6: Result := '/mre';
      7: Result := '/shw';
      66: Result := '/trap'; //firefighter
      67: Result := '/met'; //satan 1
      68: Result := '/ring'; //satan 2
    end;
    
    2: Case T of
      1: Result := '/wire';
      2: Result := '/remote';
      3: Result := '/revive';
      4: Result := '/mre';
      5: Result := '/mre';
      6: Result := '/heli';
      7: Result := '/shw';
      66: Result := '/trap'; //firefighter
      67: Result := '/des'; //satan 1
      68: Result := '/arrow'; //satan 2
    end;
    
    3: Case T of
      1: Result := '/build';
      2: Result := '/place 3';
      3: Result := '/revive';
      4: Result := '/scare';
      5: Result := '/mre';
      6: Result := '/mark';
      7: Result := '/exo';
      66: Result := '/fire'; //firefighter
      67: Result := '/min'; //satan 1
      68: Result := '/rain'; //satan 2
    end;
    
    4: Case T of
      1: Result := '/get';
      2: Result := '/act';
      3: Result := '/revive';
      4: Result := '/act';
      5: Result := '/mre';
      6: Result := '/strike';
      7: Result := '/exo';
      66: Result := '/fire'; //firefighter
      67: Result := '/par'; //satan 1
      68: Result := '/burn'; //satan 2
    end;
  end;
end;

//  * -------------------- *
//  |    INI Interface     |
//  * -------------------- *

const
  ERR_NOFILE = 'No file loaded';
  ERR_ARG = 'Invalid number of arguments';

var iini: tINI;
  iinipath: string;

procedure ShowSection(i: smallint; ID: byte);
var j: smallint;
begin
  WriteMessage(ID, IntToStr(i) + ' [' + iini.Section[i].Name + ']', ADM_INT1);
  for j := 0 to Length(iini.Section[i].Key) - 1 do begin
    WriteMessage(ID, ' ' + IntToStr(j) + '. ' + iini.Section[i].Key[j].Name + '=' + iini.Section[i].Key[j].Value, ADM_INT1);
  end;
end;

//  * ------------------------ *
//  |                          |
//  |     Crossfunc inputs     |
//  |                          |
//  * ------------------------ *

function SetAddr(Addr: String): boolean;
begin
  Result := true;
  CrossAddressMsg := Addr;
end;

function ServerInfo(): boolean;
begin
  Result := true;
  CrossFunc([GameRunning, Players_StatusNum(1), civilians, NumberOfWave, (Timer.Value div 60), zombiesKilled, Modes.RealCurrentMode], CrossAddressMsg + '.InputServerInfo');
end;

//  * ------------------------------------------------------------------------ *
//  |                                                                          |
//  |                                 Events                                   |
//  |                                                                          |
//  * ------------------------------------------------------------------------ *

procedure OnMapChange_(NewMap: string); forward;

procedure OnAfterMapChange_(Map: string);
begin
  OnMapChange_(Map);
  Base_OnMapChange();
  Config_ApplyMapSettings(Map);
  MapScore_LoadMapRecord(Map);
  CompareRecordFile_IC(Map);
  LSMap.CurrentNum := GetStringIndex(Map, MapList.List);
  AZSS_Init();
end;

// compatibile with 60hz mode
procedure OnTick_(Ticks: integer);
var
  i: integer; mi: byte; a, b: boolean; 
begin
  if Ticks mod 60 = 0 then begin // call #0

    if CheckModeVote then begin
      checkModeVote := false;
      if Players_HumanNum() > 0 then
        Modes_CheckVotes();
    end;
    
    MapVotes_Process();
    
    if ShowVersusStats > 0 then 
      {>} DisplayVersus();
      
    if News.Active then begin
      if (Timer.Value div 60) mod News.Time = 1 then begin
        incB(News.Last, 1);
        if News.Last > News.Max then
          News.Last := 0;
        for mi := 0 to News.Msg[News.Last].Height do
          WriteConsole(0, News.Msg[News.Last].Text[mi], News.msg[News.Last].Color);
      end;
    end;
    
    if CheckNumPlayers then begin
      CheckNumPlayers := false;
      if GameRunning then
        if Players_StatusNum(1) = 0 then begin
          if Modes.CurrentMode = 2 then begin
            if VersusRound = 1 then begin
              VersusSwapTeams();
            end else
              EndGame();
          end else EndGame();
        end;
    end;
    
    if PerformReset then begin
      PerformReset := false;
      Reset();
    end;
    
    if Game.Paused then begin
      if UPCountDown > 0 then begin
        UPCountDown := UPCountDown - 1;
        if UPCountDown = 0 then begin
          TaskMedic_OnUnpause();
          Command('/unpause');
          WriteConsole( 0, 'Game unpaused', $CCCC99 );
        end else WriteConsole( 0, IntToStr(UPCountDown) + '...', $CCCC99 );
      end;
    end else begin
      if Ticks mod 12600 = 0 then begin // 60*210
        WriteConsole( 0, '       Join us now!', WHITE ); 
        WriteConsole( 0, '#soldat.eat-this! @ Quakenet', WHITE ); 
        WriteConsole( 0, '      ' + ADV_SITE + '   ', WHITE );
      end;
  
      if switchMapTime > 0 then begin
        switchMapTime := switchMapTime - 1;
        Command('/map ' + MapList.List[ switchMapMap ]);
      end;
      
      if StartGame then begin
        {>} ProcessStarting();
        exit;
      end;
      
      if PerformStartMatch then begin
        PerformStartMatch := false;
        Reset();
        StartMatch(true);
      end;
    end;
  end; // <- /Call #0
  
  if Game.Paused then exit;
  if not GameRunning then exit;
  TimeStats_Start('AppOnIdle');
  Timer.Value := Timer.Value + Game.TickThreshold;
  Timer.Cycle := Timer.Value mod 60;

  if Timer.Cycle = 0 then begin // Game Running, Call #0
    if RespSG then begin
      RespSG := false;
      Statguns_Respawn();
    end;

    if (Timer.Value div 60) mod 2 = 0 then begin
      AvgSurvPwnMeter := (AvgSurvPwnMeter*4.0 + SurvPwnMeter) / 5.0;
      SurvPwnMeter := SurvPwnMeter*0.8;

      if FarmerMRECD > 0 then begin
        FarmerMRECD := FarmerMRECD - 1;
        if FarmerMRECD = 0 then begin
          FarmerMRECD := FARMER_MRE_TIME div 2;
          for i := 1 to MaxID do
            if Players[i].Active then
            if player[i].Status > 0 then
            if player[i].task = 4 then begin
              player[i].mre := player[i].mre + 1;
              WriteConsole(i, '+ 1 meal ready to eat (/mre)', GREEN);
            end;
        end;
      end;
      if {$IFDEF FPC}AZSS.{$ENDIF}AZSS.Active then
        {>} AZSS_Process();
    end;

    if SlotInfoCountdown > 0 then begin
      SlotInfoCountdown := SlotInfoCountdown - 1;
      if SlotInfoCountdown = 0 then begin
        if Modes.CurrentMode = 2 then begin
          mi := Players_ParticipantNum(-1);
          ticks := Players_ParticipantNum(1); // cba to declare another var
          a := ticks <= mi;
          b := mi <= ticks;
        end;
        for i := 1 to MaxID do
          if Players[i].Active then
            if Players[i].Human then
              if player[i].Status = 0 then
                if not PlayerBlocked(i, false, false) then begin
                  if Modes.CurrentMode = 2 then begin
                    if a then
                      if ticks < Game.MAXPLAYERS - Game.MAXPLAYERS div 2 then
                      //  WriteConsole( i, 'There are free slots in the surivors team, type /joinS <task> to join as a surivor (/free)', WHITE );
                      WriteConsole(i, 'There are free slots in the surivors team, type /joinS to join as a surivor', WHITE);
                    if b then
                      if mi < Game.MAXPLAYERS div 2 then
                        WriteConsole(i, 'There are free slots in the zombie team, type /joinZ to join as a zombie', WHITE);
                  end else
                  if Modes.CurrentMode = 3 then begin // infection
                    WriteConsole(i, 'To join Survivors, use /joinS', WHITE);
                    WriteConsole(i, 'To join Zombies, use /joinZ', WHITE);
                  end else // survival
                    if SurvivalSlotsNum > 0 then begin
                      WriteConsole(i, 'There are free slots in the game, type /joinS to join', WHITE);
                    end;
                end;
      end;
    end;
  end; // <- /GameRunning, Call #0

  // 60Hz Mode
  if Timer.Cycle mod 10 = 0 then begin
    // The point of all these funny numbers is to divide CPU load.
    // Unless someone migrates LS to C++ dll, we don't want everything computed at once.

    // (6Hz) 10, 20, 30, 40, 50, 0
    if Timer.Cycle = 0 then begin
      if PerformProgressCheck then begin
        PerformProgressCheck := false;
        CheckProgress();
      end;
      if Modes.CurrentMode > 1 then begin
        {>} CheckPlayers();
      end;
      {>} Spawn_Process();
    end else

    if Timer.Cycle = 10 then begin
      {>} ClusterBomb_Process();
      {>} Charges_Process();
      {>} ProcessINFTable();
    end else

    if Timer.Cycle = 20 then begin
    end else

    if Timer.Cycle = 30 then begin
      {>} ProcessIntro();
    end else

    if Timer.Cycle = 40 then begin
      {>} Kits_Process();
      {>} FMSG_Process();
    end else

    if Timer.Cycle = 50 then begin
      if mechanic > 0 then begin
        if Players[mechanic].Alive then begin
          {>} Statguns_ProcessConstruction();
        end;
      end;
      {>} Mines_Sign();
    end;

  end else begin // mod <> 10
    // filtered frequencies
    if Timer.Cycle mod 10 = 6 then begin // (6 hz) 6, 16, 26, 36, 46, 56
      if {$IFDEF FPC}EarthQuake.{$ENDIF}EarthQuake.Active then
        {>} EarthQuake_Process(Timer.Cycle = 6);
      {>} Hax_OnTick();
      {>} Scarecrow_Process(Timer.Cycle = 6, Timer.Value mod 600 = 6);
    end else
    if Timer.Cycle mod 20 = 4 then begin // (3 hz) 4, 24, 44
      {>} ProcessMolotovExplosion();
    end else
    if Timer.Cycle mod 15 = 7 then begin // (4 hz) 7, 22, 37, 52
      {>} ProcessMainPlayerLoop();
    end else
    if Timer.Cycle mod 20 = 9 then begin
      if mechanic > 0 then
        {>} Wires_Process(Timer.Cycle = 9); // (3 hz) 9, 29, 49
    end else
    if Timer.Cycle mod 20 = 14 then begin
      {>} Mines_Process();    // (3 hz) 14, 34, 54
    end else
    if Timer.Cycle mod 30 = 8 then begin // (2 hz) 8, 38
      {>} TaskPolice_Process(Timer.Cycle = 8);
    end;
    // ^ 4, 6, 7, 8, 9, 14, 16, 22, 24, 26, 29, 34, 36, 37, 38, 44, 46, 49, 52, 54, 56
  end;
  // ^ 4, 6, 7, 8, 9, 10, 14, 16, 20, 22, 24, 26, 29, 30, 34, 36, 37, 38, 40, 44, 46, 49, 50, 52, 54, 56

  if Timer.Cycle mod 4 = 1 then begin // (15 hz) 1, 5, 9, ..., 57
    {>} Strike_Process(Timer.Cycle = 5);
    {>} Spray_Process();
    {>} ProcessBosses(Timer.Cycle = 33);
    {>} TaskMedic_Process(Timer.Cycle = 9);
    {>} if ForcedPower > 0 then ProcessPower(ForcedPower, HaxID, Boss.Power[0].Victim, 0);
  end;
  if Timer.Cycle mod 5 = 2 then begin // (12 hz) 2, 7, ...
    {>} WeaponMenu_OnTick();
  end;

  {>} Sentry_Process(Timer.Cycle = 5);  // (60 hz)
  if Timer.Cycle mod 3 = 1 then begin  // (20 hz)
    {>} Fire_Process();
  end;
  TimeStats_End('AppOnIdle');
end;

procedure ShowStuff(ID: Byte);
begin
// why not case of? player may have more than one task...(admins haxparty)
  if ID = mechanic then begin
    WriteConsole(ID, 'Statguns:   ' + IntToStr(player[ID].statguns), GREEN);
    WriteConsole(ID, 'Wires:      ' + IntToStr(player[ID].Wires), GREEN);
    WriteConsole(ID, 'Sentryguns: ' + IntToStr(player[ID].Sentrys), GREEN);
    WriteConsole(ID, 'Sentry ammo belts: ' + IntToStr(player[ID].SentryAmmo), GREEN);
  end;
  if ID = DemoMan.ID then begin
    WriteConsole(ID, 'Mines:      ' + IntToStr(player[ID].Mines), GREEN);
    WriteConsole(ID, 'Charges:    ' + IntToStr(player[ID].charges), GREEN);
    WriteConsole(ID, 'Charges in game: '+Charges_InGameInfo(0), GREEN);
  end;
  if player[ID].task = 4 then begin
    WriteConsole(ID, 'Scarecrows: ' + IntToStr(player[ID].Scarecrows), GREEN);
  end;
  if ID = sharpshooter then begin
    WriteConsole(ID, 'Molotovs:   ' + IntToStr(player[ID].molotovs), GREEN);
  end;
  if ID = priest then begin
    WriteConsole(ID, 'Holy water: ' + IntToStr(player[ID].HolyWater), BLUE);
  end;
  if ID = Cop.ID then begin
    WriteConsole(ID, 'Supply points: ' + FormatFloat('0.0', Cop.SupplyPoints), ORANGE);
  end;
  if player[ID].mre > 0 then WriteConsole(ID, 'Meals: ' + IntToStr(player[ID].mre), GREEN);
end;

function OnPlayerCommand_(P: TActivePlayer; Text: string): boolean;
var
  z,w,v: byte; team, ID: byte;
  a, i: smallint;
  b: boolean;
  X, X2: single;
  str: string;
begin
  ID := P.ID;
  TimeStats_Start('OnPlayerCommand');
  if SHOWPLAYERCOMMANDS then begin
    if not player[ID].Admin then
      if (player[ID].Status <> 0) and (player[ID].Task > 0) then begin
        WriteLn('<' + Players[ID].Name + '> (' + TaskToShortName(player[ID].Task, player[ID].Status < 0) + ') ' + Text);
      end else
        WriteLn('<' + Players[ID].Name + '> ' + Text);
  end;
  if Players[ID].Alive then begin
    // list of commands which you need to be alive to perform
{case_of_1}
    if Copy(Text, 2, 4) = 'cmmd' then begin
      try a := StrToInt(Text[6]);
      except 
        TimeStats_End('OnPlayerCommand');
        exit;
      end;
      if (a >= 1) and (a <= 4) then begin
        str := Text;
        Text := Cmmd2RealCmmd(player[ID].task+iif(player[ID].Zombie, 60,0), a);
        WriteConsole(ID, str + ' -> ' + Text, SHORTCOMMAND);
        cmmd[0] := cmmd[0] + 1;
      end;
    end else
    if Copy(Text, 2, 2) = 'cc' then begin
      try a := StrToInt(Text[4]);
      except 
        TimeStats_End('OnPlayerCommand');
        exit;
      end;
      if (a >= 1) and (a <= 4) then begin
        str := Text;
        Text := Cmmd2RealCmmd(player[ID].task+iif(player[ID].Zombie, 60,0), a);
        WriteConsole(ID, str + ' -> ' + Text, SHORTCOMMAND);
        cmmd[1] := cmmd[1] + 1;
      end;
    end else begin
      // Hexer taunts
      str := Text;
      {$IFNDEF FPC}
      case Copy(Text, 2, 4) of
        'heal', 'smok': Text := Cmmd2RealCmmd(player[ID].task+iif(player[ID].Zombie, 60,0), 1);
        'def', 'taba': Text :=  Cmmd2RealCmmd(player[ID].task+iif(player[ID].Zombie, 60,0), 2);
        'ofs', 'take':  Text := Cmmd2RealCmmd(player[ID].task+iif(player[ID].Zombie, 60,0), 3);
        'smn', 'summ', 'vict': Text :=  Cmmd2RealCmmd(player[ID].task+iif(player[ID].Zombie, 60,0), 4);
        else b := true;
      end;
      {$ENDIF}
      if not b then begin
        WriteConsole(ID, str + ' -> ' + Text, SHORTCOMMAND);
        cmmd[2] := cmmd[2] + 1;
      end;
    end;
    
    str := LowerCase(Copy(GetPiece(Text, ' ', 0),2,5));

    {$IFNDEF FPC}
    if not Game.Paused then case str of
      'task': Taskinfo(ID);
            
      'activ', 'act': if DemoMan.ID = ID then begin
        str := LowerCase(GetPiece(Text, ' ', 1));
        try
          a := StrToInt(str) - 1;
          if (a > MAX_CHARGES-1) or (a < -1) then begin
            WriteConsole(ID, 'No charge with such ID', RED);
            TimeStats_End('OnPlayerCommand');
            exit;
          end;
        except
          case LowerCase(str) of
            '': a := $FF;
            '0', 'all': a := -1;
          end;
        end;
        Charges_Activate(ID, a);
      end else if (player[ID].task = 4) and (player[ID].Status = 1) then
        Scarecrow_TryDetonate();
      
      'mine': Mines_TryPlace(ID);
      
      'build': Statguns_TryBuild(ID);

      'sentr': Sentry_TryPlace(ID);
      
      'scare': Scarecrow_TryPlace(ID);
        
      'wire': Wires_TryPlace(ID);

      'fix': Sentry_TryOperation(ID, fix);
      
      'ammo': Sentry_TryOperation(ID, load_ammo);
      
      'get': begin
        b := false;
        if Mechanic = ID then begin
          GetPlayerXY(ID, X, X2);
          z := Statguns_GetAt(X, X2);
          if (z > 0) then  Statguns_Get(ID, z) 
          else Sentry_TryOperation(ID, retrieve);
        end;
        if WeaponSystem.Enabled then begin
          BaseWeapons_Get(ID);
        end;
      end;
        
      'mre':
        if player[ID].mre > 0 then
        begin
          player[ ID ].mre := player[ ID ].mre - 1;
          WriteConsole(ID, 'You eat your MRE and regain 50% health ['+IntToStr(player[ID].mre)+' left]', GREEN);
          Damage_Heal(ID, MAXHEALTH div 2);
        end else
          WriteConsole(ID, 'No meals ready to eat!', RED);
    
      'remot','rch': if DemoMan.ID = ID then
        Charges_TryPlace(ID, 255, true)  else //255 - infinite time;
          WriteConsole(ID, 'You are not the demolition expert', RED);

      'exorc','exo': Priest_TryOperation(ID, 2);

      'sprin','spr': WriteConsole(ID, 'Sprinkler feature moved to [Grenade] key', WHITE);

      'showe', 'shw': Priest_TryOperation(ID, 1);
          
      'seppu':
      if player[ID].status = 1 then
        if GetPiece(Text, ' ', 1) = '' then
        if Players_StatusNum(1) = 1 then Seppuku(ID, false) else
          WriteConsole(ID, 'You can do seppuku only when you are the last alive player', RED);
          
      'eqp','stuff': ShowStuff(ID);

          'gleqp', 'teqp': TaskPolice_ShowTeamEquipment(ID);
      //'give':
      //if player[ID].task = 4 then begin
        
      //end;
      //Bosses
      'auto': if ID = Boss.ID then begin
        AutoBrain := not AutoBrain;
        WriteConsole(ID, 'Automatic mode '+iif(AutoBrain, 'enabled', 'disabled'), ORANGE);
      end;
      
      'reloa':
        if player[ID].Status > 0 then begin
          player[ID].ReloadMode := not player[ID].ReloadMode;
          player[ID].ReloadTime := 0;
          WriteConsole(ID, 'Reloading info mode ' + iif(player[ID].ReloadMode, 'en', 'dis') + 'abled', GREEN);
        end;
      else b:=true;
    end else begin
      if PlayerPause = True then WriteConsole(ID, 'The game is paused (!unpause)', RED)
      else WriteConsole(ID, 'The game is paused by an admin', RED);
      b := true;
    end;
    {$ENDIF}
  end else begin
    b:=true;
    str := LowerCase(Copy(Text,2,5));
  end;
{/case_of_1}

  if not b then 
  begin
    TimeStats_End('OnPlayerCommand');
    exit; // if command already found then stop checking
  end;
  b := false;
  
  if Boss.bID > 0 then begin
    {$IFNDEF FPC}
    case Boss.bID of
      7: case str of
        //Satan
        'paral', 'par': z := 72;
        'minio', 'min': z := 71;
        'des': z := 73;
        'met': z := 74;
        else b := true;
      end;
      8: case str of
        //Satan 2'
        'ring': z := 81;
        'rain': z := 82;
        'arrow', 'arr': z := 85;
        'burn': z := 83;
        else b := true;
      end;
      6: case str of
        //Firefighter
        'trap': z := 63;
        'fire', 'fir': z := 62;
        else b := true;
      end;
      else b := true;
    end;
    {$ENDIF}

  {/case_of_2}
    if not b then begin
      a := CheckCollision(z);
      if a = 0 then Boss.PwID := z
      else if z <> a then WriteConsole(Boss.ID, 'Can''t perform '+PowerNumToName(z)+' while '+PowerNumToName(a)+' is in progress', RED);
      TimeStats_End('OnPlayerCommand');
      exit; // if command already found then stop checking
    end;
    b := false;
  end;
  
{case_of_3}
  {$IFNDEF FPC}
  case str of
    'table': begin
      WriteConsole(ID, 'Quick commands:', ORANGE);
      WriteConsole(ID, '                 | /cc1    | /cc2    | /cc3    | /cc4    |', SHORTCOMMAND);
      WriteConsole(ID, 'TASK             | Alt+1   | Alt+2   | Alt+3   | Alt+4   |', SHORTCOMMAND);
      if player[ID].Status >= 0 then begin
        z := MAX_TASKS;
        v := 1;
        team := 0;
      end else begin
        z := 68;
        v := 66;
        team := 60;
      end;
      for a := v to z do begin
        str := taskToName(a - team, team = 60);
        str := str + StringOfChar(' ',19 - Length(str));
        for w := 1 to 4 do begin
          Text := Cmmd2RealCmmd(a, w);
          str := str + Text + StringOfChar(' ', 10 - Length(Text));
        end;
        if (player[ID].task + team = a) then WriteConsole(ID, UpperCase(str), $FF7F50) else WriteConsole(ID, str, INFORMATION);
      end;
      WriteConsole(ID, 'You can play all tasks using only 4 taunts', SHORTCOMMAND);
      WriteConsole(ID, 'Alt+1...4 works only with default Soldat taunts', SHORTCOMMAND);
      TimeStats_End('OnPlayerCommand');
      exit;
    end;
    
    'quick': if player[ID].task > 0 then begin
      WriteConsole(ID, 'Short commands for the '+taskToName(player[ID].task, false)+':', ORANGE);
      if player[ID].Zombie then team := 60 else
      team := 0;
      WriteConsole(ID, 'Quick command | Task command', SHORTCOMMAND);
      WriteConsole(ID, ' /cc1, Alt+1  - ' + Cmmd2RealCmmd(player[ID].task + team, 1), INFORMATION);
      WriteConsole(ID, ' /cc2, Alt+2  - ' + Cmmd2RealCmmd(player[ID].task + team, 2), INFORMATION);
      WriteConsole(ID, ' /cc3, Alt+3  - ' + Cmmd2RealCmmd(player[ID].task + team, 3), INFORMATION);
      WriteConsole(ID, ' /cc4, Alt+4  - ' + Cmmd2RealCmmd(player[ID].task + team, 4), INFORMATION);
    end;
     
     // used this shit to create a table with commands on forums
    {'asd': begin
      WriteLnFile('cmmds.txt', '[table][tr] [td]                         [/td] [td][b]/cmmd1[/b][/td]   [td][b]/cmmd2[/b][/td]    [td][b]/cmmd3[/b][/td]    [td][b]/cmmd4[/b][/td][/tr]');
      for a := 1 to 7 do
      WriteLnFile('cmmds.txt','[tr][td][b]'+taskToName(a) +'[/b][/td]  [td]'+ Cmmd2RealCmmd(a,1) + '[/td]   [td]' +Cmmd2RealCmmd(a,2) + '[/td]   [td]' +Cmmd2RealCmmd(a,3) + '[/td]   [td]' +Cmmd2RealCmmd(a,4) + '[/td][/tr]');
      WriteLnFile('cmmds.txt', '[/table]');
    end;}
    
    'list': WriteInfo(ID,3);
    'joins': TryJoinSurvivors(ID);
    'joinz': TryJoinZombies(ID);  
    'advan': WriteInfo(ID, 4);
    'help': WriteInfo(ID, 22);
    'comma': WriteInfo(ID ,2);
    'score': DisplayScore(ID);
    
    'maps','voteh': begin
      WriteConsole(ID, 'Use /vote ID or /vote <name> (partial map name matches) to vote for the specified map, example: /vote 1', WHITE);
      WriteConsole(ID, 'Other vote options: "/vote rand" for a random map, "/vote next" for the next map', WHITE);
      for i := 0 to MapList.NumLines - 1 do
        WriteConsole(ID, MapList.InfoList[i], INFORMATION);
    end;

    'modeh': try
      if GetPiece(Text, ' ', 1) <> '' then begin
        z := StrToInt(GetPiece(Text, ' ', 1));
        if (z < 1) or (z > MAX_MODES) then begin
          WriteConsole(ID, 'There are only '+IntToStr(MAX_MODES)+' modes available', WHITE);
          TimeStats_End('OnPlayerCommand');
          exit;
        end;
        if Mode[z].Enabled then begin
          WriteInfo(ID, z+6);
        end else
          WriteConsole(ID, 'Mode ' + IntToStr(z) + ' is not available', WHITE);
      end else
        Modes_ShowModeList(ID);
    except end;
    
    'kill','bruta','mercy': begin
      {try 
        a := StrToInt( GetPiece(Text, ' ', 1 ) ) 
      except 
        if player[ID].Status = -1 then PerformProgressCheck := true;
        SetTeam(5, ID, false);
        CheckNumPlayers := true;
        exit; 
      end;    }
      Result := not player[ID].Admin;
    end;
    
    'unvot': if player[ID].VoteReady then MapVotes_OnUnVote(ID);
    'unmod': if player[ID].ModeReady then Modes_OnUnvote(ID);
    
    'credi', 'autho': WriteInfo(ID, 20);
    
    'info': begin
      SayToPlayer(ID, 'The server is running the official Last Stand mod, version ' + S_VERSION);
      SayToPlayer(ID, ADV_SITE + ', #soldat.eat-this! @ Quakenet');
      SayToPlayer(ID, '');
      SayToPlayer(ID, '/help, /commands, /credits');
      Result := true;
    end;

    else begin//if neither of commands above match then check command in the 2nd case of
      if Cop.ID = ID then
        TaskPolice_OnCommand(Text);

      if Medic.ID = ID then
        TaskMedic_OnCommand(Text);

      //2nd case of begin
      case LowerCase(GetPiece(Text, ' ', 0)) of
        '/t', '/T': if (Modes.CurrentMode <> 1) and ((GameRunning) or (StartGame)) then begin
          Text := Copy(Text,4,length(Text)-3);
          if Text <> nil then begin
            a := player[ID].Participant;
            if a = 1 then str := '(SURIVORS)' else if a = -1 then str := '(ZOMBIES)' else str := '(SPEC)';
            str := str + '[' + Players[ID].Name + '] ' + Text;
            WriteLn(str);
            for z := 1 to MaxID do
              if player[z].Participant = a then
                WriteConsole(z, str, $FFFEDA7C);
          end else WriteConsole(ID, 'Syntax error, type /t <text> (example ''/t hi!'')', RED);
        end;
        
        '/vote', '/ready': begin
            try a:=StrToInt( GetPiece(Text, ' ', 1 ) );
            except
              Text := GetPiece(Text, ' ', 1);
              if Text = nil then a:=0 else begin
                if Length(Text) > 2 then begin
                  Text := LowerCase(Text);
                  if Text = 'next' then begin
                    a := LSMap.CurrentNum + 2;
                    if a > MapList.Length then a := 1;
                  end  else
                  if Copy(Text, 1, 4) = 'rand' then begin
                    a := VOTE_RANDOM;
                  end  else for i := 0 to MapList.Length - 1 do
                    if ContainsString(LowerCase(MapList.List[i]), Text) then begin
                      a := i + 1;
                      break;
                    end;
                  if a = 0 then begin
                    WriteConsole(ID, 'No matching map name found, type /votehelp for the available maplist', RED);
                    TimeStats_End('OnPlayerCommand');
                    exit;
                  end;
                end else begin
                  WriteConsole(ID, 'Syntax: /vote <ID> or /vote <mapname> (partial name matches, at least 3 letters long, prefix not required)', RED);
                  TimeStats_End('OnPlayerCommand');
                  exit;
                end;
              end;
            end;
            MapVotes_OnVote(ID, a);
          end;
        '/autovote': begin
          Player[ID].AutoVote := not Player[ID].AutoVote;
          Player[ID].StoreAutoVote := Player[ID].AutoVote;
          WriteConsole(ID, 'Auto vote '+iif(Player[ID].AutoVote, 'enabled', 'disabled'), GREEN);
        end;
        '/votemap': if Copy(LowerCase(GetPiece(Text, ' ', 1)), 1, 3) = 'ls_' then 
          begin
            for i := 0 to MapList.Length - 1 do
              if LowerCase(MapList.List[i]) = LowerCase(GetPiece(Text, ' ', 1)) then
              begin
                Result := True; //Don't let him vote
                WriteConsole(ID, 'Type /vote <ID> to vote for a different map', GREEN); 
                WriteConsole(ID, 'Use /votehelp for more information, /list for list of votes', GREEN);                       
                TimeStats_End('OnPlayerCommand');
                Exit;
              end;
            WriteDebug(5, 'Votemap(try) started by ' + Players[ID].Name + ': ' + GetPiece(Text, ' ', 1));
          end else WriteConsole(ID, 'Only Last Stand maps (ls_*) can be played on this server.', RED);
                
                
        '/mode': begin
            Text := GetPiece(Text, ' ', 1);
            try 
              //Voted with number?
              a := StrToInt(Text);
              Modes_OnVote(ID, a);
            except 
              //Voted with name?
              Text := LowerCase(Text);
              for i := 1 to MAX_MODES do
                if ContainsString(LowerCase(Mode[i].Name), Text) then
                begin
                  Modes_OnVote(ID, i);
                  break;
                end;
              if i > MAX_MODES then
                WriteConsole(ID, 'No matching mode found, type /modehelp for the available modelist', RED);
            end;
          end;
          
        '/place':
          if DemoMan.ID = ID then begin
            try  Charges_TryPlace(ID, StrToInt(GetPiece(Text,' ',1) ), false); except WriteConsole(ID, 'Syntax: /place <time>, ie /place 3', RED); end;
          end else
            WriteConsole(ID, 'You are not the demolition expert', RED);
        '/bug': begin
          Text := Copy(text,6,length(text)-5);
          if Length(Text) > 0 then begin
            WriteLnFile('bugz.txt', FormatDate('mmm/dd hh:nn') + ' ['+IDToIp(ID)+'] <'+Players[ID].Name+'> ' + Text);
            WriteConsole(ID, '"'+Text+'"', ORANGE );
            WriteConsole(ID, 'Thank you for reporting the bug, your IP and nickname have been saved', ORANGE );
            WriteDebug(10, 'Bug <' + Players[ID].Name+ '> ' + Text);
            if FileExists('bug_n') then Text := ReadFile('bug_n')
            else Text := '';
            if Text <> nil then begin
              a := StrToInt(GetPiece(Text, '-', 0));
              WriteFile('bug_n', IntToStr(a+1) + '-');
            end else WriteFile('bug_n', '1-');
          end else WriteConsole(ID, 'Syntax error, type /bug <text>', RED);
        end;
      end;
    end;
  end;
  {$ENDIF}

{/case_of_3}
  TimeStats_End('OnPlayerCommand');
end;

const
  S_ERROR_MSG = 'syntax error';
  S_ERROR_ARG = 'invalid argument';

function OnCommand_(P: TActivePlayer; Text: string): boolean;
var i, ID, j, k: smallint; str, data: string; x, y: single;
    file2: array of string;
    {$IFNDEF FPC}
    args: array of variant;
    res: variant;
    {$ENDIF}
begin
  if P = nil then begin
    ID := 255;
  end else begin
    ID := P.ID;
  end;
  TimeStats_Start('OnCommand');

  if (ID <= 32) then begin
    player[ID].Admin := true;
    if Hax_OnCommand(ID, Text) then exit;
  end;

  {$IFNDEF FPC}
  case copy(Text,2,6) of
    'statis': begin
      TimeStats_Show(ID);
    end;
    
    'showbu': begin
      str := GetPiece(Text, ' ', 1);
      try
        if FileExists('bugz.txt') then
        begin
          data := ReadFile('bugz.txt');
            if data <> nil then
          begin  
            file2 := Explode2(data, br, false);
            if StrToInt(str) > 0 then
            begin
              WriteMessage(ID, 'Last ' + str + ' bugs: ', ORANGE);
              j := GetArrayLength(file2) - 1 - StrToInt(str);
              if j < 0 then j := 0;
              for i := j to GetArrayLength(file2) - 1 do WriteMessage(ID, file2[i], INFORMATION);
            end;
          end;
        end;    
      except
        str := S_ERROR_MSG + '/' + S_ERROR_ARG;
      end;
    end;
    'revive':try TaskMedic_RevivePlayer(StrToID(GetPiece(Text, ' ', 1), ID)); except end;
    'versio': WriteMessage(ID, 'The Last Stand, version '+S_VERSION, white);
    'list2': begin
      WriteMessage(id, 'zombiesleft:'+IntToStr(zombiesleft), white)
      for i := 1 to MAX_UNITS do
        if Players[i].Active then begin
          sleep(4);
          WriteMessage(ID, Players[i].Name + StringOfChar(' ', 22-length(Players[i].Name)) + 'part:' + IntToStr(player[i].Participant) + ' team:' + IntToStr(players[i].team) + '  stat:' + IntToStr(player[i].Status) + '  ' + TaskToShortName(player[i].task, player[i].Zombie) + '     ' + floattostr(RoundTo(Players[i].x, 2))
          +' '+floattostr(RoundTo(Players[i].y, 2)), WHITE);
        end;
    end;
    'list3': if id > 32 then begin
      for i := 1 to MAX_UNITS do
        if Players[i].Active then
          if not player[i].Zombie then
            WriteMessage(ID, Players[i].Name + StringOfChar(' ', 22-length(Players[i].Name)) + 'part:' + IntToStr(player[i].Participant) + '  stat:' + IntToStr(player[i].Status) + ' task: ' + TaskToShortName(player[i].task, player[i].Zombie) + StringOfChar(' ', 6-Length(TaskToShortName(player[i].task, player[i].Zombie))) + ' vote:' + iif(player[i].VoteReady, IntToStr(player[i].VotedMap), ''), GREEN);
    end;
    'start': begin WriteConsole( 0, 'Game reset', GREEN); PerformStartMatch := true; end;
    'stop' :  endGame();
    'demoeq': begin player[ DemoMan.ID ].charges:=MAX_CHARGES-1; player[ DemoMan.ID ].Mines:=MAX_MINES; end;
    'water':  player[priest].HolyWater := player[priest].HolyWater + 1000;
    'moloto': player[Sharpshooter].molotovs:=player[Sharpshooter].molotovs+MOLOTOVPACK;
    'str': Strike_Call(1);
    'str2': Strike_Call(2);
    'knife': Weapons_Force(ID, WTYPE_KNIFE, Players[ID].Secondary.WType, 0, 0);
    'setmar': Strike_SetMarker(ID);
    'free': if GameRunning then WriteMessage(ID, 'Free tasks: ' + FreeTasksString(false), WHITE);
    'sss': if ID <= 32 then Sht(ID, 1);
    'zzz': if ID <= 32 then Sht(ID, 2);
    'xxx': if ID <= 32 then Sht(ID, 3);
    'vvv': if ID <= 32 then Sht(ID, 4);
    'fff': if ID <= 32 then Sht(ID, 6);
    'asd':  begin
      GetPlayerXY(ID, X, Y);
      Y := Y - 10;
      CastPitchfork(X, Y, Players[ID].VELX * 5,
      Players[ID].VELY * 5, 0, 40, ID);
    end;
    'ccc': if ID <= 32 then begin
      GetPlayerXY(ID, X, Y);
      Y := Y - 10;
      Spray(X, Y, 19, 50, 600, 14, ID, true);
    end;
    'showru': WriteInfo(0, 5);
    'pause': WriteConsole(0, 'An admin paused the game.', ORANGE);
    'unpaus': begin
      PlayerPause := False;
      WriteConsole(0, 'Game Unpaused.', GREEN);
    end;
    'bugs':WriteMessage(ID, GetPiece(ReadFile('bug_n'), '-', 0) + ' bugs reported', GREEN);
    'loadfi': Config_LoadLSSettings();
    'loadli': MapList_Load();
    'dedmg': Damage_Debug := not Damage_Debug;
    'detime': TimeStats_ToggleAOIDBG();
    'status': begin
      Data := 'Mode: '+IntToStr(Modes.CurrentMode)+' ('
      case Modes.RealCurrentMode of
        1: Data := Data + 'Survival - Hardcore';
        2: Data := Data + 'Survival - Veteran';
        3: Data := Data + 'Versus';
        4: Data := Data + 'Infection';
      end;
      Data := Data + '), wave: '+IntToStr(NumberOfWave);
      Data := Data + ', Civilians left: '+IntToStr(Civilians);
      case Modes.CurrentMode of
        1: begin
          k := CalculatePoints();
          Data := Data + ', score: ' + IntToStr(k) + iif(k < MapRecord.Survival.Value, ' (' +  IntToStr(k - MapRecord.Survival.Value)  + ')', '');
        end;
        2: begin
          if VersusRound = 1 then Data := Data + ' [Team 1]: ' + IntToStr(Score[1][1]) + ' [Team 2]: ' + IntToStr(Score[2][1])
          else Data := Data + br +' [Team 1]: Current: ' + IntToStr(Score[1][2]) + '; Total: ' + IntToStr(Score[1][1]+Score[1][2]) + ' [Team 2]: Current: ' + IntToStr(Score[2][2]) + '; Total: ' + IntToStr(Score[2][1]+Score[2][2])
        end;
        //not included 3 as there's an idea to remove score from infection at all
      end;
      WriteMessage(ID, Data, WHITE);
    end;
    'fsentr': if ID <= 32 then begin
      GetPlayerXY(ID, x, y);
      Sentry_Place(x, y, ID, true);
    end;
    'seppu ', 'seppuk': try
      Text := GetPiece(Text, ' ', 1);
      Seppuku(StrToID(Text, ID), true);
    except 
      WriteMessage(ID, S_ERROR_MSG, RED);
      exit;
    end;
    'spawn': begin
      Spawn.Paused := not Spawn.Paused;
      WriteMessage(ID, 'Spawn ' + iif(Spawn.Paused, '', 'un') + 'paused', GREEN);
    end;
    'fmine': Mines_Place(ID);
    'fbomb': begin
      GetPlayerXY(ID, X, Y);
      Y := Y - 10;
      ClusterBomb_Spread(X, Y, 8, ID, 4, 11, false);
    end;
    'nws': begin
      WeaponSystem.Enabled := not WeaponSystem.Enabled;
      WriteMessage(ID, 'New WeaponSystem ' + iif(WeaponSystem.Enabled, 'enabled.', 'disabled.'), BLUE);
      BaseWeapons_Init(WeaponSystem.Enabled);
    end;
    'adbg': begin
      AZSS.Debug := not AZSS.Debug;
      WriteLn('<AZSS> Debug: ' + iif(AZSS.Debug, 'Enabled', 'Disabled'));
    end;
    'forcem': begin
      Config.ForceMode := not Config.ForceMode;
      WriteMessage(ID, 'Forced Mode: '+iif(Config.ForceMode, 'enabled', 'disabled'), WHITE);
    end;
    'godmod': begin
      player[ID].GodMode := not player[ID].GodMode;
      WriteMessage(ID, 'God mode: '+iif(player[ID].GodMode, 'enabled', 'disabled'), WHITE);
    end;
  else
    case Copy(Text,2,2) of
      'bl': begin
          try
            j := StrToInt(GetPiece(Text, ' ', 1));
          except
            WriteConsole(ID, 'Syntax Error: No ID given', RED);
            Exit;
          end;
          try
            i := StrToInt(GetPiece(Text, ' ', 2));
          except
            i := 5;
          end;
          if ID <= 32 then WriteConsole(ID, 'Player ' + Players[j].Name + ' blinded for ' + IntToStr(i) + ' seconds.', GREEN)
          else WriteDebug(10, 'Player ' + Players[j].Name + ' blinded for ' + IntToStr(i) + ' seconds.');
          BigText_DrawScreenX(DTL_BLACKOUT, j,'XXX',i * 60,WHITE,35,-3000,-3000);
        end;
      'dp' : begin
        i := StrToID(GetPiece(Text, ' ', 1), ID);
        WriteMessage(ID, Players[i].Name+' debug info:', WHITE)
        WriteMessage(ID, 'Alive: '+iif(players[i].Alive, 'true', 'false'), WHITE);
        WriteMessage(ID, 'Status: '+IntToStr(player[i].status), WHITE);
        WriteMessage(ID, 'Task: '+IntToStr(player[i].task), WHITE);
        WriteMessage(ID, 'Spawntimer: '+IntToStr(player[i].SpawnTimer), WHITE);
        WriteMessage(ID, 'Participant: '+IntToStr(player[i].participant), WHITE);
        WriteMessage(ID, 'X: '+FloatToStr(player[i].X)+', Y: '+FloatToStr(player[i].Y), WHITE);
        WriteMessage(ID, 'Pri: '+IntToStr(player[i].pri), WHITE);
        WriteMessage(ID, 'Weapon: '+IntToStr(Players[i].Primary.WType), WHITE);
        WriteMessage(ID, 'Team: '+IntToStr(Players[i].Team) , WHITE);
        WriteMessage(ID, 'Zombie: '+iif(player[i].zombie, 'true', 'false'), WHITE);
        WriteMessage(ID, 'Human: '+iif(players[i].human, 'true', 'false'), WHITE);
        WriteMessage(ID, 'Bitten: '+iif(player[i].bitten, 'true', 'false'), WHITE);
        WriteMessage(ID, 'Kicked: '++iif(player[i].kicked, 'true', 'false'), WHITE);
        WriteMessage(ID, 'GodMode: '++iif(player[i].GodMode, 'true', 'false'), WHITE);
        if i = Sharpshooter then WriteMessage(ID, Players[i].Name+' is Sharpshooter', WHITE);
        if i = Priest then WriteMessage(ID, Players[i].Name+' is Priest', WHITE);
        if i = Medic.ID then WriteMessage(ID, Players[i].Name+' is Medic', WHITE);
        if i = Cop.ID then WriteMessage(ID, Players[i].Name+' is Police Officer', WHITE);
        if i = DemoMan.ID then WriteMessage(ID, Players[i].Name+' is Demolition Expert', WHITE);
        if i = Mechanic then WriteMessage(ID, Players[i].Name+' is Mechanic', WHITE);
      end;
      'tb': begin
        i := Pos(' ', Text);
        try ID := StrToInt(Copy(Text, 4, i - 4));
        except ID := RandomPlayer(0, false);
        end;
        if i <= 0 then exit;
        BotChat(ID, Copy(Text, i+1, Length(text) - i));
      end;
      'fw': begin
        i := Pos(' ', Text);
        try
          ID := StrToInt(Copy(Text, 4, i - 4));
        except
        end;
        try 
          str := GetPiece(Text, ' ', 2);
          if str <> nil then i := WeapStrToInt(str) else i := Players[ID].Secondary.WType;
          j := WeapStrToInt(GetPiece(Text, ' ', 1));
          Weapons_Force(ID, j, i, iif(j <> 255, WeaponConfig[j].Ammo, 0), iif(i <> 255, WeaponConfig[i].Ammo, 0) );
        except WriteMessage(ID, S_ERROR_ARG+'/'+S_ERROR_MSG, RED);
        end;
      end;
      'so': try
        i := Pos(' ', Text);
        try
          ID := StrToInt(Copy(Text, 4, i - 4));
        except
        end;
        i := StrToInt(GetPiece(Text, ' ', 1))
        if i = 15 then begin
          GetPlayerXY(ID, x, y)
          statgun[SG.Num].X := x;
          statgun[SG.Num].Y := y;
          statgun[SG.Num].reference := Objects_Spawn(statgun[SG.Num].X,statgun[SG.Num].Y-15,15);
          SG.Num := SG.Num + 1;
        end else Objects_SpawnX(ID, i, 1);
      except
        WriteMessage(ID, S_ERROR_MSG, RED);
        exit;
      end;
      'gb': try
        i := Pos(' ', Text);
        try
          ID := StrToInt(Copy(Text, 4, i - 4));
        except
        end;
        i := StrToInt(GetPiece(Text, ' ', 1));
        GiveBonus(ID, i);
      except
        WriteMessage(ID, S_ERROR_MSG, RED);
        exit;
      end;
      'st': if ID <= 32 then try
        if not ((Text[4] <> '') and ((Ord(Text[4]) - 48 < 0) or (Ord(Text[4]) - 48 > 9))) then i := Pos(' ', Text);
        j := StrToIntDef(Copy(Text, 4, i - 4), ID);
        if player[j].Status < 0 then player[j].task := StrToIntDef(GetPiece(Text,' ',1), player[j].task) else begin // everyeverything was ok here
          i := TaskStrToInt(GetPiece(Text,' ',1));
          if i > 0 then begin // 0 means invalid argument
            if i = 255 then i := RandomTask();
            SwitchTask(j, i);
            if WeaponSystem.Enabled then begin
              BaseWeapons_AddTaskWeapons(j);
              BaseWeapons_Refresh(false);
            end;
            if j <> ID then WriteMessage(ID, Players[j].Name+' is now '+TaskToName(i, player[j].participant = -1), WHITE)
            else WriteMessage(ID, 'You''re now '+TaskToName(i, player[j].participant = -1), WHITE);
          end else WriteMessage(ID, S_ERROR_ARG+'/'+S_ERROR_MSG, RED);
        end;
      except; WriteMessage(ID, S_ERROR_MSG, RED);end;
    else
      case GetPiece(Text,' ',0) of
    //    '/pizg':begin ParticleCast(StrToInt(GetPiece(Text,' ',1)), StrToInt(GetPiece(Text,' ',2)), 0.3, 0.3, 200, player[id].X, player[id].Y);
      //    end;
        '/earthquake': EarthQuake_Start(StrToIntDef(GetPiece(Text, ' ', 1), 10));
        '/gr': begin
          i := StrToIntDef(GetPiece(Text, ' ', 1), 100);
          Game.Gravity := 0.0006*i;
          ServerModifier('Gravity', Game.Gravity);
          WriteMessage(ID, 'Gravity set to ' + IntToStr(i) + '%', WHITE);
        end;
        '/callfunc': begin
          file2 := Explode2(Copy(Text, 11, Length(Text) - 10), ' ', false);
          SetArrayLength(args, GetArrayLength(file2)-1);
          for i := 0 to GetArrayLength(file2) - 2 do begin
            case LowerCase(file2[i]) of
              'false': args[i] := false;
              'true': args[i] := true;
              else begin
                try
                  args[i] := StrToInt(file2[i+1]);
                except
                  try
                    args[i] := StrToFloat(file2[i+1]);
                  except
                    args[i] := file2[i+1];
                  end;
                end;
              end;
            end;
          end;
          try
            res := CrossFunc(args, Script.Name + '.' + file2[0]);
          except
            WriteMessage(ID, 'Error: ' + ExceptionToString(ExceptionType, ExceptionParam), RED);
          end;
          try
            if res <> Null then begin
              //case VarType(res) of
              //  16, 17, 18, 19, 2, 3, 5: str := FloatToStr(res);
              //  11: str := iif(res = true, 'true', 'false');
              //  else str := res;
              //end;
              //WriteMessage(ID, 'result: ' + str, GREEN);
            end;
          except
          end;
        end;
        '/delrec': begin // removes map record
          str := GetPiece(Text, ' ', 1);
          if str <> nil then begin
            MapRecord_Delete(str);
            WriteMessage(ID, 'Map record for "' + str + '" removed (if existed)', PINK);
            IC_SendData('d ' + str, 0);
          end;
        end;
        '/next', '/clear':begin
          for i:=1 to maxID do begin
            if player[i].Zombie then 
            if player[i].Status < 0 then begin
              player[i].Status := -2;
              SetTeam(5, i, true);  
              Player[i].SpawnTimer := 0;
            end else begin
              Spawn_TryKickZombie(i, true);
            end;
          end;
          i := 0;
          try i := StrToInt(GetPiece(Text, ' ', 1));
          except
          end;
          NextWave(i);
        end;
        '/s': try
          if Sentry_SetStat(GetPiece(Text, ' ', 1), StrToInt(GetPiece(Text, ' ', 2))) then WriteMessage(ID, 'No such stat', RED);
        except
          WriteMessage(ID, 'Invalid arguments', RED)
        end;
        '/spell', '/cast': 
          begin
            if GetPiece(Text, ' ', 1) = 'list' then begin
              for i := 60 to 90 do begin
                str := PowerNumToName(i)
                if str <> '' then WriteMessage(ID, IntToStr(i)+': '+str, INFORMATION);
              end;
              exit;
            end;
            try
              ForcedPower := StrToInt(GetPiece(Text, ' ', 1));
            except
              WriteMessage(ID, 'Syntax Error: /spell SPELL [USER] [VICTIM]', RED);
              Exit;
            end;
            
            try
              str := GetPiece(Text, ' ', 2);
              HaxID := StrToID(str, ID);
              if HaxID = 255 then
                HaxID := ID;
            except
              HaxID := ID;
            end;
            
            try
              str := GetPiece(Text, ' ', 3);
              GetPlayerXY(HaxID, x, y);
              if (str = 'rand') or (str = '') then i := lookForTarget(HaxID, x, y, 0, 400, true)
              else i := StrToInt(str);
              if not Players[i].Alive then i := HaxID;  
            except
              i := 0;
            end;
            CastSpell(ForcedPower, HaxID, i, 0);
        end;
        //'/ini': OnIniCommand(ID, Copy(Text, 6, Length(Text) - 5));
        '/kill': begin
          try 
            i:=StrToID(GetPiece(Text,' ',1), ID);
          except
            exit;
          end;
          if Players[i].Alive then begin
            Damage_DoAbsolute(i, i, MAXHEALTH);
          end;
          Result := true;
        end;
        '/sp': try
          Cop.SupplyPoints := Cop.SupplyPoints + StrToInt(GetPiece(Text,' ',1));
          if WeaponSystem.Enabled then
            if Cop.ID > 0 then
              if Cop.Shop.Active then
                if Cop.Shop.Status > 0 then
                  if Cop.Shop.Status <> 4 then
                    Cop.Shop.Status := 2;
        except; WriteMessage(ID, S_ERROR_MSG, RED); end;
        '/civs': try Civilians := Civilians + StrToInt(GetPiece(Text,' ',1)); except; WriteMessage(ID, S_ERROR_MSG, RED); end;
        '/fb': TaskPolice_OnBuyCommand(lowercase(copy(Text, 5, 200)));
        //'/dp':try Modes.DifficultyPercent:=StrToInt(GetPiece(Text,' ',1)) except; WriteConsole(ID, 'syntax err', RED); end;
        '/wn': begin
          try 
            i:=StrToInt(GetPiece(Text,' ',1));
          except
            WriteMessage(ID, S_ERROR_MSG, RED);
            exit;
          end;
          ScorePlayers := ScorePlayers + Players_StatusNum(1) * (i - NumberOfWave);
          NumberOfWave := i;
        end;
        '/resp', '/respz': begin
          //If no parameter's given or no task, simply resp the guy with current task
          str := GetPiece(Text, ' ', 1);
          i := 0;
          if str = Nil then str := 'me';
          
          if ID <= 32 then begin
            case LowerCase(str) of
              'last': if Players[LastJoinedID].Active then k := LastJoinedID else exit;
              else begin
                k := StrToID(str, ID);
                if k = $FF then begin
                  i := TaskStrToInt(str);
                  if i = 0 then begin
                    WriteMessage(ID, 'No matching name/task found (' + str + ')', RED);
                  end;
                end;
              end;  
            end;
          end else k := StrToID(str, ID);
        
          if GetPiece(Text,' ',0) = '/respz' then begin
            str := GetPiece(Text, ' ', 2);
            if str <> Nil then
            begin
              if i = 0 then begin
                str := GetPiece(Text, ' ', 2);
                i := StrToIntDef(str, 0);
              end;
            end;
            if not Player[k].Zombie then
            if Player[k].task <> 0 then
              OnCommand_(P, '/untask ' + IntToStr(k) + ' ' + IntToStr(Player[k].Task));
            StrToIntDef(GetPiece(Text, ' ', 2), -1);
            CreateUnit(k, i, -1);
            player[k].ShowTaskinfo := true;
            PerformProgressCheck := true;
            Zombies_Respawn(k, false, 0, 0);
          end else begin
            str := GetPiece(Text, ' ', 2);
            if (str <> Nil) or (i <> 0) then
            begin
              if i = 0 then i := TaskStrToInt(str);
              if i <> Player[k].Task then begin
                if (i <> 0) and (player[k].task <> 0) then begin
                  OnCommand_(P, '/untask ' + IntToStr(k) + ' ' + IntToStr(Player[k].Task));
                end;
              end;
            end else i := Player[k].Task;
            if i > 0 then 
            begin
              if i = 255 then i := RandomTask();
              if Players[k].Active then 
              begin
                PerformProgressCheck := true;
                CreateUnit(k, i, 1);
                if TaskAvailable[i] > 0 then
                  TaskAvailable[i] := TaskAvailable[i] - 1;
                if WeaponSystem.Enabled then begin
                  BaseWeapons_AddTaskWeapons(i);
                  BaseWeapons_Refresh(false);
                end;
                player[k].Status := 1;
                SetTeam(HUMANTEAM, k, true);
                player[k].ShowTaskinfo := true;
                player[k].JustResp := true;
              end else WriteMessage(ID, S_ERROR_ARG + '/ID ' + IntToStr(k) + 'not active', RED);
            end else WriteMessage(ID, S_ERROR_ARG+'/No Task given', RED);
          end;
        end;

        '/untask': try
          j := StrToID(GetPiece(Text,' ',1), ID);
          i := TaskStrToInt(GetPiece(Text,' ',2));
          if not Players[j].Active then begin
            WriteMessage(ID, 'No player with such ID', RED);
            exit;
          end;
          if j = Mechanic then begin
            if i = 1 then Mechanic := 0
            else k := 1;
          end else if i = 1 then begin
            WriteConsole(ID, Players[j].Name+' is not '+TaskToName(i, false), RED);
            exit;
          end;
          if j = DemoMan.ID then begin
            if i = 2 then DemoMan.ID := 0
            else k := 2;
          end else if i = 2 then begin
            WriteConsole(ID, Players[j].Name+' is not '+TaskToName(i, false), RED);
            exit;
          end;
          if j = Medic.ID then begin
            if i = 3 then Medic.ID := -1
            else k := 3;
          end else if i = 3 then begin
            WriteConsole(ID, Players[j].Name+' is not '+TaskToName(i, false), RED);
            exit;
          end;
          if Player[j].Task = 4 then begin
          end else if i = 4 then begin
            WriteConsole(ID, Players[j].Name+' is not '+TaskToName(i, false), RED);
            exit;
          end;
          if j = Sharpshooter then begin
            if i = 5 then Sharpshooter := 0
            else k := 5;
          end else if i = 5 then begin
            WriteConsole(ID, Players[j].Name+' is not '+TaskToName(i, false), RED);
            exit;
          end;
          if j =Cop.ID then begin
            if i = 6 then Cop.ID := 0
            else k := 6;
          end else if i = 6 then begin
            WriteConsole(ID, Players[j].Name+' is not '+TaskToName(i, false), RED);
            exit;
          end;
          if j = Priest then begin
            if i = 7 then Priest := 0
            else k := 7;
          end else if i = 7 then begin
            WriteConsole(ID, Players[j].Name+' is not '+TaskToName(i, false), RED);
            exit;
          end;
          if Player[j].Task = i then Player[j].Task := k;
          TaskAvailable[i] := TaskAvailable[i] + 1;
          WriteMessage(ID, TaskToName(i, false)+' task has been removed from '+Players[j].Name, WHITE);
        except
          WriteMessage(ID, S_ERROR_ARG+'/'+S_ERROR_MSG, RED);
          exit;
        end;
        '/setm': try
          str := GetPiece(Text, ' ', 1)
          if (StrToInt(str) < 1) or (StrToInt(str) > MAX_MODES) then begin
            WriteMessage(ID, 'there are only '+IntToStr(MAX_MODES)+' modes available', RED)
          end else begin
            if (GameRunning) or (StartGame) then endGame();
            Modes_Set(StrToInt(str), true);
          end;
          except
          end;
          
        '/opc': begin
          try
            ID := StrToID(GetPiece(Text, ' ', 1), ID);
          except
          end;
          if ID > 0 then
            if ID <= 32 then begin
              str := GetPiece(Text, ' ', 2);
              if str <> nil then
                OnPlayerCommand_(Players[ID], str);
            end;
        end;
      end;
    end;
  end;
  {$ENDIF}
  Result := false;
  TimeStats_End('OnCommand');
end;

procedure OnPlayerSpeak_(P: TActivePlayer; Text: string);
var
  points: integer;
  i, ID: byte;
begin

  ID := P.ID;
  if copy(Text,1,1) = '/' then 
  begin
    P.WriteConsole('This is not a command.', INFORMATION );
    P.WriteConsole('Do NOT press the chat button [default T] before typing the command', INFORMATION );
    P.WriteConsole('Press the command button [/] first!', INFORMATION );
    exit;
  end;
      
  Text := LowerCase(Text);
  {$IFNDEF FPC}
  case Copy(Text, 1, 5) of
    'medic', 'docto', 'doc!', 'doc': TaskMedic_Call(ID);
    else begin
      if copy(Text, 1, 2) = 't!' then
        delete(Text, 1, 1);
      if copy(Text, 1, 1) <> '!' then exit;
      TimeStats_Start('OnPlayerSpeak');
      case Copy(Text,2,5) of
        'joins': TryJoinSurvivors(ID);
        'joinz': TryJoinZombies(ID);
        
        'pause', 'p': if (GameRunning) then
          if not Game.Paused then
            if (player[ID].status = 1) then 
            begin
              Command( '/pause' );
              PlayerPause := True;
              WriteConsole( 0, 'Game paused. Type !unpause to unpause', $CCCC99 );
            end else WriteConsole(ID, 'Only survivors can pause the game.', RED)
          else WriteConsole(ID, 'Game is ' + iif(PlayerPause, 'already paused', 'already paused by an admin'), RED);  

        'unpau','up': if (GameRunning) then
          if (Game.Paused) then
            if (UPCountDown = 0) then
              if (player[ID].status = 1) then 
                if (PlayerPause) then 
                begin
                  UPCountDown := 4;
                  PlayerPause := False;
                end else
                  WriteConsole(ID, 'An admin paused the game, you can not unpause.', RED)
              else WriteConsole(ID, 'Only survivors can unpause the game.', RED)
            else WriteConsole(ID, 'Game is already unpausing.', RED)
          else WriteConsole(ID, 'Game isn''t paused.', RED);

        'help': WriteInfo(ID,22);
        'comma': WriteInfo(ID,2);

        { temporarily disabled, gonna change sth in news system
        !+ǫ Do not forget to add Antiflood, here +ǫ!
        'news', 'new': begin
          if News.Active then begin
            incB(News.Last, 1);
            if News.Last > News.Max then
              News.Last := 0;
            for i := 0 to News.Height[News.Last] do
              WriteConsole(0, News.Text[News.Last][i], News.Color);
          end else WriteConsole(0, 'No news activated.', News.Color);
        end;  }
        
        'medic': TaskMedic_Call(ID);
        
        'score': if Game.TickCount - ScoreAntifloodTime >= 300 then begin
          ScoreAntifloodTime := Game.TickCount;
          DisplayScore(0);
        end else WriteConsole(0, 'Antiflood: wait '+IntToStr(1 + (300 - Game.TickCount + ScoreAntifloodTime) div 60) + ' seconds', RED);
        
        'statu': if (GameRunning) or (StartGame) then begin
            case Modes.CurrentMode of
              1: begin
                points := CalculatePoints();
                WriteConsole(0, 'Survival (' + iif(Modes.RealCurrentMode = 1, 'Hardcore', 'Veteran') + ' mode) - Wave: ' + IntToStr(NumberOfWave) + '; Score: ' + IntToStr(points) + iif(points < MapRecord.Survival.Value, ' (' +  IntToStr(MapRecord.Survival.Value - points)  + ')', ''), WHITE);
              end;
              2: WriteConsole(0, 'Versus - Round: ' + IntToStr(VersusRound) + '/2; Wave: ' + IntToStr(NumberOfWave), WHITE);
              3: WriteConsole(0, 'Infection - Wave: ' + IntToStr(NumberOfWave), WHITE);
            end;
          end else begin
            Text := Mode[Modes.RealCurrentMode].Name + '  [map vote: ' + IntToStr(MapVotes_VotedNum()) + '/' + IntToStr(Players_HumanNum);
            i := Modes_VotedPlayersNum();
            if i > 0 then Text := Text + ', mode vote: ' + IntToStr(i) + '/' + IntToStr(Players_HumanNum) + ']' else Text := Text + ']';
            WriteConsole(0, Text, WHITE);
          end;
        
        'fixsg': if Players[ID].Alive then
          begin
          if Game.TickCount- SG.FixTimer >= 1200 then begin
            if SG.BuildTimer = 0 then begin
              RespSG := true;
              SG.FixTimer := Game.TickCount;
            end else WriteConsole(0, 'You can''t use fixsg during statgun build or retrieve process', RED);
            end else WriteConsole(0, 'Antiflood: wait '+IntToStr(1 + (1200 - Game.TickCount+ SG.FixTimer) div 60) + ' seconds', RED);
          end else WriteConsole(0, 'Only alive players can use this command.', RED);
        
        
        'rules': if Game.TickCount - RulesAntiflood >= 600 then begin
          WriteInfo(0, 5);
          RulesAntiflood := Game.TickCount;
        end else WriteConsole(0, 'Antiflood: wait '+IntToStr(1 + (600 - Game.TickCount + RulesAntiflood) div 60) + ' seconds', RED);
        'sbug', 'spect': 
          if Players[ID].Alive then 
            if player[ID].JustResp and not player[ID].Frozen then 
            begin
              SetTeam(iif(player[ID].Zombie, ZOMBIETEAM, HUMANTEAM), ID, true);
            end;
      end;
    end;
  end;
  {$ENDIF}
  TimeStats_End('OnPlayerSpeak');
end;

procedure OnJoinGame_(P: TActivePlayer; Team: TTeam);
var
    ID: byte;
begin
  ID := P.ID;
  GetMaxID();
  if not P.Human then Exit;

  TimeStats_Start('OnJoinGame');
  player[ID].Status := 0;
  player[ID].VoteReady := false;
  player[ID].Participant := 0;
  player[ID].SpecTimer := 0;
  player[ID].justjoined := true;
  LastJoinedID := ID;
  if ID > MaxID then MaxID := ID;
  if (Modes.CurrentMode > 1) or (SurvivalSlotsNum > 0) then
    if not PlayerBlocked(ID, false, true) then SlotInfoCountdown := 7;
  TimeStats_End('OnJoinGame');
end;

procedure OnJoinTeam_(P: TActivePlayer; Team: TTeam);
var
    HP: Single;
    ID: byte;
begin
  ID := P.ID;
  TimeStats_Start('OnJoinTeam');
  if ServerSetTeam then 
  begin 
    WriteDebug(1, Players[ID].Name + ' was forced to join team ' + inttostr(Team.ID));
    ServerSetTeam := false;
    TimeStats_End('OnJoinTeam');
    exit; 
  end;
  CheckNumPlayers := true;
  
  if player[ID].justjoined then begin
    SetTeam(5, ID, true);
    P.WriteConsole(' Welcome to {LS} Last Stand '+S_VERSION+' - Use /help to get started', WHITE ); 
    P.WriteConsole(' ' + ADV_SITE, INFORMATION );
    P.WriteConsole(' #soldat.eat-this! @ Quakenet', INFORMATION );
    P.WriteConsole('Type /votehelp to view advanced list of votes', GREEN);
    P.WriteConsole('Type /vote to start the game', GREEN);
    player[ID].justjoined := false;
    TimeStats_End('OnJoinTeam');
    exit;
  end;
  
  if (not Players[ID].Active) or (not Players[ID].Human) then Exit;

  if Team.ID <> 5 then
  begin
    if not GameRunning then begin
      P.WriteConsole('Type /votehelp to view advanced list of votes', GREEN);
      P.WriteConsole('Type /vote to start the game', GREEN);
      SetTeam(5, ID, true);
      TimeStats_End('OnJoinTeam');
      Exit;
    end;

    case player[ID].Status of
      0:   begin
          SetTeam(5, ID, true);
          P.WriteConsole('The game is currently running. Wait until the round ends', INFORMATION);
        end;

      1:   if Team.ID <> HUMANTEAM then SetTeam(5, ID, false)
        else begin
          BaseWeapons_OnPlayerRespawn(ID); // [check if this is actually necessary]
          WeaponMenu_OnPlayerRespawn(ID);
        end;

      -1: if Team.ID <> ZOMBIETEAM then begin
          SetTeam(ZOMBIETEAM, ID, true); //OnPlayerRespawn resets his HP, not good
          WeaponMenu_OnPlayerRespawn(ID);
        end;

      -2,2: SetTeam(5, ID, true);
    end;
  end else //Team = 5
    case Player[ID].Status of
      1:   begin
          BlockPlayer(ID);
          Player[ID].Status := 0;
          Untask(ID, false);
        end;

      -1: begin
          BlockPlayer(ID);
          Player[ID].Status := 0;
          player[ID].KickTimer := 0;
          player[ID].task := 0;
          player[ID].AfkSpawnTimer := 0;
          Player[ID].Zombie := False;
          HP := Players[ID].Health;
          {$IFNDEF FPC}
          case ID of
            Butcher: begin
              Butcher := 0;
              Spawn_AddZombies(1, 3);
              Damage_DoAbsolute(Butcher, Butcher, round(MAXHEALTH - HP));
             end;
            Boss.ID: begin
              Boss.ID := 0;
              Spawn_AddZombies(1, Boss.bID);
              Damage_DoAbsolute(Boss.ID, Boss.ID, round(MAXHEALTH - HP));
            end;
            zomPriest: begin
              zomPriest := 0;
              Spawn_AddZombies(1, 5);
              Damage_DoAbsolute(zomPriest, zomPriest, round(MAXHEALTH - HP));
             end;
            Plague.ID: begin
              Plague.ID := 0;
              Spawn_AddZombies(1, 9);
              Damage_DoAbsolute(Plague.ID, Plague.ID, round(MAXHEALTH - HP));
             end;
          end;
          {$ENDIF}
          PerformProgressCheck := true;
        end;
    end;
  TimeStats_End('OnJoinTeam');
end;

function OnBeforeRespawn_(P: TActivePlayer): TVector;
var
  ID: byte;
begin
  ID := P.ID;
  if player[ID].RespawnAtXY then begin
    Result.X := player[ID].X;
    Result.Y := player[ID].Y;
  end else begin
    Result.X := Players[ID].X;
    Result.Y := Players[ID].Y;
  end;
end;

procedure OnAfterRespawn_(P: TActivePlayer);
var
  ID: byte;
begin
  ID := P.ID;
  GetMaxID();
  TimeStats_Start('OnPlayerRespawn');
  if not player[ID].Respawned then begin
    player[ID].Respawned := true;
  end;
  player[ID].GetX := true;
  player[ID].JustResp := true;
  Player[ID].TicksAtSpawn := Timer.Value;    
  player[ID].RespawnTime := 0;
  if Players[ID].Human then begin
    case player[ID].Status of 
      1: begin
        // If player is a survivor
        // The client may have forgotten weapon menu settings so it must be refreshed totally.
        if WeaponSystem.Enabled then begin
          // With weaponsystem enabled, this function will refresh all weapons anyway.
          BaseWeapons_OnPlayerRespawn(ID);
        end else begin
          // Else, we just refresh whole menu using the WeaponMenu unit.
          WeaponMenu_RefreshAll(ID);
        end;
        WeaponMenu_OnPlayerRespawn(ID);
      end;
      -1: begin
        WeaponMenu_OnPlayerRespawn(ID);
      end;
      -2: begin
        InfectedDeath(ID);
      end;
      2: SetTeam(5, ID, true);
    end;
  end else begin
    if player[ID].KickTimer > 0 then Spawn_TryKickZombie(ID, false)
      else if Plague.ID <> 0 then PlagueOnMinionRespawn(ID);
  end;
  TimeStats_End('OnPlayerRespawn');
end;

procedure OnFlagGrab_(P: TActivePlayer; TFlag: TActiveFlag; Team: Byte; GrabbedInBase: Boolean);
var
  i, ID, h: byte;
  X, Y: single;
begin
  ID := P.ID;
  if not player[ID].zombie then Exit;
  if TFlag.Style <> HUMANTEAM then Exit;

  if civilians <= 1 then begin
    if Modes.CurrentMode = 2 then begin
      if VersusRound = 1 then begin
        VersusSwapTeams();
        VSStats[7] := 0
      end else begin
        EndGame();
        VSStats[8] := 0;
      end;
    end else
      EndGame();
  end else
  begin
    case Modes.CurrentMode of
      2: begin
        i:= VersusRound mod 2 + 1;
        Score[i][VersusRound] := Score[i][VersusRound] + VSPOINTSFORCIV;
        if Player[ID].Status < 0 then Player[ID].Civkills := Player[ID].Civkills + 1;
      end;
      3: begin
        Score[2][1] := Score[2][1] + VSPOINTSFORCIV
      end;
    end;
    GetPlayerXY(ID, X, Y);
    CreateBulletX(X, Y, 0, -0.2, 0, 5, ID);
    if ID = Boss.ID then begin
      case Boss.bID of
        7: h := MAXHEALTH div 9;
        8: h := MAXHEALTH div 12;
        else h := MAXHEALTH div 5;
      end;
      player[ID].BossDmg := player[ID].BossDmg + h;
    end else if ID = Satan.ArtifactID then h := MAXHEALTH div 3 else h := MAXHEALTH;
    //if Plague active,then Zombie has 50% of chance to be unrevivable
    if Plague.ID > 0 then if ID <> Plague.ID then PlagueOnFlagGrab(ID);
    Damage_DoAbsolute(ID, ID, h);
    if (not Players[ID].Alive) and (Player[ID].Task <> 91) then player[ID].KickTimer := 2;
    civilians := civilians - 1;
    Players.WriteConsole('Zombie slipped through. '+ LSMap.CivsName +' left: ' + IntToStr( civilians ), RED);
    Base_ReturnFlag();
    SurvPwnMeter := SurvPwnMeter + 0.2;
    if SurvPwnMeter > 1.0 then SurvPwnMeter := 1.0;
  end;
end;

// ---- OnPlayerDamage_ ----

function OnDamage_ApplyResistance(VID: integer; dmg_type: TDamageType): single;
begin
  case dmg_type of
    General: result := player[VID].Resistance.General;
    Explosion: result := player[VID].Resistance.Explosion;
    Heat: result := player[VID].Resistance.Heat;
    Wires: result := player[VID].Resistance.Wires;
    Shotgun: result := player[VID].Resistance.Shotgun;
    {$IFDEF FPC}TDamageType.{$ENDIF}SentryGun: result := player[VID].Resistance.SentryGun;
    Helicopter: result := player[VID].Resistance.Helicopter;
    HolyWater: result := player[VID].Resistance.HolyWater;
    ExoMagic: result := player[VID].Resistance.ExoMagic;
  end;
end;

function OnDamage_ApplyWeaponResistance(VID, SID: integer; weap: byte; Special: boolean): single;
begin
  if SID = Sentry.ID then begin
    Result := player[VID].Resistance.SentryGun;
  end else
  case weap of
    WTYPE_SPAS12: if Special then begin
      Result := player[VID].Resistance.HolyWater;    // sprinkler
    end else begin
      Result := player[VID].Resistance.Shotgun;    // shotgun
    end;
    WTYPE_M79,                      // explosives
    WTYPE_FRAGGRENADE,
    WTYPE_CLUSTER: Result := player[VID].Resistance.Explosion;
    WTYPE_FLAMER: Result := player[VID].Resistance.Heat;
    WTYPE_BOW2: Result := (player[VID].Resistance.Heat + player[VID].Resistance.Explosion) * 0.5;
    WTYPE_LAW: if Special then begin
      Result := player[VID].Resistance.Helicopter;  // heli
    end else begin
      Result := player[VID].Resistance.Explosion;    // explosives
    end;
    WTYPE_M2: if Special then begin
      Result := player[VID].Resistance.Helicopter;  // heli
    end else begin
      Result := player[VID].Resistance.General;
    end;
    else Result := player[VID].Resistance.General;
  end;
end;

function OnDamage_DebugWeapType(SID, Weap: byte; Special: boolean): string;
begin
  if SID = Sentry.ID then begin
    Result := '<Sentry>';
  end else
  case Weap of
    WTYPE_SPAS12: if Special then begin
      Result := '<HolyWater>';
    end else begin
      Result := '<Shotgun>';
    end;
    WTYPE_M79,
    WTYPE_FRAGGRENADE,
    WTYPE_CLUSTER: Result := '<Explosive>';
    WTYPE_FLAMER: Result := '<Heat>';
    WTYPE_BOW2: Result := '<FlameBow>';
    WTYPE_LAW: if Special then begin
      Result := '<Heli>';
    end else begin
      Result := '<Explosive>';
    end;
    WTYPE_M2: if Special then begin
      Result := '<Heli>';
    end else begin
      Result := '<General>';
    end;
    else Result := '<General>';
  end;
end;

function OnDamage_DebugType(): string;
begin
  case Damage_Type of
    General: Result := '<General>';
    Explosion: Result := '<Explosion>';
    Heat: Result := '<Heat>';
    Wires: Result := '<Wires>';
    Shotgun: Result := '<Shotgun>';
    {$IFDEF FPC}TDamageType.{$ENDIF}SentryGun: Result := '<Sentry>';
    Helicopter: Result := '<Helicopter>';
    HolyWater: Result := '<HolyWater>';
    ExoMagic: Result := '<ExoMagic>';
    else Result := '<wtf>';
  end;
end;

function OnDamage_ApplyHeadshotChance(Victim, Shooter: tActivePlayer; BulletID: byte): single;
var
  p: single;
  d: single;
begin
  if Players[Victim.ID].Y - Map.Bullets[BulletID].Y > 18.0 then begin
    // Lower probability of headshot out of screen range
    d := PlayersDist(Victim, Shooter) + 1.0;
    p := ToRangeF(0.0, 701.0 / d, 1.0);
    p := p*p;
    if RandFlt(0, 1.0) < p then Result := player[Victim.ID].HeadShootBonus;
  end;
end;

function OnDamage_ApplySpasReduction(Victim, Shooter: tActivePlayer): single;
var
  d: single;
begin
  d := PlayersDist(Victim, Shooter);
  if d < 250.0 then begin
    result := 1.0;
  end else
  if d < 600.0 then begin
    d := d - 250.0;
    result := 1.0 - (d / 350.0);
  end else begin
    result := 0.0;
  end;
end;

// When a zombie (human player or bot) is damaged.
function OnZombieDamage(Shooter, Victim: TActivePlayer; Damage: single; BulletId: byte; Special: boolean): single;
var
  dmg, boost: single;
  resistance: single;
  VID, SID: integer;
  weap: byte;
  i: byte;
  SkipWeaponEffect: boolean;
begin
  VID := Victim.ID;
  SID := Shooter.ID;
  
  // Damage_Direct indicates that damage has been done by the script with Damage() function.
  if Damage_Direct then begin

    // Damage_Absolute indicates that damage won't be infuenced by player-specific modifiers
    if Damage_Absolute then begin
      dmg := single(Damage);
      if Damage_Debug then WC('Zombie, direct, abs: ' + inttostr(round(dmg)));
    end else begin
      dmg := Damage * player[SID].DamageFactor / OnDamage_ApplyResistance(VID, Damage_Type);
      if Damage_Debug then begin
        WC('Zombie, direct, rel: ' + FormatFloat('0.0', Damage) + '->' + inttostr(round(dmg)) + ', ' + OnDamage_DebugType());
      end;
    end;
    weap := WTYPE_NOWEAPON;
    
  // Indirect (non-script) damage. Weapons, bullets, selfdamage, etc.
  end else begin
    if BulletID < 254 then begin
      weap := Map.Bullets[BulletID].GetOwnerWeaponId();
    end else
      weap := WTYPE_NOWEAPON;
    resistance := OnDamage_ApplyWeaponResistance(VID, SID, weap, Special);
    dmg := Damage * player[SID].DamageFactor / resistance;
    if Damage_Debug then begin
      WC('Zombie, indirect: ' + FormatFloat('0.0', Damage) + '->' + inttostr(round(dmg))+', weap: '+inttostr(weap) + ', ' + OnDamage_DebugWeapType(SID, weap, Special));
    end;
  end;
  
  // Do victim task-specific things now
  if not Damage_Absolute then
  case player[VID].Task of
    
    1: begin  // Kamikaze zombie
      // It comes together with exploding zombies, self damage from ground collisions
      // could be significant.
      if VID = SID then begin
        if dmg > 10.0 then
          dmg := 10.0;
      end;
      if (players[VID].Health - dmg <= 1) then begin
        player[VID].KamiDetonate := 1;
        player[VID].KamiKiller := SID;
        dmg := players[VID].Health - 1; // leave him with 1 hp
        SkipWeaponEffect := true;  // so dmg won't be modified since now.
      end;
    end;
    
    2: begin  // Vomiting zombie
      if VID = SID then begin
        if player[VID].charges >= ZOMBIE_JUMP_COOLDOWN div 3 then
          dmg := 0;
      end else
      if Victim.Human then
      if (Timer.Value - player[VID].FlakTime >= 15) then begin
        player[VID].FlakTime := Timer.Value;
        CreateBulletX(
          Map.Bullets[BulletID].X, Map.Bullets[BulletID].Y-7,
          Map.Bullets[BulletID].VelX*0.3, Map.Bullets[BulletID].VelY*0.3,
        1, 3, VID);
      end;
    end;
    
    4: begin // Burning Zombie
      if (Timer.Value - player[VID].FlakTime >= 15) then begin
        player[VID].FlakTime := Timer.Value;
        if BurningRef > 0 then begin
          CreateBulletX(Victim.X, Victim.Y, 0, 0, 0, 5, BurningRef);
        end else
          CreateBulletX(Victim.X, Victim.Y, 0, 0, 0, 5, VID);
      end;
    end;  
    
    11: begin  // Ticking Bomb
      // Just like kamikaze zombie, with bigger timer and some effects.
      if VID = SID then begin
        if dmg > 10.0 then
          dmg := 10.0;
      end;
      if (players[VID].Health - dmg <= 1) then begin
        if player[VID].KamiDetonate = 0 then begin
          player[VID].KamiDetonate := TICKING_BOMB_TIME;
          player[VID].KamiKiller := SID;
          CreateBulletX(Victim.X, Victim.Y, 0, 0, 0, 5, VID);
        end;
        dmg := players[VID].Health - 1; // leave him with 1 hp
        SkipWeaponEffect := true;
      end else
      // "Tick" message when shot
      if (Timer.Value - player[VID].FlakTime >= 120) then begin
        player[VID].FlakTime := Timer.Value;
        Botchat(VID, '^Tick');
      end;
    end;
    
    // Bosses
    3, 5, 6, 7, 8, 9: begin
      // Lower input if the boss is being owned too hard.
      Boss_IncreaseTempInputFactor(-dmg/player[VID].MaxDamagePerSec/5);
      dmg := dmg * Boss.TempDmgInputFactor;
      player[VID].bitten := true;    // Text with bosses hp will be displayed in AppOnIdle.
      if player[VID].Task = 8 then 
      if Satan.ArtifactID > 0 then begin
        dmg := dmg * 0.0001;
        player[VID].bitten := false;
      end;
      if VID <> SID then begin    // Let sp grow when they are fightng the boss.
        ZombieFightTime := Timer.Value;
      end;
    end;
    
    // Trap
    62: if SID = VID then begin
      dmg := 0;
    end;

      //Plague Minion blown up
      91: PlagueOnMinionDamage(VID, Damage, weap, Damage_Type);
  end;
  
  // Do special weapon effects.
  if not Damage_Direct then
  if VID <> SID then begin
    case weap of
      WTYPE_SPAS12:
        dmg := dmg * OnDamage_ApplySpasReduction(Victim, Shooter);
      WTYPE_RUGER77:
      if not SkipWeaponEffect then begin
        boost := OnDamage_ApplyHeadshotChance(Victim, Shooter, BulletID);
        if boost > 0.1 then begin
          dmg := dmg * (1.0+boost);
          BigText_DrawMap(SID, 'Head!', 60, $CCCC66, 0.04, Round(Victim.X-10.0), Round(Victim.Y-30.0));
        end;
      end;
      WTYPE_BARRETT: begin
        if not SkipWeaponEffect then begin
          boost := OnDamage_ApplyHeadshotChance(Victim, Shooter, BulletID);
          if boost > 0.1 then begin
            dmg := dmg * (1.0+boost);
            BigText_DrawMap(SID, 'Head!', 60, $CCCC66, 0.04, Round(Victim.X-10.0), Round(Victim.Y-30.0));
          end;
          if player[SID].Task = 5 then
            dmg := dmg*Math.Pow(player[VID].Resistance.General, 0.333);
        end;
        Victim.SetVelocity(Victim.VelX + Map.Bullets[BulletID].VelX * 0.04, Victim.VelY + Map.Bullets[BulletID].VelY * 0.04);
      end;        
      WTYPE_MINIGUN: begin // flak cannon
        if Timer.Value - player[SID].FlakTime > 10 then begin
          if RandInt(1,1000) <= FLAKCRITCHANCE then begin
            if Players_OnGround(VID, false, 35) = 1 then
              Fire_CreateBurningArea(Victim.X, Victim.Y, 7, 70, 4, 1, SID);
          end;            
          if RandInt(1,1000) <= FLAKCRITCHANCE then begin
            CreateBulletX(Victim.X, Victim.Y, 0, 0, 50, 4, SID);
          end else begin
            TickFlak(VID, SID, 20);
          end;
          player[SID].FlakTime := Timer.Value;
        end;
      end;
      WTYPE_CHAINSAW: begin
        dmg := dmg * player[SID].ChainsawDamageFactor;
        player[SID].ChainsawDamageFactor := player[SID].ChainsawDamageFactor * 0.5;
        if player[SID].ChainsawDamageFactor < 0.25 then
          player[SID].ChainsawDamageFactor := 0.25;
        if not RayCast(Shooter.x, Shooter.y - 10, Victim.x, Victim.y - 10, true, true, true) then dmg := dmg * 0.7;
        if not RayCast(Shooter.x+5, Shooter.y - 5, Victim.x+5, Victim.y - 5, true, true, true) then dmg := dmg * 0.7;
        if not RayCast(Shooter.x-5, Shooter.y - 5, Victim.x, Victim.y - 5, true, true, true) then dmg := dmg * 0.7;
      end;
    end;
  end;
  
  // If damage is set to be absolute: not influenced by any factors.
  if not Damage_Absolute then begin
    if dmg > 0 then
      player[VID].HurtTime := Timer.Value;
  
    // Limit amount of damage per hit for the zombie.
    if dmg > player[VID].MaxDamagePerHit then begin
      dmg := player[VID].MaxDamagePerHit;
    end;
    
    // Limit amout of damage per second for the zombie.
    if player[VID].DamagePerSec + dmg > player[VID].MaxDamagePerSec then begin
      dmg := player[VID].MaxDamagePerSec - player[VID].DamagePerSec;
    end;
  end;
  player[VID].DamagePerSec := player[VID].DamagePerSec + dmg;
  
  // Sum damage dealt to Boss for the message.
  if player[VID].Boss then
  if (SID = Sentry.ID) or (player[SID].Status = 1) then begin
    player[SID].BossDmg := player[SID].BossDmg + dmg;      
  end;

  Result := dmg;
  
  if Damage_Debug then
    WC('Z result: ' + FormatFloat('0.0', Result) + ' (' + FloatToStr(dmg) +') -----------');
end;

// When a Dummy bot is damaged
function OnDummyDamage(Shooter, Victim: TActivePlayer; Damage: single; BulletId: byte): single;
begin
  if player[Shooter.ID].Boss then begin
    case player[Shooter.ID].Task of
      6,7,8: begin
        if Victim.ID = Sentry.ID then begin
          Sentry_Clear(true);
        end else if Victim.ID = Scarecrow.ID then begin
          Scarecrow_Kaboom();
        end;
      end;
      else begin
        Result := -600;
      end;
    end;
  end else begin
    Result := -600;
  end;
end;

// When survivor player is damaged.
function OnSurvivorDamage(Shooter, Victim: TActivePlayer; Damage: Single; BulletId: byte; Special: boolean): Single;
var
  VID, SID: integer;
  tmp: Single;
  weap: byte;
begin
  VID := Victim.ID;
  SID := Shooter.ID;
  
  // Damage_Direct indicates that damage has been done by the script with Damage() function.
  if Damage_Direct then begin
  
    // Damage_Absolute indicates that damage won't be infuenced by player-specific modifiers
    if Damage_Absolute then begin
      //Damage := Damage;
      if Damage_Debug then WC('Surv, direct, abs: ' + FormatFloat('0.##', Damage));
    end else begin
      Damage := Damage * player[SID].DamageFactor / OnDamage_ApplyResistance(VID, Damage_Type);
      if Damage_Debug then WC('Surv, direct, rel: ' + FormatFloat('0.##', Damage));
    end;
    weap := WTYPE_NOWEAPON;
  end else begin
  
    if BulletID < 254 then begin
      weap := Map.Bullets[BulletID].GetOwnerWeaponId();
    end else
      weap := WTYPE_NOWEAPON;  
    if Damage_Debug then WC('Surv, indirect, rel: ' + FormatFloat('0.##', Damage) +', weap: '+inttostr(weap));
  end;
  
  if not Damage_Absolute then
  if VID <> SID then begin
    if player[SID].Zombie then begin
      case player[VID].Task of
        // Farmer
        4: Damage := Math.Pow(Damage, 0.5);
        // Priest. Lower input damage during exorcism.
        7: if player[VID].ExoTimer < 0 then begin
          Damage := Math.Pow(Damage, 0.5);
          if BulletID > 0 then
            BigText_DrawMap(0, '*', 80, BLUE, RandFlt(0.04, 0.08), Round(Map.Bullets[BulletID].X), Round(Map.Bullets[BulletID].Y));
        end;
      end;
    
      case weap of
        WTYPE_CHAINSAW:
          if player[SID].Task = 31 then Damage := 1 + Players[VID].HEALTH * 0.7;
        WTYPE_M2: begin
            if Players[VID].Vest > Player[VID].LastVest then
              Player[VID].LastVest :=  100;
            Damage_SetHealth(VID, Players[VID].Health, Player[VID].LastVest);
            Damage := 0;
        end;
      end;
      
      SurvPwnMeter := SurvPwnMeter + single(Damage) / MAXHEALTH / 5.0;
      if SurvPwnMeter > 1.0 then SurvPwnMeter := 1.0;
      
      if Modes.CurrentMode <> 1 then begin
        if Modes.CurrentMode = 2 then
        if player[VID].Status = 1 then
        if Damage <= Players[VID].Health then
          HumDamageTaken := HumDamageTaken + Damage
        else
          HumDamageTaken := HumDamageTaken + Players[VID].Health;
        if player[SID].Status = -1 then begin
          tmp := ToRangeF(0, Damage, Players[VID].Health);
          player[SID].zombdamage := player[SID].zombdamage + Trunc(tmp);
          if tmp > 0 then SetScore(SID, player[SID].zombdamage); 
        end;
      end;
      
      player[VID].HurtTime := Timer.Value;
    end else
    if SID = Sentry.ID then begin
      Damage := 0;
    end;
    
  // Lower self-damage during earthquake
  end else begin
    // a twisted case: this is regenerating polygon.
    // damage was already reversed by the Special flag,
    // so no we reverse it back
    if Special then Damage := -Damage;
  
    if {$IFDEF FPC}EarthQuake.{$ENDIF}EarthQuake.Active then
      Damage := Damage / 5;
  end;
  Result := Damage;
  Player[VID].LastVest :=  Players[VID].Vest;
end;

function OnPlayerDamage_(Shooter, Victim: TActivePlayer; Damage: single; BulletId: byte): single;
var
  Special: boolean;
begin
  if player[Victim.ID].GodMode then begin
    Result := -99999;
    if Damage_Debug then WriteConsole(0, 'GodMode exit', White);
    exit;
  end;
  
  // In LS we use negative damage for things like sprinkler, statguns, helicopter
  // to indicate that damage done by them should be treated in special way.
  // For example we don't want sprinkler bullets to hurt their owner.
  if (not Damage_Healing) and (Damage < 0) then begin
    Special := true;
    Damage := -Damage;
  end;
  
  // Victim is a zombie
  if player[Victim.ID].Zombie then begin
    Result := OnZombieDamage(Shooter, Victim, Damage, BulletId, Special);
  end else
  
  // Victim is a dummy bot
  if Players[Victim.ID].Dummy then begin//
    Result := OnDummyDamage(Shooter, Victim, Damage, BulletId);
  end else
  
  // Victim is a survivor
  if player[Victim.ID].Status > 0 then begin
    Result := OnSurvivorDamage(Shooter, Victim, Damage, BulletId, Special);
  end;
end;

procedure OnZombieKill(Killer, Victim: TActivePlayer; BulletId: Byte);
begin
  PerformProgressCheck := true;
  if not Player[Killer.ID].Zombie then player[Killer.ID].kills := player[Killer.ID].kills + 1;
  if zombiesLeft > 2 then player[Victim.ID].KickTimer := 3 else player[Victim.ID].KickTimer := 2;
  zombiesKilled := zombiesKilled + 1;
  ZombieFightTime := Timer.Value; // let sp grow when they are fightng zombies
  if Modes.CurrentMode <> 2 then Score[1][1] := Score[1][1] + 1;
  Bosses_OnZombieKill(Killer, Victim, BulletID);

  if Victim <> Killer then
    if Killer.ID = DemoMan.ID then begin
      if player[Killer.ID].kills mod Mode[Modes.RealCurrentMode].KillsForClusts = 0 then
      begin
        Killer.GiveBonus(5);
        Killer.WriteConsole('Cluster nades!', $FF8C00 );
      end;
    end else
    if (Killer.ID = mechanic) or (Killer.ID = medic.ID) then begin
      if player[Killer.ID].kills mod Mode[Modes.RealCurrentMode].KillsForNades = 0 then
        if Killer.Grenades = 0 then
        begin
          Killer.GiveBonus(4);
          Killer.WriteConsole('Grenade!', $FF8C00 );
        end;
    end;
end;

procedure OnSurvivorKill(Killer, Victim: TActivePlayer; BulletId: Byte);
begin
  if not player[Killer.ID].Zombie then
  begin
    if Timer.Value - Player[Victim.ID].TicksAtSpawn <= 90 then
    begin
      Victim.WriteConsole('SpawnProtection: Respawned due to Polybug.', GREEN);
      WriteDebug(3, 'Player ' + IntToStr( Victim.ID ) + ' spawnprotected');
      Player[Victim.ID].Status := 1;
      Player[Victim.ID].bitten := false;
      Player[Victim.ID].SpecTimer := 0;
      Player[Victim.ID].TicksAtSpawn := Timer.Value;
      SetTeam(HUMANTEAM, Victim.ID, true);
      if player[Victim.ID].task = 5 then
        Weapons_Force(Victim.ID, WTYPE_BARRETT, iif(player[Sharpshooter].molotovs > 0, WTYPE_KNIFE, WTYPE_NOWEAPON), 255, 255);
      Exit;
    end else begin
      Players.WriteConsole(taskToName(player[Victim.ID].task, false) + ' ' + Players[Victim.ID].Name + ' has been killed!', RED);
      SurvPwnMeter := SurvPwnMeter + 0.2;
      if SurvPwnMeter > 1.0 then SurvPwnMeter := 1.0;
    end;
  end else begin
    Players.WriteConsole(taskToName(player[Victim.ID].task, false)  + ' ' + Players[Victim.ID].Name + ' has been infected!', RED);
    SurvPwnMeter := (2.0+SurvPwnMeter)/3.0;
    if Modes.CurrentMode = 2 then
      if Player[Killer.ID].Status < 0 then Player[Killer.ID].Survkills := Player[Killer.ID].Survkills + 1;
    player[Victim.ID].bitten := true;
  end;
  WriteDebug(1, Players[Victim.ID].Name + ' killed');
  CheckNumPlayers := true;
  if Players_StatusNum(1) >= 1 then
  begin
    player[Victim.ID].SpecTimer := LSMap.DeathTimer;
    Player[Victim.ID].X := Victim.X;
    Player[Victim.ID].Y := Victim.Y;
    RayCast2(0, 15, 350, player[Victim.ID].X, player[Victim.ID].Y);
  end;
  if Medic.ID > 0 then
    TaskMedic_OnSurvivorDie(Victim.ID);

  if Modes.CurrentMode = 2 then
    if VersusRound = 1 then VSStats[7] := Victim.ID
    else VSStats[8] := Victim.ID;

  //|| Drop secondary weapon
  if WeaponSystem.Enabled then
    if Weapons_IsRegular(Victim.Secondary.WType) then
    begin
      Objects_Spawn(
        Victim.X - 10 * Victim.VelX + Victim.Direction*20,
        Victim.Y - 10 * Victim.VelY,
        weap2obj(Victim.Secondary.WType)
      );
    end;
end;

procedure OnPlayerKill_(Killer, Victim: TActivePlayer; BulletId: Byte);
begin
  TimeStats_Start('OnPlayerKill');
  if player[Victim.ID].Status > 0 then
    player[Victim.ID].Status := 2
  else if player[Victim.ID].Status < 0 then begin
    player[Victim.ID].Status := -2;
    player[Victim.ID].SpawnTimer := -1; // it will be set properly soon in InfectedDeath, just for now so he's not accidentally spawned
  end;
  Player[Victim.ID].JustResp := false;

  //Victim is a Zombie
  if Player[victim.ID].Zombie then OnZombieKill(Killer, Victim, BulletId)
  //Victim is a Survivor
  else OnSurvivorKill(Killer, Victim, BulletId);

  TimeStats_End('OnPlayerKill');
end;

procedure OnLeaveGame_(P: TActivePlayer; Kicked: Boolean);
var
  i: shortint;
  ID: byte;
begin
  ID := P.ID;
  GetMaxID();
  TimeStats_Start('OnLeaveGame');
  PerformProgressCheck := true;
  if Modes.CurrentMode <> 1 then begin 
    if player[ID].Status <> 0 then begin
      if Modes.CurrentMode = 2 then begin    
        if VersusRound = 1 then VSStats[7] := ID else VSStats[8] := ID;
        SlotInfoCountdown := 2;
      end;
    end;
  end;
  
  if ID = BurningRef then
  begin
    BurningRef := 0;
    for i := 1 to MaxID do
      if i <> ID then
      if Player[i].Zombie then
      if Player[i].Task = 4 then
      if Players[i].Alive then
        BurningRef := i;
  end;
    
  if player[ID].Status > 0 then begin
    if player[ID].task > 0 then begin
      Players.WriteConsole(TaskToName(player[ID].task, false)+' '+Players[ID].Name+' has left the battle', INFORMATION);
      player[ID].Participant := 0;
      if WeaponSystem.Enabled then begin
        BaseWeapons_Refresh(false);
      end;
      i := Length(MapRecord.Survival.GonePlayers);
      SetLength(MapRecord.Survival.GonePlayers, i + 1);
      MapRecord.Survival.GonePlayers[i].Name := Players[ID].Name;
      MapRecord.Survival.GonePlayers[i].Points := player[ID].Waves;

      if Medic.ID > 0 then
        TaskMedic_OnSurvivorLeaveGame(ID);
    end;
  end;
  
  Players_ClearX(ID);
  Players_ClearStats(ID);
  
  if ID = Strike.Owner then Strike_Reset();
  Fire_ClearByOwner(ID);
  Untask(ID, True);
      
  if Players[ID].Human then begin
    if player[ID].played then begin
      BlockPlayer(ID);
      player[ID].played := false;
    end;
    PlayerLeft := MapchangeStart;
    CheckNumPlayers := true;
    checkModeVote := true;
    if Players_StatusNum(1) = 0 then 
    begin
      if Game.Paused then Command('/unpause');
      PerformStartMatch := False;
    end;  
  end else begin
    Bosses_OnLeaveGame(P);
    if Players[ID].Dummy then begin
      if ID = scarecrow.ID then begin
        scarecrow.ID := 0;
        scarecrow.owner := 0;
      end else begin
        if not player[ID].kicked then Sentry_Clear(true);
      end;
    end; 
  end;
  player[ID].kicked := false;
  Hax_OnLeaveGame(ID);
  MapVotes_OnPlayerLeave(Players[ID]);
  for MaxID := MAX_UNITS downto 1 do
    if Players[MaxId].Active then break;
  TimeStats_End('OnLeaveGame');
end;

function OnVoteMap_(P: TActivePlayer; Map: string): boolean;
var vote: smallint;
begin
  vote := GetStringIndex(Map, MapList.List);
  if (vote >= 0) and (vote < MapList.Length) then
    MapVotes_OnVote(P.ID, vote);
  Result := true;
end;

procedure OnMapChange_(NewMap: string);
begin
  TimeStats_Start('OnMapChange');
  if {$IFDEF FPC}AZSS.{$ENDIF}AZSS.SpawnsMessed then begin
    WriteTmpFlag('spawnsmodified', '0');
    {$IFDEF FPC}AZSS.{$ENDIF}AZSS.SpawnsMessed := false;
  end;
  MapChange := true;
  if CurrentMap2 = '' then CurrentMap2 := NewMap;
  HackermanMode := (NewMap = 'ls_KernelPanic') or (NewMap = 'ls_dancingpigs');
  if GameRunning then EndGame();
  StartGame := false;
  StartGameCountdown := 0;
  LSMap.CurrentNum := GetStringIndex(NewMap, MapList.List);
  if MapchangeStart then begin
    MapchangeStart := false;
    PerformStartMatch := not PlayerLeft;
    PlayerLeft := false;
  end else PerformReset := true;
  if CurrentMap2 <> NewMap then CurrentMap2 := NewMap;
  TimeStats_End('OnMapChange');
end;

procedure OnKitPickup_(P: TActivePlayer; Kit: TActiveMapObject);
begin
  Kits_OnPickup(P, Kit);
end;

// -----------------------------------------------------------------------------

procedure RegisterEvents();
var i: byte;
begin
  for i := 1 to MAX_UNITS do begin
    Players[i].OnWeaponChange := @OnWeaponChange_;
    Players[i].OnDamage := @OnPlayerDamage_;
    Players[i].OnSpeak := @OnPlayerSpeak_;
    Players[i].OnCommand := @OnPlayerCommand_;
    Players[i].OnKill := @OnPlayerKill_;
    Players[i].OnVoteMapStart := @OnVoteMap_;
    Players[i].OnBeforeRespawn := @OnBeforeRespawn_;
    Players[i].OnAfterRespawn := @OnAfterRespawn_;
    Players[i].OnKitPickup := @OnKitPickup_;
    Players[i].OnFlagGrab := @OnFlagGrab_;
  end;
   Game.OnLeave := @OnLeaveGame_;
  Game.OnJoin := @OnJoinGame_;
  Game.OnClockTick := @OnTick_;
  Game.TickThreshold := 1;
  Game.OnAdminCommand := @OnCommand_;
  for i := 1 to 5 do begin
    Game.Teams[i].OnJoin := @OnJoinTeam_;
  end;
  //Map.OnBeforeMapChange := @OnMapChange_;
  Map.OnAfterMapChange := @OnAfterMapChange_;
end;

begin
  Players.WriteConsole('The Last Stand ' + S_VERSION + ', loading...', INFORMATION);

  RegisterEvents();
  
  if Game.TickCount > 60 then begin// if the script has been recompiled propably
    if ReadTmpFlag('spawnsmodified') = '1' then begin // if spawns on the map may be messed
      {$IFDEF FPC}AZSS.{$ENDIF}AZSS.SpawnsMessed := true;
      WriteDebug(10, 'Restarting map, spawns could have been modified');
      Command('/RESTART');
    end;

  end;

  // Init other modules
  WeaponMenu_Init(@Baseweapons_OnWeaponTake, 5);
  Fire_Initialise(@Fires_OnPlayerInFire);
  Mines_Initialise(0.4); // set mines sensitivity for 3 hz
  BigText_Init(DTL_CUSTOM, WTL_CUSTOM);
  MTInit(Random(1, $FFFFFF));
  
  
  PerformReset:=true;
  MapRecord.Path := Script.Dir + 'records/';
  TmpPath := Script.Dir + 'tmp/';
  
  Command('/UNPAUSE');
  if Command('/REALISTIC') = 1 then MAXHEALTH := 65 else MAXHEALTH := 150;
  
  if IC_MODULE_ENABLED then
    IC_Initialize();
  GetMaxID();

  {$IFNDEF FPC}
  WaveMessages := [
    'HERE THEY COME!',
    'Does this never end?',
    'The undead advance',
    'Their numbers seem limitless',
    'My god!',
    
    'Come to daddy!',
    'The dead rise again',
    'May god has mercy on our souls',
    'Hail to the King, baby',
    'This... is my BOOM STICK',

    'No brains and a big mouth', // 11
    'They''re coming for you! ',
    'Groovy.',
    'For God''s sake!',
    'How do you stop them?',
    
    'Got you, didn''t I?!',
    'Buckle up boneheads!',
    'Honey, you got reeal ugly! ',
    'Keep your filthy bones outta my mouth',
    'That''s it, go ahead and run',
    
    'Run home and cry to mama!', // 21
    'I''ll cut off your gizzard ',
    'Get offa me, ya crazy bitch!',
    'I got a bone to pick with you ',
    'Who wants some?',
    
    'Yo! She-bitch! Let''s go',
    'Now whoa right there spinach chin!',
    'Pick up a shovel and get digging!',
    'Surrounded by evil',
    'I''ll swallow your soul!',
    
    'We''ve been savaged', // 31
    'Groovy!',
    'What an excellent day for an exorcism',
    'Be afraid... Be very afraid',
    'The dead are not quiet',
    
    'Fresh meat',
    'It smells like a graveyard',
    'We all go a little mad sometimes',
    'I can smell your brains',
    'Freaky',
    
    'Zombies almost had my ass for dinner!', // 41
    'God has fled. Hell reigns. Darkness prevails',
    'Good... bad... I''m the guy with the gun',
    'That''s why you''re dead, asswipe.'+ br +'No brains and a big mouth!',
    'Stand back, boy! This calls for some divine intervention!',
    
    'Don''t you know what''s goin'' on out there?'+ br +'This is no Sunday School picnic!',
    'We may not enjoy living together,'+ br +'but dying together isn''t going to solve anything',
    'When there''s no more room in hell,'+ br +'the dead will walk the earth',
    'Well, that isn''t stopping them from walking around',
    'Don''t bury dead, first shoot in head',
    'Ha ha ha ha ha ha!'
  ];
  {$ENDIF}
  CurrentMap2 := Game.CurrentMap;
  Config_LoadLSSettings();
  Config_LoadNews();
  Modes_ApplyConfig();
  MapList_Load();
  MAXWAVEMESSAGES := Length(WaveMessages)-1;
  OnAfterMapChange_(Game.CurrentMap);
  WriteDebug(10, 'The Last Stand ' + S_VERSION);
  Players.WriteConsole('...complete', INFORMATION);
  TimeStats_End('ActivateServer');
end.
