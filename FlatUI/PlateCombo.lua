local _, ns = ...

local KEY = "nameplates"
local PART = "Combo points"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local K = {
	MAX = 5, SIZE = 7, SPACE = 3, DROP = 2, DIM = 0.25, POP_FROM = 1.4, POP_SECONDS = 0.15, LEVEL = 15, FADE_IN = 0.15, FADE_OUT = 0.2,
	COLOUR = { 1, 0.3, 0.2 }, FULL = { 1, 0.82, 0 },
	CLASSES = { ROGUE = true, DRUID = true },
	EVENTS = { "PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM" },
	UNIT_EVENTS = { "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER" },
}

local recs = setmetatable({}, { __mode = "k" })
local owns = setmetatable({}, { __mode = "k" })
local S = { frame = nil, on = false, builder = nil, drawn = nil, waited = 0 }
local Prepare, Draw

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

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

local function Count()
	local count = Ask(GetComboPoints, "player", "target")
	if not ns.Finite(count) or count <= 0 then
		return 0
	end
	return math.floor(count + 0.5)
end

local function Most()
	local power = type(Enum) == "table" and type(Enum.PowerType) == "table" and Enum.PowerType.ComboPoints or 4
	local most = Ask(UnitPowerMax, "player", power)
	if not ns.Finite(most) or most < 1 then
		return K.MAX
	end
	return math.min(K.MAX, math.floor(most + 0.5))
end

local function Size()
	local size = Opt("comboSize")
	size = ns.Finite(size) and size >= 1 and math.floor(size + 0.5) or K.SIZE
	return size, math.max(2, math.floor(size * K.SPACE / K.SIZE + 0.5))
end

local function Look(count, most)
	local full = Opt("comboFull") == true and count >= most
	local row = full and "comboFullColour" or "comboColour"
	local hex = Opt(row)
	return row, (type(hex) == "string" and hex or "") .. (full and "+" or ""), full
end

local function Playing(group)
	if not group then
		return false
	end
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

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

local function Under(unitFrame, cast)
	local own = owns[unitFrame]
	local icon = type(own) == "table" and own.icon
	if own and own.classShown and own.iconSide == "below" and type(icon) == "table" then
		return icon
	end
	return cast
end

local function ValuePlace(unitFrame)
	if type(ns.PlateThreatPlace) == "function" then
		pcall(ns.PlateThreatPlace, unitFrame)
	end
end

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

local function Heard(event)
	if event == "UNIT_MAXPOWER" then
		for unitFrame, rec in pairs(recs) do
			if rec.holder and not ns.Forbidden(unitFrame) then
				Place(unitFrame, rec)
			end
		end
	end
	Draw(event == "PLAYER_TARGET_CHANGED")
end

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

EXTRA.show[#EXTRA.show + 1] = function(unitFrame, own)
	if type(own) == "table" then
		owns[unitFrame] = own
	end
	if S.on then
		ns.EachPart(KEY, PART, Prepare, unitFrame)
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
