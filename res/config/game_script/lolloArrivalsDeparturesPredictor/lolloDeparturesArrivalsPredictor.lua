
local stateHelpers = require "lolloArrivalsDeparturesPredictor/stateHelpers"
local workerEngine = require "lolloArrivalsDeparturesPredictor/workerEngine"
local guiEngine = require "lolloArrivalsDeparturesPredictor/guiEngine"


function data()
    return {
        save = function()
            return stateHelpers.getState()
        end,

        load = function(loadedstate)
            stateHelpers.loadState(loadedstate)
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
