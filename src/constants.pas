//  * ------------- *
//  |   Constants   |
//  * ------------- *

// This is a part of {LS} Last Stand
// The unit contains constants that matter for configuration purposes

unit Constants;

interface

//{$ifdef FPC}
//uses Scriptcore;
//{$endif}

const
  ADV_SITE = 'www.eat-that.tk';
  S_VERSION = '1.5.28';
	br = #13#10;

	// Colors
	INFORMATION = $B4B4BE;
	ADM_INT1 =    $6B8E23;
	YELLOW =      $FFFF00;
	GREEN =       $8EC163;
	RED =         $FF0000;
	B_RED =       $FFC8C8;
	WHITE =       $FFFFFF;
	SILVER =      $AAAAAA;
	PINK =        $FF66CC;
	MODEVOTE =    $FF6347;
	ORANGE =      $F4A460;
	SHORTCOMMAND= $32FFFF;
	BLUE =        $99CCFF;
	DT_CONSTRUCTION=$64FF64;
	DT_FAIL     = $FF5050;
	HINTCOL     = $F5FFFA;
	NWSCOL      = $BDB76B;
	NWSCOL_INACT = (NWSCOL and $FEFEFE) shr 1;	// divide col by 2
	EXO_COL     = $DEFF64;


	// Big text layers
	DTL_BLACKOUT = 255;
	DTL_RADAR = 10;
	DTL_MOLOTOV = 2;
	DTL_ZOMBIE_UI = 3;
	DTL_HEALING = 2;
	DTL_BOSS_HP = 3;
	DTL_COUNTDOWN = 4;
	DTL_WEAPONLIST = 7;
	DTL_WEAPONLIST2 = 8;
	DTL_FMSG = 9;
	DTL_NOTIFICATION = 10;
	DTL_CUSTOM = 32;

	WTL_RADAR = 1;
	WTL_CHARGES = 1;
	WTL_MARKER = 1;
	WTL_CUSTOM = 32;
    WTL_PLAGUE = 1;

	// Max number of objects on the map
	MAX_OBJECTS = 90;

	// Max number of spawns on the map (in fact it's 128 but let's assume we don't use all)
	MAX_SPAWNS = 64;

	MAX_ZOMBIES = 15; // max number of zombies spawned during the wave in one time

	MAX_UNITS = 	 32;

	ZOMBIETEAM =     1;
	HUMANTEAM =      2;

	MAX_STATS = 		8;
	V_MAX_STATS =	  1;

	
	// Debug
	DEBUGLEVEL = 20;
	
	// Map votes
	VOTEROUND =   true; // voting during a round;
	
	// Scarecrow
	SCARECROW_HITPOINTS = 160;
	
	// Wires
	WIREHITPOINTS = 88;
	WIREDMG = 10;
	
	// Costs
	MEDICOST =    2;
	NADECOST =    2;
	NADEPACK =    5;
	CLUSTERCOST = 1;
	STATCOST =    7;
	SENTRYCOST = 10;
	SENTRYAMMOCOST = 5;
	MINECOST =    3;
	MINEPACK =    6;
	CHARGECOST =  1;
	VESTCOST =    5;
	STRIKECOST =  5;
	HELICOST =    7;
	WATERCOST =   7;
	WATERML = 1000;
	SCARECROWCOST=2;
	WIRECOST =    4;
	MOLOTOVCOST = 4; // cost of pack with molotov cocktails for sharpshooter
	MOLOTOVPACK = 6; // number of molotovs in pack
	
	// Strikes
	STRIKETIME = 	  2;
	HELITIME   =      5;
	HELIATTACKTIME = 28;
	HELI_DMG =        6;
	
	
	// priest
	SHOWERCOST =       33;
	SPRINKLECOST =     10;
	EXO_RANGE1 =    100.0; // exo range with unmodified, full damage
	EXO_RANGE2 =    700.0; // total exo range (with fading damage with radius)
	EXOCOST =         100;
	EXODELAY =         30; // exorcism cooldown
	SHWDELAY =          5;
    SPRINKLE_DAMAGE =  10;
    SPRINKLE_NUM =      8;
	
	// Game
	DEATH_TIMER =  20; 
	
	MINVOTEMODEPERCENT = 60;
	
	DIFFICULTYPERCENT = 90; // global difficulty percent, influences on all difficulty levels;
							// 100->90. I normalized task damages to 1.0, and compensate it here.
	VERSUS_DP =        165; // VERSUS difficulty percent;
	SURVIVAL_DP = 	   140; // SURVIVAL difficulty precent;
	SURVIVAL_V_DP =    140; // SURVIVAL VETERAN diff. percent
	INFECTION_DP =	   155; // INFECTED difficulty percent;
	EQUALIZATIONDIFF  =120; // equalization of difficulty between all modes (don't touch);
	MAPSWITCHTIME =     90;

//	TIESCOREDIFFERENCE= 10; // maximal difference between scores in versus considered as a tie
//	TIEDAMAGEMP =      0.4; // multiplier of damage transferred into score in case of tie
  VSPOINTSFORCIV =     5; // points earned by zombies on flag grab in versus
  VSPOINTSFORWAVE =   20; // base for points earned by humans for surviving a wave
  VSPOINTSFORHEALTH = 15; // maximal points earned by humans for not getting damaged in a wave (pts = VSPOINTSFORHEALTH * healthleft/healthmax)
  SPECIALWAVEMP =    2.5; // multiplier of VSPOINTSFORWAVE for special waves
  SHOWPLAYERCOMMANDS = true;

  SUPPLYTIME =    11; // basic supply time (supply time = SUPPLYTIME + (SUPPLYTIME2 / NumberOfPlayers))
  SUPPLYTIME2 =    4; // divided by number of players (supply time = SUPPLYTIME + (SUPPLYTIME2 / NumberOfPlayers))

  FLAKCRITCHANCE=111; // chance for critical hit with flak (in permiles)
  FARMER_MRE_TIME= 130;

  // flame / molotov
  AREADMG =       10; // damage on area per second
  FLAMEAREADMG=  -11; //

  VOMIT_JUMP_CHANCE=30;
  BURNING_RANGE=300;
  ZOMBIE_JUMP_COOLDOWN=30;
  TICKING_BOMB_TIME = 3;


implementation
end.
