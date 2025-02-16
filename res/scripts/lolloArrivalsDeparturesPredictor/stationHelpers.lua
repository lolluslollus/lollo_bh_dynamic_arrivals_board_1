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
local function _getNodePositionsOfEdge(edgeId)
    local nodeIds = _getNodeIdsOfEdge(edgeId)
    local result = {position0 = nil, position1 = nil}
    for i = 1, 2, 1 do
        if edgeUtils.isValidId(nodeIds[i]) then
            local baseNode = api.engine.getComponent(nodeIds[i], api.type.ComponentType.BASE_NODE)
            if baseNode ~= nil then
                if i == 1 then
                    result.position0 = baseNode.position
                else
                    result.position1 = baseNode.position
                end
            end
        end
    end
    return result
end
-- LOLLO NOTE with certain configurations, the nearest terminal estimator
-- may be more accurate if you check the distance between point and edge,
-- rather than point and point.
local function _getAdjacentNodeIds(availableNodeIds, startNodeId)
    local _nodeIdsIndexed = _getIdsIndexed(availableNodeIds)
    local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
    local visitedNodeIds_Indexed = {}

    local function _getNextNodeIds(nodeId)
        if visitedNodeIds_Indexed[nodeId] or not(_nodeIdsIndexed[nodeId]) then return {} end

        local adjacentEdgeIds_c = _map[nodeId] -- userdata
        visitedNodeIds_Indexed[nodeId] = true

        if adjacentEdgeIds_c == nil then
            logger.warn('_getAdjacentNodeIds FOUR')
            return {}
        end

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

    local results = {startNodeId}
    local nextResults = _getNextNodeIds(startNodeId)
    local isExit = false
    while not(isExit) do
        local tempResults = {}
        isExit = true
        for _, nodeId in pairs(nextResults) do
            results[#results+1] = nodeId
            arrayUtils.concatValues(tempResults, _getNextNodeIds(nodeId))
            isExit = false
        end
        nextResults = tempResults
    end
    return results
end
local function _getAdjacentEdgeIds(availableEdgeIds, startNodeId)
    local _edgeIdsIndexed = _getIdsIndexed(availableEdgeIds)
    local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
    local visitedEdgeIds_Indexed = {}
    local visitedNodeIds_Indexed = {}

    local function _getNextNodeIds(nodeId)
        if visitedNodeIds_Indexed[nodeId] then return {} end

        local adjacentEdgeIds_c = _map[nodeId] -- userdata
        visitedNodeIds_Indexed[nodeId] = true

        if adjacentEdgeIds_c == nil then
            logger.warn('_getAdjacentEdgeIds FOUR')
            return {}
        end

        local nextNodes = {}
        for _, edgeId in pairs(adjacentEdgeIds_c) do -- cannot use adjacentEdge1Ids_c[index] here
            if not(visitedEdgeIds_Indexed[edgeId]) and _edgeIdsIndexed[edgeId] then
                visitedEdgeIds_Indexed[edgeId] = true
                local newNodeIds = _getNodeIdsOfEdge(edgeId)
                for i = 1, 2, 1 do
                    if newNodeIds[i] and not(visitedNodeIds_Indexed[newNodeIds[i]]) then nextNodes[#nextNodes+1] = newNodeIds[i] end
                end
            end
        end
        -- logger.print('FIVE')
        return nextNodes
    end

    local nextNodeIds = _getNextNodeIds(startNodeId)
    local isExit = false
    while not(isExit) do
        local tempNodeIds = {}
        isExit = true
        for _, nodeId in pairs(nextNodeIds) do
            arrayUtils.concatValues(tempNodeIds, _getNextNodeIds(nodeId))
            isExit = false
        end
        nextNodeIds = tempNodeIds
    end
    local results = {}
    for edgeId, _ in pairs(visitedEdgeIds_Indexed) do
        results[#results+1] = edgeId
    end
    return results
end
---@param signTransf table<integer>
---@param stationGroupId integer
---@param isOnlyPassengers boolean
---@return nil|nearest_terminal_streetside|table<integer, nearest_terminal_generic>
local _getNearestTerminalsWithStationGroup = function(signTransf, stationGroupId, isOnlyPassengers)
    logger.print('_getNearestTerminalsWithStationGroup starting, stationGroupId =', tostring(stationGroupId))
    if type(signTransf) ~= 'table' or not(edgeUtils.isValidAndExistingId(stationGroupId)) then return nil end

    local _stationGroup = api.engine.getComponent(stationGroupId, api.type.ComponentType.STATION_GROUP)
    if not(_stationGroup) or not(_stationGroup.stations) then return nil end

    local _signPosition123 = {signTransf[13], signTransf[14], signTransf[15]}
    local stationTerminalPositionsMap = {}
    for _, stationId in pairs(_stationGroup.stations) do
        logger.print('stationId =', tostring(stationId))
        if edgeUtils.isValidAndExistingId(stationId) then
            local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION)
            if not(station.cargo) or not(isOnlyPassengers) then -- a station construction can have two stations: one for passengers and one for cargo
                stationTerminalPositionsMap[stationId] = {}
                for terminalId, terminal in pairs(station.terminals) do
                    logger.print('terminalId =', tostring(terminalId))
                    if terminal ~= nil and terminal.vehicleNodeId ~= nil
                    and edgeUtils.isValidAndExistingId(terminal.vehicleNodeId.entity) then
                        -- vehicleNodeId.entity is an edge with street stations,
                        -- a node with train stations,
                        -- a con with street station constructions
                        local edgeOrNodeOrConId = terminal.vehicleNodeId.entity
                        if edgeUtils.isValidAndExistingId(edgeOrNodeOrConId) then
                            logger.print('edgeOrNodeOrConId =', tostring(edgeOrNodeOrConId))
                            local positions = {}
                            local segments = {}
                            local baseNode = api.engine.getComponent(edgeOrNodeOrConId, api.type.ComponentType.BASE_NODE)
                            if baseNode ~= nil then
                                logger.print('it is a node')
                                -- train stations; they can have a lot of frozen nodes
                                local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForStation(stationId)
                                if edgeUtils.isValidAndExistingId(conId) then
                                    logger.print('con found')
                                    local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
                                    if con ~= nil and con.frozenNodes ~= nil then
                                        for _, edgeId in pairs(_getAdjacentEdgeIds(con.frozenEdges, edgeOrNodeOrConId)) do
                                            local adjacentEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
                                            if adjacentEdge ~= nil then
                                                segments[#segments+1] = _getNodePositionsOfEdge(edgeId)
                                            end
                                        end
                                        -- for _, nodeId in pairs(_getAdjacentNodeIds(con.frozenNodes, edgeOrNodeOrConId)) do
                                        --     -- logger.print('#nodeId ' .. tostring(nodeId) .. ' is in terminal ' .. tostring(terminalId))
                                        --     local adjacentNode = api.engine.getComponent(nodeId, api.type.ComponentType.BASE_NODE)
                                        --     if adjacentNode ~= nil then
                                        --         positions[#positions+1] = adjacentNode.position
                                        --     end
                                        -- end
                                        -- print('positions =') debugPrint(positions)
                                    else
                                        logger.warn('this should not happen, _getNearestTerminalsWithStationGroup got conId =', tostring(conId))
                                    end
                                end
                            else
                                local baseEdge = api.engine.getComponent(edgeOrNodeOrConId, api.type.ComponentType.BASE_EDGE)
                                if baseEdge ~= nil then
                                    logger.print('it is an edge')
                                    -- streetside stations
                                    return {
                                        isMultiStationGroup = true,
                                        refPosition123 = _signPosition123
                                    }
                                else
                                    local con = api.engine.getComponent(edgeOrNodeOrConId, api.type.ComponentType.CONSTRUCTION)
                                    if con ~= nil then
                                        logger.print('it is a con')
                                        -- airports freeze more nodes
                                        -- road stations freeze 1 or more nodes
                                        -- ports freeze 0 nodes
                                        -- in all cases, I cannot assign a terminal automatically
                                        -- if con.frozenNodes ~= nil and #con.frozenNodes > 1 then
                                        --     for _, nodeId in pairs(con.frozenNodes) do
                                        --         local frozenNode = api.engine.getComponent(nodeId, api.type.ComponentType.BASE_NODE)
                                        --         if frozenNode ~= nil and frozenNode.position ~= nil then
                                        --             positions[#positions+1] = frozenNode.position
                                        --         end
                                        --     end
                                        -- elseif con.transf ~= nil then
                                        --     positions[#positions+1] = con.transf:cols(3)
                                        -- end
                                        if con.transf ~= nil then
                                            positions[#positions+1] = con.transf:cols(3)
                                        end
                                    else
                                        logger.warn('_getNearestTerminalsWithStationGroup found no base node no base edge and no con!')
                                    end
                                end
                            end
                            stationTerminalPositionsMap[stationId][terminalId] = {
                                positions = positions or {},
                                segments = segments or {},
                                tag = terminal.tag, -- these tags can be nil and cannot be relied upon
                            }
                        end
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
            for _, segment in pairs(terminal.segments) do
                if segment ~= nil and segment.position0 ~= nil and segment.position1 ~= nil then
                    local distance = transfUtils.getDistanceBetweenPointAndStraight(
                        segment.position0,
                        segment.position1,
                        _signPosition123
                    )
                    if distance < nearestTerminals[stationId].distance then
                        nearestTerminals[stationId].terminalId = terminalId
                        nearestTerminals[stationId].terminalTag = terminal.tag
                        nearestTerminals[stationId].cargo = myStationData.cargo or false
                        nearestTerminals[stationId].distance = distance
                    end
                end
            end
            for _, position in pairs(terminal.positions) do
                local distance = transfUtils.getPositionsDistance_onlyXY(
                    position,
                    _signPosition123
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
---@param transf table<integer>
---@param searchRadius number
---@param isOnlyPassengers boolean
---@return table<integer, {id: integer, isCargo: boolean, isPassenger: boolean, name: string, position: table<integer>}>
local _getNearbyTrainStationGroupsIndexed = function(transf, searchRadius, isOnlyPassengers)
    logger.print('_getNearbyTrainStationGroupsIndexed starting, isOnlyPassengers =', tostring(isOnlyPassengers))
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
    ---@param transf table<integer>
    ---@param searchRadius number
    ---@param isOnlyPassengers boolean
    ---@return table<{id: integer, isCargo: boolean, isPassenger: boolean, name: string, position: table<integer>}>
    getNearbyStationGroups = function(transf, searchRadius, isOnlyPassengers)
        logger.print('getNearbyStationGroups starting, isOnlyPassengers =', tostring(isOnlyPassengers))
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
            logger.print('stationGroupId =', tostring(stationGroupId))
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
                        logger.print('stationId =', tostring(stationId))
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
                                                logger.print('edgeOrNodeOrConId =', tostring(edgeOrNodeOrConId))
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
                                                        local midPosition = transfUtils.getPositionsMiddle(baseNode0.position, baseNode1.position)
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
                    end -- loop over stations
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
        -- add more nearby train stations
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
    ---@param signTransf table<integer>
    ---@param stationGroupId integer
    ---@param isOnlyPassengers boolean
    ---@return nil|nearest_terminal_streetside|nearest_terminal_generic
    getNearestTerminalWithStationGroup = function(signTransf, stationGroupId, isOnlyPassengers)
        logger.print('getNearestTerminalWithStationGroup starting, isOnlyPassengers =', tostring(isOnlyPassengers))
        local nearestTerminals = _getNearestTerminalsWithStationGroup(signTransf, stationGroupId, isOnlyPassengers)
        if not(nearestTerminals) then return nil end

        -- streetside station: we check the terminal at every iteration, we only write away the sign position
        if nearestTerminals.isMultiStationGroup then
            -- return {
            --     isMultiStationGroup = true,
            --     refPosition123 = nearestTerminals.refPosition123
            -- }
            return nearestTerminals
        end

        -- other stations: we check it now and, if the station changes, there won't be adjustments to auto terminals - too expensive
        -- LOLLO TODO find a way to do it quickly
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
