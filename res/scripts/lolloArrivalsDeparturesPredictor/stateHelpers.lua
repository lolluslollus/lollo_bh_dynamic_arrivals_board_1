local logger = require('lolloArrivalsDeparturesPredictor.logger')

local persistent_state = {}

local _initState = function()
    if persistent_state.world_time_sec == nil then
        persistent_state.world_time_sec = 0
    end

    if persistent_state.placed_signs == nil then
        persistent_state.placed_signs = {}
    end

    if persistent_state.is_on == nil then
        persistent_state.is_on = false
    end
end

local funcs = {
    initState = _initState,
    loadState = function(state)
        if state then
            persistent_state = state
        end

        _initState()
    end,
    getState = function()
        return persistent_state
    end,
    removePlacedSign = function(key)
        if not(key) or not(persistent_state.placed_signs) then
            logger.err('cannot remove placed_signs with key '.. (key or 'NIL') ..' from state')
            logger.errorDebugPrint(persistent_state)
            return
        end

        persistent_state.placed_signs[key] = nil
    end,
    saveState = function()
        _initState()
        return persistent_state
    end,
    setPlacedSign = function(key, value)
        if not(key) then return end

        if persistent_state.placed_signs == nil then
            logger.warn('no placed_signs during setPlacedSign()')
            _initState()
        end
        persistent_state.placed_signs[key] = value
    end,
}

_initState() -- fires when loading

return funcs
