local constants = require('lolloArrivalsDeparturesPredictor.constants')

return {
    print = function(...)
        if not(constants.isExtendedLogActive) then return end
        print(...)
    end,
    warn = function(label, ...)
        if not(constants.isWarningLogActive) then return end
        print('lolloArrivalsDeparturesPredictor WARNING: ' .. label, ...)
    end,
    err = function(label, ...)
        if not(constants.isErrorLogActive) then return end
        print('lolloArrivalsDeparturesPredictor ERROR: ' .. label, ...)
    end,
    debugPrint = function(whatever)
        if not(constants.isExtendedLogActive) then return end
        debugPrint(whatever)
    end,
    warningDebugPrint = function(whatever)
        if not(constants.isWarningLogActive) then return end
        debugPrint(whatever)
    end,
    errorDebugPrint = function(whatever)
        if not(constants.isErrorLogActive) then return end
        debugPrint(whatever)
    end,
    profile = function(label, func)
        if constants.isTimersActive then
            local results
            local startSec = os.clock()
            print('######## ' .. tostring(label or '') .. ' starting at', math.ceil(startSec * 1000), 'mSec')
            -- results = {func()} -- func() may return several results, it's LUA
            results = func()
            local elapsedSec = os.clock() - startSec
            print('######## ' .. tostring(label or '') .. ' took' .. math.ceil(elapsedSec * 1000) .. 'mSec')
            -- return table.unpack(results) -- LOLLO TODO test if we really need this
            return results
        else
            return func() -- LOLLO TODO test this
        end
    end,
    errorHandler = function(error)
        print('lolloArrivalsDeparturesPredictor ERROR:') debugPrint(error)
    end,
}
