local _, ns = ...

-- Your buffs: a row of icons for the short buffs the player casts, each with its time left, at the personal resource display. The game
-- draws the row: one aura container of the game's own holds the buffs that pass its filters, also while the game hides buffs from addon code
-- in a fight. The class group matches the spell IDs of ns.ClassShortBuffs, the time group every buff the player casts that is not longer than
-- the time limit. The game compares the length of a buff with the limit, and its own parts draw the sweep, the time and the thin bar from the
-- length of each buff, so Flat UI never reads a time. The parts of each icon are made inside the function the game calls while it builds the
-- button, because from then on the game closes the button to addon code while it hides buffs. A change to those parts waits until the game
-- says buffs are open; a change to the container itself (its groups, their filters and their layout) is allowed at any time. Where the game
-- will not make the container, the same icons show out of combat from a read of the player's buffs. Nothing may anchor to the container: the
-- other rows of the display hang from the holder (ns.OwnBuffsHolder), which keeps its height when no buff is up.

local KEY = "ownbuffs"
-- The name of the row among the saved spots of the movers.
local MOVER = "FlatUIOwnBuffs"
local SPACING, GAP, CROP = 3, 4, 0.08
-- Room under the icon for the time as text, and for the thin bar and its gap.
local ROOM_TEXT, ROOM_BAR, BAR_HEIGHT = 14, 5, 3
local WIDTH = 120
local MOST_CLASS, MOST_TIME = 8, 6
local REREAD, TEST_TIME = 0.2, 8
local BARS = { "HealthBarsContainer", "PowerBar", "AlternatePowerBar" }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLUE = { 0.302, 0.6, 0.902 }
local NOTE_NO_POSITION = "Your buffs: the personal resource display has no position, so the row is above the player frame."
local NOTE_REFUSED = "Your buffs: the game refused the %s, so icons show without it."
local NOTE_MOUSE = "Your buffs: the game refused a mouse setting of the icons, so clicks or tooltips may not work."
local NOTE_READING = "Your buffs: Buff tooltips has no effect while the game makes no icon row."
local LINE_OUT = "Your buffs: the game made no icon row, so icons show out of combat only."
local HELP = {
	"/flatui buffs check - the way the row is drawn, its groups and where it hangs",
	"/flatui test - three sample icons for Your buffs",
}

local IsSecret = ns.IsSecret
local T = ns.Tracking
local B = { list = {}, pending = {}, refused = {}, icons = {}, groups = {} }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

-- A field of a frame, or nil when it is missing, cannot be read or is withheld.
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

-- The class lists ---------------------------------------------------------------------------------------------------------------------

-- The spell IDs of the short buffs of the player's class, as a map. A class with no data gives an empty map.
function B.ClassMap()
	-- The class does not change, so the game is asked once.
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

-- The buffs the rows of other pages already show: the trackers that are on, with Buffs that have a tracker set to Leave out, and the
-- defensives of Defensives on you while Your own defensives is on.
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

-- The candidate filters of the two groups. The class group matches the class list; the time group takes every buff the player casts, and
-- leaves the class list out when both groups are on, so that no buff shows twice.
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

-- The ID lists as one text, to tell whether the container has to hear of a change.
local function Signature(set)
	local ids = {}
	for id in pairs(set) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

-- The row's place ---------------------------------------------------------------------------------------------------------------------

-- The room under the icon: the text of the time, the thin bar, or none.
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

-- The highest and the lowest bar of the personal resource display that is shown, or the display itself.
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

-- True when a frame anchored to something has a rectangle. A client that cannot say is taken to have one.
local function Anchored(frame)
	local ok, left = pcall(frame.GetLeft, frame)
	return not ok or IsSecret(left) or left ~= nil
end

-- Hangs the holder by two points, so that it is as wide as the frame it hangs from. above: over the top of it, else under the bottom.
local function Hang(holder, frame, above, x, y)
	if above then
		holder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", x, GAP + y)
		holder:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", x, GAP + y)
	else
		holder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", x, y - GAP)
		holder:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", x, y - GAP)
	end
end

-- Hangs the holder at its place. Sets B.side to "above" or "below" when the other rows of the display may hang from it, and B.where to the
-- words of the check. Returns where it hangs: "above", "below", "swing", "own" or "player".
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
		holder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 70 + y)
		return "player"
	end
	holder:SetPoint("CENTER", UIParent, "CENTER", x, -150 + y)
	return "player"
end

-- The holder that the other rows of the display hang from, when the row is on and hangs over the bars ("above") or under them ("below").
function ns.OwnBuffsHolder(side)
	if B.holder and B.on and B.side == side then
		return B.holder
	end
	return nil
end

-- True while the Own spot has a handle in the movers.
function ns.OwnBuffsOwnShown()
	return ns.Enabled(KEY) and Opt("place") == "own"
end

-- The movers set or put back the spot.
function ns.OwnBuffsMoved()
	if B.holder and ns.Enabled(KEY) then
		ns.OutOfCombat(B.Refresh)
	end
end

-- The rows that hang from the holder are told when it starts or stops being their anchor.
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

-- The parts of a button ---------------------------------------------------------------------------------------------------------------

local function EdgeColour()
	if ns.Borderless() then
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

-- The four edges of the thin border, just inside the button.
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

-- The options of a bar filled by the time left (SimpleStatusBarConstantsDocumentation.lua).
local function BarOptions()
	local direction = type(Enum) == "table" and type(Enum.StatusBarTimerDirection) == "table" and Enum.StatusBarTimerDirection.RemainingTime
	local interpolation = type(Enum) == "table" and type(Enum.StatusBarInterpolation) == "table" and Enum.StatusBarInterpolation.Immediate
	return { interpolation = interpolation or 0, direction = direction or 1 }
end

-- Binds the time of the buffs to the string, the bar or nothing, as Time left says. Raises when the game refuses a binding.
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
		local font = parts[want]
		font:Show()
		button:SetDurationText(font, nil)
	elseif want == "bar" then
		parts.bar:Show()
		button:SetDurationBar(parts.bar, BarOptions())
	end
	parts.bound = want
end

-- The game's tooltip on hover and never a click, as Blizzard_CooldownViewer/CooldownViewer.lua:326-328 does it. Out of combat only keeps the
-- hover and hides the tooltip in a fight (Blizzard_AuraButton.lua:177-183).
local function Mouse(parts)
	local button, tips = parts.button, Opt("tooltips")
	local ok = pcall(button.SetMouseClickEnabled, button, false)
	ok = pcall(button.SetMouseMotionEnabled, button, tips ~= "off") and ok
	ok = pcall(button.SetHideTooltipInCombat, button, tips ~= "on") and ok
	-- A refused call leaves parts.tips empty so ApplyTips tries again, and the status names it.
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

-- Makes the parts of one button. Run by the game inside AddAuraGroup while the button is still open; nothing here may raise, and a part the
-- game refuses is left out and named in the status.
function B.Init(button)
	local parts = { button = button }
	B.list[#B.list + 1] = parts
	Mouse(parts)
	pcall(button.SetSize, button, Opt("size"), Opt("size"))
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
		B.refused.count, B.refused.time, B.refused.border = true, true, true
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
		bar:SetStatusBarTexture(ns.BarTexture() or WHITE)
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
end

-- Changes that wait for the game to open its buttons ------------------------------------------------------------------------------------

-- Time left on every button: the string under the icon, the string on it, the thin bar or none.
function B.ApplyTime()
	local want = Opt("time")
	for _, parts in ipairs(B.list) do
		if parts.bar and parts.bound ~= want then
			if not pcall(B.Bind, parts, want) then
				B.refused.time = true
			end
		end
	end
end

-- The border again where its thickness or colour has changed.
function B.ApplyBorder()
	for _, parts in ipairs(B.list) do
		if parts.edges and parts.borderKey ~= EdgeKey() then
			if not pcall(B.PaintEdges, parts) then
				B.refused.border = true
			end
		end
	end
end

-- Tooltips again where the setting has changed.
function B.ApplyTips()
	for _, parts in ipairs(B.list) do
		if parts.tips ~= Opt("tooltips") then
			Mouse(parts)
		end
	end
end

B.apply = { time = B.ApplyTime, border = B.ApplyBorder, tips = B.ApplyTips }

-- Runs what waited, once the game says buffs are open.
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

-- Does a change to the buttons now when the game says they are open, else when the game says so (a restriction that ends).
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

-- The game's container -----------------------------------------------------------------------------------------------------------------

local function Layout()
	local size = Opt("size")
	return { elementSpacing = SPACING, elementWidth = size, elementHeight = size }
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

-- Two groups of buttons on one container for the player, both for the buffs the player casts: the class list, and every buff that is not
-- longer than the limit. The buff that ends first is first.
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

-- Turns the groups on or off by Buffs shown. A container call, allowed at any time.
function B.Groups(on)
	local container = B.container
	if not container then
		return
	end
	local which = Opt("which")
	pcall(container.SetAuraGroupEnabled, container, "class", on and (which == "class" or which == "both"))
	pcall(container.SetAuraGroupEnabled, container, "time", on and (which == "every" or which == "both"))
end

-- Gives both groups their filters again where a list or the limit has changed. A container call, allowed at any time.
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

-- The size of the icons. A container call, allowed at any time.
function B.Sizes()
	local container = B.container
	if not container then
		return
	end
	local size = Opt("size")
	if size == B.sized then
		return
	end
	B.sized = size
	pcall(container.SetAuraGroupLayout, container, "class", Layout())
	pcall(container.SetAuraGroupLayout, container, "time", Layout())
end

-- Called by Trackers.lua when its list changes: Leave out hears of the new IDs.
function ns.OwnBuffsTrackers()
	if B.container and B.on then
		B.Lists()
	end
end

-- The reading path ----------------------------------------------------------------------------------------------------------------------

-- The buffs of the player that the groups would show, from one read: plain tables only. Nothing when the game hides buffs.
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

-- Puts icons in a row from the middle of the top of the holder.
function B.Row(list)
	local size = Opt("size")
	local count = #list
	local width = count > 0 and (count * size + (count - 1) * SPACING) or 0
	for index, icon in ipairs(list) do
		icon.frame:SetSize(size, size)
		icon.frame:ClearAllPoints()
		icon.frame:SetPoint("TOPLEFT", B.Holder(), "TOP", (index - 1) * (size + SPACING) - width / 2, 0)
	end
end

-- One pass of the reading path: the icons that match what was read, and none when nothing could be read.
function B.Pass()
	B.scheduled = false
	if B.path ~= "reading" or not ns.Enabled(KEY) or B.testing then
		return
	end
	local found = B.Read() or {}
	local shown = {}
	for index = 1, #found do
		local item, icon = found[index], B.Icon(index)
		if icon then
			ns.IconSet(icon, item.file, item.expires - item.length, item.length, { numbers = Opt("time") ~= "off" })
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
		-- The payload is not read where the game sends the event for the player alone: it may be withheld.
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
	for _, icon in ipairs(B.icons) do
		ns.IconClear(icon)
	end
end

-- Putting it all in place -------------------------------------------------------------------------------------------------------------------

-- True when the game has the call that reads a unit's buffs. Without it the module makes nothing.
function B.Capable()
	return type(C_UnitAuras) == "table" and type(C_UnitAuras.GetUnitAuras) == "function"
end

function B.Sync()
	B.on = B.Capable() and ns.Enabled(KEY)
	if not B.on then
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
		B.Change("time")
		B.Change("border")
		B.Change("tips")
	elseif B.path == "reading" then
		B.StartReading()
	end
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

-- The check and the test ---------------------------------------------------------------------------------------------------------------------

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

-- Ends a test: the sweeps are cleared and the icons hidden.
function B.EndTest(token)
	local test = B.testing
	if not test or (token and test ~= token) then
		return
	end
	B.testing = nil
	for _, icon in ipairs(test.list) do
		ns.IconClear(icon)
	end
	if B.holder and not (B.on and ns.Enabled(KEY)) then
		B.holder:Hide()
	end
	B.Pass()
end

-- Three sample icons, run by /flatui test with the samples of the other rows.
function ns.OwnBuffsTest()
	if not B.Capable() then
		return
	end
	if not (B.on and ns.Enabled(KEY)) then
		print("Your buffs: the row is off.")
		return
	end
	if InCombatLockdown() then
		print("Your buffs: the test shows out of combat only.")
		return
	end
	if B.testing then
		B.EndTest()
	end
	-- The icons of the reading path wait while the samples show.
	for _, icon in ipairs(B.icons) do
		ns.IconClear(icon)
	end
	local holder = B.Holder()
	B.Place()
	holder:Show()
	local list, now = {}, Now()
	B.sample = B.sample or {}
	for index = 1, 3 do
		local icon = B.sample[index] or ns.IconNew(holder)
		if not icon then
			return
		end
		B.sample[index] = icon
		list[index] = icon
		ns.IconSet(icon, ({ 135940, 135964, 136089 })[index], now, 2 * index + 2, { numbers = Opt("time") ~= "off" })
	end
	B.Row(list)
	local test = { list = list }
	B.testing = test
	print("Your buffs: three sample icons for 8 seconds.")
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(TEST_TIME, function()
			B.EndTest(test)
		end)
	end
end

function B.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if B.path == "reading" then
		lines[#lines + 1] = LINE_OUT
	end
	local names = { icon = "icon", sweep = "sweep", count = "count", time = "time left", border = "border" }
	for _, name in ipairs({ "icon", "sweep", "count", "time", "border" }) do
		if B.refused[name] then
			lines[#lines + 1] = NOTE_REFUSED:format(names[name])
		end
	end
	if B.refused.tips then
		lines[#lines + 1] = NOTE_MOUSE
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
		-- Icons read out of combat hide when the fight starts and the game withholds the buffs.
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

ns.OwnBuffsModule = B
