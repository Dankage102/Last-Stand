unit PlacePlayer;

interface

uses
  {$ifdef FPC}
	  Scriptcore,
  {$endif}
  Constants,
  LSPlayers,
  Globals,
  Debug;


procedure SetTeam(Team, ID: byte; ServerSet: boolean);

procedure PutPlayer(ID, team: byte; X, Y: single; twice: boolean);

function PutBot(NewPlayer: TNewPlayer; X, Y: single; team: byte): TActivePlayer;

implementation

procedure SetTeam(Team, ID: byte; ServerSet: boolean);
begin
	ServerSetTeam := ServerSet;
	Command('/setteam'+IntToStr(Team)+' '+IntToStr(ID));
	//TODO: Temporary fix for OnJoinTeam not called for bots
	if not Players[ID].Human then 
		ServerSetTeam := False;
end;
	
procedure PutPlayer(ID, team: byte; X, Y: single; twice: boolean);
begin
  player[ID].X := X;
  player[ID].Y := Y;
  player[ID].RespawnAtXY := true;
  if players[ID].Team = team then begin
    players[ID].ChangeTeam(players[ID].Team, TJoinSilent);
  end else begin
    SetTeam(team, ID, true);
	  if twice then begin
		  SetTeam(team, ID, true);
	  end;
  end;
  player[ID].RespawnAtXY := false;
end;

function PutBot(NewPlayer: TNewPlayer; X, Y: single; team: byte): TActivePlayer;
var i: byte;
begin
  // Assuming that he will get the first available ID
  for i := 1 to MAX_UNITS do
  if not Players[i].Active then begin
    player[i].X := X;
    player[i].Y := Y;
    player[i].RespawnAtXY := true;
	  NewPlayer.Team := team;
	  Result := Players.Add(NewPlayer, TJoinSilent);
  	player[i].RespawnAtXY := false;
    break;
  end;
end;

end.
