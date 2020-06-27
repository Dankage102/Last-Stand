//  * ------------- *
//  |      INI      |
//  * ------------- *

unit INI;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Misc;

type
	tINI = record
		Section: array of record
			Name: string;
			Key: array of record
				Name, Value: string;
			end;
		end;
	end;

function INI_Load(var IniFile: tINI; FileName: string): boolean;
	
function INI_Get(var IniFile: tINI; Section, Key, Default: string; var FoundKey: boolean): string;

procedure INI_Set(var IniFile: tINI; Section, Key, Value: string; var changed: boolean);

procedure INI_Save(var IniFile: tINI; FilePath: string);

procedure INI_Clear(var IniFile: tINI);

implementation

function INI_Load(var IniFile: tINI; FileName: string): boolean;
var line: array of string; ffile: string; i, sec, sect, key, keyn, p: integer;
begin
	if FileExists(FileName) then
		ffile := ReadFile(FileName);
	if ffile <> '' then begin
		line := Explode2(ffile, #13#10, false);
		for i := 0 to GetArrayLength(line) - 1 do
			if line[i] <> '' then begin
				if line[i][1] = '[' then
					if ContainsString(line[i], ']') then begin
						sec := sect;
						sect := sect + 1;
						SetLength(IniFile.Section, sect);
						IniFile.Section[sec].Name := Copy(line[i], 2, Pos(']', line[i]) - 2);
						keyn := 0;
						continue
					end;
				if sect > 0 then begin
					p := pos('=', line[i]);
					if p > 0 then begin
						key := keyn;
						keyn := keyn + 1;
						SetLength(IniFile.Section[sec].Key, keyn);
						IniFile.Section[sec].Key[key].Name := Copy(line[i], 1, p-1);
						IniFile.Section[sec].Key[key].Value := Copy(line[i], p + 1, Length(line[i]) - p);
					end;
				end;
			end;
		Result := true;
	end;
end;
	
function INI_Get(var IniFile: tINI; Section, Key, Default: string; var FoundKey: boolean): string;
var i, j: integer;
begin
	Result := '';
	FoundKey := false;
	for i := 0 to Length(IniFile.Section) - 1 do
		if IniFile.Section[i].Name = Section then begin
			for j := 0 to Length(IniFile.Section[i].Key) - 1 do
				if IniFile.Section[i].Key[j].Name = Key then begin
					Result := IniFile.Section[i].Key[j].Value;
					FoundKey := true;
					break;
				end;
			break;
		end;
	if Result = '' then Result := Default;
end;

procedure INI_Set(var IniFile: tINI; Section, Key, Value: string; var changed: boolean);
var i, j, l: integer; found: boolean;
begin
	l := Length(IniFile.Section);
	for i := 0 to l - 1 do // check if the section exists
		if IniFile.Section[i].Name = Section then begin
			found := true;
			break;
		end;

	if not found then begin // if not, create one
		SetLength(IniFile.Section, l + 1);
		Inifile.Section[l].Name := Section;
		i := l;
	end else found := false;
	
	l := Length(IniFile.Section[i].Key);
	for j := 0 to l - 1 do // check if the key exists
		if IniFile.Section[i].Key[j].Name = Key then begin
			found := true;
			break;
		end;
	
	if not found then begin // if not, create one
		SetLength(IniFile.Section[i].Key, l + 1);
		Inifile.Section[i].Key[l].Name := Key;
		j := l;
	end;
	Inifile.Section[i].Key[j].Value := Value; // save the value
	changed := true;
end;

procedure INI_Save(var IniFile: tINI; FilePath: string);
var ffile: string; i, j: integer;
begin
	for i := 0 to Length(IniFile.Section) - 1 do begin
		ffile := ffile + '[' + IniFile.Section[i].Name + ']' + #13#10;
		for j := 0 to Length(IniFile.Section[i].Key) - 1 do
			ffile := ffile + IniFile.Section[i].Key[j].Name + '=' + IniFile.Section[i].Key[j].Value + #13#10;
		ffile := ffile + #13#10;
	end;
	WriteFile(FilePath, ffile);
end;

procedure INI_Clear(var IniFile: tINI);
begin
	SetLength(IniFile.Section, 0);
end;
{
procedure OnIniCommand(ID: byte; str: string);
var str2, str3, str4: string; i, j, l: smallint; showkey, found: boolean;
begin
	case LowerCase(GetPiece(str, ' ', 0)) of
		'help': begin
			WriteMessage(ID, 'Commands:', ADM_INT1);
			WriteMessage(ID, ' load <path>        : loads the file', ADM_INT1);
			WriteMessage(ID, '   <path> may be: ''mapset'', ''news'' or a direct path to the file', ADM_INT1);
			WriteMessage(ID, ' show <?sec> <?key> : displays the whole file, section or they key', ADM_INT1);
			WriteMessage(ID, '   <sec> may be ID or name', ADM_INT1);
			WriteMessage(ID, ' set <sec> <key>    : sets the value', ADM_INT1);
			WriteMessage(ID, ' clear              : resets the file', ADM_INT1);
			WriteMessage(ID, ' save               : saves the loaded file', ADM_INT1);
			WriteMessage(ID, ' close              : closes the file (without saving)', ADM_INT1);
		end;
		'load': begin
			INI_Clear(iini);
			str2 := GetPiece(str, ' ', 1);
			if str2 = 'mapsettings' then str2 := LSMap.Settings.Path else
			if str2 = 'news' then str2 := News.FilePath else
			if str2 = 'config' then str2 := ConfigPath;
			if INI_Load(iini, str2) then begin
				WriteMessage(ID, 'File (' + str2 + ') loaded; Sections:', ADM_INT1);
				for i := 0 to Length(iini.Section) - 1 do
					WriteMessage(ID, IntToStr(i) + '. ' + iini.Section[i].Name, ADM_INT1);
				iinipath := str2;
			end else begin
				WriteMessage(ID, 'No such file (' + str2 + ')', ADM_INT1);
				iinipath := '';
			end;
		end;
		'show': if iinipath <> nil then begin
			str2 := GetPiece(str, ' ', 1);
			if str2 <> nil then begin
				try i := StrToInt(str2);
				except i := -1;
				end;
				str3 := GetPiece(str, ' ', 2);
				if i < Length(iini.Section) then begin
					if i >= 0 then begin
						if str3 = nil then begin
							ShowSection(i, ID);
						end else showkey := true;
					end else begin
						str2 := LowerCase(str2);
						for i := 0 to Length(iini.Section) - 1 do begin
							if LowerCase(iini.Section[i].Name) = str2 then begin
								if str3 = nil then begin
									ShowSection(i, ID);
								end else
									showkey := true;
								found := true;
								break;
							end;
						end;
						if not found then WriteMessage(ID, 'Section "' + str2 + '" not found', ADM_INT1);
					end;
					if showkey then begin
						try j := StrToInt(str3);
						except j := -1;
						end;
						if j < Length(iini.Section[i].Key) then begin
							if j >= 0 then begin
								WriteMessage(ID, '[' + iini.Section[i].Name + '] ' + iini.Section[i].Key[j].Name + '=' + iini.Section[i].Key[j].Value, ADM_INT1);
							end else begin
								str3 := LowerCase(str3);
								for j := 0 to Length(iini.Section[i].Key) - 1 do
									if LowerCase(iini.Section[i].Key[j].Name) = str3 then begin
										WriteMessage(ID, '[' + iini.Section[i].Name + '] ' + iini.Section[i].Key[j].Name + '=' + iini.Section[i].Key[j].Value, ADM_INT1);
										found := true;
										break;
									end;
								if not found then WriteMessage(ID, 'No such key', ADM_INT1);
							end;
						end else WriteMessage(ID, 'No such key', ADM_INT1);
					end;
				end;
			end else
				for i := 0 to Length(iini.Section) - 1 do begin
					WriteMessage(ID, '', ADM_INT1);
					ShowSection(i, ID);
				end;
		end else WriteMessage(ID, ERR_NOFILE, ADM_INT1);
		'set': if iinipath <> nil then begin
			str2 := GetPiece(str, ' ', 1);
			if str2 <> nil then begin
				str3 := GetPiece(str, ' ', 2);
				if str3 <> nil then begin
					l := Length(iini.Section);
					try i := StrToInt(str2);
					except i := -1;
					end;
					if i < 0 then begin
						str4 := LowerCase(str2);
						for i := 0 to l - 1 do // check if the section exists
							if LowerCase(iini.Section[i].Name) = str4 then begin
								found := true;
								break;
							end;
					end else begin
						if i < l then found := true else begin
							WriteMessage(ID, 'No such section (' + IntToStr(i) + ')', ADM_INT1);
							exit;
						end;
					end;
					if not found then begin // if not, create one
						SetLength(iini.Section, l + 1);
						iini.Section[l].Name := str2;
						i := l;
						WriteMessage(ID, 'Created section (' + str2 + ')', ADM_INT1);
						showkey := true;
					end else found := false;
					l := Length(iini.Section[i].Key);
					try j := StrToInt(str3);
					except j := -1;
					end;
					if j < 0 then begin
						str4 := LowerCase(str3);
						for j := 0 to l - 1 do // check if the key exists
							if LowerCase(iini.Section[i].Key[j].Name) = str4 then begin
								found := true;
								break;
							end;
					end else begin
						if j < l then found := true else begin
							WriteMessage(ID, iif(showkey, 'Invalid key (number as a key name is not allowed) ', 'No such key (' + IntToStr(j) + ')'), ADM_INT1);
							exit;
						end;
					end;
					if not found then begin // if not, create one
						SetLength(iini.Section[i].Key, l + 1);
						iini.Section[i].Key[l].Name := str3;
						WriteMessage(ID, 'Created key (' + str3 + ')', ADM_INT1);
						j := l;
					end;
					l := Pos2(' ', str, 2);
					if l > 0 then begin
						iini.Section[i].Key[j].Value := Copy(str, l+1, Length(str) - l); // save the value
					end else
						iini.Section[i].Key[j].Value := '';
					OnIniCommand(ID, 'show ' + str2 + ' ' + str3); // was too lazy to do it in other way
				end else WriteMessage(ID, ERR_ARG, ADM_INT1);
			end else WriteMessage(ID, ERR_ARG, ADM_INT1);
		end else WriteMessage(ID, ERR_NOFILE, ADM_INT1);
		'clear': if iinipath <> nil then begin
			INI_Clear(iini);
			WriteMessage(ID, 'File reset', ADM_INT1);
		end else WriteMessage(ID, ERR_NOFILE, ADM_INT1);
		'save': if iinipath <> nil then begin
			WriteMessage(ID, 'File (' + iinipath + ') saved', ADM_INT1);
			INI_Save(iini, iinipath);
		end else WriteMessage(ID, ERR_NOFILE, ADM_INT1);
		'close': begin
			WriteMessage(ID, 'File (' + iinipath + ') closed', ADM_INT1);
			iinipath := '';
			INI_Clear(iini);
		end else WriteMessage(ID, ERR_NOFILE, ADM_INT1);
	end;
end;
}

begin
end.
