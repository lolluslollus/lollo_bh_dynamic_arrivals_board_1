local constants = require('bh_dynamic_arrivals_board.constants')
local edgeUtils = require('bh_dynamic_arrivals_board.edgeUtils')
local stringUtils = require('bh_dynamic_arrivals_board.stringUtils')

local _stationPickerWindowId = 'bh_arrivals_manager_picker_window'
local _warningWindowWithGotoId = 'bh_arrivals_manager_warning_window_with_goto'
local _warningWindowWithMessageId = 'bh_arrivals_manager_warning_window_with_message'
local _warningWindowWithStateId = 'bh_arrivals_manager_warning_window_with_state'

local _texts = {
    goBack = _('GoBack'),
    goThere = _('GoThere'), -- cannot put this directly inside the loop for some reason
    join = _('Join'),
    noJoin = _('NoJoin'),
    stationPickerWindowTitle = _('StationPickerWindowTitle'),
    warningWindowTitle = _('WarningWindowTitle'),
}

local _windowXShift = -200

local guiHelpers = {
    isShowingWarning = false,
    moveCamera = function(position)
        local cameraData = game.gui.getCamera()
        game.gui.setCamera({position[1], position[2], cameraData[3], cameraData[4], cameraData[5]})
    end
}

guiHelpers.showNearbyStationPicker = function(isTheNewObjectCargo, stationCons, tentativeStationConId, joinCallback)
    -- print('showNearbyStationPicker starting')
    local layout = api.gui.layout.BoxLayout.new('VERTICAL')
    local window = api.gui.util.getById(_stationPickerWindowId)
    if window == nil then
        window = api.gui.comp.Window.new(_texts.stationPickerWindowTitle, layout)
        window:setId(_stationPickerWindowId)
    else
        window:setContent(layout)
        window:setVisible(true, false)
    end

    local function addJoinButtons()
        if type(stationCons) ~= 'table' then return end

        local components = {}
        for _, stationCon in pairs(stationCons) do
            local name = api.gui.comp.TextView.new(stationCon.uiName or stationCon.name or '')
            local cargoIcon = stationCon.isCargo
                and api.gui.comp.ImageView.new('ui/icons/construction-menu/category_cargo.tga')
                or api.gui.comp.TextView.new('')
            local passengerIcon = stationCon.isPassenger
                and api.gui.comp.ImageView.new('ui/icons/construction-menu/category_passengers.tga')
                or api.gui.comp.TextView.new('')

            local gotoButtonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
            gotoButtonLayout:addItem(api.gui.comp.ImageView.new('ui/design/window-content/locate_small.tga'))
            gotoButtonLayout:addItem(api.gui.comp.TextView.new(_texts.goThere))
            local gotoButton = api.gui.comp.Button.new(gotoButtonLayout, true)
            gotoButton:onClick(
                function()
                    guiHelpers.moveCamera(stationCon.position)
                    -- game.gui.setCamera({con.position[1], con.position[2], 100, 0, 0})
                end
            )

            local joinButtonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
            joinButtonLayout:addItem(api.gui.comp.ImageView.new('ui/design/components/checkbox_valid.tga'))
            joinButtonLayout:addItem(api.gui.comp.TextView.new(_texts.join))
            local joinButton = api.gui.comp.Button.new(joinButtonLayout, true)
            joinButton:onClick(
                function()
                    if type(joinCallback) == 'function' then joinCallback(stationCon.id) end
                    window:setVisible(false, false)
                end
            )
            if stationCon.id == tentativeStationConId then
                joinButton:setEnabled(false)
            end

            components[#components + 1] = {name, cargoIcon, passengerIcon, gotoButton, joinButton}
        end

        if #components > 0 then
            local guiStationsTable = api.gui.comp.Table.new(#components, 'NONE')
            guiStationsTable:setNumCols(5)
            for _, value in pairs(components) do
                guiStationsTable:addRow(value)
            end
            layout:addItem(guiStationsTable)
        end
    end

    addJoinButtons()

    -- window:setHighlighted(true)
    local position = api.gui.util.getMouseScreenPos()
    window:setPosition(position.x + _windowXShift, position.y)
    window:onClose(
        function()
            window:setVisible(false, false)
        end
    )
end

guiHelpers.showWarningWindowWithGoto = function(text, wrongObjectId, similarObjectsIds)
    local layout = api.gui.layout.BoxLayout.new('VERTICAL')
    local window = api.gui.util.getById(_warningWindowWithGotoId)
    if window == nil then
        window = api.gui.comp.Window.new(_texts.warningWindowTitle, layout)
        window:setId(_warningWindowWithGotoId)
    else
        window:setContent(layout)
        window:setVisible(true, false)
    end

    layout:addItem(api.gui.comp.TextView.new(text))

    local function addGotoOtherObjectsButtons()
        if type(similarObjectsIds) ~= 'table' then return end

        local wrongObjectIdTolerant = wrongObjectId
        if not(edgeUtils.isValidAndExistingId(wrongObjectIdTolerant)) then wrongObjectIdTolerant = -1 end

        for _, otherObjectId in pairs(similarObjectsIds) do
            if otherObjectId ~= wrongObjectIdTolerant and edgeUtils.isValidAndExistingId(otherObjectId) then
                local otherObjectPosition = edgeUtils.getObjectPosition(otherObjectId)
                if otherObjectPosition ~= nil then
                    local buttonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
                    buttonLayout:addItem(api.gui.comp.ImageView.new('ui/design/window-content/locate_small.tga'))
                    buttonLayout:addItem(api.gui.comp.TextView.new(_texts.goThere))
                    local button = api.gui.comp.Button.new(buttonLayout, true)
                    button:onClick(
                        function()
                            -- UG TODO this dumps, ask UG to fix it
                            -- api.gui.util.CameraController:setCameraData(
                            --     api.type.Vec2f.new(otherObjectPosition[1], otherObjectPosition[2]),
                            --     100, 0, 0
                            -- )
                            -- x, y, distance, angleInRad, pitchInRad
                            guiHelpers.moveCamera(otherObjectPosition)
                            -- game.gui.setCamera({otherObjectPosition[1], otherObjectPosition[2], 100, 0, 0})
                        end
                    )
                    layout:addItem(button)
                end
            end
        end
    end
    local function addGoBackToWrongObjectButton()
        if not(edgeUtils.isValidAndExistingId(wrongObjectId)) then return end

        local wrongObjectPosition = edgeUtils.getObjectPosition(wrongObjectId)
        if wrongObjectPosition ~= nil then
            local buttonLayout = api.gui.layout.BoxLayout.new('HORIZONTAL')
            buttonLayout:addItem(api.gui.comp.ImageView.new('ui/design/window-content/arrow_style1_left.tga'))
            buttonLayout:addItem(api.gui.comp.TextView.new(_texts.goBack))
            local button = api.gui.comp.Button.new(buttonLayout, true)
            button:onClick(
                function()
                    -- UG TODO this dumps, ask UG to fix it
                    -- api.gui.util.CameraController:setCameraData(
                    --     api.type.Vec2f.new(wrongObjectPosition[1], wrongObjectPosition[2]),
                    --     100, 0, 0
                    -- )
                    -- x, y, distance, angleInRad, pitchInRad
                    guiHelpers.moveCamera(wrongObjectPosition)
                    -- game.gui.setCamera({wrongObjectPosition[1], wrongObjectPosition[2], 100, 0, 0})
                end
            )
            layout:addItem(button)
        end
    end
    addGotoOtherObjectsButtons()
    addGoBackToWrongObjectButton()

    window:setHighlighted(true)
    local position = api.gui.util.getMouseScreenPos()
    window:setPosition(position.x + _windowXShift, position.y)
    window:addHideOnCloseHandler()
end

guiHelpers.showWarningWindowWithMessage = function(text)
    guiHelpers.isShowingWarning = true
    local layout = api.gui.layout.BoxLayout.new('VERTICAL')
    local window = api.gui.util.getById(_warningWindowWithMessageId)
    if window == nil then
        window = api.gui.comp.Window.new(_texts.warningWindowTitle, layout)
        window:setId(_warningWindowWithMessageId)
    else
        window:setContent(layout)
        window:setVisible(true, false)
    end

    layout:addItem(api.gui.comp.TextView.new(text))

    window:setHighlighted(true)
    local position = api.gui.util.getMouseScreenPos()
    window:setPosition(position.x + _windowXShift, position.y)
    -- window:addHideOnCloseHandler()
    window:onClose(
        function()
            window:setVisible(false, false)
        end
    )
end

guiHelpers.showWarningWindowWithState = function(text)
    guiHelpers.isShowingWarning = true
    local layout = api.gui.layout.BoxLayout.new('VERTICAL')
    local window = api.gui.util.getById(_warningWindowWithStateId)
    if window == nil then
        window = api.gui.comp.Window.new(_texts.warningWindowTitle, layout)
        window:setId(_warningWindowWithStateId)
    else
        window:setContent(layout)
        window:setVisible(true, false)
    end

    layout:addItem(api.gui.comp.TextView.new(text))

    window:setHighlighted(true)
    local position = api.gui.util.getMouseScreenPos()
    window:setPosition(position.x + _windowXShift, position.y)
    -- window:addHideOnCloseHandler()
    window:onClose(
        function()
            window:setVisible(false, false)
            api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
                -- string.sub(debug.getinfo(1, 'S').source, 1),
                constants.eventSources.bh_gui_engine,
                constants.eventId,
                constants.events.hide_warnings,
                {}
            ))
        end
    )
end

guiHelpers.hideAllWarnings = function()
    local window = api.gui.util.getById(_stationPickerWindowId)
    if window ~= nil then
        window:setVisible(false, false)
    end
    window = api.gui.util.getById(_warningWindowWithGotoId)
    if window ~= nil then
        window:setVisible(false, false)
    end
end

return guiHelpers
