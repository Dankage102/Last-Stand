//  * ------------- *
//  |    Bosses     |
//  * ------------- *

// This is a part of {LS} Last Stand.

unit bosses;

interface

uses
{$ifdef FPC}
  Scriptcore,
{$endif}
  Ballistic,
  BarbedWires,
  BaseWeapons,
  BotWizard,
  Bigtext,
  Charges,
  Constants,
  Damage,
  EarthQuake,
  GameModes,
  Globals,
  LSPlayers,
  maths,
  MersenneTwister,
   Landmines,
  Misc,
  Objects,
  PlacePlayer,
  Raycasts,
  Scarecrows,
  SentryGun,
  Spawner,
  Statguns,
  Tasks,
  Utils,
  WeaponMenu,
  Weapons,
  Zombies;

const
  
//Satan 2 const
  CircleRadius = 50; //Distance between player and circle bullets
  CircleAmount = 12; //Number of circle bullets
  ExplodeWarnings = 2; //How many times flame half-circle is created around satan before he explodes
  ExplodeAmount = 13; //Amount of bullets in explosion
  ExplodeStrength = 8; //V of explosion bullets
  RainWarnings = 4; //How many times sky is rendered before rain
  RainAmount = 40; //Amount of drops in rain
  ShowerStrength = 5;  //V of shower bullets
  ArrowWarnings = 2; //Time between bot chat or warning and arrow shot
  ShadowPhrase = 'Raise and serve me, Shadows.'; //What bot says while spawning shadows
  ArtPhrase = 'You can''t harm me anymore.'; //What bot says while spawning Artifact
  EndPhrase = 'Aaaaaaaarrrrrgh!'; //What bot says while dies
  ArtifactKillPhrase = 'NOOOOOOOOO!!!'; //What bot says while Artifact dies (fireworks begins)
  sdietimes = 3;//How many times hellsea is rendered after Satan's death
  S666_LIGRANGE  = 650;
  
// [The Undead Firefighter] (coded by The One)          
    
  FF_TrapMSG = 'The Undead Firefighter has spawned a Trap, don''t come near it!';
  FF_PortalMSG = 'The Undead Firefighter has spawned a Groundfire, don''t come near it!';

  FF_PORTALWARNINGS = 3;
  FF_Fading = 5;
  FF_TRAPWARNINGS = 3;

  FF_MSGColor = $00FF0000;  //Not all of them are in use
  FF_MSGColor2 = $0072A1D0;  //For human-FF
  FF_MSGColor3 = $006BB521;   //Health-status of FF in DrawText  

  FF_PORTALCOUNTER = 60;   //Needed for VS; Normally it's one-use, only
  FF_TRAPCOUNTER = 40;    //Restarts after the Trap is destroyed
  FF_HEATDMGMAX = 65;
  FF_HEATRANGE  = 150;

  PLAGUE_REVIVE_DISTANCE = 150;
var
  HaxID, ForcedPower: byte;
  
procedure DrawLine(X1, Y1, X2, Y2: single; N, Owner: byte; rc: boolean);

procedure Boss_IncreaseTempInputFactor(x: single);
 
procedure BlackScreen(ID: byte);
 
procedure ProcessPlagueMinions();

procedure PlagueOnMinionDamage(ID: byte; Damage: single; weap: byte; Damage_Type: TDamageType);

procedure PlagueOnFlagGrab(ID: byte);

procedure PlagueOnMinionKill(ID: byte);

procedure PlagueOnMinionRespawn(ID: byte);

procedure PlagueSpawnMinion(var Pwr: tPower);

procedure PlagueRevive(var Pwr: tPower);

procedure PlagueDeath(ID: byte);

function PowerNumToName(PwID: byte): string;

procedure ProcessPower(PwID, Shooter, Victim, slot: byte);

procedure ProcessIntro();

function BossName(bID: byte): string;

function CheckCollision(Power: byte): byte;

procedure CastSpell(SpellID, Shooter, Victim, slot: byte);

procedure DrawDebugInterface();

procedure ProcessBosses(DoBrain: boolean);

procedure ResetPower(var Pwr: tPower);

procedure ResetBoss();

procedure Steal(t: byte);

procedure Bosses_OnZombieKill(Killer, Victim: TActivePlayer; BulletID: byte);

procedure Bosses_OnLeaveGame(P: TActivePlayer);

implementation

procedure Steal(t: byte);
var j: integer; verb: string;
begin
  verb := iif(HackermanMode, 'hacked ', 'stolen ');
  case player[t].task of
    1, 4: if player[t].mre > 0 then begin
      player[t].mre := player[t].mre - 1;
      WriteConsole(0, 'Zombie has ' + verb + 'a meal ready to eat from the ' + taskToName(player[t].task, false), RED);
    end;
    2: if player[t].Mines >= 2 then begin
      j := RandInt(1,2);
      player[t].Mines := player[t].Mines - j;
      WriteConsole(0, 'Zombie has ' + verb + iif(j = 1, 'a mine', '2 mines') + ' from the demolition expert', RED);
    end else if player[t].charges > 0 then begin
      player[t].charges := player[t].charges - 1;
      WriteConsole(0, 'Zombie has ' + verb + 'a charge from the demolition expert', RED);
    end;
    5: if player[t].molotovs > 0 then begin
      player[t].molotovs := player[t].molotovs - 1;
      WriteConsole(0, 'Zombie has ' + verb + 'a molotov from the sharpshooter', RED);
    end;
    6: if Cop.SupplyPoints >= 3 then begin
      j := Trunc(Cop.SupplyPoints) div 3;
      if j > 10 then j := 10;
      Cop.SupplyPoints := Cop.SupplyPoints - j;
      WriteConsole(0, 'Zombie has ' + verb + IntToStr(j) + ' supply points from the police officer', RED);
    end;
    7: if player[t].holyWater >= 100 then begin
      j := ToRangeI(0, ToRangeI(RandInt(50, 60), player[t].holywater div 2, RandInt(50, 160)), player[t].holyWater - 30);
      player[t].holyWater := player[t].holyWater - j;
      WriteConsole(0, 'Zombie has ' + verb + IntToStr(j) + ' ml of holy water from the priest', RED);
    end;
  end;
end;

procedure ResetPower(var Pwr: tPower);
begin
  Pwr.Progress := 0;
  Pwr.Victim := 0;
  Pwr.X := 0;
  Pwr.Y := 0;
  SetLength(Pwr.Spawns, 0);
  ForcedPower := 0;
  HaxID := 0;
  if ForcedPower > 0 then begin
    Pwr.InUse := 0;
    Pwr.CountDown := 0;
  end else begin
    if (Boss.ID > 0) then
    if (Players[Boss.ID].Human) then begin
      case Pwr.InUse of
        0: exit;
        51: Pwr.CountDown := 5; //Altar
        61: Pwr.CountDown := 12; //Heat
        62: Pwr.CountDown := 25; //Portal
        63: Pwr.CountDown := 15; //Trap
        //Satan 1
        71: Pwr.CountDown := 35; //Summon Minions
        72: Pwr.CountDown := 25; //Paralyse
        73: Pwr.CountDown := 20; //Pentagram of Death
        74: Pwr.CountDown := 10; //Lighting
        //Satan 2
        81: Pwr.CountDown := 20; //Ring of Death
        82: Pwr.CountDown := 15; //Hell Rain
        83: Pwr.CountDown := 10; //Explosion
        84: Pwr.CountDown := 5; //Hell Shower
        85: Pwr.CountDown := 10; //Deadly Arrow
        86: Pwr.CountDown := 5; //Shadows
        87: Pwr.CountDown := 5; //Living Artifact
        88: Pwr.CountDown := 5; //Fireworks
        91: Pwr.CountDown := 1;
        92: Pwr.CountDown := 4;
        else Pwr.CountDown := 0; 
      end;
    end else begin
      case Pwr.InUse of
        0: exit;
        51: Pwr.CountDown := 5; //Altar
        61: Pwr.CountDown := 6; //Heat
        62: Pwr.CountDown := 15; //Portal
        63: Pwr.CountDown := 10; //Trap
        //Satan 1
        71: Pwr.CountDown := 35; //Summon Minions
        72: Pwr.CountDown := 25; //Paralyse
        73: Pwr.CountDown := 15; //Pentagram of Death
        74: Pwr.CountDown := 10; //Lighting
        //Satan 2
        81: Pwr.CountDown := 10; //Ring of Death
        82: Pwr.CountDown := 8; //Hell Rain
        83: Pwr.CountDown := 7; //Explosion
        84: Pwr.CountDown := 3; //Hell Shower
        85: Pwr.CountDown := 5; //Deadly Arrow
        86: Pwr.CountDown := 5; //Shadows
        87: Pwr.CountDown := 5; //Living Artifact
        88: Pwr.CountDown := 5; //Fireworks
        91: Pwr.CountDown := 1;
        92: Pwr.CountDown := 2;
        else Pwr.CountDown := 0; 
      end;
    end;
  end;
end;

procedure ResetBoss();
var
  i: byte;
begin
  Game.Gravity := DEFAULTGRAVITY;
  ServerModifier('Gravity', Game.Gravity);
  for i := 0 to MAX_POWERS do begin
    if Boss.Power[i].InUse = 72 then begin
      if Boss.Power[i].Victim > 0 then begin
        WeaponMenu_RefreshAll(Boss.Power[i].Victim);
        player[Boss.Power[i].Victim].Frozen := false;
      end;
    end;
    Boss.Power[i].InUse := 0;
    ResetPower(Boss.Power[i]);
  end;
    case Boss.bID of
        6: begin
              for i := 1 to FF_MAXTRAPS do
                if Firefighter.Trap[i].ID > 0 then begin
                  Players[Firefighter.Trap[i].ID].Kick(TKickSilent);
                  Firefighter.Trap[i].ID := 0;
                  Firefighter.Trap[i].InProgress := false;
                end;
              Firefighter.Trail.X := 0;
              Firefighter.Trail.Y := 0;
              Firefighter.TrapSlot := 0;
              for i := 1 to Firefighter.ActiveHeatItems do
                Firefighter.ScheduledHeatItem[i].CountdownTicks := 0;
              Firefighter.ActiveHeatItems := 0;
           end;
        7,8: begin
              Satan.ArtifactID := 0;
              Satan.DoFireworks := false;
              Satan.Shadows := false;
              Satan.Artifact := false;
              SetLength(Satan.Minions, 0);
              Game.Gravity := DEFAULTGRAVITY;
              Game.Gravity := DEFAULTGRAVITY;
           end;
        9: begin
              for i := 1 to MAX_UNITS do begin
                Plague.Minions[i].ID := 0;
                Plague.Minions[i].X := 0;
                Plague.Minions[i].Y := 0;
                Plague.Minions[i].dead := false;
                Plague.Minions[i].blown := false;
              end;
              Plague.ID := 0;
              Plague.MinionTimer := 2;
              Plague.MinionCounter := 0;
              Plague.MinionLimit := 0;
              Plague.MinionStorage := 0;
           end;
    end;
  Boss.ID := 0;
  Boss.bID := 0;
  Boss.PwID := 0;
  Boss.Intro := 0;
  Boss.Outro := false;
  Boss.CountDown := 0;
  Boss.TempDmgInputFactor := 1;
  zomPriest := 0; Butcher := 0;
end;

procedure DrawLine(X1, Y1, X2, Y2: single; N, Owner: byte; rc: boolean);
var
  i: byte;
  dx, dy, x, y: single;
begin
  dx:= X2 - X1;
  dy:= Y2 - Y1;
  dx:= dx / (N-1);
  dy:= dy / (N-1);
  x:= X1;
  y:= Y1;
  for i:= 1 to N do begin
    if rc then begin
      if PointNotInPoly(x, y, false, false, false) then CreateBulletX(x, y, 0, 0, 0, 5, Owner);
    end else CreateBulletX(x, y, 0, 0, 0, 5, Owner);
    x:= x + dx;
    y:= y + dy;
  end;
end;

procedure Boss_IncreaseTempInputFactor(x: single);
begin
  Boss.TempDmgInputFactor := Boss.TempDmgInputFactor + x;
  if Boss.TempDmgInputFactor > 1.3 then Boss.TempDmgInputFactor := 1.3 else
  if Boss.TempDmgInputFactor < 0.7 then Boss.TempDmgInputFactor := 0.7;
end;

const
  ParalyseTime = 5;
  SatanDeathStrength = 8;
  SummonMinionsBots = 6;
  //SummonMinionsLifetime = 10;
  SummonMinionsRadius = 100;
  S1_MAX_CAST_TIME = 7 * 60;

procedure SatanDeath();
var
  i, k: byte;
  j: shortint;
  X, Y, X2, Y2, dx, dy, sine, cosine: single;
  vec: tTVector;
begin
  if Boss.Intro = 0 then begin
    SetLength(Satan.Minions, SummonMinionsBots);
    GetPlayerXY(Boss.ID, Boss.Power[0].X, Boss.Power[0].Y);
    for i := 0 to SummonMinionsBots-1 do begin
      sine := sin(pi*i/SummonMinionsBots);
      cosine := cos(pi*i/SummonMinionsBots);
      j := RandInt(-3, 3);
      vec.vx := -(SatanDeathStrength+j)*cosine;
      vec.vy := -(SatanDeathStrength+j)*sine;
      vec.t := S1_MAX_CAST_TIME;
      Boss.Intro := 0;
      Boss.Outro := true;
      X2 := Boss.Power[0].X - 50*cosine;
      Y2 := Boss.Power[0].Y - 50*sine;
      CreateBulletX(X2, Y2, vec.vx, vec.vy, -5, 4, Boss.ID);
      BallisticCast(X2, Y2, -G_BUL*Game.Gravity/DEFAULTGRAVITY, vec, true, true);
      if Trunc(vec.t/60)+1 > Boss.Intro then
        Boss.Intro := Trunc(vec.t/60)+1;
      Satan.Minions[i].time := S1_MAX_CAST_TIME - vec.t + Timer.Value;
      X := vec.x + iif(vec.vx > 0, -5, 5);
      Y := vec.y + iif(vec.vy > 0, -10, 10);
      if not RayCast(X, Y, X, Y-16.0, true, false, false) then begin
        for k := 1 to 20 do begin
          dx := RandFlt(-20, 20);
          dy := RandFlt(-20, 20);
          if RayCast(X+dx, Y+dy, X+dx, Y+dy-16.0, true, false, false) then begin
             X := X + dx;
             Y := Y + dy;
             break;
          end;
        end;
      end;
      Satan.Minions[i].X := X;
      Satan.Minions[i].Y := Y;
    end;
  end else begin
    Boss.Intro := Boss.Intro - 1;
    for i := 0 to SummonMinionsBots-1 do begin
      if not Satan.Minions[i].spawned then
        if Timer.Value >= Satan.Minions[i].time then begin
          Satan.Minions[i].spawned := true;
          Zombies_SpawnOne(Spawn.Wave[Spawn.LastWave].ZombieHp * 0.0015, Spawn.Wave[Spawn.LastWave].ZombieDmg * 0.005, 0, 71, Satan.Minions[i].X, Satan.Minions[i].Y-10, true, 0);
          //Zombies_SpawnOne(Spawn.Wave[Spawn.LastWave].ZombieHp * 0.0015, Spawn.Wave[Spawn.LastWave].ZombieDmg * 0.005, 255, 0, 71, Boss.Power[0].X, Boss.Power[0].Y-10, true);
        end;
    end;
    if Boss.Intro = 0 then begin
      if (player[Boss.ID].Participant = 0) and (not Players[Boss.ID].Human) then begin
        player[Boss.ID].kicked := true;
        Players[Boss.ID].Kick(TKickSilent);
      end else if Modes.CurrentMode > 1 then
        InfectedDeath(Boss.ID);
      ResetBoss();
    end;
  end;
  {GetPlayerXy(Boss.ID, Satan.MinionX, Satan.MinionY);
  for i:= 1 to MaxID do
    if Players[i].Alive then
      if player[i].Status = 1 then begin
        GetPlayerXY(i, X, Y);
        if RayCast(Satan.MinionX, Satan.MinionY, X, Y-10, d, SatanDeathRange) then begin
          d:= Distance(Satan.MinionX, Satan.MinionY, X, Y);
          d:= 1 - d/SatanDeathRange;
          Damage_DoAbsolute(i, Boss.ID, Round(SatanDeathDmg* d*player[i].Health));
        end;
      end;
  nova_2(Satan.MinionX, Satan.MinionY, 0, 0, 0, SatanDeathNovaSpeed, 0, ANG_2PI, 0, SatanDeathNovaBullets, 14, Boss.ID);
  ApplyWeapons(Boss.ID, false);
  Spawn_AddZombies(SummonMinionsBots, 71);}
end;
 
procedure BlackScreen(ID: byte);
begin
if HackermanMode then begin
  BigText_DrawScreenX(DTL_BLACKOUT,ID,'XXX',160,$0000fe,46,-3920,-4260);
end else begin
  BigText_DrawScreenX(DTL_BLACKOUT,ID,'XXX',160,$000000,46,-3920,-4260);
end
end;
 
procedure Paralyse(ID: byte; var Pwr: tPower);
var i, z: byte; x, y: single; G, H: single;
begin
  if Timer.Cycle <> 1 then exit; //1hz power
  if Pwr.Progress = 0 then begin
    if player[ID].Status = 1 then begin
      BlackScreen(ID);
      Boss_IncreaseTempInputFactor(0.15);
      WriteConsole(0, Players[ID].Name + ' has been paralysed by Satan', RED);
      
      H := Players[ID].Health;
      G := Players[ID].Vest;
      z := Players[ID].Grenades;
      Pwr.Var1 := Players[ID].Primary.WType;
      Pwr.Var2 := Players[ID].Secondary.WType;
      if (not Weapons_IsInMenu(Pwr.Var1)) and (not Weapons_IsInMenu(Pwr.Var2)) then Pwr.Var1 := WTYPE_USSOCOM;
      
      Weapons_Force(ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
    
      GetPlayerXY(ID, x, y);
      PutPlayer(ID, HUMANTEAM, x, y, true);
      
      if z > 0 then 
        if Player[ID].Task <> 2 then GiveBonus(ID, 4)
        else GiveBonus(ID, 5);
      Damage_SetHealth(ID, H, G);  
          
      player[ID].GetX := true;
      if WeaponSystem.Enabled then begin
        BaseWeapons_RefreshActive();
      end;
      player[ID].JustResp := true;
      player[ID].Frozen := true;
      Pwr.Progress := ParalyseTime;
      for i := 1 to 14 do begin
        WeaponMenu_SwitchWeapon(ID, i, false);
      end;
    end else
      ResetPower(Pwr);
  end else begin
    Pwr.Progress := Pwr.Progress - 1;
    if Pwr.Progress = 0 then begin
      for i := 1 to 14 do begin
        z := menu2weap(i);
        if (z = Pwr.Var1) or (z = Pwr.Var2) then begin
          WeaponMenu_SwitchWeapon(ID, i, true);
        end else begin
          WeaponMenu_SwitchWeapon(ID, i, false);
        end;
      end;
      player[ID].Frozen := false;
      WriteConsole(ID, 'Paralysis fades', GREEN);
      ResetPower(Pwr);
    end;
  end;
end;

const
  PentagramRange = 250;
  PentagramBulletStep = 30;
  PentagramSleep = 30;
  ConstA = 1.256;
  ConstB = 1.571;

var
  PentagramData: record
    bulletAmount, range: word;
  end;

procedure Pentagram(Shooter, Victim: byte; var Pwr: tPower);
var
  i: word;
begin
  //15Hz power, bitches!
  if Pwr.Progress = 0 then begin
    
    PentagramData.range := PentagramRange;
    if player[Shooter].Status = -1 then begin
      PentagramData.range := PentagramData.range * 3 div 4;
    end;
    PentagramData.bulletAmount := Trunc(ANG_2PI*PentagramData.range/(PentagramBulletStep));
    Pwr.Progress := PentagramData.BulletAmount div 5+5+PentagramSleep;
    GetPlayerXY(Victim, Pwr.X, Pwr.Y);
  end else begin
    Pwr.Progress := Pwr.Progress - 1;
    if Pwr.Progress > 4+PentagramSleep then begin
      for i := 1 to 5 do begin
        CreateBulletX(Pwr.X+PentagramData.range*cos((ANG_2PI*(Pwr.Progress-4-PentagramSleep+i*PentagramData.bulletAmount/5))/PentagramData.bulletAmount-ANGLE_45),
                Pwr.Y+PentagramData.range*sin((ANG_2PI*(Pwr.Progress-4-PentagramSleep+i*PentagramData.bulletAmount/5))/PentagramData.bulletAmount-ANGLE_45),
                0, 0, 0, 5, Shooter);
      end;
    end else if Pwr.Progress <= 4 then begin
      DrawLine(cos(ConstB+ConstA*Pwr.Progress)*PentagramData.range+Pwr.X,
        sin(ConstB+ConstA*Pwr.Progress)*PentagramData.range+Pwr.Y,
        cos(ConstB+ConstA*((Pwr.Progress+2) mod 5))*PentagramData.range+Pwr.X,
        sin(ConstB+ConstA*((Pwr.Progress+2) mod 5))*PentagramData.range+Pwr.Y,
        Trunc(PentagramData.range*1.6/PentagramBulletStep),
        Shooter,
        true);
      if Pwr.Progress = 4 then begin
        for i := 1 to MaxID do 
          if Players[i].Alive then
            if not player[i].zombie then
              if IsInRange(i, Pwr.X, Pwr.Y, PentagramData.range * 3 div 4, false) then begin
                if i = Sentry.ID then Sentry_Clear(true)
                else if Players[i].Dummy then Scarecrow_Kaboom()
                else begin
                  if player[Shooter].Status = 0 then
                    BW_RandZombChat(Shooter, BW_SatanTauntsPenta, 1.0);
                  Damage_DoAbsolute(i, Shooter, 6666);
                end;
              end;
      end else if Pwr.Progress = 0 then
        ResetPower(Pwr);
    end;
  end;
end;
 
procedure SummonSpawns(Victim: byte; var Pwr: tPower);
var
  c, sine, cosine: single;
  i, k: byte;
  j: shortint;
begin
  c:= SummonMinionsRadius / 10;
  k:= SummonMinionsRadius div 10;
  GetPlayerXY(Victim, Pwr.X, Pwr.Y);
  Boss_IncreaseTempInputFactor(0.2);
  for i:= 1 to SummonMinionsBots do begin
    sine := sin(ANG_2PI*i/SummonMinionsBots);
    cosine := cos(ANG_2PI*i/SummonMinionsBots);
    for j:= k downto 0 do
      if RayCast(cosine*c*j+Pwr.X, sine*c*j+Pwr.Y, Pwr.X, Pwr.Y, true, false, false) or (j = 0) then begin
        Zombies_SpawnOne(Spawn.Wave[Spawn.LastWave].ZombieHp * 0.0015, Spawn.Wave[Spawn.LastWave].ZombieDmg * 0.005, 0, 71, cosine*c*j+Pwr.X, sine*c*j+Pwr.Y, true, 0);
        break;
      end;
  end;
  BW_RandZombChat(Boss.ID, BW_SatanTauntsMinions, 0.5);
  ResetPower(Pwr);
end;
 
function Lighting(T, ID: byte; var Pwr: tPower): boolean;
var x, y, x2, y2: single; i, j: byte;
begin
  if (Timer.Cycle <> 1) and (Timer.Cycle <> 33) then exit; //2hz power
  if Pwr.Progress = 0 then begin
    Pwr.Progress := 2;
    x := Players[i].X;
    y := Players[i].Y;
    DrawLine(x-20, y-20, x+20, y+20, 5, ID, false);
    DrawLine(x+20, y-20, x-20, y+20, 5, ID, false);
    BW_RandZombCHat(ID, BW_SatanTauntsLightning, 0.5);
  end else begin
    Pwr.Progress := Pwr.Progress - 1;
    if (Pwr.Progress = 0) or (Pwr.Progress = 1) then
      for i := 1 to MaxID do begin
        if (Player[i].Status <> 1) or (not Players[i].Alive) then continue;
        if IsInRange (i, Players[t].X, Players[t].Y, S666_LigRange, false) then begin                     // checks if players are in range for the lightning flash.
          if HackermanMode then
          	BigText_DrawScreen(i,'XXX',50-Pwr.Progress*25, $0000fe,46,-3920,-4260)   // makes screen flash blue on haxmaps.
          else
           	BigText_DrawScreen(i,'XXX',40-Pwr.Progress*25, $FFFFFF,46,-3920,-4260);   // makes screen flash white when lightning strikes.
        end;
      end;
      if Pwr.Progress = 0 then begin
        ResetPower(Pwr);
        GetPlayerXY(T, x, y);
        y := y - 200;
        for i := 0 to 4 do begin
          x := x + RandInt(-100, 100);
          if RayCast(x, y, x, y, true, false, false) then begin
            Result := true;
            x2 := x; y2 := y;
            for j := 0 to 6 do begin
              y := y + 50;
              x := x - 30 + RandInt(0, 60);
              DrawLine(X2, Y2, X, Y, 4, ID, false);
              if RayCast(x2, y2, x, y, true, false, false) then begin
                y2 := y;
                x2 := x;
              end else begin
                RayCast2((x-x2)/5, (y-y2)/5, 100, x2, y2);
                CreateBulletX(x2, y2, 0, 2, 5, 4, ID);
                exit;
              end;
            end;
            break;
          end;
        end;
      end;
end;
end;

{procedure MeteorStorm(Victim, ID: byte);
var
  i: byte;
  X, Y, dist: single;
begin
  if Boss.Power.Progress = 0 then
    Boss.Power.Progress := StormTime
  else begin
    Boss.Power.Progress := Boss.Power.Progress -1
    DrawLine(Boss.Power.X - 50, Boss.Power.Y - 200, Boss.Power.X + 50, Boss.Power.Y - 100, 15, ID, true);
    if Boss.Power.Progress = 0 then begin
      for i := 1 to StormBullets do
        X := Boss.Power.X - 50 + i*(200/StormBullets) + RandInt(-10, 10)
        Y := Boss.Power.Y - 50 - i*(200/StormBullets) - RandInt(-10, 10)
        if RayCast(X, Y, X, Y, dist, 1) then CreateBulletX(X, Y, RandFlt(-3, -1), -2, 100, 4, ID);
      ResetPower(74);
    end;
  end;
end;}

//***************************
// [Satan II] (by Falcon)

{
procedure ExamplePower();
begin
  if Boss.Power.Progress = 0 then
    Boss.Power.Progress := Time
    //OnBegin
  else begin
    Boss.Power.Progress := Boss.Power.Progress -1
    //OnCouhtDown
    if Boss.Power.Progress = 0 then begin
      //OnActivate
      ResetPower(1234);
    end;
  end;
end;
}

procedure BulletCircle(Victim, Shooter: byte; var Pwr: tPower);
var
  sine, cosine: single;
begin
  if (Timer.Cycle <> 1) and (Timer.Cycle <> 33) then exit; //2Hz power
  if Pwr.Progress = 0 then begin
    Pwr.Progress := CircleAmount;
    WriteConsole(0, Players[Victim].Name + ' has been caught by Satan!', RED);
    //BigText_DrawScreenX(DTL_ZOMBIE_UI, Victim, 'XXX', 300,0,30,-3500,-2000)
    Game.Gravity := 0;
    ServerModifier('Gravity',Game.Gravity); // packet loss
    ServerModifier('Gravity',Game.Gravity);
    GetPlayerXY(Victim, Pwr.X, Pwr.Y);
    if player[Victim].Status = 1 then PutPlayer(Victim, HUMANTEAM, Pwr.X, Pwr.Y, false);
  end else begin
    repeat 
      sine := sin(2*pi*Pwr.Progress/CircleAmount);
      cosine := cos(2*pi*Pwr.Progress/CircleAmount);
      Pwr.Progress := Pwr.Progress - 1;
      if RayCast(Pwr.X, Pwr.Y, Pwr.X - CircleRadius*cosine, Pwr.Y - CircleRadius*sine, false, true, true) then begin
        CreateBulletX(Pwr.X - CircleRadius*cosine, Pwr.Y - CircleRadius*sine , 0, 0, -1, 4, Shooter);
        break;
      end;
    until Pwr.Progress = 0;
    if Pwr.Progress = 0 then begin
      Game.Gravity := DEFAULTGRAVITY;
      ServerModifier('Gravity', Game.Gravity); // packet loss
      ServerModifier('Gravity', Game.Gravity);
      ResetPower(Pwr);
    end;
  end;
end;

procedure KaBoom(ID: byte; var Pwr: tPower);
var
  sine, cosine: single;
  i, j, s: shortint;
begin
  if Timer.Cycle <> 1 then exit; //1hz power
  if Pwr.Progress = 0 then begin
    Pwr.Progress := ExplodeWarnings;
    BW_RandZombChat(ID, BW_SatanTauntsExplosion, 1.0);
  end else begin
    Pwr.Progress := Pwr.Progress - 1;
    GetPlayerXY(ID, Pwr.X, Pwr.Y);
    for i := 0 to ExplodeAmount do begin
      sine := sin(pi*i/ExplodeAmount);
      cosine := cos(pi*i/ExplodeAmount);
      if RayCast(Pwr.X + 50*sine, Pwr.Y + 50*cosine, Pwr.X + 50*sine, Pwr.Y + 50*cosine, false, true, true) then
        CreateBulletX(Pwr.X + RandFlt(25, 35)*sine, Pwr.Y + RandFlt(25, 35)*cosine, RandFlt(-1, 1), RandFlt(-1, 1), 0, 5, ID);
    end;
    if Pwr.Progress = 0 then begin
      for i := 0 to ExplodeAmount do begin
        sine := sin(pi*i/ExplodeAmount);
        cosine := cos(pi*i/ExplodeAmount);
        j := RandInt(-3, 3);
        if RayCast(Pwr.X - 50*cosine, Pwr.Y - 50*sine, Pwr.X - 60*cosine, Pwr.Y - 60*sine, false, true, true) then begin
          if i mod 2 = 0 then s := 4 else s := 8;
          CreateBulletX(Pwr.X - 50*cosine, Pwr.Y -50*sine, -(ExplodeStrength+j)*cosine, -(ExplodeStrength+j)*sine, -5, s, ID);
        end;
      end;
      ResetPower(Pwr);
    end;
  end;
end;

procedure Cloud(X, Y: single);
begin
end;

procedure HellRain(Victim, Shooter: byte; var Pwr: tPower);
var
  x, y: single;
  i: word;
  j: smallint;
begin
  if Pwr.Progress = 0 then begin
    i := 0;
    SetLength(Pwr.Spawns, 0);
    GetPlayerXY(Victim, Pwr.X, Pwr.Y);
    while i <= 400 do begin
      if RayCast(Pwr.X+i-200, Pwr.Y - 350, Pwr.X+i-200, Pwr.Y - 360, false, true, true) then begin
        SetLength(Pwr.Spawns, Length(Pwr.Spawns)+1);
        Pwr.Spawns[Length(Pwr.Spawns)-1] := i;
      end;
      i := i + 10;
    end;
    if Length(Pwr.Spawns) = 0 then begin
      ResetPower(Pwr);
      exit;
    end;
    Pwr.Progress := RainWarnings*5+RainAmount;
    BW_RandZombChat(Shooter, BW_SatanTauntsHellrain, 1.0);
    Boss_IncreaseTempInputFactor(0.1);
    GetPlayerXY(Victim, Pwr.X, Pwr.Y);
  end else begin
    if Timer.Cycle mod 12 <> 1 then exit;
    Pwr.Progress := Pwr.Progress - 1;
    if Pwr.Progress > RainAmount then begin
      i := RandInt(0, Length(Pwr.Spawns)-1);
      j := RandInt(20, 40);
      x := Pwr.X+Pwr.Spawns[i]-RandInt(190,210);
      y := Pwr.Y - RandInt(330, 350);
      BigText_DrawMap(0, '*', 55, RGB(j, j, j), RandFlt(0.5, 1.0), trunc(X), trunc(Y-100));
      CreateBulletX(x, y, RandFlt(-1, 1), RandFlt(-1, 1), 0, 5, Shooter);
    end else if Pwr.Progress > 0 then begin
      if Timer.Cycle mod 12 <> 1 then exit;
      x := Pwr.X-200+Pwr.Spawns[RandInt(0, Length(Pwr.Spawns)-1)];
      y := RandFlt(300, 400);
      j := RandInt(20, 40);
      BigText_DrawMap(0, '*', 55, RGB(j, j, j), RandFlt(0.5, 1.0), trunc(X), trunc(Pwr.Y - y));
      BigText_DrawMap(0, '*', 55, RGB(j, j, j), RandFlt(0.5, 1.0), trunc(X+RandFlt(-50, 50)), trunc(Pwr.Y - y));
      CreateBulletX(x+10, Pwr.Y - y, 0, 0, -100, 8, Shooter);
    end else begin
      ResetPower(Pwr);
      Exit;
    end;
  end;
end;

procedure HellShower(ID: byte; var Pwr: tPower);
var
  i, s: byte;
  a, tsin, tcos, x, y: single;
begin
  GetPlayerXY(ID, x, y);
  for i := 0 to 12 do begin
    a := RandFlt(ANGLE_30, ANGLE_90);
    tsin := sin(a);
    tcos := cos(a);
    if i mod 2 = 0 then s := 7 else s := 3;
    CreateBulletX(x - tcos*20, y - tsin*20, -tcos*ShowerStrength, -tsin*ShowerStrength, -100, s, ID);
    CreateBulletX(x + tcos*20, y - tsin*20, tcos*ShowerStrength, -tsin*ShowerStrength, -200, s, ID);
  end;
  ResetPower(Pwr);
end;

procedure CreateArtifact(var Pwr: tPower);
begin
  BotChat(Boss.ID, ArtPhrase);
  GetPlayerXY(Boss.ID, Pwr.X, Pwr.Y);
  Zombies_SpawnOne(Spawn.Wave[Spawn.LastWave].ZombieHp * 0.0025, Spawn.Wave[Spawn.LastWave].ZombieDmg * 0.005, 0, 81, Pwr.X, Pwr.Y, true, 0);
  ResetPower(Pwr);
end;

procedure CreateShadows(var Pwr: tPower);
var
  i: byte; x, y: single;
begin
  Satan.Shadows := true;
  BotChat(Boss.ID, ShadowPhrase);
  for i := 1 to MaxID do
    if player[i].Status = 1 then begin
      GetPlayerXY(i, x, y);
      Zombies_SpawnOne((Sqrt(NumberOfWave + 1)) * 10 * ZombieHpInc/100, (NumberOfWave+1)*ZombieDmgInc/100, i, 0, x, y, true, 0);
    end;
  Boss_IncreaseTempInputFactor(0.1);
  ResetPower(Pwr);
end;

const
  FireworksIteration = 3; //How many times script should repeat fireworks
  FireworksAmount = 12; //Amount of bullets each firework iteration fire
  FireworksStrength = 10; //V of firefowks bullets
  FireworksSleepTime = 10;
var
  FireworksData: record
    counter: byte;
    sleeping: boolean;
  end;

procedure Fireworks(ID: byte; var Pwr: tPower);
var
  j: byte;
  x, y: single;
  //ratio: double;
begin
  if Timer.Cycle mod 4 <> 1 then exit; //15hz power
  if Pwr.Progress = 0 then begin
    Pwr.Progress := FireworksIteration*FireworksAmount+(FireworksIteration-1)*FireworksSleepTime;
    FireworksData.counter := FireworksAmount;
    FireworksData.sleeping := false;
    BotChat(ID, ArtifactKillPhrase);
    {
    GetPlayerXY(Artifact, x, y);
    GetPlayerXY(Satan2, Pwr.X, Pwr.Y);
    y := y - 10;
    Pwr.Y := Pwr.Y - 10;
    while SqrDist(Pwr.X,Pwr.Y,x,y) > 100 do begin
      ratio := 10/Distance(Pwr.X,Pwr.Y,x,y);
      Pwr.X := Pwr.X-(ratio*(Pwr.X-x));
      Pwr.Y := Pwr.Y-(ratio*(Pwr.Y-y));
      CreateBulletX(Pwr.X, Pwr.Y, 0, 0, 0, 5, Satan2);
    end;
    if Satan.ArtifactID > 0 then begin
      player[Satan.ArtifactID].kicked := true;
      KickPlayer(Satan.ArtifactID);
      Satan.ArtifactID := 0;
    end;
    }
  end else begin
    Pwr.Progress := Pwr.Progress -1;
    FireworksData.counter := FireworksData.counter - 1;
    if FireworksData.counter = 0 then begin
      if FireworksData.sleeping then begin
        FireworksData.sleeping := false;
        FireworksData.counter := FireworksAmount;
      end else begin
        FireworksData.sleeping := true;
        FireworksData.counter := FireworksSleepTime;
      end;
    end;
    if not FireworksData.sleeping then begin
      GetPlayerXY(ID, Pwr.X, Pwr.Y);
      j := RandInt(60, 120);
      x := sin(j*pi/180);
      y := cos(j*pi/180);
      CreateBulletX(Pwr.X - y*20, Pwr.Y - x*20, -y*FireworksStrength, -x*FireworksStrength, 100, 4, ID);
    end;
    if Pwr.Progress = 0 then ResetPower(Pwr);
  end;
end;

procedure Arrow(Shooter, Victim: byte; var Pwr: tPower);
var
  ang, x, y, vel: single;
  b: boolean;
begin
  if Timer.Cycle <> 1 then exit; //1hz power
  if Pwr.Progress = 0 then begin
    Pwr.Progress := ArrowWarnings;
    BW_RandZombChat(Shooter, BW_SatanTauntsArrow, 1.0);
  end else begin
    Pwr.Progress := Pwr.Progress -1;
    if Pwr.Progress = 0 then begin
      GetPlayerXY(Shooter, Pwr.X, Pwr.Y);
      Pwr.Y := Pwr.Y - 10;
      Victim := lookForTarget2(Shooter, 50, 400, ANGLE_90, true, b);
      if Victim > 0 then begin
        GetPlayerXY(Victim, x, y);
        y := y - 10;
        vel := RandFlt(18, 20);
        //ang := BallisticAim(Pwr.X, Pwr.Y, x, y, vel, Game.Gravity, b);
        ang := BallisticAimX(Pwr.X, Pwr.Y, vel, players[Victim], b);
        if b then CreateBulletX(Pwr.X, Pwr.Y, vel*cos(ang) + Players[Victim].VELX,
        vel*sin(ang) + Players[Victim].VELY, 100, 8, Shooter);
      end;
      ResetPower(Pwr);
    end;
  end;
end;

procedure Satan2Death();
var
  i: byte;
  j: smallint;
begin
  if Boss.Intro = 0 then begin
    GetPlayerXY(Boss.ID, Boss.Power[0].X, Boss.Power[0].Y);
    SetTeam(5, Boss.ID, true);
    Boss.Outro := true;
    Boss.Intro := sdietimes;
    if player[Boss.ID].Status = 0 then BotChat(Boss.ID, EndPhrase);
    for i := 1 to MaxID do begin
      if Players[i].Alive then
        if player[i].Participant = 1 then Objects_SpawnX(i, 16, 1);
    end;
    WriteConsole(0, 'Satan has been thrown into the sea of flames. Heaven reigns!', $FF0000);
  end else begin
    Boss.Intro := Boss.Intro - 1;
    if Length(Boss.Power[0].Spawns) = 0 then begin
      i := 0;
      while i <= 250 do begin
        j := 0;
        if RayCast(Boss.Power[0].X + i - 125, Boss.Power[0].Y, Boss.Power[0].X + i - 125, Boss.Power[0].Y, false, true, true) then begin
          while RayCast(Boss.Power[0].X + i - 125, Boss.Power[0].Y + j, Boss.Power[0].X + i - 125, Boss.Power[0].Y + j, false, true, true) AND (j < 100) do
            j := j + 5;
          if j >= 100 then j := 0
          else j := j - 5;
        end else begin
          while not RayCast(Boss.Power[0].X + i - 125, Boss.Power[0].Y + j, Boss.Power[0].X + i - 125, Boss.Power[0].Y + j, false, true, true) AND (j > -100) do
            j := j - 5;
          if j <= -100 then j := 0
        end;
        //write good spawnpoint to array
        SetLength(Boss.Power[0].Spawns, Length(Boss.Power[0].Spawns)+1);
        Boss.Power[0].Spawns[Length(Boss.Power[0].Spawns)-1] := j;
        i := i + 5;
      end;
    end;
    for i := 0 to (Length(Boss.Power[0].Spawns)-1) do
      CreateBulletX(Boss.Power[0].X + (i * 5) - 125 + RandFlt(-5, 5), Boss.Power[0].Y+Boss.Power[0].Spawns[i] + RandFlt(-4, 4), 0, 0, 0, 5, Boss.ID);
    if Boss.Intro = 0 then begin
      //crucifix  
      CreateBulletX(Boss.Power[0].X, Boss.Power[0].Y - 30, 0, 0, 0, 5, Boss.ID);
      CreateBulletX(Boss.Power[0].X, Boss.Power[0].Y - 40, 0, 0, 0, 5, Boss.ID);
      CreateBulletX(Boss.Power[0].X, Boss.Power[0].Y - 50, 0, 0, 0, 5, Boss.ID);
      CreateBulletX(Boss.Power[0].X, Boss.Power[0].Y - 60, 0, 0, 0, 5, Boss.ID);
      CreateBulletX(Boss.Power[0].X - 10, Boss.Power[0].Y - 50, 0, 0, 0, 5, Boss.ID);
      CreateBulletX(Boss.Power[0].X + 10, Boss.Power[0].Y - 50, 0, 0, 0, 5, Boss.ID);
      //M2 circle
      for i := 0 to 11 do
        CreateBulletX(Boss.Power[0].X, Boss.Power[0].Y, 0 + (i * 10) - 50, -25, 0, 14, Boss.ID);        
      //reset procedure  
      if (player[Boss.ID].Participant = 0) and (not Players[Boss.ID].Human) then begin
        player[Boss.ID].kicked := true;
        Players[Boss.ID].Kick(TKickSilent);
      end else if Modes.CurrentMode > 1 then
        InfectedDeath(Boss.ID);
      player[Boss.ID].Zombie := false;
      ResetBoss();
    end;
  end;
end;

//The ID parameter is the one to place the Trap
procedure CreateTrap(ID: byte; var Pwr: tPower);
var x, y: single; t: byte;
begin
  if Timer.Cycle <> 1 then exit; //1hz power
  if Pwr.Progress = 0 then begin
    Pwr.Progress := FF_TRAPWARNINGS;
    GetPlayerXY(ID, x, y);
    BW_RandZombChat(ID, BW_FirefighterTauntsTrap, 0.5);
    t := Zombies_SpawnOne(50, 1, 0, 62, x, y, true, 0);
    if t > 0 then begin
      WriteConsole(0, FF_TrapMSG, $00FF0000);    //Gives out the Trap-Spawned-Message
      Firefighter.Trap[Firefighter.TrapSlot].ID := t;
    end;
  end else begin
    Pwr.Progress := Pwr.Progress - 1;
    if Pwr.Progress = 0 then begin
      Firefighter.Trap[Firefighter.TrapSlot].InProgress := true;
      ResetPower(Pwr);
    end;
  end;
end;

procedure ProcessTrap();
var
  a, n, i: integer;
  X, Y, X2, Y2: single;
begin
  if Timer.Cycle <> 1 then exit; //1hz power  
  for a := 1 to FF_MAXTRAPS do begin
    if Firefighter.Trap[a].ID > 0 then begin
      if not Firefighter.Trap[a].InProgress then continue;
      GetPlayerXY(Firefighter.Trap[a].ID, X, Y);
      for n := 1 to MaxID do
        if Players[n].Alive then
          if player[n].Zombie <> Player[Firefighter.Trap[a].ID].Zombie then begin
            GetPlayerXY(n, X2, Y2);
            if Y2 < Y + 100 then begin
              if (X2 + Players[n].VELX * 90 >= X) = (X2 >= X) then // if player with his velocity is not going to cross the trap then check the distance
                if Abs(X - X2) > 200 then continue; // if the distance is close then let it activate else check another player
              while RayCast(X, Y - 10, X, Y - (i*20) - 10, false, true, true) do begin
                //CreateBulletX(X, Y - (i * 25), 0, 0, 0, 5, Firefighter.Trap.ID);
                CreateBulletX(X, Y, RandFlt(-0.05, 0.05), -i-5, 400, 7, Firefighter.Trap[a].ID);
                CreateBulletX(X, Y, RandFlt(-0.05, 0.05), -i-5 - 1, 400, 3, Firefighter.Trap[a].ID);
                i := i + 2;
                if i >= 20 then break;
              end;
              for i := 1 to 10 do // spam
              begin
                CreateBulletX(X - 10, Y - RandInt(1, 10), -RandInt(1, 10)*0.1, -1, 100, 3, Firefighter.Trap[a].ID);
                CreateBulletX(X + 10, Y - RandInt(5, 10), RandInt(1, 10)*0.1, -1, 100, 3, Firefighter.Trap[a].ID);
              end;
              break;
            end;
          end;
    end;
  end;
end;

// If the Minions are supposed to be calculated with the lvl., 0 should be given as parameter
procedure CreatePortal(ID, Minions: byte; var Pwr: tPower);
var
  i: byte;
  x: single;
  y: single;
begin
  if Timer.Cycle <> 1 then exit; //1hz power
  if Pwr.Progress = 0 then begin
    BW_RandZombChat(ID, BW_FirefighterTauntsPortal, 0.8);
    GetPlayerXY(ID, Pwr.X, Pwr.Y);
    // * This code checks, if the ground is even enough, and writes the y-values into Pwr.Y+Pwr.Spawns
    //    If the ground isn't fine, it simply exits this procedure, that's why the process of Portal is started after this code
    SetLength(Pwr.Spawns, 19);
    for i := 0 to 18 do begin
      // * These are the "columns" of the Portal-Fire
      x := -75 + i * 8;
      y := 0.0;
      while not RayCast(Pwr.X + x, Pwr.Y - 50, Pwr.X + x, Pwr.Y + y, true, true, true) do begin
        y := y + 10.0;        //Raycasting, until no polygon stops this  
        if (y > 200.0) then break;
      end;
      Pwr.Spawns[i] := Round(y);      //If the place is fine, the Y-value is written into the array
    end;
    WriteConsole(0, FF_PortalMSG, $00FF0000);      //Gives out the FF_PortalMSG
    Pwr.Progress  := FF_PORTALWARNINGS + (Minions * 2) + 5;
    Boss_IncreaseTempInputFactor(0.2);
  end else begin
    Pwr.Progress := Pwr.Progress - 1;
    if Pwr.Progress > Minions*2 + 4 then
    begin
      CreateBulletX(Pwr.X + 5, Pwr.Y - 35, 0, -5, 0, 14, ID);
      CreateBulletX(Pwr.X - 5, Pwr.Y - 35, 0, -5, 0, 14, ID);
      CreateBulletX(Pwr.X - 30, Pwr.Y - 30, 0, -5, 0, 14, ID);
      CreateBulletX(Pwr.X + 30, Pwr.Y - 30, 0, -5, 0, 14, ID);
      CreateBulletX(Pwr.X - 50, Pwr.Y - 10, 0, -5, 0, 14, ID);
      CreateBulletX(Pwr.X + 50, Pwr.Y - 10, 0, -5, 0, 14, ID);
      CreateBulletX(Pwr.X + 70, Pwr.Y, 0, -5, 0, 14, ID);
      CreateBulletX(Pwr.X - 70, Pwr.Y, 0, -5, 0, 14, ID);
    end;

    if Pwr.Progress > 1 then
    begin
      CreateBulletX(Pwr.X, Pwr.Y+Pwr.Spawns[9], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 10, Pwr.Y+Pwr.Spawns[11], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 10, Pwr.Y+Pwr.Spawns[7], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 20, Pwr.Y+Pwr.Spawns[12], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 20, Pwr.Y+Pwr.Spawns[6], 0, 0, 0, 5, ID);
    end;

    if Pwr.Progress > 2 then
    begin
      CreateBulletX(Pwr.X + 30, Pwr.Y+Pwr.Spawns[14], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 30, Pwr.Y+Pwr.Spawns[4], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 40, Pwr.Y+Pwr.Spawns[15], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 40, Pwr.Y+Pwr.Spawns[3], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 50, Pwr.Y+Pwr.Spawns[16], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 50, Pwr.Y+Pwr.Spawns[2], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 60, Pwr.Y+Pwr.Spawns[17], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 60, Pwr.Y+Pwr.Spawns[1], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 70, Pwr.Y+Pwr.Spawns[18], 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 70, Pwr.Y+Pwr.Spawns[0], 0, 0, 0, 5, ID);
    end;

    if Pwr.Progress > 3 then
    begin  
      CreateBulletX(Pwr.X, Pwr.Y+Pwr.Spawns[9] - 10, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 13, Pwr.Y+Pwr.Spawns[10] - 10, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 13, Pwr.Y+Pwr.Spawns[8] - 10, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 26, Pwr.Y+Pwr.Spawns[13] - 10, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 26, Pwr.Y+Pwr.Spawns[5] - 10, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 39, Pwr.Y+Pwr.Spawns[15] - 10, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 39, Pwr.Y+Pwr.Spawns[3] - 10, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 52, Pwr.Y+Pwr.Spawns[16] - 10, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 52, Pwr.Y+Pwr.Spawns[2] - 10, 0, 0, 0, 5, ID);
    end;

    if Pwr.Progress > 4 then
    begin    
      CreateBulletX(Pwr.X + 8, Pwr.Y+Pwr.Spawns[11] - 22, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 8, Pwr.Y+Pwr.Spawns[7] - 22, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 24, Pwr.Y+Pwr.Spawns[13] - 22, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 24, Pwr.Y+Pwr.Spawns[5] - 22, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 40, Pwr.Y+Pwr.Spawns[15] - 22, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 40, Pwr.Y+Pwr.Spawns[3] - 22, 0, 0, 0, 5, ID);
    end;

    if Pwr.Progress > 5 then
    begin
      CreateBulletX(Pwr.X + 10, Pwr.Y+Pwr.Spawns[11] - 31, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 10, Pwr.Y+Pwr.Spawns[7] - 31, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 30, Pwr.Y+Pwr.Spawns[14] - 29, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 30, Pwr.Y+Pwr.Spawns[4] - 29, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X + 5, Pwr.Y+Pwr.Spawns[10] - 35, 0, 0, 0, 5, ID);
      CreateBulletX(Pwr.X - 5, Pwr.Y+Pwr.Spawns[8] - 35, 0, 0, 0, 5, ID);
    end;
    if (Pwr.Progress > FF_Fading) then
      if ((Pwr.Progress mod 2) = 0) then if Pwr.Progress < FF_PORTALWARNINGS + Minions * 2 then begin
        Zombies_SpawnOne(40, 3, 0, 61, Pwr.X, Pwr.Y, true, 0);
      end;
    for i := 1 to MaxID do
      if Players[i].Alive then
      if player[i].Status = 1 then
        if IsInRange(i, Pwr.X, Pwr.Y - 20, 40, false) then begin
        Damage_DoAbsolute(i, ID, 20);
      end;
    if Pwr.Progress = 0 then ResetPower(Pwr);
  end;
  // * Activating Portal
end;

procedure CheckForHeatItem(ItemType: byte; ItemID: byte; Range: single; var Pwr: tPower; ItemX, ItemY: single; velocity: single);
var dist: single;
  i: byte;
begin
  dist := SqrDist(Pwr.X, Pwr.Y, ItemX, ItemY);
  if dist > Range*Range then exit;
    dist := sqrt(dist);

  for i := 1 to FF_MAXHEATITEMS do
    if Firefighter.ScheduledHeatItem[i].CountdownTicks <= 0 then break;

  Firefighter.ScheduledHeatItem[i].ItemType := ItemType;
  Firefighter.ScheduledHeatItem[i].ItemID := ItemID;
  Firefighter.ScheduledHeatItem[i].ItemX := ItemX;
  Firefighter.ScheduledHeatItem[i].ItemY := ItemY;
  Firefighter.ScheduledHeatItem[i].CountdownTicks := round(dist / velocity);
  if ItemType = 0 then
    Firefighter.ScheduledHeatItem[i].Amount := FF_HEATDMGMAX * iif(dist < 20, 1, 1 - (dist-20)/Range) * iif(RayCast(Pwr.X, Pwr.Y, ItemX, ItemY, false, false, false), 1, 0.2);
  if i > Firefighter.ActiveHeatItems then Firefighter.ActiveHeatItems := i;
end;

procedure Heat_(ID: byte; var Pwr: tPower);
var
  time, inner_range_x, y_offset, inner_range_y, range, velocity, x, y, vx, vy: single;
  FAmount, i: word;
begin
  if Pwr.Progress = 0 then begin
    range := FF_HEATRANGE;
    inner_range_x := 12;
    inner_range_y := 20;
    y_offset := 0.25;
    time := 40;
    FAmount := 30 * round(range / 150);
    GetPlayerXY(ID, Pwr.X, Pwr.Y);
    for i := 1 to FAmount do begin
      x := sin(2*pi*i/FAmount);
      y := cos(2*pi*i/FAmount);
      vx := 1.5 * (range - inner_range_x) * x / time;
      vy := 1.5 * (range - inner_range_y) * (y + y_offset) / time;
      CreateBulletX(Pwr.X + inner_range_x * x * RandFlt(0.9, 1.1), Pwr.Y + inner_range_y * y  * RandFlt(0.9, 1.1), vx * RandFlt(0.9, 1.1), vy * RandFlt(0.9, 1.1), 0, 5, ID);
    end;
    PlaySound(i, 'onfire.wav', Pwr.X, Pwr.Y);
    velocity := range / time;

    //Targets of heat
    for i := 1 to MaxId do
    if (Players[i].Alive) and (player[i].Status = 1) then begin
      GetPlayerXY(i, x, y);
      CheckForHeatItem(0, i, Range, Pwr, x, y, velocity);
    end;
    for i := 1 to MAX_WIRES do
        if wire[i].Active then
            CheckForHeatItem(1, i, Range, Pwr, (wire[i].bundle[0].x + wire[i].bundle[1].x)/2, (wire[i].bundle[0].y + wire[i].bundle[1].y)/2, velocity);
    for i := 1 to (SG.Num - 1) do
    CheckForHeatItem(2, i, Range, Pwr, statgun[i].X, statgun[i].Y, velocity);
    for i := 1 to Mines.MaxMineID do
        if Mines.Mine[i].placed then
      CheckForHeatItem(3, i, Range, Pwr, Mines.Mine[i].X, Mines.Mine[i].Y, velocity);
    for i := 0 to Charges_MaxID do
        if charge[i].placed then
            CheckForHeatItem(4, i, Range, Pwr, charge[i].X, charge[i].Y, velocity);
    if scarecrow.ID > 0 then begin
        GetPlayerXY(scarecrow.ID, x, y);
        CheckForHeatItem(5, i, Range, Pwr, x, y, velocity);
    end;
    if Sentry.Active then begin
        GetPlayerXY(Sentry.ID, x, y);
        CheckForHeatItem(6, Sentry.ID, Range, Pwr, x, y, velocity);
    end;
    Pwr.Progress := 1;
  end else begin
      if (Timer.Cycle - 1) mod 8 <> 0 then exit;
      for i := 1 to Firefighter.ActiveHeatItems do begin
        if Firefighter.ScheduledHeatItem[i].CountdownTicks > 0 then begin
            Firefighter.ScheduledHeatItem[i].CountdownTicks := Firefighter.ScheduledHeatItem[i].CountdownTicks - 8;
                ID := Firefighter.ScheduledHeatItem[i].ItemID;
                if Firefighter.ScheduledHeatItem[i].CountdownTicks <= 0 then begin
                  case Firefighter.ScheduledHeatItem[i].ItemType of
                    0:  //Players
                        begin
                          GetPlayerXY(ID, x, y);
                          PlaySound(ID, 'firecrack.wav', x, y);
                          Damage_DoRelative(ID, Boss.ID, Firefighter.ScheduledHeatItem[i].Amount, Heat);
                          //TODO Screen Overlay
                        end;
                        1:  //Wires
                        begin
                          CreateBulletX(wire[ID].bundle[0].x, wire[ID].bundle[0].y - 5, 0, 0, 0, 5, Boss.ID);
                          CreateBulletX(wire[ID].bundle[1].x, wire[ID].bundle[1].y - 5, 0, 0, 0, 5, Boss.ID);
                          PlaySound(0, 'firecrack.wav', wire[ID].bundle[0].x, wire[ID].bundle[0].y);
                          WriteConsole(wire[ID].owner, 'A wire was destroyed by heat.', RED);
                          Wires_ClearWire(ID);
                        end;
                    2:  //Statguns
                        begin
                          CreateBulletX(statgun[ID].X - 10, statgun[ID].Y, 0, 0, 0, 5, Boss.ID);
                          CreateBulletX(statgun[ID].X + 10, statgun[ID].Y, 0, 0, 0, 5, Boss.ID);
                          CreateBulletX(statgun[ID].X, statgun[ID].Y - 10, 0, 0, 0, 5, Boss.ID);
                          PlaySound(0, 'firecrack.wav', statgun[ID].X, statgun[ID].Y);
                          WriteConsole(statgun[ID].owner, 'A statgun was destroyed by heat.', RED);
                          Statguns_DestroySG(ID, false);
                        end;
                        3:  //Mines
                        begin
                          CreateBulletX(Mines.Mine[ID].X, Mines.Mine[ID].Y, 0, 0, 0, 5, Boss.ID);
                          WriteConsole(Mines.Mine[ID].owner, 'A mine was destroyed by heat.', RED);
                          Mines_Clear(ID);
                        end;
                        4:  //Charges
                        begin
                          CreateBulletX(charge[ID].X, charge[ID].Y, 0, 0, 0, 5, Boss.ID);
                          WriteConsole(charge[ID].owner, 'Charge [' + IntToStr(ID+1) + '] destroyed by heat.', RED);
                          Charges_Clear(ID);
                        end;
                        5:  //Scarecrow
                        begin
                          GetPlayerXY(ID, x, y);
                          CreateBulletX(x, y, 0, 0, 0, 5, Boss.ID);
                          PlaySound(0, 'firecrack.wav', x, y);
                          WriteConsole(Scarecrow.owner, 'Scarecrow was destroyed by heat.', RED);
                          Scarecrow_Clear();
                        end;
                        6:  //Sentry
                        begin
                          GetPlayerXY(ID, x, y);
                          CreateBulletX(x, y, 0, 0, 0, 5, Boss.ID);
                          PlaySound(0, 'firecrack.wav', x, y);
                          WriteConsole(Sentry.owner, 'Sentry was destroyed by heat.', RED);
                          Sentry_Clear(true);
                        end;
                    end;
                end;
            end;
        end;
      for i := Firefighter.ActiveHeatItems downto 1 do
        if Firefighter.ScheduledHeatItem[i].CountdownTicks > 0 then break;
      Firefighter.ActiveHeatItems := i;
      if i = 0 then ResetPower(Pwr);
  end;
end;

procedure ProcessTrail();
var
  vx, vy, x, y, Dist: single;
begin
  if (((Timer.Cycle-1) mod 4) <> 0) then exit;
  if Players[Boss.ID].Alive then begin
    GetPlayerXY(Boss.ID, x, y);  
    Dist := Distance(x, y, Firefighter.Trail.X, Firefighter.Trail.Y);
    if Dist > 1 then begin
      vx := (x - Firefighter.Trail.X)*2;
      if (vx > -10) and (vx < 0) then vx := -10
      else if (vx < 10) and (vx > 0) then vx := 10;
      x := x - vx;
      y := y - 10;
      if not RayCast2(0, 5, 45, x,y) then
        CreateBulletX(x,y, 0, 0.6 * RandFlt(0.9,1.1), 0, 5, Boss.ID);
      GetPlayerXY(Boss.ID, Firefighter.Trail.X, Firefighter.Trail.Y);
    end;
  end;
end;

procedure ProcessPlagueMinions();
var amount: byte;
begin
  if (Timer.Cycle <> 1) and (Timer.Cycle <> 33) then exit;
  if Plague.MinionCounter + Plague.MinionStorage >= Plague.MinionLimit then exit;

  if Plague.MinionTimer > 0 then Plague.MinionTimer := Plague.MinionTimer - 1
  else begin
    Plague.MinionStorage := Plague.MinionStorage + 1;
    amount := Plague.MinionCounter + Plague.MinionStorage;
    if amount < BRAVOPLAYERS*2 then
      Plague.MinionTimer := iif(Players[Plague.ID].Human, 1, 1)
    else if (amount >= BRAVOPLAYERS*2) and (amount < BRAVOPLAYERS * 3) then
      Plague.MinionTimer := iif(Players[Plague.ID].Human, 2, 1)
      else if amount >= (BRAVOPLAYERS * 3) then
      Plague.MinionTimer := iif(Players[Plague.ID].Human, 4, 3)
    else if BRAVOPLAYERS = 0 then Plague.Miniontimer := 4;
  end;
end;

procedure PlagueSpawnMinion(var Pwr: tPower);
var j: byte;
    x,y: single;
begin
  Plague.MinionStorage := Plague.MinionStorage - 1;
  Plague.MinionCounter := Plague.MinionCounter + 1;
  for j := 1 to Plague.MinionLimit do
      if Plague.Minions[j].ID = 0 then break;
    GetPlayerXY(Plague.ID, x, y);
  Plague.Minions[j].ID := Zombies_SpawnOne(Spawn.Wave[Spawn.LastWave].ZombieHp * 0.0007, Spawn.Wave[Spawn.LastWave].ZombieDmg * 0.005, 0, 91, x, y-10, true, 0);
  Plague.Minions[j].dead := false;
  Plague.Minions[j].blown := false;

  ResetPower(Pwr);
end;

procedure PlagueOnMinionDamage(ID: byte; Damage: single; weap: byte; Damage_Type: TDamageType);
var i: byte;
begin
  if Damage <= MAXHEALTH then exit;

  if (Damage_Type = Explosion)
  or ((Damage_Type = Heat) and (Damage_Direct))
  or (weap = WTYPE_M79)
  or (weap = WTYPE_FRAGGRENADE)
  or (weap = WTYPE_CLUSTER)
  or (weap = WTYPE_BOW2)
  or (weap = WTYPE_LAW)
  or (weap = WTYPE_FLAMER)
  then
    for i := 1 to Plague.MinionLimit do begin
      if Plague.Minions[i].ID = ID then begin
        Plague.Minions[i].blown := True;

                break;
            end;
        end;
end;

procedure PlagueOnMinionKill(ID: byte);
var i: byte;
begin
  Player[ID].KickTimer := 0;
  for i := 1 to Plague.MinionLimit do begin
    if Plague.Minions[i].ID = ID then begin
            GetPlayerXY(ID, Plague.Minions[i].X, Plague.Minions[i].Y);
        RayCast2(0, 15, 350, Plague.Minions[i].X, Plague.Minions[i].Y);
        Plague.Minions[i].dead := true;
      if not Plague.Minions[i].blown then begin
        BigText_DrawMapX(WTL_PLAGUE+ID, Boss.ID, '^', 360, $42C3BB, 0.1, Trunc(Plague.Minions[i].X) - 7, Trunc(Plague.Minions[i].Y-5));
            end;
            break;
      end;
  end;
end;

procedure PlagueOnMinionRespawn(ID: byte);
var j: byte;
    x,y: single;
begin
  for j := 1 to Plague.MinionLimit do
    if (Plague.Minions[j].dead) and (Plague.Minions[j].ID = ID) then
    begin
      GetPlayerXY(Plague.Minions[j].ID, x, y);
      if (x <> Plague.Minions[j].X) or (y <> Plague.Minions[j].Y) then
      begin
      if Player[Plague.Minions[j].ID].Status < 0 then begin //If not human zombie
        InfectedDeath(Plague.Minions[j].ID);
      end else begin
        Players[Plague.Minions[j].ID].Kick(TKickSilent);
      end;
      BigText_DrawMapX(WTL_PLAGUE+ID, Boss.ID, '', 360, $42C3BB, 0.2, 0,0);
      Plague.Minions[j].ID := 0;
      Player[ID].KickTimer := 0;
      Plague.Minions[j].X := 0;
      Plague.Minions[j].Y := 0;
      //!!ref
      //if Modes.CurrentMode <> 2 then Score[1][1] := Score[1][1] + 1;
      Plague.MinionCounter := Plague.MinionCounter - 1;
      end;
    end;
end;

procedure PlagueOnFlagGrab(ID: byte);
var i: byte;
begin
    if RandInt(0, 100) > 50 then
      for i := 1 to Plague.MinionLimit do
          if Plague.Minions[i].ID = ID then begin
                 Plague.Minions[i].blown := true;
                break;
          end;
end;

procedure PlagueRevive(var Pwr: tPower);
var j, revivedCount: byte;
    x,y: single;
begin
    revivedCount := 0;
  for j := 1 to Plague.MinionLimit do
  begin
    //Revive
    GetPlayerXY(Plague.ID, X, Y);

    if (Plague.Minions[j].ID <> 0) and (Plague.Minions[j].dead) and (not Plague.Minions[j].blown) then
      if IsInRange(Plague.ID, Plague.Minions[j].X, Plague.Minions[j].Y, PLAGUE_REVIVE_DISTANCE, false) then
          begin
              BigText_DrawMapX(WTL_PLAGUE+Plague.Minions[j].ID, Boss.ID, '', 360, $42C3BB, 0.1, 0,0);
        revivedCount := revivedCount + 1;
        Plague.Minions[j].dead := False;
            PutPlayer(Plague.Minions[j].ID, ZOMBIETEAM, Plague.Minions[j].X, Plague.Minions[j].Y, false);
      end;
  end;
  if (revivedCount > 0) then
  begin
    WriteConsole(Plague.ID, 'You recalled ' + IntToStr(revivedCount) + ' Minions.', GREEN);
    BW_RandZombChat(Plague.ID, BW_PlagueTauntsRevive, 1.0);
  end
  else
    WriteConsole(Plague.ID, 'No zombie corpse nearby', INFORMATION);
  ResetPower(Pwr);
end;

procedure PlagueDeath(ID: byte);
var
  i: byte;
  a: single;
  tsin, tcos, x, y: single;
begin
  GetPlayerXY(ID, x, y);
  for i := 0 to 12 do begin
    a := RandFlt(ANGLE_30, ANGLE_90);
    tsin := sin(a);
    tcos := cos(a);
    CreateBulletX(x - tcos*20, y - tsin*20, -tcos*ShowerStrength, -tsin*ShowerStrength, -1, 3, ID);
    CreateBulletX(x + tcos*20, y - tsin*20, tcos*ShowerStrength, -tsin*ShowerStrength, -2, 3, ID);
  end;
end;

procedure CreateAltar(Shooter, Victim: byte; var Pwr: tPower);
var 
  x, y: single;
  i: integer;
  s: string;
  col: longint;
begin
  player[Shooter].AttackReady := false;
  player[Shooter].statguns := Victim;
  player[Shooter].Mines := player[Shooter].Mines - 1;
  Zombies_SpawnOne(Spawn.Wave[Spawn.LastWave].ZombieHp * 0.0025, Spawn.Wave[Spawn.LastWave].ZombieDmg * 0.005, 0, 51, Players[Shooter].X, Players[Shooter].Y, true, 0);
  for i := 1 to 9 do begin
    if HackermanMode then begin
      col := $22FF22;
      s := IntTostr(RandInt_(1));
    end else begin
      col := $CC99AA;
      s := '*';
    end;
    x := Players[Victim].X + 20.0*cos(ANG_2PI*i/9)-5;;
    y := Players[Victim].Y + 20.0*sin(ANG_2PI*i/9)-5;;
    BigText_DrawMap(0, s, RandInt(100, 150), col, RandFlt(0.03, 0.1), trunc(x), trunc(y));
    x := Players[Shooter].X + (Players[Victim].X-Players[Shooter].X)*i/9 + RandFlt(-10, 0);
    y := Players[Shooter].Y + (Players[Victim].Y-Players[Shooter].Y)*i/9 + RandFlt(-10, 0);
    BigText_DrawMap(0, s, RandInt(100, 150), col, RandFlt(0.03, 0.1), trunc(x), trunc(y));
  end;

  if player[Shooter].Status = 0 then begin
    PutPlayer(Shooter, ZOMBIETEAM, Players[Victim].X, Players[Victim].Y, false);
  end else
    MovePlayer(Shooter, Players[Victim].X, Players[Victim].Y);
  Steal(Victim);
  if not HackermanMode then
    BW_RandZombChat(Shooter, BW_PriestTauntsTeleport, 0.167);
  if not AutoBrain then
    BigText_DrawScreenX(DTL_ZOMBIE_UI, Shooter, 'Altar servers left: '+IntToStr(player[Shooter].Mines), 100, RED, 0.1, 20, 370 );
  ResetPower(Pwr);
end;

function PowerNumToName(PwID: byte): string;
begin
  case PwID of
    //Priest
    51: Result := 'Summon Altar';
    //FireFighter
    61: Result := 'Heat';
    62: Result := 'Groundfire';
    63: Result := 'Trap';
    //Satan 1
    71: Result := 'Summon Minions';
    72: Result := 'Paralysis';
    73: Result := 'Pentagram of Death';
    74: Result := 'Lighting';
    //Satan 2
    81: Result := 'Ring of Death';
    82: Result := 'Hell Rain';
    83: Result := 'Explosion';
    84: Result := 'Hell Shower';
    85: Result := 'Deadly Arrow';
    86: Result := 'Shadows';
    87: Result := 'Living Artifact';
    88: Result := 'Fireworks';
    91: Result := 'Spawn Minion';
    92: Result := 'Recall';
    else Result := 'Unknown';
  end;
end;

procedure ProcessPower(PwID, Shooter, Victim, slot: byte);
begin
  case PwID of
    //Perished priest
    51: CreateAltar(Shooter, Victim, Boss.Power[slot]);
    //FireFighter
    61: Heat_(Shooter, Boss.Power[slot]);
    62: CreatePortal(Shooter, 4, Boss.Power[slot]);
    63: CreateTrap(Shooter, Boss.Power[slot]);
    //Satan 1
    71: SummonSpawns(Victim, Boss.Power[slot]);
    72: Paralyse(Victim, Boss.Power[slot]);
    73: Pentagram(Shooter, Victim, Boss.Power[slot]);
    74: Lighting(Victim, Shooter, Boss.Power[slot]);
    //Satan 2
    81: BulletCircle(Victim, Shooter, Boss.Power[slot]);
    82: HellRain(Victim, Shooter, Boss.Power[slot]);
    83: KaBoom(Shooter, Boss.Power[slot]);
    84: HellShower(Shooter, Boss.Power[slot]);
    85: Arrow(Shooter, Victim, Boss.Power[slot]);
    86: CreateShadows(Boss.Power[slot]);
    87: CreateArtifact(Boss.Power[slot]);
    88: Fireworks(Shooter, Boss.Power[slot]);
    91: PlagueSpawnMinion(Boss.Power[slot]);
    92: PlagueRevive(Boss.Power[slot]);
  end;
end;

procedure GetNumSpells(bID: byte; var min, max: byte);
begin
  case bID of
    5: begin
      min := 51;
      max := 51;
    end;
    6:begin
      min := 61;
      max := 63;
    end;
    7:begin
      min := 71;
      max := 74;
    end;
    8:begin
      min := 82;
      // COMMENT(Falcon): 85, not 88!
      // 86, 87 and 88 are NOT supposed to be handled by standard brain logic.
      max := 85;
    end;
    9:begin
       min := 91;
      max := 92;
    end;
    else begin
      min := 1;
      max := 0;
    end;
  end;
end;

procedure LigUp(ID: byte);            // satans intro
var
  xp, yp, xl, yl: single;
begin
  GetPlayerXY(ID, xp, yp);
  xl := xp + 10;
  yl := yp - 5;
  if HackermanMode then
      BigText_DrawScreen(ID,'XXX', 10, $0000fe, 46, -3920, -4260)   // makes screen flash blue when lightning strikes.
     else
     BigText_DrawScreen(ID,'XXX', 10, $D8D8D8, 46, -3920, -4260);   // makes screen flash white when lightning strikes.
  while yl > yp - 200 do begin
    CreateBulletX(xl, yl, 0, 0, 0, 5, ID);
    yl := yl - 20;
    xl := xl + RandFlt(-5, 5);
    end
end;

procedure ProcessLigs();
begin
  while Boss.Power[0].Victim < MaxID do begin
    Boss.Power[0].Victim := Boss.Power[0].Victim+1;
    if Players[Boss.Power[0].Victim].Alive then if player[Boss.Power[0].Victim].Status = 1 then begin
      break;
    end;
  end;
  if Boss.Power[0].Victim = MaxID then begin
    if player[Boss.Power[0].Victim].Status = 1 then LigUp(Boss.Power[0].Victim);
    Boss.Intro := Boss.Intro - 1;
  end else LigUp(Boss.Power[0].Victim);
end;

procedure ProcessIntro();
var
  i: byte;
  x, y:single;
  hp: single;
begin
  if Boss.Intro > 0 then begin
    case Boss.bID of
      6: begin
        Boss.Intro := Boss.Intro - 1;
        if Boss.Intro = 0 then
          for i := 1 to MaxID do
            if Player[i].Status = 1 then
            if Players[i].Alive then begin
              GetPlayerXY(i, x, y);
              CreateBulletX(x, y, 0, 0, 0, 5, Boss.ID);
              Damage_Direct := True;
              hp := Players[i].Health;
              if hp > 30 then Players[i].Damage(i, 30)
              else if hp > 10 then Players[i].Damage(i, Round(hp) - 10);
            end;
      end;
      7: begin
        if Boss.Outro then SatanDeath()
        else begin
          if Boss.Intro = 9 then
            EarthQuake_Start(7);
           Boss.Intro := Boss.Intro - 1;
          if Boss.Intro = 0 then begin
            Spawn_AddZombies(1, Boss.bID);
            Spawn_DrawWarning(7);
          end;
        end;
      end;
      8: begin
        if Boss.Outro then Satan2Death()
        else begin
          ProcessLigs();
          if Boss.Intro = 0 then begin
            Spawn_AddZombies(1, Boss.bID);
            Spawn_DrawWarning(8);
          end;
        end;
      end;
    end;
  end;
end;

function BossName(bID: byte): string;
begin
  case bID of
    3: Result := 'Butcher';
    5: Result := 'Priest';
    6: Result := 'Firefighter';
    7, 8: Result := 'Satan';
    9: Result := 'Plague';
  end;
end;

function CheckPowerColision(Power1, Power2: byte): boolean;
begin
  Result := false;
  case Power1 of
    //Perished Priest
    51: case Power2 of //Summon Altar
      51: Result := true;
    end;
    //FireFighter
    61: case Power2 of //Heat
      61: Result := true;
    end;
    62: case Power2 of //Portal;
      62: Result := true
    end;
    63: case Power2 of //Trap;
      63: Result := true
      else exit
    end;
    //Satan 1
    71: case Power2 of //Summon Minions
      71: Result := true;
    end;
    72: case Power2 of //Paralyse
      71, 72, 73, 74: Result := true;
    end;
    73: case Power2 of //Pentagram of Death
      72, 73: Result := true;
    end;
    74: case Power2 of //Lighting
      72, 74: Result := true;
    end;
    //Satan 2
    81: case Power2 of //Circle of Death
      81, 82, 83, 84, 85, 88: Result := true;
    end;
    82: case Power2 of //Hell Rain
      81, 82, 88: Result := true;
    end;
    83: case Power2 of //Explode
      81, 83, 88: Result := true;
    end;
    84: case Power2 of //Hell Shower
      81, 83, 84, 86, 87, 88: Result := true;
    end;
    85: case Power2 of //Deadly Arrow
      81, 85, 88: Result := true;
    end;
    86: case Power2 of //Shadows
      81, 86: Result := true;
    end;
    87: case Power2 of //Living Artifact
      87: Result := true;
    end;
    88: case Power2 of //Fireworks
      81, 83: Result := true;
    end;
  end;
end;

function CheckCollision(Power: byte): byte;
var
  i: byte;
begin
  Result := 0;
  for i := 0 to MAX_POWERS do
    if Boss.Power[i].InUse > 0 then 
      if Boss.Power[i].CountDown = 0 then begin
        if CheckPowerColision(Power, Boss.Power[i].InUse) then begin
          Result := Boss.Power[i].InUse;
          exit;
        end;
      end else if Power = Boss.Power[i].InUse then begin
        Result := Power;
        exit;
      end;
end;

procedure CastSpell(SpellID, Shooter, Victim, slot: byte);
var
  i: smallint;
begin
  i := Game.MAXPLAYERS - Players_StatusNum(1);
  if i > Game.MAXPLAYERS then i := 0;
  case SpellID of
    //Perished priest spells
    51: Boss.CountDown := 0; //Summon Altar
    //Fire fighter spells
    61: Boss.CountDown := 3; //Small heat
    62: Boss.CountDown := 10 + i; //Portal
    63: Boss.CountDown := 5 + i; //Trap
    //Satan 1 spells
    71: Boss.CountDown := 7 + i; //Minions
    72: Boss.CountDown := 7 + i; //Paralyse
    73: Boss.CountDown := 10 + i; //Pentagram
    74: Boss.CountDown := 5 + i; //Lighting
    //Satan 2 spells
    81: Boss.CountDown := 10 + i; //Circle
    82: Boss.CountDown := 8 + i; //HellRain
    83: Boss.CountDown := 5 + i; //Explode
    84: Boss.CountDown := 3; //HellShower
    85: Boss.CountDown := 8 + i; //Arrow
    86: Boss.CountDown := 10; //Shadows
    87: Boss.CountDown := 15; //Artifact
    88: Boss.CountDown := 10; //Fireworks
      //Plague spells
      91, 92: Boss.CountDown := 0;
  end;
  i := Trunc(players[Boss.ID].Health*100/MAXHEALTH);
  i := Trunc(((0.02*i-1)/sqrt(0.05+(0.02*i-1)*(0.02*i-1))+1)*30+40); //x->((0.02*x-1)/(0.05+(0.02*x-1)^2)^0.5+1)*30+40
  Boss.CountDown := Trunc(Boss.CountDown*i*0.01)+1;
  Boss.Power[slot].Victim := Victim;
  Boss.PwID := 0;
  Boss.Power[slot].InUse := SpellID;
  Boss.Power[slot].Progress := 0;
  ProcessPower(Boss.Power[slot].InUse, Shooter, Boss.Power[slot].Victim, slot);
end;

function InitialCheckSpell(SpellID: byte): boolean;
var
  j, slot: smallint;
  X, Y, X2: single;
  sgY: array[0..1] of single;
  b: boolean;
begin
  Result := false;
  if CheckCollision(SpellID) > 0 then exit;
  case SpellID of
    //Perished priest spells
    51: Result := player[Boss.ID].Mines > 0; //Summon Altar
    //Fire fighter spells
    61: Result := true; //Small heat
    62: begin  //Portal
      if AliveZombiesInGame <= 3 then begin
        if (not AutoBrain) or (players[Boss.ID].Health <= Trunc(MAXHEALTH*3/4)) then begin
          GetPlayerXY(Boss.ID, X, Y);
          if RayCast(X - 25, Y - 30, X + 25, Y - 30, true, false, false) then begin
            if RayCast(X, Y - 5, X, Y - 40, true, false, false) then begin
              if not RayCast(X, Y, X, Y + 30, true, false, false) then begin
                Result := true;
              end else if not AutoBrain then WriteConsole(Boss.ID, 'You have to stand on the ground to spawn the Fire' , RED);
            end else if not AutoBrain then WriteConsole(Boss.ID, 'Not enough space for the Fire, try somewhere else' , RED);
          end else if not AutoBrain then WriteConsole(Boss.ID, 'Not enough space for the Fire, try somewhere else' , RED);
        end// else if not AutoBrain then WriteConsole(Boss.ID, 'Groundfire can be placed later' , RED);
      end else if not AutoBrain then WriteConsole(Boss.ID, 'There are still flames from the last Fire alive', RED);
    end;
    63: begin  //Trap
      for j := FF_MAXTRAPS downto 1 do
        if Firefighter.Trap[j].ID > 0 then begin
          if AutoBrain then
            if PlayersInRange(Firefighter.Trap[j].ID, Boss.ID, 200, false) then //TODO: shooter...
              exit;
        end else slot := j;
      if slot = 0 then begin
        if not AutoBrain then
          WriteConsole(Boss.ID, 'You can''t place more traps', RED);
        exit;
      end;
      FireFighter.TrapSlot := slot;
      GetPlayerXY(Boss.ID, X, Y);
      Y := Y - 5;
      if (not Autobrain) or (RayCast(X, Y, X, Y - 200, true, false, false)) then begin//Condition: Enough vertical space
        case Players_OnGround(Boss.ID, true, 20) of    //Condition: Checking, if on ground
          1: begin
            sgY[0] := Y;
            sgY[0] := sgY[0] - 10;
            sgY[1] := sgY[0];
            b := false;
            for j := 0 to 1 do  begin
              X2 := X - (2*j - 1) * 10;
              b := (b) or (RayCast2(0, 2, 30, X2, sgY[j]));
            end;
            if not b then begin
              if Abs(sgY[0] - sgY[1]) <= 15 then
                Result := true;
            end else if not AutoBrain then WriteConsole(Boss.ID, 'Ground is too step to place a trap', RED);
          end;
          -1: if not AutoBrain then WriteConsole(Boss.ID, 'You must stand on the solid ground to place a trap', RED);
          else if not AutoBrain then WriteConsole(Boss.ID, 'You must stand on the ground to place a trap', RED);
        end;
      end; // else if not AutoBrain then WriteConsole(Boss.ID, 'Not enough space (vertical) to spawn a trap', RED);
    end;
    //Satan 1 spells
    71: begin //Minions
      if AliveZombiesInGame <= 3 then
        Result := true
      else if not AutoBrain then
        WriteConsole(Boss.ID, 'Too many minions on the map.', RED);
    end;
    72: Result := true; //Paralyse
    73: Result := true; //PentagramPentagram
    74: Result := true; //Lighting
    //Satan 2 spells
    81: Result := true; //Circle
    82: Result := true; //Hellrain
    83: Result := true; //Explode TODO: prevent explosions in tunnels, or modify them to fit
    84: Result := true; //HellShower
    85: Result := true; //Arrow
    86: Result := (not Satan.Shadows) and (players[Boss.ID].Health < MAXHEALTH / 2); //Shadows
    87: Result := (not Satan.Artifact) and (players[Boss.ID].Health < MAXHEALTH / 3); //Artifact
    88: Result := Satan.DoFireworks; //Fireworks
      91: Result := Plague.MinionStorage > 0;
      92: Result := true;
  end;
end;

function BrainCheckSpell(SpellID, ID: byte): boolean;
var
  i: byte;
begin
Result := false;
case SpellID of
    //Perished priest spells
    51: Result := true; //Summon Altar
    //Fire fighter spells
    61: begin
          for i := 1 to MaxId do
            if ((Players[i].Alive) and (player[i].Status = 1)) or (i = Scarecrow.ID) or (i = Sentry.ID) then
              if SqrDist(Players[ID].X, Players[ID].y, Players[i].X, Players[i].Y) <= FF_HEATRANGE then begin
                Result := True; Exit;
              end;
          for i := 1 to MAX_WIRES do
            if wire[i].Active then
              if SqrDist(Players[ID].X, Players[ID].y, (wire[i].bundle[0].x + wire[i].bundle[1].x)/2, (wire[i].bundle[0].y + wire[i].bundle[1].y)/2) <= FF_HEATRANGE then begin
                Result := True; Exit;
              end;
          for i := 1 to (SG.Num - 1) do
            if SqrDist(Players[ID].X, Players[ID].y, statgun[i].x, statgun[i].y) <= FF_HEATRANGE then begin
              Result := True; Exit;
            end;
          for i := 1 to Mines.MaxMineID do
            if Mines.Mine[i].placed then
              if SqrDist(Players[ID].X, Players[ID].y, Mines.Mine[i].x, Mines.Mine[i].y) <= FF_HEATRANGE then begin
                Result := True; Exit;
              end;
          for i := 0 to Charges_MaxID do
            if charge[i].placed then
              if SqrDist(Players[ID].X, Players[ID].y, charge[i].x, charge[i].y) <= FF_HEATRANGE then begin
                Result := True; Exit;
              end;
          Result := False;
        end;
        62: begin  //Portal
      if ID > 0 then
        Result := PlayersInRangeX(ID, Boss.ID, 200)
      else
        Result := players[Boss.ID].Health/MAXHEALTH < 0.4;
    end;
    63: if player[ID].status = 1 then  //Trap
      Result := PlayersInRangeX(ID, Boss.ID, 200);
    //Satan 1 spells
    71: Result := true; //Minions
    72: Result := true; //Paralyse
    73: Result := true; //Pentagram
    74: Result := true; //Lighting
    //Satan 2 spells
    81: Result := true; //Circle
    82: Result := true; //Hellrain
    83: if ID > 0 then //Explode
      Result := PlayersInRange(ID, Boss.ID, 200, true);
    84: if ID > 0 then  //HellShower
      Result := PlayersInRange(ID, Boss.ID, 100, true);
    85: Result := true; //Arrow
    86: Result := true; //Shadows
    87: Result := true; //Artifact
    88: Result := true; //Fireworks
      91: Result := True;  //Spawn minion
      92: for i := 1 to Plague.MinionLimit do
          if (Plague.Minions[i].ID <> 0) and (Plague.Minions[i].dead) and (not Plague.Minions[i].blown) then
            if PlayersInRange(Boss.ID, Plague.Minions[i].ID, PLAGUE_REVIVE_DISTANCE, false) then
            begin
              Result := True;
              break;
            end;
  end;
end;

function ManualCheckSpell(SpellID: byte): boolean;
begin
Result := false;
case SpellID of
    //Perished priest spells
    51: Result := GetKeyPress(Boss.ID, 'Grenade'); //Summon Altar
    //Fire fighter spells
    61: Result := GetKeyPress(Boss.ID, 'Shoot'); //Small heat
    62: Result := GetKeyPress(Boss.ID, 'Reload');  //Portal
    63: Result := GetKeyPress(Boss.ID, 'Grenade');  //Trap
    //Satan 1 spells
    71: Result := GetKeyPress(Boss.ID, 'Reload'); //Minions
    72: Result := GetKeyPress(Boss.ID, 'Throw'); //Paralyse
    73: Result := GetKeyPress(Boss.ID, 'Grenade'); //Pentagram
    74: Result := GetKeyPress(Boss.ID, 'Shoot'); //Lighting
    //Satan 2 spells
    81: Result := GetKeyPress(Boss.ID, 'Reload'); //Circle
    82: Result := GetKeyPress(Boss.ID, 'Changewep'); //Hellrain
    83: Result := GetKeyPress(Boss.ID, 'Grenade'); //Explode
    84: Result := GetKeyPress(Boss.ID, 'Shoot');  //HellShower
    85: Result := GetKeyPress(Boss.ID, 'Throw'); //Arrow
    //86: Result := false; //Shadows
    //87: Result := false); //Artifact
    //88: Result := false; //Fireworks
      91: Result := GetKeyPress(Boss.ID, 'Grenade');
      92: Result := GetKeyPress(Boss.ID, 'Changewep');
  end;
end;

function CheckSpell(SpellID, ID: byte; var Pwr: tPower): boolean;
begin
  Result := false;
  case SpellID of
    //Perished priest spells
    51: begin //Summon Altar
      if (player[ID].status <> 1) then
        exit;
      if PlayersInRange(ID, Boss.ID, 250, true) then
        if (ID <> player[Boss.ID].statguns) then
          Result := true
        else if not AutoBrain then
          BigText_DrawScreenX(DTL_ZOMBIE_UI, Boss.ID, 'You can''t attack the same player ('+Players[ID].Name+')', 100, RED, 0.1, 20, 370 );
    end;
    //Fire fighter spells
    61: Result := true; //Small heat
    62: Result := true; //Portal
    63: Result := true; //Trap
    64: Result := true; //Extreme Heat
    //Satan 1 spells
    71: begin //Minions
      if player[ID].status = 1 then
        if not player[ID].frozen then
          Result := PlayersInRange(ID, Boss.ID, 320, true);
    end;
    72: begin //Paralyse
      if Players[ID].Alive then
        if (ID <> Medic.ID) and (Player[ID].Status = 1) then
          Result := PlayersInRange(ID, Boss.ID, 300, true);
    end;
    73: begin //Pentagram
      if Players[ID].Alive then //anything
        if not player[ID].frozen then
          Result := PlayersInRange(ID, Boss.ID, 240, true);
    end;
    74: begin //Lighting
      if Players[ID].Alive then
        if not player[ID].frozen then
          if PlayersInRange(ID, Boss.ID, 320, true) then begin
            GetPlayerXY(ID, Pwr.X, Pwr.Y);
            Result := RayCast(Pwr.X, Pwr.Y-5, Pwr.X, Pwr.Y - 200, false, true, true);
          end;
    end;
    //Satan 2 spells
    81: begin //Circle
      if Players[ID].Alive then
        if ID <> Medic.ID then
          Result := PlayersInRange(ID, Boss.ID, 240, true);
    end;
    82: begin //HellRain
      if Players[ID].Alive then
        if PlayersInRange(ID, Boss.ID, 320, true) then begin
          GetPlayerXY(ID, Pwr.X, Pwr.Y);
          if RayCast(Pwr.X-200, Pwr.Y - 350, Pwr.X+200, Pwr.Y - 360, false, true, true) then
            Result := true
          else if not AutoBrain then
            WriteConsole(Boss.ID, 'Not enough space to cast the Hellrain', RED);
        end;
    end;
    83: Result := true; //Explode
    84: Result := true; //HellShower
    85: if Players[ID].Alive then //Arrow
      Result := PlayersInRange(ID, Boss.ID, 300, true);
    86: Result := true; //Shadows
    87: Result := true; //Artifact
    88: Result := true; //Fireworks
      91: Result := true;
      92: Result := true;
  end;
end;

procedure DrawBossInterface();
var
  Data: string;
  i: byte;
  col: integer;
begin
  if player[Boss.ID].Status = 0 then exit; // bot
  if Boss.CountDown > 0 then begin
    Data := 'Unready ['+IntToStr(Boss.CountDown)+']' + #13#10;
    col := $888888;
  end else if Boss.PwID > 0 then begin
    Data := 'Looking for target ['+PowerNumToName(Boss.PwID)+'] ' + Dots((Timer.Value div 60) mod 4) + #13#10;
    col := $888888;
  end else begin
    Data := #13#10;
    col := $EEEEEE;
  end;
  for i := 0 to MAX_POWERS do begin
    if Boss.Power[i].InUse > 0 then begin
      if Boss.Power[i].CountDown > 0 then begin
        Data := Data + PowerNumToName(Boss.Power[i].InUse) + ' ['+IntToStr(Boss.Power[i].CountDown)+']' + #13#10;
      end else
        Data := Data + PowerNumToName(Boss.Power[i].InUse) + ' ' + Dots((Timer.Value div 60) mod 4) + #13#10;
    end;
  end;
    if (Boss.bID = 9) and (Plague.MinionStorage > 0) then
    Data := Data + 'Minions: [' + IntToStr(Plague.MinionStorage) + ']' + #13#10;
  Data := Data + 'HP: ' + IntToStr(Trunc(players[Boss.ID].Health/MAXHEALTH * 100)) + '%';
  BigText_DrawScreenX(DTL_ZOMBIE_UI, Boss.ID, Data, 130, col, 0.08, 20, 350)
end;

procedure DrawDebugInterface();
var
  Data: string;
  i: byte;
begin
  Data := 'Global countdown: ['+IntToStr(Boss.CountDown)+']';
  for i := 0 to MAX_POWERS do
    Data := Data+#13#10+'slot '+IntToStr(i)+':'+iif(Boss.Power[i].InUse > 0, PowerNumToName(Boss.Power[i].InUse)+'['+IntToStr(Boss.Power[i].CountDown)+']', '');
  BigText_DrawScreenX(DTL_ZOMBIE_UI, 0, Data, 130, $FFFF0000, 0.09, 20, 330);
end;

procedure ProcessBosses(DoBrain: boolean);
var
  slot, min, max: byte;
  i: shortint;
  s: string;
  SpellQueue: array of record
    SpellID, Target: byte;
  end;
begin
  if Boss.bID = 0 then exit;
  if Boss.ID = 0 then exit;
  if not Players[Boss.ID].Alive then exit; //be sure that Boss.ID > 0 first

  //Process passive powers
  case Boss.bID of
    6: begin
          ProcessTrap();
          ProcessTrail();
       end;
      9: ProcessPlagueMinions();
  end;

  //Process all active powers;
  for i := 0 to MAX_POWERS do
    if (Boss.Power[i].CountDown = 0) and (Boss.Power[i].InUse > 0) then
      ProcessPower(Boss.Power[i].InUse, Boss.ID, Boss.Power[i].Victim, i);

  if DoBrain then begin
    if player[Boss.ID].bitten then begin
      player[Boss.ID].bitten := false;
      i := Trunc(players[Boss.ID].Health/MAXHEALTH * 100);
      if i > 0 then
      begin 
        if HackermanMode then begin
          BigText_DrawMap(0, IntTostr(RandInt_(1)), RandInt(40, 60), $22FF22, RandFlt(0.02, 0.05), trunc(Players[Boss.ID].X) + RandInt(-10, 10), trunc(Players[Boss.ID].Y) + RandInt(-10, 0));
          s := 'Players[Boss.ID].Health = 0x' + UIntToHex(Round(players[Boss.ID].Health/MAXHEALTH * 255));
        end else begin
          s := BossName(Boss.bID) + ': ' + IntToStr(Round(players[Boss.ID].Health/MAXHEALTH * 100)) + '%';        
        end;
        BigText_DrawScreenX(DTL_ZOMBIE_UI, 0, s, 120, RG_Gradient(players[Boss.ID].Health/MAXHEALTH, 0.9), 0.08, 20, 370);
      end;
    end;
  
    Boss.TempDmgInputFactor := (Boss.TempDmgInputFactor + 0.1) / 1.1; // tend to 1
    //writeconsole(0, floattostr(roundto(Boss.TempDmgInputFactor, 2)), red);
  
    DrawBossInterface();
    //DrawDebugInterface();

    //process priority powers countdowns
    if Boss.Power[0].InUse > 0 then
      if Boss.Power[0].CountDown > 0 then begin
        Boss.Power[0].CountDown := Boss.Power[0].CountDown - 1;
        if Boss.Power[0].CountDown = 0 then
          Boss.Power[0].InUse := 0;
      end;

    // special powers slot
    if Boss.Power[0].InUse = 0 then
      case Boss.bID of
        8: begin
          if InitialCheckSpell(86) then begin
            CastSpell(86, Boss.ID, 0, 0);
            Satan.Shadows := true;
          end;
          if InitialCheckSpell(87) then begin
            CastSpell(87, Boss.ID, 0, 0);
            Satan.Artifact := true;
          end;
          if InitialCheckSpell(88) then begin
            Satan.DoFireworks := false;
            CastSpell(88, Boss.ID, 0, 0);
          end;
        end;
      end;
    
    //lower local countdowns
    slot := 0;
    for i := MAX_POWERS downto 1 do
      if Boss.Power[i].InUse > 0 then begin
        if Boss.Power[i].Progress = 0 then
          if Boss.Power[i].CountDown > 0 then begin
            Boss.Power[i].CountDown := Boss.Power[i].CountDown - 1;
            if Boss.Power[i].CountDown = 0 then begin
              Boss.Power[i].InUse := 0;
              slot := i;
            end;
          end;
      end else slot := i;
  
    if Boss.CountDown > 0 then begin
      Boss.CountDown := Boss.CountDown - 1;
      exit;
    end;

    //if no slot free then exit.
    if slot = 0 then
      exit;

    GetNumSpells(Boss.bID, min, max);
    for min := min to max do begin
      if InitialCheckSpell(min) and (AutoBrain or ManualCheckSpell(min)) then begin
        for i := 1 to MaxID do
          if Players[i].Active then
          if Players[i].Alive then
          if not player[i].zombie then
            if (not AutoBrain) or BrainCheckSpell(min, i) then begin
              if CheckSpell(min, i, Boss.Power[slot]) then begin
                SetLength(SpellQueue, Length(SpellQueue)+1);
                SpellQueue[Length(SpellQueue)-1].SpellID := min;
                SpellQueue[Length(SpellQueue)-1].Target := i;
              end;
            end;
      end;
    end;
    if Length(SpellQueue) > 0 then begin //TODO: spell prioritizing
      i := Random(0, Length(SpellQueue)-1);
      CastSpell(SpellQueue[i].SpellID, Boss.ID, SpellQueue[i].Target, slot);
    end;
  end;
end;

procedure Bosses_WriteBossKillMessage();
var
  str: string;
  hdmg, tdmg: single;
  i, h, n: integer;
begin
  str := BossName(Boss.bID) + ' has been killed by: ';
  for i := 1 to MaxID do  // count total dmg
    if player[i].BossDmg > 0 then
      tdmg := tdmg + player[i].BossDmg;
  repeat // create a string with descending order
    h := 0;
    n := 0;
    hdmg := 0;
    for i := 1 to MaxID do
      if player[i].BossDmg > 0 then begin
        n := n + 1;
        if hdmg < player[i].BossDmg then begin
          hdmg := player[i].BossDmg;
          h := i;
        end;
      end;
    if h > 0 then begin
      player[h].BossDmg := 0;
      if h <> Boss.ID then begin
        if h = Sentry.ID then
          str := str + 'Sentry gun' else
          str := str + Players[h].Name;
        str := str + ' (' + IntToStr(Round(hdmg/tdmg*100)) + '%)';
        if n > 1 then str := str + ', ';
      end;
    end;
  until h = 0;
  Players.WriteConsole(str, PINK);
end;

procedure Bosses_OnZombieKill(Killer, Victim: TActivePlayer; BulletID: byte);
var
  i: integer;
  x, y, vx: single;
begin
  if Victim.ID = Boss.ID then begin
    Bosses_WriteBossKillMessage();
    case Boss.bID of
      3: begin
        for i := 1 to 6 do
          Zombies_SpawnOne(
            Spawn.Wave[Spawn.LastWave].ZombieHp/100/2,
            Spawn.Wave[Spawn.LastWave].ZombieDmg/100,
            0, 31, Victim.X+RandFlt(-6.0, 6.0), Victim.Y, true, i);
        Butcher := 0;
        ResetBoss();
        Victim.Say('Aaaarghhh!');
      end;
      6: ResetBoss();
      7: begin
        SatanDeath();
        SetTeam(5, Boss.ID, true);
        player[Victim.ID].KickTimer := 0;
      end;
      8: begin
        Satan2Death();
        SetTeam(5, Boss.ID, true);
        player[Victim.ID].KickTimer := 0;
      end;
    end;
  end else
   if Victim.ID = Satan.ArtifactID then begin
    Satan.DoFireworks := true;
  end;

  case Boss.bID of
  6:
      for i := 1 to FF_MAXTRAPS do
    if Firefighter.Trap[i].ID > 0 then
    if (Players[Firefighter.Trap[i].ID].Health < 1) then //i have no idea for what someone did it like that, leaving just in case
    begin
      Players[Firefighter.Trap[i].ID].Kick(TKickSilent);
      player[Firefighter.Trap[i].ID].kicked := true;
      player[Firefighter.Trap[i].ID].KickTimer := 0;
      Firefighter.Trap[i].ID := 0;
      Firefighter.Trap[i].InProgress := false;
    end;
  end;

    if Plague.ID > 0 then
      if Victim.ID <> Plague.ID then
          PlagueOnMinionKill(Victim.ID)
    else begin
      PlagueDeath(Victim.ID);
      Plague.ID := 0;
      player[Victim.ID].KickTimer := 1;
    end;
  if (player[Victim.ID].task = 2) or (player[Victim.ID].task = 91) then begin
    x := Victim.X;
    y := Victim.Y -5;
    vx := Victim.VELX * 0.7;
    for i:=0 to 6 do
      CreateBulletX(x, y - RandFlt(5, 10), RandFlt(-6, 6) + vx, RandFlt(-4, 0), 4, 3, Victim.ID);
  end;
end;

procedure Bosses_OnLeaveGame(P: TActivePlayer);
var
  i, ID: byte;
begin
  ID := P.ID;

  if ID = Boss.ID then begin
    Boss.ID := 0;
    if not player[ID].kicked then begin
      Spawn_AddZombies(1, Boss.bID);
      player[ID].kicked := false;
      P.Say('Hahahahaha! F**k you nabs!');
      exit;
    end else begin
      if Satan.ArtifactID > 0 then begin
        player[Satan.ArtifactID].kicked := true;
        Players[Satan.ArtifactID].Kick(TKickSilent);
      end;
      ResetBoss();
    end;

    if ID = Plague.ID then begin
      Plague.ID := 0;
      if not player[ID].kicked then begin
        Spawn_AddZombies(1, 9);
        player[ID].kicked := false;
        BotChat(ID, 'Muahahaha!');
        exit;
      end;
    end;
  end else

  if ID = Satan.ArtifactID then begin
    Satan.ArtifactID := 0;
    if Boss.ID > 0 then
    if not player[ID].kicked then begin
      player[Boss.ID].X := P.X;
      player[Boss.ID].Y := P.Y;
      Zombies_SpawnOne(
        Spawn.Wave[Spawn.LastWave].ZombieHp * 0.0025,
        Spawn.Wave[Spawn.LastWave].ZombieDmg * 0.005,
        0, 81, player[Boss.ID].X, player[Boss.ID].Y, true, 0
      );
      player[ID].kicked := false;
      P.Say('Heh, idiots....');
      exit;
    end;
  end else begin
    for i := 1 to FF_MAXTRAPS do
    if ID = Firefighter.Trap[i].ID then begin
      Firefighter.Trap[i].ID := 0;
      Firefighter.Trap[i].InProgress := false;
    end;
  end;
end;

begin
end.
