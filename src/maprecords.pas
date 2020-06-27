// * --------------- *
// |   Map records   |
// * --------------- *

// This is a part of {LS} Last Stand.

// these functions are responsible for buffering already read maprecord files, to prevent spam with ReadFile in case when the same record file is requested several times in a row (score updates, loads, IC record exchanges, etc)
// map record is kept in memory as a list of lines, each being a different entry, prefixed with different index

// clears specified map record

unit MapRecords;

interface

uses
{$ifdef FPC}
  Scriptcore,
{$endif}
	Constants,
	Debug,
	Globals,
	LSPlayers,
	Misc,
	GameModes;

const
	INF_RECORD_POSITIONS = 3;
	
	IC_PATH = 'IC';
	IC_MODULE_ENABLED = true;
	IC_MODULE_PREFIX = 'LS';

type
	tICModule = record
		Active, ReceivedResponse, Connected: boolean;
		CurrentServ, ModuleID: byte;
		Serv: array of record
			Active: boolean;
			Style: byte;
		end;
	end;
		
	tPlayerRecord = record
		Points: integer;
		Name: string;
	end;
	
	tMapRecord = record
		Line: array of string;
		Path: String;
		Survival: record
			Value: integer;
			Shown: boolean;
			GonePlayers: array of tPlayerRecord;
		end;
		TopPlayers: record
			Loaded: boolean;
			Team: array [0..1] of array [0..INF_RECORD_POSITIONS - 1] of tPlayerRecord;
		end;
		BuffFile: record
			MapName, Fstr: string;
			Loaded, Saved: boolean;
			Entries: array of string;
		end;
	end;

var
	MapRecord: tMapRecord;
	IC: tICModule;
	
procedure MapRecord_ClearFile(Map: string);

// creates an empty file for the map
procedure MapRecord_Create(var Map: string; CreateFile: boolean);

// loads map file from hdd, if it doesn't exists then it creates a new one
procedure MapRecord_LoadFile(var Map: string);

// if changes haven't been saved on HHD yet then saves the file
procedure MapRecord_SaveFile();

// if file kept in memory is for different map, then it loads it
procedure MapRecord_ReadFile(var Map: string);

// reads specified map record elements
function MapRecord_ReadElement(var Map: string; index: char): string;

// indexes available for now: s: survival score line, i: infection score line
procedure MapRecord_SaveElement(var Map: string; data: string; index: char; AppendIndex: boolean);

procedure MapScore_LoadMapRecord(var Map: string);

procedure MapRecord_Delete(var Map: string);

procedure IC_Initialize();

// IC function, sends module-prefixed to other servers
procedure IC_SendData(Packet: string; ServID: shortint);

procedure SendScoreMsg_IC(var Map: string; wave: integer; points: integer);

procedure MapScore_Display(ID: byte);

procedure MapScore_UpdateRecord(Score: integer; Send: boolean);

procedure MapScore_UpdateTopPlayers(index: char); // index v/i - versus/infeciton

procedure CompareRecordFile_IC(var Map: String);

implementation

procedure MapRecord_ClearFile(Map: string);
begin
	if Map = MapRecord.BuffFile.MapName then begin
		MapRecord.BuffFile.Loaded := true;
		MapRecord.BuffFile.Saved := true;
		SetLength(MapRecord.BuffFile.Entries, 0);
		MapRecord.BuffFile.MapName := '';
		MapRecord.BuffFile.Fstr := '';
	end;
	Map := MapRecord.Path + Map + '.txt';
	if FileExists(Map) then begin
		WriteFile(Map, '');
		WriteDebug(5, 'Map record file cleared: ' + Map);
	end;
end;


// creates an empty file for the map
procedure MapRecord_Create(var Map: string; CreateFile: boolean);
begin
	MapRecord.BuffFile.Loaded := true;
	MapRecord.BuffFile.Saved := true;
	MapRecord.BuffFile.MapName := Map;
	SetLength(MapRecord.BuffFile.Entries, 0);
	if CreateFile then begin
		//Debug(4, 'Creating record file for ' + Map);
		WriteFile(MapRecord.Path + Map + '.txt', '');
		MapRecord.BuffFile.Fstr := '';
	end;
end;

// loads map file from hdd, if it doesn't exists then it creates a new one
procedure MapRecord_LoadFile(var Map: string);
var
	fn: string;
begin
	fn := MapRecord.Path + Map + '.txt';
	if FileExists(fn) then begin
		WriteDebug(4, 'Reading record file for ' + Map);
		MapRecord.BuffFile.Fstr := ReadFile(fn);
		if MapRecord.BuffFile.Fstr <> '' then begin
			MapRecord.BuffFile.MapName := Map;
			MapRecord.BuffFile.Entries := Explode2(MapRecord.BuffFile.Fstr, #13#10, false);
			MapRecord.BuffFile.Loaded := true;
			MapRecord.BuffFile.Saved := true;
		end else MapRecord_Create(Map, false);
	end else MapRecord_Create(Map, false);
end;

// if changes haven't been saved on HHD yet then saves the file
procedure MapRecord_SaveFile();
var
	i, x, k, max_i: smallint; h, n: byte; ignore: array of boolean;
begin
	if not MapRecord.BuffFile.Saved then begin // overwrite on hdd only if the  file has been modifed
		//Debug(4, 'Saving record file for ' + MapRecord.BuffFile.MapName + '');
		max_i := GetArrayLength(MapRecord.BuffFile.Entries);
		MapRecord.BuffFile.Fstr := '';
		SetLength(ignore, max_i);
		max_i := max_i - 1;
		{for i := 0 to max_i do begin
			MapRecord.BuffFile.Fstr := MapRecord.BuffFile.Fstr + MapRecord.BuffFile.Entries[i];
			if i < max_i then
				MapRecord.BuffFile.Fstr := MapRecord.BuffFile.Fstr + #13#10;
		end;}
		while k <= max_i do begin
			h := 0;
			for i := 0 to max_i do begin // save entries in alfabetic order of indexes, so the hash of the entire file always is the same
				if not ignore[i] then begin
					if MapRecord.BuffFile.Entries[i] <> '' then begin
						n := ord(MapRecord.BuffFile.Entries[i][1]);
						if n > h then begin
							h := n;
							x := i;
						end;
					end;
				end;
			end;
			if not ignore[x] then begin
				MapRecord.BuffFile.Fstr := MapRecord.BuffFile.Fstr + MapRecord.BuffFile.Entries[x];
				ignore[x] := true;
		//writeln(IntToStr(k) + '   ' + IntToStr(max_i));
				if k < max_i then
					MapRecord.BuffFile.Fstr := MapRecord.BuffFile.Fstr + #13#10;
			end;
			k := k + 1;
		end;
		WriteFile(MapRecord.Path + MapRecord.BuffFile.MapName + '.txt', MapRecord.BuffFile.Fstr);
		MapRecord.BuffFile.Saved := true;
	end;
end;

// if file kept in memory is for different map, then it loads it
procedure MapRecord_ReadFile(var Map: string);
begin
	if Map <> MapRecord.BuffFile.MapName then begin // if file kept in memory is different than requested one then reload it
		MapRecord_LoadFile(Map);
	end;
end;

// reads specified map record elements
function MapRecord_ReadElement(var Map: string; index: char): string;
var
	i: smallint;
begin
	MapRecord_ReadFile(Map);
	Result := '';
	if MapRecord.BuffFile.Loaded then
	try
		for i := 0 to GetArrayLength(MapRecord.BuffFile.Entries) - 1 do
			if MapRecord.BuffFile.Entries[i] <> '' then
				if MapRecord.BuffFile.Entries[i][1] = index then begin
					Result := Copy(MapRecord.BuffFile.Entries[i], 3, 9999);
					exit;
				end;
	except
		WriteDebug(10, 'Error occured parsing map record for ' + Map + ' (' + index + '): ' + ExceptionToString(ExceptionType, ExceptionParam));
	end;
end;

// indexes available for now: s: survival score line, i: infection score line
procedure MapRecord_SaveElement(var Map: string; data: string; index: char; AppendIndex: boolean);
var 
	i, l: smallint;
	found: boolean;
begin
	MapRecord_ReadFile(Map);
	if not MapRecord.BuffFile.Loaded then begin
		MapRecord_Create(Map, false);
	end;
	l := GetArrayLength(MapRecord.BuffFile.Entries);
	for i := 0 to l - 1 do begin
		if MapRecord.BuffFile.Entries[i] <> '' then begin
			if MapRecord.BuffFile.Entries[i][1] = index then begin
				if AppendIndex then begin
					MapRecord.BuffFile.Entries[i] := index + ':' + data;
				end else
					MapRecord.BuffFile.Entries[i] := data;
				found := true;
				break;
			end;
		end else begin // if some empty line found (?)
			if AppendIndex then begin
				MapRecord.BuffFile.Entries[i] := index + ':' + data;
			end else
				MapRecord.BuffFile.Entries[i] := data;
			found := true;
			break;
		end;
	end;
	if not found then begin
		SetArrayLength(MapRecord.BuffFile.Entries, l + 1);
		if AppendIndex then begin
			MapRecord.BuffFile.Entries[l] := index + ':' + data;
		end else
			MapRecord.BuffFile.Entries[l] := data;
		found := true;
	end;
	MapRecord.BuffFile.Saved := false;
end;

// ---

procedure MapScore_LoadMapRecord(var Map: string);
var
	str: string;
	arr, players: array of string;
	t, h: integer;
	i, j, Line: smallint;
	x, n: byte;
	index: char;
	added: array [0..1] of array [0..INF_RECORD_POSITIONS-1] of boolean;
begin
	//if (Modes.CurrentMode = 1) or (Modes.CurrentMode = 3) then begin
		case Modes.CurrentMode of
			1: index := 's';
			2: index := 'v';
			3: index := 'i';
		end;
		SetLength(MapRecord.Line, 0);
		MapRecord.Survival.Value := 0;
		MapRecord.TopPlayers.Loaded := false;
		str := MapRecord_ReadElement(Map, index);
		if str = '' then begin
			WriteDebug(10, 'No records for ' + Map);
			exit;
		end;
		try
			case Modes.CurrentMode of
				1: begin
					arr := Explode2(str, chr(182), false);
					//value-date-mode-zombies-civs-waves-time-mostkills-killer-playerlist
					t := StrToInt(arr[6]);
					SetArrayLength(MapRecord.Line, 6);
					MapRecord.Survival.Value := StrToInt(arr[0]);
					MapRecord.Line[0] := 'Survival high score - ' + Map + ' (' + arr[1] + ')';
					MapRecord.Line[1] := ' Score: ' + arr[0];// + '  (in ' + iif(arr[2] = '1', 'classic', 'hardcore') + ' mode)';
					MapRecord.Line[2] := ' Zombies Killed: ' + arr[3] + ',  Civilians alive: ' + arr[4];
					MapRecord.Line[3] := ' Waves survived: ' + arr[5] + ',  Time Survived: ' + IntToStr(t div 60) + ':' + iif(t mod 60 <= 9,'0','') + IntToStr(t mod 60); 
					MapRecord.Line[4] := ' Most Kills by ' + arr[8] + ': ' + arr[7];
					MapRecord.Line[5] := ' Team: ';
					players := Explode2(arr[9], chr(172), false);
					Line := 5;
					j := GetArrayLength(players) - 1;
					for i := 0 to j do begin
						if Length(MapRecord.Line[Line]) > 100 then begin
							Line := Line + 1;
							SetArrayLength(MapRecord.Line, Line + 1);
							MapRecord.Line[Line] := '       ';
						end;
						MapRecord.Line[Line] := MapRecord.Line[Line] + players[i];
						if i < j then begin
							if players[i+1] <> '' then begin
								MapRecord.Line[Line] := MapRecord.Line[Line] + ', ';
							end;
						end;
					end;
				end;
				2, 3: begin
					for x := 0 to 1 do 
						for i := 0 to INF_RECORD_POSITIONS-1 do begin
							MapRecord.TopPlayers.Team[x][i].Points := 0;
							MapRecord.TopPlayers.Team[x][i].Name := '';
						end;
					arr := Explode2(str, chr(182), false);
					Line := 1;
					SetArrayLength(MapRecord.Line, Line);
					if Modes.CurrentMode = 2 then begin
						MapRecord.Line[0] := 'Versus mode top players - ' + Map;
					end else
						MapRecord.Line[0] := 'Infection mode top players - ' + Map;
					for x := 0 to 1 do begin// two teams, survivors and zombies
						SetArrayLength(MapRecord.Line, Line + 1);
						if x = 0 then begin
							if arr[x] <> '' then begin
								MapRecord.Line[Line] := ' Top zombie destroyers (zombies killed):';
							end else continue;
						end else begin
							if arr[x] <> '' then begin
								MapRecord.Line[Line] := ' The nastiest zombies (damage done):';
							end else continue;
						end;
						Line := Line + 1;
						players := Explode2(arr[x], chr(172), false);
						j := GetArrayLength(players);
						if j > INF_RECORD_POSITIONS then j := INF_RECORD_POSITIONS;
						for i := 0 to j - 1 do begin
							MapRecord.TopPlayers.Team[x][i].Points := StrToIntDef(GetPiece(players[i], chr(175), 0), 0);
							MapRecord.TopPlayers.Team[x][i].Name := GetPiece(players[i], chr(175), 1);
						end;
						while true do begin
							n := 255;
							h := 0;
							for i := 0 to INF_RECORD_POSITIONS - 1 do begin // sorting the scores in the list
								if not added[x][i] then begin
									if MapRecord.TopPlayers.Team[x][i].Points > h then begin
										h := MapRecord.TopPlayers.Team[x][i].Points;
										n := i;
									end;
								end;
							end;
							if n = 255 then break; // break this loop loop if all players have been placed on the list
							if MapRecord.TopPlayers.Team[x][n].Points > 0 then begin
								SetArrayLength(MapRecord.Line, Line + 1);
								MapRecord.Line[Line] := '  - ' + MapRecord.TopPlayers.Team[x][n].Name + ': ' + IntToStr(MapRecord.TopPlayers.Team[x][n].Points);
								added[x][n] := true;
								Line := Line + 1;
							end;
						end;
						
					end;
					MapRecord.TopPlayers.Loaded := true;
				end;
			end;
		except
			MapRecord.Survival.Value := 0;
			MapRecord.TopPlayers.Loaded := false;
			WriteDebug(7, 'Error loading highscore for ' + Map + '(' + IntToStr(Modes.CurrentMode)+ '): ' + ExceptionToString(ExceptionType, ExceptionParam));
		end;
	//end;
end;

procedure MapRecord_Delete(var Map: string);
begin
	MapRecord_ClearFile(Map);
	if Map = CurrentMap then begin
		WriteConsole(0, 'The record for this map (' + Map + ') has been deleted by an admin', PINK);
		MapScore_LoadMapRecord(Map);
	end;
end;

// * ----------------------------------- *
// |  Interserver Communication module   |
// * ----------------------------------- *

// Last Stand I.C module used to exchange map records between LS servers

// IC function, registers IC module
procedure IC_Initialize();
begin
	IC.ModuleID := Crossfunc([Script.Name, IC_MODULE_PREFIX, true], IC_PATH + '.RegisterModule');
	if IC.ModuleID > 0 then begin // if registation successful
		IC.Active := true;
		WriteDebug(7, 'Registered LS IC module (' + IntToStr(IC.ModuleID) + ')');
	end else begin
		IC.Active := false;
		WriteDebug(10, 'Couldn''t register LS module, Interserver Communication script v2.2+ required (/scripts/' + IC_PATH + ')');
	end;
end;

// IC function, sends module-prefixed to other servers
procedure IC_SendData(Packet: string; ServID: shortint);
begin
	if ServID > 0 then begin
		Crossfunc([Packet, IC.ModuleID, ServID], IC_PATH + '.SendModuleMsg');
	end else
		for ServID := 1 to Length(IC.Serv) - 1 do
			if ServID <> IC.CurrentServ then
				if IC.Serv[ServID].Style = 2 then begin
					Crossfunc([Packet, IC.ModuleID, ServID], IC_PATH + '.SendModuleMsg');
				end;
end;

// ---

// Map records exchange protocol packets:
// h: general hash of the entire map record file exchange
// H: hashes of the specific record entries exchange
// i: specific record data transmission
// f: maprecord entries transmission
// map record entries prefixes: i: - infeciton, s: survival

const PACKET_SEPARATOR = #166;

procedure CompareRecord_IC(var Map: string; index: char; ServID: smallint);
var str: string; i: smallint;
begin
	if not IC.Active then exit;
	str := 'H ' + Map + PACKET_SEPARATOR; // map
	if (index = 's') or (index = '*') then
		str := str + 's:' + uIntToHex(FNV32(MapRecord_ReadElement(Map, 's'))) + PACKET_SEPARATOR; // checksum of the survival record
	if (index = 'i') or (index = '*') then
		str := str + 'i:' + uIntToHex(FNV32(MapRecord_ReadElement(Map, 'i'))) + PACKET_SEPARATOR; // checksum of the infection record
	if (index = 'v') or (index = '*') then
		str := str + 'v:' + uIntToHex(FNV32(MapRecord_ReadElement(Map, 'v'))); // checksum of the infection record
//writeln(MapRecord_ReadElement(Map, 'i'));
	if ServID > 0 then begin
		if ServID < Length(IC.Serv) then
			IC_SendData(str, ServID); // respond with map + score values
	end else
		for i := 1 to Length(IC.Serv) - 1 do
			if i <> IC.CurrentServ then
				if IC.Serv[i].Style = 2 then begin// send request to all ls type servers
					IC_SendData(str, i);
				end;
end;

procedure CompareRecordFile_IC(var Map: String);
var i: smallint; hash: string;
begin
	if not IC.Active then exit;
//debug(10, 'CompareRecordFile_IC(' + Map + ')');
	MapRecord_ReadFile(Map);
	for i := 1 to Length(IC.Serv) - 1 do
		if i <> IC.CurrentServ then
			if IC.Serv[i].Style = 2 then begin// send request to all ls type servers
				if hash = '' then begin
					hash := uIntToHex(FNV32(MapRecord.BuffFile.Fstr));
				end;
				IC_SendData('h ' + Map + PACKET_SEPARATOR + hash, i); // send hash of the map to all the servers
			end;
end;

procedure SendScoreMsg_IC(var Map: string; wave: integer; points: integer);
var i: shortint; buff: string;
begin
	for i := 1 to Length(IC.Serv) - 1 do
		if i <> IC.CurrentServ then
			if IC.Serv[i].Style = 2 then begin// send request to all ls type servers
				if buff = '' then begin
					buff := 'm ' + Map + PACKET_SEPARATOR + IntToStr(wave) + PACKET_SEPARATOR + IntToStr(points);
				end;
				IC_SendData(buff, i);
			end;
end;

// List of infection top players is sent here after being received from another ls server
// Infection maprecord is read from the local file, player lists from packet and the file are binded and the best players are chosen
// to remain in the list, packet is updated via reference to be sent to another server, updated record for the map is saved
procedure BindNSelectTopPlayerRec(var Map: string; var Packet: string; index: char); // index 'v'/'i' (versus/infeciton)
var str: string;
	team: array [0..1] of array of string;
	players: array [0..1] of array of tPlayerRecord;
	h: integer;
	i, j, l: smallint;
	x, n, k: byte;
begin
	if Packet <> '' then begin // bind player arrays from file and received packet, select the best players only
		str := MapRecord_ReadElement(Map, index);
		if str <> '' then begin
			team[0] := Explode2(GetPiece(str, chr(182), 0), chr(172), false);
			team[1] := Explode2(GetPiece(str, chr(182), 1), chr(172), false);
			team[0] := Explode2(GetPiece(Packet, chr(182), 0), chr(172), true);
			team[1] := Explode2(GetPiece(Packet, chr(182), 1), chr(172), true);
			Packet := '';
			for x := 0 to 1 do begin
				l := GetArrayLength(team[x]);
				SetLength(players[x], l);
				for i := 0 to l - 1 do begin
					players[x][i].Points := StrToIntDef(GetPiece(team[x][i], chr(175), 0), 0);
					players[x][i].Name := GetPiece(team[x][i], chr(175), 1);
					for j := 0 to i do begin // remove player if his name already exists in the array (result of binding two records)
						if i <> j then begin
							if players[x][i].Name = players[x][j].Name then begin	
								if players[x][i].Points > players[x][j].Points then players[x][j].Points := 0
								else players[x][i].Points := 0;
								break;
							end;
						end;
					end;
				end;
				k := 0;
				while k < INF_RECORD_POSITIONS do begin // choose only INF_RECORD_POSITIONS players (default 3)
					n := 255;
					h := 0;
					for i := 0 to l - 1 do begin
						if players[x][i].Points > 0 then begin
							if players[x][i].Points > h then begin
								h := players[x][i].Points;
								n := i;
							end;
						end;
					end;
					if n = 255 then break; // if there are no more players in this team
					k := k + 1;
					if k > 1 then Packet := Packet + chr(172);
					Packet := Packet + IntToStr(h) + chr(175) + players[x][n].Name;
					players[x][n].Points := 0;
				end;
				if x < 1 then
					Packet := Packet + chr(182);
			end;
		end;
		MapRecord_SaveElement(Map, Packet, index, true);
		if (Modes.CurrentMode = 3) or (Modes.CurrentMode = 2) then
			MapScore_LoadMapRecord(Map);
	end;
end;

// * -------------- *
// |   IC, Events   |
// * -------------- *

// event, received data comes here
procedure IC_OnDataReceived(Packet: string; ServID: shortint);
{$ifndef FPC}
var str, hash, data: string; i: smallint; P, Q: integer; arr: array of string; index: char;
{$endif}
begin
  {$ifndef FPC}
  case GetPiece(Packet, ' ', 0) of
		// retireving a hash of the entire mapfile
		'h': begin // <mapname> <separator> <hash>
			Delete(Packet, 1, 2);
			str := GetPiece(Packet, PACKET_SEPARATOR, 0); // get map
			if str <> nil then begin
				MapRecord_ReadFile(str);
				hash := uIntToHex(FNV32(MapRecord.BuffFile.Fstr)); // get checksum of the local file
				if hash <> GetPiece(Packet, PACKET_SEPARATOR, 1) then begin // if hashes are diffrent, ask for exact score values
					CompareRecord_IC(str, '*', ServID);
				end;
			end;
		end;
		
		'H': begin // if hash of the specific record entries received
			Delete(Packet, 1, 2);
			arr := Explode2(Packet, PACKET_SEPARATOR, false);
			if arr[0] <> nil then begin // map
				for i := 1 to GetArrayLength(arr) - 1 do begin
					if Length(arr[i]) > 2 then begin
						index := arr[i][1];
						str := MapRecord_ReadElement(arr[0], index);
						hash := uIntToHex(FNV32(str));
//writeln(hash +' || ' + Copy(arr[i], 3, $FFFF) + ' || ' + str);
						if hash <> Copy(arr[i], 3, $FFFF) then // compare calculated hash with received hash
						case index of
							's': begin
								str := GetPiece(str, chr(182), 0);
								if str = nil then str := '0';
								data := data + 's:' + str + PACKET_SEPARATOR;
							end;
							'i', 'v': begin
								if str = nil then begin // if local infection/vs record doesn't exists then request it
									data := data + index + ':~' + PACKET_SEPARATOR;
								end else // else send back local record so the second server parses it, compares with existing one, binds and sends back a new one
									data := data + index + ':' + str + PACKET_SEPARATOR;
							end;
						end;
					end;
				end;
			end;
			if data <> nil then
				IC_SendData('i ' + arr[0] + PACKET_SEPARATOR + data, ServID);
		end;

		'i': begin // more specific records info exchange
			Delete(Packet, 1, 2);
			arr := Explode2(Packet, PACKET_SEPARATOR, false);
			if arr[0] <> nil then begin // map
				for i := 1 to GetArrayLength(arr) - 1 do begin
					if Length(arr[i]) > 2 then begin
						index := arr[i][1];
						case index of
							's': begin
								str := MapRecord_ReadElement(arr[0], 's');
								P := StrToIntDef(GetPiece(str, chr(182), 0), 0); // value of score in local file
								Delete(arr[i], 1, 2);
								Q := StrToIntDef(arr[i], 0); // value of score from the packet
								if Q > P then begin // request survival record part
									data := data + 's:~';
								end else
								if Q < P then// send the local, higher survival record part
									data := data + 's:' + str;
								data := data + PACKET_SEPARATOR;
							end;
							'i', 'v': begin
								//data := data + 'i:' + MapRecord_ReadElement(arr[0], 'i') + PACKET_SEPARATOR;
								Delete(arr[i], 1, 2);
							//	str := arr[i];
								BindNSelectTopPlayerRec(arr[0], arr[i], index);
							//	if arr[i] <> str then // if list was modified
									data := data + index + ':' + arr[i] + PACKET_SEPARATOR;
							end;
						end;
					end;
				end;
			end;
			if data <> nil then begin // map
				IC_SendData('f ' + arr[0] + PACKET_SEPARATOR + data, ServID);
			end;
		end;

		'f': begin // file transfer
			Delete(Packet, 1, 2);
			arr := Explode2(Packet, PACKET_SEPARATOR, false);
			if arr[0] <> nil then begin // map
				for i := 1 to GetArrayLength(arr) - 1 do begin
					if Length(arr[i]) > 2 then begin
						index := arr[i][1];
						case index of
							's', 'i', 'v': begin
								if arr[i][2] = ':' then begin
									if arr[i][3] = '~' then begin // if requested the record
										str := MapRecord_ReadElement(arr[0], index);
										if str <> nil then begin
											data := data + index + ':' + str + PACKET_SEPARATOR;
										end;
									end else begin
										MapRecord_SaveElement(arr[0], arr[i], index, false);
										if (Modes.CurrentMode = 1) and (CurrentMap = arr[0]) then begin
											WriteConsole(0, 'Received higher record for this map from another LS server, high score has been updated', PINK);
											MapScore_LoadMapRecord(CurrentMap);
										end;
									end;
								end;
							end;
						end;
					end;
				end;
				if data <> nil then
					IC_SendData('f ' + arr[0] + PACKET_SEPARATOR + data, ServID);
				MapRecord_SaveFile();
			end;
		end;
		
		'd': begin
			Delete(Packet, 1, 2);
			str := GetPiece(Packet, PACKET_SEPARATOR, 0); // get map
			if str <> nil then
				MapRecord_Delete(str);
		end;
		
		'm': begin
			Delete(Packet, 1, 2);
			arr := Explode2(Packet, PACKET_SEPARATOR, false);
			WriteConsole(0, 'High score for ' + arr[0] + ' has been beaten on server #' + IntToStr(ServID) + '! (Wave: ' + arr[1] + ', Points: ' + arr[2] + ')', PINK);
		end;
	end;
  {$endif}
end;

// event, called when disconnected from IC relay
procedure IC_OnDisconnected();
begin
	IC.ReceivedResponse := false;
	IC.Connected := false;
end;

// event, list of servers is sent here
procedure IC_OnUpdateReceived(Packet: string);
var i, n: smallint;
begin
	try
		i := 1;
		IC.CurrentServ := ord(Packet[1]);
		SetLength(IC.Serv, 0);
		SetLength(IC.Serv, (Length(Packet) - 1) div 2 + 1);
		while i < Length(Packet)-1 do begin
			n := n + 1;
			i := i + 1;
			IC.Serv[n].Active := Packet[i] = '1';
			i := i + 1;
			IC.Serv[n].Style := ord(Packet[i]);
		end;
		IC.Connected := true;
	except
		WriteDebug(10, 'Invalid IC update packet');
	end;
	
	// after first connection, compare records for current map
	if not IC.ReceivedResponse then begin
		for i := 1 to Length(IC.Serv) - 1 do
			if IC.Serv[i].Active then
				if i <> IC.CurrentServ then
					if IC.Serv[i].Style = 2 then begin
						IC.ReceivedResponse := true;
						CompareRecordFile_IC(CurrentMap2);
						break;
					end;
	end;
end;

procedure MapScore_Display(ID: byte);
var i, l: shortint;
begin
	if ((Modes.CurrentMode = 1) and (MapRecord.Survival.Value > 0)) or (((Modes.CurrentMode = 3) or (Modes.CurrentMode = 2)) and (MapRecord.TopPlayers.Loaded)) then begin
		l := GetArrayLength(MapRecord.Line) - 1;
		for i := 0 to l do begin
			WriteConsole(ID, MapRecord.Line[i], PINK);
		end;
	end else
		WriteConsole(0, 'No record for this map yet', PINK);
end;

procedure MapScore_UpdateRecord(Score: integer; Send: boolean);
var i, killer, kills: integer; PlayerList, kn: string;
begin
	//value-date-zombies-civs-waves-time-mostkills-killer-playerlist
	for i := 1 to MAX_UNITS do
		if players[i].Active then
		if player[i].Participant = 1 then
		if player[i].Waves >= NumberOfWave div 4 then
			PlayerList := PlayerList + Players[i].Name + chr(172);
	
	for i := 0 to Length(MapRecord.Survival.GonePlayers) - 1 do
		if MapRecord.Survival.GonePlayers[i].Points >= NumberOfWave div 4 then
		if MapRecord.Survival.GonePlayers[i].Name <> '' then
			PlayerList := PlayerList + MapRecord.Survival.GonePlayers[i].Name + chr(172);
	
	killer := Players_MostKills();
	if killer > 0 then begin
		kills := player[killer].kills;
		kn := Players[Killer].Name;
	end else
		kn := '---';
		
	MapRecord_SaveElement(CurrentMap2, 
		IntToStr(Score) + chr(182) +
		FormatDate('h:nn, d.m.yyyy') + chr(182) +
		'2' + chr(182) +
		IntToStr(ZombiesKilled) + chr(182) +
		IntToStr(Civilians) + chr(182) +
		IntToStr(NumberOfWave) + chr(182) +
		IntToStr((Timer.Value div 60)) + chr(182) +
		IntToStr(kills) + chr(182) +
		kn + chr(182) + PlayerList,
	's', true);
	MapScore_LoadMapRecord(CurrentMap2);
	MapRecord_SaveFile(); // saves new/updated record file on HDD
	if Send then
		CompareRecord_IC(CurrentMap2, 's', 0);
end;

procedure MapScore_UpdateTopPlayers(index: char); // index v/i - versus/infeciton
var i, j: smallint; x, n: byte; value, h, diff: integer; change: boolean; str: string;
begin
	for x := 0 to 1 do begin // both teams, survivors, infection
		for i := 1 to MaxID do begin
			if players[i].Active then begin
				if (x = 1) then begin // filter out survivors
					if player[i].Participant >= 0 then continue;
					value := player[i].zombdamage;
				end else // filter out zombs
				begin
					if player[i].Participant <= 0 then continue;
					value := player[i].kills;
				end;
				// check player's score against scores in record
				h := 0;
				n := 255;
				str := Players[i].Name;
				for j := 0 to INF_RECORD_POSITIONS - 1 do begin // choose the lowest ones from record to replace if players have higher scores
				//	writeconsole(0, 'asd'+IntToStr(MapRecord.TopPlayers.Team[x][j].Points), red);
					if MapRecord.TopPlayers.Team[x][j].Name = str then begin // if such player already exists in record then place him on the same position
						if value > MapRecord.TopPlayers.Team[x][j].Points then begin
							n := j;
							break;
						end else break;
					end else begin
						diff := value - MapRecord.TopPlayers.Team[x][j].Points;
						if diff > h then begin
							h := diff;
							n := j;
						end;
					end;
				end;
				if n < 255 then begin
					if index = 'i' then begin
						WriteConsole(i, 'You have been added to the Infection mode, top player list of this map', PINK);
					end else
						WriteConsole(i, 'You have been added to the Versus mode, top player list of this map', PINK);
					MapRecord.TopPlayers.Team[x][n].Points := value;
					MapRecord.TopPlayers.Team[x][n].Name := str;
					change := true;
				end;
			end;
		end;
	end;
	if change then begin // create a new record
		str := '';
		for x := 0 to 1 do begin
			for i := 0 to INF_RECORD_POSITIONS - 1 do begin
				str := str + IntToStr(MapRecord.TopPlayers.Team[x][i].Points) + chr(175) + MapRecord.TopPlayers.Team[x][i].Name;
				if i < INF_RECORD_POSITIONS - 1 then str := str + chr(172); // insert delimiters
			end;
			if x = 0 then str := str + chr(182);
		end;
		MapRecord_SaveElement(CurrentMap2, str, index, true);
		MapScore_LoadMapRecord(CurrentMap2);
		MapRecord_SaveFile(); // saves new/updated record file on HDD
		CompareRecord_IC(CurrentMap2, index, 0);
	end;
end;

end.
