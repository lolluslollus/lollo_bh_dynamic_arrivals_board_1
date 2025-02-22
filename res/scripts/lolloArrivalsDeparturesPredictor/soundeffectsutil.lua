local audioutil = require "audioutil"

local soundEffects = {
	-- ['lolloArrivalsDeparturesPredictor/car_horn'] = { "lolloArrivalsDeparturesPredictor/car_horn.wav" },
    -- ['lolloArrivalsDeparturesPredictor/car_idle'] = { "lolloArrivalsDeparturesPredictor/car_idle.wav" },
    lolloArrivalsDeparturesPredictor_car_horn = { "lolloArrivalsDeparturesPredictor/car_horn.wav" },
    lolloArrivalsDeparturesPredictor_car_idle = { "lolloArrivalsDeparturesPredictor/car_idle.wav" },

	buttonHover = { "button_hover.wav" },
	buttonClick = { "button_click.wav" },
	
	startGame = { "button_click_start_game.wav" },
	
	tabClick = { "tab.wav" },
	
	toggleOn = { "componentActive.wav" },
	toggleOff = { "toggleOff.wav" },
	menuToggle = { "componentActive.wav" },
	
	componentActive = { "componentActive.wav" },

	guidesystem = { "guide_system_bongo.wav", "guide_system_conga.wav" },
	
	selectTown = { "selected_town.wav" },

	selectTrainDepot = { "selected_traindepot3.wav" },
	selectRoadDepot = { "selected_truckdepot2.wav" },
	selectTramDepot = { "selected_tramdepot1.wav" },
	selectAirDepot = { "selected_airdepot3.wav" },
	selectWaterDepot = { "selected_waterdepot1.wav" },

	selectAirport = { "selected_airport1.wav" },
	selectHarbor = { "selected_harbor1.wav" },
	selectTrainStation = { "selected_passengertrainstation2.wav" },
	selectBusTramStation = { "selected_cargotruckstation3.wav" },
	selectRoadStation = { "selected_cargotruckstation3.wav" },

	selectBuildingResidential = { "selected_residential1.wav","selected_residential2.wav","selected_residential3.wav" },
	selectBuildingCommercial = { "selected_comercial1.wav","selected_comercial2.wav","selected_comercial3.wav" },
	selectBuildingIndustrial = { "selected_industry1.wav","selected_industry2.wav","selected_industry3.wav" },

	selectPersonMale = { "selected_male1.wav", "selected_male2.wav", "selected_male3.wav", "selected_male4.wav", "selected_male5.wav" },
	selectPersonFemale = { "selected_female1.wav", "selected_female2.wav", "selected_female3.wav", "selected_female4.wav", "selected_female5.wav" },
	
	bulldozeMedium = { "construction/bulldozemedium.wav","construction/bulldozemedium2.wav" },
	bulldozeLarge = { "construction/bulldozelarge.wav","construction/bulldozelarge2.wav" },
	
	construct = { "construction/build.wav" },
	constructHalf = { "construction/build_half.wav" },
	constructNoMoney = { "construction/cancel.wav" },
	
	cashAccount = { "cash_account_0.wav", "cash_account_1.wav", "cash_account_2.wav" },
	
	industryUpgrade =  { "industry_upgrade.wav" },
	industryDowngrade =  { "industry_downgrade.wav" },
	
	newVehicle =  { "new_vehicle.wav" },
	
	taskCompleted = { "task_done_1.wav", "task_done_2.wav", "task_done_3.wav" },
	missionSuccess = { "mission_victory_1.wav" },
	missionFailure = { "mission_failed.wav" },
	
	attention = { "attention.wav" },
	importantNote = { "important_note.wav" },
	
	achievementEarned = { "all_tasks_completed.wav" },
	medalEarned = { "all_tasks_completed.wav" },
	
	newLine = { "new_line.wav" },
	--removeLine = { "remove_line.wav" },
	addStation = { "add_station.wav" },
	addWaypoint = { "add_waypoint.wav" },
	
	buyVehicle = { "buy_vehicle_01.wav", "buy_vehicle_02.wav", "buy_vehicle_03.wav" },
	sellVehicle = { "sell_vehicle.wav" },
	setLine = { "set_line.wav" },
	replaceVehicle = { "replace_vehicle.wav" },
	sendToDepot = { "send_to_depot.wav" },
	maintainVehicle = { "maintain_vehicle.wav" },
	colorVehicle = { "color_vehicle.wav" },
	
	borrow = { "borrow.wav" },
	repay = { "repay.wav" }
}

local soundeffectsutil = { }

-- deprecated
function soundeffectsutil.sampleCurve(nodes, x)
	return audioutil.sampleCurve(nodes, x)
end

-- deprecated
function soundeffectsutil.makeRoadVehicle2(speeds, idleSpeed, idleGain0, driveSpeed, speed01)
	local tracks = audioutil.makeRoadVehicle2(speeds, "", idleSpeed, idleGain0, "", driveSpeed, 0.0)
	
	return {
		{
			gain = audioutil.sampleCurve(tracks[1].gainCurve.nodes, speed01),
			pitch = audioutil.sampleCurve(tracks[1].pitchCurve.nodes, speed01)
		},
		{
			gain = audioutil.sampleCurve(tracks[2].gainCurve.nodes, speed01),
			pitch = audioutil.sampleCurve(tracks[2].pitchCurve.nodes, speed01)
		}
	}
end

function soundeffectsutil.squeal(speed, sideForce, maxSideForce)
	local gain = 0.0
	local pitch = 1.0
	
	local speedGain = math.mapClamp(speed, 20.0, 40.0, 1.0, 0.0)
	
	local diff = math.max(maxSideForce - sideForce, 0.0)
	gain = math.min(math.max(1.0 - 2.0 * diff, 0.0), 1.0)

	return {
		gain = gain * speedGain,
		pitch = pitch
	}
end

function soundeffectsutil.chuffs(speed, chuffStep, chuffsFastFreq, weight, refWeight)
	local fastSpeed = chuffStep * chuffsFastFreq
	local transitionSpeed = 0.8 * fastSpeed
	local fastSpeed0 = 0.85 * transitionSpeed
	local fastSpeed1 = 1.15 * transitionSpeed
	local fastGain = math.mapClamp(speed, fastSpeed0, fastSpeed1, 0.0, 1.0)
	local gain = math.mapClamp(speed, 0.0, fastSpeed0, 1.0, 0.5) * (1.0 - fastGain)
	local pitch = 1.0
	
	local weightGain = math.min(weight / refWeight, 1.0)
	local weightGain2 = math.sqrt(weightGain)

	return {
		idleTrack = {
			gain = gain * weightGain2,
			pitch = pitch
		},
		fastTrack = {
			gain = fastGain * weightGain2,
			pitch = math.sqrt(speed / fastSpeed)
		},
		event = {
			gain = gain * weightGain2,
			pitch = 1.0
		}
	}
end

function soundeffectsutil.clacks(speed, weight, numAxles, axleRefWeight, gameSpeedUp)
	local speedupGain = 0.5
	if gameSpeedUp <= 2.0 then speedupGain = 0.707 end
	if gameSpeedUp <= 1.0 then speedupGain = 1.0 end
	
	local axleWeight = weight / numAxles
	local axleWeightGain = math.min(axleWeight / axleRefWeight, 1.0)
	local axleWeightGain2 = math.sqrt(axleWeightGain)
	local gain = math.mapClamp(speed, 0.0, 10.0, 0.25, 1.0)
	local pitch = math.mapClamp(weight, 10.0, 100.0, 1.0, 0.5)
	
	return {
		gain = gain * axleWeightGain2 * speedupGain,
		pitch = pitch
	}
end

function soundeffectsutil.brake(speed, brakeDecel, maxGain)
	local gain = 0.0
	if 0.1 < brakeDecel then
		local maxBrakeDecel = 5.0
		local brakeGain = math.sqrt(math.min(brakeDecel / maxBrakeDecel))
		local speed0 = 1.0
		local speed1 = 2.0 * (brakeGain + 1.0)
		local speed2 = 4.0 * (brakeGain + 1.0)
		local speedFadeIn = math.mapClamp(speed, speed1, speed2, 1.0, 0.0)
		local speedFadeOut = math.mapClamp(speed, 0.0, speed0, 0.0, 1.0)
		gain = speedFadeIn * speedFadeOut * brakeGain * maxGain
	end
	local pitch = 1.0
	
	return {
		gain = gain,
		pitch = pitch
	}
end

function soundeffectsutil.getSoundEffects()
	return soundEffects
end

function soundeffectsutil.get(key)
	return soundEffects[key]
end

return soundeffectsutil
