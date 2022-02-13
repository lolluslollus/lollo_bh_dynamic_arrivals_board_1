local constants = {
    refreshPeriodMsec = 5000, -- refresh every 5 seconds
    searchRadius4NearbyStation2JoinMetres = 100,

    guesstimatedStationWaitingTimeMsec = 30000,

    eventId = '__lollo_departures_arrivals_predictor__',
    events = {
        hide_warnings = 'hide_warnings',
        join_sign_to_station = 'join_sign_to_station',
        remove_display_construction = 'remove_display_construction',
        toggle_notaus = 'toggle_notaus'
    },

    guiIds = {
        dynamicOnOffButtonId = 'lollo_arrivals_departures_predictor_dynamic_on_off_button',
        stationPickerWindowId = 'lollo_arrivals_departures_predictor_picker_window',
        warningWindowWithMessageId = 'lollo_arrivals_departures_predictor_warning_window_with_message',
    },

    idTransf = { 1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1 },

    nameTags = {
        clock = 'clock',
        footer = 'footer',
        header = 'header',
        track = 'track',
    },

    paramPrefix = 'display_',

    currentVersion = 2
}

return constants
