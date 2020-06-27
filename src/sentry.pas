//  * -------------- *
//  |     Sentry     |
//  * -------------- *

// This is a part of {LS} Last Stand. The unit is responsible for Sentry gun.

unit Sentry;

interface

uses Players, Misc, Raycast, Ballistic, Dummy;

type
	tSentry = record
		Active: boolean;
		ID, Owner, FireDelay, FireCountdown, Style, AmmoTimer, Hp, Status, State, Timer, AmmoType: byte;
		BuildTimer, LastHP: shortint;
		X, Y, Damage, Speed, Accuracy, Recoil, FireAngle: single;
		Ammo: word;
		Aim: record
			InitialTarget, Target, Timer, Timer2, Skip: byte;
			LastAngle: single;
			Hits: word;
		end;
	end;

var
	Sentry: tSentry;
	
type
	Sentry_Operation = (fix, retrieve, load_ammo);

procedure Sentry_ResetAim();

procedure Sentry_Clear(ResetAmmo: boolean);

function Sentry_SetStat(Stat: string; Value: integer): boolean; // use for oncommand only!

function Sentry_State(i: byte): string;

procedure Sentry_OnDamage(dmg: byte);

procedure Sentry_Process(MainCall: boolean);

procedure Sentry_TryOperation(ID: byte; _type: Sentry_Operation);

procedure Sentry_TryPlace(ID: byte);

implementation

const
	// sentry constants
	SENTRY_VELOCITY = 25.0;
	SENTRY_DAMAGE = 1.35; // 1.63 -> 1.35
	SENTRY_ACCURACY = 2 * DEG_2_RAD;
	SENTRY_RECOIL = 1.0/14; // 1/12 -> 1/14
	SENTRY_HP = 9;
	SENTRY_CONSTRUCTIONTIME = 12;
	SENTRY_RETRIEVALTIME = 5;
	SENTRY_AMMOINBELT = 320; // 280 -> 320
	SENTRY_RANGE = 600;
	SENTRY_RELOADTIME = 3; 
	SENTRY_AIMSPEED = 0.55; // 0.6 -> 0.55
	SENTRY_BULLETTYPE = 1;
	SENTRY_INTERVAL = 6; // ticks

procedure Sentry_ResetAim();
begin
	Sentry.Aim.InitialTarget := 0;
	Sentry.Aim.Skip := 0;
	Sentry.Aim.Hits := 0;
	Sentry.Aim.Timer := 0;
	Sentry.Aim.Timer2 := 0;
	Sentry.Aim.LastAngle := 0;
end;

procedure Sentry_Clear(ResetAmmo: boolean);
begin
	if Sentry.ID > 0 then
		if Players[Sentry.ID].Active then begin
			player[Sentry.ID].kicked := true;
			Players[Sentry.ID].Kick(TKickSilent);
		end;
	Sentry.Active := false;
	Sentry.ID := 0;
	Sentry.Owner := 0;
	if ResetAmmo then Sentry.Ammo := SENTRY_AMMOINBELT;
	Sentry.Status := 0;
	Sentry.State := 0;
	Sentry.Recoil := 0;
	Sentry_ResetAim();
end;

const SQR_SENTRY_RANGE = SENTRY_RANGE * SENTRY_RANGE;

procedure Sentry_LookForTargetRC(X, Y: single);
var i: byte; X2, Y2, Vx, Vy, DistSqr, MaxSqrDist: single;
	head, feet, mid: boolean;
begin
	Sentry.Aim.Target := 0;
	MaxSqrDist := SQR_SENTRY_RANGE;
	for i := 1 to MaxID do
		if i <> Sentry.Owner then
		if i <> Sentry.ID then
		if Players[i].Alive then
		if player[i].Zombie then
		if not Players[i].Dummy then begin
			GetPlayerXY(i,X2,Y2);
			Vx:=X2-X;
			Vy:=Y2-Y;
			DistSqr:=Vx*Vx+Vy*Vy;
			if DistSqr < MaxSqrDist*1.44 then begin
				head := RayCast(X, Y-10, X2, Y2-16, false, true, true);
				feet := RayCast(X, Y-10, X2, Y2-3, false, true, true);
				if not (head or feet) then continue;
				if head and feet then DistSqr := DistSqr * 0.64;
				mid  := RayCast(X, Y-10, X2, Y2-10, false, true, true);
				if not mid then DistSqr := DistSqr * 1.44;
				if DistSqr < MaxSqrDist then begin
					Sentry.Aim.Target:=i;
					MaxSqrDist:=DistSqr;
				end;
			end;
		end;
end;

const SENTRY_iAIMSPEED = 1 - SENTRY_AIMSPEED;
procedure Sentry_Fire();
var X, Y, X2, Y2, ang: single; target_changed, InRange: boolean;
label start;
begin
	if Sentry.Aim.Target > 0 then begin
		if Players[Sentry.Aim.Target].Alive then begin
			start:
			if Sentry.Ammo > 0 then begin
				GetPlayerXY(Sentry.ID, X, Y);
				GetPlayerXY(Sentry.Aim.Target, X2, Y2);
				Y := Y - 10;
				Y2 := Y2 - 10;
				//ang := BallisticAim(X, Y, X2, Y2, Sentry.Speed, CurrentGravity, b);
				ang := BallisticAimX(X, Y, Sentry.Speed, Players[Sentry.Aim.Target], InRange);
				if InRange then begin
					if ang < 0 then ang := ang + ANG_2PI;
					if Sentry.FireAngle <> 0 then
						if Abs(ShortenAngle(ang - Sentry.FireAngle)) < ANGLE_70 then begin
							if Sentry.FireAngle <> 0 then begin
								ang := ang * SENTRY_AIMSPEED + Sentry.FireAngle * SENTRY_iAIMSPEED;
							end;
						end else if target_changed then exit;
					Sentry.FireAngle := ang;						
					Sentry.Ammo := Sentry.Ammo - 1;
					//Shoot(x, y, Angle, add_vx, add_vy, vmin, vmax, Spread, Accuracy, Damage: single; Style, ID, n: byte);
					Shoot(X, Y, ang, 0, 0, Sentry.Speed - 2, Sentry.Speed + 2, 0, Sentry.Accuracy*Sentry.Recoil, -Sentry.Damage, Sentry.AmmoType, Sentry.ID, 1);
					PlaySound(0, 'colt1911-fire.wav', X, Y);
					Players[Sentry.ID].MouseAimX := Round(X + cos(ang)*100.0);
					Players[Sentry.ID].MouseAimY := Round(Y + sin(ang)*100.0);
					if Sentry.Recoil < 1 then begin
						Sentry.Recoil := Sentry.Recoil + SENTRY_RECOIL;
						if Sentry.Recoil > 1 then Sentry.Recoil := 1;
					end;
					if Sentry.Ammo > 0 then
						if Sentry.Ammo mod SENTRY_AMMOINBELT = 0 then begin // reloading belt
							Sentry.State := 5;
							Sentry.Timer := SENTRY_RELOADTIME;
							BotChat(Sentry.ID, '^*Reloading*');
							PlaySound(0, 'minigun-reload.wav', X, Y);
							Weapons_Force(Sentry.ID, WTYPE_BOW, WTYPE_NOWEAPON, 1, 0);
							Sentry.Aim.Target := 0;
							Sentry_ResetAim();
						end;
				end;
			end;
		end else begin
			GetPlayerXY(Sentry.ID, X, Y);
			GetPlayerXY(Sentry.Aim.Target, X2, Y2);
			Sentry_LookForTargetRC((X + X + X2)/3, (Y + Y + Y2)/3);
			//Sentry_LookForTarget(x, y);
			//writeconsole(0, '-' + IntToStr(sentry.aim.target), pink);
			if Sentry.Aim.Target > 0 then begin
				target_changed := true;
				goto start;
			end;
		end;
	end;
end;

procedure Sentry_OpenFire();
begin
	Sentry.FireCountdown := Sentry.FireDelay;
end;

procedure Sentry_Place(X, Y: Single; Owner: byte; ResetAmmo: boolean);
var
	NewPlayer: TNewPlayer;
begin
	Sentry_Clear(ResetAmmo);
	NewPlayer := BW_CreateSentry(HackermanMode);
	try
		Sentry.ID := PutBot(NewPlayer, X, Y, 4).ID;
	finally
		NewPlayer.Free;
	end;
	Weapons_Force(Sentry.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
	GiveBonus(Sentry.ID, 3);
	if Sentry.ID > MaxID then MaxID := Sentry.ID;
	Sentry.Active := true;
	Sentry.X := X;
	Sentry.Y := Y;
	Sentry.Status := 1;
	Sentry.State := 1;
	Sentry.Owner := Owner;
	//Sentry.Ammo := SENTRY_AMMOINBELT;
	Sentry.Speed := SENTRY_VELOCITY;
	Sentry.Damage := SENTRY_DAMAGE;
	Sentry.Accuracy := SENTRY_ACCURACY;
	Sentry.FireDelay := SENTRY_INTERVAL;
	Sentry.Hp := SENTRY_HP;
	Sentry.AmmoType := SENTRY_BULLETTYPE;
	Sentry.LastHP := 0;
	player[Sentry.ID].DamageFactor := 1.0;
end;

function Sentry_SetStat(Stat: string; Value: integer): boolean; // use for oncommand only!
begin
	case LowerCase(Copy(Stat, 1, 5)) of
		'statu': Sentry.Status := Value;
		'state': Sentry.State := Value;
		'owner': Sentry.Owner := Value;
		'ammo': Sentry.Ammo := Value;
		'style', 'type': Sentry.AmmoType := Value;
		'speed', 'spd', 'vel': Sentry.Speed := Value;
		'dmg', 'damag': Sentry.Damage := Value;
		'acc', 'accur': Sentry.Accuracy := DEG_2_RAD * Value;
		'int', 'inter': Sentry.FireDelay := Value;
		'hp', 'healt': Sentry.Hp := Value;
		else Result := true;
	end;
end;

function Sentry_State(i: byte): string;
begin
	case i of
		1: Result := 'Idle';
		2: Result := 'Ready';
		3: Result := 'Active';
		4: Result := 'No ammo';
		5: Result := 'Reloading';
		6: Result := 'Broken';
	end;
end;

function Sentry_AmmoStatus(): string;
var n: smallint;
begin
	if Sentry.Ammo = 0 then
	begin
		Result := '[0]';
		exit;
	end;

	n := (Sentry.Ammo - 1) div SENTRY_AMMOINBELT; // belts num
	if n > 0 then
		Result := '[' + IntToStr(n) + '] ';
	if Sentry.State = 5 then begin// reloading
		Result := Result + 'Reloading ' + Dots((Timer.Value div 60) mod 4);
	end else begin
		n := (Sentry.Ammo - 1) mod SENTRY_AMMOINBELT + 1;
		if n > 0 then begin
			n := n * 20 div SENTRY_AMMOINBELT;
			Result := Result + '[' + StringOfChar('|', n) + StringOfChar(' ', 20 - n) + ']';
		end;
	end;
end;

procedure Sentry_OnDamage(dmg: byte);
var X, Y: single;
	hp: shortint;
begin
	if Sentry.Hp > dmg then Sentry.Hp := Sentry.Hp - dmg else Sentry.Hp := 0;
	if Sentry.Hp = 0 then begin
		WriteConsole(0, 'Zombies have destroyed a sentry gun', RED);
		GetPlayerXY(Sentry.ID, X, Y);
		CreateBulletX(X, Y, 0, 0, 1, 10, Sentry.Owner);
		CreateBulletX(X, Y - 10, RandFlt(-8, 8), RandFlt(-2, 0), 0, 3, Sentry.ID);
		CreateBulletX(X, Y - 12, RandFlt(-5, 6), RandFlt(-3, 0), 0, 7, Sentry.ID);
		CreateBulletX(X, Y - 8, RandFlt(-6, 5), RandFlt(-3, -1), 0, 14, Sentry.ID);
		Sentry_Clear(true);
		exit;
	end else begin
		if Sentry.Hp = 3 then begin
			GetPlayerXY(Sentry.ID, X, Y);
			Sentry.State := 6; // "broken"
			WriteConsole(Sentry.Owner, 'Sentry is broken, go /fix it before zombies destroy it', ORANGE);
			CreateBulletX(X, Y, 0, 0, 0, 10, Sentry.ID);
			Weapons_Force(Sentry.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
		end;
		if Sentry.Hp mod 5 = 0 then begin
			GetPlayerXY(Sentry.ID, X, Y);
			CreateBulletX(X, Y - 10, 0, 0, 0, 5, Sentry.ID);
		end;
		hp := Trunc(5.0 * Sentry.hp / SENTRY_HP + 0.99);
		if hp <> Sentry.LastHP then begin
			Sentry.LastHP := hp;
			Botchat(Sentry.ID, '^'+StringOfChar('=', hp) + StringOfChar('-', 5 - hp));
		end;
	end;
end;

procedure Sentry_Observe();
var X, Y, X2, Y2: single; i: byte; str: string; sdist: single; found: boolean;
begin
	
	if Sentry.Active then begin
		case Sentry.Status of 
			1: begin // gun ready to fire
				GetPlayerXY(Sentry.ID, X, Y);
				Y := Y - 10;
				for i := 1 to MaxID do
					if Players[i].Alive then
						if player[i].Zombie then
							if IsInRange(i, X, Y, 20, false) then begin
								Sentry_OnDamage(1);
								break;
							end;
				if Sentry.State <= 3 then begin
					if Sentry.Ammo > 0 then begin
						if Sentry.State = 1 then begin
							// check for possible targets
							for i := 1 to MaxID do
								if Players[i].Alive then
									if player[i].Zombie then begin
										GetPlayerXY(i, X2, Y2);
										sdist := SqrDist(X, Y, X2, Y2);
										if sdist < SQR_SENTRY_RANGE then
											if RayCast(X, Y-5, X2, Y2-10, false, false, false) then begin
												found := true;
												break;
											end;
									end;
							if found then begin
								if Sentry.Timer = 0 then begin
									Sentry.Timer := 2; // found sth, start activating...
									BotChat(Sentry.ID, '^*Activating*');
									PlaySound(0, 'law-start.wav', X, Y);
								end else begin
									Sentry.State := 2;
									Sentry.Timer := 10;
								end;
							end else begin
								Sentry.Timer := 0;
							end;
						end else begin
							Sentry_LookForTargetRC(X, Y);
							if Sentry.Aim.Target > 0 then begin
								if Sentry.State <> 3 then begin
									Sentry_OpenFire();
									Sentry.State := 3; // "active" (shooting)
									Sentry.Timer := 0; 
									Weapons_Force(Sentry.ID, WTYPE_BOW2, WTYPE_NOWEAPON, 1, 1);
								end;
							end else begin
								if Sentry.Recoil > 0 then Sentry.Recoil := Sentry.Recoil - 0.4;
								if Sentry.Recoil < 0 then Sentry.Recoil := 0;
								Sentry.FireAngle := 0;
								if Sentry.State = 3 then begin
									Sentry.State := 2; // "ready"
									Sentry.Timer := 10;
									Weapons_Force(Sentry.ID, WTYPE_BOW, WTYPE_NOWEAPON, 1, 1);
								end else
								if Sentry.Timer > 0 then Sentry.Timer := Sentry.Timer - 1 else begin
									Sentry.State := 1; // "idle"
									Weapons_Force(Sentry.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
									BotChat(Sentry.ID, '^*Idle*');
									Sentry_ResetAim();
								end;
							end;
						end;
					end else begin
						if Sentry.State <> 4 then begin
							Sentry.State := 4; // "no ammo"
							BotChat(Sentry.ID, '^*No ammo*');
							Weapons_Force(Sentry.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
							WriteConsole(Sentry.Owner, 'Sentry has run out of ammo, load it if you have any (/ammo)', ORANGE);
						end;
					end;
				end else
					case Sentry.State of
						6: if (Timer.Value div 60) mod 3 = 1 then begin // broken
							CreateBulletX(X, Y, 0, 0, 0, 5, Sentry.ID);
						end;
						5: begin
							if Sentry.Timer > 0 then begin
								Sentry.Timer := Sentry.Timer - 1;
							end else
								Sentry.State := 2;
						end;
					end;
						
				if Players[Sentry.Owner].Alive then
					if IsInRange(Sentry.Owner, X, Y, 40, false) then begin
						str := 'State: ' + Sentry_State(Sentry.State) + #13#10 +
							'Ammo: ' + Sentry_AmmoStatus() + #13#10 + 
							'HP: ' + IntToStr(100 * Sentry.Hp div SENTRY_HP) + '%';
						if Sentry.Ammo <= 100 then
							//if player[i].sentryammo > 0 then
								str := str + #13#10 + 'Type /ammo to load the gun';
						if Sentry.Hp < SENTRY_HP then
							str := str + #13#10 + 'Type /fix to repair the gun';
						BigText_DrawScreenX(DTL_COUNTDOWN, Sentry.Owner, str, 120, DT_CONSTRUCTION, 0.06, 20, 370);
					end;
			end;
			2: begin // under construction
				if Sentry.Timer > 0 then begin
					if (Players[Sentry.Owner].Alive) and (IsInRange(Sentry.Owner, Sentry.X, Sentry.Y, 40, false)) then begin
						BigText_DrawScreenX(DTL_COUNTDOWN, Sentry.Owner, 'Construction ['+IntToStr(Sentry.Timer)+']',100, DT_CONSTRUCTION, 0.08, 20, 370);
						Sentry.Timer := Sentry.Timer - 1;
					end else begin
						BigText_DrawScreenX(DTL_COUNTDOWN, Sentry.Owner, 'Construction failed.',100, DT_FAIL, 0.08, 20, 370);
						Sentry_Clear(false);
					end;
				end else begin
					Sentry_Place(Sentry.X, Sentry.Y, Sentry.Owner, false);
					player[Sentry.Owner].Sentrys := player[Sentry.Owner].Sentrys - 1;
					Weapons_Force(Sentry.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
					WriteDebug(3, 'sentry placed');
					WriteConsole(0, TaskToName(player[Sentry.Owner].Task, false) + ' '  + Players[Sentry.Owner].Name + ' has placed a sentry gun', GREEN);
					if player[Sentry.Owner].Sentrys > 0 then
						WriteConsole(Sentry.Owner, IntToStr(player[Sentry.Owner].Sentrys) + ' sentry guns left', GREEN);
				end;
			end;
			3: begin // being retrieved
				if Sentry.Timer > 0 then begin
					if (Players[Sentry.Owner].Alive) and (IsInRange(Sentry.Owner, Sentry.X, Sentry.Y, 40, false)) then begin
						BigText_DrawScreenX(DTL_COUNTDOWN, Sentry.Owner, 'Deconstruction ['+IntToStr(Sentry.Timer)+']', 100, DT_CONSTRUCTION, 0.08, 20, 370);
						Sentry.Timer := Sentry.Timer - 1;
					end else begin
						BigText_DrawScreenX(DTL_COUNTDOWN, Sentry.Owner, 'Retrieval failed.', 100, DT_FAIL, 0.08, 20, 370);
						Sentry.Status := 1; // normal
					end;
				end else begin
					player[Sentry.Owner].Sentrys := player[Sentry.Owner].Sentrys + 1;
					WriteConsole(Sentry.Owner, 'Deconstruction complete!', GREEN);
					WriteConsole(Sentry.Owner, IntToStr(player[Sentry.Owner].Sentrys) + ' sentry guns left', GREEN);
					Sentry_Clear(false);
				end;
			end;
			4: begin // reparation
				if Sentry.Hp < SENTRY_HP then begin
					if (Players[Sentry.Owner].Alive) and (IsInRange(Sentry.Owner, Sentry.X, Sentry.Y, 40, false)) then begin
						if Sentry.Hp < SENTRY_HP then begin
							Sentry.Hp := Sentry.Hp + 1;
							if Sentry.State = 6 then Sentry.State := 1;
							if Sentry.Hp < SENTRY_HP then begin
								str := 'Reparation: ' + IntToStr(100 * Sentry.Hp div SENTRY_HP) + '%';
							end else begin
								str := 'Sentry repaired';
								WriteConsole(Sentry.Owner, 'Reparation complete!', GREEN);
								Sentry.Status := 1; // normal
								Sentry.State := 1; // idle
							end;
							BigText_DrawScreenX(DTL_COUNTDOWN, Sentry.Owner, str, 100, DT_CONSTRUCTION, 0.08, 20, 370);
						end else begin
							Sentry.Status := 1;
							Sentry.State := 1;
						end;
					end else begin
						Sentry.Status := 1;
						Sentry.State := 1;
					end;
				end else begin
					Sentry.Status := 1;
					Sentry.State := 1;
				end;
			end;
		end;
		// protection against flag holding
		if (Timer.Value div 60) mod 10 = 5 then begin
			CheckDummyOnFlag(Sentry.ID);
		end;
	end;
end;

procedure Sentry_Process(MainCall: boolean);
begin
	if MainCall then begin // 1 Hz
		Sentry_Observe();
	end;
	if Sentry.State = 3 then begin // "active" (shooting)
		if Sentry.FireCountdown > 0 then begin
			Sentry.FireCountdown := Sentry.FireCountdown - 1;
			if Sentry.FireCountdown = 0 then begin
				Sentry_Fire();
				Sentry.FireCountdown := Sentry.FireDelay;
			end;
		end;
	end;
end;

procedure Sentry_StartConstruction(ID: byte);
begin
	WriteConsole(ID, 'Construction started, do not move!', GREEN);
	GetPlayerXY(ID, Sentry.X, Sentry.Y);
	Sentry.Active := true;
	Sentry.Status := 2; // construction
	Sentry.Timer := SENTRY_CONSTRUCTIONTIME;
	Sentry.Owner := ID;
end; 

procedure Sentry_TryOperation(ID: byte; _type: Sentry_Operation);
begin
	if Players[ID].Alive then begin
		if ID = Mechanic then begin
			if Sentry.Status > 0 then begin
				if (Sentry.Status <> 2) and (Sentry.Status <> 3) then begin
					GetPlayerXY(Sentry.ID, Sentry.X, Sentry.Y);
					if IsInRange(ID, Sentry.X, Sentry.Y, 40, false) then begin
						if _type = retrieve then begin
							Sentry.Status := 3; // deconstruction
							Sentry.Timer := SENTRY_RETRIEVALTIME;
							WriteConsole(ID, 'Deconstruction started, do not move!', GREEN);
						end else
						if _type = fix then begin
							if Sentry.Hp < SENTRY_HP then begin
								if Sentry.Status <> 4 then begin
									Sentry.Status := 4; // reparation
									WriteConsole(ID, 'Reparation started, do not move!', GREEN);
									Weapons_Force(Sentry.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
								end else WriteConsole(ID, 'The sentry gun is being fixed at the moment', RED);
							end else WriteConsole(ID, 'The sentry is not damaged', RED);
						end else begin
							if player[ID].SentryAmmo > 0 then begin
								if Sentry.Ammo <= 4 * SENTRY_AMMOINBELT then begin
									Sentry.Ammo := Sentry.Ammo + SENTRY_AMMOINBELT;
									if Sentry.State < 5 then Sentry.State := 1;
									WriteConsole(ID, 'Ammo belt loaded, sentry ammo: ' + IntToStr(Sentry.Ammo), GREEN);
									player[ID].SentryAmmo := player[ID].SentryAmmo - 1;
									if player[ID].SentryAmmo > 0 then
										WriteConsole(ID, 'Ammo belts left: ' + IntToStr(player[ID].SentryAmmo), GREEN);
								end else WriteConsole(ID, 'You can''t load more ammo, maximal ammo capacity is 5 belts (' + IntToStr(5 * SENTRY_AMMOINBELT) + ')', RED);
							end else WriteConsole(ID, 'You don''t have any sentry gun ammo', RED);
						end;
					end else WriteConsole(ID, 'You must be near to the sentry gun', RED);
				end else WriteConsole(ID, 'The sentry is now under constuction/deconstruction', RED);
			end else WriteConsole(ID, 'There is no sentry gun in game', RED);
		end else WriteConsole(ID, 'You are not the mechanic', RED);
	end else WriteConsole(ID, 'You have to be alive to get a sentry gun', RED);
end;

procedure Sentry_TryPlace(ID: byte);
var
	b: boolean; i: byte; x, x2: single; sY: array[0..1] of single;
begin
	if Players[ID].Alive then begin
		if Players_OnGround(ID, true, 10) > 0 then begin
			if ID = Mechanic then begin
				if player[ID].Sentrys > 0 then begin
					if Sentry.Status = 0 then begin
						GetPlayerXY(ID, x, sY[0]);
						RayCast2(0, 2.5, 10, x, sY[0]);
						sY[0] := sY[0] - 10;
						sY[1] := sY[0];
						for i := 0 to 1 do begin
							x2 := x - (2*i - 1) * 10;
							b := (b) or (RayCast2(0, 2, 30, x2, sY[i]));
						end;
						if not b then begin
							if Abs(sY[0] - sY[1]) <= 13 then begin
								Sentry_StartConstruction(ID);
							end else WriteConsole(ID, 'You cannot build a sentry gun here, ground is too steep',RED);
						end else begin
							WriteConsole(ID, 'You cannot build a sentry gun here, ground is too uneven', RED);
							b := false;
						end;
					end else if Sentry.Status = 2 then
						WriteConsole(ID, 'The sentry is already under construction', RED) else
						WriteConsole(ID, 'There is already a sentry gun in game', RED);
				end else WriteConsole(ID, 'You do not have any sentry guns', RED);
			end else WriteConsole(ID, 'You are not the mechanic', RED);
		end else WriteConsole(ID, 'You have to be on the ground to place a sentry gun', RED);
	end else WriteConsole(ID, 'You have to be alive to place a sentry gun', RED);
end;