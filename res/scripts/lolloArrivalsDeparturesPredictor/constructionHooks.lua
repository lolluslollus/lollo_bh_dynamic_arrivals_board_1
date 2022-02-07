local arrayUtils = require('lolloArrivalsDeparturesPredictor.arrayUtils')
local stringUtils = require('lolloArrivalsDeparturesPredictor.stringUtils')

local targetConstructions = {
    ["asset/lolloArrivalsDeparturesPredictor/platform_departures_display.con"] = {
        singleTerminal = true,
        clock = true,
        isArrivals = false,
        maxEntries = 2,
        track = true,
        absoluteArrivalTime = false,
        -- LOLLO NOTE adding a prefix is good for respecting other constructions, but I could very well use a constant instead of this
        paramPrefix = 'platform_departures_display_',
    },
    ["asset/lolloArrivalsDeparturesPredictor/station_departures_display.con"] = {
        singleTerminal = false,
        clock = true,
        isArrivals = false,
        maxEntries = 8,
        absoluteArrivalTime = true,
        paramPrefix = 'station_departures_display_',
    },
    ["asset/lolloArrivalsDeparturesPredictor/station_arrivals_display.con"] = {
        singleTerminal = false,
        clock = true,
        isArrivals = true,
        maxEntries = 8,
        absoluteArrivalTime = true,
        paramPrefix = 'station_arrivals_display_',
    }
}
-- LOLLO TODO I am surprised this works across the many different lua modes.
-- In fact, it doesn't here, so we do it here: never mind, I don't expect other mods to use this.
local funcs = {
    getRegisteredConstructions = function()
        return targetConstructions
    end,
    getRegisteredConstructionOrDefault = function(index)
        local config = targetConstructions[index]
        if not config then
            print('lolloArrivalsDeparturesPredictor WARNING: cannot read the construction config, fileName =', index or 'NIL')
            config = {}
        end

        return config
    end,
    registerConstruction = function(conPath, params)
        targetConstructions[conPath] = params
    end,
}
funcs.getParamPrefixFromCon = function()
    -- -- Only to be called from .con files! -- --
    -- This is the proper way of getting a different paramPrefix for every construction,
    -- keeping the "truth" in one place only.

    -- returns the current file path
    -- local _currentFilePathAbsolute = debug.getinfo(1, 'S').source
    -- returns the caller file path (one level up in the stack)
    local _currentFilePathAbsolute = debug.getinfo(2, 'S').source
    assert(
        stringUtils.stringEndsWith(_currentFilePathAbsolute, '.con'),
        'lolloArrivalsDeparturesPredictor ERROR: getParamPrefixFromCon was called from ' .. (_currentFilePathAbsolute or 'NIL')
    )
    -- print('_currentFilePathAbsolute =') debugPrint(_currentFilePathAbsolute)
    ---@diagnostic disable-next-line: undefined-field
    local _currentFilePathRelative = arrayUtils.getLast(_currentFilePathAbsolute:split('/res/construction/'))

    return funcs.getRegisteredConstructionOrDefault(_currentFilePathRelative).paramPrefix
end

return funcs
