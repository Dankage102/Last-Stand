// * ------------------ *
// |      Statguns      |
// * ------------------ *

// This is a part of {LS} Last Stand. 

unit Statguns;

interface

uses
{$ifdef FPC}
  Scriptcore,
{$endif}
	Bigtext,
	Constants,
	Globals,
	LSPlayers,
	MersenneTwister,
	Misc,
	Raycasts;
	
const
	BUILDTIME = 	 15;
	RETRIEVETIME =  9;
	
type
	tStat = record
		x, y: single;
		reference: integer;
		owner: byte;
	end;

	tStatguns = record
		Num, RetrieveNum: byte;
		BuildTimer: smallint;
		FixTimer: integer;
	end;

var
	statgun:     array[1..MAX_STATS] of tStat;
	SG: tStatguns;

// Get the statgun near position x y, returns index of an array
function Statguns_GetAt( x, y: single ): byte;

procedure Statguns_DestroySG(ID: byte; byPlayer: boolean );

procedure Statguns_Reset();

procedure Statguns_Clear();

procedure Statguns_Respawn();

procedure Statguns_ProcessConstruction();

procedure Statguns_TryBuild(ID: byte);

implementation

procedure Statguns_Build( x, y: single; plID: byte );
begin
	if SG.BuildTimer <> 0 then
		WriteConsole( plID, 'You can only build/retrieve one statgun at a time!', RED)
	else if SG.Num < MAX_STATS then
	begin
		statgun[SG.Num].X := x;
		statgun[SG.Num].Y := y;
		statgun[SG.Num].owner := plID;
		SG.BuildTimer := BUILDTIME;
	end else
		WriteConsole( plID, 'Maximum number of statguns ingame', RED);
end;

procedure Statguns_Get( plID: byte; index: integer  );
begin
	if SG.BuildTimer <> 0 then
	begin
		WriteConsole( plID, 'You can only build/retrieve one statgun at a time!', RED) 
	end else
	begin
		WriteConsole( plID, 'Retrieving statgun, do not move!', GREEN);
		SG.RetrieveNum := index;
		SG.BuildTimer := - RETRIEVETIME;
	end;
end;

// Create a statgun and set the reference
procedure Statguns_Ceate();
begin
	player[statgun[SG.Num].owner].statguns := player[ statgun[SG.Num].owner ].statguns - 1;
	WriteConsole( statgun[SG.Num].owner, 'Statgun complete! '+IntToStr(player[statgun[SG.Num].owner].statguns)+' statguns left.', GREEN);
	statgun[SG.Num].reference := Objects_Spawn(statgun[SG.Num].X,statgun[SG.Num].Y-15,27);
	SG.Num := SG.Num + 1;
end;

// Get the statgun near position x y, returns index of an array
function Statguns_GetAt( x, y: single ): byte;
var i: byte;
begin
	Result:=0;
	if SG.Num = 0 then exit;
	for i:=1 to SG.Num - 1 do
		if Abs(statgun[i].X-x) <= 25 then
			if Abs(statgun[i].Y-y) <= 25 then begin
				Result:=i;
				break;
			end;
end;

procedure Statguns_DestroySG(ID: byte; byPlayer: boolean );
var 
	a: integer;
begin
	if SG.Num > 1 then begin
		if ID = 0 then ID := SG.RetrieveNum;
		SG.Num := SG.Num - 1;
		KillObject( statgun[ID].reference );
		if byPlayer = true then begin
			player[ statgun[ID].owner ].statguns := player[ statgun[ID].owner ].statguns + 1; 
			WriteConsole( statgun[SG.Num].owner, 'Statgun retrieved! '+IntToStr(player[ statgun[SG.Num].owner ].statguns)+' statguns available.', GREEN);
		end;
		for a := ID to SG.Num - 1 do begin
			statgun[ a ].X := statgun[ a + 1 ].X;
			statgun[ a ].Y := statgun[ a + 1 ].Y;
			statgun[ a ].reference := statgun[ a + 1 ].reference;
		end;
	end;
end;

procedure Statguns_Reset();
begin
	while ( SG.Num > 1 ) do
	begin
		SG.RetrieveNum := SG.Num - 1;
		Statguns_DestroySG(0, false);
	end;
	SG.BuildTimer := 0;
	SG.Num := 1;	
end;

procedure Statguns_Clear();
var
	a: integer;
begin
	for a := 1 to MAX_STATS do
	begin
		statgun[a].X := 0;
		statgun[a].Y := 0;
		statgun[a].reference := 0;
		statgun[a].owner := 0;
	end;
end;

procedure Statguns_Respawn();
var i: byte;
begin
	WriteConsole( 0, 'All stationary guns fixed', $FFFFFF );
	for i := 1 to MAX_STATS do
		if statgun[i].reference > 0 then
			if Map.Objects[statgun[i].reference].Active then begin
				Map.Objects[statgun[i].reference].Kill();
				statgun[i].reference := Objects_Spawn(Round(statgun[i].X), Round(statgun[i].Y) - 15, 27);
			end;
end;

procedure Statguns_ProcessConstruction();
begin
	if (SG.BuildTimer > 1) or (SG.BuildTimer < -1) then begin
		if SG.BuildTimer > 1 then begin
			if player[statgun[ SG.Num ].owner].Frozen then exit;
			if IsInRange(statgun[ SG.Num ].owner, statgun[ SG.Num ].X, statgun[ SG.Num ].Y, 25, false) then begin
				SG.BuildTimer := SG.BuildTimer - 1;
				BigText_DrawScreenX(DTL_COUNTDOWN,  statgun[ SG.Num ].owner, 'Construction ['+IntToStr(SG.BuildTimer-1)+']',100, DT_CONSTRUCTION, 0.08, 20,370 );
				if SG.BuildTimer > 4 then if (SG.BuildTimer mod 3 = 0) or (RandInt(1,5) = 1) then
					CreateBulletX(statgun[SG.Num].X, statgun[SG.Num].Y, RandInt(20,100)/80*iif(SG.BuildTimer mod 2 = 0, 1, -1), -1.3, 0, 7, statgun[ SG.Num ].owner)
			end else begin
				BigText_DrawScreenX(DTL_COUNTDOWN,  statgun[ SG.Num ].owner, 'Construction failed',100, DT_FAIL, 0.08, 20,370 );
				SG.BuildTimer := 0;
			end;
		end else
		if SG.BuildTimer < -1 then begin
			if player[statgun[ SG.RetrieveNum ].owner].Frozen then exit;
			if IsInRange(statgun[ SG.RetrieveNum ].owner, statgun[ SG.RetrieveNum ].X, statgun[ SG.RetrieveNum ].Y, 25, false) then begin
				SG.BuildTimer := SG.BuildTimer + 1;
				BigText_DrawScreenX(DTL_COUNTDOWN,  statgun[ SG.RetrieveNum ].owner, 'Deconstruction ['+IntToStr(-SG.BuildTimer-1)+']',100, DT_CONSTRUCTION, 0.08, 20,370 );
			end else begin
				WriteConsole( statgun[ SG.RetrieveNum ].owner, 'Retrieval failed!', RED);
				SG.BuildTimer := 0;
			end;
		end;
		
		if SG.BuildTimer = 1 then begin
			SG.BuildTimer := 0;
			Statguns_Ceate();
		end else
		if SG.BuildTimer = -1 then begin
			SG.BuildTimer := 0;
			Statguns_DestroySG(0, true);
		end;
	end;
end;

function Statguns_TryBuildX(ID: byte; xoffset: single; errors: boolean): boolean;
var X, X2, Y: single; sgY: array[0..1] of single; b: boolean; a: byte;
begin
	GetPlayerXY(ID, X, sgY[0]);
  X := X + xoffset;
	RayCast2(0, 2.5, 10, X, sgY[0]);
	sgY[0] := sgY[0] - 10;
	sgY[1] := sgY[0];
	b := false;
	for a := 0 to 1 do begin
		X2 := X - (2*a - 1) * 10;
		b := (b) or (RayCast2(0, 2, 30, X2, sgY[a]));
	end;
	if not b then begin
		if Abs(sgY[0] - sgY[1]) <= 10 then begin
			if SG.BuildTimer = 0 then WriteConsole(ID, 'Construction started. Do not move!', GREEN);
			GetPlayerXY(ID, X, Y);
			Statguns_Build(X, Y, ID );
      Result := true;
		end else begin
      if errors then
      	WriteConsole(ID, 'You cannot build the statgun here, ground is too steep',RED);
    end;
  end else begin
    if errors then
    	WriteConsole(ID, 'You cannot build the statgun on an edge', RED);
		b := false;
	end;
end;

procedure Statguns_TryBuild(ID: byte);
var i: integer;
begin
	if player[ID].Task = 1 then begin
		if player[ID].statguns > 0 then begin
			if Players_OnGround(ID, true, 10) > 0 then begin
        if Statguns_TryBuildX(ID, 0.0, false) then exit;
        for i := 1 to 5 do begin
        	if Statguns_TryBuildX(ID, i, false) then exit;
          if Statguns_TryBuildX(ID, -i, false) then exit;
        end;
        Statguns_TryBuildX(ID, 0.1, true);
			end else WriteConsole(ID, 'You must be on the ground to build a statgun', RED);
		end else WriteConsole(ID, 'You do not have a statgun', RED);
	end else WriteConsole(ID, 'You are not the mechanic', RED);
end;

end.
