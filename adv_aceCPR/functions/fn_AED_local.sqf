/*
ADV_aceCPR_fnc_AED_Local - by Belbo, edited by Tommo
*/

params ["_caller", "_target"];

//standard variables:
private _inCardiac = _target getVariable ["ace_medical_inCardiacArrest",false];
private _inRevive = _target getVariable ["ace_medical_inReviveState",false];
private _reviveEnabled = missionNamespace getVariable ["ace_medical_enableRevive",0];

//backwards compatibility:
private _probabilities = missionNamespace getVariable ["adv_aceCPR_probabilities", [40,15,5,85]];
if (count _probabilities isEqualTo 3) then {
	_probabilities pushBack 85;
};

//Changes by Tommo, adding CBA variables for randomness of vitals.
//Note that the randomness is a +/- of up to that amount. So high randomness with low minimums could kill people if not swiftly epi'd. Added _gotEpi as it's not factored in by default, so epi in system can increase heartrate after stabilize.
private _minBloodVolume = missionNamespace getvariable ["adv_cpr_minBloodVolume",30];
private _randomBloodVolume = missionNamespace getvariable ["adv_cpr_randBloodVolume",0];
private _minHeartRate = missionNamespace getvariable ["adv_cpr_minHeartRate",30];
private _randomHeartRate = missionNamespace getvariable ["adv_cpr_randHeartRate",0];
private _gotEpi = _target getVariable ["ace_medical_epinephrine_insystem",0];

//what's our probability?
private _probability = (_probabilities select 3) min 100;

//let's roll the dice:
private _diceRoll = 1+floor(random 100);

//diagnostics:
[_caller,format ["probability was at %1 per-cent, and the dice-roll was %2.",_probability, _diceRoll]] call adv_aceCPR_fnc_diag;

//adds pain with each defib use:
[_target, 0.4] call ace_medical_fnc_adjustPainLevel;

if ( _probability >= _diceRoll ) exitWith {
	//resetting the values of the target:
	//_target setVariable ["ace_medical_inReviveState",false,true];
	//_target setVariable ["ace_medical_inCardiacArrest",false,true];
	_target setVariable ["ace_medical_inReviveState",nil,true];
	_target setVariable ["ace_medical_inCardiacArrest",nil,true];
	
	//if ( _reviveEnabled > 0 ) then {
	//sets the heartrate higher than CPR:
	//Tommo, modifications here for randomness, and Epi heart rate adjustment.
	private _heartChange = _minHeartRate + 10;
	if (_randomHeartRate != 0) then {
		_heartChange = _heartChange + (round (random [-_randomHeartRate,0,_randomHeartRate]));
	};
	_target setVariable ["ace_medical_heartRate",_heartChange, true];
	
	//Tommo - added heart rate adjustment for Epi in system when player revived, so it's not "wasted" so to speak.
		if (_gotEpi > 0) then {
			//_hrIncreaseLow is the config values for Epi heart rate increases take from ace_medical_treatments.hpp.
			//Multiplying that by how much epi is left in system, then apply a normal ACE heart rate adjustment.
			//Same forumla taken from fnc_treatmentAdvanced_medicationLocal.sqf
			 private _hrIncreaseLow = [10, 20, 15];
			 {_hrIncreaseLow set [_foreachIndex, (_x * _gotEpi)]} foreach _hrIncreaseLow;
			
			[_target, ((_hrIncreaseLow select 0) + random ((_hrIncreaseLow select 1) - (_hrIncreaseLow select 0))), (_hrIncreaseLow select 2), _hrCallback] call ace_medical_fnc_addHeartRateAdjustment;
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
	//};
	
	//log the custom cpr success to the treatment log:
	[_target, "activity", localize "STR_ADV_ACECPR_AED_COMPLETED", [[_caller, false, true] call ace_common_fnc_getName]] call ace_medical_fnc_addToLog;
	[_target, "activity_view", localize "STR_ADV_ACECPR_AED_COMPLETED", [[_caller, false, true] call ace_common_fnc_getName]] call ace_medical_fnc_addToLog;

	//diagnostics:
	[_caller,"patient has been succesfully stabilized"] call adv_aceCPR_fnc_diag;
	
	//show pulse after AED:
	if (!local _caller) then {
		["adv_aceCPR_evh_showPulse", [_caller, _target], _caller] call CBA_fnc_targetEvent;
	};
	["adv_aceCPR_evh_showPulse", [_caller, _target]] call CBA_fnc_localEvent;

	//return:
	true;
};

//show pulse after AED:
if (!local _caller) then {
	["adv_aceCPR_evh_showPulse", [_caller, _target], _caller] call CBA_fnc_targetEvent;
};
["adv_aceCPR_evh_showPulse", [_caller, _target]] call CBA_fnc_localEvent;

//diagnostics:
[_caller,"patient has not been stabilized"] call adv_aceCPR_fnc_diag;

//log the AED usage to the treatment log:
[_target, "activity", localize "STR_ADV_ACECPR_AED_EXECUTE", [[_caller, false, true] call ace_common_fnc_getName]] call ace_medical_fnc_addToLog;
[_target, "activity_view", localize "STR_ADV_ACECPR_AED_EXECUTE", [[_caller, false, true] call ace_common_fnc_getName]] call ace_medical_fnc_addToLog;

false;