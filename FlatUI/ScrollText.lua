local _, ns = ...

-- Scroll areas for combat text: Outgoing for your hits and Incoming for what happens to you. A number starts at the handle of its area
-- (FlatUICombatOut and FlatUICombatSelf in the movers) and moves by the style of the area for a time that Speed sets. CombatText.lua works
-- out what a hit report shows and passes it here; this file places it, pops it and fades it. A number is a font string with a Scale
-- animation in Vertex mode, so the pop is smooth, and a second font string that holds the partial effect, such as (Glancing), which
-- appears when the pop ends. A record is made on first use and reused, and no table is made for a hit. The lengths, times and sizes below
-- are choices of this file, not the game's: the design is research/reports/2026-10-20-scrolling-text/design.md, sections 2.1, 2.2 and 2.6.
-- A secret amount or name goes to SetText and SetFormattedText only; nothing here compares, counts or measures it.

local KEY = "combattext"

-- Length of an area on a screen 768 units high, the share of it an arc and a horizontal number move sideways, the seconds a number lives at
-- each Speed, the seconds a Static number lives, the share of the life at which the fade begins (a Static number fades earlier), the share
-- of the life the fade in takes, the height of a line as a share of the height of a number, the rows a Horizontal or Static area has, and
-- the heights of a number a Horizontal number must travel before another may start in its row.
local SHAPE = { length = 240, arc = 0.2, arcs = { narrow = 0.2, wide = 0.35 }, reach = 0.6, life = { fast = 1.6, normal = 2.2, slow = 3.0 }, still = 1.5, hold = 0.75, stillHold = 0.7,
	fadeIn = 0.03, line = 1.04, rows = 5, clear = 2.5 }
-- The pop: the scale at its peak, and the seconds up and down. A critical hit is this much larger than a hit. A partial effect is drawn at
-- this share of the number, this many units to the right of it.
local POP = { peak = 1.15, up = 0.05, down = 0.10 }
local CRIT, WORD, GAP = 1.25, 0.75, 4
-- The setup drawing of combat text moves its sample numbers by the same shape.
SHAPE.crit = CRIT
ns.CombatShape.scroll = SHAPE
-- The height of a message in the game's combat text (CombatTextConstants.lua:6).
local TEXT_HEIGHT = 25
-- The colours of a partial effect (CombatFeedback.lua:41-58 gives the sizes; the colours are a choice of this file).
local PARTIAL = { GLANCING = { 0.7, 0.7, 0.7 }, CRUSHING = { 1, 0.4, 0.2 }, RESIST = { 0.79, 0.3, 0.85 }, BLOCK = { 0.6, 0.7, 1 },
	BLOCK_REDUCED = { 0.6, 0.7, 1 }, ABSORB = { 1, 0.85, 0.4 }, EXTRA = { 1, 0.6, 0.15 } }
-- The two areas: the name of the handle, the row of the style, the row of the size, the direction (1 up, -1 down), the side an arc and a
-- horizontal number go to, the most numbers alive and, with no handle to take the place from, where the area starts as units from the
-- middle of the screen.
local AREAS = {
	out = { label = "Outgoing", mover = "FlatUICombatOut", style = "outStyle", size = "size", dir = 1, side = 1, max = 16, dx = 170, dy = -30 },
	inc = { label = "Incoming", mover = "FlatUICombatSelf", style = "inStyle", size = "ownSize", dir = -1, side = -1, max = 12, dx = -170, dy = -30 },
}
local ORDER = { AREAS.out, AREAS.inc }
for key, area in pairs(AREAS) do
	area.key, area.items, area.live, area.rows, area.shown, area.failed = key, {}, {}, {}, 0, 0
end

local host, ticker
-- Numbers on screen in all areas, and numbers that had no place to start from.
local active, unplaced = 0, 0

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

-- Where a number is at u, the share of its life, as units from its start: straight along the direction, along it and out to the side in a
-- half sine for an arc (width is the share of the length it bows out, SHAPE.arc when nil), out to the side for horizontal, nowhere for
-- static. dir is 1 up and -1 down, side 1 right and -1 left.
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

-- The opacity of a number at u: in over the first share of its life, whole until hold, then down to nothing.
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

-- The scale animation of a number, in Vertex mode (UISharedDocumentation.lua:6-15): up to the peak and back, played unless How a number
-- appears is Plainly. A client that has no such animation on a font string gives a number with no pop.
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
	-- The icon of the spell, left of the number. One texture for each record, made once.
	local icon = host:CreateTexture(nil, "OVERLAY", nil, 0)
	ns.Own[icon] = true
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("RIGHT", text, "LEFT", -GAP, 0)
	icon:Hide()
	local item = { text = text, word = word, icon = icon, shift = 0, area = area, on = false }
	MakePop(item)
	return item
end

-- Puts the look of the settings on both font strings of a number.
local function Style(item, look)
	local object = look.object or look.name
	pcall(item.text.SetFontObject, item.text, object)
	pcall(item.word.SetFontObject, item.word, object)
	item.look = look.key
end

local function Release(area, index)
	local item = table.remove(area.live, index)
	item.on = false
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

-- A record that is free, or a new one while the area has fewer than its most, else the oldest number, which goes.
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
	Release(area, 1)
	return oldest
end

-- Where a number is now: the start, the path of its style and its row.
local function Place(item, now)
	local t = now - item.start
	local u = t / item.life
	local dx, dy = ns.ScrollPath(item.style, u, item.length, item.dir, item.side, item.arc)
	local text = item.text
	text:ClearAllPoints()
	text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", item.x0 + dx + item.shift, item.y0 + dy + item.ry)
	local alpha = ns.ScrollAlpha(u, item.hold)
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

local function Step()
	local now = GetTime()
	for _, area in ipairs(ORDER) do
		for index = #area.live, 1, -1 do
			local item = area.live[index]
			if now - item.start >= item.life then
				Release(area, index)
			elseif not pcall(Place, item, now) then
				Release(area, index)
			end
		end
	end
end

local function Tick()
	ns.Try(KEY, Step)
end

-- The place a number starts: the middle of the handle of its area, else the middle of the screen moved by the place the handle starts at.
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

-- True when the number in a row has gone far enough for another to start there: a Horizontal number after SHAPE.clear heights, a Static
-- number when it begins to fade.
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

-- How far from its start a number begins, along the direction of its area. Straight and arc numbers start one line behind the last number
-- when that one has not moved a line yet. Horizontal and static numbers take the first row whose number has gone, else the row of the
-- oldest, one line further on for each row.
local function Row(area, item, now)
	local line = item.height * SHAPE.line
	if item.style == "straight" or item.style == "arc" then
		local last = area.live[#area.live]
		if not last then
			return 0
		end
		local ahead = last.length * (now - last.start) / last.life + area.dir * last.ry
		return ahead < line and area.dir * (ahead - line) or 0
	end
	local pick, oldest
	for row = 0, SHAPE.rows - 1 do
		local occupant = area.rows[row]
		if not occupant or Clear(occupant, item.height, now) then
			pick = row
			break
		end
		if not oldest or occupant.start < area.rows[oldest].start then
			oldest = row
		end
	end
	pick = pick or oldest
	area.rows[pick] = item
	return area.dir * pick * line
end

local function Fill(area, item, kind, value, format, crit, r, g, b, scale, flag, icon)
	local text, word = item.text, item.word
	if kind == "word" then
		text:SetText(value)
	else
		local shown = value
		if type(BreakUpLargeNumbers) == "function" then
			local ok, broken = pcall(BreakUpLargeNumbers, value)
			if ok and (ns.IsSecret(broken) or broken ~= nil) then
				shown = broken
			end
		end
		text:SetFormattedText(format or "%s", shown)
	end
	local height = TEXT_HEIGHT * Opt(area.size) / 100 * (scale or 1) * (crit and CRIT or 1)
	text:SetTextHeight(height)
	text:SetTextColor(r, g, b)
	local suffix = kind ~= "word" and Plain(flag, "string") and ns.CombatSuffix(flag) or nil
	item.hasWord = suffix ~= nil
	if suffix then
		local colour = PARTIAL[flag] or PARTIAL.GLANCING
		word:SetText(suffix)
		word:SetTextHeight(height * WORD)
		word:SetTextColor(colour[1], colour[2], colour[3])
	end
	word:Hide()
	item.height = height
	-- The icon is as high and as wide as the number, and the text moves right by half of it and the gap, so the pair is centred on the path.
	item.hasIcon = Plain(icon, "number")
	if item.hasIcon then
		item.icon:SetTexture(icon)
		item.icon:SetSize(height, height)
		item.shift = (height + GAP) / 2
	else
		item.icon:Hide()
		item.shift = 0
	end
end

local function Add(area, kind, value, format, crit, r, g, b, scale, flag, icon)
	if type(GetTime) ~= "function" then
		return false
	end
	local x, y = Spot(area)
	if not x then
		unplaced = unplaced + 1
		return false
	end
	local item = Take(area)
	local look = ns.CombatLook()
	if item.look ~= look.key then
		Style(item, look)
	end
	local now = GetTime()
	local style = Opt(area.style)
	Fill(area, item, kind, value, format, crit, r, g, b, scale, flag, icon)
	item.style, item.dir, item.side = style, area.dir, area.side
	item.arc = SHAPE.arcs[Opt("arcWidth")] or SHAPE.arc
	item.length = SHAPE.length * ns.CombatWorldScale()
	item.life = style == "static" and SHAPE.still or SHAPE.life[Opt("speed")] or SHAPE.life.normal
	item.hold = style == "static" and SHAPE.stillHold or SHAPE.hold
	item.start, item.x0, item.y0 = now, x, y
	item.ry = Row(area, item, now)
	Place(item, now)
	item.text:Show()
	if item.hasIcon then
		item.icon:Show()
	end
	if item.group then
		pcall(item.group.Stop, item.group)
		if Opt("pop") == "pop" then
			pcall(item.group.Play, item.group)
		end
	end
	item.on = true
	area.live[#area.live + 1] = item
	area.shown = area.shown + 1
	active = active + 1
	if active == 1 then
		ticker:SetScript("OnUpdate", Tick)
	end
	return true
end

local ST = {}
ns.ScrollText = ST

-- True while the Outgoing area shows hits, which is also when the movers have a handle for where it starts.
function ns.CombatOutShown()
	return ST.On("out")
end

-- True while the area shows numbers: Outgoing unless Where your hits show is Over enemies, Incoming unless Combat text for you is Off.
function ST.On(key)
	if not ns.Enabled(KEY) then
		return false
	elseif key == "out" then
		return Opt("where") ~= "over"
	end
	return Opt("own") ~= "off"
end

-- Shows one number in an area. kind is "amount" or "word"; format is the format of an amount, with its sign; flag is the plain flag of
-- the hit, which gives the partial effect, and icon is the file of the spell icon left of the number, or nil. True when the number is on screen. A sample is not counted as shown. An error is counted and
-- does not go up.
function ST.Show(key, kind, value, format, crit, r, g, b, scale, flag, sample, icon)
	local area = AREAS[key]
	local ok, shown = pcall(Add, area, kind, value, format, crit, r, g, b, scale, flag, icon)
	if ok then
		if shown and sample then
			area.shown = area.shown - 1
		end
		return shown
	end
	area.failed, area.first = area.failed + 1, area.first or tostring(shown)
	return false
end

-- Takes the numbers of one area, or of both, off the screen.
function ST.Clear(key)
	for _, area in ipairs(ORDER) do
		if key == nil or key == area.key then
			for index = #area.live, 1, -1 do
				Release(area, index)
			end
		end
	end
end

-- The numbers of one area on screen.
function ST.Live(key)
	return #AREAS[key].live
end

-- The lines /flatui combat has about the areas: the count of the Outgoing area and the numbers that failed in either.
function ST.Lines()
	local lines = {}
	for _, area in ipairs(ORDER) do
		if ST.On(area.key) then
			if area.key == "out" then
				lines[#lines + 1] = ("%s scroll area: %d shown."):format(area.label, area.shown)
			end
			if area.failed > 0 then
				lines[#lines + 1] = ("Numbers in the %s scroll area that raised an error: %d. The first: %s"):format(area.label, area.failed, area.first)
			end
		end
	end
	return lines
end

-- The numbers that had no place to start from, in both areas.
function ST.Unplaced()
	return unplaced
end

-- The numbers an area has shown since login.
function ST.Shown(key)
	return AREAS[key].shown
end
