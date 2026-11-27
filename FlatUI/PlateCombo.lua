local _, ns = ...

-- Combo points under your target's nameplate, a part of Nameplates.lua (ns.PlateExtra), for a rogue or a druid (UnitClassBase of the player, plain).
-- This client draws combo points only round the target frame's portrait (Camelot/ComboFrame.lua:13-16, 98-130): the game's own bars of combo points on
-- nameplates are not loaded on it (Blizzard_NamePlates.toc:35-38, ExcludeLoadGameType camelot). With Combo points on your target's nameplate (on by
-- default, on the Marks and icons tab of Nameplates) a row of small squares, one for each point you can have (UnitPowerMax of the combo points, as
-- ComboFrame.lua:67-69 reads it, at most MAX), stands centred just under the cast bar of your target's plate (the plate ns.PlateUnitFrame gives for
-- "target", compared as a frame, so no unit comparison the client can withhold is needed). The count is the game's own: GetComboPoints("player",
-- "target"), the call ComboFrame.lua:98 makes, which the client may withhold (SecretWhenUnitPowerRestricted, UnitDocumentation.lua:91-105). A
-- withheld count, an answer that is no plain number and 0 hide the row, as the game hides its own at 0 (ComboFrame.lua:121-130); a druid out of Cat
-- Form reads 0. A lit square is in Combo point colour and the rest of the row is in it at DIM, each in Flat UI's thin border (ns.Outline). With Full
-- points stand out (on by default), at your most points every square takes Full points colour (gold at first), so a finisher reads at a glance,
-- and spending them brings Combo point colour back. As the count goes up the newest square pops (a Scale animation of the square's own texture
-- from POP_FROM back to whole over POP_SECONDS, from its middle, not protected, so it plays in a fight), and every lit square pops together as the
-- last point lands while Full points stand out is on. The row fades in over FADE_IN seconds as the first point lands (the game fades its own row in,
-- ComboFrame.lua's COMBOFRAME_FADE_IN) and out over FADE_OUT as the points are spent, Alpha animations of the row's own frame, not protected; a
-- change of target draws the new plate's row at once without a pop or a fade, as ComboFrame.lua's suppressTransitions does, and hides the old one
-- at once, as a plate that leaves and the part going off do.
-- Combo point size (SIZE by default) sizes each square, the units between two keeping SPACE's share of SIZE, and Combo points vertical offset moves
-- the row up or down. While a class icon shows at Below on the plate (Nameplates.lua's own record of the plate, which the show and layout hooks
-- pass, and ns.PlateComboPlace as the icon comes or goes a frame after the plate shows), the row hangs just under the icon instead of lying on it,
-- and moves back under the cast bar on other plates.
-- Events: UNIT_POWER_FREQUENT, UNIT_POWER_UPDATE and UNIT_MAXPOWER of the player (RegisterUnitEvent) and PLAYER_TARGET_CHANGED, as ComboFrame.lua
-- hears them (24-31), and UPDATE_SHAPESHIFT_FORM for a druid's form, on a frame of the file's own while the row is on; the show hook of
-- Nameplates.lua draws the row as your target's plate comes into view, and its leave hook hides the row of a plate that goes.
-- With Threat value position at Below the threat value hangs under the row while it shows (ns.PlateComboRow, PlateThreatText.lua's PlaceValue),
-- placed again as the row comes and goes or moves (ns.PlateThreatPlace; in a fight on a plate that may be protected, once the fight ends); it moves
-- up as a fade out starts.
-- Combat: the row is a frame of Flat UI's own, a child of the plate's unit frame so it moves, fades and hides with the plate, made, sized and
-- anchored only out of combat on a plate the game may protect (ns.MaybeProtected, Movers.lua), as PlateOverpower.lua makes its icon: it is made on
-- each enemy plate as the plate shows while the row is on, so a target taken in a fight has it. In a fight only its alpha, its colours, its border,
-- its pops and its fades change; a new size, offset or anchor waits for the end of the fight there. A plate first seen in a fight gets its row when the fight ends; /flatui status counts those. Nothing of the game is written:
-- every call on the game only reads.

local KEY = "nameplates"
local PART = "Combo points"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

-- MAX: the most points drawn (ComboFrame.lua's MAX_COMBO_POINTS). SIZE and SPACE: each square and the units between two, in nameplate units, when
-- Combo point size cannot be read. DROP: the units between the cast bar (or a Below class icon) and the row. DIM: the opacity of a square not lit.
-- POP_FROM and POP_SECONDS: the pop of the newest point. FADE_IN and FADE_OUT: the seconds the row fades in as the first point lands and out as the
-- points are spent. COLOUR and FULL: the colours when Combo point colour and Full points colour cannot be read. LEVEL: frame levels above the
-- plate's unit frame. CLASSES: the classes that build combo points. EVENTS: heard while the row is on; UNIT_EVENTS: of the player only.
local K = {
	MAX = 5, SIZE = 7, SPACE = 3, DROP = 2, DIM = 0.25, POP_FROM = 1.4, POP_SECONDS = 0.15, LEVEL = 15, FADE_IN = 0.15, FADE_OUT = 0.2,
	COLOUR = { 1, 0.3, 0.2 }, FULL = { 1, 0.82, 0 },
	CLASSES = { ROGUE = true, DRUID = true },
	EVENTS = { "PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM" },
	UNIT_EVENTS = { "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER" },
}

-- recs[unitFrame]: holder (the row's frame), squares ({ texture, outline, pop }), cast (the plate's cast bar), under (what the row hangs from: the
-- cast bar or a Below class icon), max, size and oy (the squares laid out, their size and the offset), shown (the row shows), lit (the count it
-- shows), hex and painted (the look, Look's key, and the squares it was painted with), appear and vanish (its fades, nil on a client without them),
-- waiting (for the end of a fight). Kept when the plate leaves, so a plate's row is made once.
local recs = setmetatable({}, { __mode = "k" })
-- owns[unitFrame]: Nameplates.lua's own record of the plate (its class icon: icon, classShown, iconSide), from the show and layout hooks; only read.
local owns = setmetatable({}, { __mode = "k" })
-- S: frame (the file's own, false when it could not be made), on (the events are heard), builder (true or false once the game named the class),
-- drawn (the plate whose row shows), waited (plates that waited for the end of a fight, for /flatui status).
local S = { frame = nil, on = false, builder = nil, drawn = nil, waited = 0 }
local Prepare, Draw

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

-- True for a rogue or a druid, read once a plain answer comes (UnitClassBase, plain for the player).
local function Builder()
	if S.builder == nil then
		local token = Ask(UnitClassBase, "player")
		if type(token) == "string" then
			S.builder = K.CLASSES[token] == true
		end
	end
	return S.builder == true
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and Opt("comboPoints") == true and Builder()
end

-- The points on your target now, 0 for a withheld count or one that is no plain number.
local function Count()
	local count = Ask(GetComboPoints, "player", "target")
	if not ns.Finite(count) or count <= 0 then
		return 0
	end
	return math.floor(count + 0.5)
end

-- The most points you can have, at most MAX; MAX when the game gives no plain answer.
local function Most()
	local power = type(Enum) == "table" and type(Enum.PowerType) == "table" and Enum.PowerType.ComboPoints or 4
	local most = Ask(UnitPowerMax, "player", power)
	if not ns.Finite(most) or most < 1 then
		return K.MAX
	end
	return math.min(K.MAX, math.floor(most + 0.5))
end

-- Each square and the units between two, from Combo point size (SIZE when it cannot be read): the space keeps SPACE's share of SIZE, at least 2.
local function Size()
	local size = Opt("comboSize")
	size = ns.Finite(size) and size >= 1 and math.floor(size + 0.5) or K.SIZE
	return size, math.max(2, math.floor(size * K.SPACE / K.SIZE + 0.5))
end

-- The look of `count` of `most` points: the colour row (Full points colour at your most points while Full points stand out is on, else Combo point
-- colour), the key a painted row keeps (a change of either colour or of fullness changes it) and whether the row is full.
local function Look(count, most)
	local full = Opt("comboFull") == true and count >= most
	local row = full and "comboFullColour" or "comboColour"
	local hex = Opt(row)
	return row, (type(hex) == "string" and hex or "") .. (full and "+" or ""), full
end

-- True while an animation group plays.
local function Playing(group)
	if not group then
		return false
	end
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

-- The row's frame -----------------------------------------------------------------------------------------------------------------------------

-- SetPoint and ClearAllPoints are protected (SimpleScriptRegionResizingAPIDocumentation.lua:22-30, 135-139): on a plate that may be protected nothing
-- is made, sized or anchored in a fight. Movers.lua has ns.MaybeProtected; before it loads every frame counts as protected.
local function Locked(unitFrame)
	return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(unitFrame))
end

local function Region(owner, key)
	local region = owner[key]
	if ns.IsSecret(region) or type(region) ~= "table" or ns.Forbidden(region) then
		return nil
	end
	return region
end

local function Wait(unitFrame)
	local rec = recs[unitFrame]
	if rec == nil then
		rec = {}
		recs[unitFrame] = rec
	end
	if rec.waiting then
		return
	end
	rec.waiting = true
	S.waited = S.waited + 1
	ns.OutOfCombat(function()
		rec.waiting = nil
		if S.on and recs[unitFrame] == rec and not ns.Forbidden(unitFrame) then
			ns.EachPart(KEY, PART, Prepare, unitFrame)
			ns.EachPart(KEY, PART, Draw, true)
		end
	end)
end

-- The pop of a square: a Scale animation of its texture from POP_FROM back to whole, from its middle; nil on a client that refuses it.
local function MakePop(texture)
	local ok, group = pcall(function()
		local made = texture:CreateAnimationGroup()
		ns.Own[made] = true
		local shrink = made:CreateAnimation("Scale")
		ns.Own[shrink] = true
		shrink:SetScaleFrom(K.POP_FROM, K.POP_FROM)
		shrink:SetScaleTo(1, 1)
		shrink:SetDuration(K.POP_SECONDS)
		shrink:SetOrigin("CENTER", 0, 0)
		pcall(shrink.SetSmoothing, shrink, "OUT")
		return made
	end)
	return ok and type(group) == "table" and group or nil
end

-- The fades of the row: in over FADE_IN (an Alpha animation from nothing) and out over FADE_OUT (to nothing, keeping its end; the row stays at
-- nothing once it ends unless it shows again), animation groups of the row's own frame; none on a client that refuses them.
local function MakeFades(rec)
	local holder = rec.holder
	local ok, appear, vanish = pcall(function()
		local inGroup = holder:CreateAnimationGroup()
		ns.Own[inGroup] = true
		local fadeIn = inGroup:CreateAnimation("Alpha")
		ns.Own[fadeIn] = true
		fadeIn:SetFromAlpha(0)
		fadeIn:SetToAlpha(1)
		fadeIn:SetDuration(K.FADE_IN)
		local outGroup = holder:CreateAnimationGroup()
		ns.Own[outGroup] = true
		local fadeOut = outGroup:CreateAnimation("Alpha")
		ns.Own[fadeOut] = true
		fadeOut:SetFromAlpha(1)
		fadeOut:SetToAlpha(0)
		fadeOut:SetDuration(K.FADE_OUT)
		pcall(outGroup.SetToFinalAlpha, outGroup, true)
		outGroup:SetScript("OnFinished", function()
			if not rec.shown then
				holder:SetAlpha(0)
			end
		end)
		return inGroup, outGroup
	end)
	if ok and type(appear) == "table" and type(vanish) == "table" then
		rec.appear, rec.vanish = appear, vanish
	end
end

-- The row of a plate, made the first time the plate needs one; nil while it waits for the end of a fight.
local function Make(unitFrame)
	local rec = recs[unitFrame]
	if rec and rec.holder then
		return rec
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return nil
	end
	rec = rec or {}
	recs[unitFrame] = rec
	local holder = CreateFrame("Frame", nil, unitFrame)
	ns.Own[holder] = true
	local size, space = Size()
	holder:SetSize(K.MAX * size + (K.MAX - 1) * space, size)
	holder:SetAlpha(0)
	local squares = {}
	for index = 1, K.MAX do
		local texture = holder:CreateTexture(nil, "ARTWORK")
		ns.Own[texture] = true
		texture:SetSize(size, size)
		texture:SetColorTexture(1, 1, 1, 1)
		local outline = ns.SetOutlineArea(ns.Outline(holder, texture), KEY)
		ns.SetOutline(outline, false, false)
		squares[index] = { texture = texture, outline = outline, pop = MakePop(texture) }
	end
	rec.holder, rec.squares = holder, squares
	MakeFades(rec)
	return rec
end

-- What the row hangs from: the plate's class icon while it shows at Below (Nameplates.lua's own record, owns), else the cast bar.
local function Under(unitFrame, cast)
	local own = owns[unitFrame]
	local icon = type(own) == "table" and own.icon
	if own and own.classShown and own.iconSide == "below" and type(icon) == "table" then
		return icon
	end
	return cast
end

-- The threat value of a plate placed again (PlateThreatText.lua): at Below it hangs under the row while the row shows.
local function ValuePlace(unitFrame)
	if type(ns.PlateThreatPlace) == "function" then
		pcall(ns.PlateThreatPlace, unitFrame)
	end
end

-- Anchors the row just under the plate's cast bar (or its Below class icon), centred and moved by Combo points vertical offset, and lays its squares
-- out at Combo point size for the most points you can have, when any of that changed or it has no anchor yet, out of combat on a plate that may be
-- protected. A row that shows and moves places a Below threat value again.
local function Place(unitFrame, rec)
	local cast = Region(unitFrame, "CastBarsContainer")
	if cast == nil then
		return
	end
	local most = Most()
	local size, space = Size()
	local oy = Opt("comboY")
	oy = ns.Finite(oy) and math.floor(oy + 0.5) or 0
	local under = Under(unitFrame, cast)
	if rec.cast == cast and rec.max == most and rec.size == size and rec.oy == oy and rec.under == under then
		return
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return
	end
	local holder = rec.holder
	if rec.under ~= under or rec.oy ~= oy then
		holder:ClearAllPoints()
		holder:SetPoint("TOP", under, "BOTTOM", 0, -K.DROP + oy)
	end
	holder:SetSize(most * size + (most - 1) * space, size)
	for index, square in ipairs(rec.squares) do
		square.texture:SetSize(size, size)
		square.texture:ClearAllPoints()
		square.texture:SetPoint("LEFT", holder, "LEFT", (index - 1) * (size + space), 0)
	end
	local level = Ask(unitFrame.GetFrameLevel, unitFrame)
	if type(level) == "number" then
		pcall(holder.SetFrameLevel, holder, level + K.LEVEL)
	end
	local moved = rec.cast ~= nil and (rec.under ~= under or rec.oy ~= oy or rec.size ~= size)
	rec.cast, rec.under, rec.max, rec.size, rec.oy = cast, under, most, size, oy
	if moved and rec.shown then
		ValuePlace(unitFrame)
	end
end

-- An enemy plate gets its row ready, so a target taken in a fight shows its points at once. A plate whose side is not known yet gets it too.
function Prepare(unitFrame)
	if not S.on or ns.Forbidden(unitFrame) then
		return
	end
	local unit = unitFrame.unit
	if not ns.IsSecret(unit) and type(unit) == "string" and Ask(UnitCanAttack, "player", unit) == false then
		return
	end
	local rec = Make(unitFrame)
	if rec then
		Place(unitFrame, rec)
	end
end

-- The row of a plate hidden: its squares' pops stop and the threat value below it moves up again. soft: the points were spent, so a row that shows
-- fades out over FADE_OUT, and a fade out on its way goes on; else it goes at once, cutting a fade short (a change of target, a plate that leaves,
-- the part going off).
local function Hide(unitFrame, soft)
	local rec = recs[unitFrame]
	if not (rec and rec.holder) then
		return
	end
	local was = rec.shown
	if soft and not was then
		return
	end
	rec.shown, rec.lit = nil, nil
	if rec.appear then
		pcall(rec.appear.Stop, rec.appear)
	end
	if not (soft and rec.vanish and pcall(rec.vanish.Play, rec.vanish)) then
		if rec.vanish then
			pcall(rec.vanish.Stop, rec.vanish)
		end
		rec.holder:SetAlpha(0)
	end
	for _, square in ipairs(rec.squares) do
		if square.pop then
			pcall(square.pop.Stop, square.pop)
		end
	end
	if was then
		ValuePlace(unitFrame)
	end
end

-- Paints the row: `count` of the squares laid out lit in Combo point colour (every square in Full points colour at your most points, Look), the rest
-- at DIM, each in its border. pop: the newest point pops, and every lit one with it as a full row lands.
local function Paint(rec, count, pop)
	local most = rec.max or K.MAX
	local row, key, full = Look(count, most)
	local base = full and K.FULL or K.COLOUR
	local r, g, b = base[1], base[2], base[3]
	if type(Opt(row)) == "string" then
		r, g, b = ns.Colour(KEY .. "." .. row)
	end
	for index, square in ipairs(rec.squares) do
		local within = index <= most
		if rec.hex ~= key then
			square.texture:SetColorTexture(r, g, b, 1)
		end
		square.texture:SetAlpha(within and (index <= count and 1 or K.DIM) or 0)
		ns.SetOutline(square.outline, within, false)
	end
	rec.hex, rec.lit, rec.painted = key, count, most
	if not pop then
		return
	end
	for index, square in ipairs(rec.squares) do
		if square.pop and (index == count or (full and index < count)) then
			pcall(square.pop.Stop, square.pop)
			pcall(square.pop.Play, square.pop)
		end
	end
end

-- Draws the row on your target's plate and hides it on the plate that showed it before. snap: the target changed or the rows did, so nothing pops.
function Draw(snap)
	local target = S.on and type(ns.PlateUnitFrame) == "function" and ns.PlateUnitFrame("target") or nil
	if S.drawn ~= nil and S.drawn ~= target then
		local old = S.drawn
		S.drawn = nil
		Hide(old)
	end
	local count = target and Count() or 0
	if target == nil or count <= 0 then
		-- The points were spent on the plate that shows them: the row fades out (a row already hidden, or fading, stays so).
		if target ~= nil then
			Hide(target, not snap)
		end
		S.drawn = nil
		return
	end
	local rec = Make(target)
	if not rec then
		return
	end
	Place(target, rec)
	if rec.cast == nil then
		return
	end
	S.drawn = target
	count = math.min(count, rec.max or K.MAX)
	local _, key = Look(count, rec.max or K.MAX)
	if rec.shown and rec.lit == count and rec.hex == key and rec.painted == rec.max then
		return
	end
	local first = not rec.shown
	local pop = not snap and count > (rec.shown and rec.lit or 0)
	Paint(rec, count, pop)
	rec.shown = true
	if first then
		-- The first point fades the row in; one that comes back while its fade out runs, or on a new target, shows it at once.
		local fading = Playing(rec.vanish)
		if rec.vanish then
			pcall(rec.vanish.Stop, rec.vanish)
		end
		rec.holder:SetAlpha(1)
		if not snap and not fading and rec.appear then
			pcall(rec.appear.Stop, rec.appear)
			pcall(rec.appear.Play, rec.appear)
		end
		ValuePlace(target)
	else
		rec.holder:SetAlpha(1)
	end
end

-- Events --------------------------------------------------------------------------------------------------------------------------------------

local function Heard(event)
	if event == "UNIT_MAXPOWER" then
		-- The squares are laid out again for the new most (out of combat on a plate that may be protected).
		for unitFrame, rec in pairs(recs) do
			if rec.holder and not ns.Forbidden(unitFrame) then
				Place(unitFrame, rec)
			end
		end
	end
	Draw(event == "PLAYER_TARGET_CHANGED")
end

-- Every row hidden: the row, the page or the part went off.
local function StandDown()
	local drawn = S.drawn
	S.drawn = nil
	for unitFrame in pairs(recs) do
		if not ns.Forbidden(unitFrame) then
			pcall(Hide, unitFrame)
		end
	end
	if drawn ~= nil then
		ValuePlace(drawn)
	end
end

local function OnEvent(_, event)
	local ok = ns.EachPart(KEY, PART, Heard, event)
	if not ok and ns.PartStopped(KEY, PART) then
		S.on = false
		pcall(StandDown)
	end
end

local function Hear(on)
	if S.frame == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		S.frame = ok and type(frame) == "table" and frame or false
		if S.frame then
			ns.Own[frame] = true
			frame:SetScript("OnEvent", OnEvent)
		end
	end
	local frame = S.frame
	if not frame then
		return false
	end
	for _, event in ipairs(K.EVENTS) do
		pcall(on and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
	end
	for _, event in ipairs(K.UNIT_EVENTS) do
		if not on then
			pcall(frame.UnregisterEvent, frame, event)
		elseif not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, event, "player")) then
			pcall(frame.RegisterEvent, frame, event)
		end
	end
	return true
end

-- Starts or stops the part as the row, the page and the class say, places every row again and draws the target's.
local function Sync()
	local want = Wanted()
	if want ~= S.on then
		S.on = want and Hear(true) or false
		if S.on then
			if type(ns.EachPlate) == "function" then
				ns.EachPlate(function(unitFrame)
					ns.EachPart(KEY, PART, Prepare, unitFrame)
				end)
			end
		else
			Hear(false)
			StandDown()
		end
	end
	if S.on then
		for unitFrame, rec in pairs(recs) do
			if rec.holder and not ns.Forbidden(unitFrame) then
				ns.EachPart(KEY, PART, Place, unitFrame, rec)
			end
		end
		Draw(true)
	end
end

-- Hooks into the plates ------------------------------------------------------------------------------------------------------------------------

EXTRA.show[#EXTRA.show + 1] = function(unitFrame, own)
	if type(own) == "table" then
		owns[unitFrame] = own
	end
	if S.on then
		ns.EachPart(KEY, PART, Prepare, unitFrame)
		-- Your target's plate came into view.
		if type(ns.PlateUnitFrame) == "function" and ns.PlateUnitFrame("target") == unitFrame then
			ns.EachPart(KEY, PART, Draw, true)
		end
	end
end
EXTRA.layout[#EXTRA.layout + 1] = function(unitFrame, own)
	if type(own) == "table" then
		owns[unitFrame] = own
	end
	local rec = recs[unitFrame]
	if S.on and rec and rec.holder then
		ns.EachPart(KEY, PART, Place, unitFrame, rec)
	end
end
EXTRA.leave[#EXTRA.leave + 1] = function(unitFrame)
	if S.drawn == unitFrame then
		S.drawn = nil
	end
	pcall(Hide, unitFrame)
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	local ok = ns.EachPart(KEY, PART, Sync)
	if not ok and (ns.PartStopped(KEY, PART) or not ns.Enabled(KEY)) then
		S.on = false
		pcall(Hear, false)
		pcall(StandDown)
	end
end

-- The row of a plate placed again, for Nameplates.lua as the plate's class icon comes or goes (own: its record of the plate): under a Below class
-- icon while it shows, else under the cast bar. Out of combat on a plate that may be protected, else once the fight ends.
function ns.PlateComboPlace(unitFrame, own)
	if unitFrame == nil or ns.IsSecret(unitFrame) or ns.Forbidden(unitFrame) then
		return
	end
	if type(own) == "table" then
		owns[unitFrame] = own
	end
	local rec = recs[unitFrame]
	if S.on and rec and rec.holder then
		ns.EachPart(KEY, PART, Place, unitFrame, rec)
	end
end

-- The row of a plate while it shows, for PlateThreatText.lua: a threat value at Below hangs under it. Nil otherwise.
function ns.PlateComboRow(unitFrame)
	local rec = unitFrame ~= nil and recs[unitFrame]
	if S.on and rec and rec.holder and rec.shown and rec.cast ~= nil then
		return rec.holder
	end
	return nil
end

EXTRA.status[#EXTRA.status + 1] = function()
	if Opt("comboPoints") ~= true or not Builder() then
		return nil
	end
	return ("Combo points on your target's nameplate: %d of %d points on your target, %d plates waited for the end of a fight for their row."):format(
		Count(), Most(), S.waited)
end
