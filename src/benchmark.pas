unit Benchmark;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Bigtext,
  Misc;

function Clock(): longint;

procedure TimeStats_Start(EventName: string);

procedure TimeStats_End(EventName: string);

procedure TimeStats_Show(ID: byte);

procedure TimeStats_ToggleAOIDBG();

implementation

type
	tEventStatistic = record
		Active: boolean;
		EventName: string;
		Value, MinVal, AvgSum, MaxVal: longint;
		AvgCounter: byte;
	end;

const MAX_EVENTS = 15;
var
	TickStatistics: array[1..MAX_EVENTS] of tEventStatistic;

function Clock(): longint;
var hour, minute, second, ms: longint;
begin
	hour := StrToInt(FormatDate('h'));
	minute := StrToInt(FormatDate('n'));
	second := StrToInt(FormatDate('s'));
	ms := StrToInt(FormatDate('z'));
	Result := ms + second * 1000 + minute * 60000 + hour * 3600000;
end;

procedure TimeStats_Start(EventName: string);
var i: byte;
begin
	for i := 1 to MAX_EVENTS do
		if TickStatistics[i].Active then
		begin
			if TickStatistics[i].EventName = EventName then
			begin
				TickStatistics[i].Value := Clock();
				break;
			end;
		end else begin
			TickStatistics[i].Active := True;
			TickStatistics[i].EventName := EventName;
			TickStatistics[i].Value := Clock();
			TickStatistics[i].MinVal := 100000;
			TickStatistics[i].MaxVal := 0;
			TickStatistics[i].AvgSum := 0;
			TickStatistics[i].AvgCounter := 0;
			WriteLn('Initialised >> ' + EventName);
			break;
		end;
end;

var T: single;
var T2: single;
var dbg_aoi_time: boolean;
procedure TimeStats_End(EventName: string);
var i: byte;
	ticks: longint;
begin
	for i := 1 to MAX_EVENTS do
		if TickStatistics[i].Active then
		begin
			if TickStatistics[i].EventName = EventName then
			begin
				ticks := TickStatistics[i].Value;
				TickStatistics[i].Value := Clock();
				ticks := TickStatistics[i].Value - ticks;
				if ticks < 0 then exit;

				if TickStatistics[i].MinVal > ticks then
					TickStatistics[i].MinVal := ticks;
				if TickStatistics[i].MaxVal < ticks then
					TickStatistics[i].MaxVal := ticks;
				if TickStatistics[i].AvgCounter < 200 then
				begin
					TickStatistics[i].AvgCounter := TickStatistics[i].AvgCounter + 1;
					TickStatistics[i].AvgSum := TickStatistics[i].AvgSum + ticks;
				end;
		
				if dbg_aoi_time then
				if (TickStatistics[i].EventName	= 'AppOnIdle') then begin
					T := T*0.99 + 0.01*ticks;
					if ticks > T2 then begin
						T2 := Ticks;
					end else begin
						T2 := T2*0.995 + 0.005*ticks;
					end;
					if Game.TickCount mod 6 = 0 then
						BigText_DrawScreenX(111, 0, 'AOI: avg: ' + FormatFloat('0.0', T) + #13#10 +
													'     max: ' + FormatFloat('0.0', T2) + #13#10  +
													'     [ms]', 70, $FFFFFF, 0.05, 600, 300);	
				end;
				break;
			end
		end
		else break;
end;

procedure TimeStats_Show(ID: byte);
var i: integer;
begin
	for i := 1 to MAX_EVENTS do
	begin
		if (TickStatistics[i].Active = false) then break;

		WriteMessage(ID, ' ', $FFFFFF);
		WriteMessage(ID, 'Statistic for: [' + TickStatistics[i].EventName + ']', $FFFFFF);
		if (TickStatistics[i].AvgCounter > 0) then
			WriteMessage(ID, 'Average ms: ' + FloatToStr(TickStatistics[i].AvgSum / TickStatistics[i].AvgCounter), $FFFFFF);
		WriteMessage(ID, 'Minimium ms value: ' + IntToStr(TickStatistics[i].MinVal), $FFFFFF);
		WriteMessage(ID, 'Maximum ms value: ' + IntToStr(TickStatistics[i].MaxVal), $FFFFFF);
		WriteMessage(ID, '#Calls: ' + IntToStr(TickStatistics[i].AvgCounter), $FFFFFF);
	end;
end;

procedure TimeStats_ToggleAOIDBG();
begin
	dbg_aoi_time := not dbg_aoi_time;
end;

begin
end.
