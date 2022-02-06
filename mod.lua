local constructionHooks = require ("lolloArrivalsDeparturesPredictor.constructionHooks")

function data()
	return {
		info = {
			minorVersion = 0,
			severityAdd = "WARNING",
			severityRemove = "WARNING",
			name = _("ModName"),
			description = _("ModDesc"),
			tags = { "Track Asset", "Misc", "Script Mod" },
			visible = true,
			authors = {
				{
					name = "badgerrhax",
					role = "CREATOR"
				},
                {
					name = "lollus",
					role = "CREATOR"
				}
			}
		},

	--[[
		runFn = function()
			-- To add support for your own mod constructions, in your mod's runFn,
			-- require "bh_dynamic_arrivals_board/constructionHooks" and call construction.registerConstruction
			-- with the path to your construction file. The engine will then send data to it.
			constructionHooks.registerConstruction("asset/lolloArrivalsDeparturesPredictor/bh_digital_display.con", {
				 -- when true, attaches to a single terminal. if there is a "terminal_override" param on the construction it will use the number provided by that as the terminal,
				 -- expecting 0 to be "auto detect". 0 or absence of this parameter will auto detect the closest terminal to where the construction was placed.
				 -- when true, receives info about arrivals as parameters named "arrival_<index>_dest" and "arrival_<index>_time"
				 -- when false, attaches to the nearest station and receives data for ALL terminals in the station. there will be an additional parameter "arrival_<index>_terminal" containing the terminal id.
				 -- it is up to you to decide how your construction will handle a variable number of terminals in terms of model instances and positioning.
                 -- there is a similar parameter "cargo_override", useful to choose between the passenger or the cargo station of a station group.
                 -- station groups and station constructions are 1 to 1.
				singleTerminal = true,

				 -- send the current game time (in seconds) in a parameter "game_time" and formatted as HH:MM:SS in "time_string"
				clock = true,

				isArrivals = false, -- LOLLO TODO ignored for now
				-- show origins if true, destinations if false

				 -- max number of construction params that will be populated with arrival data. there may be less. "num_arrivals" param contains count if you want it.
				 -- if 0 there will be no arrival data provided at all (this thing becomes only a clock, basically)
				maxEntries = 2,

				-- false = time from now until arrival, true = world time of arrival
				absoluteArrivalTime = false,

				-- parameter name prefix (can help avoid conflicts with other mod params)
				labelParamPrefix = "bh_digital_display_"
			})
			constructionHooks.registerConstruction("asset/lolloArrivalsDeparturesPredictor/bh_digital_station_departures_display.con", {
				singleTerminal = false,
				clock = true,
				isArrivals = false,
				maxEntries = 8,
				absoluteArrivalTime = true,
				labelParamPrefix = "bh_departures_display_"
			})
			constructionHooks.registerConstruction("asset/lolloArrivalsDeparturesPredictor/bh_digital_station_arrivals_display.con", {
				singleTerminal = false,
				clock = true,
				isArrivals = true,
				maxEntries = 8,
				absoluteArrivalTime = true,
				labelParamPrefix = "bh_arrivals_display_"
			})
		end,
	]]
	}
end
