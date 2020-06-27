unit Debug;

interface
	
uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Constants; // for debug level
	
procedure WriteDebug(Level: byte; Message: string);

procedure Assert(Condition: boolean; Message: string);

procedure WC(Text: string);
procedure WCr(Text: string);
procedure WCg(Text: string);

implementation

procedure WriteDebug(Level: byte; Message: string);
begin
	if Level >= DEBUGLEVEL then WriteLn('<LS> '+Message);
end;

procedure Assert(Condition: boolean; Message: string);
begin
	if Condition = false then WriteDebug(10, 'Assertion failed: ' + Message);
end;

procedure WC(Text: string);
begin
	WriteConsole(0, Text, $EEEEEE);
end;

procedure WCr(Text: string);
begin
	WriteConsole(0, Text, $EE0000);
end;

procedure WCg(Text: string);
begin
	WriteConsole(0, Text, $00EE00);
end;

begin
end.
