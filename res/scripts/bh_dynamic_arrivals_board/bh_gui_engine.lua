-- NOTE that the state must be read-only here coz we are in the GUI thread
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local constructionHooks = require "bh_dynamic_arrivals_board/bh_construction_hooks"
local constants = require('bh_dynamic_arrivals_board.constants')
local edgeUtils = require('bh_dynamic_arrivals_board.edgeUtils')
local guiHelpers = require('bh_dynamic_arrivals_board.guiHelpers')
local logger = require('bh_dynamic_arrivals_board.bh_log')
local stationUtils = require('bh_dynamic_arrivals_board.stationUtils')
local transfUtilsUG = require('transf')


local function sendScriptEvent(id, name, args)
  api.cmd.sendCommand(api.cmd.make.sendScriptEvent(constants.eventSources.bh_gui_engine, id, name, args))
end

local function joinSignBase(signConId, stationConId)
  local eventArgs = {
    signConId = signConId,
    stationConId = stationConId
  }
  sendScriptEvent(constants.eventId, constants.events.join_sign_to_station, eventArgs)
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
  local nearbyStationCons = stationUtils.getNearbyStationCons(signTransf_lua, constants.searchRadius4NearbyStation2Join, true)
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
        if not(con) then return end

        local config = constructionHooks.getRegisteredConstructions()[con.fileName]
        -- logger.print('conProps =') logger.debugPrint(config)
        if not(config) then return end

        local state = stateManager.getState()
        -- logger.print('state =') logger.debugPrint(state)
        local stationConId = (state.placed_signs and state.placed_signs[args]) and state.placed_signs[args].stationConId or nil
        tryJoinSign(args, stationConId) -- args here is the construction id
    elseif id == 'constructionBuilder' and name == 'builder.apply' then
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') -- logger.debugPrint(args)
        -- logger.print('construction.getRegisteredConstructions() =') logger.debugPrint(construction.getRegisteredConstructions())
        if args and args.proposal then
            local toAdd = args.proposal.toAdd
            if toAdd and toAdd[1] then
              local config = constructionHooks.getRegisteredConstructions()[toAdd[1].fileName]
              -- logger.print('conProps =') logger.debugPrint(config)
              if config and args.result and args.result[1] then
                tryJoinSign(args.result[1])
              end
            end

            local toRemove = args.proposal.toRemove
            local state = stateManager.getState()
            if toRemove and toRemove[1] and state.placed_signs[toRemove[1]] then
                -- logger.print('remove_display_construction for con id =', toRemove[1])
                sendScriptEvent(constants.eventId, constants.events.remove_display_construction, {signConId = toRemove[1]})
            end
        end
    elseif id == 'bulldozer' and name == 'builder.apply' then
      -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') -- logger.debugPrint(args)
      -- logger.print('construction.getRegisteredConstructions() =') logger.debugPrint(construction.getRegisteredConstructions())
      if args and args.proposal then
          local toRemove = args.proposal.toRemove
          local state = stateManager.getState()
          if toRemove and toRemove[1] and state.placed_signs[toRemove[1]] then
              -- logger.print('remove_display_construction for con id =', toRemove[1])
              sendScriptEvent(constants.eventId, constants.events.remove_display_construction, {signConId = toRemove[1]})
          end
      end
    -- else
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') logger.debugPrint(args)
    end
end

return {
    handleEvent = handleEvent
}
