/*
ADV_aceCPR_fnc_CPR_Local - by Belbo, edited by Tommo
*/

params ["_caller", "_target"];

//standard variables:
private _inCardiac = _target getVariable ["ace_medical_inCardiacArrest",false];
private _inRevive = _target getVariable ["ace_medical_inReviveState",false];
private _reviveEnabled = missionNamespace getVariable ["ace_medical_enableRevive",0];

//Changes by Tommo, adding CBA variables for randomness of vitals.
//Note that the randomness is a +/- of up to that amount. So high randomness with low minimums could kill people if not swiftly epi'd. 
private _minBloodVolume = missionNamespace getvariable ["adv_cpr_minBloodVolume",30];
private _randomBloodVolume = missionNamespace getvariable ["adv_cpr_randBloodVolume",0];
private _minHeartRate = missionNamespace getvariable ["adv_cpr_minHeartRate",30];
private _randomHeartRate = missionNamespace getvariable ["adv_cpr_randHeartRate",0];

//add time if in revive:
if ( _inRevive ) then {
	["adv_aceCPR_evh_addTime", [_caller, _target]] call CBA_fnc_localEvent;
};

//minor pain adjustment with each CPR:
[_target, 0.04] call ace_medical_fnc_adjustPainLevel;

//exit if cpr no longer possible:
if !( [_target] call adv_aceCPR_fnc_isResurrectable ) exitWith {
	//diagnostics:
	[_caller,"custom CPR on target no longer possible"] call adv_aceCPR_fnc_diag;
	
	//log the inability for custom CPR to the medic log:
	[_target, "activity", localize "STR_ADV_ACECPR_CPR_FATAL", [[_caller, false, true] call ace_common_fnc_getName]] call ace_medical_fnc_addToLog;
	[_target, "activity_view", localize "STR_ADV_ACECPR_CPR_FATAL", [[_caller, false, true] call ace_common_fnc_getName]] call ace_medical_fnc_addToLog;
};

//what's our probability?
private _probability = ([_caller,_target] call ADV_aceCPR_fnc_probability) min 100;

//let's roll the dice:
private _diceRoll = 1+floor(random 100);

//diagnostics:
[_caller,format ["resulting probability was at %1 per-cent, and the dice-roll was %2.",_probability, _diceRoll]] call adv_aceCPR_fnc_diag;

if ( _probability >= _diceRoll ) exitWith {
	//resetting the values of the target:
	//_target setVariable ["ace_medical_inReviveState",false,true];
	//_target setVariable ["ace_medical_inCardiacArrest",false,true];
	_target setVariable ["ace_medical_inReviveState",nil,true];
	_target setVariable ["ace_medical_inCardiacArrest",nil,true];
	
	private _gotEpi = _target getVariable ["ace_medical_epinephrine_insystem",0];
	
	//if player has a higher bloodvolume, the new heart rate will be lower.
	//if ( _reviveEnabled > 0 ) then {
    //Tommo - changed !(_gotEpi > 0.5) to (_gotEpi < 0.5) for clarity.
	//Added _heartChange to capture min heart rate, then apply randomness.
    
	call {
		private _heartChange = 0;
		if (_target getVariable "ace_medical_bloodVolume" > 60 && (_gotEpi < 0.5)) then {
			_heartChange = _minHeartRate;
		} else {
			_heartChange = _minHeartRate + 10;
		};
		
		if (_randomHeartRate != 0) then {
			_heartChange = _heartChange + (round (random [-_randomHeartRate,0,_randomHeartRate]));
		};
		
		_target	setVariable ["ace_medical_heartRate",_heartChange, true];
		
		//Tommo - added heart rate adjustment for Epi in system when player revived, so it's not "wasted" so to speak.
		if (_gotEpi > 0) then {
			//_hrIncreaseLow is the config values for Epi heart rate increases take from ace_medical_treatments.hpp.
			//Multiplying that by how much epi is left in system, then apply a normal ACE heart rate adjustment.
			//Same forumla taken from fnc_treatmentAdvanced_medicationLocal.sqf
			 private _hrIncreaseLow = [10, 20, 15];
			 {_hrIncreaseLow set [_foreachIndex, (_x * _gotEpi)]} foreach _hrIncreaseLow;
			
			[_target, ((_hrIncreaseLow select 0) + random ((_hrIncreaseLow select 1) - (_hrIncreaseLow select 0))), (_hrIncreaseLow select 2), _hrCallback] call ace_medical_fnc_addHeartRateAdjustment;
		};
	};
	
	//if the player's bloodVolume is below the minimal value, it will be reset to 30:
	//Tommo - or some reason if ragdoll is on Belbo had an extra +10% blood volume. Dunno why, will copy.
	//Added randomness. Again could kill people with high randomness/low minimums.
	private _threshold = if (isClass(configFile >> "CfgPatches" >> "diwako_ragdoll")) then {_minBloodVolume + 10} else {_minBloodVolume};
	if (_target getVariable "ace_medical_bloodVolume" < _threshold) then {
		if (_randomBloodVolume != 0) then {
			_threshold = _threshold + (round (random [-_randomBloodVolume,0,_randomBloodVolume]));
        };
		_target setVariable ["ace_medical_bloodVolume",_threshold, true];
	};

	//log the custom cpr success to the treatment log:
	[_target, "activity", localize "STR_ADV_ACECPR_CPR_COMPLETED", [[_caller, false, true] call ace_common_fnc_getName]] call ace_medical_fnc_addToLog;
	[_target, "activity_view", localize "STR_ADV_ACECPR_CPR_COMPLETED", [[_caller, false, true] call ace_common_fnc_getName]] call ace_medical_fnc_addToLog;

	//diagnostics:
	[_caller,"patient has been successfully stabilized"] call adv_aceCPR_fnc_diag;

	//return:
	true;
};

//diagnostics:
[_caller,"patient has not been stabilized"] call adv_aceCPR_fnc_diag;

//log the custom cpr to the treatment log:
[_target, "activity", localize "STR_ADV_ACECPR_CPR_EXECUTE", [[_caller, false, true] call ace_common_fnc_getName]] call ace_medical_fnc_addToLog;
[_target, "activity_view", localize "STR_ADV_ACECPR_CPR_EXECUTE", [[_caller, false, true] call ace_common_fnc_getName]] call ace_medical_fnc_addToLog;

false;