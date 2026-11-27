local ADDON_NAME, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local ICONS, TOT = "Combat and resting icons", "Target of target position"
local GAP = { icon = 2, tot = 4 }
local REST = { box = 20, spill = 5 }
local RETRY = { tries = 5, wait = 0.2 }
local NEAR = 0.05

local kept = setmetatable({}, { __mode = "k" })
local moved = setmetatable({}, { __mode = "k" })
local followed = false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Off(part)
	return not ns.Enabled(KEY) or ns.IsStopped(KEY) or ns.PartStopped(KEY, part)
end

local function Game(name)
	local frame = _G[name]
	if ns.Forbidden(frame) then
		return nil
	end
	return frame
end

local function Thickness(frame)
	return ns.Pixels(frame, tonumber(ns.Get("general.thickness")) or 1)
end

local function Points(region)
	local ok, count = pcall(region.GetNumPoints, region)
	if not ok or not ns.Finite(count) or count < 1 then
		return nil
	end
	local list = {}
	for index = 1, count do
		local got, point, relative, relativePoint, x, y = pcall(region.GetPoint, region, index)
		if not got or ns.IsSecret(point) or ns.IsSecret(relative) or ns.IsSecret(relativePoint) or type(point) ~= "string"
			or type(relativePoint) ~= "string" or not ns.Finite(x) or not ns.Finite(y) then
			return nil
		end
		list[#list + 1] = { point, relative, relativePoint, x, y }
	end
	return list
end

local function Same(region, want)
	local have = Points(region)
	if have == nil or #have ~= #want then
		return false
	end
	for _, w in ipairs(want) do
		local found = false
		for _, h in ipairs(have) do
			if h[1] == w[1] and h[2] == w[2] and h[3] == w[3] and math.abs(h[4] - w[4]) < NEAR and math.abs(h[5] - w[5]) < NEAR then
				found = true
			end
		end
		if not found then
			return false
		end
	end
	return true
end

local function Anchor(region, list)
	region:ClearAllPoints()
	for _, p in ipairs(list) do
		region:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
end

local function Restore(region)
	if region == nil or not moved[region] then
		return
	end
	local list = kept[region]
	moved[region], kept[region] = nil, nil
	if type(list) == "table" then
		pcall(Anchor, region, list)
	end
end

local function Put(region, list)
	if region == nil or Same(region, list) then
		return
	end
	if kept[region] == nil then
		kept[region] = Points(region)
		if kept[region] == nil then
			return
		end
	end
	moved[region] = true
	if not pcall(Anchor, region, list) then
		Restore(region)
	end
end

local function Later(job)
	if job.queued then
		return
	end
	job.queued = true
	ns.OutOfCombat(function()
		job.queued = nil
		X.run(job.part, job.run, job)
	end)
end

local function Retry(job)
	if job.waiting or (job.tries or 0) >= RETRY.tries or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	job.tries, job.waiting = (job.tries or 0) + 1, true
	C_Timer.After(RETRY.wait, function()
		job.waiting = nil
		X.run(job.part, job.run, job)
	end)
end

local function Rect(region)
	if region == nil or ns.IsSecret(region) then
		return nil
	end
	local left, bottom, width, height = X.ask(region, "GetRect")
	local scale = X.ask(region, "GetEffectiveScale")
	if not (X.number(left) and X.number(bottom) and X.number(width) and X.number(height) and X.number(scale) and scale > 0) then
		return nil
	end
	return left * scale, (bottom + height) * scale, (left + width) * scale
end

local function Lit(region)
	if region == nil or ns.IsSecret(region) then
		return false
	end
	local alpha = X.ask(region, "GetAlpha")
	return X.ask(region, "IsShown") == true and X.number(alpha) and alpha > 0
end

local function Block(rec)
	local list = {}
	local body = X.joined(rec) and X.body(rec) or nil
	if body ~= nil then
		list[1] = body
	else
		local health, power, pic = rec.byRole.health, rec.byRole.power, rec.pic
		list[#list + 1] = health and health.target or rec.parts.health
		if power ~= nil and Lit(power.bar) then
			list[#list + 1] = power.target
		end
		if rec.row ~= nil and X.rowOn(rec) then
			list[#list + 1] = rec.row.frame
		end
		if pic ~= nil and pic.drawn == true then
			list[#list + 1] = pic.frame
		end
		for _, region in ipairs({ rec.parts.portrait or false, rec.parts.nameText or false }) do
			if region and Lit(region) then
				list[#list + 1] = region
			end
		end
	end
	local left, top, right
	for _, region in ipairs(list) do
		local l, t, r = Rect(region)
		if l ~= nil then
			left, top, right = math.min(left or l, l), math.max(top or t, t), math.max(right or r, r)
		end
	end
	return left, top, right
end

local function Saved(name)
	local spots = type(ns.Spots) == "function" and ns.Spots() or nil
	return type(spots) == "table" and type(ns.CleanSpot) == "function" and ns.CleanSpot(spots[name]) ~= nil
end

local function Spot(tot, parent, rec, owner)
	local _, ownTop, ownRight = Block(owner)
	local fromLeft, fromTop = Block(rec)
	local frameLeft, frameTop, frameRight = Rect(tot)
	local baseLeft, baseTop = Rect(parent)
	local scale, parentScale = X.ask(tot, "GetEffectiveScale"), X.ask(parent, "GetEffectiveScale")
	if ownRight == nil or fromLeft == nil or frameLeft == nil or baseLeft == nil
		or not (X.number(scale) and scale > 0 and X.number(parentScale) and parentScale > 0) then
		return nil
	end
	local gap = (GAP.tot + 2 * Thickness(owner.frame)) * parentScale
	local left = ownRight + gap - (fromLeft - frameLeft)
	local top = ownTop - (fromTop - frameTop)
	return (left + frameRight - frameLeft - baseLeft) / scale, (top - baseTop) / scale
end

local JOBS = {}

local function Move(job)
	local tot, parent = Game(job.tot), Game(job.parent)
	if tot == nil or parent == nil or Saved(job.tot) then
		return
	end
	if job.focus and not followed then
		followed = ns.Follow(parent, "SetSmallSize", JOBS.resized) == true
	end
	if InCombatLockdown() then
		Later(job)
		return
	end
	local rec, owner = X.known(tot), X.known(parent)
	local want = not Off(TOT) and Opt("totSpot") == "beside" and rec ~= nil and rec.made and X.active(rec) and owner ~= nil and owner.made
		and X.active(owner)
	if not want then
		Restore(tot)
		return
	end
	local x, y = Spot(tot, parent, rec, owner)
	if x == nil then
		Retry(job)
		return
	end
	job.tries = 0
	Put(tot, { { "TOPRIGHT", parent, "TOPLEFT", x, y } })
end

local function Lift(rec, pic)
	local body = X.joined(rec) and X.body(rec) or nil
	if body == nil then
		return 0
	end
	local _, high = Rect(body)
	local _, low = Rect(pic)
	local scale = X.ask(pic, "GetEffectiveScale")
	if high ~= nil and low ~= nil and X.number(scale) and scale > 0 then
		return math.max(0, (high - low) / scale)
	end
	return nil
end

local function Icons(job)
	local rec = X.known(Game("PlayerFrame"))
	if rec == nil or not rec.made then
		return
	end
	if InCombatLockdown() then
		Later(job)
		return
	end
	local contextual = X.path(rec.frame, "PlayerFrameContent", "PlayerFrameContentContextual")
	local icon, loop = X.path(contextual, "AttackIcon"), X.path(contextual, "PlayerRestLoop")
	local pic, on = rec.pic, X.active(rec)
	local want = on and not Off(ICONS) and Opt("statusIconSpot") == "above" and pic ~= nil and pic.drawn == true and X.squared(rec, on)
	if not want then
		Restore(icon)
		Restore(loop)
		return
	end
	local lift = Lift(rec, pic.frame)
	if lift == nil then
		Retry(job)
		return
	end
	job.tries = 0
	local y = lift + Thickness(rec.frame) + GAP.icon
	Put(icon, { { "BOTTOMRIGHT", pic.frame, "TOPRIGHT", 0, y } })
	Put(loop, { { "BOTTOMRIGHT", pic.frame, "TOPRIGHT", -REST.spill, y + REST.spill },
		{ "TOPLEFT", pic.frame, "TOPRIGHT", -REST.spill - REST.box, y + REST.spill + REST.box } })
end

JOBS.icons = { part = ICONS, run = Icons }
JOBS.target = { part = TOT, run = Move, tot = "TargetFrameToT", parent = "TargetFrame" }
JOBS.focus = { part = TOT, run = Move, tot = "FocusFrameToT", parent = "FocusFrame", focus = true }

function JOBS.resized()
	local tot = Game(JOBS.focus.tot)
	if tot ~= nil and moved[tot] then
		moved[tot], kept[tot] = nil, nil
	end
	X.run(TOT, Move, JOBS.focus)
end

local function OnIcons(rec)
	if rec.kind == "player" then
		Icons(JOBS.icons)
	end
end

local function OnTot(rec)
	if rec.kind ~= "target" and rec.kind ~= "focus" and rec.kind ~= "tot" then
		return
	end
	for _, job in ipairs({ JOBS.target, JOBS.focus }) do
		if rec.frame == Game(job.tot) or rec.frame == Game(job.parent) then
			Move(job)
		end
	end
end

table.insert(X.after.apply, { part = ICONS, fn = OnIcons })
table.insert(X.after.layout, { part = ICONS, fn = OnIcons })
table.insert(X.after.apply, { part = TOT, fn = OnTot })
table.insert(X.after.layout, { part = TOT, fn = OnTot })
