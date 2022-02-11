local _isExtendedLogActive = false
local _isWarningLogActive = true
local _isErrorLogActive = true
local _isTimersActive = true

return {
    print = function(...)
        if not(_isExtendedLogActive) then return end
        print(...)
    end,
    warn = function(label, ...)
        if not(_isWarningLogActive) then return end
        print('lolloArrivalsDeparturesPredictor WARNING: ' .. label, ...)
    end,
    err = function(label, ...)
        if not(_isErrorLogActive) then return end
        print('lolloArrivalsDeparturesPredictor ERROR: ' .. label, ...)
    end,
    debugPrint = function(whatever)
        if not(_isExtendedLogActive) then return end
        debugPrint(whatever)
    end,
    warningDebugPrint = function(whatever)
        if not(_isWarningLogActive) then return end
        debugPrint(whatever)
    end,
    errorDebugPrint = function(whatever)
        if not(_isErrorLogActive) then return end
        debugPrint(whatever)
    end,
    profile = function(label, func)
        if _isTimersActive then
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
    xpHandler = function(error)
        if not(_isExtendedLogActive) then return end
        print('lolloArrivalsDeparturesPredictor INFO:') debugPrint(error)
    end,
    xpWarningHandler = function(error)
        if not(_isWarningLogActive) then return end
        print('lolloArrivalsDeparturesPredictor WARNING:') debugPrint(error)
    end,
    xpErrorHandler = function(error)
        if not(_isErrorLogActive) then return end
        print('lolloArrivalsDeparturesPredictor ERROR:') debugPrint(error)
    end,
}
