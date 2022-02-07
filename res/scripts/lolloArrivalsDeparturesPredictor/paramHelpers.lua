local helpers = {
    addOffsetParams = function(params, getParamName)
        local offsetMajorValues = {}
        local offsetMinorValues = {}
        for i = -10, 10 do
            offsetMajorValues[#offsetMajorValues+1] = tostring(i)
        end
        for i = -0.95, 1, 0.05 do
            offsetMinorValues[#offsetMinorValues+1] = tostring(i)
        end
        offsetMinorValues[math.ceil(#offsetMinorValues/2)] = "0"

        params[#params+1] = {
            key = getParamName("x_offset_major"),
            name = _("X Offset"),
            values = offsetMajorValues,
            uiType = "SLIDER",
            defaultIndex = #offsetMajorValues / 2
        }
        params[#params+1] = {
            key = getParamName("x_offset_minor"),
            name = _("X Offset (fine)"),
            values = offsetMinorValues,
            uiType = "SLIDER",
            defaultIndex = #offsetMinorValues / 2
        }
        params[#params+1] = {
            key = getParamName("y_offset_major"),
            name = _("Y Offset"),
            values = offsetMajorValues,
            uiType = "SLIDER",
            defaultIndex = #offsetMajorValues / 2
        }
        params[#params+1] = {
            key = getParamName("y_offset_minor"),
            name = _("Y Offset (fine)"),
            values = offsetMinorValues,
            uiType = "SLIDER",
            defaultIndex = #offsetMinorValues / 2
        }
        params[#params+1] = {
            key = getParamName("z_offset_major"),
            name = _("Z Offset"),
            values = offsetMajorValues,
            uiType = "SLIDER",
            defaultIndex = #offsetMajorValues / 2
        }
        params[#params+1] = {
            key = getParamName("z_offset_minor"),
            name = _("Z Offset (fine)"),
            values = offsetMinorValues,
            uiType = "SLIDER",
            defaultIndex = #offsetMinorValues / 2
        }

        return params
    end,
    getOffsetValue = function(params, getParamName)
        local offsetMajorValues = {}
        local offsetMinorValues = {}
        for i = -10, 10 do
            offsetMajorValues[#offsetMajorValues+1] = i
        end
        for i = -0.95, 1, 0.05 do
            offsetMinorValues[#offsetMinorValues+1] = i
        end
        offsetMinorValues[math.ceil(#offsetMinorValues/2)] = 0

        local xMin = offsetMinorValues[params[getParamName("x_offset_minor")]+1]
        local xMaj = offsetMajorValues[params[getParamName("x_offset_major")]+1]
        local yMin = offsetMinorValues[params[getParamName("y_offset_minor")]+1]
        local yMaj = offsetMajorValues[params[getParamName("y_offset_major")]+1]
        local zMin = offsetMinorValues[params[getParamName("z_offset_minor")]+1]
        local zMaj = offsetMajorValues[params[getParamName("z_offset_major")]+1]

        return { x = xMaj + xMin, y = yMaj + yMin, z = zMaj + zMin }
    end,
    addRotateParams = function(params, getParamName)
        local fineRotateValues = {}
        for i = -11, 11, 0.25 do
            fineRotateValues[#fineRotateValues+1] = tostring(i)
        end

        local bigRotateValues = {}
        for i = 0, 348.75, 11.25 do
            bigRotateValues[#bigRotateValues+1] = tostring(i)
        end

        params[#params+1] = {
            key = getParamName("x_rotate"),
            name = _("X Rotate"),
            values = bigRotateValues,
            uiType = "SLIDER",
            defaultIndex = 0
        }

        params[#params+1] = {
            key = getParamName("x_rotate_fine"),
            name = _("X Rotate (fine)"),
            values = fineRotateValues,
            uiType = "SLIDER",
            defaultIndex = #fineRotateValues / 2
        }
        params[#params+1] = {
            key = getParamName("y_rotate_fine"),
            name = _("Y Rotate (fine)"),
            values = fineRotateValues,
            uiType = "SLIDER",
            defaultIndex = #fineRotateValues / 2
        }
        params[#params+1] = {
            key = getParamName("z_rotate_fine"),
            name = _("Z Rotate (fine)"),
            values = fineRotateValues,
            uiType = "SLIDER",
            defaultIndex = #fineRotateValues / 2
        }

        return params
    end,
    getRotateValue = function(params, getParamName)
        local fineRotateValues = {}
        for i = -11, 11, 0.25 do
            fineRotateValues[#fineRotateValues+1] = math.rad(i)
        end

        local bigRotateValues = {}
        for i = 0, 348.75, 11.25 do
            bigRotateValues[#bigRotateValues+1] = math.rad(i)
        end

        local xBig = bigRotateValues[params[getParamName("x_rotate")]+1]
        local xFine = fineRotateValues[params[getParamName("x_rotate_fine")]+1]
        local yFine = fineRotateValues[params[getParamName("y_rotate_fine")]+1]
        local zFine = fineRotateValues[params[getParamName("z_rotate_fine")]+1]

        return { x = xBig + xFine, y = yFine, z = zFine }
    end,
    addTerminalOverrideParam = function(params, getParamName)
        local terminals = {}
        for i = 1, 25 do -- what's the most terminals a station might have?
            if i == 1 then
                terminals[i] = "Auto"
            else
                terminals[i] = tostring(i-1)
            end
        end

        params[#params+1] = {
            key = getParamName("terminal_override"),
            name = _("Terminal"),
            values = terminals,
            uiType = "COMBOBOX"
        }

        return params
    end,
    addCargoOverrideParam = function(params, getParamName)
        params[#params+1] = {
            key = getParamName("cargo_override"),
            name = _("StationSection"),
            values = {_('Auto'), _('Passengers'), _('Cargo')},
            uiType = "BUTTON"
        }

        return params
    end,
    getIcons = function(names)
        local icons = {}
        for _, name in ipairs(names) do
            icons[#icons+1] = "ui/parameters/lolloArrivalsDeparturesPredictor/" .. name .. ".tga"
        end
        return icons
    end,
}

return helpers
