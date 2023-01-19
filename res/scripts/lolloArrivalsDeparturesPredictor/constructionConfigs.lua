local arrayUtils = require('lolloArrivalsDeparturesPredictor.arrayUtils')
local logger = require('lolloArrivalsDeparturesPredictor.logger')
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
        logger.print('_currentFilePathAbsolute =') logger.debugPrint(_currentFilePathAbsolute)
        -- LOLLO NOTE the following changed in beta 35126 (the initial slash was removed): add it back to make a better check in the following
        if not(stringUtils.stringStartsWith(_currentFilePathAbsolute, '/')) then
            _currentFilePathAbsolute = '/' .. _currentFilePathAbsolute
        end
        assert(
            stringUtils.stringEndsWith(_currentFilePathAbsolute, '.con'),
            'lolloArrivalsDeparturesPredictor ERROR: getParamPrefixFromCon was called from ' .. (_currentFilePathAbsolute or 'NIL')
        )
        local _currentFilePathRelative = arrayUtils.getLast(_currentFilePathAbsolute:split('/res/construction/'))
        logger.print('_currentFilePathRelative =') logger.debugPrint(_currentFilePathRelative)
        logger.print('myConstructionConfigs =') logger.debugPrint(myConstructionConfigs)
        return myConstructionConfigs[_currentFilePathRelative].paramPrefix
    end,
}

return funcs
