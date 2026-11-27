local _, ns = ...

-- The flash of a new target's nameplate, a part of Nameplates.lua (ns.PlateExtra). With Flash as you change target (on by default, on the Marks and
-- icons tab of Nameplates, under Target and focus, while Health bar border and Target and focus border are on), the health bar border of the plate
-- you take as your target flashes once in Target colour as you change target: an outline of Flat UI's own, GROW screen pixels thicker than Target
-- and focus border thickness, that starts whole and fades out over SECONDS (an Alpha animation of its own frame, smoothed out, keeping its end),
-- leaving behind the target border Nameplates.lua's Mark draws. Setting a focus flashes the focus's plate the same way in Focus colour. So with Tab
-- in a pack the eye sees at once which plate it took. The plates are found as frames (ns.PlateUnitFrame of "target" and "focus"), so no unit
-- comparison the client can withhold is needed, and only a plate Flat UI restyles (Nameplates.lua's own record of it, own.styleOn) flashes, since
-- only it has that border.
-- Combat: the flash's frame is a child of the plate's health bar, so it hides with the bar (a plate at names only) and moves, scales and fades with
-- the plate. It is made and anchored only out of combat on a plate the game may protect (ns.MaybeProtected, Movers.lua): it is made on every plate as
-- the plate shows while the row is on, so a target taken in a fight has it, and a plate first seen in a fight gets it when the fight ends (/flatui
-- status counts those). In a fight only its colour, its thickness (Flat UI's own edges) and its animation change, so it plays in a fight. A plate
-- that leaves, a refresh of the rows and the part going off stop a flash on its way. Nothing of the game is written: every call on the game only
-- reads.
-- Events: PLAYER_TARGET_CHANGED and PLAYER_FOCUS_CHANGED, added to Nameplates.lua's own (ns.AddEvent). ns.PlateTargetFlash also makes the flash of
-- the Target and Focus samples of setup's drawings (SetupDrawPlates.lua's P.TargetFlash).

local KEY = "nameplates"
local PART = "Target flash"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

-- SECONDS: how long the flash takes to fade. GROW: the screen pixels it is thicker than Target and focus border thickness. LEVEL: frame levels above
-- the health bar, over its border and the line inside a Rare Elite's.
local K = { SECONDS = 0.35, GROW = 2, LEVEL = 8 }

-- recs[unitFrame]: holder (the flash's frame), outline, flash (its animation group, nil on a client without one) and waiting (for the end of a fight).
-- Kept when the plate leaves, so a plate's flash is made once.
local recs = setmetatable({}, { __mode = "k" })
-- owns[unitFrame]: Nameplates.lua's own record of the plate (own.styleOn), from the show hook; only read.
local owns = setmetatable({}, { __mode = "k" })
-- S: on (the part runs), waited (plates that waited for the end of a fight) and played (flashes played), for /flatui status.
local S = { on = false, waited = 0, played = 0 }
local Prepare

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and Opt("health") == true and Opt("target") == true
		and Opt("targetFlash") == true
end

-- The flash's thickness in screen pixels: Target and focus border thickness (1 when it cannot be read) and GROW.
local function Thickness()
	local px = Opt("targetThickness")
	px = ns.Finite(px) and px >= 1 and math.floor(px + 0.5) or 1
	return px + K.GROW
end

-- The plate's health bar, or nil when it is missing, withheld or forbidden.
local function Bar(unitFrame)
	local container = unitFrame.HealthBarsContainer
	if ns.IsSecret(container) or type(container) ~= "table" or ns.Forbidden(container) then
		return nil
	end
	local bar = container.healthBar
	if ns.IsSecret(bar) or type(bar) ~= "table" or ns.Forbidden(bar) then
		return nil
	end
	return bar
end

-- SetPoint is protected on a plate the game protects in a fight (SimpleScriptRegionResizingAPIDocumentation.lua:22-30): nothing is made or anchored
-- there in a fight. Movers.lua has ns.MaybeProtected; before it loads every frame counts as protected.
local function Locked(unitFrame, bar)
	return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(unitFrame) or ns.MaybeProtected(bar))
end

-- The flash: an Alpha animation of `holder` from whole to nothing over SECONDS, smoothed out and keeping its end, so the frame rests unseen. Not
-- protected on a frame of Flat UI's own, so it plays in a fight. Nil when the client will not make it. Also the flash of setup's samples.
function ns.PlateTargetFlash(holder)
	local ok, group = pcall(function()
		local made = holder:CreateAnimationGroup()
		ns.Own[made] = true
		local fade = made:CreateAnimation("Alpha")
		ns.Own[fade] = true
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0)
		fade:SetDuration(K.SECONDS)
		pcall(fade.SetSmoothing, fade, "OUT")
		pcall(made.SetToFinalAlpha, made, true)
		return made
	end)
	return ok and type(group) == "table" and group or nil
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
		end
	end)
end

-- The flash of a plate, made the first time the plate needs one; nil while it waits for the end of a fight or has no health bar.
local function Make(unitFrame)
	local rec = recs[unitFrame]
	if rec and rec.holder then
		return rec
	end
	local bar = Bar(unitFrame)
	if bar == nil then
		return nil
	end
	if Locked(unitFrame, bar) then
		Wait(unitFrame)
		return nil
	end
	rec = rec or {}
	recs[unitFrame] = rec
	local holder = CreateFrame("Frame", nil, bar)
	ns.Own[holder] = true
	holder:SetAllPoints(bar)
	holder:SetAlpha(0)
	local ok, level = pcall(bar.GetFrameLevel, bar)
	if ok and ns.Finite(level) then
		pcall(holder.SetFrameLevel, holder, level + K.LEVEL)
	end
	local outline = ns.SetOutlineArea(ns.Outline(holder, holder), KEY)
	ns.KeepOutline(outline)
	ns.SetOutline(outline, true, false)
	ns.SetOutlineThickness(outline, Thickness())
	rec.holder, rec.outline, rec.flash = holder, outline, ns.PlateTargetFlash(holder)
	return rec
end

-- A flash on its way stops, and the frame rests unseen.
local function Still(rec)
	if not (rec and rec.holder) then
		return
	end
	if rec.flash then
		pcall(rec.flash.Stop, rec.flash)
	end
	rec.holder:SetAlpha(0)
end

-- A plate Flat UI restyles gets its flash ready, so a target taken in a fight flashes at once.
function Prepare(unitFrame)
	if not S.on or ns.Forbidden(unitFrame) then
		return
	end
	local own = owns[unitFrame]
	if type(own) == "table" and own.styleOn == false then
		return
	end
	Make(unitFrame)
end

-- The plate of `unit` flashes once in the colour of `row` (targetColour or focusColour).
local function Play(unit, row)
	if not (S.on and Wanted()) or type(ns.PlateUnitFrame) ~= "function" then
		return
	end
	local unitFrame = ns.PlateUnitFrame(unit)
	if unitFrame == nil or ns.Forbidden(unitFrame) then
		return
	end
	local own = owns[unitFrame]
	if type(own) ~= "table" or own.styleOn ~= true then
		return
	end
	local rec = Make(unitFrame)
	if not (rec and rec.flash) then
		return
	end
	ns.SetOutlineColour(rec.outline, ns.Colour(KEY .. "." .. row))
	ns.SetOutlineThickness(rec.outline, Thickness())
	pcall(rec.flash.Stop, rec.flash)
	if pcall(rec.flash.Play, rec.flash) then
		S.played = S.played + 1
	end
end

-- Every flash stopped: the row, the page or the part went off.
local function StandDown()
	for unitFrame, rec in pairs(recs) do
		if not ns.Forbidden(unitFrame) then
			pcall(Still, rec)
		end
	end
end

-- Starts or stops the part as the rows say; every flash on its way stops and takes the thickness of the rows.
local function Sync()
	local want = Wanted()
	if want ~= S.on then
		S.on = want
		if want and type(ns.EachPlate) == "function" then
			ns.EachPlate(function(unitFrame)
				ns.EachPart(KEY, PART, Prepare, unitFrame)
			end)
		end
	end
	for unitFrame, rec in pairs(recs) do
		if rec.holder and not ns.Forbidden(unitFrame) then
			Still(rec)
			ns.SetOutlineThickness(rec.outline, Thickness())
		end
	end
end

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	if S.on then
		ns.EachPart(KEY, PART, Play, "target", "targetColour")
	end
end)
ns.AddEvent(KEY, "PLAYER_FOCUS_CHANGED", function()
	if S.on then
		ns.EachPart(KEY, PART, Play, "focus", "focusColour")
	end
end)

-- Hooks into the plates ------------------------------------------------------------------------------------------------------------------------

EXTRA.show[#EXTRA.show + 1] = function(unitFrame, own)
	if type(own) == "table" then
		owns[unitFrame] = own
	end
	if S.on then
		ns.EachPart(KEY, PART, Prepare, unitFrame)
	end
end
EXTRA.leave[#EXTRA.leave + 1] = function(unitFrame)
	pcall(Still, recs[unitFrame])
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	local ok = ns.EachPart(KEY, PART, Sync)
	if not ok and (ns.PartStopped(KEY, PART) or not ns.Enabled(KEY)) then
		S.on = false
		pcall(StandDown)
	end
end

EXTRA.status[#EXTRA.status + 1] = function()
	if Opt("targetFlash") ~= true then
		return nil
	end
	return ("Flash as you change target: %s, %d flashes played, %d plates waited for the end of a fight for theirs."):format(
		S.on and "on" or "off (it needs Health bar border and Target and focus border)", S.played, S.waited)
end
