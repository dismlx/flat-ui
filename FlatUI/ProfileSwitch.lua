local ADDON_NAME, ns = ...

-- Switch automatically: a profile for each kind of place, chosen on the Profiles page. The rules belong to the character, so they are saved in
-- FlatUIDB.profileRules under "Name - Realm" beside FlatUIDB.profileOf, outside every profile and outside the text form of a profile.
-- A rule with no profile is No change, which is what every character has until a rule is chosen. A rule picked for the kind of place the character
-- is in now asks whether to switch now (Switch now or Later); otherwise the switch waits for the next change of place. A switch due in a fight
-- waits for its end, unless a profile is picked by hand meanwhile (Switch.Drop). A profile picked by hand in a fight (the options window, Home's
-- Profile card, /flatui profile Name) waits here too (Switch.Keep), and wins over the rule: a frame after the fight ends it is put in use and chat
-- says "Flat UI: using Raid.". The window's title bar shows what waits, either kind (Switch.Wanted). Delete profile keeps the rules that pointed at
-- the profile for the session (Switch.RulesOf), and its Bring back puts them back (Switch.Restore).

local Switch = {}
ns.ProfileSwitch = Switch

local NONE = "No change"
-- last: the kind of place last seen; pending: the rule's switch waits for the fight's end; wanted: the profile picked by hand in a fight.
local last, pending, wanted
Switch.KINDS = {
	{ key = "dungeon", label = "In a dungeon" },
	{ key = "raid", label = "In a raid" },
	{ key = "pvp", label = "In a battleground or arena" },
	{ key = "other", label = "Everywhere else" },
}

-- IsInInstance answers true and the type: "party", "raid", "pvp", "arena", "scenario" or "none" (InstanceDocumentation.lua:170-178;
-- InstanceDifficulty.lua:228 and :242 read "arena" and "party"; BossBannerToast.lua:196 reads "raid"; Deprecated_ArenaUI.lua:39-40 reads "pvp").
local KIND_OF = { party = "dungeon", raid = "raid", pvp = "pvp", arena = "pvp" }

-- The kind of place the character is in now.
function Switch.Kind()
	local ok, inside, instanceType = pcall(IsInInstance)
	if ok and inside and type(instanceType) == "string" and not (issecretvalue and issecretvalue(instanceType)) then
		return KIND_OF[instanceType] or "other"
	end
	return "other"
end

-- The rules of this character, or nil. With create, the table is made.
local function Rules(create)
	local db, key = ns.Account(), ns.CharacterKey()
	if type(db) ~= "table" or not key then
		return nil
	end
	if type(db.profileRules) ~= "table" then
		if not create then
			return nil
		end
		db.profileRules = {}
	end
	if type(db.profileRules[key]) ~= "table" and create then
		db.profileRules[key] = {}
	end
	local rules = db.profileRules[key]
	return type(rules) == "table" and rules or nil
end

local function Exists(name)
	for _, stored in ipairs(ns.Profiles()) do
		if stored == name then
			return true
		end
	end
	return false
end

-- The profile this character switches to in a kind of place, or nil for No change. A rule whose profile is gone is dropped.
function Switch.Get(kind)
	local rules = Rules(false)
	local name = rules and rules[kind]
	if name == nil then
		return nil
	end
	if type(name) ~= "string" or not Exists(name) then
		rules[kind] = nil
		return nil
	end
	return name
end

-- Chooses the profile for a kind of place; nil is No change. Returns false when the kind or the profile is not known or the character has no name.
function Switch.Set(kind, name)
	local known = false
	for _, entry in ipairs(Switch.KINDS) do
		known = known or entry.key == kind
	end
	if not known or (name ~= nil and not Exists(name)) then
		return false
	end
	local rules = Rules(true)
	if not rules then
		return false
	end
	rules[kind] = name
	last = last or Switch.Kind()
	return true
end

-- A profile was renamed (the Rename function of Core.lua must call this): every rule of every character that pointed at it follows.
function Switch.Renamed(old, new)
	local db = ns.Account()
	for _, rules in pairs(type(db) == "table" and type(db.profileRules) == "table" and db.profileRules or {}) do
		if type(rules) == "table" then
			for kind, name in pairs(rules) do
				if name == old then
					rules[kind] = new
				end
			end
		end
	end
end

-- A profile was deleted: every rule of every character that pointed at it is No change.
function Switch.Deleted(old)
	Switch.Renamed(old, nil)
end

-- The rules of every character that point at a profile, by "Name - Realm": { [key] = { kind, ... } }, or nil when none does. Delete profile keeps
-- them for its Bring back (Core.lua, ns.DeleteProfile).
function Switch.RulesOf(name)
	local db, found = ns.Account(), nil
	for key, rules in pairs(type(db) == "table" and type(db.profileRules) == "table" and db.profileRules or {}) do
		if type(rules) == "table" then
			for kind, used in pairs(rules) do
				if used == name then
					found = found or {}
					found[key] = found[key] or {}
					table.insert(found[key], kind)
				end
			end
		end
	end
	return found
end

-- Puts back the rules RulesOf gave for a profile that came back, each one only while it is still No change.
function Switch.Restore(name, kept)
	local db = ns.Account()
	if type(db) ~= "table" or type(kept) ~= "table" then
		return
	end
	if type(db.profileRules) ~= "table" then
		db.profileRules = {}
	end
	for key, kinds in pairs(kept) do
		if type(db.profileRules[key]) ~= "table" then
			db.profileRules[key] = {}
		end
		local rules = db.profileRules[key]
		for _, kind in ipairs(kinds) do
			if rules[kind] == nil then
				rules[kind] = name
			end
		end
	end
end

-- The switch ---------------------------------------------------------------------------------------


-- Puts in use the profile of the rule for the place the character is in, with the call that picking by hand makes, and says so in one line.
-- In combat nothing changes: the switch is asked again when combat ends (InCombatLockdown, GlobalAPI.lua:6008).
local function Run()
	pending = false
	local name = Switch.Get(last)
	if not name or name == ns.Profile() then
		return
	end
	if InCombatLockdown() then
		pending = true
		return
	end
	if ns.UseProfile(name) then
		print(("Flat UI: Switched to %s."):format(name))
	end
end

function Switch.Entered(initialLogin, reloadingUi)
	-- A character with no rule asks the game nothing; the place is noted when the first rule is chosen.
	local rules = Rules(false)
	if not rules or next(rules) == nil then
		last = nil
		return
	end
	local kind = Switch.Kind()
	-- A login or a reload keeps the profile in use (FlatUICharDB.profile and profileOf restore it): the place is noted and nothing switches.
	if initialLogin or reloadingUi then
		last = kind
		return
	end
	-- Only a change of place switches, so a profile picked by hand stays through the loading screens of one place.
	if kind ~= last then
		last = kind
		Run()
	end
end

-- A profile picked by hand in a fight (Panel.lua's KeepProfile) wins over the rule's switch that waits for the fight's end.
function Switch.Drop()
	pending = false
end

-- A profile picked by hand in a fight, put in use as the fight ends; nil takes the wish back. Either way the rule's switch that waits is dropped.
function Switch.Keep(name)
	wanted = type(name) == "string" and name or nil
	pending = false
end

-- What waits for the fight's end: the profile and true when it is the rule's (Switch automatically), or nil when nothing waits.
function Switch.Wanted()
	if wanted then
		return wanted, false
	end
	if pending then
		local name = Switch.Get(last)
		if name and name ~= ns.Profile() then
			return name, true
		end
	end
	return nil
end

-- The options window shows the profile in use again, with the strip's line while it is open.
local function Shown(message)
	if type(ns.RefreshPanel) == "function" then
		pcall(ns.RefreshPanel)
	end
	local kit = ns.PanelKit
	if message and type(ns.PanelShown) == "function" and ns.PanelShown() and type(kit) == "table" and type(kit.Say) == "function" then
		pcall(kit.Say, message)
	end
end

-- A frame after the fight ends (InCombatLockdown may still say true as PLAYER_REGEN_ENABLED comes): the profile picked by hand, else the rule's.
-- A new fight in that frame keeps them for its end.
local function AfterFight()
	if InCombatLockdown() then
		return
	end
	local name = wanted
	if name then
		wanted, pending = nil, false
		local done, message = ns.UseProfile(name)
		if done then
			print(("Flat UI: using %s."):format(name))
		elseif type(message) == "string" then
			print("Flat UI: " .. message)
		end
		Shown(message)
	elseif pending then
		last = Switch.Kind()
		Run()
		Shown(nil)
	end
end

function Switch.CombatEnded()
	if not (wanted or pending) then
		return
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			local ok, err = pcall(AfterFight)
			if not ok then
				geterrorhandler()(err)
			end
		end)
	else
		AfterFight()
	end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	local call = event == "PLAYER_ENTERING_WORLD" and Switch.Entered or Switch.CombatEnded
	local ok, err = pcall(call, ...)
	if not ok then
		geterrorhandler()(err)
	end
end)
-- PLAYER_ENTERING_WORLD: SystemDocumentation.lua:133-141.
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")

-- The rows on the Profiles page ---------------------------------------------------------------------

-- Adds the section to the page below y with the widgets of ns.PanelKit (`kit`), puts a function that reads the rows again into `updates`,
-- and returns the y below the section. Each row's tip says what its choice does.
local TIP = "The profile this character switches to on entering such a place. No change keeps the profile in use. Picked for the place you are in, "
	.. "it asks to switch now."
-- Where the character is, by kind of place, in the question of a rule picked for the place the character is in.
local PLACE = { dungeon = "You are in a dungeon now.", raid = "You are in a raid now.", pvp = "You are in a battleground or arena now.",
	other = "You are outside dungeons, raids and battlegrounds now." }

-- A rule picked for the kind of place the character is in now asks to put its profile in use at once, since the switch itself waits for the next change
-- of place. Switch now uses the call that picking by hand makes, and in a fight it says that profiles change after combat.
local function Offer(kit, kind, name)
	if name == "" or kind ~= Switch.Kind() or name == ns.Profile() or type(kit.Ask) ~= "function" then
		return
	end
	kit.Ask(("%s Switch to %s now?"):format(PLACE[kind] or "", name), function()
		local _, message = ns.UseProfile(name)
		kit.Say(message)
		kit.Refresh()
	end, nil, "Switch now", "Later")
end

function Switch.Build(kit, child, y, updates)
	y = kit.Header(child, "Switch automatically", y)
	for _, entry in ipairs(Switch.KINDS) do
		local row = kit.NewRow(child, y, entry.label, TIP)
		local menu = kit.Dropdown(row, kit.FIELD, {
			lines = function()
				local lines = { { "", NONE } }
				for _, name in ipairs(ns.Profiles()) do
					lines[#lines + 1] = { name, name }
				end
				return lines
			end,
			selected = function()
				return Switch.Get(entry.key) or ""
			end,
			pick = function(name)
				local set = Switch.Set(entry.key, name ~= "" and name or nil)
				kit.Refresh()
				if set then
					Offer(kit, entry.key, name)
				end
			end,
		})
		menu.frame:SetPoint("LEFT", row.frame, "LEFT", kit.CONTROL, 0)
		updates[#updates + 1] = function()
			menu.SetText(Switch.Get(entry.key) or NONE)
		end
		y = y + kit.ROW
	end
	local note = kit.Dim(kit.Label(child, "GameFontHighlightSmall", "LEFT", kit.ROW_W))
	note:SetPoint("TOPLEFT", child, "TOPLEFT", kit.PAD, -(y + 4))
	note:SetText("Switches wait until the fight ends. A rule for the place you are in asks to switch now.")
	return y + kit.ROW
end
