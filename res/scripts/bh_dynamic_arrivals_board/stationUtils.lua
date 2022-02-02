local arrayUtils = require('bh_dynamic_arrivals_board.arrayUtils')
local constants = require('bh_dynamic_arrivals_board.constants')
local edgeUtils = require('bh_dynamic_arrivals_board.edgeUtils')
local logger = require('bh_dynamic_arrivals_board.bh_log')
local stringUtils = require('bh_dynamic_arrivals_board.stringUtils')
local transfUtils = require('bh_dynamic_arrivals_board.transfUtils')
local transfUtilsUG = require('transf')

local utils = {
    getNearbyStationCons = function(transf, searchRadius, isOnlyPassengers)
        if type(transf) ~= 'table' then return {} end
        if tonumber(searchRadius) == nil then searchRadius = constants.searchRadius4NearbyStation2Join end

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

        local _station2ConstructionMap = api.engine.system.streetConnectorSystem.getStation2ConstructionMap()
        local _resultsIndexed = {}
        for _, stationId in pairs(_stationIds) do
            if edgeUtils.isValidAndExistingId(stationId) then
                local conId = _station2ConstructionMap[stationId]
                if edgeUtils.isValidAndExistingId(conId) then
                    -- logger.print('getNearbyFreestyleStationsList has found conId =', conId)
                    local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
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
    getNearestTerminalId = function(transf, stationConId)
        -- LOLLO TODO implement this
        return nil
    end,
}

return utils