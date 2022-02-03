local vec3 = require "vec3"

local bhm = require "bh_dynamic_arrivals_board/bh_maths"
local stateManager = require "bh_dynamic_arrivals_board/bh_state_manager"
local constructionHooks = require "bh_dynamic_arrivals_board/bh_construction_hooks"

local log = require "bh_dynamic_arrivals_board/bh_log"
local arrayUtils = require('bh_dynamic_arrivals_board.arrayUtils')
local constants = require('bh_dynamic_arrivals_board.constants')
local edgeUtils = require('bh_dynamic_arrivals_board.edgeUtils')
local stationUtils = require('bh_dynamic_arrivals_board.stationUtils')
local transfUtilsUG = require('transf')

local utils = {
    bulldozeConstruction = function(conId)
        if not(edgeUtils.isValidAndExistingId(conId)) then
            -- log.print('bulldozeConstruction cannot bulldoze construction with id =', conId or 'NIL', 'because it is not valid or does not exist')
            return
        end

        local proposal = api.type.SimpleProposal.new()
        -- LOLLO NOTE there are asymmetries how different tables are handled.
        -- This one requires this system, UG says they will document it or amend it.
        proposal.constructionsToRemove = { conId }
        -- proposal.constructionsToRemove[1] = constructionId -- fails to add
        -- proposal.constructionsToRemove:add(constructionId) -- fails to add

        local context = api.type.Context:new()
        -- context.checkTerrainAlignment = true -- default is false, true gives smoother Z
        -- context.cleanupStreetGraph = true -- default is false
        -- context.gatherBuildings = true  -- default is false
        -- context.gatherFields = true -- default is true
        -- context.player = api.engine.util.getPlayer() -- default is -1
        api.cmd.sendCommand(
            api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is "ignore errors"; wrong proposals will be discarded anyway
            function(result, success)
                log.print('bulldozeConstruction success = ', success)
                -- logger.print('bulldozeConstruction result = ') logger.debugPrint(result)
            end
        )
    end,
    formatClockString = function(clock_time)
        return string.format("%02d:%02d:%02d", (clock_time / 60 / 60) % 24, (clock_time / 60) % 60, clock_time % 60)
    end,
    formatClockStringHHMM = function(clock_time)
        return string.format("%02d:%02d", (clock_time / 60 / 60) % 24, (clock_time / 60) % 60)
    end,
}
utils.getFormattedArrivals = function(arrivals, time)
    local ret = {}

    if arrivals then
        for i, arrival in ipairs(arrivals) do
            local entry = { dest = "", etaMinsString = "", arrivalTimeString = "", arrivalTerminal = arrival.terminalId }
            local terminusName = api.engine.getComponent(arrival.destination, api.type.ComponentType.NAME)
            if terminusName then
                entry.dest = terminusName.name
            end

            entry.arrivalTimeString = utils.formatClockStringHHMM(arrival.arrivalTime / 1000)
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

local function calculateLineStopTermini(line, stationGroupId, terminalIndexBase0)
    -- log.print('calculateLineStopTermini starting, line =') log.debugPrint(line)
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

local function getNextArrivals(stationId, numArrivals, time, onlyTerminalId)
    -- log.print('getNextArrivals starting')
    -- TODO We should make a twin construction for arrivals, this is for departures

    -- despite how many we want to return, we actually need to look at every vehicle on every line stopping here before we can sort and trim
    local arrivals = {}

    if not stationId then return arrivals end

    local stationGroupId = api.engine.system.stationGroupSystem.getStationGroup(stationId)
    -- log.print('stationGroupId =', stationGroupId)
    -- log.print('stationId =', stationId)
    local stationTerminals = api.engine.getComponent(stationId, api.type.ComponentType.STATION).terminals
    for terminalId, terminal in pairs(stationTerminals) do
        if not(onlyTerminalId) or terminalId == onlyTerminalId then
            -- log.print('terminal.tag =', terminal.tag or 'NIL', ', terminalId =', terminalId or 'NIL')
            local lineIds = api.engine.system.lineSystem.getLineStopsForTerminal(stationId, terminal.tag)
            for _, lineId in pairs(lineIds) do
                log.print('lineId =', lineId or 'NIL')
                local lineData = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
                if lineData then
                    local vehicles = api.engine.system.transportVehicleSystem.getLineVehicles(lineId)
                    if #vehicles > 0 then
                        local hereIndex, lineTerminusIndex = calculateLineStopTermini(lineData, stationGroupId, terminal.tag) -- this will eventually be done in a slower engine loop to save performance
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
                        local lineEntity = game.interface.getEntity(lineId)
                        local fallbackLineDuration = lineEntity.frequency > 0 and (1 / lineEntity.frequency) --[[ * #vehicles ]] or lineData.waitingTime
                        -- local fallbackLineDuration2 = lineData.waitingTime -- not reliable, it is always 180
                        log.print('fallbackLineDuration =', fallbackLineDuration)
                        -- log.print('fallbackLineDuration2 =', fallbackLineDuration2)
                        local averageSectionTimeToDestinations = getAverageSectionTimeToDestinations(vehicles, nStops, fallbackLineDuration)
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
    end

    -- log.print('arrivals before sorting =') log.debugPrint(arrivals)
    table.sort(arrivals, function(a, b) return a.arrivalTime < b.arrivalTime end)

    local results = {}
    for i = 1, numArrivals do
        results[#results+1] = arrivals[i]
    end

    return results
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
    local clockString = utils.formatClockString(clock_time)

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
        -- sign is no more around: clean the state
        for signConId, signProps in pairs(state.placed_signs) do
            if not(edgeUtils.isValidAndExistingId(signConId)) then
                stateManager.removePlacedSign(signConId)
            end
        end
        -- station is no more around: bulldoze its signs
        for signConId, signProps in pairs(state.placed_signs) do
            if not(edgeUtils.isValidAndExistingId(signProps.stationConId)) then
                stateManager.removePlacedSign(signConId)
                utils.bulldozeConstruction(signConId)
            end
        end
        -- now the state is clean
        for signConId, signProps in pairs(state.placed_signs) do
            -- log.print('signConId =') log.debugPrint(signConId)
            -- log.print('signProps =') log.debugPrint(signProps)
            local signCon = api.engine.getComponent(signConId, api.type.ComponentType.CONSTRUCTION)
            local stationIds = api.engine.getComponent(signProps.stationConId, api.type.ComponentType.CONSTRUCTION).stations
            -- log.print('signCon =') log.debugPrint(signCon)
            if signCon then
                local config = constructionHooks.getRegisteredConstructions()[signCon.fileName]
                -- log.print('config =') log.debugPrint(config)
                if not config then
                    print('bh_dynamic_arrivals_board WARNING: cannot read the constructionconfig, conId =', signConId)
                end

                if not config then config = {} end
                if not config.labelParamPrefix then config.labelParamPrefix = "" end

                if not(config.singleTerminal) or (signProps.nearestTerminal and signProps.nearestTerminal.terminalId) then
                    local function param(name) return config.labelParamPrefix .. name end

                    local arrivals = {}

                    if config.singleTerminal then
                        -- update the linked terminal as it might have been changed by the player in the construction params
                        local terminalIdOverride = signCon.params[param("terminal_override")] or 0
                        if terminalIdOverride == 0 then terminalIdOverride = signProps.nearestTerminal.terminalId end

                        if config.maxArrivals > 0 then
                            local nextArrivals = {}

                            for _, stationId in pairs(stationIds) do
                                arrayUtils.concatValues(
                                    nextArrivals,
                                    getNextArrivals(
                                        stationId,
                                        config.maxArrivals,
                                        time,
                                        terminalIdOverride
                                ))
                            end

                            log.print('single terminal nextArrivals =') log.debugPrint(nextArrivals)
                            arrivals = utils.getFormattedArrivals(nextArrivals, time)
                        end
                    else
                        local nextArrivals = {}

                        for _, stationId in pairs(stationIds) do
                            arrayUtils.concatValues(
                                nextArrivals,
                                getNextArrivals(
                                    stationId,
                                    config.maxArrivals,
                                    time
                            ))
                        end

                        log.print('station nextArrivals =') log.debugPrint(nextArrivals)
                        arrivals = utils.getFormattedArrivals(nextArrivals, time)
                    end

                    -- rebuild the sign construction
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
                        local paramName = "arrival_" .. i .. "_"
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
                else
                    log.print('bh_dynamic_arrivals_board WARNING: single terminal without nearest terminal; signProps =')
                    log.debugPrint(signProps)
                end
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
        log.print('state before =') log.debugPrint(stateManager.getState())
        stateManager.removePlacedSign(args.signConId)
        utils.bulldozeConstruction(args.signConId)
        log.print('state after =') log.debugPrint(stateManager.getState())
    elseif name == constants.events.join_sign_to_station then
        log.print('state before =') log.debugPrint(stateManager.getState())
        if not(args) or not(edgeUtils.isValidAndExistingId(args.signConId)) then return end

        local signCon = api.engine.getComponent(args.signConId, api.type.ComponentType.CONSTRUCTION)
        if not(signCon) then return end

        local config = constructionHooks.getRegisteredConstructions()[signCon.fileName]
        if not(config) then return end

        if config.singleTerminal then
            -- local nearestTerminals = stationUtils.getNearestTerminals(
            --     transfUtilsUG.new(signCon.transf:cols(0), signCon.transf:cols(1), signCon.transf:cols(2), signCon.transf:cols(3)),
            --     args.stationConId,
            --     false -- not only passengers
            -- )
            -- log.print('freshly calculated nearestTerminals =') log.debugPrint(nearestTerminals)
            local nearestTerminal = stationUtils.getNearestTerminal(
                transfUtilsUG.new(signCon.transf:cols(0), signCon.transf:cols(1), signCon.transf:cols(2), signCon.transf:cols(3)),
                args.stationConId
            )
            log.print('freshly calculated nearestTerminal =') log.debugPrint(nearestTerminal)
            stateManager.setPlacedSign(
                args.signConId,
                {
                    stationConId = args.stationConId,
                    nearestTerminal = nearestTerminal,
                }
            )
        else
            stateManager.setPlacedSign(args.signConId, {stationConId = args.stationConId})
        end
        log.print('state after =') log.debugPrint(stateManager.getState())
    end
end

return {
    update = update,
    handleEvent = handleEvent
}
