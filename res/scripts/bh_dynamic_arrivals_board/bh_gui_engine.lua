-- State is pretty much read-only here
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local construction = require "bh_dynamic_arrivals_board/bh_construction_hooks"
local arrayUtils = require('bh_dynamic_arrivals_board.arrayUtils')
local constants = require('bh_dynamic_arrivals_board.constants')
local edgeUtils = require('bh_dynamic_arrivals_board.edgeUtils')
local guiHelpers = require('bh_dynamic_arrivals_board.guiHelpers')
local logger = require('bh_dynamic_arrivals_board.bh_log')
local stringUtils = require('bh_dynamic_arrivals_board.stringUtils')
local transfUtils = require('bh_dynamic_arrivals_board.transfUtils')
local transfUtilsUG = require('transf')


local _constants = {
  searchRadius4NearbyStation2Join = 50,
}

local function getNearbyStationCons(transf, searchRadius, isOnlyPassengers)
  if type(transf) ~= 'table' then return {} end
  if tonumber(searchRadius) == nil then searchRadius = _constants.searchRadius4NearbyStation2Join end

  -- LOLLO NOTE in the game and in this mod, there is one train station for each station group
  -- and viceversa. Station groups hold some information that stations don't, tho.
  -- Multiple station groups can share a construction.
  -- What I really want here is a list with one item each construction, but that could be an expensive loop,
  -- so I check the stations instead and index by the construction.

  local _stationIds = {}
  local _edgeIds = edgeUtils.getNearbyObjectIds(transf, 50, api.type.ComponentType.BASE_EDGE_TRACK)
  for key, edgeId in pairs(_edgeIds) do
    local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(edgeId)
    if edgeUtils.isValidAndExistingId(conId) then
      local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
      if con then
        local conStationIds = con.stations
        for _, stationId in pairs(conStationIds) do
          arrayUtils.addUnique(_stationIds, stationId)
        end
      end
    end
  end
  -- logger.print('_stationIds =') logger.debugPrint(_stationIds)

  -- local _stationIds = edgeUtils.getNearbyObjectIds(transf, searchRadius, api.type.ComponentType.STATION)
  local _station2ConstructionMap = api.engine.system.streetConnectorSystem.getStation2ConstructionMap()
  local _resultsIndexed = {}
  for _, stationId in pairs(_stationIds) do
      if edgeUtils.isValidAndExistingId(stationId) then
          local conId = _station2ConstructionMap[stationId]
          if edgeUtils.isValidAndExistingId(conId) then
              -- logger.print('getNearbyFreestyleStationsList has found conId =', conId)
              local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
              -- if con ~= nil and type(con.fileName) == 'string' and con.fileName == _constants.stationConFileName then
              -- logger.print('construction.name =') logger.debugPrint(con.name) -- nil
              local isCargo = api.engine.getComponent(stationId, api.type.ComponentType.STATION).cargo or false
              -- logger.print('isCargo =', isCargo)
              -- logger.print('isOnlyPassengers =', isOnlyPassengers)
              if not(isCargo) or not(isOnlyPassengers) then
                  local stationGroupId = api.engine.system.stationGroupSystem.getStationGroup(stationId)
                  local name = ''
                  local stationGroupName = api.engine.getComponent(stationGroupId, api.type.ComponentType.NAME)
                  if stationGroupName ~= nil then name = stationGroupName.name end

                  local isTwinCargo = false
                  local isTwinPassenger = false

                  if _resultsIndexed[conId] ~= nil then
                      -- logger.print('found a twin, it is') logger.debugPrint(resultsIndexed[conId])
                      if stringUtils.isNullOrEmptyString(name) then
                          name = _resultsIndexed[conId].name or ''
                      end
                      if _resultsIndexed[conId].isCargo then isTwinCargo = true end
                      if _resultsIndexed[conId].isPassenger then isTwinPassenger = true end
                  end
                  local position = transfUtils.transf2Position(
                      transfUtilsUG.new(con.transf:cols(0), con.transf:cols(1), con.transf:cols(2), con.transf:cols(3))
                  )
                  _resultsIndexed[conId] = {
                      id = conId,
                      isCargo = isCargo or isTwinCargo,
                      isPassenger = not(isCargo) or isTwinPassenger,
                      name = name,
                      position = position
                  }
              end
              -- end
          end
      end
  end

  -- logger.print('resultsIndexed =') logger.debugPrint(_resultsIndexed)
  local results = {}
  for _, value in pairs(_resultsIndexed) do
      results[#results+1] = value
  end
  -- logger.print('# nearby freestyle stations = ', #results)
  -- logger.print('nearby freestyle stations = ') logger.debugPrint(results)
  return results
end

local function sendScriptEvent(id, name, args)
  api.cmd.sendCommand(api.cmd.make.sendScriptEvent(constants.eventSources.bh_gui_engine, id, name, args))
end

local function joinBoardBase(boardConstructionId, stationConId)
  local eventArgs = {
    boardConstructionId = boardConstructionId,
    stationConId = stationConId
  }
  sendScriptEvent(constants.eventId, constants.events.join_board_to_station, eventArgs)
end

local function tryJoinBoard(boardConstructionId, tentativeStationConId)
  if not(edgeUtils.isValidAndExistingId(boardConstructionId)) then return false end

  local con = api.engine.getComponent(boardConstructionId, api.type.ComponentType.CONSTRUCTION)
  -- if con ~= nil then logger.print('con.fileName =') logger.debugPrint(con.fileName) end
  if con == nil or con.transf == nil then return false end

  local boardTransf_c = con.transf
  if boardTransf_c == nil then return false end

  local boardTransf_lua = transfUtilsUG.new(boardTransf_c:cols(0), boardTransf_c:cols(1), boardTransf_c:cols(2), boardTransf_c:cols(3))
  if boardTransf_lua == nil then return false end

  -- logger.print('conTransf =') logger.debugPrint(boardTransf_lua)
  local nearbyStationCons = getNearbyStationCons(boardTransf_lua, _constants.searchRadius4NearbyStation2Join, true)
  -- logger.print('#nearbyStationCons =', #nearbyStationCons)
  if #nearbyStationCons == 0 then
    guiHelpers.showWarningWindowWithMessage(_('CannotFindStationToJoin'))
    return false
  elseif #nearbyStationCons == 1 then
    joinBoardBase(boardConstructionId, nearbyStationCons[1].id)
  else
    guiHelpers.showNearbyStationPicker(
      true, -- passenger or cargo station
      nearbyStationCons,
      tentativeStationConId,
      function(stationConId)
        joinBoardBase(boardConstructionId, stationConId)
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

        local config = construction.getRegisteredConstructions()[con.fileName]
        -- logger.print('conProps =') logger.debugPrint(config)
        if not(config) then return end

        local state = stateManager.getState()
        local stationConId = (state.placed_signs and state.placed_signs[args]) and state.placed_signs[args].stationConId or nil
        tryJoinBoard(args, stationConId) -- args here is the construction id
    elseif id == 'constructionBuilder' and name == 'builder.apply' then
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') -- logger.debugPrint(args)
        -- logger.print('construction.getRegisteredConstructions() =') logger.debugPrint(construction.getRegisteredConstructions())
        if args and args.proposal then
            local toAdd = args.proposal.toAdd
            if toAdd and toAdd[1] then
              local config = construction.getRegisteredConstructions()[toAdd[1].fileName]
              -- logger.print('conProps =') logger.debugPrint(config)
              if config and args.result and args.result[1] then
                tryJoinBoard(args.result[1])
              end
            end

            local toRemove = args.proposal.toRemove
            local state = stateManager.getState()
            if toRemove and toRemove[1] and state.placed_signs[toRemove[1]] then
                -- logger.print('remove_display_construction for con id =', toRemove[1])
                sendScriptEvent(constants.eventId, constants.events.remove_display_construction, {boardConstructionId = toRemove[1]}) -- args.result[1] is the construction id
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
              sendScriptEvent(constants.eventId, constants.events.remove_display_construction, {boardConstructionId = toRemove[1]}) -- args.result[1] is the construction id
          end
      end
    -- else
        -- logger.print('LOLLO caught gui event, id = ', id, ' name = ', name, ' args = ') logger.debugPrint(args)
    end
end

return {
    handleEvent = handleEvent
}
