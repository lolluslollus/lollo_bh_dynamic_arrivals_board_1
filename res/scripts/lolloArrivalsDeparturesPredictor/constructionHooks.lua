local targetConstructions = {
    ["asset/lolloArrivalsDeparturesPredictor/bh_digital_display.con"] = {
        singleTerminal = true,
        clock = true,
        isArrivals = false,
        maxEntries = 2,
        absoluteArrivalTime = false,
        labelParamPrefix = "bh_digital_display_"
    },
    ["asset/lolloArrivalsDeparturesPredictor/bh_digital_station_departures_display.con"] = {
        singleTerminal = false,
        clock = true,
        isArrivals = false,
        maxEntries = 8,
        absoluteArrivalTime = true,
        labelParamPrefix = "bh_departures_display_"
    },
    ["asset/lolloArrivalsDeparturesPredictor/bh_digital_station_arrivals_display.con"] = {
        singleTerminal = false,
        clock = true,
        isArrivals = true,
        maxEntries = 8,
        absoluteArrivalTime = true,
        labelParamPrefix = "bh_arrivals_display_"
    }
}
-- LOLLO TODO I am surprised this works across the many different lua modes.
-- In fact, it doesn't here, so we do it here: never mind, I don't expect other mods to use this.
return {
    getRegisteredConstructions = function()
        return targetConstructions
    end,
    getRegisteredConstructionOrDefault = function(index)
        local config = targetConstructions[index]
        if not config then
            print('lolloArrivalsDeparturesPredictor WARNING: cannot read the construction config, fileName =', index or 'NIL')
            config = {}
        end

        if not config.labelParamPrefix then config.labelParamPrefix = '' end

        return config
    end,
    registerConstruction = function(conPath, params)
        targetConstructions[conPath] = params
    end,
}
