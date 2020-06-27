//  * ------------------ *
//  |  Flashing messages |
//  * ------------------ *

unit FlashMSG;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Bigtext,
	Constants,
	Globals;

type
	tFlashMsg = record
		Color, Color2: longint;
		Active: boolean;
		Text: string;
		Count: byte;
	end;
	
var
	FMSG: tFlashMsg;
	
procedure FMSG_Draw(Text: string; Time: byte; Color, Color2: longint);

procedure FMSG_Process();
	
implementation

procedure FMSG_Draw(Text: string; Time: byte; Color, Color2: longint);
begin
	FMSG.Active := true;
	FMSG.Text := Text;
	FMSG.Count := Time;
	FMSG.Color := Color;
	FMSG.Color2 := Color2;
end;

procedure FMSG_Process();
begin
	if FMSG.Active then begin
		if FMSG.Count <= 3 then
		BigText_DrawScreenX(DTL_FMSG, 0, FMSG.Text, 300, iif(FMSG.Count mod 2 = 1, FMSG.Color, FMSG.Color2), 0.10, 20,388);
		FMSG.Count := FMSG.Count - 1;
		if FMSG.Count = 0 then FMSG.Active := false;
	end;
end;

begin
end.
