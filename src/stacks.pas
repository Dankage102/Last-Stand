unit Stacks;

interface

{$ifdef FPC}
uses Scriptcore;
{$endif}

type
	tStack8 = record
		length: integer;
		arr: array of byte;
	end;
	
	tStack16 = record
		length: integer;
		arr: array of word;
	end;
//  * -------------- *
//  |  Stack (byte)  |
//  * -------------- *

procedure stack8_clear(var Stack: tStack8);
procedure stack8_free(var Stack: tStack8);
//procedure stack8_pushback(var Stack: tStack8; Value: byte); // adds the value on the top
//procedure stack8_insert(var Stack: tStack8; Value: byte; Index: integer); // inserts the value on the nth position
procedure stack8_push(var Stack: tStack8; Value: byte); // adds the value on the bottom
function stack8_pop(var Stack: tStack8; index: integer): byte;
procedure stack8_alloc(var Stack: tStack8; n: integer);

//  * -------------- *
//  |  Stack (word)  |
//  * -------------- *

procedure stack16_alloc(var Stack: tStack16; n: integer);
procedure stack16_push(var Stack: tStack16; Value: word); // adds the value on the bottom
function stack16_pop(var Stack: tStack16; index: integer): word;
procedure stack16_clear(var Stack: tStack16);

implementation

procedure stack8_clear(var Stack: tStack8);
begin
	Stack.length := 0;
end;

procedure stack8_free(var Stack: tStack8);
begin
	Stack.length := 0;
	SetLength(Stack.arr, 0);
end;

{procedure stack8_pushback(var Stack: tStack8; Value: byte); // adds the value on the top
var x, i: integer;
begin
	x := Stack.length;
	Stack.length := Stack.length + 1;
	if GetArrayLength(Stack.arr) < Stack.length then
		SetArrayLength(Stack.arr, Stack.length);
	for i := x downto 1 do
		Stack.arr[i] := Stack.arr[i-1];
	Stack.arr[0] := Value;
end;

procedure stack8_insert(var Stack: tStack8; Value: byte; Index: integer); // inserts the value on the nth position
var x, i: integer;
begin
	x := Stack.length;
	Stack.length := Stack.length + 1;
	if GetArrayLength(Stack.arr) < Stack.length then
		SetArrayLength(Stack.arr, Stack.length);
	for i := x downto Index+1 do
		Stack.arr[i] := Stack.arr[i-1];
	Stack.arr[Index] := Value;
end;}

procedure stack8_push(var Stack: tStack8; Value: byte); // adds the value on the bottom
var x: integer;
begin
	x := Stack.length;
	Stack.length := Stack.length + 1;
	if Length(Stack.arr) < Stack.length then
		SetLength(Stack.arr, Stack.length);
	Stack.arr[x] := Value;
end;

function stack8_pop(var Stack: tStack8; index: integer): byte;
var i: integer;
begin
	Result := Stack.arr[index];
	Stack.length := Stack.length - 1;
	for i := index to Stack.length - 1 do
		Stack.arr[i] := Stack.arr[i+1];
end;

procedure stack8_alloc(var Stack: tStack8; n: integer);
begin
	if Length(Stack.arr) <> n then begin
		SetLength(Stack.arr, n);
		if n < Stack.length then Stack.length := n;
	end;
end;

//  * -------------- *
//  |  Stack (word)  |
//  * -------------- *

procedure stack16_alloc(var Stack: tStack16; n: integer);
begin
	if Length(Stack.arr) <> n then begin
		SetLength(Stack.arr, n);
		if n < Stack.length then Stack.length := n;
	end;
end;

procedure stack16_push(var Stack: tStack16; Value: word); // adds the value on the bottom
var x: integer;
begin
	x := Stack.length;
	Stack.length := Stack.length + 1;
	if Length(Stack.arr) < Stack.length then
		SetLength(Stack.arr, Stack.length);
	Stack.arr[x] := Value;
end;

function stack16_pop(var Stack: tStack16; index: integer): word;
var i: integer;
begin
	Result := Stack.arr[index];
	Stack.length := Stack.length - 1;
	for i := index to Stack.length - 1 do
		Stack.arr[i] := Stack.arr[i+1];
end;

procedure stack16_clear(var Stack: tStack16);
begin
	Stack.length := 0;
end;

finalization

end.
