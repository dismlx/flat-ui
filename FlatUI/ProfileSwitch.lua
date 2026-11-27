local ADDON_NAME, ns = ...

local Switch = {}
ns.ProfileSwitch = Switch

local NONE = "No change"
local last, pending, wanted
Switch.KINDS = {
	{ key = "dungeon", label = "In a dungeon" },
	{ key = "raid", label = "In a raid" },
	{ key = "pvp", label = "In a battleground or arena" },
	{ key = "other", label = "Everywhere else" },
}

local KIND_OF = { party = "dungeon", raid = "raid", pvp = "pvp", arena = "pvp" }

function Switch.Kind()
	local ok, inside, instanceType = pcall(IsInInstance)
	if ok and inside and type(instanceType) == "string" and not (issecretvalue and issecretvalue(instanceType)) then
		return KIND_OF[instanceType] or "other"
	end
	return "other"
end

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

function Switch.Deleted(old)
	Switch.Renamed(old, nil)
end

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
	local rules = Rules(false)
	if not rules or next(rules) == nil then
		last = nil
		return
	end
	local kind = Switch.Kind()
	if initialLogin or reloadingUi then
		last = kind
		return
	end
	if kind ~= last then
		last = kind
		Run()
	end
end

function Switch.Drop()
	pending = false
end

function Switch.Keep(name)
	wanted = type(name) == "string" and name or nil
	pending = false
end

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

local function Shown(message)
	if type(ns.RefreshPanel) == "function" then
		pcall(ns.RefreshPanel)
	end
	local kit = ns.PanelKit
	if message and type(ns.PanelShown) == "function" and ns.PanelShown() and type(kit) == "table" and type(kit.Say) == "function" then
		pcall(kit.Say, message)
	end
end

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
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")

local TIP = "The profile this character switches to on entering such a place. No change keeps the profile in use. Picked for the place you are in, "
	.. "it asks to switch now."
local PLACE = { dungeon = "You are in a dungeon now.", raid = "You are in a raid now.", pvp = "You are in a battleground or arena now.",
	other = "You are outside dungeons, raids and battlegrounds now." }

local function Offer(kit, kind, name)
	if name == "" or kind ~= Switch.Kind() or name == ns.Profile() or type(kit.Ask) ~= "function" then
		return
	end
	kit.Ask(("%s Switch to %s now?"):format(PLACE[kind] or "", name), function()
		if InCombatLockdown() then
			Switch.Keep(name)
			kit.Say(("Switches to %s when the fight ends."):format(name))
		else
			local _, message = ns.UseProfile(name)
			kit.Say(message)
		end
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
