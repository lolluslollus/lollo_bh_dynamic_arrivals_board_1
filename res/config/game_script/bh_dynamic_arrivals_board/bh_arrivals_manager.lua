
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local engine = require "bh_dynamic_arrivals_board/bh_engine"
local guiEngine = require "bh_dynamic_arrivals_board/bh_gui_engine"

-- ensure state default structure matches across all states during load / new game
stateManager.ensureState()

local function _myErrorHandler(error)
    print('bh_dynamic_arrivals_board ERROR') debugPrint(error)
end

function data()
    return {
        save = function()
            return stateManager.getState()
        end,

        load = function(loadedstate)
            stateManager.loadState(loadedstate)
        end,

        update = function()
            xpcall(engine.update, _myErrorHandler)
        end,

        handleEvent = function(src, id, name, param)
            xpcall(function() engine.handleEvent(src, id, name, param) end, _myErrorHandler)
        end,

        guiHandleEvent = function(id, name, param)
            xpcall(function() guiEngine.handleEvent(id, name, param) end, _myErrorHandler)
        end,
    }
end
