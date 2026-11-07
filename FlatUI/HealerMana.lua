local _, ns = ...

-- Healer mana: a small window of Flat UI's own with the mana of the healers of the group, one bar each in the order of the group, in the class
-- colour of the member, with the share of mana left. A healer is a member whose role is healer (UnitGroupRolesAssigned, UnitDocumentation.lua:
-- 1318-1332), or, while the member has no role, of a class that heals (Priest, Paladin, Shaman and Druid, as Setup.lua lists them). The share is
-- UnitPowerPercent of the member's mana through the game's curve to 100 (UnitDocumentation.lua:2838-2857, CurveConstants.lua:9-12), as
-- UnitText.lua writes a power share, so a druid in a form shows mana too. The game may withhold it (SecretWhenUnitPowerRestricted): it is never
-- read, compared or added, and goes as it is to SetValue of the bar and to SetFormattedText of its text, which take it
-- (SimpleStatusBarAPIDocumentation.lua:355-365, SimpleFontStringAPIDocumentation.lua:539-548), as the Threat list does. A member offline or dead
-- has an empty bar with the word, from plain answers only. The window shows in a dungeon or raid, or in any group, as Show says, while the group
-- has a healer; it is drawn again on a step of half a second only while it shows, and the group is read again when it changes
-- (GROUP_ROSTER_UPDATE, PLAYER_ROLES_ASSIGNED, PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA; a burst is read once, a moment after the first).
-- The window is a child of UIParent in the LOW strata in the look of the Threat list (Threat.lua): a flat background and a thin border in the
-- colours of the Flat UI page, its bars in the bar texture of that page; it takes no mouse and hides with the interface. /flatui move places it
-- (FlatUIHealerMana in Movers.lua: the window's top left corner is the top left corner of the box). /flatui healers shows sample bars for a few
-- seconds. Nothing of the game is changed.
-- This follows the Healer Mana indicator of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoL/Submodules/
-- GroupTools.lua:485-713): the healers of the group by their role, their mana share through UnitPowerPercent and the curve to 100, and the
-- dungeon or raid rule. Its lines of text, fonts, alignment and name width are bars in the look of the Threat list here, and a member with no
-- role is counted by class, since groups on Forever often have no roles.

local KEY = "healermana"
local MOVER = "FlatUIHealerMana"
-- The box of the handle in Movers.lua: the room of three bars at the default size, and where it is with no spot saved, right of the middle and
-- under the Threat list.
local BOX_W, BOX_H, BOX_X, BOX_Y = 158, 76, 420, -130
-- Units inside the edge of the window, between two bars, and between the end of a bar and its text.
local PAD, GAP, INSET = 4, 2, 4
-- A burst of events is read once, this long after the first. The step while the list shows. How long /flatui healers shows.
local STEP, TICK, TEST_TIME = 0.2, 0.5, 8
local MOST_ROWS = 10
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TITLE = "Healer mana"
-- The power type of mana (Enum.PowerType.Mana).
local MANA = 0
-- The classes that heal (Setup.lua, S.HEALERS).
local HEALERS = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true }
-- The text-dim of the windows (PanelLook.lua) for the title, the track behind a fill, and the colour of a member whose class the game withholds,
-- as the Threat list has them.
local DIM = { 0.66, 0.68, 0.62 }
local TRACK = { 0.2, 0.2, 0.2, 0.5 }
local GREY = { 0.6, 0.6, 0.6 }
local LINE_MISSING = "Healer mana: this client has no UnitPowerPercent, so the list stays hidden."
local HELP = { "/flatui healers - sample bars of the healer mana list for a few seconds" }
-- The bars of /flatui healers: a name, a class and the share of mana.
local SAMPLE = { { "Priest", "PRIEST", 82 }, { "Druid", "DRUID", 47 }, { "Shaman", "SHAMAN", 15 } }

local IsSecret = ns.IsSecret
-- frame: the window, title its line. rows: the bars. healers: the units of the healers, read from the group. pending: a read waits. ticker: the
-- token of the step. sample: the token of /flatui healers while it shows. placed: the spot the window was put at, laid: the layout of its bars.
local H = { rows = {}, healers = {} }
ns.HealerMana = H

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- A number row, else its default.
local function Number(key, default)
	local value = Opt(key)
	return ns.Finite(value) and value or default
end

-- A count the game gives, as a whole number from 0 to most.
local function Count(fn, most)
	local value = Ask(fn)
	if ns.Finite(value) and value > 0 then
		return math.min(math.floor(value), most)
	end
	return 0
end

-- A timer of the client, false when there is none or it raises.
local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

-- The curve that turns a share of 1 into 100, or nil when the client has none.
local function Hundred()
	local constants = CurveConstants
	if type(constants) ~= "table" or IsSecret(constants) then
		return nil
	end
	local ok, curve = pcall(function()
		return constants.ScaleTo100
	end)
	if ok and not IsSecret(curve) and curve ~= nil then
		return curve
	end
	return nil
end

-- Who and when -----------------------------------------------------------------------------------------------------------------------------------

-- True when Show lets the list show now: in a dungeon or raid, or in any group.
function H.Allowed()
	if Ask(IsInGroup) ~= true then
		return false
	elseif Opt("show") == "group" then
		return true
	end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and not IsSecret(inside) and inside == true and not IsSecret(kind) and (kind == "party" or kind == "raid")
end

-- True for a healer: the role says so, or the member has no role and is of a class that heals. A withheld role counts as none.
function H.Healer(unit)
	local role = Ask(UnitGroupRolesAssigned, unit)
	if role == "HEALER" then
		return true
	elseif role == "TANK" or role == "DAMAGER" then
		return false
	end
	local class = Ask(UnitClassBase, unit)
	return type(class) == "string" and HEALERS[class] == true
end

-- The healers of the group in its order: in a raid raid1 to raid40, the player among them; else the player, then party1 to party4.
function H.Read()
	local list = {}
	local function Member(unit)
		if Ask(UnitExists, unit) == true and H.Healer(unit) then
			list[#list + 1] = unit
		end
	end
	if Ask(IsInRaid) == true then
		for index = 1, Count(GetNumGroupMembers, 40) do
			Member("raid" .. index)
		end
	elseif Ask(IsInGroup) == true then
		Member("player")
		for index = 1, Count(GetNumSubgroupMembers, 4) do
			Member("party" .. index)
		end
	end
	return list
end

-- Drawing -----------------------------------------------------------------------------------------------------------------------------------

-- Red, green and blue of a class by its file name, or nil.
local function ClassRGB(class)
	local colours = RAID_CLASS_COLORS
	if type(class) ~= "string" or type(colours) ~= "table" or IsSecret(colours) then
		return nil
	end
	local colour = colours[class]
	if type(colour) ~= "table" or IsSecret(colour) then
		return nil
	end
	local r, g, b = colour.r, colour.g, colour.b
	if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return nil
end

-- Writes the name of a unit, or nothing; a withheld name goes to the text as it is.
local function SetName(text, unit)
	local ok, name = pcall(UnitName, unit)
	if ok and (IsSecret(name) or type(name) == "string") then
		text:SetText(name)
	else
		text:SetText("")
	end
end

-- The window, made the first time it shows: a frame of the addon's own on UIParent with a flat background and a thin border, and its title.
function H.Frame()
	if H.frame then
		return H.frame
	end
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	frame:SetFrameStrata("LOW")
	frame:SetSize(BOX_W, BOX_H)
	frame:Hide()
	H.frame = frame
	H.outline = ns.Outline(frame, frame, true)
	local title = ns.OwnText(frame, "OVERLAY", FONT)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + INSET, -PAD)
	title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + INSET), -PAD)
	title:SetText(TITLE)
	H.title = title
	return frame
end

-- Bar number index, made the first time the list needs it: a track, the fill, the name on the left and the share on the right.
function H.Row(index)
	local row = H.rows[index]
	if row then
		return row
	end
	local bar = Own(CreateFrame("StatusBar", nil, H.frame))
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	local track = Own(bar:CreateTexture(nil, "BACKGROUND", nil, -7))
	track:SetAllPoints(bar)
	track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
	local share = ns.OwnText(bar, "OVERLAY", FONT)
	share:SetJustifyH("RIGHT")
	share:SetWordWrap(false)
	share:SetPoint("RIGHT", bar, "RIGHT", -INSET, 0)
	local name = ns.OwnText(bar, "OVERLAY", FONT)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	name:SetPoint("LEFT", bar, "LEFT", INSET, 0)
	name:SetPoint("RIGHT", share, "LEFT", -INSET, 0)
	row = { bar = bar, track = track, name = name, share = share }
	H.rows[index] = row
	return row
end

-- The bar texture of the Flat UI page, and the height of the text, on one bar. A texture the game refuses leaves a flat fill.
local function Paint(row, file, text)
	if row.file ~= file then
		local ok, done = pcall(row.bar.SetStatusBarTexture, row.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(row.bar.SetStatusBarTexture, row.bar, WHITE)
		end
		row.file = file
	end
	if row.text ~= text then
		row.name:SetTextHeight(text)
		row.share:SetTextHeight(text)
		row.text = text
	end
end

-- Lays out the title and n bars, and sizes the window to them. A layout that is already in place is left as it is. The text is as high as the bar
-- allows, as on the Threat list.
function H.Layout(n)
	local width, height = Number("barWidth", 150), Number("barHeight", 16)
	local text = math.max(7, math.min(14, height - 4))
	local file = ns.BarTexture() or WHITE
	for index = 1, n do
		Paint(H.Row(index), file, text)
	end
	local key = ("%s:%s:%s"):format(n, width, height)
	if H.laid == key then
		return
	end
	H.laid = key
	local top = PAD + text + 2 + GAP
	H.title:SetTextHeight(text)
	for index = 1, n do
		local bar = H.rows[index].bar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", H.frame, "TOPLEFT", PAD, -(top + (index - 1) * (height + GAP)))
		bar:SetSize(width, height)
	end
	H.frame:SetSize(width + 2 * PAD, top + n * height + (n - 1) * GAP + PAD)
end

-- Writes one bar: the class colour, the name and the share of mana; the share goes to the bar and its text untouched. A sample is a table of
-- SAMPLE.
function H.Fill(row, unit, sample)
	local r, g, b
	if sample then
		r, g, b = ClassRGB(sample[2])
	else
		r, g, b = ns.ClassColourOf(unit)
	end
	if not r then
		r, g, b = GREY[1], GREY[2], GREY[3]
	end
	row.bar:SetStatusBarColor(r, g, b, 1)
	row.bar:Show()
	if sample then
		row.name:SetText(sample[1])
		row.bar:SetValue(sample[3])
		row.share:SetText(("%d%%"):format(sample[3]))
		return
	end
	SetName(row.name, unit)
	local word = nil
	if Ask(UnitIsConnected, unit) == false then
		word = "Offline"
	elseif Ask(UnitIsDeadOrGhost, unit) == true then
		word = "Dead"
	end
	if word then
		row.bar:SetValue(0)
		row.share:SetText(word)
		return
	end
	local ok, share = pcall(UnitPowerPercent, unit, MANA, false, Hundred())
	if not ok or not pcall(row.bar.SetValue, row.bar, share) then
		row.bar:SetValue(0)
	end
	if not ok or not pcall(row.share.SetFormattedText, row.share, "%.0f%%", share) then
		row.share:SetText("")
	end
end

-- Puts the window at the spot of its handle: its top left corner at the top left corner of the box.
function H.Place()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "TOPLEFT")
	end
	local key = x and ("%.2f:%.2f"):format(x, y) or "start"
	if H.placed == key then
		return
	end
	H.placed = key
	local frame = H.frame
	frame:ClearAllPoints()
	if x then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	else
		frame:SetPoint("TOPLEFT", UIParent, "CENTER", BOX_X - BOX_W / 2, BOX_Y + BOX_H / 2)
	end
end

-- Shows a bar for each healer, as many as Number of bars allows (the samples for /flatui healers), or hides the window when there are none.
function H.Draw()
	local samples = H.sample and SAMPLE or nil
	local list = samples or H.healers
	local n = math.min(#list, Number("rows", 5), MOST_ROWS)
	if n < 1 then
		if H.frame then
			H.frame:Hide()
		end
		H.Tick(false)
		return
	end
	H.Frame()
	H.Layout(n)
	for index = 1, n do
		if samples then
			H.Fill(H.rows[index], nil, samples[index])
		else
			H.Fill(H.rows[index], list[index])
		end
	end
	for index = n + 1, #H.rows do
		H.rows[index].bar:Hide()
	end
	H.Place()
	H.frame:Show()
	H.Tick(not samples)
end

-- Reading -----------------------------------------------------------------------------------------------------------------------------------

-- Who the list shows now, and the list drawn.
function H.Update()
	H.pending = nil
	local on = ns.Enabled(KEY) and type(UnitPowerPercent) == "function"
	if on and not H.sample and H.Allowed() then
		H.healers = H.Read()
	else
		H.healers = {}
	end
	if on or H.sample then
		H.Draw()
	elseif H.frame then
		H.frame:Hide()
		H.Tick(false)
	end
end

-- Reads the group again a moment later, once for a burst of events.
function H.Soon()
	if H.pending then
		return
	end
	H.pending = true
	if not After(STEP, function()
		ns.Try(KEY, H.Update)
	end) then
		H.Update()
	end
end

-- A step of half a second while the list of a group shows: the shares are drawn again, and nothing is read but them. A client without NewTicker
-- gets a timer that sets the next one while the token is the step's, as the Threat list has it.
local function Step()
	if H.frame and #H.healers > 0 and not H.sample then
		local n = math.min(#H.healers, Number("rows", 5), MOST_ROWS)
		for index = 1, math.min(n, #H.rows) do
			H.Fill(H.rows[index], H.healers[index])
		end
	end
end

function H.Tick(on)
	if on and not H.ticker then
		local token = {}
		H.ticker = token
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, TICK, function()
				ns.Try(KEY, Step)
			end)
			token.handle = ok and ticker or nil
		end
		if not token.handle then
			local function Again()
				if H.ticker == token then
					ns.Try(KEY, Step)
					if H.ticker == token and not After(TICK, Again) then
						H.ticker = nil
					end
				end
			end
			if not After(TICK, Again) then
				H.ticker = nil
			end
		end
	elseif not on and H.ticker then
		local handle = H.ticker.handle
		H.ticker = nil
		if handle and type(handle.Cancel) == "function" then
			pcall(handle.Cancel, handle)
		end
	end
end

function H.Refresh()
	H.pending, H.placed, H.laid = nil, nil, nil
	if not ns.Enabled(KEY) then
		H.sample, H.healers = nil, {}
		H.Tick(false)
		if H.frame then
			H.frame:Hide()
		end
		return
	end
	H.Update()
end

-- /flatui healers: the sample bars for a few seconds.
function H.Slash()
	if not ns.Enabled(KEY) then
		print("Healer mana: turn on Show healer mana first.")
		return
	end
	local token = {}
	H.sample = token
	ns.Try(KEY, H.Update)
	local function Done()
		if H.sample == token then
			H.sample = nil
			ns.Try(KEY, H.Update)
		end
	end
	if not After(TEST_TIME, Done) then
		Done()
	end
end

function H.Status()
	local lines = {}
	if ns.Enabled(KEY) and type(UnitPowerPercent) ~= "function" then
		lines[#lines + 1] = LINE_MISSING
	end
	return lines
end

-- The movers ----------------------------------------------------------------------------------------------------------------------------------

-- True while the list has a handle in the movers: while the module is on.
function ns.HealerManaShown()
	return ns.Enabled(KEY)
end

-- The movers set or put back the spot.
function ns.HealerManaMoved()
	H.placed = nil
	if H.frame and ns.Enabled(KEY) then
		ns.Try(KEY, H.Place)
	end
end

local function Soon()
	H.Soon()
end

ns.Register(KEY, {
	label = "Healer mana",
	counted = false,
	Start = H.Refresh,
	Refresh = H.Refresh,
	Resized = H.Refresh,
	Status = H.Status,
	events = { GROUP_ROSTER_UPDATE = Soon, PLAYER_ROLES_ASSIGNED = Soon, PLAYER_ENTERING_WORLD = Soon, ZONE_CHANGED_NEW_AREA = Soon },
	slash = { healers = H.Slash },
	help = HELP,
})
