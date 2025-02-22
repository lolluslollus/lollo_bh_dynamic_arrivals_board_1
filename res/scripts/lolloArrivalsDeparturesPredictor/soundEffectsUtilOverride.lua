local soundeffectsutil = require('soundeffectsutil')

local _getUG = soundeffectsutil.get
local _getSoundEffectsUG = soundeffectsutil.getSoundEffects

local _myEffects = {
	-- ['lolloArrivalsDeparturesPredictor/car_horn'] = { "lolloArrivalsDeparturesPredictor/car_horn.wav" },
    -- ['lolloArrivalsDeparturesPredictor/car_idle'] = { "lolloArrivalsDeparturesPredictor/car_idle.wav" },
    lolloArrivalsDeparturesPredictor_car_horn = { "lolloArrivalsDeparturesPredictor/car_horn.wav" },
    lolloArrivalsDeparturesPredictor_car_idle = { "lolloArrivalsDeparturesPredictor/car_idle.wav" },
    lolloArrivalsDeparturesPredictor_test = true
}

---overrides sound effects adding mine
return function()
    soundeffectsutil.get = function(key)
        print('### get starting, key = ' .. tostring(key))
        local ugResult = _getUG(key)
        if not(ugResult) then
            print('### get is about to return my effect') debugPrint(_myEffects[key])
            return _myEffects[key]
        else
            print('### get about to return UG effect') debugPrint(ugResult)
            return ugResult
        end
    end
    soundeffectsutil.getSoundEffects = function()
        print('### getSoundEffects starting')
        local results = _getSoundEffectsUG()
        for key, value in pairs(_myEffects) do
            results[key] = value
        end
        print('### getSoundEffects about to return') debugPrint(results)
        return results
    end
    print('### sound effects initialised')
end
