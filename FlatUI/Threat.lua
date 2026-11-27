local _, ns = ...

local KEY = "threat"
local MOVER = "FlatUIThreat"
local BOX_W, BOX_H, BOX_X, BOX_Y = 188, 112, 420, 0
local PAD, GAP, INSET = 4, 2, 4
local STEP, TICK, TEST_TIME = 0.2, 1, 8
local MOST_ROWS = 10
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local DIM = { 0.66, 0.68, 0.62 }
local TRACK = { 0.2, 0.2, 0.2, 0.5 }
local GREY = { 0.6, 0.6, 0.6 }
local PET = 0.7
local MINE = { 1, 1, 1, 0.9 }
local ALARM, ALARM_LOW, ALARM_TIME = { 1, 0.12, 0.08, 0.55 }, 0.15, 0.45
local NEAR = { 1, 0.65, 0.1, 0.4 }
local REARM = 10
local LOST_TIME = 2
local TAKEN = { 1, 0.3, 0.3 }
local OWNER_LIGHT = 0.45
local TIP_SHARE = "%d%% of the threat that pulls aggro: at 100%% %s"
local TIP_WITHHELD = "The game withholds the threat on this enemy."
local FADE_IN, FADE_OUT = 0.15, 0.35
local MARKERS, MARKER_GAP = "Interface\\TargetingFrame\\UI-RaidTargetingIcons", 3
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local FIGHT_EVENTS = { "PLAYER_TARGET_CHANGED" }
local ENEMY_EVENTS = { "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_PET", "RAID_TARGET_UPDATE" }
local LINE_WITHHELD = "Threat list: the game withheld the threat on the last enemy, so its bars kept the order of the group, the pets after the members."
local LINE_MISSING = "Threat list: this client has no UnitDetailedThreatSituation, so the list stays hidden."
local HELP = { "/flatui threat - sample bars of the threat list for a few seconds, out of combat" }
local SAMPLE = {
	{ "Tank", "WARRIOR", 100 }, { false, nil, 86 }, { "Mage", "MAGE", 71 }, { "Rogue", "ROGUE", 63 }, { "Hunter", "HUNTER", 52 },
	{ "Wolf", "HUNTER", 40, true }, { "Warlock", "WARLOCK", 33 }, { "Voidwalker", "WARLOCK", 24, true }, { "Priest", "PRIEST", 12 }, { "Druid", "DRUID", 6 },
}

local IsSecret = ns.IsSecret
local T = { rows = {}, heard = {}, fighting = false, withheld = false, lift = 0 }
ns.ThreatList = T

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Look(name, ...)
	local look = ns.ThreatLook
	local fn = type(look) == "table" and look[name] or nil
	if type(fn) == "function" then
		return fn(...)
	end
	return nil
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

local function Count(fn, most)
	local value = Ask(fn)
	if ns.Finite(value) and value > 0 then
		return math.min(math.floor(value), most)
	end
	return 0
end

local function TextHeight(height)
	return math.max(7, math.min(14, height - 4))
end

local function InFight()
	local value = Ask(UnitAffectingCombat, "player")
	if type(value) == "boolean" then
		return value
	end
	return Ask(InCombatLockdown) == true
end

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

function T.Allowed()
	local show = Opt("show")
	if show == "always" then
		return true
	elseif show == "instance" then
		local ok, inside, kind = pcall(IsInInstance)
		return ok and not IsSecret(inside) and inside == true and not IsSecret(kind) and (kind == "party" or kind == "raid")
	end
	return Ask(IsInGroup) == true
end

function T.Enemy(unit)
	return Ask(UnitExists, unit) == true and Ask(UnitCanAttack, "player", unit) == true and Ask(UnitIsPlayer, unit) ~= true
		and Ask(UnitIsDeadOrGhost, unit) ~= true
end

function T.Mob()
	if T.Enemy("target") then
		return "target"
	elseif T.Enemy("targettarget") then
		return "targettarget"
	end
	local mob = Opt("follow") ~= false and T.TankMob() or nil
	if not mob and type(ns.ThreatMobs) == "table" then
		mob = ns.ThreatMobs.Worst()
	end
	return mob
end

function T.Wakes()
	local mobs = ns.ThreatMobs
	return T.fighting == true and T.tank == true and type(mobs) == "table" and mobs.Both() and ns.Enabled(KEY)
		and type(UnitDetailedThreatSituation) == "function" and T.Allowed()
end

function T.Tanks()
	local tanks = {}
	for _, member in ipairs(T.Members()) do
		local unit = member.unit
		if not member.pet and Ask(UnitExists, unit) == true and Ask(UnitIsUnit, unit, "player") ~= true and T.OtherTank({ member = member }) then
			tanks[#tanks + 1] = unit
		end
	end
	return tanks
end

function T.TankMob()
	for _, unit in ipairs(T.Tanks()) do
		if T.Enemy(unit .. "target") then
			return unit .. "target"
		end
	end
	return nil
end

function T.Following()
	return T.fighting == true and Opt("follow") ~= false and ns.Enabled(KEY) and type(UnitDetailedThreatSituation) == "function" and T.Allowed()
		and #T.Tanks() > 0
end

function T.Members()
	local list, pets = {}, Opt("pets") == true
	local function Member(unit, pet)
		list[#list + 1] = { unit = unit, owner = unit }
		if pets then
			list[#list + 1] = { unit = pet, owner = unit, pet = true }
		end
	end
	if Ask(IsInRaid) == true then
		for index = 1, Count(GetNumGroupMembers, 40) do
			Member("raid" .. index, "raidpet" .. index)
		end
	else
		Member("player", "pet")
		if Ask(IsInGroup) == true then
			for index = 1, Count(GetNumSubgroupMembers, 4) do
				Member("party" .. index, "partypet" .. index)
			end
		end
	end
	return list
end

function T.Scan(mob)
	local entries, withheld = {}, false
	for order, member in ipairs(T.Members()) do
		if Ask(UnitExists, member.unit) == true then
			local ok, tanking, _, scaled, _, value = pcall(UnitDetailedThreatSituation, member.unit, mob)
			local entry
			if ok then
				if IsSecret(scaled) or IsSecret(value) then
					withheld = true
					entry = { member = member, order = order, scaled = scaled, withheld = true }
				elseif ns.Finite(scaled) then
					entry = { member = member, order = order, scaled = math.max(0, math.min(100, scaled)), value = ns.Finite(value) and value or 0 }
				end
			end
			if entry then
				entry.tanking = not IsSecret(tanking) and tanking == true
				entry.me = not member.pet and Ask(UnitIsUnit, member.unit, "player") == true
				entries[#entries + 1] = entry
			end
		end
	end
	if not withheld then
		table.sort(entries, function(a, b)
			if a.scaled ~= b.scaled then
				return a.scaled > b.scaled
			elseif a.value ~= b.value then
				return a.value > b.value
			end
			return a.order < b.order
		end)
	else
		table.sort(entries, function(a, b)
			local petA, petB = a.member.pet == true, b.member.pet == true
			if petA ~= petB then
				return petB
			end
			return a.order < b.order
		end)
	end
	return entries, withheld
end

local SHIFT = { 0, 7, -5, 11, -8, 4, -3, 9 }
local TURN = 5

function T.Sample()
	local entries, step = {}, T.step or 0
	local turn = step > 0 and step % TURN == 0
	local calm = step > 0 and step % TURN == 3
	local pets = Opt("pets") == true
	for order, spec in ipairs(SAMPLE) do
		local share, me, tanking = spec[3], spec[1] == false, order == 1
		local skip = spec[4] == true and not pets
		if step > 0 and order > 1 then
			share = math.max(1, math.min(99, share + SHIFT[(order + step) % #SHIFT + 1]))
		end
		if T.tank then
			if me then
				share, tanking = (turn and 97) or (calm and 96) or 100, not (turn or calm)
			elseif order == 1 then
				share, tanking = calm and 100 or 88, calm
			elseif turn and spec[1] == "Mage" then
				share, tanking = 100, true
			elseif step > 0 and step % TURN == 2 and spec[1] == "Rogue" then
				share, tanking = 94, false
			end
		elseif turn and me then
			share, tanking = 100, true
		elseif turn and order == 1 then
			share, tanking = 96, false
		end
		if not skip then
			entries[#entries + 1] = { sample = spec, order = order, scaled = share, me = me, tanking = tanking }
		end
	end
	if step > 0 or T.tank then
		table.sort(entries, function(a, b)
			if a.scaled ~= b.scaled then
				return a.scaled > b.scaled
			end
			return a.order < b.order
		end)
	end
	return entries
end

function T.Testing()
	local mode = ns.TestMode
	return mode ~= nil and mode.IsOn() == true
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

function T.Colour(entry)
	local r, g, b, pet
	local spec = entry.sample
	if spec then
		if spec[1] == false then
			r, g, b = ns.ClassColour()
		else
			r, g, b = ClassRGB(spec[2])
		end
		pet = spec[4] == true
	else
		r, g, b = ns.ClassColourOf(entry.member.owner)
		pet = entry.member.pet == true
	end
	if not r then
		r, g, b = GREY[1], GREY[2], GREY[3]
	end
	if pet then
		return r * PET, g * PET, b * PET
	end
	return r, g, b
end

local function SetName(text, unit, rank)
	local ok, name = pcall(UnitName, unit)
	if ok and (IsSecret(name) or type(name) == "string") then
		if not rank or not pcall(text.SetFormattedText, text, "%d. %s", rank, name) then
			text:SetText(name)
		end
	else
		text:SetText(rank and ("%d."):format(rank) or "")
	end
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

local function Fades(frame)
	local ok, fadeIn, fadeOut = pcall(function()
		local come = frame:CreateAnimationGroup()
		local rise = come:CreateAnimation("Alpha")
		rise:SetFromAlpha(0)
		rise:SetToAlpha(1)
		rise:SetDuration(FADE_IN)
		local go = frame:CreateAnimationGroup()
		local fall = go:CreateAnimation("Alpha")
		fall:SetFromAlpha(1)
		fall:SetToAlpha(0)
		fall:SetDuration(FADE_OUT)
		pcall(go.SetToFinalAlpha, go, true)
		go:SetScript("OnFinished", function()
			frame:Hide()
			frame:SetAlpha(1)
		end)
		return come, go
	end)
	if ok then
		return fadeIn, fadeOut
	end
	return nil, nil
end

local function Showing(frame, fadeIn, fadeOut, on, now)
	local fading = fadeOut ~= nil and fadeOut:IsPlaying()
	if on then
		if fading then
			pcall(fadeOut.Stop, fadeOut)
			frame:SetAlpha(1)
		end
		if not frame:IsShown() then
			frame:SetAlpha(1)
			frame:Show()
			if fadeIn and not now then
				pcall(fadeIn.Play, fadeIn)
			end
		end
		return
	end
	if fadeIn and fadeIn:IsPlaying() then
		pcall(fadeIn.Stop, fadeIn)
	end
	if now or not fadeOut or not frame:IsShown() then
		if fading then
			pcall(fadeOut.Stop, fadeOut)
		end
		frame:Hide()
		frame:SetAlpha(1)
	elseif not fading and not pcall(fadeOut.Play, fadeOut) then
		frame:Hide()
	end
end

function T.Frame()
	if T.frame then
		return T.frame
	end
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	frame:SetFrameStrata("LOW")
	frame:SetSize(BOX_W, BOX_H)
	frame:Hide()
	T.frame = frame
	T.outline = ns.Outline(frame, frame, true)
	local title = ns.OwnText(frame, "OVERLAY", FONT)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + INSET, -PAD)
	title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + INSET), -PAD)
	T.title = title
	local marker = Own(frame:CreateTexture(nil, "OVERLAY"))
	marker:SetTexture(MARKERS)
	marker:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + INSET, -PAD)
	marker:SetSize(12, 12)
	marker:Hide()
	T.marker = marker
	T.fadeIn, T.fadeOut = Fades(frame)
	return frame
end

function T.Showing(on, now)
	if T.frame then
		Showing(T.frame, T.fadeIn, T.fadeOut, on, now)
	end
	if not on then
		T.drawnOn = nil
		for _, row in ipairs(T.rows) do
			row.who = nil
			pcall(T.Untip, row)
		end
		Look("Forget", T.rows)
	end
end

function T.Marker(mob)
	local marker, shown = T.marker, false
	if not marker then
		return
	end
	if not mob then
		shown = Cell(marker, 8)
	elseif type(GetRaidTargetIndex) == "function" then
		local ok, index = pcall(GetRaidTargetIndex, mob)
		if ok and (IsSecret(index) or (ns.Finite(index) and index >= 1 and index <= 8)) then
			shown = Cell(marker, index)
		end
	end
	marker:SetShown(shown)
	if T.marked ~= shown then
		T.marked = shown
		T.Anchor()
	end
end

function T.Anchor()
	local title, marker = T.title, T.marker
	if not title or not marker then
		return
	end
	local y = -PAD - (ns.Finite(T.lift) and T.lift or 0)
	marker:ClearAllPoints()
	marker:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PAD + INSET, y)
	title:ClearAllPoints()
	if T.marked then
		title:SetPoint("TOPLEFT", marker, "TOPRIGHT", MARKER_GAP, -1)
	else
		title:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PAD + INSET, y)
	end
	title:SetPoint("TOPRIGHT", T.frame, "TOPRIGHT", -(PAD + INSET), y)
end

function T.Lift(value)
	value = ns.Finite(value) and value or 0
	if T.lift == value then
		return false
	end
	T.lift = value
	if T.frame and T.laidN then
		T.laid = nil
		T.Layout(T.laidN)
	else
		T.Anchor()
	end
	return true
end

function T.Row(index)
	local row = T.rows[index]
	if row then
		return row
	end
	local bar = Own(CreateFrame("StatusBar", nil, T.frame))
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
	local mine = Own(CreateFrame("Frame", nil, bar))
	mine:SetAllPoints(bar)
	for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local line = Own(mine:CreateTexture(nil, "OVERLAY", nil, 7))
		line:SetColorTexture(MINE[1], MINE[2], MINE[3], MINE[4])
		line:SetPoint(edge[1], mine, edge[1], 0, 0)
		line:SetPoint(edge[2], mine, edge[2], 0, 0)
		if edge[3] then
			line:SetHeight(1)
		else
			line:SetWidth(1)
		end
	end
	mine:Hide()
	local alarm = Own(bar:CreateTexture(nil, "OVERLAY", nil, -8))
	alarm:SetAllPoints(bar)
	alarm:SetColorTexture(ALARM[1], ALARM[2], ALARM[3], ALARM[4])
	alarm:Hide()
	local near = Own(bar:CreateTexture(nil, "OVERLAY", nil, -8))
	near:SetAllPoints(bar)
	near:SetColorTexture(NEAR[1], NEAR[2], NEAR[3], NEAR[4])
	near:Hide()
	local made, pulse = pcall(function()
		local group = alarm:CreateAnimationGroup()
		group:SetLooping("BOUNCE")
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(ALARM_LOW)
		fade:SetToAlpha(1)
		fade:SetDuration(ALARM_TIME)
		return group
	end)
	row = { bar = bar, track = track, name = name, share = share, mine = mine, alarm = alarm, near = near, pulse = made and pulse or nil }
	T.rows[index] = row
	Look("Dress", row)
	T.Hover(row)
	return row
end

function T.Hover(row)
	local bar = row.bar
	if type(bar.SetMouseMotionEnabled) ~= "function" or type(bar.SetMouseClickEnabled) ~= "function" then
		return
	end
	if not (pcall(bar.SetMouseMotionEnabled, bar, true) and pcall(bar.SetMouseClickEnabled, bar, false)) then
		pcall(bar.EnableMouse, bar, false)
		return
	end
	bar:SetScript("OnEnter", function(self)
		ns.Try(KEY, T.Tip, row, self)
	end)
	bar:SetScript("OnLeave", function()
		pcall(T.Untip, row)
	end)
end

function T.Untip(row)
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

function T.Retip(row)
	if not row.tipped then
		return
	end
	local tip = GameTooltip
	local ok, owned = false, false
	if not ns.Forbidden(tip) then
		ok, owned = pcall(tip.IsOwned, tip, row.bar)
	end
	if ok and owned == true then
		T.Tip(row, row.bar)
	else
		row.tipped = nil
	end
end

function T.Near(entry)
	if Opt("warn") == false or T.tank or not entry or not entry.me or entry.withheld or entry.tanking then
		return false
	end
	return ns.Finite(entry.scaled) and entry.scaled >= Number("warnAt", 90)
end

function T.Holding(entry)
	return Opt("warn") ~= false and not T.tank and entry ~= nil and entry.me == true and not entry.withheld and entry.tanking == true
end

local function Assigned(assignment, unit)
	if type(GetPartyAssignment) ~= "function" then
		return false
	end
	local ok, yes = pcall(GetPartyAssignment, assignment, unit)
	return ok and not IsSecret(yes) and yes ~= nil and yes ~= false
end

function T.OtherTank(entry)
	if entry and entry.sample then
		return entry.sample[1] == "Tank"
	end
	local member = entry and entry.member
	if not member or entry.me or member.pet or type(member.unit) ~= "string" then
		return false
	end
	local unit = member.unit
	if Ask(UnitGroupRolesAssigned, unit) == "TANK" or Assigned("MAINTANK", unit) then
		return true
	end
	return Ask(IsInRaid) ~= true and Ask(UnitHasEffectivelyTankAura, unit) == true
end

function T.Others(entry)
	if not T.tank or Opt("others") == false or not entry or entry.me or entry.withheld or entry.tanking then
		return false
	end
	if not (ns.Finite(entry.scaled) and entry.scaled >= Number("warnAt", 90)) then
		return false
	end
	return Opt("otherTanks") == false or not T.OtherTank(entry)
end

function T.Losing(entry)
	if not T.lostUntil or not entry or not entry.me or entry.tanking == true then
		return false
	end
	local now = Ask(GetTime)
	return ns.Finite(now) and now < T.lostUntil
end

function T.Took(entry)
	if not T.lostUntil or not entry or entry.me or entry.withheld or entry.tanking ~= true then
		return false
	end
	if Opt("otherTanks") ~= false and T.OtherTank(entry) then
		return false
	end
	local now = Ask(GetTime)
	return ns.Finite(now) and now < T.lostUntil
end

function T.ReadRole()
	local ok, role = pcall(ns.PlayerRole)
	T.tank = ok and not IsSecret(role) and role == "tank" or false
end

function T.Calm(entries)
	if Opt("otherTanks") == false or type(entries) ~= "table" then
		return false
	end
	for _, other in ipairs(entries) do
		if other.tanking == true and not other.me then
			return T.OtherTank(other) == true
		end
	end
	return false
end

function T.Lost(entry, who, entries)
	if who ~= T.lostOn then
		T.held, T.lostUntil, T.lostOn = nil, nil, who
	end
	if who == nil or not T.tank or Opt("lost") == false or not entry or entry.withheld then
		T.held = nil
		return
	end
	if entry.tanking then
		T.held, T.lostUntil = who, nil
	elseif T.lostUntil and T.Calm(entries) then
		T.lostUntil = nil
	elseif T.held == who then
		T.held = nil
		if T.Calm(entries) then
			return
		end
		local now = Ask(GetTime)
		T.lostUntil = ns.Finite(now) and now + LOST_TIME or nil
		After(LOST_TIME + 0.05, function()
			ns.Try(KEY, T.Soon)
		end)
		local sound = ns.SOUNDS[KITS[Opt("warnSound")] or 0]
		local mode = ns.TestMode
		if sound and (who ~= "sample" or (mode ~= nil and mode.Sound("threat.lost"))) then
			ns.PlayKit(sound[1], KEY)
		end
	end
end

function T.Pulse(row, on, steady)
	if steady then
		if row.pulse and row.pulse:IsPlaying() then
			pcall(row.pulse.Stop, row.pulse)
		end
		row.alarm:SetAlpha(1)
		row.alarm:Show()
	elseif on then
		row.alarm:Show()
		if row.pulse and not row.pulse:IsPlaying() then
			pcall(row.pulse.Play, row.pulse)
		end
	elseif row.alarm:IsShown() then
		if row.pulse then
			pcall(row.pulse.Stop, row.pulse)
		end
		row.alarm:Hide()
	end
end

function T.Alarm(entry, who)
	if who == nil or not entry then
		T.warned = nil
		return
	end
	if T.warned and T.warned ~= who then
		T.warned = nil
	end
	if T.warned and not entry.withheld and ns.Finite(entry.scaled) and entry.scaled < Number("warnAt", 90) - REARM then
		T.warned = nil
	end
	if T.warned or not (T.Near(entry) or T.Holding(entry)) then
		return
	end
	T.warned = who
	local sound = ns.SOUNDS[KITS[Opt("warnSound")] or 0]
	local mode = ns.TestMode
	if sound and (who ~= "sample" or (mode ~= nil and mode.Sound("threat.warn"))) then
		ns.PlayKit(sound[1], KEY)
	end
end

local function Paint(row, file, text)
	if row.file ~= file then
		local ok, done = pcall(row.bar.SetStatusBarTexture, row.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(row.bar.SetStatusBarTexture, row.bar, WHITE)
		end
		row.file = file
	end
	row.name:SetTextHeight(text)
	row.share:SetTextHeight(text)
end

function T.Layout(n)
	local width, height = Number("barWidth", 180), Number("barHeight", 16)
	local text = TextHeight(height)
	local file = ns.BarTexture(Opt("barTexture")) or WHITE
	for index = 1, n do
		Paint(T.Row(index), file, text)
	end
	T.title:SetTextHeight(text)
	T.marker:SetSize(text + 2, text + 2)
	local lift = ns.Finite(T.lift) and T.lift or 0
	local key = ("%s:%s:%s:%s"):format(n, width, height, lift)
	local top = PAD + lift + text + 2 + GAP
	T.bottom, T.laidN = top + n * height + (n - 1) * GAP, n
	if T.laid == key then
		return
	end
	T.laid = key
	for index = 1, n do
		local bar = T.rows[index].bar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PAD, -(top + (index - 1) * (height + GAP)))
		bar:SetSize(width, height)
	end
	T.Anchor()
	Look("Laid", T.rows, n, PAD, top, height + GAP, width)
	T.frame:SetSize(width + 2 * PAD, T.bottom + PAD)
end

function T.Bar(row, value, jump)
	if Look("Value", row, value, jump) then
		return true
	end
	return Glide(row.bar, value, jump)
end

function T.Fill(row, entry)
	row.mine:SetShown(entry.me == true and Opt("mine") ~= false)
	row.near:SetShown(T.Others(entry))
	T.Pulse(row, T.Near(entry) or T.Losing(entry) or T.Took(entry), T.Holding(entry))
	local who = entry.sample or entry.member.unit
	local jump = row.who ~= who or not T.frame:IsShown()
	row.who = who
	local r, g, b = T.Colour(entry)
	row.bar:SetStatusBarColor(r, g, b, 1)
	Look("Name", row, r, g, b)
	local spec = entry.sample
	if spec and spec[1] ~= false then
		row.name:SetText(entry.rank and ("%d. %s"):format(entry.rank, spec[1]) or spec[1])
	else
		SetName(row.name, spec and "player" or entry.member.unit, entry.rank)
	end
	if entry.withheld then
		if not T.Bar(row, entry.scaled, jump) then
			row.bar:SetValue(0)
		end
		if not pcall(row.share.SetFormattedText, row.share, "%.0f%%", entry.scaled) then
			row.share:SetText("")
		end
	else
		T.Bar(row, entry.scaled, jump)
		row.share:SetText(("%d%%"):format(math.floor(entry.scaled + 0.5)))
	end
	row.bar:Show()
	row.entry = entry
	T.Retip(row)
end

function T.Place()
	local corner = Opt("grow") == "up" and "BOTTOMLEFT" or "TOPLEFT"
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, corner)
	end
	local key = (x and ("%.2f:%.2f"):format(x, y) or "start") .. ":" .. corner
	if T.placed == key then
		return
	end
	T.placed = key
	local frame = T.frame
	frame:ClearAllPoints()
	if x then
		frame:SetPoint(corner, UIParent, "BOTTOMLEFT", x, y)
	elseif corner == "BOTTOMLEFT" then
		frame:SetPoint(corner, UIParent, "CENTER", BOX_X - BOX_W / 2, BOX_Y - BOX_H / 2)
	else
		frame:SetPoint(corner, UIParent, "CENTER", BOX_X - BOX_W / 2, BOX_Y + BOX_H / 2)
	end
end

function T.Draw(mob, entries)
	local n = math.min(entries and #entries or 0, Number("rows", 5), MOST_ROWS)
	local mobs = type(ns.ThreatMobs) == "table" and ns.ThreatMobs or nil
	if n < 1 then
		if mobs then
			mobs.BelowOff(T.fighting == true)
		end
		T.Showing(false)
		T.Alarm(nil, nil)
		T.Lost(nil, nil)
		T.Tick(mob == "targettarget" or T.Following() or T.Wakes())
		return
	end
	T.Frame()
	T.Layout(n)
	local own, at = nil, nil
	for index, entry in ipairs(entries) do
		if entry.me and not own then
			own, at = entry, index
		end
	end
	local who = mob and (Ask(UnitGUID, mob) or mob) or "sample"
	if T.drawnOn ~= who then
		T.drawnOn = who
		for _, row in ipairs(T.rows) do
			row.who = nil
		end
	end
	T.Lost(own, who, entries)
	local shown = T.Shown(entries, n, own, at)
	for index = 1, n do
		T.Fill(T.rows[index], shown[index])
	end
	for index = n + 1, #T.rows do
		T.Pulse(T.rows[index], false)
		T.rows[index].near:Hide()
		pcall(T.Untip, T.rows[index])
		T.rows[index].bar:Hide()
		T.rows[index].who = nil
	end
	Look("Order", T.rows, n, who, T.frame)
	T.Alarm(own, who)
	T.Title(mob, entries)
	if mobs then
		mobs.Below(mob)
	end
	T.Marker(mob)
	T.Place()
	T.Showing(true)
	T.Tick(mob ~= nil)
end

function T.Taker(entries)
	for _, entry in ipairs(entries or {}) do
		if entry.tanking == true and not entry.me and not entry.withheld and not (Opt("otherTanks") ~= false and T.OtherTank(entry)) then
			return entry
		end
	end
	return nil
end

local function Named(name)
	return IsSecret(name) or (type(name) == "string" and name ~= "")
end

local function Hex(r, g, b)
	local function Byte(value)
		return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
	end
	return ("%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

function T.Owner(title, mob)
	local owner = type(mob) == "string" and mob ~= "targettarget" and mob:match("^(.+)target$") or nil
	if not owner then
		return false
	end
	local okMob, mobName = pcall(UnitName, mob)
	local okOwner, ownerName = pcall(UnitName, owner)
	if not (okMob and okOwner and Named(mobName) and Named(ownerName)) then
		return false
	end
	local r, g, b = ns.ClassColourOf(owner)
	if not r then
		r, g, b = GREY[1], GREY[2], GREY[3]
	end
	local form = { "%s |cff" .. Hex(DIM[1], DIM[2], DIM[3]) .. "·|r |cff%s%s|r", mobName, Hex(r + (1 - r) * OWNER_LIGHT, g + (1 - g) * OWNER_LIGHT,
		b + (1 - b) * OWNER_LIGHT), ownerName }
	if not pcall(title.SetFormattedText, title, form[1], form[2], form[3], form[4]) then
		return false
	end
	T.titleForm = form
	return true
end

function T.TipName(tip, entry, r, g, b)
	local spec = entry.sample
	if spec and spec[1] ~= false then
		return pcall(tip.AddLine, tip, spec[1], r, g, b)
	end
	local ok, name = pcall(UnitName, spec and "player" or entry.member.unit)
	return ok and Named(name) and pcall(tip.AddLine, tip, name, r, g, b)
end

function T.Tip(row, owner)
	local entry, tip = row.entry, GameTooltip
	if type(entry) ~= "table" or ns.Forbidden(tip) then
		return
	end
	tip:SetOwner(owner, "ANCHOR_LEFT")
	local r, g, b = T.Colour(entry)
	if not T.TipName(tip, entry, r, g, b) then
		tip:AddLine(entry.me and "You" or "Member", r, g, b)
	end
	local warnAt = Number("warnAt", 90)
	if entry.withheld then
		tip:AddLine(TIP_WITHHELD, DIM[1], DIM[2], DIM[3], true)
	elseif entry.tanking then
		tip:AddLine(entry.me and "You hold aggro" or "Holds aggro", 1, 1, 1)
	elseif ns.Finite(entry.scaled) then
		tip:AddLine(TIP_SHARE:format(math.floor(entry.scaled + 0.5), entry.me and "you take it" or "they take it"), 1, 1, 1, true)
	end
	if entry.me and not T.tank and Opt("warn") ~= false then
		tip:AddLine(("Your bar: it pulses red from Warn at (%d%%)"):format(warnAt), DIM[1], DIM[2], DIM[3], true)
	elseif entry.me then
		tip:AddLine("Your bar", DIM[1], DIM[2], DIM[3])
	end
	if T.Took(entry) then
		tip:AddLine("Took the enemy from you: taunt it back", TAKEN[1], TAKEN[2], TAKEN[3], true)
	elseif T.tank and Opt("otherTanks") ~= false and T.OtherTank(entry) then
		tip:AddLine("Another tank: calm", DIM[1], DIM[2], DIM[3])
	elseif T.Others(entry) then
		tip:AddLine("Close to your aggro", NEAR[1], NEAR[2], NEAR[3], true)
	end
	if entry.sample then
		tip:AddLine("Sample", DIM[1], DIM[2], DIM[3])
	end
	tip:Show()
	row.tipped = true
end

function T.Title(mob, entries)
	local title, taker = T.title, nil
	T.titleTaken, T.titleForm = false, nil
	local now = T.lostUntil and Ask(GetTime)
	if ns.Finite(now) and now < T.lostUntil then
		taker = T.Taker(entries)
	end
	if taker then
		local done = false
		if taker.sample then
			done = type(taker.sample[1]) == "string" and pcall(title.SetFormattedText, title, "%s > %s", "Sample", taker.sample[1])
		elseif mob and taker.member then
			local okMob, mobName = pcall(UnitName, mob)
			local okTaker, takerName = pcall(UnitName, taker.member.unit)
			if okMob and okTaker and Named(mobName) and Named(takerName) then
				done = pcall(title.SetFormattedText, title, "%s > %s", mobName, takerName)
			end
		end
		if done then
			T.titleTaken = true
			title:SetTextColor(TAKEN[1], TAKEN[2], TAKEN[3], 1)
			return
		end
	end
	title:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	if mob then
		if not T.Owner(title, mob) then
			SetName(title, mob)
		end
	else
		title:SetText("Sample")
	end
end

function T.Shown(entries, n, own, at)
	if not own or not at or at <= n or n < 2 or Opt("keepMine") == false then
		return entries
	end
	local shown = {}
	for index = 1, n - 1 do
		shown[index] = entries[index]
	end
	own.rank = not own.withheld and at or nil
	shown[n] = own
	return shown
end

function T.OnEvent(event, unit)
	if event == "UNIT_TARGET" and (IsSecret(unit) or unit ~= "target") then
		return
	end
	T.Soon()
end

function T.Listener()
	if not T.listener then
		local frame = Own(CreateFrame("Frame"))
		frame:SetScript("OnEvent", function(_, event, unit)
			ns.Try(KEY, T.OnEvent, event, unit)
		end)
		T.listener = frame
	end
	return T.listener
end

local function Hear(event, on, unit)
	on = on == true
	if on == (T.heard[event] ~= nil) or (not on and not T.listener) then
		return
	end
	local frame = T.Listener()
	if not on then
		pcall(frame.UnregisterEvent, frame, event)
		T.heard[event] = nil
		return
	end
	if unit and type(frame.RegisterUnitEvent) == "function" then
		local ok, done = pcall(frame.RegisterUnitEvent, frame, event, unit)
		if ok and (IsSecret(done) or done ~= false) then
			T.heard[event] = unit
			return
		end
	end
	if pcall(frame.RegisterEvent, frame, event) then
		T.heard[event] = true
	end
end

local function HearAll(events, on)
	for _, event in ipairs(events) do
		Hear(event, on)
	end
end

function T.Soon()
	if T.pending then
		return
	end
	T.pending = true
	if not After(STEP, function()
		ns.Try(KEY, T.Update)
	end) then
		T.Update()
	end
end

function T.Tick(on)
	if on and not T.ticker then
		local token = {}
		T.ticker = token
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, TICK, function()
				ns.Try(KEY, T.Update)
			end)
			token.handle = ok and ticker or nil
		end
		if not token.handle then
			local function Again()
				if T.ticker == token then
					ns.Try(KEY, T.Update)
					if T.ticker == token and not After(TICK, Again) then
						T.ticker = nil
					end
				end
			end
			if not After(TICK, Again) then
				T.ticker = nil
			end
		end
	elseif not on and T.ticker then
		local handle = T.ticker.handle
		T.ticker = nil
		if handle and type(handle.Cancel) == "function" then
			pcall(handle.Cancel, handle)
		end
	end
end

function T.Update()
	T.pending = nil
	local on = ns.Enabled(KEY)
	local mobs = ns.ThreatMobs
	if type(mobs) == "table" and mobs.Take(on) then
		HearAll(FIGHT_EVENTS, false)
		HearAll(ENEMY_EVENTS, false)
		Hear("UNIT_TARGET", false)
		T.Tick(false)
		return
	end
	local fighting = on and T.fighting and type(UnitDetailedThreatSituation) == "function" and T.Allowed()
	HearAll(FIGHT_EVENTS, fighting)
	Hear("UNIT_TARGET", fighting, "target")
	local mob = fighting and T.Mob() or nil
	HearAll(ENEMY_EVENTS, mob ~= nil or (fighting and T.Wakes()))
	if mob then
		local entries, withheld = T.Scan(mob)
		T.withheld = withheld
		T.Draw(mob, entries)
	elseif on and (T.sample or T.Testing()) and not T.fighting then
		T.Draw(nil, T.Sample())
	else
		T.Draw(nil, nil)
	end
end

function T.Fight(on)
	T.fighting = on
	if on then
		T.sample = nil
		T.ReadRole()
	end
	T.Update()
end

function T.Off()
	T.sample, T.fighting, T.pending, T.withheld, T.warned = nil, false, nil, false, nil
	T.held, T.lostUntil, T.lostOn = nil, nil, nil
	HearAll(FIGHT_EVENTS, false)
	HearAll(ENEMY_EVENTS, false)
	Hear("UNIT_TARGET", false)
	T.Tick(false)
	if type(ns.ThreatMobs) == "table" then
		ns.ThreatMobs.Stop()
	end
	T.Showing(false, true)
end

function T.Refresh()
	T.pending, T.placed, T.laid = nil, nil, nil
	if not ns.Enabled(KEY) then
		T.Off()
		return
	end
	T.fighting = InFight()
	T.ReadRole()
	T.Update()
end

function T.Slash()
	if not ns.Enabled(KEY) then
		print("Threat list: turn on Show the threat list first.")
		return
	end
	if T.fighting or InFight() then
		print("Threat list: the sample shows out of combat.")
		return
	end
	local token = {}
	T.sample = token
	ns.Try(KEY, T.Update)
	local function Done()
		if T.sample == token then
			T.sample = nil
			ns.Try(KEY, T.Update)
		end
	end
	if not After(TEST_TIME, Done) then
		Done()
	end
end

function T.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if type(UnitDetailedThreatSituation) ~= "function" then
		lines[#lines + 1] = LINE_MISSING
	end
	if T.withheld then
		lines[#lines + 1] = LINE_WITHHELD
	end
	if type(ns.ThreatMobs) == "table" then
		ns.ThreatMobs.Status(lines)
	end
	return lines
end

function ns.ThreatListShown()
	return ns.Enabled(KEY)
end

function ns.ThreatListMoved()
	T.placed = nil
	if T.frame and ns.Enabled(KEY) then
		ns.Try(KEY, T.Place)
	end
end

local TEST_STEP = 2

ns.Register(KEY, {
	label = "Threat list",
	counted = false,
	Start = T.Refresh,
	Refresh = T.Refresh,
	Resized = T.Refresh,
	Status = T.Status,
	events = {
		PLAYER_REGEN_DISABLED = function()
			T.Fight(true)
		end,
		PLAYER_REGEN_ENABLED = function()
			T.Fight(false)
		end,
		GROUP_ROSTER_UPDATE = function()
			if T.fighting then
				T.Soon()
			end
		end,
		PLAYER_ENTERING_WORLD = function()
			T.fighting = InFight()
			T.Update()
		end,
	},
	slash = { threat = T.Slash },
	help = HELP,
})

if ns.TestMode then
	ns.TestMode.Register("threat", {
		module = KEY,
		label = "Threat list",
		refresh = true,
		Start = function()
			T.step = 0
			T.ReadRole()
		end,
		every = TEST_STEP,
		Tick = function()
			T.step = (T.step or 0) + 1
			if not T.fighting then
				T.Update()
			end
		end,
	})
end
