// * ------------------ *
// |       Damage       |
// * ------------------ *

// This is a part of {LS} Last Stand.
// This unit, plus the OnPlayerDamage event (in main unit)
// handles damage calculations.

unit Damage;

interface

uses
{$ifdef FPC}
  Scriptcore,
{$endif}
  LSPlayers,
  Globals,
  Misc,
  Zombies,
  Debug;

type
  TDamageType = (General, Explosion, Heat, Wires, Shotgun, SentryGun, Helicopter, HolyWater, ExoMagic);

var
  Damage_Debug: boolean;
  // these flags will be processed in OnPlayerDamage event to apply appropriate logic to received damage.
  Damage_Direct: boolean;
  Damage_Type: TDamageType;
  Damage_Absolute: boolean;
  Damage_Healing: boolean;
  
procedure Damage_ZombiesAreaDamage(ID: byte; x, y, r1, r2, damage: single; DamageType: TDamageType);

// Damage will be given taking player-specific resitances and damage multipliers into account.
procedure Damage_DoRelative(Victim, Shooter: byte; Damage: integer; DamageType: TDamageType);

// Damage will be given directly, no player-specific resistances and damage multipliers will be applied.
procedure Damage_DoAbsolute(Victim, Shooter: byte; Damage: single);

// Give health to a player
function Damage_Heal(ID: byte; health: single): byte;

procedure Damage_SetHealth(ID: byte; health, vest: single);

implementation

procedure Damage_DoRelative(Victim, Shooter: byte; Damage: integer; DamageType: TDamageType);
begin
  Damage_Type := DamageType;
  Damage_Direct := true;
  Damage_Absolute := false;
  Damage_Healing := (Damage < 0);
  Players[Victim].Damage(Shooter, Damage);
  Damage_Healing := false;
  Damage_Direct := false;
end;

procedure Damage_DoAbsolute(Victim, Shooter: byte; Damage: single);
begin
  Damage_Type := General;
  Damage_Direct := true;
  Damage_Absolute := true;
  Damage_Healing := (Damage < 0);
  Players[Victim].Damage(Shooter, Round(Damage));
  Damage_Healing := false;
  Damage_Absolute := false;
  Damage_Direct := false;
end;

function Damage_Heal(ID: byte; health: single): byte;
var HP: single;
begin
  HP := Players[ID].HEALTH;
  if HP < MAXHEALTH then begin
    Damage_Healing := true;
    if HP + health <= MAXHEALTH then begin
      Damage_DoAbsolute(ID, ID, -health);
      Result := 1;
    end else begin
      Damage_DoAbsolute(ID, ID, HP - MAXHEALTH);
      Result := 2;
    end;
    Damage_Healing := false;
  end;
end;

// assuming he's not vested.
procedure Damage_SetHealth(ID: byte; health, vest: single);
//var vest_loss, predicted_hp_loss, damage: single;
begin
  {if vest > 0 then begin
    // When player is vested, vest -= dmg/3, health -= dmg/4.
    // Max vest is 100.
    // Calculate how much vest he must be missing
    vest_loss := 100 - vest; // MaxVest - Vest
    // Calculate how much dmg is needed to bring vest from full to that
    damage := vest_loss * 3;
    // Predict hp loss that will happen when doing the damage. Round up.
    predicted_hp_loss := (damage+3) / 4;
    // Do the damage needed to bring his hp to desired level + predicted hp loss
    Damage_DoAbsolute(ID, ID, -predicted_hp_loss+Players[ID].Health-health);
    //wc('-pl: ' + inttostr(Players[ID].Health));
    // Give him the vest
    Players[ID].GiveBonus(3);
    // Do damage
    Damage_DoAbsolute(ID, ID, damage);
    //wc('dmg: ' + inttostr(Players[ID].Health));
    //wc('v p:' + inttostr(predicted_hp_loss) + ' d:' + inttostr(damage));
  end else begin
    Damage_DoAbsolute(ID, ID, Players[ID].Health-health);
  end;}
  Players[ID].Health := health;
  Players[ID].Vest := vest;
end;

procedure Damage_ZombiesAreaDamage(ID: byte; x, y, r1, r2, damage: single; DamageType: TDamageType);
var
  i: byte;
  dist, dmg: single;
  owner0: boolean;
begin
  owner0 := (ID = 0);
  for i:=1 to MaxID do
    if Players[i].Alive then
    if player[i].Zombie then begin
      dist := Distance(x, y, Players[i].X, Players[i].Y);
      if dist < r2 then begin  
        if owner0 then ID := i;
        if damage > 0 then begin
          dmg := damage;
        end else
          dmg := players[i].Health+0.5;
        if dist < r1 then begin // damage in radius 1 remains unchanged
        end else begin
          dmg := dmg * (1 - (dist - r1)/(r2 - r1));
        end;
        Damage_DoRelative(i, ID, Round(dmg), DamageType);
      end;
    end;
end;

end.
