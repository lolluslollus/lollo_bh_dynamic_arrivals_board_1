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
local function _getAdjacentNodeIds(availableNodeIds, startNodeId)
    local _nodeIdsIndexed = _getIdsIndexed(availableNodeIds)
    local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
    local visitedNodeIds_Indexed = {}

    local function _getNextNodes(nodeId)
        if visitedNodeIds_Indexed[nodeId] or not(_nodeIdsIndexed[nodeId]) then return {} end

        local adjacentEdgeIds_c = _map[nodeId] -- userdata
        visitedNodeIds_Indexed[nodeId] = true

        if adjacentEdgeIds_c == nil then
            logger.warn('FOUR')
            return {}
        else
            local nextNodes = {}
            for _, edgeId in pairs(adjacentEdgeIds_c) do -- cannot use adjacentEdge1Ids_c[index] here
                local newNodeIds = _getNodeIdsOfEdge(edgeId)
                for i = 1, 2, 1 do
                    if newNodeIds[i] and not(visitedNodeIds_Indexed[newNodeIds[i]]) and _nodeIdsIndexed[newNodeIds[i]] then nextNodes[#nextNodes+1] = newNodeIds[i] end
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

local _getNearestTerminalsWithStationConUNUSED = function(transf, stationConId, isOnlyPassengers)
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
                local vehicleNodeId = terminalProps.vehicleNodeId.entity
                stationTerminalNodesMap[stationId][terminalId] = {
                    nodeIds = _getAdjacentNodeIds(stationCon.frozenNodes, vehicleNodeId),
                    tag = terminalProps.tag,
                }
            end
        end
    end
    logger.print('stationTerminalNodesMap =') logger.debugPrint(stationTerminalNodesMap)

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
end

local _getNearestTerminalsWithStationGroup = function(transf, stationGroupId, isOnlyPassengers)
    logger.print('_getNearestTerminalsWithStationGroup starting, stationGroupId =', stationGroupId or 'NIL')
    if type(transf) ~= 'table' or not(edgeUtils.isValidAndExistingId(stationGroupId)) then return nil end

    local _stationGroup = api.engine.getComponent(stationGroupId, api.type.ComponentType.STATION_GROUP)
    if not(_stationGroup) or not(_stationGroup.stations) then return nil end

    local _refPosition123 = {transf[13], transf[14], transf[15]}
    local stationTerminalPositionsMap = {}
    for _, stationId in pairs(_stationGroup.stations) do
        logger.print('stationId =', stationId or 'NIL')
        local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
        if not(station.cargo) or not(isOnlyPassengers) then -- a station construction can have two stations: one for passengers and one for cargo
            stationTerminalPositionsMap[stationId] = {}
            for terminalId, terminal in pairs(station.terminals) do
                logger.print('terminalId =', terminalId or 'NIL')
                if terminal and terminal.vehicleNodeId and terminal.vehicleNodeId.entity
                and edgeUtils.isValidAndExistingId(terminal.vehicleNodeId.entity) then
                    -- entity is an edge with street stations,
                    -- a node with train stations,
                    -- a con with street station constructions
                    local edgeOrNodeOrConId = terminal.vehicleNodeId.entity
                    if edgeUtils.isValidAndExistingId(edgeOrNodeOrConId) then
                        logger.print('edgeOrNodeOrConId =', edgeOrNodeOrConId or 'NIL')
                        local positions = {}
                        local baseNode = api.engine.getComponent(edgeOrNodeOrConId, api.type.ComponentType.BASE_NODE)
                        if baseNode then
                            logger.print('it is a node')
                            -- train stations, they can have a lot of frozen nodes
                            local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForStation(stationId)
                            if edgeUtils.isValidAndExistingId(conId) then
                                logger.print('con found')
                                local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
                                if con and con.frozenNodes then
                                    for _, nodeId in pairs(_getAdjacentNodeIds(con.frozenNodes, edgeOrNodeOrConId)) do
                                        local adjacentNode = api.engine.getComponent(nodeId, api.type.ComponentType.BASE_NODE)
                                        if adjacentNode then
                                            positions[#positions+1] = adjacentNode.position
                                        end
                                    end
                                else
                                    logger.warn('this should not happen, _getNearestTerminalsWithStationGroup got conId =', conId)
                                end
                            end
                        else
                            local baseEdge = api.engine.getComponent(edgeOrNodeOrConId, api.type.ComponentType.BASE_EDGE)
                            if baseEdge then
                                logger.print('it is an edge')
                                -- streetside stations
                                return {
                                    isMultiStationGroup = true,
                                    refPosition123 = _refPosition123
                                }
                            else
                                local con = api.engine.getComponent(edgeOrNodeOrConId, api.type.ComponentType.CONSTRUCTION)
                                if con then
                                    logger.print('it is a con')
                                    -- road stations with construction: they only freeze one node
                                    -- custom road stations with construction: they can freeze more nodes
                                    -- ports: they freeze no nodes
                                    -- in both cases, I cannot assign a terminal automatically
                                    if con.frozenNodes and #con.frozenNodes > 1 then
                                        for _, nodeId in pairs(con.frozenNodes) do
                                            local frozenNode = api.engine.getComponent(nodeId, api.type.ComponentType.BASE_NODE)
                                            if frozenNode and frozenNode.position then
                                                positions[#positions+1] = frozenNode.position
                                            end
                                        end
                                    elseif con.transf then
                                        positions[#positions+1] = con.transf:cols(3)
                                    end
                                else
                                    logger.warn('_getNearestTerminalsWithStationGroup found no base node no base edge and no con!')
                                end
                            end
                        end
                        stationTerminalPositionsMap[stationId][terminalId] = {
                            positions = positions or {},
                            tag = terminal.tag, -- these tags can be nil and cannot be relied upon
                        }
                    end
                end
            end
        end
    end
    logger.print('stationTerminalNodesMap =') logger.debugPrint(stationTerminalPositionsMap)
    -- two streetside stations on opposite sides will produce identical results coz they are tied to an edge

    local nearestTerminals = {}

    for stationId, myStationData in pairs(stationTerminalPositionsMap) do
        nearestTerminals[stationId] = {terminalId = nil, terminalTag = nil, cargo = myStationData.cargo, distance = 9999}
        for terminalId, terminal in pairs(myStationData) do
            for _, position in pairs(terminal.positions) do
                local distance = edgeUtils.getPositionsDistance(
                    position,
                    _refPosition123
                )
                if distance < nearestTerminals[stationId].distance then
                    nearestTerminals[stationId].terminalId = terminalId
                    nearestTerminals[stationId].terminalTag = terminal.tag
                    nearestTerminals[stationId].cargo = myStationData.cargo or false
                    nearestTerminals[stationId].distance = distance
                end
            end
        end
    end

    logger.print('nearestTerminals =') logger.debugPrint(nearestTerminals)
    return nearestTerminals
end

local _getNearbyTrainStationGroupsIndexed = function(transf, searchRadius, isOnlyPassengers)
    logger.print('_getNearbyTrainStationGroupsIndexed starting, isOnlyPassengers =', isOnlyPassengers or 'NIL')
    if type(transf) ~= 'table' then return {} end
    if tonumber(searchRadius) == nil then searchRadius = constants.searchRadius4NearbyStation2JoinMetres end

    -- LOLLO NOTE in the game and in this mod, there is one train station for each station group
    -- and viceversa. Station groups hold some information that stations don't, tho.
    -- Multiple station groups can share a construction.
    -- Road stations instead can have more stations in a station group.
    -- What I really want here is a list with one item each construction, but that could be an expensive loop,
    -- so I check the stations instead and index by the construction.

    local conBuffer = {}
    local stationIdsIndexed = {}
    local _edgeIds = edgeUtils.getNearbyObjectIds(transf, searchRadius, api.type.ComponentType.BASE_EDGE_TRACK)
    for _, edgeId in pairs(_edgeIds) do
        local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(edgeId)
        if edgeUtils.isValidAndExistingId(conId) then
            local con = conBuffer[conId] or api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
            if con and con.stations then
                conBuffer[conId] = {stations = con.stations, transf = con.transf}
                for _, stationId in pairs(con.stations) do
                    stationIdsIndexed[stationId] = {
                        conId = conId,
                        conPosition = transfUtils.xYZ2OneTwoThree(con.transf:cols(3))
                    }
                end
            else
                conBuffer[conId] = {} -- also buffer invalid stations so we don't need more api calls
            end
        end
    end
    logger.print('stationIdsIndexed =') logger.debugPrint(stationIdsIndexed)

    -- local _station2ConstructionMap = api.engine.system.streetConnectorSystem.getStation2ConstructionMap()
    local _resultsIndexed = {}
    for stationId, myStationData in pairs(stationIdsIndexed) do
        if edgeUtils.isValidAndExistingId(stationId) then
            local conId = myStationData.conId
            local conPosition = myStationData.conPosition
            logger.print('found conId =', conId, 'and its position')
            local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
            if conPosition and station then
                local isStationCargo = station.cargo or false
                logger.print('isStationCargo =', isStationCargo)
                if not(isStationCargo) or not(isOnlyPassengers) then
                    local stationGroupId = api.engine.system.stationGroupSystem.getStationGroup(stationId)
                    local name = ''
                    local stationGroupName = api.engine.getComponent(stationGroupId, api.type.ComponentType.NAME)
                    if stationGroupName ~= nil then name = stationGroupName.name end

                    local isTwinCargo = false
                    local isTwinPassenger = false

                    if _resultsIndexed[stationGroupId] ~= nil then
                        -- logger.print('found a twin, it is') logger.debugPrint(resultsIndexed[conId])
                        if stringUtils.isNullOrEmptyString(name) then
                            name = _resultsIndexed[stationGroupId].name
                        end
                        if _resultsIndexed[stationGroupId].isCargo then isTwinCargo = true end
                        if _resultsIndexed[stationGroupId].isPassenger then isTwinPassenger = true end
                    end
                    _resultsIndexed[stationGroupId] = {
                        id = stationGroupId,
                        isCargo = isStationCargo or isTwinCargo,
                        isPassenger = not(isStationCargo) or isTwinPassenger,
                        name = name or '',
                        position = conPosition
                    }
                end
            end
        end
    end
    -- logger.print('resultsIndexed =') logger.debugPrint(_resultsIndexed)
    return _resultsIndexed
end

local utils = {
    getNearbyStationConsUNUSED = function(transf, searchRadius, isOnlyPassengers)
        if type(transf) ~= 'table' then return {} end
        if tonumber(searchRadius) == nil then searchRadius = constants.searchRadius4NearbyStation2JoinMetres end

        -- LOLLO NOTE in the game and in this mod, there is one train station for each station group
        -- and viceversa. Station groups hold some information that stations don't, tho.
        -- Multiple station groups can share a construction.
        -- Road stations instead can have more stations in a station group.
        -- What I really want here is a list with one item each construction, but that could be an expensive loop,
        -- so I check the stations instead and index by the construction.

        local stationIdsIndexed = {}
        local _edgeIds = edgeUtils.getNearbyObjectIds(transf, searchRadius, api.type.ComponentType.BASE_EDGE_TRACK)
        for key, edgeId in pairs(_edgeIds) do
            local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(edgeId)
            if edgeUtils.isValidAndExistingId(conId) then
                local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
                if con and con.stations then
                    for _, stationId in pairs(con.stations) do
                        stationIdsIndexed[stationId] = true
                    end
                end
            end
        end
        logger.print('stationIdsIndexed =') logger.debugPrint(stationIdsIndexed)

        local _station2ConstructionMap = api.engine.system.streetConnectorSystem.getStation2ConstructionMap()
        local _resultsIndexed = {}
        for stationId, _ in pairs(stationIdsIndexed) do
            if edgeUtils.isValidAndExistingId(stationId) then
                local conId = _station2ConstructionMap[stationId]
                if edgeUtils.isValidAndExistingId(conId) then
                    logger.print('found conId =', conId)
                    local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
                    local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
                    if con and station then
                        local isCargo = station.cargo or false
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
                            _resultsIndexed[conId] = {
                                id = conId,
                                isCargo = isCargo or isTwinCargo,
                                isPassenger = not(isCargo) or isTwinPassenger,
                                name = name,
                                position = transfUtils.xYZ2OneTwoThree(con.transf:cols(3))
                            }
                        end
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
    getNearbyStationGroups = function(transf, searchRadius, isOnlyPassengers)
        logger.print('getNearbyStationGroups starting, isOnlyPassengers =', isOnlyPassengers or 'NIL')
        if type(transf) ~= 'table' then return {} end
        if tonumber(searchRadius) == nil then searchRadius = constants.searchRadius4NearbyStation2JoinMetres end

        -- LOLLO NOTE in the game and in this mod, there is one train station for each station group
        -- and viceversa. Station groups hold some information that stations don't, tho.
        -- Streetside stations on opposite sides can share a station group instead.
        -- Multiple station groups can share a construction.
        -- What I really want here is a list with one item each construction, but that could be an expensive loop,
        -- so I check the stations instead and index by the construction.

        local _stationGroupIds = edgeUtils.getNearbyObjectIds(transf, searchRadius, api.type.ComponentType.STATION_GROUP)
        local _resultsIndexed = {}
        for _, stationGroupId in pairs(_stationGroupIds) do
            logger.print('stationGroupId =', stationGroupId or 'NIL')
            if edgeUtils.isValidAndExistingId(stationGroupId) then
                local stationGroup = api.engine.getComponent(stationGroupId, api.type.ComponentType.STATION_GROUP)
                if stationGroup and stationGroup.stations then
                    local stationGroupName_struct = api.engine.getComponent(stationGroupId, api.type.ComponentType.NAME)
                    local stationGroupName = (stationGroupName_struct and stationGroupName_struct.name) and stationGroupName_struct.name or ''
                    local isStationGroupWithCargo = false
                    local isStationGroupWithPassengers = false
                    local position = { x = 0, y = 0, z = 0 }
                    local nSamples4Average = 0
                    for _, stationId in pairs(stationGroup.stations) do
                        logger.print('stationId =', stationId or 'NIL')
                        if edgeUtils.isValidAndExistingId(stationId) then
                            local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
                            if station and station.terminals then
                                local isStationCargo = station.cargo or false
                                isStationGroupWithCargo = isStationGroupWithCargo or isStationCargo
                                isStationGroupWithPassengers = isStationGroupWithPassengers or not(isStationCargo)
                                logger.print('isStationCargo =', isStationCargo)
                                if not(isStationCargo) or not(isOnlyPassengers) then
                                    -- local isStreet = false
                                    logger.print('#station.terminals =', #station.terminals)
                                    for _, terminal in pairs(station.terminals) do
                                        if terminal and terminal.vehicleNodeId and terminal.vehicleNodeId.entity
                                        and edgeUtils.isValidAndExistingId(terminal.vehicleNodeId.entity) then
                                            -- entity is an edge with street stations,
                                            -- a node with train stations,
                                            -- a con with street station constructions
                                            local edgeOrNodeOrConId = terminal.vehicleNodeId.entity
                                            if edgeUtils.isValidAndExistingId(edgeOrNodeOrConId) then
                                                logger.print('edgeOrNodeOrConId =', edgeOrNodeOrConId or 'NIL')
                                                local baseNode = api.engine.getComponent(edgeOrNodeOrConId, api.type.ComponentType.BASE_NODE)
                                                if baseNode then
                                                    logger.print('it is a node')
                                                    -- train stations -- we could do them later but this is safer, tho redundant
                                                        -- isStreet = false
                                                    position.x = position.x + baseNode.position.x
                                                    position.y = position.y + baseNode.position.y
                                                    position.z = position.z + baseNode.position.z
                                                    -- logger.print('position =') logger.debugPrint(position)
                                                    nSamples4Average = nSamples4Average + 1
                                                else
                                                    local baseEdge = api.engine.getComponent(edgeOrNodeOrConId, api.type.ComponentType.BASE_EDGE)
                                                    if baseEdge then
                                                        logger.print('it is an edge')
                                                        -- streetside stations
                                                        -- isStreet = true
                                                        local baseNode0 = api.engine.getComponent(baseEdge.node0, api.type.ComponentType.BASE_NODE)
                                                        local baseNode1 = api.engine.getComponent(baseEdge.node1, api.type.ComponentType.BASE_NODE)
                                                        local midPosition = edgeUtils.getPositionsMiddle(baseNode0.position, baseNode1.position)
                                                        position.x = position.x + midPosition.x
                                                        position.y = position.y + midPosition.y
                                                        position.z = position.z + midPosition.z
                                                        -- logger.print('position =') logger.debugPrint(position)
                                                        nSamples4Average = nSamples4Average + 1
                                                    else
                                                        local con = api.engine.getComponent(edgeOrNodeOrConId, api.type.ComponentType.CONSTRUCTION)
                                                        if con then
                                                            logger.print('it is a con')
                                                            -- road stations with construction: they only freeze one node
                                                            -- custom road stations with construction: they can freeze more nodes
                                                            -- ports: they freeze no nodes
                                                            -- if con.frozenNodes and #con.frozenNodes > 1 then
                                                            --     for _, nodeId in pairs(con.frozenNodes) do
                                                            --         local frozenNode = api.engine.getComponent(nodeId, api.type.ComponentType.BASE_NODE)
                                                            --         if frozenNode and frozenNode.position then
                                                            --             position.x = position.x + frozenNode.position.x
                                                            --             position.y = position.y + frozenNode.position.y
                                                            --             position.z = position.z + frozenNode.position.z
                                                            --             nSamples4Average = nSamples4Average + 1
                                                            --         end
                                                            --     end
                                                            -- elseif con.transf then
                                                            if con.transf then
                                                                local conPosition = con.transf:cols(3)
                                                                position.x = position.x + conPosition.x
                                                                position.y = position.y + conPosition.y
                                                                position.z = position.z + conPosition.z
                                                                nSamples4Average = nSamples4Average + 1
                                                            end
                                                        else
                                                            logger.warn('getNearbyStationGroups found no base node no base edge and no con!')
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if nSamples4Average > 0 then
                        _resultsIndexed[stationGroupId] = {
                            id = stationGroupId,
                            isCargo = isStationGroupWithCargo,
                            isPassenger = isStationGroupWithPassengers,
                            -- isStreet = isStreet,
                            name = stationGroupName,
                            position = {
                                position.x / nSamples4Average,
                                position.y / nSamples4Average,
                                position.z / nSamples4Average,
                            }
                        }
                    end
                end
            end
        end
        logger.print('resultsIndexed before adding train stations =') logger.debugPrint(_resultsIndexed)
        -- this may be a little redundant but train stations can be really huge
        -- and we never know how far our panels are meant to be located.
        arrayUtils.concatKeysValues(_resultsIndexed, _getNearbyTrainStationGroupsIndexed(transf, 1.5 * searchRadius, isOnlyPassengers))
        logger.print('resultsIndexed after adding train stations =') logger.debugPrint(_resultsIndexed)
        local results = {}
        for _, value in pairs(_resultsIndexed) do
            results[#results+1] = value
        end
        -- logger.print('# nearby freestyle stations = ', #results)
        -- logger.print('nearby freestyle stations = ') logger.debugPrint(results)
        return results
    end,
    getNearestTerminalWithStationConUNUSED = function(transf, stationConId, isOnlyPassengers)
        local nearestTerminals = _getNearestTerminalsWithStationConUNUSED(transf, stationConId, isOnlyPassengers)
        if not(nearestTerminals) then return nil end

        local result = nil
        for stationId, station in pairs(nearestTerminals) do
            if not(result) or result.distance > station.distance then
                result = station
                result.stationId = stationId
            end
        end

        return result
    end,
    getNearestTerminalWithStationGroup = function(transf, stationGroupId, isOnlyPassengers)
        logger.print('getNearestTerminalWithStationGroup starting, isOnlyPassengers =', isOnlyPassengers or 'NIL')
        local nearestTerminals = _getNearestTerminalsWithStationGroup(transf, stationGroupId, isOnlyPassengers)
        if not(nearestTerminals) then return nil end

        if nearestTerminals.isMultiStationGroup then
            return {
                isMultiStationGroup = true,
                refPosition123 = nearestTerminals.refPosition123
            }
        end

        local result = {distance = 9999}
        for stationId, myStationData in pairs(nearestTerminals) do
            if result.distance > myStationData.distance then
                result = myStationData
            end
        end

        return result
    end
}

return utils
