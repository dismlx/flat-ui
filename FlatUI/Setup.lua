local _, ns = ...

-- Flat UI setup: a mode of the options window (Panel.lua gives it the window) that walks round the player's own screen, one stop for each part of
-- it (SetupStops.lua), then Your screen and Finish. SetupWalk.lua draws the cards of a stop and of Your screen in the body of the window; this file
-- has the window round them: the screen map and the list at the left, the title, the bar of buttons and the keys, the step pages of SetupSteps.lua
-- behind More settings and Every setting, the draft and Finish. Every choice goes into a draft kept for this character in FlatUIDB.setup.drafts.
-- Nothing reaches a profile, a game setting or a list before Finish: the drawings read the draft through ns.Viewing, and a list row queues its pick.
-- Finish saves the draft into the profile in use in one call (ns.ChangeProfile), or makes a profile of the character's own from it while the
-- character is on Default (ns.NewProfile), then closes the window so that the real screen shows the change. Enter and the arrow keys come through
-- a frame of Flat UI's own that has the keyboard only out of combat. Everything here is in the table S, so that the file keeps few locals.

local kit = ns.PanelKit
local STEPS = ns.SETUP_STEPS
local S = { views = {}, lines = {}, boxes = {}, showAll = {}, everyOpen = false, version = 0 }
ns.Setup = S

local COMBAT_LINE = "In combat. Finish after combat."
local NOT_FINISHED = "Flat UI setup is not finished. /flatui setup continues it."
-- A page has the drawing band under the title and its rows under the band; the bar of buttons is at the bottom of the column.
local DRAW_H, BAR_H = 220, 44
local PAGE_Y, PAGE_H = kit.HEADER + DRAW_H, 234 + kit.HEIGHT - 620
-- The left column: the screen map at the top and the list under it, whose lines are as high as their kind.
local MAP_W, MAP_H, LIST_Y = 186, 104, 122
local LINE_H = { stop = 36, yours = 24, every = 24, area = 20, step = 22, ready = 24 }
-- The body under the title, where SetupWalk.lua shows a stop or Your screen.
S.TOP, S.BODY_H = kit.HEADER, kit.HEIGHT - kit.TITLE - kit.STRIP - kit.HEADER - BAR_H

local function IsText(value)
	return not ns.IsSecret(value) and type(value) == "string"
end

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- What pcall gave: an error is said, not raised.
local function Reported(ok, ...)
	if not ok then
		geterrorhandler()((...))
		return nil
	end
	return ...
end

-- The built steps are the pages of More settings and Every setting, in order. Steps are numbered by their place in STEPS.
S.built, S.numberOf = {}, {}
for number, step in ipairs(STEPS) do
	if step.built then
		S.built[#S.built + 1] = number
		S.numberOf[step.id] = number
	end
end

-- Where each setting is: its step number and tier.
S.where = {}
for number, step in ipairs(STEPS) do
	for index, row in ipairs(step.rows) do
		S.where[row[1]] = { step = number, tier = row[2], index = index }
	end
end

-- The rows of Config.lua by saved path, and the page each is listed on.
function S.Defs()
	if not S.defs then
		S.defs, S.pageOf = {}, {}
		for _, page in ipairs(ns.PAGES) do
			for _, item in ipairs(page) do
				if item.path then
					S.defs[item.path] = item
					S.pageOf[item] = page
				end
			end
		end
	end
	return S.defs
end

-- The walk ---------------------------------------------------------------------------------------------

-- Calls a function of the walk (ns.SetupWalk, which SetupWalk.lua makes after this file loads) when it has one, and says an error it raises. Returns
-- what the function returned, or nil.
function S.Walk(name, ...)
	local walk = ns.SetupWalk
	local fn = type(walk) == "table" and walk[name] or nil
	if type(fn) ~= "function" then
		return nil
	end
	return Reported(pcall(fn, ...))
end

-- The stops of the walk as SetupWalk.lua checked them, or none while it is missing.
function S.Stops()
	local stops = S.Walk("Stops")
	return type(stops) == "table" and stops or {}
end

function S.Stop(id)
	local stop = S.Walk("Stop", id)
	return type(stop) == "table" and stop or nil
end

-- The place of a stop in the walk, or nil.
function S.StopIndex(id)
	for index, stop in ipairs(S.Stops()) do
		if stop.id == id then
			return index
		end
	end
	return nil
end

-- The screen of the stop at a place of the walk, or nil.
function S.StopScreen(index)
	local stop = S.Stops()[index]
	return stop and { kind = "stop", id = stop.id } or nil
end

-- The first screen of the walk: its first stop, or Your screen while the walk has none.
function S.FirstScreen()
	return S.StopScreen(1) or { kind = "yours" }
end

-- The built steps More settings opens from a stop, in order.
function S.Pages(stop)
	return type(stop) == "table" and type(stop.pages) == "table" and stop.pages or {}
end

-- The settings of setup itself --------------------------------------------------------------------

-- A saved "offer" of an older build: off becomes Default profile on a new character, and the old key goes.
function S.Migrate(store)
	if type(store) == "table" and store.offer ~= nil then
		if store.offer == false and store.newCharacter == nil then
			store.newCharacter = "default"
		end
		store.offer = nil
	end
end

-- Reads the settings of the Setup section of the Flat UI page, held per account (Config.lua names these functions). A choice that no longer
-- exists, such as a profile that was deleted, reads as nothing, so as the default.
function ns.SetupGet(def)
	local db = ns.Account()
	local store = type(db) == "table" and type(db.setup) == "table" and db.setup or nil
	S.Migrate(store)
	local value = store and store[def.key]
	if def.kind == "bool" and type(value) ~= "boolean" then
		return nil
	elseif def.kind == "choice" then
		return ns.Normalised("setup." .. def.key, value)
	end
	return value
end

-- The lines of Profile on a new character: the three ways to ask or skip, the ready-made profiles, then each saved profile that is not Default and
-- not named after a ready-made one (that name is the ready-made profile).
function ns.SetupNewChoices()
	local list = { { "ask", "Show the welcome screen" }, { "default", "Default profile" }, { "recommended", "Suggested profile" } }
	local named = {}
	for _, profile in ipairs(type(ns.SETUP_PROFILES) == "table" and ns.SETUP_PROFILES or {}) do
		list[#list + 1] = { "preset:" .. profile.id, profile.label }
		named[profile.label:lower()] = true
	end
	for _, name in ipairs(ns.Profiles()) do
		if name ~= "Default" and not named[name:lower()] then
			list[#list + 1] = { "profile:" .. name, name }
		end
	end
	return list
end

function ns.SetupSet(def, value)
	local store = S.Store(true)
	if store then
		store[def.key] = value
	end
end

-- The account table of setup, with its drafts. Without create it is nil when there is none yet.
function S.Store(create)
	local db = ns.Account()
	if type(db) ~= "table" then
		return nil
	end
	S.Migrate(db.setup)
	if type(db.setup) ~= "table" then
		if not create then
			return nil
		end
		db.setup = {}
	end
	if type(db.setup.drafts) ~= "table" then
		if not create then
			return nil
		end
		db.setup.drafts = {}
	end
	return db.setup
end

-- The draft -------------------------------------------------------------------------------------------

-- The key of this character's draft. A client that gives no character key uses "unknown".
function S.Key()
	return ns.CharacterKey() or "unknown"
end

function S.PlayerName()
	if type(UnitName) == "function" then
		local ok, name = pcall(UnitName, "player")
		if ok and IsText(name) and name ~= "" then
			return name
		end
	end
	return "My profile"
end

-- A name, or with " 2", " 3" and so on when a profile has it.
function S.FreeName(base)
	local name = base
	for number = 2, 99 do
		if ns.ProfileNameCheck(name) then
			return name
		end
		name = base .. " " .. number
	end
	return base
end

-- The character's name, free.
function S.DefaultName()
	return S.FreeName(S.PlayerName())
end

-- A new draft: over the profile in use, at the first stop, with nothing chosen. The name is for the profile Finish makes on Default.
function S.Fresh()
	local first = S.Stops()[1]
	return { v = 2, from = ns.Profile(), stop = first and first.id or "yours", seen = {}, values = {}, actions = {}, name = S.DefaultName(), saveNew = false }
end

-- A draft as the saved variables hold it, made safe: every value a setting can hold, every action a pick and a plain id, the stop one the walk has.
-- A draft of 0.5.11 or older keeps only its values and actions, which now change the profile in use.
local function CleanDraft(raw)
	if type(raw) ~= "table" then
		return nil
	end
	local draft = S.Fresh()
	if raw.v == 2 then
		draft.from = IsText(raw.from) and raw.from or draft.from
		if raw.stop == "yours" or (IsText(raw.stop) and S.Stop(raw.stop)) then
			draft.stop = raw.stop
		end
		for id, seen in pairs(type(raw.seen) == "table" and raw.seen or {}) do
			if seen == true and IsText(id) and S.Stop(id) then
				draft.seen[id] = true
			end
		end
		draft.name = IsText(raw.name) and raw.name or draft.name
		draft.saveNew = raw.saveNew == true
	end
	-- A pick of Out of range dimming from an older build is Out of range opacity, on the other scale.
	local picks = type(raw.values) == "table" and raw.values or {}
	if Number(picks["unitframes.partyRangeAlpha"]) and picks["unitframes.partyRangeOpacity"] == nil then
		local moved = {}
		for path, value in pairs(picks) do
			moved[path] = value
		end
		moved["unitframes.partyRangeOpacity"] = 100 - picks["unitframes.partyRangeAlpha"]
		picks = moved
	end
	-- A draft of an older build also holds ticks for rows that are choices now.
	local values = {}
	for path, value in pairs(picks) do
		values[path] = value
	end
	ns.MigrateText(values, values)
	if ns.MigrateSounds then
		ns.MigrateSounds(values, false)
	end
	-- White names never beat a Name colour the profile in use has.
	local start = S.StartProfile()
	local base = start and start.options
	if type(raw.values) == "table" and raw.values["unitframes.nameColour"] == nil and values["unitframes.nameColour"] == "white" and type(base) == "table"
		and base["unitframes.nameColour"] ~= nil and base["unitframes.nameColour"] ~= "game" then
		values["unitframes.nameColour"] = nil
	end
	for path, value in pairs(values) do
		if IsText(path) then
			local fitted = ns.Normalised(path, value)
			if fitted ~= nil then
				draft.values[path] = fitted
			end
		end
	end
	for _, action in ipairs(type(raw.actions) == "table" and raw.actions or {}) do
		if type(action) == "table" and IsText(action.pick) and (IsText(action.id) or Number(action.id)) then
			draft.actions[#draft.actions + 1] = { pick = action.pick, id = action.id, text = IsText(action.text) and action.text or nil }
		end
	end
	return draft
end

-- True when a draft has something worth keeping: a value or a queued action.
function S.Has(draft)
	return draft ~= nil and (next(draft.values) ~= nil or #draft.actions > 0)
end

-- This character's saved draft, cleaned and put back, or nil.
function S.Load()
	local store = S.Store(false)
	local draft = store and CleanDraft(store.drafts[S.Key()])
	if draft and S.Has(draft) then
		store.drafts[S.Key()] = draft
		return draft
	end
	return nil
end

-- True when this character has a saved draft. Writes nothing.
function S.Peek()
	local store = S.Store(false)
	local raw = store and store.drafts[S.Key()]
	local draft = raw ~= nil and CleanDraft(raw) or nil
	return S.Has(draft)
end

function ns.SetupHasDraft()
	return S.Peek()
end

-- Keeps the draft in the saved variables while it has something worth keeping, and takes it out when it has not.
function S.Sync()
	local draft = S.draft
	if not draft then
		return
	end
	if S.Has(draft) then
		local store = S.Store(true)
		if store then
			store.drafts[S.Key()] = draft
		end
	else
		local store = S.Store(false)
		if store and store.drafts[S.Key()] == draft then
			store.drafts[S.Key()] = nil
		end
	end
end

-- Takes the draft away for good.
function S.Drop()
	local store = S.Store(false)
	if store then
		store.drafts[S.Key()] = nil
	end
	S.draft = nil
end

-- A draft made over another profile than the one in use now changes the one in use, and the values that profile has already go. Returns the line
-- that says so while values remain, else nil.
function S.Rebase()
	local draft = S.draft
	local using = ns.Profile()
	if draft.from == using then
		return nil
	end
	draft.from = using
	S.Prune()
	S.Sync()
	if next(draft.values) ~= nil then
		return ("Setup now changes |cffffffff%s|r, the profile in use."):format(using)
	end
	return nil
end

-- True when Finish makes a new profile: on Default, which stays as it is for the other characters, or with Save as a new profile ticked.
function S.SavesNew()
	return ns.Profile() == "Default" or (S.draft ~= nil and S.draft.saveNew == true)
end

-- How many characters of the account use the profile `name`.
function S.Users(name)
	local db = ns.Account()
	local count = 0
	for _, used in pairs(type(db) == "table" and type(db.profileOf) == "table" and db.profileOf or {}) do
		if used == name then
			count = count + 1
		end
	end
	return count
end

-- The name of the profile Finish makes, or nil and the sentence why it cannot have it.
function S.NameCheck()
	local clean, why = ns.ProfileNameCheck(S.draft and S.draft.name or "")
	return clean, why
end

-- The views ------------------------------------------------------------------------------------------

-- The profile the draft changes: the profile in use. Finish saves into it, or into a copy of it.
function S.StartProfile()
	local db = ns.Account()
	return type(db) == "table" and type(db.profiles) == "table" and db.profiles[ns.Profile()] or nil
end

S.noSpots = {}

-- What a drawing reads: the draft, else the profile in use, else the row's default. Its spots are the positions of the profile in use.
S.view = setmetatable({ spots = S.noSpots }, { __index = function(_, path)
	local drafted = S.draft and S.draft.values[path]
	if drafted ~= nil then
		return drafted
	end
	local start = S.StartProfile()
	return start and start.options[path]
end })

-- The same without the draft: what the profile in use has now.
S.startView = setmetatable({ spots = S.noSpots }, { __index = function(_, path)
	local start = S.StartProfile()
	return start and start.options[path]
end })

-- Runs fn(...) with ns.Get reading `view`, and says an error it raised. Returns what fn returned.
function S.Under(view, fn, ...)
	local start = S.StartProfile()
	rawset(view, "spots", start and start.movers or S.noSpots)
	return Reported(ns.Viewing(view, fn, ...))
end

-- The value of a setting in the draft: a draft value, else what the profile in use has.
function S.Value(path)
	return S.Under(S.view, ns.Get, path)
end

function S.StartValue(path)
	return S.Under(S.startView, ns.Get, path)
end

-- Gives a setting a value in the draft. A value the profile in use has is not kept, so a card picked back, Back and a change back leave nothing
-- behind. Nothing is written to a profile, a game setting or a list.
function S.Set(path, value)
	local draft = S.draft
	if not draft then
		return
	end
	local fitted = ns.Normalised(path, value)
	if fitted == nil then
		return
	end
	if fitted == S.StartValue(path) then
		draft.values[path] = nil
	else
		draft.values[path] = fitted
	end
	S.dirty = true
	S.version = S.version + 1
	S.Sync()
end

-- A draft over another profile in use keeps every choice made, except those that profile has already.
function S.Prune()
	local draft = S.draft
	for path, value in pairs(draft.values) do
		if value == S.StartValue(path) then
			draft.values[path] = nil
		end
	end
	S.version = S.version + 1
end

-- The choices that differ from the profile in use, in step order: { path, step, tier, value }.
function S.Changes()
	local list = {}
	for path, value in pairs(S.draft and S.draft.values or {}) do
		local place = S.where[path]
		list[#list + 1] = { path = path, step = place and place.step or 0, tier = place and place.tier or "o", index = place and place.index or 0, value = value }
	end
	table.sort(list, function(a, b)
		if a.step ~= b.step then
			return a.step < b.step
		elseif a.index ~= b.index then
			return a.index < b.index
		end
		return a.path < b.path
	end)
	return list
end

-- The rows that need a reload, by the reload field of their row in Config.lua: "off" for a switch that takes full effect after /reload when it is turned
-- off, "change" for a row that applies after /reload when its value changes. An entry { label, field } for each one that is on now and off in the
-- draft ("off"), or that has another value there ("change").
function S.ReloadLines()
	local lines = {}
	for _, page in ipairs(ns.PAGES) do
		for _, item in ipairs(page) do
			if item.path and item.reload and IsText(item.label) and not ns.RowUnsaved(item) then
				local now, later = ns.Get(item.path), S.Value(item.path)
				if item.reload == "off" and now == true and later == false or item.reload == "change" and now ~= later then
					lines[#lines + 1] = { item.label, item.reload }
				end
			end
		end
	end
	return lines
end

-- The sentence of an entry of S.ReloadLines.
function S.ReloadText(entry)
	if entry[2] == "change" then
		return ("|cffffffff%s|r applies after /reload."):format(entry[1])
	end
	return ("Turning off |cffffffff%s|r takes full effect after /reload."):format(entry[1])
end

-- Lists, at Finish ------------------------------------------------------------------------------------

-- Queues a pick for Finish: `pick` names the function of ns that a list row or a tick of the walk calls, `id` the line chosen and `text` what the
-- player reads of it. The same pick and id are queued once. Nothing runs before Finish.
function S.Queue(pick, id, text)
	local draft = S.draft
	if not draft or not IsText(pick) or not (IsText(id) or Number(id)) then
		return
	end
	if not S.Queued(pick, id) then
		draft.actions[#draft.actions + 1] = { pick = pick, id = id, text = IsText(text) and text or nil }
		S.version = S.version + 1
		S.Sync()
	end
	if IsText(text) then
		kit.Say(("At Finish: %s."):format(text))
	end
end

function S.Unqueue(pick, id)
	local draft = S.draft
	if not draft then
		return
	end
	for index = #draft.actions, 1, -1 do
		if draft.actions[index].pick == pick and draft.actions[index].id == id then
			table.remove(draft.actions, index)
		end
	end
	S.version = S.version + 1
	S.Sync()
end

function S.Queued(pick, id)
	for _, action in ipairs(S.draft and S.draft.actions or {}) do
		if action.pick == pick and action.id == id then
			return true
		end
	end
	return false
end

-- What a pick of a list row reads as: "<row label>: <the line chosen>", or the label alone when its lines do not have the id.
function S.ListText(def, id)
	local call = ns[def.items]
	if type(call) == "function" then
		local ok, lines = pcall(call)
		for _, line in ipairs(ok and type(lines) == "table" and lines or {}) do
			if type(line) == "table" and line[1] == id and IsText(line[2]) then
				return ("%s: %s"):format(def.label, line[2])
			end
		end
	end
	return def.label
end

-- Rows ---------------------------------------------------------------------------------------------

-- A copy of a row of Config.lua that reads and writes the draft: it has no saved path, so the row builders never touch a profile. A list row queues
-- its pick for Finish (Panel.lua calls item.act in place of the pick), and a row the step only describes ("behaviour") that has no tip of its own
-- takes the step's sentence as its tip.
function S.Item(def, entry)
	local path = def.path
	local item = {}
	for field, value in pairs(def) do
		item[field] = value
	end
	item.path = nil
	item.read = function()
		return S.Value(path)
	end
	item.write = function(value)
		S.Set(path, value)
	end
	if IsText(def.tip) and def.tip ~= "" then
		-- Inside setup the profiles are in front of the player already.
		item.tip = def.tip:gsub(" Profiles are in the options window%.$", "")
	elseif type(entry) == "table" and entry[3] == "behaviour" and IsText(entry[4]) then
		item.tip = entry[4]
	end
	if def.kind == "list" and IsText(def.pick) then
		item.act = function(id)
			S.Queue(def.pick, id, S.ListText(def, id))
		end
	end
	return item
end

-- The rows of a step, built the first time its page is shown: { row, item, page, tier, path }.
function S.BuildRows(number, scroller)
	local defs = S.Defs()
	local rows = {}
	for _, entry in ipairs(STEPS[number].rows) do
		local def = defs[entry[1]]
		if def and ns.RowShown(def.path) then
			local item = S.Item(def, entry)
			local page = S.pageOf[def]
			local row = kit.BuildRow(scroller.child, page, item, 8)
			if row then
				-- Hovering the row marks the part of the drawing the setting changes.
				row.entered = function()
					ns.SetupDraw.Mark(def.path)
				end
				row.left = function()
					ns.SetupDraw.Mark(nil)
				end
				rows[#rows + 1] = { row = row, item = item, page = page, tier = entry[2], path = def.path }
			end
		end
	end
	return rows
end

-- The rows of the page that show now: open (every setting they need is on), and the main ones, or all of them with Show all. Run under the view.
function S.Shown(view)
	local all = S.showAll[view.step] == true
	local shown, more = {}, 0
	for _, entry in ipairs(view.rows) do
		if kit.IsOpen(entry.page, entry.item) then
			if entry.tier ~= "c" then
				more = more + 1
			end
			if all or entry.tier == "c" then
				shown[#shown + 1] = entry
			end
		end
	end
	return shown, more
end

-- Puts the rows that show in a column and hides the rest. Show all counts every open row of the page.
function S.LayoutStep(view)
	local shown, more = S.Shown(view)
	local y = 8
	local on = {}
	for _, entry in ipairs(shown) do
		on[entry] = true
		entry.row.Place(y)
		entry.row.frame:Show()
		y = y + kit.ROW
	end
	for _, entry in ipairs(view.rows) do
		if not on[entry] then
			entry.row.frame:Hide()
		end
	end
	local all = S.showAll[view.step] == true
	view.more:SetShown(more > 0)
	if more > 0 then
		view.moreText:SetText(all and "Show fewer" or ("Show all (%d)"):format(#shown + more))
		view.more:ClearAllPoints()
		view.more:SetPoint("TOPLEFT", view.scroller.child, "TOPLEFT", kit.PAD, -(y + 6))
		y = y + 40
	end
	view.scroller.SetContent(y + kit.PAD)
	view.sig = S.Signature(view, shown, more)
end

function S.Signature(view, shown, more)
	local parts = { S.showAll[view.step] and "all" or "main", tostring(more) }
	for _, entry in ipairs(shown) do
		parts[#parts + 1] = entry.path
	end
	return table.concat(parts, ",")
end

function S.StepView(number)
	local view = S.views[number]
	if view then
		return view
	end
	local scroller = kit.Scroller(S.right, kit.RIGHT_W, PAGE_H)
	scroller.frame:SetPoint("TOPLEFT", S.right, "TOPLEFT", 0, -PAGE_Y)
	view = { scroller = scroller, step = number }
	view.rows = S.BuildRows(number, scroller)
	-- Show all and Show fewer are for this page, while the window is open.
	local more, text = kit.Button(scroller.child, "Show all", 150, function()
		S.showAll[number] = not S.showAll[number] or nil
		kit.Refresh()
	end)
	view.more, view.moreText = more, text
	more:Hide()
	scroller.frame:Hide()
	S.views[number] = view
	return view
end

-- The text under the page title: a module that is off ("Off. Turn on Unit frames for more choices."); else the switches that closed rows wait for,
-- the first each row waits for and at most two ("Turn on Flat UI portraits for more choices."); and a line when the page has rows the game holds.
-- Run under the view.
function S.Subtitle(view)
	local lines = {}
	local defs = S.Defs()
	local off, waits, named = nil, {}, {}
	for _, entry in ipairs(view.rows) do
		if not kit.IsOpen(entry.page, entry.item) then
			for _, needed in ipairs(S.Gates(entry)) do
				if not off and needed:find("%.enabled$") and ns.Get(needed) ~= true then
					off = defs[needed]
				end
			end
			-- Only a switch is turned on: a row that waits for a choice is not named.
			local unmet = kit.Unmet(entry.page, entry.item)
			local def = unmet and defs[unmet]
			if def and def.kind == "bool" and IsText(def.label) and not named[unmet] and #waits < 2 then
				named[unmet] = true
				waits[#waits + 1] = ("|cffffffff%s|r"):format(def.label)
			end
		end
	end
	if off then
		lines[#lines + 1] = ("Off. Turn on |cffffffff%s|r for more choices."):format(off.label)
	elseif #waits > 0 then
		lines[#lines + 1] = ("Turn on %s for more choices."):format(table.concat(waits, " or "))
	end
	for _, entry in ipairs(view.rows) do
		if entry.item.cvar then
			lines[#lines + 1] = "Game settings. They apply to every profile."
			break
		end
	end
	return table.concat(lines, " ")
end

-- The settings a row needs, from the first it names to the switch of its page.
function S.Gates(entry)
	local list = {}
	local item, page = entry.item, entry.page
	local owner = page.owner or page.switch or page.key
	local switch = ns.RowLive(item) and "" or owner
	local path = item.needsPath
	if not path and switch ~= "" and owner ~= "general" and item.key ~= "enabled" then
		path = switch .. ".enabled"
	end
	while path and #list < 8 do
		list[#list + 1] = path
		path = ns.Needs(path)
		if not path and switch ~= "" and owner ~= "general" and list[#list] ~= switch .. ".enabled" then
			path = switch .. ".enabled"
		end
	end
	return list
end

-- Screens ---------------------------------------------------------------------------------------------
-- A screen is { kind = "stop", id }, { kind = "yours" } (Your screen) or { kind = "page", number, list, back }: a built step, the steps Next and
-- Back go through, and the stop or Your screen Done goes back to.

-- The text of the counter in the title bar: "2 of 6" on a stop, Your screen, or the area of the page shown.
function S.Counter()
	local screen = S.screen
	if not screen then
		return ""
	elseif screen.kind == "stop" then
		local at = S.StopIndex(screen.id)
		return at and ("%d of %d"):format(at, #S.Stops()) or ""
	elseif screen.kind == "yours" then
		return "Your screen"
	end
	return STEPS[screen.number].area or ""
end

-- The page of a built step reached from Every setting or a search: every built step for Next and Back, and Done back to the stop or Your screen
-- last shown.
function S.PageOf(number)
	return { kind = "page", number = number, list = S.built, back = S.walkAt or S.FirstScreen() }
end

-- The screen an id opens: "yours" is Your screen, a built step its page, a stop its stop. The id "bars" names both a step and a stop: it is the step,
-- as a search hit means it.
function S.ScreenOf(id)
	if id == "yours" then
		return { kind = "yours" }
	elseif not IsText(id) then
		return nil
	elseif S.numberOf[id] then
		return S.PageOf(S.numberOf[id])
	end
	return S.StopIndex(id) and { kind = "stop", id = id } or nil
end

-- Where setup opens: the stop or Your screen the draft was last at, else the first stop.
function S.Opening()
	local at = S.draft and S.draft.stop
	if at == "yours" then
		return { kind = "yours" }
	end
	return IsText(at) and S.StopIndex(at) and { kind = "stop", id = at } or S.FirstScreen()
end

-- Opens a screen. A stop or Your screen is where the draft opens next time; a page is not remembered.
function S.Go(screen)
	local draft = S.draft
	if not draft or type(screen) ~= "table" then
		return
	elseif screen.kind == "page" and not (STEPS[screen.number] and STEPS[screen.number].built) then
		return
	elseif screen.kind == "stop" and not S.StopIndex(screen.id) then
		return
	end
	if screen.kind ~= "page" then
		S.walkAt = screen
		draft.stop = screen.kind == "yours" and "yours" or screen.id
		S.Sync()
	end
	S.screen = screen
	ns.SetupDraw.Mark(nil)
	S.Show()
end

-- The place of the page shown in the pages it goes through, or nil.
function S.PageIndex(screen)
	for index, number in ipairs(screen.list or {}) do
		if number == screen.number then
			return index
		end
	end
	return nil
end

-- Next: the next stop, and Your screen after the last; on a page the next page, and after the last the screen the pages came from.
function S.Next()
	local screen = S.screen
	if not screen then
		return
	elseif screen.kind == "stop" then
		S.Go(S.StopScreen((S.StopIndex(screen.id) or 0) + 1) or { kind = "yours" })
	elseif screen.kind == "page" then
		local at = S.PageIndex(screen)
		local number = at and screen.list[at + 1]
		if number then
			S.Go({ kind = "page", number = number, list = screen.list, back = screen.back })
		else
			S.Go(screen.back or S.FirstScreen())
		end
	end
end

-- Back: the stop before, the last stop from Your screen; on a page the page before, and from the first the screen the pages came from.
function S.Back()
	local screen = S.screen
	if not screen then
		return
	elseif screen.kind == "stop" then
		local before = S.StopScreen((S.StopIndex(screen.id) or 1) - 1)
		if before then
			S.Go(before)
		end
	elseif screen.kind == "yours" then
		local last = S.StopScreen(#S.Stops())
		if last then
			S.Go(last)
		end
	else
		local at = S.PageIndex(screen)
		local number = at and at > 1 and screen.list[at - 1]
		if number then
			S.Go({ kind = "page", number = number, list = screen.list, back = screen.back })
		else
			S.Go(screen.back or S.FirstScreen())
		end
	end
end

-- The button Enter presses: Finish on Your screen, else Next.
function S.Primary()
	if S.screen and S.screen.kind == "yours" then
		S.Finish()
	else
		S.Next()
	end
end

-- The button left of the primary one: Skip the rest on a stop (stops not visited stay as they are), Start over on Your screen, Done on a page.
function S.Second()
	local screen = S.screen
	if not screen then
		return
	elseif screen.kind == "stop" then
		S.Go({ kind = "yours" })
	elseif screen.kind == "yours" then
		S.StartOver()
	else
		S.Go(screen.back or S.FirstScreen())
	end
end

-- More settings: the pages of the stop shown, from the first, with Done back to the stop.
function S.More()
	local screen = S.screen
	local pages = screen and screen.kind == "stop" and S.Pages(S.Stop(screen.id)) or {}
	if pages[1] then
		S.Go({ kind = "page", number = pages[1], list = pages, back = screen })
	end
end

-- Asks a question in the window. Enter does nothing while it shows, so that it is not taken for an answer.
function S.Question(question, onYes, onNo, yesText, noText)
	S.asking = true
	kit.Ask(question, function()
		S.asking = false
		if onYes then
			onYes()
		end
	end, function()
		S.asking = false
		if onNo then
			onNo()
		end
	end, yesText, noText)
end

-- Start over: every choice goes, and the walk starts again at its first stop.
function S.Reset()
	S.Drop()
	S.draft = S.Fresh()
	S.Walk("Begin")
	S.Go(S.FirstScreen())
end

-- Start over on Your screen asks first when there is something to lose.
function S.StartOver()
	if S.Has(S.draft) then
		S.Question("Start over. Every choice made here goes.", S.Reset, nil, "Start over", "Keep choices")
	else
		S.Reset()
	end
end

-- The list and the map ------------------------------------------------------------------------------

-- The lines of the list: the stops, Your screen, Every setting (with the areas and the pages under it while it is open) and Ready-made looks.
function S.Entries()
	local list = {}
	for index, stop in ipairs(S.Stops()) do
		list[#list + 1] = { kind = "stop", key = "stop:" .. stop.id, id = stop.id, number = index, text = stop.title }
	end
	list[#list + 1] = { kind = "yours", key = "yours", text = "Your screen" }
	list[#list + 1] = { kind = "every", text = "Every setting", gap = 8 }
	if S.everyOpen then
		local last
		for _, number in ipairs(S.built) do
			local step = STEPS[number]
			if step.area ~= last then
				last = step.area
				list[#list + 1] = { kind = "area", text = step.area }
			end
			list[#list + 1] = { kind = "step", key = "step:" .. number, number = number, text = step.title }
		end
	end
	if type(ns.OpenProfiles) == "function" then
		list[#list + 1] = { kind = "ready", text = "Ready-made looks" }
	end
	return list
end

-- The key of a screen's own line.
function S.KeyOf(screen)
	if not screen then
		return nil
	elseif screen.kind == "stop" then
		return "stop:" .. screen.id
	elseif screen.kind == "yours" then
		return "yours"
	end
	return "step:" .. screen.number
end

-- The line that is current: the screen's own, or for a page while Every setting is shut, the stop or Your screen it came from.
function S.CurrentKey()
	local screen = S.screen
	if screen and screen.kind == "page" and not S.everyOpen then
		screen = screen.back
	end
	return S.KeyOf(screen)
end

-- A line of the list, made the first time it is needed. A line shows any kind of entry; the parts its kind does not use are hidden.
function S.ListLine(index)
	local line = S.lines[index]
	if line then
		return line
	end
	local frame = kit.Frame(S.listScroller.child)
	frame:SetWidth(kit.LEFT - 1)
	local fill = kit.Fill(frame, "BACKGROUND")
	fill:SetAllPoints(frame)
	local mark = kit.Fill(frame, "ARTWORK")
	mark:SetWidth(2)
	mark:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	mark:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	-- A stop has its number in a square, filled once the stop has been seen.
	local square = kit.Fill(frame, "BORDER")
	square:SetSize(16, 16)
	square:SetPoint("LEFT", frame, "LEFT", 12, 0)
	local inside = kit.Fill(frame, "ARTWORK")
	inside:SetSize(14, 14)
	inside:SetPoint("CENTER", square, "CENTER", 0, 0)
	-- A page has the small square the list of steps always had.
	local box = kit.Fill(frame, "ARTWORK")
	box:SetSize(8, 8)
	box:SetPoint("LEFT", frame, "LEFT", 14, 0)
	local inner = kit.Fill(frame, "OVERLAY")
	inner:SetSize(6, 6)
	inner:SetPoint("CENTER", box, "CENTER", 0, 0)
	-- Every setting has a chevron of four short bars: pointing down while it is open, right while it is shut.
	local chevron = {}
	for bar = 1, 4 do
		chevron[bar] = kit.Fill(frame, "ARTWORK")
	end
	line = {
		frame = frame,
		digit = kit.Label(frame, "GameFontHighlightSmall", "CENTER", 16),
		text = kit.Label(frame, "GameFontHighlight", "LEFT", kit.LEFT - 50),
		head = kit.Tint(kit.Label(frame, "GameFontHighlightSmall", "LEFT", kit.LEFT - 50), "text-faint"),
		summary = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", 160)),
	}
	line.digit:SetPoint("CENTER", square, "CENTER", 0, 0)
	line.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 36, -20)
	local function Paint()
		local kind = line.kind
		fill:SetShown(line.current == true or line.hover == true)
		kit.Solid(fill, line.current and 0.1 or 0.06)
		mark:SetShown(line.current == true)
		mark:SetColorTexture(kit.Accent())
		square:SetShown(kind == "stop")
		inside:SetShown(kind == "stop")
		line.digit:SetShown(kind == "stop")
		kit.Solid(square, "line-strong")
		kit.Solid(inside, line.seen and "line-strong" or "stage")
		line.digit:SetTextColor(kit.Shade(line.seen and "text" or "text-dim"))
		box:SetShown(kind == "step")
		inner:SetShown(kind == "step")
		kit.Solid(box, "line-strong")
		kit.Solid(inner, "stage")
		for bar, texture in ipairs(chevron) do
			texture:SetShown(kind == "every")
			texture:ClearAllPoints()
			if S.everyOpen then
				texture:SetSize(10 - 2 * bar, 1.5)
				texture:SetPoint("TOP", frame, "TOPRIGHT", -20, -(9 + (bar - 1) * 1.5))
			else
				texture:SetSize(1.5, 10 - 2 * bar)
				texture:SetPoint("LEFT", frame, "TOPRIGHT", -24 + (bar - 1) * 1.5, -12)
			end
			texture:SetColorTexture(kit.Shade("text-dim"))
		end
		if line.current then
			line.text:SetTextColor(kit.Accent())
		else
			line.text:SetTextColor(kit.Shade("text"))
		end
	end
	line.Paint = Paint
	kit.Painted(Paint)
	frame:SetScript("OnEnter", function()
		line.hover = line.kind ~= nil and line.kind ~= "area"
		Paint()
	end)
	frame:SetScript("OnLeave", function()
		line.hover = false
		Paint()
	end)
	kit.Clickable(frame, function()
		S.PickLine(line)
	end)
	S.lines[index] = line
	return line
end

-- A click on a line of the list. The line of the screen shown does nothing.
function S.PickLine(line)
	local kind = line.kind
	if kind == "every" then
		S.everyOpen = not S.everyOpen
		S.LayoutList()
	elseif kind == "ready" then
		if type(ns.OpenProfiles) == "function" then
			Reported(pcall(ns.OpenProfiles))
		end
	elseif line.key == nil or line.key == S.KeyOf(S.screen) then
		return
	elseif kind == "stop" then
		S.Go({ kind = "stop", id = line.id })
	elseif kind == "yours" then
		S.Go({ kind = "yours" })
	elseif kind == "step" then
		S.Go(S.PageOf(line.number))
	end
end

-- Lays the list out, then keeps the current line in view: when it is not, the list scrolls so that it is three lines from the top.
function S.LayoutList()
	local scroller = S.listScroller
	if not scroller then
		return
	end
	S.LayoutMap()
	local entries = S.Entries()
	local current = S.CurrentKey()
	local tops, at = {}, nil
	local y = 4
	for index, entry in ipairs(entries) do
		y = y + (entry.gap or 0)
		local line = S.ListLine(index)
		local kind = entry.kind
		line.kind, line.key, line.id, line.number = kind, entry.key, entry.id, entry.number
		line.text:SetShown(kind ~= "area")
		line.head:SetShown(kind == "area")
		local label = kind == "area" and line.head or line.text
		label:SetText(entry.text)
		label:ClearAllPoints()
		if kind == "stop" then
			label:SetPoint("TOPLEFT", line.frame, "TOPLEFT", 36, -4)
		else
			label:SetPoint("LEFT", line.frame, "LEFT", kind == "step" and 30 or 12, 0)
		end
		line.summary:SetShown(kind == "stop")
		line.digit:SetText(entry.number and kind == "stop" and tostring(entry.number) or "")
		line.frame:SetHeight(LINE_H[kind])
		line.frame:ClearAllPoints()
		line.frame:SetPoint("TOPLEFT", scroller.child, "TOPLEFT", 0, -y)
		line.frame:Show()
		tops[index] = y
		if entry.key ~= nil and entry.key == current then
			at = index
		end
		y = y + LINE_H[kind]
	end
	for index = #entries + 1, #S.lines do
		local line = S.lines[index]
		line.frame:Hide()
		line.kind, line.key, line.hover = nil, nil, false
	end
	scroller.SetContent(y + 8)
	if at and (tops[at] < scroller.offset or tops[at] + LINE_H[entries[at].kind] > scroller.offset + scroller.height) then
		scroller.Scroll(tops[math.max(1, at - 3)] - 4)
	end
	S.ReadList(true)
end

-- Reads the list and the map again: the current line, the stops seen, the stops the draft changed and, after a change of the draft or of the
-- profile in use, what each stop has picked. A line is painted again when one of these changed, or every line with `force` (after a layout).
function S.ReadList(force)
	local current = S.CurrentKey()
	local seen = S.draft and S.draft.seen or {}
	local stamp = S.version .. "|" .. tostring(ns.Profile())
	local summed = force or S.summed ~= stamp
	S.summed = stamp
	for _, line in ipairs(S.lines) do
		if line.kind then
			local now, saw = line.key ~= nil and line.key == current, line.kind == "stop" and seen[line.id] == true
			if force or now ~= line.current or saw ~= line.seen then
				line.current, line.seen = now, saw
				line.Paint()
			end
			if summed and line.kind == "stop" then
				local summary = S.Walk("Summary", line.id)
				line.summary:SetText(IsText(summary) and summary or "")
			end
		end
	end
	S.ReadMap(force)
end

-- The screen map: the screen drawn small, with a box for each stop where that part of the screen is, numbered as the list is. The box of the stop
-- shown is in the accent, a stop the draft changed has a dot, and a click on a box opens its stop.
function S.BuildMap(left)
	local map = kit.Frame(left)
	map:SetSize(MAP_W, MAP_H)
	map:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -10)
	local edge = kit.Fill(map, "BACKGROUND")
	edge:SetAllPoints(map)
	local floor = kit.Fill(map, "BORDER")
	floor:SetPoint("TOPLEFT", map, "TOPLEFT", 1, -1)
	floor:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -1, 1)
	kit.Painted(function()
		kit.Solid(edge, "line")
		kit.Solid(floor, "stage")
	end)
	S.map = map
end

-- A box of the map, made the first time it is needed.
function S.MapBox(index)
	local box = S.boxes[index]
	if box then
		return box
	end
	local frame = kit.Frame(S.map)
	local edge = kit.Fill(frame, "BORDER")
	edge:SetAllPoints(frame)
	local fill = kit.Fill(frame, "ARTWORK")
	fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	local dot = kit.Fill(frame, "OVERLAY")
	dot:SetSize(4, 4)
	dot:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
	box = { frame = frame, digit = kit.Label(frame, "GameFontHighlightSmall", "CENTER") }
	box.digit:SetPoint("CENTER", frame, "CENTER", 0, 0)
	function box.Paint()
		kit.Solid(edge, "line")
		kit.Solid(fill, box.current and "accent" or "raised")
		box.digit:SetTextColor(kit.Shade(box.current and "on-accent" or "text"))
		dot:SetShown(box.changed == true)
		-- On the box in the accent the dot takes the colour of text on the accent, so that it still shows.
		kit.Solid(dot, box.current and "on-accent" or "accent")
	end
	kit.Painted(box.Paint)
	kit.Clickable(frame, function()
		if box.id and S.KeyOf(S.screen) ~= "stop:" .. box.id then
			S.Go({ kind = "stop", id = box.id })
		end
	end)
	S.boxes[index] = box
	return box
end

-- Places a box for each stop that has a spot: left, top, width and height as shares of the screen.
function S.LayoutMap()
	if not S.map then
		return
	end
	local used = 0
	for index, stop in ipairs(S.Stops()) do
		local spot = stop.spot
		if type(spot) == "table" and Number(spot[1]) and Number(spot[2]) and Number(spot[3]) and Number(spot[4]) then
			used = used + 1
			local box = S.MapBox(used)
			box.id = stop.id
			box.frame:ClearAllPoints()
			box.frame:SetPoint("TOPLEFT", S.map, "TOPLEFT", spot[1] * MAP_W, -spot[2] * MAP_H)
			box.frame:SetSize(math.max(4, spot[3] * MAP_W), math.max(4, spot[4] * MAP_H))
			box.digit:SetText(tostring(index))
			box.frame:Show()
		end
	end
	for index = used + 1, #S.boxes do
		S.boxes[index].id = nil
		S.boxes[index].frame:Hide()
	end
end

-- Reads the boxes of the map again: the stop shown (or the stop a page came from) and the stops the draft changed. A box is painted again when one
-- of these changed, or every box with `force`.
function S.ReadMap(force)
	local screen = S.screen
	if screen and screen.kind == "page" then
		screen = screen.back
	end
	for _, box in ipairs(S.boxes) do
		if box.id then
			local now, changed = screen ~= nil and screen.kind == "stop" and screen.id == box.id, S.Walk("Changed", box.id) == true
			if force or now ~= box.current or changed ~= box.changed then
				box.current, box.changed = now, changed
				box.Paint()
			end
		end
	end
end

-- The bar and the page drawing ------------------------------------------------------------------------

-- The bar: Back at the left; at the right the primary button and up to two more, relabelled for the screen shown. On a stop Next, Skip the rest
-- (not on the last) and More settings (when the stop has pages); on Your screen Finish (dim in combat or while the name is refused) and Start over;
-- on a page Next and Done.
function S.Buttons()
	local screen = S.screen
	if not screen or not S.next then
		return
	end
	local back, primary, first, second
	if screen.kind == "stop" then
		local at = S.StopIndex(screen.id) or 1
		back, primary = at > 1, "Next"
		first = at < #S.Stops() and "Skip the rest" or nil
		second = #S.Pages(S.Stop(screen.id)) > 0 and "More settings" or nil
	elseif screen.kind == "yours" then
		back, primary, first = #S.Stops() > 0, "Finish", "Start over"
	else
		back, primary, first = true, "Next", "Done"
	end
	S.back:SetShown(back)
	S.nextText:SetText(primary)
	S.mid1:SetShown(first ~= nil)
	S.mid1Text:SetText(first or "")
	S.mid2:SetShown(second ~= nil)
	S.mid2Text:SetText(second or "")
	S.mid2:ClearAllPoints()
	S.mid2:SetPoint("RIGHT", first and S.mid1 or S.next, "LEFT", -8, 0)
	local blocked = screen.kind == "yours" and (InCombatLockdown() or (S.SavesNew() and not S.NameCheck()))
	S.next:SetAlpha(blocked and 0.4 or 1)
end

-- Paints the drawing of the page shown, under the draft. SetupWalk.lua paints the cards of a stop and the pictures of Your screen.
function S.Redraw()
	local screen = S.screen
	if S.draft and screen and screen.kind == "page" then
		ns.SetupDraw.Show(STEPS[screen.number].draw)
		S.Under(S.view, ns.SetupDraw.Paint)
	end
end

-- Finish -----------------------------------------------------------------------------------------------

local function Count(number, one, many)
	return ("%d %s"):format(number, number == 1 and one or many)
end

-- The counts of a result in one clause: "16 settings, 2 game settings, 1 kept by the game".
function S.Totals(result)
	local parts = { Count(result.settings, "setting", "settings") }
	if result.game > 0 then
		parts[#parts + 1] = Count(result.game, "game setting", "game settings")
	end
	if #result.kept > 0 then
		parts[#parts + 1] = ("%d kept by the game"):format(#result.kept)
	end
	return table.concat(parts, ", ")
end

-- The lines of /flatui status for the last setup of this character, while its profile exists. Core.lua adds them. A result of 0.5.11 has the same
-- fields and reads the same.
function ns.SetupStatus()
	local character = ns.Character()
	local result = type(character) == "table" and character.setupResult
	if type(result) ~= "table" or not IsText(result.name) or not Number(result.settings) or not Number(result.game) or type(result.kept) ~= "table" then
		return {}
	end
	local found = false
	for _, name in ipairs(ns.Profiles()) do
		found = found or name == result.name
	end
	if not found then
		return {}
	end
	local lines = { ("Setup: %s, %s."):format(result.name, S.Totals(result)) }
	local defs = S.Defs()
	for index, text in ipairs(result.kept) do
		-- The setting is read again: a line whose setting now holds the pick is left out. A value that cannot be read keeps its line.
		local at = type(result.keptAt) == "table" and result.keptAt[index]
		local def = type(at) == "table" and defs[at.path]
		local now = def and def.cvar and ns.CVarGet(def)
		if type(at) ~= "table" or now == nil or not ns.CVarSame(now, at.value) then
			lines[#lines + 1] = ("Setup: the game kept %s."):format(tostring(text))
		end
	end
	return lines
end

-- Saves the draft: into the profile in use in one call, or into a new profile of the character's own, a copy of the profile in use with the draft
-- over it, while it is on Default or Save as a new profile is ticked. Then the rows the game holds are written and read back, the queued picks run,
-- the flag and the result are kept, one line goes to chat, and the window closes so that the real screen shows the change, with the after card
-- (SetupWelcome.lua) over it. Out of combat only: the profile calls refuse in combat, and so does this.
function S.Finish()
	local draft = S.draft
	if not draft then
		return
	elseif InCombatLockdown() then
		kit.Say(COMBAT_LINE)
		return
	elseif not S.Has(draft) then
		S.Flag()
		if ns.Get("setup.say") == "line" then
			print("Flat UI: nothing changed.")
		end
		S.Drop()
		kit.Hide()
		return
	end
	local new = S.SavesNew()
	local name, why
	if new then
		name, why = S.NameCheck()
		if not name then
			kit.Say(why)
			S.Walk("FocusName")
			return
		end
	end
	local reloadLines = S.ReloadLines()
	local picks, settings = {}, 0
	for path, value in pairs(draft.values) do
		picks[path] = value
		settings = settings + 1
	end
	local ok, message
	if new then
		ok, message = ns.NewProfile(name, ns.Profile(), picks)
	else
		name = ns.Profile()
		ok, message = ns.ChangeProfile(picks)
	end
	if not ok then
		kit.Say(message)
		return
	end
	-- The rows the game or a function holds are written now that the profile in use has the rest.
	local defs = S.Defs()
	local problems = {}
	local game, kept, keptAt = 0, {}, {}
	for path, value in pairs(picks) do
		local def = defs[path]
		if def and ns.RowUnsaved(def) then
			ns.Set(path, value, true)
			-- A game setting is read back: the game may keep another value.
			local now = def.cvar and ns.CVarGet(def)
			if now ~= nil then
				game = game + 1
				if not ns.CVarSame(now, ns.Normalised(path, value)) then
					kept[#kept + 1] = { text = ("%s %s"):format(def.label, ns.CVarShown(def, now)), path = path, value = ns.Normalised(path, value) }
				end
			end
		end
	end
	table.sort(kept, function(x, y) return x.text < y.text end)
	for index, entry in ipairs(kept) do
		keptAt[index] = { path = entry.path, value = entry.value }
		kept[index] = entry.text
	end
	for _, action in ipairs(draft.actions) do
		local call = ns[action.pick]
		if type(call) == "function" then
			local good, done, text = pcall(call, action.id)
			if not good then
				geterrorhandler()(done)
			elseif done == false and IsText(text) and text ~= "" then
				problems[#problems + 1] = text
			end
		end
	end
	local result = { name = name, saved = not new, settings = settings, game = game, kept = kept, keptAt = keptAt }
	local character = ns.Character()
	if type(character) == "table" then
		character.setupOffered = true
		character.setupResult = result
	end
	if ns.Get("setup.say") == "line" then
		print((new and "Flat UI: %s is in use. %s." or "Flat UI: %s is saved. %s."):format(name, S.Totals(result)))
	end
	local finished = { name = name, new = new, users = S.Users(name), reloadLines = reloadLines, kept = kept, problems = problems }
	S.Drop()
	kit.Hide()
	if type(ns.SetupAfter) == "function" then
		Reported(pcall(ns.SetupAfter, finished))
	end
end

-- The window -----------------------------------------------------------------------------------------

-- Shows the screen S.screen is: the title, the page's rows and drawing or the walk's stop or Your screen, the buttons and the list.
function S.Show()
	local screen = S.screen
	if not S.root or not S.draft or not screen then
		return
	end
	S.asking = false
	kit.CloseList()
	kit.Tip("")
	for _, other in pairs(S.views) do
		other.scroller.frame:Hide()
	end
	S.band:SetShown(screen.kind == "page")
	if screen.kind == "page" then
		S.Walk("Hide")
		local view = S.StepView(screen.number)
		S.title:SetText(STEPS[screen.number].title)
		view.scroller.frame:Show()
		S.Under(S.view, function()
			for _, entry in ipairs(view.rows) do
				entry.row.Update()
			end
			S.LayoutStep(view)
			S.sub:SetText(S.Subtitle(view))
		end)
		view.scroller.Scroll(0)
	else
		-- The walk writes its own title and line; these stand while it is missing.
		local stop = screen.kind == "stop" and S.Stop(screen.id)
		S.title:SetText(stop and stop.title or "Your screen")
		S.sub:SetText(stop and stop.line or "")
		S.Walk("Show", screen)
	end
	S.dirty = true
	S.LayoutList()
	S.Buttons()
	kit.SetCounter(S.Counter())
	kit.Refresh()
end

-- Reads every control on screen again: the window calls it every half second and after every change.
function S.Update()
	local screen = S.screen
	if not S.root or not S.draft or not screen then
		return
	end
	kit.SetCounter(S.Counter())
	if screen.kind == "page" then
		local view = S.StepView(screen.number)
		S.Under(S.view, function()
			for _, entry in ipairs(view.rows) do
				entry.row.Update()
			end
			local shown, more = S.Shown(view)
			if S.Signature(view, shown, more) ~= view.sig then
				S.LayoutStep(view)
				S.sub:SetText(S.Subtitle(view))
			end
		end)
	else
		S.Walk("Update")
	end
	-- While Your screen shows in a fight the strip says why Finish does nothing, and stops saying it when the fight is over.
	if screen.kind == "yours" and InCombatLockdown() then
		kit.Say(COMBAT_LINE)
		S.combatSaid = true
	elseif S.combatSaid then
		S.combatSaid = false
		kit.Tip("")
	end
	S.ReadList()
	S.Buttons()
end

-- On the frame after a change the drawings are painted again: the page's, or the walk's cards and pictures.
function S.Frame()
	if not S.dirty or not S.draft or not S.screen then
		return
	end
	S.dirty = false
	if S.screen.kind == "page" then
		S.Redraw()
	else
		S.Walk("Paint")
	end
end

function S.Build(window)
	local root = kit.Frame(window)
	root:SetSize(kit.WIDTH, kit.HEIGHT - kit.TITLE - kit.STRIP)
	root:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -kit.TITLE)
	S.root = root

	local left = kit.Frame(root)
	left:SetSize(kit.LEFT, kit.HEIGHT - kit.TITLE - kit.STRIP)
	left:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
	local back = kit.Fill(left, "BACKGROUND")
	back:SetAllPoints(left)
	local divider = kit.Fill(left, "BORDER")
	divider:SetWidth(1)
	divider:SetPoint("TOPRIGHT", left, "TOPRIGHT", 0, 0)
	divider:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 0)
	kit.Painted(function()
		kit.Solid(back, "sidebar")
		kit.Solid(divider, "line")
	end)
	S.BuildMap(left)
	S.listScroller = kit.Scroller(left, kit.LEFT - 1, kit.HEIGHT - kit.TITLE - kit.STRIP - LIST_Y - 8)
	S.listScroller.frame:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -LIST_Y)

	local right = kit.Frame(root)
	right:SetSize(kit.RIGHT_W, kit.HEIGHT - kit.TITLE - kit.STRIP)
	right:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
	S.right = right
	S.title = kit.Label(right, "GameFontNormalLarge", "LEFT", 620)
	S.title:SetPoint("TOPLEFT", right, "TOPLEFT", kit.PAD, -4)
	S.sub = kit.Dim(kit.Label(right, "GameFontHighlightSmall", "LEFT", 640, true))
	S.sub:SetPoint("TOPLEFT", right, "TOPLEFT", kit.PAD, -24)
	S.sub:SetHeight(24)
	S.sub:SetJustifyV("TOP")
	local line = kit.Fill(right, "BORDER")
	line:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -(kit.HEADER - 1))
	line:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -(kit.HEADER - 1))
	line:SetHeight(1)

	-- The drawing band of a page, under the title. The stops draw on cards of their own.
	local band = kit.Frame(right)
	band:SetSize(kit.RIGHT_W, DRAW_H)
	band:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -kit.HEADER)
	local floor = kit.Fill(band, "BACKGROUND")
	floor:SetAllPoints(band)
	local edge = kit.Fill(band, "BORDER")
	edge:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", 0, 0)
	edge:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", 0, 0)
	edge:SetHeight(1)
	kit.Painted(function()
		kit.Solid(line, 0.08)
		kit.Solid(floor, 0.02)
		kit.Solid(edge, 0.08)
	end)
	ns.SetupDraw.Build(band, S.view)
	band:Hide()
	S.band = band

	-- A stop and Your screen, under the title (SetupWalk.lua).
	S.Walk("Build", right)

	-- Back at the left; Next (or Finish) at the right, and the two buttons left of it.
	local bar = kit.Frame(right)
	bar:SetSize(kit.RIGHT_W, BAR_H)
	bar:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
	S.back = kit.Button(bar, "Back", 80, S.Back)
	S.back:SetPoint("LEFT", bar, "LEFT", kit.PAD, 0)
	S.next, S.nextText = kit.Button(bar, "Next", 120, S.Primary, true)
	S.next:SetPoint("RIGHT", bar, "RIGHT", -kit.PAD, 0)
	S.mid1, S.mid1Text = kit.Button(bar, "Skip the rest", 130, S.Second)
	S.mid1:SetPoint("RIGHT", S.next, "LEFT", -8, 0)
	S.mid2, S.mid2Text = kit.Button(bar, "More settings", 130, S.More)
	S.mid2:SetPoint("RIGHT", S.mid1, "LEFT", -8, 0)

	S.BuildKeys(root)
	return root
end

-- Enter presses the primary button and Left and Right pick the card before or after on a stop. The keys come through a frame of Flat UI's own
-- that has the keyboard while setup shows and only out of combat (EnableKeyboard and SetPropagateKeyboardInput are protected); every key it does not
-- use goes on to the game, Escape too, so Escape closes the window. A box with the cursor takes the keys first.
function S.BuildKeys(root)
	local keys = kit.Frame(root)
	keys:SetAllPoints(root)
	keys:Hide()
	keys:SetScript("OnKeyDown", function(self, key)
		local enter = key == "ENTER" or key == "NUMPADENTER"
		local handled = enter
		if not enter and (key == "LEFT" or key == "RIGHT") and S.screen and S.screen.kind == "stop" and not S.asking then
			handled = S.Walk("Key", key) == true
		end
		if not InCombatLockdown() then
			Reported(pcall(self.SetPropagateKeyboardInput, self, not handled))
		end
		-- Enter is always taken, so that it never opens chat while setup has the keys; while a question shows it does nothing.
		if enter and not S.asking then
			Reported(pcall(S.Primary))
		end
	end)
	-- A fight takes the keyboard from it at its start, the last moment that may, and gives it back after while setup still shows.
	keys:RegisterEvent("PLAYER_REGEN_DISABLED")
	keys:RegisterEvent("PLAYER_REGEN_ENABLED")
	keys:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			S.Keys(false)
		elseif S.root:IsVisible() then
			S.Keys(true)
		end
	end)
	S.keys = keys
end

-- Gives the keys frame the keyboard, or takes it away. In a fight it only hides: the keyboard is changed out of combat only.
function S.Keys(on)
	local keys = S.keys
	if not keys then
		return
	end
	if InCombatLockdown() then
		keys:Hide()
		return
	end
	local ok, err = pcall(keys.EnableKeyboard, keys, on)
	if not ok then
		geterrorhandler()(err)
	end
	keys:SetShown(on and ok)
end

-- The window has the mode: this character's draft opens where it was left, over the profile in use, or a new draft at the first stop.
function S.Enter()
	S.draft = S.Load() or S.Fresh()
	local moved = S.Rebase()
	S.Walk("Begin")
	S.screen, S.walkAt, S.combatSaid, S.asking = nil, nil, false, false
	S.showAll = {}
	S.Keys(true)
	S.Go(S.Opening())
	if moved then
		kit.Say(moved)
	end
end

-- The window was hidden: by Close, Escape, Finish or the game (a loading screen). A draft with a choice or a queued pick stays for next time; one with
-- neither is dropped.
function S.Hidden()
	if S.draft then
		S.Sync()
	end
	S.draft, S.screen, S.asking = nil, nil, false
	S.Keys(false)
end

-- Close: with something to keep it asks.
function S.Close()
	if not S.Has(S.draft) then
		kit.Hide()
		return
	end
	S.Question("Close setup.", function()
		kit.Hide()
	end, function()
		S.Drop()
		kit.Hide()
	end, "Keep choices", "Discard choices")
end

S.mode = {
	title = "Flat UI setup", waiting = "Setup opens after combat.",
	Build = S.Build, Enter = S.Enter, Update = S.Update, Frame = S.Frame, Hidden = S.Hidden, Close = S.Close,
}

-- Opens setup at this character's draft, where it was left, or at the first stop. With an id it opens there: a stop, "yours" for Your screen, or a
-- built step, whose page goes through every built step and back to the stop or Your screen last shown, with Every setting open in the list.
function ns.OpenSetup(id)
	local shown = ns.OpenPanelMode(S.mode)
	local screen = id ~= nil and S.draft and S.ScreenOf(id)
	if screen then
		if screen.kind == "page" then
			S.everyOpen = true
		end
		S.Go(screen)
	end
	return shown
end

-- The offer on a new character ------------------------------------------------------------------------

function S.Flag()
	local character = ns.Character()
	if type(character) == "table" then
		character.setupOffered = true
	end
end

-- Ready-made profiles ----------------------------------------------------------------------------------

-- Rows no ready-made profile sets: the scale rows other than Custom UI scale, and the two that read a value the client withholds in a fight.
S.NEVER = {
	["general.scale"] = true, ["general.pixelPerfect"] = true, ["general.pixelSize"] = true,
	["nameplates.threat"] = true, ["nameplates.threatRole"] = true,
}

-- The profiles of ns.SETUP_PROFILES with every value and position checked: a value stays when its setting exists, a profile holds it, no profile may set it, a step
-- lists it and the setting takes it exactly as it is. A value that fails is dropped and said once. Made when first read, since the lists of the choice rows
-- are made by files that load after Core.
function S.Presets()
	if S.presets then
		return S.presets
	end
	-- Before the modules start those lists are not complete: the profiles are checked then, not kept, and nothing is said.
	local started = type(ns.Started) ~= "function" or ns.Started()
	local defs = S.Defs()
	local list, dropped = {}, {}
	for _, raw in ipairs(type(ns.SETUP_PROFILES) == "table" and ns.SETUP_PROFILES or {}) do
		local profile = { id = raw.id, label = raw.label, line = raw.line, values = {} }
		-- Positions, by frame name; a spot that is not valid is dropped and said once, as a value is.
		for _, spot in ipairs(type(raw.movers) == "table" and raw.movers or {}) do
			local copy = { point = spot.point, x = spot.x, y = spot.y, scale = spot.scale, kind = spot.kind, label = spot.label }
			if IsText(spot.frame) and ns.CleanSpot(copy) then
				profile.movers = profile.movers or {}
				profile.movers[spot.frame] = copy
			else
				dropped[#dropped + 1] = ("Flat UI: the %s profile leaves out the position of %s: not a position."):format(tostring(raw.label), tostring(spot.frame))
			end
		end
		for path, value in pairs(type(raw.values) == "table" and raw.values or {}) do
			local def = defs[path]
			local why
			if not def then
				why = "no such setting"
			elseif ns.RowUnsaved(def) then
				why = "the game holds it"
			elseif path:find("^setup%.") or path:find("^barblock%.") or S.NEVER[path] then
				why = "a profile never sets it"
			elseif not S.where[path] then
				why = "no step has it"
			elseif ns.Normalised(path, value) ~= value then
				why = "not a value it takes"
			end
			if why then
				dropped[#dropped + 1] = ("Flat UI: the %s profile leaves out %s: %s."):format(tostring(raw.label), tostring(path), why)
			else
				profile.values[path] = value
			end
		end
		list[#list + 1] = profile
	end
	if not started then
		return list
	end
	S.presets = list
	table.sort(dropped)
	for _, line in ipairs(dropped) do
		geterrorhandler()(line)
	end
	return list
end

-- A ready-made profile by id, or nil.
function S.PresetOf(id)
	for _, profile in ipairs(S.Presets()) do
		if profile.id == id then
			return profile
		end
	end
	return nil
end

-- A ready-made profile in the shape of a saved one: its values as the options and its positions as the movers.
function S.Preset(id)
	local profile = S.PresetOf(id)
	return profile and { options = profile.values, movers = profile.movers or S.noSpots } or nil
end

-- What a call of the client answers, or nil when the call is missing, raises or gives a withheld value.
function S.Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not ns.IsSecret(answer) then
		return answer
	end
	return nil
end

S.TANKS = { WARRIOR = true, PALADIN = true, DRUID = true }
S.HEALERS = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true }
S.DAMAGERS = { MAGE = true, WARLOCK = true, ROGUE = true, HUNTER = true }

-- The id of the ready-made profile that suits this character, from the first rule that matches: a tank role or aura on a tank class, a healer role on a
-- healer class, a damage role, text or interface the player made larger, the Classic experience, a small screen, a class that only deals damage; else
-- Standard. A call that is missing, fails or is withheld counts as no match.
function S.Recommend()
	local class = S.Ask(UnitClassBase, "player")
	class = type(class) == "string" and class or nil
	local role = S.Ask(UnitGroupRolesAssigned, "player")
	if (role == "TANK" or S.Ask(UnitHasEffectivelyTankAura, "player") == true) and class and S.TANKS[class] then
		return "tank"
	elseif role == "HEALER" and class and S.HEALERS[class] then
		return "healer"
	elseif role == "DAMAGER" then
		return "damage"
	end
	local cvar = type(C_CVar) == "table" and C_CVar.GetCVar or nil
	local fontScale, useScale, uiScale = tonumber(S.Ask(cvar, "userFontScale")), S.Ask(cvar, "useUiScale"),
		tonumber(S.Ask(cvar, "uiScale")) or tonumber(S.Ask(cvar, "uiscale"))
	if (fontScale and fontScale >= 1.1) or (useScale == "1" and uiScale and uiScale >= 1) then
		return "large"
	end
	local rules = type(C_GameRules) == "table" and C_GameRules or nil
	local classic = type(Enum) == "table" and type(Enum.ForeverExperiencePreset) == "table" and Enum.ForeverExperiencePreset.Classic or 0
	local preset = rules and S.Ask(rules.GetForeverExperiencePreset)
	if Number(preset) and preset == classic then
		return "minimal"
	end
	local seen, width, height = false, nil, nil
	if type(GetPhysicalScreenSize) == "function" then
		seen, width, height = pcall(GetPhysicalScreenSize)
	end
	if seen and Number(height) and height > 0 and height < 900 then
		return "minimal"
	end
	if class and S.DAMAGERS[class] then
		return "damage"
	end
	return "standard"
end

-- The name a profile is stored under, whatever its case, or nil.
function S.FindProfile(name)
	if IsText(name) then
		local lower = name:lower()
		for _, stored in ipairs(ns.Profiles()) do
			if stored:lower() == lower then
				return stored
			end
		end
	end
	return nil
end

-- The profile most characters of the account use, leaving Default out (ties by name), or nil when none uses another.
function S.MostUsed()
	local db = ns.Account()
	if type(db) ~= "table" or type(db.profileOf) ~= "table" or type(db.profiles) ~= "table" then
		return nil
	end
	local counts, using = {}, ns.Profile()
	for _, name in pairs(db.profileOf) do
		if IsText(name) and name ~= "Default" and name ~= using and db.profiles[name] then
			counts[name] = (counts[name] or 0) + 1
		end
	end
	local best, most
	for name, count in pairs(counts) do
		if most == nil or count > most or (count == most and name:lower() < best:lower()) then
			best, most = name, count
		end
	end
	return best
end

-- Puts a ready-made profile in use: the profile of that name when there is one, as it is, else a new one made from the values. The flag is set and one
-- line said. Returns true, or false and why (in combat nothing changes).
function S.UseReady(id)
	local profile = S.PresetOf(id)
	if not profile then
		return false, "No such profile."
	elseif InCombatLockdown() then
		return false, "combat"
	end
	local found = S.FindProfile(profile.label)
	local ok, why
	if found then
		ok, why = ns.UseProfile(found)
	else
		ok, why = ns.NewProfile(profile.label, nil, profile.values, profile.movers)
	end
	if ok then
		S.Flag()
		print(("Flat UI: using %s."):format(found or profile.label))
	end
	return ok, why
end

-- What Profile on a new character holds to share a profile that is in use: a ready-made profile is shared by its tile, any other by its name.
function S.ShareMode(name)
	for _, profile in ipairs(S.Presets()) do
		if profile.label:lower() == name:lower() then
			return "preset:" .. profile.id
		end
	end
	return "profile:" .. name
end

-- The short form of a profile name for a button: 16 characters, then "...".
function S.Short(name)
	local count, at = 0, 1
	for start, stop in name:gmatch("()[\1-\127\194-\244][\128-\191]*()") do
		count = count + 1
		if count == 16 then
			at = stop
		elseif count > 16 then
			return name:sub(1, at - 1) .. "..."
		end
	end
	return name
end

-- True when this character has no profile of its own, has not been offered, and keeps no draft: a new character. With `asked` the welcome screen is
-- offered only when Profile on a new character is Show the welcome screen.
function S.Offerable(asked)
	local db, key = ns.Account(), ns.CharacterKey()
	local character = ns.Character()
	return key ~= nil and type(db) == "table" and type(db.profileOf) == "table" and db.profileOf[key] == nil and type(character) == "table"
		and character.setupOffered ~= true and (asked ~= true or ns.Get("setup.newCharacter") == "ask") and not S.Peek()
end

-- At login, before the modules start: a new character takes the profile that Profile on a new character names, with no window. Default profile only
-- sets the flag. A profile put in use leaves its line for ns.SetupLogin. Show the welcome screen does nothing here.
function ns.SetupAuto()
	S.line = nil
	local mode = ns.Get("setup.newCharacter")
	if mode == "ask" or not S.Offerable() then
		return
	elseif mode == "default" then
		S.Flag()
		return
	end
	local name, picks, spots
	local id = mode == "recommended" and S.Recommend() or (mode:find("^preset:") and mode:sub(8)) or nil
	if id then
		local profile = S.PresetOf(id)
		if not profile then
			return
		end
		name = S.FindProfile(profile.label)
		picks = not name and profile.values or nil
		spots = not name and profile.movers or nil
		name = name or profile.label
	elseif mode:find("^profile:") then
		name = S.FindProfile(mode:sub(9))
	end
	if name and ns.AssignProfile(name, picks, spots) then
		S.Flag()
		S.line = ("Flat UI: using %s."):format(name)
	end
end

function S.ShowOffer()
	ns.WelcomeShow()
end

-- At login: the line of a profile put in use by ns.SetupAuto, else a line when a draft is kept, else the welcome screen a second later, once the other login
-- windows have opened.
function ns.SetupLogin()
	if S.line then
		print(S.line)
		S.line = nil
		return
	elseif S.Peek() then
		print(NOT_FINISHED)
		return
	end
	if ns.WelcomeWanted() and C_Timer and C_Timer.After then
		C_Timer.After(1, function()
			ns.OutOfCombat(S.ShowOffer)
		end)
	end
end
