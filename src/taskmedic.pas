unit TaskMedic;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	BaseWeapons,
	BigText,
	Constants,
	Configs,
	Charges,
	Debug,
	Damage,
	GameModes,
  Globals,
	Objects,
	LSPlayers,
	Maths,
  Misc,
	PlacePlayer,
	Raycasts,
	Statguns,
	Strikes,
	Tasks,
	Weapons,
	WeaponMenu;

procedure TaskMedic_Call(ID: byte);

procedure TaskMedic_Reset();

procedure TaskMedic_RevivePlayer(ID: byte);

procedure TaskMedic_OnCommand(Text: string);

procedure TaskMedic_OnWeaponChange(PrimaryNum, SecondaryNum: byte);

procedure TaskMedic_Process(MainCall: boolean);

procedure TaskMedic_OnUnpause();

procedure TaskMedic_OnSurvivorLeaveGame(ID: byte);

procedure TaskMedic_OnSurvivorDie(ID: byte);

implementation

const
  //Medic's radar
  RADAR_ALPHA = ANG_PI/18;
  RADAR_COL = $FFFFFF;
  RADAR_PLAYER_COL = $00FF00;
  RADAR_OTHERS_COL = $AA4455;
  RADAR_RANGEM = 100.0; // meters
  RADAR_RADIUS = 90.0;
  RADAR_DIST_EXPONENT = 0.98; // some nonlinearity
  RADAR_X = 100;
  RADAR_Y = 250;
  RADAR_SCALE = 0.04;
  RADAR_MAP_SCALE = 0.2;
  RADAR_MAP_SCALE_OTHERS = 0.08;
  RADAR_RANGE = RADAR_RANGEM * PX_PER_METER;

// * ------------------ *
// |        Medic       |
// * ------------------ *
procedure Radar_DrawWorldMarkerMedic(i: byte);
begin
	//BigText_DrawMapX(WTL_RADAR, i, '^', 120, RG_Gradient(1.0*player[i].SpecTimer/DeathTimer, 240), RADAR_MAP_SCALE, player[i].X - 7, player[i].Y-5);
	BigText_DrawMapX(WTL_RADAR+i, Medic.ID, '^', 120,
  	RG_Gradient(1.0*player[i].SpecTimer/LSMap.DeathTimer, 0.9), RADAR_MAP_SCALE,
    Trunc(player[i].X) - 7, Trunc(player[i].Y-5)
  );
end;

procedure Radar_DrawWorldMarkerOthers(i: byte);
var j, k: integer;
begin
  for k := 0 to 1 do // packetloss
  for j := 1 to MaxID do begin
  	if Players[j].Human then
    if j <> Medic.ID then begin
      BigText_DrawMapX(WTL_RADAR+i, j, '+', player[i].SpecTimer*60,
  	    RADAR_OTHERS_COL, RADAR_MAP_SCALE_OTHERS, Trunc(player[i].X) - 4,
        Trunc(player[i].Y-2.5)
      );
    end;
  end;
end;

procedure Radar_ClearWorldMarker(i: byte);
var j, k: integer;
begin
  for k := 0 to 1 do begin // packetloss
    BigText_DrawMapX(WTL_RADAR+i, Medic.ID, '', 1, 0, 1, 0, 0);
    for j := 1 to MaxID do begin
      if Players[j].Human then
      if j <> Medic.ID then begin
        BigText_DrawMapX(WTL_RADAR+i, j, '', 1, 0, 1, 0, 0);
      end;
    end;
  end;
end;

procedure Radar_Draw(Time: integer);
var i, j: integer;
begin
	DrawTextEx(Medic.ID, DTL_RADAR, '.', Time * 60, RADAR_PLAYER_COL, RADAR_SCALE, RADAR_X, RADAR_Y);
	for i := 0 to 1 do begin // packetloss
		for j := 1 to round(2*ANG_PI/RADAR_ALPHA) do begin
			DrawTextEx(Medic.ID, DTL_RADAR + 1 + j, '.', Time * 60, RADAR_COL, RADAR_SCALE,
				RADAR_X+round(cos(RADAR_ALPHA*j)*RADAR_RADIUS), RADAR_Y+round(sin(RADAR_ALPHA*j)*RADAR_RADIUS)
			);
    end;
  end;
end;

procedure Radar_Restore();
var i, maxTimer: integer;
begin
	for i := 1 to MaxID do begin
		if player[i].SpecTimer > 0 then begin
			Radar_DrawWorldMarkerMedic(i);
      Radar_DrawWorldMarkerOthers(i);
			if player[i].SpecTimer > maxTimer then
				maxTimer := player[i].SpecTimer;
		end;
  end;
  if maxTimer > 0 then
		Radar_Draw(maxTimer);
end;

procedure Radar_Clear();
var i, j: byte;
begin
	for i := 0 to round(2*ANG_PI/RADAR_ALPHA) + 1 do
		for j := 0 to 2 do
			Drawtextex(Medic.ID, DTL_RADAR + i, '', 9999999, 0, 0, 99999, 99999);
end;

procedure Radar_Process();
var
	a: byte;
	dx, dy, d, factor: single;
	str: string;
begin
	if Medic.ID > 0 then
	if Players[Medic.ID].Alive then
		for a := 1 to MaxID do
			if Players[a].Active then
			if player[a].SpecTimer > 0 then begin
				GetPlayerXY(Medic.ID, player[Medic.ID].X, player[Medic.ID].Y);
				dx := player[a].X - player[Medic.ID].X;
				dy := player[a].Y - player[Medic.ID].Y;
				d := Distance(player[a].X, player[a].Y, player[Medic.ID].X, player[Medic.ID].Y);
				d := Math.Pow(d, RADAR_DIST_EXPONENT);
				factor := d / RADAR_RANGE * RADAR_RADIUS;
				if factor > RADAR_RADIUS then factor := RADAR_RADIUS;
				dx := dx / d * factor;
				dy := dy / d * factor;
				str := IntToStr(player[a].SpecTimer);
				DrawTextEx(Medic.ID, DTL_RADAR - a, str, 60, RG_Gradient(1.0*player[a].SpecTimer/LSMap.DeathTimer, 0.9),
					RADAR_SCALE, Trunc(RADAR_X+dx) - 2 * Length(str), Trunc(RADAR_Y+dy) + 2
				);
				Radar_DrawWorldMarkerMedic(a);
			end;
end;

procedure TaskMedic_Heal(ID: byte; Hp: smallint);
var
	j: byte; X, Y, X2, Y2: single;
begin
	GetPlayerXY(ID, X, Y);
	for j := 1 to MaxID do
		if j <> Medic.ID then
		if Players[j].Alive then
		if not player[j].Zombie then begin
			GetPlayerXY(j, X2, Y2);
			if Distance(X, Y, X2, Y2) < 33.0 then
			case Damage_Heal(j, hp) of
				1: begin
					BigText_DrawScreenX(DTL_HEALING, ID, 'Healing',100, $3040FF, 0.08, 20, 370 );
					BigText_DrawScreenX(DTL_HEALING, j, 'You are being healed...',100, $3040FF, 0.08, 20, 370 );
					hp := hp div 2;
				end;
				2: begin
					BigText_DrawScreenX(DTL_HEALING, ID, 'Soldier is at full health',100, $3040FF, 0.08, 20, 370 );
					BigText_DrawScreenX(DTL_HEALING, j, 'Fully healed!',100, $3040FF, 0.08, 20, 370 );
					hp := hp div 2;
				end;
			end;
		end;
end;

procedure TaskMedic_AutoHeal();
var X, Y: single;
begin
	if Medic.ID > 0 then
	if Players[Medic.ID].Alive then begin
		GetPlayerXY(Medic.ID, X, Y);
		if PointsInRange(X, Y, Medic.X, Medic.Y, 40, false) then begin
			if Medic.HealSpeed < 10 then Medic.HealSpeed := Medic.HealSpeed + 2;
			Damage_Heal(Medic.ID, Medic.HealSpeed);
		end else
			Medic.HealSpeed := 0;
		Medic.X := X;
		Medic.Y := Y;
	end;
end;

procedure TaskMedic_Call(ID: byte);
var
	dx: word; x1,x2,y: single;
begin
	if player[ID].Status = 1 then begin
		if Medic.ID > 0 then begin
			if ( Medic.ID <> ID ) then begin
				if Players[Medic.ID].Alive then begin
					GetPlayerXY(ID, x1, y);
					GetPlayerXY(Medic.ID, x2, y);
					dx := trunc(abs(x1 - x2)/PX_PER_METER);
					if x1 > x2 then
					begin
						Players[Medic.ID].WriteConsole(Players[ID ].Name + ' is calling for help to your right!', GREEN);
						Players[ID].WriteConsole('Doctor '+ Players[ Medic.ID ].Name +' is on your left ('+IntToStr(dx)+'m)', GREEN);
						BigText_DrawScreenX(DTL_NOTIFICATION, Medic.ID, 'Call for help! ('+IntToStr(dx)+'m)> -->',100, RGB(255,80,80), 0.1, 20, 370 );
					end else
					begin
						Players[Medic.ID].WriteConsole(Players[ID ].Name + ' is calling for help to your left!', GREEN);
						Players[ID].WriteConsole('Doctor '+ Players[ Medic.ID ].Name +' is on your right ('+IntToStr(dx)+'m)', GREEN);
						BigText_DrawScreenX(DTL_NOTIFICATION, Medic.ID, '<-- <('+IntToStr(dx)+'m) Call for help!',100, RGB(255,80,80), 0.1, 20, 370 );
					end;
				end else Players[ID].WriteConsole('The doctor is dead!', RED);
			end else Players[ID].WriteConsole('You are the doctor...', RED);
		end else Players[ID].WriteConsole('Your team has no doctor!', RED);
	end;
end;

procedure TaskMedic_RevivePlayer(ID: byte);
var i: byte; found: boolean;
begin
	Players.WriteConsole(Players[ID ].Name + ' has been revived!', GREEN);
	BigText_DrawScreenX(DTL_NOTIFICATION, 0, Players[ID ].Name + ' has been revived!',180,  RGB(100,255,100), 0.1, 20,370);
	WriteDebug(3,  'player ' + IntToStr(ID ) + ' revived');
	Radar_ClearWorldMarker(ID);
	player[ID].Status := 1;
	player[ID].bitten := false;
	player[ID].SpecTimer := 0;
	Player[ID].TicksAtSpawn := Timer.Value;
	SetTeam(HUMANTEAM, ID, true);
	Damage_DoAbsolute(ID, ID, 15);
	found := false;
	for i := 1 to MaxID do
		if player[i].SpecTimer > 0 then
			found := true;
	if not found then Radar_Clear();
end;

procedure TaskMedic_TryRevive();
var i: byte;
begin
	if Players[Medic.ID].Alive then
	for i := 1 to MaxID do begin
		if player[i].Status = 2 then
		if Players[i].Active then
		if Medic.ID <> i then
		if player[i].SpecTimer > 0 then
		if IsInRange(Medic.ID , player[i].X, player[i].Y, 50, false) then
			TaskMedic_RevivePlayer(i);
	end;
end;

procedure TaskMedic_OnCommand(Text: string);
begin

  if LowerCase(Copy(Text, 2, 3)) = 'rev' then begin
    if Players[Medic.ID].Alive then begin
    	TaskMedic_TryRevive();
    end else
      players[Medic.ID].WriteConsole('You are already dead', RED);
  end;
end;

procedure TaskMedic_OnWeaponChange(PrimaryNum, SecondaryNum: byte);
begin
	// If it's called by AppOnIdle with two same weapons heal a bit slower (4 calls per sec)
	TaskMedic_TryRevive();
	TaskMedic_Heal(Medic.ID, iif(PrimaryNum = SecondaryNum, 5, 15));
end;

procedure TaskMedic_Reset();
begin
	Radar_Clear();
  Medic.ID := 0;
end;

procedure TaskMedic_Process(MainCall: boolean);
begin
  if MainCall then TaskMedic_AutoHeal();
  Radar_Process();
end;

procedure TaskMedic_OnUnpause();
begin
  Radar_Restore();
end;

procedure TaskMedic_OnSurvivorLeaveGame(ID: byte);
var
  i: integer;
begin
	if player[ID].SpecTimer > 0 then begin
		player[ID].SpecTimer := 0;
		Radar_ClearWorldMarker(ID);
		for i := 1 to MaxID do
			if player[i].SpecTimer > 0 then break;
		if i > MaxID then
			Radar_Clear();
	end;
end;

procedure TaskMedic_OnSurvivorDie(ID: byte);
begin
  if ID = Medic.ID then
		Radar_Clear()
	else
  if Players[Medic.ID].Alive then begin
		Radar_Draw(LSMap.DeathTimer);
		Radar_DrawWorldMarkerMedic(ID);
    Radar_DrawWorldMarkerOthers(ID);
	end;
end;

end.

