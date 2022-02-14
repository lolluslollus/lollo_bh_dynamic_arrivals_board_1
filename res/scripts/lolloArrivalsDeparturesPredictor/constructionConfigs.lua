local arrayUtils = require('lolloArrivalsDeparturesPredictor.arrayUtils')
local stringUtils = require('lolloArrivalsDeparturesPredictor.stringUtils')

-- LOLLO NOTE config.maxEntries is tied to the construction type,
-- and we buffer:
-- make sure sign configs with the same singleTerminal have the same maxEntries

local myConstructionConfigs = {
    ['asset/lolloArrivalsDeparturesPredictor/platform_departures_display.con'] = {
        singleTerminal = true,
        clock = true,
        isArrivals = false,
        maxEntries = 2,
        track = true,
        -- LOLLO NOTE adding a prefix is good for respecting other constructions,
        -- but I could very well use a constant instead of this
        paramPrefix = 'platform_departures_display_',
    },
    ['asset/lolloArrivalsDeparturesPredictor/street_platform_departures_display.con'] = {
        singleTerminal = true,
        clock = true,
        isArrivals = false,
        maxEntries = 2,
        track = false,
        -- LOLLO NOTE adding a prefix is good for respecting other constructions,
        -- but I could very well use a constant instead of this
        paramPrefix = 'street_platform_departures_display_',
    },
    ['asset/lolloArrivalsDeparturesPredictor/station_departures_display.con'] = {
        singleTerminal = false,
        clock = true,
        isArrivals = false,
        maxEntries = 8,
        paramPrefix = 'station_departures_display_',
    },
    ['asset/lolloArrivalsDeparturesPredictor/station_arrivals_display.con'] = {
        singleTerminal = false,
        clock = true,
        isArrivals = true,
        maxEntries = 8,
        paramPrefix = 'station_arrivals_display_',
    }
}

local funcs = {
    get = function()
        return myConstructionConfigs
    end,
    getParamPrefixFromCon = function()
        -- -- Only to be called from .con files! -- --
        -- This is the proper way of getting a different paramPrefix for every construction,
        -- keeping the 'truth' in one place only.

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
        -- print('_currentFilePathRelative =') debugPrint(_currentFilePathRelative)

        return myConstructionConfigs[_currentFilePathRelative].paramPrefix
    end,
}

return funcs
