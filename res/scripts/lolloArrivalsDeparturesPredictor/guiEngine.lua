-- NOTE that the state must be read-only here coz we are in the GUI thread
local constructionHooks = require ("lolloArrivalsDeparturesPredictor.constructionHooks")
local constants = require('lolloArrivalsDeparturesPredictor.constants')
local edgeUtils = require('lolloArrivalsDeparturesPredictor.edgeUtils')
local guiHelpers = require('lolloArrivalsDeparturesPredictor.guiHelpers')
local logger = require('lolloArrivalsDeparturesPredictor.logger')
local stateHelpers = require ("lolloArrivalsDeparturesPredictor.stateHelpers")
local stationHelpers = require('lolloArrivalsDeparturesPredictor.stationHelpers')
local transfUtilsUG = require('transf')


local function _sendScriptEvent(id, name, args)
    api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
        string.sub(debug.getinfo(1, 'S').source, 1), id, name, args)
    )
end

local function joinSignBase(signConId, stationConId)
    local eventArgs = {
        signConId = signConId,
        stationConId = stationConId
    }
    _sendScriptEvent(constants.eventId, constants.events.join_sign_to_station, eventArgs)
end

local function tryJoinSign(signConId, tentativeStationConId)
    if not(edgeUtils.isValidAndExistingId(signConId)) then return false end

    local con = api.engine.getComponent(signConId, api.type.ComponentType.CONSTRUCTION)
    -- if con ~= nil then logger.print('con.fileName =') logger.debugPrint(con.fileName) end
    if con == nil or con.transf == nil then return false end

    local signTransf_c = con.transf
    if signTransf_c == nil then return false end

    local signTransf_lua = transfUtilsUG.new(signTransf_c:cols(0), signTransf_c:cols(1), signTransf_c:cols(2), signTransf_c:cols(3))
    if signTransf_lua == nil then return false end

    -- logger.print('conTransf =') logger.debugPrint(signTransf_lua)
    local nearbyStationCons = stationHelpers.getNearbyStationCons(signTransf_lua, constants.searchRadius4NearbyStation2JoinMetres, true)
    -- logger.print('#nearbyStationCons =', #nearbyStationCons)
    if #nearbyStationCons == 0 then
        guiHelpers.showWarningWindowWithMessage(_('CannotFindStationToJoin'))
        return false
    elseif #nearbyStationCons == 1 then
        joinSignBase(signConId, nearbyStationCons[1].id)
    else
        guiHelpers.showNearbyStationPicker(
            true, -- pick passenger or cargo stations
            nearbyStationCons,
            tentativeStationConId,
            function(stationConId)
                joinSignBase(signConId, stationConId)
            end
        )
    end
    return true
end

local function handleEvent(id, name, args)
    if name == 'select' then -- this never really fires coz these things are hard to select
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') logger.debugPrint(args)
        -- logger.print('construction.getRegisteredConstructions() =') logger.debugPrint(construction.getRegisteredConstructions())
        -- if not(api.engine.entityExists(args)) then return end -- probably redundant

        local con = api.engine.getComponent(args, api.type.ComponentType.CONSTRUCTION)
        if not(con) or not(con.fileName) then return end

        local config = constructionHooks.getRegisteredConstructions()[con.fileName]
        -- logger.print('conProps =') logger.debugPrint(config)
        if not(config) then return end

        xpcall(
            function()
                local state = stateHelpers.getState()
                -- logger.print('state =') logger.debugPrint(state)
                local stationConId = (state.placed_signs and state.placed_signs[args]) and state.placed_signs[args].stationConId or nil
                if stationConId then return end

                tryJoinSign(args, stationConId) -- args here is the construction id
            end,
            logger.errorHandler
        )
    elseif id == 'constructionBuilder' and name == 'builder.apply' then
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') -- logger.debugPrint(args)
        -- logger.print('construction.getRegisteredConstructions() =') logger.debugPrint(construction.getRegisteredConstructions())
        if args and args.proposal then
            local toAdd = args.proposal.toAdd
            if toAdd and toAdd[1] then
                local config = constructionHooks.getRegisteredConstructions()[toAdd[1].fileName]
                -- logger.print('conProps =') logger.debugPrint(config)
                if config and args.result and args.result[1] then
                    xpcall(
                        function()
                            tryJoinSign(args.result[1])
                        end,
                        logger.errorHandler
                    )
                end
            end

            local toRemove = args.proposal.toRemove
            local state = stateHelpers.getState()
            if toRemove and toRemove[1] and state.placed_signs[toRemove[1]] then
                -- logger.print('remove_display_construction for con id =', toRemove[1])
                _sendScriptEvent(constants.eventId, constants.events.remove_display_construction, {signConId = toRemove[1]})
            end
        end
    elseif id == 'bulldozer' and name == 'builder.apply' then
        -- LOLLO NOTE when bulldozing with the game unpaused,
        -- the yes / no dialogue will disappear as soon as the construction is rebuilt.
        -- This is inevitable;
        -- still, if the user is quick enough and the updatte frequency is low enough,
        -- there will be a chance to bulldoze.
        -- LOLLO renaming the constructions instead of rebuilding them at every tick
        -- may be quicker, and it is easy to bulldoze. I checked it: construction can take very long names.
        -- I tried 20480 characters or more, that will do.
        -- The only drawback is, when hovering they show a long tooltip - with one row only, luckily.
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') -- logger.debugPrint(args)
        -- logger.print('construction.getRegisteredConstructions() =') logger.debugPrint(construction.getRegisteredConstructions())
        if args and args.proposal and args.proposal.toRemove and args.proposal.toRemove[1] then
            local signConId = args.proposal.toRemove[1]
            local state = stateHelpers.getState()
            if state.placed_signs[signConId] then
                -- logger.print('remove_display_construction for con id =', toRemove[1])
                _sendScriptEvent(constants.eventId, constants.events.remove_display_construction, {signConId = signConId})
            end
        end
    -- else
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') logger.debugPrint(args)
    end
end

return {
    handleEvent = handleEvent
}
