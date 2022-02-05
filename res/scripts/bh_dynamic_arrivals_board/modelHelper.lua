local constants = require('bh_dynamic_arrivals_board.constants')

local function params(counter)
    return {
        -- text = "@1SELECT_PART_1@2SELECT_PART_2@",
        -- text = "@1SEL_P1@2SEL_P2@31:50@4Brignole@52@61:50@7Porta Nuova@824@923:59@",
        -- expr = "@2([a-zA-Z0-9_]+)@", -- works
        -- expr = "@1([a-zA-Z0-9_]+)@", -- works
        -- expr = "@1([^@]+)@", -- works best
        -- expr = "@" .. counter .. "([^@]+)@",
        expr = "@_" .. counter .. "_@([^@]+)@",
        replace="\\1", -- works
    }
end

-- stick this in the model editor under "options - config - name"
-- local _testText = "@_1_@Brignole@_2_@12:25@_3_@Ü Bigottu@_4_@1:11@_clock_@01:12:20@"

local utils = {
    getManchesterMetrolinkLabelList = function()
        return {
            labels = {
                -- face A
                {
                    alignment = "LEFT",
                    alpha = 1,
                    alphaMode = "CUTOUT",
                    childId = "",
                    color = { 1, 0.541, 0, },
                    filter = "CUSTOM",
                    fitting = "CUT",
                    nLines = 1,
                    params = params(1),
                    renderMode = "EMISSIVE",
                    size = { 0.97, 0.1, },
                    transf = { 1, 0, 0, 0, 0, -0.139, 0.99, 0, 0, -0.99, -0.139, 0, 0.4, -0.09, 4.35, 1, },
                    type = "NAME",
                    verticalAlignment = "CENTER",
                },
                {
                    alignment = "LEFT",
                    alpha = 1,
                    alphaMode = "CUTOUT",
                    childId = "",
                    color = { 1, 0.541, 0, },
                    filter = "CUSTOM",
                    fitting = "CUT",
                    nLines = 1,
                    params = params(3),
                    renderMode = "EMISSIVE",
                    size = { 0.97, 0.1, },
                    transf = { 1, 0, 0, 0, 0, -0.139, 0.99, 0, 0, -0.99, -0.139, 0, 0.4, -0.09, 4.25, 1, },
                    type = "NAME",
                    verticalAlignment = "CENTER",
                },
                {
                    alignment = "CENTER",
                    alpha = 1,
                    alphaMode = "CUTOUT",
                    childId = "",
                    color = { 1, 0.541, 0, },
                    filter = "CUSTOM",
                    fitting = "CUT",
                    nLines = 1,
                    params = params(constants.nameTags.clock),
                    renderMode = "EMISSIVE",
                    size = { 1.27, 0.14, },
                    transf = { 1, 0, -0, 0, 0, -0.139, 0.99, 0, 0, -0.99, -0.139, 0, 0.4, -0.07, 4.1, 1, },
                    type = "NAME",
                    verticalAlignment = "BOTTOM",
                },
                {
                    alignment = "RIGHT",
                    alpha = 1,
                    alphaMode = "CUTOUT",
                    childId = "",
                    color = { 1, 0.541, 0, },
                    filter = "CUSTOM",
                    fitting = "CUT",
                    nLines = 1,
                    params = params(2),
                    renderMode = "EMISSIVE",
                    size = { 0.3, 0.1, },
                    transf = { 1, 0, -0, 0, 0, -0.139, 0.99, 0, 0, -0.99, -0.139, 0, 1.37, -0.09, 4.35, 1, },
                    type = "NAME",
                    verticalAlignment = "CENTER",
                },
                {
                    alignment = "RIGHT",
                    alpha = 1,
                    alphaMode = "CUTOUT",
                    childId = "",
                    color = { 1, 0.541, 0, },
                    filter = "CUSTOM",
                    fitting = "CUT",
                    nLines = 1,
                    params = params(4),
                    renderMode = "EMISSIVE",
                    size = { 0.3, 0.1, },
                    transf = { 1, 0, -0, 0, 0, -0.139, 0.99, 0, 0, -0.99, -0.139, 0, 1.37, -0.08, 4.25, 1, },
                    type = "NAME",
                    verticalAlignment = "CENTER",
                },
                -- face B
                {
                	alignment = "LEFT",
                	alpha = 1,
                	alphaMode = "CUTOUT",
                	childId = "",
                	color = { 1, 0.541, 0, },
                	filter = "CUSTOM",
                	fitting = "CUT",
                	nLines = 1,
                	params = params(1),
                	renderMode = "EMISSIVE",
                	size = { 0.97, 0.1, },
                	transf = { -1, 0, -0, 0, 0, 0.139, 0.99, 0, 0, 0.99, -0.139, 0, 1.66, 0.09, 4.35, 1, },
                	type = "NAME",
                	verticalAlignment = "CENTER",
                },
                {
                	alignment = "LEFT",
                	alpha = 1,
                	alphaMode = "CUTOUT",
                	childId = "",
                	color = { 1, 0.541, 0, },
                	filter = "CUSTOM",
                	fitting = "CUT",
                	nLines = 1,
                	params = params(3),
                	renderMode = "EMISSIVE",
                	size = { 0.97, 0.1, },
                	transf = { -1, 0, -0, 0, 0, 0.139, 0.99, 0, 0, 0.99, -0.139, 0, 1.66, 0.08, 4.25, 1, },
                	type = "NAME",
                	verticalAlignment = "CENTER",
                },
                {
                	alignment = "CENTER",
                	alpha = 1,
                	alphaMode = "CUTOUT",
                	childId = "",
                	color = { 1, 0.541, 0, },
                	filter = "CUSTOM",
                	fitting = "CUT",
                	nLines = 1,
                	params = params(constants.nameTags.clock),
                	renderMode = "EMISSIVE",
                	size = { 1.27, 0.14, },
                	transf = { -1, 0, -0, 0, 0, 0.139, 0.99, 0, 0, 0.99, -0.139, 0, 1.66, 0.07, 4.1, 1, },
                	type = "NAME",
                	verticalAlignment = "BOTTOM",
                },
                {
                	alignment = "RIGHT",
                	alpha = 1,
                	alphaMode = "CUTOUT",
                	childId = "",
                	color = { 1, 0.541, 0, },
                	filter = "CUSTOM",
                	fitting = "CUT",
                	nLines = 1,
                	params = params(2),
                	renderMode = "EMISSIVE",
                	size = { 0.3, 0.1, },
                	transf = { -1, 0, -0, 0, 0, 0.139, 0.99, 0, 0, 0.99, -0.139, 0, 0.7, 0.09, 4.35, 1, },
                	type = "NAME",
                	verticalAlignment = "CENTER",
                },
                {
                	alignment = "RIGHT",
                	alpha = 1,
                	alphaMode = "CUTOUT",
                	childId = "",
                	color = { 1, 0.541, 0, },
                	filter = "CUSTOM",
                	fitting = "CUT",
                	nLines = 1,
                	params = params(4),
                	renderMode = "EMISSIVE",
                	size = { 0.3, 0.1, },
                	transf = { -1, 0, -0, 0, 0, 0.139, 0.99, 0, 0, 0.99, -0.139, 0, 0.7, 0.08, 4.25, 1, },
                	type = "NAME",
                	verticalAlignment = "CENTER",
                },
            },
        }
    end,
    -- LOLLO NOTE if a construction contains models without bounding info and collider,
    -- it will still detect collisions with them. With these, we avoid that problem.
    getVoidBoundingInfo = function()
        return {} -- this seems the same as the following
        -- return {
        --     bbMax = { 0, 0, 0 },
        --     bbMin = { 0, 0, 0 },
        -- }
    end,
    getVoidCollider = function()
        -- return {
        --     params = {
        --         halfExtents = { 0, 0, 0, },
        --     },
        --     transf = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, },
        --     type = 'BOX',
        -- }
        return {
            type = 'NONE'
        }
    end,
}

return utils
