unit MersenneTwister;

//  * ------------------------------------------ *
//  |  Mersenne Twister Random Number Generator  |
//  * ------------------------------------------ *

interface

procedure MTInit(seed: LongWord);
function RandInt(min, max: integer): Integer;
function RandInt_(max: integer): Integer;
function RandSign(): shortint;
function RandBool(): boolean;
function RandByte(): byte;
function RandFlt(min, max: Single): Single;
function RandFlt_(): Single;

implementation

const // don't touch
// Period parameters
  MT_N = 624;
  MT_M = 397;
  MATRIX_A   = $9908b0df;   { constant vector a }
  UPPER_MASK = $80000000; { most significant w-r bits }
  LOWER_MASK = $7fffffff; { least significant r bits }
// Tempering parameters
  TEMPERING_MASK_B = $9d2c5680;
  TEMPERING_MASK_C = $efc60000;

var
  mt: array[0..MT_N - 1] of Int64; { the array for the state vector  }
	mti: LongInt; { mti==N+1 means mt[N] is not initialized }

//initializing the array with a NONZERO seed
procedure MTInit(seed: LongWord);
begin
	mt[0] := seed and $ffffffff;
  mti := 1;
  while(mti<MT_N)do
  begin
    mt[mti] := ((69069 * mt[mti-1]) and $ffffffff);
    mti := mti + 1;
  end;
end;

function GenRandIntMT: LongWord;
var
  mag01: array[0..1] of LongWord;
  y: LongWord;
  kk: LongInt;
begin
  mag01[0]:=$0;
	mag01[1]:=MATRIX_A;
	if (mti >= MT_N) then begin
    if (mti = (MT_N+1))then
      MTInit(4357);
    kk := 0;
    while(kk<(MT_N-MT_M))do begin
      y := (mt[kk]and UPPER_MASK)or(mt[kk+1]and LOWER_MASK);
      mt[kk] := mt[kk+MT_M] xor (y shr 1) xor mag01[y and $1];
      kk := kk + 1;
    end;
    while(kk<(MT_N-1))do begin
      y := (mt[kk]and UPPER_MASK)or(mt[kk+1]and LOWER_MASK);
      mt[kk] := mt[kk+(MT_M-MT_N)] xor (y shr 1) xor mag01[y and $1];
      kk := kk + 1;
    end;
    y := (mt[MT_N-1]and UPPER_MASK)or(mt[0]and LOWER_MASK);
    mt[MT_N-1] := mt[MT_M-1] xor (y shr 1) xor mag01[y and $1];
    mti := 0;
  end;
  y := mt[mti];
  mti := mti +	1;
  y := y xor (y shr 11);
  y := y xor (y shl 7) and TEMPERING_MASK_B;
  y := y xor (y shl 15) and TEMPERING_MASK_C;
  y := y xor (y shr 18);
  Result := y;
end;

function RandInt(min, max: integer): Integer;
begin
	Result := max - min + 1;
	if Result = 0 then begin
		Result := min;
		exit;
	end;
	max := GenRandIntMT;
	if max < 0 then max := -max;
	Result := min + max mod Result;
end;

function RandInt_(max: integer): Integer;
begin
	Result := GenRandIntMT;
	if Result < 0 then Result := -Result;
	Result := Result mod (max + 1);
end;

function RandByte(): byte;
begin
	Result := GenRandIntMT mod 2;
end;

function RandBool(): boolean;
begin
	Result := GenRandIntMT mod 2 = 0;
end;

function RandSign(): shortint;
begin
	if GenRandIntMT mod 2 = 1 then Result := 1 else Result := -1;
end;

function RandFlt(min, max: Single): Single;
begin
	Result := min + (max - min) * GenRandIntMT * 2.3283064370807974e-10;
end;

function RandFlt_(): Single;
begin
	Result := GenRandIntMT * 2.3283064370807974e-10;
end;

finalization

end.
