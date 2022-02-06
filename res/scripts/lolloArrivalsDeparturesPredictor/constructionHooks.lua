local targetConstructions = {}
-- LOLLO TODO I am surprised this works across the many different lua modes
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
