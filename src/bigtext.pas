unit BigText;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Misc;

const
	BIGTEXT_MT_NUM = 64;
	BIGTEXT_ST_NUM = 64;

procedure BigText_DrawMap(ID: byte; Text: string; Duration: integer; Colour: longint; Scale: single; X, Y: integer);
procedure BigText_DrawMapX(Layer: byte; ID: byte; Text: string; Duration: integer; Colour: longint; Scale: single; X, Y: integer);
procedure BigText_DrawScreen(ID: byte; Text: string; Duration: integer; Colour: longint; Scale: single; X, Y: integer);
procedure BigText_DrawScreenX(Layer: byte; ID: byte; Text: string; Duration: integer; Colour: longint; Scale: single; X, Y: integer);
procedure BigText_Init(ReservedMTNum, ReservedSTNum: byte);
	
implementation
	
type
	tText = record
		EndTime: LongInt;
	end;
	
	tTextPlayer = record
		ScreenText: array[0..BIGTEXT_ST_NUM] of tText;
		MapText: array[0..BIGTEXT_MT_NUM] of tText;
	end;
	
var
	MT_First: byte;
	ST_First: byte;
	TextPlayer: array [1..32] of tTextPlayer;
	
procedure BigText_Init(ReservedMTNum, ReservedSTNum: byte);
begin
	MT_First := ReservedMTNum;
	ST_First := ReservedSTNum;
end;

procedure BigText_DrawS(ID: byte; var Text: string; Duration: integer; Colour: longint; Scale: single; X, Y: integer);
var i: byte;
begin
	for i := ST_First to BIGTEXT_ST_NUM do begin
		if TextPlayer[ID].ScreenText[i].EndTime <= Game.TickCount then begin
			TextPlayer[ID].ScreenText[i].EndTime := Game.TickCount + Duration;
			Players[ID].BigText(i, Text, Duration, Colour, Scale, X, Y);
			break;
		end
	end;
end;

procedure BigText_DrawM(ID: byte; var Text: string; Duration: integer; Colour: longint; Scale: single; X, Y: integer);
var i: byte;
begin
	for i := MT_First to BIGTEXT_MT_NUM do begin
		if TextPlayer[ID].MapText[i].EndTime <= Game.TickCount then begin
			TextPlayer[ID].MapText[i].EndTime := Game.TickCount + Duration;
			Players[ID].WorldText(i, Text, Duration, Colour, Scale, X, Y);
			break;
		end
	end;
end;

procedure BigText_DrawScreen(ID: byte; Text: string; Duration: integer; Colour: longint; Scale: single; X, Y: integer);
var i: byte;
begin
	if ID = 0 then begin
		for i := 1 to MaxID do begin
			if Players[i].Human then
			if Players[i].Active then
				BigText_DrawS(i, Text, Duration, Colour, Scale, X, Y);
		end;
	end else begin
		BigText_DrawS(ID, Text, Duration, Colour,  Scale, X, Y);
	end;
end;

procedure BigText_DrawScreenX(Layer: byte; ID: byte; Text: string; Duration: integer; Colour: longint; Scale: single; X, Y: integer);
begin
	if ID = 0 then begin
		Players.BigText(Layer, Text, Duration, Colour, Scale, X, Y);
	end else begin
		Players[ID].BigText(Layer, Text, Duration, Colour, Scale, X, Y);
	end;
end;

procedure BigText_DrawMap(ID: byte; Text: string; Duration: integer; Colour: longint; Scale: single; X, Y: integer);
var i: byte;
begin
	if ID = 0 then begin
		for i := 1 to MaxID do begin
			if Players[i].Human then
			if Players[i].Active then
				BigText_DrawM(i, Text, Duration, Colour, Scale, X, Y);
		end;
	end else begin
		BigText_DrawM(ID, Text, Duration, Colour,  Scale, X, Y);
	end;
end;

procedure BigText_DrawMapX(Layer: byte; ID: byte; Text: string; Duration: integer; Colour: longint; Scale: single; X, Y: integer);
begin
	if ID = 0 then begin
		Players.WorldText(Layer, Text, Duration, Colour,  Scale, X, Y);
	end else begin
		Players[ID].WorldText(Layer, Text, Duration, Colour,  Scale, X, Y);
	end;
end;

begin
end.
