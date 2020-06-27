unit Misc;
// miscellaneous functions free of LS dependences.

interface

uses
  {$ifdef FPC}
    Scriptcore,
  {$endif}
	Debug,
	MersenneTwister;

const MAXLINT = $FFFFFFFF;

var
	MaxID: byte;
	TmpPath: string;
	
type
	tArrPointer = record
		val: longint;
		index: integer;
	end;

	//TStringArray = record
  //  arr: array of string;
  //end;

procedure GetMaxID();

procedure Weapons_Force(ID, Primary, Secondary, PAmmo, SAmmo: byte);

function Objects_Spawn(X, Y: single; style: byte): byte;

procedure QuickSort(var Field: array of tArrPointer; Left, Right: integer);

//function IsBetween(a, b, c: integer): boolean;

procedure WriteMessage(ID: byte; Text: string; Color: longint);

function Explode2(Source: string; const Delimiter: string; Append: boolean): TStringArray;

function StrToId(s: string; ID: byte): byte;

function UIntToHex(Int: cardinal): string;

function FNV32(s: string): cardinal;

function Pos2(needle, haystack: string; n: smallint): word;

procedure nova_2(X,Y,dir_x,dir_y,r,speed,power,cutoff,start: single; n: word; style, id: byte);

procedure nova_3(X,Y,dir_x,dir_y,r,speedmin,speedmax,power,cutoff,start: single; n: word; style, id: byte);

function Dots(n: byte): string;

procedure incB(var n: byte; k: smallint);

procedure incW(var n: word; k: smallint);

function pl(n: byte): string;

function t2s(ticks: longint): longint;

function FormatTime(time_m: cardinal): string;

procedure WriteTmpFlag(name, str: string);

function ReadTmpFlag(name: string): string;

function RG_Gradient(degree, color_intensity: single): integer;

procedure Shoot(x, y, Angle, add_vx, add_vy, vmin, vmax, Spread, Accuracy, Damage: single; Style, ID, n: byte);

procedure CreateBulletX(X,Y,VelX,VelY,HitM: Single; sStyle, Owner: Byte);

implementation
  
const
	Hex_Charset = '0123456789ABCDEF';
	FNV_PRIME_32 = 16777619;
	FNV_OFFSET_32 = 2166136261;

function Explode2(Source: string; const Delimiter: string; Append: boolean): TStringArray;
var
  Position, DelLength, ResLength: integer;
begin
  DelLength := Length(Delimiter);
  Source := Source + Delimiter;
  if Append then ResLength := Length(Result);
  repeat
    Position := Pos(Delimiter, Source);
    SetLength(Result, ResLength + 1);
    Result[ResLength] := Copy(Source, 1, Position - 1);
    ResLength := ResLength + 1;
    Delete(Source, 1, Position + DelLength - 1);
  until (Position = 0);
  SetLength(Result, ResLength - 1);
end;

// thanks to CurryWurst for this one
procedure QuickSort(var Field: array of tArrPointer; Left, Right: integer);
var    
  l, r, Pivot: integer; Buffer: tArrPointer;
begin
  // Chek whether there is at least more than one element to sort
  if (Left < Right) then
  begin
    l:= Left;
    r:= Right;
    // Pick the Pivot element
    Pivot:= Field[(Left + Right) shr 1].val;
    // Presort
    repeat 
      // Search an element which is smaller than the piviot
      while (Field[l].val < Pivot) do
        l := l + 1;
      // Search an element which is greater than the pivot
      while (Field[r].val > Pivot) do
        r := r - 1;
      // Swap the greater element with the smaller one
      if (l <= r) then
      begin
        Buffer:= Field[r];
        Field[r]:= Field[l];
        Field[l]:= Buffer;
        l := l + 1;
        r := r - 1;
      end;
    until (l >= r);
    if (Left < r) then
      QuickSort(Field, Left, r);
    if (Right > l) then
      QuickSort(Field, l, Right);
  end else 
    exit;
end;

procedure WriteMessage(ID: byte; Text: string; Color: longint);
begin
	if ID <= 32 then WriteConsole(ID, Text, Color)
	else WriteLn(Text);
end;

procedure GetMaxID();
begin
	for MaxID := 32 downto 1 do
		if Players[MaxID].Active then break;
end;

procedure Weapons_Force(ID, Primary, Secondary, PAmmo, SAmmo: byte);
var
	NewPrimary, NewSecondary: TNewWeapon;
begin
	NewPrimary := TNewWeapon.Create();
	NewSecondary := TNewWeapon.Create();
	try
		NewPrimary.WType := Primary;
		NewPrimary.Ammo := PAmmo;
		NewSecondary.WType := Secondary;
		NewSecondary.Ammo := SAmmo;
		Players[ID].ForceWeapon(NewPrimary, NewSecondary);
	finally
		NewPrimary.Free();
		NewSecondary.Free();
	end;
end;

function Objects_Spawn(X, Y: single; style: byte): byte;
var temp: TNewMapObject;
begin
  temp := TNewMapObject.Create; 
  temp.X := X;
  temp.Y := Y;
  temp.Style := style;
  result := Map.AddObject(temp).ID;
  temp.Free;
end;

function StrToId(s: string; ID: byte): byte;
var i: byte;
begin
	try Result := StrToInt(s);
	except
		s := LowerCase(s);
		if s = 'me' then begin
			Result := ID;
		end else begin
			Result := $FF;
			for i := 1 to MaxID do
				if Players[i].Active then
					if ContainsString(LowerCase(Players[i].Name), s) then begin
						Result := i;
						break;
					end;
		end;
	end;
end;

function UIntToHex(Int: cardinal): string;
var
  Rem: cardinal;
begin
	Result := '';
	repeat
		Rem := Int mod 16;
		Int := Int div 16;
		Result := Hex_Charset[Rem + 1] + Result;
	until Int = 0;
end;

function FNV32(s: string): cardinal;
var i: smallint;
begin
    Result := FNV_OFFSET_32;
    for i := 1 to Length(s) do begin
        Result := Result xor ord(s[i]); // xor next byte into the bottom of the hash
        Result := Result * FNV_PRIME_32; // Multiply by prime number found to work well
	end;
end;

function Pos2(needle, haystack: string; n: smallint): word;
var x, y: word; label l;
begin
	l:
		x := Pos(needle, haystack);
		if x > 0 then begin
			Delete(haystack, 1, x);
			y := y + x;
			if n <= 0 then begin
				Result := y;
				exit;
			end;
			n := n - 1;
		end else exit;
	goto l;
end;

procedure CreateBulletX(X,Y,VelX,VelY,HitM: Single; sStyle, Owner: Byte);
begin
WriteDebug(10, 'Owner' + IntToStr(Owner));
	if Players[Owner].Active then begin
		CreateBullet(X, Y, VelX, VelY, HitM, sStyle, Owner);
	end else WriteDebug(10, 'bID: ' + IntToStr(owner));
end;

procedure Shoot(x, y, Angle, add_vx, add_vy, vmin, vmax, Spread, Accuracy, Damage: single; Style, ID, n: byte);
var v, a: single;
begin
	if n > 1 then begin
		Angle := Angle - Spread/2;
		Spread := Spread / n;
		Angle := Angle + Spread/2;
	end;
	while n > 0 do begin
		n := n - 1;
		v := RandFlt(vmin, vmax);
		a := Angle + RandFlt(-Accuracy, Accuracy);
		CreateBulletX(x, y, cos(a)*v + add_vx, sin(a)*v + add_vy, Damage, Style, ID);
		Angle := Angle + spread;
	end;
end;

function Dots(n: byte): string;
begin
	case n of
		1: Result := '.';
		2: Result := '..';
		3: Result := '...';
	end;
end;

procedure incB(var n: byte; k: smallint);
begin
	n := n + k;
end;

procedure incW(var n: word; k: smallint);
begin
	n := n + k;
end;

function pl(n: byte): string;
begin
	if n > 1 then Result := 's' else Result := '';
end;

function t2s(ticks: longint): longint;
begin
	Result := (ticks+30) div 60;
end;

function FormatTime(time_m: cardinal): string;
var h, m: cardinal;
begin
	h := time_m div 60;
	m := time_m mod 60;
	if h > 0 then
		Result := IntToStr(h) + ' h, ';
	Result := Result + IntToStr(m) + ' min';
end;

procedure WriteTmpFlag(name, str: string);
begin
	WriteFile(TmpPath + name, str);
end;

function ReadTmpFlag(name: string): string;
var str: string;
begin
	str := TmpPath + name;
	if FileExists(str) then
		Result := ReadFile(str);
end;

function RG_Gradient(degree, color_intensity: single): integer;
var r, g, b: byte; down: single;
begin
	down := (1.0 - color_intensity)*0.5;
	if degree < 0.5 then begin
		r := Round(255.0 * (down + color_intensity));
		g := Round(255.0 * (down + degree*2.0*color_intensity));
	end else begin
		g := Round(255.0 * (down + color_intensity));
		r := Round(255.0 * (down + (1.0-(degree-0.5)*2.0)*color_intensity));
	end;
	b := Round(255.0*down);
	Result := RGB(r, g, b);
end;

procedure nova_2(X,Y,dir_x,dir_y,r,speed,power,cutoff,start: single; n: word; style, id: byte);
// r: radius; cutoff: part of a circle;
// start: angle where circle begins; n: number of bullets;
var
	angle,sine,cosine: single;
begin
	angle:=cutoff/n;
	for n:=n downto 1 do
	begin
		sine:=sin(start);
		cosine:=cos(start);
		CreateBulletX(cosine*r + X, sine*r + Y,cosine*speed + dir_x,sine*speed + dir_y,power, style, ID);
		start := start + angle;
	end;
end;

procedure nova_3(X,Y,dir_x,dir_y,r,speedmin,speedmax,power,cutoff,start: single; n: word; style, id: byte);
// r: radius; cutoff: part of a circle;
// start: angle where circle begins; n: number of bullets;
var
	angle,sine,cosine,speed: single;
begin
	angle:=cutoff/n; // part_of_circle / number of bullets
	for n:=n downto 1 do
	begin
		sine:=sin(start);
		cosine:=cos(start);
		speed:=RandFlt(speedmin, speedmax);
		CreateBulletX(cosine*r + X, sine*r + Y,cosine*speed + dir_x,sine*speed + dir_y,power, style, ID);
		start := start + angle;
	end;
end;

begin
end.
