function data()
	return {
		en = {
            ["ModDesc"] =
                [[
                    Displays for incoming and outgoing vehicles.
                    Turn the updates on or off with the bottom bar. When turned on, they update every 5 seconds.
                    If you add a pair of brackets to your line names, the displays will show the stuff between the brackets, same as https://steamcommunity.com/sharedfiles/filedetails/?id=2528202101.

                    I have been thinking long and hard whether to publish this mod or not, since I copied the idea from badgerrhax. However, this is my own code and my own models, so I do. If you don't like it, don't use it.

                    NOTES:
                    - These things can be performance-intensive, so you can switch them on and off from the bottom bar.
                    - If you think they are not working, check your bottom bar, unpause the game and wait a little.
                    - Once you attached a display to a station, it will be tied to it forever. If you bulldoze the station, its displays will disappear automatically, as soon as you unpause the game.
                    - Accuracy improves over time.
                    - Accuracy goes down when you add or remove vehicles, it picks up again after a bit.
                    - Rearrange these at any time with the construction mover.

                    A big thank you goes out to Mr F from UG, this mod would have never worked without his help.
                    Another big thank you goes out to badgerrhax for the idea.
			]],
            ["ModName"] = "Dynamic Departures / Arrivals Displays",
            ["Align2Platform"] = "Align to Platform",
            ["ArrivalsAllCaps"] = "ARRIVALS",
            ["Auto"] = "Auto",
            ["displays"] = "displays",
            ["DynamicDisplaysOff"] = "Dynamic Displays OFF",
            ["DynamicDisplaysOn"] = "Dynamic Displays ON",
            ["Cargo"] = "Cargo",
            ["CompanyNamePrefix1"] = "A service provided by ",
            ["DeparturesAllCaps"] = "DEPARTURES",
            ["Destination"] = "Destination",
            ["Due"] = "Due",
            ["PlatformDeparturesDisplayName"] = "Dynamic Departures Display for a Terminal",
            ["PlatformDeparturesDisplayDesc"] = "A digital display showing the next two trains approaching a terminal. It will be bulldozed when the station is bulldozed and you unpause the game.",
            ["StationArrivalsDisplayName"] = "Dynamic Arrivals Display for a Station",
            ["StationArrivalsDisplayDesc"] = "A digital display showing approaching vehicles to all terminals at a nearby station. It will be bulldozed when the station is bulldozed and you unpause the game.",
            ["StationDeparturesDisplayName"] = "Dynamic Departures Display for a Station",
            ["StationDeparturesDisplayDesc"] = "A digital display showing vehicles departing from all terminals at a nearby station. It will be bulldozed when the station is bulldozed and you unpause the game.",
            ["StreetPlatformDeparturesDisplayName"] = "Dynamic Departures Display for a Street Terminal",
            ["StreetPlatformDeparturesDisplayDesc"] = "A digital display showing the next two vehicles approaching a terminal. It will be bulldozed when the station is bulldozed and you unpause the game.",
            ["CannotFindStationToJoin"] = "Cannot find a nearby station to join",
            ["FromSpace"] = "From ",
            ["From"] = "From",
            ["GoBack"] = "Go back",
            ["GoThere"] = "Go there",
            ["GuessedTooltip"] = "Adjust this if required",
            ["Join"] = "Join",
            ["MinutesShort"] = "'",
            ["No"] = "No",
            ["Origin"] = "Origin",
            ["Passengers"] = "Passengers",
            ["PlatformShort"] = "↑", -- ↑ ↓ Plat
            ["SorryNoService"] = "Sorry no service",
            ["SorryTrouble"] = "We are sorry",
            ["SorryTroubleShort"] = "!",
            ["StationPickerWindowTitle"] = "Pick a station to join",
            ["StationSection"] = "Station Section",
            ["Time"] = "Time",
            ["TimeDisplay"] = "Time Display",
            ["To"] = "To",
            ["WarningWindowTitle"] = "Warning",
            ["Yes"] = "Yes",
        },
    }
end