local _, ns = ...

-- Flat UI setup: a mode of the options window (Panel.lua gives it the window) that makes a new profile step by step, with a drawing of what each choice
-- looks like. Every choice goes into a draft kept for this character in FlatUIDB.setup.drafts. Nothing reaches a profile, a game setting or a list
-- before Finish: the drawings read the draft through ns.Viewing, and Finish makes the profile in one call. Everything here is in the table S, so that the
-- file keeps few locals.

local kit = ns.PanelKit
local STEPS = ns.SETUP_STEPS
local S = { views = {}, lines = {}, hist = {}, skipped = {}, quiet = false }
ns.Setup = S

local COMBAT_LINE = "In combat. Finish after combat."
local NOT_FINISHED = "Flat UI setup is not finished. /flatui setup continues it."
local BODY_Y, BODY_H, DRAW_H, BAR_H = 268, 234 + kit.HEIGHT - 620, 220, 44
local REPORT_Y = 56

local function IsText(value)
	return not ns.IsSecret(value) and type(value) == "string"
end

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Every step is in STEPS; the ones the wizard shows are the built ones, in order. Steps are numbered by their place in STEPS. 0 is New profile
-- and REVIEW is Review.
S.REVIEW = #STEPS + 1
S.built, S.position = {}, {}
for number, step in ipairs(STEPS) do
	if step.built then
		S.built[#S.built + 1] = number
		S.position[number] = #S.built
	end
end
S.total = #S.built

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
	local list = { { "ask", "Show profiles" }, { "default", "Default profile" }, { "recommended", "Recommended profile" } }
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

-- True when a name is one the window filled in: the character's name, or the label of the tile the draft starts from, with the " 2", " 3" FreeName adds.
function S.Filled(name, preset)
	if not IsText(name) then
		return false
	end
	local base = name:match("^(.-) %d+$") or name
	local profile = IsText(preset) and S.PresetOf(preset) or nil
	return base == S.PlayerName() or (profile ~= nil and (name == profile.label or base == profile.label))
end

function S.Fresh()
	return { name = S.DefaultName(), step = 0, seen = {}, values = {}, actions = {} }
end

-- A draft as the saved variables hold it, made safe: every value a setting can hold, every step a step, every action a pick and a plain id.
local function CleanDraft(raw)
	if type(raw) ~= "table" then
		return nil
	end
	local draft = { name = IsText(raw.name) and raw.name or S.DefaultName(), step = 0, seen = {}, values = {}, actions = {} }
	local db = ns.Account()
	if IsText(raw.preset) and S.PresetOf(raw.preset) then
		draft.preset = raw.preset
	elseif IsText(raw.from) and db and db.profiles and db.profiles[raw.from] then
		draft.from = raw.from
	end
	local function Screen(number)
		if Number(number) and number >= 0 and number <= S.REVIEW and number == math.floor(number) then
			return (number == 0 or number == S.REVIEW or (STEPS[number] and STEPS[number].built)) and number or 0
		end
		return 0
	end
	draft.step = Screen(raw.step)
	draft.at = Screen(raw.at) > 0 and Screen(raw.at) or nil
	for number, seen in pairs(type(raw.seen) == "table" and raw.seen or {}) do
		if Number(number) and STEPS[number] and seen == true then
			draft.seen[number] = true
		end
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
	-- White names never beat a Name colour the profile the draft starts from has.
	local base = draft.from and db.profiles[draft.from].options
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
	-- A draft made before the ready-made profiles started from the defaults, which Standard is.
	if not draft.preset and not draft.from and (next(draft.values) ~= nil or #draft.actions > 0 or draft.at ~= nil) then
		draft.preset = "standard"
	end
	return draft
end

-- True when a draft has something worth keeping: a value, a queued action, a saved profile or a ready-made profile other than Standard to start from.
function S.Has(draft)
	return draft ~= nil and (next(draft.values) ~= nil or #draft.actions > 0 or draft.from ~= nil or (draft.preset ~= nil and draft.preset ~= "standard"))
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

-- The views ------------------------------------------------------------------------------------------

-- The profile the draft starts from, or nil for the defaults.
function S.StartProfile()
	local db = ns.Account()
	if S.done then
		-- Finish made the profile: the drawing shows the profile in use.
		return db and db.profiles and db.profiles[ns.Profile()] or nil
	end
	local preset = S.draft and S.draft.preset
	if preset then
		return S.Preset(preset)
	end
	local from = S.draft and S.draft.from
	return from and db and db.profiles and db.profiles[from] or nil
end

-- The ready-made profile shown selected on New profile: the one the draft starts from, else the one that suits this character; none while a saved
-- profile is picked. Nothing is written.
function S.SelectedPreset()
	local draft = S.draft
	if not draft or draft.from then
		return nil
	end
	if draft.preset then
		return draft.preset
	end
	if not S.pick then
		S.pick = S.Recommend()
	end
	return S.pick
end

-- The name of the profile the draft starts from, for the buttons and Review: the ready-made profile's, else the saved profile's, else Defaults.
function S.StartName()
	local profile = S.PresetOf(S.SelectedPreset())
	if profile then
		return profile.label
	end
	return S.draft and S.draft.from or "Defaults"
end

-- The ready-made profile shown becomes the draft's start, as the steps, Review and Finish need it. A saved profile or an earlier pick is kept.
function S.Commit()
	local draft = S.draft
	if draft and not draft.from and not draft.preset and S.PresetOf(S.SelectedPreset()) then
		draft.preset = S.SelectedPreset()
		S.Prune()
		S.dirty = true
		S.Sync()
	end
end

S.noSpots = {}

-- What a drawing reads: the draft, else the start profile, else the row's default. Its spots are the start profile's positions.
S.view = setmetatable({ spots = S.noSpots }, { __index = function(_, path)
	local drafted = S.draft and S.draft.values[path]
	if drafted ~= nil then
		return drafted
	end
	local start = S.StartProfile()
	return start and start.options[path]
end })

-- The same without the draft: what the new profile starts with.
S.startView = setmetatable({ spots = S.noSpots }, { __index = function(_, path)
	local start = S.StartProfile()
	return start and start.options[path]
end })

local function Reported(ok, ...)
	if not ok then
		geterrorhandler()((...))
		return nil
	end
	return ...
end

-- Runs fn(...) with ns.Get reading `view`, and says an error it raised. Returns what fn returned.
function S.Under(view, fn, ...)
	local start = S.StartProfile()
	rawset(view, "spots", start and start.movers or S.noSpots)
	return Reported(ns.Viewing(view, fn, ...))
end

-- The value of a setting in the draft: a draft value, else what the new profile starts with.
function S.Value(path)
	return S.Under(S.view, ns.Get, path)
end

function S.StartValue(path)
	return S.Under(S.startView, ns.Get, path)
end

-- Gives a setting a value in the draft. A value the new profile starts with is not kept, so Undo, Back and a change back leave nothing behind.
-- Nothing is written to a profile, a game setting or a list.
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
	S.Sync()
end

-- A change of the profile to start from keeps every choice made, except those the new start already has.
function S.Prune()
	local draft = S.draft
	for path, value in pairs(draft.values) do
		if value == S.StartValue(path) then
			draft.values[path] = nil
		end
	end
end

-- The choices that differ from the start, in step order: { path, step, tier, value }.
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
-- off, "change" for a row that applies after /reload when its value changes. An entry { label, field } for each one that is on now and off in the new
-- profile ("off"), or that has another value there ("change").
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

-- Rows ---------------------------------------------------------------------------------------------

-- A copy of a row of Config.lua that reads and writes the draft: it has no saved path, so the row builders never touch a profile.
function S.Item(def)
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
	if IsText(def.tip) then
		-- Inside setup the profiles are in front of the player already.
		item.tip = def.tip:gsub(" Profiles are in the options window%.$", "")
	end
	return item
end

-- The rows of a step, built the first time the step is shown: { row, item, page, tier, path }.
function S.BuildRows(number, scroller)
	local defs = S.Defs()
	local rows = {}
	for _, entry in ipairs(STEPS[number].rows) do
		local def = defs[entry[1]]
		if def and ns.RowShown(def.path) then
			local item = S.Item(def)
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

-- The rows of the step that show now: open (every setting they need is on), and main ones, or all of them with Every choice. Run under the view.
function S.Shown(view)
	local all = ns.Get("setup.choices") == "all"
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

-- Puts the rows that show in a column and hides the rest.
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
	local all = ns.Get("setup.choices") == "all"
	view.more:SetShown(more > 0)
	if more > 0 then
		view.moreText:SetText(all and "Fewer choices" or ("More choices (%d)"):format(more))
		view.more:ClearAllPoints()
		view.more:SetPoint("TOPLEFT", view.scroller.child, "TOPLEFT", kit.PAD, -(y + 6))
		y = y + 40
	end
	view.scroller.SetContent(y + kit.PAD)
	view.sig = S.Signature(view, shown, more)
end

function S.Signature(view, shown, more)
	local parts = { ns.Get("setup.choices") == "all" and "all" or "main", tostring(more) }
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
	local scroller = kit.Scroller(S.right, kit.RIGHT_W, BODY_H)
	scroller.frame:SetPoint("TOPLEFT", S.right, "TOPLEFT", 0, -BODY_Y)
	view = { scroller = scroller, step = number }
	view.rows = S.BuildRows(number, scroller)
	local more, text = kit.Button(scroller.child, "More choices", 150, function()
		ns.Set("setup.choices", ns.Get("setup.choices") == "all" and "main" or "all")
		kit.Refresh()
	end)
	view.more, view.moreText = more, text
	more:Hide()
	scroller.frame:Hide()
	S.views[number] = view
	return view
end

-- The text under the step title: a switch that is off, and rows the game holds.
function S.Subtitle(view)
	local lines = {}
	local defs = S.Defs()
	local closed, off = false, nil
	for _, entry in ipairs(view.rows) do
		if not kit.IsOpen(entry.page, entry.item) then
			closed = true
			for _, needed in ipairs(S.Gates(entry)) do
				if not off and needed:find("%.enabled$") and ns.Get(needed) ~= true then
					off = defs[needed]
				end
			end
		end
	end
	if closed and off then
		lines[#lines + 1] = ("Off. Turn on |cffffffff%s|r for more choices."):format(off.label)
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

-- The text of the counter in the title bar.
function S.Counter()
	if S.done then
		return "Finished"
	elseif S.cur == 0 then
		return "Start"
	elseif S.cur == S.REVIEW then
		return "Review"
	end
	return ("%d of %d"):format(S.position[S.cur] or 0, S.total)
end

-- The step to open after this one: the next built step that has a row to show, else Review. With a number, the step after that screen.
function S.NextStep(after)
	after = after or S.cur
	for _, number in ipairs(S.built) do
		if number > after then
			local view = S.StepView(number)
			local shown = S.Under(S.view, S.Shown, view)
			if shown and #shown > 0 then
				return number
			end
		end
	end
	return S.REVIEW
end

-- The first step of the next area.
function S.SkipStep()
	local area = S.cur >= 1 and STEPS[S.cur] and STEPS[S.cur].area
	for _, number in ipairs(S.built) do
		if number > S.cur and STEPS[number].area ~= area then
			return number
		end
	end
	return S.REVIEW
end

function S.NameCheck()
	local clean, why = ns.ProfileNameCheck(S.draft and S.draft.name or "")
	return clean, why
end

-- Opens a screen: 0 New profile, a step number, or S.REVIEW.
function S.Go(number, quiet)
	local draft = S.draft
	if not draft then
		return
	end
	if S.cur == 0 and number ~= 0 then
		S.Commit()
	end
	if S.cur ~= number then
		if not quiet then
			S.hist[#S.hist + 1] = S.cur
		end
		if S.cur >= 1 and S.cur < S.REVIEW then
			draft.seen[S.cur] = true
		end
	end
	S.cur, S.done = number, false
	ns.SetupDraw.Mark(nil)
	draft.step = number
	if number > 0 then
		draft.at = number
	end
	S.Sync()
	S.Show()
end

function S.Back()
	local before = table.remove(S.hist)
	if before then
		if S.cur >= 1 and S.cur < S.REVIEW then
			S.draft.seen[S.cur] = true
		end
		S.cur, S.done = before, false
		S.draft.step = before
		if before > 0 then
			S.draft.at = before
		end
		S.Sync()
		S.Show()
	end
end

-- The list at the left: the areas and the steps in them, New profile before and Review after.
function S.Entries()
	local list = { { area = "Start" }, { number = 0, text = "New profile" } }
	local last
	for _, number in ipairs(S.built) do
		local step = STEPS[number]
		if step.area ~= last then
			last = step.area
			list[#list + 1] = { area = step.area }
		end
		list[#list + 1] = { number = number, text = step.title }
	end
	list[#list + 1] = { area = "Finish" }
	list[#list + 1] = { number = S.REVIEW, text = "Review" }
	return list
end

function S.ListLine(index)
	local line = S.lines[index]
	if line then
		return line
	end
	local frame = kit.Frame(S.listScroller.child)
	frame:SetSize(kit.LEFT - 1, 22)
	local fill = kit.Fill(frame, "BACKGROUND")
	fill:SetAllPoints(frame)
	local mark = kit.Fill(frame, "ARTWORK")
	mark:SetWidth(2)
	mark:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	mark:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	local box = kit.Fill(frame, "ARTWORK")
	box:SetSize(8, 8)
	box:SetPoint("LEFT", frame, "LEFT", 14, 0)
	local inner = kit.Fill(frame, "OVERLAY")
	inner:SetSize(6, 6)
	inner:SetPoint("CENTER", box, "CENTER", 0, 0)
	local text = kit.Label(frame, "GameFontHighlight", "LEFT", kit.LEFT - 50)
	text:SetPoint("LEFT", frame, "LEFT", 30, 0)
	line = { frame = frame, fill = fill, mark = mark, box = box, inner = inner, text = text }
	local function Paint()
		fill:SetShown(line.current == true or line.hover == true)
		kit.Solid(fill, line.current and 0.1 or 0.06)
		mark:SetShown(line.current == true)
		mark:SetColorTexture(kit.Accent())
		kit.Solid(box, "line-strong", line.area and 0 or 1)
		kit.Solid(inner, line.seen and "text-faint" or "stage", line.area and 0 or 1)
		if line.current then
			text:SetTextColor(kit.Accent())
		elseif line.area or line.skipped then
			text:SetTextColor(kit.Shade("text-faint"))
		else
			text:SetTextColor(kit.Shade("text"))
		end
	end
	line.Paint = Paint
	kit.Painted(Paint)
	frame:SetScript("OnEnter", function()
		line.hover = line.number ~= nil
		Paint()
	end)
	frame:SetScript("OnLeave", function()
		line.hover = false
		Paint()
	end)
	kit.Clickable(frame, function()
		if line.number ~= nil and line.number ~= S.cur then
			if line.number > 0 and S.cur == 0 and not S.NameCheck() then
				kit.Say(select(2, S.NameCheck()))
				return
			end
			S.Go(line.number)
		end
	end)
	S.lines[index] = line
	return line
end

function S.LayoutList()
	local y = 4
	local entries = S.Entries()
	for index, entry in ipairs(entries) do
		local line = S.ListLine(index)
		line.area, line.number = entry.area ~= nil, entry.number
		line.current = not S.done and entry.number ~= nil and entry.number == S.cur
		line.seen = entry.number ~= nil and S.draft ~= nil and S.draft.seen[entry.number] == true
		line.skipped = entry.area ~= nil and S.skipped[entry.area] == true
		line.text:ClearAllPoints()
		line.text:SetPoint("LEFT", line.frame, "LEFT", entry.area and 12 or 30, 0)
		line.text:SetFontObject(entry.area and "GameFontHighlightSmall" or "GameFontHighlight")
		line.text:SetText(entry.area or entry.text)
		line.frame:SetHeight(entry.area and 20 or 22)
		line.frame:ClearAllPoints()
		line.frame:SetPoint("TOPLEFT", S.listScroller.child, "TOPLEFT", 0, -y)
		line.Paint()
		line.frame:Show()
		y = y + (entry.area and 20 or 22)
	end
	for index = #entries + 1, #S.lines do
		S.lines[index].frame:Hide()
	end
	S.listScroller.SetContent(y + 8)
end

-- The drawing of a screen: the ready-made profiles on New profile, the look of the profile being made on Review and after Finish.
function S.DrawingOf(number)
	if number >= 1 and number < S.REVIEW then
		return STEPS[number].draw
	end
	return number == 0 and "mock-profiles" or "mock-profile"
end

function S.Redraw()
	if not (S.draft or S.done) then
		return
	end
	local id = S.done and "mock-profile" or S.DrawingOf(S.cur)
	local marks = ns.SetupDraw.cardMarks
	if id == "mock-profiles" then
		if not S.pick then
			S.pick = S.Recommend()
		end
		marks.selected, marks.tag = S.SelectedPreset(), S.pick
	end
	ns.SetupDraw.Show(id)
	S.Under(S.view, ns.SetupDraw.Paint)
	S.marked = id == "mock-profiles" and (tostring(marks.selected) .. "," .. tostring(marks.tag)) or nil
end

-- Buttons ----------------------------------------------------------------------------------------------

-- The text of the Next button on New profile: Use Healer for a ready-made profile, Copy Mira for a saved one.
function S.UseText()
	local draft = S.draft
	if draft and draft.from and not S.PresetOf(S.SelectedPreset()) then
		return "Copy " .. S.Short(draft.from)
	end
	return "Use " .. S.Short(S.StartName())
end

function S.Buttons()
	local number, done = S.cur, S.done
	local review = number == S.REVIEW
	local start = number == 0
	S.back:SetShown(not done and number > 0)
	S.skip:SetShown(not done)
	S.skip:ClearAllPoints()
	S.skip:SetPoint("RIGHT", review and S.next or S.keep, "LEFT", -8, 0)
	S.skipText:SetText((start or review) and "Every step" or "Skip this area")
	S.keep:SetShown(not done and not review)
	S.next:SetShown(not done)
	S.nextText:SetText(review and "Finish" or (start and S.UseText() or "Next"))
	if start then
		S.keepText:SetText("Review")
	else
		local name = S.StartName()
		local plain = name == "Standard" or name == "Defaults"
		S.keepText:SetText(plain and "Keep the defaults for the rest" or ("Keep the rest from %s"):format(name))
	end
	local blocked = ((start or review) and InCombatLockdown()) or (start and not S.NameCheck())
	S.next:SetAlpha(blocked and 0.4 or 1)
end

-- Checks the name on New profile; says why when it fails. True when the name is good or the screen is not New profile.
function S.NameGood()
	if S.cur == 0 and not S.NameCheck() then
		kit.Say(select(2, S.NameCheck()))
		return false
	end
	return true
end

function S.OnNext()
	if S.cur == S.REVIEW then
		S.Finish()
	elseif S.cur == 0 then
		if S.NameGood() then
			-- In combat Finish says so and the tile is not written into the draft.
			if not InCombatLockdown() then
				S.Commit()
			end
			S.Finish()
		end
	else
		S.Go(S.NextStep())
	end
end

function S.OnSkip()
	if S.cur == 0 or S.cur == S.REVIEW then
		if S.NameGood() then
			S.Commit()
			S.Go(S.NextStep(0))
		end
	elseif S.cur >= 1 then
		S.skipped[STEPS[S.cur].area] = true
		S.Go(S.SkipStep())
	end
end

function S.OnKeep()
	if S.NameGood() then
		S.Go(S.REVIEW)
	end
end

-- The start screen -----------------------------------------------------------------------------------

local function Profiles()
	local lines = {}
	local current = ns.Profile()
	for _, name in ipairs(ns.Profiles()) do
		lines[#lines + 1] = { name, name == current and (name .. " (in use)") or name }
	end
	return lines
end

-- A saved profile picked in Start from: the ready-made profile is no longer the start, and a name the window filled goes back to the character's.
function S.PickSaved(name)
	local draft = S.draft
	if draft and IsText(name) then
		local filled = S.Filled(draft.name, draft.preset)
		draft.from, draft.preset = name, nil
		if filled then
			draft.name = S.DefaultName()
		end
		S.Prune()
		S.dirty = true
		S.Sync()
		kit.Refresh()
	end
end

-- A click on a tile of New profile: the ready-made profile is the start. Choices made keep, except those it already has. A name the window filled
-- becomes the tile's name; a name the player typed stays.
function S.PickCard(id)
	local draft, profile = S.draft, S.PresetOf(id)
	if not draft or S.cur ~= 0 or not profile then
		return
	end
	local filled = S.Filled(draft.name, draft.preset)
	draft.preset, draft.from = id, nil
	if filled then
		draft.name = S.FreeName(profile.label)
	end
	S.Prune()
	S.dirty = true
	S.Sync()
	kit.Refresh()
end

function S.BuildStart()
	local scroller = kit.Scroller(S.right, kit.RIGHT_W, BODY_H)
	scroller.frame:SetPoint("TOPLEFT", S.right, "TOPLEFT", 0, -BODY_Y)
	scroller.frame:Hide()
	local child = scroller.child
	local view = { scroller = scroller, rows = {} }

	view.unfinished = kit.Label(child, "GameFontHighlight", "LEFT", kit.ROW_W)
	view.again = kit.Button(child, "Continue", 90, function()
		S.Go(S.draft.at)
	end)
	view.reset = kit.Button(child, "Start over", 110, function()
		S.Reset()
	end)

	view.name = kit.NewRow(child, 8, "Profile name")
	local box = kit.Field(view.name.frame, kit.FIELD, 40)
	box:SetPoint("LEFT", view.name.frame, "LEFT", kit.CONTROL, 0)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnTextChanged", function(self)
		if not S.quiet and S.draft then
			local typed = self:GetText()
			S.draft.name = IsText(typed) and typed or ""
			S.NameLine()
			S.Buttons()
		end
	end)
	view.name.Hover(box)
	view.box = box
	view.bad = kit.Label(view.name.frame, "GameFontHighlightSmall", "LEFT", 100, true)
	view.bad:SetPoint("LEFT", view.name.frame, "LEFT", kit.CONTROL + kit.FIELD + 10, 0)
	kit.Painted(function()
		view.bad:SetTextColor(kit.Shade("danger"))
	end)

	view.from = kit.NewRow(child, 8, "Start from")
	view.fromMenu = kit.Dropdown(view.from, kit.FIELD, {
		lines = Profiles,
		selected = function()
			return S.draft and S.draft.from or nil
		end,
		pick = function(value)
			S.PickSaved(value)
		end,
	})
	view.fromMenu.frame:SetPoint("LEFT", view.from.frame, "LEFT", kit.CONTROL, 0)
	view.line = kit.Label(child, "GameFontHighlight", "LEFT", kit.ROW_W)

	local _, header = kit.Header(child, "Setup", 8)
	view.header = header
	local defs = S.Defs()
	for _, path in ipairs({ "setup.newCharacter", "setup.choices", "setup.say" }) do
		local def = defs[path]
		local row = def and kit.BuildRow(child, S.pageOf[def], def, 8)
		if row then
			view.rows[#view.rows + 1] = row
		end
	end
	S.start = view
	return view
end

function S.NameLine()
	local _, why = S.NameCheck()
	S.start.bad:SetText(why or "")
end

function S.LayoutStart()
	local view = S.start
	local draft = S.draft
	local y = 8
	local progress = draft.at ~= nil
	view.unfinished:SetShown(progress)
	view.again:SetShown(progress)
	view.reset:SetShown(progress)
	if progress then
		local where = draft.at == S.REVIEW and "at Review" or ("step %d of %d"):format(S.position[draft.at] or 0, S.total)
		view.unfinished:SetText(("Unfinished setup: %s, %s."):format(draft.name, where))
		view.unfinished:ClearAllPoints()
		view.unfinished:SetPoint("TOPLEFT", view.scroller.child, "TOPLEFT", kit.PAD, -(y + 6))
		view.again:ClearAllPoints()
		view.again:SetPoint("TOPLEFT", view.scroller.child, "TOPLEFT", kit.PAD, -(y + 32))
		view.reset:ClearAllPoints()
		view.reset:SetPoint("TOPLEFT", view.scroller.child, "TOPLEFT", kit.PAD + 100, -(y + 32))
		y = y + 66
	end
	local profile = S.PresetOf(S.SelectedPreset())
	view.shown = profile ~= nil
	view.line:SetShown(profile ~= nil)
	if profile then
		view.line:SetText(profile.line)
		view.line:ClearAllPoints()
		view.line:SetPoint("TOPLEFT", view.scroller.child, "TOPLEFT", kit.PAD, -(y + 6))
		y = y + 28
	end
	view.name.Place(y)
	y = y + kit.ROW
	view.from.Place(y)
	y = y + kit.ROW
	view.header.Place(y + 6)
	y = y + kit.SECTION + 6
	for _, row in ipairs(view.rows) do
		row.Place(y)
		y = y + kit.ROW
	end
	view.scroller.SetContent(y + kit.PAD)
	view.progress = progress
end

function S.UpdateStart()
	local view = S.start
	local draft = S.draft
	if draft.from and not (ns.Account().profiles or {})[draft.from] then
		draft.from = nil
		S.Sync()
	end
	if (draft.at ~= nil) ~= view.progress or (S.PresetOf(S.SelectedPreset()) ~= nil) ~= view.shown then
		S.LayoutStart()
	end
	local profile = S.PresetOf(S.SelectedPreset())
	if profile and view.line:GetText() ~= profile.line then
		view.line:SetText(profile.line)
	end
	if not view.box:HasFocus() then
		local text = view.box:GetText()
		if text ~= draft.name then
			S.quiet = true
			view.box:SetText(draft.name)
			S.quiet = false
		end
	end
	S.NameLine()
	view.fromMenu.SetText(profile and profile.label or draft.from or "Defaults")
	if S.marked ~= (tostring(S.SelectedPreset()) .. "," .. tostring(S.pick)) then
		S.dirty = true
	end
	for _, row in ipairs(view.rows) do
		row.Update()
	end
end

-- Discards every choice and starts again.
function S.Reset()
	S.Drop()
	S.draft = S.Fresh()
	S.pick = nil
	S.hist, S.skipped = {}, {}
	S.cur = 0
	S.dirty = true
	S.Show()
end

-- Review ---------------------------------------------------------------------------------------------

function S.ValueText(item, value)
	if item.kind == "bool" then
		return value and "On" or "Off"
	elseif item.kind == "number" then
		return ("%g%s"):format(value, item.unit or "")
	elseif item.kind == "colour" then
		return "#" .. value:sub(3):upper()
	end
	for _, choice in ipairs(ns.Choices(item)) do
		if choice[1] == value then
			return choice[2]
		end
	end
	return tostring(value)
end

function S.BuildReview()
	local scroller = kit.Scroller(S.right, kit.RIGHT_W, BODY_H)
	scroller.frame:SetPoint("TOPLEFT", S.right, "TOPLEFT", 0, -BODY_Y)
	scroller.frame:Hide()
	S.reviewView = { scroller = scroller, heads = {}, items = {}, notes = {} }
	return S.reviewView
end

-- A group title, a change line (the label, with Undo) or a plain line of the review, made when it is first needed.
function S.ReviewPart(kind, index)
	local view = S.reviewView
	local pool = view[kind]
	local part = pool[index]
	if part then
		return part
	end
	local child = view.scroller.child
	if kind == "heads" then
		local text = kit.Dim(kit.Label(child, "GameFontHighlightSmall", "LEFT", kit.ROW_W))
		part = { text = text }
		function part.Place(top)
			text:ClearAllPoints()
			text:SetPoint("TOPLEFT", child, "TOPLEFT", kit.PAD, -top)
		end
		function part.Show(shown)
			text:SetShown(shown)
		end
	elseif kind == "notes" then
		local text = kit.Label(child, "GameFontHighlight", "LEFT", kit.ROW_W, true)
		part = { text = text }
		function part.Place(top)
			text:ClearAllPoints()
			text:SetPoint("TOPLEFT", child, "TOPLEFT", kit.PAD, -top)
		end
		function part.Show(shown)
			text:SetShown(shown)
		end
	else
		local frame = kit.Frame(child)
		frame:SetSize(kit.ROW_W, 26)
		local open = kit.Frame(frame)
		open:SetSize(440, 26)
		open:SetPoint("LEFT", frame, "LEFT", 0, 0)
		local text = kit.Label(open, "GameFontHighlight", "LEFT", 330)
		text:SetPoint("LEFT", open, "LEFT", 0, 0)
		local swatch = kit.Fill(open, "ARTWORK")
		swatch:SetSize(14, 14)
		swatch:SetPoint("LEFT", open, "LEFT", 340, 0)
		part = { frame = frame, text = text, swatch = swatch }
		kit.Clickable(open, function()
			if part.step then
				S.Go(part.step)
			end
		end)
		local undo = kit.Button(frame, "Undo", 70, function()
			if part.path then
				S.Undo(part.path, part.toDefault)
			end
		end)
		undo:SetPoint("LEFT", frame, "LEFT", 450, 0)
		function part.Place(top)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", child, "TOPLEFT", kit.PAD, -top)
		end
		function part.Show(shown)
			frame:SetShown(shown)
		end
	end
	pool[index] = part
	return part
end

-- Undo on a change goes back to what the start has. Undo on a line of Set by writes the setting's default, which differs from the start, so the draft
-- keeps it and the line moves to the changes.
function S.Undo(path, toDefault)
	if S.draft then
		if toDefault then
			local def = S.Defs()[path]
			if def then
				S.Set(path, def.default)
			end
		else
			S.draft.values[path] = nil
			S.dirty = true
			S.Sync()
		end
		S.LayoutReview()
	end
end

-- The values of the ready-made profile the draft starts from that the draft does not override, in step order: { path, step, tier, value }. Empty for
-- Standard and for a saved profile.
function S.SetBy()
	local list = {}
	local draft, profile = S.draft, S.draft and S.draft.preset and S.PresetOf(S.draft.preset)
	if not profile then
		return list
	end
	for path, value in pairs(profile.values) do
		if draft.values[path] == nil then
			local place = S.where[path]
			list[#list + 1] = { path = path, step = place and place.step or 0, index = place and place.index or 0, value = value }
		end
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

-- How many lines Review lists: the values the start sets and the changes made over it.
function S.ReviewCount()
	return #S.SetBy() + #S.Changes()
end

function S.LayoutReview()
	local view = S.reviewView
	local y = 8
	local heads, items, notes = 0, 0, 0
	local function Head(text)
		heads = heads + 1
		local head = S.ReviewPart("heads", heads)
		head.text:SetText(text)
		head.Place(y + 6)
		head.Show(true)
		y = y + 28
	end
	-- One line: the label and the value, with Undo. A line of Set by has Undo write the default.
	local function Line(change, def, toDefault)
		items = items + 1
		local line = S.ReviewPart("items", items)
		line.path, line.step, line.toDefault = change.path, change.step, toDefault
		line.text:SetText(("%s: %s"):format(def.label, S.ValueText(def, change.value)))
		if def.kind == "colour" then
			local r, g, b = tonumber(change.value:sub(3, 4), 16) / 255, tonumber(change.value:sub(5, 6), 16) / 255, tonumber(change.value:sub(7, 8), 16) / 255
			line.swatch:SetColorTexture(r, g, b, 1)
			line.swatch:Show()
		else
			line.swatch:Hide()
		end
		line.Place(y)
		line.Show(true)
		y = y + 28
	end
	local setBy = S.SetBy()
	if #setBy > 0 then
		Head("Set by " .. S.StartName())
		for _, change in ipairs(setBy) do
			local def = S.Defs()[change.path]
			if def then
				Line(change, def, true)
			end
		end
	end
	local last
	for _, change in ipairs(S.Changes()) do
		local def = S.Defs()[change.path]
		if def then
			local step = STEPS[change.step]
			if step and step.title ~= last then
				last = step.title
				Head(step.title)
			end
			Line(change, def, false)
		end
	end
	local reload = S.ReloadLines()
	if #reload > 0 then
		Head("Reload")
		for _, entry in ipairs(reload) do
			notes = notes + 1
			local note = S.ReviewPart("notes", notes)
			note.text:SetText(S.ReloadText(entry))
			note.Place(y)
			note.Show(true)
			y = y + 20
		end
	end
	for index = heads + 1, #view.heads do
		view.heads[index].Show(false)
	end
	for index = items + 1, #view.items do
		view.items[index].Show(false)
	end
	for index = notes + 1, #view.notes do
		view.notes[index].Show(false)
	end
	view.scroller.SetContent(y + kit.PAD)
	view.count = S.ReviewCount()
	S.sub:SetText(S.ReviewSubtitle())
end

-- The lines under the title of Review: the profile and where it starts, then the settings the start sets and the changes made over it.
function S.ReviewSubtitle()
	local changes, set = #S.Changes(), #S.SetBy()
	local name = IsText(S.draft.name) and S.draft.name:match("^%s*(.-)%s*$") or ""
	local start = S.StartName()
	local parts = {}
	if set > 0 then
		parts[#parts + 1] = ("%d %s from %s"):format(set, set == 1 and "setting" or "settings", start)
	end
	if changes > 0 then
		parts[#parts + 1] = changes == 1 and "1 change" or ("%d changes"):format(changes)
	end
	return ("|cffffffff%s|r, from |cffffffff%s|r.\n%s"):format(name ~= "" and name or "Profile", start,
		#parts == 0 and "No changes." or (table.concat(parts, ", ") .. "."))
end

-- Finish and the screen after it ----------------------------------------------------------------------

local function Count(number, one, many)
	return ("%d %s"):format(number, number == 1 and one or many)
end

-- The settings the draft chooses, and the settings the new profile takes from its start (a ready-made or saved profile) that the draft leaves alone.
-- Only saved settings count from the start: the game and the functions hold the others.
function S.Counts()
	local draft = S.draft
	local defs = S.Defs()
	local chosen, fromStart = 0, 0
	for _ in pairs(draft.values) do
		chosen = chosen + 1
	end
	local start = S.StartProfile()
	for path in pairs(start and start.options or {}) do
		local def = defs[path]
		if def and not ns.RowUnsaved(def) and draft.values[path] == nil then
			fromStart = fromStart + 1
		end
	end
	return chosen, fromStart
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

-- The lines of the Finish screen: the counts, the game settings, each one the game kept, the problems of the queued actions, each reload need.
function S.ReportLines(finished)
	local result = finished.result
	local texts = {}
	if result.settings == 0 then
		texts[1] = ("%s: no settings chosen."):format(result.name)
	elseif result.settings == result.chosen then
		texts[1] = ("%s: %s chosen here."):format(result.name, Count(result.chosen, "setting", "settings"))
	else
		texts[1] = ("%s: %s. %d chosen here, %d from %s."):format(result.name, Count(result.settings, "setting", "settings"), result.chosen, result.settings - result.chosen,
			tostring(result.start))
	end
	if result.game > 0 then
		texts[#texts + 1] = #result.kept > 0 and ("Game settings: %d set, %d kept by the game."):format(result.game, #result.kept) or ("Game settings: %d set."):format(result.game)
	end
	for _, text in ipairs(result.kept) do
		texts[#texts + 1] = ("Kept by the game: %s."):format(text)
	end
	for _, text in ipairs(finished.problems) do
		texts[#texts + 1] = text
	end
	for _, entry in ipairs(finished.reloadLines or {}) do
		texts[#texts + 1] = S.ReloadText(entry)
	end
	return texts
end

-- The line of /flatui status for the last setup of this character, while its profile exists. Core.lua adds it.
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
	local lines = { ("Setup: %s%s. %s."):format(result.name, IsText(result.start) and (" from " .. result.start) or "", S.Totals(result)) }
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

-- Makes the profile. Out of combat only: the profile calls refuse in combat, and so does this.
function S.Finish()
	local draft = S.draft
	if not draft then
		return
	end
	if InCombatLockdown() then
		kit.Say(COMBAT_LINE)
		return
	end
	local name, why = S.NameCheck()
	if not name then
		S.Go(0)
		kit.Say(why)
		S.start.box:SetFocus()
		return
	end
	local reloadLines = S.ReloadLines()
	local reload = #reloadLines > 0
	local chosen, fromStart = S.Counts()
	local profile = draft.preset and S.PresetOf(draft.preset)
	-- The start is the ready-made profile or the saved profile the draft came from, whatever the name text says.
	local start = profile and profile.label or draft.from
	local picks = draft.values
	if profile then
		-- A ready-made profile is the start: its values with the draft's over them, in a table of their own.
		picks = {}
		for path, value in pairs(profile.values) do
			picks[path] = value
		end
		for path, value in pairs(draft.values) do
			picks[path] = value
		end
	end
	local ok, message = ns.NewProfile(name, draft.from, picks, profile and profile.movers)
	if not ok then
		S.Go(0)
		kit.Say(message)
		S.start.box:SetFocus()
		return
	end
	-- The rows the game or a function holds are written now that the new profile is in use.
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
	local character = ns.Character()
	if type(character) == "table" then
		character.setupOffered = true
	end
	local result = { name = name, start = fromStart > 0 and start or nil, settings = chosen + fromStart, chosen = chosen, game = game, kept = kept, keptAt = keptAt }
	if type(character) == "table" then
		character.setupResult = result
	end
	if ns.Get("setup.say") == "line" then
		print(("Flat UI: %s is in use. %s."):format(name, S.Totals(result)))
	end
	S.Drop()
	S.finished = { name = name, reload = reload, reloadLines = reloadLines, problems = problems, result = result }
	S.done = true
	S.draft = nil
	S.Show()
end

-- Gives a button of the Finish screen a tip line besides its own hover behaviour.
function S.Tipped(button, tip)
	local enter, leave = button:GetScript("OnEnter"), button:GetScript("OnLeave")
	button:SetScript("OnEnter", function(...)
		enter(...)
		kit.Tip(tip)
	end)
	button:SetScript("OnLeave", function(...)
		leave(...)
		kit.Tip("")
	end)
end

function S.BuildDone()
	local view = { frame = kit.Frame(S.right) }
	view.frame:SetSize(kit.RIGHT_W, BODY_H)
	view.frame:SetPoint("TOPLEFT", S.right, "TOPLEFT", 0, -BODY_Y)
	view.frame:Hide()
	local Tipped = S.Tipped
	local x = kit.PAD
	local function Add(text, width, tip, onClick)
		local button = kit.Button(view.frame, text, width, onClick)
		button:SetPoint("TOPLEFT", view.frame, "TOPLEFT", x, -16)
		Tipped(button, tip)
		x = x + width + 8
		return button
	end
	view.movers = Add("Movers", 90, "Shows the handles for moving frames.", function()
		local module = ns.modules and ns.modules.movers
		local command = module and module.slash and module.slash.move
		if type(command) == "function" then
			local ok, err = pcall(command, "")
			if not ok then
				geterrorhandler()(err)
			end
		end
	end)
	view.options = Add("Options", 90, "Opens the Flat UI options.", function()
		kit.Hide()
		ns.OpenPanel()
	end)
	view.close = Add("Close", 90, "Closes setup.", function()
		kit.Hide()
	end)
	-- The report scrolls under the buttons, a line for each text.
	view.scroller = kit.Scroller(view.frame, kit.RIGHT_W, BODY_H - REPORT_Y)
	view.scroller.frame:SetPoint("TOPLEFT", view.frame, "TOPLEFT", 0, -REPORT_Y)
	view.lines = {}
	S.doneView = view
	return view
end

-- The Reload button of Finish, made when a reload is needed: Finish runs out of combat, where the secure button can be made.
function S.ReloadButton()
	local view = S.doneView
	if not view.reload then
		view.reload = kit.Button(view.frame, "Reload", 90, ns.Reload)
		S.Tipped(view.reload, "Reloads the interface.")
		ns.SecureReload(view.reload)
	end
	return view.reload
end

function S.ShowDone()
	local view = S.doneView or S.BuildDone()
	local finished = S.finished
	view.frame:Show()
	local x = kit.PAD
	if finished.reload then
		local reload = S.ReloadButton()
		reload:ClearAllPoints()
		reload:SetPoint("TOPLEFT", view.frame, "TOPLEFT", x, -16)
		reload:Show()
		x = x + 98
	elseif view.reload then
		view.reload:Hide()
	end
	for _, button in ipairs({ view.movers, view.options, view.close }) do
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", view.frame, "TOPLEFT", x, -16)
		x = x + 98
	end
	local texts = S.ReportLines(finished)
	local y = 8
	for index = 1, math.max(#texts, #view.lines) do
		local text = texts[index]
		local line = view.lines[index]
		if not line and text then
			line = kit.Label(view.scroller.child, "GameFontHighlight", "LEFT", kit.ROW_W, true)
			view.lines[index] = line
		end
		if line then
			line:SetText(text or "")
			line:SetShown(text ~= nil)
			if text then
				line:ClearAllPoints()
				line:SetPoint("TOPLEFT", view.scroller.child, "TOPLEFT", kit.PAD, -y)
				local ok, height = pcall(line.GetStringHeight, line)
				y = y + (ok and Number(height) and height > 0 and height or 14) + 8
			end
		end
	end
	view.scroller.SetContent(y + kit.PAD)
	view.scroller.Scroll(0)
end

-- The window -----------------------------------------------------------------------------------------

-- Shows the screen S.cur is: the title, the rows or lines, the drawing, the buttons, the list.
function S.Show()
	if not S.root or not S.draft and not S.done then
		return
	end
	local view
	kit.Tip("")
	for _, other in pairs(S.views) do
		other.scroller.frame:Hide()
	end
	S.start.scroller.frame:Hide()
	S.reviewView.scroller.frame:Hide()
	S.doneView.frame:Hide()
	if S.done then
		S.title:SetText(S.finished.name)
		S.sub:SetText(("|cffffffff%s|r is in use."):format(S.finished.name))
		S.ShowDone()
	elseif S.cur == 0 then
		S.title:SetText("New profile")
		S.sub:SetText("")
		S.start.scroller.frame:Show()
		S.LayoutStart()
		S.start.scroller.Scroll(0)
	elseif S.cur == S.REVIEW then
		S.title:SetText("Review")
		S.reviewView.scroller.frame:Show()
		S.LayoutReview()
		S.reviewView.scroller.Scroll(0)
		S.sub:SetText(S.ReviewSubtitle())
	else
		view = S.StepView(S.cur)
		S.title:SetText(STEPS[S.cur].title)
		view.scroller.frame:Show()
		S.Under(S.view, function()
			for _, entry in ipairs(view.rows) do
				entry.row.Update()
			end
			S.LayoutStep(view)
			S.sub:SetText(S.Subtitle(view))
		end)
		view.scroller.Scroll(0)
	end
	S.dirty = true
	S.LayoutList()
	S.Buttons()
	S.Redraw()
	kit.SetCounter(S.Counter())
	kit.Refresh()
end

-- Reads every control on screen again: the window calls it every half second and after every change.
function S.Update()
	if not S.root or not (S.draft or S.done) then
		return
	end
	kit.SetCounter(S.Counter())
	if S.done then
		return
	end
	if S.cur == 0 then
		S.UpdateStart()
	elseif S.cur == S.REVIEW then
		if S.reviewView.count ~= S.ReviewCount() then
			S.LayoutReview()
		end
		S.sub:SetText(S.ReviewSubtitle())
		-- The strip says why Finish does nothing, and stops saying it when the fight is over.
		if InCombatLockdown() then
			kit.Say(COMBAT_LINE)
			S.combatSaid = true
		elseif S.combatSaid then
			S.combatSaid = false
			kit.Tip("")
		end
	else
		local view = S.StepView(S.cur)
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
	end
	S.Buttons()
end

-- Draws the drawing again on the frame after a change.
function S.Frame()
	if S.dirty then
		S.dirty = false
		S.Redraw()
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
	S.listScroller = kit.Scroller(left, kit.LEFT - 1, kit.HEIGHT - kit.TITLE - kit.STRIP - 8)
	S.listScroller.frame:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -4)

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

	local area = kit.Frame(right)
	area:SetSize(kit.RIGHT_W, DRAW_H)
	area:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -kit.HEADER)
	local floor = kit.Fill(area, "BACKGROUND")
	floor:SetAllPoints(area)
	local edge = kit.Fill(area, "BORDER")
	edge:SetPoint("BOTTOMLEFT", area, "BOTTOMLEFT", 0, 0)
	edge:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, 0)
	edge:SetHeight(1)
	kit.Painted(function()
		kit.Solid(line, 0.08)
		kit.Solid(floor, 0.02)
		kit.Solid(edge, 0.08)
	end)
	ns.SetupDraw.Build(area, S.view)
	ns.SetupDraw.onCard = function(id)
		S.PickCard(id)
	end

	S.BuildStart()
	S.BuildReview()
	S.BuildDone()

	-- Back at the left, Skip this area, Keep the defaults for the rest and Next at the right.
	local bar = kit.Frame(right)
	bar:SetSize(kit.RIGHT_W, BAR_H)
	bar:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
	S.back = kit.Button(bar, "Back", 80, S.Back)
	S.back:SetPoint("LEFT", bar, "LEFT", kit.PAD, 0)
	S.next, S.nextText = kit.Button(bar, "Next", 160, S.OnNext)
	S.next:SetPoint("RIGHT", bar, "RIGHT", -kit.PAD, 0)
	S.keep, S.keepText = kit.Button(bar, "Keep the defaults for the rest", 220, S.OnKeep)
	S.keep:SetPoint("RIGHT", S.next, "LEFT", -8, 0)
	S.skip, S.skipText = kit.Button(bar, "Skip this area", 120, S.OnSkip)
	S.skip:SetPoint("RIGHT", S.keep, "LEFT", -8, 0)
	return root
end

-- The window has the mode: this character's draft is opened at its step, or a new one at New profile.
function S.Enter()
	S.draft = S.Load() or S.Fresh()
	S.pick = nil
	S.done, S.finished = false, nil
	S.hist, S.skipped = {}, {}
	S.cur = S.draft.step or 0
	S.combatSaid = false
	S.Show()
end

-- The window was hidden, by Close or by the game (Escape, a loading screen). A draft with a choice or a queued action stays for Continue; one with
-- neither is dropped.
function S.Hidden()
	if S.draft then
		S.Sync()
	end
	S.draft = nil
	S.done, S.finished = false, nil
end

-- Close: with something to keep it asks.
function S.Close()
	if S.done or not S.Has(S.draft) then
		kit.Hide()
		return
	end
	kit.Ask("Close setup.", function()
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

-- Opens setup at this character's draft, or at New profile.
function ns.OpenSetup()
	return ns.OpenPanelMode(S.mode)
end

-- The offer on a new character ------------------------------------------------------------------------

function S.Flag()
	local character = ns.Character()
	if type(character) == "table" then
		character.setupOffered = true
	end
end

-- Ready-made profiles ----------------------------------------------------------------------------------

-- Rows no ready-made profile sets: the scale rows, and the two that read a value the client withholds in a fight.
S.NEVER = {
	["general.scaleOn"] = true, ["general.scale"] = true, ["general.pixelPerfect"] = true, ["general.pixelSize"] = true,
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

-- A ready-made profile in the shape of a saved one, which is what the draft starts from.
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

-- The panel: a tile for each ready-made profile, each a picture of it, three to a row. A click on a tile puts that profile in use.
S.OFFER_W, S.OFFER_H, S.TILE_W, S.TILE_H = 644, 518, 200, 118
S.PICK_LINE = "Click a profile to use it."

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

-- Reads the tile buttons' states again: the line, the tags, the pictures, and which buttons show. Run when the panel opens and when combat or the
-- screen changes.
function S.UpdateOffer()
	local frame = S.offer
	if not frame then
		return
	end
	S.offerLine:SetText(InCombatLockdown() and "In combat. Pick a profile after combat." or S.PICK_LINE)
	local pick, using = S.Recommend(), ns.Profile()
	local db = ns.Account()
	for _, tile in ipairs(S.tiles) do
		local found = S.FindProfile(tile.profile.label)
		local saved = found and type(db) == "table" and type(db.profiles) == "table" and db.profiles[found]
		tile.values = saved and saved.options or tile.profile.values
		local tag = (found and found == using and "In use") or (tile.profile.id == pick and "Recommended") or nil
		tile.tag:SetShown(tag ~= nil)
		tile.tagText:SetText(tag or "")
		tile.card.Paint()
	end
	S.mark:SetShown(S.share == true)
	local mate = S.MostUsed()
	S.same:SetShown(mate ~= nil)
	S.same:ClearAllPoints()
	S.open:ClearAllPoints()
	S.offerKeep:ClearAllPoints()
	S.sameName = mate
	if mate then
		S.sameText:SetText("Same as " .. S.Short(mate))
		S.same:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
		S.open:SetPoint("LEFT", S.same, "RIGHT", 8, 0)
	else
		S.open:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
	end
	S.offerKeep:SetPoint("LEFT", S.open, "RIGHT", 8, 0)
end

-- A click on a tile: its profile is put in use and the panel closes; in combat the line says so and nothing changes.
function S.PickTile(index)
	local tile = S.tiles[index]
	if not tile or not S.offer then
		return false
	end
	local ok, why = S.UseReady(tile.profile.id)
	if ok then
		if S.share then
			ns.Set("setup.newCharacter", "preset:" .. tile.profile.id)
		end
		S.offer:Hide()
	else
		S.offerLine:SetText(why == "combat" and "In combat. Pick a profile after combat." or tostring(why))
	end
	return ok
end

function S.BuildOffer()
	local frame = CreateFrame("Frame", "FlatUISetupOffer", UIParent)
	ns.Own[frame] = true
	frame:SetSize(S.OFFER_W, S.OFFER_H)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
	frame:SetFrameStrata("HIGH")
	-- Above the options window, which is in the same strata.
	frame:SetFrameLevel(200)
	frame:EnableMouse(true)
	local outline = ns.Outline(frame, frame, true)
	kit.Painted(function()
		kit.Backing(outline, "window", 0.98)
	end)
	S.offer = frame
	local title = kit.Label(frame, "GameFontNormal", "LEFT", 400)
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
	title:SetText("Flat UI setup")
	S.offerLine = kit.Label(frame, "GameFontHighlight", "LEFT", 620)
	S.offerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -34)
	S.offerLine:SetText(S.PICK_LINE)

	S.tiles = {}
	for index, profile in ipairs(S.Presets()) do
		local entry = { profile = profile, values = profile.values }
		local tile = kit.Frame(frame)
		tile:SetSize(S.TILE_W, S.TILE_H)
		tile:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + ((index - 1) % 3) * 210, -(58 + math.floor((index - 1) / 3) * 128))
		local edge = ns.Outline(tile, tile, true)
		kit.Painted(function()
			kit.Backing(edge, "raised")
		end)
		entry.frame, entry.edge = tile, edge
		entry.card = ns.SetupDraw.Card(tile, ns.SetupDraw.CardView(function()
			return entry.values
		end))
		entry.card.frame:SetScale(0.595)
		entry.card.frame:SetPoint("TOPLEFT", tile, "TOPLEFT", 0, 0)
		local name = kit.Label(tile, "GameFontNormal", "LEFT", 184)
		name:SetPoint("TOPLEFT", tile, "TOPLEFT", 8, -72)
		name:SetText(profile.label)
		local line = kit.Dim(kit.Label(tile, "GameFontHighlightSmall", "LEFT", 184, true))
		line:SetPoint("TOPLEFT", tile, "TOPLEFT", 8, -90)
		line:SetText(profile.line)
		entry.name, entry.line = name, line
		-- The tag sits on a frame of its own, above every frame of the picture.
		local tag = kit.Frame(tile)
		tag:SetFrameLevel(tile:GetFrameLevel() + 10)
		tag:SetSize(88, 16)
		tag:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -4, -4)
		local back = kit.Fill(tag, "BACKGROUND")
		back:SetAllPoints(tag)
		back:SetColorTexture(0, 0, 0, 0.75)
		entry.tagText = kit.Label(tag, "GameFontHighlightSmall", "CENTER", 88)
		entry.tagText:SetPoint("CENTER", tag, "CENTER", 0, 0)
		tag:Hide()
		entry.tag = tag
		kit.Clickable(tile, function()
			S.PickTile(index)
		end)
		tile:SetScript("OnEnter", function()
			ns.SetOutlineColour(edge, kit.Accent())
		end)
		tile:SetScript("OnLeave", function()
			ns.SetOutlineColour(edge, nil, nil, nil)
		end)
		S.tiles[index] = entry
	end

	S.same, S.sameText = kit.Button(frame, "Same as", 200, function()
		local name = S.sameName
		if not name then
			return
		end
		if InCombatLockdown() then
			S.offerLine:SetText("In combat. Pick a profile after combat.")
			return
		end
		local ok, why = ns.UseProfile(name)
		if ok then
			S.Flag()
			local used = S.FindProfile(name) or name
			print(("Flat UI: using %s."):format(used))
			if S.share then
				ns.Set("setup.newCharacter", S.ShareMode(used))
			end
			frame:Hide()
		else
			S.offerLine:SetText(tostring(why))
		end
	end)
	S.open = kit.Button(frame, "Open setup", 110, function()
		S.Flag()
		frame:Hide()
		ns.OpenSetup()
	end)
	S.offerKeep = kit.Button(frame, "Keep Default", 110, function()
		S.Flag()
		frame:Hide()
	end)
	-- The check box: the profile picked next is the one every new character gets. Unticked each time the panel opens.
	local box = kit.Frame(frame)
	box:SetSize(18, 18)
	box:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 50)
	local boxOutline = ns.Outline(box, box, true)
	S.mark = kit.Fill(box, "ARTWORK")
	S.mark:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
	S.mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
	S.shareLabel = kit.Label(frame, "GameFontHighlight", "LEFT", 400)
	S.shareLabel:SetPoint("LEFT", box, "RIGHT", 8, 0)
	S.shareLabel:SetText("Same profile on new characters")
	kit.Painted(function()
		kit.Backing(boxOutline, "raised")
		S.mark:SetColorTexture(kit.Accent())
	end)
	kit.Clickable(box, function()
		S.share = not S.share
		S.mark:SetShown(S.share == true)
	end)
	S.box = box
	frame:SetScript("OnShow", function()
		S.share = false
		S.UpdateOffer()
	end)
	-- The events go to a frame of their own: the panel hides itself, and a hidden frame still hears them.
	local listener = CreateFrame("Frame")
	ns.Own[listener] = true
	listener:RegisterEvent("PLAYER_REGEN_DISABLED")
	listener:RegisterEvent("PLAYER_REGEN_ENABLED")
	listener:RegisterEvent("UI_SCALE_CHANGED")
	listener:RegisterEvent("DISPLAY_SIZE_CHANGED")
	listener:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			frame:Hide()
		elseif frame:IsShown() then
			S.UpdateOffer()
		end
	end)
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "FlatUISetupOffer")
	end
	frame:Hide()
	return frame
end

-- Opens the panel, whether or not the character was offered: /flatui profiles and the Profiles page.
function ns.OpenProfiles()
	local frame = S.offer or S.BuildOffer()
	frame:Show()
	return frame:IsShown() == true
end

-- True when this character has no profile of its own, has not been offered, and keeps no draft: a new character. With `asked` the panel is
-- offered only when Profile on a new character is Show profiles.
function S.Offerable(asked)
	local db, key = ns.Account(), ns.CharacterKey()
	local character = ns.Character()
	return key ~= nil and type(db) == "table" and type(db.profileOf) == "table" and db.profileOf[key] == nil and type(character) == "table"
		and character.setupOffered ~= true and (asked ~= true or ns.Get("setup.newCharacter") == "ask") and not S.Peek()
end

-- At login, before the modules start: a new character takes the profile that Profile on a new character names, with no window. Default profile only
-- sets the flag. A profile put in use leaves its line for ns.SetupLogin. Show profiles does nothing here.
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
	if S.Offerable(true) and not InCombatLockdown() then
		local frame = S.offer or S.BuildOffer()
		frame:Show()
	end
end

-- At login: the line of a profile put in use by ns.SetupAuto, else a line when a draft is kept, else the offer a second later, once the other login
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
	if S.Offerable(true) and C_Timer and C_Timer.After then
		C_Timer.After(1, function()
			ns.OutOfCombat(S.ShowOffer)
		end)
	end
end
