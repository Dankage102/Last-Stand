//  * ------------- *
//  |  Mode System  |
//  * ------------- *

// This is a part of {LS} Last Stand. The unit is responsible for spawning zombies in waves.

unit
  Spawner;

interface

uses
{$ifdef FPC}
  Scriptcore,
{$endif}
  Constants,
  Configs,
  FlashMSG,
  Gamemodes,
  Globals,
  maths,
  MersenneTwister,
  Misc,
  LSPlayers,
  Zombies;


  
const
  MAX_SPAWNWAVES = 3;
  
type
  tSpawn = record
    Active, Paused: boolean;
    Wave: array[1..MAX_SPAWNWAVES] of record
      Active: boolean;
      Style, ActivationNum: byte;
      Counter: word;
      ZombieHp, ZombieDmg: integer;
    end;
    CurrentWave, LastWave: byte;
    TimeStarted: integer;
  end;
  
var
  Spawn: tSpawn;
  
procedure Spawn_Reset();

procedure Spawn_Process();

procedure Spawn_AddZombies(N, Style: word);

// takes care of removing a zombie bot from game, unless ForceKick is true, decides if it should be kicked, or allows it to spawn once again in the wave
// reduces zombie add/kick console spam
procedure Spawn_TryKickZombie(ID: byte; ForceKick: boolean);

procedure Spawn_ClearAllZombies();

procedure Spawn_DrawWarning(Style: byte);

{$ifndef FPC}
// Moved here from AZSS unit to satisfy cross-reference restriction
// when a spawning process starts a new sub wave
procedure AZSS_OnSpawnWave(style: byte);

// when the spawning process respawns all the zombies
procedure AZSS_OnSpawnWaveEnd();
{$endif}

implementation

procedure Spawn_ClearAllZombies();
var
  a: byte;
begin
  for a := 1 to 32 do begin
    if Players[a].Active then begin
      if not Players[a].Human then begin
        if Players[a].Dummy then continue;
        Spawn_TryKickZombie(a, true);
      end else if Modes.CurrentMode <> 1 then
        if player[a].Status < 0 then InfectedDeath(a);
    end;
  end;
  ZombiesLeft := 0;
  AliveZombiesInGame := 0;
  ZombiesInGame := 0;
  BurningRef := 0;
end;

procedure Spawn_TryKickZombie(ID: byte; ForceKick: boolean);
var temp: byte;
begin
  player[ID].KickTimer := 0;
  PerformProgressCheck := true;
  if ForceKick then begin
    player[ID].kicked := true;
    Players[ID].Kick(TKickSilent);
  end else begin
    if (Spawn.Active) and (Spawn.CurrentWave > 0) then begin
      if (Spawn.Wave[Spawn.CurrentWave].Counter > 0) and (player[ID].task = Spawn.Wave[Spawn.CurrentWave].Style) then begin
        if Modes.CurrentMode > 1 then // not survival
          if Zombies_GetZombieCandidate(temp, Spawn.Wave[Spawn.CurrentWave].Style = 0) then begin // if there is a human-zombie player waiting and ready to spawn, kick this zombie and make a place for him
            player[ID].kicked := true;
            Players[ID].Kick(TKickSilent);
            exit; // skip the rest of code \/
          end;  
        Spawn.Wave[Spawn.CurrentWave].Counter := Spawn.Wave[Spawn.CurrentWave].Counter - 1; // in this case we just let the zombie bot respawn again
      end else begin
        player[ID].kicked := true;
        Players[ID].Kick(TKickSilent);
      end;
    end else begin
      player[ID].kicked := true;
      Players[ID].Kick(TKickSilent);
    end;
  end;
end;

procedure Spawn_Reset();
var i: byte;
begin
  for i := 1 to MAX_SPAWNWAVES do begin
    Spawn.Wave[i].Active := false;
    SPawn.Wave[i].Counter := 0;
  end;
  Spawn.Paused := false;
  Spawn.Active := false;
  Spawn.CurrentWave := 0;
end;

procedure Spawn_WarnBossPlayer();
var ID, i: byte; str: string;
begin
  if Modes.CurrentMode > 1 then begin
    ID := Zombies_GetBossCandidate(true);
    if ID > 0 then begin
      WriteConsole(ID, 'Be ready! You will be spawned as a boss in this wave!', WHITE);
      str := Players[ID].Name + ' will be spawned as a boss in this wave';
      for i := 1 to MaxID do
        if i <> ID then
          if player[i].Status < 0 then
            WriteConsole(i, str, WHITE);
    end;
  end;
end;

procedure Spawn_AddZombies(N, Style: word);
var
  j, k: word;
begin
  for j := 1 to MAX_SPAWNWAVES do // find a slot
    if not Spawn.Wave[j].Active then begin
      k := j;
      break;
    end;
  if k = 0 then exit;
  case Style of
    0,1,2,4: begin
      if Modes.RealCurrentMode = 2 then
        Spawn.Wave[k].ZombieHp := Trunc(ZombieHpInit + V_Z_W_HPINC*Modes.DifficultyPercent*LSMap.DifficultyPercent/10000*Math.Pow(NumberOfWave, (Modes.DifficultyPercent+EQUALIZATIONDIFF)/(100+EQUALIZATIONDIFF)))
      else Spawn.Wave[k].ZombieHp := Trunc(Z_W_HPINC*Modes.DifficultyPercent*LSMap.DifficultyPercent/10000*Math.Pow(NumberOfWave, (Modes.DifficultyPercent+EQUALIZATIONDIFF)/(100+EQUALIZATIONDIFF)));
      Spawn.Wave[k].ZombieHp := Trunc(Z_W_HPINIT + Z_W_HPINC*Modes.DifficultyPercent*LSMap.DifficultyPercent/10000*Math.Pow(NumberOfWave, (Modes.DifficultyPercent+EQUALIZATIONDIFF)/(100+EQUALIZATIONDIFF)));
      if Style = 2 then Spawn.Wave[k].ZombieHp := Spawn.Wave[k].ZombieHp + 150;
      Spawn.Wave[k].ZombieDmg := Trunc(Z_W_DMGINC*Math.Pow(NumberOfWave, 0.875) * Modes.DifficultyPercent * LSMap.DifficultyPercent / 10000);
      Spawn.Wave[k].ActivationNum := MAX_ZOMBIES;
    end;
    3,5: begin // butcher, priest
      case Modes.CurrentMode of
        1: begin
          Spawn.Wave[k].ZombieHp := (10000 + NumberOfWave * 120) * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
          Spawn.Wave[k].ZombieDmg := 500 * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
        end;
        2: begin
          Spawn.Wave[k].ZombieHp := (5000 + NumberOfWave * 120) * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
          Spawn.Wave[k].ZombieDmg := 200 * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
        end;
        3: begin
          Spawn.Wave[k].ZombieHp := (8000 + NumberOfWave * 120) * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
          Spawn.Wave[k].ZombieDmg := 400 * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
        end;
      end;
      
      Spawn.Wave[k].ActivationNum := 10;
      Spawn_WarnBossPlayer();
    end;
    6: begin // firefighter
      Spawn.Wave[k].ZombieHp := 18500 + 10000 * Players_StatusNum(1)div Game.MAXPLAYERS * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
      Spawn.Wave[k].ZombieDmg := 400;
      if Players_ParticipantNum(-1) > 0 then begin
        Spawn.Wave[k].ActivationNum := 4;
      end else
        Spawn.Wave[k].ActivationNum := 8;
      Spawn_WarnBossPlayer();
    end;
    7: begin // satan
      Spawn.Wave[k].ZombieHp := 19000 + 10000 * Players_StatusNum(1) div Game.MAXPLAYERS * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
      Spawn.Wave[k].ZombieDmg := 666;
      if Players_ParticipantNum(-1) > 0 then begin
        Spawn.Wave[k].ActivationNum := 5;
      end else
        Spawn.Wave[k].ActivationNum := 10;
    end;
    8: begin // satan2
      Spawn.Wave[k].ZombieHp := 25000 + 10000 * Players_StatusNum(1) div Game.MAXPLAYERS * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
      Spawn.Wave[k].ZombieDmg := 666;
      if Players_ParticipantNum(-1) > 0 then begin
        Spawn.Wave[k].ActivationNum := 5;
      end else
        Spawn.Wave[k].ActivationNum := 10;
    end;
    11: begin // kamikaze2
      Spawn.Wave[k].ZombieHp := (2500 + NumberOfWave * 120) * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
      Spawn.Wave[k].ZombieDmg := 300;
      Spawn.Wave[k].ActivationNum := 8;
      Spawn_WarnBossPlayer();
    end;
    107: begin
      Spawn.Wave[k].ActivationNum := 7; // for satan init
      Spawn_WarnBossPlayer();
    end;
    108: begin
      Spawn.Wave[k].ActivationNum := 5;
      Spawn_WarnBossPlayer();
    end;
    9: begin // plague
      Spawn.Wave[k].ZombieHp := 18000 + 8000 * Players_StatusNum(1) div Game.MAXPLAYERS * Modes.DifficultyPercent * LSMap.DifficultyPercent div 10000;
      Spawn.Wave[k].ZombieDmg := 500;
      Spawn.Wave[k].ActivationNum := 10;
      Spawn_WarnBossPlayer();
    end;
    else Spawn.Wave[k].ActivationNum := MAX_ZOMBIES;
  end;
  Spawn.Wave[k].Active := true;
  Spawn.Wave[k].Style := Style;
  Spawn.Wave[k].Counter := N;
  Spawn.Active := true;
end;

procedure Spawn_Process();
var i, Style: byte; Hp: integer; found: boolean;
  ZombiePowerDivergence: integer;
label pos1;
begin
  if Spawn.Active then begin
    if Spawn.Paused then exit;
    pos1:
    if Spawn.CurrentWave > 0 then begin // if current wave is active then keep spawning
      if Spawn.Wave[Spawn.CurrentWave].Counter > 0 then begin // if something left in the wave to spawn then keep spawning
        Style := Spawn.Wave[Spawn.CurrentWave].Style;
        Hp := Spawn.Wave[Spawn.CurrentWave].ZombieHp;
        if Style = 0 then begin
          ZombiePowerDivergence := Trunc(0.7 * Hp);
          Hp := ToRangeI(100, Hp + RandInt(-ZombiePowerDivergence, ZombiePowerDivergence), 10000000);
        end;
        if Modes.CurrentMode = 2 then //versus
        begin
          if Style = 0 then // in VS, instead of spawning as normal zombie, make Zombies_SpawnOne decide what species it will be
            Style := 200;
        end else
          if Modes.RealCurrentMode = 2 then
          begin
            if RandInt(0, 1000) < (1000 / (100 - 8 * Players_HumanNum)) then
            begin
              Style := 12;
            end;
          end;
        if Zombies_SpawnOne(Hp / 100, Spawn.Wave[Spawn.CurrentWave].ZombieDmg / 100, 0, Style, 0, 0, false, 0) > 0 then begin
          incW(Spawn.Wave[Spawn.CurrentWave].Counter, -1);
          //if Spawn.TimeStarted > TimeLeft + MAX_ZOMBIES then
          //  if Spawn.Wave[Spawn.CurrentWave].Counter >= 7 then
          //    if Spawn.Wave[Spawn.CurrentWave].Counter mod 22 = 0 then
              // why isnt it displayed?
          //      BigText_DrawScreenX(DTL_NOTIFICATION, 0, WaveMessages[RandInt(0, MAXWAVEMESSAGES)], 300, Mode[Modes.RealCurrentMode].Color, 0.07, 20, 390);
        end;
      //exit;
      end else begin // otherwise reset the wave, go to the begining, try to find another one
        Spawn.Wave[Spawn.CurrentWave].Active := false;
        Spawn.CurrentWave := 0;
        goto pos1;
      end;
    end else begin // otherwise try to find another wave of spawn
      for i := 1 to MAX_SPAWNWAVES do
        if Spawn.Wave[i].Active then
          if Spawn.Wave[i].Counter > 0 then begin
            if ZombiesLeft > Spawn.Wave[i].ActivationNum then begin
              exit; // if there are too many zombies in game for the incoming wave then wait
            end;
            if Spawn.Wave[i].Style > 0 then begin
              Spawn_DrawWarning(Spawn.Wave[i].Style);
            end;
            PerformProgressCheck := true;
            found := true;
            //Spawn.TimeStarted := TimeLeft;
            Spawn.CurrentWave := i;
            Spawn.LastWave := i;
            //!!ref
            {$ifndef FPC}
            AZSS_OnSpawnWave(Spawn.Wave[Spawn.CurrentWave].Style);
            {$endif}
            break;
          end else Spawn.Wave[i].Active := false;
      if found then begin
        found := false;
        goto pos1; // if found one then go to the begining and keep spawning
      end else begin
        Spawn.Active := false; // if no more spawn waves left then stop spawning process
            //!!ref
        {$ifndef FPC}
        AZSS_OnSpawnWaveEnd();
        {$endif}
        PerformProgressCheck := true;
      end;
    end;
  end;
end;

procedure Spawn_DrawWarning(Style: byte);
begin
  case Style of
    1:if HackermanMode then begin
      FMSG_Draw('Trigger warning!', 5, $FF3728, WHITE);
    end else begin
      FMSG_Draw('Kamikaze zombies!', 5, $FF3728, WHITE);
    end;
    2:if HackermanMode then begin
      FMSG_Draw('This output stinks!', 5, $99CC33, WHITE);
    end else begin
      FMSG_Draw('Vomiting zombies!', 5, $99CC33, WHITE);
    end;
    3: if HackermanMode then begin
    FMSG_Draw('Compiler''s fault incoming!', 5, $22FF22, WHITE);
    end else begin
    FMSG_Draw('The Undead Butcher incoming!', 5, $FF96A0, WHITE);
    end;
    4: if HackermanMode then begin
    FMSG_Draw('Burning code!', 5, $FF7830, WHITE);
    end else begin
    FMSG_Draw('Burning zombies!', 5, $FF7830, WHITE);
    end;
    5: if HackermanMode then begin
      FMSG_Draw('Hackerman incoming!', 5, $22FF22, WHITE);  
    end else begin
      FMSG_Draw('The Perished Priest incoming!', 5, $A070E0, WHITE);      
    end;
    6: if HackermanMode then begin
      FMSG_Draw('Snapdragon 810 incoming!', 5, $CC0000, $FFCC00);
      WriteConsole(0, 'Its heat emission destroys everything!', $CC0000);
    end else begin
      FMSG_Draw('The Undead Firefighter incoming!', 5, $CC0000, $FFCC00);
      WriteConsole(0, 'Its heat emission destroys everything!', $CC0000);
              end;
    7:  if HackermanMode then begin
    FMSG_Draw('Windows 98 has been installed!', 4, $008080, WHITE);
    end else begin
    FMSG_Draw('Satan has come!', 4, $A52A2A, WHITE);
    end;
    8: if HackermanMode then begin
    FMSG_Draw('Windows 98 has been re-installed!', 4, $008080, WHITE);
    end else begin
    FMSG_Draw('Satan has returned!', 4, $A52A2A, WHITE);
    end;
    9: if HackermanMode then begin
    FMSG_Draw('A DDoS Attack incoming!', 5, $3F7F52, $42C3BB);
      WriteConsole(0, 'Blow them to pieces, so it won''t recall them!', $42C3BB);
       end else begin
      FMSG_Draw('The Plague incoming!', 5, $3F7F52, $42C3BB); 
      WriteConsole(0, 'Blow them to pieces, so it won''t recall them!', $42C3BB);
       end;  
  end;
end;

end.
