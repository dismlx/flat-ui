local _, ns = ...

local kit = ns.PanelKit
local STEPS = ns.SETUP_STEPS
local S = { views = {}, lines = {}, boxes = {}, showAll = {}, everyOpen = false, version = 0 }
ns.Setup = S

local COMBAT_LINE = "In combat. Finish after combat."
local NOT_FINISHED = "Flat UI setup is not finished. /flatui setup continues it."
local DRAW_H, BAR_H = 220, 44
local PAGE_Y, PAGE_H = kit.HEADER + DRAW_H, 234 + kit.HEIGHT - 620
local MAP_W, MAP_H, LIST_Y = 186, 104, 122
local LINE_H = { stop = 36, yours = 24, every = 24, area = 20, step = 22, ready = 24 }
S.TOP, S.BODY_H = kit.HEADER, kit.HEIGHT - kit.TITLE - kit.STRIP - kit.HEADER - BAR_H

local function IsText(value)
	return not ns.IsSecret(value) and type(value) == "string"
end

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function Reported(ok, ...)
	if not ok then
		geterrorhandler()((...))
		return nil
	end
	return ...
end

S.built, S.numberOf = {}, {}
for number, step in ipairs(STEPS) do
	if step.built then
		S.built[#S.built + 1] = number
		S.numberOf[step.id] = number
	end
end

S.where = {}
for number, step in ipairs(STEPS) do
	for index, row in ipairs(step.rows) do
		S.where[row[1]] = { step = number, tier = row[2], index = index }
	end
end

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

function S.Walk(name, ...)
	local walk = ns.SetupWalk
	local fn = type(walk) == "table" and walk[name] or nil
	if type(fn) ~= "function" then
		return nil
	end
	return Reported(pcall(fn, ...))
end

function S.Stops()
	local stops = S.Walk("Stops")
	return type(stops) == "table" and stops or {}
end

function S.Stop(id)
	local stop = S.Walk("Stop", id)
	return type(stop) == "table" and stop or nil
end

function S.StopIndex(id)
	for index, stop in ipairs(S.Stops()) do
		if stop.id == id then
			return index
		end
	end
	return nil
end

function S.StopScreen(index)
	local stop = S.Stops()[index]
	return stop and { kind = "stop", id = stop.id } or nil
end

function S.FirstScreen()
	return S.StopScreen(1) or { kind = "yours" }
end

function S.Pages(stop)
	return type(stop) == "table" and type(stop.pages) == "table" and stop.pages or {}
end

function S.Migrate(store)
	if type(store) == "table" and store.offer ~= nil then
		if store.offer == false and store.newCharacter == nil then
			store.newCharacter = "default"
		end
		store.offer = nil
	end
end

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

function S.DefaultName()
	return S.FreeName(S.PlayerName())
end

function S.Fresh()
	local first = S.Stops()[1]
	return { v = 2, from = ns.Profile(), stop = first and first.id or "yours", seen = {}, values = {}, actions = {}, name = S.DefaultName(), saveNew = false }
end

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
	local picks = type(raw.values) == "table" and raw.values or {}
	if Number(picks["unitframes.partyRangeAlpha"]) and picks["unitframes.partyRangeOpacity"] == nil then
		local moved = {}
		for path, value in pairs(picks) do
			moved[path] = value
		end
		moved["unitframes.partyRangeOpacity"] = 100 - picks["unitframes.partyRangeAlpha"]
		picks = moved
	end
	local values = {}
	for path, value in pairs(picks) do
		values[path] = value
	end
	ns.MigrateText(values, values)
	if ns.MigrateSounds then
		ns.MigrateSounds(values, false)
	end
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

function S.Has(draft)
	return draft ~= nil and (next(draft.values) ~= nil or #draft.actions > 0)
end

function S.Load()
	local store = S.Store(false)
	local draft = store and CleanDraft(store.drafts[S.Key()])
	if draft and S.Has(draft) then
		store.drafts[S.Key()] = draft
		return draft
	end
	return nil
end

function S.Peek()
	local store = S.Store(false)
	local raw = store and store.drafts[S.Key()]
	local draft = raw ~= nil and CleanDraft(raw) or nil
	return S.Has(draft)
end

function ns.SetupHasDraft()
	return S.Peek()
end

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

function S.Drop()
	local store = S.Store(false)
	if store then
		store.drafts[S.Key()] = nil
	end
	S.draft = nil
end

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

function S.SavesNew()
	return ns.Profile() == "Default" or (S.draft ~= nil and S.draft.saveNew == true)
end

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

function S.NameCheck()
	local clean, why = ns.ProfileNameCheck(S.draft and S.draft.name or "")
	return clean, why
end

function S.StartProfile()
	local db = ns.Account()
	return type(db) == "table" and type(db.profiles) == "table" and db.profiles[ns.Profile()] or nil
end

S.noSpots = {}

S.view = setmetatable({ spots = S.noSpots }, { __index = function(_, path)
	local drafted = S.draft and S.draft.values[path]
	if drafted ~= nil then
		return drafted
	end
	local start = S.StartProfile()
	return start and start.options[path]
end })

S.startView = setmetatable({ spots = S.noSpots }, { __index = function(_, path)
	local start = S.StartProfile()
	return start and start.options[path]
end })

function S.Under(view, fn, ...)
	local start = S.StartProfile()
	rawset(view, "spots", start and start.movers or S.noSpots)
	return Reported(ns.Viewing(view, fn, ...))
end

function S.Value(path)
	return S.Under(S.view, ns.Get, path)
end

function S.StartValue(path)
	return S.Under(S.startView, ns.Get, path)
end

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

function S.Prune()
	local draft = S.draft
	for path, value in pairs(draft.values) do
		if value == S.StartValue(path) then
			draft.values[path] = nil
		end
	end
	S.version = S.version + 1
end

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

function S.ReloadText(entry)
	if entry[2] == "change" then
		return ("|cffffffff%s|r applies after /reload."):format(entry[1])
	end
	return ("Turning off |cffffffff%s|r takes full effect after /reload."):format(entry[1])
end

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

function S.LineId(action)
	local id, wanted = action.id, action.text
	if not IsText(wanted) then
		return id
	end
	local moved
	for _, def in pairs(S.Defs()) do
		local call = def.kind == "list" and def.pick == action.pick and IsText(def.label) and IsText(def.items) and ns[def.items] or nil
		if type(call) == "function" then
			local ok, lines = pcall(call)
			for _, line in ipairs(ok and type(lines) == "table" and lines or {}) do
				local at = type(line) == "table" and line[1] or nil
				if (IsText(at) or Number(at)) and IsText(line[2]) and ("%s: %s"):format(def.label, line[2]) == wanted then
					if at == id then
						return id
					end
					moved = moved == nil and at or moved
				end
			end
		end
	end
	if moved ~= nil then
		return moved
	end
	return id
end

S.APART = {
	["cooldowns.iconSound"] = true, ["cooldowns.iconShow"] = true, ["cooldowns.rowOf"] = true, ["pulse.iconSound"] = true, ["pulse.iconSpot"] = true,
	["trackers.clickUse"] = true, ["movers.layoutText"] = true, ["chat.gearOpen"] = true,
	["mount.bind"] = true,
}

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

function S.BuildRows(number, scroller)
	local defs = S.Defs()
	local rows = {}
	for _, entry in ipairs(STEPS[number].rows) do
		local def = defs[entry[1]]
		if def and ns.RowShown(def.path) and not S.APART[def.path] then
			local item = S.Item(def, entry)
			local page = S.pageOf[def]
			local row = kit.BuildRow(scroller.child, page, item, 8)
			if row then
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

function S.PageOf(number)
	return { kind = "page", number = number, list = S.built, back = S.walkAt or S.FirstScreen() }
end

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

function S.Opening()
	local at = S.draft and S.draft.stop
	if at == "yours" then
		return { kind = "yours" }
	end
	return IsText(at) and S.StopIndex(at) and { kind = "stop", id = at } or S.FirstScreen()
end

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

function S.PageIndex(screen)
	for index, number in ipairs(screen.list or {}) do
		if number == screen.number then
			return index
		end
	end
	return nil
end

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

function S.Leave()
	local from = S.from
	S.from = nil
	if type(from) == "table" and type(ns.WelcomeReturn) == "function" then
		if from.pages then
			kit.Leave()
		else
			kit.Hide()
		end
		ns.WelcomeReturn(from.welcome)
	else
		kit.Leave()
	end
end

function S.Back()
	local screen = S.screen
	if not screen then
		return
	elseif screen.kind == "stop" then
		local before = S.StopScreen((S.StopIndex(screen.id) or 1) - 1)
		if before then
			S.Go(before)
		else
			S.Leave()
		end
	elseif screen.kind == "yours" then
		local last = S.StopScreen(#S.Stops())
		if last then
			S.Go(last)
		else
			S.Leave()
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

function S.Primary()
	if S.screen and S.screen.kind == "yours" then
		S.Finish()
	else
		S.Next()
	end
end

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

function S.More()
	local screen = S.screen
	local pages = screen and screen.kind == "stop" and S.Pages(S.Stop(screen.id)) or {}
	if pages[1] then
		S.Go({ kind = "page", number = pages[1], list = pages, back = screen })
	end
end

function S.Covered()
	local welcome = _G.FlatUIWelcome
	if type(welcome) == "table" and type(welcome.IsShown) == "function" then
		local ok, shown = pcall(welcome.IsShown, welcome)
		if ok and not ns.IsSecret(shown) and shown == true then
			return true
		end
	end
	local window = kit.Window()
	if not window then
		return false
	end
	local ok, base = pcall(window.GetFrameLevel, window)
	local children = { pcall(window.GetChildren, window) }
	if not ok or not Number(base) or children[1] ~= true then
		return false
	end
	for index = 2, #children do
		local child = children[index]
		local read, level = pcall(child.GetFrameLevel, child)
		local seen, shown = pcall(child.IsShown, child)
		if read and seen and Number(level) and level >= base + 40 and not ns.IsSecret(shown) and shown == true then
			return true
		end
	end
	return false
end

function S.Reset()
	S.Drop()
	S.draft = S.Fresh()
	S.Walk("Begin")
	S.Go(S.FirstScreen())
end

function S.StartOver()
	if S.Has(S.draft) then
		kit.Ask("Start over. Every choice made here goes.", S.Reset, nil, "Start over", "Keep choices", true)
	else
		S.Reset()
	end
end

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

function S.CurrentKey()
	local screen = S.screen
	if screen and screen.kind == "page" and not S.everyOpen then
		screen = screen.back
	end
	return S.KeyOf(screen)
end

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
	local square = kit.Fill(frame, "BORDER")
	square:SetSize(16, 16)
	square:SetPoint("LEFT", frame, "LEFT", 12, 0)
	local inside = kit.Fill(frame, "ARTWORK")
	inside:SetSize(14, 14)
	inside:SetPoint("CENTER", square, "CENTER", 0, 0)
	local box = kit.Fill(frame, "ARTWORK")
	box:SetSize(8, 8)
	box:SetPoint("LEFT", frame, "LEFT", 14, 0)
	local inner = kit.Fill(frame, "OVERLAY")
	inner:SetSize(6, 6)
	inner:SetPoint("CENTER", box, "CENTER", 0, 0)
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

function S.Buttons()
	local screen = S.screen
	if not screen or not S.next then
		return
	end
	local primary, first, second
	if screen.kind == "stop" then
		local at = S.StopIndex(screen.id) or 1
		primary = "Next"
		first = at < #S.Stops() and "Skip the rest" or nil
		second = #S.Pages(S.Stop(screen.id)) > 0 and "More settings" or nil
	elseif screen.kind == "yours" then
		primary, first = "Finish", "Start over"
	else
		primary, first = "Next", "Done"
	end
	S.back:Show()
	S.nextText:SetText(primary)
	S.mid1:SetShown(first ~= nil)
	S.mid1Text:SetText(first or "")
	S.mid2:SetShown(second ~= nil)
	S.mid2Text:SetText(second or "")
	S.mid2:ClearAllPoints()
	S.mid2:SetPoint("RIGHT", first and S.mid1 or S.next, "LEFT", -8, 0)
	local blocked = screen.kind == "yours" and (InCombatLockdown() or (S.SavesNew() and S.Has(S.draft) and not S.NameCheck()))
	S.next:SetAlpha(blocked and 0.4 or 1)
end

function S.Redraw()
	local screen = S.screen
	if S.draft and screen and screen.kind == "page" then
		ns.SetupDraw.Show(STEPS[screen.number].draw)
		S.Under(S.view, ns.SetupDraw.Paint)
	end
end

local function Count(number, one, many)
	return ("%d %s"):format(number, number == 1 and one or many)
end

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
		local at = type(result.keptAt) == "table" and result.keptAt[index]
		local def = type(at) == "table" and defs[at.path]
		local now = def and def.cvar and ns.CVarGet(def)
		if type(at) ~= "table" or now == nil or not ns.CVarSame(now, at.value) then
			lines[#lines + 1] = ("Setup: the game kept %s."):format(tostring(text))
		end
	end
	return lines
end

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
	local before = ns.Profile()
	if new then
		ok, message = ns.NewProfile(name, before, picks)
	else
		name = ns.Profile()
		ok, message = ns.ChangeProfile(picks)
	end
	if not ok then
		kit.Say(message)
		return
	end
	local defs = S.Defs()
	local problems = {}
	local game, kept, keptAt = 0, {}, {}
	for path, value in pairs(picks) do
		local def = defs[path]
		if def and ns.RowUnsaved(def) then
			ns.Set(path, value, true)
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
			local good, done, text = pcall(function()
				return call(S.LineId(action))
			end)
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
		print((new and "Flat UI: %s is in use. %s." or "Flat UI: %s is saved. %s. Undo setup on the card, or Profiles > Bring back, puts it back until you reload."):format(name,
			S.Totals(result)))
	end
	local finished = { name = name, new = new, users = S.Users(name), reloadLines = reloadLines, kept = kept, problems = problems, game = game,
		previous = new and before ~= ns.Profile() and before or nil }
	S.Drop()
	kit.Hide()
	if type(ns.SetupAfter) == "function" then
		Reported(pcall(ns.SetupAfter, finished))
	end
end

function S.Show()
	local screen = S.screen
	if not S.root or not S.draft or not screen then
		return
	end
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

	S.Walk("Build", right)

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

function S.BuildKeys(root)
	local keys = kit.Frame(root)
	keys:SetAllPoints(root)
	keys:Hide()
	keys:SetScript("OnKeyDown", function(self, key)
		local enter = key == "ENTER" or key == "NUMPADENTER"
		local arrow = key == "LEFT" or key == "RIGHT"
		local covered = (enter or arrow) and Reported(pcall(S.Covered)) == true
		local handled = enter
		if arrow and not covered and S.screen and S.screen.kind == "stop" then
			handled = S.Walk("Key", key) == true
		elseif key == "ESCAPE" and type(kit.Escape) == "function" then
			handled = Reported(pcall(kit.Escape)) == true
		end
		if not InCombatLockdown() then
			local done, failed = pcall(self.SetPropagateKeyboardInput, self, not handled)
			if not done then
				geterrorhandler()(failed)
			end
			if handled and done and C_Timer and C_Timer.After then
				C_Timer.After(0, function()
					if not InCombatLockdown() then
						pcall(self.SetPropagateKeyboardInput, self, true)
					end
				end)
			end
		end
		if enter then
			if covered then
				Reported(pcall(kit.Enter))
			else
				Reported(pcall(S.Primary))
			end
		end
	end)
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
	if on and ok then
		pcall(keys.SetPropagateKeyboardInput, keys, true)
	end
	keys:SetShown(on and ok)
end

function S.Enter()
	S.draft = S.Load() or S.Fresh()
	local moved = S.Rebase()
	S.Walk("Begin")
	S.screen, S.walkAt, S.combatSaid = nil, nil, false
	S.showAll = {}
	S.Keys(true)
	S.Go(S.Opening())
	if moved then
		kit.Say(moved)
	end
end

function S.Hidden()
	if S.draft then
		S.Sync()
	end
	S.draft, S.screen = nil, nil
	S.Keys(false)
end

function S.Close()
	if not S.Has(S.draft) then
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
	title = "Flat UI setup", waiting = "Flat UI: Setup opens after combat.",
	Build = S.Build, Enter = S.Enter, Update = S.Update, Frame = S.Frame, Hidden = S.Hidden, Close = S.Close,
}

function ns.OpenSetup(id, welcome)
	local pages = type(ns.PanelShown) == "function" and ns.PanelShown() and not ns.PanelInMode()
	S.from = welcome ~= nil and { welcome = welcome, pages = pages } or nil
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

function S.Flag()
	local character = ns.Character()
	if type(character) == "table" then
		character.setupOffered = true
	end
end

S.NEVER = {
	["general.scale"] = true, ["general.pixelPerfect"] = true, ["general.pixelSize"] = true,
	["nameplates.threat"] = true, ["nameplates.threatRole"] = true,
}

function S.Presets()
	if S.presets then
		return S.presets
	end
	local started = type(ns.Started) ~= "function" or ns.Started()
	local defs = S.Defs()
	local list, dropped = {}, {}
	for _, raw in ipairs(type(ns.SETUP_PROFILES) == "table" and ns.SETUP_PROFILES or {}) do
		local profile = { id = raw.id, label = raw.label, line = raw.line, values = {}, screen = type(raw.screen) == "table" and raw.screen or nil }
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

function S.PresetOf(id)
	for _, profile in ipairs(S.Presets()) do
		if profile.id == id then
			return profile
		end
	end
	return nil
end

function S.SpotsOf(profile)
	if profile.movers and profile.screen and type(ns.FitSpots) == "function" then
		return ns.FitSpots(profile.movers, profile.screen, profile.values)
	end
	return profile.movers
end

function S.Preset(id)
	local profile = S.PresetOf(id)
	return profile and { options = profile.values, movers = S.SpotsOf(profile) or S.noSpots } or nil
end

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
		ok, why = ns.NewProfile(profile.label, nil, profile.values, S.SpotsOf(profile))
	end
	if ok then
		S.Flag()
		print(("Flat UI: using %s."):format(found or profile.label))
	end
	return ok, why
end

function S.ShareMode(name)
	for _, profile in ipairs(S.Presets()) do
		if profile.label:lower() == name:lower() then
			return "preset:" .. profile.id
		end
	end
	return "profile:" .. name
end

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

function S.Offerable(asked)
	local db, key = ns.Account(), ns.CharacterKey()
	local character = ns.Character()
	return key ~= nil and type(db) == "table" and type(db.profileOf) == "table" and ns.OwnProfile() == nil and type(character) == "table"
		and character.setupOffered ~= true and (asked ~= true or ns.Get("setup.newCharacter") == "ask") and not S.Peek()
end

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
		spots = not name and S.SpotsOf(profile) or nil
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
