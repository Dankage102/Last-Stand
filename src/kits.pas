// * -------------- *
// |      Kits      |
// * -------------- *

// Implements a timed kit.

unit Kits;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Misc;

const
	MAX_KITS =    30;

type
	tKit = record
		ID: byte;
		duration: word;
		active: boolean;
		x, y: single;
	end;
	
var
	MaxKitID: integer;
	kit:         array[1..MAX_KITS] of tKit;
	
function Kits_Spawn(x, y: single; style: byte; duration: word): boolean;

procedure Kits_Kill(ID: byte);

procedure Kits_Process();

// external, called from on pickup event
procedure Kits_OnPickup(P: TActivePlayer; Kit: TActiveMapObject);

implementation

function Kits_Spawn(x, y: single; style: byte; duration: word): boolean;
var
	i: integer;
begin
	for i := 1 to MAX_KITS do
		if not kit[i].Active then begin
			kit[i].ID := Objects_Spawn(x, y, style);
			kit[i].duration := duration;
			kit[i].Active := true;
			kit[i].X := x;
			kit[i].Y := y;
			Result := true;
			if i > MaxKitID then MaxKitID := i;
			exit;
		end;
end;

procedure Kits_Kill(ID: byte);
var i: integer;
begin
	kit[ID].Active := false;
	kit[ID].duration := 0;
	if kit[ID].ID > 0 then
	if Map.Objects[kit[ID].ID].Active then
		Map.Objects[kit[ID].ID].Kill();
	kit[ID].ID := 0;
	if ID >= MaxKitID then begin
		for i := MaxKitID downto 1 do begin
			if kit[i].Active then begin
				MaxKitID := i;
				break;
			end;
		end;
	end;
end;

procedure Kits_Process();
var
	i: integer;
begin
	if MaxKitID > 0 then	
		for i := 1 to MaxKitID do
			if kit[i].Active then
				if kit[i].duration > 0 then begin
					kit[i].duration := kit[i].duration - 1;
				end else begin
					CreateBulletX(Map.Objects[kit[i].ID].X, Map.Objects[kit[i].ID].Y-3, 0, 0, 0, 5, MaxID);
					Kits_Kill(i);
				end;
end;

procedure Kits_OnPickup(P: TActivePlayer; Kit: TActiveMapObject);
begin
   if Kit.Active then Kit.Kill();
end;

begin
end.
