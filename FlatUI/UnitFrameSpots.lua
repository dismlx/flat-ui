local ADDON_NAME, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local ICONS, TOT = "Combat and resting icons", "Target of target position"
local COMBO, MARKS, GROUP = "Combo points", "Target marks", "Raid group number"
local GAP = { icon = 2, tot = 4 }
local REST = { box = 20, spill = 5 }
local RETRY = { tries = 5, wait = 0.2 }
local NEAR = 0.05
local RING = { radius = 39.6, reach = 45, room = 9, low = 0.6, high = 1.2 }
local CAST = { far = -40, x = 43, small = 38, pad = 123, padSmall = 118, y = 5, smallY = 3, gameY = -46, smallGameY = -48, auraX = 18, auraY = -10 }
local MARK = { lift = 1, quest = 3, name = -13, pad = 4 }
local TELL = { tot = "Flat UI: the target of target frame moves when the fight ends.", icons = "Flat UI: the combat and resting icons move when the fight ends." }

local kept = setmetatable({}, { __mode = "k" })
local moved = setmetatable({}, { __mode = "k" })
local cast = setmetatable({}, { __mode = "k" })
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

local JOBS = {}

local function Ringed()
	local ok, _, class = pcall(UnitClass, "player")
	if not ok or ns.IsSecret(class) or (class ~= "ROGUE" and class ~= "DRUID") then
		return false
	end
	local kinds = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.PowerType or nil
	local kind = type(kinds) == "table" and kinds.ComboPoints or nil
	if kind ~= nil and type(UnitPowerMax) == "function" then
		local got, most = pcall(UnitPowerMax, "player", kind)
		if got and ns.Finite(most) then
			return most > 0
		end
	end
	return true
end

local function RingRight(parentScale)
	local job = JOBS.combo
	if job.at == nil or job.k == nil or not Ringed() then
		return nil
	end
	local left, _, right = Rect(job.at)
	if left == nil then
		return nil
	end
	local centre = job.round and (left + right) / 2 or right
	return centre + RING.reach * job.k * parentScale
end

local function Spot(tot, parent, rec, owner, ring)
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
	local edge = ownRight + gap
	local reach = ring and RingRight(parentScale) or nil
	if reach ~= nil then
		edge = math.max(edge, reach + gap)
	end
	local left = edge - (fromLeft - frameLeft)
	local top = ownTop - (fromTop - frameTop)
	return (left + frameRight - frameLeft - baseLeft) / scale, (top - baseTop) / scale
end

local function Cast(bar, game)
	if bar == nil or ns.IsSecret(bar) then
		return
	end
	local job = bar == Game(JOBS.focus.bar) and JOBS.focus or JOBS.target
	local tot, parent = Game(job.tot), Game(job.parent)
	if tot == nil or parent == nil or bar ~= Game(job.bar) then
		return
	end
	local shown = X.ask(tot, "IsShown") == true
	local beside = moved[tot] == true and shown and not Off(TOT) and Opt("totSpot") == "beside"
	if (game or not cast[bar]) and not beside then
		cast[bar] = nil
		return
	end
	if InCombatLockdown() and type(ns.MaybeProtected) == "function" and ns.MaybeProtected(bar) then
		if not job.castQueued then
			job.castQueued = true
			ns.OutOfCombat(function()
				job.castQueued = nil
				X.run(TOT, Cast, Game(job.bar))
			end)
		end
		return
	end
	local list = Points(bar)
	local p = list ~= nil and #list == 1 and list[1] or nil
	if p == nil or p[1] ~= "TOPLEFT" or p[2] ~= parent or p[3] ~= "BOTTOMLEFT" then
		return
	end
	local small = math.abs(p[4] - CAST.small) < 0.5 or math.abs(p[4] - CAST.padSmall) < 0.5
	if not beside then
		cast[bar] = nil
		if shown and p[5] > CAST.far then
			pcall(Anchor, bar, { { "TOPLEFT", parent, "BOTTOMLEFT", p[4], small and CAST.smallGameY or CAST.gameY } })
		end
		return
	end
	if p[5] >= CAST.far then
		return
	end
	local auras = X.path(parent, "TargetFrameContent", "TargetFrameContentContextual", "Auras")
	local below = auras ~= nil and Points(auras) or nil
	local tall = auras ~= nil and X.ask(auras, "GetHeight") or nil
	local spot
	if below ~= nil and below[1][1] == "TOPLEFT" and X.ask(auras, "IsShown") == true and X.number(tall) and tall > 1 then
		spot = { { "TOPLEFT", auras, "BOTTOMLEFT", CAST.auraX, CAST.auraY } }
	else
		spot = { { "TOPLEFT", parent, "BOTTOMLEFT", small and CAST.small or CAST.x, small and CAST.smallY or CAST.y } }
	end
	if pcall(Anchor, bar, spot) then
		cast[bar] = true
	end
end

local function Move(job)
	local tot, parent = Game(job.tot), Game(job.parent)
	if tot == nil or parent == nil or Saved(job.tot) then
		return
	end
	if job.focus and not followed then
		followed = ns.Follow(parent, "SetSmallSize", JOBS.resized) == true
	end
	if not job.cast then
		job.cast = ns.Follow(Game(job.bar), "AdjustPosition", JOBS.cast) == true
	end
	local rec, owner = X.known(tot), X.known(parent)
	local want = not Off(TOT) and Opt("totSpot") == "beside" and rec ~= nil and rec.made and X.active(rec) and owner ~= nil and owner.made
		and X.active(owner)
	if InCombatLockdown() then
		if (want and true or false) ~= (moved[tot] == true) then
			X.tell(TELL.tot)
		end
		Later(job)
		return
	end
	if not want then
		Restore(tot)
		Cast(Game(job.bar))
		return
	end
	local x, y = Spot(tot, parent, rec, owner, job.ring)
	if x == nil then
		Retry(job)
		return
	end
	job.tries = 0
	Put(tot, { { "TOPRIGHT", parent, "TOPLEFT", x, y } })
	Cast(Game(job.bar))
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
	local contextual = X.path(rec.frame, "PlayerFrameContent", "PlayerFrameContentContextual")
	local icon, loop = X.path(contextual, "AttackIcon"), X.path(contextual, "PlayerRestLoop")
	local pic, on = rec.pic, X.active(rec)
	local want = on and not Off(ICONS) and Opt("statusIconSpot") == "above" and pic ~= nil and pic.drawn == true and X.squared(rec, on)
	if InCombatLockdown() then
		if icon ~= nil and (want and true or false) ~= (moved[icon] == true) then
			X.tell(TELL.icons)
		end
		Later(job)
		return
	end
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

local function Bar(rec)
	local health = rec.byRole.health
	return health ~= nil and health.target or rec.parts.health
end

local function Over(rec)
	if X.joined(rec) and X.body(rec) ~= nil then
		return X.body(rec)
	elseif rec.row ~= nil and X.rowOn(rec) then
		return rec.row.frame
	end
	return Bar(rec)
end

local function Unring(job, combo)
	Restore(combo)
	if job.scale ~= nil then
		pcall(combo.SetScale, combo, job.scale)
		job.scale = nil
	end
	job.at, job.k, job.round = nil, nil, nil
end

local function Combo(job)
	local combo, rec = Game("ComboFrame"), X.known(Game("TargetFrame"))
	if combo == nil or rec == nil or not rec.made then
		return
	end
	if InCombatLockdown() then
		Later(job)
		return
	end
	local pic, bar = rec.pic, Bar(rec)
	local drawn = pic ~= nil and pic.drawn == true
	if not (X.active(rec) and not Off(COMBO) and (drawn or bar ~= nil)) then
		Unring(job, combo)
		return
	end
	if job.scale == nil then
		local scale = X.ask(combo, "GetScale")
		job.scale = X.number(scale) and scale > 0 and scale or 1
	end
	local k = job.scale
	if drawn then
		k = math.min(RING.high, math.max(RING.low, ((pic.side or 0) / 2 + 2 * Thickness(rec.frame) + RING.room) / RING.radius))
		Put(combo, { { "CENTER", pic.frame, "CENTER", 0, 0 } })
	else
		Put(combo, { { "CENTER", bar, "RIGHT", 0, 0 } })
	end
	if not moved[combo] then
		Unring(job, combo)
		return
	end
	pcall(combo.SetScale, combo, k)
	job.at, job.k, job.round = drawn and pic.frame or bar, k, drawn
end

local function Marks(job)
	local rec = X.known(Game(job.parent))
	if rec == nil or not rec.made then
		return
	end
	if InCombatLockdown() then
		Later(job)
		return
	end
	local contextual = X.path(rec.frame, "TargetFrameContent", "TargetFrameContentContextual")
	local raid, quest, star = X.path(contextual, "RaidTargetIcon"), X.path(contextual, "QuestIcon"), X.path(contextual, "BossIcon")
	if not (X.active(rec) and not Off(MARKS) and Opt("squarePortrait") == true) then
		Restore(raid)
		Restore(quest)
		if job.faded then
			ns.SetFaded(star, false)
			job.faded = nil
		end
		return
	end
	local pic, bar, t = rec.pic, Bar(rec), Thickness(rec.frame)
	if pic ~= nil and pic.drawn == true then
		Put(raid, { { "BOTTOM", pic.frame, "TOP", 0, (Lift(rec, pic.frame) or 0) + t + MARK.lift } })
		Put(quest, { { "CENTER", pic.frame, "BOTTOMRIGHT", -MARK.quest, MARK.quest } })
	else
		Put(raid, { { "BOTTOM", Over(rec), "TOPRIGHT", MARK.name, t + MARK.lift } })
		Put(quest, { { "CENTER", bar, "BOTTOMRIGHT", -MARK.quest, MARK.quest } })
	end
	local fade = Opt("elite") == true or Opt("kindMark") == true or Opt("kindWord") == true
	if fade or job.faded then
		ns.SetFaded(star, fade)
		job.faded = fade or nil
	end
end

local function Art(job, indicator, text)
	if job.art ~= nil then
		return job.art
	end
	local got = { pcall(indicator.GetRegions, indicator) }
	if not got[1] then
		return {}
	end
	job.art = {}
	for index = 2, #got do
		local region = got[index]
		if region ~= nil and region ~= text and not ns.IsSecret(region) then
			job.art[#job.art + 1] = region
		end
	end
	return job.art
end

local function Group(job)
	local rec = X.known(Game("PlayerFrame"))
	if rec == nil or not rec.made then
		return
	end
	if InCombatLockdown() then
		Later(job)
		return
	end
	local indicator = X.path(rec.frame, "PlayerFrameContent", "PlayerFrameContentContextual", "GroupIndicator")
	local text = Game("PlayerFrameGroupIndicatorText")
	if indicator == nil or text == nil then
		return
	end
	local want = X.active(rec) and not Off(GROUP) and Opt("squarePortrait") == true
	if want or job.styled then
		for _, region in ipairs(Art(job, indicator, text)) do
			ns.SetFaded(region, want)
		end
	end
	if not want then
		if job.styled then
			ns.TextStyle(text, {})
			pcall(text.SetAlpha, text, job.alpha or 1)
			job.styled = nil
		end
		Restore(text)
		return
	end
	if not job.styled then
		local alpha = X.ask(text, "GetAlpha")
		job.alpha = X.number(alpha) and alpha or nil
	end
	ns.TextStyle(text, type(X.ownSpec) == "function" and X.ownSpec("name", {}) or {})
	pcall(text.SetAlpha, text, 1)
	job.styled = true
	Put(text, { { "BOTTOMRIGHT", Over(rec), "TOPRIGHT", -MARK.pad, Thickness(rec.frame) + MARK.lift } })
end

JOBS.icons = { part = ICONS, run = Icons }
JOBS.target = { part = TOT, run = Move, tot = "TargetFrameToT", parent = "TargetFrame", bar = "TargetFrameSpellBar", ring = true }
JOBS.focus = { part = TOT, run = Move, tot = "FocusFrameToT", parent = "FocusFrame", bar = "FocusFrameSpellBar", focus = true }
JOBS.combo = { part = COMBO, run = Combo }
JOBS.targetMarks = { part = MARKS, run = Marks, parent = "TargetFrame" }
JOBS.focusMarks = { part = MARKS, run = Marks, parent = "FocusFrame" }
JOBS.group = { part = GROUP, run = Group }

function JOBS.resized()
	local tot = Game(JOBS.focus.tot)
	if tot ~= nil and moved[tot] then
		moved[tot], kept[tot] = nil, nil
	end
	X.run(TOT, Move, JOBS.focus)
end

function JOBS.cast(bar)
	X.run(TOT, Cast, bar, true)
end

local function OnIcons(rec)
	if rec.kind == "player" then
		Icons(JOBS.icons)
	end
end

local function OnGroup(rec)
	if rec.kind == "player" then
		Group(JOBS.group)
	end
end

local function OnCombo(rec)
	if rec.kind == "target" then
		Combo(JOBS.combo)
	end
end

local function OnMarks(rec)
	if rec.kind == "target" then
		Marks(JOBS.targetMarks)
	elseif rec.kind == "focus" then
		Marks(JOBS.focusMarks)
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

local function Where(region, job, there, waits, game)
	if region ~= nil and moved[region] then
		return there
	elseif job.queued then
		return waits
	end
	return game
end

ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.IsStopped(KEY) then
		return {}
	end
	local lines = {}
	local tot = Game(JOBS.target.tot)
	if tot ~= nil and X.known(tot) ~= nil then
		local where = Saved(JOBS.target.tot) and "at its saved spot"
			or Where(tot, JOBS.target, "beside the target frame", "waits for the fight to end", "at the game's spot")
		lines[#lines + 1] = "Target of target: " .. where
	end
	local player = X.known(Game("PlayerFrame"))
	local icon = player ~= nil and X.path(player.frame, "PlayerFrameContent", "PlayerFrameContentContextual", "AttackIcon") or nil
	if icon ~= nil then
		lines[#lines + 1] = "Combat and resting icons: " .. Where(icon, JOBS.icons, "above the portrait", "move when the fight ends", "where the game draws them")
	end
	if Ringed() and X.known(Game("TargetFrame")) ~= nil then
		local there = JOBS.combo.round and "round the target picture" or "at the right end of the target's health bar"
		lines[#lines + 1] = "Combo points: " .. Where(Game("ComboFrame"), JOBS.combo, there, "move when the fight ends", "where the game draws them")
	end
	return lines
end)

table.insert(X.after.apply, { part = ICONS, fn = OnIcons })
table.insert(X.after.layout, { part = ICONS, fn = OnIcons })
table.insert(X.after.apply, { part = GROUP, fn = OnGroup })
table.insert(X.after.layout, { part = GROUP, fn = OnGroup })
table.insert(X.after.apply, { part = COMBO, fn = OnCombo })
table.insert(X.after.layout, { part = COMBO, fn = OnCombo })
table.insert(X.after.apply, { part = MARKS, fn = OnMarks })
table.insert(X.after.layout, { part = MARKS, fn = OnMarks })
table.insert(X.after.apply, { part = TOT, fn = OnTot })
table.insert(X.after.layout, { part = TOT, fn = OnTot })
