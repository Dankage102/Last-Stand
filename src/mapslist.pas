unit mapslist;

interface

uses
  {$ifdef FPC}
  	Scriptcore,
  {$endif}
  Misc;

type
	tMapList = record
		Length, NumLines: smallint;
		List, InfoList: array of string;
	end;

var
	MapList: tMapList;
	
procedure MapList_Load();
	
implementation

procedure MapList_Load();
var n, k, l, i, j, x: smallint; str: string;
	row: array [0..2] of record
		h: smallint;
	end;
begin
	MapList.List := Explode2(ReadFile('mapslist.txt'), #13#10, false);
	MapList.Length := Length(MapList.List);
	for i := 0 to MapList.Length-1 do begin
		if MapList.List[i] = '' then begin // remove blank lines on the end?
			SetLength(MapList.List, i);
			MapList.Length := i;
			break;
		end;
	end;
	
	n := MapList.Length div 5;
	if n > 3 then n := 3 else
	if n = 0 then n := 1;
	k := MapList.Length div n + MapList.Length mod n;
	SetLength(MapList.InfoList, 0);;
	SetArrayLength(MapList.InfoList, k);
	MapList.NumLines := k;
	for i := 0 to n-1 do begin
		for j := 0 to k - 1 do begin
			x := i * k + j;
			if x >= MapList.Length then break;
			l := Length(MapList.List[x]);
			if row[i].h < l then
				row[i].h := l;
		end;
		row[i].h := row[i].h + 5;
		for j := 0 to k - 1 do begin
			x := i * k + j;
			if x >= MapList.Length then break;
			str := IntToStr(x + 1) + '. ' + MapList.List[x];
			if i < k-1 then
				str := str + StringOfChar(' ', row[i].h - Length(str));
			MapList.InfoList[j] := MapList.InfoList[j] + str;
		end;
	end;
end;

begin
end.
