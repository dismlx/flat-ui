local _, ns = ...

local KEY = "nameplates"
local PART = "Target flash"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local K = { SECONDS = 0.35, GROW = 2, LEVEL = 8 }

local recs = setmetatable({}, { __mode = "k" })
local copies = setmetatable({}, { __mode = "k" })
local owns = setmetatable({}, { __mode = "k" })
local S = { on = false, waited = 0, played = 0 }
local Prepare

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and Opt("health") == true and Opt("target") == true
		and Opt("targetFlash") == true
end

local function Thickness()
	local px = Opt("targetThickness")
	px = ns.Finite(px) and px >= 1 and math.floor(px + 0.5) or 1
	local mark = type(ns.PlateMarkPx) == "function" and ns.PlateMarkPx() or nil
	if ns.Finite(mark) and mark > px then
		px = mark
	end
	return px + K.GROW
end

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

local function Locked(unitFrame, bar)
	return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(unitFrame) or ns.MaybeProtected(bar))
end

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
	rec.holder, rec.outline, rec.flash = Holder(bar, bar)
	return rec
end

local function Holder(parent, bar)
	local holder = CreateFrame("Frame", nil, parent)
	ns.Own[holder] = true
	pcall(holder.EnableMouse, holder, false)
	holder:SetAllPoints(bar)
	holder:SetAlpha(0)
	local top = type(ns.PlateMarkLevel) == "function" and ns.PlateMarkLevel() or nil
	local ok, level = pcall(bar.GetFrameLevel, bar)
	if ns.Finite(top) then
		pcall(holder.SetFrameLevel, holder, top + 1)
	elseif ok and ns.Finite(level) then
		pcall(holder.SetFrameLevel, holder, level + K.LEVEL)
	end
	local outline = ns.SetOutlineArea(ns.Outline(holder, holder), KEY)
	ns.KeepOutline(outline)
	ns.SetOutline(outline, true, false)
	ns.SetOutlineThickness(outline, Thickness())
	return holder, outline, ns.PlateTargetFlash(holder)
end

local function Copy(unitFrame)
	if type(ns.PlateSlipCopy) ~= "function" then
		return nil
	end
	local ok, frame, bar = pcall(ns.PlateSlipCopy, unitFrame)
	if not ok or type(frame) ~= "table" or type(bar) ~= "table" then
		return nil
	end
	local rec = copies[frame]
	if rec == nil then
		rec = {}
		rec.holder, rec.outline, rec.flash = Holder(frame, bar)
		copies[frame] = rec
	end
	return rec
end

local function Still(rec)
	if not (rec and rec.holder) then
		return
	end
	if rec.flash then
		pcall(rec.flash.Stop, rec.flash)
	end
	rec.holder:SetAlpha(0)
end

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
	local rec = Copy(unitFrame) or Make(unitFrame)
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

local function StandDown()
	for unitFrame, rec in pairs(recs) do
		if not ns.Forbidden(unitFrame) then
			pcall(Still, rec)
		end
	end
	for _, rec in pairs(copies) do
		pcall(Still, rec)
	end
end

local function Sync()
	S.on = Wanted()
	if S.on and type(ns.EachPlate) == "function" then
		ns.EachPlate(function(unitFrame)
			ns.EachPart(KEY, PART, Prepare, unitFrame)
		end)
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
