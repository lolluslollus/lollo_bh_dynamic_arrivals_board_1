local helpers = {
    addTerminalOverrideParam = function(params, getParamName)
        local terminals = {
            [1] = 'Auto'
        }
        for i = 2, 33 do -- I doubt there will be stations with more terminals
            terminals[i] = tostring(i - 1)
        end

        params[#params+1] = {
            key = getParamName('terminal_override'),
            name = _('Terminal'),
            values = terminals,
            uiType = 'COMBOBOX'
        }

        return params
    end,
    addCargoOverrideParam = function(params, getParamName)
        params[#params+1] = {
            key = getParamName('cargo_override'),
            name = _('StationSection'),
            values = {_('Auto'), _('Passengers'), _('Cargo')},
            uiType = 'BUTTON'
        }

        return params
    end,
    getDummyGroundFaces = function()
        --[[
            LOLLO NOTE
            constructions that do not contain
            ground faces, terrain alignments, edges or depot/station/industry/town building definitions
            are not treated like constructions in the game,
            ie they cannot be selected.
            That's why we make a dummy ground face, which is practically invisible and harmless.
        ]]
        return {
            {
                face = {
                    {0.1, -0.1, 0.0, 1.0},
                    {0.1, 0.1, 0.0, 1.0},
                    {-0.1, 0.1, 0.0, 1.0},
                    {-0.1, -0.1, 0.0, 1.0},
                },
                modes = {
                    {
                        type = 'FILL',
                        key = 'shared/asphalt_01.gtex.lua' --'shared/gravel_03.gtex.lua'
                    }
                }
            },
        }
    end,
    getDummyTerrainAlignmentLists = function()
        -- LOLLO NOTE this thing with the empty faces is required , otherwise the game will make its own alignments, with spikes and all on bridges or tunnels.
        return { {
            type = 'EQUAL',
            optional = true,
            faces =  { }
        } }
    end,
    getIcons = function(names)
        local icons = {}
        for _, name in ipairs(names) do
            icons[#icons+1] = 'ui/parameters/lolloArrivalsDeparturesPredictor/' .. name .. '.tga'
        end
        return icons
    end,
}

return helpers
