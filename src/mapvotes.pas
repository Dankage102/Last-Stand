//  * ------------- *
//  |  Vote system  |
//  * ------------- *

// This is a part of {LS} Last Stand.

unit MapVotes;

interface

uses
{$ifdef FPC}
  Scriptcore,
{$endif}
	Constants,
	Debug,
	Globals,
	lsplayers,
	MapsList,
	MersenneTwister,
	Misc,
	configs;

const
	VOTE_RANDOM = -2;	//Vote for a random map
	
function MapVotes_VotedNum(): byte;

procedure MapVotes_Reset();

procedure MapVotes_OnVote(ID: byte; voteID: smallint);

procedure MapVotes_OnUnVote(ID: byte);

procedure MapVotes_Process();

procedure MapVotes_OnPlayerLeave(Player: tActivePlayer);

implementation

var
	CheckVotes: boolean;

function MapVotes_VotedNum(): byte;
var
	i: byte;
begin
	Result:= 0;
	for i := 1 to MaxID do
		if Players[i].Active then
			if player[i].VoteReady then
				Result := Result + 1;
end;

procedure MapVotes_Reset();
var
	i: byte;
begin
	for i := 1 to MaxID do
		if Players[i].Active then
			if Players[i].Human then
				player[i].VoteReady := false;
end;

procedure MapVotes_OnVote(ID: byte; voteID: smallint);
var a: smallint; str: string;
begin
	if (not VOTEROUND) and (GameRunning) then begin
		WriteConsole(ID, 'You can''t vote during a round. Please wait.', INFORMATION ); 
		exit;
	end;

	// vote id = map id + 1
	if ((voteID <= MapList.Length) and (voteID >= 0)) or (voteID = VOTE_RANDOM) then begin
		if voteID = 0 then begin
			a := LSMap.CurrentNum;
		end else if voteID = VOTE_RANDOM then
			a := voteID
		else a := voteID - 1;
		
		if ((player[ID].VoteReady) and (a = player[ID].VotedMap)) then
		begin
			WriteConsole(ID, 'You already voted for this option', RED);
			exit;
		end;
		
		player[ID].VotedMap := a;

		str := Players[ID].Name;
		if (player[ID].VoteReady) then
			str := Players[ID].Name + ' has changed his vote to '
		else str := Players[ID].Name + ' has voted for ';

		player[ID].VoteReady := true;
		Player[ID].Autovote := Player[ID].StoreAutoVote;
		
		if player[ID].VotedMap = LSMap.CurrentNum then
			str := str + 'the current map [' + IntToStr(MapVotes_VotedNum()) + '/' + IntToStr(Players_HumanNum()) + ']'
		else if voteID = VOTE_RANDOM then
			str := str + 'a random map [' + IntToStr(MapVotes_VotedNum()) + '/' + IntToStr(Players_HumanNum()) + ']'
		else
			str := str + MapList.List[player[ID].VotedMap]  + '('+IntToStr(voteID)+') [' + IntToStr(MapVotes_VotedNum()) + '/' + IntToStr(Players_HumanNum()) + ']';
				
		WriteConsole(0, str, GREEN);
		WriteDebug(4, str);
		
		if MapVotes_VotedNum() = 1 then
		for a := 1 to MaxID do
		if a <> ID then begin
			WriteConsole(a, 'Type /vote to vote for starting the game on the current map', GREEN); 
			WriteConsole(a, 'Use /votehelp for more information, /list for a list of votes', GREEN); 
		end;
		CheckVotes := true;
	end
		else WriteConsole(ID, 'This vote option does not exist, use numbers 1-' + IntToStr(MapList.Length), GREEN);
end;

procedure MapVotes_OnUnVote(ID: byte);
begin
	if (not VOTEROUND) and (GameRunning) then begin
		WriteConsole(ID, 'You can''t vote during a round. Please wait.', INFORMATION ); 
		exit;
	end;
	if player[ID].VoteReady then 
	begin						
		player[ID].VoteReady := false;
		Player[ID].AutoVote := False;
		WriteConsole( 0, Players[ID].Name + ' removed his vote. ', RED);
	end;
end;

procedure MapVotes_Check();
var choosenVote: smallint;
	i, x, h, n: smallint; occ: array of byte;
	randomPick: byte;
	votedOption: array of byte;
begin
	if Players_HumanNum() = 0 then exit;
	if MapVotes_VotedNum() < Players_HumanNum() then exit;
	
	SetLength(votedOption, MapList.Length + 1);	//Last entry if current map isn't on the list
	
	for i := 0 to MapList.Length do
		votedOption[i] := 0;
	
	//Choose a random map for those who voted random
	randomPick := RandInt_(MapList.Length-1);
		
	for i := 1 to MAX_UNITS do
		if Players[i].Active then
			if Players[i].Human then begin
				//writeln(IntToStr(i) + ' voted ' + maplist.list[player[i].VotedMap] + ' (' + IntToStr(player[i].VotedMap) + '/' + IntToStr(GetArrayLength(maplist.list)-1) + ',' + IntToStr(maplist.length-1) + ')');
				if Player[i].VotedMap = VOTE_RANDOM then
					Player[i].VotedMap := randomPick;
				
				if Player[i].VotedMap = -1 then votedOption[MapList.Length] := votedOption[MapList.Length] + 1
				else votedOption[player[i].VotedMap] := votedOption[player[i].VotedMap] + 1;
			end;

	// choose the winning option
	SetLength(occ, MapList.Length+1);
	for i := 0 to MapList.Length do begin
		if votedOption[i] > x then begin
			x := votedOption[i];
			h := i;
			n := 1;
			occ[0] := i;		
		end else if votedOption[i] = x then begin
			occ[n] := i;
			n := n + 1;
		end;
	end;
	if n <= 1 then choosenVote := h else
	choosenVote := occ[RandInt(0, n - 1)];
	WriteDebug(5, 'Vote result: '+IntToStr(choosenVote));
	
	if choosenVote = LSMap.CurrentNum then begin
		WriteConsole( 0, 'Vote successful', GREEN);
		if (TimeLeft = 0) or (TimeLeft >= 60 * MAPSWITCHTIME) then begin
			PerformStartMatch := true;
		end else begin
			MapchangeStart := true;
			GameRunning := false;
			StartGame := false;
			Command('/restart');
		end;
	end else begin
		switchMapTime := 2;
		switchMapMap := choosenVote;
		GameRunning := false;
		StartGame := false;
		MapchangeStart := true;
		PlayerLeft := false;
		WriteConsole( 0, 'Vote successful, changing the map to ' +MapList.List[choosenVote], GREEN);
	end;
	for i := 1 to MAX_UNITS do
		player[i].VoteReady := false;
end;

procedure MapVotes_Process();
var
	i: byte;
begin
	if not StartGame then begin
		if TimeLeft mod 3 = 0 then
		for i := 1 to MaxID do
			if Player[i].AutoVote then
			if not Player[i].VoteReady then
			if player[i].Status = 0 then
				MapVotes_OnVote(i, 0);
				
		if CheckVotes then begin
			MapVotes_Check();
			CheckVotes := false;
		end;
	end;
end;

procedure MapVotes_OnPlayerLeave(Player: tActivePlayer);
begin
	if Player.Human then
		CheckVotes := true;
end;

end.
