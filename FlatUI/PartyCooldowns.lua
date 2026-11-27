local _, ns = ...

local KEY = "partycd"
local SPACING = 2
local GAP, BELOW = 4, -1
local LOOK = 0.5
local TEST_TIME = 8
local DARK = 0.6
local UNKNOWN_ICON = 134400
local READY = { 0.4, 0.9, 0.4 }
local DIM = { 0.66, 0.68, 0.62 }
local GONE = 0.35
local FAR = 0.45
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local FLASH = 0.5
local SWITCHES = { { "interrupts", { 1 } }, { "defensives", { 2, 6 } }, { "externals", { 3 } }, { "breaks", { 5 } }, { "group", { 9 } } }
local LINE_ROSTER = "Party cooldowns: your subgroup is read from the raid roster here."
local LINE_CASTS = "Party cooldowns: the game hides party members' casts here."
local LINE_RANGE = "Party cooldowns: the game refused to fade a row by its answer about range, so members out of range stay bright."
local MOVER = "FlatUIPartyRaid"
local LABEL_W, MOST_ROWS, STACK_X, STACK_Y = 70, 5, -420, 0
local LIVE = { standard = true, style = true, raid = true }
local MOST_ADDED, MOST_SECONDS, MOST_ID = 30, 86400, 9999999
local HELP = {
	"/flatui party add Pummel 12 - an ability, a spell ID or a shift-clicked spell, and its cooldown in seconds",
	"/flatui party hide 6552 - an ability or a spell ID",
	"/flatui party list - the abilities shown and who shares cooldowns",
	"/flatui party reset - puts the abilities back as Flat UI ships them",
}

local IsSecret = ns.IsSecret
local T = ns.Tracking
local TM = ns.TestMode
local SAMPLE_PARTY = { { "Mara", "PALADIN" }, { "Eli", "PRIEST" }, { "Ivo", "WARLOCK", "Dead" }, { "Fay", "ROGUE", far = true } }
local P = { assigned = {}, pool = {}, known = {}, level = {}, never = {}, tex = {}, last = {}, frames = {}, raidUnits = {} }

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Text(fn, ...)
	local answer = T.Ask(fn, ...)
	return Plain(answer, "string") and answer ~= "" and answer or nil
end

local function Shown(frame)
	if frame == nil or IsSecret(frame) or type(frame) ~= "table" then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not IsSecret(shown) and shown == true
end

function P.Members()
	local list = {}
	local pool = type(_G.PartyFrame) == "table" and not IsSecret(_G.PartyFrame) and _G.PartyFrame.PartyMemberFramePool or nil
	if type(pool) ~= "table" or IsSecret(pool) or type(pool.EnumerateActive) ~= "function" then
		return list
	end
	local ok = pcall(function()
		for frame in pool:EnumerateActive() do
			local unit = type(frame) == "table" and not ns.Forbidden(frame) and frame.unit or nil
			if Plain(unit, "string") and unit:match("^party%d$") and Shown(frame) then
				list[#list + 1] = { frame = frame, unit = unit }
			end
		end
	end)
	if not ok then
		return {}
	end
	table.sort(list, function(a, b)
		return a.unit < b.unit
	end)
	return list
end

local function Token(unit)
	return Plain(unit, "string") and (unit == "player" or unit:match("^party%d$") ~= nil)
end

function P.StyleMembers()
	local list, seen = {}, {}
	for index = 1, 5 do
		local frame = _G["CompactPartyFrameMember" .. index]
		if Shown(frame) and not ns.Forbidden(frame) then
			local ok, unit, shown = pcall(function()
				return frame.unit, frame.displayedUnit
			end)
			if ok and not Token(unit) then
				unit = shown
			end
			if ok and Token(unit) and not seen[unit] then
				seen[unit] = true
				list[#list + 1] = { frame = frame, unit = unit }
			end
		end
	end
	return list
end

ns.PartyMembers, ns.PartyStyleMembers = P.Members, P.StyleMembers

function P.RaidMembers()
	local list = {}
	for index = 1, 4 do
		local unit = "party" .. index
		if T.Ask(UnitExists, unit) == true then
			list[#list + 1] = { unit = unit }
		end
	end
	P.via = "party"
	if #list > 0 then
		return list
	end
	local count = T.Ask(GetNumGroupMembers)
	if not Plain(count, "number") then
		return list
	end
	local mine = Text(UnitName, "player")
	local people, group = {}, nil
	for index = 1, math.min(count, 40) do
		local ok, name, _, subgroup = pcall(GetRaidRosterInfo, index)
		if ok and Plain(name, "string") and Plain(subgroup, "number") then
			if mine and (name == mine or (name:match("^([^%-]+)") or name) == mine) then
				group = subgroup
			else
				people[#people + 1] = { unit = "raid" .. index, subgroup = subgroup }
			end
		end
	end
	for _, person in ipairs(people) do
		if group and person.subgroup == group and #list < MOST_ROWS - 1 then
			list[#list + 1] = { unit = person.unit }
		end
	end
	if #list > 0 then
		P.via = "roster"
	end
	return list
end

function P.Look()
	if not ns.Enabled(KEY) then
		return "off"
	elseif T.Ask(IsInRaid) == true then
		if Opt("raid") ~= "own" then
			return "raidoff"
		end
		return "raid", P.RaidMembers()
	elseif T.Ask(IsInGroup) ~= true then
		return "none"
	end
	local members = P.Members()
	if #members > 0 then
		return "standard", members
	end
	members = P.StyleMembers()
	if #members > 0 then
		return "style", members
	end
	return "none"
end

function P.Owner(unit, frame)
	local guid = Text(UnitGUID, unit)
	if guid then
		return guid
	end
	return frame
end

function P.Race(unit)
	if type(UnitRace) ~= "function" then
		return nil
	end
	local ok, name, file = pcall(UnitRace, unit)
	if ok and Plain(name, "string") then
		return name, Plain(file, "string") and file or nil
	end
	return nil
end

function P.RaceIs(row, race)
	local name, file = row.race, row.raceFile
	return name == race or (file ~= nil and (file == race:gsub("%s", "") or (file == "Scourge" and race == "Undead")))
end

function P.Who(unit)
	if unit == "pet" then
		unit = "player"
	end
	if unit ~= "player" and not unit:match("^party%d$") and not P.raidUnits[unit] then
		return nil
	end
	local frame = P.frames[unit]
	return P.Owner(unit, frame) or (unit == "player" and "player" or nil), Text(UnitClassBase, unit)
end

function P.Kinds()
	local on = {}
	for _, switch in ipairs(SWITCHES) do
		for _, kind in ipairs(switch[2]) do
			on[kind] = Opt(switch[1]) == true
		end
	end
	return on
end

local function Rank(kind)
	for rank, switch in ipairs(SWITCHES) do
		for _, number in ipairs(switch[2]) do
			if number == kind then
				return rank
			end
		end
	end
	return #SWITCHES + 1
end

function P.Knows(a)
	local known = P.known[a.key]
	if known ~= nil then
		return known
	end
	local book = type(C_SpellBook) == "table" and C_SpellBook or {}
	local call = book.IsSpellKnownOrInSpellBook or book.IsSpellKnown
	if type(call) ~= "function" then
		return nil
	end
	known = false
	for _, id in ipairs(a.casts) do
		if T.Ask(call, id) == true then
			known = true
			break
		end
	end
	P.known[a.key] = known
	return known
end

function P.Listed(a, on, lists)
	return not lists.hidden[a.key] and (a.custom == true or on[a.kind] == true or lists.added[a.key] == true)
end

function P.Fits(row, a)
	if a.race and not P.RaceIs(row, a.race) then
		return false
	end
	local seen = T.Seen(row.owner, a.key)
	local talent = a.custom or a.classes or a.flags:find("t", 1, true) or a.flags:find("r", 1, true)
	if row.own then
		local known = P.Knows(a)
		if known == nil then
			known = not talent
		end
		return known or seen
	end
	return seen or (not (talent or a.flags:find("p", 1, true)) and (a.lvl == nil or not Plain(row.level, "number") or row.level <= 0 or row.level >= a.lvl))
end

function P.Candidates(row)
	local list = {}
	if type(ns.ABILITIES) ~= "table" or not row.class then
		return list
	end
	local on, lists = P.Kinds(), P.Lists()
	local indexes = {}
	for _, group in ipairs({ row.class, "ALL" }) do
		for _, index in ipairs(ns.ABILITIES_BY_CLASS[group] or {}) do
			indexes[#indexes + 1] = index
		end
	end
	table.sort(indexes)
	local last
	for _, index in ipairs(indexes) do
		local a = ns.ABILITIES[index]
		if index ~= last and P.Listed(a, on, lists) and not a.flags:find("n", 1, true) and P.Fits(row, a) then
			list[#list + 1] = { a = a, index = index }
		end
		last = index
	end
	for _, a in ipairs(lists.custom) do
		if not lists.hidden[a.key] and P.Fits(row, a) then
			list[#list + 1] = { a = a, index = 1000000 + a.id }
		end
	end
	local function Order(item)
		return (lists.added[item.a.key] or item.a.custom) and 0 or Rank(item.a.kind)
	end
	table.sort(list, function(x, y)
		local rx, ry = Order(x), Order(y)
		if rx ~= ry then
			return rx < ry
		end
		return x.index < y.index
	end)
	local abilities = {}
	for position = 1, math.min(#list, Opt("count")) do
		abilities[position] = list[position].a
	end
	return abilities
end

function P.CastNever(id)
	local level = P.level[id]
	if level == nil then
		local never = type(Enum) == "table" and type(Enum.SecrecyLevel) == "table" and Enum.SecrecyLevel.NeverSecret or nil
		level = never ~= nil and ns.CastLevel(id) == never
		P.level[id] = level
	end
	return level
end

function P.BuffNever(id)
	local never = P.never[id]
	if never == nil then
		never = T.NeverHidden(id)
		P.never[id] = never
	end
	return never
end

function P.Hears(unit, what)
	local rec = T.units[unit]
	local want = rec and rec.want[KEY]
	return want ~= nil and want[what] == true
end

function P.CanSee(row, a)
	if row.own then
		return true
	end
	local sync = ns.PartySync
	if sync and sync.Shares(row.owner) then
		return true
	end
	local unit = row.unit
	if #a.casts > 0 and P.Hears(unit, "cast") then
		if ns.CanSeeCasts(unit) == true then
			return true
		end
		for _, id in ipairs(a.casts) do
			if P.CastNever(id) then
				return true
			end
		end
	end
	if #a.buffs > 0 and P.Hears(unit, "aura") and (not a.flags:find("o", 1, true) or T.lastCaster == "readable") then
		if ns.AurasReadable() == true then
			return true
		end
		for _, id in ipairs(a.buffs) do
			if P.BuffNever(id) then
				return true
			end
		end
	end
	return false
end

function P.Visible(row)
	local list = {}
	local always = Opt("show") == "always"
	for _, a in ipairs(P.Candidates(row)) do
		local start, seconds = T.Timer(row.owner, a.key)
		if start or (always and P.CanSee(row, a)) then
			list[#list + 1] = { a = a, start = start, seconds = seconds }
		end
	end
	return list
end

function P.Texture(a)
	local file = P.tex[a.key]
	if file then
		return file
	end
	local spells = type(C_Spell) == "table" and C_Spell or {}
	for _, id in ipairs(a.casts) do
		local answer = T.Ask(spells.GetSpellTexture, id)
		if Plain(answer, "number") or Plain(answer, "string") then
			P.tex[a.key] = answer
			return answer
		end
	end
	return UNKNOWN_ICON
end

function P.Sweep(a)
	local spell = P.last[a.key] or a.casts[1]
	local call = type(C_Spell) == "table" and C_Spell.GetSpellCooldownDuration or nil
	if type(call) ~= "function" then
		return nil
	end
	local ok, object = pcall(call, spell, true)
	if ok and (IsSecret(object) or object ~= nil) then
		return object
	end
	return nil
end

function P.Kit(seconds)
	local least = Opt("soundMinimum")
	if ns.Finite(seconds) and ns.Finite(least) and seconds < least then
		return nil
	end
	local sound = ns.SOUNDS[KITS[Opt("sound")] or 0]
	return sound and sound[1] or nil
end

function P.Draw(row, slot, item)
	local icon = row.icons[slot]
	local key = "none"
	local seconds
	if item then
		seconds = item.seconds
		if row.own and item.start then
			seconds = P.Sweep(item.a) or seconds
		end
		key = ("%s:%s:%s:%s:%s:%s:%s:%s:%s:%s"):format(item.a.key, tostring(item.start), type(seconds) == "table" and "object" or "number", tostring(Opt("seconds")),
			Opt("numbersFont"), tostring(Opt("iconBorder")), tostring(Opt("kindBorder")), tostring(Opt("flash")), tostring(Opt("sound")), tostring(Opt("soundMinimum")))
	end
	if row.drawn[slot] == key then
		return
	end
	row.drawn[slot] = key
	if not item then
		icon.key = nil
		ns.IconClear(icon)
		return
	end
	icon.key = item.a.key
	local used = item.start ~= nil
	if not used then
		pcall(icon.cooldown.Clear, icon.cooldown)
	end
	local kit = used and P.Kit(item.seconds) or nil
	ns.IconSet(icon, P.Texture(item.a), item.start, seconds, { kind = Opt("kindBorder") ~= false and item.a.kind or nil, numbers = Opt("seconds") == true,
		font = Opt("numbersFont"), border = Opt("iconBorder"), flash = Opt("flash") == true and used, sound = kit, key = KEY })
	local level = used and DARK or 1
	icon.texture:SetDesaturated(used)
	icon.texture:SetVertexColor(level, level, level)
end

function P.Fade(row, word)
	word = word or nil
	if row.gone == word then
		return
	end
	row.gone = word
	local level = word and GONE or 1
	row.holder:SetAlpha(level)
	if row.label then
		row.label:SetAlpha(level)
	end
end

function P.Gone(row)
	local unit = row.unit
	if not unit then
		return row.testing and row.sampleGone or false
	end
	if T.Ask(UnitIsConnected, unit) == false then
		return "Offline"
	end
	local dead, why = T.Ask(UnitIsDeadOrGhost, unit)
	if dead == true then
		return "Dead"
	elseif dead == nil and why == "hidden" then
		return nil
	end
	return false
end

function P.Unrange(row)
	if row.ranged then
		row.ranged = nil
		row.holder:SetAlpha(1)
		if row.label then
			row.label:SetAlpha(1)
		end
	end
end

function P.Range(row)
	if row.gone then
		row.ranged = nil
		return
	end
	if Opt("range") == false then
		P.Unrange(row)
		return
	end
	if not row.unit then
		if row.testing and row.sampleFar then
			row.ranged = true
			row.holder:SetAlpha(FAR)
			if row.label then
				row.label:SetAlpha(FAR)
			end
		else
			P.Unrange(row)
		end
		return
	end
	if T.Ask(UnitIsUnit, row.unit, "player") ~= false or type(UnitInRange) ~= "function" or type(row.holder.SetAlphaFromBoolean) ~= "function" then
		P.Unrange(row)
		return
	end
	local ok, inRange = pcall(UnitInRange, row.unit)
	if not ok or not (IsSecret(inRange) or type(inRange) == "boolean") then
		P.Unrange(row)
		return
	end
	row.ranged = true
	local done = pcall(row.holder.SetAlphaFromBoolean, row.holder, inRange, 1, FAR)
	if done and row.label and type(row.label.SetAlphaFromBoolean) == "function" then
		done = pcall(row.label.SetAlphaFromBoolean, row.label, inRange, 1, FAR)
	end
	if done then
		P.rangeRefused = nil
	else
		P.Unrange(row)
		P.rangeRefused = true
	end
end

function P.RenderRow(row)
	local gone = P.Gone(row)
	if gone ~= nil then
		P.Fade(row, gone)
	end
	P.Range(row)
	if row.testing then
		return
	end
	if row.flashEnd then
		if T.Now() < row.flashEnd then
			return
		end
		row.flashEnd = nil
	end
	local list = P.Visible(row)
	for slot = 1, #row.icons do
		P.Draw(row, slot, list[slot])
	end
end

function P.Render()
	for _, row in pairs(P.assigned) do
		P.RenderRow(row)
	end
end

function P.Done(row, icon)
	if row.testing then
		return
	end
	if row.own and icon.key then
		T.Drop(row.owner, icon.key)
	end
	local look = icon.look
	if look and look.flash and Opt("show") ~= "always" and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		local owner = row.owner
		row.flashEnd = T.Now() + FLASH - 0.05
		C_Timer.After(FLASH, function()
			if row.owner == owner then
				ns.Try(KEY, P.RenderRow, row)
			end
		end)
		return
	end
	P.RenderRow(row)
end

function P.Take(owner)
	local row = P.assigned[owner]
	if row then
		return row
	end
	row = table.remove(P.pool)
	if not row then
		if not ns.IconRow.CanMake(UIParent) then
			return nil
		end
		local frame = CreateFrame("Frame", nil, UIParent)
		ns.Own[frame] = true
		frame:SetSize(1, 1)
		row = { holder = frame, icons = {}, drawn = {} }
	end
	row.owner, row.own, row.testing = owner, nil, nil
	P.assigned[owner] = row
	return row
end

function P.Release(row)
	P.assigned[row.owner] = nil
	row.owner, row.unit, row.frame, row.side, row.testing, row.stackAt, row.flashEnd, row.sampleGone = nil, nil, nil, nil, nil, nil, nil, nil
	row.sampleFar = nil
	for slot, icon in ipairs(row.icons) do
		P.Untip(icon)
		ns.IconClear(icon)
		row.drawn[slot] = nil
	end
	if row.label then
		row.label:Hide()
	end
	P.Fade(row, nil)
	P.Unrange(row)
	row.holder:Hide()
	P.pool[#P.pool + 1] = row
end

function P.Fit(row, size, count, side)
	local key = ("%s:%s:%s"):format(size, count, side)
	while #row.icons < count do
		local icon = ns.IconNew(row.holder)
		if not icon then
			break
		end
		icon.onDone = function()
			P.Done(row, icon)
		end
		icon.frame:SetScript("OnEnter", function()
			ns.Try(KEY, P.Tip, row, icon)
			P.TipTick(row, icon)
		end)
		icon.frame:SetScript("OnLeave", function()
			ns.Try(KEY, P.Untip, icon)
		end)
		row.icons[#row.icons + 1] = icon
	end
	for _, icon in ipairs(row.icons) do
		P.Mouse(icon)
	end
	if row.fitKey == key and row.fitCount == #row.icons then
		return
	end
	row.fitKey, row.fitCount = key, #row.icons
	local width = ns.IconLayout(row.icons, row.holder, size, SPACING, side == "left" and "left" or "right")
	row.holder:SetSize(math.max(width, 1), size)
end

local function Tooltip()
	local tip = _G.GameTooltip
	if tip == nil or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

local function Owned(icon)
	local tip = Tooltip()
	if not tip then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, icon.frame)
	return ok and not IsSecret(owned) and owned == true
end

function P.Mouse(icon)
	local tips = Opt("tooltips") or "on"
	if icon.tips == tips then
		return
	end
	local frame = icon.frame
	if pcall(frame.SetMouseClickEnabled, frame, false) and pcall(frame.SetMouseMotionEnabled, frame, tips ~= "off") then
		icon.tips = tips
	end
	if tips == "off" then
		P.Untip(icon)
	end
end

function P.MouseAll()
	for _, row in pairs(P.assigned) do
		for _, icon in ipairs(row.icons) do
			P.Mouse(icon)
		end
	end
end

local function Clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function P.Tip(row, icon)
	local tips = Opt("tooltips") or "on"
	local tip = Tooltip()
	if not tip or tips == "off" or (tips == "out" and InCombatLockdown()) then
		return
	end
	local a = P.ByKey(icon.key)
	if not a and not row.testing then
		return
	end
	local who = row.unit and Text(UnitName, row.unit) or row.labelText
	local start, seconds
	if a and not row.testing and row.owner then
		start, seconds = T.Timer(row.owner, a.key)
	end
	local sync = ns.PartySync
	local shares = not row.testing and not row.own and row.owner and sync and sync.Shares(row.owner)
	local gone = P.Gone(row)
	pcall(function()
		tip:SetOwner(icon.frame, "ANCHOR_TOP")
		if row.testing then
			tip:SetText("Sample", 1, 1, 1)
			if a then
				tip:AddLine(P.Name(a), ns.KindColour(a.kind))
			end
		else
			local r, g, b = ns.KindColour(a.kind)
			tip:SetText(P.Name(a), r or 1, g or 1, b or 1)
		end
		if type(who) == "string" and who ~= "" then
			tip:AddLine(who, 1, 1, 1)
		end
		if row.testing then
			tip:AddLine("A sample of test mode.", DIM[1], DIM[2], DIM[3])
		elseif start and seconds then
			tip:AddLine(("Ready in %s"):format(Clock(start + seconds - T.Now())), DIM[1], DIM[2], DIM[3])
		else
			tip:AddLine("Ready", READY[1], READY[2], READY[3])
		end
		if gone then
			tip:AddLine(gone, DIM[1], DIM[2], DIM[3])
		end
		if shares then
			tip:AddLine("Shared by Flat UI", DIM[1], DIM[2], DIM[3])
		end
		tip:Show()
	end)
	return true
end

function P.TipTick(row, icon)
	if icon.tipTicker or type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then
		return
	end
	local ok, ticker = pcall(C_Timer.NewTicker, 1, function()
		ns.Try(KEY, P.Retip, row, icon)
	end)
	icon.tipTicker = ok and ticker or nil
end

function P.Retip(row, icon)
	local ok, visible = pcall(icon.frame.IsVisible, icon.frame)
	if not Owned(icon) or not ok or visible ~= true or not P.Tip(row, icon) then
		P.Untip(icon)
	end
end

function P.Untip(icon)
	local ticker = icon.tipTicker
	icon.tipTicker = nil
	if ticker then
		pcall(ticker.Cancel, ticker)
	end
	if Owned(icon) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
end

function P.Anchor(row, frame, side)
	if row.frame == frame and row.side == side and row.anchored then
		return
	end
	local holder = row.holder
	holder:ClearAllPoints()
	if side == "left" then
		holder:SetPoint("RIGHT", frame, "LEFT", -GAP, 0)
	elseif side == "below" then
		holder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, BELOW)
	else
		holder:SetPoint("LEFT", frame, "RIGHT", GAP, 0)
	end
	row.frame, row.side, row.anchored = frame, side, true
	row.above, row.aboveFrame, row.stackAt = nil, nil, nil
	if row.label then
		row.label:Hide()
	end
end

function P.Above(row, other, side)
	local frame = side == "below" and other.frame or nil
	if row.above == other and row.side == side and row.aboveFrame == frame then
		return
	end
	local holder = row.holder
	holder:ClearAllPoints()
	if frame then
		holder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, SPACING)
	elseif side == "left" then
		holder:SetPoint("BOTTOMRIGHT", other.holder, "TOPRIGHT", 0, SPACING)
	else
		holder:SetPoint("BOTTOMLEFT", other.holder, "TOPLEFT", 0, SPACING)
	end
	row.above, row.aboveFrame, row.side, row.frame, row.anchored, row.stackAt = other, frame, side, nil, true, nil
	if row.label then
		row.label:Hide()
	end
end

function P.Stack()
	if not P.stack then
		local frame = Own(CreateFrame("Frame", nil, UIParent))
		frame:SetSize(220, 150)
		P.stack = frame
	end
	return P.stack
end

function P.PlaceStack(stack)
	stack:ClearAllPoints()
	local corner = Opt("grow") == "up" and "BOTTOMLEFT" or "TOPLEFT"
	local x, y = ns.MoverSpot(MOVER, corner)
	if x then
		stack:SetPoint(corner, UIParent, "BOTTOMLEFT", x, y)
	else
		stack:SetPoint("CENTER", UIParent, "CENTER", STACK_X, STACK_Y)
	end
end

function P.Stacked(row, stack, position, size, total)
	local up = Opt("grow") == "up"
	total = total or position
	if row.stackAt == position and row.stackSize == size and row.stackTotal == total and row.stackUp == up and row.anchored then
		return
	end
	local holder = row.holder
	holder:ClearAllPoints()
	if up then
		holder:SetPoint("BOTTOMLEFT", stack, "BOTTOMLEFT", LABEL_W, (total - position) * (size + SPACING))
	else
		holder:SetPoint("TOPLEFT", stack, "TOPLEFT", LABEL_W, -(position - 1) * (size + SPACING))
	end
	row.stackAt, row.stackSize, row.stackTotal, row.stackUp = position, size, total, up
	row.frame, row.side, row.above, row.aboveFrame, row.anchored = nil, nil, nil, nil, true
end

local function ClassRGB(class)
	local colours = RAID_CLASS_COLORS
	if not Plain(class, "string") or type(colours) ~= "table" or IsSecret(colours) then
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

function P.Label(row, stack, text, class)
	local label = row.label
	if not label then
		label = Own(stack:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
		label:SetWidth(LABEL_W - 4)
		label:SetJustifyH("RIGHT")
		label:SetWordWrap(false)
		pcall(label.SetMaxLines, label, 1)
		label:SetPoint("RIGHT", row.holder, "LEFT", -4, 0)
		row.label = label
		row.labelClass = nil
	end
	text = text or ""
	if row.labelText ~= text then
		label:SetText(text)
		row.labelText = text
	end
	class = Plain(class, "string") and class or ""
	if row.labelClass ~= class then
		row.labelClass = class
		local r, g, b = ClassRGB(class)
		label:SetTextColor(r or 1, g or 1, b or 1, 1)
	end
	label:SetAlpha(row.gone and GONE or 1)
	label:Show()
end

function P.Listen(members)
	local own = Opt("ownRow")
	T.Hear(KEY, "player", own, true)
	if own then
		T.Hear(KEY, "pet", true, false)
	else
		T.Deafen(KEY, "pet")
	end
	local wanted = {}
	for _, member in ipairs(members) do
		if member.unit ~= "player" then
			wanted[member.unit] = true
			T.Hear(KEY, member.unit, true, true)
		end
	end
	for _, unit in ipairs(T.Heard(KEY)) do
		if unit ~= "player" and unit ~= "pet" and not wanted[unit] then
			T.Deafen(KEY, unit)
		end
	end
end

function P.Cast(unit, spell)
	local owner, class = P.Who(unit)
	if not owner then
		return
	end
	local now = T.Now()
	local a = T.Cast(owner, class, spell, now)
	local custom = P.Lists().byCast[spell]
	if custom then
		T.Use(owner, class, custom, now, spell)
		a = a or custom
	end
	if a then
		P.Seconds(owner, a, now)
		if unit == "player" or unit == "pet" then
			P.last[a.key] = spell
		end
		P.Render()
	end
end

function P.Seconds(owner, a, at)
	local seconds = P.Lists().seconds[a.key]
	local book = seconds and T.Book(owner)
	local timer = book and book.timers[a.key]
	if timer and timer.start == at then
		timer.seconds = seconds
	end
end

function P.Aura(unit, id, start, seconds, source)
	local by = ns.ABILITY_BY_BUFF
	if type(by) ~= "table" then
		return
	end
	local who = source
	if who ~= nil and who ~= "player" and who ~= "pet" and not who:match("^party%d$") then
		return
	end
	local owner, class = P.Who(who or unit)
	if not owner then
		return
	end
	local started = false
	for _, group in ipairs({ type(class) == "string" and class or "ALL", "ALL" }) do
		for _, index in ipairs(by[group] and by[group][id] or {}) do
			local a = ns.ABILITIES[index]
			if a and (source ~= nil or not a.flags:find("o", 1, true)) and T.Use(owner, class, a, start, nil) then
				P.Seconds(owner, a, start)
				started = true
			end
		end
	end
	if started then
		P.Render()
	end
end

function P.ReleaseAll()
	for _, row in pairs(P.assigned) do
		P.Release(row)
	end
	if P.stack then
		P.stack:Hide()
	end
end

function P.SyncFrames(members)
	local side, size, count = Opt("side"), Opt("size"), Opt("count")
	local own = Opt("ownRow")
	P.frames, P.raidUnits = {}, {}
	local wanted, first, ownDone = {}, nil, false
	for _, member in ipairs(members) do
		if member.unit == "player" then
			member.owner = Text(UnitGUID, "player") or "player"
		else
			P.frames[member.unit] = member.frame
			member.owner = P.Owner(member.unit, member.frame)
		end
	end
	for _, member in ipairs(members) do
		local owner, mine = member.owner, member.unit == "player"
		if owner and (own or not mine) then
			local row = P.Take(owner)
			if row then
				wanted[owner] = true
				row.unit, row.class, row.own = member.unit, Text(UnitClassBase, member.unit), mine or nil
				row.level = mine and row.level or T.Ask(UnitLevel, member.unit)
				row.race, row.raceFile = P.Race(member.unit)
				P.Fit(row, size, count, side)
				P.Anchor(row, member.frame, side)
				row.holder:Show()
				first = first or row
				ownDone = ownDone or mine
			end
		end
	end
	if own and first and not ownDone then
		local owner = Text(UnitGUID, "player") or "player"
		local row = P.Take(owner)
		if row then
			wanted[owner] = true
			row.unit, row.class, row.own = "player", Text(UnitClassBase, "player"), true
			row.race, row.raceFile = P.Race("player")
			P.Fit(row, size, count, side)
			P.Above(row, first, side)
			row.holder:Show()
		end
	end
	return wanted
end

function P.SyncRaid(members)
	local stack = P.Stack()
	P.PlaceStack(stack)
	local size, count = Opt("size"), Opt("count")
	P.frames, P.raidUnits = {}, {}
	local list = {}
	if Opt("ownRow") then
		list[1] = { unit = "player", own = true }
	end
	for _, member in ipairs(members) do
		list[#list + 1] = member
		P.raidUnits[member.unit] = true
	end
	local wanted, rows = {}, {}
	for _, member in ipairs(list) do
		local unit = member.unit
		local owner = Text(UnitGUID, unit) or (member.own and "player" or nil)
		local row = owner and P.Take(owner)
		if row then
			rows[#rows + 1] = row
			wanted[owner] = true
			row.unit, row.class, row.own = unit, Text(UnitClassBase, unit), member.own
			row.level = T.Ask(UnitLevel, unit)
			row.race, row.raceFile = P.Race(unit)
			P.Fit(row, size, count, "right")
			P.Label(row, stack, Text(UnitName, unit), row.class)
			row.holder:Show()
		end
	end
	for position, row in ipairs(rows) do
		P.Stacked(row, stack, position, size, #rows)
	end
	stack:Show()
	return wanted
end

function P.Sync()
	P.queued = false
	local state, members = P.Look()
	if state == "none" and P.Holding() then
		state = "sample"
	end
	P.state = state
	if state == "sample" then
		P.SyncSample()
		return
	end
	if not LIVE[state] then
		P.ReleaseAll()
		T.DeafenAll(KEY)
		return
	end
	local wanted
	if state == "raid" then
		wanted = P.SyncRaid(members)
	else
		wanted = P.SyncFrames(members)
		if P.stack then
			P.stack:Hide()
		end
	end
	for owner, row in pairs(P.assigned) do
		if not wanted[owner] then
			P.Release(row)
		end
	end
	P.Listen(members)
	P.Render()
	P.HoldRows()
	P.Arm()
end

function P.Forget()
	P.level, P.never, P.known = {}, {}, {}
	P.Refresh()
end

function P.Refresh()
	if ns.PartySync then
		ns.PartySync.Refresh()
	end
	P.MouseAll()
	if InCombatLockdown() then
		if not P.queued then
			P.queued = true
			ns.OutOfCombat(function()
				ns.Try(KEY, P.Sync)
			end)
		end
		P.Render()
		return
	end
	P.Sync()
end

function P.Tick()
	P.armed = false
	if not LIVE[P.state] or not ns.Enabled(KEY) then
		return
	end
	if InCombatLockdown() then
		P.Render()
		if P.Look() ~= P.state and not P.queued then
			P.queued = true
			ns.OutOfCombat(function()
				ns.Try(KEY, P.Sync)
			end)
		end
		P.Arm()
	else
		P.Sync()
	end
end

function P.Arm()
	if P.armed or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	P.armed = true
	C_Timer.After(LOOK, function()
		ns.Try(KEY, P.Tick)
	end)
end

function P.OnRestriction(kind, state)
	if ns.PartySync then
		ns.PartySync.Restriction(kind, state)
	end
	if not LIVE[P.state] then
		return
	end
	P.Render()
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, function()
			ns.Try(KEY, P.Render)
		end)
	end
end

function P.Start()
	T.Subscribe(KEY, function(unit, spell)
		ns.Try(KEY, P.Cast, unit, spell)
	end, function(unit, id, start, seconds, source)
		ns.Try(KEY, P.Aura, unit, id, start, seconds, source)
	end)
	if ns.PartySync then
		ns.PartySync.Start()
	end
	P.Refresh()
end

function P.Roster()
	P.Forget()
	if ns.PartySync then
		ns.PartySync.Roster()
	end
end

function P.Message(...)
	if ns.PartySync then
		ns.PartySync.Receive(...)
	end
end

function P.Cooldown()
	if ns.PartySync then
		ns.PartySync.Cooldown()
	end
end

function P.Saved()
	local account = ns.Account()
	if type(account) ~= "table" then
		return nil
	end
	if type(account.abilities) ~= "table" then
		account.abilities = {}
	end
	local saved = account.abilities.party
	if type(saved) ~= "table" then
		saved = {}
		account.abilities.party = saved
	end
	local function Whole(value, most)
		return Plain(value, "number") and value >= 1 and value <= most and value == math.floor(value)
	end
	for _, field in ipairs({ "added", "hidden" }) do
		local map = {}
		for key, yes in pairs(type(saved[field]) == "table" and saved[field] or {}) do
			if type(key) == "string" and #key <= 120 and yes == true then
				map[key] = true
			end
		end
		saved[field] = map
	end
	local seconds, custom = {}, {}
	for key, value in pairs(type(saved.seconds) == "table" and saved.seconds or {}) do
		if type(key) == "string" and #key <= 120 and Whole(value, MOST_SECONDS) then
			seconds[key] = value
		end
	end
	for id, entry in pairs(type(saved.custom) == "table" and saved.custom or {}) do
		if Whole(id, MOST_ID) and type(entry) == "table" and Whole(entry.seconds, MOST_SECONDS) and type(entry.name) == "string" and entry.name ~= "" then
			custom[id] = { seconds = entry.seconds, name = entry.name }
		end
	end
	saved.seconds, saved.custom = seconds, custom
	return saved
end

function P.Lists()
	local lists = P.lists
	if lists then
		return lists
	end
	lists = { added = {}, hidden = {}, seconds = {}, custom = {}, byCast = {} }
	local saved = P.Saved()
	if not saved then
		return lists
	end
	for _, field in ipairs({ "added", "hidden", "seconds" }) do
		for key, value in pairs(saved[field]) do
			lists[field][key] = value
		end
	end
	for id, entry in pairs(saved.custom) do
		local a = { key = "custom:" .. id, class = "ALL", kind = 0, name = entry.name, cd = entry.seconds, casts = { id }, buffs = {}, flags = "", cat = 0,
			custom = true, id = id }
		lists.custom[#lists.custom + 1] = a
		lists.byCast[id] = a
	end
	table.sort(lists.custom, function(x, y)
		return x.id < y.id
	end)
	P.lists = lists
	return lists
end

function P.Changed()
	P.lists = nil
	P.Render()
end

local function Capital(class)
	return class:sub(1, 1) .. class:sub(2):lower()
end

function P.Name(a)
	if a.class and a.class ~= "ALL" then
		return ("%s (%s)"):format(a.name, Capital(a.class))
	end
	return a.name
end

function P.Every()
	local list = {}
	for _, a in ipairs(type(ns.ABILITIES) == "table" and ns.ABILITIES or {}) do
		list[#list + 1] = a
	end
	for _, a in ipairs(P.Lists().custom) do
		list[#list + 1] = a
	end
	return list
end

function P.Lines(abilities)
	local rows, count = {}, {}
	for _, a in ipairs(abilities) do
		local text = P.Name(a)
		count[text] = (count[text] or 0) + 1
		rows[#rows + 1] = { a.key, text, a }
	end
	for _, row in ipairs(rows) do
		if count[row[2]] > 1 then
			row[2] = ("%s, spell %d"):format(row[2], row[3].casts[1] or 0)
		end
	end
	table.sort(rows, function(x, y)
		local first, second = x[2]:lower(), y[2]:lower()
		if first ~= second then
			return first < second
		end
		return x[1] < y[1]
	end)
	return rows
end

function P.IsShown(a)
	return not a.flags:find("n", 1, true) and P.Listed(a, P.Kinds(), P.Lists())
end

function ns.PartyAbilityCandidates()
	local out = {}
	for _, a in ipairs(type(ns.ABILITIES) == "table" and ns.ABILITIES or {}) do
		if not a.flags:find("n", 1, true) and not P.IsShown(a) then
			out[#out + 1] = a
		end
	end
	return P.Lines(out)
end

function ns.PartyAbilityShown()
	local out = {}
	for _, a in ipairs(P.Every()) do
		if P.IsShown(a) then
			out[#out + 1] = a
		end
	end
	return P.Lines(out)
end

function P.ByKey(key)
	if type(key) ~= "string" then
		return nil
	end
	for _, a in ipairs(P.Every()) do
		if a.key == key then
			return a
		end
	end
	return nil
end

function P.ByCast(id)
	local found = {}
	for _, a in ipairs(P.Every()) do
		for _, cast in ipairs(a.casts) do
			if cast == id then
				found[#found + 1] = a
				break
			end
		end
	end
	return found
end

function P.ByName(text)
	local found, wanted = {}, text:lower()
	for _, a in ipairs(P.Every()) do
		if a.name:lower() == wanted or P.Name(a):lower() == wanted then
			found[#found + 1] = a
		end
	end
	return found
end

function P.Added(saved)
	local count = 0
	for _ in pairs(saved.added) do
		count = count + 1
	end
	for _ in pairs(saved.custom) do
		count = count + 1
	end
	return count
end

function P.Add(a, seconds)
	local saved = P.Saved()
	if not saved then
		return false, "Nothing can be saved yet."
	end
	if a.flags:find("n", 1, true) then
		return false, ("%s has no cooldown to show."):format(P.Name(a))
	end
	local shown = P.IsShown(a)
	local typed = seconds ~= nil and (a.custom and a.cd or P.Lists().seconds[a.key] or a.cd) ~= seconds
	if shown and not typed then
		return false, ("%s is already shown."):format(P.Name(a))
	end
	if not shown and not saved.added[a.key] and P.Added(saved) >= MOST_ADDED then
		return false, ("%d added abilities is the most."):format(MOST_ADDED)
	end
	saved.hidden[a.key] = nil
	if a.custom then
		if seconds then
			saved.custom[a.id].seconds = seconds
		end
	else
		if not shown then
			saved.added[a.key] = true
		end
		if seconds then
			saved.seconds[a.key] = seconds
		end
	end
	P.Changed()
	if seconds then
		return true, ("Added %s, %d seconds."):format(P.Name(a), seconds)
	end
	return true, ("Added %s."):format(P.Name(a))
end

function P.AddSpell(id, seconds)
	local saved = P.Saved()
	if not saved then
		return false, "Nothing can be saved yet."
	end
	local name = Text(C_Spell and C_Spell.GetSpellName, id)
	if not name then
		return false, ('No spell found for "%s".'):format(tostring(id))
	end
	if P.Added(saved) >= MOST_ADDED then
		return false, ("%d added abilities is the most."):format(MOST_ADDED)
	end
	saved.custom[id] = { seconds = seconds, name = name }
	P.Changed()
	return true, ("Added %s, %d seconds."):format(name, seconds)
end

function P.Hide(a)
	local saved = P.Saved()
	if not saved then
		return false, "Nothing can be saved yet."
	end
	if saved.hidden[a.key] then
		return false, ("%s is already hidden."):format(P.Name(a))
	elseif not P.IsShown(a) then
		return false, ("%s is not shown."):format(P.Name(a))
	end
	saved.added[a.key] = nil
	if a.custom then
		saved.custom[a.id] = nil
		P.Changed()
		return true, ("Removed %s."):format(P.Name(a))
	end
	saved.hidden[a.key] = true
	P.Changed()
	return true, ("Hid %s."):format(P.Name(a))
end

function ns.PartyAbilityAdd(key)
	local a = P.ByKey(key)
	if not a then
		return false, ('No ability found for "%s".'):format(tostring(key))
	end
	return P.Add(a)
end

function ns.PartyAbilityHide(key)
	local a = P.ByKey(key)
	if not a then
		return false, ('No ability found for "%s".'):format(tostring(key))
	end
	return P.Hide(a)
end

function P.Parse(text)
	local id = tonumber(text:match("|Hspell:(%d+)"))
	local rest = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|H[^|]*|h[^|]*|h", " "):gsub("|r", " ")
	if not id then
		local plain, tail = text:match("^spell:(%d+)%s*(.*)$")
		id, rest = tonumber(plain), tail
	end
	if id then
		return { id = id, seconds = tonumber(rest:match("^%s*(%d+)%s*$")) }
	end
	local head, tail = text:match("^(.-)%s+(%d+)$")
	if head and head ~= "" then
		if head:match("^%d+$") then
			return { id = tonumber(head), seconds = tonumber(tail) }
		end
		return { name = head, seconds = tonumber(tail) }
	end
	if text:match("^%d+$") then
		return { id = tonumber(text) }
	end
	return { name = text }
end

function P.Resolve(parsed, text)
	local found = parsed.id and P.ByCast(parsed.id) or P.ByName(parsed.name or text)
	if #found == 1 then
		return found[1]
	elseif #found > 1 then
		local lines = { ('More than one ability is "%s". Type a spell ID:'):format(parsed.id and tostring(parsed.id) or parsed.name or text) }
		for _, row in ipairs(P.Lines(found)) do
			lines[#lines + 1] = ("%s, spell %d"):format(P.Name(row[3]), row[3].casts[1] or 0)
		end
		return nil, table.concat(lines, "\n")
	end
	return nil, nil
end

function P.SlashAdd(text)
	local parsed = P.Parse(text)
	local seconds = parsed.seconds
	if seconds and (seconds < 1 or seconds > MOST_SECONDS) then
		print(("A cooldown is 1 to %d seconds."):format(MOST_SECONDS))
		return
	end
	local a, message = P.Resolve(parsed, text)
	if message then
		print(message)
	elseif a then
		print(select(2, P.Add(a, seconds)))
	elseif parsed.id then
		if not seconds then
			print(("Spell %d is not listed. Type its cooldown in seconds after the ID."):format(parsed.id))
		else
			print(select(2, P.AddSpell(parsed.id, seconds)))
		end
	else
		print(('No ability found for "%s".'):format(parsed.name or text))
	end
end

function P.SlashHide(text)
	local parsed = { name = text }
	local id = tonumber(text:match("|Hspell:(%d+)") or text:match("^spell:(%d+)") or text:match("^(%d+)$"))
	if id then
		parsed = { id = id }
	end
	local a, message = P.Resolve(parsed, text)
	if message then
		print(message)
	elseif a then
		print(select(2, P.Hide(a)))
	else
		print(('No ability found for "%s".'):format(parsed.id and tostring(parsed.id) or text))
	end
end

function P.SlashList()
	local classes, order = {}, {}
	for _, row in ipairs(ns.PartyAbilityShown()) do
		local a = row[3]
		local class = a.custom and "Added by spell ID" or (a.class == "ALL" and "Any class" or Capital(a.class))
		if not classes[class] then
			classes[class] = {}
			order[#order + 1] = class
		end
		classes[class][#classes[class] + 1] = a.name
	end
	table.sort(order)
	if #order == 0 then
		print("No abilities shown.")
	end
	for _, class in ipairs(order) do
		print(("%s: %s"):format(class, table.concat(classes[class], ", ")))
	end
	local state, members = P.Look()
	if not LIVE[state] then
		if state == "off" then
			print("Party cooldowns are off.")
		elseif state == "raidoff" then
			print("No rows shown. In a raid group is Off.")
		elseif T.Ask(IsInGroup) == true then
			print("No rows shown.")
		else
			print("Not in a party.")
		end
		return
	end
	for _, member in ipairs(members) do
		if member.unit ~= "player" then
			local guid = Text(UnitGUID, member.unit)
			local book = guid and T.Book(guid)
			print(("%s: %s"):format(Text(UnitName, member.unit) or member.unit, book and book.shares == true and "shares cooldowns" or "does not share cooldowns"))
		end
	end
end

function P.Undone(label, added, hidden, seconds)
	local parts = {}
	if added > 0 then
		parts[#parts + 1] = ("%d added"):format(added)
	end
	if hidden > 0 then
		parts[#parts + 1] = ("%d hidden"):format(hidden)
	end
	if seconds > 0 then
		parts[#parts + 1] = ("%d %s"):format(seconds, seconds == 1 and "cooldown" or "cooldowns")
	end
	if #parts == 0 then
		return ("%s: nothing to undo, the abilities are as shipped."):format(label)
	end
	local last = table.remove(parts)
	local list = #parts > 0 and (table.concat(parts, ", ") .. " and " .. last) or last
	return ("%s: the abilities are back as shipped (%s undone)."):format(label, list)
end

ns.AbilitiesUndone = P.Undone

function P.Reset()
	local saved = P.Saved()
	if not saved then
		print("Nothing can be saved yet.")
		return
	end
	local function Size(map)
		local count = 0
		for _ in pairs(map) do
			count = count + 1
		end
		return count
	end
	local added, hidden, seconds = P.Added(saved), Size(saved.hidden), Size(saved.seconds)
	saved.added, saved.hidden, saved.seconds, saved.custom = {}, {}, {}, {}
	P.Changed()
	print(P.Undone("Party cooldowns", added, hidden, seconds))
end

function P.Slash(rest)
	local word, text = (rest or ""):match("^(%S*)%s*(.-)%s*$")
	word = word:lower()
	if word == "add" and text ~= "" then
		P.SlashAdd(text)
	elseif word == "hide" and text ~= "" then
		P.SlashHide(text)
	elseif word == "list" then
		P.SlashList()
	elseif word == "reset" then
		P.Reset()
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

function ns.PartyRaidShown()
	return ns.Enabled(KEY) and ((Opt("raid") == "own" and T.Ask(IsInRaid) == true) or (P.state == "sample" and TM.IsOn()))
end

function ns.PartyRaidMoved()
	if P.stack and ns.Enabled(KEY) then
		ns.OutOfCombat(function()
			P.PlaceStack(P.stack)
		end)
	end
end

P.HELD = {}

function P.Holding()
	return TM.IsOn() and ns.Enabled(KEY) and not InCombatLockdown()
end

function P.Hold(row)
	row.testing = P.HELD
	local abilities = P.Candidates(row)
	local count = math.min(3, #row.icons)
	for slot, icon in ipairs(row.icons) do
		row.drawn[slot] = nil
		local a = abilities[slot]
		icon.key = a and a.key or nil
		if slot <= count then
			local look = { kind = Opt("kindBorder") ~= false and a and a.kind or nil, numbers = Opt("seconds") == true, font = Opt("numbersFont"),
				border = Opt("iconBorder") }
			local texture = a and P.Texture(a) or ns.IconSamplePicture(slot)
			local used = slot > 1 or Opt("show") ~= "always"
			if not used then
				icon.held = nil
				pcall(icon.cooldown.Clear, icon.cooldown)
				ns.IconSet(icon, texture, nil, nil, look)
			else
				look.kind, look.flash, look.sound = look.kind or (Opt("kindBorder") ~= false or nil), Opt("flash") == true, P.Kit() or false
				ns.IconSampleHeld(icon, slot, KEY, look, texture)
			end
			local level = used and DARK or 1
			icon.texture:SetDesaturated(used)
			icon.texture:SetVertexColor(level, level, level)
		else
			icon.held = nil
			ns.IconClear(icon)
		end
	end
end

function P.Unhold(row)
	row.testing = nil
	for slot, icon in ipairs(row.icons) do
		row.drawn[slot] = nil
		icon.held = nil
	end
end

function P.HoldRows()
	if P.testing then
		return
	end
	local holding = P.Holding()
	for _, row in pairs(P.assigned) do
		if holding then
			P.Hold(row)
		elseif row.testing == P.HELD then
			P.Unhold(row)
			P.RenderRow(row)
		end
	end
end

function P.SyncSample()
	local stack = P.Stack()
	P.PlaceStack(stack)
	local size, count = Opt("size"), Opt("count")
	P.frames, P.raidUnits = {}, {}
	local list = {}
	if Opt("ownRow") then
		list[1] = { owner = "test:player", class = Text(UnitClassBase, "player"), name = Text(UnitName, "player") }
	end
	if TM.Group() ~= "solo" then
		for index, member in ipairs(SAMPLE_PARTY) do
			list[#list + 1] = { owner = "test:" .. index, class = member[2], name = member[1], gone = member[3], far = member.far }
		end
	end
	local wanted, rows = {}, {}
	for _, member in ipairs(list) do
		local row = P.Take(member.owner)
		if row then
			rows[#rows + 1] = row
			wanted[member.owner] = true
			row.unit, row.class, row.own, row.level, row.race, row.raceFile = nil, member.class, nil, nil, nil, nil
			row.sampleGone, row.sampleFar = member.gone, member.far
			P.Fit(row, size, count, "right")
			P.Label(row, stack, member.name, member.class)
			P.Hold(row)
			P.Fade(row, member.gone)
			P.Range(row)
			row.holder:Show()
		end
	end
	for position, row in ipairs(rows) do
		P.Stacked(row, stack, position, size, #rows)
	end
	for owner, row in pairs(P.assigned) do
		if not wanted[owner] then
			P.Release(row)
		end
	end
	T.DeafenAll(KEY)
	stack:Show()
end

function P.TestStop()
	for _, row in pairs(P.assigned) do
		if row.testing == P.HELD then
			if P.state == "sample" then
				P.Release(row)
			else
				P.Unhold(row)
			end
		end
	end
	if P.state == "sample" and P.stack then
		P.stack:Hide()
	end
end

function P.TestTick(now)
	for _, row in pairs(P.assigned) do
		if row.testing == P.HELD then
			ns.IconSampleLoop(row.icons, now)
		end
	end
end

function ns.PartyTest()
	if not ns.Enabled(KEY) or InCombatLockdown() or not LIVE[P.state] then
		if ns.Enabled(KEY) then
			print("Party cooldowns: the test shows in a party, out of combat.")
		end
		return
	end
	local token = {}
	P.testing = token
	local now = T.Now()
	local shown = 0
	local cue = { flash = Opt("flash") == true, sound = P.Kit() or false }
	for _, row in pairs(P.assigned) do
		row.testing = token
		for slot = 1, math.min(3, #row.icons) do
			local icon = row.icons[slot]
			row.drawn[slot] = nil
			ns.IconSample(icon, slot, now, 2 * slot, KEY, cue)
			icon.texture:SetDesaturated(false)
			icon.texture:SetVertexColor(1, 1, 1)
		end
		for slot = 4, #row.icons do
			row.drawn[slot] = nil
			ns.IconClear(row.icons[slot])
		end
		shown = shown + 1
	end
	if shown == 0 then
		return
	end
	print("Party cooldowns: sample icons on each row for 8 seconds.")
	local function Over()
		if P.testing ~= token then
			return
		end
		P.testing = nil
		for _, row in pairs(P.assigned) do
			row.testing = nil
			for slot = 1, #row.icons do
				row.drawn[slot] = nil
			end
		end
		P.Render()
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(TEST_TIME, function()
			ns.Try(KEY, Over)
		end)
	end
end

function P.Status()
	local lines = {}
	local state, members = P.Look()
	if state == "raid" and P.via == "roster" then
		lines[#lines + 1] = LINE_ROSTER
	end
	if P.rangeRefused then
		lines[#lines + 1] = LINE_RANGE
	end
	for _, member in ipairs(LIVE[state] and members or {}) do
		if member.unit ~= "player" then
			if ns.CanSeeCasts(member.unit) == false then
				lines[#lines + 1] = LINE_CASTS
			end
			break
		end
	end
	return lines
end

function P.Group()
	if ns.PartySync then
		ns.PartySync.Regroup()
	end
	P.Roster()
end

ns.Register(KEY, {
	label = "Party cooldowns",
	counted = false,
	Start = P.Start,
	Refresh = P.Refresh,
	events = {
		GROUP_ROSTER_UPDATE = P.Group,
		PLAYER_ENTERING_WORLD = P.Roster,
		EDIT_MODE_LAYOUTS_UPDATED = P.Refresh,
		SPELLS_CHANGED = P.Roster,
		ADDON_RESTRICTION_STATE_CHANGED = P.OnRestriction,
		CHAT_MSG_ADDON = P.Message,
		SPELL_UPDATE_COOLDOWN = P.Cooldown,
	},
	filters = {
		CHAT_MSG_ADDON = function(prefix)
			return not IsSecret(prefix) and prefix == "FlatUI"
		end,
	},
	Status = P.Status,
	slash = { party = P.Slash },
	help = HELP,
})

TM.Register(KEY, {
	module = KEY,
	label = "Party cooldowns",
	refresh = true,
	Stop = P.TestStop,
	Tick = P.TestTick,
})

ns.PartyCooldownsModule = P
