local _, ns = ...

-- The stops of Flat UI setup, in the order the walk visits them (SetupWalk.lua shows them, Setup.lua lists them). A stop is { id, title, line,
-- draw, spot, more, parts }: draw is the drawing of its cards and of its picture on Your screen, spot is its place on the screen map at the top of
-- the list (left, top, width and height as shares of the screen), and more lists the steps of SetupSteps.lua that More settings opens.
-- A part is { id, label, note, kind, owns, styles, cards }. kind is "cards" (one of them, each drawn), "chips" (one of them, a small button each,
-- shown on the cards while pointed at) or "ticks" (each on or off). A part owns every path its cards name and the paths in owns: a card sets each
-- to its own value, else to the setting's default. With styles, the cards are those of ns.SETUP_FRAME_STYLES when that table has any.
-- A card is { id, label, line, values, suggest, icon, action }: suggest names the facts that make it the suggestion (SetupWalk.lua, Walk.Facts;
-- "else" is always true and counts last), icon names a cell of the sidebar's icons (PanelNav.lua), and action is a list pick that a tick queues
-- for Finish. SetupWalk.lua checks every value the first time it reads the table, as Setup.lua checks the ready-made profiles.

local U = "unitframes."

ns.SETUP_STOPS = {
	{
		id = "me", title = "Your character", line = "Your own frame, top left. The frame you pick here goes on every unit frame.",
		draw = "mock-player", spot = { 0.03, 0.05, 0.22, 0.12 },
		more = { "uf-portraits", "uf-bars", "uf-row", "uf-text", "uf-player", "look", "bars" },
		parts = {
			-- The unit frame styles (Config.lua, ns.SETUP_FRAME_STYLES); while there are none, this part has no cards and Picture takes its place.
			{ id = "frame", label = "Frame", kind = "cards", styles = true, owns = { U .. "enabled", U .. "player" }, cards = {} },
			-- Every path here is also a path of the styles, so this part goes while the styles are there.
			{ id = "picture", label = "Picture", kind = "cards", owns = { U .. "enabled", U .. "player" }, cards = {
				{ id = "face", label = "Face", line = "Your face beside the bars.", suggest = { "else" },
					values = { [U .. "portraitStyle"] = "picture" } },
				{ id = "head", label = "3D head", line = "Your character, moving, beside the bars.",
					values = { [U .. "portraitStyle"] = "head" } },
				{ id = "icon", label = "Class icon", line = "Your class's icon. Other units keep their face.",
					values = { [U .. "portraitStyle"] = "icon" } },
				{ id = "game", label = "Game portrait", line = "The game's portrait, drawn in your frame.",
					values = { [U .. "playerPicture"] = "game", [U .. "targetPicture"] = "game", [U .. "focusPicture"] = "game", [U .. "petPicture"] = "game",
						[U .. "totPicture"] = "game" } },
				{ id = "none", label = "None", line = "Just the name and the bars.",
					values = { [U .. "portraitStyle"] = "none" } },
			} },
			{ id = "finish", label = "Borders and bars", note = "Also on nameplates, action bars and windows.", kind = "chips", cards = {
				{ id = "thin", label = "Thin borders", suggest = { "else" },
					values = { ["general.borderless"] = false, ["general.barTexture"] = "flat", [U .. "corners"] = "square", [U .. "playerHealthBy"] = "custom" } },
				{ id = "soft", label = "Soft",
					values = { ["general.borderless"] = true, ["general.barTexture"] = "soft", [U .. "corners"] = "soft", [U .. "playerHealthBy"] = "custom" } },
				{ id = "class", label = "Soft in class colour",
					values = { ["general.borderless"] = true, ["general.barTexture"] = "soft", [U .. "corners"] = "soft", [U .. "playerHealthBy"] = "class" } },
			} },
		},
	},
	{
		id = "group", title = "Your target and party", line = "Whoever you click, and your group. Pick what their health bars say.",
		draw = "mock-group-frames", spot = { 0.28, 0.05, 0.2, 0.12 },
		more = { "uf-player", "uf-other", "uf-party", "uf-group", "uf-icons", "uf-frames" },
		parts = {
			{ id = "text", label = "Health text", kind = "cards",
				owns = { U .. "playerHealthText", U .. "targetHealthText", U .. "focusHealthText", U .. "partyHealthText", U .. "bossHealthText",
					U .. "partyRangeDim", U .. "target", U .. "party" },
				cards = {
					{ id = "damage", label = "For damage", line = "Your target's health in percent, for Execute and finishing moves.", suggest = { "damage" },
						values = { [U .. "targetHealthText"] = "pct" } },
					{ id = "tank", label = "For tanking", line = "Health and percent on your frames and your party's.", suggest = { "tank" },
						values = { [U .. "playerHealthText"] = "curpct", [U .. "targetHealthText"] = "curpct", [U .. "focusHealthText"] = "curpct",
							[U .. "partyHealthText"] = "curpct", [U .. "bossHealthText"] = "curpct" } },
					{ id = "healer", label = "For healing", line = "Missing health on your party, and members out of range dimmed.", suggest = { "healer" },
						values = { [U .. "playerHealthText"] = "pct", [U .. "targetHealthText"] = "pct", [U .. "focusHealthText"] = "pct",
							[U .. "bossHealthText"] = "pct", [U .. "partyHealthText"] = "miss", [U .. "partyRangeDim"] = true } },
					{ id = "plain", label = "As the game has it", line = "Health text as the game's Status Text option shows it.", values = {} },
				} },
		},
	},
	{
		-- Not "bars": that is the id of the step Bar texture and colours, and ns.OpenSetup takes the id of a stop or of a step.
		id = "actionbars", title = "Your action bars", line = "Your spells, bottom middle. Pick how the buttons look.",
		draw = "mock-action-row", spot = { 0.3, 0.84, 0.4, 0.12 },
		more = { "ab-bars", "ab-text", "ab-colours", "ab-effects", "ab-block", "ab-places", "cb-look", "cb-size", "cb-text" },
		parts = {
			{ id = "buttons", label = "Buttons", kind = "cards",
				owns = { "actionbars.enabled", "actionbars.own", "actionbars.square", "actionbars.empty", "actionbars.nameShow", "actionbars.hotkeyShow" },
				cards = {
					{ id = "flat", label = "Flat buttons", line = "Square icons, thin borders, every slot shown.", suggest = { "else" }, values = {} },
					{ id = "quiet", label = "Flat and quiet", line = "Empty slots hidden, no macro names, hotkeys on the main bar only.", suggest = { "small" },
						values = { ["actionbars.empty"] = "hidden", ["actionbars.nameShow"] = "none", ["actionbars.hotkeyShow"] = "main" } },
					{ id = "round", label = "Round icons", line = "Flat buttons with the game's round icons. After a reload.",
						values = { ["actionbars.square"] = false } },
					{ id = "game", label = "The game's buttons", line = "As the game draws them, for another bar addon. After a reload.",
						values = { ["actionbars.own"] = "game", ["actionbars.enabled"] = false } },
				} },
		},
	},
	{
		id = "plates", title = "Enemies' nameplates", line = "The bars over enemies' heads. Pick how much they show.",
		draw = "mock-nameplate-walk", spot = { 0.42, 0.36, 0.16, 0.08 },
		more = { "np-plate", "np-text", "np-colours", "np-cast", "np-auras", "np-marks", "np-game" },
		parts = {
			{ id = "plates", label = "Nameplates", kind = "cards",
				owns = { "nameplates.enabled", "nameplates.healthHeight", "nameplates.barWidth", "nameplates.nameSize", "nameplates.healthText",
					"nameplates.auraTimers", "nameplates.aurasWhen", "nameplates.castTime", "nameplates.colours", "nameplates.lowHealth" },
				cards = {
					{ id = "plain", label = "Plain plates", line = "Flat bars at the game's size.", values = {} },
					{ id = "tall", label = "Taller, with cast times", line = "Reaction colours, cast times and a border under 20% health.", suggest = { "tank", "damage" },
						values = { ["nameplates.healthHeight"] = 125, ["nameplates.castTime"] = true, ["nameplates.colours"] = true, ["nameplates.lowHealth"] = true } },
					{ id = "small", label = "Small and quiet", line = "Narrow, no health text, auras only on your target.", suggest = { "healer", "small" },
						values = { ["nameplates.healthHeight"] = 80, ["nameplates.barWidth"] = 80, ["nameplates.nameSize"] = 90, ["nameplates.healthText"] = false,
							["nameplates.auraTimers"] = false, ["nameplates.aurasWhen"] = "target" } },
				} },
		},
	},
	{
		id = "chat", title = "Chat", line = "Bottom left. Pick how much the chat window stands out.",
		draw = "mock-chat", spot = { 0.02, 0.66, 0.26, 0.28 },
		more = { "chat-window", "chat-text", "tips" },
		parts = {
			{ id = "panel", label = "Chat window", kind = "cards", owns = { "chat.enabled", "chat.frames", "chat.opacity", "chat.frameBorder" }, cards = {
				{ id = "dark", label = "Dark panel", line = "See-through dark, with a thin border.", suggest = { "else" }, values = {} },
				{ id = "light", label = "Light panel", line = "Faint, with no border: the world shows through.", suggest = { "small" },
					values = { ["chat.opacity"] = 25, ["chat.frameBorder"] = false } },
				{ id = "solid", label = "Solid panel", line = "Almost solid, so the text is easy to read.", suggest = { "large" },
					values = { ["chat.opacity"] = 90 } },
				{ id = "none", label = "No panel", line = "The game's own chat background.", values = { ["chat.frames"] = false } },
			} },
		},
	},
	{
		id = "helpers", title = "Helpers", line = "Things Flat UI can do for you. Tick the ones you want.",
		more = { "tr-list", "tr-look", "tr-proc", "tr-def", "cd-row", "cd-states", "pcd", "ecd", "ct" },
		parts = {
			{ id = "helpers", label = "Helpers", kind = "ticks", cards = {
				{ id = "trackers", label = "Class trackers", line = "Icons for your class's buffs and items, red when one runs low.", icon = "trackers",
					suggest = { "notrackers" }, action = { pick = "TrackerAddClass", id = 1, text = "Add class trackers: All" } },
				{ id = "errands", label = "Errands", line = "Sells grey items, repairs, loots at once and hands in quests.", icon = "errands",
					suggest = { "levelling" }, values = { ["errands.enabled"] = true } },
				{ id = "datapanels", label = "Data panels", line = "Bag space, gold, durability and more at the edge of the screen.", icon = "datapanels",
					values = { ["datapanels.enabled"] = true } },
				{ id = "threat", label = "Threat list", line = "Your group by threat on the enemy you fight.", icon = "threat",
					suggest = { "tank" }, values = { ["threat.enabled"] = true } },
				{ id = "healermana", label = "Healer mana", line = "The mana of your group's healers.", icon = "healermana",
					suggest = { "healer" }, values = { ["healermana.enabled"] = true } },
				{ id = "grouptools", label = "Group tools", line = "Raid markers, a ready check and a pull countdown.", icon = "grouptools",
					values = { ["grouptools.enabled"] = true } },
				{ id = "mount", label = "Mount key", line = "One key mounts you. Bind it in the game's Key Bindings.", icon = "mount",
					values = { ["mount.enabled"] = true } },
				{ id = "consumables", label = "Drink and health macros", line = "Two macros that always hold your best drink and potion.", icon = "consumables",
					values = { ["consumables.enabled"] = true } },
			} },
		},
	},
}
