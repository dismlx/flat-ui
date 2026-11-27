local _, ns = ...

local KEY = "ownbuffs"
local MOVER = "FlatUIOwnBuffs"
local SPACING, GAP, CROP = 3, 4, 0.08
local ROOM_TEXT, ROOM_BAR, BAR_HEIGHT = 14, 5, 3
local WIDTH = 120
local MOST_CLASS, MOST_TIME = 8, 6
local REREAD, TEST_TIME = 0.2, 8
local PREVIEW = 4
local LOW, AMBER = 5, { 1, 0.7, 0.2 }
local BARS = { "HealthBarsContainer", "PowerBar", "AlternatePowerBar" }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLUE = { 0.302, 0.6, 0.902 }
local NOTE_NO_POSITION = "Your buffs: the personal resource display has no position, so the row is above the player frame."
local NOTE_REFUSED = "Your buffs: the game refused the %s, so icons show without it."
local NOTE_MOUSE = "Your buffs: the game refused a mouse setting of the icons, so clicks or tooltips may not work."
local NOTE_SIZE = "Your buffs: the game refused a new icon size, so icons already shown keep their old one until you log in again."
local NOTE_READING = "Your buffs: Buff tooltips has no effect while the game makes no icon row."
local LINE_OUT = "Your buffs: the game made no icon row, so icons show out of combat only."
local HELP = {
	"/flatui buffs check - the way the row is drawn, its groups and where it hangs",
	"/flatui test icons - three sample icons for Your buffs, for 8 seconds",
}

local IsSecret = ns.IsSecret
local T = ns.Tracking
local TM = ns.TestMode
local B = { list = {}, pending = {}, refused = {}, icons = {}, groups = {} }
B.FLASH_FROM, B.FLASH = 0.8, 0.5

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Spacing()
	local value = Opt("spacing")
	return ns.Finite(value) and value or SPACING
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Field(frame, key)
	local ok, value = pcall(function()
		return frame[key]
	end)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Whole(value)
	return Plain(value, "number") and value > 0 and value == math.floor(value)
end

function B.ClassMap()
	local class = B.class or T.Ask(UnitClassBase, "player")
	if Plain(class, "string") then
		B.class = class
	end
	local map, count, buffs = {}, 0, 0
	local list = type(ns.ClassShortBuffs) == "table" and Plain(class, "string") and ns.ClassShortBuffs[class] or nil
	for _, entry in ipairs(list or {}) do
		buffs = buffs + 1
		for _, id in ipairs(entry.ids) do
			if not map[id] then
				map[id] = true
				count = count + 1
			end
		end
	end
	B.listBuffs, B.listIDs = buffs, count
	return map
end

local function Merge(into, from)
	for id in pairs(from or {}) do
		into[id] = true
	end
	return into
end

function B.Left()
	local set = {}
	if Opt("trackers") == "leave" and ns.Enabled("trackers") and type(ns.TrackerSpellIDs) == "function" then
		Merge(set, ns.TrackerSpellIDs())
	end
	local defensives = ns.DefensivesModule
	if ns.Enabled("defensives") and ns.Get("defensives.own") == true and ns.Get("defensives.place") ~= "off" and defensives and defensives.OwnIDs then
		Merge(set, defensives.OwnIDs())
	end
	return set
end

function B.ClassFilters()
	return { includeSpellIDs = B.ClassMap(), excludeSpellIDs = B.Left(), maxDuration = Opt("limit") }
end

function B.TimeFilters()
	local exclude = B.Left()
	if Opt("which") == "both" then
		Merge(exclude, B.ClassMap())
	end
	return { excludeSpellIDs = exclude, isFromPlayerOrPlayerPet = true, maxDuration = Opt("limit") }
end

local function Signature(set)
	local ids = {}
	for id in pairs(set) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

function B.Room()
	local time = Opt("time")
	return time == "under" and ROOM_TEXT or (time == "bar" and ROOM_BAR or 0)
end

function B.Height()
	return Opt("size") + B.Room()
end

function B.Holder()
	if not B.holder then
		local holder = Own(CreateFrame("Frame", nil, UIParent))
		holder:SetSize(WIDTH, 1)
		B.holder = holder
	end
	return B.holder
end

function B.Bar(display, last)
	local from, to, step = 1, #BARS, 1
	if last then
		from, to, step = #BARS, 1, -1
	end
	for index = from, to, step do
		local bar = Field(display, BARS[index])
		if bar ~= nil and not ns.Forbidden(bar) then
			local ok, shown = pcall(bar.IsShown, bar)
			if ok and not IsSecret(shown) and shown == true then
				return bar
			end
		end
	end
	return display
end

local function Anchored(frame)
	local ok, left = pcall(frame.GetLeft, frame)
	return not ok or IsSecret(left) or left ~= nil
end

local function Hang(holder, frame, above, x, y)
	if above then
		holder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", x, GAP + y)
		holder:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", x, GAP + y)
	else
		holder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", x, y - GAP)
		holder:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", x, y - GAP)
	end
end

function B.Place()
	local holder = B.Holder()
	local place, x, y = Opt("place"), Opt("x"), Opt("y")
	holder:ClearAllPoints()
	holder:SetSize(WIDTH, B.Height())
	B.side = nil
	if place == "own" then
		local spotX, spotY = ns.MoverSpot(MOVER, "CENTER")
		if spotX then
			holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", spotX + x, spotY + y)
			B.where = "at the spot saved with the movers"
			ns.ClearNote(KEY, NOTE_NO_POSITION)
			return "own"
		end
	end
	local display = PersonalResourceDisplayFrame
	if display ~= nil and not ns.Forbidden(display) then
		local used = place
		if place == "swing" then
			local timer = SwingTimerMainHandFrame
			if timer ~= nil and not ns.Forbidden(timer) then
				Hang(holder, timer, false, x, y)
				B.side, B.where = "below", "under the swing timer"
			else
				Hang(holder, B.Bar(display, true), false, x, y)
				B.side, B.where = "below", "under the bars, there is no swing timer"
				used = "below"
			end
		elseif place == "below" then
			Hang(holder, B.Bar(display, true), false, x, y)
			B.side, B.where = "below", "under the bars"
		else
			Hang(holder, B.Bar(display), true, x, y)
			B.side, B.where = "above", "above the bars"
			used = "above"
		end
		if Anchored(holder) then
			ns.ClearNote(KEY, NOTE_NO_POSITION)
			return used
		end
		holder:ClearAllPoints()
		holder:SetSize(WIDTH, B.Height())
		B.side = nil
	end
	ns.Note(KEY, NOTE_NO_POSITION)
	B.where = "above the player frame, the personal resource display cannot be used"
	local frame = PlayerFrame
	if frame ~= nil and not ns.Forbidden(frame) then
		holder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", x, 70 + y)
		return "player"
	end
	holder:SetPoint("CENTER", UIParent, "CENTER", x, -150 + y)
	return "player"
end

function ns.OwnBuffsHolder(side)
	if B.holder and B.on and B.side == side then
		return B.holder
	end
	return nil
end

function ns.OwnBuffsOwnShown()
	return ns.Enabled(KEY) and Opt("place") == "own"
end

function ns.OwnBuffsMoved()
	if B.holder and ns.Enabled(KEY) then
		ns.OutOfCombat(B.Refresh)
	end
end

function B.Tell()
	local key = tostring(B.on and B.side) .. ":" .. tostring(B.on and B.Height())
	if key == B.told then
		return
	end
	B.told = key
	if type(ns.TrackerPlaceAgain) == "function" then
		pcall(ns.TrackerPlaceAgain)
	end
	if type(ns.CooldownsMoved) == "function" then
		pcall(ns.CooldownsMoved)
	end
	if type(ns.DefensivesMoved) == "function" then
		pcall(ns.DefensivesMoved)
	end
end

local function EdgeColour()
	if ns.Borderless() or not Opt("iconBorder") then
		return 0, 0, 0, 0
	end
	local r, g, b = ns.Colour("general.border")
	return r, g, b, 1
end

local function Thick()
	return ns.Pixels(B.Holder(), ns.Get("general.thickness"))
end

local function EdgeKey()
	local r, g, b, a = EdgeColour()
	return ("%s,%s,%s,%s,%s"):format(Thick(), r, g, b, a)
end

function B.PaintEdges(parts)
	local button, edges = parts.button, parts.edges
	local thick = Thick()
	local r, g, b, a = EdgeColour()
	edges[1]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	edges[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
	edges[1]:SetHeight(thick)
	edges[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	edges[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	edges[2]:SetHeight(thick)
	edges[3]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -thick)
	edges[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, thick)
	edges[3]:SetWidth(thick)
	edges[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, -thick)
	edges[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, thick)
	edges[4]:SetWidth(thick)
	for _, edge in ipairs(edges) do
		edge:SetColorTexture(r, g, b, a)
	end
	parts.borderKey = EdgeKey()
end

local function BarOptions()
	local direction = type(Enum) == "table" and type(Enum.StatusBarTimerDirection) == "table" and Enum.StatusBarTimerDirection.RemainingTime
	local interpolation = type(Enum) == "table" and type(Enum.StatusBarInterpolation) == "table" and Enum.StatusBarInterpolation.Immediate
	return { interpolation = interpolation or 0, direction = direction or 1 }
end

function B.TimeOptions()
	if B.timeOptions == nil then
		local ok, options = pcall(function()
			local curve = C_CurveUtil.CreateColorCurve()
			curve:SetType(Enum.LuaCurveType.Step)
			curve:AddPoint(0, CreateColor(AMBER[1], AMBER[2], AMBER[3], 1))
			curve:AddPoint(LOW, CreateColor(1, 1, 1, 1))
			return { textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration } }
		end)
		B.timeOptions = ok and type(options) == "table" and options or false
	end
	return B.timeOptions or nil
end

function B.Bind(parts, want)
	if parts.bound == want then
		return
	end
	local button = parts.button
	local was = parts.bound
	if was == "under" or was == "on" then
		pcall(button.ClearDurationText, button)
		parts.under:SetText("")
		parts.under:Hide()
		parts.on:SetText("")
		parts.on:Hide()
	elseif was == "bar" then
		pcall(button.ClearDurationBar, button)
		parts.bar:Hide()
	end
	parts.bound = nil
	if want == "under" or want == "on" then
		local font, options = parts[want], B.TimeOptions()
		font:Show()
		if not (options and pcall(button.SetDurationText, button, font, options)) then
			button:SetDurationText(font, nil)
		end
	elseif want == "bar" then
		parts.bar:Show()
		button:SetDurationBar(parts.bar, BarOptions())
	end
	parts.bound = want
end

local function Mouse(parts)
	local button, tips = parts.button, Opt("tooltips")
	local ok = pcall(button.SetMouseClickEnabled, button, false)
	ok = pcall(button.SetMouseMotionEnabled, button, tips ~= "off") and ok
	ok = pcall(button.SetHideTooltipInCombat, button, tips ~= "on") and ok
	parts.tips = ok and tips or nil
	if not ok then
		B.refused.tips = true
	else
		B.refused.tips = nil
		for _, other in ipairs(B.list) do
			if other.tips == nil then
				B.refused.tips = true
			end
		end
	end
end

B.BASE = 40
function B.SizeText(parts, size)
	local time = ns.IconNumberHeight(ns.IconFontHeight("NumberFontNormal", 14), size, B.BASE)
	local count = ns.IconNumberHeight(ns.IconFontHeight("NumberFontNormalSmall", 12), size, B.BASE)
	local ok = true
	if parts.on then
		ok = pcall(parts.on.SetTextHeight, parts.on, time) and ok
	end
	if parts.count then
		ok = pcall(parts.count.SetTextHeight, parts.count, count) and ok
	end
	if ok then
		parts.textSize = size
	end
	return ok
end

function B.Init(button)
	local parts = { button = button }
	B.list[#B.list + 1] = parts
	Mouse(parts)
	parts.size = pcall(button.SetSize, button, Opt("size"), Opt("size")) and Opt("size") or nil
	local function Part(name, fn)
		if not pcall(fn) then
			B.refused[name] = true
		end
	end
	Part("icon", function()
		local icon = Own(button:CreateTexture(nil, "ARTWORK", nil, 0))
		icon:SetAllPoints()
		icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		button:SetIcon(icon)
		parts.icon = icon
	end)
	Part("sweep", function()
		local sweep = Own(CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate"))
		sweep:SetAllPoints()
		sweep:SetDrawEdge(false)
		sweep:SetDrawBling(false)
		sweep:SetSwipeColor(0, 0, 0, 0.7)
		sweep:SetHideCountdownNumbers(true)
		parts.sweep = sweep
		button:SetDurationCooldown(sweep)
	end)
	local made, top = pcall(function()
		local frame = Own(CreateFrame("Frame", nil, button))
		frame:SetAllPoints()
		frame:SetFrameLevel(button:GetFrameLevel() + 3)
		return frame
	end)
	if not made then
		B.refused.count, B.refused.time, B.refused.border, B.refused.flash = true, true, true, true
		return
	end
	parts.top = top
	Part("count", function()
		local count = Own(top:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"))
		count:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", -2, 2)
		button:SetApplicationCount(count, nil)
		parts.count = count
	end)
	Part("time", function()
		local under = Own(top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
		under:SetPoint("TOP", button, "BOTTOM", 0, -1)
		under:Hide()
		local on = Own(top:CreateFontString(nil, "OVERLAY", "NumberFontNormal"))
		on:SetPoint("CENTER", top, "CENTER", 0, 0)
		on:Hide()
		local bar = Own(CreateFrame("StatusBar", nil, button))
		bar:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -1)
		bar:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -1)
		bar:SetHeight(BAR_HEIGHT)
		parts.file = ns.BarTexture(Opt("barTexture")) or WHITE
		bar:SetStatusBarTexture(parts.file)
		bar:SetStatusBarColor(BLUE[1], BLUE[2], BLUE[3], 1)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar:Hide()
		parts.under, parts.on, parts.bar = under, on, bar
		B.Bind(parts, Opt("time"))
	end)
	Part("border", function()
		local edges = {}
		for index = 1, 4 do
			local edge = Own(top:CreateTexture(nil, "OVERLAY", nil, 7))
			if edge.SetSnapToPixelGrid then
				pcall(edge.SetSnapToPixelGrid, edge, false)
			end
			edges[index] = edge
		end
		parts.edges = edges
		B.PaintEdges(parts)
	end)
	Part("flash", function()
		local flash = Own(top:CreateTexture(nil, "OVERLAY", nil, 7))
		flash:SetAllPoints(button)
		flash:SetColorTexture(1, 1, 1, 1)
		flash:SetAlpha(0)
		local group = flash:CreateAnimationGroup()
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(B.FLASH_FROM)
		fade:SetToAlpha(0)
		fade:SetDuration(B.FLASH)
		group:SetToFinalAlpha(true)
		button:AddAuraShownAnimation(group)
		parts.flash = flash
		parts.flashOn = Opt("flash") ~= false
		flash:SetShown(parts.flashOn)
	end)
	pcall(B.SizeText, parts, Opt("size"))
end

function B.ApplyTime()
	local want = Opt("time")
	local file = ns.BarTexture(Opt("barTexture")) or WHITE
	for _, parts in ipairs(B.list) do
		if parts.bar and parts.file ~= file then
			parts.file = file
			pcall(parts.bar.SetStatusBarTexture, parts.bar, file)
		end
		if parts.bar and parts.bound ~= want then
			if not pcall(B.Bind, parts, want) then
				B.refused.time = true
			end
		end
	end
end

function B.ApplyBorder()
	for _, parts in ipairs(B.list) do
		if parts.edges and parts.borderKey ~= EdgeKey() then
			if not pcall(B.PaintEdges, parts) then
				B.refused.border = true
			end
		end
	end
end

function B.ApplyTips()
	for _, parts in ipairs(B.list) do
		if parts.tips ~= Opt("tooltips") then
			Mouse(parts)
		end
	end
end

function B.ApplySize()
	local size, refused = Opt("size"), nil
	for _, parts in ipairs(B.list) do
		if parts.size ~= size then
			if pcall(parts.button.SetSize, parts.button, size, size) then
				parts.size = size
			else
				refused = true
			end
		end
		if parts.textSize ~= size then
			B.SizeText(parts, size)
		end
	end
	B.refused.size = refused
end

function B.ApplyFlash()
	local want = Opt("flash") ~= false
	for _, parts in ipairs(B.list) do
		if parts.flash and parts.flashOn ~= want then
			if pcall(parts.flash.SetShown, parts.flash, want) then
				parts.flashOn = want
			else
				B.refused.flash = true
			end
		end
	end
end

B.apply = { time = B.ApplyTime, border = B.ApplyBorder, tips = B.ApplyTips, size = B.ApplySize, flash = B.ApplyFlash }

function B.Flush()
	if next(B.pending) == nil or not T.Open() then
		return
	end
	local todo = B.pending
	B.pending = {}
	for kind in pairs(todo) do
		pcall(B.apply[kind])
	end
end

function B.Change(kind)
	if T.Open() then
		pcall(B.apply[kind])
		return
	end
	B.pending[kind] = true
end

function B.OnRestriction()
	if next(B.pending) ~= nil then
		B.Flush()
		if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			C_Timer.After(0, B.Flush)
		end
	end
end

local function Layout()
	local size = Opt("size")
	return { elementSpacing = Spacing(), elementWidth = size, elementHeight = size }
end

local function SortMethod()
	if type(AuraContainerSortMethod) == "table" then
		return AuraContainerSortMethod.Expiration
	end
	return nil
end

function B.InitCall(button)
	local ok, err = pcall(B.Init, button)
	if not ok then
		B.refused.icon = true
		B.failure = tostring(err)
	end
end

function B.Build()
	B.tried = true
	local holder = B.Holder()
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
	if not ok or type(container) ~= "table" then
		B.path = "reading"
		return
	end
	Own(container)
	local made, err = pcall(function()
		container:SetEditModePreviewEnabled(false)
		container:SetUnit("player")
		container:SetPoint("TOP", holder, "TOP", 0, 0)
		container:AddAuraGroup("class", "HELPFUL|PLAYER", { candidateFilters = B.ClassFilters(), maxFrameCount = MOST_CLASS, layout = Layout(),
			sortMethod = SortMethod(), initializeFrame = B.InitCall })
		container:AddAuraGroup("time", "HELPFUL|PLAYER", { candidateFilters = B.TimeFilters(), maxFrameCount = MOST_TIME, layout = Layout(),
			sortMethod = SortMethod(), initializeFrame = B.InitCall })
	end)
	B.container = container
	if made then
		B.path = "container"
		return
	end
	B.failure = tostring(err)
	B.Groups(false)
	B.path = "reading"
end

function B.Groups(on)
	local container = B.container
	if not container then
		return
	end
	local which = Opt("which")
	pcall(container.SetAuraGroupEnabled, container, "class", on and (which == "class" or which == "both"))
	pcall(container.SetAuraGroupEnabled, container, "time", on and (which == "every" or which == "both"))
end

function B.Lists()
	local container = B.container
	if not container then
		return
	end
	local class, time = B.ClassFilters(), B.TimeFilters()
	local key = Signature(class.includeSpellIDs) .. "|" .. Signature(class.excludeSpellIDs) .. "|" .. Signature(time.excludeSpellIDs) .. "|"
		.. tostring(class.maxDuration)
	if key == B.listKey then
		return
	end
	B.listKey = key
	pcall(container.SetAuraGroupCandidateFilters, container, "class", class)
	pcall(container.SetAuraGroupCandidateFilters, container, "time", time)
end

function B.Sizes()
	local container = B.container
	if not container then
		return
	end
	local size = Opt("size") .. ":" .. Spacing()
	if size == B.sized then
		return
	end
	B.sized = size
	pcall(container.SetAuraGroupLayout, container, "class", Layout())
	pcall(container.SetAuraGroupLayout, container, "time", Layout())
end

function ns.OwnBuffsTrackers()
	if B.container and B.on then
		B.Lists()
	end
end

function B.Read()
	if not T.Open() then
		return nil
	end
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.GetUnitAuras or nil
	if type(call) ~= "function" then
		return nil
	end
	local ok, auras = pcall(call, "player", "HELPFUL|PLAYER")
	if not ok or IsSecret(auras) or type(auras) ~= "table" then
		return nil
	end
	local which, limit = Opt("which"), Opt("limit")
	local class, left, found = B.ClassMap(), B.Left(), {}
	for _, aura in ipairs(auras) do
		if type(aura) == "table" and not IsSecret(aura) then
			local read, id, expires, length, file = pcall(function()
				return aura.spellId, aura.expirationTime, aura.duration, aura.icon
			end)
			if read and Plain(id, "number") and ns.Finite(expires) and ns.Finite(length) and length > 0 and length <= limit and not left[id] then
				if which ~= "class" or class[id] == true then
					found[#found + 1] = { id = id, expires = expires, length = length, file = (Plain(file, "number") or Plain(file, "string")) and file or nil }
				end
			end
		end
	end
	table.sort(found, function(a, b)
		if a.expires ~= b.expires then
			return a.expires < b.expires
		end
		return a.id < b.id
	end)
	return found
end

function B.Icon(index)
	local icon = B.icons[index]
	if not icon then
		icon = ns.IconNew(B.Holder())
		if not icon then
			return nil
		end
		B.icons[index] = icon
	end
	return icon
end

function B.Row(list)
	local size, spacing = Opt("size"), Spacing()
	local count = #list
	local width = count > 0 and (count * size + (count - 1) * spacing) or 0
	for index, icon in ipairs(list) do
		icon.frame:SetSize(size, size)
		icon.frame:ClearAllPoints()
		icon.frame:SetPoint("TOPLEFT", B.Holder(), "TOP", (index - 1) * (size + spacing) - width / 2, 0)
	end
end

function B.Pass()
	B.scheduled = false
	if B.path ~= "reading" or not ns.Enabled(KEY) or B.testing or B.Holding() then
		return
	end
	local read = B.Read()
	local found = read or {}
	local shown = {}
	local before, now = B.landed, {}
	B.landed = read and now or nil
	for index = 1, #found do
		local item, icon = found[index], B.Icon(index)
		if icon then
			ns.IconSet(icon, item.file, item.expires - item.length, item.length, { numbers = Opt("time") ~= "off", border = Opt("iconBorder") })
			ns.IconCountdownHeight(icon, Opt("size"), B.BASE)
			now[item.id] = true
			if before and not before[item.id] and Opt("flash") ~= false then
				ns.IconFlash(icon)
			end
			shown[#shown + 1] = icon
		end
	end
	if #found > 0 then
		B.seen = "readable"
	end
	for index = #shown + 1, #B.icons do
		ns.IconClear(B.icons[index])
	end
	B.Row(shown)
end

function B.Queue()
	if B.scheduled then
		return
	end
	B.scheduled = true
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(REREAD, B.Pass)
	else
		B.Pass()
	end
end

function B.StartReading()
	if not B.watcher then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			return
		end
		B.watcher = Own(frame)
		frame:SetScript("OnEvent", function(_, _, unit)
			if B.path == "reading" and (B.playerOnly or (Plain(unit, "string") and unit == "player")) then
				B.Queue()
			end
		end)
	end
	local frame = B.watcher
	B.playerOnly = frame.RegisterUnitEvent ~= nil and pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "player")
	if not B.playerOnly then
		pcall(frame.RegisterEvent, frame, "UNIT_AURA")
	end
	B.Queue()
end

function B.StopReading()
	if B.watcher then
		pcall(B.watcher.UnregisterAllEvents, B.watcher)
	end
	B.landed = nil
	for _, icon in ipairs(B.icons) do
		ns.IconClear(icon)
	end
end

function B.Capable()
	return type(C_UnitAuras) == "table" and type(C_UnitAuras.GetUnitAuras) == "function"
end

function B.Sync()
	B.on = B.Capable() and ns.Enabled(KEY)
	if not B.on then
		B.Held()
		if B.holder and not B.testing then
			B.holder:Hide()
		end
		B.Groups(false)
		B.StopReading()
		B.Tell()
		return
	end
	local holder = B.Holder()
	holder:Show()
	B.Place()
	if not B.tried then
		B.Build()
	end
	if B.path == "container" then
		B.Groups(true)
		B.Lists()
		B.Sizes()
		B.Change("size")
		B.Change("time")
		B.Change("border")
		B.Change("tips")
		B.Change("flash")
	elseif B.path == "reading" then
		B.StartReading()
	end
	B.Held()
	B.Tell()
end

function B.Refresh()
	if B.Capable() then
		ns.OutOfCombat(B.Sync)
	end
end

function B.Start()
	if not B.Capable() then
		return
	end
	B.Sync()
end

function B.PathText()
	if not B.Capable() then
		return "Your buffs: the game gives no buff information."
	elseif not ns.Enabled(KEY) then
		return "Your buffs: off."
	elseif B.path == "container" then
		return "Your buffs: the game's own icon row."
	elseif B.path == "reading" then
		return "Your buffs: out of combat only, the game made no icon row."
	end
	return "Your buffs: not started."
end

local WHICH = { class = "short buffs of your class", every = "every buff you cast", both = "both" }

function B.Check()
	local lines = { B.PathText() }
	if B.Capable() and ns.Enabled(KEY) then
		local container = B.container
		local groups = {}
		for _, name in ipairs({ "class", "time" }) do
			local ok, on = false, nil
			if container then
				ok, on = pcall(container.IsAuraGroupEnabled, container, name)
			end
			if ok and on == true then
				groups[#groups + 1] = name
			end
		end
		B.ClassMap()
		lines[#lines + 1] = ("Buffs shown: %s. Groups on: %s."):format(WHICH[Opt("which")] or tostring(Opt("which")), #groups > 0 and table.concat(groups, ", ") or "none")
		lines[#lines + 1] = ("Class list: %d buffs, %d spell IDs."):format(B.listBuffs or 0, B.listIDs or 0)
		lines[#lines + 1] = ("Time limit: %d s. Hangs %s."):format(Opt("limit"), B.where or "nowhere yet")
	end
	return lines
end

function B.Slash(rest)
	local word = (rest or ""):match("^(%S*)"):lower()
	if word == "check" then
		for _, line in ipairs(B.Check()) do
			print(line)
		end
		return
	end
	for _, line in ipairs(HELP) do
		print(line)
	end
end

local function Now()
	return type(GetTime) == "function" and GetTime() or 0
end

function B.SampleTime(icon, start, seconds)
	local parts = icon.time
	if parts == nil then
		local ok, made = pcall(function()
			local clock = Own(CreateFrame("Frame", nil, icon.frame))
			clock:SetAllPoints(icon.frame)
			clock:SetFrameLevel(icon.frame:GetFrameLevel() + 3)
			local text = Own(clock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
			text:SetPoint("TOP", icon.frame, "BOTTOM", 0, -1)
			local bar = Own(CreateFrame("StatusBar", nil, clock))
			bar:SetPoint("TOPLEFT", icon.frame, "BOTTOMLEFT", 0, -1)
			bar:SetPoint("TOPRIGHT", icon.frame, "BOTTOMRIGHT", 0, -1)
			bar:SetHeight(BAR_HEIGHT)
			bar:SetMinMaxValues(0, 1)
			clock:Hide()
			return { clock = clock, text = text, bar = bar }
		end)
		parts = ok and made or false
		icon.time = parts
		if parts then
			parts.clock:SetScript("OnUpdate", function()
				local held = icon.held
				local length = held and held.seconds or parts.seconds
				local left = math.max(0, (held and held.ends or (parts.start + parts.seconds)) - Now())
				local low = left > 0 and left <= LOW
				if parts.want == "under" then
					parts.text:SetText(left > 0 and ("%d"):format(math.ceil(left)) or "")
					if parts.low ~= low then
						parts.low = low
						parts.text:SetTextColor(low and AMBER[1] or 1, low and AMBER[2] or 1, low and AMBER[3] or 1)
					end
				elseif parts.want == "on" then
					B.SampleTint(icon, low)
				else
					parts.bar:SetMinMaxValues(0, length > 0 and length or 1)
					parts.bar:SetValue(left)
				end
			end)
		end
	end
	if not parts then
		return
	end
	local want = Opt("time")
	parts.want, parts.start, parts.seconds = want, start or Now(), seconds or 0
	parts.text:SetShown(want == "under")
	parts.bar:SetShown(want == "bar")
	if want == "bar" then
		pcall(parts.bar.SetStatusBarTexture, parts.bar, ns.BarTexture(Opt("barTexture")) or WHITE)
		pcall(parts.bar.SetStatusBarColor, parts.bar, BLUE[1], BLUE[2], BLUE[3], 1)
	end
	parts.clock:SetShown(want == "under" or want == "bar" or want == "on")
end

function B.SampleTint(icon, low)
	if icon.tint == low then
		return
	end
	local ok, text = pcall(icon.cooldown.GetCountdownFontString, icon.cooldown)
	if ok and not IsSecret(text) and type(text) == "table" then
		text:SetTextColor(low and AMBER[1] or 1, low and AMBER[2] or 1, low and AMBER[3] or 1)
		icon.tint = low
	end
end

function B.SampleTimeOff(icon)
	if icon.time then
		icon.time.clock:Hide()
	end
end

function B.EndTest(token)
	local test = B.testing
	if not test or (token and test ~= token) then
		return
	end
	B.testing = nil
	for _, icon in ipairs(test.list) do
		ns.IconClear(icon)
		B.SampleTimeOff(icon)
	end
	if B.holder and not (B.on and ns.Enabled(KEY)) then
		B.holder:Hide()
	end
	B.Pass()
end

function ns.OwnBuffsTest(quiet, path)
	quiet = quiet == true
	if not B.Capable() then
		return
	end
	if not (B.on and ns.Enabled(KEY)) then
		if not quiet then
			print("Your buffs: the row is off.")
		end
		return
	end
	if InCombatLockdown() then
		if not quiet then
			print("Your buffs: the test shows out of combat only.")
		end
		return
	end
	local again = quiet and B.testing and B.testing.quiet and B.testing or nil
	if B.testing then
		B.EndTest()
	end
	for _, icon in ipairs(B.icons) do
		ns.IconClear(icon)
	end
	local holder = B.Holder()
	B.Place()
	holder:Show()
	local list, now = {}, Now()
	if again and again.start and now - again.start < 8 then
		now = again.start
	end
	local flash = Opt("flash") ~= false and (not again or path == KEY .. ".flash")
	B.sample = B.sample or {}
	for index = 1, 3 do
		local icon = B.sample[index] or ns.IconNew(holder)
		if not icon then
			return
		end
		B.sample[index] = icon
		list[index] = icon
		ns.IconSet(icon, ({ 135940, 135964, 136089 })[index], now, 2 * index + 2, { numbers = Opt("time") == "on", border = Opt("iconBorder") })
		ns.IconCountdownHeight(icon, Opt("size"), B.BASE)
		B.SampleTime(icon, now, 2 * index + 2)
		if flash then
			ns.IconFlash(icon)
		end
	end
	B.Row(list)
	local test = { list = list, quiet = quiet, start = now }
	B.testing = test
	if not quiet then
		print("Your buffs: three sample icons for 8 seconds.")
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(quiet and PREVIEW or TEST_TIME, function()
			B.EndTest(test)
		end)
	end
end

function ns.OwnBuffsLookChanged(path)
	ns.Try(KEY, B.Refresh)
	if InCombatLockdown() or TM.IsOn() or not (B.Capable() and B.on and ns.Enabled(KEY)) then
		return
	end
	local read, found = pcall(B.Read)
	if (B.testing and not B.testing.quiet) or not read or (type(found) == "table" and #found > 0) then
		return
	end
	ns.Try(KEY, ns.OwnBuffsTest, true, path)
end

function B.Holding()
	return TM.IsOn() and B.on == true and not InCombatLockdown()
end

function B.Held()
	local list = B.held or {}
	B.held = list
	if not B.Holding() then
		local had = B.Drop()
		if had and B.on and B.path == "reading" then
			B.Queue()
		end
		return
	end
	local holder = B.Holder()
	for index = 1, 3 do
		list[index] = list[index] or ns.IconNew(holder)
		if not list[index] then
			return
		end
	end
	for _, icon in ipairs(B.icons) do
		ns.IconClear(icon)
	end
	local look = { numbers = Opt("time") == "on", border = Opt("iconBorder"), flash = false, sound = false }
	local flash = Opt("flash") ~= false
	for index, icon in ipairs(list) do
		local fresh = not (icon.held and icon.frame:IsShown())
		ns.IconSampleHeld(icon, index, KEY, look)
		ns.IconCountdownHeight(icon, Opt("size"), B.BASE)
		B.SampleTime(icon)
		if fresh and icon.held and flash then
			ns.IconFlash(icon)
		end
	end
	B.Row(list)
end

function B.Drop()
	local had = false
	for _, icon in ipairs(B.held or {}) do
		had = ns.IconSampleDrop(icon) or had
		B.SampleTimeOff(icon)
	end
	return had
end

function B.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if B.path == "reading" then
		lines[#lines + 1] = LINE_OUT
	end
	local names = { icon = "icon", sweep = "sweep", count = "count", time = "time left", border = "border", flash = "flash" }
	for _, name in ipairs({ "icon", "sweep", "count", "time", "border", "flash" }) do
		if B.refused[name] then
			lines[#lines + 1] = NOTE_REFUSED:format(names[name])
		end
	end
	if B.refused.tips then
		lines[#lines + 1] = NOTE_MOUSE
	end
	if B.refused.size then
		lines[#lines + 1] = NOTE_SIZE
	end
	if B.path == "reading" then
		lines[#lines + 1] = NOTE_READING
	end
	return lines
end

ns.Register(KEY, {
	label = "Your buffs",
	counted = false,
	Start = B.Start,
	Refresh = B.Refresh,
	Resized = B.Refresh,
	events = {
		PLAYER_ENTERING_WORLD = function()
			B.Refresh()
		end,
		ADDON_RESTRICTION_STATE_CHANGED = function()
			B.OnRestriction()
			if B.path == "reading" then
				B.Queue()
			end
		end,
		PLAYER_REGEN_DISABLED = function()
			if B.path == "reading" then
				B.Queue()
			end
		end,
		EDIT_MODE_LAYOUTS_UPDATED = function()
			B.Refresh()
		end,
	},
	slash = { buffs = B.Slash },
	help = HELP,
	Status = B.Status,
})

TM.Register(KEY, {
	module = KEY,
	label = "Your buffs",
	refresh = true,
	Stop = B.Drop,
	Tick = function(now)
		ns.IconSampleLoop(B.held, now)
	end,
})

ns.OwnBuffsModule = B
