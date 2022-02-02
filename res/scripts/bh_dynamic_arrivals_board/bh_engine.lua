local vec3 = require "vec3"

local bhm = require "bh_dynamic_arrivals_board/bh_maths"
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local construction = require "bh_dynamic_arrivals_board/bh_construction_hooks"

local log = require "bh_dynamic_arrivals_board/bh_log"
local arrayUtils = require('bh_dynamic_arrivals_board.arrayUtils')
local constants = require('bh_dynamic_arrivals_board.constants')
local edgeUtils = require('bh_dynamic_arrivals_board.edgeUtils')

local function getClosestTerminal(transform)
  local position = bhm.transformVec(vec3.new(0, 0, 0), transform)
  local radius = 50

  local box = api.type.Box3.new(
    api.type.Vec3f.new(position.x - radius, position.y - radius, -9999),
    api.type.Vec3f.new(position.x + radius, position.y + radius, 9999)
  )
  local results = {}
  api.engine.system.octreeSystem.findIntersectingEntities(box, function(entity, boundingVolume)
    if entity and api.engine.getComponent(entity, api.type.ComponentType.STATION) then
      results[#results+1] = entity
    end
  end)

  local shortestDistance = 9999
  local closestEntity
  local closestTerminal
  local closestStationGroup

  for _, entity in ipairs(results) do
    local station = api.engine.getComponent(entity, api.type.ComponentType.STATION)
    if station then
      local stationGroup = api.engine.system.stationGroupSystem.getStationGroup(entity)
      for k, v in pairs(station.terminals) do
        -- TODO - use positions of the person nodes on the termainl or something, as using vehicle node alone is prone to incorrect calcs (esp with varying length platforms)
        local nodeData = api.engine.getComponent(v.vehicleNodeId.entity, api.type.ComponentType.BASE_NODE)

        -- try getting a node from the edge if there is one
        if not nodeData then
          local edge = api.engine.getComponent(v.vehicleNodeId.entity, api.type.ComponentType.BASE_EDGE)
          --log.object("edge", edge)
          if edge then
            nodeData = api.engine.getComponent(edge.node0, api.type.ComponentType.BASE_NODE)
          end
        end

        -- if we couldn't get this node, need to fall back to station only...
        if not nodeData then
          local s2c = api.engine.system.streetConnectorSystem.getStation2ConstructionMap()
          local conId = s2c[entity]
          if conId then
            local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
            if con then
              local distance = vec3.distance(position, vec3.new(con.transf[13], con.transf[14], con.transf[15]))
              if distance < shortestDistance then
                shortestDistance = distance
                closestEntity = entity
                closestTerminal = 1
                closestStationGroup = stationGroup
              end
              log.message("Station " .. tostring(entity) .. " is " .. tostring(distance) .. "m away")
              break
            end
          end
        end

        if nodeData then
          local distance = vec3.distance(position, nodeData.position)
          if distance < shortestDistance then
            shortestDistance = distance
            closestEntity = entity
            closestTerminal = k - 1
            closestStationGroup = stationGroup
          end
          log.message("Terminal " .. tostring(k) .. " is " .. tostring(distance) .. "m away")
        end
      end
    end
  end

  if closestEntity then
    return { station = closestEntity, stationGroup = closestStationGroup, terminal = closestTerminal, auto = true }
  else
    return nil
  end
end

local function calculateLineStopTermini(line)
  local lineStops = line.stops
  local stops = {}
  local visitedStations = {}
  local legStart = 1

  local function setLegTerminus(start, length, terminus)
    for i = start, start + length - 1 do
      stops[i] = terminus
    end
  end

  for stopIndex, stop in ipairs(lineStops) do
    if visitedStations[stop.stationGroup] then
      setLegTerminus(legStart, stopIndex - 2, stopIndex - 1)
      legStart = stopIndex - 1
      visitedStations = {}
    end

    visitedStations[stop.stationGroup] = true
  end

  if legStart == 1 then
    log.print('ONE')
    -- route is direct (there are no repeated stops on the way back)
    setLegTerminus(legStart, #lineStops - legStart, #lineStops)
    stops[#lineStops] = 1
  else
    log.print('TWO')
    setLegTerminus(legStart, #lineStops - legStart + 1, 1)
  end
  return stops
end

local function calculateLineStopTermini4Station(line, stationGroupId, terminalIndexBase0)
  -- log.print('calculateLineStopTermini4Station starting, line =') log.debugPrint(line)
  local lineStops = line.stops
  local legStartIndex = 1
  for stopIndex, stop in ipairs(lineStops) do
    if stop.stationGroup == stationGroupId and stop.terminal == terminalIndexBase0 then
      legStartIndex = stopIndex
      break
    end
  end

  local stationVisits = {}
  for stopIndex, stop in ipairs(lineStops) do
    stationVisits[stop.stationGroup] = (stationVisits[stop.stationGroup] or 0) + 1
  end

  local legEndIndex = 0
  local i = legStartIndex + 1
  while i ~= legStartIndex do
    if i > #lineStops then i = i - #lineStops end
    if stationVisits[lineStops[i].stationGroup] == 1 then
      legEndIndex = i
      break
    end
    i = i + 1
  end

  if legEndIndex == 0 then
  -- good for circular lines
    legEndIndex = legStartIndex + math.ceil(#lineStops * 0.5)
    if legEndIndex > #lineStops then
      legEndIndex = legEndIndex - #lineStops
    end
  end

  -- just in case
  if legEndIndex == legStartIndex then
    if legEndIndex < #lineStops then legEndIndex = legEndIndex + 1
    else legEndIndex = 1
    end
  end

  -- log.print('legStartIndex, legEndIndex =', legStartIndex, legEndIndex)
  return legStartIndex, legEndIndex
end

local function calculateTimeUntilStop(vehicle, stopIdx, stopsAway, nStops, averageSectionTime, currentTime)
  local idx = (stopIdx - 2) % nStops + 1
  local segTotal = 0
  for _ = 1, stopsAway + 1 do
    local seg = vehicle.sectionTimes[idx]
    segTotal = segTotal + (seg or averageSectionTime)
    idx = (idx - 2) % nStops + 1
  end
  segTotal = segTotal * 1000

  local timeSinceLastDeparture = currentTime - vehicle.lineStopDepartures[idx % nStops + 1]
  return math.ceil(segTotal - timeSinceLastDeparture)
end

-- local selectedObject

--[[ 
  returns an array of tables that look like this:
  {
    terminalId = n,
    destination = stationGroup,
    arrivalTime = milliseconds,
    stopsAway = n
  }
  sorted in order of arrivalTime (earliest first)
]]
local function getNextArrivals(stationTerminal, numArrivals, time)
  -- despite how many we want to return, we actually need to look at every vehicle on every line stopping here before we can sort and trim
  local arrivals = {}

  if not stationTerminal then return arrivals end

  local lineStops
  if stationTerminal.terminal ~= nil then
    lineStops = api.engine.system.lineSystem.getLineStopsForTerminal(stationTerminal.station, stationTerminal.terminal)
  else
    lineStops = api.engine.system.lineSystem.getLineStopsForStation(stationTerminal.station)
  end
  
  if lineStops then
    local uniqueLines = {}
    for _, line in pairs(lineStops) do
      uniqueLines[line] = line
    end
    
    for _, line in pairs(uniqueLines) do
      local lineData = api.engine.getComponent(line, api.type.ComponentType.LINE)
      if lineData then
        local lineTermini = calculateLineStopTermini(lineData) -- this will eventually be done in a slower engine loop to save performance
        local terminalStopIndex = {}
        local nStops = #lineData.stops
        
        for stopIdx, stop in ipairs(lineData.stops) do
          if stop.stationGroup == stationTerminal.stationGroup and (stationTerminal.terminal == nil or stationTerminal.terminal == stop.terminal) then
            terminalStopIndex[stop.terminal] = stopIdx
          end
        end

        local vehicles = api.engine.system.transportVehicleSystem.getLineVehicles(line)
        if vehicles then
          for _, veh in ipairs(vehicles) do
            local vehicle = api.engine.getComponent(veh, api.type.ComponentType.TRANSPORT_VEHICLE)
            if vehicle then
              local lineDuration = 0
              for _, sectionTime in ipairs(vehicle.sectionTimes) do
                lineDuration = lineDuration + sectionTime
                if sectionTime == 0 then
                  lineDuration = 0
                  break -- early out if we dont have full line duration data. we need to calculate a different (less accurate) way
                end
              end

              --[[if selectedObject == veh then
                debugPrint({ terminals = terminalStopIndex, sectionTimes = vehicle.sectionTimes, stopDepartures = vehicle.lineStopDepartures })
              end]]

              -- local function blah(str, val)
              --   if selectedObject == veh then
              --     print(str .. " = " .. val)
              --   end
              -- end

              if lineDuration == 0 then
                -- vehicle hasn't run a full route yet, so fall back to less accurate (?) method
                -- calculate line duration by multiplying the number of vehicles by the line frequency
                local lineEntity = game.interface.getEntity(line)
                lineDuration = (1 / lineEntity.frequency) * #vehicles
              end

              -- and calculate an average section time by dividing by the number of stops
              local averageSectionTime = lineDuration / nStops

              --log.object("vehicle_" .. veh, vehicle)
              for terminalIdx, stopIdx in pairs(terminalStopIndex) do
                local stopsAway = (stopIdx - vehicle.stopIndex - 1) % nStops

                -- using lineStopDepartures[stopIdx] + lineDuration seems simple but requires at least one full loop and still isn't always correct if there's bunching.
                -- so instead, using stopsAway, add up the sectionTimes of the stops between there and here, and subtract the diff of now - stopsAway departure time.
                -- lastLineStopDeparture seems to be inaccurate.
                --local expectedArrivalTime = vehicle.lineStopDepartures[stopIdx] + math.ceil(lineDuration) * 1000

                local timeUntilArrival = calculateTimeUntilStop(vehicle, stopIdx, stopsAway, nStops, averageSectionTime, time)
                -- blah("[Stop " .. stopIdx .. "]: timeUntilArrival", timeUntilArrival)
                local expectedArrivalTime = time + timeUntilArrival

                arrivals[#arrivals+1] = {
                  terminalId = terminalIdx,
                  destination = lineData.stops[lineTermini[stopIdx]].stationGroup,
                  arrivalTime = expectedArrivalTime,
                  stopsAway = stopsAway
                }

                if #vehicles == 1 and lineDuration > 0 then
                  -- if there's only one vehicle, make a second arrival eta + an entire line duration
                  arrivals[#arrivals+1] = {
                    terminalId = terminalIdx,
                    destination = lineData.stops[lineTermini[stopIdx]].stationGroup,
                    arrivalTime = math.ceil(expectedArrivalTime + lineDuration * 1000),
                    stopsAway = stopsAway
                  }
                end
              end
            end
          end
        end
      end
    end
  end

  table.sort(arrivals, function(a, b) return a.arrivalTime < b.arrivalTime end)

  local ret = {}
  
  for i = 1, numArrivals do
    ret[#ret+1] = arrivals[i]
  end

  return ret
end

local function getAverageSectionTimeToDestinations(vehicles, nStops, fallbackLegDuration)
  local averages = {}

  for hereIndex = 1, nStops, 1 do
    local prevIndex = hereIndex - 1
    if prevIndex < 1 then prevIndex = prevIndex + nStops end

    local average, nVehicles4Average = 0, #vehicles
    for _, vehicleId in ipairs(vehicles) do
      local vehicle = api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE)
      if vehicle.sectionTimes[prevIndex] == 0 then
        nVehicles4Average = nVehicles4Average - 1
      else
        average = average + vehicle.sectionTimes[prevIndex]
      end
    end
    if nVehicles4Average > 0 then
      average = average / nVehicles4Average
    else
      average = fallbackLegDuration -- useful when starting a new line
    end

    averages[hereIndex] = math.ceil(average * 1000)
  end

  return averages
end

local function getNextArrivals4Station(stationId, numArrivals, time)
  -- log.print('getNextArrivals4Station starting')
  -- TODO We should make a twin construction for arrivals, this is for departures
  -- TODO if a terminal is skipped, for example 3, the display will show 3 instead of 4, 4 instead of 5, and so on
  -- This may have to do with the way the freestyle station works

  -- despite how many we want to return, we actually need to look at every vehicle on every line stopping here before we can sort and trim
  local arrivals = {}

  if not stationId then return arrivals end

  local stationGroupId = api.engine.system.stationGroupSystem.getStationGroup(stationId)
  -- log.print('stationGroupId =', stationGroupId)
  -- log.print('stationId =', stationId)
  local stationTerminals = api.engine.getComponent(stationId, api.type.ComponentType.STATION).terminals
  for terminalId, terminal in pairs(stationTerminals) do
    -- log.print('terminal.tag =', terminal.tag or 'NIL', ', terminalId =', terminalId or 'NIL')
    local lineIds = api.engine.system.lineSystem.getLineStopsForTerminal(stationId, terminal.tag)
    for _, lineId in pairs(lineIds) do
      -- log.print('lineId =', lineId or 'NIL')
      local lineData = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
      if lineData then
        local vehicles = api.engine.system.transportVehicleSystem.getLineVehicles(lineId)
        if #vehicles > 0 then
          local hereIndex, lineTerminusIndex = calculateLineStopTermini4Station(lineData, stationGroupId, terminal.tag) -- this will eventually be done in a slower engine loop to save performance
          local nStops = #lineData.stops
          -- local prevIndex = hereIndex - 1
          -- if prevIndex < 1 then prevIndex = prevIndex + nStops end
          -- log.print('hereIndex, prevIndex, nStops, lineTerminusIndex =', hereIndex, prevIndex, nStops, lineTerminusIndex)
          log.print('hereIndex, nStops, lineTerminusIndex =', hereIndex, nStops, lineTerminusIndex)

          -- Here, I average the times across all the trains on this line.
          -- If they are wildly different, which is stupid, this could be less accurate;
          -- otherwise, it will be more accurate.

          -- alternative calculation for line duration, I don't like mixing the old and the new api tho
          -- vehicle hasn't run a full route yet, so fall back to less accurate (?) method
          -- calculate line duration by multiplying the number of vehicles by the line frequency
          --   local lineEntity = game.interface.getEntity(lineId)
          --   lineDuration = (1 / lineEntity.frequency) * #vehicles
          local averageSectionTimeToDestinations = getAverageSectionTimeToDestinations(vehicles, nStops, lineData.waitingTime / nStops)
          log.print('averageSectionTimeToDestinations =') log.debugPrint(averageSectionTimeToDestinations)
          -- log.print('#averageSectionTimeToDestinations =', #averageSectionTimeToDestinations or 'NIL') -- ok
          -- log.print('time =', time)
          -- log.print('There are', #vehicles, 'vehicles')

          for _, vehicleId in ipairs(vehicles) do
            log.print('vehicleId =', vehicleId or 'NIL')
            local vehicle = api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE)
            -- vehicle has:
            -- stopIndex = 1, -- next stop index, base 0
            -- lineStopDepartures = { -- last recorded departure times, they can be 0 if not yet recorded
            --   [1] = 4591600,
            --   [2] = 4498000,
            -- },
            -- lastLineStopDeparture = 0, -- seems inaccurate
            -- sectionTimes = { -- take a while to calculate when starting a new line
            --   [1] = 0, -- time it took to complete a segment, starting from stop 1
            --   [2] = 86.600006103516, -- time it took to complete a segment, starting from stop 2
            -- },
            -- timeUntilLoad = -5.5633368492126, -- seems useless
            -- timeUntilCloseDoors = -0.19238702952862, -- seems useless
            -- timeUntilDeparture = -0.026386171579361, -- seems useless
            -- doorsTime = 4590600000, -- last departure time, seems OK
            -- and it is quicker than checking the max across lineStopDepartures
            -- we add 1000 so we match it to the highest lineStopDeparture, but it varies with the cargo => no

            -- log.print('vehicle.stopIndex =', vehicle.stopIndex)
            local stopsAway = (hereIndex - vehicle.stopIndex - 1)
            if stopsAway < 0 then stopsAway = stopsAway + nStops end
            -- log.print('stopsAway =', stopsAway or 'NIL')
            -- log.print('vehicle.doorsTime / 1000 + 1000', vehicle.doorsTime / 1000 + 1000)

            local lastDepartureTime = math.max(table.unpack(vehicle.lineStopDepartures))
            -- useful when starting a new line
            if lastDepartureTime == 0 then lastDepartureTime = time end

            local remainingTime = 0
            local destinationIndex = vehicle.stopIndex + 1 -- base 0 to base 1
            while destinationIndex ~= hereIndex do
              remainingTime = remainingTime + averageSectionTimeToDestinations[destinationIndex]
              destinationIndex = destinationIndex + 1
              if destinationIndex > nStops then destinationIndex = destinationIndex - nStops end
            end
            remainingTime = remainingTime + averageSectionTimeToDestinations[hereIndex]

            arrivals[#arrivals+1] = {
              terminalId = terminal.tag,
              destination = lineData.stops[lineTerminusIndex].stationGroup,
              arrivalTime = lastDepartureTime + remainingTime,
              stopsAway = stopsAway
            }

            if #vehicles == 1 and averageSectionTimeToDestinations > 0 then
              -- if there's only one vehicle, make a second arrival eta + an entire line duration
              arrivals[#arrivals+1] = {
                terminalId = terminal.tag,
                destination = lineData.stops[lineTerminusIndex].stationGroup,
                arrivalTime = lastDepartureTime + remainingTime + remainingTime,
                stopsAway = stopsAway
              }
            end
          end
        end
      end
    end
  end

  -- log.print('arrivals before sorting =') log.debugPrint(arrivals)
  table.sort(arrivals, function(a, b) return a.arrivalTime < b.arrivalTime end)

  local results = {}
  for i = 1, numArrivals do
    results[#results+1] = arrivals[i]
  end

  return results
end

local function formatClockString(clock_time)
  return string.format("%02d:%02d:%02d", (clock_time / 60 / 60) % 24, (clock_time / 60) % 60, clock_time % 60)
end

local function formatClockStringHHMM(clock_time)
  return string.format("%02d:%02d", (clock_time / 60 / 60) % 24, (clock_time / 60) % 60)
end

local function formatArrivals(arrivals, time)
  local ret = {}

  if arrivals then
    for i, arrival in ipairs(arrivals) do
      local entry = { dest = "", etaMinsString = "", arrivalTimeString = "", arrivalTerminal = arrival.terminalId }
      local terminusName = api.engine.getComponent(arrival.destination, api.type.ComponentType.NAME)
      if terminusName then
        entry.dest = terminusName.name
      end

      entry.arrivalTimeString = formatClockStringHHMM(arrival.arrivalTime / 1000)
      local expectedSecondsFromNow = math.ceil((arrival.arrivalTime - time) / 1000)
      local expectedMins = math.ceil(expectedSecondsFromNow / 60)
      if expectedMins > 0 then
        entry.etaMinsString = expectedMins .. "min"
      end

      ret[#ret+1] = entry
    end
  end
  while #ret < 2 do
    ret[#ret+1] = { dest = "", eta = 0 }
  end

  return ret
end

local function configureSignLink(sign, state, config)
  local stationTerminal = getClosestTerminal(sign.transf)

  if stationTerminal then
    log.object("Closest Terminal", { ClosestTerminal = stationTerminal })
    if not config.singleTerminal then
      stationTerminal.terminal = nil
    end
    state.stationTerminal = stationTerminal
  end

  state.isLinked = true
end

local function update()
  local time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
  if not(time) then log.message("cannot get time!") return end

  if math.fmod(time, constants.refreshCount) ~= 0 then --[[ log.print('skipping') ]] return end
  -- log.print('doing it')

  local speed = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED).speedup
  if not speed then speed = 1 end
  local state = stateManager.loadState()
  local clock_time = math.floor(time / 1000)
  if clock_time == state.world_time then return end

  state.world_time = clock_time

  -- performance profiling
  local startTick = os.clock()
  local clockString = formatClockString(clock_time)

  -- some optimisation ideas noting here while i think of them.
  -- * (maybe not needed after below) build the proposal of multiple construction updates and send a single command after the loop.
  --    (is this even a bottleneck? - not per call - batching all constructions into single proposal takes about as long as each individual build command.
  --     so it may be more beneficial to make smaller batches and apply over a few updates to avoid a risk of stuttering)
  -- * move station / line info gathering into less frequent coroutine
  -- prevent multiple requests for the same data in this single update. (how slow are engine api calls? )
  -- we do need to request these per update tho because the player might edit the lines / add / remove vehicles
  -- do a pass over signs and sort into ones with and without a clock, and update the non-clock ones less frequently

  local newConstructions = {}
  local oldConstructions = {}

  log.timed("sign processing", function()
    for signConId, signProps in pairs(state.placed_signs) do
      -- log.print('signConId =') log.debugPrint(signConId)
      -- log.print('signProps =') log.debugPrint(signProps)
      if edgeUtils.isValidAndExistingId(signConId) then -- prevent crash if construction does not exist
        local signCon = api.engine.getComponent(signConId, api.type.ComponentType.CONSTRUCTION)
        -- log.print('signCon =') log.debugPrint(signCon)
        if signCon then
          local config = construction.getRegisteredConstructions()[signCon.fileName]
          -- log.print('config =') log.debugPrint(config)
          if not config then
            print('bh_dynamic_arrivals_board WARNING: cannot read the constructionconfig, conId =', signConId)
          end

          if not config then config = {} end
          if not config.labelParamPrefix then config.labelParamPrefix = "" end
          local function param(name) return config.labelParamPrefix .. name end

          -- update the linked terminal as it might have been changed by the player in the construction params
          local terminalOverride = signCon.params[param("terminal_override")] or 0

          if config.singleTerminal then
            if signProps.stationTerminal and not signProps.stationTerminal.auto and terminalOverride == 0 then
              -- player may have changed the construction from a specific terminal to auto, so we need to recalculate the closest one
              signProps.isLinked = false
            end
          else
            if signProps.stationConId then
              signProps.isLinked = true
            end
          end

          local arrivals = {}

          if config.singleTerminal then
            if not signProps.isLinked then
              configureSignLink(signCon, signProps, config)
            end

            if signProps.stationTerminal and terminalOverride > 0 then
              signProps.stationTerminal.terminal = terminalOverride - 1
              signProps.stationTerminal.auto = false
            end

            if signProps.stationTerminal and config.maxArrivals > 0 then
              local nextArrivals = getNextArrivals(signProps.stationTerminal, config.maxArrivals, time)

              -- if selectedObject == signConId then
              --   log.object("Time", time)
              --   log.object("stationTerminal", signProps.stationTerminal)
              --   log.object("nextArrivals", nextArrivals)
              -- end

              arrivals = formatArrivals(nextArrivals, time)
            end
          else
            local _setNextArrivals = function()
              local nextArrivals = {}
              local stationIds = api.engine.getComponent(signProps.stationConId, api.type.ComponentType.CONSTRUCTION).stations
              for _, stationId in pairs(stationIds) do
                arrayUtils.concatValues(
                  nextArrivals,
                  getNextArrivals4Station(
                    stationId,
                    config.maxArrivals,
                    time
                ))
              end

              log.print('nextArrivals =') log.debugPrint(nextArrivals)
              arrivals = formatArrivals(nextArrivals, time)
            end

            _setNextArrivals()
          end

          local newCon = api.type.SimpleProposal.ConstructionEntity.new()

          local newParams = {}
          for oldKey, oldVal in pairs(signCon.params) do
            newParams[oldKey] = oldVal
          end

          if config.clock then
            newParams[param("time_string")] = clockString
            newParams[param("game_time")] = clock_time
          end

          newParams[param("num_arrivals")] = #arrivals

          for i, a in ipairs(arrivals) do
            local paramName = ""
            
            paramName = paramName .. "arrival_" .. i .. "_"
            newParams[param(paramName .. "dest")] = a.dest
            newParams[param(paramName .. "time")] = config.absoluteArrivalTime and a.arrivalTimeString or a.etaMinsString
            if not config.singleTerminal and a.arrivalTerminal then
              newParams[param(paramName .. "terminal")] = a.arrivalTerminal + 1
            end
          end

          newParams.seed = signCon.params.seed + 1

          newCon.fileName = signCon.fileName
          newCon.params = newParams
          newCon.transf = signCon.transf
          newCon.playerEntity = api.engine.util.getPlayer()

          newConstructions[#newConstructions+1] = newCon
          oldConstructions[#oldConstructions+1] = signConId

          -- log.print('newCon =') log.debugPrint(newCon)
        end
      else -- signCon does not exist
        stateManager.removePlacedSign(signConId) -- it might skip one, never mind: it will come at the next tick
      end
    end
  end)

  if #newConstructions > 0 then
    local proposal = api.type.SimpleProposal.new()
    for i = 1, #newConstructions do
      proposal.constructionsToAdd[i] = newConstructions[i]
    end
    proposal.constructionsToRemove = oldConstructions

    log.timed("buildProposal command", function()
      -- changing params on a construction doesn't seem to change the entity id which indicates it doesn't completely "replace" it but i don't know how expensive this command actually is...
      api.cmd.sendCommand(api.cmd.make.buildProposal(proposal, api.type.Context:new(), true))
    end)
  end

  local executionTime = math.ceil((os.clock() - startTick) * 1000)
  print("Full update took " .. executionTime .. "ms")
end

local function handleEvent(src, id, name, args)
  if src ~= constants.eventSources.bh_gui_engine then return end

  log.print('handleEvent firing, src =', src, ', id =', id, ', name =', name, ', args =') log.debugPrint(args)

  if name == constants.events.remove_display_construction then
    log.print('state before =') log.debugPrint(stateManager.loadState())
    stateManager.removePlacedSign(args.boardConstructionId)
    -- local state = stateManager.getState()
    -- state.placed_signs[args] = nil
    -- log.print("Removed display construction id ") log.debugPrint(args)
    log.print('state after =') log.debugPrint(stateManager.loadState())
  elseif name == constants.events.join_board_to_station then
    log.print('state before =') log.debugPrint(stateManager.loadState())
    stateManager.setPlacedSign(args.boardConstructionId, {['stationConId'] = args.stationConId})
    -- log.print("Added display construction id ") log.debugPrint(args)
    log.print('state after =') log.debugPrint(stateManager.loadState())
  -- elseif name == "select_object" then
  --   -- selectedObject = args
  --   -- log.message("bh_dynamic_arrivals_board WARNING LEGACY Selected display construction id " .. tostring(args))
  -- elseif name == "add_display_construction" then
  --   local state = stateManager.getState()
  --   state.placed_signs[args] = {}
  --   -- log.message("bh_dynamic_arrivals_board WARNING LEGACY Added display construction id " .. tostring(args))
  end
end

return {
  update = update,
  handleEvent = handleEvent
}