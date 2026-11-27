local ADDON_NAME, ns = ...

local KEY = "datapanels"
local SLOTS = 6
local BASE, PAD_X, PAD_Y = 12, 8, 4
local SETTLE, STEP, LIVE = 0.1, 0.5, 1
local HOVER = 0.1
local RISE, FALL = 0.1, 0.3
local HOVER_LIGHT = { 1, 1, 1, 0.07 }
local STRATA = { low = "LOW", medium = "MEDIUM", high = "HIGH" }
local SANS = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Fonts\\IBMPlexSans-Regular.ttf"
local GAME_FONT = "Fonts\\FRIZQT__.TTF"
local FEED = "ldb:"
local LIBRARY = "LibDataBroker-1.1"
local DIM, GOOD, WARN, BAD = "|cffa9ae9f", "|cff7ccb8f", "|cffe6b85c", "|cffe5776c"
local DIM_RGB = { 0.66, 0.68, 0.62 }
local PANELS = {
	{ id = "top", mover = "FlatUIDataTop", point = "TOP", relative = "TOP", x = 0, y = -2 },
	{ id = "bottom", mover = "FlatUIDataBottom", point = "BOTTOMLEFT", relative = "BOTTOMLEFT", x = 4, y = 4 },
}
local NOTE_SANS = "Data panels: the game did not load Flat UI Sans, so the panels use the game font."
local LINE_PET = "Data panels: hidden during the pet battle."
local LINE_FEED = "Data panels: no addon has made the feed %s yet."

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

function P.Plain(value)
	if value == nil or ns.IsSecret(value) then
		return nil
	end
	return value
end

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

function P.Count(value)
	if ns.Finite(value) and value >= 0 then
		return math.floor(value)
	end
	return nil
end

function P.Field(object, key)
	if type(object) ~= "table" or ns.IsSecret(object) then
		return nil
	end
	local ok, value = pcall(function()
		return object[key]
	end)
	return ok and P.Plain(value) or nil
end

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

function P.After(delay, fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, delay, fn) then
		return
	end
	fn()
end

function P.InCombat()
	return P.Ask(InCombatLockdown) == true
end

function P.Hex(r, g, b)
	local function Byte(value)
		return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
	end
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

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

function P.Labelled(label, value)
	return DIM .. label .. "|r " .. value
end

function P.Time(seconds)
	if seconds >= 3600 then
		return ("%dh %dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
	elseif seconds >= 60 then
		return ("%dm"):format(math.ceil(seconds / 60))
	end
	return ("%ds"):format(math.ceil(seconds))
end

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

function P.Kept(name)
	local store = P.Store()
	local list = store and store[name]
	return type(list) == "table" and list or {}
end

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

function P.FeedLabel(name)
	local object = P.FeedObject(name)
	return object and P.Text(P.Field(object, "label")) or nil
end

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

function P.FeedChanged(_, name)
	if P.usedFeeds[name] then
		P.Mark(FEED .. name)
	end
end

function P.FeedMade(_, name)
	if P.usedFeeds[name] == false then
		P.Soon()
	end
end

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

function P.StreamOf(id)
	if type(id) ~= "string" or id == "none" then
		return nil
	end
	if id:sub(1, #FEED) == FEED then
		return P.FeedStream(id:sub(#FEED + 1))
	end
	return P.streams[id]
end

local function Covers()
	if ns.FontsLatin == nil or ns.FontsLatin() then
		return true
	end
	return P.Ask(GetLocale) == "ruRU"
end

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

function P.Font()
	local size = BASE * Opt("textSize") / 100
	local file = Opt("font") == "sans" and Covers() and SANS or nil
	return file, size, math.ceil(size + 2 * PAD_Y), ns.OUTLINE_FLAGS[Opt("outline")] or ""
end

function P.SetFont(text, file, size, flags)
	flags = type(flags) == "string" and flags or ""
	if file then
		local ok, set = pcall(text.SetFont, text, file, size, flags)
		if ok and (ns.IsSecret(set) or set ~= false) then
			ns.ClearNote(KEY, NOTE_SANS)
			return
		end
		ns.Note(KEY, NOTE_SANS)
	else
		ns.ClearNote(KEY, NOTE_SANS)
	end
	pcall(text.SetFont, text, GameFile(), size, flags)
end

function P.TextStyle()
	local shadow = Opt("shadow") == true
	local r, g, b = 1, 1, 1
	local colour = Opt("textColour")
	if colour == "class" then
		local cr, cg, cb = ns.ClassColour()
		if cr then
			r, g, b = cr, cg, cb
		end
	elseif colour == "custom" then
		r, g, b = ns.Colour(KEY .. ".textCustom")
	end
	return { shadow = shadow, r = r, g = g, b = b, key = ("%s:%.3f:%.3f:%.3f"):format(shadow and "shadow" or "plain", r, g, b) }
end

function P.Style(slot)
	local style, text = P.style, slot.text
	if not style or not text or slot.styleKey == style.key then
		return
	end
	slot.styleKey = style.key
	pcall(text.SetShadowOffset, text, style.shadow and 1 or 0, style.shadow and -1 or 0)
	pcall(text.SetShadowColor, text, 0, 0, 0, style.shadow and 1 or 0)
	pcall(text.SetTextColor, text, style.r, style.g, style.b, 1)
end

local function Guard(fn)
	return function(...)
		ns.Try(KEY, fn, ...)
	end
end

function P.MakeSlot(panel, slot)
	local frame = Own(CreateFrame("Frame", nil, panel.frame))
	frame:Hide()
	slot.frame = frame
	slot.text = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	slot.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	slot.text:SetJustifyH("CENTER")
	slot.text:SetWordWrap(false)
	P.Style(slot)
	slot.line = Own(panel.frame:CreateTexture(nil, "ARTWORK", nil, 0))
	slot.line:Hide()
	slot.hover = Own(frame:CreateTexture(nil, "BACKGROUND", nil, 1))
	slot.hover:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	slot.hover:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	slot.hover:SetColorTexture(HOVER_LIGHT[1], HOVER_LIGHT[2], HOVER_LIGHT[3], HOVER_LIGHT[4])
	slot.hover:Hide()
	frame:SetScript("OnEnter", Guard(function()
		P.Secure(panel)
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
		slot.hover:Hide()
		local float = slot.float
		if float then
			pcall(float.group.Stop, float.group)
			float.holder:Hide()
			float.sum = 0
		end
	end))
	frame:SetScript("OnMouseDown", function(_, button)
		slot.down = button
	end)
	frame:SetScript("OnMouseUp", Guard(function(self, button)
		local pressed = slot.down == button
		slot.down = nil
		local ok, over = pcall(self.IsMouseOver, self)
		if pressed and (not ok or ns.IsSecret(over) or over ~= false) then
			P.Click(slot, button)
		end
	end))
end

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

function P.Build(panel)
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	panel.strata = STRATA[Opt("strata")] or "LOW"
	frame:SetFrameStrata(panel.strata)
	frame:SetSize(1, 1)
	frame:Hide()
	panel.frame, panel.alpha = frame, 1
	panel.ease = Guard(function()
		P.Ease(panel)
	end)
	panel.outline = ns.Outline(frame, frame, true)
	for _, slot in ipairs(panel.slots) do
		P.MakeSlot(panel, slot)
	end
end

function P.TextOf(slot)
	local stream = P.StreamOf(slot.id)
	if stream and not ns.PartStopped(KEY, stream.label) then
		local ok, answer = P.Run(stream, stream.Text)
		local text = ok and P.Text(answer) or nil
		local mode = ns.TestMode
		if text == nil and type(stream.sample) == "string" and mode ~= nil and mode.IsOn() == true then
			return stream.sample
		end
		return text
	end
	return nil
end

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
		width = math.max(width, slot.width - 2 * PAD_X)
	else
		width = math.max(width, #(text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * slot.size / 2)
	end
	width = math.ceil(width) + 2 * PAD_X
	slot.shownText = text
	local changed = slot.width ~= width
	slot.width = width
	return changed
end

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

function P.Layout(panel)
	local frame, height = panel.frame, P.height
	local x, shown = 0, 0
	local line = Opt("background")
	local r, g, b = ns.BorderRGB()
	local thin = ns.Pixels(frame, 1)
	local need, count = 0, 0
	for _, slot in ipairs(panel.slots) do
		if slot.width then
			need, count = need + slot.width, count + 1
		end
	end
	local wide = Opt(panel.spec.id .. "Width")
	local extra = count > 0 and ns.Finite(wide) and wide > need and math.floor(wide - need + 0.5) or 0
	local each = count > 0 and math.floor(extra / count) or 0
	local left = extra - each * count
	for _, slot in ipairs(panel.slots) do
		if slot.width then
			local width = slot.width + each + (shown < left and 1 or 0)
			slot.frame:ClearAllPoints()
			slot.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
			slot.frame:SetSize(width, height)
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
			x = x + width
			shown = shown + 1
		else
			slot.frame:Hide()
			slot.line:Hide()
		end
	end
	panel.shown = shown > 0
	if panel.shown then
		frame:SetSize(x, height)
		if not frame:IsShown() then
			panel.snap = true
		end
		frame:Show()
	else
		frame:Hide()
	end
	P.Secure(panel)
end

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

function P.Place(panel)
	local spec, frame = panel.spec, panel.frame
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
	P.Secure(panel)
end

function P.Fill(panel, wanted)
	if not wanted then
		for _, slot in ipairs(panel.slots) do
			slot.id, slot.feed, slot.width, slot.shownText = nil, nil, nil, nil
		end
		panel.shown = false
		if panel.frame then
			panel.frame:Hide()
		end
		P.Secure(panel)
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
	local file, size, _, flags = P.Font()
	local tips = Opt("tooltips") == true
	for index, slot in ipairs(panel.slots) do
		if slot.fontKey ~= P.fontKey then
			P.SetFont(slot.text, file, size, flags)
			slot.fontKey, slot.size, slot.shownText = P.fontKey, size, nil
		end
		P.Style(slot)
		P.Draw(slot, texts[index])
		local stream = P.StreamOf(slot.id)
		local clicks = stream ~= nil and type(stream.Click) == "function" and not stream.through
		slot.frame:EnableMouse(slot.id ~= nil and (tips or slot.feed ~= nil or clicks))
	end
	ns.SetOutline(panel.outline, Opt("background") == true, Opt("background") == true)
	local strata = STRATA[Opt("strata")] or "LOW"
	if panel.strata ~= strata then
		panel.frame:SetFrameStrata(strata)
		panel.strata = strata
	end
	P.Layout(panel)
	P.Place(panel)
end

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
	else
		P.fight = nil
	end
	local file, size, height, flags = P.Font()
	P.fontKey, P.height, P.size = ("%s:%.2f:%s"):format(tostring(file), size, flags), height, size
	P.style = P.TextStyle()
	for _, spec in ipairs(PANELS) do
		local wanted = on and Opt(spec.id) == true and not P.petBattle
		local panel = wanted and P.Panel(spec) or P.panels[spec.id]
		if panel then
			panel.wanted = wanted
			P.Fill(panel, wanted)
		end
	end
	local menu = P.menu
	local open = menu and menu.slot
	if open and on and open.panel.wanted and open.width and menu.stream == P.SLOT_MENU then
		local target = menu.target
		P.CloseMenu()
		P.SlotMenu(open, target)
		if open.hover and P.MenuOpen(open) then
			open.hover:Show()
		end
	elseif open and not (on and open.panel.wanted and open.width and P.StreamOf(open.id) == menu.stream) then
		P.CloseMenu()
	end
	P.Used()
	P.dirty = {}
	P.Ticker()
	P.FadeAll()
end

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

function P.Rest()
	local fight = P.fight
	if fight == nil then
		fight = P.InCombat()
	end
	local percent = Opt(fight and "combatAlpha" or "idleAlpha")
	if not ns.Finite(percent) then
		return 1
	end
	return math.max(0, math.min(100, percent)) / 100
end

local function Under(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and (ns.IsSecret(over) or over == true)
end

local function SetAlpha(panel, alpha)
	if panel.alpha ~= alpha then
		panel.alpha = alpha
		panel.frame:SetAlpha(alpha)
	end
end

function P.Lining()
	local kit = ns.MoverKit
	if type(kit) == "table" and type(kit.IsOpen) == "function" and kit.IsOpen() == true then
		return true
	end
	return type(ns.EditModeOpen) == "function" and ns.EditModeOpen() == true
end

function P.Fade(panel)
	local frame = panel.frame
	if not frame then
		return
	end
	local alpha = P.Rest()
	local menu = P.menu
	if alpha < 1 and panel.shown and ((menu and menu.slot and menu.slot.panel == panel) or Under(frame) or P.Lining()) then
		alpha = 1
	end
	local snap = panel.snap
	panel.snap = nil
	local now = GetTime()
	if snap or not frame:IsShown() or not ns.Finite(now) then
		if panel.fade then
			panel.fade = nil
			frame:SetScript("OnUpdate", nil)
		end
		SetAlpha(panel, alpha)
		return
	end
	local fade = panel.fade
	if fade and fade.to == alpha then
		return
	elseif not fade and panel.alpha == alpha then
		return
	end
	local from = panel.alpha or 1
	panel.fade = { from = from, to = alpha, start = now, duration = (alpha > from and RISE or FALL) * math.abs(alpha - from) }
	if not fade then
		frame:SetScript("OnUpdate", panel.ease)
	end
end

function P.Ease(panel)
	local fade, frame = panel.fade, panel.frame
	if not fade then
		frame:SetScript("OnUpdate", nil)
		return
	end
	local share = fade.duration > 0 and (GetTime() - fade.start) / fade.duration or 1
	if not ns.Finite(share) or share >= 1 then
		panel.fade = nil
		frame:SetScript("OnUpdate", nil)
		SetAlpha(panel, fade.to)
		return
	end
	share = math.max(0, share)
	SetAlpha(panel, fade.from + (fade.to - fade.from) * (1 - (1 - share) * (1 - share)))
end

function P.Dimmed()
	if not ns.Enabled(KEY) or P.Rest() >= 1 then
		return false
	end
	for _, panel in pairs(P.panels) do
		if panel.wanted and panel.shown and panel.frame then
			return true
		end
	end
	return false
end

local function StopHover()
	local ticker = P.hover
	P.hover = nil
	if type(ticker) == "table" and type(ticker.Cancel) == "function" then
		pcall(ticker.Cancel, ticker)
	end
end

function P.HoverTicker()
	local want = P.Dimmed()
	if want and not P.hover then
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, HOVER, function()
				if not ns.Try(KEY, P.HoverTick) then
					StopHover()
				end
			end)
			P.hover = ok and ticker or nil
		end
	elseif not want and P.hover then
		StopHover()
	end
end

function P.HoverTick()
	for _, panel in pairs(P.panels) do
		P.Fade(panel)
	end
	if not P.Dimmed() then
		P.HoverTicker()
	end
end

function P.FadeAll()
	for _, panel in pairs(P.panels) do
		P.Fade(panel)
	end
	P.HoverTicker()
end

function P.Combat(on)
	P.fight = on
	P.FadeAll()
end

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

function P.Flush()
	local dirty = P.dirty
	P.dirty = {}
	if not ns.Enabled(KEY) or next(dirty) == nil then
		return
	end
	for _, panel in pairs(P.panels) do
		if panel.wanted and not panel.frame then
			for _, slot in ipairs(panel.slots) do
				if slot.id and dirty[slot.id] and P.TextOf(slot) then
					P.Fill(panel, true)
					break
				end
			end
		elseif panel.wanted then
			local moved, secure = false, false
			for _, slot in ipairs(panel.slots) do
				if slot.id and dirty[slot.id] then
					moved = P.Draw(slot, P.TextOf(slot)) or moved
					local stream = P.StreamOf(slot.id)
					secure = secure or (stream ~= nil and stream.secure ~= nil)
					if slot.over then
						P.Retip(slot)
					end
				end
			end
			if moved then
				P.Layout(panel)
			elseif secure then
				P.Secure(panel)
			end
		end
	end
	P.Ticker()
	P.FadeAll()
end

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

local FLOAT = { rise = 10, seconds = 1.2, fade = 0.6 }

local function MakeFloat(slot)
	local holder = Own(CreateFrame("Frame", nil, slot.frame))
	holder:SetSize(1, 1)
	holder:Hide()
	local text = ns.OwnText(holder, "OVERLAY", "GameFontHighlightSmall")
	text:SetWordWrap(false)
	pcall(text.SetShadowOffset, text, 1, -1)
	pcall(text.SetShadowColor, text, 0, 0, 0, 1)
	local group = holder:CreateAnimationGroup()
	local move = group:CreateAnimation("Translation")
	move:SetDuration(FLOAT.seconds)
	move:SetSmoothing("OUT")
	local fade = group:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
	fade:SetStartDelay(FLOAT.fade)
	fade:SetDuration(FLOAT.seconds - FLOAT.fade)
	local float = { holder = holder, text = text, group = group, move = move, sum = 0 }
	group:SetScript("OnFinished", function()
		holder:Hide()
		float.sum = 0
	end)
	return float
end

local function FloatOn(slot, delta)
	local float = slot.float
	if float == nil then
		local ok, made = pcall(MakeFloat, slot)
		float = ok and made or false
		slot.float = float
	end
	if not float then
		return
	end
	local okPlaying, playing = pcall(float.group.IsPlaying, float.group)
	float.sum = (okPlaying and playing == true and float.sum or 0) + delta
	float.group:Stop()
	if float.sum == 0 then
		float.holder:Hide()
		return
	end
	local file, size, _, flags = P.Font()
	if float.fontKey ~= P.fontKey then
		P.SetFont(float.text, file, size, flags)
		float.fontKey = P.fontKey
	end
	local down = P.Anchor(slot.panel) == "ANCHOR_BOTTOM"
	float.holder:ClearAllPoints()
	float.text:ClearAllPoints()
	if down then
		float.holder:SetPoint("TOP", slot.frame, "BOTTOM", 0, -2)
		float.text:SetPoint("TOP", float.holder, "TOP", 0, 0)
	else
		float.holder:SetPoint("BOTTOM", slot.frame, "TOP", 0, 2)
		float.text:SetPoint("BOTTOM", float.holder, "BOTTOM", 0, 0)
	end
	float.move:SetOffset(0, down and -FLOAT.rise or FLOAT.rise)
	float.text:SetText((float.sum > 0 and (GOOD .. "+") or (BAD .. "-")) .. P.Money(math.abs(float.sum), size) .. "|r")
	float.holder:Show()
	float.group:Play()
end

function P.Float(id, delta)
	if not (ns.Finite(delta) and delta ~= 0) or not ns.Enabled(KEY) then
		return
	end
	for _, panel in pairs(P.panels) do
		if panel.wanted and panel.shown and panel.frame and Visible(panel.frame) then
			for _, slot in ipairs(panel.slots) do
				if slot.id == id and slot.width and slot.frame then
					FloatOn(slot, delta)
				end
			end
		end
	end
end

local function Tooltip()
	local tip = _G.GameTooltip
	if tip == nil or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

local function Owned(slot)
	local tip = Tooltip()
	if not tip then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, slot.frame)
	return ok and not ns.IsSecret(owned) and owned == true
end

function P.Anchor(panel)
	local ok, _, y = pcall(panel.frame.GetCenter, panel.frame)
	local okHeight, height = pcall(UIParent.GetHeight, UIParent)
	if ok and okHeight and ns.Finite(y) and ns.Finite(height) then
		return y > height / 2 and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
	end
	return panel.spec.point:find("TOP", 1, true) and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
end

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
	local hint
	if type(stream.Hint) == "function" then
		local said, text = P.Run(stream, stream.Hint)
		hint = said and type(text) == "string" and text ~= "" and text or nil
	end
	hint = (hint and (hint .. " ") or "") .. "Right-click: choose what this slot shows."
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
		tip:AddLine(hint, DIM_RGB[1], DIM_RGB[2], DIM_RGB[3])
		tip:Show()
	end)
end

function P.TipAt(owner, anchor, id, fresh, hints)
	local stream, tip = P.StreamOf(id), Tooltip()
	if not (owner and stream and stream.Tip and tip) or ns.PartStopped(KEY, stream.label) then
		return false
	end
	local ok, lines = P.Run(stream, stream.Tip, fresh)
	if not ok or type(lines) ~= "table" then
		return false
	end
	return (pcall(function()
		tip:SetOwner(owner, anchor or "ANCHOR_TOP")
		tip:SetText(lines.title or stream.label, 1, 1, 1)
		for _, line in ipairs(lines) do
			if line[2] ~= nil then
				tip:AddDoubleLine(line[1], line[2], DIM_RGB[1], DIM_RGB[2], DIM_RGB[3], 1, 1, 1)
			else
				tip:AddLine(line[1] or " ", 1, 1, 1)
			end
		end
		for _, hint in ipairs(type(hints) == "table" and hints or {}) do
			tip:AddLine(hint, DIM_RGB[1], DIM_RGB[2], DIM_RGB[3])
		end
		tip:Show()
	end))
end

function P.Retip(slot)
	if slot.over and not slot.feed and Opt("tooltips") and Owned(slot) then
		P.Tip(slot, false)
	end
end

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
	pcall(tip.AddLine, tip, "Alt-right-click: choose what this slot shows.", DIM_RGB[1], DIM_RGB[2], DIM_RGB[3])
	pcall(tip.Show, tip)
end

function P.Enter(slot)
	slot.over = true
	if slot.hover then
		slot.hover:Show()
	end
	P.Fade(slot.panel)
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
	if slot.hover and not P.MenuOpen(slot) then
		slot.hover:Hide()
	end
	P.Fade(slot.panel)
end

function P.Click(slot, button)
	local alt = false
	if slot.feed and button == "RightButton" and type(IsAltKeyDown) == "function" then
		local ok, down = pcall(IsAltKeyDown)
		alt = ok and not ns.IsSecret(down) and down == true
	end
	if not slot.feed or alt then
		local stream = P.StreamOf(slot.id)
		if button == "RightButton" and stream then
			if P.MenuOpen(slot) and P.menu.stream == P.SLOT_MENU then
				P.CloseMenu()
				return
			end
			P.CloseMenu()
			if Owned(slot) then
				pcall(_G.GameTooltip.Hide, _G.GameTooltip)
			end
			local entered = slot.entered
			if entered then
				slot.entered = nil
				local leave = P.Field(entered, "OnLeave")
				if type(leave) == "function" then
					P.Call(slot.feed or "", leave, slot.frame)
				end
			end
			P.SlotMenu(slot)
			return
		end
		if stream and type(stream.Click) == "function" and not ns.PartStopped(KEY, stream.label) then
			P.Run(stream, stream.Click, slot, button)
		end
		return
	end
	if P.MenuOpen(slot) then
		P.CloseMenu()
	end
	local object = P.FeedObject(slot.feed)
	local click = object and P.Field(object, "OnClick")
	if type(click) == "function" then
		P.Call(slot.feed, click, slot.frame, button)
	end
end

local function Number(frame, method)
	local ok, value = pcall(frame[method], frame)
	return ok and ns.Finite(value) and value or nil
end

local function SecureItem(slot)
	local stream = P.StreamOf(slot.id)
	if not (stream and type(stream.secure) == "function" and slot.width and slot.panel.wanted and slot.panel.shown and ns.Enabled(KEY))
		or ns.PartStopped(KEY, stream.label) then
		return nil
	end
	local ok, item = P.Run(stream, stream.secure)
	return ok and type(item) == "string" and item ~= "" and item or nil
end

local function SecureHolder()
	if not P.secureHolder then
		local holder = Own(CreateFrame("Frame", nil, UIParent))
		if type(RegisterStateDriver) == "function" then
			pcall(RegisterStateDriver, holder, "visibility", "[combat] hide; show")
		end
		P.secureHolder = holder
	end
	return P.secureHolder
end

local function Overlay(slot)
	if slot.secure ~= nil then
		return slot.secure or nil
	end
	slot.secure = false
	local made, button = pcall(CreateFrame, "Button", nil, SecureHolder(), "SecureActionButtonTemplate")
	if not made or type(button) ~= "table" then
		return nil
	end
	Own(button)
	local done = pcall(function()
		button:Hide()
		button:EnableMouse(true)
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:SetScript("OnEnter", Guard(function()
			P.Secure(slot.panel)
			P.Enter(slot)
		end))
		button:SetScript("OnLeave", Guard(function()
			P.Leave(slot)
		end))
		button:SetScript("PreClick", function(self, mouse)
			if mouse == "LeftButton" and not InCombatLockdown() and not Under(slot.frame) and pcall(self.SetAttribute, self, "*type1", nil) then
				slot.armed = nil
			end
		end)
		button:SetScript("PostClick", Guard(function(_, mouse)
			if mouse == "RightButton" then
				P.Click(slot, mouse)
			end
			if not slot.armed then
				slot.secureKey = nil
				P.Secure(slot.panel)
			end
		end))
	end)
	if not done then
		pcall(button.Hide, button)
		return nil
	end
	slot.secure = button
	return button
end

function P.Cover(slot, button, item)
	local frame, panel = slot.frame, slot.panel
	local scale, base = Number(frame, "GetEffectiveScale"), Number(UIParent, "GetEffectiveScale")
	local left, bottom = Number(frame, "GetLeft"), Number(frame, "GetBottom")
	local width, height = Number(frame, "GetWidth"), Number(frame, "GetHeight")
	if not (item and frame:IsShown() and panel.frame and panel.frame:IsShown() and scale and base and left and bottom and width and height)
		or scale <= 0 or base <= 0 or width <= 0 or height <= 0 then
		slot.secureKey = nil
		pcall(button.Hide, button)
		return
	end
	local share = scale / base
	local x, y, w, h = left * share, bottom * share, width * share, height * share
	local strata, level = panel.strata or "LOW", math.floor(Number(frame, "GetFrameLevel") or 1) + 2
	local key = ("%s:%.2f:%.2f:%.2f:%.2f:%s:%d"):format(item, x, y, w, h, strata, level)
	if slot.secureKey == key and slot.armed == item then
		return
	end
	local ok = pcall(function()
		button:ClearAllPoints()
		button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
		button:SetSize(w, h)
		button:SetFrameStrata(strata)
		button:SetFrameLevel(level)
		if slot.armed ~= item then
			slot.armed = nil
			button:SetAttribute("item", item)
			button:SetAttribute("*type1", "item")
			slot.armed = item
		end
		button:Show()
	end)
	slot.secureKey = ok and key or nil
end

function P.Secure(panel)
	if not panel or P.InCombat() then
		return
	end
	for _, slot in ipairs(panel.slots) do
		local item = slot.frame and SecureItem(slot) or nil
		local button = item and Overlay(slot) or slot.secure or nil
		if button then
			P.Cover(slot, button, item)
		end
	end
end

function P.SecureAll()
	for _, panel in pairs(P.panels) do
		P.Secure(panel)
	end
end

local EDGE = 4
local LIGHT = { 1, 1, 1, 0.08 }

local function Over(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and not ns.IsSecret(over) and over == true
end

function P.MenuOpen(slot)
	local menu = P.menu
	return menu ~= nil and menu.slot ~= nil and (slot == nil or menu.slot == slot)
end

function P.CloseMenu()
	local menu = P.menu
	if not (menu and menu.slot) then
		return
	end
	local panel, slot = menu.slot.panel, menu.slot
	menu.slot, menu.stream, menu.target = nil, nil, nil
	if slot.hover and not slot.over then
		slot.hover:Hide()
	end
	pcall(menu.listener.UnregisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
	pcall(menu.frame.EnableKeyboard, menu.frame, false)
	menu.frame:Hide()
	if panel then
		P.Fade(panel)
	end
end

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
	frame:EnableMouse(true)
	pcall(frame.SetClampedToScreen, frame, true)
	pcall(frame.EnableKeyboard, frame, false)
	frame:SetScript("OnKeyDown", function(self, key)
		local escape = key == "ESCAPE" and P.MenuOpen()
		if not InCombatLockdown() then
			pcall(self.SetPropagateKeyboardInput, self, not escape)
		end
		if escape then
			ns.Try(KEY, P.CloseMenu)
		end
	end)
	frame:Hide()
	local menu = { frame = frame, outline = ns.Outline(frame, frame, true), lines = {}, dividers = {} }
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

local function Measure(text, value, size)
	local ok, width = pcall(text.GetStringWidth, text)
	if ok and ns.Finite(width) then
		return width
	end
	return #value * size / 2
end

function P.MenuRoom(slot, screen)
	local frame = slot.frame
	local okBottom, bottom = pcall(frame.GetBottom, frame)
	local okTop, top = pcall(frame.GetTop, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	local okParent, parent = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (okBottom and okTop and okScale and okParent and ns.Finite(bottom) and ns.Finite(top) and ns.Finite(scale) and ns.Finite(parent))
		or scale <= 0 or parent <= 0 then
		return nil
	end
	local share = scale / parent
	local room
	if P.Anchor(slot.panel) == "ANCHOR_BOTTOM" then
		room = bottom * share - 2
	else
		room = screen - top * share - 2
	end
	if not ns.Finite(room) or room <= 0 then
		return nil
	end
	return math.min(room, screen - 16)
end

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
	local per = #items
	local okScreen, screen = pcall(UIParent.GetHeight, UIParent)
	if okScreen and ns.Finite(screen) and screen > 0 then
		local room = P.MenuRoom(slot, screen) or (screen - 16)
		per = math.max(4, math.floor((room - 2 * EDGE - height) / height))
	end
	per = math.max(1, math.min(per, #items))
	local columns = math.ceil(#items / per)
	local widths = {}
	for index, item in ipairs(items) do
		local line = MenuLine(menu, index)
		line.item = item
		P.SetFont(line.text, file, size)
		line.text:SetText(item.text)
		line.light:Hide()
		local column = math.floor((index - 1) / per) + 1
		widths[column] = math.max(widths[column] or 0, Measure(line.text, item.text, size))
	end
	local lefts, total = {}, 0
	for column = 1, columns do
		widths[column] = math.ceil(widths[column]) + 2 * PAD_X
		lefts[column] = total
		total = total + widths[column]
	end
	local need = math.ceil(Measure(menu.title, title, size)) + 2 * PAD_X
	if need > total then
		widths[columns] = widths[columns] + need - total
		total = need
	end
	for index in ipairs(items) do
		local line = menu.lines[index]
		local column, row = math.floor((index - 1) / per) + 1, (index - 1) % per
		line.frame:ClearAllPoints()
		line.frame:SetPoint("TOPLEFT", menu.frame, "TOPLEFT", lefts[column], -(EDGE + height + row * height))
		line.frame:SetSize(widths[column], height)
		line.frame:Show()
	end
	for index = #items + 1, #menu.lines do
		menu.lines[index].item = nil
		menu.lines[index].frame:Hide()
	end
	local r, g, b = ns.BorderRGB()
	local thin = ns.Pixels(menu.frame, 1)
	for column = 2, columns do
		local divider = menu.dividers[column]
		if not divider then
			divider = Own(menu.frame:CreateTexture(nil, "ARTWORK", nil, 1))
			menu.dividers[column] = divider
		end
		divider:ClearAllPoints()
		divider:SetPoint("TOP", menu.frame, "TOPLEFT", lefts[column], -(EDGE + height))
		divider:SetSize(thin, per * height)
		divider:SetColorTexture(r, g, b, 0.6)
		divider:Show()
	end
	for column, divider in pairs(menu.dividers) do
		if column > columns then
			divider:Hide()
		end
	end
	menu.frame:SetSize(total, EDGE + height + per * height + EDGE)
	menu.frame:ClearAllPoints()
	if P.Anchor(slot.panel) == "ANCHOR_BOTTOM" then
		menu.frame:SetPoint("TOP", slot.frame, "BOTTOM", 0, -2)
	else
		menu.frame:SetPoint("BOTTOM", slot.frame, "TOP", 0, 2)
	end
	ns.SetOutline(menu.outline, true, true)
	menu.slot, menu.stream = slot, stream
	menu.frame:Show()
	if not InCombatLockdown() then
		pcall(menu.frame.EnableKeyboard, menu.frame, true)
		pcall(menu.frame.SetPropagateKeyboardInput, menu.frame, true)
	end
	P.Fade(slot.panel)
	pcall(menu.listener.RegisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
	if Owned(slot) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
	return true
end

P.SLOT_MENU = { label = "Slot menu" }
local ORDINALS = { "first", "second", "third", "fourth", "fifth", "sixth" }
local TICK = " |TInterface\\Buttons\\UI-CheckBox-Check:0|t"

local function SetSlot(path, id, batch)
	local before = ns.Get(path)
	ns.Set(path, id)
	local home = ns.PanelHome
	if not (type(home) == "table" and type(home.Noted) == "function" and type(ns.PAGES) == "table") then
		return
	end
	for _, page in ipairs(ns.PAGES) do
		for _, row in ipairs(page) do
			if type(row) == "table" and row.path == path then
				home.Noted(row, before, ns.Get(path), batch)
				return
			end
		end
	end
end

local function Empty(stream)
	if ns.PartStopped(KEY, stream.label) then
		return true, "stopped after an error"
	end
	local ok, answer = P.Run(stream, stream.Text)
	if ok and P.Text(answer) then
		return false
	end
	return true, stream.idle
end

local function SayEmpty(slot, label, why)
	if slot.width or not slot.panel.wanted then
		return
	end
	local where = ("the %s slot of the %s panel"):format(ORDINALS[slot.index] or tostring(slot.index), slot.panel.spec.id)
	local line
	if not label then
		line = ("Flat UI: %s is set to None, so it takes no room."):format(where)
	elseif why then
		line = ("Flat UI: %s shows nothing for this character now (%s), so %s takes no room."):format(label, why, where)
	else
		line = ("Flat UI: %s shows nothing now, so %s takes no room."):format(label, where)
	end
	if slot.panel.shown then
		line = line .. " Right-click another slot, or open the Data panels options, to change it."
	else
		line = line .. (" The %s panel hides until one of its slots has something to show; the Data panels options change it."):format(slot.panel.spec.id)
	end
	print(line)
end

local function FreeSlot(slot)
	local spec, nearest = slot.panel.spec, nil
	for index = 1, SLOTS do
		if index ~= slot.index and Opt(spec.id .. index) == "none" then
			if index > slot.index then
				return index, true
			end
			nearest = index
		end
	end
	return nearest, false
end

local function Neighbour(panel, index, step)
	local at = index + step
	while at >= 1 and at <= SLOTS do
		local other = panel.slots[at]
		if other and other.width then
			return at
		end
		at = at + step
	end
	return nil
end

local function AddBeside(spec, index, free, id)
	local batch = { label = "Add a slot", what = "adding the slot" }
	local step = free > index and 1 or -1
	local landing = index + step
	for at = free, landing + step, -step do
		SetSlot(KEY .. "." .. spec.id .. at, Opt(spec.id .. (at - step)), batch)
	end
	SetSlot(KEY .. "." .. spec.id .. landing, id, batch)
end

local function Swap(panel, index, other)
	local spec = panel.spec
	local batch = { label = "Move a slot", what = "the move" }
	local mine, theirs = Opt(spec.id .. index), Opt(spec.id .. other)
	SetSlot(KEY .. "." .. spec.id .. other, mine, batch)
	SetSlot(KEY .. "." .. spec.id .. index, theirs, batch)
	local moved = panel.slots[other]
	P.SlotMenu(moved)
	if moved.hover and P.MenuOpen(moved) then
		moved.hover:Show()
	end
end

local MOVES = { { -1, "Move left" }, { 1, "Move right" } }

function P.SlotMenu(slot, target)
	local panel = slot.panel
	local spec = panel and panel.spec
	if not (spec and slot.index) then
		return
	end
	if target and not (panel.slots[target] and Opt(spec.id .. target) == "none") then
		target = nil
	end
	local landing = target and (target > slot.index and slot.index + 1 or slot.index - 1) or slot.index
	local filled = panel.slots[landing] or slot
	local path, now = KEY .. "." .. spec.id .. slot.index, target and "none" or (slot.id or "none")
	local items = {}
	for _, choice in ipairs(ns.DataPanelChoices()) do
		local id, label = choice[1], choice[2]
		local shown = id == now
		if not (target and id == "none") then
			local text, why = label, nil
			local stream = not shown and P.StreamOf(id) or nil
			if shown then
				text = WARN .. label .. "|r" .. TICK
			elseif stream and not stream.feed then
				local empty
				empty, why = Empty(stream)
				if empty then
					text = ("%s%s (%s)|r"):format(DIM, label, why or "nothing now")
				end
			end
			items[#items + 1] = { text = text, inert = shown, pick = function()
				if target then
					AddBeside(spec, slot.index, target, id)
				else
					SetSlot(path, id)
				end
				SayEmpty(filled, id ~= "none" and label or nil, why)
			end }
		end
	end
	local free, after = nil, false
	if not target then
		free, after = FreeSlot(slot)
		if slot.width then
			for _, move in ipairs(MOVES) do
				local other = Neighbour(panel, slot.index, move[1])
				if other then
					items[#items + 1] = { text = move[2], pick = function()
						Swap(panel, slot.index, other)
					end }
				end
			end
		end
	end
	if free then
		items[#items + 1] = { text = after and "Add a slot after this one" or "Add a slot before this one", pick = function()
			P.SlotMenu(slot, free)
		end }
	end
	items[#items + 1] = { text = DIM .. "Data panels options|r", pick = function()
		if type(ns.OpenPanelPage) == "function" then
			ns.OpenPanelPage(KEY)
		end
	end }
	local name = spec.id == "top" and "Top" or "Bottom"
	local title = target and ("%s panel, new %s slot"):format(name, ORDINALS[landing] or tostring(landing))
		or ("%s panel, %s slot"):format(name, ORDINALS[slot.index] or tostring(slot.index))
	if P.OpenMenu(slot, P.SLOT_MENU, title, items) and target then
		P.menu.target = target
	end
end

local function EachStream(method)
	for _, id in ipairs(P.order) do
		local stream = P.streams[id]
		if type(stream[method]) == "function" and not ns.PartStopped(KEY, stream.label) then
			P.Run(stream, stream[method])
		end
	end
end

local function PetBattleNow()
	local battles = _G.C_PetBattles
	local now = type(battles) == "table" and not ns.IsSecret(battles) and P.Ask(battles.IsInBattle) or nil
	if now == true or now == false then
		P.petBattle = now
	end
end

function P.Start()
	PetBattleNow()
	P.fight = nil
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

function ns.DataPanelsMoved()
	for _, panel in pairs(P.panels) do
		panel.placed = nil
		if panel.wanted and panel.frame then
			ns.Try(KEY, P.Place, panel)
		end
	end
	if ns.Enabled(KEY) then
		ns.Try(KEY, P.FadeAll)
	end
end

function ns.DataPanelMark(id)
	if ns.Enabled(KEY) then
		ns.Try(KEY, P.Mark, id)
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
		PLAYER_REGEN_DISABLED = function()
			P.Combat(true)
			P.CloseMenu()
		end,
		PLAYER_REGEN_ENABLED = function()
			P.Combat(false)
			P.SecureAll()
		end,
	},
})

if ns.TestMode then
	local SAMPLE_GOLD, GAIN, LOSS = 5, 3802, -10400
	local loss = false
	ns.TestMode.Register("datapanels", { module = KEY, label = "Data panels", refresh = true,
		every = SAMPLE_GOLD, Tick = function()
			P.Float("gold", loss and LOSS or GAIN)
			loss = not loss
		end })
end
