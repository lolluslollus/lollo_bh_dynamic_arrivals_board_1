local constants = {
    refreshPeriodMsec = 5000, -- refresh every 5 seconds
    searchRadius4NearbyStation2JoinMetres = 50,

    guesstimatedStationWaitingTimeMsec = 30000,

    eventId = '__lollo_departures_arrivals_predictor__',
    eventIdOLD = 'bh_arrivals_manager',
    eventSource = 'lollo_departures_arrivals_predictor',
    eventSourceOLD = 'bh_gui_engine.lua',
    events = {
        hide_warnings = 'hide_warnings',
        join_sign_to_station = 'join_sign_to_station',
        remove_display_construction = 'remove_display_construction',
    },

    nameTags = {
        clock = 'clock',
    }
}

return constants
