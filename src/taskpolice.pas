unit TaskPolice;

interface

uses
{$ifdef FPC}
	Scriptcore,
{$endif}
	BaseWeapons,
	BigText,
	Constants,
	Charges,
	Debug,
	Damage,
	GameModes,
  Globals,
	Objects,
	LSPlayers,
  Misc,
	PlacePlayer,
	Raycasts,
	Statguns,
	Strikes,
	Tasks,
	Weapons,
	WeaponMenu;

procedure TaskPolice_OnWeaponChange(PrimaryNum, SecondaryNum: byte);

procedure TaskPolice_Process(MainCall: boolean);

procedure TaskPolice_OnNextWave();

procedure TaskPolice_Reset();

procedure TaskPolice_OnCommand(Text: string);

procedure TaskPolice_OnBuyCommand(Text: string);

procedure TaskPolice_ShowTeamEquipment(ID: byte);

implementation

var SPTime: integer;

//TryBuyWeap must be called with the WeaponMenu-ID
function TaskPolice_TryBuyWeapon(x: byte; Amount: smallint; CheckPriceOnly: boolean): smallint;
var cost: smallint;
begin
	Result := -1;
	if not Weapon[x].Buyable then exit;
	cost := Weapon[x].Cost;
	if CheckPriceOnly then begin
		Result := Trunc(Cop.SupplyPoints) div cost;
		exit;
	end;
	if Cop.SupplyPoints >= cost then begin
		if Cop.SupplyPoints >= cost * Amount then begin
			Result := Amount;
		end else begin
			Result := Trunc(Cop.SupplyPoints) div cost;
		end;

		if (WeaponSystem.Enabled) {and (Base.Found)} and (x <> 10) then begin
			BaseWeapons_Add(x, Result, 0);
		end else begin
			Objects_SpawnX(Cop.ID, menu2obj(x), Result);
		end;
		Cop.SupplyPoints := Cop.SupplyPoints - cost * Result;
	end else
		Result := 0;
end;

//  * ------------- *
//  |  Weapon Shop  |
//  * ------------- *

procedure TaskPolice_Shop_Switch(state: boolean);
begin
	if (state) then begin
		if player[Cop.ID].Status = 1 then begin
			if (not player[Cop.ID].JustResp) and (not WeaponMenu_IsGettingWeapon(Cop.ID)) then begin
				if Players_OnGround(Cop.ID, true, 20) > 0 then begin
					Players[Cop.ID].WriteConsole( 'Welcome to the Weapon Shop, "/shop" to exit', NWSCOL);
					Cop.Shop.Pri := Players[Cop.ID].Primary.WType;
					Cop.Shop.Sec := Players[Cop.ID].Secondary.WType;
					Cop.Shop.Vest := Players[Cop.ID].Vest;
					Cop.Shop.HP := Players[Cop.ID].HEALTH;
					Cop.Shop.Nades := Players[Cop.ID].GRENADES;
					Cop.Shop.Ammo := Players[Cop.ID].Primary.Ammo;
					Cop.Shop.SecAmmo := Players[Cop.ID].Secondary.Ammo;
					if (Cop.Shop.Pri <> WTYPE_NOWEAPON) or (Cop.Shop.Sec <> WTYPE_NOWEAPON) then
						Weapons_Force(Cop.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
					GetPlayerXY(Cop.ID, Cop.Shop.X, Cop.Shop.Y);
					Cop.Shop.Timer := 5;
					Cop.Shop.Active := true;
					Cop.Shop.Status := 4;
				end else
					Players[Cop.ID].WriteConsole( 'You must be standing on the ground', RED);
			end else
				Players[Cop.ID].WriteConsole( 'Can''t open the shop now, you haven''t selected your weapons yet', RED);
		end else
			Players[Cop.ID].WriteConsole( 'You must be alive to open the shop interface', RED);
	end else begin
		Players[Cop.ID].WriteConsole( 'Quitting shop, click anything to exit', NWSCOL);
		Cop.Shop.Status := 0;
	end;
end;

procedure TaskPolice_Shop_Exit();
begin
	Cop.Shop.Active := false;
	Cop.Shop.Status := 0;
	Cop.Shop.Timer := 0;
	Damage_SetHealth(Cop.ID, Cop.Shop.HP, Cop.Shop.Vest);
	Weapons_Force(Cop.ID, Cop.Shop.Pri, Cop.Shop.Sec, Cop.Shop.Ammo, Cop.Shop.SecAmmo);
	Cop.Shop.Pri := 0;
	Cop.Shop.Sec := 0;
	Cop.Shop.Vest := 0;
	Cop.Shop.HP := 0;
	Cop.Shop.Nades := 0;
	Players[Cop.ID].WriteConsole( 'Weapon Shop closed, supply points left: ' + FormatFloat('0.0', Cop.SupplyPoints), NWSCOL);
	BigText_DrawScreenX(DTL_WEAPONLIST, Cop.ID, 'Weapon Shop closed', 150, NWSCOL, 0.07, 250, 80);
end;

function TaskPolice_Shop_WeapSelect(x: byte): boolean;
var n: smallint; str: string; i, y: byte;
begin
	if x = WTYPE_NOWEAPON then exit;
	if (x = WTYPE_USSOCOM) or (Cop.Shop.Status = 0) then begin
		TaskPolice_Shop_Switch(false);
	end else begin
		y := weap2menu(x);
		n := TaskPolice_TryBuyWeapon(y, 1, false);
		if n > 0 then begin
			if (Weapon[y].Used) and (Players_ParticipantNum(1) > 1) then begin
				for i := 1 to MaxID do
					if player[i].Participant = 1 then
					if player[i].ActiveWeapons[y] then begin
						if str <> '' then str := str + ', ';
						str := str + TaskToName(player[i].Task, false);
					end;
			end else
				str := 'your team';
			Players[Cop.ID].WriteConsole( WeaponName(x) + ' purchased for ' + str, NWSCOL);
			Result := true;
			Cop.Shop.JustBought := y;
		end else
		if n = 0 then begin
			Players[Cop.ID].WriteConsole( 'Insufficient funds to buy ' + WeaponName(x), NWSCOL);
		end;
		Cop.Shop.Status := 4;
		Weapons_Force(Cop.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
	end;
end;

procedure TaskPolice_Shop_RefreshMenu(stage: byte);
var i: byte;
begin
	if (stage <> 0) then begin
		for i := 1 to 14 do begin
			if i <> 11 then
			if i <> 10 then
			if TaskPolice_TryBuyWeapon(i, 1, true) > 0 then begin
				WeaponMenu_SwitchWeapon(Cop.ID, i, true);
			end;
		end;
		WeaponMenu_SwitchWeapon(Cop.ID, 11, true);
	end;
	if (stage <> 1) then begin
		for i := 1 to 14 do begin
			if i <> 11 then
			if i <> 10 then
			if TaskPolice_TryBuyWeapon(i, 1, true) <= 0 then begin
				WeaponMenu_SwitchWeapon(Cop.ID, i, false);
			end;
		end;
		WeaponMenu_SwitchWeapon(Cop.ID, 10, false);
	end;
end;

procedure TaskPolice_Shop_Process(MainCall: boolean); // 1, 2hz compatibile
var i: byte; X, Y: single; str, str2: string;
begin
	if Cop.Shop.Active then begin
		if Cop.ID > 0 then begin
			if player[Cop.ID].Status = 1 then begin

				GetPlayerXY(Cop.ID, X, Y);
				if Cop.Shop.Status > 0 then
					for i := 1 to MaxID do // close the shop if zombie is around
						if Players[i].Active then
							if player[i].Zombie then begin
								if IsInRange(i, X, Y, 80, false) then begin
									BigText_DrawScreenX(DTL_WEAPONLIST, Cop.ID, 'Zombies!' + br + 'Click anything to exit', 150, $FF2222, 0.07, 250, 80);
									TaskPolice_Shop_Switch(false);
									exit;
								end;
							end;
				if not PointsInRange(X, Y, Cop.Shop.X, Cop.Shop.Y, 20, false) then begin
					TaskPolice_Shop_Exit();
				end;
				if MainCall then str := str + IntToStr(Trunc(Cop.SupplyPoints)) + ' supply points left' + br;
				case Cop.Shop.Status of
					1: if Cop.Shop.Timer > 0 then begin
							if MainCall then begin
								Cop.Shop.Timer := Cop.Shop.Timer - 1;
								if Cop.Shop.Timer <= 5 then begin
									str := str + 'Closing in ' + IntToStr(Cop.Shop.Timer) + br + br;
								end else
									str := str + br + br;
							end;
							if not
								TaskPolice_Shop_WeapSelect(Players[Cop.ID].Primary.WType)
							then
								TaskPolice_Shop_WeapSelect(Players[Cop.ID].Secondary.WType);
						end else begin
							TaskPolice_Shop_Switch(false);
						end;
					2: begin
						Cop.Shop.Status := 3;
						str := str + br + br;
						if not
							TaskPolice_Shop_WeapSelect(Players[Cop.ID].Primary.WType)
						then
							TaskPolice_Shop_WeapSelect(Players[Cop.ID].Secondary.WType);
						TaskPolice_Shop_RefreshMenu(1);
					end;
					3: begin
						Cop.Shop.Status := 1;
						Cop.Shop.Timer := 8;
						str := str + br + br;
						if not
							TaskPolice_Shop_WeapSelect(Players[Cop.ID].Primary.WType)
						then
							TaskPolice_Shop_WeapSelect(Players[Cop.ID].Secondary.WType);
						TaskPolice_Shop_RefreshMenu(0);
					end;
					4: begin
						Weapons_Force(Cop.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
						PutPlayer(Cop.ID, HUMANTEAM, X, Y, false);
						Weapons_Force(Cop.ID, WTYPE_NOWEAPON, WTYPE_NOWEAPON, 0, 0);
						str := str + br + br;
						player[Cop.ID].JustResp := false;
						player[Cop.ID].GetX := false;
						Cop.Shop.X := X;
						Cop.Shop.Y := Y;
						Cop.Shop.Status := 2;
					end;
					0: if MainCall then
						BigText_DrawScreenX(DTL_WEAPONLIST, Cop.ID,
            	'Quitting shop' + Dots((Timer.Value div 60) mod 4) + br + 'Click anything to exit',
            	120, NWSCOL, 0.08, 250, 80);
				end;
				if MainCall then if Cop.Shop.Status > 0 then begin
					str := str + 'Weapons in base:' + br;
					for i := 1 to 14 do
						if i <> 11 then
						if i <> 12 then
							if (Weapon[i].Used) or (Weapon[i].Num > 0) then begin
								if (player[Cop.ID].ActiveWeapons[i]) or (not Weapon[i].Used) then begin
									if Cop.Shop.JustBought = i then begin
										str := str + ' +  ';
										Cop.Shop.JustBought := 0;
									end else
										str := str + ' ' + IntToStr(Weapon[i].Num) + 'x ';
									str := str + WeaponName(menu2weap(i)) + br;
								end else begin
									if Cop.Shop.JustBought = i then begin
										str2 := str2 + ' +  ';
										Cop.Shop.JustBought := 0;
									end else
										str2 := str2 + ' ' + IntToStr(Weapon[i].Num) + 'x ';
									str2 := str2 + WeaponName(menu2weap(i)) + br;
								end;
							end;
					str := str + br;
					if str2 <> '' then str := str + 'Task specific:' + br + str2 + br;
					str := str + br + 'Type /shop or click USSOCOM to exit';
					BigText_DrawScreenX(DTL_WEAPONLIST, Cop.ID, str, 150, NWSCOL, 0.06, 250, 80);
				end;
			end;
		end;
	end;
end;

procedure TaskPolice_WriteSupplyInfo();
begin
	Players[Cop.ID].WriteConsole(' /mark       - To place a marker for an airstrike', GREEN);
	Players[Cop.ID].WriteConsole(' /strike     - To bomb the marked area: ' + IntToStr(STRIKECOST), GREEN);
	Players[Cop.ID].WriteConsole(' /heli       - To call a helicopter strike: ' + IntToStr(HELICOST), GREEN);
	Players[Cop.ID].WriteConsole(' /buy <item> - To buy the selected item', GREEN);
	Players[Cop.ID].WriteConsole('   "vest"   - Bulletproof vest (' + IntToStr(VESTCOST) + ' sp),    "nade" - Grenades (' + IntToStr(NADECOST) + ' sp)', GREEN);
	Players[Cop.ID].WriteConsole('   "medi"   - Medical kit ('  + IntToStr(MEDICOST) +  ' sp),         "clus" - Cluster nades (' + IntToStr(CLUSTERCOST) + ' sp)', GREEN);
	if mechanic > 0 then begin
	Players[Cop.ID].WriteConsole('   "wire"   - Barbed wire ( '  + IntToStr(WIRECOST) + ' sp),         "sg"   - Stationary gun for the mechanic (' + IntToStr(STATCOST) + ' sp)', GREEN);
	Players[Cop.ID].WriteConsole('   "sentry" - Sentry gun (' + IntToStr(SENTRYCOST) + ' sp),          "ammo" - Sentry gun ammo for the mechanic (' + IntToStr(SENTRYAMMOCOST) + ' sp)', GREEN);
	end;
	if DemoMan.ID > 0 then
	Players[Cop.ID].WriteConsole('   "mines"  - Mines pack ['   + IntToStr(MINEPACK) + '] ('   + IntToStr(MINECOST) + ' sp),        "char" -  Charges for the demolition man ( ' + IntToStr(CHARGECOST) + ' sp)', GREEN);
	if priest > 0 then
	Players[Cop.ID].WriteConsole('   "water"  - Holy Water for the priest ( ' + IntToStr(WATERCOST) + ' sp)', GREEN);
	if sharpshooter > 0 then
	Players[Cop.ID].WriteConsole('   "molo"   -  Molotovs pack for the sharpshooter (' + IntToStr(MOLOTOVCOST) + ' sp)', GREEN);
	if Players_IDByTask(4) > 0 then
		Players[Cop.ID].WriteConsole('   "scare"  - Scarecrow for the farmer (' + IntToStr(SCARECROWCOST) + ' sp)', GREEN);
	Players[Cop.ID].WriteConsole(' /weaps      - Shows a list with costs of buyable weapons', GREEN);
end;

procedure TaskPolice_WriteWeaponInfo();
begin
  Players[Cop.ID].WriteConsole('You can buy weapons for your team:', WHITE);
  if WeaponSystem.Enabled then begin
  	Players[Cop.ID].WriteConsole('Type /buy <weapon name> [number] to buy weapon(s), partial name matches', WHITE);
  	Players[Cop.ID].WriteConsole('  MP5:     ' + IntToStr(Weapon[2].Cost)  +  ' sp      AK-74:    '  + IntToStr(Weapon[3].Cost) + ' sp', INFORMATION);
  	Players[Cop.ID].WriteConsole('  Steyr:   ' + IntToStr(Weapon[4].Cost)  +  ' sp      Minimi:   ' + IntToStr(Weapon[9].Cost) +  ' sp', INFORMATION);
  	Players[Cop.ID].WriteConsole('  Deagles: ' + IntToStr(Weapon[1].Cost)  +  ' sp      Ruger:    ' + IntToStr(Weapon[6].Cost) +  ' sp', INFORMATION);
  	Players[Cop.ID].WriteConsole('  Spas:    ' + IntToStr(Weapon[5].Cost)  +  ' sp      M79:      ' + IntToStr(Weapon[7].Cost) +  ' sp', INFORMATION);
  	Players[Cop.ID].WriteConsole('  Flak:    ' + IntToStr(Weapon[10].Cost) + ' sp', INFORMATION);
  	Players[Cop.ID].WriteConsole('  Law:     ' + IntToStr(Weapon[14].Cost), INFORMATION);
  	Players[Cop.ID].WriteConsole('Type /shop to activate your weapon shop interface', WHITE);
  end else begin
  	Players[Cop.ID].WriteConsole('Type /buy <weapon name> to buy a weapon, partial name matches', WHITE);
  	Players[Cop.ID].WriteConsole('  MP5:    ' + IntToStr(Weapon[2].Cost)  + ' sp      AK-74:  ' + IntToStr(Weapon[3].Cost)  + ' sp', INFORMATION);
  	Players[Cop.ID].WriteConsole('  Steyr:  ' + IntToStr(Weapon[4].Cost)  + ' sp      Minimi: ' + IntToStr(Weapon[9].Cost)  + ' sp', INFORMATION);
  	Players[Cop.ID].WriteConsole('  Spas:   ' + IntToStr(Weapon[5].Cost)  + ' sp      M79:    ' + IntToStr(Weapon[7].Cost)  + ' sp', INFORMATION);
  	Players[Cop.ID].WriteConsole('  Law:    ' + IntToStr(Weapon[14].Cost) + ' sp      Flak:   ' + IntToStr(Weapon[10].Cost) + ' sp', INFORMATION);
  end;
end;

procedure TaskPolice_Process(MainCall: boolean);
begin
  if MainCall then begin
    if Cop.ID > 0 then
		if player[Cop.ID].Status = 1 then
		if ZombieFightTime + 1800 >= Timer.Value then begin // don't let them keep last ozmbies alive to get sp
			if (Timer.Value div 60) mod SPTime = 1 then begin
				Cop.SupplyPoints := Cop.SupplyPoints + 1.0;
				Players[Cop.ID].WriteConsole( 'Supply points: ' + IntToStr(Trunc(Cop.SupplyPoints)), ORANGE);
				if Trunc(Cop.SupplyPoints) mod 5 = 0 then
					Players[Cop.ID].WriteConsole( 'Type /supply for a list of supplies you can order', ORANGE);
				if Cop.Shop.Active then
					if Cop.Shop.Status > 0 then
						if Cop.Shop.Status <> 4 then
							Cop.Shop.Status := 2;
			end;
		end;
  end;

  TaskPolice_Shop_Process(MainCall);
end;

procedure TaskPolice_OnNextWave();
begin
  SPTime := Trunc((SUPPLYTIME + Round(SUPPLYTIME2 / Players_HumanNum)) * Mode[Modes.RealCurrentMode].SPTimeFactor);
end;

// When cop changes his weapon
procedure TaskPolice_OnWeaponChange(PrimaryNum, SecondaryNum: byte);
begin
	if Cop.Shop.Active then begin
		if (Cop.Shop.Status = 1) or (Cop.Shop.Status = 4) then
		if PrimaryNum <> WTYPE_NOWEAPON then
		if SecondaryNum <> WTYPE_NOWEAPON then begin
			Cop.Shop.Status := 4;
		end;
	end;
end;

procedure TaskPolice_ShowTeamEquipment(ID: byte);
var i: integer;
begin
  if mechanic > 0 then begin
		WriteMessage(ID, 'Mechanic:', ORANGE);
		WriteMessage(ID, 'Statguns:   ' + IntToStr(player[mechanic].statguns), GREEN);
		WriteMessage(ID, 'Sentrys:    ' + IntToStr(player[mechanic].sentrys), GREEN);
		WriteMessage(ID, 'Ammo belts: ' + IntToStr(player[mechanic].SentryAmmo), GREEN);
		WriteMessage(ID, 'Wires:      ' + IntToStr(player[mechanic].Wires), GREEN);
		WriteMessage(ID, 'Meals:      ' + IntToStr(player[mechanic].mre), GREEN);
	end;
	if DemoMan.ID > 0 then begin
		WriteMessage(ID, 'Demolition expert:', ORANGE);
		WriteMessage(ID, 'Mines:      ' + IntToStr(player[DemoMan.ID].Mines), GREEN);
		WriteMessage(ID, 'Charges:    ' + IntToStr(player[DemoMan.ID].charges), GREEN);
	end;
	if Players_IDByTask(4) > 0 then begin
		WriteMessage(ID, 'Farmer(s):', ORANGE);
		for i := 1 to MaxID do
			if Players[i].Active then
			if player[i].task = 4 then begin
				WriteMessage(ID, Players[i].Name+': ', GREEN);
				WriteMessage(ID, 'Scarecrows: ' + IntToStr(player[i].Scarecrows), GREEN);
				WriteMessage(ID, 'Meals:' + IntToStr(player[i].mre), GREEN);
			end;
	end;
	if sharpshooter > 0 then begin
		WriteMessage(ID, 'Sharpshooter:', ORANGE);
		WriteMessage(ID, 'Molotovs:   ' + IntToStr(player[Sharpshooter].molotovs), GREEN);
	end;
	if priest > 0 then begin
		WriteMessage(ID, 'Priest:', ORANGE);
		WriteMessage(ID, 'Holy water: ' + IntToStr(player[priest].HolyWater), GREEN);
	end;
	if Cop.ID > 0 then begin
		WriteMessage(ID, 'Police officer:', ORANGE);
		WriteMessage(ID, 'Supply points: ' + IntToStr(Trunc(Cop.SupplyPoints)), GREEN);
		WriteMessage(ID, 'Meals:         ' + IntToStr(player[Cop.ID].mre), GREEN);
	end;
end;

function TaskPolice_TryBuyItem(Name: string; Amount: integer): string; // Amount: if zero then default value is used
var b, taken: boolean;
	i, x: smallint;
	cost: single;
begin
  {$IFNDEF FPC}
	case Copy(Name, 1, 4) of
		'vest': begin
			if Amount < 1 then Amount := 1;
			if Cop.SupplyPoints >= VESTCOST * Amount then
			begin
				Cop.SupplyPoints := Cop.SupplyPoints - VESTCOST * Amount;
				Objects_SpawnX(Cop.ID, OBJECT_VEST_KIT, Amount);
			end else b:=true;
			Name := 'Vest';
		end;

		'medi', 'med': begin
			if Amount < 1 then Amount := 1;
			if Cop.SupplyPoints >= MEDICOST * Amount then
			begin
				if Objects_SpawnX(Cop.ID, OBJECT_MEDICAL_KIT, Amount) then Cop.SupplyPoints := Cop.SupplyPoints - MEDICOST * Amount;
			end else b:=true;
			Name := 'Medical kit';
		end;

		'clus': begin
			if Amount < 1 then Amount := 1;
			if Cop.SupplyPoints >= CLUSTERCOST * Amount then
			begin
				Cop.SupplyPoints := Cop.SupplyPoints - CLUSTERCOST * Amount;
				Objects_SpawnX(Cop.ID, OBJECT_CLUSTER_KIT, Amount);
			end else b:=true;
			Name := 'Clusters pack';
		end;

		'nade', 'gren': begin
			if Amount < 1 then Amount := NADEPACK;
			cost := Int(NADECOST) * Int(Amount) / Int(NADEPACK);
			if Cop.SupplyPoints >= cost then
			begin
				if Objects_SpawnX(Cop.ID, OBJECT_GRENADE_KIT, Amount) then Cop.SupplyPoints := Cop.SupplyPoints - cost;
			end else b:=true;
			Name := 'Grenade pack';
		end;

		'wate', 'holy': begin
			if priest > 0 then
				if Player[Priest].Status = 1 then
					taken := true;
			if taken then begin
				if Amount < 1 then Amount := WATERML else
				if Amount < WATERML / 2 then begin
					if Amount > 0 then
						WriteConsole(Cop.ID, 'Can''t buy less than ' + IntToStr(WATERML / 2) + ' ml at once', RED);
					Amount := WATERML;
				end;
				cost := Int(WATERCOST) * Int(Amount) / Int(WATERML);
				if Cop.SupplyPoints >= cost then
				begin
					Cop.SupplyPoints := Cop.SupplyPoints - cost;
					player[priest].HolyWater := player[priest].HolyWater +Amount;
					WriteConsole(priest, 'The police officer has ordered '+IntToStr(Amount)+' ml of Holy Water for you', GREEN);
				end else b:=true;
			end else WriteConsole(Cop.ID, 'There is no priest at the moment', RED);
			Name := 'HW';
		end;

		'molo', 'mol': begin
			if sharpshooter > 0 then
				if Player[Sharpshooter].Status = 1 then
					taken := true;
			if taken then begin
				if Amount < 1 then Amount := MOLOTOVPACK;
				cost := Int(MOLOTOVCOST) * Int(Amount) / Int(MOLOTOVPACK);
				if Cop.SupplyPoints >= cost then begin
					Cop.SupplyPoints := Cop.SupplyPoints - cost;
					player[Sharpshooter].molotovs := player[Sharpshooter].molotovs + Amount;
					WriteConsole(sharpshooter, 'The police officer has ordered '+IntToStr(Amount)+' Molotovs for you', GREEN);
				end else b:=true;
			end else WriteConsole(Cop.ID, 'There is no sharpshooter at the moment', RED);
			Name := 'Molotov';
		end;

		'stat', 'sg': begin
			if mechanic > 0 then
				if Player[Mechanic].Status = 1 then
					taken := true;

			if taken then begin
				if Amount < 1 then Amount := 1;
				if SG.Num + player[ mechanic ].statguns + Amount > Mode[Modes.RealCurrentMode].MaxSG then
					if 1.0 * Mode[Modes.RealCurrentMode].MaxSG - SG.Num - player[ mechanic ].statguns < 1 then
					begin
						WriteConsole(Cop.ID, 'Your team can''t have more stationary guns', RED);
						exit;
					end else Amount := Mode[Modes.RealCurrentMode].MaxSG - SG.Num - player[ mechanic ].statguns;

				cost := Amount * STATCOST;
				if Cop.SupplyPoints >= cost then
				begin
					Cop.SupplyPoints := Cop.SupplyPoints - cost;
					WriteConsole(mechanic, 'The police officer has ordered ' + IntToStr(Amount) + ' Stationary Gun' + pl(Amount) + ' for you!', GREEN);
					player[ mechanic ].statguns := player[ mechanic ].statguns + Amount;
				end else b:=true;
			end else WriteConsole(Cop.ID, 'There is no mechanic at the moment', RED);
			Name := 'Stationary gun';
		end;

		'sent': begin
			if mechanic > 0 then
				if Player[Mechanic].Status = 1 then
					taken := true;
			if taken then begin
				if player[mechanic].Sentrys = 0 then begin
					//Disable sentry for VS
					if not Mode[Modes.RealCurrentMode].Sentry then
					begin
						WriteConsole(Cop.ID, 'Sentry Gun is not available in this mode', RED);
						exit;
					end;

					if Cop.SupplyPoints >= SENTRYCOST then
					begin
						Cop.SupplyPoints := Cop.SupplyPoints - SENTRYCOST;
						WriteConsole(mechanic, 'The police officer has ordered a Sentry Gun for you!', GREEN);
						player[mechanic].Sentrys := 1;
						if Amount > 1 then
							WriteConsole(Cop.ID, 'The mechanic can have only 1 Sentry Gun', RED);
						Amount := 1;
					end else b:=true;
				end else WriteConsole(Cop.ID, 'The mechanic has already got a Sentry Gun', RED);
			end else WriteConsole(Cop.ID, 'There is no mechanic at the moment', RED);
			Name := 'Sentry gun';
		end;

		'ammo': begin
			if mechanic > 0 then
				if Player[Mechanic].Status = 1 then
					taken := true;

			if taken then begin
				if Amount < 1 then Amount := 1;
				cost := Amount * SENTRYAMMOCOST;
				if Cop.SupplyPoints >= cost then
				begin
					Cop.SupplyPoints := Cop.SupplyPoints - cost;
					WriteConsole(mechanic, 'The police officer has ordered ' + IntToStr(Amount) + ' sentry gun Ammo Belt' + pl(Amount) + ' for you!', GREEN);
					player[mechanic].SentryAmmo := player[mechanic].SentryAmmo + Amount;
				end else b:=true;
			end else WriteConsole(Cop.ID, 'There is no mechanic at the moment', RED);
			Name := 'Sentry ammo belt';
		end;

		'mine': begin
			if DemoMan.ID > 0 then
				if Player[DemoMan.ID].Status = 1 then
					taken := true;

			if Taken then begin
				if Amount < 1 then Amount := MINEPACK;
				cost := Int(MINECOST) * Int(Amount) / Int(MINEPACK);
				if Cop.SupplyPoints >= cost then begin
					Cop.SupplyPoints := Cop.SupplyPoints - cost;
					WriteConsole(DemoMan.ID, IntToStr(Amount) + ' mines added to arsenal!', GREEN);
					player[ DemoMan.ID ].Mines := player[ DemoMan.ID ].Mines + Amount;
				end else b:=true;
			end else WriteConsole(Cop.ID, 'There is no demolition man at the moment', RED);
			Name := 'Mine';
		end;

		'char': begin
			if DemoMan.ID > 0 then
				if Player[DemoMan.ID].Status = 1 then
					taken := true;

			if taken then begin
				if Amount < 1 then Amount := 1;
				if Cop.SupplyPoints >= (CHARGECOST * Amount) then begin
					Cop.SupplyPoints := Cop.SupplyPoints - (CHARGECOST * Amount);
					WriteConsole(DemoMan.ID, IntToStr(Amount) + ' charges added to arsenal!', GREEN);
					player[ DemoMan.ID ].charges := player[ DemoMan.ID ].charges + Amount;
				end else b:=true;
			end else WriteConsole(Cop.ID, 'There is no demolition man at the moment', RED);
			Name := 'Charge';
		end;

		'wire': begin
			if mechanic > 0 then
				if Player[Mechanic].Status = 1 then
					taken := true;

			if taken then begin
				if Amount < 1 then Amount := 1;
				if Cop.SupplyPoints >= (WIRECOST * Amount) then begin
					Cop.SupplyPoints := Cop.SupplyPoints - (WiRECOST * Amount);
					WriteConsole(mechanic, 'The police officer has ordered '+IntToStr(Amount) + ' wire' + pl(Amount) + ' for you!', GREEN);
					player[ mechanic ].Wires := player[ mechanic ].Wires + Amount;
				end else b:=true;
			end else WriteConsole(Cop.ID, 'There is no mechanic at the moment', RED);
			Name := 'Barbed wire';
		end;

		'scar': begin
			if Amount < 1 then Amount := 1;
			for i := 1 to MaxID do
				if player[i].Status = 1 then
					if player[i].task = 4 then begin
						b := true;
						break;
					end;
			if not b then begin
				WriteConsole(Cop.ID, 'There is no farmer at the moment', RED);
				exit;
			end;
			b := false;
			if Cop.SupplyPoints >= (SCARECROWCOST * Amount) then begin
				Cop.SupplyPoints := Cop.SupplyPoints - (SCARECROWCOST * Amount);
				WriteConsole(i, 'The police officer has ordered '+IntToStr(Amount) + ' scarecrow' + pl(Amount) + ' for you!', GREEN);
				player[i].Scarecrows := player[i].Scarecrows + Amount;
			end else b:=true;
			Name := 'Scarecrow';
		end;
		else begin
			if Amount < 1 then Amount := 1;
			i := WeapStrToInt(Name);
			if (i <= 0) or (i > 16) then begin
				WriteConsole(Cop.ID, 'No such weapon', RED);
				exit;
			end;

			if Modes.CurrentMode = 2 then
				if i = 10 then begin
					WriteConsole(Cop.ID, 'Flak cannon is not available in Versus mode', RED);
					exit;
				end;
			try
				weap2menu(i);
			except
				WriteConsole(Cop.ID, 'This weapon cannot be bought.', RED);
				exit;
			end;
			x := TaskPolice_TryBuyWeapon(weap2menu(i), Amount, false);
			if x > 0 then begin
				if x = 1 then begin
					Result := WeaponName(i);
				end else
					Result := IntToStr(x) + 'x ' + WeaponName(i);
			end else begin
				if x = -1 then begin
					WriteConsole(Cop.ID, WeaponName(i) + ' is not buyable', RED);
				end else begin
					if Amount = 1 then begin
						WriteConsole(Cop.ID, 'Insufficient funds to buy ' + WeaponName(i), RED);
					end else
						WriteConsole(Cop.ID, 'Insufficient funds to buy ' + IntToStr(Amount) + 'x ' + WeaponName(i), RED);
				end;
			end;
			exit;
		end;
	end;
  {$ENDIF}
	if b then begin
		if Name <> 'HW' then begin
			if Amount = 1 then begin
				WriteConsole(Cop.ID, 'Insufficient funds to buy a ' + Name + '!', RED);
			end else
				WriteConsole(Cop.ID, 'Insufficient funds to buy ' + IntToStr(Amount) + ' ' + Name + 's!', RED);
		end else
			WriteConsole(Cop.ID, 'Insufficient funds to buy ' + IntToStr(Amount) + ' ml of Holy Water', RED);
	end else
		if Name <> 'HW' then begin
			if Amount = 1 then begin
				Result := Name;
			end else
				Result := IntToStr(Amount) + ' ' + Name + 's';
		end else
			Result := '(' + IntToStr(Amount) + ' ml) Holy Water';
end;

procedure TaskPolice_OnBuyCommand(text: string);
var notfirst: boolean;
	sp: single;
	l, i: smallint;
	n: integer;
	arg: array of string;
	last, res: string;
begin
	arg := Explode2(text, ' ', false);
	l := Length(arg);
	if l = 0 then exit;
	text := 'The Police Officer has ordered ';
	sp := Cop.SupplyPoints;
	for i := 0 to l - 1 do begin
		if arg[i] <> ' ' then begin
			n := StrtoIntDef(arg[i], $FFFFFF);
			if n <> $FFFFFF then begin
				if n < 1 then n := 1;
				//if n > 50 then begin
				//	n := 50;
				//	WriteConsole(Cop.ID, 'Max amount of the ordered item is 50', RED);
				//end;
				if last <> '' then begin
					res := TaskPolice_TryBuyItem(last, n);
					last := '';
				end else
					WriteConsole(Cop.ID, 'Unassigned quantifier (' + arg[i] + '), proper syntax: "/buy <name> [number] <name> [numer] ... "', RED);
			end else begin
				if last <> '' then
					res := TaskPolice_TryBuyItem(last, 0); // 0 - default value
				if i < l-1 then begin
					last := arg[i];
				end else
					if res <> '' then res := res + ', ' + TaskPolice_TryBuyItem(arg[i], 0)
					else res := TaskPolice_TryBuyItem(arg[i], 0);
					//^this is needed so the second last item (saved in res) isn't overwritten by the last item
			end;

			if res <> '' then begin
				if text <> '' then begin
					if Length(text) < 100 then begin
						if notfirst then text := text + ', ' else notfirst := true; // don't add comma before the first listed item
					end else begin
						WriteConsole(0, text, ORANGE);
						text := '';
					end;
				end;
				text := text + res;
				res := '';
			end;
		end;
	end;

	if sp <> Cop.SupplyPoints then begin
		if Length(text) <= 90 then begin
			//if text <> nil then text := text + '. ';
			//text := text + 'Supply points left: ' + IntToStr(Cop.SupplyPoints);
			WriteConsole(0, text, ORANGE);
		end else begin
			WriteConsole(0, text, ORANGE);
		end;
		WriteConsole(Cop.ID, 'Supply points left: ' + FormatFloat('.0', Cop.SupplyPoints), ORANGE);
	end;

	if l = 1 then begin
		Cop.SingleOrders := Cop.SingleOrders + 1;
		if Cop.SingleOrders mod 10 = 0 then begin
			WriteConsole(Cop.ID, 'Hint: You can buy multiple items at once, example: "/buy molotovs grenade wires 3 mp5" (will buy 3 wires instead of one)', HINTCOL);
		end else
		if Cop.SingleOrders = 5 then begin
			WriteConsole(Cop.ID, 'Hint: You can buy multiple items at once, example: "/buy statgun mines spas"', HINTCOL);
		end;
  end;

  if l > 0 then begin
    if Cop.Orders mod 20 = 19 then begin
      WriteConsole(Cop.ID, 'Hint: See your teams equipment with /teqp', HINTCOL);
    end;
    Cop.Orders := Cop.Orders + 1;
  end;
end;

procedure TaskPolice_OnCommand(Text: string);
var
  str: string;
begin
  str := LowerCase(Text);

  if str = '/supply' then begin
	  TaskPolice_WriteSupplyInfo();
    exit;
  end;

  if Players[Cop.ID].IsAdmin = false then // so it doesn't appear twice
  if (str = '/qleqp') or (str = '/teqp') then begin
	  TaskPolice_WriteSupplyInfo();
    exit;
  end;

  if Copy(str, 2, 4) = 'weap' then begin
	  TaskPolice_WriteWeaponInfo();
    exit;
  end;

  if Players[Cop.ID].Alive then begin

    if Copy(str,2,3) = 'buy' then begin
			TaskPolice_OnBuyCommand(Copy(str, 5, 200));
      exit;
		end;

		if str = '/mark' then begin
			Strike_SetMarker(Cop.ID);
      exit;
		end;

    if str = '/shop' then begin
			if WeaponSystem.Enabled then begin
				TaskPolice_Shop_Switch(not Cop.Shop.Active);
			end else
				Players[Cop.ID].WriteConsole( 'Weapon Shop is disabled in current weapon system', RED);
      exit;
		end;

    if str = '/strike' then begin
			if not Strike.Active then begin
				if Marker.Active[0] then begin
					if Marker.Active[1] then begin
						if Cop.SupplyPoints >= STRIKECOST then begin
							Cop.SupplyPoints := Cop.SupplyPoints - STRIKECOST;
							Strike_Call(1);
						end else Players[Cop.ID].WriteConsole( 'Insufficient points', RED);
					end else Players[Cop.ID].WriteConsole( 'Marked area can''t be bombed from the air', RED);
				end else Players[Cop.ID].WriteConsole( 'Marker not set, type /mark to set a marker', RED);
			end else Players[Cop.ID].WriteConsole( 'Strike already in progress', RED);
      exit;
		end;

    if str = '/heli' then begin
			if not Strike.Active then begin
				if Marker.Active[0] then begin
					if Marker.Active[2] then begin
						if Cop.SupplyPoints >= HELICOST then begin
							Cop.SupplyPoints := Cop.SupplyPoints - HELICOST;
							Strike_Call(2);
						end else Players[Cop.ID].WriteConsole( 'Insufficient points', RED);
					end else Players[Cop.ID].WriteConsole( 'Marked area can''t be struck by the helicopter', RED);
				end else Players[Cop.ID].WriteConsole( 'Marker not set, type /mark to set a marker', RED);
			end else Players[Cop.ID].WriteConsole('Strike already in progress', RED);
      exit;
    end;

	end else
  	Players[Cop.ID].WriteConsole('You are already dead', RED);
end;

procedure TaskPolice_Reset();
begin
  Cop.Orders := 0;
	Cop.SingleOrders := 0;
	Cop.SupplyPoints := 0.0;
	Cop.Shop.Active := false;
	Cop.Shop.Status := 0;
  Cop.ID := 0;
end;

initialization
 	SPTime := SUPPLYTIME;
end.

