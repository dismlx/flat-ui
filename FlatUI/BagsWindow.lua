local _, ns = ...

local B = ns.Bags
local Window = B.Window
local Layout = B.Layout
local Data = B.Data
local Search = B.Search
local Buttons = B.Buttons
local Bank = B.Bank
local Errands = ns.Errands

local NAMES = { bags = "FlatUIBags", bank = "FlatUIBank" }
local CORNERS = { bags = "BOTTOMRIGHT", bank = "TOPLEFT" }
local BOXES = { bags = { 360, 260, -60, 110 }, bank = { 420, 300, 25, -110 } }
local RIGHT_BARS = { "MultiBarRight", "MultiBarLeft" }
local BAR_SLACK, BAR_ROOM = 12, 10
local PAD, BAR, FOOT, INNER = 8, 26, 22, 4
local ICON, ICON_GAP, CLOSE = 18, 3, 18
local PICKER_LEAST, PICKER_MOST, SEARCH_LEAST, SEARCH_HEIGHT = 64, 0.5, 70, 18
local STRIP, STRIP_GAP = 26, 6
local PARK = 200
local LEAST_VIEW, MESSAGE_VIEW, MOST = 40, 64, 0.85
local TRACK_W, THUMB_LEAST, WHEEL_ROWS = 4, 16, 2
local PITCH, SLOT = 40, 37
local SELL_W, MOVE_W, FOOT_BUTTON = 108, 96, 18
local GOLD_ROOM, FREE_ROOM, FOOT_GAP = 96, 40, 12
local POLL, BUSY_MOST, BUSY_LEAST, MOST_GOLD = 0.5, 6.5, 0.35, 15
local HOURLY_AFTER = 600
local GRIP = { size = 10, level = 5, alpha = 0.6, corners = { bags = "BOTTOMLEFT", bank = "BOTTOMRIGHT" },
	lines = { bags = { { 1, 2, 8, 9 }, { 1, 5.5, 4.5, 9 } }, bank = { { 2, 9, 9, 2 }, { 5.5, 9, 9, 5.5 } } },
	paths = { bags = "bags.columns", bank = "bags.bankColumns" } }
local KEYRING = -1
local DIM = { 0.66, 0.68, 0.62 }
local SESSION_GAIN, SESSION_LOSS = { 0.3, 0.85, 0.3 }, { 1, 0.35, 0.24 }
local DIM_HEX, WHITE_HEX, LOW_HEX, NONE_HEX = "|cffa8ad9e", "|cffffffff", "|cffffd100", "|cffff5a3d"
local LOW = 4
local CUE = { rise = 12, seconds = 1.0, fade = 0.35, half = 0.2, dip = 0.25, pulses = 2 }
local SEPARATOR = 0.07
local GLYPHS = {
	sections = { rects = { { 4, 4, 2, 2 }, { 8, 4, 6, 2 }, { 4, 8, 2, 2 }, { 8, 8, 6, 2 }, { 4, 12, 2, 2 }, { 8, 12, 6, 2 } } },
	bags = { rects = { { 4, 4, 2, 2 }, { 8, 4, 2, 2 }, { 12, 4, 2, 2 }, { 4, 8, 2, 2 }, { 8, 8, 2, 2 }, { 12, 8, 2, 2 }, { 4, 12, 2, 2 },
		{ 8, 12, 2, 2 }, { 12, 12, 2, 2 } } },
	sort = { rects = { { 4, 4, 10, 2 }, { 4, 8, 7, 2 }, { 4, 12, 4, 2 } } },
	bank = { rects = { { 4, 8, 10, 1 }, { 5, 10, 1.5, 3.5 }, { 8.25, 10, 1.5, 3.5 }, { 11.5, 10, 1.5, 3.5 }, { 3.5, 14, 11, 1.5 } },
		strokes = { { 3.5, 7.5, 9, 3.5 }, { 9, 3.5, 14.5, 7.5 } } },
}

local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

local windows = {}
local Grip = {}
local played, watching = {}, false
local watcher = nil

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Fn(tbl, name)
	local fn = type(tbl) == "table" and tbl[name] or nil
	if type(fn) == "function" then
		return fn
	end
	return nil
end

local function Call(tbl, name, ...)
	local fn = Fn(tbl, name)
	if fn then
		return fn(...)
	end
	return nil
end

local function Run(part, fn, ...)
	local run = Fn(B, "Part")
	if run then
		return run(part, fn, ...)
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		geterrorhandler()(err)
	end
	return ok
end

local function Opt(key)
	return Call(B, "Opt", key)
end

local function On()
	return Call(B, "On") == true
end

local function Request(flag, which)
	Call(B, "Request", flag, which)
end

local function Now()
	local ok, now = pcall(GetTime)
	return ok and Finite(now) and now or 0
end

local function After(seconds, fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(seconds, fn)
	else
		fn()
	end
end

local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

local function Plain(text)
	return (tostring(text):gsub("|", "||"))
end

local function Hex(r, g, b)
	local function Byte(value)
		return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
	end
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

local function LookRGB(key, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, "windows." .. key)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

local function Opacity()
	local value = Call(B, "Look", "opacity")
	if not Finite(value) then
		value = ns.Get("windows.opacity")
	end
	return Finite(value) and math.max(0, math.min(1, value / 100)) or 0.8
end

local function TextWidth(text)
	local ok, width = pcall(text.GetUnboundedStringWidth, text)
	if not (ok and Finite(width)) then
		ok, width = pcall(text.GetStringWidth, text)
	end
	return ok and Finite(width) and width or 0
end

local function Shown(w)
	return w ~= nil and not w.warming and w.frame:IsShown() == true
end

local function Money(copper)
	if type(Errands) == "table" and type(Errands.Money) == "function" then
		return Errands.Money(copper)
	end
	return ("%dg"):format(math.floor(copper / 10000))
end

local function Tip(owner)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return nil
	end
	tip:SetOwner(owner, "ANCHOR_TOP")
	return tip
end

local function Untip(owner)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, owner)
	if ok and owned == true then
		tip:Hide()
	end
end

local function Say(owner, title, ...)
	local tip = Tip(owner)
	if not tip then
		return
	end
	tip:SetText(title, 1, 1, 1)
	for index = 1, select("#", ...) do
		local line = select(index, ...)
		if line then
			tip:AddLine(line, DIM[1], DIM[2], DIM[3], true)
		end
	end
	tip:Show()
end

local function Characters()
	local list = Call(Data, "Characters")
	return type(list) == "table" and list or {}
end

local function CharacterOf(key)
	if key == nil then
		return nil
	end
	for _, c in ipairs(Characters()) do
		if type(c) == "table" and c.key == key then
			return c
		end
	end
	return nil
end

local function NameOf(key, c)
	if c and type(c.name) == "string" and not IsSecret(c.name) and c.name ~= "" then
		return c.name
	end
	if type(key) == "string" and not IsSecret(key) then
		return key:match("^(.-) %- ") or key
	end
	local ok, name = pcall(UnitName, "player")
	if ok and type(name) == "string" and not IsSecret(name) and name ~= "" then
		return name
	end
	return "?"
end

local function RealmOf(c)
	if type(c.key) == "string" and not IsSecret(c.key) then
		local realm = c.key:match(" %- (.+)$")
		if realm and realm ~= "" then
			return realm
		end
	end
	if type(c.realm) == "string" and not IsSecret(c.realm) and c.realm ~= "" then
		return c.realm
	end
	return "?"
end

local function Named(key, c)
	local name = NameOf(key, c)
	local me = Call(B, "Me")
	local mine = type(me) == "string" and not IsSecret(me) and me:match(" %- (.+)$") or nil
	local realm = type(c) == "table" and RealmOf(c) or nil
	if (realm == nil or realm == "?") and type(key) == "string" and not IsSecret(key) then
		realm = key:match(" %- (.+)$")
	end
	if mine and realm and realm ~= "?" and realm ~= mine then
		return name .. " - " .. realm
	end
	return name
end

local function ClassRGB(class)
	if type(class) ~= "string" or IsSecret(class) then
		return nil
	end
	local colours = RAID_CLASS_COLORS
	local colour = type(colours) == "table" and not IsSecret(colours) and colours[class] or nil
	if type(colour) ~= "table" or IsSecret(colour) then
		return nil
	end
	local r, g, b = colour.r, colour.g, colour.b
	if Finite(r) and Finite(g) and Finite(b) then
		return r, g, b
	end
	return nil
end

local function ClassHex(class)
	local r, g, b = ClassRGB(class)
	return r and Hex(r, g, b) or WHITE_HEX
end

local function AsOf(seen)
	if not Finite(seen) or seen <= 0 then
		return nil
	end
	local function Noon(t)
		local ok, day = pcall(date, "*t", t)
		if not ok or type(day) ~= "table" then
			return nil
		end
		local okTime, noon = pcall(time, { year = day.year, month = day.month, day = day.day, hour = 12 })
		return okTime and Finite(noon) and noon or nil
	end
	local okNow, now = pcall(time)
	local today, then_ = okNow and Finite(now) and Noon(now) or nil, Noon(seen)
	if not (today and then_) then
		return nil
	end
	local days = math.floor((today - then_) / 86400 + 0.5)
	if days <= 0 then
		return "as of today"
	elseif days == 1 then
		return "as of yesterday"
	end
	return ("as of %d days ago"):format(days)
end

local function Matches(which, key, stacks)
	local match = Fn(Search, "Match")
	if not match then
		return 0
	end
	local count = 0
	local list = Call(Data, "Containers", which, key)
	for _, bag in ipairs(type(list) == "table" and list or {}) do
		if Finite(bag) and (stacks or bag ~= KEYRING) then
			local slots = Call(Data, "Size", key, bag)
			for slot = 1, Finite(slots) and slots or 0 do
				local record = Call(Data, "Item", key, bag, slot)
				if type(record) == "table" then
					local ok, matched = pcall(match, record)
					if ok and matched == true then
						local n = stacks and record.count or 1
						count = count + (Finite(n) and n > 0 and n or 1)
					end
				end
			end
		end
	end
	return math.floor(count)
end

local function MatchCount(w)
	local n = nil
	if Call(Search, "Active") == true then
		n = Matches(w.which, (Layout.Viewed(w.which)), true)
	end
	Call(Search, "SetCount", w.which, n)
end

local function Rule(owner)
	local rule = Own(owner:CreateTexture(nil, "ARTWORK"))
	return rule
end

local function Bit(button, x, y, width, height)
	local bit = Own(button:CreateTexture(nil, "OVERLAY", nil, 2))
	bit:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
	bit:SetSize(width, height)
	return bit
end

local function Stroke(button, layer, x1, y1, x2, y2)
	local line = Own(button:CreateLine(nil, layer or "OVERLAY", nil, 2))
	line:SetThickness(1.5)
	line:SetStartPoint("TOPLEFT", button, x1, -y1)
	line:SetEndPoint("TOPLEFT", button, x2, -y2)
	return line
end

local function Glyph(button, spec)
	local parts = {}
	for _, r in ipairs(spec.rects or {}) do
		parts[#parts + 1] = Bit(button, r[1], r[2], r[3], r[4])
	end
	for _, s in ipairs(spec.strokes or {}) do
		parts[#parts + 1] = Stroke(button, "OVERLAY", s[1], s[2], s[3], s[4])
	end
	return parts
end

local function SetGlyph(parts, shown)
	for _, part in ipairs(parts) do
		part:SetShown(shown)
	end
end

local function PaintIcon(icon, alpha)
	local pr, pg, pb = LookRGB("panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
	ns.SetOutlineFill(icon.outline, pr, pg, pb, 1)
	ns.SetOutline(icon.outline, true, true)
	icon.hover:SetColorTexture(ar, ag, ab, 0.25)
	for _, parts in pairs(icon.glyphs) do
		for _, part in ipairs(parts) do
			part:SetColorTexture(ar, ag, ab, alpha or 0.9)
		end
	end
end

local function PaintPlate(plate)
	local pr, pg, pb = LookRGB("panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
	ns.SetOutlineFill(plate.outline, pr, pg, pb, 1)
	ns.SetOutline(plate.outline, true, true)
	plate.hover:SetColorTexture(ar, ag, ab, plate.usable and 0.25 or 0)
	plate.label:SetAlpha(plate.usable and 1 or 0.45)
end

function Grip.Paint(w)
	local grip = w.grip
	if not grip then
		return
	end
	local r, g, b, a = DIM[1], DIM[2], DIM[3], GRIP.alpha
	if grip.over or w.sizing then
		r, g, b = LookRGB("accent", 0.85, 0.85, 0.85)
		a = 1
	end
	for _, line in ipairs(grip.lines) do
		line:SetColorTexture(r, g, b, a)
	end
end

local function PaintWindow(w)
	local r, g, b = ns.Colour("general.backdrop")
	ns.SetOutlineFill(w.outline, r, g, b, Opacity())
	ns.SetOutline(w.outline, true, true)
	local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
	for _, icon in pairs(w.icons) do
		PaintIcon(icon)
	end
	for _, line in ipairs(w.close.lines) do
		line:SetColorTexture(1, 1, 1, 0.6)
	end
	for _, line in ipairs(w.close.hover) do
		line:SetColorTexture(ar, ag, ab, 1)
	end
	w.pickerLight:SetColorTexture(1, 1, 1, 0.06)
	for _, line in ipairs(w.chevron) do
		line:SetColorTexture(1, 1, 1, 0.6)
	end
	for _, rule in ipairs(w.rules) do
		rule:SetColorTexture(1, 1, 1, SEPARATOR)
	end
	w.trackBack:SetColorTexture(0, 0, 0, 0.3)
	w.thumbBack:SetColorTexture(ar, ag, ab, w.thumbOver and 0.5 or 0.25)
	w.message:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	for _, plate in ipairs(w.plates) do
		PaintPlate(plate)
	end
	Grip.Paint(w)
end

local Showing, Hiding, Missed, Footer, TitleLine, Resize, ArrangeBar, ArrangeFoot, SetOffset

local function Mode(which)
	local key, _, live = Layout.Viewed(which)
	return tostring(key) .. ":" .. tostring(live)
end

local function Special(name)
	if type(UISpecialFrames) ~= "table" then
		return
	end
	for _, listed in ipairs(UISpecialFrames) do
		if listed == name then
			return
		end
	end
	table.insert(UISpecialFrames, name)
end

local function Sound(name)
	if type(PlaySound) ~= "function" or type(SOUNDKIT) ~= "table" or IsSecret(SOUNDKIT) then
		return
	end
	local id = SOUNDKIT[name]
	if not Finite(id) then
		return
	end
	local now = Now()
	if played[name] == now then
		return
	end
	played[name] = now
	pcall(PlaySound, id)
end

local function Unsplit(w, button)
	if w.which == "bags" then
		Call(Buttons, "Unsplit", button)
	end
end

local function PaintSort(w)
	local icon = w.icons.sort
	if icon then
		PaintIcon(icon)
	end
end

local function EndBusy(w)
	if w.busy then
		w.busy = nil
		PaintSort(w)
	end
end

local function Sorting(w)
	return w.busy ~= nil or Call(B, "Sorting", w.which) == true
end

local function Sorted(which)
	local w = windows[which]
	if not w then
		return
	end
	local began = Now()
	w.busy = began
	After(BUSY_MOST, function()
		if w.busy == began then
			Run("window", EndBusy, w)
		end
	end)
end

local function Watching()
	if watching then
		return
	end
	local sort = ns.BagSort
	local watch = type(sort) == "table" and sort.Watch or nil
	if type(watch) == "function" then
		watching = pcall(watch, function(which)
			Run("window", Sorted, which)
		end) == true
	end
end

local function Pulse(w)
	local icon = w.icons.sort
	if not icon then
		return
	end
	local alpha = 0.3 + 0.55 * math.abs(math.sin(Now() * 3))
	local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
	for _, part in ipairs(icon.glyphs.sort) do
		part:SetColorTexture(ar, ag, ab, alpha)
	end
end

local Clicks, Tips = {}, {}

local function Icon(w, kind, glyphs)
	local button = Own(CreateFrame("Button", nil, w.bar))
	button:SetSize(ICON, ICON)
	button:RegisterForClicks("LeftButtonUp")
	local icon = { kind = kind, button = button, glyphs = {} }
	icon.outline = ns.Outline(button, button)
	icon.hover = Own(button:CreateTexture(nil, "HIGHLIGHT"))
	icon.hover:SetAllPoints(button)
	for _, name in ipairs(glyphs) do
		icon.glyphs[name] = Glyph(button, GLYPHS[name])
	end
	local function Release()
		if icon.pressed then
			icon.pressed = nil
			icon.hover:SetAlpha(1)
			PaintIcon(icon)
		end
	end
	button:SetScript("OnClick", function()
		Run("window", Clicks[kind], w)
	end)
	button:SetScript("OnMouseDown", function(_, mouse)
		if mouse == "LeftButton" then
			icon.pressed = true
			PaintIcon(icon, 0.6)
			icon.hover:SetAlpha(0)
		end
	end)
	button:SetScript("OnMouseUp", function()
		Release()
	end)
	button:SetScript("OnEnter", function()
		Run("window", Tips[kind], w, button)
	end)
	button:SetScript("OnLeave", function()
		Release()
		Untip(button)
	end)
	w.icons[kind] = icon
	return icon
end

local function MakeClose(w)
	local button = Own(CreateFrame("Button", nil, w.bar))
	button:SetSize(CLOSE, CLOSE)
	button:RegisterForClicks("LeftButtonUp")
	local close = { button = button }
	close.lines = { Stroke(button, "OVERLAY", 5, 5, 13, 13), Stroke(button, "OVERLAY", 5, 13, 13, 5) }
	close.hover = { Stroke(button, "HIGHLIGHT", 5, 5, 13, 13), Stroke(button, "HIGHLIGHT", 5, 13, 13, 5) }
	button:SetScript("OnClick", function()
		Window.Hide(w.which)
	end)
	w.close = close
end

local function DragStart(w)
	Layout.CloseMenu(w.which)
	w.frame:StartMoving()
	w.moving = true
end

local function RectOf(frame)
	local ok, left, bottom, width, height = pcall(frame.GetRect, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (ok and okScale and okBase and Finite(left) and Finite(bottom) and Finite(width) and Finite(height) and Finite(scale) and Finite(base))
		or base <= 0 then
		return nil
	end
	local k = scale / base
	return left * k, bottom * k, width * k, height * k
end

local function Dropped(w)
	if not w.moving then
		return
	end
	w.moving = false
	local frame = w.frame
	frame:StopMovingOrSizing()
	pcall(frame.SetUserPlaced, frame, false)
	w.placed = nil
	local which = w.which
	local left, bottom, width, height = RectOf(frame)
	if not left then
		Window.Place(which)
		return
	end
	local name, box = NAMES[which], BOXES[which]
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[name] or nil
	local boxW = info and Finite(info.width) and info.width > 0 and info.width or box[1]
	local boxH = info and Finite(info.height) and info.height > 0 and info.height or box[2]
	local boxLeft, boxBottom
	if CORNERS[which] == "BOTTOMRIGHT" then
		boxLeft, boxBottom = left + width - boxW, bottom
	else
		boxLeft, boxBottom = left, bottom + height - boxH
	end
	local saved = false
	if info and type(kit.Commit) == "function" then
		saved = kit.Commit(name, info, boxLeft, boxBottom, boxW, boxH) == true
	end
	if saved then
		w.dropped = nil
	elseif CORNERS[which] == "BOTTOMRIGHT" then
		w.dropped = { left + width, bottom }
	else
		w.dropped = { left, bottom + height }
	end
	w.placed = nil
	Window.Place(which)
end

local function MakePicker(w)
	local button = Own(CreateFrame("Button", nil, w.bar))
	button:SetHeight(ICON)
	button:RegisterForClicks("LeftButtonUp")
	w.pickerLight = Own(button:CreateTexture(nil, "HIGHLIGHT"))
	w.pickerLight:SetAllPoints(button)
	local text = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT", button, "LEFT", 4, 0)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	w.picker, w.pickerText = button, text
	w.chevron = {}
	for index, s in ipairs({ { -11, 1.5, -8, -1.5 }, { -8, -1.5, -5, 1.5 } }) do
		local line = Own(button:CreateLine(nil, "OVERLAY", nil, 2))
		line:SetThickness(1.5)
		line:SetStartPoint("RIGHT", button, s[1], s[2])
		line:SetEndPoint("RIGHT", button, s[3], s[4])
		w.chevron[index] = line
	end
	button:SetScript("OnClick", function()
		Run("window", Clicks.picker, w)
	end)
	button:SetScript("OnEnter", function()
		Run("window", Tips.picker, w, button)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", function()
		Run("window", DragStart, w)
	end)
	button:SetScript("OnDragStop", function()
		Run("window", Dropped, w)
	end)
end

local function MakeBar(w)
	local frame = w.frame
	local bar = Own(CreateFrame("Frame", nil, frame))
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	bar:SetHeight(BAR)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		Run("window", DragStart, w)
	end)
	bar:SetScript("OnDragStop", function()
		Run("window", Dropped, w)
	end)
	bar:SetScript("OnHide", function()
		Unsplit(w)
		if w.moving then
			Run("window", Dropped, w)
		end
	end)
	w.bar = bar
	MakeClose(w)
	MakePicker(w)
	Icon(w, "view", { "sections", "bags" })
	Icon(w, "sort", { "sort" })
	if w.which == "bags" then
		Icon(w, "bank", { "bank" })
	end
	local box = Call(Search, "Box", bar, w.which)
	if type(box) == "table" then
		w.search = box
		pcall(box.SetHeight, box, SEARCH_HEIGHT)
	end
	local rule = Rule(frame)
	rule:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -BAR)
	rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -BAR)
	w.rules[#w.rules + 1] = rule
	w.barRule = rule
end

function ArrangeBar(w)
	local bar = w.bar
	local ok, width = pcall(w.frame.GetWidth, w.frame)
	width = ok and Finite(width) and width or BOXES[w.which][1]
	w.close.button:ClearAllPoints()
	w.close.button:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	local x = -(4 + CLOSE + 4)
	local _, _, live = Layout.Viewed(w.which)
	local shown = { bank = w.which == "bags", sort = live == true, view = true }
	for _, kind in ipairs({ "bank", "sort", "view" }) do
		local icon = w.icons[kind]
		if icon then
			icon.button:SetShown(shown[kind] == true)
			if shown[kind] then
				icon.button:ClearAllPoints()
				icon.button:SetPoint("RIGHT", bar, "RIGHT", x, 0)
				x = x - ICON - ICON_GAP
			end
		end
	end
	local view = Opt("view") == "bags" and "bags" or "sections"
	local icon = w.icons.view
	SetGlyph(icon.glyphs.sections, view == "sections")
	SetGlyph(icon.glyphs.bags, view == "bags")
	local right = width + x + ICON_GAP - 6
	local room = right - PAD
	local most = w.search and math.max(PICKER_LEAST, math.min(room * PICKER_MOST, room - SEARCH_LEAST - 6)) or room
	local picker = math.max(PICKER_LEAST, math.min(w.pickerNeed or PICKER_LEAST, most))
	w.picker:ClearAllPoints()
	w.picker:SetPoint("LEFT", bar, "LEFT", PAD - 4, 0)
	w.picker:SetWidth(picker)
	w.pickerText:SetWidth(math.max(1, picker - 20))
	if w.search then
		w.search:ClearAllPoints()
		w.search:SetPoint("LEFT", w.picker, "RIGHT", 6, 0)
		w.search:SetPoint("RIGHT", bar, "RIGHT", x + ICON_GAP - 6, 0)
	end
end

function TitleLine(w)
	local which = w.which
	local key, _, live = Layout.Viewed(which)
	local c = CharacterOf(key)
	local text = ClassHex(c and c.class) .. Plain(Named(key, c)) .. "|r"
	local parts = {}
	if which == "bank" then
		parts[#parts + 1] = Word("BANK", "Bank")
	end
	if not live and c then
		local seen = c.seen
		if which == "bank" then
			seen = c.bankSeen
		end
		local asOf = AsOf(seen)
		if asOf then
			parts[#parts + 1] = asOf
		end
	end
	if #parts > 0 then
		text = text .. DIM_HEX .. "  ·  " .. table.concat(parts, "  ·  ") .. "|r"
	end
	w.pickerText:SetWidth(0)
	w.pickerText:SetText(text)
	w.pickerNeed = math.ceil(TextWidth(w.pickerText)) + 4 + 18
	ArrangeBar(w)
end

local function Range(w)
	return math.max(0, (w.contentH or 0) - (w.viewH or 0))
end

local function ScrollBar(w)
	local range = Range(w)
	if range <= 0 then
		w.track:Hide()
		return
	end
	local trackH = w.viewH or 0
	local thumbH = math.max(THUMB_LEAST, trackH * trackH / math.max(1, w.contentH))
	local y = (trackH - thumbH) * ((w.offset or 0) / range)
	w.thumb:ClearAllPoints()
	w.thumb:SetPoint("TOPLEFT", w.track, "TOPLEFT", 0, -y)
	w.thumb:SetPoint("TOPRIGHT", w.track, "TOPRIGHT", 0, -y)
	w.thumb:SetHeight(thumbH)
	w.track:Show()
end

function SetOffset(w, offset)
	offset = math.max(0, math.min(Range(w), offset or 0))
	w.offset = offset
	w.scroll:SetVerticalScroll(offset)
	ScrollBar(w)
end

local function RowHeight()
	local size = Opt("slotSize")
	if not Finite(size) or size <= 0 then
		size = 36
	end
	return PITCH * size / SLOT
end

local function CursorY(w)
	local ok, _, y = pcall(GetCursorPosition)
	local okScale, scale = pcall(w.frame.GetEffectiveScale, w.frame)
	if ok and okScale and Finite(y) and Finite(scale) and scale > 0 then
		return y / scale
	end
	return nil
end

local function MakeView(w)
	local frame = w.frame
	local scroll = Own(CreateFrame("ScrollFrame", nil, frame))
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		if Finite(delta) then
			SetOffset(w, (w.offset or 0) - delta * WHEEL_ROWS * RowHeight())
		end
	end)
	local child = Own(CreateFrame("Frame", nil, scroll))
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	local content = Own(CreateFrame("Frame", nil, child))
	content:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
	content:SetSize(1, 1)
	w.scroll, w.child, w.content = scroll, child, content
	frame.content = content
	local track = Own(CreateFrame("Frame", nil, frame))
	track:SetWidth(TRACK_W)
	track:EnableMouse(true)
	track:Hide()
	w.trackBack = Own(track:CreateTexture(nil, "BACKGROUND"))
	w.trackBack:SetAllPoints(track)
	local thumb = Own(CreateFrame("Frame", nil, track))
	thumb:EnableMouse(true)
	w.thumbBack = Own(thumb:CreateTexture(nil, "ARTWORK"))
	w.thumbBack:SetAllPoints(thumb)
	w.track, w.thumb = track, thumb
	track:SetScript("OnMouseDown", function()
		local y = CursorY(w)
		local ok, top = pcall(thumb.GetTop, thumb)
		if y and ok and Finite(top) then
			local page = (w.viewH or 0) * 0.9
			SetOffset(w, (w.offset or 0) + (y > top and -page or page))
		end
	end)
	thumb:SetScript("OnMouseDown", function(_, mouse)
		if mouse == "LeftButton" then
			w.drag = { y = CursorY(w), offset = w.offset or 0 }
		end
	end)
	thumb:SetScript("OnMouseUp", function()
		w.drag = nil
	end)
	thumb:SetScript("OnEnter", function()
		w.thumbOver = true
		local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
		w.thumbBack:SetColorTexture(ar, ag, ab, 0.5)
	end)
	thumb:SetScript("OnLeave", function()
		w.thumbOver = false
		local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
		w.thumbBack:SetColorTexture(ar, ag, ab, 0.25)
	end)
	w.message = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	w.message:SetJustifyH("CENTER")
	w.message:SetPoint("TOP", frame, "TOP", 0, -(BAR + INNER + 14))
	w.message:Hide()
end

local function ThumbDrag(w)
	local drag = w.drag
	local y = CursorY(w)
	if not (drag and drag.y and y) then
		return
	end
	local range = Range(w)
	local trackH = w.viewH or 0
	local thumbH = math.max(THUMB_LEAST, trackH * trackH / math.max(1, w.contentH or 1))
	local free = trackH - thumbH
	if free > 0 then
		SetOffset(w, drag.offset + (drag.y - y) * range / free)
	end
end

local function FootLabel(w, tip, onClick)
	local holder = Own(CreateFrame("Frame", nil, w.foot))
	holder:SetHeight(FOOT)
	holder:EnableMouse(true)
	local text = ns.OwnText(holder, "OVERLAY", "GameFontHighlightSmall")
	text:SetAllPoints(holder)
	text:SetWordWrap(false)
	holder:SetScript("OnEnter", function()
		Run("window", tip, w, holder)
	end)
	holder:SetScript("OnLeave", function()
		Untip(holder)
	end)
	if onClick then
		holder:SetScript("OnMouseUp", function(_, mouse)
			Run("window", onClick, w, holder, mouse)
		end)
	end
	return { frame = holder, text = text }
end

local function GoldTip(w, owner)
	local tip = Tip(owner)
	if not tip then
		return
	end
	local near, total, other, others = {}, 0, 0, 0
	for _, c in ipairs(Characters()) do
		if type(c) == "table" and Finite(c.money) and c.money >= 0 then
			if c.near == true or c.me == true then
				near[#near + 1] = c
				total = total + c.money
			else
				other, others = other + c.money, others + 1
			end
		end
	end
	table.sort(near, function(a, b)
		if a.money ~= b.money then
			return a.money > b.money
		end
		return tostring(a.key) < tostring(b.key)
	end)
	tip:SetText("Gold", 1, 1, 1)
	for index, c in ipairs(near) do
		if index > MOST_GOLD then
			tip:AddLine(("and %d more"):format(#near - MOST_GOLD), DIM[1], DIM[2], DIM[3])
			break
		end
		local r, g, b = ClassRGB(c.class)
		tip:AddDoubleLine(Plain(Named(c.key, c)), Money(c.money), r or 1, g or 1, b or 1, 1, 1, 1)
	end
	if #near > 1 then
		tip:AddDoubleLine("Total", Money(total), DIM[1], DIM[2], DIM[3], 1, 1, 1)
	end
	if others > 0 then
		tip:AddDoubleLine(("Other realms (%d)"):format(others), Money(other), DIM[1], DIM[2], DIM[3], DIM[1], DIM[2], DIM[3])
	end
	if #near == 0 and others == 0 then
		tip:AddLine("Flat UI keeps the gold of each character that logs in with Flat UI bags on.", DIM[1], DIM[2], DIM[3], true)
	end
	local _, mine = Layout.Viewed(w.which)
	local okSession, session, seconds = pcall(Call, ns, "SessionMoney")
	if mine and okSession and Finite(session) and session ~= 0 then
		local hourly = ""
		if Finite(seconds) and seconds >= HOURLY_AFTER then
			hourly = (" (%s an hour)"):format(Money(math.abs(session) * 3600 / seconds))
		end
		tip:AddLine(" ")
		if session > 0 then
			tip:AddDoubleLine("This session", "+" .. Money(session) .. hourly, DIM[1], DIM[2], DIM[3], SESSION_GAIN[1], SESSION_GAIN[2],
				SESSION_GAIN[3])
		else
			tip:AddDoubleLine("This session", "-" .. Money(-session) .. hourly, DIM[1], DIM[2], DIM[3], SESSION_LOSS[1], SESSION_LOSS[2],
				SESSION_LOSS[3])
		end
	end
	if mine and type(ns.SessionRestart) == "function" then
		tip:AddLine("Ctrl-click: count this session from now.", DIM[1], DIM[2], DIM[3], true)
	end
	tip:Show()
end

local function GoldClick(w, owner, mouse)
	local okCtrl, ctrl = pcall(IsControlKeyDown)
	if mouse ~= "LeftButton" or not (okCtrl and not IsSecret(ctrl) and ctrl == true) then
		return
	end
	local _, mine = Layout.Viewed(w.which)
	if not mine then
		return
	end
	local ok, done = pcall(Call, ns, "SessionRestart")
	if not (ok and done == true) then
		return
	end
	local tip = GameTooltip
	if type(tip) == "table" and not ns.Forbidden(tip) then
		local okOwned, owned = pcall(tip.IsOwned, tip, owner)
		if okOwned and owned == true then
			GoldTip(w, owner)
		end
	end
	Request("footer", w.which)
end

local function Kinds(w)
	local key = Layout.Viewed(w.which)
	local list = Call(Data, "Free", key, w.which)
	local out = {}
	for _, kind in ipairs(type(list) == "table" and list or {}) do
		if type(kind) == "table" and Finite(kind.free) and Finite(kind.total) and kind.total > 0 then
			local label = kind.label
			if type(label) ~= "string" or IsSecret(label) or label == "" then
				label = type(kind.kind) == "table" and type(kind.kind.label) == "string" and kind.kind.label or "Bags"
			end
			out[#out + 1] = { label = label, free = math.max(0, math.floor(kind.free)), total = math.floor(kind.total), general = kind.general == true }
		end
	end
	return out
end

local function FreeTip(w, owner)
	local tip = Tip(owner)
	if not tip then
		return
	end
	tip:SetText("Free slots", 1, 1, 1)
	local kinds, apart = Kinds(w), false
	for _, kind in ipairs(kinds) do
		if kind.general then
			tip:AddDoubleLine(Plain(kind.label), ("%d of %d"):format(kind.free, kind.total), DIM[1], DIM[2], DIM[3], 1, 1, 1)
		end
	end
	for _, kind in ipairs(kinds) do
		if not kind.general then
			if not apart then
				apart = true
				tip:AddLine(" ")
				tip:AddLine("Not counted, for certain items only", DIM[1], DIM[2], DIM[3])
			end
			tip:AddDoubleLine(Plain(kind.label), ("%d of %d"):format(kind.free, kind.total), DIM[1], DIM[2], DIM[3], 1, 1, 1)
		end
	end
	tip:Show()
end

local function FreeTexts(w)
	local main
	for _, kind in ipairs(Kinds(w)) do
		if kind.general then
			main = kind
			break
		end
	end
	if not main then
		return { "" }
	end
	local colour = main.free <= 0 and NONE_HEX or (main.free <= LOW and LOW_HEX) or WHITE_HEX
	local count = ("%s%d|r%s/%d|r"):format(colour, main.free, DIM_HEX, main.total)
	return { DIM_HEX .. "Free|r " .. count, count }, main.free
end

local function JunkCount()
	local count = ns.ErrandsJunkCount
	if type(count) ~= "function" then
		return 0, 0, 0, false
	end
	local ok, n, waits, value, unknown = pcall(count)
	if not ok then
		return 0, 0, 0, false
	end
	return Finite(n) and math.max(0, math.floor(n)) or 0, Finite(waits) and math.max(0, math.floor(waits)) or 0,
		Finite(value) and math.max(0, math.floor(value)) or 0, not IsSecret(unknown) and unknown == true
end

local function Selling()
	local selling = ns.ErrandsSelling
	if type(selling) ~= "function" then
		return false
	end
	local ok, on = pcall(selling)
	return ok and on == true
end

local function Plural(n, one, many)
	return n == 1 and one or many
end

local function SellTest(record)
	return Call(B.Categories, "IsJunk", record) == true
end

local function SellTip(w, owner)
	local tip = Tip(owner)
	if not tip then
		return
	end
	local n, waits, value = w.sellCount or 0, w.sellWaits or 0, w.sellValue or 0
	local worth = ""
	if value > 0 then
		worth = (w.sellUnknown and " for at least %s" or " for %s"):format(Money(value))
	end
	tip:SetText("Sell junk", 1, 1, 1)
	if Selling() then
		tip:AddLine(("Selling: %d %s left."):format(n, Plural(n, "item", "items")), DIM[1], DIM[2], DIM[3], true)
	else
		tip:AddLine(("Sells %d %s%s, as Errands sells: grey items with a price and the items of your sell list, one at a time."):format(n,
			Plural(n, "item", "items"), worth), DIM[1], DIM[2], DIM[3], true)
	end
	if waits > 0 then
		tip:AddLine(("%d more of your sell list %s for the next click."):format(waits, Plural(waits, "waits", "wait")), DIM[1], DIM[2], DIM[3],
			true)
	end
	local list = {}
	local okEntries, entries = pcall(Call, Layout, "Entries", "bags")
	for _, entry in ipairs(okEntries and type(entries) == "table" and entries or {}) do
		local ok, junk = pcall(SellTest, entry.record)
		if ok and junk == true then
			list[#list + 1] = entry
		end
	end
	if #list > 0 and Fn(Layout, "ListTip") then
		tip:AddLine(" ")
		pcall(Layout.ListTip, tip, list, { worth = true })
	end
	tip:Show()
	Call(Layout, "LightWith", "bags", SellTest)
end

local function SellClick(w)
	local sell = ns.ErrandsSellJunk
	if type(sell) ~= "function" then
		return
	end
	local ok, why = sell()
	if ok == false and type(why) == "string" and why ~= "" and why ~= "busy" then
		print(("Flat UI: Sold nothing: %s."):format(why))
	end
	Request("footer", "bags")
end

function Tips.Again(owner, fn, ...)
	local tip = GameTooltip
	if type(owner) ~= "table" or type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, owner)
	local okShown, shown = pcall(owner.IsShown, owner)
	if ok and owned == true and okShown and shown == true then
		Run("window", fn, ...)
	end
end

local function Busy()
	local busy, left, perClick = Call(Bank, "Busy")
	left = Finite(left) and math.max(0, math.floor(left)) or 0
	if busy == "deposit" or busy == "takeout" then
		return busy, left, perClick == true
	end
	return busy and true or nil, left, perClick == true
end

local function MoveTip(w, owner, kind)
	local busy, left, perClick = Busy()
	if busy == true or busy == kind then
		if perClick then
			Say(owner, kind == "deposit" and "Deposit" or "Take out", ("Each click moves the next item: %d %s left."):format(left,
				Plural(left, "is", "are")))
		else
			Say(owner, kind == "deposit" and "Deposit" or "Take out", "A click stops it.")
		end
		return
	end
	local n = kind == "deposit" and (w.depositCount or 0) or (w.takeoutCount or 0)
	local items = Plural(n, "item", "items")
	if kind == "deposit" then
		Say(owner, "Deposit", ("Puts the %d %s of your bags that match the search in the bank, one at a time."):format(n, items))
	else
		Say(owner, "Take out", ("Takes the %d %s of the bank that match the search out to your bags, one at a time."):format(n, items))
	end
end

local function MoveClick(w, kind)
	Call(Bank, kind == "deposit" and "Deposit" or "TakeOut")
	Request("footer", "bank")
end

local function FootButton(w, text, width, onClick, onEnter, onLeave)
	local button = Own(CreateFrame("Button", nil, w.foot))
	button:SetSize(width, FOOT_BUTTON)
	button:RegisterForClicks("LeftButtonUp")
	local plate = { button = button, usable = true }
	plate.outline = ns.Outline(button, button)
	plate.hover = Own(button:CreateTexture(nil, "HIGHLIGHT"))
	plate.hover:SetAllPoints(button)
	plate.label = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	plate.label:SetPoint("CENTER", button, "CENTER", 0, 0)
	plate.label:SetWordWrap(false)
	plate.label:SetText(text)
	local function Press(on)
		on = on == true and plate.usable
		if on == (plate.pressed == true) then
			return
		end
		plate.pressed = on or nil
		plate.label:SetPoint("CENTER", button, "CENTER", 0, on and -1 or 0)
		if on then
			local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
			plate.hover:SetColorTexture(ar, ag, ab, 0)
		else
			PaintPlate(plate)
		end
	end
	local function Left()
		Press(false)
		if onLeave then
			Run("window", onLeave, button)
		end
	end
	button:SetScript("OnClick", function()
		if plate.usable then
			onClick(button)
		end
	end)
	button:SetScript("OnMouseDown", function(_, mouse)
		if mouse == "LeftButton" then
			Press(true)
		end
	end)
	button:SetScript("OnMouseUp", function()
		Press(false)
	end)
	button:SetScript("OnEnter", function()
		onEnter(button)
	end)
	button:SetScript("OnLeave", function()
		Left()
		Untip(button)
	end)
	button:SetScript("OnHide", function()
		if not w.frame:IsVisible() then
			Unsplit(w)
		end
		Left()
		Untip(button)
	end)
	function button.Keep(wanted)
		button:SetScript("OnUpdate", function()
			local ok, keep = pcall(wanted)
			if not ok or not keep then
				button:Hide()
			end
		end)
	end
	function button.SetUsable(on)
		plate.usable = on == true
		if not plate.usable then
			Press(false)
		end
		PaintPlate(plate)
	end
	function button.SetLabel(words)
		plate.label:SetText(words)
	end
	w.plates[#w.plates + 1] = plate
	PaintPlate(plate)
	return button
end

local function MakeFoot(w)
	local frame = w.frame
	local foot = Own(CreateFrame("Frame", nil, frame))
	foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 0)
	foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 0)
	foot:SetHeight(FOOT)
	w.foot = foot
	local rule = Rule(frame)
	rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, FOOT)
	rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, FOOT)
	w.rules[#w.rules + 1] = rule
	w.footRule = rule
	w.free = FootLabel(w, FreeTip)
	w.free.text:SetJustifyH(w.which == "bags" and "RIGHT" or "LEFT")
	local strip = Own(CreateFrame("Frame", nil, frame))
	strip:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, INNER)
	strip:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, INNER)
	strip:SetHeight(STRIP)
	strip:Hide()
	w.strip = strip
	local stripRule = Rule(strip)
	stripRule:SetPoint("BOTTOMLEFT", strip, "TOPLEFT", 0, STRIP_GAP)
	stripRule:SetPoint("BOTTOMRIGHT", strip, "TOPRIGHT", 0, STRIP_GAP)
	w.rules[#w.rules + 1] = stripRule
	if w.which == "bags" then
		w.gold = FootLabel(w, GoldTip, GoldClick)
		w.gold.text:SetJustifyH("LEFT")
		local sell = FootButton(w, "Sell junk", SELL_W, function()
			Run("window", SellClick, w)
		end, function(button)
			Run("window", SellTip, w, button)
		end, function()
			Call(Layout, "LightWith", "bags", nil)
		end)
		sell:Hide()
		sell.Keep(function()
			return w.sellOn == true and B.atMerchant == true and Shown(w)
		end)
		w.sell = sell
	else
		for _, kind in ipairs({ "deposit", "takeout" }) do
			local button = FootButton(w, kind == "deposit" and "Deposit" or "Take out", MOVE_W, function()
				Run("window", MoveClick, w, kind)
			end, function(owner)
				Run("window", MoveTip, w, owner, kind)
			end)
			button:Hide()
			button.Keep(function()
				return w.moveOn == true and Call(Bank, "Live") == true and Shown(w)
			end)
			w[kind] = button
		end
	end
end

local function WindowWidth(w)
	local ok, width = pcall(w.frame.GetWidth, w.frame)
	return ok and Finite(width) and width or BOXES[w.which][1]
end

local function FitFree(w, room)
	local texts = w.freeTexts or { "" }
	for index, words in ipairs(texts) do
		w.free.text:SetText(words)
		if index == #texts or TextWidth(w.free.text) <= room then
			return
		end
	end
end

function ArrangeFoot(w)
	local foot = w.foot
	local room = WindowWidth(w) - 2 * PAD
	if w.which == "bags" then
		local gold = w.gold
		local right, gap = foot, 0
		if w.sell and w.sell:IsShown() then
			w.sell:ClearAllPoints()
			w.sell:SetPoint("RIGHT", foot, "RIGHT", 0, 0)
			right, gap = w.sell, -8
			room = room - SELL_W - 8
		end
		local left = foot
		if gold then
			local goldW = math.max(1, math.ceil(TextWidth(gold.text)) + 2)
			gold.frame:ClearAllPoints()
			gold.frame:SetPoint("LEFT", foot, "LEFT", 0, 0)
			gold.frame:SetWidth(goldW)
			left = gold.frame
			room = room - goldW - FOOT_GAP
		end
		local texts = w.freeTexts or { "" }
		w.free.text:SetText(texts[#texts])
		local least = math.max(FREE_ROOM, math.ceil(TextWidth(w.free.text)))
		local coins, coinsW = Call(B.Currency, "Fit", w, room - least - FOOT_GAP)
		if coins and Finite(coinsW) then
			coins:ClearAllPoints()
			coins:SetPoint("LEFT", left, left == foot and "LEFT" or "RIGHT", left == foot and 0 or FOOT_GAP, 0)
			left, room = coins, room - coinsW - FOOT_GAP
		end
		w.free.frame:ClearAllPoints()
		w.free.frame:SetPoint("LEFT", left, left == foot and "LEFT" or "RIGHT", left == foot and 0 or FOOT_GAP, 0)
		w.free.frame:SetPoint("RIGHT", right, right == foot and "RIGHT" or "LEFT", gap, 0)
	else
		local right = foot
		for _, kind in ipairs({ "takeout", "deposit" }) do
			local button = w[kind]
			if button and button:IsShown() then
				button:ClearAllPoints()
				button:SetPoint("RIGHT", right, right == foot and "RIGHT" or "LEFT", right == foot and 0 or -4, 0)
				room = room - MOVE_W - (right == foot and 8 or 4)
				right = button
			end
		end
		w.free.frame:ClearAllPoints()
		w.free.frame:SetPoint("LEFT", foot, "LEFT", 0, 0)
		w.free.frame:SetPoint("RIGHT", right, right == foot and "RIGHT" or "LEFT", right == foot and 0 or -8, 0)
	end
	FitFree(w, room)
end

local function FootLeast(w)
	if w.which == "bags" then
		return 2 * PAD + GOLD_ROOM + FOOT_GAP + FREE_ROOM + 8 + SELL_W
	end
	return 2 * PAD + FREE_ROOM + 8 + MOVE_W + 4 + MOVE_W
end

local function GoldFloat(w, delta)
	local float = w.float
	if float == nil then
		local ok, made = pcall(function()
			local holder = Own(CreateFrame("Frame", nil, w.foot))
			holder:SetFrameLevel(math.min(9000, w.frame:GetFrameLevel() + 40))
			holder:SetSize(1, 1)
			holder:SetPoint("BOTTOMLEFT", w.gold.frame, "TOPLEFT", 0, -6)
			holder:Hide()
			local text = ns.OwnText(holder, "OVERLAY", "GameFontHighlightSmall")
			text:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
			text:SetWordWrap(false)
			local group = holder:CreateAnimationGroup()
			local move = group:CreateAnimation("Translation")
			move:SetOffset(0, CUE.rise)
			move:SetDuration(CUE.seconds)
			move:SetSmoothing("OUT")
			local fade = group:CreateAnimation("Alpha")
			fade:SetFromAlpha(1)
			fade:SetToAlpha(0)
			fade:SetStartDelay(CUE.fade)
			fade:SetDuration(CUE.seconds - CUE.fade)
			local cue = { holder = holder, text = text, group = group, sum = 0 }
			group:SetScript("OnFinished", function()
				holder:Hide()
				cue.sum = 0
			end)
			return cue
		end)
		float = ok and made or false
		w.float = float
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
	local colour = float.sum > 0 and SESSION_GAIN or SESSION_LOSS
	float.text:SetText((float.sum > 0 and "+" or "-") .. Money(math.abs(float.sum)))
	float.text:SetTextColor(colour[1], colour[2], colour[3], 1)
	float.holder:Show()
	float.group:Play()
end

local function FullPulse(w)
	local pulse = w.pulse
	if pulse == nil then
		local ok, made = pcall(function()
			local group = w.free.frame:CreateAnimationGroup()
			for index = 1, CUE.pulses * 2 do
				local step = group:CreateAnimation("Alpha")
				local down = index % 2 == 1
				step:SetFromAlpha(down and 1 or CUE.dip)
				step:SetToAlpha(down and CUE.dip or 1)
				step:SetDuration(CUE.half)
				step:SetOrder(index)
			end
			group:SetLooping("NONE")
			return group
		end)
		pulse = ok and made or false
		w.pulse = pulse
	end
	if pulse then
		pulse:Stop()
		pulse:Play()
	end
end

local function FootCues(w, key, mine, live, money, free)
	local own = mine and live and w.open == true and not w.warming
	if w.gold then
		if own and Finite(money) and w.goldKey == key and Finite(w.goldShown) and money ~= w.goldShown then
			GoldFloat(w, money - w.goldShown)
		end
		w.goldShown, w.goldKey = Finite(money) and money or nil, key
	end
	if own and Finite(free) then
		if free <= 0 and Finite(w.lastFree) and w.lastFree > 0 then
			FullPulse(w)
		end
		w.lastFree = free
	end
end

function Footer(w)
	local which = w.which
	local key, mine, live = Layout.Viewed(which)
	local free
	w.freeTexts, free = FreeTexts(w)
	if which == "bags" then
		if w.gold then
			local money = Call(Data, "Money", key)
			w.gold.text:SetText(Finite(money) and money >= 0 and Money(money) or "")
			Run("window", FootCues, w, key, mine, live, money, free)
		end
		Call(B.Currency, "Read", w, key, mine)
		if w.sell then
			local wanted = mine and live and B.atMerchant == true and Opt("sellButton") ~= false
			local n, waits, value, unknown, selling = 0, 0, 0, false, false
			if wanted then
				n, waits, value, unknown = JunkCount()
				selling = Selling()
			end
			w.sellCount, w.sellWaits, w.sellValue, w.sellUnknown = n, waits, value, unknown
			w.sellOn = wanted and (n > 0 or selling)
			if w.sellOn then
				w.sell.SetLabel(selling and (n > 0 and ("Selling... %d"):format(n) or "Selling...") or ("Sell junk (%d)"):format(n))
				w.sell.SetUsable(not selling)
				w.sell:Show()
			else
				w.sell:Hide()
			end
		end
	elseif w.deposit then
		local on = live and Opt("bankButtons") ~= false
		local busy, left, perClick = nil, 0, false
		if on then
			busy, left, perClick = Busy()
		end
		local wanted = on and Call(Search, "Active") == true
		if wanted then
			w.depositCount = Matches("bags", key, false)
			w.takeoutCount = Matches("bank", key, false)
		else
			w.depositCount, w.takeoutCount = 0, 0
		end
		w.moveOn = on and (wanted or busy ~= nil)
		for _, kind in ipairs({ "deposit", "takeout" }) do
			local button = w[kind]
			local count = kind == "deposit" and w.depositCount or w.takeoutCount
			local running = busy == true or busy == kind
			if on and (running or (wanted and count > 0)) then
				if running and perClick then
					button.SetLabel(("%s (%d)"):format(kind == "deposit" and "Deposit" or "Take out", left))
				elseif running then
					button.SetLabel("Stop")
				else
					button.SetLabel(("%s (%d)"):format(kind == "deposit" and "Deposit" or "Take out", count))
				end
				button:Show()
			else
				button:Hide()
			end
		end
	end
	ArrangeFoot(w)
	if w.sell then
		Tips.Again(w.sell, SellTip, w, w.sell)
	end
	for _, kind in ipairs({ "deposit", "takeout" }) do
		if w[kind] then
			Tips.Again(w[kind], MoveTip, w, w[kind], kind)
		end
	end
	if w.gold then
		Tips.Again(w.gold.frame, GoldTip, w, w.gold.frame)
	end
	if w.free then
		Tips.Again(w.free.frame, FreeTip, w, w.free.frame)
	end
end

local function StripHeight(w)
	local strip = w.strip
	if not strip or not strip:IsShown() then
		return 0
	end
	local ok, height = pcall(strip.GetHeight, strip)
	if not ok or not Finite(height) or height < 1 then
		return 0
	end
	return height
end

local function Message(w)
	if w.which ~= "bank" then
		return nil
	end
	local key, mine, live = Layout.Viewed("bank")
	if live then
		return nil
	end
	local c = CharacterOf(key)
	if c and Finite(c.bankSeen) then
		return nil
	end
	if mine then
		return "Visit a banker once with Flat UI bags on, and your bank shows here wherever you are."
	end
	return ("%s has not visited a banker with Flat UI bags on."):format(Plain(Named(key, c)))
end

function Resize(w, keep)
	local which = w.which
	local cw, ch = Layout.Size(which)
	cw = Finite(cw) and math.max(0, cw) or 0
	ch = Finite(ch) and math.max(0, ch) or 0
	local least = 2 * PAD + PICKER_LEAST + (w.search and (SEARCH_LEAST + 12) or 6) + 3 * (ICON + ICON_GAP) + CLOSE + 8
	least = math.max(least, FootLeast(w))
	local strip = StripHeight(w)
	if strip > 0 then
		least = math.max(least, math.ceil((w.stripW or 0) + 2 * PAD))
	end
	local width = math.max(least, math.ceil(cw + 2 * PAD))
	local fixed = BAR + INNER + INNER + FOOT + (strip > 0 and (strip + 2 * STRIP_GAP) or 0)
	local okScreen, screen = pcall(UIParent.GetHeight, UIParent)
	screen = okScreen and Finite(screen) and screen > 0 and screen or 768
	local most = math.max(fixed + LEAST_VIEW, math.floor(screen * MOST))
	local message = ch <= 0 and Message(w) or nil
	local view
	if ch <= 0 then
		view = message and MESSAGE_VIEW or LEAST_VIEW
	else
		view = math.max(LEAST_VIEW, math.min(math.ceil(ch), most - fixed))
	end
	w.slack = nil
	if keep and Finite(w.viewH) and w.viewH > view then
		local kept = math.min(w.viewH, math.max(view, most - fixed))
		w.slack = kept > view or nil
		view = kept
	end
	w.frame:SetSize(width, fixed + view)
	local left = math.floor((width - cw) / 2 + 0.5)
	w.scroll:ClearAllPoints()
	w.scroll:SetPoint("TOPLEFT", w.frame, "TOPLEFT", left, -(BAR + INNER))
	w.scroll:SetSize(math.max(1, cw), view)
	w.child:SetSize(math.max(1, cw), math.max(1, ch))
	w.viewH, w.contentH = view, ch
	w.track:ClearAllPoints()
	w.track:SetPoint("TOPRIGHT", w.frame, "TOPRIGHT", -2, -(BAR + INNER))
	w.track:SetHeight(view)
	for _, rule in ipairs(w.rules) do
		rule:SetHeight(ns.Pixels(w.frame, 1))
	end
	if message then
		w.message:SetWidth(math.max(1, width - 4 * PAD))
		w.message:SetText(message)
		w.message:Show()
	else
		w.message:Hide()
	end
	SetOffset(w, w.offset)
	ArrangeBar(w)
	ArrangeFoot(w)
end

local function Slots(w)
	local strip = w.strip
	if not strip then
		return
	end
	local width, height = 0, 0
	local _, mine, live = Layout.Viewed(w.which)
	if live then
		local wide, h
		if w.which == "bank" then
			wide, h = Call(Bank, "Slots", strip)
		elseif mine and Opt("bagSlots") ~= false then
			wide, h = Call(B.Slots, "Row", strip)
		end
		height = Finite(h) and h > 0 and h or 0
		width = Finite(wide) and wide > 0 and wide or 0
	end
	if height > 0 then
		w.stripW = width
		strip:SetHeight(height)
		strip:Show()
	else
		w.stripW = 0
		strip:Hide()
	end
end

local function Unslack(w)
	if Call(Layout, "MenuOf", w.which) == true then
		return
	end
	local ok, over = pcall(w.frame.IsMouseOver, w.frame)
	if ok and not IsSecret(over) and over == false then
		w.slack = nil
		Resize(w, false)
		Window.Place(w.which)
	end
end

do
	local function CursorX(w)
		local ok, x = pcall(GetCursorPosition)
		local okScale, scale = pcall(w.frame.GetEffectiveScale, w.frame)
		if ok and okScale and Finite(x) and Finite(scale) and scale > 0 then
			return x / scale
		end
		return nil
	end

	local function Width(w)
		local value = ns.Get(GRIP.paths[w.which])
		return Finite(value) and math.floor(value + 0.5) or nil
	end

	local function Tell(w)
		local grip, n = w.grip, w.sizing and w.sizing.now or Width(w)
		if not (grip and n) then
			return
		end
		Say(grip.button, w.which == "bank" and "Bank width in slots" or "Width in slots", ("Drag to change the width: %d slots."):format(n))
	end

	local function Down(w)
		if w.moving or w.sizing then
			return
		end
		local path = GRIP.paths[w.which]
		local def = type(ns.Def) == "function" and ns.Def(path) or nil
		local start, x = Width(w), CursorX(w)
		if type(def) ~= "table" or not start or not x then
			return
		end
		Layout.CloseMenu(w.which)
		w.sizing = { x = x, start = start, before = ns.Get(path), now = start, path = path, def = def }
		Grip.Paint(w)
	end

	local function Up(w)
		local sizing = w.sizing
		if not sizing then
			return
		end
		w.sizing = nil
		Grip.Paint(w)
		local now = ns.Get(sizing.path)
		if now ~= sizing.before then
			local home = ns.PanelHome
			if type(home) == "table" and type(home.Noted) == "function" then
				pcall(home.Noted, sizing.def, sizing.before, now)
			end
			if type(ns.RefreshPanel) == "function" then
				pcall(ns.RefreshPanel)
			end
		end
	end

	function Grip.Drag(w)
		local sizing = w.sizing
		local okDown, down = pcall(IsMouseButtonDown, "LeftButton")
		if okDown and not IsSecret(down) and not down then
			Up(w)
			return
		end
		local x = CursorX(w)
		if not x then
			return
		end
		local def = sizing.def
		local low = Finite(def.min) and def.min or 1
		local high = Finite(def.max) and def.max or sizing.start
		local delta = (x - sizing.x) * (w.which == "bags" and -1 or 1)
		local n = math.max(low, math.min(high, sizing.start + math.floor(delta / RowHeight() + 0.5)))
		if n == sizing.now then
			return
		end
		sizing.now = n
		ns.Set(sizing.path, n)
		Request("layout", w.which)
		local tip = GameTooltip
		if type(tip) == "table" and not ns.Forbidden(tip) then
			local ok, owned = pcall(tip.IsOwned, tip, w.grip.button)
			if ok and owned == true then
				Tell(w)
			end
		end
	end

	function Grip.Make(w)
		local frame = w.frame
		local button = Own(CreateFrame("Button", nil, frame))
		button:SetSize(GRIP.size, GRIP.size)
		local corner = GRIP.corners[w.which]
		button:SetPoint(corner, frame, corner, 0, 0)
		pcall(button.SetFrameLevel, button, w.foot:GetFrameLevel() + GRIP.level)
		local grip = { button = button, lines = {} }
		for _, spot in ipairs(GRIP.lines[w.which]) do
			grip.lines[#grip.lines + 1] = Stroke(button, "OVERLAY", spot[1], spot[2], spot[3], spot[4])
		end
		w.grip = grip
		button:SetScript("OnEnter", function()
			grip.over = true
			Grip.Paint(w)
			Run("window", Tell, w)
		end)
		button:SetScript("OnLeave", function()
			grip.over = nil
			Grip.Paint(w)
			Untip(button)
		end)
		button:SetScript("OnMouseDown", function(_, mouse)
			if mouse == "LeftButton" then
				Run("window", Down, w)
			end
		end)
		button:SetScript("OnMouseUp", function()
			Run("window", Up, w)
		end)
		button:SetScript("OnHide", function()
			Run("window", Up, w)
			Untip(button)
		end)
		Grip.Paint(w)
	end
end

local function Tick(w, elapsed)
	if w.warming then
		return
	end
	if w.sizing then
		Run("window", Grip.Drag, w)
	end
	if w.drag then
		Run("window", ThumbDrag, w)
	elseif w.slack and not w.moving then
		Run("window", Unslack, w)
	end
	if Sorting(w) then
		w.pulsing = true
		Run("window", Pulse, w)
	elseif w.pulsing then
		w.pulsing = nil
		Run("window", PaintSort, w)
		if w.icons.sort then
			Tips.Again(w.icons.sort.button, Tips.sort, w, w.icons.sort.button)
		end
	end
	w.wait = (w.wait or 0) - (Finite(elapsed) and elapsed or 0)
	if w.wait > 0 then
		return
	end
	w.wait = POLL
	local sign
	if w.which == "bags" then
		sign = w.sellOn and tostring(Selling()) or ""
	else
		sign = w.moveOn and tostring(Busy()) or ""
	end
	if sign ~= (w.sign or "") then
		w.sign = sign
		Run("window", Footer, w)
	end
end

local function Make(which)
	local frame = Own(CreateFrame("Frame", NAMES[which], UIParent))
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	pcall(frame.SetDontSavePosition, frame, true)
	frame:SetSize(BOXES[which][1], BOXES[which][2])
	frame:Hide()
	local w = { which = which, frame = frame, icons = {}, rules = {}, plates = {}, offset = 0 }
	windows[which] = w
	w.outline = ns.Outline(frame, frame)
	MakeBar(w)
	MakeView(w)
	MakeFoot(w)
	Grip.Make(w)
	frame:SetScript("OnShow", function()
		Run("window", Showing, w)
	end)
	frame:SetScript("OnHide", function()
		Run("window", Hiding, w)
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		Tick(w, elapsed)
	end)
	if not watcher then
		watcher = Own(CreateFrame("Frame", nil, UIParent))
		watcher:SetSize(1, 1)
		watcher:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
		watcher:SetScript("OnShow", function()
			Missed()
		end)
	end
	Special(NAMES[which])
	Watching()
	PaintWindow(w)
	TitleLine(w)
	Resize(w)
	Window.Place(which)
	return w
end

function Showing(w)
	if w.warming then
		return
	end
	w.open = true
	w.keepNext, w.slack, w.goldShown, w.goldKey = nil, nil, nil, nil
	Run("window", Call, B, "LaidOut", w.which)
	Sound("IG_BACKPACK_OPEN")
	Watching()
	PaintWindow(w)
	Slots(w)
	Run("layout", Layout.Build, w.which)
	w.mode = Mode(w.which)
	w.offset = 0
	TitleLine(w)
	Footer(w)
	Run("search", MatchCount, w)
	Resize(w)
	Window.Place(w.which)
end

function Hiding(w, quiet)
	Unsplit(w)
	if w.warming then
		return
	end
	if w.frame:IsShown() then
		w.drag = nil
		if w.moving then
			Dropped(w)
		end
		if w.search then
			pcall(w.search.ClearFocus, w.search)
		end
		Layout.CloseMenu(w.which)
		return
	end
	w.open, w.drag, w.slack = false, nil, nil
	if w.float then
		pcall(w.float.group.Stop, w.float.group)
		w.float.holder:Hide()
		w.float.sum = 0
	end
	if w.pulse then
		pcall(w.pulse.Stop, w.pulse)
	end
	if w.moving then
		Run("window", Dropped, w)
	end
	if w.search then
		pcall(w.search.ClearFocus, w.search)
	end
	Layout.CloseMenu(w.which)
	EndBusy(w)
	if w.which == "bank" then
		Run("layout", Layout.Closed, "bank")
		if not Shown(windows.bags) then
			Run("window", Call, Search, "SetText", "")
		end
		Run("window", Call, B, "SetViewing", "bank", nil)
	end
	if not quiet then
		Sound("IG_BACKPACK_CLOSE")
	end
end

local function Unseen(w)
	Run("window", Hiding, w, true)
	if w.which == "bank" then
		local hidden = Fn(Bank, "Hidden")
		if hidden then
			pcall(hidden)
		end
	end
end

function Missed()
	for which, w in pairs(windows) do
		if w.open and not w.warming and not w.frame:IsShown() then
			Unseen(w)
			if which == "bags" then
				Run("window", Call, B, "HideBags")
			end
		end
	end
end

function Window.Get(which)
	if which ~= "bags" and which ~= "bank" then
		return nil
	end
	local w = windows[which] or Make(which)
	return w.frame
end

function Window.Place(which)
	local w = windows[which]
	if not w or w.moving or w.parked then
		return
	end
	local corner = CORNERS[which]
	local x, y
	local anchor = "BOTTOMLEFT"
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(NAMES[which], corner)
	end
	if not (Finite(x) and Finite(y)) then
		x, y = nil, nil
		if w.dropped then
			x, y = w.dropped[1], w.dropped[2]
		end
	end
	if not (Finite(x) and Finite(y)) then
		local box = BOXES[which]
		x, y, anchor = box[3], box[4], corner
		if which == "bags" then
			x, y = ns.BagsWindowStart(x, y)
		end
	end
	local key = ("%s:%.2f:%.2f"):format(anchor, x, y)
	if w.placed == key then
		return
	end
	w.placed = key
	local frame = w.frame
	frame:ClearAllPoints()
	frame:SetPoint(corner, UIParent, anchor, x, y)
	frame:SetClampedToScreen(true)
end

function Window.Show(which)
	if not On() then
		return
	end
	Window.Get(which)
	local w = windows[which]
	if not w then
		return
	end
	if w.warming then
		w.wantShow = true
		return
	end
	if w.frame:IsShown() then
		if w.mode ~= Mode(which) then
			Request("layout", which)
		end
		return
	end
	Window.Place(which)
	w.frame:Show()
end

function Window.Focus(which, toggle)
	local w = windows[which]
	if not (Shown(w) and w.search) then
		return false
	end
	local box = w.search
	local ok, focus = pcall(box.HasFocus, box)
	if toggle and ok and not IsSecret(focus) and focus == true then
		box:ClearFocus()
	else
		box:SetFocus()
	end
	return true
end

function Window.Hide(which)
	local w = windows[which]
	if not w then
		return
	end
	if w.warming then
		w.wantShow = false
		return
	end
	if w.frame:IsShown() then
		Unsplit(w)
		local visible = w.frame:IsVisible() == true
		w.frame:Hide()
		if not visible then
			Unseen(w)
		end
	end
end

local function Updating(w, flags, changed)
	local which = w.which
	local builds = Call(Layout, "Builds", which)
	if flags.look then
		PaintWindow(w)
		Run("search", Call, Search, "Paint")
		Call(Buttons, "Paint")
	end
	Slots(w)
	if flags.layout then
		Run("layout", Layout.Build, which)
		w.mode = Mode(which)
		if w.busy and Now() - w.busy >= BUSY_LEAST then
			EndBusy(w)
		end
		TitleLine(w)
	else
		if flags.items then
			Run("layout", Layout.Update, which, changed, Sorting(w))
		end
		if flags.search then
			Run("layout", Layout.Dim, which)
		end
		if flags.look then
			Run("layout", Layout.Render, which)
		end
	end
	Footer(w)
	Run("search", MatchCount, w)
	local keep = w.keepNext == true
	w.keepNext = nil
	Resize(w, keep or (not flags.layout and Call(Layout, "Builds", which) == builds))
	Window.Place(which)
end

function Window.Sorting(which)
	local w = windows[which]
	return w ~= nil and Sorting(w) == true
end

function Window.KeyName(binding)
	local ok, key = pcall(GetBindingKey, binding)
	if not ok or IsSecret(key) or type(key) ~= "string" or key == "" then
		return "Bind a key under Flat UI in Key Bindings."
	end
	local okWords, words = pcall(GetBindingText, key)
	words = okWords and not IsSecret(words) and type(words) == "string" and words ~= "" and words or key
	return "Key: " .. words
end

function Window.KeepHeight(which)
	local w = windows[which]
	local corner = CORNERS[which]
	if Shown(w) and type(corner) == "string" and corner:find("^BOTTOM") then
		w.keepNext = true
	end
end

function Window.Update(which, flags, changed)
	local w = windows[which]
	if not Shown(w) then
		return
	end
	if type(flags) == "string" then
		flags = { [flags] = true }
	elseif type(flags) ~= "table" then
		flags = { layout = true }
	end
	Run("window", Updating, w, flags, changed)
end

function Window.Paint()
	for which, w in pairs(windows) do
		PaintWindow(w)
		if Shown(w) then
			Run("layout", Layout.Render, which)
		end
	end
	Run("search", Call, Search, "Paint")
	Call(Buttons, "Paint")
end

local function Park(w)
	w.parked = true
	w.frame:SetClampedToScreen(false)
	w.frame:ClearAllPoints()
	w.frame:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -PARK, 0)
end

local function WarmDone(w, warmed, opening, new)
	if new then
		for button in pairs(new) do
			if not Layout.Placed(w.which, button) then
				Unsplit(w, button)
				button:Hide()
			end
		end
	end
	if warmed then
		Call(Buttons, "ShowAll", false)
		Window.Place(w.which)
		if opening then
			Showing(w)
		end
	elseif Shown(w) then
		Run("layout", Layout.Render, w.which)
	end
end

local function WarmEnd(w)
	w.warmQueued = false
	local warmed = w.warming == true
	local opening = false
	if warmed and w.wantShow == true and w.frame:IsShown() then
		local ok, on = pcall(On)
		opening = ok and on == true
	end
	if warmed and not opening then
		pcall(Unsplit, w)
		pcall(w.frame.Hide, w.frame)
	end
	w.warming, w.wantShow = false, false
	if w.parked then
		w.parked, w.placed = nil, nil
	end
	local new = w.warmButtons
	w.warmButtons = nil
	Run("window", WarmDone, w, warmed, opening, new)
end

local function Unplaced(w)
	local list = {}
	local key = Layout.Viewed("bags")
	local bags = Call(Data, "Containers", "bags", key)
	for _, bag in ipairs(type(bags) == "table" and bags or {}) do
		local slots = Call(Data, "Size", key, bag)
		for slot = 1, Finite(slots) and slots or 0 do
			local button = Call(Buttons, "Live", bag, slot)
			if type(button) == "table" and not Layout.Placed("bags", button) then
				list[#list + 1] = button
			end
		end
	end
	return list
end

local function WarmStart(w, buttons)
	if w.warming then
		Call(Buttons, "ShowAll", true)
		return
	end
	if not w.frame:IsShown() then
		w.warming, w.wantShow = true, false
		Park(w)
		Layout.Adopt("bags")
		w.frame:Show()
		Call(Buttons, "ShowAll", true)
	else
		w.warmButtons = w.warmButtons or {}
		Layout.Adopt("bags")
		for _, button in ipairs(type(buttons) == "table" and buttons or Unplaced(w)) do
			if type(button) == "table" and not Layout.Placed("bags", button) then
				Layout.Park(button)
				button:Show()
				w.warmButtons[button] = true
			end
		end
	end
end

local function Warming(w, buttons)
	local ok, err = pcall(WarmStart, w, buttons)
	if not w.warmQueued then
		w.warmQueued = true
		After(0, function()
			WarmEnd(w)
		end)
	end
	if not ok then
		error(err, 0)
	end
end

function Window.Warm(which, buttons)
	if which ~= "bags" or not On() then
		return
	end
	Window.Get("bags")
	Run("window", Warming, windows.bags, buttons)
end

local function BarEdges(name)
	local frame = _G[name]
	if ns.Forbidden(frame) then
		return nil
	end
	local okShown, shown = pcall(frame.IsVisible, frame)
	if not okShown or IsSecret(shown) or shown ~= true then
		return nil
	end
	local okLeft, left = pcall(frame.GetLeft, frame)
	local okRight, right = pcall(frame.GetRight, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (okLeft and okRight and okScale and okBase and Finite(left) and Finite(right) and Finite(scale) and Finite(base)) or base <= 0 then
		return nil
	end
	local k = scale / base
	return left * k, right * k
end

local function InPlace(name)
	local frame = _G[name]
	if ns.Forbidden(frame) then
		return false
	end
	local okInfo, info = pcall(rawget, frame, "systemInfo")
	if not okInfo or IsSecret(info) or type(info) ~= "table" then
		return true
	end
	local okFlag, flag = pcall(rawget, info, "isInDefaultPosition")
	return not (okFlag and not IsSecret(flag) and flag == false)
end

local function RightBarsRoom()
	local ok, screen = pcall(UIParent.GetRight, UIParent)
	if not ok or not Finite(screen) then
		return 0
	end
	local bars = {}
	for _, name in ipairs(RIGHT_BARS) do
		local left, right = BarEdges(name)
		if left and right > left and InPlace(name) then
			bars[#bars + 1] = { left = left, right = right }
		end
	end
	table.sort(bars, function(a, b)
		return a.right > b.right
	end)
	local edge = screen
	for _, bar in ipairs(bars) do
		if math.abs(bar.right - edge) <= BAR_SLACK then
			edge = math.min(edge, bar.left)
		end
	end
	return math.max(0, screen - edge)
end

function ns.BagsWindowStart(x, y)
	if not Finite(x) then
		return x, y
	end
	local room = RightBarsRoom()
	if room > 0 then
		x = math.min(x, -(room + BAR_ROOM))
	end
	return x, y
end

function ns.BagsWindowShown()
	return On()
end

function ns.BankWindowShown()
	return On()
end

function ns.BagsWindowMoved()
	local w = windows.bags
	if w then
		w.placed, w.dropped = nil, nil
		Run("window", Window.Place, "bags")
	end
end

function ns.BankWindowMoved()
	local w = windows.bank
	if w then
		w.placed, w.dropped = nil, nil
		Run("window", Window.Place, "bank")
	end
end

function Clicks.picker(w)
	local which = w.which
	local viewed = Layout.Viewed(which)
	local me = Call(B, "Me")
	local groups, order, myRealm = {}, {}, nil
	for _, c in ipairs(Characters()) do
		if type(c) == "table" and type(c.key) == "string" and not IsSecret(c.key) then
			local realm = RealmOf(c)
			if c.me == true or c.key == me then
				myRealm = realm
			end
			local group = groups[realm]
			if not group then
				group = { realm = realm, near = false, list = {} }
				groups[realm] = group
				order[#order + 1] = group
			end
			group.near = group.near or c.near == true or c.me == true
			group.list[#group.list + 1] = c
		end
	end
	table.sort(order, function(a, b)
		if (a.realm == myRealm) ~= (b.realm == myRealm) then
			return a.realm == myRealm
		end
		if a.near ~= b.near then
			return a.near
		end
		return a.realm < b.realm
	end)
	local items, jobs = {}, {}
	local searching = Call(Search, "Active") == true
	for _, group in ipairs(order) do
		table.sort(group.list, function(a, b)
			local am, bm = a.key == me, b.key == me
			if am ~= bm then
				return am
			end
			return NameOf(a.key, a) < NameOf(b.key, b)
		end)
		items[#items + 1] = { text = Plain(group.realm), header = true }
		for _, c in ipairs(group.list) do
			local level = Finite(c.level) and ("  " .. DIM_HEX .. math.floor(c.level) .. "|r") or ""
			local key = c.key
			local gold = (not searching and Finite(c.money) and c.money >= 0) and Money(c.money) or nil
			items[#items + 1] = { text = ClassHex(c.class) .. Plain(NameOf(key, c)) .. "|r" .. level, tick = key == viewed, part = "window",
				right = gold, pick = function()
					Call(B, "SetViewing", which, key ~= me and key or nil)
					Request("layout", which)
					TitleLine(w)
				end }
			jobs[#jobs + 1] = { index = #items, key = key }
		end
	end
	if #jobs == 0 then
		return
	end
	local title = "Characters"
	if searching then
		local text = Call(Search, "Text")
		text = type(text) == "string" and not IsSecret(text) and text or ""
		text = (text:gsub("||", "|"))
		if #text > 24 then
			local cut = 24
			while cut > 1 and text:byte(cut) >= 128 and text:byte(cut) < 192 do
				cut = cut - 1
			end
			text = text:sub(1, cut - 1) .. "..."
		end
		title = ("Items matching %s"):format(Plain(text))
	end
	local menu = Layout.Menu(w.picker, title, items, which)
	if not (menu and searching) then
		return
	end
	for _, job in ipairs(jobs) do
		Layout.MenuRight(job.index, "...")
	end
	local step = 1
	menu.tick = function()
		local job = jobs[step]
		if not job then
			menu.tick = nil
			return
		end
		step = step + 1
		local n = Matches(which, job.key, true)
		Layout.MenuRight(job.index, n > 0 and (WHITE_HEX .. n .. "|r") or "0")
	end
end

function Tips.picker(w, owner)
	if Layout.MenuOn(owner) then
		return
	end
	if w.which == "bank" then
		Say(owner, "Characters", "Choose a character to see their bank, as it was last seen.")
	else
		Say(owner, "Characters", "Choose a character to see their bags, as they were last seen.")
	end
end

function Clicks.view(w)
	local view = Opt("view") == "bags" and "sections" or "bags"
	local before = ns.Get("bags.view")
	ns.Set("bags.view", view)
	local home = ns.PanelHome
	local def = type(ns.Def) == "function" and ns.Def("bags.view") or nil
	if type(home) == "table" and type(home.Noted) == "function" and type(def) == "table" then
		pcall(home.Noted, def, before, ns.Get("bags.view"))
	end
	if type(ns.RefreshPanel) == "function" then
		pcall(ns.RefreshPanel)
	end
	Request("layout", nil)
	ArrangeBar(w)
end

function Tips.view(w, owner)
	if Opt("view") == "bags" then
		Say(owner, "Bag by bag", "Each bag in turn, as the game shows them.", "Click for Sections.")
	else
		Say(owner, "Sections", "Items grouped by kind.", "Click for Bag by bag.")
	end
end

function Clicks.sort(w)
	if Sorting(w) then
		return
	end
	local sort = ns.BagSort
	local run = type(sort) == "table" and sort.Run or nil
	if type(run) ~= "function" then
		return
	end
	if run(w.which) then
		local sound = sort.Sound
		if type(sound) == "function" then
			sound()
		end
		if not watching and w.which == "bags" then
			Sorted("bags")
		end
		if w.icons.sort then
			Tips.Again(w.icons.sort.button, Tips.sort, w, w.icons.sort.button)
		end
	end
end

function Tips.sort(w, owner)
	local title = w.which == "bank" and Word("BAG_CLEANUP_BANK", "Clean Up Bank") or Word("BAG_CLEANUP_BAGS", "Clean Up Bags")
	local key = w.which == "bags" and Window.KeyName("CLICK FlatUIBagSortButton:LeftButton") or nil
	if Sorting(w) then
		Say(owner, title, "Sorting: the window is laid out again once your items have stopped moving.", key)
	else
		Say(owner, title, key)
	end
end

function Clicks.bank(w)
	local key, mine = Layout.Viewed("bags")
	Call(Bank, "Toggle", (not mine) and key or nil)
end

function Tips.bank(w, owner)
	local key, mine = Layout.Viewed("bags")
	local game
	if Call(Bank, "Visiting") == true then
		game = Call(Bank, "Live") ~= true
	else
		game = Opt("bank") == "game"
	end
	local bind = Window.KeyName("CLICK FlatUIBankButton:LeftButton")
	if mine and game then
		Say(owner, Word("BANK", "Bank"), "Your bank as you last left it. At the banker the game's bank window is the live one.", bind)
	elseif mine then
		Say(owner, Word("BANK", "Bank"), "Your bank: live at the banker, and as you last left it anywhere else.", bind)
	else
		Say(owner, Word("BANK", "Bank"), ("The bank of %s, as it was last seen."):format(Plain(Named(key, CharacterOf(key)))), bind)
	end
end
