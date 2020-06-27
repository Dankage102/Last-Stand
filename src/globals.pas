//  * -------------- *
//  |    Globals     |
//  * -------------- *

// This is a part of {LS} Last Stand. Global constants and variables.

unit Globals;

interface


{$ifdef FPC}
uses
   Scriptcore;
{$endif}

	
type
	
	tTimer = record
		Value: longint;
		Cycle: integer;
	end;
	
var
	HackermanMode,
	PerformProgressCheck,
	ServerSetTeam,
	StartGame,
	PerformStartMatch,
	MapchangeStart,
	GameRunning: boolean;
	
	ZombiesInGame: byte;
	NumberOfWave,
	Civilians: word;
	
	CurrentMap2: string;
	
	Timer: tTimer;
	SurvPwnMeter, AvgSurvPwnMeter: single;
	
	MAXHEALTH,
	ZombiesKilled,
	ZombieHpInc,
	ZombieDmgInc,
	ZombieHpInit: integer;
	
	switchMapTime, switchMapMap: integer;
	PlayerLeft: boolean;

  ZombieFightTime: longint;

implementation

begin
end.
