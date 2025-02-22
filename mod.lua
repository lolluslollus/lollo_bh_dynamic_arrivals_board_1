-- local soundEffectsUtilOverride = require('lolloArrivalsDeparturesPredictor.soundEffectsUtilOverride')

function data()
	-- local function _addModel(oldFileName, newFileName)
	-- 	-- UG TODO the api does not support this
    --     local oldModelId = api.res.modelRep.find(oldFileName)
    --     local oldModel = api.res.modelRep.get(oldModelId)
    --     local newModel = api.type.ModelDesc.new() -- not available
    --     newModel.fileName = newFileName
    --     -- newModel.type = oldModel.type

    --     api.res.modelRep.add(newModel.fileName, newModel, true) -- fileName, resource, visible
    -- end

	return {
		info = {
			minorVersion = 22,
			severityAdd = 'NONE',
			severityRemove = 'WARNING',
			name = _('ModName'),
			description = _('ModDesc'),
			tags = { 'Misc', 'Script Mod', 'Track Asset', },
			visible = true,
			authors = {
                {
					name = 'lollus',
					role = 'CREATOR'
				},
				{
					name = 'badgerrhax',
					role = 'CREATOR'
				},
			}
		},
		-- runFn = function (settings, modParams)
		-- 	soundEffectsUtilOverride()
		-- end,
		-- postRunFn = function(settings, params)
		-- 	soundEffectsUtilOverride()
        -- end
	}
end
