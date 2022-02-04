local persistent_state = {}

local function ensureState()
    if persistent_state.world_time == nil then
        persistent_state.world_time = 0
    end

    if persistent_state.placed_signs == nil then
        persistent_state.placed_signs = {}
    end
end

local function loadState(state)
    if state then
        persistent_state = state
    end

    ensureState()

    return persistent_state
end

local function getState()
    return persistent_state
end

local function removePlacedSign(key)
    if not(key) or not(persistent_state.placed_signs) then
        print('bh_dynamic_arrivals_board ERROR: cannot remove state element')
        return
    end

    persistent_state.placed_signs[key] = nil
end

local function setPlacedSign(key, value)
    if not(key) and not(value) then return end

    if persistent_state.placed_signs == nil then
        print('bh_dynamic_arrivals_board WARNING no state while setting a state element')
        persistent_state.placed_signs = {}
    end
    persistent_state.placed_signs[key] = value
end

return {
    loadState = loadState,
    getState = getState,
    ensureState = ensureState,
    removePlacedSign = removePlacedSign,
    setPlacedSign = setPlacedSign,
}
