local persistent_state = {}

local _initState = function()
    if persistent_state.world_time == nil then
        persistent_state.world_time = 0
    end

    if persistent_state.placed_signs == nil then
        persistent_state.placed_signs = {}
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
            print('lolloArrivalsDeparturesPredictor ERROR: cannot remove state element')
            return
        end

        persistent_state.placed_signs[key] = nil
    end,
    saveState = function()
        _initState()
        return persistent_state
    end,
    setPlacedSign = function(key, value)
        if not(key) and not(value) then return end

        if persistent_state.placed_signs == nil then
            print('lolloArrivalsDeparturesPredictor WARNING no state while setting a state element')
            persistent_state.placed_signs = {}
        end
        persistent_state.placed_signs[key] = value
    end,
}

_initState() -- fires when loading

return funcs
