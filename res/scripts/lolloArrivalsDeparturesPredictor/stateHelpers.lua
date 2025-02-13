local logger = require('lolloArrivalsDeparturesPredictor.logger')

---@alias nearest_terminal_streetside {isMultiStationGroup: true, refPosition123: table<integer>}
---@alias nearest_terminal_generic {cargo: boolean, distance: number, terminalId: integer, terminalTag: integer}
---@alias placed_sign {stationGroupId: integer, nearestTerminal: nearest_terminal_generic|nearest_terminal_streetside|nil}
---@alias state {gameTime_msec: integer, is_on: boolean, placed_signs: table<integer, placed_sign>}

---@type state
local persistent_state = {}

local _initState = function()
    if persistent_state.gameTime_msec == nil then
        persistent_state.gameTime_msec = 0
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
    ---@param state state
    loadState = function(state)
        if state then
            persistent_state = state
        end

        _initState()
    end,
    ---@return state
    getState = function()
        return persistent_state
    end,
    ---@param key integer
    removePlacedSign = function(key)
        if not(key) or not(persistent_state.placed_signs) then
            logger.err('cannot remove placed_signs with key '.. tostring(key) ..' from state')
            logger.errorDebugPrint(persistent_state)
            return
        end

        persistent_state.placed_signs[key] = nil
    end,
    saveState = function()
        _initState()
        return persistent_state
    end,
    ---@param key integer
    ---@param value placed_sign
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
