local _, ns = ...

-- Combo points under your target's nameplate, a part of Nameplates.lua (ns.PlateExtra), for a rogue or a druid (UnitClassBase of the player, plain).
-- This client draws combo points only round the target frame's portrait (Camelot/ComboFrame.lua:13-16, 98-130): the game's own bars of combo points on
-- nameplates are not loaded on it (Blizzard_NamePlates.toc:35-38, ExcludeLoadGameType camelot). With Combo points on your target's nameplate (on by
-- default, on the Marks and icons tab of Nameplates) a row of small squares, one for each point you can have (UnitPowerMax of the combo points, as
-- ComboFrame.lua:67-69 reads it, at most MAX), stands centred just under the cast bar of your target's plate (the plate ns.PlateUnitFrame gives for
-- "target", compared as a frame, so no unit comparison the client can withhold is needed). The count is the game's own: GetComboPoints("player",
-- "target"), the call ComboFrame.lua:98 makes, which the client may withhold (SecretWhenUnitPowerRestricted, UnitDocumentation.lua:91-105). A
-- withheld count, an answer that is no plain number and 0 hide the row, as the game hides its own at 0 (ComboFrame.lua:121-130); a druid out of Cat
-- Form reads 0. A lit square is in Combo point colour and the rest of the row is in it at DIM, each in Flat UI's thin border (ns.Outline). As the
-- count goes up the newest square pops (a Scale animation of the square's own texture from POP_FROM back to whole over POP_SECONDS, from its middle,
-- not protected, so it plays in a fight); a change of target draws the new plate's row at once without a pop, as ComboFrame.lua's
-- suppressTransitions does, and hides the old one.
-- Events: UNIT_POWER_FREQUENT, UNIT_POWER_UPDATE and UNIT_MAXPOWER of the player (RegisterUnitEvent) and PLAYER_TARGET_CHANGED, as ComboFrame.lua
-- hears them (24-31), and UPDATE_SHAPESHIFT_FORM for a druid's form, on a frame of the file's own while the row is on; the show hook of
-- Nameplates.lua draws the row as your target's plate comes into view, and its leave hook hides the row of a plate that goes.
-- With Threat value position at Below the threat value hangs under the row while it shows (ns.PlateComboRow, PlateThreatText.lua's PlaceValue),
-- placed again as the row comes and goes (ns.PlateThreatPlace; in a fight on a plate that may be protected, once the fight ends).
-- Combat: the row is a frame of Flat UI's own, a child of the plate's unit frame so it moves, fades and hides with the plate, made, sized and
-- anchored only out of combat on a plate the game may protect (ns.MaybeProtected, Movers.lua), as PlateOverpower.lua makes its icon: it is made on
-- each enemy plate as the plate shows while the row is on, so a target taken in a fight has it. In a fight only its alpha, its colours, its border
-- and its pop change. A plate first seen in a fight gets its row when the fight ends; /flatui status counts those. Nothing of the game is written:
-- every call on the game only reads.

local KEY = "nameplates"
local PART = "Combo points"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

-- MAX: the most points drawn (ComboFrame.lua's MAX_COMBO_POINTS). SIZE and SPACE: each square and the units between two, in nameplate units. DROP:
-- the units between the cast bar and the row. DIM: the opacity of a square not lit. POP_FROM and POP_SECONDS: the pop of the newest point. LEVEL:
-- frame levels above the plate's unit frame. CLASSES: the classes that build combo points. EVENTS: heard while the row is on; UNIT_EVENTS: of the
-- player only.
local K = {
	MAX = 5, SIZE = 7, SPACE = 3, DROP = 2, DIM = 0.25, POP_FROM = 1.4, POP_SECONDS = 0.15, LEVEL = 15,
	CLASSES = { ROGUE = true, DRUID = true },
	EVENTS = { "PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM" },
	UNIT_EVENTS = { "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER" },
}

-- recs[unitFrame]: holder (the row's frame), squares ({ texture, outline, pop }), cast (the cast bar it hangs from), max (the squares laid out),
-- shown (the row shows), lit (the count it shows), hex and painted (the colour and the squares it was painted with), waiting (for the end of a
-- fight). Kept when the plate leaves, so a plate's row is made once.
local recs = setmetatable({}, { __mode = "k" })
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
	holder:SetSize(K.MAX * K.SIZE + (K.MAX - 1) * K.SPACE, K.SIZE)
	holder:SetAlpha(0)
	local squares = {}
	for index = 1, K.MAX do
		local texture = holder:CreateTexture(nil, "ARTWORK")
		ns.Own[texture] = true
		texture:SetSize(K.SIZE, K.SIZE)
		texture:SetColorTexture(1, 1, 1, 1)
		local outline = ns.SetOutlineArea(ns.Outline(holder, texture), KEY)
		ns.SetOutline(outline, false, false)
		squares[index] = { texture = texture, outline = outline, pop = MakePop(texture) }
	end
	rec.holder, rec.squares = holder, squares
	return rec
end

-- Anchors the row just under the plate's cast bar, centred, and lays its squares out for the most points you can have, when that changed or it has
-- no anchor yet, out of combat on a plate that may be protected.
local function Place(unitFrame, rec)
	local cast = Region(unitFrame, "CastBarsContainer")
	local most = Most()
	if cast == nil or (rec.cast == cast and rec.max == most) then
		return
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return
	end
	local holder = rec.holder
	if rec.cast ~= cast then
		holder:ClearAllPoints()
		holder:SetPoint("TOP", cast, "BOTTOM", 0, -K.DROP)
	end
	local width = most * K.SIZE + (most - 1) * K.SPACE
	holder:SetSize(width, K.SIZE)
	for index, square in ipairs(rec.squares) do
		square.texture:ClearAllPoints()
		square.texture:SetPoint("LEFT", holder, "LEFT", (index - 1) * (K.SIZE + K.SPACE), 0)
	end
	local level = Ask(unitFrame.GetFrameLevel, unitFrame)
	if type(level) == "number" then
		pcall(holder.SetFrameLevel, holder, level + K.LEVEL)
	end
	rec.cast, rec.max = cast, most
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

-- The threat value of a plate placed again (PlateThreatText.lua): at Below it hangs under the row while the row shows.
local function ValuePlace(unitFrame)
	if type(ns.PlateThreatPlace) == "function" then
		pcall(ns.PlateThreatPlace, unitFrame)
	end
end

-- The row of a plate hidden: its squares' pops stop and the threat value below it moves up again.
local function Hide(unitFrame)
	local rec = recs[unitFrame]
	if not (rec and rec.holder) then
		return
	end
	local was = rec.shown
	rec.shown, rec.lit = nil, nil
	rec.holder:SetAlpha(0)
	for _, square in ipairs(rec.squares) do
		if square.pop then
			pcall(square.pop.Stop, square.pop)
		end
	end
	if was then
		ValuePlace(unitFrame)
	end
end

-- Paints the row: `count` of the squares laid out lit in Combo point colour, the rest at DIM, each in its border. pop: the newest point pops.
local function Paint(rec, count, pop)
	local hex = Opt("comboColour")
	local r, g, b = 1, 0.3, 0.2
	if type(hex) == "string" then
		r, g, b = ns.Colour(KEY .. ".comboColour")
	end
	local most = rec.max or K.MAX
	for index, square in ipairs(rec.squares) do
		local within = index <= most
		if rec.hex ~= hex then
			square.texture:SetColorTexture(r, g, b, 1)
		end
		square.texture:SetAlpha(within and (index <= count and 1 or K.DIM) or 0)
		ns.SetOutline(square.outline, within, false)
	end
	rec.hex, rec.lit, rec.painted = hex, count, most
	local newest = pop and rec.squares[count]
	if newest and newest.pop then
		pcall(newest.pop.Stop, newest.pop)
		pcall(newest.pop.Play, newest.pop)
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
		if target ~= nil then
			Hide(target)
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
	if rec.shown and rec.lit == count and rec.hex == Opt("comboColour") and rec.painted == rec.max then
		return
	end
	local first = not rec.shown
	local pop = not snap and count > (rec.shown and rec.lit or 0)
	Paint(rec, count, pop)
	rec.shown = true
	rec.holder:SetAlpha(1)
	if first then
		ValuePlace(target)
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

EXTRA.show[#EXTRA.show + 1] = function(unitFrame)
	if S.on then
		ns.EachPart(KEY, PART, Prepare, unitFrame)
		-- Your target's plate came into view.
		if type(ns.PlateUnitFrame) == "function" and ns.PlateUnitFrame("target") == unitFrame then
			ns.EachPart(KEY, PART, Draw, true)
		end
	end
end
EXTRA.layout[#EXTRA.layout + 1] = function(unitFrame)
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
