local _, ns = ...

local KEY = "combattext"

local SHAPE = { length = 240, arc = 0.2, arcs = { narrow = 0.2, wide = 0.35 }, reach = 0.6, life = { fast = 1.6, normal = 2.2, slow = 3.0 }, still = 1.5, hold = 0.75, stillHold = 0.7,
	fadeIn = 0.03, line = 1.04, rows = 5, clear = 2.5, lane = 1.5, lanes = { 0, 1, -1, 2 }, wait = 0.3, most = 1.2 }
local PATH = { straight = true, arc = true }
local POP = { peak = 1.15, up = 0.05, down = 0.10 }
local CRIT, WORD, GAP = 1.25, 0.75, 4
local SMALLER = 0.75
SHAPE.crit = CRIT
ns.CombatShape.scroll = SHAPE
local TEXT_HEIGHT = 25
local PARTIAL = { GLANCING = { 0.7, 0.7, 0.7 }, CRUSHING = { 1, 0.4, 0.2 }, RESIST = { 0.79, 0.3, 0.85 }, BLOCK = { 0.6, 0.7, 1 },
	BLOCK_REDUCED = { 0.6, 0.7, 1 }, ABSORB = { 1, 0.85, 0.4 } }
local EXTRA_TEXT = "|cffff9926(Extra attack)|r"
local INLINE = "|T%d:0:0:0:0:64:64:5:59:5:59|t "
local AREAS = {
	out = { label = "Outgoing", mover = "FlatUICombatOut", style = "outStyle", size = "size", sizeRow = "outSize", dir = 1, dirRow = "outDir", side = 1,
		max = 32, dx = 170, dy = -30 },
	inc = { label = "Incoming", mover = "FlatUICombatSelf", style = "inStyle", size = "ownSize", sizeRow = "inSize", dirRow = "inDir", dir = -1, side = -1, max = 32,
		dx = -170, dy = -30 },
}
local ORDER = { AREAS.out, AREAS.inc }
for key, area in pairs(AREAS) do
	area.key, area.items, area.live, area.rows, area.lanes, area.shown, area.failed, area.waited, area.cut = key, {}, {}, {}, {}, 0, 0, 0, 0
end

local host, ticker
local serial = 0
local active, unplaced = 0, 0

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

function ns.ScrollPath(style, u, length, dir, side, width)
	if style == "straight" then
		return 0, dir * length * u
	elseif style == "arc" then
		return side * (width or SHAPE.arc) * length * math.sin(math.pi * u), dir * length * u
	elseif style == "horizontal" then
		return side * SHAPE.reach * length * u, 0
	end
	return 0, 0
end

function ns.ScrollAlpha(u, hold)
	if u < SHAPE.fadeIn then
		return u / SHAPE.fadeIn
	elseif u <= hold then
		return 1
	end
	return math.max(0, 1 - (u - hold) / (1 - hold))
end

local function Host()
	if not host then
		host = CreateFrame("Frame", nil, UIParent)
		ns.Own[host] = true
		host:SetAllPoints(UIParent)
		host:SetFrameStrata("MEDIUM")
		ticker = CreateFrame("Frame")
	end
end

local function MakePop(item)
	local ok, group = pcall(function()
		local text = item.text
		text:SetScaleAnimationMode(Enum and Enum.FontStringScaleAnimationMode and Enum.FontStringScaleAnimationMode.Vertex or 1)
		local made = text:CreateAnimationGroup()
		local steps = { { 1, POP.peak, POP.up }, { POP.peak, 1, POP.down } }
		for order, step in ipairs(steps) do
			local scale = made:CreateAnimation("Scale")
			scale:SetOrder(order)
			scale:SetScaleFrom(step[1], step[1])
			scale:SetScaleTo(step[2], step[2])
			scale:SetDuration(step[3])
			scale:SetOrigin("CENTER", 0, 0)
		end
		return made
	end)
	item.group = ok and group or nil
end

local function Make(area)
	Host()
	local look = ns.CombatLook()
	local text = host:CreateFontString(nil, "OVERLAY", look.last)
	local word = host:CreateFontString(nil, "OVERLAY", look.last)
	ns.Own[text], ns.Own[word] = true, true
	text:Hide()
	word:Hide()
	pcall(text.SetJustifyH, text, "CENTER")
	pcall(text.SetJustifyV, text, "MIDDLE")
	pcall(word.SetJustifyH, word, "LEFT")
	word:SetPoint("LEFT", text, "RIGHT", GAP, 0)
	local icon = host:CreateTexture(nil, "OVERLAY", nil, 0)
	ns.Own[icon] = true
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("RIGHT", text, "LEFT", -GAP, 0)
	icon:Hide()
	local item = { text = text, word = word, icon = icon, shift = 0, rx = 0, ry = 0, start = 0, serial = 0, area = area, on = false, cue = false }
	MakePop(item)
	return item
end

local function Style(item, look)
	local object = look.object or look.name
	pcall(item.text.SetFontObject, item.text, object)
	pcall(item.word.SetFontObject, item.word, object)
	pcall(item.text.SetJustifyH, item.text, "CENTER")
	pcall(item.text.SetJustifyV, item.text, "MIDDLE")
	pcall(item.word.SetJustifyH, item.word, "LEFT")
	item.look = look.key
end

local function Release(area, index)
	local item = table.remove(area.live, index)
	item.on, item.cue = false, false
	if item.row ~= nil and area.rows[item.row] == item then
		area.rows[item.row] = nil
	end
	if item.lane ~= nil and area.lanes[item.lane] == item then
		area.lanes[item.lane] = nil
	end
	item.row, item.lane = nil, nil
	item.text:Hide()
	item.word:Hide()
	item.icon:Hide()
	if item.group then
		pcall(item.group.Stop, item.group)
	end
	active = active - 1
	if active == 0 then
		ticker:SetScript("OnUpdate", nil)
	end
end

local function Take(area)
	for _, item in ipairs(area.items) do
		if not item.on then
			return item
		end
	end
	if #area.items < area.max then
		local item = Make(area)
		area.items[#area.items + 1] = item
		return item
	end
	local oldest = area.live[1]
	if not oldest.sample then
		area.cut = area.cut + 1
	end
	Release(area, 1)
	return oldest
end

local function Place(item, now)
	local t = now - item.start
	local waiting = t < 0
	local u = waiting and 0 or t / item.life
	local dx, dy = ns.ScrollPath(item.style, u, item.length, item.dir, item.side, item.arc)
	local text = item.text
	text:ClearAllPoints()
	text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", item.x0 + dx + item.shift + item.rx, item.y0 + dy + item.ry)
	local alpha = waiting and 0 or ns.ScrollAlpha(u, item.hold)
	text:SetAlpha(alpha)
	if item.hasIcon then
		item.icon:SetAlpha(alpha)
	end
	if item.hasWord then
		if t >= POP.up + POP.down then
			item.word:Show()
		end
		item.word:SetAlpha(alpha)
	end
end

local function Begin(item)
	item.cue = false
	if item.group and Opt("pop") == "pop" then
		pcall(item.group.Play, item.group)
	end
end

local function Step()
	local now = GetTime()
	for _, area in ipairs(ORDER) do
		for index = #area.live, 1, -1 do
			local item = area.live[index]
			if now - item.start >= item.life or not pcall(Place, item, now) then
				Release(area, index)
			elseif item.cue and now >= item.start then
				Begin(item)
			end
		end
	end
end

local function Tick()
	ns.Try(KEY, Step)
end

local function Spot(area)
	if type(ns.MoverSpot) == "function" then
		local x, y = ns.MoverSpot(area.mover, "CENTER")
		if x then
			return x, y
		end
	end
	local ok, width, height = pcall(UIParent.GetSize, UIParent)
	if ok and Plain(width, "number") and Plain(height, "number") and width > 0 and height > 0 then
		return width / 2 + area.dx, height / 2 + area.dy
	end
	return nil
end

local function Busy(last, height, now)
	local free = last.start + (last.height + height) / 2 * SHAPE.line * last.life / last.length
	if free <= now then
		return nil
	end
	return math.min(free, math.max(now, last.start) + SHAPE.wait, now + SHAPE.most)
end

function ns.ScrollLane(newest, height, now, count, unit, half)
	local pick, at, first, age
	for lane = 1, count or #SHAPE.lanes do
		local last = newest[lane]
		local free = last and Busy(last, height, now)
		local by = free and last or nil
		if unit and half then
			local x = SHAPE.lanes[lane] * unit
			for other = 1, #SHAPE.lanes do
				local item = newest[other]
				if other ~= lane and item and item.on and ns.Finite(item.rx) and math.abs(x - item.rx) < half + (item.half or 0) + GAP then
					local busy = Busy(item, height, now)
					if busy and (not free or busy > free) then
						free, by = busy, item
					end
				end
			end
		end
		if not free then
			return lane, now
		end
		if not pick or free < at or (free == at and (by.start < first or (by.start == first and by.serial < age))) then
			pick, at, first, age = lane, free, by.start, by.serial
		end
	end
	return pick, at
end

local function Clear(occupant, height, now)
	if not occupant.on then
		return true
	end
	local u = (now - occupant.start) / occupant.life
	if occupant.style == "horizontal" then
		return SHAPE.reach * occupant.length * u >= SHAPE.clear * math.max(height, occupant.height)
	end
	return u >= occupant.hold
end

local function Row(area, item, now)
	local pick, oldest
	for row = 0, SHAPE.rows - 1 do
		local occupant = area.rows[row]
		if not occupant or Clear(occupant, item.height, now) then
			pick = row
			break
		end
		if not oldest or occupant.serial < area.rows[oldest].serial then
			oldest = row
		end
	end
	if not pick then
		pick = oldest
		for index, other in ipairs(area.live) do
			if other == area.rows[pick] then
				Release(area, index)
				break
			end
		end
	end
	area.rows[pick] = item
	item.row = pick
	return item.dir * pick * item.height * SHAPE.line
end

local function Direction(area)
	local choice = Opt(area.dirRow)
	if choice == "up" then
		return 1
	elseif choice == "down" then
		return -1
	end
	return area.dir
end

function ns.ScrollSize(key)
	local area = AREAS[key]
	local rule = Opt(area.sizeRow)
	if rule == "own" then
		return Opt("ownSize")
	elseif rule == "enemy" then
		return Opt("size")
	elseif rule == "smaller" then
		return Opt("size") * SMALLER
	end
	return Opt(area.size)
end

function ns.ScrollPitch(height, half)
	return math.max(SHAPE.lane * height, 2 * (half or 0) + GAP)
end

local function Height(area, crit, scale)
	return TEXT_HEIGHT * ns.ScrollSize(area.key) / 100 * (scale or 1) * (crit and CRIT or 1)
end

local function Fill(item, height, kind, value, format, r, g, b, flag, icon, value2)
	local text, word = item.text, item.word
	local hasIcon = Plain(icon, "number")
	local extra = kind ~= "word" and Plain(flag, "string") and flag == "EXTRA"
	if kind == "word" then
		text:SetText(value)
	else
		local done, withheld = false, nil
		local spec = (format or "%s") .. (extra and (" " .. EXTRA_TEXT) or "")
		local lead = hasIcon and INLINE:format(icon) or ""
		local at = ns.IsSecret(value) and ns.CombatWithheld and spec:find("%s", 1, true)
		if at then
			local before = lead .. (spec:sub(1, at - 1):gsub("%%%%", "%%"))
			local after = (spec:sub(at + 2):gsub("%%%%", "%%"))
			before, after = before ~= "" and before or nil, after ~= "" and after or nil
			done, withheld = ns.CombatWithheld(value, before, after)
			if done then
				local other
				if ns.IsSecret(value2) then
					local joined
					joined, other = ns.CombatWithheld(value2, " " .. (before or ""), after)
					if not joined then
						other = nil
					end
				end
				text:SetFormattedText("%s%s", withheld, other or "")
			end
		end
		if not done then
			local shown = value
			if type(BreakUpLargeNumbers) == "function" then
				local ok, broken = pcall(BreakUpLargeNumbers, value)
				if ok and (ns.IsSecret(broken) or broken ~= nil) then
					shown = broken
				end
			end
			text:SetFormattedText(lead .. spec, shown)
		end
	end
	text:SetTextHeight(height)
	text:SetTextColor(r, g, b)
	local suffix = kind ~= "word" and not extra and Plain(flag, "string") and ns.CombatSuffix(flag) or nil
	item.hasWord = suffix ~= nil
	if suffix then
		local colour = PARTIAL[flag] or PARTIAL.GLANCING
		word:SetText(suffix)
		word:SetTextHeight(height * WORD)
		word:SetTextColor(colour[1], colour[2], colour[3])
	end
	word:Hide()
	item.height = height
	item.hasIcon = kind == "word" and hasIcon
	if item.hasIcon then
		item.icon:SetTexture(icon)
		item.icon:SetSize(height, height)
		item.shift = (height + GAP) / 2
	else
		item.icon:Hide()
		item.shift = 0
	end
end

local function Chars(text)
	local count = _G.strlenutf8
	if type(count) == "function" then
		local ok, length = pcall(count, text)
		if ok and ns.Finite(length) then
			return length
		end
	end
	return #text
end

local function Width(region)
	local ok, width = pcall(region.GetStringWidth, region)
	if ok and ns.Finite(width) and width > 0 then
		return width
	end
	return nil
end

local function Half(item, height, value, named)
	local width = Width(item.text)
	if not width then
		local digits = 5
		if Plain(value, "number") then
			digits = #tostring(math.floor(math.abs(value)))
			digits = digits + math.floor((digits - 1) / 3)
		elseif Plain(value, "string") then
			digits = Chars(value)
		end
		width = 0.5 * height * (digits + named)
	end
	if item.hasWord then
		width = width + GAP + (Width(item.word) or 0.5 * height * WORD * 6)
	end
	return width / 2 + item.shift
end

local function Add(area, kind, value, format, crit, r, g, b, scale, flag, icon, value2, sample)
	if type(GetTime) ~= "function" then
		return false
	end
	local x, y = Spot(area)
	if not x then
		unplaced = unplaced + 1
		return false
	end
	local now = GetTime()
	local style = Opt(area.style)
	local height = Height(area, crit, scale)
	local item = Take(area)
	local look = ns.CombatLook()
	if item.look ~= look.key then
		Style(item, look)
	end
	Fill(item, height, kind, value, format, r, g, b, flag, icon, value2)
	serial = serial + 1
	item.serial, item.sample = serial, sample and true or false
	item.style, item.dir, item.side = style, Direction(area), area.side
	item.arc = SHAPE.arcs[Opt("arcWidth")] or SHAPE.arc
	item.length = SHAPE.length * ns.CombatWorldScale()
	item.life = style == "static" and SHAPE.still or SHAPE.life[Opt("speed")] or SHAPE.life.normal
	item.hold = style == "static" and SHAPE.stillHold or SHAPE.hold
	local start, lane, named, unit = now, nil, 0, 0
	if area.key == "out" and kind == "amount" and type(format) == "string" and not ns.IsSecret(format) and format ~= "%s" then
		named = math.max(0, Chars(format) - 3)
	end
	item.half = nil
	if PATH[style] then
		item.half = Half(item, height, value, named)
		unit = area.side * ns.ScrollPitch(Height(area), item.half)
		lane, start = ns.ScrollLane(area.lanes, height, now, named > 0 and 2 or nil, unit, item.half)
	end
	item.start, item.lane, item.x0, item.y0 = start, lane, x, y
	item.rx = lane and SHAPE.lanes[lane] * unit or 0
	item.ry = lane and 0 or Row(area, item, now)
	Place(item, now)
	item.text:Show()
	if item.hasIcon then
		item.icon:Show()
	end
	if item.group then
		pcall(item.group.Stop, item.group)
	end
	item.on = true
	area.live[#area.live + 1] = item
	if lane then
		area.lanes[lane] = item
	end
	if not sample then
		area.shown = area.shown + 1
		if start > now then
			area.waited = area.waited + 1
		end
	end
	active = active + 1
	if active == 1 then
		ticker:SetScript("OnUpdate", Tick)
	end
	if start <= now then
		Begin(item)
	else
		item.cue = true
	end
	return true
end

local ST = {}
ns.ScrollText = ST

function ns.CombatOutShown()
	return ST.On("out")
end

function ST.On(key)
	if not ns.Enabled(KEY) then
		return false
	elseif key == "out" then
		return Opt("where") ~= "over"
	end
	return Opt("own") ~= "off"
end

function ST.Show(key, kind, value, format, crit, r, g, b, scale, flag, sample, icon, value2)
	local area = AREAS[key]
	local ok, shown = pcall(Add, area, kind, value, format, crit, r, g, b, scale, flag, icon, value2, sample)
	if ok then
		return shown
	end
	area.failed, area.first = area.failed + 1, area.first or tostring(shown)
	return false
end

function ST.Clear(key)
	for _, area in ipairs(ORDER) do
		if key == nil or key == area.key then
			for index = #area.live, 1, -1 do
				Release(area, index)
			end
		end
	end
end

function ST.ClearSamples()
	for _, area in ipairs(ORDER) do
		for index = #area.live, 1, -1 do
			if area.live[index].sample then
				Release(area, index)
			end
		end
	end
end

function ST.Live(key)
	return #AREAS[key].live
end

function ST.Lines()
	local lines = {}
	for _, area in ipairs(ORDER) do
		if ST.On(area.key) then
			if area.key == "out" then
				lines[#lines + 1] = ("%s scroll area: %d shown."):format(area.label, area.shown)
			end
			if area.waited > 0 then
				lines[#lines + 1] = ("Numbers in the %s scroll area that waited for a free lane: %d."):format(area.label, area.waited)
			end
			if area.cut > 0 then
				lines[#lines + 1] = ("Numbers taken off the %s scroll area early, to make room when %d were on screen: %d."):format(area.label, area.max, area.cut)
			end
			if area.failed > 0 then
				lines[#lines + 1] = ("Numbers in the %s scroll area that raised an error: %d. The first: %s"):format(area.label, area.failed, area.first)
			end
		end
	end
	return lines
end

function ST.Unplaced()
	return unplaced
end

function ST.Shown(key)
	return AREAS[key].shown
end
