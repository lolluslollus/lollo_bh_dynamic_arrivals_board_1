local persistent_state = {}

local function ensureState()
  if persistent_state.world_time == nil then
    persistent_state.world_time = 0
  end

  if persistent_state.placed_signs == nil then
    persistent_state.placed_signs = {}
  end
end

local function loadState(state)
  if state then
    persistent_state = state
  end

  ensureState()

  return persistent_state
end

local function getState()
  return persistent_state
end

local function removeStatePlacedSign(key)
  if not(key) then return end

  if persistent_state.placed_signs == nil then
    persistent_state.placed_signs = {}
  end
  persistent_state.placed_signs[key] = nil
end

local function setStatePlacedSign(key, value)
  if not(key) and not(value) then return end

  if persistent_state.placed_signs == nil then
    persistent_state.placed_signs = {}
  end
  persistent_state.placed_signs[key] = value
end

return {
  loadState = loadState,
  getState = getState,
  ensureState = ensureState,
  removeStatePlacedSign = removeStatePlacedSign,
  setStatePlacedSign = setStatePlacedSign,
}