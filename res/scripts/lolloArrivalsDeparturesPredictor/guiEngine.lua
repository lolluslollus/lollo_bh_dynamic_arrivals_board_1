local constructionConfigs = require ("lolloArrivalsDeparturesPredictor.constructionConfigs")
local constants = require('lolloArrivalsDeparturesPredictor.constants')
local edgeUtils = require('lolloArrivalsDeparturesPredictor.edgeUtils')
local guiHelpers = require('lolloArrivalsDeparturesPredictor.guiHelpers')
local logger = require('lolloArrivalsDeparturesPredictor.logger')
local soundeffectsutil = require('soundeffectsutil')
-- local soundEffectsUtilOverride = require('lolloArrivalsDeparturesPredictor.soundEffectsUtilOverride')
local stateHelpers = require ("lolloArrivalsDeparturesPredictor.stateHelpers")
local stationHelpers = require('lolloArrivalsDeparturesPredictor.stationHelpers')
local stringUtils = require('lolloArrivalsDeparturesPredictor.stringUtils')
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

local function _tryJoinSign(signConId, tentativeStationGroupId)
    if not(edgeUtils.isValidAndExistingId(signConId)) then return false end

    local con = api.engine.getComponent(signConId, api.type.ComponentType.CONSTRUCTION)
    -- if con ~= nil then logger.print('con.fileName =') logger.debugPrint(con.fileName) end
    if con == nil or con.transf == nil then return false end

    local signTransf_c = con.transf
    if signTransf_c == nil then return false end

    local signTransf_lua = transfUtilsUG.new(signTransf_c:cols(0), signTransf_c:cols(1), signTransf_c:cols(2), signTransf_c:cols(3))
    if signTransf_lua == nil then return false end

    -- logger.print('signTransf_lua =') logger.debugPrint(signTransf_lua)
    local nearbyStationGroups = stationHelpers.getNearbyStationGroups(signTransf_lua, constants.searchRadius4NearbyStation2JoinMetres, false)
    logger.print('_tryJoinSign running, #nearbyStationGroups =', #nearbyStationGroups)
    if #nearbyStationGroups == 0 then
        guiHelpers.showWarningWindowWithMessage(_('CannotFindStationToJoin'))
        return false
    elseif #nearbyStationGroups == 1 then
        _joinSignBase(signConId, nearbyStationGroups[1].id)
    else
        table.sort(nearbyStationGroups, function(a, b) return a.name < b.name end)
        guiHelpers.showNearbyObjectPicker(
            nearbyStationGroups,
            transfUtils.transf2Position(signTransf_lua),
            tentativeStationGroupId,
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

        -- if not(soundeffectsutil.get('lolloArrivalsDeparturesPredictor_test')) then
        --     print('### about to call override')
        --     soundEffectsUtilOverride()
        --     print('### soundeffectsutil.get(\'lolloArrivalsDeparturesPredictor_test\') = ') debugPrint(soundeffectsutil.get('lolloArrivalsDeparturesPredictor_test'))
        -- end
        print('### about to play effects')
        -- api.gui.util.getGameUI():playSoundEffect("lolloArrivalsDeparturesPredictor/car_idle") -- does nowt
        -- api.gui.util.getGameUI():playSoundEffect("lolloArrivalsDeparturesPredictor/car_horn") -- does nowt
        -- api.gui.util.getGameUI():playSoundEffect("lolloArrivalsDeparturesPredictor_car_idle") -- does nowt
        -- api.gui.util.getGameUI():playSoundEffect("lolloArrivalsDeparturesPredictor_car_horn") -- does nowt
        -- api.gui.util.getGameUI():playSoundEffect("construct") -- works because this effect comes with the game
        -- api.gui.util.getGameUI():playTrack('lolloArrivalsDeparturesPredictor/car_idle.wav', 0.0) -- this starts the music but does not play my effect
        -- api.gui.util.getGameUI():playTrack('lolloArrivalsDeparturesPredictor/car_horn.wav', 0.0) -- this starts the music but does not play my effect
        -- api.gui.util.getGameUI():playCutscene("lolloArrivalsDeparturesPredictor/car_horn.wav") -- does nowt
        local config = constructionConfigs.get()[con.fileName]
        if not(config) then return end

        xpcall(
            function()
                local _state = stateHelpers.getState()
                local stationGroupId = (_state.placed_signs and _state.placed_signs[args]) and _state.placed_signs[args].stationGroupId or nil
                if edgeUtils.isValidAndExistingId(stationGroupId) then return end

                _tryJoinSign(args, stationGroupId) -- args here is the sign construction id
            end,
            logger.xpErrorHandler
        )
    elseif id == 'constructionBuilder' and name == 'builder.apply' then
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') -- logger.debugPrint(args)

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
        -- still, if the user is quick enough and the update frequency is low enough,
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
    elseif name == 'destroy' and type(id) == 'string' and stringUtils.stringStartsWith(id, 'temp.addModuleComp.params.entity_') then
        -- logger.print('### destroy fired, id = ' .. id)
        local conId = tonumber(id:sub(34), 10)
        if not(edgeUtils.isValidAndExistingId(conId)) then return end

        local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
        logger.print('config menu of conId ' .. tostring(conId) .. ' was closed')
        if con == nil or type(con.fileName) ~= 'string' then return end

        -- prevent a crash if loading a game when the con config menu is open.
        local _ingameMenu = api.gui.util.getById('ingameMenu')
        if _ingameMenu ~= nil and _ingameMenu:isVisible() then return end

        if stringUtils.stringContains(con.fileName, 'station/rail/') and con.stations ~= nil then
            -- logger.print('conId ' .. tostring(conId) .. ' is a train station')
            local stationGroupId = api.engine.system.stationGroupSystem.getStationGroup(con.stations[1])
            if not(edgeUtils.isValidAndExistingId(stationGroupId)) then return end

            local _state = stateHelpers.getState()
            if not(_state) or not(_state.placed_signs) then return end
            for signConId, signProps in pairs(_state.placed_signs) do
                if signProps.stationGroupId == stationGroupId then
                    logger.print('the con config menu was closed, about to send command refresh_sign_of_station_group, signConId = ' .. tostring(signConId) .. ', stationGroupId = ' .. tostring(stationGroupId))
                    _sendScriptEvent(
                        constants.events.refresh_sign_of_station_group,
                        {
                            signConId = signConId,
                            stationGroupId = stationGroupId,
                        }
                    )
                end
            end
        elseif stringUtils.stringContains(con.fileName, 'asset/lolloArrivalsDeparturesPredictor/') then
            -- logger.print('conId ' .. tostring(conId) .. ' is a dynamic display')
            local _state = stateHelpers.getState()
            if not(_state) or not(_state.placed_signs) or not(_state.placed_signs[conId]) then return end

            local stationGroupId = _state.placed_signs[conId].stationGroupId
            if not(edgeUtils.isValidAndExistingId(stationGroupId)) then return end

            logger.print('the display config menu was closed, about to send command refresh_sign_of_station_group, signConId = ' .. tostring(conId) .. ', stationGroupId = ' .. tostring(stationGroupId))
            _sendScriptEvent(
                constants.events.refresh_sign_of_station_group,
                {
                    signConId = conId,
                    stationGroupId = stationGroupId,
                }
            )
        end
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

    -- initSoundEffects()
end

return {
    guiInit = guiInit,
    handleEvent = handleEvent,
}
