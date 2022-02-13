local constructionConfigs = require ("lolloArrivalsDeparturesPredictor.constructionConfigs")
local constants = require('lolloArrivalsDeparturesPredictor.constants')
local edgeUtils = require('lolloArrivalsDeparturesPredictor.edgeUtils')
local guiHelpers = require('lolloArrivalsDeparturesPredictor.guiHelpers')
local logger = require('lolloArrivalsDeparturesPredictor.logger')
local stateHelpers = require ("lolloArrivalsDeparturesPredictor.stateHelpers")
local stationHelpers = require('lolloArrivalsDeparturesPredictor.stationHelpers')
local transfUtils = require('lolloArrivalsDeparturesPredictor.transfUtils')
local transfUtilsUG = require('transf')


-- LOLLO NOTE that the state must be read-only here coz we are in the GUI thread

local function _sendScriptEvent(name, args)
    api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
        string.sub(debug.getinfo(1, 'S').source, 1), constants.eventId, name, args)
    )
end

local function _joinSignBase(signConId, id)
    _sendScriptEvent(
        constants.events.join_sign_to_station_group,
        {
            signConId = signConId,
            stationGroupId = id,
        }
    )
end

local function _tryJoinSign(signConId, tentativeObjectId)
    if not(edgeUtils.isValidAndExistingId(signConId)) then return false end

    local con = api.engine.getComponent(signConId, api.type.ComponentType.CONSTRUCTION)
    -- if con ~= nil then logger.print('con.fileName =') logger.debugPrint(con.fileName) end
    if con == nil or con.transf == nil then return false end

    local signTransf_c = con.transf
    if signTransf_c == nil then return false end

    local signTransf_lua = transfUtilsUG.new(signTransf_c:cols(0), signTransf_c:cols(1), signTransf_c:cols(2), signTransf_c:cols(3))
    if signTransf_lua == nil then return false end

    -- logger.print('signTransf_lua =') logger.debugPrint(signTransf_lua)
    local nearbyObjects = stationHelpers.getNearbyStationGroups(signTransf_lua, constants.searchRadius4NearbyStation2JoinMetres, false)
    logger.print('_tryJoinSign running, #nearbyObjects =', #nearbyObjects)
    -- logger.print('nearbyObjects =') logger.debugPrint(nearbyObjects)
    if #nearbyObjects == 0 then
        guiHelpers.showWarningWindowWithMessage(_('CannotFindStationToJoin'))
        return false
    elseif #nearbyObjects == 1 then
        _joinSignBase(signConId, nearbyObjects[1].id)
    else
        table.sort(nearbyObjects, function(a, b) return a.name < b.name end)
        guiHelpers.showNearbyObjectPicker(
            nearbyObjects,
            transfUtils.transf2Position(signTransf_lua),
            tentativeObjectId,
            function(objectId)
                _joinSignBase(signConId, objectId)
            end
        )
    end
    return true
end

local function handleEvent(id, name, args)
    if name == 'select' then
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') logger.debugPrint(args)
        if not(args) or not(edgeUtils.isValidAndExistingId(args)) then return end -- probably redundant

        local con = api.engine.getComponent(args, api.type.ComponentType.CONSTRUCTION)
        if not(con) or not(con.fileName) then return end

        local config = constructionConfigs.get()[con.fileName]
        if not(config) then return end

        xpcall(
            function()
                local _state = stateHelpers.getState()
                local stationGroupId = (_state.placed_signs and _state.placed_signs[args]) and _state.placed_signs[args].stationGroupId or nil
                if stationGroupId then return end

                _tryJoinSign(args, stationGroupId) -- args here is the sign construction id
            end,
            logger.xpErrorHandler
        )
    elseif id == 'constructionBuilder' and name == 'builder.apply' then
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') -- logger.debugPrint(args)
        -- logger.print('construction.get() =') logger.debugPrint(construction.get())

        if args and args.proposal then
            local _toAdd = args.proposal.toAdd
            if _toAdd and _toAdd[1] then
                local _config = constructionConfigs.get()[_toAdd[1].fileName]
                -- logger.print('_config =') logger.debugPrint(_config)
                if _config and args.result and args.result[1] then
                    xpcall(
                        function()
                            _tryJoinSign(args.result[1])
                        end,
                        logger.xpErrorHandler
                    )
                end
            end

            local _toRemove = args.proposal.toRemove
            if _toRemove and _toRemove[1] then
                local _state = stateHelpers.getState()
                if _state and _state.placed_signs and _state.placed_signs[_toRemove[1]] then
                    -- logger.print('remove_display_construction for con id =', _toRemove[1])
                    _sendScriptEvent(constants.events.remove_display_construction, {signConId = _toRemove[1]})
                end
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

        if args and args.proposal and args.proposal.toRemove and args.proposal.toRemove[1] then
            local _signConId = args.proposal.toRemove[1]
            local _state = stateHelpers.getState()
            if _state and _state.placed_signs and _state.placed_signs[_signConId] then
                -- logger.print('remove_display_construction for con id =', toRemove[1])
                _sendScriptEvent(constants.events.remove_display_construction, {signConId = _signConId})
            end
        end
    -- else
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') logger.debugPrint(args)
    end
end

local function guiInit()
    local _state = stateHelpers.getState()
    if not(_state) then
        logger.err('cannot read state at guiInit')
        return
    end

    guiHelpers.initNotausButton(
        _state.is_on,
        function(isOn)
            _sendScriptEvent(constants.events.toggle_notaus, isOn)
        end
    )
end

return {
    guiInit = guiInit,
    handleEvent = handleEvent,
}
