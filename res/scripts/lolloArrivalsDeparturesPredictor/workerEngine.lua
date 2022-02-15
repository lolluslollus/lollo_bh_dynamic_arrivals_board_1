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
    lineName = '', -- let's leave it empty
    minutesShort = _('MinutesShort'),
    origin = _('Origin'),
    platform = _('PlatformShort'),
    sorryNoService = _('SorryNoService'),
    sorryTrouble = _('SorryTrouble'),
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
    getTextBetweenBrackets = function(str, isOnlyBetweenBrackets)
        -- call this with isOnlyBetweenBrackets == true to fully match lennardo's mod
        -- set it false or leave it empty to always display something
        if not(str) then return '' end

        local result = ''
        local isFound = false
        for match in string.gmatch(str, '%([^()]*%)') do
            result = result .. string.sub(match, 2, match:len() - 1)
            isFound = true
        end

        if not(isFound) and not(isOnlyBetweenBrackets) then
            return str
        end
        return result
    end,
    getTextBetweenBracketsOLD = function(str)
        -- if str contains brackets with something between, return the bit inside the brackets,
        -- otherwise return the whole str
        if not(str) then return nil end

        local str1 = string.gsub(str, '[^(]*%(', '')
        local str2 = string.gsub(str1, '%)[^)]*', '')
        return str2
    end,
    getProblemLineIds = function()
        local results = {}
        local problemLineIds = api.engine.system.lineSystem.getProblemLines(api.engine.util.getPlayer())
        for _, lineId in pairs(problemLineIds) do
            if lineId then results[lineId] = true end
        end
        return results
    end,
    -- getTerminalId = function(config, signCon, signState, getParamName)
    --     if not(config) or not(config.singleTerminal) then return nil end

    --     local result = signCon.params[getParamName('terminal_override')] or 0
    --     if result == 0 then -- 0 is automatic terminal detection
    --         if signState and signState.nearestTerminal and signState.nearestTerminal.terminalId then
    --             result = signState.nearestTerminal.terminalId
    --         else
    --             result = 1
    --             logger.warn('cannot find signState.nearestTerminal.terminalId for signCon', signCon or 'NIL')
    --         end
    --     end
    --     return result
    -- end,
    getTerminalAndStationId = function(config, signCon, signState, getParamName, stationIds)
        if not(config) or not(config.singleTerminal) then return nil, nil end

        if not(signState) or not(signState.nearestTerminal) then
            logger.warn('cannot find signState.nearestTerminal for signCon', signCon or 'NIL')
            return nil, nil
        end

        local terminalParamValue = signCon.params[getParamName('terminal_override')] or 0
        if signState.nearestTerminal.isMultiStationGroup then
            if terminalParamValue == 0 then -- 0 is automatic terminal detection
                logger.print('getTerminalAndStationId working on auto, signState =') logger.debugPrint(signState)
                if #stationIds == 1 then return nil, stationIds[1] end

                -- expensive: two twin streetside stations. One could be bulldozed but the other one lives on.
                -- One could be added later.
                logger.print('getTerminalAndStationId working harder on auto, #stationIds =', #stationIds)
                local refStation = {distance = 9999, id = nil}
                for _, stationId in pairs(stationIds) do
                    local streetsideStationPosition = edgeUtils.getObjectPosition(stationId)
                    if streetsideStationPosition then
                        local distance = edgeUtils.getPositionsDistance(
                            signState.nearestTerminal.refPosition123,
                            streetsideStationPosition
                        )
                        if distance < refStation.distance then
                            refStation.distance = distance
                            refStation.id = stationId
                        end
                    end
                end
                if refStation.id then
                    return nil, refStation.id
                end
                logger.warn('cannot find posisions of stations in a multistation group')
                return nil, nil
            else
                local stationId = stationIds[terminalParamValue]
                -- if not(stationId) then stationId = arrayUtils.getLast(stationIds) end
                return nil, stationId
            end
        end

        if terminalParamValue == 0 then -- 0 is automatic terminal detection
            return signState.nearestTerminal.terminalId, nil
        end
        return terminalParamValue, nil
    end,
    getStationIndexInStationGroupBase0 = function(stationId, stationGroup)
        -- logger.print('stationGroup.stations =') logger.debugPrint(stationGroup.stations)
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
                lineName = rawEntry.lineName or '-',
                originString = '-',
                destinationString = '-',
                etaMinutesString = _texts.due,
                etdMinutesString = _texts.due,
                arrivalTimeString = _texts.due,
                departureTimeString = _texts.due,
                arrivalTerminal = (rawEntry.terminalId or '-'), -- the terminal id has base 1
            }

            if rawEntry.isProblem then
                fmtEntry.destinationString = _texts.sorryTrouble
                -- sanitize away the characters that we use in the regex in the model
                fmtEntry.destinationString:gsub('_', ' ')
                fmtEntry.destinationString:gsub('@', ' ')
                fmtEntry.originString = _texts.sorryTrouble
                -- sanitize away the characters that we use in the regex in the model
                fmtEntry.originString:gsub('_', ' ')
                fmtEntry.originString:gsub('@', ' ')
                fmtEntry.arrivalTimeString = _texts.sorryTroubleShort
                fmtEntry.departureTimeString = _texts.sorryTroubleShort
                fmtEntry.etaMinutesString = _texts.sorryTroubleShort
                fmtEntry.etdMinutesString = _texts.sorryTroubleShort
            else
                if edgeUtils.isValidAndExistingId(rawEntry.destinationStationGroupId) then
                    local destinationStationGroupName = api.engine.getComponent(rawEntry.destinationStationGroupId, api.type.ComponentType.NAME)
                    if destinationStationGroupName and destinationStationGroupName.name then
                        fmtEntry.destinationString = destinationStationGroupName.name
                        -- sanitize away the characters that we use in the regex in the model
                        fmtEntry.destinationString:gsub('_', ' ')
                        fmtEntry.destinationString:gsub('@', ' ')
                    end
                end
                if edgeUtils.isValidAndExistingId(rawEntry.originStationGroupId) then
                    local originStationGroupName = api.engine.getComponent(rawEntry.originStationGroupId, api.type.ComponentType.NAME)
                    if originStationGroupName and originStationGroupName.name then
                        -- fmtEntry.originString = _texts.fromSpace .. originStationGroupName.name
                        fmtEntry.originString = originStationGroupName.name
                        -- sanitize away the characters that we use in the regex in the model
                        fmtEntry.originString:gsub('_', ' ')
                        fmtEntry.originString:gsub('@', ' ')
                    end
                end

                local expectedMinutesToArrival = math.floor((rawEntry.arrivalTime - time) / 60000)
                if expectedMinutesToArrival > 0 then
                    fmtEntry.arrivalTimeString = utils.formatClockStringHHMM(rawEntry.arrivalTime / 1000)
                    fmtEntry.etaMinutesString = expectedMinutesToArrival .. _texts.minutesShort
                end
                local expectedMinutesToDeparture = math.floor((rawEntry.departureTime - time) / 60000)
                if expectedMinutesToDeparture > 0 then
                    fmtEntry.departureTimeString = utils.formatClockStringHHMM(rawEntry.departureTime / 1000)
                    fmtEntry.etdMinutesString = expectedMinutesToDeparture .. _texts.minutesShort
                end
            end

            results[#results+1] = fmtEntry
        end
    end
    while #results < 1 do
        results[#results+1] = {
            lineName = '-',
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

utils.getNewSignConName = function(formattedPredictions, config, clockString, signCon)
    local result = ''
    if config.singleTerminal then
        local function _getParamName(subfix) return config.paramPrefix .. subfix end
        local isAbsoluteTime = signCon.params[_getParamName('absoluteTime')] == 1
        local i = 1
        for _, prediction in ipairs(formattedPredictions) do
            if config.track and i == 1 then
                result = result .. '@_' .. constants.nameTags.track .. '_@' .. prediction.arrivalTerminal
            end
            result = result .. '@_' .. i .. '_@' .. prediction.destinationString
            i = i + 1
            result = result .. '@_' .. i .. '_@' .. prediction.lineName
            i = i + 1
            result = result .. '@_' .. i .. '_@' .. (isAbsoluteTime and prediction.departureTimeString or prediction.etdMinutesString)
            i = i + 1
        end
        if config.clock and clockString then
            result = result .. '@_' .. constants.nameTags.clock .. '_@' .. clockString
        end
    else
        if config.isArrivals then
            result = '@_1_@' .. _texts.from .. '@_2_@' .. _texts.lineName .. '@_3_@' .. _texts.platform .. '@_4_@' .. _texts.time
            local i = 5
            for _, prediction in ipairs(formattedPredictions) do
                result = result .. '@_' .. i .. '_@' .. prediction.originString
                i = i + 1
                result = result .. '@_' .. i .. '_@' .. prediction.lineName
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
            result = '@_1_@' .. _texts.to .. '@_2_@' .. _texts.lineName .. '@_3_@' .. _texts.platform .. '@_4_@' .. _texts.time
            local i = 5
            for _, prediction in ipairs(formattedPredictions) do
                result = result .. '@_' .. i .. '_@' .. prediction.destinationString
                i = i + 1
                result = result .. '@_' .. i .. '_@' .. prediction.lineName
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

local function getHereStartEndIndexesOLD(line, stationGroupId, stationIndexBase0, terminalIndexBase0)
    -- logger.print('getHereStartEndIndexesOLD starting, line =') logger.debugPrint(line)
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

local function getHereNextIndexes(line, stationGroupId, stationIndexBase0, terminalIndexBase0)
    -- logger.print('getHereNextIndexes starting, line =') logger.debugPrint(line)
    local stops = line.stops
    local nStops = #line.stops

    local hereIndex = 0
    for stopIndex, stop in ipairs(stops) do
        if stop.stationGroup == stationGroupId and stop.station == stationIndexBase0 and stop.terminal == terminalIndexBase0 then
            hereIndex = stopIndex
            break
        end
    end
    if hereIndex == 0 then
        logger.warn('cannot find hereIndexBase1')
        hereIndex = 1
    end

    local nextIndex = hereIndex + 1
    if nextIndex > nStops then
        nextIndex = 1
    end

    return hereIndex, nextIndex
end

local getLineStartEndIndexes = function(line)
    -- returns indexes in base 1
    -- logger.print('getLineStartEndIndexes starting, line =') logger.debugPrint(line)
    local stops = line.stops
    local nStops = #line.stops

    local nStationVisitsAtStationGroupIds = {}
    for _, stop in ipairs(stops) do
        nStationVisitsAtStationGroupIds[stop.stationGroup] = (nStationVisitsAtStationGroupIds[stop.stationGroup] or 0) + 1
    end

    local startIndex = 1
    local endIndex = math.ceil(nStops / 2 + 0.1)
    -- the first stop occurs only once, so chances are, it was chosen with a criterion
    -- if the last stop occurs more than once, try and find another stop nearby that occurs only once.
    if nStationVisitsAtStationGroupIds[stops[startIndex].stationGroup] == 1 then
        local deltaI = 0
        local _fetchNextDelta = function()
            -- + 1, -1, +2, -2, +3. -3 and so on
            if deltaI > 0 then deltaI = -deltaI else deltaI = -deltaI + 1 end
        end
        while nStationVisitsAtStationGroupIds[stops[endIndex + deltaI].stationGroup] > 1 do
            _fetchNextDelta()
            if endIndex + deltaI > nStops or endIndex + deltaI < 2 then _fetchNextDelta() end
            if endIndex + deltaI > nStops or endIndex + deltaI < 2 then deltaI = 0 break end
        end
        endIndex = endIndex + deltaI
    end

    -- just in case
    if endIndex == startIndex and endIndex < nStops then
        endIndex = endIndex + 1
    end

    -- logger.print('startIndexBase1, endIndexBase1 =', startIndexBase1, endIndexBase1)
    return startIndex, endIndex
end

local function getMyLineData(vehicleIds, line, lineId, lineWaitingTime, buffer)
    -- Here, I average the times across all the trains on this line.
    -- If the trains are wildly different, which is stupid, this could be less accurate;
    -- otherwise, it will be pretty accurate.
    -- buffer
    if buffer[lineId] then logger.print('using line buffer for lineID =', lineId) return buffer[lineId] end
    logger.print('NOT using line buffer for lineID =', lineId)

    local name = api.engine.getComponent(lineId, api.type.ComponentType.NAME)
    if name and name.name then
        name = utils.getTextBetweenBrackets(name.name)
    end

    local startIndex, endIndex = getLineStartEndIndexes(line)

    local nStops = #line.stops
    if nStops < 1 or #vehicleIds < 1 then return {} end

    -- UG TODO the new API hasn't got this yet, only a dumb fixed waitingTime == 180 seconds
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
    local period = 0
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
        period = period + averages[index].lsd
    end

    buffer[lineId] = {
        averages = averages,
        endIndex = endIndex,
        name = name,
        period = period,
        startIndex = startIndex,
        vehicles = vehicles
    }
    return buffer[lineId]
end

local function getLastDepartureTime(vehicle, time)
    -- this is a little slower than doorsTime but more accurate;
    -- it is 0 when a new train leaves the depot
    local result = math.max(table.unpack(vehicle.lineStopDepartures))
    -- logger.print('lastDepartureTime with unpack =', result)

    -- useful when starting a new line or a new train
    if result == 0 then
        if vehicle.doorsTime > 0 then
            -- add one second to match lsd more closely; still less reliable tho.
            result = math.ceil(vehicle.doorsTime / 1000) + 1000
            logger.print('lastDepartureTime == 0, falling back to doorsTime')
            if result > time then
                -- logger.print('doorsTime > time, doorsTime = ' .. result .. ', time = ' .. time)
                result = time
            end
        else
            result = time
            logger.print('lastDepartureTime == 0 AND vehicle.doorsTime == ' .. (vehicle.doorsTime or 'NIL') .. ', a train has just left the depot')
        end
        -- logger.print('vehicle.lineStopDepartures =') logger.debugPrint(vehicle.lineStopDepartures)
        -- logger.print('vehicle.doorsTime =') logger.debugPrint(vehicle.doorsTime)
        -- logger.print('time =') logger.debugPrint(time)
    -- else
        -- logger.print('lineStopDepartures OK, last departure time = ' .. result .. ', lastDoorsTime would yield ' .. (math.ceil(vehicle.doorsTime / 1000) + 1000))
    end

--[[
    doorsTime is -1 when a vehicle has just left the depot
    and it can be 0 at other early times
    It is always a little sooner then lastDepartureTime, by about 1 second,
    but it may vary.
]]

    return result
end

local getRemainingTimeToPrevious = function(averages, stopIndex, hereIndex, nStops)
    local result = 0

    local nextStopIndex = stopIndex + 1
    while nextStopIndex ~= hereIndex do
        result = result + averages[nextStopIndex].lsd
        nextStopIndex = nextStopIndex + 1
        if nextStopIndex > nStops then nextStopIndex = nextStopIndex - nStops end
    end

    return result
end

local function getNextPredictions(stationGroupId, stationGroup, stationId, station, nEntries, time, onlyTerminalId, predictionsBufferHelpers, lineBuffer, problemLineIds)
    logger.print('getNextPredictions starting')
    logger.print('stationId =') logger.debugPrint(stationId)
    local predictions = {}

    if not(station) or not(station.terminals) or not(nEntries) or nEntries < 1 then return predictions end

    local stationIndexInStationGroupBase0 = utils.getStationIndexInStationGroupBase0(stationId, stationGroup)
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
                        local hereIndex, nextIndex = getHereNextIndexes(line, stationGroupId, stationIndexInStationGroupBase0, terminalIndexBase0)
                        -- local hereIndex, startIndex, endIndex = getHereStartEndIndexesOLD(line, stationGroupId, stationIndexInStationGroupBase0, terminalIndexBase0)
                        -- logger.print('hereIndex, startIndex, endIndex, nStops =', hereIndex, startIndex, endIndex, nStops)
                        logger.print('hereIndex, nextIndex, nStops =', hereIndex, nextIndex, nStops)
                        if nStops < 2 --[[ or problemLineIds[lineId] ]] then
                            predictions[#predictions+1] = {
                                terminalId = terminalId,
                                originStationGroupId = nil, --line.stops[1].stationGroup,
                                destinationStationGroupId = nil, --line.stops[1].stationGroup,
                                nextStationGroupId = nil,
                                arrivalTime = time + 3600, -- add a dummy hour
                                departureTime = time + 3600,
                                isProblem = true,
                            }
                        else
                            local myLineData = getMyLineData(vehicleIds, line, lineId, line.waitingTime, lineBuffer)
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

                                    local lastDepartureTime = getLastDepartureTime(vehicle, time)
                                    logger.print('lastDepartureTime =', lastDepartureTime)
                                    local remainingTimeToPrevious = getRemainingTimeToPrevious(myLineData.averages, vehicle.stopIndex, hereIndex, nStops)

                                    local originIndex = (hereIndex > myLineData.startIndex and hereIndex <= myLineData.endIndex)
                                        and myLineData.startIndex
                                        or myLineData.endIndex
                                    local destIndex = (hereIndex >= myLineData.startIndex and hereIndex < myLineData.endIndex)
                                        and myLineData.endIndex
                                        or myLineData.startIndex

                                    predictions[#predictions+1] = {
                                        terminalId = terminalId,
                                        originStationGroupId = line.stops[originIndex].stationGroup,
                                        destinationStationGroupId = line.stops[destIndex].stationGroup,
                                        nextStationGroupId = line.stops[nextIndex].stationGroup,
                                        arrivalTime = lastDepartureTime + remainingTimeToPrevious + myLineData.averages[hereIndex].st,
                                        departureTime = lastDepartureTime + remainingTimeToPrevious + myLineData.averages[hereIndex].lsd,
                                        lineName = myLineData.name,
                                    }

                                    logger.print('myLineData.period =', myLineData.period)
                                    if #vehicleIds == 1 then -- fill up the display a bit
                                        predictions[#predictions+1] = {
                                            terminalId = terminalId,
                                            originStationGroupId = line.stops[originIndex].stationGroup,
                                            destinationStationGroupId = line.stops[destIndex].stationGroup,
                                            nextStationGroupId = line.stops[nextIndex].stationGroup,
                                            arrivalTime = predictions[#predictions].arrivalTime + myLineData.period,
                                            departureTime = predictions[#predictions].departureTime + myLineData.period,
                                            lineName = myLineData.name,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        terminalIndexBase0 = terminalIndexBase0 + 1
    end

    -- table.sort(predictions, function(a, b) return a.arrivalTime < b.arrivalTime end)
    -- for i = #predictions, 1, -1 do
    --     if i > (nEntries or 0) then
    --         table.remove(predictions, i)
    --     end
    -- end

    predictionsBufferHelpers.set(stationId, onlyTerminalId, predictions)
    return predictions
end

local function tryUpgradeState(state)
--[[
    Routine to fix the old state and update it to new.
    The previous version was only for trains!

    state looked like:
    {
        world_time = 123456,
        placed_signs = {
            [80896] = {
                nearestTerminal = {
                    cargo = false,
                    distance = 3.0044617009524,
                    stationId = 105917,
                    terminalId = 2,
                    terminalTag = 1,
                },
                stationConId = 119445,
            },
            ...
        }
    }

    it now looks like:
    {
        world_time_sec = 123456,
        placed_signs = {
            [107217] = {
                nearestTerminal = {
                    cargo = false,
                    distance = 17.064646354462,
                    stationId = 105915,
                    terminalId = 2,
                    terminalTag = 1,
                },
                stationGroupId = 102655,
            },
            [107218] = {
                nearestTerminal = {
                    isMultiStationGroup = true,
                    refPosition123 = { 1000.1, 1000.1, 1000.1 },
                },
                stationGroupId = 102656,
            },
            [107219] = {
                stationGroupId = 102657,
            },
            ...
        }
    }
]]
    if state.version == constants.currentVersion then return false end

    logger.print('--- state about to be upgraded, old state =') logger.debugPrint(state)

    state.world_time = nil

    for signConId, signState in pairs(state.placed_signs) do
        if not(edgeUtils.isValidAndExistingId(signConId)) then
            -- sign is no more around: clean the state
            logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around ONE')
            stateHelpers.removePlacedSign(signConId)
        else
            -- an entity with the id of our sign is still around
            local signCon = api.engine.getComponent(signConId, api.type.ComponentType.CONSTRUCTION)
            if not(signCon) or not(constructionConfigs.get()[signCon.fileName]) then
                -- sign is no more around or no more supported: clean the state
                logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around TWO')
                stateHelpers.removePlacedSign(signConId)
            else
                logger.print('signState.stationConId =', signState.stationConId)
                if signState.stationConId then -- was removed with version 1
                    if not(edgeUtils.isValidAndExistingId(signState.stationConId)) then
                        -- station is no more around: bulldoze its signs
                        logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around THREE')
                        stateHelpers.removePlacedSign(signConId)
                        utils.bulldozeConstruction(signConId)
                    else
                        local stationCon = api.engine.getComponent(signState.stationConId, api.type.ComponentType.CONSTRUCTION)
                        if not(stationCon) or not(stationCon.stations) then
                            -- station is no more around: bulldoze its signs
                            logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around FOUR')
                            stateHelpers.removePlacedSign(signConId)
                            utils.bulldozeConstruction(signConId)
                        else
                            local stationGroupIdsIndexed = {}
                            for _, stationId in pairs(stationCon.stations) do
                                if edgeUtils.isValidAndExistingId(stationId) then
                                    local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
                                    if station then
                                        local stationGroupId = api.engine.system.stationGroupSystem.getStationGroup(stationId)
                                        if edgeUtils.isValidAndExistingId(stationGroupId) then
                                            stationGroupIdsIndexed[stationGroupId] = {
                                                isCargo = (station and station.cargo or false)
                                            }
                                        end
                                    end
                                end
                            end
                            logger.print('stationGroupIdsIndexed =') logger.debugPrint(stationGroupIdsIndexed)
                            for stationGroupId, sgData in pairs(stationGroupIdsIndexed) do
                                local isStationConCargo = (signState and signState.nearestTerminal and signState.nearestTerminal.cargo) or false
                                if isStationConCargo == sgData.isCargo then
                                    signState.stationGroupId = stationGroupId
                                end
                            end
                            signState.stationConId = nil
                        end
                    end
                end
            end
        end
    end
    state.version = constants.currentVersion
    logger.print('--- state upgraded, new state =') logger.debugPrint(state)
    return true
end

local function update()
    local state = stateHelpers.getState()
    if not(state.is_on) then return end

    local _time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
    if not(_time) then logger.err('update() cannot get time') return end

    if math.fmod(_time, constants.refreshPeriodMsec) ~= 0 then
        -- logger.print('skipping')
    return end
    -- logger.print('doing it')

    xpcall(
        function()
            local _startTick = os.clock()

            local _clockTimeSec = math.floor(_time / 1000)
            -- leave if paused
            if _clockTimeSec == state.world_time_sec then return end

            state.world_time_sec = _clockTimeSec

            local linesBuffer = {}
            local predictionsBuffer = {
                byStation = {},
                byStationTerminal = {}
            }
            local predictionsBufferHelpers = {
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

            tryUpgradeState(state)

            for signConId, signState in pairs(state.placed_signs) do
                -- logger.print('signConId =') logger.debugPrint(signConId)
                -- logger.print('signState =') logger.debugPrint(signState)
                if not(edgeUtils.isValidAndExistingId(signConId)) then
                    -- sign is no more around: clean the state
                    logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around ONE')
                    stateHelpers.removePlacedSign(signConId)
                else
                    -- an entity with the id of our sign is still around
                    local signCon = api.engine.getComponent(signConId, api.type.ComponentType.CONSTRUCTION)
                    -- logger.print('signCon =') logger.debugPrint(signCon)
                    if not(signCon) or not(constructionConfigs.get()[signCon.fileName]) then
                        -- sign is no more around or no more supported: clean the state
                        logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around TWO')
                        stateHelpers.removePlacedSign(signConId)
                    else
                        local formattedPredictions = {}
                        local config = constructionConfigs.get()[signCon.fileName]
                        -- LOLLO NOTE config.maxEntries is tied to the construction type,
                        -- and we buffer:
                        -- make sure sign configs with the same singleTerminal have the same maxEntries
                        if (config.maxEntries or 0) > 0 then
                            if not(signState) or not(edgeUtils.isValidAndExistingId(signState.stationGroupId)) then
                                -- station is no more around: bulldoze its signs
                                logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around THREE')
                                stateHelpers.removePlacedSign(signConId)
                                utils.bulldozeConstruction(signConId)
                            else
                                logger.print('signState.stationGroupId =', signState.stationGroupId)
                                local stationGroup = api.engine.getComponent(signState.stationGroupId, api.type.ComponentType.STATION_GROUP)
                                if not(stationGroup) or not(stationGroup.stations) then
                                    -- station is no more around: bulldoze its signs
                                    logger.warn('signConId' .. (signConId or 'NIL') .. ' is no more around FOUR')
                                    stateHelpers.removePlacedSign(signConId)
                                    utils.bulldozeConstruction(signConId)
                                elseif #stationGroup.stations ~= 0 then
                                    local stationIds = stationGroup.stations
                                    local function _getParamName(subfix) return config.paramPrefix .. subfix end
                                    local rawPredictions = nil
                                    -- the player may have changed the terminal in the construction params
                                    local chosenTerminalId, chosenStationId = utils.getTerminalAndStationId(config, signCon, signState, _getParamName, stationIds)
                                    logger.print('chosenTerminalId =', chosenTerminalId, 'chosenStationId =', chosenStationId)
                                    for _, stationId in pairs(stationIds) do
                                        -- this works coz the table indexes have base 1
                                        if not(chosenStationId) or chosenStationId == stationId then
                                            if edgeUtils.isValidAndExistingId(stationId) then
                                                local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
                                                local nextPredictions = getNextPredictions(
                                                    signState.stationGroupId,
                                                    stationGroup,
                                                    stationId,
                                                    station,
                                                    config.maxEntries,
                                                    _time,
                                                    chosenTerminalId, -- nil if config.singleTerminal == falsy
                                                    predictionsBufferHelpers,
                                                    linesBuffer,
                                                    _problemLineIds
                                                )
                                                if rawPredictions == nil then
                                                    rawPredictions = nextPredictions
                                                else
                                                    logger.print('this concat should never be required except for twin streetside stations')
                                                    arrayUtils.concatValues(rawPredictions, nextPredictions)
                                                end
                                            end
                                        end
                                    end
                                    if rawPredictions then
                                        table.sort(rawPredictions, function(a, b) return a.arrivalTime < b.arrivalTime end)
                                        for i = #rawPredictions, 1, -1 do
                                            if i > (config.maxEntries or 0) then
                                                table.remove(rawPredictions, i)
                                            end
                                        end
                                    end
                                    -- logger.print('rawPredictions =') logger.debugPrint(rawPredictions)
                                    formattedPredictions = utils.getFormattedPredictions(rawPredictions or {}, _time, chosenTerminalId)
                                end
                            end
                        end

                        -- rename the construction
                        local newName = utils.getNewSignConName(
                            formattedPredictions,
                            config,
                            utils.formatClockString(_clockTimeSec),
                            signCon
                        )
                        api.cmd.sendCommand(api.cmd.make.setName(signConId, newName))
                    end
                end
            end

            local executionTime = math.ceil((os.clock() - _startTick) * 1000)
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
            elseif name == constants.events.join_sign_to_station_group then
                logger.print('state before =') logger.debugPrint(stateHelpers.getState())
                if not(args) or not(edgeUtils.isValidAndExistingId(args.signConId)) then return end

                local signCon = api.engine.getComponent(args.signConId, api.type.ComponentType.CONSTRUCTION)
                if not(signCon) then return end

                -- logger.print('constructionConfigs.get() =') logger.debugPrint(constructionConfigs.get())
                -- logger.print('signCon.fileName =', signCon.fileName)
                local config = constructionConfigs.get()[signCon.fileName]
                if not(config) then return end

                -- rename the sign construction so it shows something at once
                local _times = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
                if _times and type(_times.gameTime) == 'number' then
                    local newName = utils.getNewSignConName(
                        {},
                        config,
                        utils.formatClockString(math.floor(_times.gameTime / 1000)),
                        signCon
                    )
                    api.cmd.sendCommand(api.cmd.make.setName(args.signConId, newName))
                end

                local nearestTerminal = config.singleTerminal
                    and stationHelpers.getNearestTerminalWithStationGroup(
                        transfUtilsUG.new(signCon.transf:cols(0), signCon.transf:cols(1), signCon.transf:cols(2), signCon.transf:cols(3)),
                        args.stationGroupId, -- in fact, it is a station group id
                        false -- not only passengers
                    )
                    or nil
                logger.print('freshly calculated nearestTerminal =') logger.debugPrint(nearestTerminal)
                stateHelpers.setPlacedSign(
                    args.signConId,
                    {
                        -- stationConId = args.stationConId,
                        stationGroupId = args.stationGroupId,
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
