local ADDON_NAME, ns = ...

-- Data panels: two panels of Flat UI's own, the top panel and the bottom panel, each a row of up to six slots on a flat background with a thin
-- border, in Flat UI Sans or the game's font. A slot shows one stream (DataStreams.lua): bag space, gold, durability, the hearthstone,
-- coordinates, frame rate and latency, friends or guild members online, the equipment set worn, or the feed of another addon through
-- LibDataBroker, when an addon that is loaded brought LibStub and LibDataBroker-1.1 with it (Flat UI ships no library, and shows feeds of the
-- kind "data source" only). A slot with nothing to show takes no room, a panel with nothing to show is hidden, and a panel makes its frames
-- only once a slot has something to show. The panels are children of UIParent, so they hide with the interface, and they are hidden in a pet
-- battle (PET_BATTLE_OPENING_START to PET_BATTLE_CLOSE, and C_PetBattles.IsInBattle at each loading screen). /flatui move places them: each is
-- in the list of the movers (FlatUIDataTop and FlatUIDataBottom) with the panel itself as its box.
-- A stream is drawn again on its events, once for a burst of them, and the few that change by themselves (coordinates, frame rate and latency,
-- the cooldown of the hearthstone) on a ticker that runs only while a shown panel holds one of them. Pointing at a slot writes its lines in
-- GameTooltip (SetOwner, SetText, AddLine, AddDoubleLine, Show, and Hide when the cursor leaves). No click casts anything: a slot of Flat UI's
-- own takes no click but the equipment set's, which opens a menu of Flat UI's own (Menus, below), and a click on a feed goes to the feed's own
-- OnClick. Every value of the game is read in pcall, and one it withholds is left out, with the count it belongs to: no part of a count is
-- shown. A stream that keeps failing is stopped alone (ns.EachPart), with a line for /flatui status.
-- The gold of the account's characters is kept in FlatUIDB.datapanels.gold by "Name - Realm", and the feeds a slot of any profile shows in
-- FlatUIDB.datapanels.feeds, so a slot keeps its feed while the addon that makes it loads after Flat UI.
-- Built on the data panels of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission: its streams, the bridge to LibDataBroker
-- and the ticker that runs only for the streams that are shown. Panels made in Edit Mode, their many looks and the secure buttons of its
-- streams are left out.

local KEY = "datapanels"
local SLOTS = 6
-- The size of the text at 100%, the room left and right of the text of a slot and above and below it.
local BASE, PAD_X, PAD_Y = 12, 8, 4
-- A burst of events is drawn once, this long after the first. The ticker's step. A live tooltip is written again this often.
local SETTLE, STEP, LIVE = 0.1, 0.5, 1
local SANS = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Fonts\\IBMPlexSans-Regular.ttf"
local GAME_FONT = "Fonts\\FRIZQT__.TTF"
local FEED = "ldb:"
local LIBRARY = "LibDataBroker-1.1"
-- The colours of the window's text-dim and of its states (PanelLook.lua), for the labels and for what a value tells.
local DIM, GOOD, WARN, BAD = "|cffa9ae9f", "|cff7ccb8f", "|cffe6b85c", "|cffe5776c"
local DIM_RGB = { 0.66, 0.68, 0.62 }
-- point: the point of the panel its handle saves, which stays where it is as the panel grows. relative, x, y: where it is with no spot saved.
local PANELS = {
	{ id = "top", mover = "FlatUIDataTop", point = "TOP", relative = "TOP", x = 0, y = -2 },
	{ id = "bottom", mover = "FlatUIDataBottom", point = "BOTTOMLEFT", relative = "BOTTOMLEFT", x = 4, y = 4 },
}
local NOTE_SANS = "Data panels: the game did not load Flat UI Sans, so the panels use the game font."
local LINE_PET = "Data panels: hidden during the pet battle."
local LINE_FEED = "Data panels: no addon has made the feed %s yet."

-- streams: by id, and order: the ids in the order a slot's list shows them (DataStreams.lua adds them). panels: by id. used: the streams a
-- shown slot holds, by id. dirty: the streams to draw again. last: when a stream with a step of its own was last drawn. feedStreams: the
-- stream of each feed, by its name. reported: the streams and feeds whose first error went to the error handler.
local P = { streams = {}, order = {}, panels = {}, used = {}, dirty = {}, last = {}, feedStreams = {}, usedFeeds = {}, reported = {}, owner = {},
	petBattle = false, DIM = DIM, GOOD = GOOD, WARN = WARN, BAD = BAD, FEED = FEED }
ns.DataPanels = P

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

-- Values the game gives ----------------------------------------------------------------------------------------------------------------

-- A value that is neither secret nor missing, or nil.
function P.Plain(value)
	if value == nil or ns.IsSecret(value) then
		return nil
	end
	return value
end

-- Up to four values of a call of the client, each nil when the client withholds it; nothing when the call is missing or raises.
function P.Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		return nil
	end
	return P.Plain(a), P.Plain(b), P.Plain(c), P.Plain(d)
end

-- Up to four values of a call of the client after true when it withholds any of them, and after false when it does not. A call that is
-- missing or raises gives false and no value. A stream whose count needs every answer shows nothing rather than a part of it.
function P.Read(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		return false
	end
	if ns.IsSecret(a) or ns.IsSecret(b) or ns.IsSecret(c) or ns.IsSecret(d) then
		return true
	end
	return false, a, b, c, d
end

-- A whole number that is not negative, or nil.
function P.Count(value)
	if ns.Finite(value) and value >= 0 then
		return math.floor(value)
	end
	return nil
end

-- A field of a table of the game or of another addon, read in pcall: nil when it is missing, withheld or cannot be read.
function P.Field(object, key)
	if type(object) ~= "table" or ns.IsSecret(object) then
		return nil
	end
	local ok, value = pcall(function()
		return object[key]
	end)
	return ok and P.Plain(value) or nil
end

-- A text a stream can show: a string that is not empty, or a number written as one.
function P.Text(value)
	if type(value) == "number" and ns.Finite(value) then
		return tostring(value)
	end
	return type(value) == "string" and value ~= "" and value or nil
end

function P.Now()
	local now = P.Ask(GetTime)
	return ns.Finite(now) and now or 0
end

-- Runs fn after a delay, or at once on a client without a timer.
function P.After(delay, fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, delay, fn) then
		return
	end
	fn()
end

function P.InCombat()
	return P.Ask(InCombatLockdown) == true
end

-- The colour code of red, green and blue.
function P.Hex(r, g, b)
	local function Byte(value)
		return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
	end
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

-- The colour code of a class by its file name (WARRIOR), or nil.
function P.ClassHex(class)
	if type(class) ~= "string" or ns.IsSecret(class) then
		return nil
	end
	local colour = P.Field(RAID_CLASS_COLORS, class)
	local r, g, b = P.Field(colour, "r"), P.Field(colour, "g"), P.Field(colour, "b")
	if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return P.Hex(r, g, b)
	end
	return nil
end

-- "Label value", the label in the dim colour.
function P.Labelled(label, value)
	return DIM .. label .. "|r " .. value
end

-- Seconds as the slot and the tooltip write them: 59m, 45s.
function P.Time(seconds)
	if seconds >= 3600 then
		return ("%dh %dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
	elseif seconds >= 60 then
		return ("%dm"):format(math.ceil(seconds / 60))
	end
	return ("%ds"):format(math.ceil(seconds))
end

-- What the account keeps for the data panels, outside every profile: { gold = { ["Name - Realm"] = { money, class } }, feeds = { name = label } }.
-- Made only with create, which only the module does while it is on; without it nil when there is none. Nil before the saved variables are loaded.
function P.Store(create)
	local db = ns.Account()
	if type(db) ~= "table" then
		return nil
	end
	if type(db.datapanels) ~= "table" then
		if not create then
			return nil
		end
		db.datapanels = {}
	end
	local store = db.datapanels
	if create then
		store.gold = type(store.gold) == "table" and store.gold or {}
		store.feeds = type(store.feeds) == "table" and store.feeds or {}
	end
	return store
end

-- A list the account keeps (gold or feeds), or an empty table to read when it has none.
function P.Kept(name)
	local store = P.Store()
	local list = store and store[name]
	return type(list) == "table" and list or {}
end

-- Streams ---------------------------------------------------------------------------------------------------------------------------------------

-- stream: { id, label = the line of a slot's list and the name of its part in /flatui status, Text = function returning the text of a slot, or
-- nil for nothing, Tip = function(fresh) returning the lines of the tooltip ({ title = text, { left, right }, { left }, ... }; fresh is false when a
-- shown tooltip is written again), sample = the widest text it shows, so the slot keeps its width as its numbers change, every = seconds between
-- two drawings while a slot shows it, or a function giving them (nil when it changes only on its events), live = true for a tooltip that is
-- written again while it is shown, events = { EVENT = true or a function run before the slot is drawn again }, Start = function run when the
-- module starts and at each loading screen }.
function P.Stream(stream)
	P.streams[stream.id] = stream
	P.order[#P.order + 1] = stream.id
	for event, fn in pairs(stream.events or {}) do
		ns.AddEvent(KEY, event, function(...)
			if type(fn) == "function" then
				P.Run(stream, fn, ...)
			end
			P.Mark(stream.id)
		end)
	end
	return stream
end

-- Runs a function of a stream as a part of the module: a stream that keeps failing is stopped alone, with a line for /flatui status, and its
-- first error also goes to the game's error handler. True and the first value it returned, or false.
function P.Run(stream, fn, ...)
	local answer
	local ok, err = ns.EachPart(KEY, stream.label, function(_, ...)
		answer = fn(...)
	end, {}, ...)
	if not ok and err ~= nil and not P.reported[stream.label] then
		P.reported[stream.label] = true
		local handler = type(geterrorhandler) == "function" and geterrorhandler()
		if type(handler) == "function" then
			pcall(handler, ("Flat UI Data panels, %s: %s"):format(stream.label, tostring(err)))
		end
	end
	return ok == true, answer
end

-- Calls a function of a feed, which is another addon's code. Its first error goes to the game's error handler.
function P.Call(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not P.reported[FEED .. name] then
		P.reported[FEED .. name] = true
		local handler = type(geterrorhandler) == "function" and geterrorhandler()
		if type(handler) == "function" then
			pcall(handler, err)
		end
	end
	return ok
end

-- LibDataBroker -----------------------------------------------------------------------------------------------------------------------------

-- The library, when an addon brought it. Nothing else of LibStub is asked for.
function P.Library()
	if P.lib == nil then
		local stub = _G.LibStub
		if stub ~= nil and not ns.IsSecret(stub) then
			local ok, lib = pcall(stub, LIBRARY, true)
			if ok and type(lib) == "table" and not ns.IsSecret(lib) then
				P.lib = lib
			end
		end
	end
	return P.lib
end

-- The data object of a feed by its name, or nil.
function P.FeedObject(name)
	local lib = P.Library()
	local get = lib and P.Field(lib, "GetDataObjectByName")
	if type(get) ~= "function" then
		return nil
	end
	local ok, object = pcall(get, lib, name)
	if ok and type(object) == "table" and not ns.IsSecret(object) then
		return object
	end
	return nil
end

-- The name a feed shows in a slot's list: its label, else its name.
function P.FeedLabel(name)
	local object = P.FeedObject(name)
	return object and P.Text(P.Field(object, "label")) or nil
end

-- The feeds of the kind "data source" that exist now: { name = label }.
function P.Feeds()
	local found = {}
	local lib = P.Library()
	local iterate = lib and P.Field(lib, "DataObjectIterator")
	if type(iterate) ~= "function" then
		return found
	end
	local ok, step, state, first = pcall(iterate, lib)
	if not ok or type(step) ~= "function" then
		return found
	end
	pcall(function()
		for name, object in step, state, first do
			if type(name) == "string" and not ns.IsSecret(name) and P.Field(object, "type") == "data source" then
				found[name] = P.Text(P.Field(object, "label")) or name
			end
		end
	end)
	return found
end

-- The stream of a feed: its text is the feed's text, else its value and label; its tooltip and its clicks are the feed's own.
function P.FeedStream(name)
	local stream = P.feedStreams[name]
	if not stream then
		stream = { id = FEED .. name, feed = name, label = name }
		function stream.Text()
			return P.FeedText(name)
		end
		P.feedStreams[name] = stream
	end
	return stream
end

local function Coords(object)
	local coords = P.Field(object, "iconCoords")
	if type(coords) ~= "table" then
		return ""
	end
	local parts = {}
	for index = 1, 4 do
		local value = P.Field(coords, index)
		if not (ns.Finite(value) and value >= 0 and value <= 1) then
			return ""
		end
		parts[index] = math.floor(value * 64 + 0.5)
	end
	return (":0:0:0:0:64:64:%d:%d:%d:%d"):format(parts[1], parts[2], parts[3], parts[4])
end

function P.FeedText(name)
	local object = P.FeedObject(name)
	if not object then
		return nil
	end
	local text = P.Text(P.Field(object, "text"))
	if not text then
		local value, label = P.Text(P.Field(object, "value")), P.Text(P.Field(object, "label"))
		if value then
			value = value .. (P.Text(P.Field(object, "suffix")) or "")
			text = label and P.Labelled(label, value) or value
		else
			text = label or name
		end
	end
	local icon = P.Field(object, "icon")
	if (type(icon) == "string" and icon ~= "" and not icon:find("[|:]")) or (ns.Finite(icon) and icon > 0) then
		local coords = Coords(object)
		text = ("|T%s%s|t %s"):format(tostring(icon), coords ~= "" and coords or ":0", text)
	end
	return (text:gsub("[\r\n]+", " "))
end

-- A feed changed one of its values: its slots are drawn again. Called for every value of every feed, so it does little.
function P.FeedChanged(_, name)
	if P.usedFeeds[name] then
		P.Mark(FEED .. name)
	end
end

-- A feed was made: a slot that waited for it shows it.
function P.FeedMade(_, name)
	if P.usedFeeds[name] == false then
		P.Soon()
	end
end

-- Listens to the library once it is found, while the module is on. The callbacks look at nothing while it is off.
function P.Listen()
	local lib = P.Library()
	if not lib or P.listening then
		return
	end
	local register = P.Field(lib, "RegisterCallback")
	if type(register) ~= "function" then
		return
	end
	local made = pcall(register, P.owner, "LibDataBroker_DataObjectCreated", function(...)
		if ns.Enabled(KEY) then
			pcall(P.FeedMade, ...)
		end
	end)
	local changed = pcall(register, P.owner, "LibDataBroker_AttributeChanged", function(...)
		if ns.Enabled(KEY) then
			pcall(P.FeedChanged, ...)
		end
	end)
	P.listening = made or changed
end

-- The feeds a slot of any profile shows are kept for the account with their label, and the others are forgotten.
function P.Remember()
	local store, db = P.Store(true), ns.Account()
	if not store then
		return
	end
	local picked = {}
	for _, saved in pairs(type(db.profiles) == "table" and db.profiles or {}) do
		local options = type(saved) == "table" and saved.options
		if type(options) == "table" then
			for _, spec in ipairs(PANELS) do
				for index = 1, SLOTS do
					local value = options[KEY .. "." .. spec.id .. index]
					if type(value) == "string" and value:sub(1, #FEED) == FEED then
						picked[value:sub(#FEED + 1)] = true
					end
				end
			end
		end
	end
	for name in pairs(picked) do
		store.feeds[name] = P.FeedLabel(name) or (type(store.feeds[name]) == "string" and store.feeds[name]) or name
	end
	for name in pairs(store.feeds) do
		if not picked[name] then
			store.feeds[name] = nil
		end
	end
end

-- The lines of a slot's list: None, the streams, then the feeds that exist now and the ones a slot keeps while their addon is not loaded.
function ns.DataPanelChoices()
	local list = { { "none", "None" } }
	for _, id in ipairs(P.order) do
		list[#list + 1] = { id, P.streams[id].label }
	end
	local feeds, rows = P.Feeds(), {}
	for name, label in pairs(feeds) do
		rows[#rows + 1] = { FEED .. name, ("Feed: %s"):format(label) }
	end
	for name, label in pairs(P.Kept("feeds")) do
		if type(name) == "string" and feeds[name] == nil then
			rows[#rows + 1] = { FEED .. name, ("Feed: %s (not loaded)"):format(type(label) == "string" and label or name) }
		end
	end
	table.sort(rows, function(a, b)
		return a[2]:lower() < b[2]:lower()
	end)
	for _, row in ipairs(rows) do
		list[#list + 1] = row
	end
	return list
end

-- The stream a slot's choice names, or nil.
function P.StreamOf(id)
	if type(id) ~= "string" or id == "none" then
		return nil
	end
	if id:sub(1, #FEED) == FEED then
		return P.FeedStream(id:sub(#FEED + 1))
	end
	return P.streams[id]
end

-- The font ------------------------------------------------------------------------------------------------------------------------------------

-- Flat UI Sans has Latin and Cyrillic letters (PanelLook.lua says the same of the options window); any other client takes the game font.
local function Covers()
	if ns.FontsLatin == nil or ns.FontsLatin() then
		return true
	end
	return P.Ask(GetLocale) == "ruRU"
end

-- The file of the game's small text, read from its font object.
local function GameFile()
	local object = _G.GameFontHighlightSmall
	if type(object) == "table" and not ns.IsSecret(object) then
		local ok, file = pcall(object.GetFont, object)
		if ok and not ns.IsSecret(file) and type(file) == "string" and file ~= "" then
			return file
		end
	end
	return GAME_FONT
end

-- The face and size of the text, and the height of a panel.
function P.Font()
	local size = BASE * Opt("textSize") / 100
	local file = Opt("font") == "sans" and Covers() and SANS or nil
	return file, size, math.ceil(size + 2 * PAD_Y)
end

-- Sets the face on a text of a slot. A face the game refuses (an answer of false, or an error) leaves the game's font, and the status says so.
function P.SetFont(text, file, size)
	if file then
		local ok, set = pcall(text.SetFont, text, file, size, "")
		if ok and (ns.IsSecret(set) or set ~= false) then
			ns.ClearNote(KEY, NOTE_SANS)
			return
		end
		ns.Note(KEY, NOTE_SANS)
	else
		ns.ClearNote(KEY, NOTE_SANS)
	end
	pcall(text.SetFont, text, GameFile(), size, "")
end

-- Panels ------------------------------------------------------------------------------------------------------------------------------------------

local function Guard(fn)
	return function(...)
		ns.Try(KEY, fn, ...)
	end
end

-- The frame, the text and the line of a slot, made with its panel's frame.
function P.MakeSlot(panel, slot)
	local frame = Own(CreateFrame("Frame", nil, panel.frame))
	frame:Hide()
	slot.frame = frame
	slot.text = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	slot.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	slot.text:SetJustifyH("CENTER")
	slot.text:SetWordWrap(false)
	pcall(slot.text.SetShadowOffset, slot.text, 1, -1)
	pcall(slot.text.SetShadowColor, slot.text, 0, 0, 0, 1)
	-- The line between this slot and the one before it.
	slot.line = Own(panel.frame:CreateTexture(nil, "ARTWORK", nil, 0))
	slot.line:Hide()
	frame:SetScript("OnEnter", Guard(function()
		P.Enter(slot)
	end))
	frame:SetScript("OnLeave", Guard(function()
		P.Leave(slot)
	end))
	frame:SetScript("OnHide", Guard(function()
		P.Leave(slot)
		if P.MenuOpen(slot) then
			P.CloseMenu()
		end
	end))
	frame:SetScript("OnMouseDown", function(_, button)
		slot.down = button
	end)
	frame:SetScript("OnMouseUp", Guard(function(_, button)
		local pressed = slot.down == button
		slot.down = nil
		if pressed then
			P.Click(slot, button)
		end
	end))
end

-- A panel: its slots, and no frame until one of them has something to show, so a panel that shows nothing makes nothing.
function P.Panel(spec)
	local panel = P.panels[spec.id]
	if not panel then
		panel = { spec = spec, slots = {} }
		for index = 1, SLOTS do
			panel.slots[index] = { panel = panel, index = index }
		end
		P.panels[spec.id] = panel
	end
	return panel
end

-- The frame of a panel, on UIParent, with a flat background and a thin border, and the frames of its slots.
function P.Build(panel)
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	frame:SetFrameStrata("LOW")
	frame:SetSize(1, 1)
	frame:Hide()
	panel.frame = frame
	panel.outline = ns.Outline(frame, frame, true)
	for _, slot in ipairs(panel.slots) do
		P.MakeSlot(panel, slot)
	end
end

-- The text a slot's stream gives now, or nil.
function P.TextOf(slot)
	local stream = P.StreamOf(slot.id)
	if stream and not ns.PartStopped(KEY, stream.label) then
		local ok, answer = P.Run(stream, stream.Text)
		return ok and P.Text(answer) or nil
	end
	return nil
end

-- The text of a slot is written again. True when the room it takes changed.
function P.Draw(slot, text)
	local stream = P.StreamOf(slot.id)
	if text == nil or stream == nil then
		slot.text:SetText("")
		local changed = slot.width ~= nil
		slot.width, slot.shownText = nil, nil
		return changed
	end
	if text == slot.shownText and slot.width then
		return false
	end
	local width = P.Width(slot, stream.sample)
	slot.text:SetText(text)
	local ok, measured = pcall(slot.text.GetStringWidth, slot.text)
	if ns.Finite(measured) and ok then
		width = math.max(width, measured)
	elseif slot.width then
		-- A width the game does not give keeps the last one.
		width = math.max(width, slot.width - 2 * PAD_X)
	else
		width = math.max(width, #text * slot.size / 2)
	end
	width = math.ceil(width) + 2 * PAD_X
	slot.shownText = text
	local changed = slot.width ~= width
	slot.width = width
	return changed
end

-- The width of the widest text a stream shows, measured once for each face and size on the slot's own text.
function P.Width(slot, sample)
	if type(sample) ~= "string" then
		return 0
	end
	local key = sample .. "|" .. tostring(P.fontKey)
	P.samples = P.samples or {}
	if P.samples[key] == nil then
		slot.text:SetText(sample)
		local ok, width = pcall(slot.text.GetStringWidth, slot.text)
		P.samples[key] = ok and ns.Finite(width) and width or #sample * slot.size / 2
	end
	return P.samples[key]
end

-- Lays the slots of a panel out from the left, each as wide as its text, with a thin line between two. A panel with no slot to show is hidden.
function P.Layout(panel)
	local frame, height = panel.frame, P.height
	local x, shown = 0, 0
	local line = Opt("background")
	local r, g, b = ns.BorderRGB()
	local thin = ns.Pixels(frame, 1)
	for _, slot in ipairs(panel.slots) do
		if slot.width then
			slot.frame:ClearAllPoints()
			slot.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
			slot.frame:SetSize(slot.width, height)
			slot.frame:Show()
			if shown > 0 and line then
				slot.line:ClearAllPoints()
				slot.line:SetPoint("TOP", frame, "TOPLEFT", x, -PAD_Y)
				slot.line:SetSize(thin, math.max(height - 2 * PAD_Y, 1))
				slot.line:SetColorTexture(r, g, b, 0.6)
				slot.line:Show()
			else
				slot.line:Hide()
			end
			x = x + slot.width
			shown = shown + 1
		else
			slot.frame:Hide()
			slot.line:Hide()
		end
	end
	panel.shown = shown > 0
	if panel.shown then
		frame:SetSize(x, height)
		frame:Show()
	else
		frame:Hide()
	end
end

-- The game's widgets at the top of the screen (the scores of a battleground or of a world PvP zone: UIWidgetTopCenterContainerFrame, TOP 0,-15
-- of UIParent on MEDIUM, Blizzard_UIWidgetTopCenterFrame.xml:3-7), while they are where the game puts them; nil once the movers placed them.
local function TopWidgets()
	local widgets = _G.UIWidgetTopCenterContainerFrame
	if ns.Forbidden(widgets) then
		return nil
	end
	if ns.Enabled("movers") and type(ns.MoverSaved) == "function" and ns.MoverSaved("UIWidgetTopCenterContainerFrame") then
		return nil
	end
	return widgets
end

-- Puts a panel at the spot of its handle, else where it starts. A handle that was centred keeps the panel on the middle of the screen at any width.
-- With no spot the top panel hangs under the top widgets, 4 below their bottom as the game hangs its GhostFrame (GhostFrame.lua:21), so a
-- battleground's scores push it down instead of being drawn over it. Only Flat UI's own frame gets a point.
function P.Place(panel)
	local spec, frame = panel.spec, panel.frame
	-- The handle has no box of its own, so the panel hangs from the point its spot was saved by: a centred handle keeps the panel on the middle
	-- of the screen at any width, and a nudge from there moves it by the nudge.
	local spots = type(ns.Spots) == "function" and ns.Spots()
	local entry = type(spots) == "table" and type(ns.CleanSpot) == "function" and ns.CleanSpot(spots[spec.mover]) or nil
	local point = entry and entry.point or spec.point
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(spec.mover, point)
	end
	local widgets = not x and spec.id == "top" and TopWidgets() or nil
	local key = x and ("%s:%.2f:%.2f"):format(point, x, y) or widgets and "widgets" or "start"
	if panel.placed == key then
		return
	end
	panel.placed = key
	frame:ClearAllPoints()
	if x then
		frame:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
	elseif not (widgets and pcall(frame.SetPoint, frame, "TOP", widgets, "BOTTOM", 0, -4)) then
		frame:ClearAllPoints()
		frame:SetPoint(spec.point, UIParent, spec.relative, spec.x, spec.y)
	end
end

-- Sets up the slots of a panel from its rows and draws them, or hides the panel.
function P.Fill(panel, wanted)
	if not wanted then
		for _, slot in ipairs(panel.slots) do
			slot.id, slot.feed, slot.width, slot.shownText = nil, nil, nil, nil
		end
		panel.shown = false
		if panel.frame then
			panel.frame:Hide()
		end
		return
	end
	local texts, any = {}, false
	for index, slot in ipairs(panel.slots) do
		local id = Opt(panel.spec.id .. index)
		id = id ~= "none" and id or nil
		if slot.id ~= id then
			slot.shownText = nil
		end
		slot.id = id
		slot.feed = id and id:sub(1, #FEED) == FEED and id:sub(#FEED + 1) or nil
		texts[index] = P.TextOf(slot)
		any = any or texts[index] ~= nil
	end
	if not panel.frame then
		if not any then
			panel.shown = false
			return
		end
		P.Build(panel)
	end
	local file, size = P.Font()
	local tips = Opt("tooltips") == true
	for index, slot in ipairs(panel.slots) do
		if slot.fontKey ~= P.fontKey then
			P.SetFont(slot.text, file, size)
			slot.fontKey, slot.size, slot.shownText = P.fontKey, size, nil
		end
		P.Draw(slot, texts[index])
		-- A feed and a stream with a click of its own (Equipment set) keep their clicks while the tooltips are off.
		local stream = P.StreamOf(slot.id)
		slot.frame:EnableMouse(slot.id ~= nil and (tips or slot.feed ~= nil or (stream ~= nil and type(stream.Click) == "function")))
	end
	ns.SetOutline(panel.outline, Opt("background") == true, Opt("background") == true)
	P.Layout(panel)
	P.Place(panel)
end

-- The streams the shown slots hold, and the feeds they show or wait for (false while the library has no object of that name).
function P.Used()
	local used, feeds = {}, {}
	for _, panel in pairs(P.panels) do
		if panel.wanted then
			for _, slot in ipairs(panel.slots) do
				if slot.id then
					used[slot.id] = true
					if slot.feed then
						feeds[slot.feed] = P.FeedObject(slot.feed) ~= nil
					end
				end
			end
		end
	end
	P.used, P.usedFeeds = used, feeds
end

function P.Refresh()
	local on = ns.Enabled(KEY)
	if on then
		P.Listen()
		P.Remember()
	end
	local file, size, height = P.Font()
	P.fontKey, P.height, P.size = ("%s:%.2f"):format(tostring(file), size), height, size
	for _, spec in ipairs(PANELS) do
		local wanted = on and Opt(spec.id) == true and not P.petBattle
		local panel = wanted and P.Panel(spec) or P.panels[spec.id]
		if panel then
			panel.wanted = wanted
			P.Fill(panel, wanted)
		end
	end
	-- A menu stays open only while the module is on and its slot still shows the stream that opened it.
	local menu = P.menu
	if menu and menu.slot and not (on and menu.slot.panel.wanted and menu.slot.width and P.StreamOf(menu.slot.id) == menu.stream) then
		P.CloseMenu()
	end
	P.Used()
	P.dirty = {}
	P.Ticker()
end

-- A refresh a moment later, for a burst of changes.
function P.Soon()
	if P.soon then
		return
	end
	P.soon = true
	P.After(SETTLE, function()
		P.soon = false
		if ns.Enabled(KEY) then
			ns.Try(KEY, P.Refresh)
		end
	end)
end

-- Drawing again --------------------------------------------------------------------------------------------------------------------------------

-- A stream changed: its slots are drawn again a moment later, once for a burst of events.
function P.Mark(id)
	if not P.used[id] then
		return
	end
	P.dirty[id] = true
	if P.waiting then
		return
	end
	P.waiting = true
	P.After(SETTLE, function()
		P.waiting = false
		ns.Try(KEY, P.Flush)
	end)
end

-- Draws the slots of the streams that changed, lays out the panels whose slots took another width and writes again a tooltip of theirs.
function P.Flush()
	local dirty = P.dirty
	P.dirty = {}
	if not ns.Enabled(KEY) or next(dirty) == nil then
		return
	end
	for _, panel in pairs(P.panels) do
		if panel.wanted and not panel.frame then
			-- A panel that showed nothing yet is made once a slot of it has something to show.
			for _, slot in ipairs(panel.slots) do
				if slot.id and dirty[slot.id] and P.TextOf(slot) then
					P.Fill(panel, true)
					break
				end
			end
		elseif panel.wanted then
			local moved = false
			for _, slot in ipairs(panel.slots) do
				if slot.id and dirty[slot.id] then
					moved = P.Draw(slot, P.TextOf(slot)) or moved
					if slot.over then
						P.Retip(slot)
					end
				end
			end
			if moved then
				P.Layout(panel)
			end
		end
	end
	P.Ticker()
end

-- The step of a stream: seconds between two drawings while it is shown, or nil.
local function Every(stream)
	local every = stream and stream.every
	if type(every) == "function" then
		local ok, seconds = pcall(every)
		every = ok and seconds or nil
	end
	return ns.Finite(every) and every > 0 and every or nil
end

local function Visible(frame)
	local ok, visible = pcall(frame.IsVisible, frame)
	return ok and not ns.IsSecret(visible) and visible == true
end

-- True while a shown panel holds a stream with a step of its own, or a live tooltip of one of its slots is shown. A panel hidden with the
-- interface (Alt+Z) keeps the ticker, which draws nothing then.
function P.NeedsTicker()
	if not ns.Enabled(KEY) then
		return false
	end
	for _, panel in pairs(P.panels) do
		if panel.wanted and panel.shown then
			for _, slot in ipairs(panel.slots) do
				local stream = P.StreamOf(slot.id)
				if stream and (Every(stream) or (slot.over and stream.live)) then
					return true
				end
			end
		end
	end
	return false
end

-- Starts the ticker while something needs it and stops it once nothing does.
function P.Ticker()
	local want = P.NeedsTicker()
	if want and not P.ticker then
		local token = {}
		P.ticker = token
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, STEP, function()
				ns.Try(KEY, P.Tick)
			end)
			token.handle = ok and ticker or nil
		end
		if not token.handle then
			-- A client without NewTicker: a timer that sets the next one while the token is the ticker. With no timer at all there is no ticker.
			local function Later(fn)
				return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, STEP, fn)
			end
			local function Again()
				if P.ticker == token then
					ns.Try(KEY, P.Tick)
					if P.ticker == token and not Later(Again) then
						P.ticker = nil
					end
				end
			end
			if not Later(Again) then
				P.ticker = nil
			end
		end
	elseif not want and P.ticker then
		local handle = P.ticker.handle
		P.ticker = nil
		if handle and type(handle.Cancel) == "function" then
			pcall(handle.Cancel, handle)
		end
	end
end

function P.Tick()
	if not P.NeedsTicker() then
		P.Ticker()
		return
	end
	-- Nothing is drawn while no panel is on screen, as with the interface hidden.
	local seen = false
	for _, panel in pairs(P.panels) do
		seen = seen or (panel.wanted and panel.shown and panel.frame ~= nil and Visible(panel.frame))
	end
	if not seen then
		return
	end
	local now = P.Now()
	for id in pairs(P.used) do
		local every = Every(P.StreamOf(id))
		if every and now - (P.last[id] or -math.huge) >= every - 0.05 then
			P.last[id] = now
			P.dirty[id] = true
		end
	end
	P.Flush()
	for _, panel in pairs(P.panels) do
		for _, slot in ipairs(panel.slots) do
			local stream = P.StreamOf(slot.id)
			if slot.over and stream and stream.live and now - (slot.tipped or 0) >= LIVE - 0.05 then
				P.Retip(slot)
			end
		end
	end
end

-- Tooltips and clicks -------------------------------------------------------------------------------------------------------------------------

local function Tooltip()
	local tip = _G.GameTooltip
	if tip == nil or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

-- Whether GameTooltip is the slot's and the cursor is still over the slot.
local function Owned(slot)
	local tip = Tooltip()
	if not tip then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, slot.frame)
	return ok and not ns.IsSecret(owned) and owned == true
end

-- Where a tooltip opens: below a panel in the upper half of the screen, above one in the lower half.
function P.Anchor(panel)
	local ok, _, y = pcall(panel.frame.GetCenter, panel.frame)
	local okHeight, height = pcall(UIParent.GetHeight, UIParent)
	if ok and okHeight and ns.Finite(y) and ns.Finite(height) then
		return y > height / 2 and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
	end
	return panel.spec.point:find("TOP", 1, true) and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
end

-- Writes the lines of a stream's tooltip: the title, then { left, right } as two columns (the left in the dim colour) or { left } alone.
function P.Tip(slot, fresh)
	local stream, tip = P.StreamOf(slot.id), Tooltip()
	if not (stream and stream.Tip and tip) or ns.PartStopped(KEY, stream.label) then
		return
	end
	local ok, lines = P.Run(stream, stream.Tip, fresh)
	if not ok or type(lines) ~= "table" then
		return
	end
	slot.tipped = P.Now()
	pcall(function()
		tip:SetOwner(slot.frame, P.Anchor(slot.panel))
		tip:SetText(lines.title or stream.label, 1, 1, 1)
		for _, line in ipairs(lines) do
			if line[2] ~= nil then
				tip:AddDoubleLine(line[1], line[2], DIM_RGB[1], DIM_RGB[2], DIM_RGB[3], 1, 1, 1)
			else
				tip:AddLine(line[1] or " ", 1, 1, 1)
			end
		end
		tip:Show()
	end)
end

-- A tooltip that is shown is written again, while it is still the slot's.
function P.Retip(slot)
	if slot.over and not slot.feed and Opt("tooltips") and Owned(slot) then
		P.Tip(slot, false)
	end
end

-- The tooltip of a feed: its OnEnter when it has one, which shows its own, else GameTooltip with the lines of its OnTooltipShow or its tooltip text.
function P.FeedEnter(slot)
	local name, object = slot.feed, P.FeedObject(slot.feed)
	if not object then
		return
	end
	local enter = P.Field(object, "OnEnter")
	if type(enter) == "function" then
		slot.entered = P.Call(name, enter, slot.frame) and object or nil
		return
	end
	local tip = Tooltip()
	if not tip then
		return
	end
	local show = P.Field(object, "OnTooltipShow")
	pcall(tip.SetOwner, tip, slot.frame, P.Anchor(slot.panel))
	if type(show) == "function" then
		P.Call(name, show, tip)
	else
		pcall(tip.SetText, tip, P.Text(P.Field(object, "tooltiptext")) or P.Text(P.Field(object, "label")) or name, 1, 1, 1, 1, true)
	end
	pcall(tip.Show, tip)
end

function P.Enter(slot)
	slot.over = true
	-- The slot's menu lies where its tooltip would.
	if not slot.id or not Opt("tooltips") or P.MenuOpen(slot) then
		return
	end
	if slot.feed then
		P.FeedEnter(slot)
	else
		P.Tip(slot, true)
		P.Ticker()
	end
end

function P.Leave(slot)
	if not slot.over then
		return
	end
	slot.over, slot.down = false, nil
	local entered = slot.entered
	slot.entered = nil
	if entered then
		local leave = P.Field(entered, "OnLeave")
		if type(leave) == "function" then
			P.Call(slot.feed or "", leave, slot.frame)
		end
	end
	if Owned(slot) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
end

-- A click on a slot: a feed's own OnClick, with the slot and the button, or the Click of a stream of Flat UI's own that has one (Equipment
-- set), with the slot and the button. Any other slot of Flat UI's own does nothing.
function P.Click(slot, button)
	if not slot.feed then
		local stream = P.StreamOf(slot.id)
		if stream and type(stream.Click) == "function" and not ns.PartStopped(KEY, stream.label) then
			P.Run(stream, stream.Click, slot, button)
		end
		return
	end
	local object = P.FeedObject(slot.feed)
	local click = object and P.Field(object, "OnClick")
	if type(click) == "function" then
		P.Call(slot.feed, click, slot.frame, button)
	end
end

-- Menus -------------------------------------------------------------------------------------------------------------------------------------------

-- A menu of Flat UI's own that a stream opens from its slot (Equipment set): a title and a column of lines in the face and size of the panels, on
-- a flat background with a thin border, under the slot when the panel is in the upper half of the screen and over it in the lower half, as its
-- tooltip opens. A line is { text, pick = function, inert = true for a line that does nothing }. A click on a line closes the menu and runs its
-- pick as a part of the stream. A press anywhere else (GLOBAL_MOUSE_DOWN, heard on a frame of Flat UI's own only while the menu is shown), a
-- second click on the slot, the start of a fight, the slot hiding or showing another stream and the module going off close it. Nothing of the
-- game's is used for it: neither the game's menus nor its list of the windows that Escape closes.
local EDGE = 4
-- The light behind the line under the cursor.
local LIGHT = { 1, 1, 1, 0.08 }

local function Over(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and not ns.IsSecret(over) and over == true
end

-- True while the menu is open, on that slot when one is given.
function P.MenuOpen(slot)
	local menu = P.menu
	return menu ~= nil and menu.slot ~= nil and (slot == nil or menu.slot == slot)
end

function P.CloseMenu()
	local menu = P.menu
	if not (menu and menu.slot) then
		return
	end
	menu.slot, menu.stream = nil, nil
	pcall(menu.listener.UnregisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
	menu.frame:Hide()
end

-- A press of a mouse button while the menu is open: one outside the menu and its slot closes it. A press on the slot is the slot's own click,
-- which closes the menu as the button comes up.
local function Pressed()
	local menu = P.menu
	if menu and menu.slot and not Over(menu.frame) and not Over(menu.slot.frame) then
		P.CloseMenu()
	end
end

local function MenuFrame()
	if P.menu then
		return P.menu
	end
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	frame:SetFrameStrata("DIALOG")
	frame:SetSize(1, 1)
	-- A click on the edge of the menu stays on it.
	frame:EnableMouse(true)
	pcall(frame.SetClampedToScreen, frame, true)
	frame:Hide()
	local menu = { frame = frame, outline = ns.Outline(frame, frame, true), lines = {} }
	menu.title = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	menu.title:SetJustifyH("LEFT")
	menu.title:SetWordWrap(false)
	menu.listener = Own(CreateFrame("Frame"))
	menu.listener:SetScript("OnEvent", Guard(Pressed))
	P.menu = menu
	return menu
end

local function MenuLine(menu, index)
	local line = menu.lines[index]
	if line then
		return line
	end
	local frame = Own(CreateFrame("Frame", nil, menu.frame))
	frame:EnableMouse(true)
	line = { frame = frame }
	line.light = Own(frame:CreateTexture(nil, "ARTWORK", nil, 0))
	line.light:SetAllPoints(frame)
	line.light:SetColorTexture(LIGHT[1], LIGHT[2], LIGHT[3], LIGHT[4])
	line.light:Hide()
	line.text = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	line.text:SetPoint("LEFT", frame, "LEFT", PAD_X, 0)
	line.text:SetJustifyH("LEFT")
	line.text:SetWordWrap(false)
	pcall(line.text.SetShadowOffset, line.text, 1, -1)
	pcall(line.text.SetShadowColor, line.text, 0, 0, 0, 1)
	frame:SetScript("OnEnter", function()
		line.light:SetShown(line.item ~= nil and not line.item.inert)
	end)
	frame:SetScript("OnLeave", function()
		line.light:Hide()
	end)
	frame:SetScript("OnMouseDown", function(_, button)
		line.down = button
	end)
	frame:SetScript("OnMouseUp", Guard(function(_, button)
		local pressed, item, stream = line.down == button, line.item, menu.stream
		line.down = nil
		if not pressed or button ~= "LeftButton" or not item then
			return
		end
		P.CloseMenu()
		if not item.inert and stream and type(item.pick) == "function" and not ns.PartStopped(KEY, stream.label) then
			P.Run(stream, item.pick)
		end
	end))
	menu.lines[index] = line
	return line
end

-- The width of a text of the menu: measured, else guessed from its length.
local function Measure(text, value, size)
	local ok, width = pcall(text.GetStringWidth, text)
	if ok and ns.Finite(width) then
		return width
	end
	return #value * size / 2
end

-- Opens the menu of a stream on its slot with a title and lines, or closes it when it is open on that slot already. True when it opened.
function P.OpenMenu(slot, stream, title, items)
	if P.MenuOpen(slot) then
		P.CloseMenu()
		return false
	end
	if type(items) ~= "table" or #items == 0 or not slot.frame then
		return false
	end
	local menu = MenuFrame()
	P.CloseMenu()
	local file, size = P.Font()
	local height = P.height or math.ceil(size + 2 * PAD_Y)
	P.SetFont(menu.title, file, size)
	menu.title:SetText(DIM .. title .. "|r")
	menu.title:ClearAllPoints()
	menu.title:SetPoint("LEFT", menu.frame, "TOPLEFT", PAD_X, -(EDGE + height / 2))
	local width, y = Measure(menu.title, title, size), EDGE + height
	for index, item in ipairs(items) do
		local line = MenuLine(menu, index)
		line.item = item
		P.SetFont(line.text, file, size)
		line.text:SetText(item.text)
		width = math.max(width, Measure(line.text, item.text, size))
		line.light:Hide()
		line.frame:ClearAllPoints()
		line.frame:SetPoint("TOPLEFT", menu.frame, "TOPLEFT", 0, -y)
		line.frame:SetPoint("TOPRIGHT", menu.frame, "TOPRIGHT", 0, -y)
		line.frame:SetHeight(height)
		line.frame:Show()
		y = y + height
	end
	for index = #items + 1, #menu.lines do
		menu.lines[index].item = nil
		menu.lines[index].frame:Hide()
	end
	menu.frame:SetSize(math.ceil(width) + 2 * PAD_X, y + EDGE)
	menu.frame:ClearAllPoints()
	if P.Anchor(slot.panel) == "ANCHOR_BOTTOM" then
		menu.frame:SetPoint("TOP", slot.frame, "BOTTOM", 0, -2)
	else
		menu.frame:SetPoint("BOTTOM", slot.frame, "TOP", 0, 2)
	end
	ns.SetOutline(menu.outline, true, true)
	menu.slot, menu.stream = slot, stream
	menu.frame:Show()
	pcall(menu.listener.RegisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
	-- The slot's tooltip would lie over the menu.
	if Owned(slot) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
	return true
end

-- The module --------------------------------------------------------------------------------------------------------------------------------------

local function EachStream(method)
	for _, id in ipairs(P.order) do
		local stream = P.streams[id]
		if type(stream[method]) == "function" and not ns.PartStopped(KEY, stream.label) then
			P.Run(stream, stream[method])
		end
	end
end

-- The game says whether a pet battle is on (C_PetBattles.IsInBattle); a client that does not say keeps what the events said.
local function PetBattleNow()
	local battles = _G.C_PetBattles
	local now = type(battles) == "table" and not ns.IsSecret(battles) and P.Ask(battles.IsInBattle) or nil
	if now == true or now == false then
		P.petBattle = now
	end
end

-- At the start and at each loading screen: the panels are drawn, then each stream does what it does once (the gold is kept, the guild roster
-- asked for), which a slot it holds needs to be drawn first for.
function P.Start()
	PetBattleNow()
	P.Refresh()
	EachStream("Start")
end

P.OnWorld = P.Start

function P.PetBattle(on)
	if P.petBattle ~= on then
		P.petBattle = on
		P.Refresh()
	end
end

-- Another addon loaded: the library may have come with it, and a slot may wait for its feed.
function P.OnAddon()
	if P.lib == nil and P.Library() then
		P.Soon()
	elseif P.lib then
		for _, made in pairs(P.usedFeeds) do
			if made == false then
				P.Soon()
				break
			end
		end
	end
end

function P.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if P.petBattle then
		lines[#lines + 1] = LINE_PET
	end
	for name, made in pairs(P.usedFeeds) do
		if made == false then
			local label = P.Kept("feeds")[name]
			label = type(label) == "string" and label or name
			lines[#lines + 1] = LINE_FEED:format(label)
		end
	end
	return lines
end

-- The movers: the frame of a shown panel is its handle's box and the frame the handle hangs from.
local function Row(id)
	local panel = P.panels[id]
	if panel and panel.frame and panel.wanted and panel.shown and ns.Enabled(KEY) then
		return { panel.frame }, panel.frame
	end
	return {}
end

function ns.DataPanelTopRow()
	return Row("top")
end

function ns.DataPanelBottomRow()
	return Row("bottom")
end

-- The movers set or put back the spot of a panel.
function ns.DataPanelsMoved()
	for _, panel in pairs(P.panels) do
		panel.placed = nil
		if panel.wanted and panel.frame then
			ns.Try(KEY, P.Place, panel)
		end
	end
end

ns.Register(KEY, {
	label = "Data panels",
	counted = false,
	Start = P.Start,
	Refresh = P.Refresh,
	Resized = P.Refresh,
	Status = P.Status,
	events = {
		PLAYER_ENTERING_WORLD = P.OnWorld,
		PET_BATTLE_OPENING_START = function()
			P.PetBattle(true)
		end,
		PET_BATTLE_CLOSE = function()
			P.PetBattle(false)
		end,
		ADDON_LOADED = P.OnAddon,
		-- Nothing is offered in a fight (DataStreams.lua, Equipment set).
		PLAYER_REGEN_DISABLED = P.CloseMenu,
	},
})
