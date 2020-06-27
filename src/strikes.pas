// * ------------------ *
// |       Strikes      |
// * ------------------ *

// This is a part of {LS} Last Stand.

unit Strikes;

interface

uses
{$ifdef FPC}
  Scriptcore,
{$endif}
	Bigtext,
	Constants,
	Debug,
	maths,
	Misc,
	LSPlayers,
	Damage,
	Raycasts,
	Ballistic,
	MersenneTwister,
	Fire,
	Utils;

type
	tMarker = record
		X, Y: single;
		Owner: byte;
		Active: array[0..2] of boolean;
	end;
	
	tStrike = record
		Owner, Style, AmmoType, Target, AimTimer: byte;
		Timer, Timer2, CoolDown, HeliFireN, SwitchedTargetCooldown: smallint;
		X, Y, X2, Y2, Recoil, LastAngle, LastDeltaAngle, CurrentAngle: single;
		Active: boolean;
		Shift, HeightDiff: SmallInt;
	end;

var
	Strike: tStrike;
	Marker: tMarker;
	
procedure Strike_Reset();

procedure Strike_Process(MainCall: boolean); // 1hz, 15hz compatibile

procedure Strike_Call(Style: byte);

procedure Strike_ResetMarker();

procedure Strike_SetMarker(ID: Byte);

implementation

procedure Strike_Reset();
begin
	Strike.Owner := 0;
	Strike.Active := false;
	Strike.Active := false;
	Strike.Timer := 0;
	Strike.Timer2 := 0;
	Strike.Target := 0;
	Strike.AmmoType := 0;
	Strike.Style := 0;
	Strike.Shift := 0;
	Strike.HeightDiff := 0;
	Strike.X := 0;
	Strike.Y := 0;
	Strike.X2 := 0;
	Strike.Y2 := 0;
	Strike.Recoil := 0;
	Strike.LastAngle := 0;
	Strike.LastDeltaAngle := 0;
	Strike.CoolDown := 0;
	Strike.HeliFireN := 0;
	Strike.AimTimer := 0;
end;

procedure ThrowBomb(X,Y,VelX,VelY: Single; Owner: Byte; cluster: boolean);
begin
	if cluster then begin
		CreateBulletX(X, Y, VelX, VelY, 100, 9, Owner);
		CreateBulletX(X, Y, VelX, VelY, 100, 12, Owner);
	end else begin
		CreateBulletX(X, Y, VelX, VelY, 100, 2, Owner);
		CreateBulletX(X, Y, VelX, VelY, 100, 4, Owner);
	end;
end;

procedure Strike_Process(MainCall: boolean); // 1hz, 15hz compatibile
var
	a, b, c: smallint; X, Y: single; DeltaFactor, DeltaAngle: single;
	inrange: boolean;
begin
	if Strike.Active then begin
		if (Strike.Style = 1) then begin // bomb strike
			if MainCall then begin // 1hz
				if Strike.Timer > 0 then	begin
					WriteConsole( 0, 'Incoming Airstrike ['+IntToStr( Strike.Timer )+']', GREEN);
					for a := 0 to 4 do
						CreateBulletX( Strike.X - 250 + a * 100, Strike.Y - Strike.HeightDiff - 400 - a * (Strike.Shift * 20), 0, 11 - a * Strike.Shift, 0, 14,Strike.Owner );
				end else begin
					if Strike.Timer = 0 then begin
						WriteConsole( 0, 'Airstrike...', GREEN);
						Damage_ZombiesAreaDamage(Strike.Owner, Strike.X, Strike.Y, 180, 260, 4000, Explosion);
				//procedure Fire_CreateBurningArea(X, Y: single; ParticleVel: single; casting_rng: word; duration, n, owner: byte);
						Fire_CreateBurningArea(Strike.X + 40, Strike.Y - 160, 20, 300, 10, 8,Strike.Owner);
					end else if Strike.Timer = -1 then begin
						Fire_CreateBurningArea(Strike.X - 40, Strike.Y, 20, 300, 14, 5,Strike.Owner);
					end else if Strike.Timer = -2 then begin
						Damage_ZombiesAreaDamage(Strike.Owner, Strike.X, Strike.Y, 180, 260, 4000, Heat);
						Strike.Active := false;
					end;
					if Strike.Timer <> -2 then begin
						b := RandInt(-40, 40);
						for a := 0 to RandInt(4, 5) do begin
							ThrowBomb(Strike.X - 100 * Strike.Shift - 240 + a * 90 + b, Strike.Y - Strike.HeightDiff - 400 - a * (Strike.Shift * 50), RandFlt(3, 4) * Strike.Shift, RandFlt(8, 9)-a,Strike.Owner, Strike.Timer = -1);
						end;
					end;
					if not Strike.Active then Strike_Reset();
				end;
				Strike.Timer := strike.Timer - 1;
			end;
		end else begin // helicopter strike
					
			if MainCall then begin // 1hz
				if Strike.Timer = HELITIME then	begin
					WriteConsole( 0, 'Helicopter strike incoming in ' + IntToStr(HELITIME) + ' seconds!', GREEN);
				end else begin
					if Strike.Timer = 0 then begin
						WriteConsole( 0, 'Helicopter strike...', GREEN);
						Strike.AmmoType := 1;
						Strike.Timer2 := 7;
						Strike.Y2 := Strike.Y - 400;
						Strike.X2 := Strike.X;
						b := 300;
						for a := 1 to 5 do begin
							if Raycast(Strike.X, Strike.Y, Strike.X - Strike.Shift * b, Strike.Y2, true, false, false) then begin
								Strike.X2 := Strike.X - Strike.Shift * b;
								break;
							end;
							b := b - 50;
						end;
					end else if Strike.Timer < 0 then begin // strike in progress
						if -Strike.Timer >= HELIATTACKTIME then begin
							Strike_Reset();
							WriteConsole( 0, 'The helicopter flies away', GREEN);
							exit;
						end;
						if Strike.CoolDown = 0 then begin
							Strike.Target := lookForTarget(Strike.Owner, Strike.X2, Strike.Y2, 100, 800, true);
						end else begin
							Strike.Target := 0;
							Strike.AimTimer := 0;
						end;
						if strike.Timer2 > 0 then begin
							Strike.Timer2 := Strike.Timer2 - 1;
						end else
						if Strike.Target > 0 then begin
							if Strike.Timer2 = 0 then begin // switching ammo
								for a := 1 to MaxID do // find a group of zombies
									if Players[a].Alive then begin
										if PlayersInRange(a, Strike.Target, 310, false) then //TODO: false?
											if player[a].Zombie then c := c + 1 else
											if player[a].Status = 1 then begin
												if PlayersInRange(a, Strike.Target, 150, false) then begin
													c := 0;
													break;
												end;
											end;
									end;
								if Strike.AmmoType = 1 then begin
									//if c >= 5 then begin
									//	Strike.AmmoType := 3;
									//	Strike.Timer2 := 3;
									//end else
									if c >= 4 then begin
										Strike.AmmoType := 2;
										Strike.Timer2 := 2;
										Strike.HeliFireN := 0;
										Strike.Cooldown := 0;
									end;
								end else
								if c < 5 then begin
									Strike.AmmoType := 1;
									Strike.Timer2 := 4;
									Strike.HeliFireN := 0;
									Strike.Cooldown := 0;
									Strike.LastAngle := 0;
									Strike.LastDeltaAngle := 0;
								end;
							end;
						end;
					end; // <- /strike in progress
				end;
				Strike.Timer := strike.Timer - 1;
			end; // <-/main call
	
			if Strike.Target > 0 then begin
				if Strike.AmmoType = 1 then begin // Gatling
					if not Players[Strike.Target].Alive then begin
						Strike.AimTimer := 0;
						Strike.Target := lookForTarget(Strike.Owner, Strike.X2, Strike.Y2, 100, 800, true);
					end;
					if Strike.Target > 0 then begin
						// we call ballisticaimx once per 2 shoots, not to use it 15 times/s (efficiency)
						if Strike.AimTimer <= 0 then begin
							Strike.AimTimer := 1;
							GetPlayerXY(Strike.Target, X, Y);
							Y := Y - 10.0;
							Strike.CurrentAngle := BallisticAimX(Strike.X2, Strike.Y2-100, 30, Players[Strike.Target], InRange);
						end else
							Strike.AimTimer := Strike.AimTimer - 1;
						
						if Strike.CurrentAngle < 0.0 then Strike.CurrentAngle := Strike.CurrentAngle + ANG_2PI;
						// smooth fire angle progression
						if Strike.LastAngle = 0 then
							Strike.LastAngle := Strike.CurrentAngle;
						DeltaAngle := Strike.CurrentAngle-Strike.LastAngle;
						if Strike.LastDeltaAngle = 0 then begin
							Strike.LastDeltaAngle := DeltaAngle;
						end else begin
							if DeltaAngle > ANGLE_5 then begin
								DeltaAngle := ANGLE_5;
							end else if DeltaAngle < -ANGLE_5 then
								DeltaAngle := -ANGLE_5;
						end;
						// Delta factor - weighted rate factor (0-1)
						// for small values of Angle Delta, factor is less significant
						// in other words: the faster angle changes, the bigger smoothing we use
						DeltaFactor := 0.1 + (Abs(Strike.LastDeltaAngle) + Abs(DeltaAngle)) / ANGLE_5;
						if DeltaFactor > 0.7 then DeltaFactor := 0.7;
						//writeconsole(0, floattostr(DeltaFactor), green);
						Strike.CurrentAngle := Strike.LastAngle + Strike.LastDeltaAngle*DeltaFactor + DeltaAngle*(1.0-DeltaFactor);
						Strike.LastAngle := Strike.CurrentAngle;
						Strike.LastDeltaAngle := DeltaAngle;
						
						if Strike.Recoil < 1.0 then begin
							Strike.Recoil := Strike.Recoil + 0.08;
							if Strike.Recoil > 1.0 then Strike.Recoil := 1.0;
						end;
						Strike.HeliFireN := Strike.HeliFireN + 1;
						Shoot(Strike.X2, Strike.Y2 - 100.0, Strike.CurrentAngle, 0, 0, 28, 32, 0, Strike.Recoil*3.0*DEG_2_RAD, -HELI_DMG, 14, Strike.Owner, 1);
						PlaySound(0, 'dist-gun3.wav', Strike.X2, Strike.Y2);
						if Strike.HeliFireN >= 35 then begin
							Strike.Cooldown := RandInt(Strike.HeliFireN div 5, Strike.HeliFireN div 3);
							Strike.HeliFireN := 0;
							Strike.Recoil := 0;
							Strike.LastAngle := 0;
							Strike.LastDeltaAngle := 0;
						end;
					end else begin
						Strike.Recoil := 0;
						Strike.LastAngle := 0;
						Strike.LastDeltaAngle := 0;
					end;
				end else begin // missiles
					if Strike.Cooldown = 0 then begin
						Strike.HeliFireN := Strike.HeliFireN + 1;
						if Strike.HeliFireN mod 2 = 0 then begin
							for a := 1 to MaxID do // find a group of zombies
								if player[a].Status = 1 then begin
									if PlayersInRange(a, Strike.Target, 150, false) then begin
										// if survivor is in range of fire then switch back to gatling, not to kill him
										Strike.AmmoType := 1;
										Strike.Timer2 := 4;
										Strike.HeliFireN := 0;
										Strike.Cooldown := 0;
										Strike.LastAngle := 0;
										Strike.LastDeltaAngle := 0;
										exit;
									end;
								end;
							GetPlayerXY(Strike.Target, X, Y);
							//Strike.CurrentAngle := BallisticAim(Strike.X2, Strike.Y2-100, X, Y, 20, Game.Gravity, inrange);
							Strike.CurrentAngle := BallisticAim(Strike.X2, Strike.Y2-100, X, Y, 20, inrange);
							if Strike.HeliFireN = 2 then c := 4 else c := 12;
							if Strike.HeliFireN = 3 then DeltaAngle := 0.0 else DeltaAngle := ANGLE_10; // make at least one missile accurate
							X := Players[Strike.Target].VELX/2;
							Shoot(Strike.X2, Strike.Y2 - 100, Strike.CurrentAngle, X, 0, 18, 22, 0, DeltaAngle, -20, c, Strike.Owner, 1);
							PlaySound(0, 'law.wav', Strike.X2, Strike.Y2);
							if Strike.HeliFireN/2 >= RandInt(3, 4) then begin
								Strike.Cooldown := Strike.HeliFireN * 3 div 2 + RandInt_(5);
								Strike.HeliFireN := 0;
							end;
						end;
					end;
				end;
			end;
			if Strike.Cooldown > 0 then begin
				Strike.Cooldown := Strike.Cooldown-1;
			end;
		end; // <- /heli strike
	end // <- /strike active
end;

procedure Strike_Call(Style: byte);
var x, y, y2: single;
begin
	Strike.X := Marker.X;
	Strike.Y := Marker.Y;
	Strike.Style := Style;
	Strike.Active := true;
	Strike.Timer2 := 0;
	Strike.Owner := Cop.ID;
	y := Marker.Y - 350;
	y2 := y;
	x := Marker.X - 200;
	RayCast2(0, 20, 350, x, y);
	x := Marker.X + 200;
	RayCast2(0, 20, 350, x, y2);
	if y2 > y then Strike.Shift := -1 else Strike.Shift := 1;
	Strike.HeightDiff := Trunc(Abs(y2 - y));
	if Style = 1 then begin
		if y < Marker.Y then Marker.Y := y;
		if y2 < Marker.Y then Marker.Y := y2;
		Strike.Timer := STRIKETIME;
	end else
		Strike.Timer := HELITIME;
	WriteDebug(1, 'Airstrike');
end;

procedure Strike_ResetMarker();
var i: byte;
begin
	Marker.X := 0;
	Marker.Y := 0;
	if Marker.Owner > 0 then begin
		BigText_DrawMapX(WTL_MARKER, Marker.Owner, '', 1, 0, 0.1, 0, 0);
		BigText_DrawMapX(WTL_MARKER, Marker.Owner, '', 1, 0, 0.1, 0, 0);
	end;
	Marker.Owner := 0;
	for i := 0 to 2 do
		Marker.Active[i] := false;
end;

procedure Strike_SetMarker(ID: Byte);
begin
	GetPlayerXY(ID, Marker.X, Marker.Y );
	if not RayCast2(0, 40, 200, Marker.X, Marker.Y) then begin
		RayCast2(0, 4, 40, Marker.X, Marker.Y);
		WriteConsole(ID, 'Marker set!', GREEN);
		Marker.Active[0] := true;
		Marker.Owner := ID;
		Marker.Active[1] := false;
		Marker.Active[2] := false;
		if Raycast(Marker.X, Marker.Y-5, Marker.X, Marker.Y-500, false, true, true) then begin
			Marker.Active[1] := Raycast(Marker.X-150, Marker.Y-400, Marker.X+150, Marker.Y-400, false, true, true);
			Marker.Active[2] := Raycast(Marker.X-250, Marker.Y-400, Marker.X+250, Marker.Y-400, false, true, true);
			if Marker.Active[2] then
				Marker.Active[2] := Raycast(Marker.X, Marker.Y-700, Marker.X, Marker.Y-100, false, true, true);
		end;
		WriteConsole(ID, 'Marked area can' + iif(Marker.Active[1], '', 'not') + ' be bombed from the air', iif(Marker.Active[1], GREEN, RED));
		WriteConsole(ID, 'Marked area can' + iif(Marker.Active[2], '', 'not') + ' be struck by the helicopter', iif(Marker.Active[2], GREEN, RED));
		BigText_DrawMapX(WTL_MARKER, Marker.Owner, '!', 99999999, iif(Marker.Active[1] and Marker.Active[2], $22FF22, $FF2222), 0.05, Trunc(Marker.X), Trunc(Marker.Y));
		BigText_DrawMapX(WTL_MARKER, Marker.Owner, '!', 99999999, iif(Marker.Active[1] and Marker.Active[2], $22FF22, $FF2222), 0.05, Trunc(Marker.X), Trunc(Marker.Y));
	end else begin
		WriteConsole(ID, 'Cannot place the marker in the air', RED);
	end;
end;

end.
