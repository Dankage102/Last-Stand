unit Scriptcore;

// This unit provides most of Soldat's Scriptcore2 and Scriptcore3 functions,
// constants, variables and classes in form of empty definitions.
// By "using" it in your script files you can develop your scripts under
// Pascal IDE like Lazaurs.
// Note: the unit must be included with preprocessor, so it stays visible for
// the IDE and the compiler and invisible for SoldatServer, for example:
//
// > {$ifdef FPC}
// > uses
// >	 Scriptcore;
// > {$endif}
//
// Some definitions may be missing since we could forget about something.
// 
// By tk and Falcon.

{$IFDEF FPC}{$mode delphi}{$ENDIF}
interface

 type
  // //////////////////////////// SC3 classes //////////////////////////////////
	TActiveBullet = class;
  TActiveFlag = class;
  TActiveMapObject = class;
  TActivePlayer = class;
  TActiveSpawnPoint = class;
	TBanLists = class;
  TFile = class;
  TGame = class;
	TGlobal = class;
	TIniFile = class;
  TMap = class;
	TMapsList = class;
  TNewMapObject = class;
  TNewWeapon = class;
  TPlayer = class;
  TPlayers = class;
  TPlayerWeapon = class;
	TScript = class;
	TSpawnPoint = class;
  TStream = class;
  TStringList = class;
  TTeam = class;
  TThing = class;
	TWeapon = class;

  TStringArray = array of string;

  TVector = record
    x, y: single;
  end;

  TValueSign = -1..1;
  TRoundToRange = -37..37;

  // //////////////////////////// SC3 enums ////////////////////////////////////
  TJoinType = (TJoinNormal, TJoinSilent);
  TKickReason = (TKickNoResponse, TKickNoCheatResponse,
		TKickChangeTeam, TKickPing, TKickFlooding, TKickConsole,
		TKickConnectionCheat, TKickCheat, TKickLeft, TKickVoted,
		TKickAC, TKickSilent
  );

  // //////////////////////////// SC3 events ///////////////////////////////////
  // Team
	TOnJoinTeam = procedure(Player: TActivePlayer; Team: TTeam);
  TOnLeaveTeam = procedure(Player: TActivePlayer; Team: TTeam; Kicked: Boolean);
  TOnClockTick = procedure(Ticks: Integer);
  TOnJoin = procedure(Player: TActivePlayer; Team: TTeam);
  TOnLeave = procedure(Player: TActivePlayer; Kicked: Boolean);

	// Game
	TOnRequest = function(Ip, Hw: string; Port: Word; State: Byte;
	 Forwarded: Boolean; Password: string): Integer;
  TOnAdminCommand = function(Player: TActivePlayer; Command: string): Boolean;
  TOnTCPMessage = procedure(Ip: string; Port: Word; Message: string);
  TOnTCPCommand = function(Ip: string; Port: Word; Command: string): Boolean;
  TOnAdminConnect = procedure(Ip: string; Port: Word);
  TOnAdminDisconnect = procedure(Ip: string; Port: Word);
	TOnBeforeMapChange = procedure(Next: string);
  TOnAfterMapChange = procedure(Next: string);

  // ActivePlayer
	TOnFlagGrab = procedure(Player: TActivePlayer; TFlag: TActiveFlag;
    Team: Byte; GrabbedInBase: Boolean);
  TOnFlagReturn = procedure(Player: TActivePlayer; Flag: TActiveFlag;
    Team: Byte);
  TOnFlagScore = procedure(Player: TActivePlayer; Flag: TActiveFlag;
    Team: Byte);
  TOnFlagDrop = procedure(Player: TActivePlayer; Flag: TActiveFlag;
    Team: Byte; Thrown: Boolean);
  TOnKitPickup = procedure(Player: TActivePlayer;
    Kit: TActiveMapObject);
  TOnBeforeRespawn = function(Player: TActivePlayer): Byte;
  TOnAfterRespawn = procedure(Player: TActivePlayer);
  TOnDamage = function(Shooter, Victim: TActivePlayer; Damage: Integer;
    BulletID: Byte): Integer;
  TOnKill = procedure(Killer, Victim: TActivePlayer;
    WeaponType: Byte);
  TOnWeaponChange = procedure(Player: TActivePlayer;
    Primary, Secondary: TPlayerWeapon);
  TOnVoteMapStart = function(Player: TActivePlayer;
    Map: string): Boolean;
  TOnVoteKickStart = function(Player, Victim: TActivePlayer;
    Reason: string): Boolean;
  TOnVoteMap = procedure(Player: TActivePlayer; Map: string);
  TOnVoteKick = procedure(Player, Victim: TActivePlayer);
  TOnSpeak = procedure(Player: TActivePlayer; Text: string);
  TOnCommand = function(Player: TActivePlayer; Command: string): Boolean;

	// Script
  TErrorType =
      (ErNoError, erCannotImport, erInvalidType, ErInternalError,
      erInvalidHeader, erInvalidOpcode, erInvalidOpcodeParameter, erNoMainProc,
      erOutOfGlobalVarsRange, erOutOfProcRange, ErOutOfRange, erOutOfStackRange,
      ErTypeMismatch, erUnexpectedEof, erVersionError, ErDivideByZero, ErMathError,
      erCouldNotCallProc, erOutofRecordRange, erOutOfMemory, erException,
      erNullPointerException, erNullVariantError, erInterfaceNotSupported, erCustomError);

  TOnException = function(ErrorCode: TErrorType; Message, UnitName, FunctionName: string;
    Row, Col: Cardinal): Boolean;


	////////////////////////////// SC3 classes ///////////////////////////////////
	// ------------------------------- Bullet ------------------------------------
  TActiveBullet = class(TObject)
  protected
    FID: Byte;
    function GetActive: Boolean;
    function GetID: Byte;
    function GetStyle: Byte;
    function GetX: Single;
    function GetY: Single;
    function GetVelX: Single;
    function GetVelY: Single;
    function GetOwner: Byte;
  public
    //constructor CreateActive(ID: Byte; var Bul: TBullet);
    function GetOwnerWeaponId: Integer;
    property Active: Boolean read GetActive;
    property ID: Byte read GetID;
    property Style: Byte read GetStyle;
    property X: Single read GetX;
    property Y: Single read GetY;
    property VelX: Single read GetVelX;
    property VelY: Single read GetVelY;
    property Owner: Byte read GetOwner;
  end;

	// ----------------------------- BanList -------------------------------------
  TBanHW = class(TObject)
	  HW: string; Time: Integer; Reason: string;
	end;

  TBanIP = class(TObject)
	  IP: string; Time: Integer; Reason: string;
	end;

	TBanLists = class(TObject)
  private
    function GetBannedHW(Num: Integer): TBanHW;
    function GetBannedIP(Num: Integer): TBanIP;
    function GetBannedHWCount: Integer;
    function GetBannedIPCount: Integer;
  public
    procedure AddHWBan(HW, Reason: string; Duration: Integer);
    procedure AddIPBan(IP: string; Reason: string; Duration: Integer);
    function DelHWBan(HW: string): Boolean;
    function DelIPBan(IP: string): Boolean;
    function IsBannedHW(HW: string): Boolean;
    function IsBannedIP(IP: string): Boolean;
    function GetHWBanId(HW: string): Integer;
    function GetIPBanId(IP: string): Integer;
    property HW[i: Integer]: TBanHW read GetBannedHW;
    property IP[i: Integer]: TBanIP read GetBannedIP;
    property BannedHWCount: Integer read GetBannedHWCount;
    property BannedIPCount: Integer read GetBannedIPCount;
  end;

  // --------------------------- File API --------------------------------------
  TStringList = class(TObject)
	public
	end;

	TIniFile = class(TObject)
	public
	end;

	TStream = class(TObject)
	public
	end;

  TFile = class(TObject)
  public
    //constructor Create(API: TScriptFileAPI);
    function CheckAccess(const FilePath: string): Boolean;
    function CreateFileStream(): TStream;
    function CreateFileStreamFromFile(const Path: string): TStream;
    function CreateStringList(): TStringList;
    function CreateStringListFromFile(const Path: string): TStringList;
    function CreateINI(const Path: string): TIniFile;
    function Exists(const Path: string): Boolean;
    function Copy(const Source, Destination: string): Boolean;
    function Move(const Source, Destination: string): Boolean;
    function Delete(const Path: string): Boolean;
  end;

  // -------------------------------- Game -------------------------------------
  TGame = class(TObject)
    private
      //FTeams: array [0..5] of TTeam;
      //FMapsList: TMapsList;
      //FBanLists: TBanLists;
      FOnClockTick: TOnClockTick;
      FOnJoin: TOnJoin;
      FOnLeave: TOnLeave;
      FOnRequest: TOnRequest;
      FOnAdminCommand: TOnAdminCommand;
      FOnTCPMessage: TOnTCPMessage;
      FOnTCPCommand: TOnTCPCommand;
      FOnAdminConnect: TOnAdminConnect;
      FOnAdminDisconnect: TOnAdminDisconnect;
      FTickThreshold: Longint;
      function GetGameStyle: Byte;
      procedure SetGameStyle(Style: Byte);
      function GetMaxPlayers: Byte;
      procedure SetMaxPlayers(Max: Byte);
      function GetNextMap: string;
      function GetCurrentMap: string;
      function GetNumBots: Byte;
      function GetNumPlayers: Byte;
      function GetSpectators: Byte;
      function GetScoreLimit: Word;
      procedure SetScoreLimit(Limit: Word);
      function GetServerIP: string;
      function GetServerName: string;
      function GetServerPort: Word;
      function GetServerVersion: string;
      function GetServerInfo: string;
      function GetGravity: Single;
      procedure SetGravity(Grav: Single);
      function GetPaused: Boolean;
      procedure SetPaused(Paused: Boolean);
      function GetRespawnTime: Integer;
      procedure SetRespawnTime(Time: Integer);
      function GetMinRespawnTime: Integer;
      procedure SetMinRespawnTime(Time: Integer);
      function GetMaxRespawnTime: Integer;
      procedure SetMaxRespawnTime(Time: Integer);
      function GetMaxGrenades: Byte;
      procedure SetMaxGrenades(Num: Byte);
      function GetBonus: Byte;
      procedure SetBonus(Num: Byte);
      function GetTimeLimit: Longint;
      procedure SetTimeLimit(Num: Longint);
      function GetTimeLeft: Longint;
      function GetFriendlyFire: Boolean;
      procedure SetFriendlyFire(Enabled: Boolean);
      function GetPassword: string;
      procedure SetPassword(Pass: string);
      function GetAdminPassword: string;
      procedure SetAdminPassword(Pass: string);
      function GetVotePercent: Byte;
      procedure SetVotePercent(Percent: Byte);
      function GetRealistic: Boolean;
      procedure SetRealistic(Enabled: Boolean);
      function GetSurvival: Boolean;
      procedure SetSurvival(Enabled: Boolean);
      function GetAdvance: Boolean;
      procedure SetAdvance(Enabled: Boolean);
      function GetBalance: Boolean;
      procedure SetBalance(Enabled: Boolean);
      function GetTickCount: Longint;
      function GetTeam(ID: Byte): TTeam;
      function GetMapsList: TMapsList;
      function GetBanLists: TBanLists;
    public
      constructor Create;
      procedure Shutdown;
      procedure StartVoteKick(ID: Byte; Reason: string);
      procedure StartVoteMap(Name: string);
      procedure Restart;
      function LoadWeap(WeaponMod: string): Boolean;
      function LoadCon(ConfigFile: string): Boolean;
      function LoadList(MapsList: string): Boolean;
      function LobbyRegister: Boolean;
      property GameStyle: Byte read GetGameStyle write SetGameStyle;
      property MaxPlayers: Byte read GetMaxPlayers write SetMaxPlayers;
      property NextMap: string read GetNextMap;
      property CurrentMap: string read GetCurrentMap;
      property NumBots: Byte read GetNumBots;
      property NumPlayers: Byte read GetNumPlayers;
      property Spectators: Byte read GetSpectators;
      property ScoreLimit: Word read GetScoreLimit write SetScoreLimit;
      property ServerIP: string read GetServerIP;
      property ServerName: string read GetServerName;
      property ServerPort: Word read GetServerPort;
      property ServerVersion: string read GetServerVersion;
      property ServerInfo: string read GetServerInfo;
      property Gravity: Single read GetGravity write SetGravity;
      property Paused: Boolean read GetPaused write SetPaused;
      property RespawnTime: Longint read GetRespawnTime write SetRespawnTime;
      property MinRespawnTime: Longint read GetMinRespawnTime write SetMinRespawnTime;
      property MaxRespawnTime: Longint read GetMaxRespawnTime write SetMaxRespawnTime;
      property MaxGrenades: Byte read GetMaxGrenades write SetMaxGrenades;
      property Bonus: Byte read GetBonus write SetBonus;
      property TimeLimit: Longint read GetTimeLimit write SetTimeLimit;
      property TimeLeft: Longint read GetTimeLeft;
      property FriendlyFire: Boolean read GetFriendlyFire write SetFriendlyFire;
      property Password: string read GetPassword write SetPassword;
      property AdminPassword: string read GetAdminPassword write SetAdminPassword;
      property VotePercent: Byte read GetVotePercent write SetVotePercent;
      property Realistic: Boolean read GetRealistic write SetRealistic;
      property Survival: Boolean read GetSurvival write SetSurvival;
      property Advance: Boolean read GetAdvance write SetAdvance;
      property Balance: Boolean read GetBalance write SetBalance;
      property TickThreshold: Longint read FTickThreshold write FTickThreshold;
      property TickCount: Longint read GetTickCount;
      property Teams[ID: Byte]: TTeam read GetTeam;
      property ScriptMapsList: TMapsList read GetMapsList;
      property ScriptBanLists: TBanLists read GetBanLists;
      property OnClockTick: TOnClockTick read FOnClockTick write FOnClockTick;
      property OnJoin: TOnJoin read FOnJoin write FOnJoin;
      property OnLeave: TOnLeave read FOnLeave write FOnLeave;
      property OnRequest: TOnRequest read FOnRequest write FOnRequest;
      property OnAdminCommand: TOnAdminCommand read FOnAdminCommand write FOnAdminCommand;
      property OnTCPMessage: TOnTCPMessage read FOnTCPMessage write FOnTCPMessage;
      property OnTCPCommand: TOnTCPCommand read FOnTCPCommand write FOnTCPCommand;
      property OnAdminConnect: TOnAdminConnect read FOnAdminConnect write FOnAdminConnect;
      property OnAdminDisconnect: TOnAdminDisconnect read FOnAdminDisconnect write FOnAdminDisconnect;
    end;

	// -------------------------------- Global -----------------------------------
  TGlobal = class(TObject)
  private
    function GetDateSeparator: Char;
    procedure SetDateSeparator(Separator: Char);
    function GetShortDateFormat: string;
    procedure SetShortDateFormat(Format: string);
  public
    property ScriptDateSeparator: Char read GetDateSeparator write SetDateSeparator;
    property ScriptShortDateFormat: string read GetShortDateFormat write SetShortDateFormat;
  end;

	// --------------------------------- Map -------------------------------------
  TMap = class(TObject)
    private
      //FObjects: array [1..128] of TActiveMapObject;
      //FBullets: array [1..256] of TActiveBullet;
      //FSpawnpoints: array [1..128] of TActiveSpawnPoint;
      //FLastFlagObjs: array [1..3] of TActiveFlag;
      FOnBeforeMapChange: TOnBeforeMapChange;
      FOnAfterMapChange: TOnAfterMapChange;
      function GetObject(ID: Byte): TActiveMapObject;
      function GetBullet(ID: Byte): TActiveBullet;
      function GetSpawn(ID: Byte): TSpawnPoint;
      procedure SetSpawn(ID: Byte; const Spawn: TSpawnPoint);
      function GetName: string;
    public
      constructor Create;
      function GetFlag(ID: Integer): TActiveFlag;
      function RayCast(x1, y1, x2, y2: Single; Player: Boolean = False;
        Flag: Boolean = False; Bullet: Boolean = True; CheckCollider: Boolean = False;
        Team: Byte = 0): Boolean;
      function RayCastVector(A, B: TVector; Player: Boolean = False;
        Flag: Boolean = False; Bullet: Boolean = True; CheckCollider: Boolean = False;
        Team: Byte = 0): Boolean;
      function CreateBulletVector(A, B: TVector; HitM: Single; sStyle: Byte;
			  Owner: TActivePlayer): Integer;
      function CreateBullet(X, Y, VelX, VelY, HitM: Single; sStyle: Byte; Owner: TActivePlayer): Integer;
      function AddObject(Obj: TNewMapObject): TActiveMapObject;
      function AddSpawnPoint(Spawn: TSpawnPoint): TActiveSpawnPoint;
      procedure NextMap;
      procedure SetMap(NewMap: string);
      property Objects[ID: Byte]: TActiveMapObject read GetObject;
      property Bullets[ID: Byte]: TActiveBullet read GetBullet;
      property Spawns[ID: Byte]: TSpawnPoint read GetSpawn write SetSpawn;
      property Name: string read GetName;
      property RedFlag: TActiveFlag index 1 read GetFlag;
      property BlueFlag: TActiveFlag index 2 read GetFlag;
      property YellowFlag: TActiveFlag index 3 read GetFlag;
      property OnBeforeMapChange: TOnBeforeMapChange
        read FOnBeforeMapChange write FOnBeforeMapChange;
      property OnAfterMapChange: TOnAfterMapChange
        read FOnAfterMapChange write FOnAfterMapChange;
    end;

	// ----------------------------- Maplist -------------------------------------
  TMapsList = class(TObject)
  private
    function GetMap(Num: Integer): string;
    function GetCurrentMapId: Integer;
    procedure SetCurrentMapId(NewNum: Integer);
    function GetMapsCount: Integer;
  public
    procedure AddMap(Name: string);
    procedure RemoveMap(Name: string);
    function GetMapIdByName(Name: string): Integer;
    property Map[i: Integer]: string read GetMap; default;
    property CurrentMapId: Integer read GetCurrentMapId write SetCurrentMapId;
    property MapsCount: Integer read GetMapsCount;
  end;

  // ------------------------------- Math --------------------------------------
  TMath = class
  private
    function GetE: Extended;
    function GetPi: Extended;
  public
    function Sin(A: Extended): Extended;
    function Cos(A: Extended): Extended;
    function Tan(A: Extended): Extended;
    function Cotan(A: Extended): Extended;
    function Pow(A, B: Extended): Extended;
    function LogN(A, B: Extended): Extended;
    function Ln(A: Extended): Extended;
    function ArcSin(A: Extended): Extended;
    function ArcCos(A: Extended): Extended;
    function ArcTan(A: Extended): Extended;
    function ArcCotan(A: Extended): Extended;
    function ArcTan2(A, B: Extended): Extended;
    function Min(A, B: Extended): Extended;
    function Max(A, B: Extended): Extended;
    function Abs(A: Extended): Extended;
    function Exp(A: Extended): Extended;
    function Sign(A: Extended): TValueSign;
    function IsNaN(A: Extended): Boolean;
    function Round(A: Extended): Integer;
    function RoundTo(A: Extended; B: TRoundToRange): Extended;
    function DegToRad(A: Extended): Extended;
    function RadToDeg(A: Extended): Extended;
    function DegNormalize(A: Extended): Extended;
    function InRange(const A, B, C: Double): Boolean;
    function EnsureRange(const AValue, AMin, AMax: Double): Double;
    function Random(Min, Max: Extended): Extended;
    property E: Extended read GetE;
    property Pi: Extended read GetPi;
  end;

  // ------------------------------ Object -------------------------------------
	TThing = class(TObject)
  protected
    //FObj: PThing;
    function GetStyle: Byte; virtual; abstract;
    function GetX: Single;
    function GetY: Single;
  public
    property Style: Byte read GetStyle;
    property X: Single read GetX;
    property Y: Single read GetY;
  end;

  TNewMapObject = class(TThing)
  protected
    function GetStyle: Byte; override;
    procedure SetStyle(Style: Byte);
    procedure SetX(X: Single);
    procedure SetY(Y: Single);
  public
    constructor Create;
    destructor Destroy; override;
    property Style: Byte read GetStyle write SetStyle;
    property X: Single read GetX write SetX;
    property Y: Single read GetY write SetY;
  end;

  TActiveMapObject = class(TThing)
  protected
    FID: Byte;
    function GetActive: Boolean;
    function GetID: Byte;
    function GetStyle: Byte; override;
  public
    //constructor CreateActive(ID: Byte; var Obj: TThing);
    procedure Kill;
    property Active: Boolean read GetActive;
    property ID: Byte read GetID;
  end;

  TActiveFlag = class(TActiveMapObject)
  private
    function GetInBase: Boolean;
  public
    property InBase: Boolean read GetInBase;
  end;

  // ------------------------------ Player -------------------------------------
  TPlayer = class(TObject)
    protected
      FPrimary: TWeapon;
      FSecondary: TWeapon;
      //function GetSprite: TSprite;
      function GetTeam: Byte;
      function GetName: string;
      function GetAlive: Boolean;
      function GetHealth: Single;
      procedure SetHealth(Health: Single);
      function GetVest: Single;
      procedure SetVest(Vest: Single);
      function GetPrimary: TPlayerWeapon;
      function GetSecondary: TPlayerWeapon;
      function GetShirtColor: Longword;
      function GetPantsColor: Longword;
      function GetSkinColor: Longword;
      function GetHairColor: Longword;
      function GetFavouriteWeapon: string;
      procedure SetFavouriteWeapon(Weapon: string);
      function GetChosenSecondaryWeapon: Byte;
      function GetFriend: string;
      procedure SetFriend(Friend: string);
      function GetAccuracy: Byte;
      procedure SetAccuracy(Accuracy: Byte);
      function GetShootDead: Boolean;
      procedure SetShootDead(ShootDead: Boolean);
      function GetGrenadeFrequency: Byte;
      procedure SetGrenadeFrequency(Frequency: Byte);
      function GetCamping: Boolean;
      procedure SetCamping(Camping: Boolean);
      function GetOnStartUse: Byte;
      procedure SetOnStartUse(Thing: Byte);
      function GetHairStyle: Byte;
      function GetHeadgear: Byte;
      function GetChain: Byte;
      function GetChatFrequency: Byte;
      procedure SetChatFrequency(Frequency: Byte);
      function GetChatKill: string;
      procedure SetChatKill(Message: string);
      function GetChatDead: string;
      procedure SetChatDead(Message: string);
      function GetChatLowHealth: string;
      procedure SetChatLowHealth(Message: string);
      function GetChatSeeEnemy: string;
      procedure SetChatSeeEnemy(Message: string);
      function GetChatWinning: string;
      procedure SetChatWinning(Message: string);
      function GetAdmin: Boolean;
      procedure SetAdmin(SetAsAdmin: Boolean);
      function GetDummy: Boolean;
      procedure SetDummy(Dummy: Boolean);
    public
      destructor Destroy; override;
      //Not exported
      //property Sprite: TSprite read GetSprite;
      property Team: Byte read GetTeam;
      property Name: string read GetName;
      property Alive: Boolean read GetAlive;
      property Health: Single read GetHealth write SetHealth;
      property Vest: Single read GetVest write SetVest;
      property Primary: TPlayerWeapon read GetPrimary;
      property Secondary: TPlayerWeapon read GetSecondary;
      property ShirtColor: Longword read GetShirtColor;
      property PantsColor: Longword read GetPantsColor;
      property SkinColor: Longword read GetSkinColor;
      property HairColor: Longword read GetHairColor;
      property FavouriteWeapon: string read GetFavouriteWeapon write SetFavouriteWeapon;
      property ChosenSecondaryWeapon: Byte read GetChosenSecondaryWeapon;
      property Friend: string read GetFriend write SetFriend;
      property Accuracy: Byte read GetAccuracy write SetAccuracy;
      property ShootDead: Boolean read GetShootDead write SetShootDead;
      property GrenadeFrequency: Byte read GetGrenadeFrequency write SetGrenadeFrequency;
      property Camping: Boolean read GetCamping write SetCamping;
      property OnStartUse: Byte read GetOnStartUse write SetOnStartUse;
      property HairStyle: Byte read GetHairStyle;
      property Headgear: Byte read GetHeadgear;
      property Chain: Byte read GetChain;
      property ChatFrequency: Byte read GetChatFrequency write SetChatFrequency;
      property ChatKill: string read GetChatKill write SetChatKill;
      property ChatDead: string read GetChatDead write SetChatDead;
      property ChatLowHealth: string read GetChatLowHealth write SetChatLowHealth;
      property ChatSeeEnemy: string read GetChatSeeEnemy write SetChatSeeEnemy;
      property ChatWinning: string read GetChatWinning write SetChatWinning;
      property IsAdmin: Boolean read GetAdmin write SetAdmin;
      property Dummy: Boolean read GetDummy write SetDummy;
    end;

    TNewPlayer = class(TPlayer)
    protected
      procedure SetName(Name: string);
      procedure SetTeam(Team: Byte);
      procedure SetHealth(Health: Single);
      function GetPrimary: TWeapon;
      procedure SetPrimary(Primary: TWeapon);
      function GetSecondary: TWeapon;
      procedure SetSecondary(Secondary: TWeapon);
      procedure SetShirtColor(Color: Longword);
      procedure SetPantsColor(Color: Longword);
      procedure SetSkinColor(Color: Longword);
      procedure SetHairColor(Color: Longword);
      procedure SetHairStyle(Style: Byte);
      procedure SetHeadgear(Headgear: Byte);
      procedure SetChain(Chain: Byte);
      function GetDummy: Boolean;
      procedure SetDummy(Dummy: Boolean);
    public
      constructor Create;
      property Name: string read GetName write SetName;
      property Team: Byte read GetTeam write SetTeam;
      property Health: Single read GetHealth write SetHealth;
      property Primary: TWeapon read GetPrimary write SetPrimary;
      property Secondary: TWeapon read GetSecondary write SetSecondary;
      property ShirtColor: Longword read GetShirtColor write SetShirtColor;
      property PantsColor: Longword read GetPantsColor write SetPantsColor;
      property SkinColor: Longword read GetSkinColor write SetSkinColor;
      property HairColor: Longword read GetHairColor write SetHairColor;
      property HairStyle: Byte read GetHairStyle write SetHairStyle;
      property Headgear: Byte read GetHeadgear write SetHeadgear;
      property Chain: Byte read GetChain write SetChain;
      property Dummy: Boolean read GetDummy write SetDummy;
    end;

    TActivePlayer = class(TPlayer)
    private
      FID: Byte;
      FOnFlagGrab: TOnFlagGrab;
      FOnFlagReturn: TOnFlagReturn;
      FOnFlagScore: TOnFlagScore;
      FOnFlagDrop: TOnFlagDrop;
      FOnKitPickup: TOnKitPickup;
      FOnBeforeRespawn: TOnBeforeRespawn;
      FOnAfterRespawn: TOnAfterRespawn;
      FOnDamage: TOnDamage;
      FOnKill: TOnKill;
      FOnWeaponChange: TOnWeaponChange;
      FOnVoteMapStart: TOnVoteMapStart;
      FOnVoteKickStart: TOnVoteKickStart;
      FOnVoteMap: TOnVoteMap;
      FOnVoteKick: TOnVoteKick;
      FOnSpeak: TOnSpeak;
      FOnCommand: TOnCommand;
    protected
      function GetKills: Integer;
      procedure SetKills(Kills: Integer);
      function GetDeaths: Integer;
      function GetPing: Integer;
      procedure SetTeam(Team: Byte);
      function GetActive: Boolean;
      procedure SetAlive(Alive: Boolean);
      function GetIP: string;
      function GetPort: Word;
      function GetVelX: Single;
      function GetVelY: Single;
      function GetMuted: Boolean;
      procedure SetMuted(Muted: Boolean);
      function GetJets: Integer;
      function GetGrenades: Byte;
      function GetX: Single;
      function GetY: Single;
      function GetMouseAimX: SmallInt;
      procedure SetMouseAimX(AimX: SmallInt);
      function GetMouseAimY: SmallInt;
      procedure SetMouseAimY(AimY: SmallInt);
      function GetFlagger: Boolean;
      function GetTime: Integer;
      function GetOnGround: Boolean;
      function GetProne: Boolean;
      function GetHuman: Boolean;
      function GetDirection: Shortint;
      function GetFlags: Byte;
      function GetHWID: string;
      function GetKeyUp: Boolean;
      procedure SetKeyUp(Pressed: Boolean);
      function GetKeyLeft: Boolean;
      procedure SetKeyLeft(Pressed: Boolean);
      function GetKeyRight: Boolean;
      procedure SetKeyRight(Pressed: Boolean);
      function GetKeyShoot: Boolean;
      procedure SetKeyShoot(Pressed: Boolean);
      function GetKeyJetpack: Boolean;
      procedure SetKeyJetpack(Pressed: Boolean);
      function GetKeyGrenade: Boolean;
      procedure SetKeyGrenade(Pressed: Boolean);
      function GetKeyChangeWeap: Boolean;
      procedure SetKeyChangeWeap(Pressed: Boolean);
      function GetKeyThrow: Boolean;
      procedure SetKeyThrow(Pressed: Boolean);
      function GetKeyReload: Boolean;
      procedure SetKeyReload(Pressed: Boolean);
      function GetKeyCrouch: Boolean;
      procedure SetKeyCrouch(Pressed: Boolean);
      function GetKeyProne: Boolean;
      procedure SetKeyProne(Pressed: Boolean);
      function GetKeyFlagThrow: Boolean;
      procedure SetKeyFlagThrow(Pressed: Boolean);
      procedure SetWeaponActive(ID: Byte; Active: Boolean);
    public
      //constructor Create(var Sprite: TSprite; ID: Byte); overload;
      function Ban(Time: Integer; Reason: string): Boolean;
      procedure Say(Text: string);
      procedure Damage(Shooter: Byte; Damage: Integer);
      procedure BigText(Layer: Byte; Text: string; Delay: Integer;
        Color: Longint; Scale: Single; X, Y: Integer);
      procedure WorldText(Layer: Byte; Text: string; Delay: Integer;
        Color: Longint; Scale, X, Y: Single);
      procedure ForceWeapon(Primary, Secondary: TNewWeapon);
      procedure ForwardTo(TargetIP: string; TargetPort: Word; Message: string);
      procedure GiveBonus(BType: Byte);
      function Kick(reason: TKickReason): Boolean;
      procedure ChangeTeam(NewTeam: Byte; JoinType: TJoinType);
      procedure Move(X, Y: Single);
      procedure SetVelocity(VelX, VelY: Single);
      procedure Tell(Text: string);
      procedure WriteConsole(Text: string; Color: Longint);
      property ID: Byte read FID;
      property Team: Byte read GetTeam write SetTeam;
      property Alive: Boolean read GetAlive;
      property Kills: Integer read GetKills write SetKills;
      property Deaths: Integer read GetDeaths;
      property Ping: Integer read GetPing;
      property Active: Boolean read GetActive;
      property IP: string read GetIP;
      property Port: Word read GetPort;
      property VelX: Single read GetVelX;
      property VelY: Single read GetVelY;
      property Muted: Boolean read GetMuted write SetMuted;
      property Jets: Integer read GetJets;
      property Grenades: Byte read GetGrenades;
      property X: Single read GetX;
      property Y: Single read GetY;
      property MouseAimX: SmallInt read GetMouseAimX write SetMouseAimX;
      property MouseAimY: SmallInt read GetMouseAimY write SetMouseAimY;
      property Flagger: Boolean read GetFlagger;
      property Time: Integer read GetTime;
      property OnGround: Boolean read GetOnGround;
      property IsProne: Boolean read GetProne;
      property Human: Boolean read GetHuman;
      property Direction: Shortint read GetDirection;
      property Flags: Byte read GetFlags;
      property HWID: string read GetHWID;
      property KeyUp: Boolean read GetKeyUp write SetKeyUp;
      property KeyLeft: Boolean read GetKeyLeft write SetKeyLeft;
      property KeyRight: Boolean read GetKeyRight write SetKeyRight;
      property KeyShoot: Boolean read GetKeyShoot write SetKeyShoot;
      property KeyJetpack: Boolean read GetKeyJetpack write SetKeyJetpack;
      property KeyGrenade: Boolean read GetKeyGrenade write SetKeyGrenade;
      property KeyChangeWeap: Boolean read GetKeyChangeWeap write SetKeyChangeWeap;
      property KeyThrow: Boolean read GetKeyThrow write SetKeyThrow;
      property KeyReload: Boolean read GetKeyReload write SetKeyReload;
      property KeyCrouch: Boolean read GetKeyCrouch write SetKeyCrouch;
      property KeyProne: Boolean read GetKeyProne write SetKeyProne;
      property KeyFlagThrow: Boolean read GetKeyFlagThrow write SetKeyFlagThrow;
      property WeaponActive[ID: Byte]: Boolean write SetWeaponActive;
      property OnFlagGrab: TOnFlagGrab read FOnFlagGrab write FOnFlagGrab;
      property OnFlagReturn: TOnFlagReturn read FOnFlagReturn write FOnFlagReturn;
      property OnFlagScore: TOnFlagScore read FOnFlagScore write FOnFlagScore;
      property OnFlagDrop: TOnFlagDrop read FOnFlagDrop write FOnFlagDrop;
      property OnKitPickup: TOnKitPickup read FOnKitPickup write FOnKitPickup;
      property OnBeforeRespawn: TOnBeforeRespawn
        read FOnBeforeRespawn write FOnBeforeRespawn;
      property OnAfterRespawn: TOnAfterRespawn read FOnAfterRespawn write FOnAfterRespawn;
      property OnDamage: TOnDamage read FOnDamage write FOnDamage;
      property OnKill: TOnKill read FOnKill write FOnKill;
      property OnWeaponChange: TOnWeaponChange read FOnWeaponChange write FOnWeaponChange;
      property OnVoteMapStart: TOnVoteMapStart read FOnVoteMapStart write FOnVoteMapStart;
      property OnVoteKickStart: TOnVoteKickStart
        read FOnVoteKickStart write FOnVoteKickStart;
      property OnVoteMap: TOnVoteMap read FOnVoteMap write FOnVoteMap;
      property OnVoteKick: TOnVoteKick read FOnVoteKick write FOnVoteKick;
      property OnSpeak: TOnSpeak read FOnSpeak write FOnSpeak;
      property OnCommand: TOnCommand read FOnCommand write FOnCommand;
    end;

	// ------------------------------ Players ------------------------------------
  TPlayers = class(TObject)
    private
      //FPlayers: array [1..32] of TActivePlayer;
      function GetPlayer(ID: Byte): TActivePlayer;
    public
      constructor Create;
      destructor Destroy; override;
      function Add(Player: TNewPlayer; jointype: TJoinType): TActivePlayer;
      procedure WriteConsole(Text: string; Color: Longint);
      procedure BigText(Layer: Byte; Text: string; Delay: Integer;
        Color: Longint; Scale: Single; X, Y: Integer);
      procedure WorldText(Layer: Byte; Text: string; Delay: Integer;
        Color: Longint; Scale, X, Y: Single);
      function GetByName(Name: string): TActivePlayer;
      function GetByIP(IP: string): TActivePlayer;
      procedure Tell(Text: string);

      property Player[ID: Byte]: TActivePlayer read GetPlayer; default;
    end;

	// -------------------------------- Script -----------------------------------
	TScript = class(TObject)
  private
    FOnException: TOnException;
    function GetName: string;
    function GetVersion: string;
    function GetDir: string;
    function GetDebugMode: Boolean;
  public
    //constructor Create(Script: TScript);
    procedure Recompile(Force: Boolean);
    procedure Unload;
    property Name: string read GetName;
    property Version: string read GetVersion;
    property Dir: string read GetDir;
    property DebugMode: Boolean read GetDebugMode;
    property OnException: TOnException read FOnException write FOnException;
  end;

  // ---------------------------- SpawnPoint -----------------------------------
	TSpawnPoint = class(TObject)
  protected
    function GetActive: Boolean;
    procedure SetActive(Active: Boolean);
    function GetX: Longint;
    procedure SetX(X: Longint);
    function GetY: Longint;
    procedure SetY(Y: Longint);
    function GetStyle: Byte;
    procedure SetStyle(Style: Byte);
  public
    property Active: Boolean read GetActive write SetActive;
    property X: Longint read GetX write SetX;
    property Y: Longint read GetY write SetY;
    property Style: Byte read GetStyle write SetStyle;
  end;

  TNewSpawnPoint = class(TSpawnPoint)
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TActiveSpawnPoint = class(TSpawnPoint)
  private
    FID: Byte;
  public
    //constructor CreateActive(ID: Byte; var Spawn: TMapSpawnPoint);
    property ID: Byte read FID;
  end;

  // ------------------------------- Team --------------------------------------
  TTeam = class(TObject)
  private
    //FPlayers: TList;
    FID: Byte;
    FOnJoin: TOnJoinTeam;
    FOnLeave: TOnLeaveTeam;
    function GetScore: Byte;
    procedure SetScore(Score: Byte);
    function GetPlayer(Num: Byte): TPlayer;
    function GetCount: Byte;
  public
    constructor Create(ID: Byte);
    destructor Destroy; override;
    procedure AddPlayer(Player: TPlayer);
    procedure RemovePlayer(Player: TPlayer);

    procedure Add(Player: TPlayer);
    property Score: Byte read GetScore write SetScore;
    property Player[i: Byte]: TPlayer read GetPlayer; default;
    property Count: Byte read GetCount;
    property ID: Byte read FID;
    property OnJoin: TOnJoinTeam read FOnJoin write FOnJoin;
    property OnLeave: TOnLeaveTeam read FOnLeave write FOnLeave;
  end;

	// -------------------------------- Weapon -----------------------------------
	TWeapon = class(TObject)
  protected
    //FWeapon: PGun;
    //function GetGun: TGun;
    function GetType: Byte;
    function GetName: string;
    function GetBulletStyle: Byte;
    function GetAmmo: Byte;
    procedure SetAmmo(Ammo: Byte); virtual; abstract;
  public
    //property Gun: TGun read GetGun;

    property WType: Byte read GetType;
    property Name: string read GetName;
    property BulletStyle: Byte read GetBulletStyle;
    property Ammo: Byte read GetAmmo write SetAmmo;
  end;

	TPlayerWeapon = class(TWeapon)
  protected
    procedure SetAmmo(Ammo: Byte); override;
  public
    //constructor Create(var Sprite: TSprite); override;
  end;

  TNewWeapon = class(TWeapon)
  private
    procedure SetType(WType: Byte);
  protected
    procedure SetAmmo(Ammo: Byte); override;
  public
    constructor Create;
    destructor Destroy; override;
    property WType: Byte read GetType write SetType;
  end;

const
  // These number don't have to be correct, it's just to satisfy the FPC.
  WTYPE_EAGLE = 0;
  WTYPE_MP5 = 1;
  WTYPE_AK74 = 2;
  WTYPE_STEYRAUG = 3;
  WTYPE_SPAS12 = 4;
  WTYPE_RUGER77 = 5;
  WTYPE_M79 = 6;
  WTYPE_BARRETT = 7;
  WTYPE_M249 = 8;
  WTYPE_MINIGUN = 9;
  WTYPE_USSOCOM = 10;
  WTYPE_KNIFE = 11;
  WTYPE_CHAINSAW = 12;
  WTYPE_LAW = 13;
  WTYPE_FLAMER = 14;
  WTYPE_BOW = 15;
  WTYPE_BOW2 = 16;
  WTYPE_M2 = 17;
  WTYPE_NOWEAPON = 18;
  WTYPE_FRAGGRENADE = 19;
  WTYPE_CLUSTERGRENADE = 20;
  WTYPE_CLUSTER = 21;
  WTYPE_THROWNKNIFE = 22;

var
  // SC3
	Map: TMap;
	//File: TFile;
	Game: TGame;
	Global: TGlobal;
  Math: TMath;
  Players: TPlayers;
  Script: TScript;

  // SC2
  CoreVersion: string;
  ScriptName: string;
  SafeMode: Byte;
  MaxPlayers: Byte;
  NumPlayers: Byte;
  NumBots: Byte;
  CurrentMap: string;
  NextMap: string;
  TimeLimit: Integer;
  TimeLeft: Integer;
  ScoreLimit: Integer;
  GameStyle: Byte;
  Version: string;
  ServerVersion: string;
  ServerName: string;
  ServerIP: string;
  ServerPort: Integer;
  DeathmatchPlayers: Byte;
  Spectators: Byte;
  AlphaPlayers: Byte;
  BravoPlayers: Byte;
  CharliePlayers: Byte;
  DeltaPlayers: Byte;
  AlphaScore: Byte;
  BravoScore: Byte;
  CharlieScore: Byte;
  DeltaScore: Byte;
  ReqPort: Word;
  Paused: Boolean;
  Password: string;
  DisableScript: Boolean;
  AppOnIdleTimer: LongWord;
  ExceptionType, ExceptionParam: integer;

///////////////////////////////  Functions /////////////////////////////////////

function weap2obj(Style: Byte): Byte;

function menu2obj(Style: Byte): Byte;

function obj2weap(Style: Byte): Byte;

function obj2menu(Style: Byte): Byte;

function weap2menu(Style: Byte): Byte;

function menu2weap(Style: Byte): Byte;

function FileExists(FileName: String): Boolean;

function GetURL(Url: String): String;

procedure DrawTextEx(Id, Num: Byte; Text: String; Delay: Integer;
  Colour: Longint; Scale: Single; X, Y: Integer);

procedure DrawText(Id: Byte; Text: String; Delay: Integer; Colour: Longint;
  Scale: Single; X, Y: Integer);

function ReadFile(FileName: String): String;

function RGB(R, G, B: Byte): Cardinal;

function RayCast(P1X, P1Y, P2X, P2Y: Single; var Distance: Single;
  MaxDist: Single): Boolean;

function RayCastEx(P1X, P1Y, P2X, P2Y: Single; var Distance: Single;
  MaxDist: Single; Player, Flag, Bullet, Collider: Boolean; Team: Byte): Boolean;

function ArrayHigh(Arr: array of String): Integer;

function WeaponNameByNum(Num: Integer): string;

procedure ForceWeapon(A, B, C, D: Byte);

procedure ForceWeaponEx(A, B, C, D, E: Byte);

procedure SetScore(Id: Byte; Score: Integer);

procedure SetTeamScore(Team: Byte; Score: Integer);

procedure KickPlayer(Num: Byte);

function GetTickCount: Cardinal;

function arctan(Num: Extended): Extended;

function LogN(base, x: double): double;

function CreateBullet(X, Y, VelX, VelY, HitM: Single; sStyle, Owner: Byte): Integer;

function CreateObject(X, Y: Single; BType: Byte): Integer;

procedure KillObject(Id: Integer);

procedure GiveBonus(Id, Bonus: Byte);

function Random(Min, Max: Integer): Integer;

function RegExpMatch(RegularExpression, Source: String): Boolean;

function RegExpReplace(RegularExpression, Source, ReplaceText: String): String;

function FormatDate(Format: String): String;

function IDToIP(Id: Byte): String;

function IDToHW(Id: Byte): String;

procedure BanPlayer(Num: Byte; Time: Integer);

procedure BanPlayerReason(Num: Byte; Time: Integer; Reason: String);

function Command(Cmd: String): Variant;

procedure SendStringToPlayer(Id: Byte; Text: String);

procedure BotChat(Id: Byte; Text: String);

procedure Sleep(Milliseconds: Cardinal);

function GetSystem: String;

function GetPlayerStat(Id: Byte; Stat: String): Variant;

function GetKeyPress(Id: Byte; Key: String): Boolean;

function GetObjectStat(Id: Byte; Stat: String): Variant;

function GetSpawnStat(Id: Byte; Stat: String): Variant;

procedure SetSpawnStat(Id: Byte; Stat: String; Value: Variant);

procedure DoDamage(Id: Byte; Damage: Integer);

procedure DoDamageBy(Id, Shooter: Byte; Damage: Integer);

procedure GetPlayerXY(Id: Byte; var X, Y: Single);

procedure GetFlagsXY(var BlueFlagX, BlueFlagY, RedFlagX, RedFlagY: Single);

procedure GetFlagsSpawnXY(var BlueFlagX, BlueFlagY, RedFlagX, RedFlagY: Single);

procedure StartVoteKick(Target: Byte; Reason: String);

procedure StartVoteMap(Mapname, Reason: String);

function Sqrt(Number: Extended): Extended;

function Round(const Number: Variant): Int64;

function RoundTo(const AValue: Extended; ADigit: Integer): Extended;

function GetPiece(const Input, Splitter: String; Index: Integer): String;

function WriteFile(FileName: String; SData: String): Boolean;

procedure WriteLn(const Data: String);

//function Length(S: String): Integer;

procedure Inc(var X: Integer; N: Integer);

procedure Dec(var X: Integer; N: Integer);

function CrossFunc(const Params: array of Variant; ProcName: String): Variant;

procedure WriteConsole(ID: byte; Text: string; Color: Cardinal);

procedure SetArrayLength(arr: array of string; len: integer);  overload;

function GetArrayLength(arr: array of string): integer;  overload;

function StrToInt(s: string): integer;

function StrToIntDef(s: string; default: integer): integer;

function ContainsString(haystack, needle: string): boolean;

procedure RaiseException(code: integer; msg: string);

function IntToStr(x: integer): string;

function FloatToStr(x: Extended): string;

function StrPos(const A, S: string): Integer;

function StrReplace(const A, B, C: string): string;

function HTTPEncode(A: string): string;

function HTTPDecode(A: string): string;

function shell_exec(A: string): Integer;

function Distance(x1, y1, x2, y2: single): single;

function iif(cond: boolean; t, f: variant): variant;

procedure PlaySound(ID: byte; name: string; x, y: single);

function FormatFloat(format: string; float: double): string;

procedure ServerModifier(what: string; param: variant);

procedure MovePlayer(ID: byte; x, y: single);

function  ExceptionToString(ex_type, ex_param: integer): string;

procedure ShutDown();

function GetStringIndex(arg1: string; arg2: array of string): Integer;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

implementation

function weap2obj(Style: Byte): Byte;
begin
  Result := 0;
end;

function menu2obj(Style: Byte): Byte;
begin
  Result := 0;
end;

function obj2weap(Style: Byte): Byte;
begin
  Result := 0;
end;

function obj2menu(Style: Byte): Byte;
begin
  Result := 0;
end;

function weap2menu(Style: Byte): Byte;
begin
  Result := 0;
end;

function menu2weap(Style: Byte): Byte;
begin
  Result := 0;
end;

function FileExists(FileName: String): Boolean;
begin
  Result := false;
end;

function GetURL(Url: String): String;
begin
  Result := '';
end;

procedure DrawTextEx(Id, Num: Byte; Text: String; Delay: Integer;
  Colour: Longint; Scale: Single; X, Y: Integer);
begin
end;

procedure DrawText(Id: Byte; Text: String; Delay: Integer; Colour: Longint;
  Scale: Single; X, Y: Integer);
begin
end;

function ReadFile(FileName: String): String;
begin
  Result := '';
end;

function RGB(R, G, B: Byte): Cardinal;
begin
  Result := 0;
end;

function RayCast(P1X, P1Y, P2X, P2Y: Single; var Distance: Single;
  MaxDist: Single): Boolean;
begin
  Result := false;
end;

function RayCastEx(P1X, P1Y, P2X, P2Y: Single; var Distance: Single;
  MaxDist: Single; Player, Flag, Bullet, Collider: Boolean; Team: Byte): Boolean;
begin
  Result := false;
end;

function ArrayHigh(Arr: array of String): Integer;
begin
  Result := 0;
end;

function WeaponNameByNum(Num: Integer): string;
begin
  Result := '';
end;

procedure ForceWeapon(A, B, C, D: Byte);
begin
end;

procedure ForceWeaponEx(A, B, C, D, E: Byte);
begin
end;

procedure SetScore(Id: Byte; Score: Integer);
begin
end;

procedure SetTeamScore(Team: Byte; Score: Integer);
begin
end;

procedure KickPlayer(Num: Byte);
begin
end;

function GetTickCount: Cardinal;
begin
  Result := 0;
end;

function arctan(Num: Extended): Extended;
begin
  Result := 0;
end;

function LogN(base, x: double): double;
begin
  Result := 0;
end;

function CreateBullet(X, Y, VelX, VelY, HitM: Single; sStyle, Owner: Byte): Integer;
begin
  Result := 0;
end;

function CreateObject(X, Y: Single; BType: Byte): Integer;
begin
  Result := 0;
end;

procedure KillObject(Id: Integer);
begin
end;

procedure GiveBonus(Id, Bonus: Byte);
begin
end;

function Random(Min, Max: Integer): Integer;
begin
  Result := 0;
end;

function RegExpMatch(RegularExpression, Source: String): Boolean;
begin
  Result := false;
end;

function RegExpReplace(RegularExpression, Source, ReplaceText: String): String;
begin
  Result := '';
end;

function FormatDate(Format: String): String;
begin
  Result := '';
end;

function IDToIP(Id: Byte): String;
begin
  Result := '';
end;

function IDToHW(Id: Byte): String;
begin
  Result := '';
end;

procedure BanPlayer(Num: Byte; Time: Integer);
begin
end;

procedure BanPlayerReason(Num: Byte; Time: Integer; Reason: String);
begin
end;

function Command(Cmd: String): Variant;
begin
    Result := nil;
end;

procedure SendStringToPlayer(Id: Byte; Text: String);
begin
end;

procedure BotChat(Id: Byte; Text: String);
begin
end;

procedure Sleep(Milliseconds: Cardinal);
begin
end;

function GetSystem: String;
begin
  Result := '';
end;

function GetPlayerStat(Id: Byte; Stat: String): Variant;
begin
  Result := nil;
end;

function GetKeyPress(Id: Byte; Key: String): Boolean;
begin
  Result := false;
end;

function GetObjectStat(Id: Byte; Stat: String): Variant;
begin
  Result := nil;
end;

function GetSpawnStat(Id: Byte; Stat: String): Variant;
begin
  Result := nil;
end;

procedure SetSpawnStat(Id: Byte; Stat: String; Value: Variant);
begin
end;

procedure DoDamage(Id: Byte; Damage: Integer);
begin
end;

procedure DoDamageBy(Id, Shooter: Byte; Damage: Integer);
begin
end;

procedure GetPlayerXY(Id: Byte; var X, Y: Single);
begin
  X := 0;
	Y := 0;
end;

procedure GetFlagsXY(var BlueFlagX, BlueFlagY, RedFlagX, RedFlagY: Single);
begin
end;

procedure GetFlagsSpawnXY(var BlueFlagX, BlueFlagY, RedFlagX, RedFlagY: Single);
begin
end;

procedure StartVoteKick(Target: Byte; Reason: String);
begin
end;

procedure StartVoteMap(Mapname, Reason: String);
begin
end;

function Sqrt(Number: Extended): Extended;
begin
  Result := 0;
end;

function Round(const Number: Variant): Int64;
begin
  Result := 0;
end;

function RoundTo(const AValue: Extended; ADigit: Integer): Extended;
begin
  Result := 0;
end;

function GetPiece(const Input, Splitter: String; Index: Integer): String;
begin
  Result := '';
end;

function WriteFile(FileName: String; SData: String): Boolean;
begin
  Result := false;
end;

procedure WriteLn(const Data: String);
begin
end;

//function Length(S: String): Integer;
//begin
//  Result := 0;
//end;

procedure Inc(var X: Integer; N: Integer);
begin
end;

procedure Dec(var X: Integer; N: Integer);
begin
end;

function CrossFunc(const Params: array of Variant; ProcName: String): Variant;
begin
  Result := nil;
end;

procedure WriteConsole(ID: byte; Text: string; Color: Cardinal);
begin
end;

procedure SetArrayLength(arr: array of string; len: integer); overload;
begin
end;

function GetArrayLength(arr: array of string): integer; overload;
begin
  Result := 0;
end;

function StrToInt(s: string): integer;
begin
	Result := 0;
end;

function StrToIntDef(s: string; default: integer): integer;
begin
  Result := 0;
end;

function ContainsString(haystack, needle: string): boolean;
begin
	Result := false;
end;

procedure RaiseException(code: integer; msg: string);
begin
end;

function IntToStr(x: integer): string;
begin
	Result := '';
end;

function FloatToStr(x: Extended): string;
begin
	Result := '';
end;

function StrPos(const A, S: string): Integer;
begin
	Result := 0;
end;

function StrReplace(const A, B, C: string): string;
begin
	Result := '';
end;

function HTTPEncode(A: string): string;
begin
	Result := '';
end;

function HTTPDecode(A: string): string;
begin
	Result := '';
end;

function shell_exec(A: string): Integer;
begin
	Result := 0;
end;

function Distance(x1, y1, x2, y2: single): single;
begin
	Result := 0;
end;

function iif(cond: boolean; t, f: variant): variant;
begin
  Result := f;
end;

procedure PlaySound(ID: byte; name: string; x, y: single);
begin
end;

procedure ServerModifier(what: string; param: variant);
begin
end;

function FormatFloat(format: string; float: double): string;
begin
	Result := '';
end;

procedure MovePlayer(ID: byte; x, y: single);
begin
end;

function ExceptionToString(ex_type, ex_param: integer): string;
begin
	Result := '';
end;

procedure ShutDown();
begin

end;

function GetStringIndex(arg1: string; arg2: array of string): Integer;
begin
  Result := 0;
end;

////////////////////////////////// METHODS /////////////////////////////////////

procedure TBanLists.AddHWBan(HW, Reason: string; Duration: Integer);
begin
end;

procedure TBanLists.AddIPBan(IP: string; Reason: string; Duration: Integer);
begin
end;

function TBanLists.DelHWBan(HW: string): Boolean;
begin
  Result := false;
end;

function TBanLists.DelIPBan(IP: string): Boolean;
begin
  Result := false;
end;

function TBanLists.IsBannedHW(HW: string): Boolean;
begin
  Result := false;
end;

function TBanLists.IsBannedIP(IP: string): Boolean;
begin
  Result := false;
end;

function TBanLists.GetHWBanId(HW: string): Integer;
begin
  Result := 0;
end;

function TBanLists.GetIPBanId(IP: string): Integer;
begin
  Result := 0;
end;

function TBanLists.GetBannedHW(Num: Integer): TBanHW;
begin
  Result := nil;
end;

function TBanLists.GetBannedIP(Num: Integer): TBanIP;
begin
  Result := nil;
end;

function TBanLists.GetBannedHWCount: Integer;
begin
  Result := 0;
end;

function TBanLists.GetBannedIPCount: Integer;
begin
  Result := 0;
end;

// -------------------------------- Bullet -------------------------------------
function TActiveBullet.GetOwnerWeaponId: Integer;
begin
  Result := 0;
end;

function TActiveBullet.GetActive: Boolean;
begin
  Result := false;
end;

function TActiveBullet.GetID: Byte;
begin
  Result := 0;
end;

function TActiveBullet.GetStyle: Byte;
begin
  Result := 0;
end;

function TActiveBullet.GetX: Single;
begin
  Result := 0;
end;

function TActiveBullet.GetY: Single;
begin
  Result := 0;
end;

function TActiveBullet.GetVelX: Single;
begin
  Result := 0;
end;

function TActiveBullet.GetVelY: Single;
begin
  Result := 0;
end;

function TActiveBullet.GetOwner: Byte;
begin
  Result := 0;
end;

// -------------------------------- File API -----------------------------------
//constructor TFile.Create(API: TScriptFileAPI);
//begin
//  Self.FAPI := API;
//end;

function TFile.CheckAccess(const FilePath: string): Boolean;
begin
  Result := false;
end;

function TFile.CreateFileStream(): TStream;
begin
  Result := nil;
end;

function TFile.CreateFileStreamFromFile(const Path: string): TStream;
begin
  Result := nil;
end;

function TFile.CreateStringList(): TStringList;
begin
  Result := nil;
end;

function TFile.CreateStringListFromFile(const Path: string): TStringList;
begin
  Result := nil;
end;

function TFile.CreateINI(const Path: string): TIniFile;
begin
  Result := nil;
end;

function TFile.Exists(const Path: string): Boolean;
begin
  Result := false;
end;

function TFile.Copy(const Source, Destination: string): Boolean;
begin
		 Result := false;
end;

function TFile.Move(const Source, Destination: string): Boolean;
begin
  Result := false;
end;

function TFile.Delete(const Path: string): Boolean;
begin
  Result := false;
end;

// ---------------------------------- Game -------------------------------------
function TGame.GetGameStyle: Byte;
begin
  Result := 0;
end;

procedure TGame.SetGameStyle(Style: Byte);
begin
end;

function TGame.GetMaxPlayers: Byte;
begin
  Result := 0;
end;

procedure TGame.SetMaxPlayers(Max: Byte);
begin
end;

function TGame.GetNextMap: string;
begin
  Result := '';
end;

function TGame.GetCurrentMap: string;
begin
  Result := '';
end;

function TGame.GetNumBots: Byte;
begin
  Result := 0;
end;

function TGame.GetNumPlayers: Byte;
begin
  Result := 0;
end;

function TGame.GetSpectators: Byte;
begin
  Result := 0;
end;

function TGame.GetScoreLimit: Word;
begin
  Result := 0;
end;

procedure TGame.SetScoreLimit(Limit: Word);
begin
end;

function TGame.GetServerIP: string;
begin
  Result := '';
end;

function TGame.GetServerName: string;
begin
  Result := '';
end;

function TGame.GetServerPort: Word;
begin
  Result := 0;
end;

function TGame.GetServerVersion: string;
begin
  Result := '';
end;

function TGame.GetServerInfo: string;
begin
  Result := '';
end;

function TGame.GetGravity: Single;
begin
  Result := 0;
end;

procedure TGame.SetGravity(Grav: Single);
begin
end;

function TGame.GetPaused: Boolean;
begin
  Result := false;
end;

procedure TGame.SetPaused(Paused: Boolean);
begin
end;

function TGame.GetRespawnTime: Integer;
begin
   Result := 0;
end;

procedure TGame.SetRespawnTime(Time: Integer);
begin
end;

function TGame.GetMinRespawnTime: Integer;
begin
  Result := 0;
end;

procedure TGame.SetMinRespawnTime(Time: Integer);
begin
end;

function TGame.GetMaxRespawnTime: Integer;
begin
  Result := 0;
end;

procedure TGame.SetMaxRespawnTime(Time: Integer);
begin
end;

function TGame.GetMaxGrenades: Byte;
begin
  Result := 0;
end;

procedure TGame.SetMaxGrenades(Num: Byte);
begin
end;

function TGame.GetBonus: Byte;
begin
  Result := 0;
end;

procedure TGame.SetBonus(Num: Byte);
begin
end;

function TGame.GetTimeLimit: Longint;
begin
  Result := 0;
end;

procedure TGame.SetTimeLimit(Num: Longint);
begin
end;

function TGame.GetTimeLeft: Longint;
begin
	Result := 0;
end;

function TGame.GetFriendlyFire: Boolean;
begin
  Result := false
end;

procedure TGame.SetFriendlyFire(Enabled: Boolean);
begin
end;

function TGame.GetPassword: string;
begin
  Result := '';
end;

procedure TGame.SetPassword(Pass: string);
begin
end;

function TGame.GetAdminPassword: string;
begin
		 Result := '';
end;

procedure TGame.SetAdminPassword(Pass: string);
begin
end;

function TGame.GetVotePercent: Byte;
begin
  Result := 0;
end;

procedure TGame.SetVotePercent(Percent: Byte);
begin
end;

function TGame.GetRealistic: Boolean;
begin
  Result := false;
end;

procedure TGame.SetRealistic(Enabled: Boolean);
begin
end;

function TGame.GetSurvival: Boolean;
begin
  Result := false;
end;

procedure TGame.SetSurvival(Enabled: Boolean);
begin
end;

function TGame.GetAdvance: Boolean;
begin
  Result := false;
end;

procedure TGame.SetAdvance(Enabled: Boolean);
begin
end;

function TGame.GetBalance: Boolean;
begin
  Result := false;
end;

procedure TGame.SetBalance(Enabled: Boolean);
begin
end;

function TGame.GetTickCount: Longint;
begin
  Result := 0;
end;

function TGame.GetTeam(ID: Byte): TTeam;
begin
  Result := nil;
end;

function TGame.GetMapsList: TMapsList;
begin
  Result := nil;
end;

function TGame.GetBanLists: TBanLists;
begin
  Result := nil;
end;

procedure TGame.Restart;
begin
end;

function TGame.LoadWeap(WeaponMod: string): Boolean;
begin
  Result := false;
end;

function TGame.LoadCon(ConfigFile: string): Boolean;
begin
  Result := false;
end;

function TGame.LoadList(MapsList: string): Boolean;
begin
  Result := false;
end;

function TGame.LobbyRegister: Boolean;
begin
  Result := false;
end;

constructor TGame.Create;
begin
end;

procedure TGame.Shutdown;
begin
end;

procedure TGame.StartVoteKick(ID: Byte; Reason: string);
begin
end;

procedure TGame.StartVoteMap(Name: string);
begin
end;

// -------------------------------- Global -------------------------------------
function TGlobal.GetDateSeparator: Char;
begin
	Result := #0;
end;

procedure TGlobal.SetDateSeparator(Separator: Char);
begin
end;

function TGlobal.GetShortDateFormat: string;
begin
  Result := '';
end;

procedure TGlobal.SetShortDateFormat(Format: string);
begin
end;

// --------------------------------- Map ---------------------------------------
constructor TMap.Create;
begin
end;

function TMap.GetObject(ID: Byte): TActiveMapObject;
begin
  Result := nil;
end;

function TMap.GetBullet(ID: Byte): TActiveBullet;
begin
  Result := nil;
end;

function TMap.GetSpawn(ID: Byte): TSpawnPoint;
begin
  Result := nil;
end;

procedure TMap.SetSpawn(ID: Byte; const Spawn: TSpawnPoint);
begin
end;

function TMap.GetName: string;
begin
  Result := '';
end;

function TMap.GetFlag(ID: Integer): TActiveFlag;
begin
  Result := nil;
end;

function TMap.RayCast(x1, y1, x2, y2: Single; Player: Boolean = False;
  Flag: Boolean = False; Bullet: Boolean = True; CheckCollider: Boolean = False;
  Team: Byte = 0): Boolean;
begin
	 Result := false;
end;

function TMap.RayCastVector(A, B: TVector; Player: Boolean = False;
  Flag: Boolean = False; Bullet: Boolean = True; CheckCollider: Boolean = False;
  Team: Byte = 0): Boolean;
begin
  Result := false;
end;

function TMap.CreateBulletVector(A, B: TVector; HitM: Single; sStyle: Byte; Owner: TActivePlayer): Integer;
begin
  Result := 0;
end;

function TMap.CreateBullet(X, Y, VelX, VelY, HitM: Single; sStyle: Byte; Owner: TActivePlayer): Integer;
begin
  Result := 0;
end;

function TMap.AddObject(Obj: TNewMapObject): TActiveMapObject;
begin
  Result := nil;
end;

function TMap.AddSpawnPoint(Spawn: TSpawnPoint): TActiveSpawnPoint;
begin
  Result := nil;
end;

procedure TMap.NextMap;
begin
end;

procedure TMap.SetMap(NewMap: string);
begin
end;

// ------------------------------- Mapslist ------------------------------------
procedure TMapsList.AddMap(Name: string);
begin
end;

procedure TMapsList.RemoveMap(Name: string);
begin
end;

function TMapsList.GetMapIdByName(Name: string): Integer;
begin
  Result := 0;
end;

function TMapsList.GetMap(Num: Integer): string;
begin
    Result := '';
end;

function TMapsList.GetCurrentMapId: Integer;
begin
  Result := 0;
end;

procedure TMapsList.SetCurrentMapId(NewNum: Integer);
begin
end;

function TMapsList.GetMapsCount: Integer;
begin
  Result := 0;
end;

// -------------------------------- Math ---------------------------------------
function TMath.GetE: Extended;
begin
  Result := 0.0;
end;

function TMath.GetPi: Extended;
begin
  Result := 0.0;
end;

function TMath.Sin(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.Cos(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.Tan(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.Cotan(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.Pow(A, B: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.LogN(A, B: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.Ln(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.ArcSin(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.ArcCos(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.ArcTan(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.ArcCotan(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.ArcTan2(A, B: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.Min(A, B: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.Max(A, B: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.Abs(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.Exp(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.Sign(A: Extended): TValueSign;
begin
  Result := 0;
end;

function TMath.IsNaN(A: Extended): Boolean;
begin
  Result := false;
end;

function TMath.Round(A: Extended): Integer;
begin
  Result := 0;
end;

function TMath.RoundTo(A: Extended; B: TRoundToRange): Extended;
begin
  Result := 0.0;
end;

function TMath.DegToRad(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.RadToDeg(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.DegNormalize(A: Extended): Extended;
begin
  Result := 0.0;
end;

function TMath.InRange(const A, B, C: Double): Boolean;
begin
  Result := false;
end;

function TMath.EnsureRange(const AValue, AMin, AMax: Double): Double;
begin
  Result := 0.0;
end;

function TMath.Random(Min, Max: Extended): Extended;
begin
  Result := 0.0;
end;

// -------------------------------- Object -------------------------------------
function TThing.GetX: Single;
begin
  Result := 0;
end;

function TThing.GetY: Single;
begin
  Result := 0;
end;

function TNewMapObject.GetStyle: Byte;
begin
  Result := 0;
end;

constructor TNewMapObject.Create;
begin
end;

destructor TNewMapObject.Destroy;
begin
end;

procedure TNewMapObject.SetStyle(Style: Byte);
begin
end;

procedure TNewMapObject.SetX(X: Single);
begin
end;

procedure TNewMapObject.SetY(Y: Single);
begin
end;

function TActiveMapObject.GetActive: Boolean;
begin
  Result := false;
end;

function TActiveMapObject.GetID: Byte;
begin
  Result := 0;
end;

function TActiveMapObject.GetStyle: Byte;
begin
  Result := 0;
end;

procedure TActiveMapObject.Kill;
begin
end;

function TActiveFlag.GetInBase: Boolean;
begin
  Result := false;
end;

// --------------------------------- Player ------------------------------------
constructor TNewPlayer.Create;
begin
end;

destructor TPlayer.Destroy;
begin
end;

//function TPlayer.GetSprite: TSprite;
//begin
//  Result := nil;
//end;

function TPlayer.GetTeam: Byte;
begin
  Result := 0;
end;

function TPlayer.GetName: string;
begin
  Result := '';;
end;

function TPlayer.GetAlive: Boolean;
begin
  Result := false;
end;

function TPlayer.GetHealth: Single;
begin
  Result := 0;
end;

procedure TPlayer.SetHealth(Health: Single);
begin
end;

function TPlayer.GetVest: Single;
begin
  Result := 0;
end;

procedure TPlayer.SetVest(Vest: Single);
begin
end;

function TPlayer.GetPrimary: TPlayerWeapon;
begin
  Result := nil;
end;

function TPlayer.GetSecondary: TPlayerWeapon;
begin
  Result := nil;
end;

function TPlayer.GetShirtColor: Longword;
begin
  Result := 0;
end;

function TPlayer.GetPantsColor: Longword;
begin
  Result := 0;
end;

function TPlayer.GetSkinColor: Longword;
begin
  Result := 0;
end;

function TPlayer.GetHairColor: Longword;
begin
  Result := 0;
end;

function TPlayer.GetFavouriteWeapon: string;
begin
  Result := '';
end;

procedure TPlayer.SetFavouriteWeapon(Weapon: string);
begin
end;

function TPlayer.GetChosenSecondaryWeapon: Byte;
begin
  Result := 0;
end;

function TPlayer.GetFriend: string;
begin
  Result := '';
end;

procedure TPlayer.SetFriend(Friend: string);
begin
end;

function TPlayer.GetAccuracy: Byte;
begin
  Result := 0;
end;

procedure TPlayer.SetAccuracy(Accuracy: Byte);
begin
end;

function TPlayer.GetShootDead: Boolean;
begin
  Result := false;
end;

procedure TPlayer.SetShootDead(ShootDead: Boolean);
begin
end;

function TPlayer.GetGrenadeFrequency: Byte;
begin
  Result := 0;
end;

procedure TPlayer.SetGrenadeFrequency(Frequency: Byte);
begin
end;

function TPlayer.GetCamping: Boolean;
begin
  Result := false;
end;

procedure TPlayer.SetCamping(Camping: Boolean);
begin
end;

function TPlayer.GetOnStartUse: Byte;
begin
  Result := 0;
end;

procedure TPlayer.SetOnStartUse(Thing: Byte);
begin
end;

function TPlayer.GetHairStyle: Byte;
begin
  Result := 0;
end;

function TPlayer.GetHeadgear: Byte;
begin
  Result := 0;
end;

function TPlayer.GetChain: Byte;
begin
  Result := 0;
end;

function TPlayer.GetChatFrequency: Byte;
begin
  Result := 0;
end;

procedure TPlayer.SetChatFrequency(Frequency: Byte);
begin
end;

function TPlayer.GetChatKill: string;
begin
  Result := '';
end;

procedure TPlayer.SetChatKill(Message: string);
begin
end;

function TPlayer.GetChatDead: string;
begin
  Result := '';
end;

procedure TPlayer.SetChatDead(Message: string);
begin
end;

function TPlayer.GetChatLowHealth: string;
begin
  Result := '';
end;

procedure TPlayer.SetChatLowHealth(Message: string);
begin
end;

function TPlayer.GetChatSeeEnemy: string;
begin
  Result := '';
end;

procedure TPlayer.SetChatSeeEnemy(Message: string);
begin
end;

function TPlayer.GetChatWinning: string;
begin
  Result := '';
end;

procedure TPlayer.SetChatWinning(Message: string);
begin
end;

function TPlayer.GetAdmin: Boolean;
begin
  Result := false;
end;

procedure TPlayer.SetAdmin(SetAsAdmin: Boolean);
begin
end;

function TPlayer.GetDummy: Boolean;
begin
  Result := false;
end;

procedure TPlayer.SetDummy(Dummy: Boolean);
begin
end;

//constructor TActivePlayer.Create(var Sprite: TSprite; ID: Byte);
//begin
//end;

function TActivePlayer.GetKills: Integer;
begin
  Result := 0;
end;

procedure TActivePlayer.SetKills(Kills: Integer);
begin
end;

function TActivePlayer.GetDeaths: Integer;
begin
  Result := 0;
end;

function TActivePlayer.GetPing: Integer;
begin
  Result := 0;
end;

function TActivePlayer.GetActive: Boolean;
begin
  Result := false;
end;

function TActivePlayer.GetIP: string;
begin
  Result := '';
end;

function TActivePlayer.GetPort: Word;
begin
  Result := 0;
end;

procedure TActivePlayer.SetAlive(Alive: Boolean);
begin
end;

function TActivePlayer.GetJets: Integer;
begin
  Result := 0;
end;

function TActivePlayer.GetGrenades: Byte;
begin
  Result := 0;
end;

function TActivePlayer.GetX: Single;
begin
  Result := 0;
end;

function TActivePlayer.GetY: Single;
begin
  Result := 0;
end;

function TActivePlayer.GetMouseAimX: SmallInt;
begin
  Result := 0;
end;

procedure TActivePlayer.SetMouseAimX(AimX: SmallInt);
begin
end;

function TActivePlayer.GetMouseAimY: SmallInt;
begin
  Result := 0;
end;

procedure TActivePlayer.SetMouseAimY(AimY: SmallInt);
begin
end;

function TActivePlayer.GetFlagger: Boolean;
begin
  Result := false;
end;

function TActivePlayer.GetTime: Integer;
begin
  Result := 0;
end;

function TActivePlayer.GetOnGround: Boolean;
begin
  Result := false;
end;

function TActivePlayer.GetProne: Boolean;
begin
  Result := false;
end;

function TActivePlayer.GetHuman: Boolean;
begin
  Result := false;
end;

function TActivePlayer.GetDirection: Shortint;
begin
  Result := 0;
end;

function TActivePlayer.GetFlags: Byte;
begin
  Result := 0;
end;

function TActivePlayer.GetHWID: string;
begin
  Result := '';
end;

function TActivePlayer.GetKeyUp: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyUp(Pressed: Boolean);
begin
end;

function TActivePlayer.GetKeyLeft: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyLeft(Pressed: Boolean);
begin
end;

function TActivePlayer.GetKeyRight: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyRight(Pressed: Boolean);
begin
end;

function TActivePlayer.GetKeyShoot: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyShoot(Pressed: Boolean);
begin
end;

function TActivePlayer.GetKeyJetpack: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyJetpack(Pressed: Boolean);
begin
end;

function TActivePlayer.GetKeyGrenade: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyGrenade(Pressed: Boolean);
begin
end;

function TActivePlayer.GetKeyChangeWeap: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyChangeWeap(Pressed: Boolean);
begin
end;

function TActivePlayer.GetKeyThrow: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyThrow(Pressed: Boolean);
begin;
end;

function TActivePlayer.GetKeyReload: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyReload(Pressed: Boolean);
begin
end;

function TActivePlayer.GetKeyCrouch: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyCrouch(Pressed: Boolean);
begin
end;

function TActivePlayer.GetKeyProne: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyProne(Pressed: Boolean);
begin
end;

function TActivePlayer.GetKeyFlagThrow: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetKeyFlagThrow(Pressed: Boolean);
begin
end;


function TActivePlayer.Ban(Time: Integer; Reason: string): Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.Say(Text: string);
begin
end;

procedure TActivePlayer.Damage(Shooter: Byte; Damage: Integer);
begin
end;

procedure TActivePlayer.BigText(Layer: Byte; Text: string;
  Delay: Integer; Color: Longint; Scale: Single; X, Y: Integer);
begin
end;

procedure TActivePlayer.WorldText(Layer: Byte; Text: string;
  Delay: Integer; Color: Longint; Scale, X, Y: Single);
begin
end;

procedure TActivePlayer.ForceWeapon(Primary, Secondary: TNewWeapon);
begin
end;

procedure TActivePlayer.ForwardTo(TargetIP: string; TargetPort: Word;
  Message: string);
begin
end;

procedure TActivePlayer.GiveBonus(BType: Byte);
begin
end;

function TActivePlayer.Kick(reason: TKickReason): Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.ChangeTeam(NewTeam: Byte; JoinType: TJoinType);
begin
end;

procedure TActivePlayer.Move(X, Y: Single);
begin
end;

procedure TActivePlayer.SetVelocity(VelX, VelY: Single);
begin
end;

procedure TActivePlayer.Tell(Text: string);
begin
end;

procedure TActivePlayer.WriteConsole(Text: string; Color: Longint);
begin
end;

procedure TNewPlayer.SetTeam(Team: Byte);
begin
end;

procedure TNewPlayer.SetName(Name: string);
begin
end;

procedure TNewPlayer.SetHealth(Health: Single);
begin
end;

function TNewPlayer.GetPrimary: TWeapon;
begin
  Result := nil;
end;

procedure TNewPlayer.SetPrimary(Primary: TWeapon);
begin
end;

function TNewPlayer.GetSecondary: TWeapon;
begin
  Result := nil;
end;

procedure TNewPlayer.SetSecondary(Secondary: TWeapon);
begin
end;

procedure TNewPlayer.SetShirtColor(Color: Longword);
begin
end;

procedure TNewPlayer.SetPantsColor(Color: Longword);
begin
end;

procedure TNewPlayer.SetSkinColor(Color: Longword);
begin
end;

procedure TNewPlayer.SetHairColor(Color: Longword);
begin
end;

procedure TNewPlayer.SetHairStyle(Style: Byte);
begin
end;

procedure TNewPlayer.SetHeadgear(Headgear: Byte);
begin
end;

procedure TNewPlayer.SetChain(Chain: Byte);
begin
end;

function TNewPlayer.GetDummy(): Boolean;
begin
  Result := false;
end;

procedure TNewPlayer.SetDummy(Dummy: Boolean);
begin
end;

procedure TActivePlayer.SetTeam(Team: Byte);
begin
end;

function TActivePlayer.GetVelX: Single;
begin
  Result := 0;
end;

function TActivePlayer.GetVelY: Single;
begin
  Result := 0;
end;

function TActivePlayer.GetMuted: Boolean;
begin
  Result := false;
end;

procedure TActivePlayer.SetWeaponActive(ID: Byte; Active: Boolean);
begin
end;

procedure TActivePlayer.SetMuted(Muted: Boolean);
begin
end;

// -------------------------------- Players ------------------------------------
constructor TPlayers.Create;
begin
end;

destructor TPlayers.Destroy;
begin
end;

function TPlayers.GetPlayer(ID: Byte): TActivePlayer;
begin
  Result := nil;
end;

function TPlayers.Add(Player: TNewPlayer; jointype: TJoinType): TActivePlayer;
begin
  Result := nil;
end;

procedure TPlayers.WriteConsole(Text: string; Color: Longint);
begin
end;

procedure TPlayers.BigText(Layer: Byte; Text: string; Delay: Integer;
  Color: Longint; Scale: Single; X, Y: Integer);
begin
end;

procedure TPlayers.WorldText(Layer: Byte; Text: string; Delay: Integer;
  Color: Longint; Scale, X, Y: Single);
begin
end;

function TPlayers.GetByName(Name: string): TActivePlayer;
begin
  Result := nil;
end;

function TPlayers.GetByIP(IP: string): TActivePlayer;
begin
  Result := nil;
end;

procedure TPlayers.Tell(Text: string);
begin
end;

// -------------------------------- Script -------------------------------------
function TScript.GetName: string;
begin
  Result := '';
end;

function TScript.GetVersion: string;
begin
  Result := '';
end;

function TScript.GetDir: string;
begin
  Result := '';
end;

function TScript.GetDebugMode: Boolean;
begin
  Result := false;
end;


procedure TScript.Recompile(Force: Boolean);
begin
end;

procedure TScript.Unload;
begin
end;

// ------------------------------ Spawnpoint -----------------------------------
function TSpawnPoint.GetActive: Boolean;
begin
  Result := false;
end;

procedure TSpawnPoint.SetActive(Active: Boolean);
begin
end;

function TSpawnPoint.GetX: Longint;
begin
  Result := 0;
end;

procedure TSpawnPoint.SetX(X: Longint);
begin
end;

function TSpawnPoint.GetY: Longint;
begin
  Result := 0;
end;

procedure TSpawnPoint.SetY(Y: Longint);
begin
end;

function TSpawnPoint.GetStyle: Byte;
begin
  Result := 0;
end;

procedure TSpawnPoint.SetStyle(Style: Byte);
begin
end;

constructor TNewSpawnPoint.Create;
begin
end;

destructor TNewSpawnPoint.Destroy;
begin
end;

//constructor TScriptActiveSpawnPoint.CreateActive(ID: Byte; var Spawn: TMapSpawnPoint);
//begin
//end;

// --------------------------------- Team --------------------------------------
constructor TTeam.Create(ID: Byte);
begin
end;

destructor TTeam.Destroy;
begin
end;

procedure TTeam.AddPlayer(Player: TPlayer);
begin
end;

procedure TTeam.RemovePlayer(Player: TPlayer);
begin
end;

function TTeam.GetScore: Byte;
begin
  Result := 0;
end;

procedure TTeam.SetScore(Score: Byte);
begin
end;

function TTeam.GetPlayer(Num: Byte): TPlayer;
begin
  Result := nil;
end;

function TTeam.GetCount: Byte;
begin
  Result := 0;
end;

procedure TTeam.Add(Player: TPlayer);
begin
end;

// ------------------------------- Weapons -------------------------------------
constructor TNewWeapon.Create;
begin
end;

destructor TNewWeapon.Destroy;
begin
end;

function TWeapon.GetType: Byte;
begin
  Result := 0;
end;

function TWeapon.GetName: string;
begin
  Result := '';
end;

function TWeapon.GetBulletStyle: Byte;
begin
  Result := 0;
end;

function TWeapon.GetAmmo: Byte;
begin
  Result := 0;
end;

procedure TPlayerWeapon.SetAmmo(Ammo: Byte);
begin
end;


procedure TNewWeapon.SetAmmo(Ammo: Byte);
begin
end;

procedure TNewWeapon.SetType(WType: Byte);
begin
end;

end.
