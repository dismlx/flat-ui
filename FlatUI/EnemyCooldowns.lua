local _, ns = ...

local KEY = "enemycd"
local SPACING = 2
local BELOW = 1
local MOST = 4
local BAR_MOST = 8
local BAR_UP = 4
local LOOK = 0.5
local TEST_TIME = 8
local UNKNOWN_ICON = 134400
local HOLD = 0.5
local JUST = 1
local NET_LATE = 0.1
local DARK = 0.6
local READY = { 0.4, 0.9, 0.4 }
local DIM = { 0.66, 0.68, 0.62 }
local UNKNOWN = 0.45
local MARK_FONTS = { { 22, "NumberFontNormalSmall" }, { 36, "NumberFontNormal" }, { 52, "NumberFontNormalLarge" }, { math.huge, "NumberFontNormalHuge" } }
local AURA, AURAS_BESIDE, CC_GAP = 25, 2, 5
local RAID_MARK, CLASSIFICATION, BUFF_GAP = 22, 20, 5
local ICON_GAP = 3
local NO_START = { [8178] = true }
local MOST_ADDED, MOST_SECONDS, MOST_ID = 30, 86400, 9999999
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local HELP = {
	"/flatui enemy add Blink 15 - an ability, a spell ID or a shift-clicked spell, and its cooldown in seconds",
	"/flatui enemy hide 2139 - an ability or a spell ID",
	"/flatui enemy list - the abilities shown and whether their use can be seen here",
	"/flatui enemy clear - forgets the running timers of enemies",
}
local PLATES = 40
local SWITCHES = { { "interrupts", { 1 } }, { "wards", { 6 } }, { "breaks", { 5 } }, { "defensives", { 2 } }, { "mobility", { 7 } }, { "offensive", { 8 } } }
local LINE_CASTS = "Enemy cooldowns: the game hides enemy casts. Abilities with a buff are tracked while you are out of combat."
local LINE_HERE = "Enemy cooldowns: the game hides enemy casts and buffs here. Timers already running stay."
local LINE_UNKNOWN = "Enemy cooldowns: an ability whose use the game hides shows dim with a question mark, not as ready."
local LINE_PLATES = "Enemy cooldowns: some nameplates show no icons."
local LINE_WAIT = "Enemy cooldowns: a bar waits for the nameplate of its unit, whose identity the game hides."
local LINE_ARENA = "Crowd control break in arenas: the game refused the arena call."
local ARENA_OPPONENTS = 5
local SAMPLE_KEYS = { "ROGUE:Kick", "MAGE:Ice Block", "PALADIN:Divine Shield" }

local IsSecret = ns.IsSecret
local T = ns.Tracking
local TM = ns.TestMode
local E = { plates = {}, rows = setmetatable({}, { __mode = "k" }), stuck = {}, tex = {}, byKey = nil, order = nil, never = {}, holds = setmetatable({}, { __mode = "k" }),
	owners = setmetatable({}, { __mode = "k" }),
	sight = -math.huge, open = nil,
	arena = { on = false, stamp = 0, tex = {}, raised = false, durationRaised = false },
	bars = { target = { unit = "target", mover = "FlatUIEnemyTarget", frame = "TargetFrame" }, focus = { unit = "focus", mover = "FlatUIEnemyFocus", frame = "FocusFrame" } } }

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

local function Soon(fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

function E.UnitFrameOf(unit)
	local plate = T.Ask(type(C_NamePlate) == "table" and C_NamePlate.GetNamePlateForUnit or nil, unit)
	if type(plate) ~= "table" then
		return nil
	end
	local ok, frame = pcall(function()
		return plate.UnitFrame
	end)
	if not ok or ns.Forbidden(frame) then
		return nil
	end
	return frame
end

function E.PlatesOn()
	return Opt("place") ~= "bars"
end

function E.BarsOn()
	return Opt("place") ~= "plates"
end

function E.Enemy(unit)
	return T.Ask(UnitIsPlayer, unit) == true and T.Ask(UnitCanAttack, "player", unit) == true
end

function E.Target(frame)
	for _, name in ipairs({ "WidgetContainer", "CastBarsContainer" }) do
		local ok, part = pcall(function()
			return frame[name]
		end)
		if ok and not ns.Forbidden(part) then
			return part
		end
	end
	return frame
end

function E.Part(frame, ...)
	local part = frame
	for index = 1, select("#", ...) do
		local key = select(index, ...)
		local ok, found = pcall(function()
			return part[key]
		end)
		if not ok or ns.Forbidden(found) then
			return nil
		end
		part = found
	end
	return part
end

function E.Shown(part)
	if not part then
		return false
	end
	local ok, shown = pcall(part.IsShown, part)
	return ok and Plain(shown, "boolean") and shown
end

function E.AuraScale(frame)
	local auras = E.Part(frame, "AurasFrame")
	if not auras then
		return 1
	end
	local ok, scale = pcall(function()
		return auras.auraItemScale
	end)
	if ok and ns.Finite(scale) and scale > 0 then
		return math.min(scale, 4)
	end
	return 1
end

function E.NameInside()
	local options, constants = NamePlateSetupOptions, NamePlateConstants
	if not (Plain(options, "table") and Plain(constants, "table")) then
		return false
	end
	local ok, style, inside = pcall(function()
		return options.unitNameAnchorStyle, constants.NAME_ANCHOR_STYLES.InsideHealthBar
	end)
	return ok and Plain(style, "number") and Plain(inside, "number") and style == inside
end

function E.Padding()
	local number = tonumber(Text(type(C_CVar) == "table" and C_CVar.GetCVar or nil, "nameplateDebuffPadding") or "")
	return ns.Finite(number) and math.max(number, 0) or 0
end

function E.IconAbove(frame)
	if not (ns.Enabled("nameplates") and ns.Get("nameplates.classEnemy") == true and ns.Get("nameplates.classPosition") == "above") then
		return 0
	end
	local size = ns.Get("nameplates.classSize")
	if ns.Get("nameplates.classFit") == "bar" then
		local bar = E.Part(frame, "HealthBarsContainer")
		local ok, height = false, nil
		if bar then
			ok, height = pcall(bar.GetHeight, bar)
		end
		size = ok and ns.Finite(height) and height or size
	end
	local up = ns.Get("nameplates.classY")
	return ICON_GAP + (ns.Finite(size) and size or 0) + (ns.Finite(up) and math.max(up, 0) or 0)
end

function E.Spot(frame)
	local place = Opt("platePlace")
	local scale = E.AuraScale(frame)
	local beside = AURAS_BESIDE * AURA * scale + SPACING
	if place == "right" then
		local list = E.Part(frame, "AurasFrame", "CrowdControlListFrame")
		if list then
			return "LEFT", list, "LEFT", beside, 0, "right"
		end
		local level, bar = E.Part(frame, "PlayerLevelDiffFrame"), E.Part(frame, "HealthBarsContainer")
		if bar then
			return "LEFT", E.Shown(level) and level or bar, "RIGHT", CC_GAP + beside, 0, "right"
		end
	elseif place == "left" then
		local list = E.Part(frame, "AurasFrame", "BuffListFrame")
		if list then
			return "RIGHT", list, "RIGHT", -beside, 0, "left"
		end
		local bar = E.Part(frame, "HealthBarsContainer")
		if bar then
			return "RIGHT", bar, "LEFT", -(RAID_MARK + CLASSIFICATION + BUFF_GAP + beside), 0, "left"
		end
	elseif place == "above" then
		local base = E.Part(frame, "name")
		if E.NameInside() then
			base = E.Part(frame, "HealthBarsContainer", "healthBar") or E.Part(frame, "HealthBarsContainer") or base
		end
		if base then
			return "BOTTOM", base, "TOP", 0, math.max(E.Padding() + AURA * scale, E.IconAbove(frame)) + SPACING, "center"
		end
	end
	return "TOP", E.Target(frame), "BOTTOM", 0, -BELOW, "center"
end

function E.Ability(key)
	if not E.byKey then
		local map, order = {}, {}
		for index, a in ipairs(ns.ABILITIES or {}) do
			map[a.key], order[a.key] = a, index
		end
		E.byKey, E.order = map, order
	end
	return E.byKey[key]
end

function E.Rank(a)
	local lists = E.Lists()
	if lists.hidden[a.key] then
		return nil
	elseif a.custom or lists.added[a.key] then
		return 0
	end
	for rank, switch in ipairs(SWITCHES) do
		if Opt(switch[1]) == true then
			for _, kind in ipairs(switch[2]) do
				if a.kind == kind then
					return rank
				end
				for _, also in ipairs(a.also or {}) do
					if also == kind then
						return rank
					end
				end
			end
		end
	end
	return nil
end

function E.Items(rec, most)
	local list = {}
	local book = T.Book(rec.owner)
	local have = {}
	E.Sight()
	for key, last in pairs(book and book.timers or {}) do
		local a = E.Ability(key)
		local rank = a and E.Rank(a)
		if rank then
			local start, seconds = T.Timer(rec.owner, key)
			if start then
				list[#list + 1] = { a = a, start = start, seconds = seconds, rank = rank, over = start + seconds }
				have[key] = true
			else
				E.Ended(rec, key, last)
			end
		end
	end
	E.Held(rec, list, have)
	if Opt("show") == "always" then
		E.Bright(rec, list, have)
		for _, item in ipairs(list) do
			item.over = 0
		end
	end
	table.sort(list, function(x, y)
		if x.rank ~= y.rank then
			return x.rank < y.rank
		elseif x.over ~= y.over then
			return x.over < y.over
		end
		return E.order[x.a.key] < E.order[y.a.key]
	end)
	for _, field in ipairs({ "unknown", "ready" }) do
		for index = #list, 1, -1 do
			if #list <= (most or MOST) then
				break
			elseif list[index][field] then
				table.remove(list, index)
			end
		end
	end
	while #list > (most or MOST) do
		list[#list] = nil
	end
	return list
end

function E.RaceOf(rec)
	if rec.race == nil then
		local ok, name, file = pcall(UnitRace, rec.unit)
		rec.race = ok and Plain(name, "string") and name or false
		rec.raceFile = ok and Plain(file, "string") and file or false
	end
	return rec.race, rec.raceFile
end

function E.RaceIs(rec, race)
	local name, file = E.RaceOf(rec)
	return name == race or (file and (file == race:gsub("%s", "") or (file == "Scourge" and race == "Undead"))) or false
end

function E.Fits(rec, a)
	if a.race and not E.RaceIs(rec, a.race) then
		return false
	end
	if a.custom or a.classes or a.flags:find("[trp]") then
		return T.Seen(rec.owner, a.key)
	end
	if rec.level == nil then
		local level = T.Ask(UnitLevel, rec.unit)
		rec.level = Plain(level, "number") and level or false
	end
	return a.lvl == nil or not rec.level or rec.level <= 0 or rec.level >= a.lvl
end

function E.Crowd(a)
	if a.kind == 4 then
		return true
	end
	for _, also in ipairs(a.also or {}) do
		if also == 4 then
			return true
		end
	end
	return false
end

function E.Harmful(id)
	return T.Ask(type(C_Spell) == "table" and C_Spell.IsSpellHarmful or nil, id) == true
end

function E.AuraLevel(id)
	local level = T.Ask(type(C_Secrets) == "table" and C_Secrets.GetSpellAuraSecrecy or nil, id)
	return Plain(level, "number") and level or nil
end

function E.Ways(a)
	local ways = E.never[a.key]
	if ways then
		return ways
	end
	ways = { cast = false, buff = false, never = false }
	if not a.flags:find("p", 1, true) then
		for _, id in ipairs(a.casts) do
			local level = ns.CastLevel(id)
			ways.cast = ways.cast or level ~= 1
			ways.never = ways.never or level == 0
		end
		if not a.flags:find("o", 1, true) and not E.Crowd(a) then
			for _, id in ipairs(a.buffs) do
				if not NO_START[id] and not E.Harmful(id) and E.AuraLevel(id) ~= 1 then
					ways.buff = true
					ways.never = ways.never or T.NeverHidden(id) == true
				end
			end
		end
	end
	E.never[a.key] = ways
	return ways
end

function E.Cooldown(a)
	local seconds = E.Lists().seconds[a.key] or a.cd
	return Plain(seconds, "number") and seconds or 0
end

function E.Kick(a)
	return a.kind == 1 and not a.flags:find("p", 1, true)
end

function E.Sight()
	local open = ns.AurasReadable() == true
	if open and E.open == false then
		E.sight = T.Now()
	end
	E.open = open
end

function E.Seeable(a, rec, state)
	local ways = E.Ways(a)
	if ways.never then
		return true
	end
	if state.casts == nil then
		state.casts = ns.CanSeeCasts(rec.unit) == true
		state.auras = ns.AurasReadable() == true
	end
	return (state.casts and ways.cast) or (state.auras and ways.buff)
end

function E.Visible(a, rec, state)
	if not E.Seeable(a, rec, state) then
		return false
	end
	local ways = E.Ways(a)
	return ways.never or (state.casts and ways.cast) or T.Now() - E.sight >= E.Cooldown(a)
end

function E.Bright(rec, list, have)
	if type(ns.ABILITIES) ~= "table" or type(ns.ABILITIES_BY_CLASS) ~= "table" or type(rec.class) ~= "string" then
		return
	end
	local state, seen = {}, {}
	local function Add(a)
		local rank = not have[a.key] and E.Rank(a)
		if rank and a.cd ~= 0 and not a.flags:find("n", 1, true) and E.Fits(rec, a) then
			local known = E.Visible(a, rec, state)
			list[#list + 1] = { a = a, rank = rank, ready = true, unknown = not known or nil, over = 0 }
		end
	end
	for _, group in ipairs({ rec.class, "ALL" }) do
		for _, index in ipairs(ns.ABILITIES_BY_CLASS[group] or {}) do
			if not seen[index] and ns.ABILITIES[index] then
				seen[index] = true
				Add(ns.ABILITIES[index])
			end
		end
	end
	for _, a in ipairs(E.Lists().custom) do
		Add(a)
	end
end

function E.Held(rec, list, have)
	local held = E.holds[rec.owner]
	if not held then
		return
	end
	local now = T.Now()
	for key, over in pairs(held) do
		local a = E.Ability(key)
		local rank = a and E.Rank(a)
		if over <= now then
			held[key] = nil
		elseif rank and not have[key] then
			list[#list + 1] = { a = a, rank = rank, ready = true, hold = true, over = over }
			have[key] = true
		end
	end
	if next(held) == nil then
		E.holds[rec.owner] = nil
	end
end

local function Cue()
	return Opt("flash") == true or KITS[Opt("sound")] ~= nil
end

function E.Hears(rec)
	if rec.mover then
		return true
	end
	for _, unit in ipairs({ "target", "focus" }) do
		if rec.unit and T.Ask(UnitIsUnit, rec.unit, unit) == true then
			return true
		end
	end
	return false
end

function E.Ended(rec, key, last)
	if rec.owner == nil or type(last) ~= "table" or T.Now() - (last.start + last.seconds) > JUST then
		return
	end
	if not (Opt("flash") == true or (KITS[Opt("sound")] ~= nil and E.Hears(rec) and E.Loud(last.seconds))) then
		return
	end
	local held = E.holds[rec.owner] or {}
	if (held[key] or 0) <= T.Now() then
		held[key] = T.Now() + HOLD
		E.holds[rec.owner] = held
		if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			C_Timer.After(HOLD + 0.05, function()
				ns.Try(KEY, E.Render)
			end)
		end
	end
end

function E.Kit()
	local sound = ns.SOUNDS[KITS[Opt("sound")] or 0]
	return sound and sound[1] or nil
end

function E.Loud(seconds)
	local least = Opt("soundMinimum")
	return not (ns.Finite(seconds) and ns.Finite(least) and seconds < least)
end

function E.Flash(row, icon, seconds)
	local sound = ns.SOUNDS[KITS[Opt("sound")] or 0]
	if Opt("flash") then
		ns.IconFlash(icon)
	end
	if sound and row.rec and E.Hears(row.rec) and E.Loud(seconds) then
		ns.PlayKit(sound[1], KEY)
	end
end

function E.Net(row, icon, item)
	icon.net = nil
	if not Cue() or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	local mark = { key = item.a.key, start = item.start }
	icon.net = mark
	C_Timer.After(math.max(item.start + item.seconds - T.Now(), 0) + NET_LATE, function()
		if icon.net == mark then
			icon.net = nil
			if row.rec then
				ns.Try(KEY, E.RenderRec, row.rec)
			end
		end
	end)
end

function E.Texture(a)
	local file = E.tex[a.key]
	if file then
		return file
	end
	local spells = type(C_Spell) == "table" and C_Spell or {}
	for _, id in ipairs(a.casts) do
		local answer = T.Ask(spells.GetSpellTexture, id)
		if Plain(answer, "number") or Plain(answer, "string") then
			E.tex[a.key] = answer
			return answer
		end
	end
	return UNKNOWN_ICON
end

function E.Make(frame, bar)
	local row = E.rows[bar or frame]
	if row then
		return row
	end
	if not ns.IconRow.CanMake(frame) then
		return nil
	end
	local ok, holder = pcall(CreateFrame, "Frame", nil, frame)
	if not ok or type(holder) ~= "table" then
		return nil
	end
	ns.Own[holder] = true
	holder:SetSize(1, 1)
	row = { holder = holder, icons = {}, drawn = {}, bar = bar }
	E.rows[bar or frame] = row
	return row
end

function E.Anchor(row, frame)
	local point, relative, relativePoint, x, y, direction = E.Spot(frame)
	local key = ("%s:%s:%s:%.2f:%.2f"):format(point, tostring(relative), relativePoint, x, y)
	if row.spot == key then
		return
	end
	if row.spot ~= nil and not ns.IconRow.CanMake(frame) then
		E.Later()
		return
	end
	local holder = row.holder
	if pcall(function()
		holder:ClearAllPoints()
		holder:SetPoint(point, relative, relativePoint, x, y)
	end) then
		row.spot, row.direction = key, direction
	else
		pcall(holder.ClearAllPoints, holder)
		pcall(holder.SetPoint, holder, "TOP", E.Target(frame), "BOTTOM", 0, -BELOW)
		row.spot, row.direction = key, "center"
	end
end

function E.Fit(row, count)
	local size = Opt("size")
	local direction = row.direction or "center"
	while #row.icons < count do
		local icon = ns.IconNew(row.holder)
		if not icon then
			break
		end
		icon.onDone = function()
			local rec = row.rec
			if rec then
				E.RenderRec(rec)
			end
		end
		if row.bar then
			icon.frame:SetScript("OnEnter", function()
				ns.Try(KEY, E.Tip, row, icon)
				E.TipTick(row, icon)
			end)
			icon.frame:SetScript("OnLeave", function()
				ns.Try(KEY, E.Untip, icon)
			end)
		end
		row.icons[#row.icons + 1] = icon
	end
	if row.bar then
		for _, icon in ipairs(row.icons) do
			E.Mouse(icon)
		end
	end
	count = math.min(count, #row.icons)
	local key = ("%s:%s:%s"):format(size, count, direction)
	if row.fitKey ~= key then
		row.fitKey = key
		local shown = {}
		for slot = 1, count do
			shown[slot] = row.icons[slot]
		end
		local width = ns.IconLayout(shown, row.holder, size, SPACING, direction)
		row.holder:SetSize(math.max(width, 1), size)
	end
	return count
end

function E.Mark(icon, on)
	local mark = icon.mark
	if not on then
		if mark then
			mark:Hide()
		end
		return
	end
	if not mark then
		local ok, made = pcall(icon.frame.CreateFontString, icon.frame, nil, "OVERLAY", MARK_FONTS[2][2])
		if not ok or type(made) ~= "table" then
			return
		end
		ns.Own[made] = true
		made:SetPoint("CENTER", icon.frame, "CENTER", 0, 0)
		mark = made
		icon.mark, icon.markFont = made, MARK_FONTS[2][2]
	end
	local size, font = Opt("size"), nil
	for _, step in ipairs(MARK_FONTS) do
		if not font and Plain(size, "number") and size <= step[1] then
			font = step[2]
		end
	end
	font = font or MARK_FONTS[2][2]
	if icon.markFont ~= font and pcall(mark.SetFontObject, mark, font) then
		icon.markFont = font
	end
	mark:SetText("?")
	mark:Show()
end

function E.Draw(row, slot, item)
	local icon = row.icons[slot]
	local key = "none"
	if item then
		local state = item.unknown and "unknown" or item.ready and "ready" or "used"
		key = ("%s:%s:%s:%s:%s:%s:%s:%s:%s:%s"):format(item.a.key, tostring(item.start), tostring(Opt("seconds")), tostring(Opt("kindBorder")), state,
			tostring(Opt("show")), tostring(Opt("flash")), tostring(Opt("sound")), Opt("numbersFont"), tostring(Opt("iconBorder"))) .. ":" .. tostring(Opt("soundMinimum"))
	end
	if row.drawn[slot] == key then
		return
	end
	row.drawn[slot] = key
	local was = icon.was
	icon.was = item and { key = item.a.key, ready = item.ready == true, seconds = item.seconds } or nil
	if not item then
		icon.key, icon.net = nil, nil
		E.Mark(icon, false)
		ns.IconClear(icon)
		return
	end
	icon.key, icon.unknown = item.a.key, item.unknown == true
	local look = { numbers = Opt("seconds") == true, font = Opt("numbersFont"), kind = Opt("kindBorder") == true and item.a.kind or nil, border = Opt("iconBorder") }
	if item.ready then
		icon.net = nil
		pcall(icon.cooldown.Clear, icon.cooldown)
	end
	ns.IconSet(icon, E.Texture(item.a), item.start, item.seconds, look)
	if not item.ready then
		E.Net(row, icon, item)
	elseif was and was.key == item.a.key and not was.ready and not item.unknown then
		E.Flash(row, icon, was.seconds)
	end
	local level = item.unknown and UNKNOWN or ((not item.ready and Opt("show") == "always") and DARK or 1)
	icon.texture:SetDesaturated(level < 1)
	icon.texture:SetVertexColor(level, level, level)
	E.Mark(icon, item.unknown == true)
end

function E.Blank(row)
	for slot = 1, #row.icons do
		E.Draw(row, slot, nil)
	end
	row.holder:Hide()
end

function E.RenderRec(rec)
	if rec.mover then
		return E.RenderBar(rec)
	end
	local row = E.rows[rec.frame]
	if row and row.testing and row.testing ~= E.HELD then
		return
	end
	local items = E.PlatesOn() and E.Items(rec) or {}
	if #items == 0 then
		E.stuck[rec.frame] = nil
		if E.Hold(rec) then
			return
		end
		if row then
			E.Blank(row)
		end
		return
	end
	if row and row.testing == E.HELD then
		E.Unhold(row)
	end
	row = row or E.Make(rec.frame)
	if not row then
		E.stuck[rec.frame] = true
		E.Later()
		return
	end
	E.stuck[rec.frame] = nil
	row.rec = rec
	E.Anchor(row, rec.frame)
	local count = E.Fit(row, #items)
	for slot = 1, #row.icons do
		E.Draw(row, slot, slot <= count and items[slot] or nil)
	end
	row.holder:Show()
end

function E.Render()
	if not ns.Enabled(KEY) then
		return
	end
	for _, rec in pairs(E.plates) do
		E.RenderRec(rec)
	end
	for _, bar in pairs(E.bars) do
		E.RenderBar(bar)
	end
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

function E.Mouse(icon)
	local tips = Opt("tooltips") or "on"
	if icon.tips == tips then
		return
	end
	local frame = icon.frame
	if pcall(frame.SetMouseClickEnabled, frame, false) and pcall(frame.SetMouseMotionEnabled, frame, tips ~= "off") then
		icon.tips = tips
	end
	if tips == "off" then
		E.Untip(icon)
	end
end

local function Clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function E.Tip(row, icon)
	local tips = Opt("tooltips") or "on"
	local tip = Tooltip()
	if not tip or tips == "off" or (tips == "out" and InCombatLockdown()) then
		return
	end
	local a = E.ByKey(icon.key)
	if not a and not row.testing then
		return
	end
	local rec = row.rec
	local who = rec and rec.unit and Text(UnitName, rec.unit) or nil
	local start, seconds
	if a and not row.testing and rec and rec.owner then
		start, seconds = T.Timer(rec.owner, a.key)
	end
	pcall(function()
		tip:SetOwner(icon.frame, "ANCHOR_TOP")
		if row.testing then
			tip:SetText("Sample", 1, 1, 1)
			if a then
				tip:AddLine(E.Name(a), ns.KindColour(a.kind))
			end
			if icon.unknown and row.testing == E.HELD then
				tip:AddLine("Ready or used: the game hides its use here.", DIM[1], DIM[2], DIM[3], true)
			end
			tip:AddLine("A sample of test mode.", DIM[1], DIM[2], DIM[3])
			tip:Show()
			return
		end
		local r, g, b = ns.KindColour(a.kind)
		tip:SetText(E.Name(a), r or 1, g or 1, b or 1)
		if who then
			tip:AddLine(who, 1, 1, 1)
		end
		if start and seconds then
			tip:AddLine(("Ready in %s"):format(Clock(start + seconds - T.Now())), DIM[1], DIM[2], DIM[3])
		elseif icon.unknown then
			tip:AddLine("Ready or used: the game hides its use here.", DIM[1], DIM[2], DIM[3], true)
		else
			tip:AddLine("Ready", READY[1], READY[2], READY[3])
		end
		tip:Show()
	end)
	return true
end

function E.TipTick(row, icon)
	if icon.tipTicker or type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then
		return
	end
	local ok, ticker = pcall(C_Timer.NewTicker, 1, function()
		ns.Try(KEY, E.Retip, row, icon)
	end)
	icon.tipTicker = ok and ticker or nil
end

function E.Retip(row, icon)
	local ok, visible = pcall(icon.frame.IsVisible, icon.frame)
	if not Owned(icon) or not ok or visible ~= true or not E.Tip(row, icon) then
		E.Untip(icon)
	end
end

function E.Untip(icon)
	local ticker = icon.tipTicker
	icon.tipTicker = nil
	if ticker then
		pcall(ticker.Cancel, ticker)
	end
	if Owned(icon) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
end

function E.PlateOf(unit)
	local frame = E.UnitFrameOf(unit)
	if frame then
		for _, rec in pairs(E.plates) do
			if rec.frame == frame then
				return rec
			end
		end
	end
	return nil
end

function E.PlaceBar(row, bar)
	local x, y
	if type(ns.MoverSaved) == "function" and ns.MoverSaved(bar.mover) and type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(bar.mover, "TOPLEFT")
	end
	local size = Opt("size")
	local game = _G[bar.frame]
	if type(game) ~= "table" or ns.Forbidden(game) then
		game = nil
	end
	local key = ("%s:%s:%s"):format(tostring(x), tostring(y), size)
	if row.placeKey == key and row.placeGame == game then
		return
	end
	row.placeKey, row.placeGame = key, game
	row.holder:ClearAllPoints()
	if x then
		row.holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	elseif game then
		row.holder:SetPoint("TOPLEFT", game, "TOPLEFT", 0, size + BAR_UP)
	else
		row.holder:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

function E.ArenaNow()
	local raised = false
	local calls = { IsActiveBattlefieldArena or false, type(C_PvP) == "table" and C_PvP.IsArena or false }
	for _, fn in ipairs(calls) do
		if fn then
			local answer, why = T.Ask(fn)
			if answer == true then
				E.arena.raised = false
				return true
			end
			raised = raised or why == "refused"
		end
	end
	E.arena.raised = raised
	return false
end

function E.ArenaCheck()
	local A = E.arena
	A.on = E.ArenaNow() and type(C_PvP) == "table" and type(C_PvP.GetArenaCrowdControlDuration) == "function"
	A.stamp = A.stamp + 1
	if not A.on then
		A.tex, A.durationRaised = {}, false
		for _, bar in pairs(E.bars) do
			bar.arenaWhy = nil
		end
	end
end

function E.ArenaChanged()
	if not ns.Enabled(KEY) then
		return
	end
	local was = E.arena.on
	E.ArenaCheck()
	if was or E.arena.on then
		for _, bar in pairs(E.bars) do
			E.RenderBar(bar)
		end
	end
end

function E.ArenaSpell(unit, spell)
	local A = E.arena
	A.stamp = A.stamp + 1
	if not A.on or not ns.Enabled(KEY) then
		return
	end
	local digit = Plain(unit, "string") and unit:match("^arena(%d)$")
	local n = digit and tonumber(digit)
	if n and type(C_Spell) == "table" and type(C_Spell.GetSpellTexture) == "function" then
		local ok, tex = pcall(C_Spell.GetSpellTexture, spell)
		A.tex[n] = ok and { tex } or nil
	end
	for _, bar in pairs(E.bars) do
		E.RenderBar(bar)
	end
end

function E.ArenaCooldowns()
	local A = E.arena
	A.stamp = A.stamp + 1
	if A.on and ns.Enabled(KEY) then
		for _, bar in pairs(E.bars) do
			E.RenderBar(bar)
		end
	end
end

function E.ArenaOf(unit)
	local withheld = false
	for n = 1, ARENA_OPPONENTS do
		local same, why = T.Ask(UnitIsUnit, unit, "arena" .. n)
		if same == true then
			return n
		end
		withheld = withheld or why == "hidden"
	end
	return nil, withheld
end

function E.ArenaFor(bar)
	local A = E.arena
	bar.arenaWhy = nil
	if not (A.on and Opt("arenaBreak") == true and E.BarsOn()) then
		return nil
	end
	local n, withheld = E.ArenaOf(bar.unit)
	if not n then
		bar.arenaWhy = withheld and "unknown" or "none"
		return nil
	end
	local ok, duration = pcall(C_PvP.GetArenaCrowdControlDuration, "arena" .. n)
	if not ok then
		A.durationRaised = true
		bar.arenaWhy = "refused"
		return nil
	end
	A.durationRaised = false
	if type(duration) ~= "table" and type(duration) ~= "userdata" then
		bar.arenaWhy = "refused"
		return nil
	end
	bar.arenaWhy = "shown"
	return n, duration
end

function E.ArenaDraw(row, slot, n, duration)
	local icon = row.icons[slot]
	local key = ("arena:%s:%s:%s:%s"):format(n, E.arena.stamp, tostring(Opt("seconds")), Opt("numbersFont"))
	if row.drawn[slot] == key then
		return
	end
	row.drawn[slot] = key
	icon.key, icon.net, icon.was = nil, nil, nil
	E.Mark(icon, false)
	pcall(icon.texture.SetTexture, icon.texture, UNKNOWN_ICON)
	local tex = E.arena.tex[n]
	if tex then
		pcall(icon.texture.SetTexture, icon.texture, tex[1])
	end
	icon.texture:SetDesaturated(false)
	icon.texture:SetVertexColor(1, 1, 1)
	ns.IconSet(icon, nil, nil, duration, { numbers = Opt("seconds") == true, font = Opt("numbersFont"), border = Opt("iconBorder") })
end

function ns.EnemyArenaLine()
	if not ns.Enabled(KEY) or not E.arena.on then
		return nil
	end
	if Opt("arenaBreak") ~= true then
		return "Arena crowd control break: off."
	end
	local unknown, refused = false, E.arena.durationRaised
	for _, bar in pairs(E.bars) do
		if bar.arenaWhy == "shown" then
			return "Arena crowd control break: shown."
		end
		unknown = unknown or bar.arenaWhy == "unknown"
		refused = refused or bar.arenaWhy == "refused"
	end
	if refused then
		return "Arena crowd control break: refused by the game."
	elseif unknown then
		return "Arena crowd control break: opponent not known."
	end
	return "Arena crowd control break: no opponent targeted."
end

function E.RenderBar(bar)
	local row = E.rows[bar]
	if row and row.testing and row.testing ~= E.HELD then
		return
	end
	local items = E.BarsOn() and bar.owner and E.Items(bar, BAR_MOST) or {}
	local arena, duration = nil, nil
	if E.arena.on then
		arena, duration = E.ArenaFor(bar)
	end
	if #items == 0 and not arena then
		if E.Hold(bar) then
			return
		end
		if row then
			E.Blank(row)
		end
		return
	end
	if row and row.testing == E.HELD then
		E.Unhold(row)
	end
	row = row or E.Make(UIParent, bar)
	if not row then
		return
	end
	row.rec = bar
	E.PlaceBar(row, bar)
	local count = E.Fit(row, #items + (arena and 1 or 0))
	for slot = 1, #row.icons do
		if arena and slot == #items + 1 and slot <= count then
			E.ArenaDraw(row, slot, arena, duration)
		else
			E.Draw(row, slot, slot <= count and items[slot] or nil)
		end
	end
	row.holder:Show()
end

function E.BarWho(unit)
	if not E.Enemy(unit) then
		return nil
	end
	local guid = Text(UnitGUID, unit)
	local rec = not guid and E.PlateOf(unit) or nil
	local owner = guid or rec and rec.owner
	if not owner then
		return nil, true
	end
	return { owner = owner, class = Text(UnitClassBase, unit) or rec and rec.class }
end

function E.BarSet(unit)
	local bar = E.bars[unit]
	if not bar or not ns.Enabled(KEY) then
		return
	end
	local who, pending = nil, nil
	if E.BarsOn() then
		who, pending = E.BarWho(unit)
	end
	bar.owner, bar.class, bar.pending = who and who.owner, who and who.class, pending
	bar.race, bar.raceFile, bar.level = nil, nil, nil
	if bar.owner then
		E.owners[bar.owner] = true
	end
	if who then
		if T.Hear(KEY, unit, true, true) and T.units[unit] then
			T.Queue(T.units[unit])
		end
	else
		T.Deafen(KEY, unit)
	end
	E.RenderBar(bar)
	if bar.owner then
		E.Arm()
	end
end

function E.BarsAgain()
	for unit, bar in pairs(E.bars) do
		if bar.pending or type(bar.owner) == "table" then
			E.BarSet(unit)
		end
	end
end

function E.BarsAll()
	for unit in pairs(E.bars) do
		E.BarSet(unit)
	end
end

function E.Live()
	if next(E.plates) ~= nil then
		return true
	end
	for _, bar in pairs(E.bars) do
		if bar.owner then
			return true
		end
	end
	return false
end

function E.Later()
	if E.queued or not InCombatLockdown() then
		return
	end
	E.queued = true
	ns.OutOfCombat(function()
		E.queued = false
		ns.Try(KEY, E.Render)
	end)
end

function E.Tick()
	E.armed = false
	if not ns.Enabled(KEY) then
		return
	end
	E.Render()
	if E.Live() then
		E.Arm()
	end
end

function E.Arm()
	if E.armed or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	E.armed = true
	C_Timer.After(LOOK, function()
		ns.Try(KEY, E.Tick)
	end)
end

local function Whole(value, most)
	return Plain(value, "number") and value >= 1 and value <= most and value == math.floor(value)
end

function E.Saved()
	local account = ns.Account()
	if type(account) ~= "table" then
		return nil
	end
	if type(account.abilities) ~= "table" then
		account.abilities = {}
	end
	local saved = account.abilities.enemy
	if type(saved) ~= "table" then
		saved = {}
		account.abilities.enemy = saved
	end
	local added, hidden = {}, {}
	for key, value in pairs(type(saved.added) == "table" and saved.added or {}) do
		if type(key) == "string" and #key <= 120 and (value == true or Whole(value, MOST_SECONDS)) then
			added[key] = value
		elseif Whole(key, MOST_ID) and Whole(value, MOST_SECONDS) then
			added[key] = value
		end
	end
	for key, yes in pairs(type(saved.hidden) == "table" and saved.hidden or {}) do
		if type(key) == "string" and #key <= 120 and yes == true then
			hidden[key] = true
		end
	end
	saved.added, saved.hidden = added, hidden
	return saved
end

function E.Lists()
	local lists = E.lists
	if lists then
		return lists
	end
	lists = { added = {}, hidden = {}, seconds = {}, custom = {}, byCast = {} }
	local saved = E.Saved()
	if not saved then
		return lists
	end
	E.Ability("")
	for key in pairs(saved.hidden) do
		lists.hidden[key] = true
	end
	for key, value in pairs(saved.added) do
		if type(key) == "string" then
			lists.added[key] = true
			lists.seconds[key] = value ~= true and value or nil
		else
			local name = Text(type(C_Spell) == "table" and C_Spell.GetSpellName or nil, key)
			local a = { key = "custom:" .. key, class = "ALL", kind = 0, name = name or ("Spell " .. key), cd = value, casts = { key }, buffs = {}, flags = "", cat = 0,
				custom = true, id = key }
			lists.custom[#lists.custom + 1] = a
			lists.byCast[key] = a
			E.byKey[a.key], E.order[a.key] = a, 1000000 + key
		end
	end
	table.sort(lists.custom, function(x, y)
		return x.id < y.id
	end)
	E.lists = lists
	return lists
end

function E.Changed()
	for _, a in ipairs(E.lists and E.lists.custom or {}) do
		E.byKey[a.key], E.order[a.key] = nil, nil
	end
	E.lists = nil
	if ns.Enabled(KEY) then
		ns.Try(KEY, E.Render)
	end
end

local function Capital(class)
	return class:sub(1, 1) .. class:sub(2):lower()
end

function E.Name(a)
	if a.class and a.class ~= "ALL" then
		return ("%s (%s)"):format(a.name, Capital(a.class))
	end
	return a.name
end

function E.Every()
	local list = {}
	for _, a in ipairs(type(ns.ABILITIES) == "table" and ns.ABILITIES or {}) do
		list[#list + 1] = a
	end
	for _, a in ipairs(E.Lists().custom) do
		list[#list + 1] = a
	end
	return list
end

function E.Lines(abilities)
	local rows, count = {}, {}
	for _, a in ipairs(abilities) do
		local text = E.Name(a)
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

function E.NoCooldown(a)
	return a.cd == 0 or a.flags:find("n", 1, true) ~= nil
end

function E.IsShown(a)
	return not E.NoCooldown(a) and E.Rank(a) ~= nil
end

function ns.EnemyAbilityCandidates()
	local out = {}
	for _, a in ipairs(type(ns.ABILITIES) == "table" and ns.ABILITIES or {}) do
		if not E.NoCooldown(a) and not E.IsShown(a) then
			out[#out + 1] = a
		end
	end
	return E.Lines(out)
end

function ns.EnemyAbilityShown()
	local out = {}
	for _, a in ipairs(E.Every()) do
		if E.IsShown(a) then
			out[#out + 1] = a
		end
	end
	return E.Lines(out)
end

function E.ByKey(key)
	if type(key) ~= "string" then
		return nil
	end
	for _, a in ipairs(E.Every()) do
		if a.key == key then
			return a
		end
	end
	return nil
end

function E.ByCast(id)
	local found = {}
	for _, a in ipairs(E.Every()) do
		for _, cast in ipairs(a.casts) do
			if cast == id then
				found[#found + 1] = a
				break
			end
		end
	end
	return found
end

function E.ByName(text)
	local found, wanted = {}, text:lower()
	for _, a in ipairs(E.Every()) do
		if a.name:lower() == wanted or E.Name(a):lower() == wanted then
			found[#found + 1] = a
		end
	end
	return found
end

function E.Count(saved)
	local count = 0
	for _ in pairs(saved.added) do
		count = count + 1
	end
	return count
end

function E.Add(a, seconds)
	local saved = E.Saved()
	if not saved then
		return false, "Nothing can be saved yet."
	end
	if E.NoCooldown(a) then
		return false, ("%s has no cooldown to show."):format(E.Name(a))
	end
	local lists = E.Lists()
	local shown = E.IsShown(a)
	local typed = seconds ~= nil and (a.custom and a.cd or lists.seconds[a.key] or a.cd) ~= seconds
	if shown and not typed then
		return false, ("%s is already shown."):format(E.Name(a))
	end
	local at = a.custom and a.id or a.key
	if saved.added[at] == nil and E.Count(saved) >= MOST_ADDED then
		return false, ("%d added abilities is the most."):format(MOST_ADDED)
	end
	saved.hidden[a.key] = nil
	saved.added[at] = seconds or saved.added[at] or true
	E.Changed()
	if seconds then
		return true, ("Added %s, %d seconds."):format(E.Name(a), seconds)
	end
	return true, ("Added %s."):format(E.Name(a))
end

function E.AddSpell(id, seconds)
	local saved = E.Saved()
	if not saved then
		return false, "Nothing can be saved yet."
	end
	local name = Text(type(C_Spell) == "table" and C_Spell.GetSpellName or nil, id)
	if not name then
		return false, ('No spell found for "%s".'):format(tostring(id))
	end
	if saved.added[id] == nil and E.Count(saved) >= MOST_ADDED then
		return false, ("%d added abilities is the most."):format(MOST_ADDED)
	end
	saved.added[id] = seconds
	E.Changed()
	return true, ("Added %s, %d seconds."):format(name, seconds)
end

function E.Hide(a)
	local saved = E.Saved()
	if not saved then
		return false, "Nothing can be saved yet."
	end
	if saved.hidden[a.key] then
		return false, ("%s is already hidden."):format(E.Name(a))
	elseif not E.IsShown(a) then
		return false, ("%s is not shown."):format(E.Name(a))
	end
	if a.custom then
		saved.added[a.id] = nil
		E.Changed()
		return true, ("Removed %s."):format(E.Name(a))
	end
	saved.added[a.key] = nil
	saved.hidden[a.key] = true
	E.Changed()
	return true, ("Hid %s."):format(E.Name(a))
end

function ns.EnemyAbilityAdd(key)
	local a = E.ByKey(key)
	if not a then
		return false, ('No ability found for "%s".'):format(tostring(key))
	end
	return E.Add(a)
end

function ns.EnemyAbilityHide(key)
	local a = E.ByKey(key)
	if not a then
		return false, ('No ability found for "%s".'):format(tostring(key))
	end
	return E.Hide(a)
end

function E.Parse(text)
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

function E.Resolve(parsed, text)
	local found = parsed.id and E.ByCast(parsed.id) or E.ByName(parsed.name or text)
	if #found == 1 then
		return found[1]
	elseif #found > 1 then
		local lines = { ('More than one ability is "%s". Type a spell ID:'):format(parsed.id and tostring(parsed.id) or parsed.name or text) }
		for _, row in ipairs(E.Lines(found)) do
			lines[#lines + 1] = ("%s, spell %d"):format(E.Name(row[3]), row[3].casts[1] or 0)
		end
		return nil, table.concat(lines, "\n")
	end
	return nil, nil
end

function E.SlashAdd(text)
	local parsed = E.Parse(text)
	local seconds = parsed.seconds
	if seconds and (seconds < 1 or seconds > MOST_SECONDS) then
		print(("A cooldown is 1 to %d seconds."):format(MOST_SECONDS))
		return
	end
	local a, message = E.Resolve(parsed, text)
	if message then
		print(message)
	elseif a then
		print(select(2, E.Add(a, seconds)))
	elseif parsed.id then
		if not seconds then
			print(("Spell %d is not listed. Type its cooldown in seconds after the ID."):format(parsed.id))
		elseif parsed.id > MOST_ID then
			print(('No spell found for "%s".'):format(tostring(parsed.id)))
		else
			print(select(2, E.AddSpell(parsed.id, seconds)))
		end
	else
		print(('No ability found for "%s".'):format(parsed.name or text))
	end
end

function E.SlashHide(text)
	local parsed = { name = text }
	local id = tonumber(text:match("|Hspell:(%d+)") or text:match("^spell:(%d+)") or text:match("^(%d+)$"))
	if id then
		parsed = { id = id }
	end
	local a, message = E.Resolve(parsed, text)
	if message then
		print(message)
	elseif a then
		print(select(2, E.Hide(a)))
	else
		print(('No ability found for "%s".'):format(parsed.id and tostring(parsed.id) or text))
	end
end

function E.SlashList()
	local state = {}
	local rec = { unit = "target" }
	local rows = ns.EnemyAbilityShown()
	if #rows == 0 then
		print("No abilities shown.")
	end
	for _, row in ipairs(rows) do
		local a = row[3]
		local how = "use cannot be seen here"
		if E.Seeable(a, rec, state) then
			how = "use can be seen here"
		elseif E.Kick(a) then
			how = "use seen here only when it stops your own cast"
		elseif a.flags:find("o", 1, true) and #a.buffs > 0 and state.auras then
			how = "use seen here only when its buff is on a player whose nameplate shows"
		end
		print(("%s: %d seconds, %s."):format(row[2], a.cd, how))
	end
end

function E.Clear()
	for owner in pairs(E.owners) do
		local book = T.Book(owner)
		if book then
			book.timers = {}
		end
	end
	E.owners = setmetatable({}, { __mode = "k" })
	E.holds = setmetatable({}, { __mode = "k" })
	E.Render()
end

function E.Slash(rest)
	local word, text = (rest or ""):match("^(%S*)%s*(.-)%s*$")
	word = word:lower()
	if word == "add" and text ~= "" then
		E.SlashAdd(text)
	elseif word == "hide" and text ~= "" then
		E.SlashHide(text)
	elseif word == "list" then
		E.SlashList()
	elseif word == "clear" then
		E.Clear()
		print("Enemy timers cleared.")
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

function E.Added(unit)
	if not Plain(unit, "string") or not ns.Enabled(KEY) then
		return
	end
	E.Leave(unit)
	local frame = E.UnitFrameOf(unit)
	if not frame then
		return
	end
	local row = E.rows[frame]
	if not E.Enemy(unit) then
		if row then
			row.rec = nil
			E.Blank(row)
		end
		return
	end
	local rec = { unit = unit, frame = frame, owner = Text(UnitGUID, unit) or frame, class = Text(UnitClassBase, unit) }
	E.plates[unit] = rec
	E.owners[rec.owner] = true
	if row then
		row.rec = rec
		for slot = 1, #row.icons do
			row.drawn[slot] = nil
		end
	end
	if T.Hear(KEY, unit, true, true) and T.units[unit] then
		T.Queue(T.units[unit])
	end
	E.RenderRec(rec)
	E.Arm()
	E.BarsAgain()
end

function E.Leave(unit)
	local rec = E.plates[unit]
	if not rec then
		return
	end
	E.plates[unit] = nil
	E.stuck[rec.frame] = nil
	T.Deafen(KEY, unit)
	if type(rec.owner) == "table" then
		T.frames[rec.owner] = nil
	end
	local row = E.rows[rec.frame]
	if row and row.rec == rec then
		Soon(function()
			if row.rec == rec then
				row.rec = nil
				E.Blank(row)
			end
		end)
	end
	E.BarsAgain()
end

function E.Removed(unit)
	if Plain(unit, "string") then
		E.Leave(unit)
	end
end

function E.Scan()
	for number = 1, PLATES do
		local unit = "nameplate" .. number
		if not E.plates[unit] and E.UnitFrameOf(unit) then
			E.Added(unit)
		end
	end
end

function E.Off()
	T.DeafenAll(KEY)
	for _, row in pairs(E.rows) do
		row.rec, row.testing = nil, nil
		E.Blank(row)
	end
	E.plates, E.stuck = {}, {}
	E.arena.on, E.arena.tex = false, {}
	for _, bar in pairs(E.bars) do
		bar.owner, bar.class, bar.pending, bar.arenaWhy = nil, nil, nil, nil
	end
end

function E.Caster(source)
	if not Plain(source, "string") then
		return nil
	end
	if E.plates[source] then
		return E.plates[source]
	end
	local guid = Text(UnitGUID, source)
	if guid then
		for _, rec in pairs(E.plates) do
			if rec.owner == guid then
				return rec
			end
		end
	end
	return nil
end

function E.Cast(unit, spell)
	local rec = E.plates[unit] or E.bars[unit]
	if not rec or not rec.owner then
		return
	end
	rec.class = rec.class or Text(UnitClassBase, unit)
	local now = T.Now()
	local custom = E.Lists().byCast[spell]
	if custom and T.Use(rec.owner, rec.class, custom, now, spell) then
		E.Render()
	end
	if T.Cast(rec.owner, rec.class, spell, now) then
		E.Retime(rec.owner, rec.class, spell, now)
		E.Render()
	end
end

function ns.EnemyKicked(guid, class, a, at)
	if not ns.Enabled(KEY) or not Plain(guid, "string") then
		return false
	end
	local token = Text(UnitTokenFromGUID, guid)
	if not token then
		return false
	end
	local started = false
	for _, rec in ipairs({ E.plates[token] or false, E.bars[token] or false }) do
		if rec and type(rec.owner) == "table" and T.Use(rec.owner, class, a, at, nil) then
			E.owners[rec.owner] = true
			started = true
		end
	end
	return started
end

function E.Retime(owner, class, spell, now)
	local lists = E.Lists()
	if next(lists.seconds) == nil or type(ns.ABILITY_BY_CAST) ~= "table" then
		return
	end
	for _, group in ipairs({ type(class) == "string" and class or "ALL", "ALL" }) do
		local index = ns.ABILITY_BY_CAST[group] and ns.ABILITY_BY_CAST[group][spell]
		local a = index and ns.ABILITIES[index]
		local seconds = a and lists.seconds[a.key]
		local book = seconds and T.Book(owner)
		local timer = book and book.timers[a.key]
		if timer and timer.start == now then
			timer.seconds = seconds
		end
	end
end

function E.Begin(who, id, start, others)
	local by = ns.ABILITY_BY_BUFF
	local started = false
	for _, group in ipairs({ type(who.class) == "string" and who.class or "ALL", "ALL" }) do
		for _, index in ipairs(by[group] and by[group][id] or {}) do
			local a = ns.ABILITIES[index]
			if a and (a.flags:find("o", 1, true) ~= nil) == others and T.Use(who.owner, who.class, a, start, nil) then
				started = true
				E.Retimed(who.owner, a, start)
			end
		end
	end
	return started
end

function E.Retimed(owner, a, at)
	local seconds = E.Lists().seconds[a.key]
	local book = seconds and T.Book(owner)
	local timer = book and book.timers[a.key]
	if timer and timer.start == at then
		timer.seconds = seconds
	end
end

function E.Aura(unit, id, start, seconds, source)
	local rec = E.plates[unit] or E.bars[unit]
	if not rec or not rec.owner or type(ns.ABILITY_BY_BUFF) ~= "table" then
		return
	end
	rec.class = rec.class or Text(UnitClassBase, unit)
	local started = E.Begin(rec, id, start, false)
	local caster = source ~= nil and E.Caster(source) or nil
	if caster and E.Begin(caster, id, start, true) then
		started = true
	end
	if started then
		E.Render()
	end
end

function E.Refresh()
	if not ns.Enabled(KEY) then
		E.Off()
		return
	end
	E.never = {}
	E.ArenaCheck()
	E.Scan()
	E.BarsAll()
	for _, row in pairs(E.rows) do
		for slot = 1, #row.icons do
			row.drawn[slot] = nil
			if row.bar then
				E.Mouse(row.icons[slot])
			end
		end
		row.fitKey, row.placeKey = nil, nil
	end
	E.Render()
	if E.Live() then
		E.Arm()
	end
end

function E.OnRestriction()
	E.Sight()
	if E.Live() then
		E.Render()
	end
	Soon(function()
		ns.Try(KEY, E.Sight)
		if E.Live() then
			ns.Try(KEY, E.Render)
		end
	end)
end

function E.OnWorld()
	E.Refresh()
	if E.Live() then
		Soon(function()
			ns.Try(KEY, E.Render)
		end)
	end
end

function E.Start()
	T.Listen()
	T.Subscribe(KEY, function(unit, spell)
		ns.Try(KEY, E.Cast, unit, spell)
	end, function(unit, id, start, seconds, source)
		ns.Try(KEY, E.Aura, unit, id, start, seconds, source)
	end)
	E.Refresh()
end

function ns.EnemyTargetBarShown()
	return ns.Enabled(KEY) and E.BarsOn()
end

function ns.EnemyFocusBarShown()
	return ns.Enabled(KEY) and E.BarsOn()
end

function ns.EnemyBarsMoved()
	for _, bar in pairs(E.bars) do
		local row = E.rows[bar]
		if row then
			row.placeKey = nil
		end
	end
	if ns.Enabled(KEY) then
		ns.Try(KEY, E.Render)
	end
end

function ns.EnemyRender()
	if ns.Enabled(KEY) then
		ns.Try(KEY, E.Render)
	end
end

E.HELD = {}

function E.Holding()
	return TM.IsOn() and ns.Enabled(KEY) and not InCombatLockdown()
end

function E.Unhold(row)
	row.testing = nil
	for slot, icon in ipairs(row.icons) do
		row.drawn[slot] = nil
		icon.held, icon.unknown = nil, nil
	end
end

function E.Hold(rec)
	local bar = rec.mover ~= nil
	local row = E.rows[bar and rec or rec.frame]
	if not (E.Holding() and (bar and E.BarsOn() or (not bar and E.PlatesOn()))) then
		if row and row.testing == E.HELD then
			E.Unhold(row)
		end
		return false
	end
	if bar then
		row = row or E.Make(UIParent, rec)
	else
		row = row or E.Make(rec.frame)
	end
	if not row then
		return false
	end
	if bar then
		E.PlaceBar(row, rec)
	else
		E.Anchor(row, rec.frame)
	end
	row.rec, row.testing = rec, E.HELD
	local count = E.Fit(row, 3)
	local look = { numbers = Opt("seconds") == true, font = Opt("numbersFont"), kind = Opt("kindBorder") == true or nil, border = Opt("iconBorder"),
		flash = Opt("flash") == true, sound = bar and E.Kit() or false }
	local always = Opt("show") == "always"
	for slot, icon in ipairs(row.icons) do
		row.drawn[slot] = nil
		if slot <= count then
			local a = E.Ability(SAMPLE_KEYS[slot])
			icon.key, icon.unknown = a and a.key or nil, nil
			local shown = look
			if a and look.kind then
				shown = {}
				for name, value in pairs(look) do
					shown[name] = value
				end
				shown.kind = a.kind
			end
			local level = always and DARK or 1
			if always and (slot == 1 or slot == 3) then
				icon.held = nil
				pcall(icon.cooldown.Clear, icon.cooldown)
				ns.IconSet(icon, a and E.Texture(a) or ns.IconSamplePicture(slot), nil, nil,
					{ numbers = shown.numbers, font = shown.font, kind = shown.kind ~= true and shown.kind or nil, border = shown.border })
				level = slot == 3 and UNKNOWN or 1
				icon.unknown = slot == 3 or nil
				E.Mark(icon, slot == 3)
			else
				E.Mark(icon, false)
				ns.IconSampleHeld(icon, slot, KEY, shown, a and E.Texture(a) or nil)
			end
			icon.texture:SetDesaturated(level < 1)
			icon.texture:SetVertexColor(level, level, level)
		else
			icon.key, icon.held = nil, nil
			ns.IconClear(icon)
		end
	end
	row.holder:Show()
	return true
end

function E.TestTick(now)
	for _, row in pairs(E.rows) do
		if row.testing == E.HELD then
			ns.IconSampleLoop(row.icons, now)
		end
	end
end

function E.Sample(row, rec, token, now)
	row.rec, row.testing = rec, token
	local count = E.Fit(row, 3)
	local cue = { flash = Opt("flash") == true, sound = E.Hears(rec) and E.Kit() or false }
	for slot = 1, #row.icons do
		row.drawn[slot] = nil
		if slot <= count then
			E.Mark(row.icons[slot], false)
			ns.IconSample(row.icons[slot], slot, now, 2 * slot, KEY, cue)
			row.icons[slot].texture:SetDesaturated(false)
			row.icons[slot].texture:SetVertexColor(1, 1, 1)
		else
			ns.IconClear(row.icons[slot])
		end
	end
	row.holder:Show()
end

function ns.EnemyTest()
	if not ns.Enabled(KEY) or InCombatLockdown() then
		return
	end
	local token = {}
	local now = T.Now()
	local shown, bars = 0, 0
	if E.PlatesOn() then
		for _, rec in pairs(E.plates) do
			local row = E.Make(rec.frame)
			if row then
				E.Anchor(row, rec.frame)
				E.Sample(row, rec, token, now)
				shown = shown + 1
			end
		end
	end
	if E.BarsOn() then
		for _, bar in pairs(E.bars) do
			local row = E.Make(UIParent, bar)
			if row then
				E.PlaceBar(row, bar)
				E.Sample(row, bar, token, now)
				bars = bars + 1
			end
		end
	end
	if shown + bars == 0 then
		return
	end
	E.testing = token
	print(bars == 0 and "Enemy cooldowns: sample icons on each plate for 8 seconds." or "Enemy cooldowns: sample icons for 8 seconds.")
	local function Over()
		if E.testing ~= token then
			return
		end
		E.testing = nil
		for _, row in pairs(E.rows) do
			if row.testing == token then
				row.testing = nil
				for slot = 1, #row.icons do
					row.drawn[slot] = nil
				end
				E.Blank(row)
			end
		end
		E.Render()
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(TEST_TIME, function()
			ns.Try(KEY, Over)
		end)
	end
end

function E.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	local seen = ns.CanSeeCasts(T.Heard(KEY)[1] or "target")
	if seen == false then
		lines[1] = (InCombatLockdown() or ns.AurasReadable() == false) and LINE_HERE or LINE_CASTS
		if Opt("show") == "always" then
			lines[#lines + 1] = LINE_UNKNOWN
		end
	end
	if next(E.stuck) then
		lines[#lines + 1] = LINE_PLATES
	end
	if E.arena.raised or E.arena.durationRaised then
		lines[#lines + 1] = LINE_ARENA
	end
	for _, unit in ipairs({ "target", "focus" }) do
		local bar = E.bars[unit]
		if bar and bar.pending then
			lines[#lines + 1] = LINE_WAIT
			break
		end
	end
	return lines
end

ns.Register(KEY, {
	label = "Enemy cooldowns",
	counted = false,
	Start = E.Start,
	Refresh = E.Refresh,
	events = {
		NAME_PLATE_UNIT_ADDED = E.Added,
		NAME_PLATE_UNIT_REMOVED = E.Removed,
		PLAYER_TARGET_CHANGED = function()
			E.BarSet("target")
		end,
		PLAYER_FOCUS_CHANGED = function()
			E.BarSet("focus")
		end,
		PLAYER_ENTERING_WORLD = E.OnWorld,
		ZONE_CHANGED_NEW_AREA = E.ArenaChanged,
		ARENA_OPPONENT_UPDATE = E.ArenaChanged,
		ARENA_CROWD_CONTROL_SPELL_UPDATE = E.ArenaSpell,
		ARENA_COOLDOWNS_UPDATE = E.ArenaCooldowns,
		ADDON_RESTRICTION_STATE_CHANGED = E.OnRestriction,
	},
	Status = E.Status,
	slash = { enemy = E.Slash },
})

TM.Register(KEY, {
	module = KEY,
	label = "Enemy cooldowns",
	refresh = true,
	Tick = E.TestTick,
})

ns.EnemyCooldownsModule = E
