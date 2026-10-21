local _, ns = ...

-- Enemy cooldowns: up to four icons under the nameplate of each enemy player, each an ability with the time left on its cooldown.
-- A use is seen from a kick that stopped the player's own cast (Tracking.lua), from the casts of the enemy where the game does not
-- hide them, and from the buffs of abilities where the game does not hide buffs (Tracking.lua keeps the timers and listens, one
-- small frame for each nameplate of an enemy player). The game's spell-ID groups serve units the player can assist only, so the
-- container route is not used here. The rows are frames of this addon's own, children of the nameplate's unit frame only when the
-- game says plainly that it is not protected, else after combat. In combat only the picture, the sweep, the colour and show or hide
-- of icons that exist are touched. Two bars of up to eight icons, for the target and the focus, are rows of the same kind that hang
-- from UIParent, above the target and focus frames until a spot is saved with the movers. Show can keep every ability whose use can be
-- seen at that moment on the row, ready ones bright and used ones dark; When it is ready again flashes the icon at the end of a timer and,
-- for the target and focus, plays a sound. The Add and Hide lists and /flatui enemy are kept for the account. The helpers are in one table, E.

local KEY = "enemycd"
local SPACING = 2
-- Units between the part of the plate the row hangs from and the row.
local BELOW = 1
local MOST = 4
local BAR_MOST = 8
-- Units between the top of a target or focus frame and the bottom of its bar.
local BAR_UP = 4
local LOOK = 0.5
local TEST_TIME = 8
local UNKNOWN_ICON = 134400
-- How long an icon whose timer has ended stays to flash, how long after the end of a timer the addon still counts it as just ended, and
-- how long after the end the addon looks for itself in case the game does not say the sweep is done.
local HOLD = 0.5
local JUST = 1
local NET_LATE = 0.1
-- The look of a used icon in Always, the abilities added by hand at most, and the longest cooldown and the highest spell ID that can be typed.
local DARK = 0.6
local MOST_ADDED, MOST_SECONDS, MOST_ID = 30, 86400, 9999999
-- The places of the Ready sound choices in ns.SOUNDS (IconRow.lua).
local KITS = { alert = 1, chimes = 2, bell = 3, horn = 4, raid = 5 }
local HELP = {
	"/flatui enemy add Blink 15 - an ability, a spell ID or a shift-clicked spell, and its cooldown in seconds",
	"/flatui enemy hide 2139 - an ability or a spell ID",
	"/flatui enemy list - the abilities shown and whether their use can be seen here",
	"/flatui enemy clear - forgets the running timers of enemies",
}
local PLATES = 40
-- The kinds each switch shows (CooldownData.lua: ns.COOLDOWN_KINDS), in the order of the icons.
local SWITCHES = { { "interrupts", { 1 } }, { "wards", { 6 } }, { "breaks", { 5 } }, { "defensives", { 2 } }, { "mobility", { 7 } }, { "offensive", { 8 } } }
local LINE_CASTS = "Enemy cooldowns: the game hides enemy casts. Abilities with a buff are tracked while you are out of combat."
local LINE_HERE = "Enemy cooldowns: the game hides enemy casts and buffs here. Timers already running stay."
local LINE_PLATES = "Enemy cooldowns: some nameplates show no icons."
local LINE_WAIT = "Enemy cooldowns: a bar waits for the nameplate of its unit, whose identity the game hides."
local LINE_ARENA = "Crowd control break in arenas: the game refused the arena call."
local ARENA_OPPONENTS = 5

local IsSecret = ns.IsSecret
local T = ns.Tracking
local E = { plates = {}, rows = setmetatable({}, { __mode = "k" }), stuck = {}, tex = {}, byKey = nil, order = nil, never = {}, holds = setmetatable({}, { __mode = "k" }),
	owners = setmetatable({}, { __mode = "k" }),
	arena = { on = false, stamp = 0, tex = {}, raised = false, durationRaised = false },
	bars = { target = { unit = "target", mover = "FlatUIEnemyTarget", frame = "TargetFrame" }, focus = { unit = "focus", mover = "FlatUIEnemyFocus", frame = "FocusFrame" } } }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

-- A game call that answers a plain string, or nil.
local function Text(fn, ...)
	local answer = T.Ask(fn, ...)
	return Plain(answer, "string") and answer ~= "" and answer or nil
end

-- Runs fn on the next frame, or at once when the client has no timer.
local function Soon(fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

-- The plates ---------------------------------------------------------------------------------------------------------------------

-- The unit frame of the plate of a unit token, or nil when there is none or the game forbids it.
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

-- True while the plates show icons: Place is Both or On enemy nameplates.
function E.PlatesOn()
	return Opt("place") ~= "bars"
end

-- True while the target and focus bars show icons: Place is Both or Bars for target and focus.
function E.BarsOn()
	return Opt("place") ~= "plates"
end

-- True when the unit is an enemy player: both answers are plain and true.
function E.Enemy(unit)
	return T.Ask(UnitIsPlayer, unit) == true and T.Ask(UnitCanAttack, "player", unit) == true
end

-- The part of a unit frame a row hangs from: the widget container, which the game hangs under the cast bar
-- (Blizzard_NamePlateUnitFrame.lua:550-557), else the cast bars, else the frame.
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

-- The abilities --------------------------------------------------------------------------------------------------------------------

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

-- The rank of an ability in a row, or nil when it is hidden or no switch of its kinds is on: interrupts, wards and immunities, crowd
-- control breaks, defensives, mobility, offensive cooldowns. An ability with a second kind shows when either switch is on. An ability
-- added by hand shows whatever its kind and comes first.
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

-- The icons a plate or bar shows now, in order: { a, start, seconds }, at most four for a plate and `most` for a bar. A used ability has
-- start and seconds. With Show on Always the abilities of the player's class and race whose use can be seen now are in the list too,
-- ready, with no start; with Only while on cooldown an icon whose timer has just ended stays for the flash, ready.
function E.Items(rec, most)
	local list = {}
	local book = T.Book(rec.owner)
	local have = {}
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
	-- Ready icons give way first when there is no room.
	for index = #list, 1, -1 do
		if #list <= (most or MOST) then
			break
		elseif list[index].ready then
			table.remove(list, index)
		end
	end
	while #list > (most or MOST) do
		list[#list] = nil
	end
	return list
end

-- The ready icons ----------------------------------------------------------------------------------------------------------------------

-- The race of the player of a plate or bar, as the name and the file name the game gives, or false when it is not plain.
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

-- True when the ability can be on the row of this player: his class and race are the ability's, and either he was seen to use it or it
-- is no talent, rune or item and his level is high enough.
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

-- True when the game never hides a cast or a buff of the ability, from the secrecy levels it gives the spells.
function E.Never(a)
	local known = E.never[a.key]
	if known == nil then
		known = false
		for _, id in ipairs(a.casts) do
			known = known or ns.CastLevel(id) == 0
		end
		for _, id in ipairs(a.buffs) do
			known = known or T.NeverHidden(id) == true
		end
		E.never[a.key] = known
	end
	return known
end

-- True when a use of the ability can be seen at this moment: the step of the interrupts, a cast the game never hides, a cast of the unit
-- the game lets through, or a buff that can be read. `state` keeps the answers of one pass.
function E.Visible(a, rec, state)
	if a.kind == 1 and not a.flags:find("p", 1, true) or E.Never(a) then
		return true
	end
	if state.casts == nil then
		state.casts = ns.CanSeeCasts(rec.unit) == true
		state.auras = ns.AurasReadable() == true
	end
	return state.casts or (#a.buffs > 0 and state.auras)
end

-- Adds to a list the abilities of the player's class and race that are shown, fit him and can be seen now, and are not on it.
function E.Bright(rec, list, have)
	if type(ns.ABILITIES) ~= "table" or type(ns.ABILITIES_BY_CLASS) ~= "table" or type(rec.class) ~= "string" then
		return
	end
	local state, seen = {}, {}
	local function Add(a)
		local rank = not have[a.key] and E.Rank(a)
		if rank and a.cd ~= 0 and not a.flags:find("n", 1, true) and E.Fits(rec, a) and E.Visible(a, rec, state) then
			list[#list + 1] = { a = a, rank = rank, ready = true, over = 0 }
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

-- Adds to a list the icons whose timer ended a moment ago, so that they can flash.
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

-- True when the sound is for this plate or bar: the target and the focus.
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

-- The timer of ability `key` has ended, a moment ago: with a flash chosen, its icon stays a moment, ready, so that it can flash.
function E.Ended(rec, key, last)
	if Opt("ready") == "none" or rec.owner == nil or type(last) ~= "table" or T.Now() - (last.start + last.seconds) > JUST then
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

-- The icon of an ability that was used is now ready: it flashes, and for the target and the focus Flash and sound plays the sound.
function E.Flash(row, icon)
	if Opt("ready") == "none" then
		return
	end
	ns.IconFlash(icon)
	local sound = Opt("ready") == "sound" and ns.SOUNDS[KITS[Opt("sound")] or 1]
	if sound and row.rec and E.Hears(row.rec) then
		ns.PlayKit(sound[1], KEY)
	end
end

-- The game says the sweep of a number the addon set is done through OnCooldownDone, which may not come for it, so the row is drawn
-- again a moment after the timer ends.
function E.Net(row, icon, item)
	icon.net = nil
	if Opt("ready") == "none" or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
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

-- The picture of an ability: the texture of its first spell the game knows.
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

-- The rows ------------------------------------------------------------------------------------------------------------------------

-- The row of a unit frame, made when first wanted, or of a bar (kept under the bar, on UIParent). nil when the game would not allow a
-- frame on it now.
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
	row = { holder = holder, icons = {}, drawn = {} }
	E.rows[bar or frame] = row
	return row
end

-- Hangs a row from the part of its unit frame it belongs under.
function E.Anchor(row, frame)
	local target = E.Target(frame)
	if row.target == target and row.anchored then
		return
	end
	row.holder:ClearAllPoints()
	row.holder:SetPoint("TOP", target, "BOTTOM", 0, -BELOW)
	row.target, row.anchored = target, true
end

-- Makes the icons a row needs and puts them in their places, centred. Returns how many it has.
function E.Fit(row, count)
	local size = Opt("size")
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
		row.icons[#row.icons + 1] = icon
	end
	count = math.min(count, #row.icons)
	local key = ("%s:%s"):format(size, count)
	if row.fitKey ~= key then
		row.fitKey = key
		local shown = {}
		for slot = 1, count do
			shown[slot] = row.icons[slot]
		end
		local width = ns.IconLayout(shown, row.holder, size, SPACING, "center")
		row.holder:SetSize(math.max(width, 1), size)
	end
	return count
end

-- Puts what a slot shows on its icon, when it is not what the icon already shows. A used ability has the sweep and, with Show on Always,
-- is dark; a ready one has none and is bright.
function E.Draw(row, slot, item)
	local icon = row.icons[slot]
	local key = "none"
	if item then
		key = ("%s:%s:%s:%s:%s:%s:%s"):format(item.a.key, tostring(item.start), tostring(Opt("seconds")), tostring(Opt("kindBorder")), item.ready and "ready" or "used",
			tostring(Opt("show")), tostring(Opt("ready")))
	end
	if row.drawn[slot] == key then
		return
	end
	row.drawn[slot] = key
	local was = icon.was
	icon.was = item and { key = item.a.key, ready = item.ready == true } or nil
	if not item then
		icon.key, icon.net = nil, nil
		ns.IconClear(icon)
		return
	end
	icon.key = item.a.key
	local look = { numbers = Opt("seconds") == true, kind = Opt("kindBorder") == true and item.a.kind or nil }
	if item.ready then
		icon.net = nil
		pcall(icon.cooldown.Clear, icon.cooldown)
	end
	ns.IconSet(icon, E.Texture(item.a), item.start, item.seconds, look)
	if not item.ready then
		E.Net(row, icon, item)
	elseif was and was.key == item.a.key and not was.ready then
		E.Flash(row, icon)
	end
	local level = (not item.ready and Opt("show") == "always") and DARK or 1
	icon.texture:SetDesaturated(level < 1)
	icon.texture:SetVertexColor(level, level, level)
end

-- Takes every icon of a row away and hides it.
function E.Blank(row)
	for slot = 1, #row.icons do
		E.Draw(row, slot, nil)
	end
	row.holder:Hide()
end

-- The icons of one plate, from the timers of its player.
function E.RenderRec(rec)
	if rec.mover then
		return E.RenderBar(rec)
	end
	local row = E.rows[rec.frame]
	if row and row.testing then
		return
	end
	local items = E.PlatesOn() and E.Items(rec) or {}
	if #items == 0 then
		if row then
			E.Blank(row)
		end
		E.stuck[rec.frame] = nil
		return
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

-- The bars ---------------------------------------------------------------------------------------------------------------------------

-- The record of the plate that shows a unit: the unit frame of its plate is the frame of one of the records.
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

-- Hangs a bar from the spot saved with the movers, else above the target or focus frame, else from the middle of the screen.
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

-- The arena ----------------------------------------------------------------------------------------------------------------------

-- True while the player is in an arena: IsActiveBattlefieldArena or C_PvP.IsArena answers a plain true (GlobalAPI.lua:6023 and 3475,
-- PvpInfoDocumentation.lua:914). A call that raises is noted for the status. EllesmereUI has no arena break icon; this is Flat UI's own,
-- and follows its rule of events only: no hook, no call into the game's arena frames.
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

-- Looks at the arena again: the icons are drawn again with a new stamp, and what the arena had told is dropped after leaving it.
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

-- The arena or the opponent list changed: the arena is looked at again and the bars are drawn.
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

-- The game says which spell breaks the crowd control of an opponent. Its spell ID may be withheld: it is handed unread to the call that
-- makes the picture, and the picture is kept unread for the icon (UnitDocumentation.lua:3535-3545). A withheld opponent token keeps
-- nothing.
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

-- Another cooldown of the arena changed: the sweeps are asked for again.
function E.ArenaCooldowns()
	local A = E.arena
	A.stamp = A.stamp + 1
	if A.on and ns.Enabled(KEY) then
		for _, bar in pairs(E.bars) do
			E.RenderBar(bar)
		end
	end
end

-- The arena opponent a bar's unit is: a number 1 to 5 when UnitIsUnit answers a plain true, else nil and true when an answer was withheld.
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

-- The opponent whose break a bar shows, and the game's duration object for it: nothing while the setting is off, outside an arena, for
-- an unknown opponent and when the game refuses the call. bar.arenaWhy says which, for the check.
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

-- Puts the break of opponent n on a slot of a bar's row: the picture of the spell the game named, the sweep from the duration object. Both
-- are handed on unread. Display only: no border by kind, no alert at the end of the sweep.
function E.ArenaDraw(row, slot, n, duration)
	local icon = row.icons[slot]
	local key = ("arena:%s:%s:%s"):format(n, E.arena.stamp, tostring(Opt("seconds")))
	if row.drawn[slot] == key then
		return
	end
	row.drawn[slot] = key
	icon.key, icon.net, icon.was = nil, nil, nil
	pcall(icon.texture.SetTexture, icon.texture, UNKNOWN_ICON)
	local tex = E.arena.tex[n]
	if tex then
		pcall(icon.texture.SetTexture, icon.texture, tex[1])
	end
	icon.texture:SetDesaturated(false)
	icon.texture:SetVertexColor(1, 1, 1)
	ns.IconSet(icon, nil, nil, duration, { numbers = Opt("seconds") == true })
end

-- One line for /flatui check, or nil: how the break of the target and focus bars stands in an arena.
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

-- The icons of a bar, from the timers of the player it shows.
function E.RenderBar(bar)
	local row = E.rows[bar]
	if row and row.testing then
		return
	end
	local items = E.BarsOn() and bar.owner and E.Items(bar, BAR_MOST) or {}
	local arena, duration = nil, nil
	if E.arena.on then
		arena, duration = E.ArenaFor(bar)
	end
	if #items == 0 and not arena then
		if row then
			E.Blank(row)
		end
		return
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

-- Who a bar shows now: { owner, class } for an enemy player whose GUID is plain, or whose plate has a record; nothing for a creature, a
-- friendly player or no unit. The second answer is true for an enemy player with no owner yet: his plate is not on screen.
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

-- The target or focus has changed: the bar shows that player, is listened to, and is drawn from his timers.
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

-- A plate came or went: a bar that waits for a plate, or is kept by one, is looked at again.
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

-- True while a plate or a bar has icons to keep up to date.
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

-- A plate that could not get its row in combat gets it when combat ends.
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

-- A look every half second while a plate of an enemy player is on screen: icons whose sweep ended go, and the status is right.
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

-- The lists ----------------------------------------------------------------------------------------------------------------------------

local function Whole(value, most)
	return Plain(value, "number") and value >= 1 and value <= most and value == math.floor(value)
end

-- What the account keeps: added = { [ability key] = true or seconds, [spell ID] = seconds } and hidden = { [ability key] = true }.
-- Damaged entries are dropped.
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

-- The lists as the rows use them: maps added, hidden and seconds (by ability key), the abilities made from the spells added by ID
-- (custom), and those by cast ID. Kept until a list changes.
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

-- A list changed: what the rows read is made again, and the rows are drawn. Both work in a fight and with the page off.
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

-- An ability by name, with its class in brackets for a class's.
function E.Name(a)
	if a.class and a.class ~= "ALL" then
		return ("%s (%s)"):format(a.name, Capital(a.class))
	end
	return a.name
end

-- The abilities of the data and the custom ones, as one list.
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

-- The lines of a list as { key, text, ability }, by name; two with one name get the spell ID beside it.
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

-- True for an ability that has no cooldown to show.
function E.NoCooldown(a)
	return a.cd == 0 or a.flags:find("n", 1, true) ~= nil
end

-- True when the ability is shown by the switches and the lists.
function E.IsShown(a)
	return not E.NoCooldown(a) and E.Rank(a) ~= nil
end

-- The abilities of the data that the switches and the lists do not show now, by name.
function ns.EnemyAbilityCandidates()
	local out = {}
	for _, a in ipairs(type(ns.ABILITIES) == "table" and ns.ABILITIES or {}) do
		if not E.NoCooldown(a) and not E.IsShown(a) then
			out[#out + 1] = a
		end
	end
	return E.Lines(out)
end

-- The abilities shown now, by name.
function ns.EnemyAbilityShown()
	local out = {}
	for _, a in ipairs(E.Every()) do
		if E.IsShown(a) then
			out[#out + 1] = a
		end
	end
	return E.Lines(out)
end

-- The ability of a key, or nil.
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

-- The abilities that have a spell ID among their casts.
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

-- The abilities with a name, in any capitals, with or without the class in brackets.
function E.ByName(text)
	local found, wanted = {}, text:lower()
	for _, a in ipairs(E.Every()) do
		if a.name:lower() == wanted or E.Name(a):lower() == wanted then
			found[#found + 1] = a
		end
	end
	return found
end

-- How many abilities were added by hand.
function E.Count(saved)
	local count = 0
	for _ in pairs(saved.added) do
		count = count + 1
	end
	return count
end

-- Shows an ability whatever its kind. With seconds the cooldown of its timers is that. Returns true or false and what to tell.
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

-- A spell the data lacks, by ID, with its cooldown in seconds. False and what to tell when the game knows no spell by the ID.
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

-- Takes an ability off the rows.
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

-- The two dropdowns of the page: each is called with the key of the line chosen.
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

-- The words typed after add: a link or a number is a spell ID, anything else a name, and a number last is the cooldown in seconds.
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

-- The one ability a word names. nil when there is none, and nil with a message when more than one has the name or the ID: then nothing
-- is changed.
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

-- /flatui enemy list: each ability shown with its cooldown and whether a use of it can be seen here.
function E.SlashList()
	local state = {}
	local rec = { unit = "target" }
	local rows = ns.EnemyAbilityShown()
	if #rows == 0 then
		print("No abilities shown.")
	end
	for _, row in ipairs(rows) do
		local a = row[3]
		print(("%s: %d seconds, %s."):format(row[2], a.cd, E.Visible(a, rec, state) and "use can be seen here" or "use cannot be seen here"))
	end
end

-- /flatui enemy clear: the running timers of enemies are forgotten. What was seen of a player stays.
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

-- Listening ---------------------------------------------------------------------------------------------------------------------------

-- A plate of an enemy player: it is listened to, and its row is drawn from the timers of its player.
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
		-- A unit frame the game gives to another unit keeps nothing of the last one.
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

-- A plate goes: its unit is not listened to any more, a timer kept by unit frame is lost with it, and its icons are taken away on the
-- next frame. A timer kept by GUID stays with the player.
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

-- The plates on screen now, from the tokens the game names them by.
function E.Scan()
	for number = 1, PLATES do
		local unit = "nameplate" .. number
		if not E.plates[unit] and E.UnitFrameOf(unit) then
			E.Added(unit)
		end
	end
end

-- The module is off: no plate is listened to and no icon is shown.
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

-- The enemy a unit token names, as the plate record of an enemy player: a nameplate token, or a token whose GUID is a plate's.
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

-- A cast of a unit that the game let through: the ability it is starts its timers.
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

-- The abilities of the cast of a spell that have a cooldown typed for them: their timers take it.
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

-- The abilities of the buffs of an enemy, from the abilities that list buff `id`: a buff of its own starts the timer of the enemy; a
-- buff cast on another (flag o) starts that of its caster, when the caster is one of the plates.
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

-- An ability started by a buff that has a cooldown typed for it: its timer takes it.
function E.Retimed(owner, a, at)
	local seconds = E.Lists().seconds[a.key]
	local book = seconds and T.Book(owner)
	local timer = book and book.timers[a.key]
	if timer and timer.start == at then
		timer.seconds = seconds
	end
end

-- A buff of a unit seen in a pass.
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

-- Putting it in place ---------------------------------------------------------------------------------------------------------------

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
		end
		row.fitKey, row.placeKey = nil, nil
	end
	E.Render()
	if E.Live() then
		E.Arm()
	end
end

function E.OnRestriction()
	if not E.Live() then
		return
	end
	E.Render()
	Soon(function()
		ns.Try(KEY, E.Render)
	end)
end

-- The player enters a place: the timers may have been cleared (Tracking.lua), so the icons are drawn again after it has done so.
function E.OnWorld()
	E.Refresh()
	if E.Live() then
		Soon(function()
			ns.Try(KEY, E.Render)
		end)
	end
end

function E.Start()
	-- The kick that stops the player's own cast is heard by the small frame of Tracking.lua.
	T.Listen()
	T.Subscribe(KEY, function(unit, spell)
		ns.Try(KEY, E.Cast, unit, spell)
	end, function(unit, id, start, seconds, source)
		ns.Try(KEY, E.Aura, unit, id, start, seconds, source)
	end)
	E.Refresh()
end

-- True while the target bar or the focus bar has a handle in the movers.
function ns.EnemyTargetBarShown()
	return ns.Enabled(KEY) and E.BarsOn()
end

function ns.EnemyFocusBarShown()
	return ns.Enabled(KEY) and E.BarsOn()
end

-- The movers set or put back the spot of a bar.
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

-- The test and the status -----------------------------------------------------------------------------------------------------------

-- Three sample icons on a row, for the test.
function E.Sample(row, rec, token, now)
	row.rec, row.testing = rec, token
	local count = E.Fit(row, 3)
	for slot = 1, #row.icons do
		row.drawn[slot] = nil
		if slot <= count then
			ns.IconSample(row.icons[slot], slot, now, 2 * slot, KEY)
			row.icons[slot].texture:SetDesaturated(false)
			row.icons[slot].texture:SetVertexColor(1, 1, 1)
		else
			ns.IconClear(row.icons[slot])
		end
	end
	row.holder:Show()
end

-- /flatui test: three sample icons on the plate of every enemy player on screen and on the target and focus bars, for a few seconds.
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

ns.EnemyCooldownsModule = E
