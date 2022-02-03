local targetConstructions = {}
-- LOLLO TODO I am surprised this works coz of the many different lua modes
local function getRegisteredConstructions()
    return targetConstructions
end

local function getRegisteredConstructionOrDefault(index)
    local config = targetConstructions[index]
    if not config then
        print('bh_dynamic_arrivals_board WARNING: cannot read the constructionconfig, fileName =', index or 'NIL')
        config = {}
    end

    if not config.labelParamPrefix then config.labelParamPrefix = '' end

    return config
end

local function registerConstruction(conPath, params)
    targetConstructions[conPath] = params
end

return {
    registerConstruction = registerConstruction,
    getRegisteredConstructions = getRegisteredConstructions,
    getRegisteredConstructionOrDefault = getRegisteredConstructionOrDefault,
}
