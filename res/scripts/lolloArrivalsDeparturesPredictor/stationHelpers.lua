local arrayUtils = require('lolloArrivalsDeparturesPredictor.arrayUtils')
local constants = require('lolloArrivalsDeparturesPredictor.constants')
local edgeUtils = require('lolloArrivalsDeparturesPredictor.edgeUtils')
local logger = require('lolloArrivalsDeparturesPredictor.logger')
local stringUtils = require('lolloArrivalsDeparturesPredictor.stringUtils')
local transfUtils = require('lolloArrivalsDeparturesPredictor.transfUtils')
local transfUtilsUG = require('transf')


local frozenNodeIds_test = {
    [1] = 3889,
    [2] = 25744,
    [3] = 25927,
    [4] = 25934,
    [5] = 26157,
    [6] = 26314,
    [7] = 26322,
    [8] = 26425,
    [9] = 26622,
    [10] = 13218,
    [11] = 25700,
}

local startNodeId_test = 26322

local function _getIdsIndexed(nodeIds)
    local results = {}
    for _, nodeId in pairs(nodeIds) do
        results[nodeId] = true
    end
    return results
end

local function _getNodeIdsOfEdge(edgeId)
    if not(edgeUtils.isValidAndExistingId(edgeId)) then return {nil, nil} end

    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    if not(baseEdge) then return {nil, nil} end

    return {baseEdge.node0, baseEdge.node1} -- an edge always has 2 nodes
end
-- LOLLO TODO with certain configurations, the nearest terminal estimator
-- may be more accurate if you check the distance between point and edge,
-- rather than point and point.
local function getNodeIds4Terminal(frozenNodeIds, startNodeId)
    local _frozenNodeIds_Indexed = _getIdsIndexed(frozenNodeIds)
    local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
    local visitedNodeIds_Indexed = {}

    local function _getNextNodes(nodeId)
        if visitedNodeIds_Indexed[nodeId] or not(_frozenNodeIds_Indexed[nodeId]) then return {} end

        local adjacentEdgeIds_c = _map[nodeId] -- userdata
        visitedNodeIds_Indexed[nodeId] = true

        if adjacentEdgeIds_c == nil then
            logger.print('Warning: FOUR')
            return {}
        else
            local nextNodes = {}
            for _, edgeId in pairs(adjacentEdgeIds_c) do -- cannot use adjacentEdge1Ids_c[index] here
                local newNodeIds = _getNodeIdsOfEdge(edgeId)
                for i = 1, 2, 1 do
                    if newNodeIds[i] and not(visitedNodeIds_Indexed[newNodeIds[i]]) and _frozenNodeIds_Indexed[newNodeIds[i]] then nextNodes[#nextNodes+1] = newNodeIds[i] end
                end
            end
            -- logger.print('FIVE')
            return nextNodes
        end
    end

    local results = {startNodeId}
    local nextResults = _getNextNodes(startNodeId)
    local isExit = false
    while not(isExit) do
        local tempResults = {}
        isExit = true
        for _, nodeId in pairs(nextResults) do
            results[#results+1] = nodeId
            arrayUtils.concatValues(tempResults, _getNextNodes(nodeId))
            isExit = false
        end
        nextResults = tempResults
    end

    return results
end

local utils = {
    getNearbyStationCons = function(transf, searchRadius, isOnlyPassengers)
        if type(transf) ~= 'table' then return {} end
        if tonumber(searchRadius) == nil then searchRadius = constants.searchRadius4NearbyStation2JoinMetres end

        -- LOLLO NOTE in the game and in this mod, there is one train station for each station group
        -- and viceversa. Station groups hold some information that stations don't, tho.
        -- Multiple station groups can share a construction.
        -- What I really want here is a list with one item each construction, but that could be an expensive loop,
        -- so I check the stations instead and index by the construction.

        local _stationIds = {}
        local _edgeIds = edgeUtils.getNearbyObjectIds(transf, searchRadius, api.type.ComponentType.BASE_EDGE_TRACK)
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
        logger.print('_stationIds =') logger.debugPrint(_stationIds)

        local _station2ConstructionMap = api.engine.system.streetConnectorSystem.getStation2ConstructionMap()
        local _resultsIndexed = {}
        for _, stationId in pairs(_stationIds) do
            if edgeUtils.isValidAndExistingId(stationId) then
                local conId = _station2ConstructionMap[stationId]
                if edgeUtils.isValidAndExistingId(conId) then
                    logger.print('found conId =', conId)
                    local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
                    -- logger.print('construction.name =') logger.debugPrint(con.name) -- nil
                    local isCargo = api.engine.getComponent(stationId, api.type.ComponentType.STATION).cargo or false
                    logger.print('isCargo =', isCargo)
                    logger.print('isOnlyPassengers =', isOnlyPassengers)
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
    end,
    getNearestTerminals = function(transf, stationConId, isOnlyPassengers)
        if type(transf) ~= 'table' or not(edgeUtils.isValidAndExistingId(stationConId)) then return nil end

        local pos = {transf[13], transf[14], transf[15]}
        -- the station can have many forms
        -- a terminal is not a point but a collection of edges, and edges have nodes.
        -- I need to iterate across those collections of edges and find the one collection (ie the terminal)
        -- that contains the edge closest to pos.
        -- construction.frozenNodes[] and construction.frozenEdges[] only contain tracks;
        -- there is no telling to which terminal they belong
        -- station.terminals[].personNodes and station.terminals[].personEdges do not have a position
        -- station.terminals[].vehicleNodeId.entity is an actual node, and it is in the construction.frozenNodes[]
        -- starting from it, I can move left and see which nodes I come upon.
        -- As soon as one node is not frozen, return
        -- Repeat to the right.
        -- This way, I can tell which vehicle nodes belong to which terminal

        local stationCon = api.engine.getComponent(stationConId, api.type.ComponentType.CONSTRUCTION)
        if not(stationCon) or not(stationCon.stations) then return nil end

        local stationTerminalNodesMap = {}
        for _, stationId in pairs(stationCon.stations) do
            local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
            if not(station.cargo) or not(isOnlyPassengers) then -- a station construction can have two stations: one for passengers and one for cargo
                stationTerminalNodesMap[stationId] = {}
                for terminalId, terminalProps in pairs(station.terminals) do
                    -- print(terminalId, terminalProps.tag, terminalProps.vehicleNodeId.entity)
                    local vehicleNodeId = terminalProps.vehicleNodeId.entity
                    stationTerminalNodesMap[stationId][terminalId] = {
                        nodeIds = getNodeIds4Terminal(stationCon.frozenNodes, vehicleNodeId),
                        tag = terminalProps.tag,
                    }
                end
            end
        end

        local nearestTerminals = {}
        for stationId, station in pairs(stationTerminalNodesMap) do
            nearestTerminals[stationId] = {terminalId = nil, terminalTag = nil, cargo = station.cargo, distance = 9999}
            for terminalId, terminal in pairs(station) do
                for _, nodeId in pairs(terminal.nodeIds) do
                    local distance = edgeUtils.getPositionsDistance(
                        api.engine.getComponent(nodeId, api.type.ComponentType.BASE_NODE).position,
                        pos
                    )
                    if distance < nearestTerminals[stationId].distance then
                        nearestTerminals[stationId].terminalId = terminalId
                        nearestTerminals[stationId].terminalTag = terminal.tag
                        nearestTerminals[stationId].cargo = station.cargo or false
                        nearestTerminals[stationId].distance = distance
                    end
                end
            end
        end

        return nearestTerminals
    end,
}

utils.getNearestTerminal = function(transf, stationConId)
    local nearestTerminals = utils.getNearestTerminals(transf, stationConId, false)
    if not(nearestTerminals) then return nil end

    local result = nil
    for stationId, station in pairs(nearestTerminals) do
        if not(result) or result.distance > station.distance then
            result = station
            result.stationId = stationId
        end
    end

    return result
end

return utils
