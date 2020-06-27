// * ------------------ *
// |       Weapons      |
// * ------------------ *

// This is a part of {LS} Last Stand. Weapon related stuff.

unit Weapons;

interface

{$ifdef FPC}
uses Scriptcore,
  	 INI;
{$endif}

function ShortWeapName(x: byte): string;

function WeaponName(x: smallint): string;

function WeaponConfigName(x: smallint): string;

procedure Weapons_Init(weaponFile: string);

// Is the weapon a regular (in terms of LS) weapon?
function Weapons_IsRegular(Wtype: byte): boolean;

// Is the weapon a menu weapon?
function Weapons_IsInMenu(Wtype: byte): boolean;

function WeapStrToInt(s: string): byte;

implementation

type
	tWeaponConfig = record
		Ammo: byte;
	end;

const
	WEAPON_NUM = 16;
var
	WeaponConfig: array[0..WEAPON_NUM] of tWeaponConfig;

procedure Weapons_Init(weaponFile: string);
var ini: tINI;
  	i: byte;
	foundKey: boolean;
begin
  	INI_LOAD(ini, weaponFile + '.ini');
  	for i := 0 to WEAPON_NUM do
    begin
  		WeaponConfig[i].Ammo := strtoint(INI_Get(ini, WeaponConfigName(i), 'Ammo', '0', foundKey));
    end;
end;

function ShortWeapName(x: byte): string;
begin
	case x of
		WTYPE_EAGLE: Result := 'de';
		WTYPE_MP5: Result := 'mp5';
		WTYPE_AK74: Result := 'ak';
		WTYPE_STEYRAUG: Result := 'aug';
		WTYPE_SPAS12: Result := 'spas';
		WTYPE_RUGER77: Result := 'rgr';
		WTYPE_M79: Result := 'm79';
		WTYPE_BARRETT: Result := 'brt';
		WTYPE_M249: Result := 'fn';
		WTYPE_MINIGUN: Result := 'flak';
	end;
end;

function WeaponName(x: smallint): string;
begin
	case x of
		WTYPE_EAGLE: Result := 'Desert eagles';
		WTYPE_MP5: Result := 'MP5';
		WTYPE_AK74: Result := 'AK-74';
		WTYPE_STEYRAUG: Result := 'Steyr';
		WTYPE_SPAS12: Result := 'Spas';
		WTYPE_RUGER77: Result := 'Ruger';
		WTYPE_M79: Result := 'M79';
		WTYPE_BARRETT: Result := 'Barret';
		WTYPE_M249: Result := 'Minimi';
		WTYPE_MINIGUN: Result := 'Flak cannon';
		WTYPE_USSOCOM: Result := 'USSOCOM';
		WTYPE_KNIFE: Result := 'Molotov';
		WTYPE_CHAINSAW: Result := 'Chainsaw';
		WTYPE_LAW: Result := 'Law';
		WTYPE_FLAMER: Result := 'Flamer';
	end;
end;

function WeaponConfigName(x: smallint): string;
begin
	case x of
		WTYPE_EAGLE: Result := 'Desert Eagles';
		WTYPE_MP5: Result := 'HK MP5';
		WTYPE_AK74: Result := 'Ak-74';
		WTYPE_STEYRAUG: Result := 'Steyr AUG';
		WTYPE_SPAS12: Result := 'Spas-12';
		WTYPE_RUGER77: Result := 'Ruger 77';
		WTYPE_M79: Result := 'M79';
		WTYPE_BARRETT: Result := 'Barret M82A1';
		WTYPE_M249: Result := 'FN Minimi';
		WTYPE_MINIGUN: Result := 'XM214 Minigun';
		WTYPE_USSOCOM: Result := 'USSOCOM';
		WTYPE_KNIFE: Result := 'Combat Knife';
		WTYPE_CHAINSAW: Result := 'Chainsaw';
		WTYPE_LAW: Result := 'M72 LAW';
		WTYPE_FLAMER: Result := 'Flamer';
		WTYPE_BOW: Result := 'Rambo Bow';
		WTYPE_BOW2: Result := 'Flamed Arrows';
    	WTYPE_NOWEAPON: Result := 'Punch';
	end;
end;

// Is the weapon a regular (in terms of LS) weapon?
function Weapons_IsRegular(Wtype: byte): boolean;
begin
	result := (WType <> WTYPE_NOWEAPON)
		and (WType <> WTYPE_FLAMER)
		and (WType <> WTYPE_USSOCOM)
		and (WType <> WTYPE_KNIFE)
		and (WType <> WTYPE_BOW)
		and (WType <> WTYPE_BOW2);
end;

function Weapons_IsInMenu(Wtype: byte): boolean;
begin
	result := (WType <> WTYPE_NOWEAPON)
		and (WType <> WTYPE_FLAMER)
		and (WType <> WTYPE_BOW)
		and (WType <> WTYPE_BOW2);
end;

function WeapStrToInt(s: string): byte;
{$ifndef FPC}
var s2: string; int: integer;
{$endif}
begin
  {$ifndef FPC}
	s := LowerCase(s);
	s2 := Copy(s, 1, 2);
	case s2 of
		'us', 'so': Result := WTYPE_USSOCOM;
		'de': Result := WTYPE_EAGLE;
		'mp': Result := WTYPE_MP5;
		'ak': Result := WTYPE_AK74;
		'st', 'au': Result := WTYPE_STEYRAUG;
		'sp': Result := WTYPE_SPAS12;
		'ru', 'rg': Result := WTYPE_RUGER77;
		'm7': Result := WTYPE_M79;
		'ba', 'br': Result := WTYPE_BARRETT;
		'fn', 'mg': Result := WTYPE_M249;
		'mi', 'fl': case Copy(s, 1, 5) of
			'flak', 'minig': Result := WTYPE_MINIGUN;
			'minim': Result := WTYPE_M249;
			'flame': if ContainsString(s, 'bow') then Result := WTYPE_BOW2 else Result := WTYPE_FLAMER;
			else if s2 = 'fl' then Result := WTYPE_FLAMER;
		end;
		'bo': Result := WTYPE_BOW;
		'kn', 'mo': Result := WTYPE_KNIFE;
		'ch', 'sa': Result := WTYPE_CHAINSAW;
		'la': Result := WTYPE_LAW;
		'fi': Result := WTYPE_NOWEAPON;
		else begin
			int := StrToIntDef(s, -1);
			if (int > 16) or (int = -1) then begin
				Result := WTYPE_NOWEAPON;
				exit;
			end else
				Result := int;
		end;
	end;
  {$else}
    Result := 0;
  {$endif}
end;

begin

end.
