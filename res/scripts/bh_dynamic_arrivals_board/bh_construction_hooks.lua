local targetConstructions = {}
-- LOLLO TODO I am surprised this works coz of the many different lua modes
local function getRegisteredConstructions()
  return targetConstructions
end

local function registerConstruction(conPath, params)
  targetConstructions[conPath] = params
end

return {
  registerConstruction = registerConstruction,
  getRegisteredConstructions = getRegisteredConstructions,
}