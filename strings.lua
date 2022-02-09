function data()
	return {
		en = {
            ["ModDesc"] =
                [[
[h1]EARLY BETA VERSION - EXPECT BUGS AND INCOMPATIBILITIES[/h1]
At this time I make no promises about feature-completeness or stability.
Depending on feedback and bugs I may have to rework things that could cause this mod to stop working on earlier save games.

[b]DURING BETA, PLEASE BACK UP YOUR SAVE GAMES BEFORE SAVING THIS MOD IN THEM[/b]
Pretty good general advice when experimenting with new mods, really :)

I'm making this available for people to help with testing if they wish.

[b]What I'd like help with[/b]
- Feedback on how well it performs on various computers and map sizes, station sizes, etc.
- Feedback about the functionality, what is good, bad, missing
- Mods that might stop this working - e.g. the Timetables mod which I am already investigating for compatibility

[b]Logging is enabled for the beta period[/b]
- Update timing
- Selected sign details
- Selected vehicle time to arrival at each station with a sign on

If you report performance or timing issues I may request that you provide this info from your stdout.txt.

When I am happy with the quality and performance I will remove all these beta warnings.

[h1]Main Features[/h1]
* = refer to known issues and limitations for clarifications
- [b]Single Terminal Arrivals Display[/b] - place it on a platform and it will automatically* display the next arriving trains to that platform
- [b]Station Departures Display[/b] - place within 50m* of a station and it will display up to the next 8 trains and their destinations / platform / departure times

[h1]Planned Features[/h1]
I'm planning on extending the mod to support signs displaying the following type of information
- Single Terminal for one vehicle with list of "calling at" stations
- Station Arrivals Display (showing origins instead of destinations)

[h1]Known issues[/h1]
These are things I've identified as needing more work
- Must be placed within 50m of a station - this distance is abitrary and open to feedback on reasonable values
- The terminal detection needs improvement - if you place it too far from where the train stops it'll likely get it wrong. There's a terminal override on the asset parameters for now.
- Line destination calculations may be wrong for some lines - it depends how they are defined. If you have lines that it gets wrong, please provide the list of stops and expected destinations. It may or may not be possible to automatically calculate - e.g. I don't think it'll ever work for "circular" lines without manual configuration
- Detection of nearby street bus stations is only semi-functional - especially when there is a terminal on both sides of the road. Work in progress.
- General code optimisations will be done once the functionality is solid, to speed up the station updates

[h1]Limitations[/h1]
These are things I don't believe can be much better than they are right now
- The ETA calculations are based on previous arrival times and segment travel times - if the vehicle has not travelled the line at least once, this data will be inaccurate but will improve over time.
- [b]You must pause the game before editing / deleting the assets[/b] - the asset is regularly "replaced" so by the time you've clicked bulldoze, the thing you tried to bulldoze isn't there anymore.

[h1]Extensibility[/h1]
This is designed to work as a base mod for other modders to create their own displays too. There's a construction registration API where you can tell it about your
display construction and it will manage its display updates when placed in game. See the comments in mod.lua and how the included constructions use the data the engine provides.

[b]Please report any bugs with this mod so I can try to address them.[/b]
			]],
            ["ModName"] = "Dynamic Departures / Arrivals Boards",
            ["AlignFree"] = 'Free',
            ["AlignPlatform"] = 'Platform',
            ["ArrivalsAllCaps"] = "ARRIVALS",
            ["Auto"] = "Auto",
            ["BoardsOff"] = "Dynamic boards OFF",
            ["BoardsOn"] = "Dynamic boards ON",
            ["Cargo"] = "Cargo",
            ["CompanyNamePrefix1"] = "A service provided by ",
            ["DeparturesAllCaps"] = "DEPARTURES",
            ["Destination"] = "Destination",
            ["Due"] = "Due",
            ["PlatformDeparturesDisplayName"] = "Dynamic Arrivals Single Terminal",
            ["PlatformDeparturesDisplayDesc"] = "A digital display showing the next two approaching trains to a single terminal. It will be bulldozed when the station is bulldozed and you unpause the game.",
            ["StationArrivalsDisplayName"] = "Dynamic Arrivals Summary Board",
            ["StationArrivalsDisplayDesc"] = "A digital display showing approaching trains to all terminals at a nearby station. It will be bulldozed when the station is bulldozed and you unpause the game.",
            ["StationDeparturesDisplayName"] = "Dynamic Departures Summary Board",
            ["StationDeparturesDisplayDesc"] = "A digital display showing trains departing from all terminals at a nearby station. It will be bulldozed when the station is bulldozed and you unpause the game.",
            ["CannotFindStationToJoin"] = "Cannot find a nearby station to join",
            ["FromSpace"] = "From ",
            ["From"] = "From",
            ["GoBack"] = "Go back",
            ["GoThere"] = "Go there",
            ["Join"] = "Join",
            ["MinutesShort"] = "min",
            ["NoJoin"] = "Do not join",
            ["Origin"] = "Origin",
            ["Passengers"] = "Passengers",
            ["PlatformShort"] = "Plat",
            ["SorryNoService"] = "Sorry No Service",
            ["StationPickerWindowTitle"] = "Pick a station to join",
            ["StationSection"] = "Station Section",
            ["Time"] = "Time",
            ["To"] = "To",
            ["WarningWindowTitle"] = "Warning",
        },
    }
end