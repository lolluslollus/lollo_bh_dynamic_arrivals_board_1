local logger = require ('lolloArrivalsDeparturesPredictor.logger')
local arrayUtils = require('lolloArrivalsDeparturesPredictor.arrayUtils')
local constants = require('lolloArrivalsDeparturesPredictor.constants')
local constructionConfigs = require('lolloArrivalsDeparturesPredictor.constructionConfigs')
local edgeUtils = require('lolloArrivalsDeparturesPredictor.edgeUtils')
local stateHelpers = require('lolloArrivalsDeparturesPredictor.stateHelpers')
local stationHelpers = require('lolloArrivalsDeparturesPredictor.stationHelpers')
local transfUtilsUG = require('transf')

local _texts = {
    arrivalsAllCaps = _('ArrivalsAllCaps'),
    companyNamePrefix1 = _('CompanyNamePrefix1'),
    departuresAllCaps = _('DeparturesAllCaps'),
    destination = _('Destination'),
    due = _('Due'),
    from = _('From'),
    fromSpace = _('FromSpace'),
    minutesShort = _('MinutesShort'),
    origin = _('Origin'),
    platform = _('PlatformShort'),
    sorryNoService = _('SorryNoService'),
    sorryTroubleShort = _('SorryTroubleShort'),
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
            api.cmd.make.buildProposal(proposal, context, true), -- the 3rd param is 'ignore errors'; wrong proposals will be discarded anyway
            function(result, success)
                logger.print('bulldozeConstruction success = ', success)
                -- logger.print('bulldozeConstruction result = ') logger.debugPrint(result)
            end
        )
    end,
    formatClockString = function(clock_time)
        return string.format('%02d:%02d:%02d', (clock_time / 60 / 60) % 24, (clock_time / 60) % 60, clock_time % 60)
    end,
    formatClockStringHHMM = function(clock_time)
        return string.format('%02d:%02d', (clock_time / 60 / 60) % 24, (clock_time / 60) % 60)
    end,
    getIsCargo = function(config, signCon, signState, getParamName)
        -- returns true for cargo and false for passenger stations
        -- logger.print('signCon.params[getParamName(\'cargo_override\')] =') logger.debugPrint(signCon.params[getParamName('cargo_override')])
        local result = signCon.params[getParamName('cargo_override')] or 0
        if result == 0 then
            -- logger.print('signState =') logger.debugPrint(signState)
            if signState and signState.nearestTerminal and signState.nearestTerminal.cargo then
                return true
            else
                return false
            end
        end
        -- logger.print('getIsCargo is about to return', (result == 2))
        return (result == 2)
    end,
    getProblemLineIds = function()
        local results = {}
        local problemLineIds = api.engine.system.lineSystem.getProblemLines(api.engine.util.getPlayer())
        for _, lineId in pairs(problemLineIds) do
            if lineId then results[lineId] = true end
        end
        return results
    end,
    getTerminalId = function(config, signCon, signState, getParamName)
        if not(config) or not(config.singleTerminal) then return nil end

        local result = signCon.params[getParamName('terminal_override')] or 0
        if result == 0 then -- 0 is automatic terminal detection
            if signState and signState.nearestTerminal and signState.nearestTerminal.terminalId then
                result = signState.nearestTerminal.terminalId
            else
                result = 1
                logger.warn('cannot find signState.nearestTerminal.terminalId for signCon', signCon or 'NIL')
            end
        end
        return result
    end,
    getStationIndexInStationGroupBase0 = function(stationId, stationGroupId)
        local stationGroup = api.engine.getComponent(stationGroupId, api.type.ComponentType.STATION_GROUP)
        logger.print('stationGroup.stations =') logger.debugPrint(stationGroup.stations)
        local indexBase0 = 0
        for _, staId in pairs(stationGroup.stations) do
            -- this works coz the table indexes have base 1
            if staId == stationId then return indexBase0 end
            indexBase0 = indexBase0 + 1
        end
        return nil
    end,
}
utils.getFormattedPredictions = function(predictions, time, fallbackTerminalIdIfAny)
    -- logger.print('getFormattedPredictions starting, predictions =') logger.debugPrint(predictions)
    local results = {}

    if predictions then
        for _, rawEntry in ipairs(predictions) do
            local fmtEntry = {
                originString = '-',
                destinationString = '-',
                etaMinutesString = _texts.due,
                etdMinutesString = _texts.due,
                arrivalTimeString = '--:--',
                departureTimeString = '--:--',
                arrivalTerminal = (rawEntry.terminalId or '-'), -- the terminal id has base 1
            }
            if edgeUtils.isValidAndExistingId(rawEntry.destinationStationGroupId) then
                local destinationStationGroupName = api.engine.getComponent(rawEntry.destinationStationGroupId, api.type.ComponentType.NAME)
                if destinationStationGroupName and destinationStationGroupName.name then
                    fmtEntry.destinationString = destinationStationGroupName.name
                    -- LOLLO NOTE sanitize away the characters that we use in the regex in the model
                    fmtEntry.destinationString:gsub('_', ' ')
                    fmtEntry.destinationString:gsub('@', ' ')
                end
            end
            if edgeUtils.isValidAndExistingId(rawEntry.originStationGroupId) then
                local originStationGroupName = api.engine.getComponent(rawEntry.originStationGroupId, api.type.ComponentType.NAME)
                if originStationGroupName and originStationGroupName.name then
                    -- fmtEntry.originString = _texts.fromSpace .. originStationGroupName.name
                    fmtEntry.originString = originStationGroupName.name
                    -- LOLLO NOTE sanitize away the characters that we use in the regex in the model
                    fmtEntry.originString:gsub('_', ' ')
                    fmtEntry.originString:gsub('@', ' ')
                end
            end

            if rawEntry.isProblem then
                fmtEntry.arrivalTimeString = _texts.sorryTroubleShort
                fmtEntry.departureTimeString = _texts.sorryTroubleShort
                fmtEntry.etaMinutesString = _texts.sorryTroubleShort
                fmtEntry.etdMinutesString = _texts.sorryTroubleShort
            else
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
            end

            results[#results+1] = fmtEntry
        end
    end
    while #results < 1 do
        results[#results+1] = {
            originString = _texts.sorryNoService,
            destinationString = _texts.sorryNoService,
            etaMinutesString = '-',
            etdMinutesString = '-',
            arrivalTimeString = '--:--',
            departureTimeString = '--:--',
            arrivalTerminal = tostring(fallbackTerminalIdIfAny or '-')
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
            if config.track and i == 1 then
                result = result .. '@_' .. constants.nameTags.track .. '_@' .. prediction.arrivalTerminal
            end
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

local function getMyLineData(vehicleIds, nStops, lineId, lineWaitingTime, buffer)
    -- Here, I average the times across all the trains on this line.
    -- If the trains are wildly different, which is stupid, this could be less accurate;
    -- otherwise, it will be pretty accurate.
    -- buffer
    if buffer[lineId] then logger.print('using line buffer for lineID =', lineId) return buffer[lineId] end
    logger.print('NOT using line buffer for lineID =', lineId)

    if nStops < 1 or #vehicleIds < 1 then return {} end

    -- the new API hasn't got this yet, only a dumb fixed waitingTime == 180 seconds
    local lineEntity = game.interface.getEntity(lineId)
        -- logger.print('lineEntity.frequency =', lineEntity.frequency)
        -- logger.print('lineWaitingTime =', lineWaitingTime)
    local fallbackLegDuration = (
        (lineEntity.frequency > 0) -- this is a proper frequency and not a period
            and (#vehicleIds / lineEntity.frequency) -- the same vehicle calls at any station every this seconds
            or lineWaitingTime -- should never happen
        ) / nStops * 1000
    -- logger.print('1 / lineEntity.frequency =', 1 / lineEntity.frequency)
    -- logger.print('#vehicleIds =', #vehicleIds)
    -- logger.print('nStops =', nStops)
    logger.print('fallbackLegDuration =', fallbackLegDuration)

    local _vehicleStates = {
        atTerminal = api.type.enum.TransportVehicleState.AT_TERMINAL, -- 2
        enRoute = api.type.enum.TransportVehicleState.EN_ROUTE, -- 1
    -- api.type.enum.TransportVehicleState.GOING_TO_DEPOT -- 3
    -- api.type.enum.TransportVehicleState.IN_DEPOT -- 0
    }

    local averages = {}
    local vehicles = {}

    for _, vehicleId in pairs(vehicleIds) do
        vehicles[vehicleId] = api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE)
    end

    for index = 1, nStops, 1 do
        local prevIndex = index - 1
        if prevIndex < 1 then prevIndex = prevIndex + nStops end

        local averageLSD, nVehicles4AverageLSD, averageST, nVehicles4AverageST = 0, #vehicleIds, 0, #vehicleIds
        for _, vehicleId in pairs(vehicleIds) do
            local vehicle = vehicles[vehicleId]
            local lineStopDepartures = vehicle.lineStopDepartures
            if lineStopDepartures[index] == 0
            or lineStopDepartures[prevIndex] == 0
            or lineStopDepartures[index] <= lineStopDepartures[prevIndex]
            or (vehicle.state ~= _vehicleStates.atTerminal and vehicle.state ~= _vehicleStates.enRoute)
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
            or (vehicle.state ~= _vehicleStates.atTerminal and vehicle.state ~= _vehicleStates.enRoute)
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

    buffer[lineId] = {averages = averages, vehicles = vehicles}
    return buffer[lineId]
end

local function getLastDepartureTime(vehicle, time)
    -- this is a little slower; it is 0 when a new train leaves the depot
    local result = math.max(table.unpack(vehicle.lineStopDepartures))
    -- logger.print('lastDepartureTime with unpack =', result)

    -- useful when starting a new line or a new train
    if result == 0 then
        if vehicle.doorsTime > 0 then
            result = math.ceil(vehicle.doorsTime / 1000) + 1000
            logger.print('lastDepartureTime == 0, falling back to doorsTime')
            if result > time then
                logger.print('doorsTime > time, doorsTime = ' .. result .. ', time = ' .. time)
                result = time
            end
        else
            result = time
            logger.print('lastDepartureTime == 0 AND vehicle.doorsTime == ' .. (vehicle.doorsTime or 'NIL') .. ', a train has just left the depot')
        end
        -- logger.print('vehicle.lineStopDepartures =') logger.debugPrint(vehicle.lineStopDepartures)
        -- logger.print('vehicle.doorsTime =') logger.debugPrint(vehicle.doorsTime)
        -- logger.print('time =') logger.debugPrint(time)
    else
        logger.print('lineStopDepartures OK, last departure time = ' .. result .. ', lastDoorsTime would yield ' .. (math.ceil(vehicle.doorsTime / 1000) + 1000))
    end

--[[
    doorsTime is 0 when a new train leaves the depot
    and -1 when a vehicle has just left the depot
    It is always a little sooner then lastDepartureTime, by about 1 second,
    but it may vary.
]]

    return result
end

local function getNextPredictions(stationId, station, nEntries, time, onlyTerminalId, predictionsBufferHelpers, lineBuffer, problemLineIds)
    logger.print('getNextPredictions starting')
    logger.print('stationId =') logger.debugPrint(stationId)
    local predictions = {}

    if not(station) or not(station.terminals) or not(nEntries) or nEntries < 1 then return predictions end

    local stationGroupId = api.engine.system.stationGroupSystem.getStationGroup(stationId)
    local stationIndexInStationGroupBase0 = utils.getStationIndexInStationGroupBase0(stationId, stationGroupId)
    if not(stationIndexInStationGroupBase0) then return predictions end

    local predictionsBuffer = predictionsBufferHelpers.get(stationId, onlyTerminalId)
    if predictionsBuffer then
        logger.print('time = ', time, 'using buffer for stationId =', stationId, 'and onlyTerminalId =', onlyTerminalId or 'NIL')
        return predictionsBuffer
    else
        logger.print('time = ', time, 'NOT using buffer for stationId =', stationId, 'and onlyTerminalId =', onlyTerminalId or 'NIL')
    end

    -- logger.print('stationGroupId =', stationGroupId)
    -- logger.print('stationId =', stationId)
    -- logger.print('station.terminals =') logger.debugPrint(station.terminals)
    local terminalIndexBase0 = 0
    for terminalId, _ in pairs(station.terminals) do
        -- this works coz the table indexes have base 1
        if not(onlyTerminalId) or (terminalId == onlyTerminalId) then
            logger.print('terminalId =', terminalId or 'NIL')
            local lineIds = api.engine.system.lineSystem.getLineStopsForTerminal(stationId, terminalIndexBase0)
            for _, lineId in pairs(lineIds) do
                logger.print('lineId =', lineId or 'NIL')
                local line = api.engine.getComponent(lineId, api.type.ComponentType.LINE)
                if line then
                    local vehicleIds = api.engine.system.transportVehicleSystem.getLineVehicles(lineId)
                    -- logger.print('There are', #vehicleIds, 'vehicles')
                    if #vehicleIds > 0 then
                        local nStops = #line.stops
                        local hereIndex, startIndex, endIndex = getHereStartEndIndexes(line, stationGroupId, stationIndexInStationGroupBase0, terminalIndexBase0)
                        logger.print('hereIndex, startIndex, endIndex, nStops =', hereIndex, startIndex, endIndex, nStops)
                        if nStops < 2 --[[ or problemLineIds[lineId] ]] then
                            predictions[#predictions+1] = {
                                terminalId = terminalId,
                                originStationGroupId = line.stops[startIndex].stationGroup,
                                destinationStationGroupId = line.stops[endIndex].stationGroup,
                                arrivalTime = time + 3600,
                                departureTime = time + 3600,
                                isProblem = true,
                            }
                        else
                            local myLineData = getMyLineData(vehicleIds, nStops, lineId, line.waitingTime, lineBuffer)
                            logger.print('myLineData.averages =') logger.debugPrint(myLineData.averages)

                            for _, vehicleId in pairs(vehicleIds) do
                                logger.print('vehicleId =', vehicleId or 'NIL')
                                local vehicle = myLineData.vehicles[vehicleId]
                                if not(vehicle) then
                                    logger.warn('vehicle with id ' .. (vehicleId or 'NIL') .. ' not found but it should be there')
                                else
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
                                    -- local remainingTime = myLineData.averages[hereIndex].lsd
                                    local remainingTime = 0
                                    while nextStopIndex ~= hereIndex do
                                        remainingTime = remainingTime + myLineData.averages[nextStopIndex].lsd
                                            -- + getWaitingTimeMsec(line, nextStopIndex) -- not needed since I check the departures
                                        nextStopIndex = nextStopIndex + 1
                                        if nextStopIndex > nStops then nextStopIndex = nextStopIndex - nStops end
                                    end

                                    predictions[#predictions+1] = {
                                        terminalId = terminalId,
                                        originStationGroupId = line.stops[startIndex].stationGroup,
                                        destinationStationGroupId = line.stops[endIndex].stationGroup,
                                        -- arrivalTime = lastDepartureTime + remainingTime - getWaitingTimeMsec(line, hereIndex),
                                        arrivalTime = lastDepartureTime + remainingTime + myLineData.averages[hereIndex].st,
                                        departureTime = lastDepartureTime + remainingTime + myLineData.averages[hereIndex].lsd,
                                        -- nStopsAway = nStopsAway
                                    }

                                    -- if #vehicles == 1 then -- LOLLO TODO MAYBE add another loop
                                end
                            end
                        end
                    end
                end
            end
        end
        terminalIndexBase0 = terminalIndexBase0 + 1
    end

    -- logger.print('predictions before sorting =') logger.debugPrint(predictions)
    table.sort(predictions, function(a, b) return a.arrivalTime < b.arrivalTime end)

    local results = {}
    for i = 1, nEntries do
        results[#results+1] = predictions[i]
    end

    predictionsBufferHelpers.set(stationId, onlyTerminalId, results)
    return results
end

local function update()
    local state = stateHelpers.getState()
    if not(state.is_on) then return end

    local _time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
    if not(_time) then logger.err('cannot get time') return end

    if math.fmod(_time, constants.refreshPeriodMsec) ~= 0 then
        -- logger.print('skipping')
    return end
    -- logger.print('doing it')

    xpcall(
        function()
            local startTick = os.clock()

            local _clock_time = math.floor(_time / 1000)
            if _clock_time == state.world_time then return end

            state.world_time = _clock_time

            local lineBuffer = {}
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
                get = function(stationId, onlyTerminalId)
                    if onlyTerminalId then
                        if predictionsBuffer.byStationTerminal[stationId] then
                            return predictionsBuffer.byStationTerminal[stationId][onlyTerminalId]
                        end
                    else
                        return predictionsBuffer.byStation[stationId]
                    end
                    return nil
                end,
                set = function(stationId, onlyTerminalId, data)
                    if onlyTerminalId then
                        if not(predictionsBuffer.byStationTerminal[stationId]) then predictionsBuffer.byStationTerminal[stationId] = {} end
                        predictionsBuffer.byStationTerminal[stationId][onlyTerminalId] = data
                    else
                        predictionsBuffer.byStation[stationId] = data
                    end
                end,
            }

            local _problemLineIds = {} -- utils.getProblemLineIds() -- this is moderately useful and a bit slow

            for signConId, signState in pairs(state.placed_signs) do
                -- logger.print('signConId =') logger.debugPrint(signConId)
                -- logger.print('signState =') logger.debugPrint(signState)
                if not(edgeUtils.isValidAndExistingId(signConId)) then
                    -- sign is no more around: clean the state
                    logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around ONE')
                    stateHelpers.removePlacedSign(signConId)
                else
                    -- an entity with the id of our sign is still around
                    logger.print('signState.stationConId =', signState.stationConId)
                    local signCon = api.engine.getComponent(signConId, api.type.ComponentType.CONSTRUCTION)
                    -- logger.print('signCon =') logger.debugPrint(signCon)
                    if not(signCon) or not(constructionConfigs.get()[signCon.fileName]) then
                        -- sign is no more around: clean the state
                        logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around TWO')
                        stateHelpers.removePlacedSign(signConId)
                    else
                        local formattedPredictions = {}
                        local config = constructionConfigs.get()[signCon.fileName]
                        -- LOLLO TODO config.maxEntries is tied to the construction type, make sure the same-type signs have the same maxEntries
                        if (config.maxEntries or 0) > 0 then
                            if not(edgeUtils.isValidAndExistingId(signState.stationConId)) then
                                -- station is no more around: bulldoze its signs
                                logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around THREE')
                                stateHelpers.removePlacedSign(signConId)
                                utils.bulldozeConstruction(signConId)
                            else
                                local stationCon = api.engine.getComponent(signState.stationConId, api.type.ComponentType.CONSTRUCTION)
                                if not(stationCon) or not(stationCon.stations) or #stationCon.stations == 0 then
                                    -- station is no more around: bulldoze its signs
                                    logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around FOUR')
                                    stateHelpers.removePlacedSign(signConId)
                                    utils.bulldozeConstruction(signConId)
                                else
                                    local stationIds = stationCon.stations
                                    local function _getParamName(subfix) return config.paramPrefix .. subfix end
                                    local rawPredictions = nil
                                    -- the player may have changed the cargo flag or the terminal in the construction params
                                    local isCargo = utils.getIsCargo(config, signCon, signState, _getParamName)
                                    logger.print('isCargo =') logger.debugPrint(isCargo)
                                    local terminalId = utils.getTerminalId(config, signCon, signState, _getParamName)
                                    logger.print('terminalId =') logger.debugPrint(terminalId)

                                    for _, stationId in pairs(stationIds) do
                                        -- this works coz the table indexes have base 1
                                        if edgeUtils.isValidAndExistingId(stationId) then
                                            local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
                                            logger.print('station', stationId, 'has station.cargo =', (station.cargo or 'false'))
                                            if isCargo == not(not(station.cargo)) then
                                                local nextPredictions = getNextPredictions(
                                                    stationId,
                                                    station,
                                                    config.maxEntries,
                                                    _time,
                                                    terminalId, -- nil if config.singleTerminal == falsy
                                                    predictionsBufferHelpers,
                                                    lineBuffer,
                                                    _problemLineIds
                                                )
                                                if rawPredictions == nil then
                                                    rawPredictions = nextPredictions
                                                else
                                                    logger.warn('this concat should never be required ONE')
                                                    arrayUtils.concatValues(rawPredictions, nextPredictions)
                                                end
                                            -- else
                                            --     logger.print('skipping station', stationId, 'because of cargo')
                                            --     logger.print('isCargo =') logger.debugPrint(isCargo)
                                            --     logger.print('not(not(station.cargo)) =') logger.debugPrint(not(not(station.cargo)))
                                            end
                                        end
                                    end
                                    -- logger.print('rawPredictions =') logger.debugPrint(rawPredictions)
                                    formattedPredictions = utils.getFormattedPredictions(rawPredictions or {}, _time, terminalId)
                                end
                            end
                        end

                        -- rename the construction
                        local newName = utils.getNewSignConName(
                            formattedPredictions,
                            config,
                            utils.formatClockString(_clock_time)
                        )
                        api.cmd.sendCommand(api.cmd.make.setName(signConId, newName))
                    end
                end
            end

            local executionTime = math.ceil((os.clock() - startTick) * 1000)
            logger.print('Full update took ' .. executionTime .. 'ms')
        end,
        logger.xpErrorHandler
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

                -- logger.print('constructionConfigs.get() =') logger.debugPrint(constructionConfigs.get())
                -- logger.print('signCon.fileName =', signCon.fileName)
                local config = constructionConfigs.get()[signCon.fileName]
                if not(config) then return end

                -- rename the construction so it shows something at once
                local _times = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
                if _times and type(_times.gameTime) == 'number' then
                    local newName = utils.getNewSignConName(
                        {},
                        config,
                        utils.formatClockString(math.floor(_times.gameTime / 1000))
                    )
                    api.cmd.sendCommand(api.cmd.make.setName(args.signConId, newName))
                end

                local nearestTerminal = stationHelpers.getNearestTerminal(
                    transfUtilsUG.new(signCon.transf:cols(0), signCon.transf:cols(1), signCon.transf:cols(2), signCon.transf:cols(3)),
                    args.stationConId,
                    false -- not only passengers
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
            elseif name == constants.events.toggle_notaus then
                logger.print('state before =') logger.debugPrint(stateHelpers.getState())
                local state = stateHelpers.getState()
                state.is_on = not(not(args))
                logger.print('state after =') logger.debugPrint(stateHelpers.getState())
            end
        end,
        logger.xpErrorHandler
    )
end

return {
    update = update,
    handleEvent = handleEvent
}
