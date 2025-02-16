function data()
	return {
		en = {
            ["ModDesc"] =
                [[
Displays for incoming and outgoing vehicles, to be found in the assets menu.
Turn the updates on or off with the bottom bar. When turned on, they update every 5 seconds.
If you add a pair of brackets to your line names, the displays will show the stuff between the brackets, same as https://steamcommunity.com/sharedfiles/filedetails/?id=2528202101. The only difference is: if you add no brackets, the whole line name will be displayed. You can play with this, here some examples: "(IC 335) London - Rosenheim" will show as "IC 335". "Schnellzug (Flieg)ende( Kartof)fel" will show as "Flieg Kartof". Anything plus () will show no name at all.

I have been thinking long and hard whether to publish this mod or not, since I copied the idea from badgerrhax. However, this is my own code and my own models, so I do. If you don't like it, don't use it.

NOTES:
1) These things can be performance-intensive, so you can switch them on and off from the bottom bar (toggle the orange icon). Some other mods, such as advanced statistics, priority signals or shunting, hog game_script.update(). The game can only take so much, so you might need to choose.
2) If you think they are not working, check your bottom bar (toggle the orange icon), unpause the game and wait a little.
3) Once you attached a display to a station, it will be tied to it forever. If you bulldoze the station, its displays will disappear automatically, as soon as you unpause the game and the station dies.
4) Accuracy improves over time.
5) Accuracy goes down when you add or remove vehicles, it picks up again after a bit.
6) Rearrange these at any time with https://steamcommunity.com/sharedfiles/filedetails/?id=2748222965.

A big thank you goes out to Mr F from UG, this mod would have never worked without his help.
Another big thank you goes out to badgerrhax for the idea.
			]],
            ["ModName"] = "Dynamic Departures / Arrivals Displays",
            ["Align2Platform"] = "Align to Platform",
            ["ArrivalsAllCaps"] = "ARRIVALS",
            ["Auto"] = "Auto",
            ["ColourScheme"] = "Colour Scheme",
            ["displays"] = "displays",
            ["DynamicDisplaysOff"] = "Dynamic Displays OFF",
            ["DynamicDisplaysOn"] = "Dynamic Displays ON",
            ["Cargo"] = "Cargo",
            ["CompanyNamePrefix1"] = "A service provided by ",
            ["DeparturesAllCaps"] = "DEPARTURES",
            ["Due"] = "Due",
            ["PlatformDeparturesDisplayName"] = "Dynamic Departures Display for a Train Terminal",
            ["PlatformDeparturesDisplayDesc"] = "A digital display showing the next two trains approaching a terminal. It will be bulldozed if the station is bulldozed and you unpause the game.",
            ["StationArrivalsDisplayName"] = "Dynamic Arrivals Display for a Station",
            ["StationArrivalsDisplayDesc"] = "A digital display showing vehicles approaching all terminals at a nearby station. It will be bulldozed if the station is bulldozed and you unpause the game.",
            ["StationDeparturesDisplayName"] = "Dynamic Departures Display for a Station",
            ["StationDeparturesDisplayDesc"] = "A digital display showing vehicles departing from all terminals at a nearby station. It will be bulldozed if the station is bulldozed and you unpause the game.",
            ["StreetPlatformDeparturesDisplayName"] = "Dynamic Departures Display for a Street Terminal",
            ["StreetPlatformDeparturesDisplayDesc"] = "A digital display showing the next two vehicles approaching a terminal. It will be bulldozed if the station is bulldozed and you unpause the game.",
            ["CannotFindStationToJoin"] = "Cannot find a nearby station to join",
            ["From"] = "From",
            ["GoBack"] = "Go back",
            ["GoThere"] = "Go there",
            ["GuessedTooltip"] = "\"Auto\" changes the terminal automatically, when you close a station config menu, or this menu.",
            ["GuessedTooltip_Street"] = "\"Auto\" changes the kerb automatically, when you close this menu; it does not work with station constructions.",
            ["Join"] = "Join",
            ["MinutesShort"] = "'",
            ["No"] = "No",
            ["Passengers"] = "Passengers",
            ["PlatformShort"] = "↑↓", -- ↑ ↓ Plat = ─ ┼ ═
            ["ShowIntermediateDestinations"] = "Show Intermediate Destinations",
            ["SorryNoService"] = "Sorry no service",
            ["SorryTrouble"] = "We are sorry",
            ["SorryTroubleShort"] = "!",
            ["StationPickerWindowTitle"] = "Pick a station to join",
            ["Style"] = "Style",
            ["Terminal"] = "Terminal",
            ["Terminal_Street"] = "Kerb",
            ["Time"] = "Time",
            ["TimeDisplay"] = "Time Display",
            ["To"] = "To",
            ["WarningWindowTitle"] = "Warning",
            ["Yes"] = "Yes",
        },
        de = {
            ["ModDesc"] =
                [[
Displays for incoming and outgoing vehicles, to be found in the assets menu.
Turn the updates on or off with the bottom bar. When turned on, they update every 5 seconds.
If you add a pair of brackets to your line names, the displays will show the stuff between the brackets, same as https://steamcommunity.com/sharedfiles/filedetails/?id=2528202101. The only difference is: if you add no brackets, the whole line name will be displayed. You can play with this, here some examples: "(IC 335) London - Rosenheim" will show as "IC 335". "Schnellzug (Flieg)ende( Kartof)fel" will show as "Flieg Kartof". Anything plus () will show no name at all.

I have been thinking long and hard whether to publish this mod or not, since I copied the idea from badgerrhax. However, this is my own code and my own models, so I do. If you don't like it, don't use it.

NOTES:
1) These things can be performance-intensive, so you can switch them on and off from the bottom bar (toggle the orange icon). Some other mods, such as advanced statistics, priority signals or shunting, hog game_script.update(). The game can only take so much, so you might need to choose.
2) If you think they are not working, check your bottom bar (toggle the orange icon), unpause the game and wait a little.
3) Once you attached a display to a station, it will be tied to it forever. If you bulldoze the station, its displays will disappear automatically, as soon as you unpause the game and the station dies.
4) Accuracy improves over time.
5) Accuracy goes down when you add or remove vehicles, it picks up again after a bit.
6) Rearrange these at any time with https://steamcommunity.com/sharedfiles/filedetails/?id=2748222965.

A big thank you goes out to Mr F from UG, this mod would have never worked without his help.
Another big thank you goes out to badgerrhax for the idea.
			]],
            ["ModName"] = "Dynamic Departures / Arrivals Displays",
            ["Align2Platform"] = "Automatisch ausrichten",
            ["ArrivalsAllCaps"] = "ANKUNFT",
            ["Auto"] = "Auto",
            ["ColourScheme"] = "Farbauswahl",
            ["displays"] = "Anzeigen",
            ["DynamicDisplaysOff"] = "Dynamische Anzeigen AUS",
            ["DynamicDisplaysOn"] = "Dynamische Anzeigen EIN",
            ["Cargo"] = "Fracht",
            ["CompanyNamePrefix1"] = "Ein Dienst von ",
            ["DeparturesAllCaps"] = "ABFAHRT",
            ["Due"] = "!!!",
            ["PlatformDeparturesDisplayName"] = "Dynamische Gleisabfahrtsanzeige",
            ["PlatformDeparturesDisplayDesc"] = "A digital display showing the next two trains approaching a terminal. It will be bulldozed if the station is bulldozed and you unpause the game.",
            ["StationArrivalsDisplayName"] = "Dynamische Bahnhofsankunftsanzeige",
            ["StationArrivalsDisplayDesc"] = "A digital display showing vehicles approaching all terminals at a nearby station. It will be bulldozed if the station is bulldozed and you unpause the game.",
            ["StationDeparturesDisplayName"] = "Dynamische Bahnhofsabfahrtsanzeige",
            ["StationDeparturesDisplayDesc"] = "A digital display showing vehicles departing from all terminals at a nearby station. It will be bulldozed if the station is bulldozed and you unpause the game.",
            ["StreetPlatformDeparturesDisplayName"] = "Dynamische Haltestellenabfahrtsanzeige",
            ["StreetPlatformDeparturesDisplayDesc"] = "A digital display showing the next two vehicles approaching a terminal. It will be bulldozed if the station is bulldozed and you unpause the game.",
            ["CannotFindStationToJoin"] = "Keinen Bahnhof in der Nähe gefunden",
            ["From"] = "Von",
            ["GoBack"] = "Zurück",
            ["GoThere"] = "Guck",
            ["GuessedTooltip"] = "\"Auto\" justiert das Gleis automatisch, wenn ein Bahnhof-Konfig-Menü, oder diese Menü, geschlossen wird.",
            ["GuessedTooltip_Street"] = "\"Auto\" justiert die Haltestelle automatisch, wenn diese Menü geschlossen wird. Es funktioniert mit Haltestellenkonstruktionen nicht.",
            ["Join"] = "Verknüpfen",
            ["MinutesShort"] = "'",
            ["No"] = "Nein",
            ["Passengers"] = "Passagiere",
            ["PlatformShort"] = "↑↓", -- ↑ ↓ Gls = ─ ┼ ═
            ["ShowIntermediateDestinations"] = "Zwischenhalte anzeigen",
            ["SorryNoService"] = "Kein Dienst",
            ["SorryTrouble"] = "Störung",
            ["SorryTroubleShort"] = "!",
            ["StationPickerWindowTitle"] = "Wähle einen Bahnhof",
            ["Style"] = "Stil",
            ["Terminal"] = "Gleis",
            ["Terminal_Street"] = "Haltestelle",
            ["Time"] = "Zeit",
            ["TimeDisplay"] = "Zeitformat",
            ["To"] = "Nach",
            ["WarningWindowTitle"] = "Achtung",
            ["Yes"] = "Ja",
        },
        it = {
            ["ModDesc"] =
                [[
Tabelloni per veicoli in arrivo e in partenza, si trovano nel menu \"assets\".
Attiva o disattiva gli aggiornamenti con la barra in basso. Quando sono accesi, si aggiornano ogni 5 secondi.
Se aggiungi un paio di parentesi ai nomi delle linee, i tabelloni mostreranno i caratteri fra le parentesi, come https://steamcommunity.com/sharedfiles/filedetails/?id=2528202101. L'unica differenza è: se non si aggiungono parentesi, verrà visualizzato l'intero nome della riga. Puoi sperimentare, ecco alcuni esempi: "(IC 335) London - Rosenheim" verrà visualizzato come "IC 335". "(Rap)ido Andrea (Doria)" apparirà come "Rap Doria". Qualunque cosa più () non mostrerà alcun nome.

Ho pensato a lungo se pubblicare o meno questa mod, dato che ho copiato l'idea da badgerrhax. Alla fine questo è il mio codice e i miei modelli, quindi l'ho fatto. Se non ti piace, non usarla.

NOTE:
1) Questi tabelloni possono succhiare molta CPU, quindi puoi attivarli e disattivarli dalla barra in basso (usa l'icona arancione). Esistono altre mod, come advanced statistics, priority signals or shunting, che adoperano game_script.update(). Il gioco pone dei limiti, quindi a volte bisogna scegliere.
2) Se pensi che non funzionino, controlla la barra in basso (usa l'icona arancione) e aspetta un po'.
3) Una volta collegato un tabellone a una stazione, sarà legato ad essa per sempre. Se demolisci la stazione i suoi tabelloni scompariranno automaticamente, non appena riprendi il gioco e la stazione muore.
4) La precisione migliora nel tempo.
5) La precisione diminuisce quando aggiungi o rimuovi veicoli e torna migliore dopo un po'.
6) Sposta questi tabelloni quando vuoi con https://steamcommunity.com/sharedfiles/filedetails/?id=2748222965.

Un grande ringraziamento va a Mr F di Urban Games; questa mod non avrebbe mai funzionato senza il suo aiuto.
Un altro grande ringraziamento va a Badgerrhax per l'idea.
			]],
            ["ModName"] = "Tabelloni dinamici per arrivi e partenze",
            ["Align2Platform"] = "Allinea alla pensilina",
            ["ArrivalsAllCaps"] = "ARRIVI",
            ["Auto"] = "Auto",
            ["ColourScheme"] = "Colori",
            ["displays"] = "tabelloni",
            ["DynamicDisplaysOff"] = "Tabelloni dinamici SPENTI",
            ["DynamicDisplaysOn"] = "Tabelloni dinamici ACCESI",
            ["Cargo"] = "Merci",
            ["CompanyNamePrefix1"] = "Un servizio di ",
            ["DeparturesAllCaps"] = "PARTENZE",
            ["Due"] = "!!!",
            ["PlatformDeparturesDisplayName"] = "Tabellone dinamico per binari ferroviari",
            ["PlatformDeparturesDisplayDesc"] = "Un tabellone digitale che mostra i prossimi due treni in arrivo al binario. Si autodistruggerà se distruggi la stazione e riprendi il gioco.",
            ["StationArrivalsDisplayName"] = "Tabellone dinamico per arrivi",
            ["StationArrivalsDisplayDesc"] = "Un tabellone digitale che mostra i veicoli in arrivo a tutti i binari/marciapiedi/altro di una stazione/aeroporto/porto nelle vicinanze. Si autodistruggerà se distruggi la stazione e riprendi il gioco.",
            ["StationDeparturesDisplayName"] = "Tabellone dinamico per partenze",
            ["StationDeparturesDisplayDesc"] = "Un tabellone digitale che mostra i veicoli in partenza da tutti i binari di una stazione/aeroporto/porto nelle vicinanze. Si autodistruggerà se distruggi la stazione e riprendi il gioco.",
            ["StreetPlatformDeparturesDisplayName"] = "Tabellone dinamico per fermate",
            ["StreetPlatformDeparturesDisplayDesc"] = "Un tabellone digitale che mostra i prossimi due veicoli in arrivo al marciapiede. Si autodistruggerà se distruggi la stazione e riprendi il gioco.",
            ["CannotFindStationToJoin"] = "Non vedo stazioni qui vicino",
            ["From"] = "Origine",
            ["GoBack"] = "Indietro",
            ["GoThere"] = "Guarda",
            ["GuessedTooltip"] = "\"Auto\" cambia il binario automaticamente quando chiudi il menu di configurazione della stazione, oppure questo menu.",
            ["GuessedTooltip_Street"] = "\"Auto\" cambia il marciapiede automaticamente quando chiudi questo menu; non funziona con costruzioni-stazione.",
            ["Join"] = "Unisci",
            ["MinutesShort"] = "'",
            ["No"] = "No",
            ["Passengers"] = "Passeggeri",
            ["PlatformShort"] = "↑↓", -- ↑ ↓ Bin = ─ ┼ ═
            ["ShowIntermediateDestinations"] = "Mostra destinazioni intermedie",
            ["SorryNoService"] = "Fuori servizio",
            ["SorryTrouble"] = "Disturbo sulla linea",
            ["SorryTroubleShort"] = "!",
            ["StationPickerWindowTitle"] = "Scegli una stazione",
            ["Style"] = "Stile",
            ["Terminal"] = "Binario",
            ["Terminal_Street"] = "Marciapiede",
            ["Time"] = "Ora",
            ["TimeDisplay"] = "Formato dell'ora",
            ["To"] = "Destinazione",
            ["WarningWindowTitle"] = "Attenzione",
            ["Yes"] = "Sì",
        },
    }
end
