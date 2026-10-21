local _, ns = ...

-- The game's own icon, bar or text for each buff tracker. In a fight the game withholds the values of a buff from addon code,
-- so Trackers.lua cannot read its charges or time left, but the game will draw the buff itself: an aura container
-- with one slot, laid over the tracker's frame, shows the buff, its charges and its time left. A bar is a second look of the same
-- slot: a status bar the game fills by the time left, and for a bar filled by charges a second slot whose button fills a bar by
-- the charges (a button has one application bar and the icon's cover has it). The icon, the bar and the text are three wrapper
-- frames of the button, and the shape the tracker has is the wrapper whose alpha is 1. The slot is made
-- out of sight (alpha 0) with every part it will ever need made inside the function the game calls while it builds
-- the slot, because from then on the game closes the button to addon code while it hides buffs. A change to those
-- parts waits until the game says buffs are open; a change to the container itself (its alpha, its slot, the
-- spell IDs it matches) is allowed at any time. The game has no call that frees a container, so a tracker frame
-- keeps its container for good and the next tracker on that frame uses it. This file is no module of its own:
-- Trackers.lua calls ns.TrackerSlots, and what it has to say goes to the status lines of Trackers.

local KEY = "trackers"
-- The key of the slot, and of the second try after the first slot could not be made.
local SLOT, SLOT_AGAIN = "tracker", "tracker2"
-- The key of the second slot, the bar filled by charges.
local SLOT_BAR = "trackerbar"
-- Levels the container is drawn above the tracker's frame, so above every child of it.
local ABOVE = 10
local CROP = 0.08
-- The thickness of the low rim, in screen pixels.
local RIM = 2
local UNKNOWN_ICON = 134400
-- ffd94040, the colour of a low count and of the low rim.
local RED = { 0.851, 0.251, 0.251 }
local LOW_FORMAT = "|cffd94040%d|r"
local PLAIN_FORMAT = "%d"
local NOTE_REFUSED = "Trackers: the game refused its own icon for buffs, so in fights trackers show the last known charges and time, or are hidden, as In fights without the game's icon says."
local NOTE_LATE = "Trackers: a setting did not reach the game's own icon. /reload applies it."
local NOTE_ERROR = "Trackers: error in the game's own icon. "
local NOTE_TARGET = "Trackers: the game refused to refresh its own icon for the target, so a debuff may show late after a target change."
local NOTE_HIDE = "Trackers: in fights Only when low or missing shows every tracker, because the game refused a hidden answer."
local NOTE_BAR = "Trackers: the game refused its own bar, so in fights the bar shows its last known fill, or is hidden, as In fights without the game's icon says."
local NOTE_ART = "Trackers: the game refused art on its own icon, so in fights proc art follows only the proc's other triggers."
-- The plate behind a bar or text, the blue of a bar when the tracker has no colour, the white image a bar is filled from, the font object
-- of the strings of a bar or text, and the inset of a string from the edge and the gap between two strings.
local PLATE = { 0.06, 0.06, 0.06, 1 }
local BLUE = { 0.302, 0.6, 0.902 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT_BAR, FONT_COUNT, FONT_TIME = "GameFontHighlightSmall", "NumberFontNormalSmall", "NumberFontNormal"
local PAD, GAP = 3, 4
-- What the container is told, in the order it is told. The last two are for the second slot.
local KINDS = { "enabled", "ids", "alpha", "enabled2", "ids2" }
local WHY = { off = "off in settings", never = "not needed, the game never hides this buff" }
local DIGITS = { coloured = "coloured digits", plain = "plain digits", above = "digits above 1 only" }
local TIMES = { text = "time as text", sweep = "time as the sweep's numbers", none = "no time" }

local IsSecret = ns.IsSecret

-- The extra parts other files add to the button, by kind of tracker: fn(rec, button, entry), run at the end of Init inside the function the
-- game calls while it builds the slot. It may return a handle { Pending() -> bool, Apply(), Shown(on) } for what changes later: Pending says
-- the parts differ from the settings, Apply puts them right (only while the game says buffs are open), and Shown is told when the game's own
-- icon starts or stops being used. Procs.lua registers the proc art.
ns.TrackerSlotParts = ns.TrackerSlotParts or {}

-- The record of each tracker frame: its container and button, what was applied to them, and what waits.
local records = setmetatable({}, { __mode = "k" })
-- A frame that a withheld answer is handed to, made out of combat, and what the last probe found.
local scratch, looked

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

-- A short form of an error text, without the file and line.
local function Brief(err)
	if type(err) == "string" then
		return (err:gsub("^[^:]*:%d+: ", ""):sub(1, 80))
	end
	return "an error"
end

-- The note for an error that stopped a call of this file, with the text of the error.
local function Failure(err)
	local text = Brief(err)
	return NOTE_ERROR .. (text:find("%.$") and text or (text .. "."))
end

-- True when the game says buffs are open to addon code. Without the call, out of combat.
local function Open()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret
	if type(call) == "function" then
		local ok, answer = pcall(call)
		return ok and not IsSecret(answer) and answer == false
	end
	return not InCombatLockdown()
end

local function Value(entry, key)
	return ns.TrackerValue(entry, key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Art(spellID)
	local call = type(C_Spell) == "table" and C_Spell.GetSpellTexture
	local ok, file = pcall(call, spellID)
	if ok and (Plain(file, "number") or Plain(file, "string")) then
		return file
	end
	return UNKNOWN_ICON
end

-- Why a tracker has no icon of the game's: "off" (the setting), "none" (no spell ID to match) or "never" (the game
-- never hides any of its IDs). Nil when it has one.
local function Why(entry)
	if Opt("gameIcon") == false then
		return "off"
	elseif #entry.spells == 0 then
		return "none"
	end
	local call = type(C_Secrets) == "table" and C_Secrets.GetSpellAuraSecrecy
	local never = type(Enum) == "table" and type(Enum.SecrecyLevel) == "table" and Enum.SecrecyLevel.NeverSecret
	if type(call) ~= "function" or never == nil or never == false then
		return nil
	end
	for _, id in ipairs(entry.spells) do
		local ok, level = pcall(call, id)
		if not ok or IsSecret(level) or level ~= never then
			return nil
		end
	end
	return "never"
end

local function Wanted(entry)
	return Why(entry) == nil
end

-- The unit the container looks at and the filter of its slots, from the kind of the entry. A frame keeps its container for good, so the pool of the
-- frame (Trackers.lua) is the unit and the filter, and a container is never given another unit.
local function Spec(entry)
	return ns.TrackerSlotSpec(entry) or { unit = "player", filter = "HELPFUL" }
end

local function IdKey(entry)
	return table.concat(entry.spells, ",")
end

-- The unit and the aura filter of the slot of an entry: a buff on the player, or what the entry's kind names.
local function Spec(entry)
	local spec = type(ns.TrackerSlotSpec) == "function" and ns.TrackerSlotSpec(entry)
	if type(spec) == "table" and type(spec.unit) == "string" and type(spec.filter) == "string" then
		return spec
	end
	return { unit = "player", filter = "HELPFUL" }
end

local function IdSet(entry)
	local set = {}
	for _, id in ipairs(entry.spells) do
		set[id] = true
	end
	return set
end

-- True when the game's own icon can show the charges of the tracker. Its digit and its cover follow the stacks field
-- of the buff alone (Blizzard_CustomAuraButton.lua, ApplyApplicationBar and ApplyApplicationCount), so a buff
-- that gives its count in the charges field would show a red 0 there.
local function Charged(entry)
	return entry.charged == true and entry.chargesField ~= true
end

-- The shape of a tracker: bar, text or icon.
local function ShapeOf(entry)
	local shape = Value(entry, "shape")
	return (shape == "bar" or shape == "text") and shape or "icon"
end

-- How a bar is filled: by the charges for a charged tracker set to Bar fill Charges, else by the time left.
local function FillOf(entry, shape)
	return (shape == "bar" and Charged(entry) and Value(entry, "barFill") == "charges") and "charges" or "time"
end

-- The most charges the bar of a tracker stands for.
local function Top(entry)
	return math.max(Plain(entry.top, "number") and entry.top or 3, 1)
end

local function Number(key, default)
	local value = Opt(key)
	return Plain(value, "number") and value or default
end

-- What the parts of the button should be now. A tracker that is not charged has no Low at (charges).
local function Want(rec)
	local entry = rec.entry
	local charged = Charged(entry)
	local low = charged and Value(entry, "low") or 0
	if rec.override and charged then
		low = rec.override
	end
	local shape = ShapeOf(entry)
	local label = type(ns.TrackerLabel) == "function" and Opt("names") and ns.TrackerLabel(entry) or nil
	local hex = Value(entry, "colour")
	return { charged = charged, counts = Value(entry, "counts") and true or false, low = low, lowTime = Value(entry, "lowTime"), numbers = Value(entry, "numbers") and true or false,
		art = entry.seen or entry.spells[1], thick = ns.Pixels(rec.frame, RIM), shape = shape, fill = FillOf(entry, shape), top = Top(entry),
		height = Number("barHeight", 14), width = Number("barWidth", 140), name = Plain(label, "string") and label or "",
		hex = Plain(hex, "string") and hex or "" }
end

-- Which parts differ from what was applied, and what they should be. shape: the wrappers and the strings, fill: what the bars show.
local function Dirty(rec)
	local want, was = Want(rec), rec.applied
	return { count = want.charged ~= was.charged or want.counts ~= was.counts or want.low ~= was.low, time = want.lowTime ~= was.lowTime or want.numbers ~= was.numbers,
		art = want.art ~= was.art, rim = want.thick ~= was.thick,
		shape = want.shape ~= was.shape or want.height ~= was.height or want.width ~= was.width or want.name ~= was.name or want.hex ~= was.hex,
		fill = want.fill ~= was.fill or want.top ~= was.top or want.shape ~= was.shape or want.hex ~= was.hex }, want
end

-- The parts of the button -----------------------------------------------------------------------------

-- A child of the button that fills it, `above` levels over it.
local function Layer(kind, button, template, above)
	local frame = Own(CreateFrame(kind, nil, button, template))
	frame:SetAllPoints()
	frame:SetFrameLevel(button:GetFrameLevel() + above)
	return frame
end

-- The four edges of the rim, just inside the button.
local function PlaceRim(rec, thick)
	local button, rim = rec.parts.iconW or rec.button, rec.parts.rim
	rim[1]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	rim[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
	rim[1]:SetHeight(thick)
	rim[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	rim[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	rim[2]:SetHeight(thick)
	rim[3]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -thick)
	rim[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, thick)
	rim[3]:SetWidth(thick)
	rim[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, -thick)
	rim[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, thick)
	rim[4]:SetWidth(thick)
end

-- What shows under the cover once a count is at or under Low at: a black square, a still of the spell and the red rim.
local function Look(rec, button, entry)
	local parts = rec.parts
	local back = Own(button:CreateTexture(nil, "BACKGROUND", nil, 0))
	back:SetAllPoints()
	back:SetColorTexture(0, 0, 0, 1)
	local still = Own(button:CreateTexture(nil, "ARTWORK", nil, 0))
	still:SetAllPoints()
	still:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	still:SetTexture(Art(entry.seen or entry.spells[1]))
	parts.still = still
	local rim = {}
	for index = 1, 4 do
		local edge = Own(button:CreateTexture(nil, "OVERLAY", nil, 0))
		if edge.SetSnapToPixelGrid then
			pcall(edge.SetSnapToPixelGrid, edge, false)
		end
		edge:SetColorTexture(RED[1], RED[2], RED[3], 1)
		rim[index] = edge
	end
	parts.rim = rim
	PlaceRim(rec, ns.Pixels(rec.frame, RIM))
end

-- A formatter for the count: red up to Low at, plain from Low at + 1. Nil when the game refuses a breakpoint.
local function Digits(low, colour)
	local call = type(C_StringUtil) == "table" and C_StringUtil.CreateNumericRuleFormatter
	local ok, formatter = pcall(call)
	if not ok or IsSecret(formatter) or formatter == nil then
		return nil
	end
	ok = pcall(formatter.AddBreakpoint, formatter, { threshold = 0, format = colour and LOW_FORMAT or PLAIN_FORMAT })
	if ok and low > 0 then
		ok = pcall(formatter.AddBreakpoint, formatter, { threshold = low + 1, format = PLAIN_FORMAT })
	end
	return ok and formatter or nil
end

-- The count: the game writes the formatter's text for the charges of the buff. A buff that is not charged gets the
-- game's own text, a number above 1 only.
local function Count(rec, entry, low)
	local button, font = rec.button, rec.parts.count
	if not font then
		return false
	end
	if not Value(entry, "counts") then
		-- Charges off: the game writes no digit, whatever the shape.
		pcall(button.ClearApplicationCount, button)
		pcall(font.SetText, font, "")
		rec.parts.countKind = nil
		return true
	end
	local options, kind
	if Charged(entry) then
		local formatter
		if low > 0 then
			formatter, kind = Digits(low, true), "coloured"
			if not formatter then
				formatter, kind = Digits(low, false), "plain"
			end
		else
			formatter, kind = Digits(0, false), "plain"
		end
		if formatter then
			options = { formatter = formatter }
		else
			kind = nil
		end
	end
	local ok = pcall(button.SetApplicationCount, button, font, options)
	if ok then
		rec.parts.countKind = kind or "above"
	end
	return ok
end

-- The cover, with the live icon on it: the game shows it only while the charges are over Low at, so the low look
-- under it shows at or under Low at.
local function Cover(rec, entry, low)
	local button, parts = rec.button, rec.parts
	local cover = parts.cover
	if not cover then
		return false
	end
	if Charged(entry) and low > 0 then
		local ok = pcall(button.SetApplicationBar, button, cover, { minApplications = low + 1, maxApplications = low + 2 })
		if ok then
			parts.coverOn = true
		end
		return ok
	end
	local cleared = pcall(button.ClearApplicationBar, button)
	local shown = pcall(cover.Show, cover)
	if cleared then
		parts.coverOn = false
	end
	return cleared and shown
end

-- The colour of the time left: red under `seconds`, white from there on. A step curve takes the value of the last
-- point at or under its input.
local function Colours(seconds)
	local ok, options = pcall(function()
		local curve = C_CurveUtil.CreateColorCurve()
		curve:SetType(Enum.LuaCurveType.Step)
		curve:AddPoint(0, CreateColor(RED[1], RED[2], RED[3], 1))
		curve:AddPoint(seconds, CreateColor(1, 1, 1, 1))
		return { textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration } }
	end)
	return ok and options or nil
end

-- The sweep draws numbers of its own when the game's time text is not there.
local function Numbers(parts, shown)
	if parts.sweep and parts.numbers ~= shown and pcall(parts.sweep.SetHideCountdownNumbers, parts.sweep, not shown) then
		parts.numbers = shown
	end
end

local function Time(rec, entry)
	local button, parts = rec.button, rec.parts
	local text = parts.time
	if not text then
		return false
	end
	parts.plainText = nil
	if Value(entry, "numbers") then
		local seconds = Value(entry, "lowTime")
		local options = seconds > 0 and Colours(seconds) or nil
		local ok = pcall(button.SetDurationText, button, text, options)
		-- The colour is the part a client may refuse in a fight: the time shows without it.
		if not ok and options ~= nil then
			ok = pcall(button.SetDurationText, button, text)
			parts.plainText = ok or nil
		end
		parts.timeKind = ok and "text" or "sweep"
		Numbers(parts, not ok)
		return ok
	end
	local ok = pcall(button.ClearDurationText, button)
	pcall(text.SetText, text, "")
	Numbers(parts, false)
	if ok then
		parts.timeKind = "none"
	end
	return ok
end

-- The wrappers, the strings and the bars -------------------------------------------------------------

-- The call, and whether every call so far went through.
local function Try(ok, fn, ...)
	return pcall(fn, ...) and ok
end

-- Red, green and blue of a tracker's colour: the 8 digits of its hex, else the blue of a bar.
local function Colour(hex)
	if #hex == 8 then
		local r, g, b = tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), tonumber(hex:sub(7, 8), 16)
		if r and g and b then
			return r / 255, g / 255, b / 255
		end
	end
	return BLUE[1], BLUE[2], BLUE[3]
end

-- The text of the strings is as high as the bar allows.
local function TextHeight(height)
	return math.max(7, math.min(14, height - 4))
end

-- The options of a bar filled by the time left. The enumerations are those of the documentation (SimpleStatusBarConstantsDocumentation.lua).
local function TimeOptions()
	local direction = type(Enum) == "table" and type(Enum.StatusBarTimerDirection) == "table" and Enum.StatusBarTimerDirection.RemainingTime
	local interpolation = type(Enum) == "table" and type(Enum.StatusBarInterpolation) == "table" and Enum.StatusBarInterpolation.Immediate
	return { interpolation = interpolation or 0, direction = direction or 1 }
end

-- Puts the body of a bar or text, the part that is not the icon's square, in a wrapper of the button.
local function Body(wrapper, button, square)
	wrapper:ClearAllPoints()
	wrapper:SetPoint("TOPLEFT", button, "TOPLEFT", square, 0)
	wrapper:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
end

-- The wrappers of the shape: the icon's has the cover, the sweep and the low look, a bar's the plate and the fill by time, a text's the plate.
-- The one that is not the shape has alpha 0. The strings are one count and one time that the game fills, and a name of the tracker's own, set
-- in the font and the places of the shape. Every call is on a part of the button, so this runs while the game says buffs are open, or while
-- the button is built.
local function Shape(rec, want, first)
	local parts, ok = rec.parts, true
	local shape, height, button = want.shape, want.height, rec.button
	local square = shape == "bar" and height or 0
	local icon, bar, plate, top = parts.iconW, parts.barW, parts.textW, parts.top
	if icon then
		ok = Try(ok, icon.SetAlpha, icon, shape == "text" and 0 or 1)
		ok = Try(ok, icon.ClearAllPoints, icon)
		if shape == "bar" then
			ok = Try(ok, icon.SetPoint, icon, "TOPLEFT", button, "TOPLEFT", 0, 0)
			ok = Try(ok, icon.SetPoint, icon, "BOTTOMRIGHT", button, "BOTTOMLEFT", height, 0)
		else
			ok = Try(ok, icon.SetAllPoints, icon, button)
		end
	end
	if bar then
		ok = Try(ok, bar.SetAlpha, bar, shape == "bar" and 1 or 0)
		ok = Try(ok, Body, bar, button, square)
	end
	if plate then
		ok = Try(ok, plate.SetAlpha, plate, shape == "text" and 1 or 0)
		ok = Try(ok, Body, plate, button, square)
	end
	local name, count, time = parts.name, parts.count, parts.time
	if not (top and name and count and time) then
		return ok
	end
	local r, g, b = 1, 1, 1
	if shape == "text" then
		r, g, b = Colour(want.hex)
	end
	if shape == "icon" then
		ok = Try(ok, count.SetFontObject, count, FONT_COUNT)
		ok = Try(ok, time.SetFontObject, time, FONT_TIME)
	else
		local size = TextHeight(height)
		for _, text in ipairs({ name, count, time }) do
			ok = Try(ok, text.SetFontObject, text, FONT_BAR)
			ok = Try(ok, text.SetTextHeight, text, size)
		end
	end
	-- The time string is registered with the game once built, and a registered string keeps the colour it had then.
	for _, text in ipairs({ name, count, time }) do
		if text ~= time or first then
			ok = Try(ok, text.SetTextColor, text, r, g, b, 1)
		end
		ok = Try(ok, text.ClearAllPoints, text)
	end
	ok = Try(ok, name.SetText, name, shape == "icon" and "" or want.name)
	ok = Try(ok, name.SetWidth, name, 0)
	if shape == "icon" then
		ok = Try(ok, count.SetPoint, count, "BOTTOMRIGHT", top, "BOTTOMRIGHT", -2, 2)
		ok = Try(ok, time.SetPoint, time, "CENTER", top, "CENTER", 0, 0)
	elseif shape == "bar" then
		-- The name stops before the strings on the right.
		local size = TextHeight(height)
		local room = want.width - PAD * 2 - GAP * 2 - size * 0.6 * 7
		ok = Try(ok, name.SetPoint, name, "LEFT", top, "LEFT", square + PAD, 0)
		ok = Try(ok, name.SetWidth, name, math.max(1, math.floor(room)))
		ok = Try(ok, time.SetPoint, time, "RIGHT", top, "RIGHT", -PAD, 0)
		ok = Try(ok, count.SetPoint, count, "RIGHT", time, "LEFT", -GAP, 0)
	else
		ok = Try(ok, name.SetPoint, name, "LEFT", top, "LEFT", PAD, 0)
		if want.name == "" then
			ok = Try(ok, count.SetPoint, count, "LEFT", top, "LEFT", PAD, 0)
		else
			ok = Try(ok, count.SetPoint, count, "LEFT", name, "RIGHT", GAP, 0)
		end
		ok = Try(ok, time.SetPoint, time, "LEFT", count, "RIGHT", GAP, 0)
	end
	return ok
end

-- The geometry and the look of the second slot's bar: the body of the bar, in the colour of the tracker, shown for a bar filled by charges.
local function Charges(rec, want)
	local second = rec.parts2
	if rec.bar2 == "refused" or not (second and second.wrap) then
		return true
	end
	local ok = Try(true, second.wrap.SetAlpha, second.wrap, (want.shape == "bar" and want.fill == "charges") and 1 or 0)
	ok = Try(ok, Body, second.wrap, second.button, want.shape == "bar" and want.height or 0)
	local r, g, b = Colour(want.hex)
	ok = Try(ok, second.bar.SetStatusBarColor, second.bar, r, g, b, 1)
	if second.top ~= want.top then
		local set = pcall(second.button.SetApplicationBar, second.button, second.bar, { minApplications = 0, maxApplications = want.top })
		second.top = set and want.top or second.top
		ok = ok and set
	end
	return ok
end

-- What the bars show: the bar of the time left in the colour of the tracker, and which of the two bars is on.
local function Bars(rec, want)
	local parts, ok = rec.parts, true
	if parts.timeBar then
		local r, g, b = Colour(want.hex)
		ok = Try(ok, parts.timeBar.SetStatusBarColor, parts.timeBar, r, g, b, 1)
		ok = Try(ok, parts.timeHost.SetAlpha, parts.timeHost, want.fill == "charges" and 0 or 1)
	end
	return Charges(rec, want) and ok
end

-- Run once by the game inside AddAuraSlot, before it closes the button. Nothing here may raise: a call that does is
-- kept in the record, and a failure without which the button is of no use is the error of the whole build.
local function Init(rec, button)
	local entry, parts = rec.entry, rec.parts
	local function Fail(err)
		rec.err = rec.err or Brief(err)
	end
	rec.button = button
	local ok, err = pcall(button.SetAllPoints, button)
	parts.sized = ok
	if not ok then
		Fail(err)
	end
	parts.hideOk = pcall(button.SetHideTooltipInCombat, button, true)
	parts.mouseOff = pcall(button.EnableMouse, button, false)
	parts.level = select(2, pcall(button.GetFrameLevel, button))
	-- The icon wrapper: the low look, and the cover with the icon the game fills.
	local made, iconW = pcall(Layer, "Frame", button, nil, 0)
	if made then
		parts.iconW = iconW
		pcall(Look, rec, iconW, entry)
	else
		Fail(iconW)
	end
	local cover
	made, cover = pcall(Layer, "StatusBar", iconW, nil, 1)
	if made then
		parts.cover = cover
		local fine, live = pcall(function()
			local texture = Own(cover:CreateTexture(nil, "ARTWORK", nil, 0))
			texture:SetAllPoints()
			texture:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
			return texture
		end)
		if fine then
			ok, err = pcall(button.SetIcon, button, live)
			parts.iconOk = ok
			if not ok then
				Fail(err)
			end
		else
			Fail(live)
		end
	else
		Fail(cover)
	end
	-- The sweep.
	local sweep
	made, sweep = pcall(function()
		local frame = Layer("Cooldown", iconW, "CooldownFrameTemplate", 2)
		frame:SetDrawEdge(false)
		frame:SetDrawBling(false)
		frame:SetSwipeColor(0, 0, 0, 0.7)
		frame:SetHideCountdownNumbers(true)
		return frame
	end)
	if made then
		parts.sweep, parts.numbers = sweep, false
		parts.sweepOk = pcall(button.SetDurationCooldown, button, sweep)
	end
	-- The bar: a plate and a status bar the game fills by the time left. A refusal leaves the tracker without a bar of the game's.
	local want = Want(rec)
	made, err = pcall(function()
		local wrapper = Layer("Frame", button, nil, 0)
		local back = Own(wrapper:CreateTexture(nil, "BACKGROUND", nil, -7))
		back:SetAllPoints()
		back:SetColorTexture(PLATE[1], PLATE[2], PLATE[3], PLATE[4])
		local host = Layer("Frame", wrapper, nil, 1)
		local bar = Layer("StatusBar", host, nil, 0)
		local set, done = pcall(bar.SetStatusBarTexture, bar, ns.BarTexture() or WHITE)
		if not set or (not IsSecret(done) and done == false) then
			error("the bar texture was refused", 0)
		end
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		parts.barW, parts.timeHost, parts.timeBar = wrapper, host, bar
		parts.barOk = pcall(button.SetDurationBar, button, bar, TimeOptions())
	end)
	if not made then
		rec.barErr = Brief(err)
	end
	made, err = pcall(function()
		local wrapper = Layer("Frame", button, nil, 0)
		local back = Own(wrapper:CreateTexture(nil, "BACKGROUND", nil, -7))
		back:SetAllPoints()
		back:SetColorTexture(PLATE[1], PLATE[2], PLATE[3], PLATE[4])
		parts.textW = wrapper
	end)
	-- The count and the time left, and the name of the tracker, on a frame above the sweep and the bars.
	local top, count, left
	made, top, count, left = pcall(function()
		local frame = Layer("Frame", button, nil, 3)
		local number = Own(frame:CreateFontString(nil, "OVERLAY", FONT_COUNT))
		local seconds = Own(frame:CreateFontString(nil, "OVERLAY", FONT_TIME))
		local word = Own(frame:CreateFontString(nil, "OVERLAY", FONT_BAR))
		word:SetJustifyH("LEFT")
		word:SetWordWrap(false)
		parts.name = word
		return frame, number, seconds
	end)
	if made then
		parts.top, parts.count, parts.time = top, count, left
	end
	pcall(Shape, rec, want, true)
	pcall(Bars, rec, want)
	Count(rec, entry, want.low)
	Cover(rec, entry, want.low)
	Time(rec, entry)
	rec.applied = want
	-- The parts other files make on the button, inside this call, because from here on the game closes the button.
	local extra = ns.TrackerSlotParts[entry.kind]
	if type(extra) == "function" then
		local fine, made = pcall(extra, rec, button, entry)
		rec.partsOk = fine
		if fine then
			rec.partsHandle = type(made) == "table" and made or nil
		else
			rec.partsErr = Brief(made)
		end
	end
end

-- The container and its slot --------------------------------------------------------------------------

local CALLS = {
	enabled = function(rec, on)
		rec.container:SetAuraSlotEnabled(rec.slotKey, on)
	end,
	ids = function(rec)
		rec.container:SetAuraSlotCandidateFilters(rec.slotKey, { includeSpellIDs = rec.goal.set })
	end,
	alpha = function(rec, alpha)
		rec.container:SetAlpha(alpha)
	end,
	enabled2 = function(rec, on)
		rec.container:SetAuraSlotEnabled(rec.slotKey2, on)
	end,
	ids2 = function(rec)
		rec.container:SetAuraSlotCandidateFilters(rec.slotKey2, { includeSpellIDs = rec.goal.set })
	end,
}

-- Tells the container what differs from what it was told last. A call that raises is held for the next Flush; at
-- the Flush (final) it is dropped with a note, and the container is taken to have what was asked for.
local function Send(rec, final)
	local goal, now, held = rec.goal, rec.now, rec.held
	for _, kind in ipairs(KINDS) do
		local want = goal[kind]
		if (kind == "enabled2" or kind == "ids2") and rec.bar2 ~= "made" then
			held[kind] = nil
		elseif want == now[kind] then
			held[kind] = nil
		elseif final or not held[kind] then
			local ok = pcall(CALLS[kind], rec, want)
			if ok or final then
				now[kind], held[kind] = want, nil
			else
				held[kind] = true
			end
			if final and not ok then
				ns.Note(KEY, NOTE_LATE)
			end
		end
	end
end

-- True when the game's bar is of no use: its parts were not made or the game refused its timer.
local function BarRefused(rec)
	return rec.parts.timeBar == nil or rec.parts.barOk ~= true
end

-- One note, when a tracker set to Bar has no bar of the game's.
local function BarNote(rec, want)
	if want.shape == "bar" and BarRefused(rec) and not rec.barNoted then
		rec.barNoted = true
		ns.Note(KEY, NOTE_BAR)
	end
end

-- Registers again what differs on the button. Only while the game says buffs are open.
local function Apply(rec)
	local dirty, want = Dirty(rec)
	local entry, parts, ok = rec.entry, rec.parts, true
	if dirty.count then
		ok = Count(rec, entry, want.low) and ok
		ok = Cover(rec, entry, want.low) and ok
	end
	if dirty.time then
		ok = Time(rec, entry) and ok
	end
	if dirty.art and parts.still then
		ok = pcall(parts.still.SetTexture, parts.still, Art(want.art)) and ok
	end
	if dirty.rim and parts.rim then
		ok = pcall(PlaceRim, rec, want.thick) and ok
	end
	local was = rec.applied
	local shaped, filled = true, true
	if dirty.shape then
		local called, done = pcall(Shape, rec, want)
		shaped = called and done and true or false
	end
	if dirty.fill then
		local called, done = pcall(Bars, rec, want)
		filled = called and done and true or false
	end
	ok = shaped and filled and ok
	-- A change the game refused stays asked for: the record keeps what the button has, and the next Flush sends it again.
	if not shaped then
		want.shape, want.height, want.width, want.name, want.hex = was.shape, was.height, was.width, was.name, was.hex
	end
	if not filled then
		want.fill, want.top = was.fill, was.top
	end
	rec.applied = want
	if not ok then
		ns.Note(KEY, NOTE_LATE)
	end
	BarNote(rec, want)
	return ok
end

-- Puts the extra parts of the button right when they differ from the settings. Only while the game says buffs are open.
local function PartsApply(rec)
	local handle = rec.partsHandle
	if not (rec.partsOk and handle) then
		return
	end
	local fine, pending = pcall(handle.Pending)
	if fine and pending then
		if not pcall(handle.Apply) then
			ns.Note(KEY, NOTE_LATE)
		end
	end
end

-- True when the game's own icon of the tracker is on show, with the extra parts made on it.
local function InUse(rec)
	return rec ~= nil and rec.partsOk == true and rec.state == "built" and rec.now ~= nil and rec.now.alpha == 1
end

local function Build(rec, key)
	local entry, frame = rec.entry, rec.frame
	if not rec.container then
		rec.container = Own(CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate"))
	end
	local container = rec.container
	if not rec.configured then
		container:SetAllPoints(frame)
		container:SetFrameLevel(frame:GetFrameLevel() + ABOVE)
		container:SetAlpha(0)
		container:SetEditModePreviewEnabled(false)
		container:SetUnit(Spec(entry).unit)
		rec.configured = true
	end
	rec.slotKey = key
	rec.button = container:AddAuraSlot(key, Spec(entry).filter, { candidateFilters = { includeSpellIDs = IdSet(entry) },
		initializeFrame = function(button)
			local ok, err = pcall(Init, rec, button)
			if not ok then
				rec.err = rec.err or Brief(err)
			end
		end })
	rec.slotMade = true
end

-- Makes the slot. A refusal while the game hides buffs is tried once more at the next Flush; a refusal while buffs
-- are open, or the second one, is final.
local function Make(rec, attempt)
	local open = Open()
	rec.parts, rec.err, rec.slotMade, rec.button = {}, nil, nil, nil
	rec.partsOk, rec.partsErr, rec.partsHandle = nil, nil, nil
	local ok, err = pcall(Build, rec, (attempt > 1 and rec.container) and SLOT_AGAIN or SLOT)
	if ok and rec.parts.iconOk and rec.parts.sized then
		local key = IdKey(rec.entry)
		rec.state, rec.err, rec.held = "built", nil, {}
		rec.now = { enabled = true, ids = key, alpha = 0 }
		rec.goal = { enabled = true, ids = key, set = IdSet(rec.entry), alpha = 0 }
		rec.bar2, rec.parts2 = nil, nil
		BarNote(rec, rec.applied)
		if rec.partsOk == false and not rec.artNoted then
			rec.artNoted = true
			ns.Note(KEY, NOTE_ART)
		end
		return
	end
	if not ok then
		rec.err = Brief(err)
	end
	rec.err = rec.err or "no icon"
	if rec.slotMade then
		pcall(rec.container.SetAuraSlotEnabled, rec.container, rec.slotKey, false)
	end
	if attempt == 1 and not open then
		rec.state = "waiting"
	else
		rec.state = "refused"
		ns.Note(KEY, NOTE_REFUSED)
	end
end

-- Run once by the game inside AddAuraSlot for the second slot: a button that holds the bar filled by the charges. The bar is a descendant
-- of the button, in a wrapper placed over the body of the bar.
local function Init2(rec, button)
	local second, want = rec.parts2, Want(rec)
	second.button = button
	second.ok = pcall(button.SetAllPoints, button)
	pcall(button.SetHideTooltipInCombat, button, true)
	pcall(button.EnableMouse, button, false)
	if Plain(rec.parts.level, "number") then
		pcall(button.SetFrameLevel, button, rec.parts.level + 1)
	end
	local made, wrapper, bar = pcall(function()
		local frame = Layer("Frame", button, nil, 0)
		local fill = Layer("StatusBar", frame, nil, 0)
		local set, done = pcall(fill.SetStatusBarTexture, fill, ns.BarTexture() or WHITE)
		if not set or (not IsSecret(done) and done == false) then
			error("the bar texture was refused", 0)
		end
		return frame, fill
	end)
	if made then
		second.wrap, second.bar = wrapper, bar
		second.applied = pcall(button.SetApplicationBar, button, bar, { minApplications = 0, maxApplications = want.top })
		second.top = want.top
		pcall(Charges, rec, want)
	end
end

-- True when the tracker is a bar filled by the charges, so it needs the second slot.
local function Needs(rec)
	local shape = ShapeOf(rec.entry)
	return FillOf(rec.entry, shape) == "charges"
end

-- Makes the second slot, once, while the game says buffs are open. A refusal is final and a note.
local function Make2(rec)
	local key = SLOT_BAR
	rec.slotKey2 = key
	rec.parts2, rec.err2 = {}, nil
	local ok, err = pcall(function()
		rec.container:AddAuraSlot(key, Spec(rec.entry).filter, { candidateFilters = { includeSpellIDs = IdSet(rec.entry) },
			initializeFrame = function(button)
				local fine, why = pcall(Init2, rec, button)
				if not fine then
					rec.err2 = rec.err2 or Brief(why)
				end
			end })
		rec.slot2Made = true
	end)
	if ok and rec.parts2.ok and rec.parts2.applied and rec.parts2.wrap then
		local ids = IdKey(rec.entry)
		rec.bar2 = "made"
		rec.now.enabled2, rec.now.ids2 = true, ids
		rec.goal.enabled2, rec.goal.ids2 = true, ids
		return
	end
	rec.err2 = rec.err2 or (not ok and Brief(err)) or "no bar"
	if rec.slot2Made then
		pcall(rec.container.SetAuraSlotEnabled, rec.container, key, false)
	end
	rec.bar2 = "refused"
	ns.Note(KEY, NOTE_BAR)
end

-- A frame for the probe, made out of combat with the first frame that gets a container.
local function MakeScratch(frame)
	local holder = Own(CreateFrame("Frame", nil, frame))
	holder:SetSize(1, 1)
	holder:SetPoint("CENTER", frame, "CENTER", 0, 0)
	scratch = holder
end

local function RecOf(entry)
	local frame = ns.TrackerFrame(entry)
	return frame and records[frame] or nil
end

local function Off(rec)
	if rec.state == "built" then
		rec.goal.enabled, rec.goal.alpha, rec.goal.enabled2 = false, 0, false
		Send(rec, false)
	end
end

local function Update(rec)
	local goal = rec.goal
	goal.enabled, goal.ids, goal.set = true, IdKey(rec.entry), IdSet(rec.entry)
	goal.enabled2, goal.ids2 = Needs(rec), goal.ids
	Send(rec, false)
end

local function One(frame, entry)
	local rec = records[frame]
	if not Wanted(entry) then
		if rec then
			rec.entry = entry
			Off(rec)
		end
		return
	end
	local spec = Spec(entry)
	local pool = spec.unit .. "|" .. spec.filter
	if rec and rec.pool ~= pool then
		-- The container of the frame looks at another unit than this entry needs: it is left off.
		Off(rec)
		return
	end
	if not rec then
		rec = { frame = frame, entry = entry, parts = {}, held = {}, pool = pool }
		records[frame] = rec
		if not scratch then
			pcall(MakeScratch, frame)
		end
		Make(rec, 1)
		return
	end
	rec.entry = entry
	if rec.state == "built" then
		Update(rec)
	end
end

-- What Trackers.lua calls -----------------------------------------------------------------------------

-- A new target: the containers that look at the target are told to look again. A refusal, in a fight, is a note and nothing else.
local function Retarget()
	for _, rec in pairs(records) do
		if rec.state == "built" and rec.pool:find("^target|") then
			if not pcall(rec.container.UpdateAllAuras, rec.container) then
				ns.Note(KEY, NOTE_TARGET)
			end
		end
	end
end

-- Runs what waits, when the game says buffs are open: the second try of a build, the calls the container refused, and
-- the parts of the button that changed.
local function Flush()
	if not Open() then
		return
	end
	for _, rec in pairs(records) do
		local ok, err = pcall(function()
			if rec.state == "waiting" and Wanted(rec.entry) then
				Make(rec, 2)
			end
			if rec.state == "built" then
				if rec.bar2 == nil and Wanted(rec.entry) and Needs(rec) then
					Make2(rec)
				end
				Send(rec, true)
				Apply(rec)
				PartsApply(rec)
			end
		end)
		if not ok then
			ns.Note(KEY, Failure(err))
		end
	end
end

-- The trackers that are on: a slot for each that needs one, and the slot of a frame that has none now switched off.
local function Sync(entries)
	local current = {}
	for _, entry in ipairs(entries) do
		local frame = ns.TrackerFrame(entry)
		if frame then
			current[frame] = true
			local ok, err = pcall(One, frame, entry)
			if not ok then
				ns.Note(KEY, Failure(err))
			end
		end
	end
	for frame, rec in pairs(records) do
		if not current[frame] then
			local ok, err = pcall(Off, rec)
			if not ok then
				ns.Note(KEY, Failure(err))
			end
		end
	end
	Flush()
end

-- True when what the game draws is what the tracker is set to: the shape and the fill the wrappers were last given, and for a bar the parts
-- and the timer the game took, and for a bar filled by charges the second slot.
local function Fits(rec)
	local entry, was = rec.entry, rec.applied
	local shape = ShapeOf(entry)
	if was.shape ~= shape or was.fill ~= FillOf(entry, shape) then
		return false
	elseif shape == "bar" then
		if was.height ~= Number("barHeight", 14) then
			return false
		end
		return not BarRefused(rec) and (was.fill ~= "charges" or (rec.bar2 == "made" and rec.now.enabled2 == true))
	end
	return true
end

-- A tracker set to Only when low or missing is fine in a fight while the game's own icon is visible (the cover when the tracker has charges,
-- since the cover shows only above Low at, else the icon's wrapper). The answer is withheld, so it goes unread to the frame of the tracker:
-- alpha 0 while fine, 1 while low or missing. Only while the container is drawn and the probe found that the game takes such an answer.
-- A tracker with Low at (seconds left) stays shown, since the game's icon does not follow the time left. Without that the tracker stays shown, and one note says so. Back at the alpha the tracker's own drawing has: given by the caller.
local function Hide(rec, entry, alpha)
	local want = Value(entry, "show") == "low" and rec.now.alpha == 1 and rec.goal.alpha == 1 and Plain(alpha, "number") and alpha == 1
		and Value(entry, "lowTime") == 0
	if want and looked and looked.hide == "refused" and not rec.noted then
		rec.noted = true
		ns.Note(KEY, NOTE_HIDE)
	end
	local answer = false
	if want and looked and looked.hide == "accepted" then
		local part = Charged(entry) and rec.parts.cover or rec.parts.iconW
		local ok, fine
		if part then
			ok, fine = pcall(part.IsVisible, part)
		end
		if ok and IsSecret(fine) then
			answer = pcall(rec.frame.SetAlphaFromBoolean, rec.frame, fine, 0, 1)
		end
	end
	if answer then
		rec.hid = true
	elseif rec.hid then
		rec.hid = false
		pcall(rec.frame.SetAlpha, rec.frame, Plain(alpha, "number") and alpha or 1)
	end
end

-- The container is shown with its alpha: it works only while it is visible, so it is never hidden. alpha is the alpha the tracker's frame has
-- when the game's own icon is not hiding it.
local function Show(entry, shown, alpha)
	local rec = RecOf(entry)
	if rec and rec.state == "built" then
		local was = InUse(rec)
		rec.goal.alpha = (shown and Fits(rec)) and 1 or 0
		Send(rec, false)
		Hide(rec, entry, alpha)
		local now = InUse(rec)
		if now ~= was and rec.partsHandle and type(rec.partsHandle.Shown) == "function" then
			pcall(rec.partsHandle.Shown, now)
		end
	end
end

-- True when the game's own icon of the tracker is on show and the art made on it is in place.
local function Used(entry)
	return InUse(RecOf(entry))
end

local function Live(entry)
	local rec = RecOf(entry)
	return rec ~= nil and rec.state == "built" and rec.now.enabled == true and Wanted(entry) and Fits(rec)
end

-- The low look of a count: with a number, a charged tracker is low up to that count. With nil the real values again.
-- Only while buffs are open.
local function LowTest(entry, count)
	local rec = RecOf(entry)
	if not rec or rec.state ~= "built" then
		return false
	end
	if count == nil then
		rec.override = nil
		if not Open() then
			return false
		end
	else
		if not Open() or not Plain(count, "number") then
			return false
		end
		rec.override = count
	end
	Apply(rec)
	return true
end

-- The check -------------------------------------------------------------------------------------------

local function Level(object)
	local ok, level = pcall(object.GetFrameLevel, object)
	return ok and Plain(level, "number") and level or nil
end

-- The level of the container, and the highest level of the tracker's frame and of its children.
local function Levels(rec)
	local frame, container = rec.frame, rec.container
	local highest = Level(frame)
	local ok, children = pcall(function()
		return { frame:GetChildren() }
	end)
	for _, child in ipairs(ok and children or {}) do
		local level = child ~= container and Level(child) or nil
		if level and (not highest or level > highest) then
			highest = level
		end
	end
	return Level(container), highest
end

local function Waiting(rec)
	local waiting = 0
	for _, yes in pairs(rec.held) do
		waiting = waiting + (yes and 1 or 0)
	end
	for _, yes in pairs((Dirty(rec))) do
		waiting = waiting + (yes and 1 or 0)
	end
	return waiting
end

local CHARGES = { made = "made", refused = "refused" }

local function Parts(rec)
	local parts = rec.parts
	local list = { parts.countKind and ("charges as " .. DIGITS[parts.countKind]) or "no charges",
		parts.plainText and "time as text without the red colour" or TIMES[parts.timeKind or "none"],
		"low border " .. (parts.coverOn and "yes" or "no") }
	if not parts.sweepOk then
		list[#list + 1] = "no sweep"
	end
	if parts.mouseOff then
		list[#list + 1] = "tooltip off"
	elseif parts.hideOk then
		list[#list + 1] = "tooltip shown out of combat"
	else
		list[#list + 1] = "tooltip shown"
	end
	if rec.applied.shape == "bar" then
		list[#list + 1] = "bar " .. (parts.timeBar and "made" or "refused")
		list[#list + 1] = "charges bar " .. (rec.bar2 and CHARGES[rec.bar2] or (Needs(rec) and "waits for the game" or "not needed"))
	end
	return table.concat(list, ", ")
end

-- The line about the art made on the button, for a kind of tracker that has some, or nil.
local function ArtLine(rec, entry)
	if type(ns.TrackerSlotParts[entry.kind]) ~= "function" then
		return nil
	elseif entry.kind == "proc" and ns.ProcArtOn and not ns.ProcArtOn() then
		return "Art in fights: off, Art beside the character is off."
	elseif rec.state == "waiting" then
		return "Art in fights: waits for the game's own icon."
	elseif rec.state == "built" and rec.partsOk == nil then
		return "Art in fights: not made."
	elseif rec.state ~= "built" or not rec.partsOk then
		return "Art in fights: refused by the game."
	end
	local fine, pending = false, false
	if rec.partsHandle then
		fine, pending = pcall(rec.partsHandle.Pending)
	end
	if fine and pending then
		return "Art in fights: a change waits for the end of the fight."
	end
	return "Art in fights: ready."
end

local function Lines(entry)
	local why = Why(entry)
	if why == "none" then
		return {}
	elseif why then
		return { "Game's own icon: " .. WHY[why] .. "." }
	end
	local rec = RecOf(entry)
	if not rec then
		return {}
	elseif rec.state == "waiting" then
		return { "Game's own icon: waits until the game shows buffs again.", ArtLine(rec, entry) }
	elseif rec.state == "refused" then
		return { "Game's own icon: not made. " .. (rec.err:find("%.$") and rec.err or (rec.err .. ".")), ArtLine(rec, entry) }
	end
	local lines = { "Game's own icon: ready.", "Its parts: " .. Parts(rec) .. "." }
	if rec.applied.shape == "bar" then
		lines[#lines + 1] = "Timer on a bar: " .. (rec.parts.barOk and "accepted." or "refused.")
	end
	if entry.chargesField then
		lines[#lines + 1] = "The buff gives its charges in the charges field, so the game's own icon shows no digit and no low rim."
		if rec.applied.shape == "bar" and Value(entry, "barFill") == "charges" then
			lines[#lines + 1] = "So in a fight the game's bar fills by the time left, not the charges."
		end
	end
	local mine, highest = Levels(rec)
	if mine and highest then
		lines[#lines + 1] = mine > highest and ("Drawn above the tracker: yes (level %d over %d)."):format(mine, highest)
			or ("Drawn above the tracker: no (level %d under %d)."):format(mine, highest)
	end
	local waiting = Waiting(rec)
	if waiting > 0 then
		lines[#lines + 1] = ("Changes waiting until the game shows buffs again: %d."):format(waiting)
	end
	lines[#lines + 1] = ArtLine(rec, entry)
	return lines
end

-- Asks the first slot that was built whether two of its parts are visible, during a fight. A plain answer is dropped
-- unread. A withheld one is handed to a frame of this file to see whether the game takes it.
local function Probe()
	local rec
	for _, found in pairs(records) do
		if found.state == "built" and found.parts.top and found.parts.cover then
			rec = found
			break
		end
	end
	if not rec then
		return
	end
	local top, cover = rec.parts.top, rec.parts.cover
	local topOk, topAnswer = pcall(top.IsVisible, top)
	local coverOk, coverAnswer = pcall(cover.IsVisible, cover)
	local pass
	if topOk and IsSecret(topAnswer) then
		pass = topAnswer
	elseif coverOk and IsSecret(coverAnswer) then
		pass = coverAnswer
	end
	local hidden = (topOk and IsSecret(topAnswer)) or (coverOk and IsSecret(coverAnswer))
	looked = { answer = (not topOk or not coverOk) and "refused" or (hidden and "hidden" or "open") }
	if hidden then
		looked.hide = scratch ~= nil and pcall(scratch.SetAlphaFromBoolean, scratch, pass, 1, 0) and "accepted" or "refused"
	end
end

local function FightLines()
	local word = "not asked"
	if looked and looked.answer == "hidden" then
		word = "answer hidden, hiding by it " .. looked.hide
	elseif looked then
		word = looked.answer == "open" and "answer open, not used" or "answer refused"
	end
	return { "Parts of the game's own icon: " .. word .. "." }
end

-- No error leaves this file: one that does is a note with its text.
local function Safe(fn)
	return function(...)
		local ok, result = pcall(fn, ...)
		if ok then
			return result
		end
		ns.Note(KEY, Failure(result))
		return nil
	end
end

ns.TrackerSlots = { Sync = Safe(Sync), Show = Safe(Show), Live = Safe(Live), InUse = Safe(Used), Flush = Safe(Flush), Lines = Safe(Lines), FightLines = Safe(FightLines),
	Probe = Safe(Probe), LowTest = Safe(LowTest), Retarget = Safe(Retarget) }
