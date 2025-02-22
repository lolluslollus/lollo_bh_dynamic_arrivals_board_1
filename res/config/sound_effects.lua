-- local soundeffectsutil = require "soundeffectsutil"
-- local soundEffectsUtilOverride = require('lolloArrivalsDeparturesPredictor.soundEffectsUtilOverride')
local soundeffectsutil = require('lolloArrivalsDeparturesPredictor.soundeffectsutil')

function data()
    return soundeffectsutil.getSoundEffects()
end
