local constants = require('lolloArrivalsDeparturesPredictor.constants')
local logger = require('lolloArrivalsDeparturesPredictor.logger')
local stringUtils = require('lolloArrivalsDeparturesPredictor.stringUtils')


local _texts = {
    dynamicOff = _('DynamicDisplaysOff'),
    dynamicOn = _('DynamicDisplaysOn'),
    goBack = _('GoBack'),
    goThere = _('GoThere'), -- cannot put this directly inside the loop for some reason
    join = _('Join'),
    objectPickerWindowTitle = _('StationPickerWindowTitle'),
    warningWindowTitle = _('WarningWindowTitle'),
}

-- local _windowXShift = -200
local _windowYShift = 40

local utils = {
    moveCamera = function(position123)
        -- logger.print('moveCamera starting, position123 =') logger.debugPrint(position123)
        local cameraData = game.gui.getCamera()
        game.gui.setCamera({position123[1], position123[2], cameraData[3], cameraData[4], cameraData[5]})
    end,
    modifyOnOffButtonLayout = function(layout, isOn)
        local img = nil
        if isOn then
            -- img = api.gui.comp.ImageView.new('ui/design/components/checkbox_valid.tga')
            img = api.gui.comp.ImageView.new('ui/lolloArrivalsDeparturesPredictor/checkbox_valid.tga')
            img:setTooltip(_texts.dynamicOn)
            layout:addItem(img, api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
            -- layout:addItem(api.gui.comp.TextView.new(_texts.dynamicOn), api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
        else
            img = api.gui.comp.ImageView.new('ui/lolloArrivalsDeparturesPredictor/checkbox_invalid.tga')
            img:setTooltip(_texts.dynamicOff)
            layout:addItem(img, api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
            -- layout:addItem(api.gui.comp.TextView.new(_texts.dynamicOff), api.gui.util.Alignment.HORIZONTAL, api.gui.util.Alignment.VERTICAL)
        end
    end,
    ---position window keeping it within the screen
    ---@param window any
    ---@param initialPosition {x:number, y:number}|nil
    setWindowPosition = function(window, initialPosition)
        local gameContentRect = api.gui.util.getGameUI():getContentRect()
        local windowContentRect = window:getContentRect()
        local windowMinimumSize = window:calcMinimumSize()

        local windowHeight = math.max(windowContentRect.h, windowMinimumSize.h)
        local windowWidth = math.max(windowContentRect.w, windowMinimumSize.w)
        local positionX = (initialPosition ~= nil and initialPosition.x) or math.max(0, (gameContentRect.w - windowWidth) * 0.5)
        local positionY = (initialPosition ~= nil and initialPosition.y) or math.max(0, (gameContentRect.h - windowHeight) * 0.5)

        if (positionX + windowWidth) > gameContentRect.w then
            positionX = math.max(0, gameContentRect.w - windowWidth)
        end
        if (positionY + windowHeight) > gameContentRect.h then
            positionY = math.max(0, gameContentRect.h - windowHeight -100)
        end

        window:setPosition(math.floor(positionX), math.floor(positionY))
    end
}
-- LOLLO TODO in the picker popup, add icons to tell if it is a port, an airport, a train station or a road station
-- UG TODO there is no obvious way of doing this
local guiHelpers = {
    showNearbyObjectPicker = function(objects2Pick, startPosition123, tentativeObjectId, joinCallback)
        -- logger.print('showNearbyObjectPicker starting')
        local list = api.gui.comp.List.new(false, api.gui.util.Orientation.VERTICAL, false)
        list:setDeselectAllowed(false)
        list:setVerticalScrollBarPolicy(0) -- 0 as needed 1 always off 2 always show 3 simple
        local layout = api.gui.layout.BoxLayout.new('VERTICAL')
        layout:addItem(list)

        local window = api.gui.util.getById(constants.guiIds.objectPickerWindowId)
        if window == nil then
            window = api.gui.comp.Window.new(_texts.objectPickerWindowTitle, layout)
            window:setId(constants.guiIds.objectPickerWindowId)
        else
            window:setContent(layout)
            window:setVisible(true, false)
        end
        window:setResizable(true)

        local function addJoinButtons()
            if type(objects2Pick) ~= 'table' then return end

            local components = {}
            for _, object in pairs(objects2Pick) do
                local name = api.gui.comp.TextView.new(object.uiName or object.name or '')
                local cargoIcon = object.isCargo
                    and api.gui.comp.ImageView.new('ui/icons/construction-menu/category_cargo.tga')
                    or api.gui.comp.TextView.new('')
                local passengerIcon = object.isPassenger
                    and api.gui.comp.ImageView.new('ui/icons/construction-menu/category_passengers.tga')
                    or api.gui.comp.TextView.new('')

                local gotoButtonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
                gotoButtonLayout:addItem(api.gui.comp.ImageView.new('ui/design/window-content/locate_small.tga'))
                gotoButtonLayout:addItem(api.gui.comp.TextView.new(_texts.goThere))
                local gotoButton = api.gui.comp.Button.new(gotoButtonLayout, true)
                gotoButton:onClick(
                    function()
                        utils.moveCamera(object.position)
                        -- game.gui.setCamera({con.position[1], con.position[2], 100, 0, 0})
                    end
                )

                local joinButtonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
                joinButtonLayout:addItem(api.gui.comp.ImageView.new('ui/design/components/checkbox_valid.tga'))
                joinButtonLayout:addItem(api.gui.comp.TextView.new(_texts.join))
                local joinButton = api.gui.comp.Button.new(joinButtonLayout, true)
                joinButton:onClick(
                    function()
                        if type(joinCallback) == 'function' then joinCallback(object.id) end
                        window:setVisible(false, false)
                    end
                )
                if object.id == tentativeObjectId then
                    joinButton:setEnabled(false)
                end

                components[#components + 1] = {name, cargoIcon, passengerIcon, gotoButton, joinButton}
            end

            if #components > 0 then
                local guiObjectsTable = api.gui.comp.Table.new(#components, 'NONE')
                guiObjectsTable:setNumCols(5)
                for _, value in pairs(components) do
                    guiObjectsTable:addRow(value)
                end
                list:addItem(guiObjectsTable)
            end
        end

        local function addGoBackButton()
            if not(startPosition123) then logger.warn('startPosition123 not found') return end

            local buttonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
            buttonLayout:addItem(api.gui.comp.ImageView.new('ui/design/window-content/arrow_style1_left.tga'))
            buttonLayout:addItem(api.gui.comp.TextView.new(_texts.goBack))
            local button = api.gui.comp.Button.new(buttonLayout, true)
            button:onClick(
                function()
                    -- UG TODO this dumps, ask UG to fix it
                    -- api.gui.util.CameraController:setCameraData(
                    --     api.type.Vec2f.new(startPosition123[1], startPosition123[2]),
                    --     100, 0, 0
                    -- )
                    -- x, y, distance, angleInRad, pitchInRad
                    -- logger.print('startPosition123 =') logger.debugPrint(startPosition123)
                    utils.moveCamera(startPosition123)
                    -- game.gui.setCamera({startPosition123[1], startPosition123[2], 100, 0, 0})
                end
            )
            layout:addItem(button)
        end

        addJoinButtons()
        addGoBackButton()

        -- window:setHighlighted(true)
        local position = api.gui.util.getMouseScreenPos()
        -- position.x = position.x + _windowXShift
        position.y = position.y + _windowYShift
        utils.setWindowPosition(window, position)

        window:onClose(
            function()
                window:setVisible(false, false)
            end
        )
    end,
    showWarningWindowWithMessage = function(text)
        local layout = api.gui.layout.BoxLayout.new('VERTICAL')
        local window = api.gui.util.getById(constants.guiIds.warningWindowWithMessageId)
        if window == nil then
            window = api.gui.comp.Window.new(_texts.warningWindowTitle, layout)
            window:setId(constants.guiIds.warningWindowWithMessageId)
        else
            window:setContent(layout)
            window:setVisible(true, false)
        end

        layout:addItem(api.gui.comp.TextView.new(text))

        window:setHighlighted(true)
        local position = api.gui.util.getMouseScreenPos()
        -- position.x = position.x + _windowXShift
        position.y = position.y + _windowYShift
        utils.setWindowPosition(window, position)

        -- window:addHideOnCloseHandler()
        window:onClose(
            function()
                window:setVisible(false, false)
            end
        )
    end,
    initNotausButton = function(isDynamicOn, funcOfBool)
        if api.gui.util.getById(constants.guiIds.dynamicOnOffButtonId) then return end

        local buttonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
        utils.modifyOnOffButtonLayout(buttonLayout, isDynamicOn)
        local button = api.gui.comp.ToggleButton.new(buttonLayout)
        button:setSelected(isDynamicOn, false)
        button:onToggle(function(isOn) -- isOn is boolean
            logger.print('toggled; isOn = ', isOn)
            while buttonLayout:getNumItems() > 0 do
                local item0 = buttonLayout:getItem(0)
                buttonLayout:removeItem(item0)
            end
            utils.modifyOnOffButtonLayout(buttonLayout, isOn)
            button:setSelected(isOn, false)
            funcOfBool(isOn)
        end)

        button:setId(constants.guiIds.dynamicOnOffButtonId)

        api.gui.util.getById('gameInfo'):getLayout():addItem(button) -- adds a button in the right place
    end,
}

local _fuckAround = function()
    local _mbl = api.gui.util.getById('mainButtonsLayout')
    _mbl:getItem(1):setHighlighted(true) -- flashes the main 7 buttons at the centre
    _mbl:getItem(1):getLayout()
    _mbl:getItem(1):getLayout():getNumItems() -- returns 7


    -- this adds a button to the bottom right
    local _mmbb = api.gui.util.getById("mainMenuBottomBar")
    _mmbb:setHighlighted(true) -- flashes the bottom bar
    local buttonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
    buttonLayout:addItem(api.gui.comp.ImageView.new('ui/design/components/checkbox_invalid.tga'))
    buttonLayout:addItem(api.gui.comp.TextView.new('Lollo'))
    local button = api.gui.comp.Button.new(buttonLayout, true)
    button:setId('LolloButton')

    _mmbb:getLayout():addItem(button)

    -- where best to add my button?
    _mmbb:getLayout():getItem(0):setHighlighted(true) -- far left and tiny
    _mmbb:getLayout():getItem(1):setHighlighted(true) -- most of the width. The id is 'gameInfo'
    _mmbb:getLayout():getItem(2):setHighlighted(true) -- tiny, just left of the music player
    _mmbb:getLayout():getItem(3):setHighlighted(true) -- I see nothing
    _mmbb:getLayout():getItem(4):setHighlighted(true) -- music player
    _mmbb:getLayout():getItem(5):setHighlighted(true) -- tiny, just right of the music player
    _mmbb:getLayout():getItem(6):setHighlighted(true) -- pause, play, fast, very fast and the date

    _mmbb:getLayout():getItem(1):getLayout()
    -- easier:
    api.gui.util.getById('gameInfo'):getLayout():getNumItems() -- returns 5
    api.gui.util.getById('gameInfo'):getLayout():addItem(button) -- adds a button in the right place
    api.gui.util.getById('LolloButton'):getLayout():getItem(0):getNumItems() -- returns 2, coz I put two things into my button
    -- adds a third icon to my button
    api.gui.util.getById('LolloButton'):getLayout():getItem(0):addItem(api.gui.comp.ImageView.new('ui/design/components/checkbox_valid.tga'))
end

return guiHelpers
