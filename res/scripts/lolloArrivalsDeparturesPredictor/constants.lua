local constants = {
    refreshPeriodMsec = 5000, -- refresh every 5 seconds
    numUpdateSignsCoroutineResumesPerTick = 25,
    searchRadius4NearbyStation2JoinMetres = 100,

    colours = {
        white = { 1, 1, 1, },
        yellow = { 1, 0.75, 0, },
        orange = { 1, 0.541, 0, },
        orangeRed = { 1, 0.3, 0, },
        red = { 1, 0.1, 0.0, },
        green = { 0, 1, 0.1, },
        cyan = { 0, 0.5, 1.0, },
        blue = { 0, 0.1, 1.0, },
        black = { 0, 0, 0, },
    },

    eventId = '__lollo_departures_arrivals_predictor__',
    events = {
        hide_warnings = 'hide_warnings',
        join_sign_to_station_group = 'join_sign_to_station_group',
        remove_display_construction = 'remove_display_construction',
        toggle_notaus = 'toggle_notaus'
    },

    guiIds = {
        dynamicOnOffButtonId = 'lollo_arrivals_departures_predictor_dynamic_on_off_button',
        objectPickerWindowId = 'lollo_arrivals_departures_predictor_picker_window',
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
