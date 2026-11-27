local _, ns = ...

local KEY = "threat"
local T = ns.ThreatList
if type(T) ~= "table" then
	return
end

local PAD, GAP, INSET, MARK_GAP = 4, 2, 4, 2
local STEP, TURN = 0.2, 3
local RAID_STEP, ROSTER_TIME = 0.5, 2
local MOST_ROWS, PLATES, MOST_SHARE = 10, 40, 999
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MARKERS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local TRACK = { 0.2, 0.2, 0.2, 0.5 }
local DIM = { 0.66, 0.68, 0.62 }
local MINE = { 1, 1, 1, 0.9 }
local GREY = { 0.55, 0.55, 0.55 }
local EVEN, EDGE = { 1, 1, 1, 0.35 }, { 1, 1, 1, 0.16 }
local WASH, PULSE_LOW, PET, LIGHT = 0.45, 0.12, 0.7, 0.35
local PULSES = { lost = 0.4, slipping = 0.95 }
local REARM, BUCKET = 5, 5
local BELOW, SMALL, RULE = 4, 0.8, 0.3
local RANK = { lost = 1, slipping = 2, held = 3, theirs = 4, withheld = 5 }
local ROWS = { lost = "threatBad", slipping = "threatTransition", held = "threatGood", theirs = "threatTankColour" }
local ALPHA = { lost = 1, slipping = 1, held = 0.72, theirs = 0.55, withheld = 0.72 }
local NAMES = { lost = { 1, 1, 1 }, slipping = { 1, 1, 1 }, held = { 0.85, 0.86, 0.82 }, theirs = { 0.78, 0.8, 0.76 }, withheld = { 0.85, 0.86, 0.82 } }
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local WITHHELD = "The game withholds the threat on this enemy."
local TIP_CLICK = "Click the enemy's nameplate to target it."
local SAMPLE_MOBS = { { "Defias Pillager", 8 }, { "Defias Taskmaster", 7 }, { "Defias Wizard", 2 }, { "Defias Miner" } }
local SAMPLE_LOST = { { "Priest", "PRIEST" }, { "Mage", "MAGE" } }
local SAMPLE_SLIP = { "Rogue", "ROGUE" }
local SAMPLE_HELD = { { "Hunter", "HUNTER" }, { "Warlock", "WARLOCK" } }
local IsSecret = ns.IsSecret

local M = { rows = {}, known = {}, seq = 0, active = false, count = 0 }
ns.ThreatMobs = M

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

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

local function Number(key, default)
	local value = Opt(key)
	return ns.Finite(value) and value or default
end

local function Look(name, ...)
	local look = ns.ThreatLook
	local fn = type(look) == "table" and look[name] or nil
	if type(fn) == "function" then
		return fn(...)
	end
	return nil
end

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

local function TextHeight(height)
	return math.max(7, math.min(14, height - 4))
end

local function Glide(bar, value, now)
	local list = not now and type(Enum) == "table" and Enum.StatusBarInterpolation or nil
	local how = type(list) == "table" and list.ExponentialEaseOut or nil
	if how ~= nil and pcall(bar.SetValue, bar, value, how) then
		return true
	end
	return (pcall(bar.SetValue, bar, value))
end

local function Cell(icon, index)
	if type(icon.SetSpriteSheetCell) == "function" then
		return (pcall(icon.SetSpriteSheetCell, icon, index, 4, 4))
	elseif ns.Finite(index) then
		local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
		return (pcall(icon.SetTexCoord, icon, column / 4, (column + 1) / 4, row / 4, (row + 1) / 4))
	end
	return false
end

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

local function StateColour(state)
	local row = ROWS[state]
	if row then
		local ok, r, g, b = pcall(ns.Colour, "nameplates." .. row)
		if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
			return r, g, b
		end
	end
	return GREY[1], GREY[2], GREY[3]
end

local function Lighter(r, g, b, k)
	k = k or LIGHT
	return r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k
end

local function Count(fn, most)
	local value = Ask(fn)
	if ns.Finite(value) and value > 0 then
		return math.min(math.floor(value), most)
	end
	return 0
end

local function Roster()
	local list = {}
	local function Add(unit, pet)
		list[#list + 1] = { unit = unit, owner = unit }
		list[#list + 1] = { unit = pet, owner = unit, pet = true }
	end
	if Ask(IsInRaid) == true then
		for index = 1, Count(GetNumGroupMembers, 40) do
			Add("raid" .. index, "raidpet" .. index)
		end
	else
		Add("player", "pet")
		if Ask(IsInGroup) == true then
			for index = 1, Count(GetNumSubgroupMembers, 4) do
				Add("party" .. index, "partypet" .. index)
			end
		end
	end
	return list
end

local function Named(value)
	return IsSecret(value) or (type(value) == "string" and value ~= "")
end

local function Hex(r, g, b)
	local function Byte(value)
		return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
	end
	return ("%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

function M.View()
	return Opt("view") == "mobs"
end

function M.Both()
	local view = Opt("view")
	return view ~= "mobs" and view ~= "group"
end

local function Tanking(read)
	local tanking = read.tanking
	if not IsSecret(tanking) and type(tanking) == "boolean" then
		return tanking
	end
	if ns.Finite(read.status) then
		return read.status >= 2
	end
	return nil
end

local function ShareOf(read, me, raw)
	if raw and ns.Finite(read.raw) then
		return math.min(MOST_SHARE, math.max(0, read.raw))
	end
	if me and ns.Finite(read.value) and ns.Finite(me.value) and me.value > 0 then
		return math.min(MOST_SHARE, math.max(0, read.value / me.value * 100))
	end
	return nil
end

local function HolderShare(holder, me)
	if me and ns.Finite(holder.value) and ns.Finite(me.value) and me.value > 0 then
		return math.min(MOST_SHARE, math.max(0, holder.value / me.value * 100))
	end
	if me and ns.Finite(me.raw) and me.raw > 0 then
		return math.min(MOST_SHARE, 10000 / me.raw)
	end
	return nil
end

local function Who(read)
	local who = read.who
	local member = who.member
	local ok, name = pcall(UnitName, who.unit)
	if not ok or not Named(name) then
		name = nil
	end
	local r, g, b = ns.ClassColourOf(member.pet and member.owner or who.unit)
	if not r then
		r, g, b = GREY[1], GREY[2], GREY[3]
	elseif member.pet then
		r, g, b = r * PET, g * PET, b * PET
	end
	return { name = name, plain = not IsSecret(name) and name or nil, r = r, g = g, b = b }
end

local function Bar(share, full)
	if ns.Finite(share) then
		return math.max(0, math.min(100, 100 - share / 2))
	end
	return full
end

function M.Held(mob, me, others, calm, byValue)
	local top, share, hidden = nil, nil, false
	for _, read in ipairs(others) do
		if not (calm and read.who.tank) then
			local value = ShareOf(read, me, not byValue)
			if value == nil then
				hidden = true
			elseif share == nil or value > share then
				top, share = read, value
			end
		end
	end
	local slip = Number("slipAt", 80)
	local was = M.known[mob.key]
	if was and was.state == "slipping" then
		slip = slip - REARM
	end
	local state = "held"
	if share ~= nil and share >= slip then
		state = "slipping"
	elseif share == nil and hidden and ns.Finite(me.status) and me.status == 2 then
		state = "slipping"
	end
	mob.state, mob.share, mob.bar = state, share, Bar(share, 100)
	mob.who = top and Who(top) or nil
end

function M.Taken(mob, me, holder, calm)
	local share = HolderShare(holder, me)
	mob.state = (calm and holder.who.tank) and "theirs" or "lost"
	mob.share, mob.bar, mob.who = share, Bar(share, 0), Who(holder)
end

function M.Unclear(mob, me, others, calm)
	local top, best = nil, nil
	for _, read in ipairs(others) do
		if ns.Finite(read.value) and (best == nil or read.value > best) then
			top, best = read, read.value
		end
	end
	if me and (#others == 0 or (ns.Finite(me.value) and (best == nil or me.value >= best))) then
		M.Held(mob, me, others, calm, true)
	elseif top and (me == nil or ns.Finite(me.value)) then
		M.Taken(mob, me, top, calm)
	else
		mob.state, mob.bar = "withheld", 0
		if me and (IsSecret(me.scaled) or ns.Finite(me.scaled)) then
			mob.bar, mob.secret = me.scaled, me.scaled
		end
	end
end

function M.Judge(unit, members)
	local me, others = nil, {}
	for _, who in ipairs(members) do
		local ok, tanking, status, scaled, raw, value = pcall(UnitDetailedThreatSituation, who.unit, unit)
		if ok and (IsSecret(status) or status ~= nil) then
			local read = { who = who, tanking = tanking, status = status, scaled = scaled, raw = raw, value = value }
			if who.me then
				me = read
			else
				others[#others + 1] = read
			end
		end
	end
	if me == nil and #others == 0 then
		return nil
	end
	local ok, name = pcall(UnitName, unit)
	if not ok or not Named(name) then
		name = nil
	end
	local okMark, marker = pcall(GetRaidTargetIndex, unit)
	if not okMark then
		marker = nil
	end
	local mob = { unit = unit, key = Ask(UnitGUID, unit) or unit, target = Ask(UnitIsUnit, unit, "target") == true }
	mob.name, mob.marker = name, marker
	local calm = Opt("otherTanks") ~= false
	local mine = me and Tanking(me)
	local holder
	if mine ~= true then
		for _, read in ipairs(others) do
			if Tanking(read) == true then
				holder = read
				break
			end
		end
	end
	if mine == true then
		M.Held(mob, me, others, calm, false)
	elseif holder then
		M.Taken(mob, me, holder, calm)
	else
		M.Unclear(mob, me, others, calm)
	end
	return mob
end

function M.Members()
	local list = {}
	local calm = Opt("otherTanks") ~= false
	for _, member in ipairs(Roster()) do
		if Ask(UnitExists, member.unit) == true then
			local own = member.pet and Ask(UnitIsUnit, member.owner, "player") == true
			if not own then
				local me = not member.pet and Ask(UnitIsUnit, member.unit, "player") == true
				local who = { unit = member.unit, member = member, me = me }
				who.tank = calm and not me and T.OtherTank({ member = member }) == true
				list[#list + 1] = who
			end
		end
	end
	return list
end

function M.Roster()
	local now, calm = Ask(GetTime), Opt("otherTanks") ~= false
	local at = M.rosterAt
	if M.roster and M.rosterCalm == calm and ns.Finite(now) and ns.Finite(at) and now >= at and now - at < ROSTER_TIME then
		return M.roster
	end
	M.roster, M.rosterAt, M.rosterCalm = M.Members(), now, calm
	return M.roster
end

function M.Step()
	return Ask(IsInRaid) == true and RAID_STEP or STEP
end

function M.Read()
	local list, members = {}, M.Roster()
	if #members == 0 then
		return list
	end
	for index = 1, PLATES do
		local unit = "nameplate" .. index
		if T.Enemy(unit) and Ask(UnitAffectingCombat, unit) == true then
			local mob = M.Judge(unit, members)
			if mob then
				list[#list + 1] = mob
			end
		end
	end
	return list
end

local function SampleWho(spec)
	local r, g, b = ClassRGB(spec[2])
	if not r then
		r, g, b = GREY[1], GREY[2], GREY[3]
	end
	return { name = spec[1], plain = spec[1], r = r, g = g, b = b }
end

function M.Samples()
	local step = T.step or 0
	local turn, wiggle = math.floor(step / TURN), step % TURN
	local lostAt, slipAt = turn % #SAMPLE_MOBS + 1, (turn + 1) % #SAMPLE_MOBS + 1
	local edge = Number("slipAt", 80)
	local list, held = {}, 0
	for index, spec in ipairs(SAMPLE_MOBS) do
		local mob = { key = "sample" .. index, name = spec[1], marker = spec[2], target = index == 1 }
		if index == lostAt then
			mob.state, mob.share = "lost", 104 + wiggle * 4
			mob.who = SampleWho(SAMPLE_LOST[turn % #SAMPLE_LOST + 1])
		elseif index == slipAt then
			mob.state, mob.share = "slipping", math.min(99, edge + 2 + wiggle * 4)
			mob.who = SampleWho(SAMPLE_SLIP)
		else
			held = held + 1
			mob.state, mob.share = "held", math.max(5, math.min(edge - 8, 30 + index * 6 + wiggle * 3))
			mob.who = SampleWho(SAMPLE_HELD[(held - 1) % #SAMPLE_HELD + 1])
		end
		mob.bar = Bar(mob.share, 0)
		list[#list + 1] = mob
	end
	return list
end

function M.Spares()
	local step = T.step or 0
	local turn, wiggle = math.floor(step / TURN), step % TURN
	local edge = Number("slipAt", 80)
	local spares, list = #SAMPLE_MOBS - 1, {}
	for index = 2, #SAMPLE_MOBS do
		local spec = SAMPLE_MOBS[index]
		local at = (index - 2 - turn) % spares
		local mob = { key = "sample" .. index, name = spec[1], marker = spec[2], target = false }
		if at == 0 then
			mob.state, mob.share = "lost", 104 + wiggle * 4
			mob.who = SampleWho(SAMPLE_LOST[turn % #SAMPLE_LOST + 1])
		elseif at == 1 then
			mob.state, mob.share = "slipping", math.min(99, edge + 2 + wiggle * 4)
			mob.who = SampleWho(SAMPLE_SLIP)
		else
			mob.state, mob.share = "held", math.max(5, edge - 20)
			mob.who = SampleWho(SAMPLE_HELD[1])
		end
		mob.bar = Bar(mob.share, 0)
		list[#list + 1] = mob
	end
	return list
end

local function Before(a, b)
	local ra, rb = RANK[a.state] or 9, RANK[b.state] or 9
	if ra ~= rb then
		return ra < rb
	elseif a.close ~= b.close then
		return a.close > b.close
	end
	return a.seq < b.seq
end

function M.Rank(list)
	local lost = 0
	for _, mob in ipairs(list) do
		local rec = M.known[mob.key]
		if rec == nil then
			M.seq = M.seq + 1
			rec = { seq = M.seq }
			M.known[mob.key] = rec
		end
		mob.seq = rec.seq
		mob.turned = mob.state == "lost" and (rec.state == "held" or rec.state == "slipping")
		mob.back = mob.state == "held" and rec.state == "lost"
		rec.state = mob.state
		mob.close = mob.state == "slipping" and ns.Finite(mob.share) and math.floor(mob.share / BUCKET) or 0
		if mob.state == "lost" then
			lost = lost + 1
		end
	end
	table.sort(list, Before)
	return lost
end

local function Pulse(texture, seconds)
	local ok, group = pcall(function()
		local made = Own(texture:CreateAnimationGroup())
		made:SetLooping("BOUNCE")
		local fade = Own(made:CreateAnimation("Alpha"))
		fade:SetFromAlpha(PULSE_LOW)
		fade:SetToAlpha(1)
		fade:SetDuration(seconds)
		return made
	end)
	return ok and type(group) == "table" and group or nil
end

local function Wash(row, state, r, g, b)
	local pulsing = state == "lost" or state == "slipping"
	for kind, group in pairs(row.pulses) do
		if kind ~= state or not pulsing then
			pcall(group.Stop, group)
		end
	end
	if not pulsing then
		row.wash:Hide()
		return
	end
	row.wash:SetVertexColor(r, g, b, WASH)
	row.wash:Show()
	local group = row.pulses[state]
	if group and not group:IsPlaying() then
		pcall(group.Play, group)
	end
end

local function Mark(row, index)
	local shown = false
	if IsSecret(index) or (ns.Finite(index) and index >= 1 and index <= 8) then
		shown = Cell(row.mark, index)
	end
	row.mark:SetShown(shown)
	if row.marked ~= shown then
		row.marked = shown
		row.name:ClearAllPoints()
		if shown then
			row.name:SetPoint("LEFT", row.mark, "RIGHT", MARK_GAP, 0)
		else
			row.name:SetPoint("LEFT", row.bar, "LEFT", INSET, 0)
		end
		row.name:SetPoint("RIGHT", row.share, "LEFT", -INSET, 0)
	end
end

local function Share(row, mob)
	local text, who = row.share, mob.who
	local pct = ns.Finite(mob.share) and math.floor(mob.share + 0.5) or nil
	if mob.state == "withheld" then
		text:SetTextColor(GREY[1], GREY[2], GREY[3], 1)
		local value = mob.secret
		if not (IsSecret(value) or ns.Finite(value)) or not pcall(text.SetFormattedText, text, "%.0f%%", value) then
			text:SetText("")
		end
		return
	end
	if mob.state == "held" or who == nil then
		text:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
		text:SetText(pct and ("%d%%"):format(pct) or "")
		return
	end
	text:SetTextColor(1, 1, 1, 1)
	local colour = "|cff" .. Hex(Lighter(who.r, who.g, who.b, 0.15)) .. "%s|r"
	local ok
	if not Named(who.name) then
		ok = false
	elseif pct then
		ok = pcall(text.SetFormattedText, text, colour .. " %d%%", who.name, pct)
	else
		ok = pcall(text.SetFormattedText, text, colour, who.name)
	end
	if not ok then
		text:SetText(pct and ("%d%%"):format(pct) or "")
	end
end

function M.Words(mob)
	local who = mob.who and mob.who.plain
	local pct = ns.Finite(mob.share) and math.floor(mob.share + 0.5) or nil
	local state = mob.state
	if state == "lost" then
		if who and pct then
			return ("Lost: %s holds it with %d%% of your threat."):format(who, pct)
		end
		return who and ("Lost: %s holds it."):format(who) or "Lost: someone else holds it."
	elseif state == "slipping" then
		if who and pct then
			return ("Slipping: %s is at %d%% of your threat."):format(who, pct)
		end
		return "Slipping: someone is past your threat or close to it."
	elseif state == "held" then
		return pct and ("Held: the closest is at %d%% of your threat."):format(pct) or "Held."
	elseif state == "theirs" then
		return who and ("Held by %s, another tank."):format(who) or "Held by another tank."
	end
	return WITHHELD
end

function M.Tip(row, owner)
	local mob, tip = row.mob, GameTooltip
	if type(mob) ~= "table" or ns.Forbidden(tip) then
		return
	end
	tip:SetOwner(owner, "ANCHOR_LEFT")
	if not Named(mob.name) or not pcall(tip.AddLine, tip, mob.name, 1, 1, 1) then
		tip:AddLine("Enemy", 1, 1, 1)
	end
	local r, g, b = StateColour(mob.state)
	tip:AddLine(M.Words(mob), r, g, b, true)
	if mob.target then
		tip:AddLine("Your target", 1, 1, 1)
	end
	tip:AddLine(TIP_CLICK, DIM[1], DIM[2], DIM[3], true)
	tip:Show()
	row.tipped = true
end

function M.Untip(row)
	if not row.tipped then
		return
	end
	row.tipped = nil
	local tip = GameTooltip
	if not ns.Forbidden(tip) then
		local ok, owned = pcall(tip.IsOwned, tip, row.bar)
		if ok and owned == true then
			tip:Hide()
		end
	end
end

function M.Retip(row)
	if not row.tipped then
		return
	end
	local tip = GameTooltip
	local ok, owned = false, false
	if not ns.Forbidden(tip) then
		ok, owned = pcall(tip.IsOwned, tip, row.bar)
	end
	if ok and owned == true then
		M.Tip(row, row.bar)
	else
		row.tipped = nil
	end
end

local function Hover(row)
	local bar = row.bar
	if type(bar.SetMouseMotionEnabled) ~= "function" or type(bar.SetMouseClickEnabled) ~= "function" then
		return
	end
	if not (pcall(bar.SetMouseMotionEnabled, bar, true) and pcall(bar.SetMouseClickEnabled, bar, false)) then
		pcall(bar.EnableMouse, bar, false)
		return
	end
	bar:SetScript("OnEnter", function(self)
		ns.Try(KEY, M.Tip, row, self)
	end)
	bar:SetScript("OnLeave", function()
		pcall(M.Untip, row)
	end)
end

function M.Row(index)
	local row = M.rows[index]
	if row then
		return row
	end
	local bar = Own(CreateFrame("StatusBar", nil, T.Frame()))
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	bar:Hide()
	local track = Own(bar:CreateTexture(nil, "BACKGROUND", nil, -7))
	track:SetAllPoints(bar)
	track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
	local even = Own(bar:CreateTexture(nil, "OVERLAY", nil, 1))
	even:SetColorTexture(EVEN[1], EVEN[2], EVEN[3], EVEN[4])
	local edge = Own(bar:CreateTexture(nil, "OVERLAY", nil, 1))
	edge:SetColorTexture(EDGE[1], EDGE[2], EDGE[3], EDGE[4])
	local mark = Own(bar:CreateTexture(nil, "OVERLAY", nil, 3))
	mark:SetTexture(MARKERS)
	mark:SetPoint("LEFT", bar, "LEFT", MARK_GAP, 0)
	mark:SetSize(12, 12)
	mark:Hide()
	local share = ns.OwnText(bar, "OVERLAY", FONT)
	share:SetJustifyH("RIGHT")
	share:SetWordWrap(false)
	share:SetPoint("RIGHT", bar, "RIGHT", -INSET, 0)
	local name = ns.OwnText(bar, "OVERLAY", FONT)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	name:SetPoint("LEFT", bar, "LEFT", INSET, 0)
	name:SetPoint("RIGHT", share, "LEFT", -INSET, 0)
	local mine = Own(CreateFrame("Frame", nil, bar))
	mine:SetAllPoints(bar)
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local line = Own(mine:CreateTexture(nil, "OVERLAY", nil, 7))
		line:SetColorTexture(MINE[1], MINE[2], MINE[3], MINE[4])
		line:SetPoint(side[1], mine, side[1], 0, 0)
		line:SetPoint(side[2], mine, side[2], 0, 0)
		if side[3] then
			line:SetHeight(1)
		else
			line:SetWidth(1)
		end
	end
	mine:Hide()
	local wash = Own(bar:CreateTexture(nil, "OVERLAY", nil, -8))
	wash:SetAllPoints(bar)
	wash:SetColorTexture(1, 1, 1, 1)
	wash:Hide()
	row = { bar = bar, track = track, even = even, edge = edge, mark = mark, share = share, name = name, mine = mine, wash = wash,
		pulses = { lost = Pulse(wash, PULSES.lost), slipping = Pulse(wash, PULSES.slipping) } }
	M.rows[index] = row
	Look("Dress", row)
	Hover(row)
	return row
end

local function Paint(row, file, text, height)
	if row.file ~= file then
		local ok, done = pcall(row.bar.SetStatusBarTexture, row.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(row.bar.SetStatusBarTexture, row.bar, WHITE)
		end
		row.file = file
	end
	row.name:SetTextHeight(text)
	row.share:SetTextHeight(text)
	local size = math.max(6, height - 2)
	row.mark:SetSize(size, size)
end

local function Tick(texture, bar, x)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
	texture:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
	texture:SetWidth(1)
end

function M.Line()
	if not M.more then
		local more = ns.OwnText(T.Frame(), "OVERLAY", FONT)
		more:SetJustifyH("LEFT")
		more:SetWordWrap(false)
		more:Hide()
		M.more = more
	end
	return M.more
end

function M.Layout(n, extra)
	local width, height = Number("barWidth", 180), Number("barHeight", 16)
	local text = TextHeight(height)
	local file = ns.BarTexture(Opt("barTexture")) or WHITE
	for index = 1, n do
		Paint(M.Row(index), file, text, height)
	end
	T.title:SetTextHeight(text)
	T.marker:SetSize(text + 2, text + 2)
	local slip = Number("slipAt", 80)
	local key = ("%s:%s:%s:%s:%s"):format(n, width, height, extra and 1 or 0, slip)
	if M.laid == key and T.laid == "mobs" then
		return
	end
	M.laid, T.laid = key, "mobs"
	local top = PAD + text + 2 + GAP
	for index = 1, n do
		local row = M.rows[index]
		local bar = row.bar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PAD, -(top + (index - 1) * (height + GAP)))
		bar:SetSize(width, height)
		Tick(row.even, bar, width / 2)
		Tick(row.edge, bar, width * (100 - slip / 2) / 100)
	end
	Look("Laid", M.rows, n, PAD, top, height + GAP, width)
	local tall = top + n * height + (n - 1) * GAP + PAD
	if extra then
		local more = M.Line()
		more:SetTextHeight(text)
		more:ClearAllPoints()
		more:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PAD + INSET, -(top + n * (height + GAP)))
		more:SetPoint("TOPRIGHT", T.frame, "TOPRIGHT", -(PAD + INSET), -(top + n * (height + GAP)))
		tall = tall + GAP + text
	end
	T.frame:SetSize(width + 2 * PAD, tall)
end

function M.Fill(row, mob)
	local fresh = row.key ~= mob.key or not T.frame:IsShown()
	row.key, row.mob = mob.key, mob
	local r, g, b = StateColour(mob.state)
	row.bar:SetStatusBarColor(r, g, b, 1)
	row.bar:SetAlpha(ALPHA[mob.state] or 1)
	if not Look("Value", row, mob.bar, fresh) and not Glide(row.bar, mob.bar, fresh) then
		pcall(row.bar.SetValue, row.bar, 0)
	end
	Mark(row, mob.marker)
	if not pcall(row.name.SetText, row.name, mob.name) then
		row.name:SetText("")
	end
	local tint = NAMES[mob.state] or NAMES.held
	row.name:SetTextColor(tint[1], tint[2], tint[3], 1)
	Share(row, mob)
	row.mine:SetShown(mob.target == true)
	Wash(row, mob.state, r, g, b)
	row.bar:Show()
	M.Retip(row)
end

function M.Clear(from)
	for index = from, #M.rows do
		local row = M.rows[index]
		Wash(row, nil)
		Look("Halt", row)
		pcall(M.Untip, row)
		row.bar:Hide()
		row.key, row.mob = nil, nil
	end
end

function M.Rest()
	for _, row in ipairs(M.rows) do
		Wash(row, nil)
		Look("Halt", row)
	end
end

function M.More(list, n, hidden)
	if hidden <= 0 then
		if M.more then
			M.more:Hide()
		end
		return
	end
	local more = M.Line()
	local lost, slipping = 0, 0
	for index = n + 1, #list do
		local state = list[index].state
		if state == "lost" then
			lost = lost + 1
		elseif state == "slipping" then
			slipping = slipping + 1
		end
	end
	local text = ("+%d more"):format(hidden)
	if lost > 0 then
		text = text .. (", %d lost"):format(lost)
	end
	if slipping > 0 then
		text = text .. (", %d slipping"):format(slipping)
	end
	more:SetText(text)
	if lost > 0 then
		more:SetTextColor(Lighter(StateColour("lost")))
	else
		more:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	end
	more:Show()
end

local function Sound(sample)
	local choice = Opt("lostSound")
	if choice == "warning" then
		if Opt("lost") == false then
			return
		end
		choice = Opt("warnSound")
	end
	local kit = KITS[choice]
	local sound = kit and ns.SOUNDS and ns.SOUNDS[kit]
	if not sound then
		return
	end
	local mode = ns.TestMode
	if sample and not (mode ~= nil and mode.Sound("threat.enemies")) then
		return
	end
	ns.PlayKit(sound[1], KEY, true)
end

function M.Turned(list, n, sample)
	local any = false
	for index, mob in ipairs(list) do
		if mob.turned then
			any = true
			if index <= n then
				local r, g, b = Lighter(StateColour("lost"))
				Look("Flash", M.rows[index], r, g, b)
			end
		elseif mob.back and index <= n then
			local r, g, b = Lighter(StateColour("held"))
			Look("Flash", M.rows[index], r, g, b)
		end
	end
	if any then
		Sound(sample)
	end
end

function M.Title(lost, sample)
	local count = M.count
	local text = ("%s: %d %s"):format(sample and "Sample" or "Threat", count, count == 1 and "enemy" or "enemies")
	if lost > 0 then
		text = text .. (", %d lost"):format(lost)
		T.title:SetTextColor(Lighter(StateColour("lost")))
	else
		T.title:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	end
	T.title:SetText(text)
end

function M.Claim()
	if M.active then
		return
	end
	M.active = true
	for _, row in ipairs(T.rows) do
		T.Pulse(row, false)
		row.near:Hide()
		row.mine:Hide()
		if type(T.Untip) == "function" then
			pcall(T.Untip, row)
		end
		row.bar:Hide()
		row.who = nil
	end
	Look("Forget", T.rows)
	T.drawnOn = nil
	if T.lift ~= 0 then
		T.lift = 0
		T.Anchor()
	end
	M.below, M.belowLaid, M.last, M.readAt = nil, nil, nil, nil
	if M.line then
		M.line:Hide()
	end
end

function M.Draw(list, sample)
	M.count = type(list) == "table" and #list or 0
	if M.count == 0 then
		if M.active or (T.frame and T.frame:IsShown()) then
			M.Rest()
			T.Showing(false)
		end
		return
	end
	T.Frame()
	M.Claim()
	local lost = M.Rank(list)
	local n = math.min(M.count, math.max(1, math.floor(Number("rows", 5))), MOST_ROWS)
	local hidden = M.count - n
	M.Layout(n, hidden > 0)
	local keys = {}
	for index = 1, n do
		M.Fill(M.Row(index), list[index])
		keys[index] = list[index].key
	end
	M.Clear(n + 1)
	M.More(list, n, hidden)
	Look("Order", M.rows, n, sample and "sample" or "live", T.frame, keys)
	M.Turned(list, n, sample)
	M.Title(lost, sample)
	T.Marker("none")
	T.Place()
	T.Showing(true)
end

function M.Tick(on)
	if on and not M.ticker then
		local token, step = {}, M.Step()
		M.ticker = token
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, step, function()
				ns.Try(KEY, T.Update)
			end)
			token.handle = ok and ticker or nil
		end
		if not token.handle then
			local function Again()
				if M.ticker == token then
					ns.Try(KEY, T.Update)
					if M.ticker == token and not After(step, Again) then
						M.ticker = nil
					end
				end
			end
			if not After(step, Again) then
				M.ticker = nil
			end
		end
	elseif not on and M.ticker then
		local handle = M.ticker.handle
		M.ticker = nil
		if handle and type(handle.Cancel) == "function" then
			pcall(handle.Cancel, handle)
		end
	end
end

function M.Update()
	local fighting = T.fighting and type(UnitDetailedThreatSituation) == "function" and T.Allowed()
	local mode
	if fighting then
		mode = "live"
	elseif (T.sample or T.Testing()) and not T.fighting then
		mode = "sample"
	end
	if mode ~= M.mode then
		M.mode, M.known, M.last, M.readAt = mode, {}, nil, nil
	end
	M.Tick(mode == "live")
	if mode == "live" then
		if M.Due() or M.last == nil then
			M.last = M.Read()
		end
		M.Draw(M.last, false)
	elseif mode == "sample" then
		M.Draw(M.Samples(), true)
	else
		M.Draw(nil)
	end
end

function M.Take(on)
	if on and M.View() then
		M.Update()
		return true
	end
	if M.active or M.mode == "live" or M.mode == "sample" then
		M.Stop()
	end
	return false
end

function M.Divider()
	if not M.line then
		local line = Own(T.Frame():CreateTexture(nil, "ARTWORK"))
		line:SetColorTexture(DIM[1], DIM[2], DIM[3], RULE)
		line:Hide()
		M.line = line
	end
	return M.line
end

function M.LayBelow(k, extra)
	local width, height = Number("barWidth", 180), Number("barHeight", 16)
	local small = math.max(10, math.floor(height * SMALL + 0.5))
	local file = ns.BarTexture(Opt("barTexture")) or WHITE
	for index = 1, k do
		Paint(M.Row(index), file, TextHeight(small), small)
	end
	local up = Opt("grow") == "up" and k > 0
	local section = k * small + (k - 1) * GAP + (extra and GAP + TextHeight(small) or 0)
	if T.Lift(up and section + 2 * GAP + 1 or 0) then
		M.belowLaid = nil
	end
	local bottom = ns.Finite(T.bottom) and T.bottom or 0
	local start = up and PAD or bottom + 2 * GAP + 1
	T.frame:SetSize(width + 2 * PAD, (k > 0 and not up) and start + section + PAD or bottom + PAD)
	if k < 1 then
		if M.line then
			M.line:Hide()
		end
		if M.more then
			M.more:Hide()
		end
		M.belowLaid = nil
		return
	end
	local slip = Number("slipAt", 80)
	local key = ("%s:%s:%s:%s:%s:%s"):format(tostring(T.laid), bottom, k, slip, extra and 1 or 0, up and 1 or 0)
	if M.belowLaid == key then
		return
	end
	M.belowLaid = key
	if extra then
		local more = M.Line()
		local below = start + k * (small + GAP)
		more:SetTextHeight(TextHeight(small))
		more:ClearAllPoints()
		more:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PAD + INSET, -below)
		more:SetPoint("TOPRIGHT", T.frame, "TOPRIGHT", -(PAD + INSET), -below)
	end
	local line = M.Divider()
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PAD, -(up and PAD + section + GAP or bottom + GAP))
	line:SetSize(width, 1)
	line:Show()
	for index = 1, k do
		local row = M.rows[index]
		local bar = row.bar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PAD, -(start + (index - 1) * (small + GAP)))
		bar:SetSize(width, small)
		Tick(row.even, bar, width / 2)
		Tick(row.edge, bar, width * (100 - slip / 2) / 100)
	end
	Look("Laid", M.rows, k, PAD, start, small + GAP, width)
end

function M.Due()
	local now = Ask(GetTime)
	if not ns.Finite(now) then
		return true
	end
	local last = M.readAt
	if ns.Finite(last) and now >= last and now - last < M.Step() * 0.9 then
		return false
	end
	M.readAt = now
	return true
end

local function Spare(mob, unit, key)
	if mob.state ~= "lost" and mob.state ~= "slipping" then
		return false
	elseif unit == nil then
		return mob.target ~= true
	elseif key ~= nil and mob.key == key then
		return false
	end
	return Ask(UnitIsUnit, mob.unit, unit) ~= true
end

function M.Suffix(unit, lost)
	if lost < 1 or not T.title or T.titleTaken then
		return
	end
	local tail = (" |cff%s· %d lost|r"):format(Hex(Lighter(StateColour("lost"))), lost)
	if unit == nil then
		T.title:SetText("Sample" .. tail)
		return
	end
	local form = T.titleForm
	if type(form) == "table" and pcall(T.title.SetFormattedText, T.title, form[1] .. tail, form[2], form[3], form[4]) then
		return
	end
	local ok, name = pcall(UnitName, unit)
	if ok and Named(name) then
		pcall(T.title.SetFormattedText, T.title, "%s" .. tail, name)
	end
end

function M.Worst()
	if not M.Both() or not T.fighting or T.tank ~= true then
		return nil
	end
	if M.mode ~= "both:live" then
		M.mode, M.known, M.last, M.readAt, M.unranked = "both:live", {}, nil, nil, nil
	end
	if M.Due() or M.last == nil then
		M.last, M.unranked = M.Read(), true
	end
	local best, rank, share
	for _, mob in ipairs(M.last) do
		local at = mob.state == "lost" and 1 or mob.state == "slipping" and 2 or nil
		local value = ns.Finite(mob.share) and mob.share or 0
		if at and (mob.key == M.worst and (rank == nil or at <= rank)) then
			best, rank, share = mob, at, math.huge
		elseif at and (rank == nil or at < rank or (at == rank and value > share)) then
			best, rank, share = mob, at, value
		end
	end
	M.worst = best and best.key or nil
	return best and best.unit or nil
end

function M.Below(unit)
	local sample = unit == nil
	if not M.Both() or not (sample or (T.fighting and T.tank == true)) then
		M.BelowOff()
		return
	end
	local mode = sample and "both:sample" or "both:live"
	if mode ~= M.mode then
		M.mode, M.known, M.last, M.readAt = mode, {}, nil, nil
	end
	M.fading = nil
	M.Tick(not sample)
	local fresh = sample or M.unranked or M.Due() or M.last == nil
	if fresh then
		if sample or not M.unranked then
			M.last = sample and M.Spares() or M.Read()
		end
		M.unranked = nil
		M.Rank(M.last)
	end
	local key = unit and Ask(UnitGUID, unit) or nil
	local shown, lost = {}, 0
	for _, mob in ipairs(M.last) do
		if Spare(mob, unit, key) then
			shown[#shown + 1] = mob
			if mob.state == "lost" then
				lost = lost + 1
			end
		end
	end
	local k = math.min(#shown, BELOW)
	local hidden = #shown - k
	M.LayBelow(k, hidden > 0)
	local keys = {}
	for index = 1, k do
		M.Fill(M.rows[index], shown[index])
		keys[index] = shown[index].key
	end
	M.Clear(k + 1)
	M.More(shown, k, hidden)
	M.below, M.shown = k > 0 or nil, #shown
	Look("Order", M.rows, k, mode, T.frame, keys, true)
	if fresh then
		M.Turned(shown, k, sample)
	end
	M.Suffix(unit, lost)
end

function M.BelowOff(keep, fading)
	if M.mode == "both:live" or M.mode == "both:sample" then
		M.Tick(false)
		if not (keep and M.mode == "both:live") then
			M.mode, M.known = nil, {}
		end
		M.last, M.readAt, M.unranked = nil, nil, nil
	end
	if not M.below then
		M.fading = nil
		return
	end
	if fading then
		M.fading = true
		return
	end
	M.Unlay()
end

function M.Faded()
	if M.fading then
		M.Unlay()
	end
end

function M.Unlay()
	M.fading = nil
	M.below, M.belowLaid, M.shown = nil, nil, 0
	M.Clear(1)
	Look("Forget", M.rows)
	if M.line then
		M.line:Hide()
	end
	if M.more then
		M.more:Hide()
	end
	T.Lift(0)
	if T.frame and ns.Finite(T.bottom) then
		T.frame:SetSize(Number("barWidth", 180) + 2 * PAD, T.bottom + PAD)
	end
end

function M.Stop()
	M.Tick(false)
	if M.mode ~= nil or next(M.known) ~= nil then
		M.known, M.mode = {}, nil
	end
	M.count, M.shown, M.last, M.readAt, M.belowLaid, M.unranked, M.worst = 0, 0, nil, nil, nil, nil, nil
	M.roster, M.rosterAt, M.fading = nil, nil, nil
	if M.line then
		M.line:Hide()
	end
	if not M.active and not M.below then
		return
	end
	M.active, M.below = false, nil
	M.Clear(1)
	if M.more then
		M.more:Hide()
	end
	Look("Forget", M.rows)
	T.laid = nil
	if T.lift ~= 0 then
		T.lift = 0
		T.Anchor()
	end
	if T.title then
		T.title:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	end
end

function M.Status(lines)
	if not ns.Enabled(KEY) then
		return
	end
	if M.View() then
		lines[#lines + 1] = ("Threat list: Enemies you fight, %d in the last look."):format(M.count or 0)
	elseif M.Both() and T.tank == true then
		lines[#lines + 1] = ("Threat list: you count as a tank, so the enemies you are losing show under your target, %d in the last look."):format(M.shown or 0)
	end
end
