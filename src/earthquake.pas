// * -------------- *
// |   EarthQuake   |
// * -------------- *

// This is a part of {LS} Last Stand.

unit EarthQuake;

interface

uses
{$ifdef FPC}
  Scriptcore,
{$endif}
  Bigtext,
  LSPlayers,
  Globals,
  Ballistic,
  maths,
  MersenneTwister;
  
type
  tEarthQuake = record
    Active: boolean;
    Timer: byte;
    TimeStarted, Duration: longint;
    Phase, Direction: single;
  end;
  
var
  EarthQuake: tEarthQuake;
  
procedure EarthQuake_Reset();

procedure EarthQuake_Process(MainCall: boolean);

procedure EarthQuake_Start(Duration: smallint);

implementation

const
  EQ_MAXAPLITUDE = DEFAULTGRAVITY * 12.0;
  EQ_PRESSURE = DEFAULTGRAVITY*2;

procedure EarthQuake_Reset();
begin
  EarthQuake.Active := false;
  EarthQuake.Timer := 0;
  Game.Gravity := DEFAULTGRAVITY;
  Game.Gravity := DEFAULTGRAVITY;
end;
  
procedure EarthQuake_Process(MainCall: boolean);
var DeltaT, modifier: single;
begin
  if EarthQuake.Active then begin
    if EarthQuake.Timer > 0 then begin // fast mode
      EarthQuake.Direction := -EarthQuake.Direction; // 1/-1
      DeltaT := Game.TickCount-EarthQuake.TimeStarted;
      modifier := Sqr(sin(DeltaT*EarthQuake.Phase)) // local modifier, waves are determined by sin^x
        * Sqrt(sin(ANG_PI*Sqr(DeltaT/EarthQuake.Duration))); // global modifier, Sqrt(sin(x^2)) (0 <= x^2 <= pi), raises gradually, drops significantly at the end
      Game.Gravity := DEFAULTGRAVITY + modifier * EQ_MAXAPLITUDE * (EarthQuake.Direction+EQ_PRESSURE);
      ServerModifier('Gravity', Game.Gravity);
      if RandInt_(3) = 0 then
        if HackermanMode then begin
        BigText_DrawScreen(0,'XXX',ToRangeI(10, Trunc(60*modifier), 60), $2067B2,46,-3920,-4260);   // makes screen flash blue on haxmaps.
      end else
        BigText_DrawScreen(0,'XXX',ToRangeI(10, Trunc(60*modifier), 60), $280000,46,-3920,-4260);
    end;
  end;
  if MainCall then begin
    EarthQuake.Timer := EarthQuake.Timer - 1;
    if EarthQuake.Timer <= 0 then begin // normal mode
      EarthQuake_Reset();
    end;
  end;
end;

procedure EarthQuake_Start(Duration: smallint);
begin
  EarthQuake.Active := true;
  EarthQuake.Timer := Duration;
  EarthQuake.Duration := Duration*60;
  EarthQuake.Direction := 1.0;
  EarthQuake.Phase := ANG_PI * Trunc(math.Pow(Duration, 0.667)) / (60.0 * Duration); // sinusoide semi-periods (60 - ticks/s)
  EarthQuake.TimeStarted := Game.TickCount;
end;

begin
end.
