local ADDON_NAME, ns = ...

-- Switch automatically: a profile for each kind of place, chosen on the Profiles page. The rules belong to the character, so they are saved in
-- FlatUIDB.profileRules under "Name - Realm" beside FlatUIDB.profileOf, outside every profile and outside the text form of a profile.
-- A rule with no profile is No change, which is what every character has until a rule is chosen.

local Switch = {}
ns.ProfileSwitch = Switch

local NONE = "No change"
local last, pending
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
	-- A login or a reload keeps the profile in use (profileOf restores it): the place is noted and nothing switches.
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

function Switch.CombatEnded()
	if pending then
		last = Switch.Kind()
		Run()
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
-- and returns the y below the section.
function Switch.Build(kit, child, y, updates)
	y = kit.Header(child, "Switch automatically", y)
	for _, entry in ipairs(Switch.KINDS) do
		local row = kit.NewRow(child, y, entry.label)
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
				Switch.Set(entry.key, name ~= "" and name or nil)
				kit.Refresh()
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
	note:SetText("Switches wait until the fight ends.")
	return y + kit.ROW
end
