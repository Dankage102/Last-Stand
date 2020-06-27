unit Ballistic;

//  * --------------------- *
//  |  Ballistic Functions  |
//  * --------------------- *

interface

{$ifdef FPC}
	uses Scriptcore;
{$endif}

const
  DEFAULTGRAVITY = 0.06;
	G_BUL = -0.135; //gravity acceleration for a bullet [pixels/tick^2]
	K_AIR = 0.01; // air resistance factor
	G_PL = -DEFAULTGRAVITY;
	
	ik_ = 1.0 - K_AIR;

type
	tTVector = record
		x, y, vx, vy: single;
		t: word;
	end;
	
// returns time in ticks of a bullet's flight
// sx - x axis distance beetween start and destination
// vx - x axis velocity of a bullet
function BallisticTime(sx, vx: double): double;
//	external 'BallisticTime@ballistic.dll';
	
function BallisticAim(x1, y1, x2, y2, v: double; var target_in_range: boolean): double;

function BallisticAimX(x, y, v: double; target: tActivePlayer; var target_in_range: boolean): double;

function BallisticAimX2(shooter, target: tActivePlayer; velocity, inheirted: double; var target_in_range: boolean): double;

//function BallisticAimX32(x0, y0, vx0, vy0, x1, y1, vx1, vy1, ax1, ay1, velocity: double; var target_in_range: boolean): double;

function BallisticCast(x, y, g: single; var vec: tTVector; CheckPlayerOnly, CheckBulletOnly: boolean): boolean;

implementation

// -----------------------------------------------------------------------------
const
	BA_ITERATIONS = 20;
	BA_EPSILON = 1.0;
	BA_GAMMA = 1.0;
	BAX_GAMMA = 1.0;
	BA_S_EPSILON = BA_EPSILON*BA_EPSILON;
	

// Simple 2x2 matrix for the Newton algo.
type Matrix2 = record
	m11, m12: double;
	m21, m22: double;
end;

type Vector2 = record
	v1: double;
	v2: double;
end;

function Matrix2VecMul(var m: Matrix2; var v: Vector2): Vector2;
begin
	Result.v1 := m.m11*v.v1 + m.m12*v.v2;
	Result.v2 := m.m21*v.v1 + m.m22*v.v2;
	//WriteLn('[' + FormatFloat('', Result.v1) + ', ' + FormatFloat('', Result.v2));
end;

function Matrix2Inverse(var m: Matrix2): Matrix2;
var
	idet: double;
begin
	idet := 1.0/(m.m11*m.m22 - m.m21*m.m12);
	Result.m11 := m.m22 * idet;
	Result.m12 := -m.m12 * idet;
	Result.m21 := -m.m21 * idet;
	Result.m22 := m.m11 * idet;
end;  

//function BallisticAim_DLL(x1, y1, x2, y2, v, gravity_factor: double; var time: double): double;
//	external 'BallisticAim@ballistic.dll';
	
//function BallisticAimX_DLL(
//	a, t,
//	xb0, yb0,
//	xp0, yp0, vpx, vpy, accpx, accpy,
//	vb, gravity_factor: double;
//	var target_in_range: boolean
//): double;
//	external 'BallisticAimX@ballistic.dll';
	
// Ballstic functions

// returns time in ticks of a bullet's flight
// sx - x axis distance beetween start and destination
// vx - x axis velocity of a bullet
function BallisticTime(sx, vx: double): double;
begin
	Result := -Math.ln(1 - K_AIR*sx/vx) / K_AIR;
end;


// Simple ballistic aim. Calculates the angle the bullet must be shot with,
// to reach destination. Air restistance and gravity are taken into account.
// Basic Newton algorithm was employed to find the solution of ballistic curve
// equation:
// F(a, x) = y; x and y are given.
//
// Ballistic curve:
// F(a) = x*(tan(a) + g/(k*v*cos(a))) + (g*logn(e, 1 - (k*x)/(v*cos(a))))/k^2
//
// Jacobian (in this case just dF/da):
// J(a) = x*(tan(a)^2 + (g*sin(a))/(k*v*cos(a)^2) + 1) +
//                      + (g*x*sin(a))/(k*v*cos(a)^2*((k*x)/(v*cos(a)) - 1)) =
//      = (x*(- cos(a)*v^2 + k*x*v + g*x*sin(a)))/(v*cos(a)^2*(k*x - v*cos(a)))
//
// x1, y1: bullet starting point
// x2, y2: bullet destination
// v: bullet velocity
// gravity: current server's gravity factor (normalized do 1.0 at default gravity)
// time: estimated time of collision, returned via reference
function _ba_solve(x1, y1, x2, y2, v, gravity_factor: double; var time: double): double;
var
	x, y, a, err: double;
	F, J: double;
	s, c, vc, kx, g: double;
	n: integer;
begin
	x := x2 - x1;
	y := y2 - y1;
	a := Math.arctan2(y, x);
	// a := arctan2(y, x);
	n := BA_ITERATIONS;
	g := G_BUL * gravity_factor;
	kx := K_AIR*x;
	while n > 0 do begin
		s := sin(a);
		c := cos(a);
		vc := v*c;
		if K_AIR*x/vc >= 1.0 then begin
			break;
		end;
		F := x*(s/c + g/(K_AIR*vc)) +
				(g*Math.ln(1 - kx/vc))/(K_AIR*K_AIR);
		J := (x*(-vc*v + kx*v + g*x*s))/(vc*c*(kx - vc));
		err := F - y;
		a := a - BA_GAMMA*err/J;
		if abs(err) < BA_EPSILON then begin
			break;
		end;
		n := n - 1;
	end;
	time := BallisticTime(abs(x), abs(cos(a)*v));
	Result := a;
end;


// Extended ballistic aim. It finds an angle the bullet must be shot with,
// to collide with a player moving by parametrized trajectory.
// Gravity, air resistance and inherted shooter velocity are taken into account.
// Player trajectory is parametrized by initial position, velocity and
// acceleration.
// Newton algorithm will be employed here. See derivation.m file for derivation
// of the equations.
//
// a, t - initial seeking point that must be provided. Simple BallisticAim or
//   atan2 and BallisticTime may be used. t may also be chosen arbitrarily.
//
// xb0, yb0 - bullet starting position
//
// vxb0, vyb0 - bullet initial inheirted velocity. May be set to zero
//  or a fraction of velocity the "shooter" is moving with.
//
// xp0, yp0, vpx, vpy, accpx, accpy - parameters of players trajectory:
//  initial position, velocity and acceleration. The acceleration may be set to
//  [0, 0], player trajectory will be simulated as a line based on velocity.
//  To take player gravity into account, [0, -0.06] may be set. Other forces
//  like left, right and jetpack keys may also be included in acceleration.
//
// vb - velocity the bullet will be shot with
//
// gravity_factor - current server gravity (normalized to 1.0 at default gravity)
//
// var target_in_range - was the solution found? Returned via reference.
function _bax_solve(
	a, t,
	xb0, yb0,
	vxb0, vyb0,
	xp0, yp0, vpx, vpy, accpx, accpy,
	vb, gravity_factor: double;
	var target_in_range: boolean
): double;
var
	n: integer;
	F, TMP: Vector2;
	J, Ji: Matrix2;
	vbs, vbc, ex, ex1, ik, gb: double;
	dx0, dy0, akvx, akvy, ex1ik, gbkvby, gbkvbys, vxb0vbc: double;
begin
	n := BA_ITERATIONS;
	ik := 1.0/K_AIR;
	gb := G_BUL * gravity_factor;
	dx0 := xb0 - xp0;
	dy0 := yb0 - yp0;
	target_in_range := false;
	akvx := accpx + K_AIR*vpx;
	akvy := accpy + K_AIR*vpy;
	gbkvby := gb + K_AIR*vyb0;
	while n > 0 do begin
		vbs := vb*sin(a); // repeated calculcations
		vbc := vb*cos(a);
		ex := exp(-K_AIR*t);
		ex1 := ex-1.0;
		ex1ik := ex1*ik;
		gbkvbys := gbkvby + K_AIR*vbs;
		vxb0vbc := vxb0 + vbc;
		F.v1 := dx0 + (ex1*(akvx*ik - vxb0vbc) + accpx*t)*ik;
		F.v2 := dy0 - (gb*t - (akvy - gbkvbys)*ex1ik - accpy*t)*ik;
		if F.v1*F.v1 + F.v2*F.v2 < BA_S_EPSILON then begin
			target_in_range := t > 0.0;
			//Players.WriteConsole(FormatFloat('0.0', t) + '   ' + InttoStr(BA_ITERATIONS-n), $FFFF00);
			Result := a;
			exit;
		end;
		J.m11 := ex*vxb0vbc + (accpx - ex*akvx)*ik;
		J.m12 := vbs*ex1ik;
		J.m21 := (accpy - gb - ex*(akvy - gbkvbys))*ik;
		J.m22 := -vbc*ex1ik;
		Ji := Matrix2Inverse(J);
		TMP := Matrix2VecMul(Ji, F);
		t := t - BAX_GAMMA * TMP.v1;
		a := a - BAX_GAMMA * TMP.v2;
		n := n - 1;
	end;
	if F.v1*F.v1 + F.v2*F.v2 < BA_S_EPSILON then begin
		target_in_range := t > 0.0;
		//Players.WriteConsole(FormatFloat('0.0', t) + '   ' + InttoStr(BA_ITERATIONS-n), $FFFF00);
		Result := a;
	end;
end; 

//function _bax_solve2(
//	a, t,
//	xb0, yb0,
//	vxb0, vyb0,
//	xp0, yp0, vpx, vpy, accpx, accpy,
//	vb, gravity_factor: double;
//	var target_in_range: boolean
//): double;
//var
//	n: integer;
//	F, TMP: Vector2;
//	J, Ji: Matrix2;
//	vbs, vbc, ex, ik, gb: double;
//	dx0, dy0, akvxik, ex1ik, vxb0vbc, accpygbik, gbkvbakvyik: double;
//begin
//	n := BA_ITERATIONS;
//	ik := 1.0/K_AIR;
//	gb := G_BUL * gravity_factor;
//	dx0 := xb0 - xp0;
//	dy0 := yb0 - yp0;
//	akvxik := (accpx + K_AIR*vpx)*ik;
//	gbkvbakvyik := (accpy + K_AIR*vpy - (gb + K_AIR*vyb0))*ik;
//	accpygbik := (accpy-gb)*ik;
//	target_in_range := false;
//	while n > 0 do begin
//		vbs := vb*sin(a); // repeated calculcations
//		vbc := vb*cos(a);
//		ex := exp(-K_AIR*t);
//		ex1ik := ex*ik-ik;
//		vxb0vbc := vxb0 + vbc;
//		F.v1 := xb0 - xp0 + ((accpx + K_AIR*vpx)*(ex - 1))/K_AIR/K_AIR - ((ex - 1)*(vxb0 + vbc))/K_AIR + (accpx*t)/K_AIR;
//		F.v2 :=  yb0 - yp0 - (gb*t)/K_AIR + ((accpy + K_AIR*vpy)*(ex - 1))/K_AIR/K_AIR - ((ex - 1)*(gb + K_AIR*vyb0 + K_AIR*vbs))/K_AIR/K_AIR + (accpy*t)/K_AIR;
//		if F.v1*F.v1 + F.v2*F.v2 < BA_S_EPSILON then begin
//			target_in_range := true;
//			break;
//		end;
//		J.m11 := ex*(vxb0 + vbc) + accpx/K_AIR - (ex*(accpx + K_AIR*vpx))/K_AIR;
//		J.m12 := (vbs*(ex - 1))/K_AIR;
//		J.m21 := accpy/K_AIR - gb/K_AIR - (ex*(accpy + K_AIR*vpy))/K_AIR + (ex*(gb + K_AIR*vyb0 + K_AIR*vbs))/K_AIR;
//		J.m22 := -(vbc*(ex - 1))/K_AIR;
//		Ji := Matrix2Inverse(J);
//		TMP := Matrix2VecMul(Ji, F);
//		t := t - BAX_GAMMA * TMP.v1;
//		a := a - BAX_GAMMA * TMP.v2;
//		n := n - 1;
//	end;
//	//WriteLn(inttostr(BA_ITERATIONS-n));
//	Result := a;
//end;

function _bax(x, y, v, vb0x, vb0y: double; target: tActivePlayer; var target_in_range: boolean): double;
var
	a0, t0: double;
	px, py: double;
	vx, vy: double;
	ax, ay: double;
	gravity: double;
	ground: boolean;
begin
	gravity := Game.Gravity / 0.06;
	
	// Calculate aiming point
	px := target.X;
	py := target.Y - 10;
	if target.KeyCrouch then
		py := target.Y - 6;
	if target.IsProne then
		py := target.Y - 3;
	
	// Get players velocity
	vx := target.VelX;
	vy := target.VelY;
	
	// Estimate players acceleration
	ground := Map.RayCast(px, py, px-10, py+50, true, false, false, false, 0);
	ground := ground or Map.RayCast(px, py, px+10, py+50, true, false, false, false, 0);
	if ((ground) or (target.OnGround)) and (vy > -3.0) then begin
		ay := 0;
	end else
		ay := G_PL*gravity;
	if (target.KeyJetpack) and (target.Jets > 20) then
		ay := ay + 0.08;
	if target.KeyLeft then
		ax := -0.01;
	if target.KeyRight then
		ax := ax + 0.01;
		
	// Aim
	a0 := _ba_solve(x, y, px, py, v, gravity, t0);
	if not ((t0 >= 0) or (t0 < 0)) then begin // if NaN
		t0 := 120;
		//Players.WriteConsole('BA failed: ' + IntToStr(Round(a0/pi*180)), $FFFFFF);
	end;
	
	// Aim
	Result := _bax_solve(
		a0, t0,
		x, y,
		vb0x, vb0y,
		px, py, vx, vy, ax, ay,
		v, gravity,
		target_in_range
	);
	
	if not target_in_range then begin
		//Players.WriteConsole('BAX failed: ' + IntToStr(Round(Result/pi*180)), $FFFFFF);
		Result := a0;
	end;
end;


function BallisticAim(x1, y1, x2, y2, v: double; var target_in_range: boolean): double;
var
	time: double;
begin
	Result := _ba_solve(x1, y1, x2, y2, v, Game.Gravity / 0.06, time);
	target_in_range := ((time >= 0) or (time < 0)); // NaN?
end;

function BallisticAimX(x, y, v: double; target: tActivePlayer; var target_in_range: boolean): double;
begin
	result := _bax(x, y, v, 0, 0, target, target_in_range);
end;

function BallisticAimX2(shooter, target: tActivePlayer; velocity, inheirted: double; var target_in_range: boolean): double;
begin
	result := _bax(shooter.X, shooter.Y - 10, velocity, inheirted*shooter.VelX, inheirted*shooter.VelY, target, target_in_range);
end;

function BallisticAimX3(x0, y0, vx0, vy0, x1, y1, vx1, vy1, ax1, ay1, velocity: double; var target_in_range: boolean): double;
var t, a: double;
begin
	a := _ba_solve(x0, y0, x1, y1, velocity,  Game.Gravity / 0.06, t);
	result := _bax_solve(a, t, x0, y0, vx0, vy0, x1, y1, vx1, vy1, ax1, ay1, velocity, Game.Gravity / 0.06, target_in_range);
end;

//function BallisticAimX32(x0, y0, vx0, vy0, x1, y1, vx1, vy1, ax1, ay1, velocity: double; var target_in_range: boolean): double;
//var x, y, t, a: double;
//begin
//	a := _ba_solve(x0, y0, x1, y1, velocity,  Game.Gravity / 0.06, t);
//	result := _bax_solve2(a, t, x0, y0, vx0, vy0, x1, y1, vx1, vy1, ax1, ay1, velocity, Game.Gravity / 0.06, target_in_range);
//end;


function BallisticCast(x, y, g: single; var vec: tTVector; CheckPlayerOnly, CheckBulletOnly: boolean): boolean;
var x2, y2: single;
begin
	while vec.t > 0 do begin
		vec.t := vec.t - 1;
		x2 := x;
		x := x + vec.vx;
		vec.vx := vec.vx * ik_;
		vec.vy := vec.vy + g;
		y2 := y;
		y := y + vec.vy;
		vec.vy := vec.vy * ik_;
		if Map.RayCast(x, y, x2, y2, CheckPlayerOnly, false, CheckBulletOnly, CheckBulletOnly, 0) then begin
			vec.X := x2;
			vec.Y := y2;
			exit;
		end;
	end;
	vec.X := x2;
	vec.Y := y2;
	Result := true;
end;

begin
end.

