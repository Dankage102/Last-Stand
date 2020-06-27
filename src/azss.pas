//	* ---------------------------- *
//	| Advanced Zombie Spawn System |
//	* ---------------------------- *

// This is a part of {LS} Last Stand.
//	This module is responsible for advanced zombie spawn system
//	The point is to modify zombie spawn position under some circumstances
//	to accelerate the game a bit, for instance when the zombies have a long way from spawn,
//	and survivors team is owning them too hard from a well set base with a few statguns.
//	Let's flood them with zombies!

unit AZSS;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	Constants,
	Debug,
  Globals,
	LSPlayers,
  maths,
  Misc,
	Stacks,
	Spawner,
  Raycasts,
  Zombies;

const
	AZSS_MAXOBSERVED = 4;
	AZSS_MAXPOINTS = 32;
	AZSS_POINT_READY_THRESHOLD = 15;
	AZSS_SPAWNS_READY_THRESHOLD = 5;
	AZSS_TMP_SPAWN_NUM = 3;
	AZSS_POINT_R = 200.0;
	AZSS_REGRESSION_FACTOR = 1.0;
	AZSS_SQR_POINT_R = AZSS_POINT_R * AZSS_POINT_R;
	
	//For the Veteran mode
	AZSS_PROGRESSION_FACTOR = 1.2;
	AZSS_PROGRESSION_FACTOR_PER = 0.5;
	
	
	V_AZSS_POINT_READY_THRESHOLD = 5;
	V_AZSS_SPAWNS_READY_THRESHOLD = 4;

type
	tAdvancedZombieSpawnSystem = record
		Active, Enabled, SpawnsMessed, SpawnsModified: boolean;
		Observation, InProgress, Idle, Debug, HighProgress: boolean;
		PointNum, ReadySpawnsNum, ActiveSpawnsNum, ActivationTimer, ArrayNum: smallint;
		ReadySpawnsNum_THRESHOLD, PointReady_THRESHOLD: smallint;
		TmpPoint, ZombBasePoint: tStack8; // "pointers" to spawnpoints
		LastSpawnReview, UpperTimeLimit, ObservationEndTime, IdleTimer: longint;
		TmpBaseX, TmpBaseY, TmpBaseR, BaseX, BaseY, BaseR, Progression, ProgressionMeter, TmpZombHpFactor: single;
		Point: array [0..AZSS_MAXPOINTS] of record
			Active: boolean;
			AvgZombieTime, LastVisit: longint;
			ZombieNum: integer;
			x, y: single;
		end;
		PointArray: array of tArrPointer;
		ObservedZombie: array[1..AZSS_MAXOBSERVED] of record
			ID, StuckCD: byte;
			Point: array [0..AZSS_MAXPOINTS] of boolean;
			prevX, prevY: single;
		end;
	end;
	
var
	AZSS: tAdvancedZombieSpawnSystem;
	AliveSurvivors: tStack8;

procedure AZSS_Reset();

procedure AZSS_SetIdle(Time: longint);

procedure adbg_list(); // just temp, for debug

// time: approx time threshold in zombie way, on which spawn should be set
// pre: alive survivors quick list must be refreshed!
procedure AZSS_SetSpawn(time: longint);

// called short after zombie spawn
procedure AZSS_OnZombieResp(ID: byte);

// pre: should be called once/3s
procedure AZSS_Process();

procedure AZSS_Switch(on, hard: boolean);

// find base spawn points and decide what spawns could be used as temp spawn
// if the map is to messy, disable the AZSS
procedure AZSS_Init();

implementation

procedure RefreshAliveSurvList();
var i: byte;
begin
	stack8_clear(AliveSurvivors);
	for i := 1 to MaxID do
		if player[i].Status = 1 then
			stack8_push(AliveSurvivors, i);
end;

// sets default map spawnpoints
procedure AZSS_SetDefaultSpawns();
var i: smallint;
begin
	// turn default ones on
	for i := 0 to AZSS.ZombBasePoint.Length - 1 do
		Map.Spawns[AZSS.ZombBasePoint.arr[i]].Active := true;
	// turn temp ones off
	for i := 0 to AZSS.TmpPoint.Length - 1 do
		Map.Spawns[AZSS.TmpPoint.arr[i]].Active := false;
	AZSS.SpawnsModified := false;
end;

procedure AZSS_ResetObservedSlot(i: byte);
var j: smallint;
begin
	AZSS.ObservedZombie[i].ID := 0;
	AZSS.ObservedZombie[i].StuckCD := 0;
	for j := 1 to AZSS_MAXPOINTS do
		AZSS.ObservedZombie[i].Point[j] := false;
end;

procedure AZSS_Reset();
var i: smallint;
begin
	AZSS_SetDefaultSpawns();
	for i := 0 to AZSS_MAXPOINTS do begin
		AZSS.Point[i].Active := false;
		AZSS.Point[i].AvgZombieTime := 0;
		AZSS.Point[i].ZombieNum := 0;
		AZSS.Point[i].LastVisit := 0;
	end;
	AZSS.PointNum := 0;
	AZSS.Idle := false;
	AZSS.InProgress := false;
	AZSS.Observation := false;
	AZSS.IdleTimer := 0;
	AZSS.ActivationTimer := 0;
	AZSS.ReadySpawnsNum := 0;
	AZSS.UpperTimeLimit := 0;
	AZSS.ObservationEndTime := 0;
	AZSS.Progression := 0.0;
	AZSS.ProgressionMeter := 0.0;
	AZSS.SpawnsModified := false;
	AZSS.TmpZombHpFactor := 1.0;
	for i := 1 to AZSS_MAXOBSERVED do
		AZSS_ResetObservedSlot(i);
	if AZSS.SpawnsMessed then begin
		AZSS.SpawnsMessed := false;
		WriteTmpFlag('spawnsmodified', '0');
	end;
end;

procedure AZSS_DisableDefaultSpawns();
var i: smallint;
begin
	AZSS.SpawnsModified := true;
	for i := 0 to AZSS.ZombBasePoint.Length - 1 do
		SetSpawnStat(AZSS.ZombBasePoint.arr[i], 'ACTIVE', false);
	if not AZSS.SpawnsMessed then begin
		AZSS.SpawnsMessed := true;
		WriteTmpFlag('spawnsmodified', '1');
	end;
end;
// we don't observe all the ozmbies on the map (performance), just a few
// if somehting happens to one of our observed zombies, we can find a new one with this function
procedure AZSS_SelectZombie(slot: byte);
var i, j: byte;
begin
	for i := 1 to MaxID do
		if (Players[i].Alive) and (player[i].Status = 0) then begin
			if player[i].AZSS_DontObserve then continue;
			if player[i].RespawnTime = 0 then continue;
			if player[i].Boss then continue;
			for j := 1 to AZSS_MAXOBSERVED do
				if AZSS.ObservedZombie[j].ID = i then break;
			if j > AZSS_MAXOBSERVED then begin
				AZSS.ObservedZombie[slot].ID := i;
				exit;
			end;
		end;
	AZSS.ObservedZombie[slot].ID := 0;
end;

procedure AZSS_CreateSpawnList();
var i: smallint;
begin
	AZSS.ArrayNum := 0;
	//AZSS.PointArray[0].val := 0;
	//AZSS.PointArray[0].index := 0;
	for i := 1 to AZSS.PointNum do
		if AZSS.Point[i].Active then
			if (AZSS.Point[i].ZombieNum >= AZSS.PointReady_THRESHOLD) then begin
				AZSS.ArrayNum := AZSS.ArrayNum + 1;
				AZSS.PointArray[AZSS.ArrayNum].val := AZSS.Point[i].AvgZombieTime;
				AZSS.PointArray[AZSS.ArrayNum].index := i;
			end;
	// now we sort this array. some points are closer to original zombie base, some farther. we decide that looking at avergae zombie way time to that point
	if AZSS.ArrayNum >= 0 then begin // the num must be >= 0 anyway since this piece of code is processed, just to be sure...
		QuickSort(AZSS.PointArray, 1, AZSS.ArrayNum);
	end;
end;

procedure AZSS_SetProgression(on: boolean);
begin
	AZSS.ActivationTimer := 0;
	if on then begin
		AZSS.Idle := false;
		// we are building an array of "pointers" to points which are ready, and can be used as potential spawn positions
		AZSS_CreateSpawnList();
		if AZSS.Debug then WriteLn('<AZSS> Progression (' + inttostr(AZSS.ArrayNum) + ')');
	end else begin
		if AZSS.Debug then WriteLn('<AZSS> Progression off');
		if AZSS.SpawnsModified then
			AZSS_SetDefaultSpawns();
	end;
	AZSS.InProgress := on;
	AZSS.Progression := 0.0;
	AZSS.ProgressionMeter := 0.0;
end;

procedure AZSS_SetObservation(on: boolean);
var NoObservationTime: longint; i: smallint;
begin
	if on then begin
		AZSS.Idle := false;
		if AZSS.ObservationEndTime > 0 then
			NoObservationTime := Timer.Value - AZSS.ObservationEndTime;
		for i := 1 to AZSS.PointNum do // increment last visit time for all points by time they weren't observed
			AZSS.Point[i].LastVisit := AZSS.Point[i].LastVisit + 60*NoObservationTime;
		if AZSS.Debug then WriteLn('<AZSS> Observation on');
	end else begin
		if AZSS.Observation <> on then AZSS.ObservationEndTime := Timer.Value;
		if AZSS.Debug then WriteLn('<AZSS> Observation on');
	end;
	AZSS.Observation := on;
end;

procedure AZSS_SetIdle(Time: longint);
begin
	AZSS_SetObservation(false);
	AZSS_SetProgression(false);
	AZSS.IdleTimer := Time div 3 + 1;
	AZSS.Idle := true;
	if AZSS.Debug then WriteLn('<AZSS> Idle');
end;

// returns a number of potential spawn positions that are considered "ready"
procedure AZSS_GetReadySpawnsNum(visitsnum: integer);
var j: smallint;
begin
	AZSS.ReadySpawnsNum := 0;
	AZSS.ActiveSpawnsNum := 0;
	for j := 1 to AZSS.PointNum do
		if AZSS.Point[j].Active then begin
			if AZSS.Point[j].ZombieNum > visitsnum then
				AZSS.ReadySpawnsNum := AZSS.ReadySpawnsNum + 1;
			AZSS.ActiveSpawnsNum := AZSS.ActiveSpawnsNum + 1;
		end;
end;

// finds current player base (group of survivors) and it's radius
// pre: alive survivors quick list must be refreshed!
procedure AZSS_GetBase();
var i, index, mindistindex: smallint; x, y, d, sqdist, mindist: single; min, prev: longint;
begin
	AZSS.TmpBaseX := 0.0;
	AZSS.TmpBaseY := 0.0;
	for i := 0 to AliveSurvivors.length-1 do begin // get the middle point of player group (arithmetic mean)
		d := d + 1.0;
		GetPlayerXY(AliveSurvivors.arr[i], X, Y);
		AZSS.TmpBaseX := AZSS.TmpBaseX + X;
		AZSS.TmpBaseY := AZSS.TmpBaseY + Y;	
	end;
	AZSS.TmpBaseX := AZSS.TmpBaseX / d;
	AZSS.TmpBaseY := AZSS.TmpBaseY / d;
	AZSS.TmpBaseR := 0.0;
	// now the radius
	for i := 0 to AliveSurvivors.length-1 do begin
		GetPlayerXY(AliveSurvivors.arr[i], X, Y);
		d := Distance(X, Y, AZSS.TmpBaseX, AZSS.TmpBaseY);
		if d > AZSS.TmpBaseR then AZSS.TmpBaseR := d;
	end;
	
	// we need to decide how much time zombies need to get to the temporary surv base
	// later it will be used to eliminate potential spawnpoints more distant
	// we wouldn't like zombies to spawn behind surivors line
	if d < 400.0 then d := 400.0;
	d := d*d;
	min := 99999999;
	mindist := 99999999;
	index := 0;
	for i := 1 to AZSS.PointNum do
		if AZSS.Point[i].Active then
			if AZSS.Point[i].ZombieNum >= 10 then begin
				sqdist := SqrDist(AZSS.TmpBaseX, AZSS.TmpBaseY, AZSS.Point[i].x, AZSS.Point[i].y);
				if sqdist < mindist then begin
					mindist := sqdist;
					mindistindex := i;
				end;
				if sqdist < d then begin
					if AZSS.Point[i].AvgZombieTime < min then begin
						min := AZSS.Point[i].AvgZombieTime;
						index := i;
					end;
				end;
			end;
	prev := AZSS.UpperTimeLimit;
	if min < 99999999 then begin
		AZSS.UpperTimeLimit := AZSS.Point[index].AvgZombieTime;
		if AZSS.Debug then if prev <> AZSS.UpperTimeLimit then WriteLn('<AZSS> base time (in range): ' + IntToStr(t2s(AZSS.UpperTimeLimit)));
	end else begin
		AZSS.UpperTimeLimit := AZSS.Point[mindistindex].AvgZombieTime;
		if AZSS.Debug then if prev <> AZSS.UpperTimeLimit then WriteLn('<AZSS> base time (closest): ' + IntToStr(t2s(AZSS.UpperTimeLimit)));
	end;
end;

procedure AZSS_ActivateSpawn(ID: byte; index: smallint);
begin
	if index > 0 then begin
		Map.Spawns[ID].X := Round(AZSS.Point[index].X);
		Map.Spawns[ID].Y := Round(AZSS.Point[index].Y);
		Map.Spawns[ID].Active := true;
	end else
		if AZSS.SpawnsModified then
			AZSS_SetDefaultSpawns();
end;

procedure adbg_list(); // just temp, for debug
var i: smallint;
begin
	for i := 1 to AZSS.PointNum do
		if AZSS.Point[i].Active then
			WriteLn(inttostr(i) + '. n: ' + inttostr(AZSS.Point[i].ZombieNum) + ', t: ' + inttostr(t2s(AZSS.Point[i].AvgZombieTime)));
end;

// time: approx time threshold in zombie way, on which spawn should be set
// pre: alive survivors quick list must be refreshed!
procedure AZSS_SetSpawn(time: longint);
var h, l, j, i, k, n, last_ok, numback, numfront: smallint; front, diff: integer;
	x, y: single;
begin
	last_ok := -1;
	for h := 0 to AZSS.ArrayNum do begin // we start looping from the most distant points to zombie base
		// using array of "pointers" sorted by pointed value, we can loop through the chosen points in growing order
		j := AZSS.PointArray[h].index;
		if h < AZSS.ArrayNum then
			k := AZSS.PointArray[h+1].index // one forward
		else k := -1;
		if AZSS.Point[j].AvgZombieTime <= AZSS.UpperTimeLimit then begin // allow only points "before" the tmp surv base
			// find two points close to this time, one on the left, on on the right
			if (j=0) or (SqrDist(AZSS.TmpBaseX, AZSS.TmpBaseY, AZSS.Point[j].x, AZSS.Point[j].y) > AZSS.TmpBaseR*AZSS.TmpBaseR) then begin // point cannot be in range of surv tmp base
				for i := 0 to AliveSurvivors.length-1 do begin // (*1) look for close survivors 
					GetPlayerXY(AliveSurvivors.arr[i], x, y);
					if SqrDist(x, y, AZSS.Point[j].x, AZSS.Point[j].y) < 640000 then // 800^2
						break;
				end;
				if i >= AliveSurvivors.length then begin // there mustn't be any survivor close
					last_ok := j; // if we don't find two neighboring spawns, then at least save index of the last spawn that could be used (just in case) (*2)
					if k > -1 then begin
						if IsBetween(AZSS.Point[j].AvgZombieTime, time, AZSS.Point[k].AvgZombieTime) then begin
							// calculate spawns proportions on neighboring points
							//back := time - AZSS.Point[j].AvgZombieTime;
							front := AZSS.Point[k].AvgZombieTime - time;
							diff := AZSS.Point[k].AvgZombieTime - AZSS.Point[j].AvgZombieTime;
							numback := front * AZSS_TMP_SPAWN_NUM div diff;
							numfront := AZSS_TMP_SPAWN_NUM - numback;
							
							if numfront > 0 then begin // check if the front point is not close to survivors, for now only backpoint was checked (ad.1)
								for i := 0 to AliveSurvivors.length-1 do begin // look for close survivors
									GetPlayerXY(AliveSurvivors.arr[i], x, y);
									if SqrDist(x, y, AZSS.Point[k].x, AZSS.Point[k].y) < 640000 then begin// 800^2
										// oh no, survivor close, let's use only back points since they were already checked for survivor visiblity
										numfront := 0;
										numback := AZSS_TMP_SPAWN_NUM;
									end;
								end;
							end;
							// if back point is still in base area
							if j = 0 then begin // index 0 means base
								if AZSS.SpawnsModified then // activate default spawns points
									AZSS_SetDefaultSpawns();
							end else begin // if it's not base area anymore
								if not AZSS.SpawnsModified then // deactivate default spawns if active
									AZSS_DisableDefaultSpawns();
								for l := 1 to numback do begin // activate back spawns
									AZSS_ActivateSpawn(AZSS.TmpPoint.arr[n], j);
									n:=n+1;
								end;
							end;
							for l := 1 to numfront do begin // activate front spawns
								AZSS_ActivateSpawn(AZSS.TmpPoint.arr[n], k);
								n:=n+1;
							end;
							if AZSS.Debug then WriteLn('<AZSS> spawn - time: ' + IntToStr(t2s(time)) + '/' + IntToStr(t2s(AZSS.UpperTimeLimit)) + ', ' + IntToStr(numback) + 'x' + IntToStr(t2s(AZSS.Point[j].AvgZombieTime)) + ', ' + IntToStr(numfront) + 'x' + IntToStr(t2s(AZSS.Point[k].AvgZombieTime)));
							exit; // <- (*3)
						end;
					end;
				end;
			end;
		end else break; // if came out of allowed range
	end;
	
	if last_ok >= 0 then begin // since we reached this place (ad.3), no two neighboring spawnpoints were found. If there is a spawnpoint which could be used though (ad.2), set it.
		AZSS_ActivateSpawn(AZSS.TmpPoint.arr[0], last_ok);
		if AZSS.Debug then WriteLn('<AZSS> spawn - time: ' + IntToStr(t2s(time)) + '/' + IntToStr(t2s(AZSS.UpperTimeLimit)) + ', ' + IntToStr(t2s(AZSS.Point[last_ok].AvgZombieTime)));
		n := 1;
	end else begin // if completely no place to spawn available
		AZSS_SetObservation(true);
		AZSS_SetProgression(false);
		if AZSS.Debug then WriteLn('<AZSS> spawn - time: ' + IntToStr(t2s(time)) + ', none');
		exit; // <-
	end;
	
	for n := n to AZSS_TMP_SPAWN_NUM-1 do // if didnt find a position for some of the temp spawns, disable them
		SetSpawnStat(AZSS.TmpPoint.arr[n], 'ACTIVE', false);
end;

// "events"

// when a spawning process starts a new sub wave
procedure AZSS_OnSpawnWave(style: byte);
begin
	if AZSS.Active then begin
		case style of
			0, 1, 2, 4: AZSS_SetObservation(true);
			else AZSS_SetIdle(99999999);
		end;
	end;
end;

// called short after zombie spawn
procedure AZSS_OnZombieResp(ID: byte);
var x, y: single; i: byte;
begin
	player[ID].RespawnTime := Timer.Value;
	if AZSS.SpawnsModified then begin // if zombie have spawned on temporary spawn points, not default
		GetPlayerXY(ID, x, y);
		for i := 1 to AZSS.PointNum do // we check at what point it was spawned
			if AZSS.Point[i].Active then // ... and decrement time of it's respawn, by average zombie time on that point, so the zombie will look older and not mess average times on the next points with it's low, "new" time
				if (AZSS.Point[i].ZombieNum >= Azss.PointReady_THRESHOLD) then
					if SqrDist(x, y, AZSS.Point[i].x, AZSS.Point[i].y) < AZSS_SQR_POINT_R then begin
						player[ID].RespawnTime := player[ID].RespawnTime - AZSS.Point[i].AvgZombieTime;
						if AZSS.Debug then WriteLn('<AZSS> resp ' + IntToStr(t2s(AZSS.Point[i].AvgZombieTime)));
						break;
					end;
	end;
end;

// when the spawning process, shits all the zombies out
procedure AZSS_OnSpawnWaveEnd();
begin
	if AZSS.Active then begin
		AZSS.Progression := AZSS.Progression / 2;
		if AZSS.InProgress then
		begin				
			if Spawn.Active then begin
				AZSS_GetBase();
				AZSS_SetSpawn(Round(AZSS.Progression*AZSS.UpperTimeLimit));
			end;
		end;
	end;
end;

// pre: should be called once/3s
procedure AZSS_Process();
var h, i, j, k: smallint; p: single;
	x, y, x2, y2: single;
	observed: byte;
	RefreshSpawnList: boolean;
	t: longint;
begin
	if AZSS.Idle then begin
		if AZSS.IdleTimer <= 1 then AZSS.Idle := false else
			AZSS.IdleTimer := AZSS.IdleTimer - 1;
		AZSS.TmpZombHpFactor := (1.0 + AZSS.TmpZombHpFactor) / 2.0; // tend to 1
	end else begin
		RefreshAliveSurvList(); // we will use a quick list of alive survivors in functions below, perfomance reasons
		
		// in this state, bots are being observed, potential spawn points are found
		if AZSS.Observation then begin
			for h := 1 to AZSS_MAXOBSERVED do begin
				i := AZSS.ObservedZombie[h].ID;
				if i = 0 then continue;
				observed := observed + 1;
				if Players[i].Alive then begin
					if player[i].Status = 0 then begin // bot zombie
						if player[i].RespawnTime = 0 then continue; // if respaned, but his position hasn't been updated yet (just in case)
						GetPlayerXY(i, x, y);
						if SqrDist(x, y, AZSS.ObservedZombie[h].prevX, AZSS.ObservedZombie[h].prevY) < 10000 then begin // we check is zombie didn't get stuck
							AZSS.ObservedZombie[h].StuckCD := AZSS.ObservedZombie[h].StuckCD + 1;
							if AZSS.ObservedZombie[h].StuckCD >= 3 then begin
								player[i].AZSS_DontObserve := true;
								AZSS_ResetObservedSlot(h);
								if AZSS.Debug then WriteLn('<AZSS> zombie ' + inttostr(i) + ' ignored (stuck)');
								continue;
							end;
						end else begin
							AZSS.ObservedZombie[h].prevX := x;
							AZSS.ObservedZombie[h].prevY := y;
							AZSS.ObservedZombie[h].StuckCD := 0;
						end;
						if SqrDist(x, y, AZSS.BaseX, AZSS.BaseY) > AZSS.BaseR*AZSS.BaseR then begin // don't try to create points in base area
							for j := 0 to AliveSurvivors.length-1 do // if zombie hasn't seen anyone
								if SqrDist(x, y, x2, y2) < 360000 then// 600 ^ 2
									if RayCast(x, y-12.0, x2, y2-12.0, false, false, false) then begin
										player[i].AZSS_DontObserve := true;
										AZSS_ResetObservedSlot(h);
										break;
									end;
							if j >= AliveSurvivors.length then begin
								k := -1;	
								for j := 1 to AZSS.PointNum do
									if AZSS.Point[j].Active then begin
										if not AZSS.ObservedZombie[h].Point[j] then
											if SqrDist(x, y, AZSS.Point[j].x, AZSS.Point[j].y) < AZSS_SQR_POINT_R then begin
												t := Timer.Value-player[i].RespawnTime;
												AZSS.ObservedZombie[h].Point[j] := true;	
												if (t div 2 >= AZSS.Point[j].AvgZombieTime) then
													if (AZSS.Point[j].AvgZombieTime > 600) and (AZSS.Point[j].ZombieNum >= 10) then
														break; // <- if the zombie time is much higher (twice) than average time at this point, skip it
												// almost-arithmetic mean, older values become less significant in time	
												p := Math.Pow(AZSS.Point[j].ZombieNum, 0.8);
												// Timer.Value-player[i].RespawnTime represents time, in which zombie reached this point
												AZSS.Point[j].AvgZombieTime := Trunc((p*AZSS.Point[j].AvgZombieTime + t) / (p + 1.0));
												AZSS.Point[j].ZombieNum := AZSS.Point[j].ZombieNum + 1;
												if AZSS.Debug then 
													if (AZSS.Point[j].ZombieNum >= AZSS.PointReady_THRESHOLD) then 
														WriteLn('<AZSS> point ready ' + inttostr(j) + '-> zn: '+ inttostr(AZSS.Point[j].ZombieNum) + ', t: ' + IntToStr(t2s(AZSS.Point[j].AvgZombieTime)));
												AZSS.Point[j].LastVisit := Timer.Value;
												RefreshSpawnList := true;
												break;
											end;
									end else
										if k = -1 then k := j; // if we don't find anything, we will be able to use this slot
								if j > AZSS.PointNum then begin // if no point in range of zombie found
									if k >= 0 then j := k;
									if j <= AZSS_MAXPOINTS then begin // create a new one
										if PointNotInPoly(x, y-10.0, true, false, false) then
											if Players_OnGround(i, true, 40) <> 0 then begin
												if j > AZSS.PointNum then AZSS.PointNum := j;	
												if AZSS.Debug then WriteLn('<AZSS> new ' + inttostr(j) + '/' + inttostr(AZSS.PointNum));
												AZSS.Point[j].Active := true;
												AZSS.Point[j].AvgZombieTime := Timer.Value-player[i].RespawnTime;
												AZSS.Point[j].LastVisit := Timer.Value;
												AZSS.Point[j].ZombieNum := 1;
												AZSS.Point[j].x := x;
												AZSS.Point[j].y := y;
											end;
									end;
								end;
							end;
						end;
					end else AZSS_ResetObservedSlot(h);
				end else AZSS_ResetObservedSlot(h);
			end; // <-/player loop
			if (observed < AZSS_MAXOBSERVED) and (observed < AliveZombiesInGame) then
				for h := 1 to AZSS_MAXOBSERVED do
					if AZSS.ObservedZombie[h].ID = 0 then AZSS_SelectZombie(h);
				
			if Timer.Value >= AZSS.LastSpawnReview + 7200 then begin // from time to time (each 2 mins), clear loop though all points, and if some seem unused anymore (for 5 mins), get rid of them
				for j := 1 to AZSS.PointNum do
					if AZSS.Point[j].Active then begin
						if Timer.Value > AZSS.Point[j].LastVisit + 18000 then begin
							AZSS.Point[j].Active := false;
							if AZSS.Debug then WriteLn('<AZSS> del ' + inttostr(j));
						end;
					end;
				AZSS.LastSpawnReview := Timer.Value;
			end;
			//AZSS_GetReadySpawnsNum();
			//if AZSS.ActiveSpawnsNum >= AZSS_MAXPOINTS then begin
			//	AZSS_SetObservation(false);
			//end;
		//end else begin // if observation is currently off
		end;
			
		// progressive spawn controller
		if AZSS.InProgress then begin
			if SurvPwnMeter >= 0.8 then begin
				if AZSS.ActivationTimer < 3 then begin
					AZSS.ActivationTimer := AZSS.ActivationTimer + 1;
				end else begin
					AZSS_SetIdle(10 + Trunc(SurvPwnMeter*60.0));
					exit;
				end;
			end else if AZSS.ActivationTimer > 0 then begin
				AZSS.ActivationTimer := AZSS.ActivationTimer - 1;
			end;
			
			if Spawn.Active then
				// increment progression factor
				if AZSS.HighProgress then
					AZSS.Progression := AZSS.Progression + (0.012 + 0.001 * NumberOfWave - SurvPwnMeter / 100.0) * (AZSS_PROGRESSION_FACTOR + AZSS_PROGRESSION_FACTOR_PER * AliveSurvivors.length)
				else
					AZSS.Progression := AZSS.Progression + (0.012 + 0.001 * NumberOfWave - SurvPwnMeter / 100.0);
				
				// decrement if survivors are being damaged
			
			if SurvPwnMeter > AvgSurvPwnMeter then
				AZSS.Progression := AZSS.Progression - AZSS_REGRESSION_FACTOR*(SurvPwnMeter-AvgSurvPwnMeter);
			// make sure value is in range 0...1
			if AZSS.Progression < 0.0 then AZSS.Progression := 0.0 else
			if AZSS.Progression > 1.0 then AZSS.Progression := 1.0;
			
			if (AZSS.Observation) and (RefreshSpawnList) then
				AZSS_CreateSpawnList();
			
			if Spawn.Active then begin
				AZSS_GetBase();
				AZSS_SetSpawn(Round(AZSS.Progression*AZSS.UpperTimeLimit));
			end;
				
			// calculate progresssion meter now
			if AZSS.Progression >= AZSS.ProgressionMeter then begin
				// tending to current progression
				AZSS.ProgressionMeter := (AZSS.ProgressionMeter + AZSS.Progression) / 2.0;
			end else begin
				x := ZombiesLeft; // i wrote it this way to be sure about valid int-float conversion, so division result is ok
				x := x / MAX_ZOMBIES;
				if x > 0.9 then x := 0.9 else
				if x < 0.3 then x := 0.3;
				// tending to current progression, but with weigthed rate by zombies num in game
				AZSS.ProgressionMeter := AZSS.ProgressionMeter*x + AZSS.Progression*(1.0-x);
			end;
			
			// the point of AZSS is not to increase difficulty significantly, just to make the game more dynamic
			// if survivors are being flooded with zombies because of AZSS progression, weaken the zombies a bit
			AZSS.TmpZombHpFactor := 1.0-Sqr(AZSS.ProgressionMeter * SurvPwnMeter) - AvgSurvPwnMeter / 3.0 - AZSS.ProgressionMeter*AZSS.ProgressionMeter / 6.0;
			if AZSS.TmpZombHpFactor < 0.3 then AZSS.TmpZombHpFactor := 0.3;
			
			if AZSS.Debug then WriteLn('<AZSS> SPM: ' + IntToStr(Round(SurvPwnMeter*100.0)) + '%, ASPM: ' + IntToStr(Round(AvgSurvPwnMeter*100.0)) + '%, PROGRESS: ' + IntToStr(Round(AZSS.Progression*100.0)) + '(' + IntToStr(Round(AZSS.ProgressionMeter*100.0)) + ')%, ZHPF: ' + IntToStr(Round(AZSS.TmpZombHpFactor*100.0)) + '%');
		
		end else begin
			if SurvPwnMeter < 0.01 then begin // leaning towards activation
				if AZSS.ActivationTimer < 10 then begin // need 15 secs to fully activate
					AZSS.ActivationTimer := AZSS.ActivationTimer + 2;
				end else begin
					AZSS_GetReadySpawnsNum(AZSS_POINT_READY_THRESHOLD);
					if (AZSS.ReadySpawnsNum >= AZSS.ReadySpawnsNum_THRESHOLD) then				
						AZSS_SetProgression(true);
				end;
			end	else // leaning towards deactivation
				if AZSS.ActivationTimer > 0 then AZSS.ActivationTimer := AZSS.ActivationTimer - 1;
			AZSS.TmpZombHpFactor := (1.0 + AZSS.TmpZombHpFactor) / 2.0;
		end;
	end;
end;

procedure AZSS_Switch(on, hard: boolean);
begin
	if not AZSS.Enabled then begin
		AZSS.Active := false;
		exit;
	end;
	AZSS.Active := on;
	AZSS.TmpZombHpFactor := 1.0;
	if hard then
	begin
		AZSS.PointReady_THRESHOLD := V_AZSS_POINT_READY_THRESHOLD;
		AZSS.ReadySpawnsNum_THRESHOLD := V_AZSS_SPAWNS_READY_THRESHOLD;
		AZSS.HighProgress := True;
	end else begin
		AZSS.PointReady_THRESHOLD := AZSS_POINT_READY_THRESHOLD;
		AZSS.ReadySpawnsNum_THRESHOLD := AZSS_SPAWNS_READY_THRESHOLD;
		AZSS.HighProgress := False;
	end;
	WriteDebug(6, 'Advanced Zombie Spawn System ' + iif(on, 'enabled', 'disabled'));
	if on then begin
		AZSS_SetIdle(10);
	end else
		AZSS_Reset();
end;

// find base spawn points and decide what spawns could be used as temp spawn
// if the map is to messy, disable the AZSS
procedure AZSS_Init();
var i, n: smallint; d: single;
begin
	WriteDebug(8, 'AZSS_Init()');
	AZSS.Enabled := false;
	stack8_clear(AZSS.ZombBasePoint);
	stack8_alloc(AZSS.ZombBasePoint, 10);
	stack8_clear(AZSS.TmpPoint);
	stack8_alloc(AZSS.TmpPoint, AZSS_TMP_SPAWN_NUM);
	SetLength(AZSS.PointArray, AZSS_MAXPOINTS+1);
	AZSS.PointArray[0].val := 0;
	AZSS.PointArray[0].index := 0;
	// calculate the middle of surivors base, and it's radius (more or less)
	AZSS.BaseX := 0.0;
	AZSS.BaseY := 0.0;
	for i:=1 to MAX_SPAWNS do
		if (Map.Spawns[i].style = HUMANTEAM) or (Map.Spawns[i].style = HUMANTEAM + 4) then begin
			d := d + 1.0;
			AZSS.BaseX := AZSS.BaseX + Map.Spawns[i].x;
			AZSS.BaseY := AZSS.BaseY + Map.Spawns[i].y;
		end else // and since we are looping through spawns already, let's save zombies spawns' ids
			// it will be easier to turn them on/off later
			if Map.Spawns[i].style = ZOMBIETEAM then
				stack8_push(AZSS.ZombBasePoint, i);

	AZSS.BaseX := AZSS.BaseX / d;
	AZSS.BaseY := AZSS.BaseY / d;
	AZSS.BaseR := 0.0;
	for i:=1 to MAX_SPAWNS do
		if (Map.Spawns[i].style = HUMANTEAM) or (Map.Spawns[i].style = HUMANTEAM + 4) then begin
			d := Distance(Map.Spawns[i].x, Map.Spawns[i].y, AZSS.BaseX, AZSS.BaseY);
			if d > AZSS.BaseR then AZSS.BaseR := d;
		end;
	if AZSS.Debug then WriteLn('<AZSS> Base: R = ' + IntToStr(Trunc(AZSS.BaseR)) + ', X = ' + IntToStr(Trunc(AZSS.BaseX)) + ', Y = ' + IntToStr(Trunc(AZSS.BaseY)));
		
	// we got that stuff loaded now, let's check if the bravo base isn't mixed with alpha base
	// some maps are built this way, our system would get confused there a bit, so we just disable it.
	for i:=1 to MAX_SPAWNS do
		if Map.Spawns[i].style = ZOMBIETEAM then begin
			if SqrDist(Map.Spawns[i].x, Map.Spawns[i].y, AZSS.BaseX, AZSS.BaseY) < AZSS.BaseR * AZSS.BaseR then begin
				WriteDebug(8, 'AZSS_Init(): Cannot set the system for this map, spawn structure is too complicated');
				exit;
			end;
		end;
		
	// find some unused spawns, we will use them as temporary spawns for zombies
	for i:=MAX_SPAWNS downto 1 do
		if Map.Spawns[i].Active = false then begin
			stack8_push(AZSS.TmpPoint, i);
			Map.Spawns[i].Style := ZOMBIETEAM;
			if n >= 2 then break;
			n := n + 1;
		end;
	
	if n <= 1 then begin
		stack8_push(AZSS.TmpPoint, 222);
		stack8_push(AZSS.TmpPoint, 223);
	end;
	AZSS.Enabled := true;
end;

begin
end.
