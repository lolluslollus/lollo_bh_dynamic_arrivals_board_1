local stateHelpers = require("lolloArrivalsDeparturesPredictor.stateHelpers")
local constructionHooks = require("lolloArrivalsDeparturesPredictor.constructionHooks")

local logger = require ("lolloArrivalsDeparturesPredictor.logger")
local arrayUtils = require('lolloArrivalsDeparturesPredictor.arrayUtils')
local constants = require('lolloArrivalsDeparturesPredictor.constants')
local edgeUtils = require('lolloArrivalsDeparturesPredictor.edgeUtils')
local stationHelpers = require('lolloArrivalsDeparturesPredictor.stationHelpers')
local transfUtilsUG = require('transf')

local _texts = {
    arrivalsAllCaps = _("ArrivalsAllCaps"),
    companyNamePrefix1 = _("CompanyNamePrefix1"),
    departuresAllCaps = _("DeparturesAllCaps"),
    destination = _('Destination'),
    due = _('Due'),
    from = _('From'),
    fromSpace = _('FromSpace'),
    minutesShort = _('MinutesShort'),
    origin = _('Origin'),
    platform = _('Platform'),
    sorryNoService = _('SorryNoService'),
    time = _('Time'),
    to = _('To'),
}

local utils = {
    bulldozeConstruction = function(conId)
        if not(edgeUtils.isValidAndExistingId(conId)) then
            -- logger.print('bulldozeConstruction cannot bulldoze construction with id =', conId or 'NIL', 'because it is not valid or does not exist')
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
                logger.print('bulldozeConstruction success = ', success)
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
    getIsCargo = function(config, signCon, signState, getParam)
        -- returns true for cargo and false for passenger stations
        local result = signCon.params[getParam("cargo_override")] or 0
        if result == 0 then
            if signState and signState.nearestTerminal and signState.nearestTerminal.cargo then
                return true
            else
                return false
            end
        end
        return (result == 2)
    end,
    getTerminalId = function(config, signCon, signState, getParam)
        -- returns a terminalId if config.singleTerminal == true, otherwise nil
        if not(config) or not(config.singleTerminal) then return nil end

        local result = signCon.params[getParam("terminal_override")] or 0
        if result == 0 then
            if signState and signState.nearestTerminal and signState.nearestTerminal.terminalId then
                result = signState.nearestTerminal.terminalId
            else
                result = 1
            end
        end
        return result
    end,
    getStationIndexInStationGroupBase0 = function(stationId, stationGroupId)
        local stationGroup = api.engine.getComponent(stationGroupId, api.type.ComponentType.STATION_GROUP)
        for indexBase1, id in ipairs(stationGroup.stations) do
            if id == stationId then return indexBase1 - 1 end
        end
        return nil
    end,
}
utils.getFormattedPredictions = function(predictions, time)
    -- logger.print('getFormattedPredictions starting, predictions =') logger.debugPrint(predictions)
    local results = {}

    if predictions then
        for _, rawEntry in ipairs(predictions) do
            local fmtEntry = {
                originString = "-",
                destinationString = "-",
                etaMinutesString = _texts.due,
                etdMinutesString = _texts.due,
                arrivalTimeString = "--:--",
                departureTimeString = "--:--",
                -- arrivalTerminal = (rawEntry.terminalTag or 0) + 1, -- the terminal tag has base 0
                arrivalTerminal = (rawEntry.terminalId or '-'), -- the terminal id has base 1
            }
            local destinationStationGroupName = api.engine.getComponent(rawEntry.destinationStationGroupId, api.type.ComponentType.NAME)
            if destinationStationGroupName and destinationStationGroupName.name then
                fmtEntry.destinationString = destinationStationGroupName.name
                -- LOLLO NOTE sanitize away the characters that we use in the regex in the model
                fmtEntry.destinationString:gsub('_', ' ')
                fmtEntry.destinationString:gsub('@', ' ')
            end
            local originStationGroupName = api.engine.getComponent(rawEntry.originStationGroupId, api.type.ComponentType.NAME)
            if originStationGroupName and originStationGroupName.name then
                -- fmtEntry.originString = _texts.fromSpace .. originStationGroupName.name
                fmtEntry.originString = originStationGroupName.name
                -- LOLLO NOTE sanitize away the characters that we use in the regex in the model
                fmtEntry.originString:gsub('_', ' ')
                fmtEntry.originString:gsub('@', ' ')
            end

            fmtEntry.arrivalTimeString = utils.formatClockStringHHMM(rawEntry.arrivalTime / 1000)
            fmtEntry.departureTimeString = utils.formatClockStringHHMM(rawEntry.departureTime / 1000)
            local expectedMinutesToArrival = math.floor((rawEntry.arrivalTime - time) / 60000)
            if expectedMinutesToArrival > 0 then
                fmtEntry.etaMinutesString = expectedMinutesToArrival .. _texts.minutesShort
            end
            local expectedMinutesToDeparture = math.floor((rawEntry.departureTime - time) / 60000)
            if expectedMinutesToDeparture > 0 then
                fmtEntry.etdMinutesString = expectedMinutesToDeparture .. _texts.minutesShort
            end

            results[#results+1] = fmtEntry
        end
    end
    while #results < 1 do
        results[#results+1] = {
            originString = _texts.sorryNoService,
            destinationString = _texts.sorryNoService,
            etaMinutesString = "-",
            etdMinutesString = "-",
            arrivalTimeString = "--:--",
            departureTimeString = "--:--",
            arrivalTerminal = "-"
        }
    end

    -- logger.print('getFormattedPredictions about to return results =') logger.debugPrint(results)
    return results
end

utils.getNewSignConName = function(formattedPredictions, config, clockString)
    local result = ''
    if config.singleTerminal then
        local i = 1
        for _, prediction in ipairs(formattedPredictions) do
            result = result .. '@_' .. i .. '_@' .. prediction.destinationString
            i = i + 1
            result = result .. '@_' .. i .. '_@' .. (config.absoluteArrivalTime and prediction.departureTimeString or prediction.etdMinutesString)
            -- result = result .. '@_' .. i .. '_@' .. (config.absoluteArrivalTime and prediction.arrivalTimeString or prediction.etaMinutesString)
            i = i + 1
        end
        if config.clock and clockString then
            result = result .. '@_' .. constants.nameTags.clock .. '_@' .. clockString
        end
    else
        if config.isArrivals then
            result = '@_1_@' .. _texts.from .. '@_2_@' .. _texts.platform .. '@_3_@' .. _texts.time
            local i = 4
            for _, prediction in ipairs(formattedPredictions) do
                result = result .. '@_' .. i .. '_@' .. prediction.originString
                i = i + 1
                result = result .. '@_' .. i .. '_@' .. prediction.arrivalTerminal
                i = i + 1
                result = result .. '@_' .. i .. '_@' .. prediction.arrivalTimeString
                i = i + 1
            end
            if config.clock and clockString then
                result = result .. '@_' .. constants.nameTags.clock .. '_@' .. clockString
            end
            result = result .. '@_' .. constants.nameTags.header .. '_@' .. _texts.arrivalsAllCaps
        else
            result = '@_1_@' .. _texts.to .. '@_2_@' .. _texts.platform .. '@_3_@' .. _texts.time
            local i = 4
            for _, prediction in ipairs(formattedPredictions) do
                result = result .. '@_' .. i .. '_@' .. prediction.destinationString
                i = i + 1
                result = result .. '@_' .. i .. '_@' .. prediction.arrivalTerminal
                i = i + 1
                result = result .. '@_' .. i .. '_@' .. prediction.departureTimeString
                i = i + 1
            end
            if config.clock and clockString then
                result = result .. '@_' .. constants.nameTags.clock .. '_@' .. clockString
            end
            result = result .. '@_' .. constants.nameTags.header .. '_@' .. _texts.departuresAllCaps
        end
    end
    return result .. '@'
end

local function getHereStartEndIndexes(line, stationGroupId, stationIndexBase0, terminalIndexBase0)
    -- logger.print('getHereStartEndIndexes starting, line =') logger.debugPrint(line)
    local lineStops = line.stops
    local hereIndexBase1 = 1
    for stopIndex, stop in ipairs(lineStops) do
        if stop.stationGroup == stationGroupId and stop.station == stationIndexBase0 and stop.terminal == terminalIndexBase0 then
            hereIndexBase1 = stopIndex
            break
        end
    end

    local nStationVisits = {}
    for _, stop in ipairs(lineStops) do
        nStationVisits[stop.stationGroup] = (nStationVisits[stop.stationGroup] or 0) + 1
    end

    local endIndexBase1 = 0
    local i = hereIndexBase1 + 1
    while i ~= hereIndexBase1 do
        if i > #lineStops then i = i - #lineStops end
        if nStationVisits[lineStops[i].stationGroup] == 1 then
            endIndexBase1 = i
            break
        end
        i = i + 1
    end

    if endIndexBase1 == 0 then
    -- good for circular lines
        endIndexBase1 = hereIndexBase1 + math.ceil(#lineStops * 0.5)
        if endIndexBase1 > #lineStops then
            endIndexBase1 = endIndexBase1 - #lineStops
        end
    end

    -- just in case
    if endIndexBase1 == hereIndexBase1 then
        if endIndexBase1 < #lineStops then endIndexBase1 = endIndexBase1 + 1
        else endIndexBase1 = 1
        end
    end

    local startIndexBase1 = 0
    local j = hereIndexBase1 - 1
    while j ~= hereIndexBase1 do
        if j < 1 then j = j + #lineStops end
        if nStationVisits[lineStops[j].stationGroup] == 1 then
            startIndexBase1 = j
            break
        end
        j = j - 1
    end

    if startIndexBase1 == 0 then
    -- good for circular lines
        startIndexBase1 = hereIndexBase1 - math.ceil(#lineStops * 0.5)
        if startIndexBase1 < 1 then
            startIndexBase1 = startIndexBase1 + #lineStops
        end
    end

    -- just in case
    if startIndexBase1 == hereIndexBase1 then
        if startIndexBase1 > 1 then startIndexBase1 = startIndexBase1 - 1
        else startIndexBase1 = #lineStops
        end
    end

    -- logger.print('legStartIndex, legEndIndex =', legStartIndex, legEndIndex)
    return hereIndexBase1, startIndexBase1, endIndexBase1
end

local function getWaitingTimeMsec(line, stopIndex)
    -- This is a quick and dirty estimate, I doubt the game offers more
    local max = line.stops[stopIndex].maxWaitingTime * 1000
    local min = line.stops[stopIndex].minWaitingTime * 1000
    local result = math.max(constants.guesstimatedStationWaitingTimeMsec, min)
    return math.ceil(result)
    -- if max > 0 then
    --     return (max + min) * 500
    -- elseif min > 0 then -- max is endless and min is set
    --     return (min + line.waitingTime) * 500
    -- else -- max is endless and min is not set
    --     return line.waitingTime * 1000
    -- end
end

local function getAverageTimeToLeaveDestinationFromPrevious(vehicles, nStops, lineId, lineWaitingTime, buffer)
    -- buffer
    if buffer[lineId] then logger.print('using ATT buffer for lineID =', lineId) return buffer[lineId] end
    logger.print('NOT using ATT buffer for lineID =', lineId)

    if nStops < 1 or #vehicles < 1 then return {} end

    -- vehicle states:
    -- api.type.enum.TransportVehicleState.AT_TERMINAL -- 2
    -- api.type.enum.TransportVehicleState.EN_ROUTE -- 1
    -- api.type.enum.TransportVehicleState.GOING_TO_DEPOT -- 3
    -- api.type.enum.TransportVehicleState.IN_DEPOT -- 0

    -- the new API hasn't got this yet, only a dumb fixed waitingTime == 180 seconds
    local lineEntity = game.interface.getEntity(lineId)
        -- logger.print('lineEntity.frequency =', lineEntity.frequency)
        -- logger.print('lineWaitingTime =', lineWaitingTime)
    local fallbackLegDuration = (
        (lineEntity.frequency > 0) -- this is a proper frequency and not a period
            and (#vehicles / lineEntity.frequency) -- the same vehicle calls at any station every this seconds
            or lineWaitingTime -- should never happen
        ) / nStops * 1000
    -- logger.print('1 / lineEntity.frequency =', 1 / lineEntity.frequency)
    -- logger.print('#vehicles =', #vehicles)
    -- logger.print('nStops =', nStops)
    logger.print('fallbackLegDuration =', fallbackLegDuration)

    local averages = {}

    for index = 1, nStops, 1 do
        local prevIndex = index - 1
        if prevIndex < 1 then prevIndex = prevIndex + nStops end

        local averageLSD, nVehicles4AverageLSD, averageST, nVehicles4AverageST = 0, #vehicles, 0, #vehicles
        for _, vehicleId in pairs(vehicles) do
            local vehicle = api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE)
            local lineStopDepartures = vehicle.lineStopDepartures
            if lineStopDepartures[index] == 0
            or lineStopDepartures[prevIndex] == 0
            or lineStopDepartures[index] <= lineStopDepartures[prevIndex]
            or (vehicle.state ~= api.type.enum.TransportVehicleState.AT_TERMINAL and vehicle.state ~= api.type.enum.TransportVehicleState.EN_ROUTE)
            then
                nVehicles4AverageLSD = nVehicles4AverageLSD - 1
            else
                -- if vehicleId == '198731' then -- one fliegender purupu
                -- if lineId ~= 86608 then -- fliegender purupu
                --     print('lineStopDepartures[prevIndex] =', lineStopDepartures[prevIndex])
                --     print('lineStopDepartures[stopIndex] =', lineStopDepartures[stopIndex])
                -- end
                -- LOLLO TODO to respond better to sudden changes,
                -- you cound use a weighted average
                -- with more weight for the latest data
                averageLSD = averageLSD + lineStopDepartures[index] - lineStopDepartures[prevIndex]
            end
            local sectionTimes = vehicle.sectionTimes
            if sectionTimes[prevIndex] == 0
            or (vehicle.state ~= api.type.enum.TransportVehicleState.AT_TERMINAL and vehicle.state ~= api.type.enum.TransportVehicleState.EN_ROUTE)
            then
                nVehicles4AverageST = nVehicles4AverageST - 1
            else
                -- if vehicleId == '198731' then -- one fliegender purupu
                -- if lineId == '86608' then -- fliegender purupu
                --     print('vehicle.sectionTimes[prevIndex] =', sectionTimes[prevIndex])
                -- end
                averageST = averageST + sectionTimes[prevIndex] * 1000
            end
        end
        -- with every vehicle, there will always be an index like this:
        -- stopIndex = 2,
        -- lineStopDepartures = {
        -- [2] = 19904000,
        -- [3] = 19068800,
        -- sectionTimes = {
        -- [2] = 0,
        -- so I will always fall back at least once, if I have one vehicle only
        if nVehicles4AverageLSD > 0 then
            averageLSD = averageLSD / nVehicles4AverageLSD
        else
            averageLSD = fallbackLegDuration -- useful when starting a new line
        end
        if nVehicles4AverageST > 0 then
            averageST = averageST / nVehicles4AverageST
        else
            averageST = fallbackLegDuration -- useful when starting a new line
        end

        averages[index] = {lsd = math.ceil(averageLSD), st = math.ceil(averageST)}
    end

    buffer[lineId] = averages
    return averages
end

local function getLastDepartureTime(vehicle, time)
    -- LOLLO TODO choose one varying the waiting times at stations
    -- this is a little slower; it is 0 when a new train leaves the depot
    local result = math.max(table.unpack(vehicle.lineStopDepartures))
    -- logger.print('lastDepartureTime with unpack =', result)

    -- useful when starting a new line or a new train
    if result == 0 then
        result = time
        logger.print('lastDepartureTime == 0, a train has just left the depot')
    end

--[[     -- this is 0 when a new train leaves the depot
    -- doorsTime == -1 when a vehicle has just left the depot

    local result2 = math.ceil(vehicle.doorsTime / 1000)
    logger.print('lastDepartureTime with doorsTime =', result2)

    -- useful when starting a new line or a new train
    if result2 == 0 then
        result2 = time
        logger.print('lolloArrivalsDeparturesPredictor WARNING: lastDepartureTime == 0')
        result2 = result2 + 1000
    end ]]

    return result
end
local function getNextPredictions(stationId, station, nEntries, time, onlyTerminalId, predictionsBufferHelpers, averageTimeToLeaveDestinationsFromPreviousBuffer)
    -- logger.print('getNextPredictions starting')
    local predictions = {}

    if not(station) or not(station.terminals) then return predictions end

    local stationGroupId = api.engine.system.stationGroupSystem.getStationGroup(stationId)
    local stationIndexInStationGroupBase0 = utils.getStationIndexInStationGroupBase0(stationId, stationGroupId)
    if not(stationIndexInStationGroupBase0) then return predictions end

    local predictionsBuffer = predictionsBufferHelpers.getIt(stationId, onlyTerminalId)
    if predictionsBuffer then
        logger.print('time = ', time, 'using buffer for stationId =', stationId, 'and onlyTerminalId =', onlyTerminalId or 'NIL')
        return predictionsBuffer
    else
        logger.print('time = ', time, 'NOT using buffer for stationId =', stationId, 'and onlyTerminalId =', onlyTerminalId or 'NIL')
    end

    -- logger.print('stationGroupId =', stationGroupId)
    -- logger.print('stationId =', stationId)
    for terminalId, terminal in pairs(station.terminals) do
        if not(onlyTerminalId) or terminalId == onlyTerminalId then
            logger.print('terminal.tag =', terminal.tag or 'NIL', ', terminalId =', terminalId or 'NIL')
            local lineIds = api.engine.system.lineSystem.getLineStopsForTerminal(stationId, terminal.tag) -- use the tag coz it's in base 0
            for _, lineId in pairs(lineIds) do
                logger.print('lineId =', lineId or 'NIL')
                local line = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
                if line then
                    local vehicles = api.engine.system.transportVehicleSystem.getLineVehicles(lineId)
                    if #vehicles > 0 then
                        local hereIndex, startIndex, endIndex = getHereStartEndIndexes(line, stationGroupId, stationIndexInStationGroupBase0, terminal.tag) -- LOLLO TODO tag or id - 1?
                        local nStops = #line.stops
                        logger.print('hereIndex, startIndex, endIndex, nStops =', hereIndex, startIndex, endIndex, nStops)
                        -- Here, I average the times across all the trains on this line.
                        -- If the trains are wildly different, which is stupid, this could be less accurate;
                        -- otherwise, it will be pretty accurate.
                        local averageTimeToLeaveDestinationFromPrevious = getAverageTimeToLeaveDestinationFromPrevious(vehicles, nStops, lineId, line.waitingTime, averageTimeToLeaveDestinationsFromPreviousBuffer)
                        logger.print('averageTimeToLeaveDestinationFromPrevious =') logger.debugPrint(averageTimeToLeaveDestinationFromPrevious)
                        -- logger.print('#averageTimeToLeaveDestinationFromPrevious =', #averageTimeToLeaveDestinationFromPrevious or 'NIL') -- ok
                        -- logger.print('There are', #vehicles, 'vehicles')

                        for _, vehicleId in ipairs(vehicles) do
                            logger.print('vehicleId =', vehicleId or 'NIL')
                            local vehicle = api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE)
                            --[[
                                vehicle has:
                                stopIndex = 1, -- last stop index or next stop index in base 0
                                lineStopDepartures = { -- last recorded departure times, they can be 0 if not yet recorded
                                [1] = 4591600,
                                [2] = 4498000,
                                },
                                lastLineStopDeparture = 0, -- seems inaccurate
                                sectionTimes = { -- take a while to calculate when starting a new line
                                [1] = 0, -- time it took to complete a segment, starting from stop 1
                                [2] = 86.600006103516, -- time it took to complete a segment, starting from stop 2
                                },
                                timeUntilLoad = -5.5633368492126, -- seems useless
                                timeUntilCloseDoors = -0.19238702952862, -- seems useless
                                timeUntilDeparture = -0.026386171579361, -- seems useless
                                doorsTime = 4590600000, -- last departure time, seems OK
                                and it is quicker than checking the max across lineStopDepartures
                                we add 1000 so we match it to the highest lineStopDeparture, but it varies with some unknown factor.
                                Sometimes, two vehicles A and B on the same line may have A the highest lineStopDeparture and B the highest doorsTime.

                                Here is another example with two vehicles on the same line:
                                line = 86608,
                                stopIndex = 5,
                                lineStopDepartures = {
                                [1] = 19082400,
                                [2] = 19228400,
                                [3] = 19590000,
                                [4] = 19710800,
                                [5] = 19844000,
                                [6] = 18969400,
                                },
                                lastLineStopDeparture = 0,
                                sectionTimes = {
                                [1] = 127.00000762939, -- 146 counting the time spent standing
                                [2] = 354.00003051758, -- 362 counting the time spent standing
                                [3] = 111.00000762939, -- 120 counting the time spent standing
                                [4] = 123.40000915527, -- 133 counting the time spent standing
                                [5] = 0,
                                [6] = 93.200004577637,
                                },
                                line = 86608,
                                stopIndex = 2,
                                lineStopDepartures = {
                                    [1] = 19769400,
                                    [2] = 19904000,
                                    [3] = 19068800,
                                    [4] = 19199800,
                                    [5] = 19330400,
                                    [6] = 19669800,
                                },
                                lastLineStopDeparture = 0,
                                sectionTimes = {
                                    [1] = 126.60000610352, -- 135 counting the time spent standing
                                    [2] = 0,
                                    [3] = 111.00000762939,
                                    [4] = 123.40000915527,
                                    [5] = 332.20001220703,
                                    [6] = 93.200004577637,
                                },
                                sectionTimes tend to be similar but they don't account for the time spent standing
                            ]]
                            -- logger.print('vehicle.stopIndex =', vehicle.stopIndex)
                            local nextStopIndex = vehicle.stopIndex + 1
                            -- local nStopsAway = hereIndex - nextStopIndex
                            -- if nStopsAway < 0 then nStopsAway = nStopsAway + nStops end
                            -- logger.print('nStopsAway =', nStopsAway or 'NIL')

                            local lastDepartureTime = getLastDepartureTime(vehicle, time)
                            logger.print('lastDepartureTime =', lastDepartureTime)
                            -- local remainingTime = averageTimeToLeaveDestinationFromPrevious[hereIndex].lsd
                            local remainingTime = 0
                            while nextStopIndex ~= hereIndex do
                                remainingTime = remainingTime + averageTimeToLeaveDestinationFromPrevious[nextStopIndex].lsd
                                    -- + getWaitingTimeMsec(line, nextStopIndex) -- not needed since I check the departures
                                nextStopIndex = nextStopIndex + 1
                                if nextStopIndex > nStops then nextStopIndex = nextStopIndex - nStops end
                            end

                            predictions[#predictions+1] = {
                                terminalId = terminalId,
                                terminalTag = terminal.tag,
                                originStationGroupId = line.stops[startIndex].stationGroup,
                                destinationStationGroupId = line.stops[endIndex].stationGroup,
                                -- arrivalTime = lastDepartureTime + remainingTime - getWaitingTimeMsec(line, hereIndex),
                                arrivalTime = lastDepartureTime + remainingTime + averageTimeToLeaveDestinationFromPrevious[hereIndex].st,
                                departureTime = lastDepartureTime + remainingTime + averageTimeToLeaveDestinationFromPrevious[hereIndex].lsd,
                                -- nStopsAway = nStopsAway
                            }

                            -- not a good calculation. You should, instead,
                            -- add the highest departure time and subtract the lowest
                            -- to the values you just calculated,
                            -- but only if none is zero.
                            -- if #vehicles == 1 and averageTimeToLeaveDestinationFromPrevious > 0 then
                            --     -- if there's only one vehicle, make a second predictions eta + an entire line duration
                            --     predictions[#predictions+1] = {
                            --         terminalId = terminalId,
                            --         terminalTag = terminal.tag,
                            --         originStationGroupId = lineData.stops[startIndex].stationGroup,
                            --         destinationStationGroupId = lineData.stops[lineTerminusIndex].stationGroup,
                            --         arrivalTime = lastDepartureTime + remainingTime + remainingTime - getWaitingTimeMsec(line, hereIndex),
                            --         departureTime = lastDepartureTime + remainingTime,
                            --         nStopsAway = nStopsAway
                            --     }
                            -- end
                        end
                    end
                end
            end
        end
    end

    -- logger.print('predictions before sorting =') logger.debugPrint(predictions)
    table.sort(predictions, function(a, b) return a.arrivalTime < b.arrivalTime end)

    local results = {}
    for i = 1, (nEntries or 0) do
        results[#results+1] = predictions[i]
    end

    predictionsBufferHelpers.setIt(stationId, onlyTerminalId, results)
    return results
end

---@diagnostic disable-next-line: unused-function
local function update()
    local _time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
    if not(_time) then logger.print("ERROR: cannot get time") return end

    if math.fmod(_time, constants.refreshPeriodMsec) ~= 0 then
        -- logger.print('skipping')
    return end
    -- logger.print('doing it')

    xpcall(
        function()
            local startTick = os.clock()

            local state = stateHelpers.getState()
            local _clock_time = math.floor(_time / 1000)
            if _clock_time == state.world_time then return end

            state.world_time = _clock_time

            -- local speed = (api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED).speedup) or 1

            -- local newConstructions = {}
            -- local oldConstructions = {}

            local averageTimeToLeaveDestinationsFromPreviousBuffer = {}
            local predictionsBuffer = {
                byStation = {},
                byStationTerminal = {}
            }
            local predictionsBufferHelpers = {
                -- isThere = function(stationId, onlyTerminalId)
                --     if onlyTerminalId then
                --         if predictionsBuffer.byStationTerminal[stationId] and predictionsBuffer.byStationTerminal[stationId][onlyTerminalId] then
                --             return true
                --         end
                --     else
                --         if predictionsBuffer.byStation[stationId] then
                --             return true
                --         end
                --     end
                --     return false
                -- end,
                getIt = function(stationId, onlyTerminalId)
                    if onlyTerminalId then
                        if predictionsBuffer.byStationTerminal[stationId] then
                            return predictionsBuffer.byStationTerminal[stationId][onlyTerminalId]
                        end
                    else
                        return predictionsBuffer.byStation[stationId]
                    end
                    return nil
                end,
                setIt = function(stationId, onlyTerminalId, data)
                    if onlyTerminalId then
                        if not(predictionsBuffer.byStationTerminal[stationId]) then predictionsBuffer.byStationTerminal[stationId] = {} end
                        predictionsBuffer.byStationTerminal[stationId][onlyTerminalId] = data
                    else
                        predictionsBuffer.byStation[stationId] = data
                    end
                end,
            }

            -- sign is no more around: clean the state
            for signConId, signState in pairs(state.placed_signs) do
                if not(edgeUtils.isValidAndExistingId(signConId)) then
                    stateHelpers.removePlacedSign(signConId)
                end
            end
            -- station is no more around: bulldoze its signs
            for signConId, signState in pairs(state.placed_signs) do
                if not(edgeUtils.isValidAndExistingId(signState.stationConId)) then
                    stateHelpers.removePlacedSign(signConId)
                    utils.bulldozeConstruction(signConId)
                end
            end
            -- now the state is clean
            for signConId, signState in pairs(state.placed_signs) do
                -- logger.print('signConId =') logger.debugPrint(signConId)
                -- logger.print('signState =') logger.debugPrint(signState)
                local signCon = api.engine.getComponent(signConId, api.type.ComponentType.CONSTRUCTION)
                local stationIds = api.engine.getComponent(signState.stationConId, api.type.ComponentType.CONSTRUCTION).stations
                -- logger.print('signCon =') logger.debugPrint(signCon)
                if signCon then
                    local formattedPredictions = {}
                    local config = constructionHooks.getRegisteredConstructionOrDefault(signCon.fileName)
                    if (config.maxEntries or 0) > 0 then -- config.maxEntries is tied to the construction type, like our tables
                        local function getParam(name) return config.paramPrefix .. name end
                        local rawPredictions = nil
                        -- the player may have changed the cargo flag or the terminal in the construction params
                        local isCargo = utils.getIsCargo(config, signCon, signState, getParam)
                        local terminalId = utils.getTerminalId(config, signCon, signState, getParam)
                        for _, stationId in pairs(stationIds) do
                            if edgeUtils.isValidAndExistingId(stationId) then
                                local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
                                if isCargo == not(not(station.cargo)) then
                                    local nextPredictions = getNextPredictions(
                                        stationId,
                                        station,
                                        config.maxEntries,
                                        _time,
                                        terminalId, -- nil if config.singleTerminal == falsy
                                        predictionsBufferHelpers,
                                        averageTimeToLeaveDestinationsFromPreviousBuffer
                                    )
                                    if rawPredictions == nil then
                                        rawPredictions = nextPredictions
                                    else
                                        print('lolloArrivalsDeparturesPredictor WARNING this should never happen ONE')
                                        arrayUtils.concatValues(rawPredictions, nextPredictions)
                                    end
                                end
                            end
                        end
                        -- logger.print('single terminal rawPredictions =') logger.debugPrint(rawPredictions)
                        formattedPredictions = utils.getFormattedPredictions(rawPredictions or {}, _time)
                    end

                    -- rename the construction
                    local newName = utils.getNewSignConName(
                        formattedPredictions,
                        config,
                        utils.formatClockString(_clock_time)
                    )
                    api.cmd.sendCommand(api.cmd.make.setName(signConId, newName))

                    -- -- rebuild the sign construction
                    -- local newCon = api.type.SimpleProposal.ConstructionEntity.new()

                    -- local newParams = {}
                    -- for oldKey, oldVal in pairs(signCon.params) do
                    --     newParams[oldKey] = oldVal
                    -- end

                    -- if config.clock then
                    --     newParams[param("time_string")] = clockString
                    --     newParams[param("game_time")] = clock_time
                    -- end

                    -- newParams[param("num_arrivals")] = #formattedArrivals

                    -- for i, a in ipairs(formattedArrivals) do
                    --     local paramName = "arrival_" .. i .. "_"
                    --     newParams[param(paramName .. "dest")] = a.destinationString
                    --     newParams[param(paramName .. "time")] = config.absoluteArrivalTime and a.arrivalTimeString or a.etaMinutesString
                    --     if not config.singleTerminal and a.arrivalTerminal then
                    --         newParams[param(paramName .. "terminal")] = a.arrivalTerminal
                    --     end
                    -- end

                    -- newParams.seed = signCon.params.seed + 1

                    -- newCon.fileName = signCon.fileName
                    -- newCon.params = newParams
                    -- newCon.transf = signCon.transf
                    -- newCon.playerEntity = api.engine.util.getPlayer()

                    -- newConstructions[#newConstructions+1] = newCon
                    -- oldConstructions[#oldConstructions+1] = signConId

                    -- logger.print('newCon =') logger.debugPrint(newCon)
                end
            end

            -- if #newConstructions > 0 then
            --         local proposal = api.type.SimpleProposal.new()
            --         for i = 1, #newConstructions do
            --         proposal.constructionsToAdd[i] = newConstructions[i]
            --         end
            --         proposal.constructionsToRemove = oldConstructions

            --         logger.profile("buildProposal command", function()
            --         -- changing params on a construction doesn't seem to change the entity id which indicates it doesn't completely "replace" it but i don't know how expensive this command actually is...
            --         api.cmd.sendCommand(api.cmd.make.buildProposal(proposal, api.type.Context:new(), true))
            --         end)
            -- end

            local executionTime = math.ceil((os.clock() - startTick) * 1000)
            print("Full update took " .. executionTime .. "ms")
        end,
        logger.errorHandler
    )
end

local function handleEvent(src, id, name, args)
    if id ~= constants.eventId then return end

    xpcall(
        function()
            logger.print('handleEvent firing, src =', src, ', id =', id, ', name =', name, ', args =') logger.debugPrint(args)

            if name == constants.events.remove_display_construction then
                logger.print('state before =') logger.debugPrint(stateHelpers.getState())
                stateHelpers.removePlacedSign(args.signConId)
                utils.bulldozeConstruction(args.signConId)
                logger.print('state after =') logger.debugPrint(stateHelpers.getState())
            elseif name == constants.events.join_sign_to_station then
                logger.print('state before =') logger.debugPrint(stateHelpers.getState())
                if not(args) or not(edgeUtils.isValidAndExistingId(args.signConId)) then return end

                local signCon = api.engine.getComponent(args.signConId, api.type.ComponentType.CONSTRUCTION)
                if not(signCon) then return end

                -- logger.print('constructionHooks.getRegisteredConstructions() =') logger.debugPrint(constructionHooks.getRegisteredConstructions())
                -- logger.print('signCon.fileName =', signCon.fileName)
                local config = constructionHooks.getRegisteredConstructions()[signCon.fileName]
                if not(config) then return end

                -- rename the construction so it shows something at once
                local _times = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
                if _times and type(_times.gameTime) == "number" then
                    local newName = utils.getNewSignConName(
                        {},
                        config,
                        utils.formatClockString(math.floor(_times.gameTime / 1000))
                    )
                    api.cmd.sendCommand(api.cmd.make.setName(args.signConId, newName))
                end

                -- we need this for the station panel too,
                -- to find out if it is closer to the cargo or the passenger station
                -- local nearestTerminals = stationHelpers.getNearestTerminals(
                --     transfUtilsUG.new(signCon.transf:cols(0), signCon.transf:cols(1), signCon.transf:cols(2), signCon.transf:cols(3)),
                --     args.stationConId,
                --     false -- not only passengers
                -- )
                -- logger.print('freshly calculated nearestTerminals =') logger.debugPrint(nearestTerminals)
                local nearestTerminal = stationHelpers.getNearestTerminal(
                    transfUtilsUG.new(signCon.transf:cols(0), signCon.transf:cols(1), signCon.transf:cols(2), signCon.transf:cols(3)),
                    args.stationConId
                )
                logger.print('freshly calculated nearestTerminal =') logger.debugPrint(nearestTerminal)
                stateHelpers.setPlacedSign(
                    args.signConId,
                    {
                        stationConId = args.stationConId,
                        nearestTerminal = nearestTerminal,
                    }
                )
                logger.print('state after =') logger.debugPrint(stateHelpers.getState())
            end
        end,
        logger.errorHandler
    )
end

return {
    update = update,
    handleEvent = handleEvent
}
