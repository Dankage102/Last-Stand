//  * ------------- *
//  |     Mines     |
//  * ------------- *

// This is a part of {LS} Last Stand. 

unit landmines;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Constants,
	Damage,
	Globals,
	LSPlayers,
	Misc,
	maths,
	MersenneTwister,
	Raycasts;
	
const
	MAX_MINES = 	 20;
	
type
	tMineSyst = record
		PS, SR, MaxAngle, RMax, RMin: single;
		MaxMineID: byte;
		Mine: array [1..MAX_MINES] of record
			x, y: single;
			placed: boolean;
			owner: byte;
		end;
	end;

var
	Mines: tMineSyst;
	
function Mines_Place(ID: byte): boolean;

procedure Mines_TryPlace(ID: byte);

procedure Mines_Initialise(Sensitivity: single);

procedure Mines_Process();

procedure Mines_Sign();

procedure Mines_Clear(a: byte);

implementation


function Mines_Place(ID: byte): boolean;
var
	found: boolean;
	a: byte;
begin
	for a := 1 to MAX_MINES do
		if not Mines.Mine[a].placed then begin
			found := true;
			break;
		end;
	if found then begin
		GetPlayerXY(ID, Mines.Mine[a].X, Mines.Mine[a].Y);
		RayCast2(0, 4, 20, Mines.Mine[a].X, Mines.Mine[a].Y); // move mine pointer to the ground so marker doesn't jump
		RayCast2(0, 1, 4, Mines.Mine[a].X, Mines.Mine[a].Y); // more accuracy
		Mines.Mine[a].Y := Mines.Mine[a].Y - 4;
		Mines.Mine[a].placed := true;
		Mines.Mine[a].owner := ID;
		if a > Mines.MaxMineID then Mines.MaxMineID := a;
		Result := true;
	end;
end;

procedure Mines_TryPlace(ID: byte);
begin
	if player[ID].task = 2 then begin
		if Players[ID].Alive then begin
			case Players_OnGround(ID, false, 20) of
				1: if player[ID].Mines > 0 then begin
						if Mines_Place(ID) then begin
							player[ID].Mines := player[ID].Mines - 1;
							WriteConsole(ID, 'Mine placed ('+IntToStr(player[ID].Mines)+' left)! Keep distance to activate it!', GREEN);
						end else WriteConsole(ID, 'Mines limit in game exceeded', RED);
					end else WriteConsole(ID, 'You do not have any mines left', RED);
				-1: WriteConsole(ID, 'You have to be on the solid ground to place a mine', RED);
				else WriteConsole(ID, 'You have to be on the ground to place a mine', RED);
			end;
		end else WriteConsole(ID, 'You have to be alive to place a mine', RED);
	end else WriteConsole(ID, 'You are not the demolition expert ', RED);
end;

procedure Mines_Initialise(Sensitivity: single);
begin
	Mines.PS := 6.0 * Sensitivity; // position shift factor
	Mines.SR := 25.0 * Sensitivity; // speed -> range factor
	Mines.RMin := 18.0 * Sqrt(Sensitivity); // min, max radius of range
	Mines.RMax := 80.0 * Sensitivity;
	Mines.MaxAngle := 40 // max angle between vectors (player_speed, distance_mine_player) in degrees
		* DEG_2_RAD; // deg -> rad
end;

procedure Mines_Process();
var
	i, j, k, owner: byte; x, y, x2, y2, v1x, v1y, v2x, v2y, a, r: single;
begin
	if Mines.MaxMineID > 0 then
		for i:=1 to Mines.MaxMineID do
			if Mines.Mine[i].placed then begin
				for j:=1 to MaxID do
					//if Players[j].Active then
						if Players[j].Alive then
							if player[j].Zombie then
							begin
								GetPlayerXY(j, x, y);
								v2x:=Mines.Mine[i].X-x;
								if Abs(v2x) <= Mines.RMax*2 then 
								begin
									v2y:=Mines.Mine[i].Y-2-y;
									if Abs(v2y) <= Mines.RMax*2 then
									begin
										if Players[Mines.Mine[i].owner].Alive then begin
											GetPlayerXY(Mines.Mine[i].owner, x2, y2);
											if PointsInRange(x, y, x2, y2, 100, false) then //TODO: false?
												continue;
										end;
										v1x:=Players[j].VELX;
										v1y:=Players[j].VELY;
										r:=ToRangeF(Mines.RMin, Sqrt(v1x*v1x + v1y*v1y)*Mines.SR, Mines.RMax);
										if IsInRange(j, Mines.Mine[i].X + v1x*Mines.PS * r / Mines.RMax, Mines.Mine[i].Y + v1y*Mines.PS * r / Mines.RMax, r, false) then begin //TODO: false?
											//nova_2(Mines.Mine[i].X + v1x*Mines.PS * r / Mines.RMax, Mines.Mine[i].Y + v1y*Mines.PS * r / Mines.RMax, 0, 0, r, 0, 0, ANG_2PI,0, 10, 5, Mines.Mine[i].owner);
											if r > Mines.RMin+5 then begin
												// calculate angle between vectors
												a:=math.arccos((v1x*v2x + v1y*v2y) / Sqrt((v1x*v1x + v1y*v1y)*(v2x*v2x + v2y*v2y)));
												if a>ANGLE_90 then a:=pi-a;
												if a > Mines.MaxAngle then
													continue;
											end;
											Mines.Mine[i].placed := false;
											CreateBulletX( Mines.Mine[i].X, Mines.Mine[i].Y - 19, 0, 0, 99,4, Mines.Mine[i].owner );
											CreateBulletX( Mines.Mine[i].X + 19, Mines.Mine[i].Y - 5, 0, 0, 99, 4, Mines.Mine[i].owner );
											CreateBulletX( Mines.Mine[i].X - 19, Mines.Mine[i].Y + 5, 0, 0, 99, 4, Mines.Mine[i].owner);
											CreateBulletX( Mines.Mine[i].X + RandFlt(-24,24), Mines.Mine[i].Y - RandFlt(8,16), 0, 0, 99, 4, Mines.Mine[i].owner);
											CreateBulletX( Mines.Mine[i].X, Mines.Mine[i].Y -10, RandFlt(-7, 7), RandFlt(-4, 0), 0, 14, Mines.Mine[i].owner);
											if player[Mines.Mine[i].owner].Status > 0 then owner := Mines.Mine[i].owner else owner := 0;
											Damage_ZombiesAreaDamage(owner, Mines.Mine[i].X, Mines.Mine[i].Y, 75, 130, 4000, explosion);
											WriteConsole( Mines.Mine[i].owner, 'Your mine detonated!', GREEN);
											// refresh max mine id
											if i = Mines.MaxMineID then begin
												for k := MAX_MINES downto 1 do
													if Mines.Mine[k].placed then begin
                            Mines.MaxMineID := k;
														break;
													end;
											end;
											break;
										end;
									end;
								end;
							end;
		end;
end;

procedure Mines_Sign();
var g: byte;
begin
for g := 1 to Mines.MaxMineID do
	if Mines.Mine[g].placed then
		if (Timer.Value div 60) mod 5 = g mod 5 then
			CreateBulletX(Mines.Mine[g].X,Mines.Mine[g].Y,0,0,0,7,Mines.Mine[g].owner);
			//BigText_DrawMap(0, '|', 360, 0, 0.08, trunc(Mines.Mine[g].X)-3, trunc(Mines.Mine[g].Y)-8);
end;

procedure Mines_Clear(a: byte);
begin
	Mines.Mine[a].X := 0;
	Mines.Mine[a].Y := 0;
	Mines.Mine[a].placed := false;
	Mines.Mine[a].owner := 0;
end;

begin
end.
