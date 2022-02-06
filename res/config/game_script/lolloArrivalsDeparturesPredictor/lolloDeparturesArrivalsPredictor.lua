
local stateManager = require "lolloArrivalsDeparturesPredictor/stateHelpers"
local workerEngine = require "lolloArrivalsDeparturesPredictor/workerEngine"
local guiEngine = require "lolloArrivalsDeparturesPredictor/guiEngine"


function data()
    return {
        save = function()
            return stateManager.getState()
        end,

        load = function(loadedstate)
            stateManager.loadState(loadedstate)
        end,

        update = function()
            workerEngine.update()
        end,

        handleEvent = function(src, id, name, param)
            workerEngine.handleEvent(src, id, name, param)
        end,

        guiHandleEvent = function(id, name, param)
            guiEngine.handleEvent(id, name, param)
        end,
    }
end
