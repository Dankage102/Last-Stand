unit Hax;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Misc,
	Ballistic;

function Hax_OnCommand(ID: byte; cmd: string): boolean;
procedure Hax_OnTick();
procedure Hax_OnLeaveGame(ID: byte);

implementation

const
	VACUUM_RANGE = 400.0;
	VACUUM_FORCE = 2.0;
	
	AIMBOT_RANGE = 680.0;
	AIMBOT_VELOCITY = 15.0;
	
	
type
	tHaxPlayer = record
		Vacuum: boolean;
		AimBot: boolean;
	end;
	
var
	HaxPlayers: array [1..32] of tHaxPlayer;

function Hax_OnCommand(ID: byte; cmd: string): boolean;
begin
	if ID > 0 then begin
    {$ifndef FPC}
		case cmd of
			'/vacuum': begin
				HaxPlayers[ID].Vacuum := not HaxPlayers[ID].Vacuum;
				Players[ID].WriteConsole(
					'[Hax] Vacuum ' + iif(HaxPlayers[ID].Vacuum, 'enabled. Use the Flag Throw key.', 'disabled.'),
				$64FF64);
				Result := true;
			end;
			'/aimbot': begin
				HaxPlayers[ID].AimBot := not HaxPlayers[ID].AimBot;
				Players[ID].WriteConsole(
					'[Hax] Aimbot ' + iif(HaxPlayers[ID].AimBot, 'en', 'dis') + 'abled',
				$64FF64);
				Result := true;
			end;
		end;
    {$else}
    Result := false;
    {$endif}
	end;
end;

procedure Hax_Vacuum(ID: integer);
var 
	i: integer;
	r, vx, vy: single;
begin
	for i := 1 to MaxID do begin
		if Players[i].Active then
		if Players[i].Alive then
		if Players[i].Team <> Players[ID].Team then
		if not Players[i].Dummy then begin
			r := Distance(Players[ID].MouseAimX, Players[ID].MouseAimY, Players[i].X, Players[i].Y);
			if r < VACUUM_RANGE then begin
				vx := (Players[ID].MouseAimX - Players[i].X) / r * VACUUM_FORCE;
				vy := (Players[ID].MouseAimY - Players[i].Y) / r * VACUUM_FORCE;
				Players[i].SetVelocity(Players[i].VelX + vx, Players[i].VelY + vy);
				Players[i].MouseAimX := Players[ID].MouseAimX;
				Players[i].MouseAimY := Players[ID].MouseAimY;
			end;
		end;
	end;
end;

procedure Hax_AimBot(ID: integer);
var 
	i, t: integer;
	r: single;
	max_r: single;
	InRange: boolean;
begin
	max_r := AIMBOT_RANGE;
	for i := 1 to MaxID do begin
		if Players[i].Active then
		if Players[i].Alive then
		if Players[i].Team <> Players[ID].Team then
		if not Players[i].Dummy then
		if not Map.RayCast(Players[ID].X, Players[ID].Y-7.0, Players[i].X, Players[i].Y-7.0, false, false, true, true, 0) then begin
			r := Distance(
				0.5*(Players[ID].MouseAimX+Players[ID].X), 0.5*(Players[ID].MouseAimY+Players[ID].Y),
				Players[i].X, Players[i].Y
			);
			if r < max_r then begin
				t := i;
				max_r := r;
			end;
		end;
	end;
	if t > 0 then begin
		r := BallisticAimX2(Players[ID], Players[t], AIMBOT_VELOCITY, 1.0, InRange);
		if (InRange) then begin
			Map.CreateBullet(Players[ID].X, Players[ID].Y-8.0,
      	cos(r-0.005)*AIMBOT_VELOCITY+Players[ID].VelX, sin(r-0.005)*AIMBOT_VELOCITY + Players[ID].VelY,
      10, 1, Players[ID]);
			Map.CreateBullet(Players[ID].X, Players[ID].Y-8.0,
      	cos(r+0.005)*AIMBOT_VELOCITY+Players[ID].VelX, sin(r+0.005)*AIMBOT_VELOCITY + Players[ID].VelY,
      10, 1, Players[ID]);
		end;
	end;
end;

procedure Hax_OnTick();
var i: integer;
begin
	for i := 1 to MaxID do begin
		if Players[i].Active then
		if Players[i].Alive then begin
			if HaxPlayers[i].Vacuum then begin
				if Players[i].KeyFlagThrow then begin
					Hax_Vacuum(i);
				end;
			end;
			if HaxPlayers[i].AimBot then begin
				Hax_AimBot(i);
			end;
		end;
	end;
end;

procedure Hax_OnLeaveGame(ID: byte);
begin
	HaxPlayers[ID].Vacuum := false;
	HaxPlayers[ID].AimBot := false;
end;

begin
end.
