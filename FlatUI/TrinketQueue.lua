local _, ns = ...

local KEY, PART = "trinkets", "swaps"
local SLOTS = { top = 13, bottom = 14 }
local ORDER = { "top", "bottom" }
local OTHER = { top = "bottom", bottom = "top" }
local ROW = { top = "trinkets.autoTop", bottom = "trinkets.autoBottom" }
local AUTO = { autoTop = "top", autoBottom = "bottom" }
local WORD = { top = "Top", bottom = "Bottom" }
local MOST, LONGEST, READY_MOST = 24, 120, 60
local TIME = { SETTLE = 0.2, CONFIRM = 2, ASK = 60, LATE = 15, RETRY = 0.5, BUSY = 1, QUIET = 3, LOCKOUT = 30.5, GCD = 2, FAR = 3600, TRIES = 10, NEAR = 0.05 }
local BACKOFF = { 5, 20, 60 }
local MAX_ID = 2147483647
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local UNITS = { s = 1, m = 60, h = 3600, d = 86400 }
local TRINKET, ON_USE, LINES, RIDING = "INVTYPE_TRINKET", 44, 40, 11122
local T = {
	NO_CALL = "Trinket queue: this client cannot put on items (no C_Item.EquipItemByName), so nothing is swapped.",
	FALLBACK = "Trinket queue: the game did not give trinket cooldowns, so the queue reads them from the tooltips.",
	NO_SOUND = "Trinket queue: the game played no swap sound.",
	REFUSED_NOTE = "Trinket queue: the game refused %s.",
	REFUSED = "Flat UI: the game would not put on %s; the trinket queue leaves it until you press Queue now.",
	WEAR_REFUSED = "Flat UI: the game would not put on %s.",
	SWAP = "Flat UI: %s trinket: %s in place of %s (%s).",
	NOTHING = "nothing", COOLING = "on cooldown, %s", HIGHER = "ready again", EMPTY_SLOT = "the slot was empty",
	RIDE = "riding", OFF_MOUNT = "off the mount",
	REPORT = "Flat UI, Trinket queue, %s: %s",
	WEAR_FIGHT = "Flat UI: trinkets change after the fight.",
	WEAR_WAIT = "Flat UI: %s cannot go on now (%s).",
	WEAR_GONE = "Flat UI: %s is not in your bags.",
	WEAR_OFF = "Flat UI: the trinket queue's swaps are off. /flatui status says why.",
	ONLY = "Only trinkets go in the queue.",
	FULL = "That list is full (24).",
	NO_ITEM = "That is not an item.",
	PAUSED = "Flat UI: the trinket queue is paused: nothing is swapped until /flatui queue pause again.",
	RESUMED = "Flat UI: the trinket queue swaps again.",
	NOW = "Flat UI: the trinket queue looks again now, also at a trinket you put on or took off yourself.",
	OFF = "Flat UI: the trinket queue is off. Turn it on with Trinket queue (Character and gear).",
	LIST = "Flat UI: %s trinket list%s:",
	LIST_OFF = " (Auto queue off)",
	LIST_EMPTY = "  (empty)",
	LIST_LINE = "  %d. %s%s",
	HELP = "/flatui queue - the trinket queue window; queue top, bottom, pause, now, list, copy top or bottom, clear top or bottom",
	COPIED = "Flat UI: the %s trinket list took %d from the %s list, in its order, with each Delay and Stop.",
	COPY_NONE = "Flat UI: nothing to copy: every trinket of the %s list is in the %s trinket list already, or it is full.",
	COPY_EMPTY = "Flat UI: nothing to copy: the %s trinket list is empty.",
	CLEARED = "Flat UI: the %s trinket list is empty now (%d taken out).",
	CLEAR_NONE = "Flat UI: the %s trinket list is empty already.",
	WHICH = "Flat UI: say which list: /flatui queue %s top or %s bottom.",
	STATUS_PAUSED = "Trinket queue: paused.",
	STATUS_OFF = "Trinket queue, %s: auto queue off.",
	STATUS_SLOT = "Trinket queue, %s: wearing %s; %s%s.",
	STATUS_NEXT = "; next %s in %s",
	TIP_LINE = "Trinket queue: %s of %d, %s slot",
	TIP_STOP = " · Stop",
	TIP_DELAY = " · kept %d s",
	TIP_AUTO_OFF = " · Auto queue off",
	TIP_COLOUR = { 0.66, 0.68, 0.62 },
}
local WHY = {
	off = { "off", "The trinket queue is off" },
	auto = { "off", "Auto queue is off" },
	paused = { "halt", "Paused" },
	empty = { "on", "Nothing in the list yet" },
	pending = { "wait", "Putting it on" },
	nocall = { "halt", "This client cannot put on items" },
	fight = { "wait", "Waits for the end of the fight" },
	dead = { "wait", "Waits until you are alive" },
	cast = { "wait", "Waits for your cast to end" },
	busy = { "wait", "Waits for the cursor and your bags" },
	locked = { "wait", "Waits for the slot" },
	quiet = { "wait", "Waits a moment after the loading screen" },
	held = { "halt", "Held: you put it on. It stays until you use it or press Queue now" },
	emptied = { "halt", "Held empty: you took it off. It stays so until you put one on or press Queue now" },
	stop = { "halt", "Stop: kept on" },
	delay = { "wait", "Kept %d s more (delay)" },
	inuse = { "wait", "In use" },
	keep = { "on", "Ready" },
	wait = { "on", "On cooldown %s" },
	unknown = { "on", "Kept on: its cooldown cannot be read" },
	none = { "on", "Nothing in the list is in your bags" },
	next = { "on", "Waits for a trinket of the list to be ready" },
	higher = { "on", "Putting it on" },
	cooling = { "on", "Putting it on" },
	refused = { "halt", "The game refused it: Queue now tries it again" },
	riding = { "on", "Riding: Carrot on a Stick until you get off" },
	dismounted = { "on", "Off the mount: your trinket goes back on" },
}

local PLAIN = { delay = "Kept on for its delay", wait = "On cooldown" }

local RESTING = { keep = true, wait = true, unknown = true, none = true, next = true }

local Q, R, D = {}, {}, {}
local S = { pending = nil, fails = {}, nextTry = {}, refused = {}, said = {}, noted = {}, equippedAt = {}, heldAt = {}, heard = {}, uses = {},
	tipLen = {}, kinds = {}, levels = {}, loading = {}, autoWas = {}, once = {}, why = {}, untilAt = {}, nextAt = {}, next = {}, token = 0,
	soon = false, quietUntil = 0, version = 0, runs = 0, faults = {}, bags = nil, order = nil, fightTries = 0, normalised = false,
	fallback = false, listening = false, ear = nil, pattern = nil, late = nil, ridingOff = {}, rode = {},
	tipMarks = setmetatable({}, { __mode = "k" }), tipHooked = false }
ns.TrinketQueue = Q

local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

local function Fn(source, name)
	if type(source) ~= "table" or IsSecret(source) then
		return nil
	end
	local fn = source[name]
	return type(fn) == "function" and fn or nil
end

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, ...)
end

local function Ask(fn, ...)
	local ok, answer = Call(fn, ...)
	if ok and not IsSecret(answer) then
		return answer
	end
	return nil
end

local function Whole(value)
	return Finite(value) and value > 0 and value <= MAX_ID and value == math.floor(value)
end

local function Now()
	local now = Ask(GetTime)
	return Finite(now) and now or 0
end

local function Earliest(a, b)
	if a == nil then
		return b
	elseif b == nil then
		return a
	end
	return math.min(a, b)
end

function Q.Report(what, err)
	if S.faults[what] then
		return
	end
	S.faults[what] = true
	local handler = type(geterrorhandler) == "function" and geterrorhandler() or nil
	if type(handler) == "function" then
		pcall(handler, T.REPORT:format(tostring(what), tostring(err)))
	end
end

local function Step(_, fn, ...)
	return fn(...)
end

function Q.Run(fn, ...)
	S.runs = S.runs + 1
	local ok, err = ns.EachPart(KEY, PART, Step, S.runs, fn, ...)
	if not ok and err ~= nil then
		Q.Report(PART, err)
		if ns.PartStopped(KEY, PART) then
			Q.Halt()
		end
	end
	return ok == true
end

function Q.Running()
	return type(ns.modules) == "table" and ns.modules[KEY] ~= nil and ns.ModuleOn(KEY) and not ns.PartStopped(KEY, PART)
end

function Q.Halt()
	S.token = S.token + 1
	S.pending = nil
	R.Ear(false)
end

function R.CleanList(list)
	if type(list) ~= "table" then
		return {}, true
	end
	local out, seen, changed = {}, {}, false
	for _, entry in ipairs(list) do
		local id = type(entry) == "table" and entry.item or nil
		if Whole(id) and not seen[id] and #out < MOST then
			seen[id] = true
			local delay = Finite(entry.delay) and math.max(0, math.min(LONGEST, math.floor(entry.delay))) or 0
			local stop = entry.stop == true or nil
			for key in pairs(entry) do
				changed = changed or (key ~= "item" and key ~= "delay" and key ~= "stop")
			end
			changed = changed or delay ~= entry.delay or stop ~= entry.stop
			out[#out + 1] = { item = id, delay = delay, stop = stop }
		else
			changed = true
		end
	end
	local count = 0
	for _ in pairs(list) do
		count = count + 1
	end
	if changed or count ~= #out then
		return out, true
	end
	return list, false
end

function R.Normalise(store)
	for _, n in ipairs(ORDER) do
		if store[n] ~= nil then
			local list, changed = R.CleanList(store[n])
			if changed then
				store[n] = list
			end
		end
	end
	if store.paused ~= nil and store.paused ~= true then
		store.paused = nil
	end
	if store.held ~= nil then
		if type(store.held) ~= "table" then
			store.held = nil
		else
			for key, id in pairs(store.held) do
				if not SLOTS[key] or not (Whole(id) or id == 0) then
					store.held[key] = nil
				end
			end
		end
	end
	if store.riding ~= nil then
		if type(store.riding) ~= "table" then
			store.riding = nil
		else
			for key, id in pairs(store.riding) do
				if not SLOTS[key] or not (Whole(id) or id == 0) then
					store.riding[key] = nil
				end
			end
		end
	end
	if store.auto ~= nil then
		if type(store.auto) ~= "table" then
			store.auto = nil
		else
			for key, on in pairs(store.auto) do
				if not SLOTS[key] or on ~= true then
					store.auto[key] = nil
				end
			end
		end
	end
end

function Q.Store(make)
	local char = ns.Character()
	if type(char) ~= "table" then
		return nil
	end
	local store = char.trinketQueue
	if type(store) ~= "table" then
		if not make then
			return nil
		end
		store = {}
		char.trinketQueue = store
	end
	if not S.normalised then
		S.normalised = true
		R.Normalise(store)
	end
	return store
end

function Q.List(n, make)
	if not SLOTS[n] then
		return {}
	end
	local store = Q.Store(make)
	if not store then
		return {}
	end
	if type(store[n]) ~= "table" then
		if not make then
			return {}
		end
		store[n] = {}
	end
	return store[n]
end

function Q.Find(list, id)
	if id == nil then
		return nil, nil
	end
	for index, entry in ipairs(list) do
		if entry.item == id then
			return index, entry
		end
	end
	return nil, nil
end

function Q.Held(n)
	local store = Q.Store(false)
	local held = store and store.held
	return type(held) == "table" and held[n] or nil
end

function R.Unhold(n)
	local store = Q.Store(false)
	if store and type(store.held) == "table" and store.held[n] ~= nil then
		store.held[n] = nil
		S.version = S.version + 1
	end
end

function R.Hold(n, id)
	local store = Q.Store(true)
	if type(store.held) ~= "table" then
		store.held = {}
	end
	store.held[n] = id
	S.heldAt[n] = Now()
	S.version = S.version + 1
end

function R.Edited()
	S.version = S.version + 1
	Q.Soon()
end

function R.Worn(slot)
	local id = Ask(GetInventoryItemID, "player", slot)
	return Whole(id) and id or nil
end

function R.WornLink(slot)
	local link = Ask(GetInventoryItemLink, "player", slot)
	return type(link) == "string" and link ~= "" and link or nil
end

function R.Load(id)
	if not S.loading[id] then
		S.loading[id] = true
		Call(Fn(C_Item, "RequestLoadItemDataByID"), id)
	end
end

function R.ItemID(item)
	if Whole(item) then
		return item
	end
	if type(item) == "string" and not IsSecret(item) then
		local id = tonumber(item:match("item:(%d+)") or item:match("^%s*(%d+)%s*$") or "")
		return Whole(id) and id or nil
	end
	return nil
end

function R.Trinket(id)
	if S.kinds[id] ~= nil then
		return S.kinds[id]
	end
	local ok, _, _, _, slot = Call(Fn(C_Item, "GetItemInfoInstant"), id)
	if not ok or IsSecret(slot) then
		return nil
	end
	S.kinds[id] = slot == TRINKET
	return S.kinds[id]
end

function R.Scan()
	if S.bags then
		return S.bags, S.order
	end
	local bags, order = {}, {}
	local containers = type(C_Container) == "table" and C_Container or {}
	local last = Finite(NUM_BAG_SLOTS) and NUM_BAG_SLOTS or 4
	for bag = 0, last do
		local slots = Ask(containers.GetContainerNumSlots, bag)
		for slot = 1, Finite(slots) and slots or 0 do
			local info = Ask(containers.GetContainerItemInfo, bag, slot)
			local id = type(info) == "table" and info.itemID or nil
			if Whole(id) and R.Trinket(id) == true then
				local link = info.hyperlink
				local copy = { bag = bag, slot = slot, link = not IsSecret(link) and type(link) == "string" and link or nil,
					locked = IsSecret(info.isLocked) or info.isLocked == true, bound = not IsSecret(info.isBound) and info.isBound == true }
				if not bags[id] then
					bags[id] = {}
					order[#order + 1] = id
				end
				table.insert(bags[id], copy)
			end
		end
	end
	S.bags, S.order = bags, order
	return bags, order
end

function R.Copies(id)
	local bags = R.Scan()
	return bags[id] or {}
end

function R.Use(id)
	if S.uses[id] ~= nil then
		return S.uses[id]
	end
	local ok, _, spellID = Call(Fn(C_Item, "GetItemSpell"), id)
	if ok and Whole(spellID) then
		S.uses[id] = spellID
		return spellID
	end
	if ok and not IsSecret(spellID) and Ask(Fn(C_Item, "IsItemDataCachedByID"), id) == true then
		S.uses[id] = false
		return false
	end
	R.Load(id)
	return nil
end

function R.Level(id)
	if S.levels[id] ~= nil then
		return S.levels[id]
	end
	local ok, _, _, _, _, level = Call(Fn(C_Item, "GetItemInfo"), id)
	if ok and Finite(level) then
		S.levels[id] = level
		return level
	end
	R.Load(id)
	return nil
end

function R.Plain(ok, start, duration, enable)
	if not (ok and Finite(start) and Finite(duration)) then
		return nil
	end
	return start, duration, not IsSecret(enable) and (enable == false or enable == 0)
end

function R.Cooldown(id, where)
	local start, duration, held = R.Plain(Call(Fn(C_Item, "GetItemCooldown"), id))
	if start == nil and where.worn then
		start, duration, held = R.Plain(Call(GetInventoryItemCooldown, "player", where.worn))
	elseif start == nil and where.bag then
		start, duration, held = R.Plain(Call(Fn(C_Container, "GetContainerItemCooldown"), where.bag, where.slot))
	end
	return start, duration, held
end

function R.TipLines(getter, ...)
	local ok, data = Call(Fn(C_TooltipInfo, getter), ...)
	if not ok or type(data) ~= "table" or IsSecret(data) then
		return nil
	end
	local lines = data.lines
	return type(lines) == "table" and not IsSecret(lines) and lines or nil
end

function R.Text(line)
	local text = type(line) == "table" and line.leftText or nil
	return not IsSecret(text) and type(text) == "string" and text or nil
end

function R.Seconds(text)
	local m, s = text:match("(%d+):(%d%d)")
	if m then
		return tonumber(m) * 60 + tonumber(s)
	end
	local number, word = text:match("(%d+%.?%d*)%s*(%a)")
	local unit = word and UNITS[word:lower()]
	return number and unit and tonumber(number) * unit or nil
end

function R.Pattern()
	if S.pattern then
		return S.pattern
	end
	local text = _G.ITEM_COOLDOWN_TIME
	if type(text) == "string" and not IsSecret(text) and text:find("%s", 1, true) then
		S.pattern = "^" .. text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
	else
		S.pattern = "^Cooldown remaining: (.+)$"
	end
	return S.pattern
end

function R.TipLeft(where)
	if D.Fighting() then
		return nil
	end
	local lines
	if where.worn then
		lines = R.TipLines("GetInventoryItem", "player", where.worn)
	elseif where.bag then
		lines = R.TipLines("GetBagItem", where.bag, where.slot)
	end
	if not lines then
		return nil
	end
	local pattern = R.Pattern()
	for index = 1, LINES do
		local line = lines[index]
		if type(line) ~= "table" then
			break
		end
		local text = R.Text(line)
		local rest = text and text:match(pattern)
		if rest then
			return R.Seconds(rest)
		end
	end
	return 0
end

function R.TipLength(id)
	if S.tipLen[id] ~= nil then
		return S.tipLen[id] or nil
	end
	local lines = R.TipLines("GetItemByID", id)
	if not lines then
		return nil
	end
	local onUse = _G.ITEM_SPELL_TRIGGER_ONUSE
	onUse = type(onUse) == "string" and not IsSecret(onUse) and onUse ~= "" and onUse or "Use:"
	for index = 1, LINES do
		local line = lines[index]
		if type(line) ~= "table" then
			break
		end
		local text, kind = R.Text(line), line.type
		if text and ((not IsSecret(kind) and kind == ON_USE) or text:sub(1, #onUse) == onUse) then
			local number, word = text:match("%((%d+%.?%d*)%s+(%a+)%.?%s+[Cc]ooldown%)")
			local unit = word and UNITS[word:sub(1, 1):lower()]
			if number and unit then
				S.tipLen[id] = tonumber(number) * unit
				return S.tipLen[id]
			end
		end
	end
	S.tipLen[id] = false
	return nil
end

function R.Left(id, where, now)
	local use = R.Use(id)
	if use == false then
		return false
	end
	local start, duration, held = R.Cooldown(id, where)
	if start ~= nil then
		if S.fallback then
			S.fallback = false
			ns.ClearNote(KEY, T.FALLBACK)
		end
		local used = duration > TIME.LOCKOUT and start or nil
		if held then
			return "held", used, start, duration
		end
		if duration <= TIME.GCD or start + duration <= now then
			return 0, used, start, duration
		end
		return start + duration - now, used, start, duration
	end
	if not (where.worn or where.bag) then
		return nil
	end
	if not S.fallback then
		S.fallback = true
		ns.Note(KEY, T.FALLBACK)
	end
	local left = R.TipLeft(where)
	local heard, length = S.heard[id], R.TipLength(id)
	if heard and length then
		left = math.max(left or 0, heard + length - now)
	end
	return left, heard, nil, nil
end

function R.Shown(name)
	local frame = _G[name]
	if type(frame) ~= "table" or ns.Forbidden(frame) then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and (IsSecret(shown) or shown == true)
end

function R.Yes(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	local ok, answer = pcall(fn, ...)
	return not ok or IsSecret(answer) or answer == true
end

function R.Locked(slot)
	return R.Yes(IsInventoryItemLocked, slot)
end

function R.CursorHolds()
	local ok, has = Call(CursorHasItem)
	if ok and (IsSecret(has) or has == true) then
		return true
	end
	local okInfo, kind = Call(GetCursorInfo)
	return okInfo and kind ~= nil
end

function R.ClearCursor()
	Call(ClearCursor)
end

function R.Heard(unit, spellID)
	if unit ~= "player" or not Whole(spellID) then
		return
	end
	for _, n in ipairs(ORDER) do
		local worn = R.Worn(SLOTS[n])
		if worn and R.Use(worn) == spellID then
			S.heard[worn] = Now()
			Q.Soon()
		end
	end
end

function R.Ear(on)
	on = on == true
	if on == S.listening then
		return
	end
	if on and not S.ear then
		S.ear = CreateFrame("Frame")
		ns.Own[S.ear] = true
		S.ear:SetScript("OnEvent", function(_, _, unit, _, spellID)
			if not IsSecret(unit) then
				Q.Run(R.Heard, unit, spellID)
			end
		end)
	end
	if not S.ear then
		return
	end
	if on then
		S.listening = pcall(S.ear.RegisterUnitEvent, S.ear, "UNIT_SPELLCAST_SUCCEEDED", "player") == true
	else
		pcall(S.ear.UnregisterAllEvents, S.ear)
		S.listening = false
	end
end

function R.EarWanted()
	if not Q.Active() then
		return false
	end
	if S.fallback then
		return true
	end
	for _, n in ipairs(ORDER) do
		for _, entry in ipairs(Q.List(n)) do
			if entry.delay > 0 then
				return true
			end
		end
	end
	return false
end

function R.ClearRefused(only)
	for id in pairs(S.refused) do
		if not only or only[id] then
			S.refused[id] = nil
			if S.noted[id] then
				ns.ClearNote(KEY, S.noted[id])
				S.noted[id] = nil
			end
		end
	end
end

function D.Fighting()
	return R.Yes(InCombatLockdown) or R.Yes(UnitAffectingCombat, "player")
end

function D.Lockdown()
	return R.Yes(InCombatLockdown)
end

function D.Casting()
	for _, name in ipairs({ "UnitCastingInfo", "UnitChannelInfo" }) do
		local ok, answer = Call(_G[name], "player")
		if ok and (IsSecret(answer) or answer ~= nil) then
			return true
		end
	end
	return false
end

function D.Busy()
	if R.CursorHolds() or R.Yes(SpellIsTargeting) then
		return true
	end
	if Ask(Fn(ns, "ErrandsSelling")) == true then
		return true
	end
	local bags = ns.Bags
	local bank = type(bags) == "table" and bags.Bank or nil
	if Fn(bank, "Busy") and Ask(bank.Busy) ~= nil then
		return true
	end
	if R.Shown("TradeFrame") or R.Shown("StackSplitFrame") then
		return true
	end
	return Ask(Fn(bags, "Sorting"), "bags") == true
end

function D.Blocked(now)
	if S.pending then
		return "pending"
	end
	if not Fn(C_Item, "EquipItemByName") then
		ns.Note(KEY, T.NO_CALL)
		return "nocall"
	end
	if D.Fighting() then
		if not D.Lockdown() and S.fightTries < TIME.TRIES then
			S.fightTries = S.fightTries + 1
			return "fight", now + TIME.RETRY
		end
		return "fight"
	end
	if R.Yes(UnitIsDeadOrGhost, "player") then
		return "dead"
	end
	if D.Casting() then
		return "cast", now + TIME.RETRY
	end
	if D.Busy() then
		return "busy", now + TIME.BUSY
	end
	return nil
end

function D.Static(n)
	if not Q.Running() then
		return "off"
	elseif Q.Paused() then
		return "paused"
	elseif not Q.Auto(n) then
		return "auto"
	elseif #Q.List(n) == 0 then
		return "empty"
	end
	return nil
end

function D.Ready(left, start, duration, equippedAt, threshold)
	if left == false then
		return true
	end
	if Finite(left) and left <= threshold then
		return true
	end
	return Finite(start) and Finite(duration) and duration <= TIME.LOCKOUT and equippedAt ~= nil and math.abs(start - equippedAt) <= 1
end

function D.Usable(id, otherWorn, now)
	if S.refused[id] then
		return nil
	end
	if S.nextTry[id] and now < S.nextTry[id] then
		return nil, S.nextTry[id]
	end
	local copy
	for _, candidate in ipairs(R.Copies(id)) do
		if not candidate.locked and candidate.bound then
			copy = candidate
			break
		end
	end
	if not copy then
		return nil
	end
	local level, mine = R.Level(id), Ask(UnitLevel, "player")
	if Finite(level) and Finite(mine) and level > mine then
		return nil
	end
	if otherWorn == id then
		local ok, unique = Call(Fn(C_Item, "GetItemUniquenessByID"), id)
		if not (ok and not IsSecret(unique) and unique == false) then
			return nil
		end
	end
	return copy
end

function D.Candidate(id, otherWorn, now, threshold)
	local copy, retry = D.Usable(id, otherWorn, now)
	if not copy then
		return nil, retry, retry ~= nil
	end
	local left = R.Left(id, copy, now)
	if left == false or (Finite(left) and left <= threshold) then
		return copy, nil, true
	end
	if Finite(left) then
		return nil, now + left - threshold, true
	end
	return nil, nil, true
end

function D.Through(n, list, first, last, otherWorn, now, threshold)
	local wake, any = nil, false
	for i = first, last do
		local copy, at, usable = D.Candidate(list[i].item, otherWorn, now, threshold)
		if copy then
			return list[i], copy
		end
		any = any or usable
		if at and (S.nextAt[n] == nil or at < S.nextAt[n]) then
			S.next[n], S.nextAt[n] = list[i].item, at
		end
		wake = Earliest(wake, at)
	end
	return nil, nil, wake, any
end

function D.Slot(n, now, threshold)
	local slot, list = SLOTS[n], Q.List(n)
	local worn, otherWorn = R.Worn(slot), R.Worn(SLOTS[OTHER[n]])
	local once = S.once[n]
	S.once[n] = nil
	S.next[n], S.nextAt[n], S.untilAt[n] = nil, nil, nil
	local held = Q.Held(n)
	if held ~= nil and held ~= (worn or 0) then
		R.Unhold(n)
		held = nil
	end
	local index, entry = Q.Find(list, worn)
	local left, used, start, duration
	if worn then
		left, used, start, duration = R.Left(worn, { worn = slot }, now)
	end
	if held ~= nil then
		if used and S.heldAt[n] and used > S.heldAt[n] then
			R.Unhold(n)
		else
			return held == 0 and "emptied" or "held"
		end
	end
	if entry and entry.stop and not once then
		return "stop"
	end
	if entry and entry.delay > 0 and not once then
		local since = used or S.heard[worn]
		if since and now < since + entry.delay then
			S.untilAt[n] = since + entry.delay
			return "delay", since + entry.delay
		end
	end
	if left == "held" then
		return "inuse"
	end
	local place = index or (#list + 1)
	local target, copy, wake, any = D.Through(n, list, 1, place - 1, otherWorn, now, threshold)
	if target then
		return "higher", nil, target, copy
	end
	if not index then
		return any and "next" or "none", wake
	end
	if left == nil then
		return "unknown", wake
	end
	if not D.Ready(left, start, duration, S.equippedAt[n], threshold) then
		local lower, lowerCopy, lowerWake = D.Through(n, list, place + 1, #list, otherWorn, now, threshold)
		if lower then
			return "cooling", nil, lower, lowerCopy
		end
		return "wait", Earliest(wake, lowerWake)
	end
	return "keep", wake
end

function D.Threshold()
	local value = ns.Get("trinkets.ready")
	return Finite(value) and math.max(0, math.min(READY_MOST, value)) or 30
end

function D.Signature()
	return ("%s/%s/%s/%s"):format(tostring(S.why.top), tostring(S.why.bottom), tostring(S.next.top), tostring(S.next.bottom))
end

function D.RidingSlot()
	local n = ns.Get("trinkets.riding")
	return SLOTS[n] and n or nil
end

function D.Mounted()
	return Ask(IsMounted) == true and not R.Yes(UnitOnTaxi, "player")
end

function D.Back(n)
	local store = Q.Store(false)
	local riding = store and store.riding
	return type(riding) == "table" and riding[n] or nil
end

function D.SetBack(n, id)
	local store = Q.Store(id ~= nil)
	if not store then
		return
	end
	if type(store.riding) ~= "table" then
		if id == nil then
			return
		end
		store.riding = {}
	end
	store.riding[n] = id
	if next(store.riding) == nil then
		store.riding = nil
	end
end

function D.Forget()
	local store = Q.Store(false)
	local riding = store and store.riding
	if type(riding) ~= "table" then
		return
	end
	local keep = D.RidingSlot()
	for _, n in ipairs(ORDER) do
		if n ~= keep then
			riding[n] = nil
		end
	end
	if next(riding) == nil then
		store.riding = nil
	end
end

function D.Riding(n, now, threshold, blocked, blockedAt, quiet)
	local slot = SLOTS[n]
	local worn, otherWorn = R.Worn(slot), R.Worn(SLOTS[OTHER[n]])
	local ride, back
	local pending = S.pending
	if pending and pending.name == n and (pending.why == "riding" or pending.why == "dismounted") then
		return "pending"
	end
	if D.Mounted() then
		if worn ~= RIDING then
			if S.ridingOff[n] or otherWorn == RIDING then
				return nil
			end
			ride = D.Usable(RIDING, otherWorn, now)
			if not ride then
				return nil
			end
		end
	else
		S.ridingOff[n] = nil
		back = D.Back(n)
		if back == nil then
			return nil
		elseif worn ~= RIDING or back == 0 then
			D.SetBack(n, nil)
			return nil
		end
	end
	S.next[n], S.nextAt[n], S.untilAt[n] = nil, nil, nil
	if not ride and not back then
		return "riding"
	elseif blocked then
		return blocked, blockedAt
	elseif quiet then
		return "quiet", S.quietUntil
	elseif R.Locked(slot) then
		return "locked"
	elseif ride then
		D.SetBack(n, D.Back(n) or worn or 0)
		return "riding", nil, RIDING, ride
	end
	local why, at, entry, copy
	if Q.Auto(n) and #Q.List(n) > 0 and Q.Held(n) == nil then
		why, at, entry, copy = D.Slot(n, now, threshold)
		if entry and copy then
			return "dismounted", nil, entry.item, copy
		end
	end
	local home, retry = D.Usable(back, otherWorn, now)
	if home then
		return "dismounted", nil, back, home
	elseif not retry then
		D.SetBack(n, nil)
	end
	if why then
		return why, Earliest(at, retry)
	end
	return retry and "dismounted" or nil, retry
end

function D.Pass()
	local now = Now()
	local threshold = D.Threshold()
	local blocked, blockedAt = D.Blocked(now)
	local quiet = now < S.quietUntil
	local wake, before = nil, D.Signature()
	local riding = Q.Running() and not Q.Paused() and D.RidingSlot()
	D.Forget()
	for _, n in ipairs(ORDER) do
		local why, at, item, copy = nil, nil, nil, nil
		if riding == n then
			why, at, item, copy = D.Riding(n, now, threshold, blocked, blockedAt, quiet)
		end
		S.rode[n] = why and true or nil
		if not why then
			why = D.Static(n)
			if why then
				S.next[n], S.nextAt[n], S.untilAt[n] = nil, nil, nil
			elseif blocked then
				why, at = blocked, blockedAt
			elseif quiet then
				why, at = "quiet", S.quietUntil
			elseif R.Locked(SLOTS[n]) then
				why = "locked"
			else
				local entry
				why, at, entry, copy = D.Slot(n, now, threshold)
				item = entry and entry.item
			end
		end
		S.why[n] = why
		wake = Earliest(wake, at)
		if item and copy then
			Q.Swap(n, item, copy, why, false)
			blocked, blockedAt = "pending", nil
		end
	end
	if before ~= D.Signature() then
		S.version = S.version + 1
	end
	return wake
end

function D.Arm(at)
	S.token = S.token + 1
	if at == nil or not (C_Timer and C_Timer.After) then
		return
	end
	local token = S.token
	C_Timer.After(math.max(TIME.NEAR, math.min(TIME.FAR, at - Now())), function()
		if token == S.token then
			Q.Run(D.Look)
		end
	end)
end

function D.Look()
	if not Q.Active() then
		D.Idle()
		return
	end
	D.Arm(D.Pass())
	R.Ear(R.EarWanted())
end

function D.Idle()
	S.token = S.token + 1
	R.Ear(false)
	D.Forget()
	for _, n in ipairs(ORDER) do
		local why = D.Static(n) or "auto"
		S.rode[n] = nil
		if S.why[n] ~= why then
			S.why[n] = why
			S.version = S.version + 1
		end
	end
end

function R.PickUp(copy, slot)
	local pick = Fn(C_Container, "PickupContainerItem")
	if not pick or type(PickupInventoryItem) ~= "function" then
		return false
	end
	if not pcall(pick, copy.bag, copy.slot) then
		R.ClearCursor()
		return false
	end
	local placed = false
	if Ask(CursorHasItem) == true and Ask(Fn(C_PaperDollInfo, "CursorCanGoInSlot"), slot) == true and not R.Locked(slot) then
		placed = pcall(PickupInventoryItem, slot)
	end
	if R.CursorHolds() then
		R.ClearCursor()
	end
	return placed
end

function R.Mixed(id)
	local bound, unbound = false, false
	for _, copy in ipairs(R.Copies(id)) do
		bound = bound or copy.bound
		unbound = unbound or not copy.bound
	end
	return bound and unbound
end

function Q.Swap(n, id, copy, why, wear)
	local slot = SLOTS[n]
	local from = R.Worn(slot)
	local pending = { name = n, item = id, at = Now(), from = from, fromLink = R.WornLink(slot), why = why, wear = wear,
		asked = wear and not copy.bound or nil }
	if why == "cooling" and from then
		local left = R.Left(from, { worn = slot }, pending.at)
		pending.left = Finite(left) and left or nil
	end
	S.pending = pending
	S.version = S.version + 1
	local ok
	if R.Worn(SLOTS[OTHER[n]]) == id or R.Mixed(id) then
		ok = R.PickUp(copy, slot)
	else
		ok = pcall(C_Item.EquipItemByName, copy.link or ("item:%d"):format(id), slot)
	end
	S.bags = nil
	if not ok then
		Q.Failed(pending)
		return
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(wear and not copy.bound and TIME.ASK or TIME.CONFIRM, function()
			if S.pending == pending then
				Q.Run(Q.Failed, pending)
			end
		end)
	end
end

function R.Named(id, link)
	if link then
		return link
	end
	local name = Ask(Fn(C_Item, "GetItemNameByID"), id)
	if type(name) == "string" and name ~= "" then
		return name
	end
	R.Load(id)
	return ("item %d"):format(id)
end

function R.Sound()
	local word = ns.Get("trinkets.sound")
	local kit = word ~= "none" and type(ns.SOUNDS) == "table" and ns.SOUNDS[KITS[word] or 0] or nil
	if not kit then
		return
	end
	local ok, played = Call(PlaySound, kit[1])
	if not ok or played == false then
		ns.Note(KEY, T.NO_SOUND)
	end
end

function Q.Confirmed(pending)
	S.pending = nil
	S.fails[pending.item], S.nextTry[pending.item] = nil, nil
	if pending.wear then
		R.Hold(pending.name, pending.item)
	else
		if pending.why == "dismounted" then
			D.SetBack(pending.name, nil)
		end
		if ns.Get("trinkets.say") == true then
			local why = T.EMPTY_SLOT
			if pending.why == "riding" then
				why = T.RIDE
			elseif pending.why == "dismounted" then
				why = T.OFF_MOUNT
			elseif pending.from and pending.why == "cooling" then
				why = pending.left and T.COOLING:format(Q.Clock(pending.left)) or R.Lower(PLAIN.wait)
			elseif pending.from then
				why = T.HIGHER
			end
			print(T.SWAP:format(WORD[pending.name], R.Named(pending.item, R.WornLink(SLOTS[pending.name])),
				pending.from and R.Named(pending.from, pending.fromLink) or T.NOTHING, why))
		end
		R.Sound()
	end
	S.version = S.version + 1
	Q.Soon()
end

function Q.Failed(pending)
	if S.pending == pending then
		S.pending = nil
	end
	local id = pending.item
	S.late = pending
	if pending.wear then
		if not pending.asked then
			print(T.WEAR_REFUSED:format(R.Named(id)))
		end
	else
		local fails = (S.fails[id] or 0) + 1
		S.fails[id] = fails
		if BACKOFF[fails] then
			S.nextTry[id] = Now() + BACKOFF[fails]
		else
			S.refused[id] = true
			local name = R.Named(id)
			if not S.said[id] and ns.Get("trinkets.say") == true then
				S.said[id] = true
				print(T.REFUSED:format(name))
			end
			S.noted[id] = T.REFUSED_NOTE:format(name)
			ns.Note(KEY, S.noted[id])
		end
	end
	S.version = S.version + 1
	Q.Soon()
end

function Q.Equipped(slot)
	local n = slot == SLOTS.top and "top" or slot == SLOTS.bottom and "bottom" or nil
	if not n then
		return
	end
	local now = Now()
	S.equippedAt[n] = now
	S.bags = nil
	local worn, pending, late = R.Worn(slot), S.pending, S.late
	if pending and pending.name == n then
		if worn == pending.item then
			Q.Confirmed(pending)
			return
		end
	elseif not pending and late and late.name == n and late.item == worn and now - late.at < TIME.LATE then
		S.late = nil
		S.refused[late.item] = nil
		Q.Confirmed(late)
		return
	elseif not pending and now >= S.quietUntil and Q.Running() and Q.Auto(n) and not Q.Paused() and #Q.List(n) > 0 then
		R.Hold(n, worn or 0)
	end
	if not pending and now >= S.quietUntil and D.RidingSlot() == n then
		D.SetBack(n, nil)
		S.ridingOff[n] = D.Mounted() or nil
	end
	S.version = S.version + 1
	Q.Soon()
end

function Q.Fight()
	S.token = S.token + 1
	for _, n in ipairs(ORDER) do
		if not D.Static(n) then
			S.why[n] = "fight"
		end
	end
	S.version = S.version + 1
end

function Q.Peace()
	S.nextTry = {}
	S.fightTries = 0
	Q.Soon(true)
end

function Q.Entered()
	S.quietUntil = Now() + TIME.QUIET
	S.bags = nil
	Q.Soon()
end

function Q.BagsChanged()
	S.bags = nil
	Q.Soon()
end

function R.Listed(id)
	for _, n in ipairs(ORDER) do
		if Q.Find(Q.List(n), id) then
			return true
		end
	end
	return false
end

function Q.Loaded(id)
	if not Whole(id) or not (S.loading[id] or R.Listed(id)) then
		return
	end
	S.uses[id], S.tipLen[id], S.levels[id], S.loading[id] = nil, nil, nil, nil
	if S.kinds[id] == nil then
		S.bags = nil
	end
	S.version = S.version + 1
	Q.Soon()
end

function Q.Active()
	return Q.Running() and not Q.Paused() and (Q.Auto("top") or Q.Auto("bottom") or D.RidingSlot() ~= nil)
end

function Q.Soon(force)
	if not Q.Active() then
		D.Idle()
		return
	end
	if S.soon or (D.Lockdown() and not force) then
		return
	end
	if not (C_Timer and C_Timer.After) then
		Q.Run(D.Look)
		return
	end
	S.soon = true
	C_Timer.After(TIME.SETTLE, function()
		S.soon = false
		Q.Run(D.Look)
	end)
end

function Q.Version()
	return S.version
end

function Q.Paused()
	local store = Q.Store(false)
	return store ~= nil and store.paused == true
end

function Q.SetPaused(on)
	on = on == true
	if on == Q.Paused() then
		return
	end
	local store = Q.Store(true)
	store.paused = on or nil
	if not on then
		R.Unhold("top")
		R.Unhold("bottom")
	end
	R.Edited()
end

function Q.Auto(n)
	return ROW[n] ~= nil and ns.Get(ROW[n]) == true
end

function ns.TrinketAutoGet(def)
	local n = type(def) == "table" and AUTO[def.key] or nil
	if not n or type(ns.Character()) ~= "table" then
		return nil
	end
	local store = Q.Store(false)
	local auto = store and store.auto
	return type(auto) == "table" and auto[n] == true
end

function ns.TrinketAutoSet(def, value)
	local n = type(def) == "table" and AUTO[def.key] or nil
	local store = n and Q.Store(true)
	if not store then
		return
	end
	if type(store.auto) ~= "table" then
		store.auto = {}
	end
	store.auto[n] = value == true or nil
	S.version = S.version + 1
end

function Q.SetAuto(n, on)
	if not ROW[n] then
		return
	end
	if on then
		R.Unhold(n)
	end
	ns.Set(ROW[n], on == true)
	R.Edited()
end

function Q.Add(n, item, atTop)
	local id = R.ItemID(item)
	if not SLOTS[n] or not id then
		return false, T.NO_ITEM
	end
	if R.Trinket(id) ~= true then
		return false, T.ONLY
	end
	local index = Q.Find(Q.List(n), id)
	if index then
		if atTop and index > 1 then
			local list = Q.List(n, true)
			table.insert(list, 1, table.remove(list, index))
			R.Edited()
		end
		return true
	end
	if #Q.List(n) >= MOST then
		return false, T.FULL
	end
	local list = Q.List(n, true)
	table.insert(list, atTop and 1 or #list + 1, { item = id, delay = 0 })
	R.Edited()
	return true
end

function Q.Remove(n, index)
	local list = Q.List(n)
	if list[index] then
		table.remove(Q.List(n, true), index)
		R.Edited()
	end
end

function Q.Move(n, index, by)
	local list = Q.List(n)
	if not list[index] or not Finite(by) and by ~= math.huge and by ~= -math.huge then
		return
	end
	local to = math.max(1, math.min(#list, by == math.huge and #list or by == -math.huge and 1 or index + by))
	if to ~= index then
		list = Q.List(n, true)
		table.insert(list, to, table.remove(list, index))
		R.Edited()
	end
end

function Q.SetDelay(n, index, seconds)
	local entry = Q.List(n)[index]
	if entry and Finite(seconds) then
		local delay = math.max(0, math.min(LONGEST, math.floor(seconds)))
		if delay ~= entry.delay then
			entry.delay = delay
			R.Edited()
		end
	end
end

function Q.ToggleStop(n, index)
	local entry = Q.List(n)[index]
	if entry then
		entry.stop = not entry.stop or nil
		R.Edited()
	end
end

function Q.Copy(n)
	if not SLOTS[n] then
		return 0
	end
	local added = 0
	for _, entry in ipairs(Q.List(OTHER[n])) do
		if #Q.List(n) >= MOST then
			break
		end
		if not Q.Find(Q.List(n), entry.item) then
			local list = Q.List(n, true)
			list[#list + 1] = { item = entry.item, delay = Finite(entry.delay) and entry.delay or 0, stop = entry.stop == true or nil }
			added = added + 1
		end
	end
	if added > 0 then
		R.Edited()
	end
	return added
end

function Q.Clear(n)
	local count = #Q.List(n)
	if SLOTS[n] and count > 0 then
		local list = Q.List(n, true)
		for index = #list, 1, -1 do
			list[index] = nil
		end
		R.Edited()
	end
	return count
end

function Q.Now(n)
	for _, name in ipairs(n and { n } or ORDER) do
		if SLOTS[name] then
			R.Unhold(name)
			S.once[name] = true
			local only = {}
			for _, entry in ipairs(Q.List(name)) do
				only[entry.item] = true
				S.fails[entry.item], S.nextTry[entry.item] = nil, nil
			end
			R.ClearRefused(only)
		end
	end
	R.Edited()
end

function Q.Wear(n, id)
	local slot = SLOTS[n]
	if not slot or not Whole(id) then
		return false
	end
	if not Q.Running() then
		print(T.WEAR_OFF)
		return false
	end
	if D.Fighting() then
		print(T.WEAR_FIGHT)
		return false
	end
	if R.Worn(slot) == id then
		return true
	end
	local copy, carried, bound = nil, false, false
	for _, candidate in ipairs(R.Copies(id)) do
		carried, bound = true, bound or candidate.bound
		if not candidate.locked and (not copy or (candidate.bound and not copy.bound)) then
			copy = candidate
		end
	end
	if copy and bound and not copy.bound then
		copy = nil
	end
	local name = R.Named(id, copy and copy.link)
	if not carried then
		print(T.WEAR_GONE:format(name))
		return false
	end
	local blocked = D.Blocked(Now()) or (R.Locked(slot) and "locked") or (not copy and "busy") or nil
	if blocked then
		print(T.WEAR_WAIT:format(name, R.Lower(WHY[blocked][2])))
		return false
	end
	Q.Swap(n, id, copy, "wear", true)
	return true
end

function Q.State(n)
	local slot = SLOTS[n]
	local worn = slot and R.Worn(slot) or nil
	local why = D.Static(n)
	if (why == "auto" or why == "empty") and S.rode[n] and D.RidingSlot() == n then
		why = nil
	end
	if not why then
		why = S.why[n] or "keep"
		if D.Fighting() and why ~= "riding" then
			why = "fight"
		end
	end
	local refused = false
	for _, entry in ipairs(Q.List(n)) do
		refused = refused or S.refused[entry.item] == true
	end
	return { worn = worn, wornLink = slot and R.WornLink(slot) or nil, why = why, untilAt = S.untilAt[n], next = S.next[n],
		nextAt = S.nextAt[n], held = Q.Held(n), refused = refused }
end

function Q.Clock(seconds)
	seconds = Finite(seconds) and math.max(0, math.ceil(seconds)) or 0
	if seconds >= 3600 then
		return ("%dh"):format(math.ceil(seconds / 3600))
	elseif seconds >= 600 then
		return ("%dm"):format(math.ceil(seconds / 60))
	end
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function Q.Tone(n, state)
	state = state or Q.State(n)
	if state.why == "fight" or (D.Fighting() and not D.Static(n) and state.why ~= "riding") then
		return "wait"
	end
	if state.refused and RESTING[state.why] then
		return "halt"
	end
	return (WHY[state.why] or WHY.keep)[1]
end

function Q.Sentence(n, state)
	state = state or Q.State(n)
	local why = state.why
	if why == "pending" and S.pending and S.pending.name ~= n then
		return "Waits for the other slot"
	elseif why == "delay" and state.untilAt then
		return WHY.delay[2]:format(math.max(1, math.ceil(state.untilAt - Now())))
	end
	if state.refused and RESTING[why] then
		return WHY.refused[2]
	end
	if (why == "keep" or why == "wait") and state.worn then
		local left = R.Left(state.worn, { worn = SLOTS[n] }, Now())
		if Finite(left) and left > 0 then
			return WHY.wait[2]:format(Q.Clock(left))
		end
		return WHY.keep[2]
	end
	return (PLAIN[why] or (WHY[why] or WHY.keep)[2])
end

function Q.Info(id)
	local info = { id = id, carried = 0, bound = false }
	for _, n in ipairs(ORDER) do
		if R.Worn(SLOTS[n]) == id then
			info.wornIn = info.wornIn or n
		end
	end
	for _, copy in ipairs(R.Copies(id)) do
		info.carried = info.carried + 1
		info.bound = info.bound or copy.bound
		if not info.copy or (copy.bound and not info.copy.bound) then
			info.copy = copy
		end
	end
	local where = info.wornIn and { worn = SLOTS[info.wornIn] } or info.copy or {}
	info.left = R.Left(id, where, Now())
	info.level = R.Level(id)
	local mine = Ask(UnitLevel, "player")
	info.tooHigh = Finite(info.level) and Finite(mine) and info.level > mine
	info.link = info.wornIn and R.WornLink(SLOTS[info.wornIn]) or info.copy and info.copy.link or nil
	local ok, name, link, quality = Call(Fn(C_Item, "GetItemInfo"), id)
	if ok then
		info.name = not IsSecret(name) and type(name) == "string" and name ~= "" and name or nil
		info.link = info.link or (not IsSecret(link) and type(link) == "string" and link or nil)
		info.quality = Finite(quality) and quality or nil
	end
	info.name = info.name or Ask(Fn(C_Item, "GetItemNameByID"), id)
	if type(info.name) ~= "string" or info.name == "" then
		R.Load(id)
		info.name = ("Item %d"):format(id)
	end
	local okIcon, _, _, _, _, icon = Call(Fn(C_Item, "GetItemInfoInstant"), id)
	info.icon = okIcon and not IsSecret(icon) and icon or 134400
	return info
end

function Q.Candidates()
	local list, seen = {}, {}
	for _, n in ipairs(ORDER) do
		local id = R.Worn(SLOTS[n])
		if id and not seen[id] then
			seen[id] = true
			list[#list + 1] = { id = id, worn = n }
		end
	end
	local bags, order = R.Scan()
	for _, id in ipairs(order) do
		if not seen[id] then
			seen[id] = true
			list[#list + 1] = { id = id, copy = bags[id][1] }
		end
	end
	for _, row in ipairs(list) do
		local name = Ask(Fn(C_Item, "GetItemNameByID"), row.id)
		row.name = type(name) == "string" and name or ("~%09d"):format(row.id)
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

function Q.Word(n)
	return WORD[n]
end

function Q.Fighting()
	return D.Fighting()
end

function Q.Threshold()
	return D.Threshold()
end

function R.Tell()
	for _, name in ipairs({ "TrinketWindowSync", "TrinketButtonsChanged" }) do
		local ok, err = Call(Fn(ns, name))
		if not ok and err ~= nil then
			Q.Report(name, err)
		end
	end
end

function R.Ordinal(number)
	local tens, ones = number % 100, number % 10
	local suffix = "th"
	if tens < 11 or tens > 13 then
		suffix = ones == 1 and "st" or ones == 2 and "nd" or ones == 3 and "rd" or "th"
	end
	return ("%d%s"):format(number, suffix)
end

function R.QueueLines(id)
	local lines = {}
	for _, n in ipairs(ORDER) do
		local list = Q.List(n)
		local index, entry = Q.Find(list, id)
		if index then
			local text = T.TIP_LINE:format(R.Ordinal(index), #list, WORD[n]:lower())
			if entry.stop then
				text = text .. T.TIP_STOP
			elseif Finite(entry.delay) and entry.delay > 0 then
				text = text .. T.TIP_DELAY:format(entry.delay)
			end
			if not Q.Auto(n) then
				text = text .. T.TIP_AUTO_OFF
			end
			lines[#lines + 1] = text
		end
	end
	return lines
end

function R.TipFilled(tooltip, data)
	if not (rawequal(tooltip, GameTooltip) or rawequal(tooltip, ItemRefTooltip)) or ns.Forbidden(tooltip)
		or type(data) ~= "table" or IsSecret(data) or not Q.Running() or ns.Get("trinkets.tipLine") ~= true then
		return
	end
	if type(ns.TrinketWindowOwns) == "function" then
		local got, owner = Call(tooltip.GetOwner, tooltip)
		if got and ns.TrinketWindowOwns(owner) then
			return
		end
	end
	local id = data.id
	if not Whole(id) then
		return
	end
	local ok, shown = Call(tooltip.NumLines, tooltip)
	if not ok or not Finite(shown) then
		return
	end
	local mark = S.tipMarks[tooltip]
	if mark and mark.data == data and shown >= mark.lines then
		return
	end
	local lines = R.QueueLines(id)
	if #lines == 0 then
		return
	end
	local colour = T.TIP_COLOUR
	for _, text in ipairs(lines) do
		if not Call(tooltip.AddLine, tooltip, text, colour[1], colour[2], colour[3]) then
			return
		end
		shown = shown + 1
	end
	S.tipMarks[tooltip] = { data = data, lines = shown }
end

function R.HookTips()
	if S.tipHooked then
		return
	end
	local processor = TooltipDataProcessor
	local kinds = type(Enum) == "table" and not IsSecret(Enum) and Enum.TooltipDataType or nil
	local item = type(kinds) == "table" and not IsSecret(kinds) and kinds.Item or nil
	if not Fn(processor, "AddTooltipPostCall") or not Finite(item) then
		return
	end
	S.tipHooked = true
	Call(processor.AddTooltipPostCall, item, function(tooltip, data)
		if not IsSecret(tooltip) then
			Q.Run(R.TipFilled, tooltip, data)
		end
	end)
end

function Q.Started()
	R.HookTips()
	local now = Now()
	S.quietUntil = now + TIME.QUIET
	for _, n in ipairs(ORDER) do
		S.autoWas[n] = Q.Auto(n)
		if Q.Held(n) ~= nil then
			S.heldAt[n] = now
		end
	end
	Q.Soon()
	R.Tell()
end

function Q.Refreshed()
	if not Q.Running() then
		Q.Halt()
		D.Idle()
	else
		for _, n in ipairs(ORDER) do
			local on = Q.Auto(n)
			if on and S.autoWas[n] == false then
				R.Unhold(n)
			end
			S.autoWas[n] = on
		end
		Q.Soon()
	end
	R.Tell()
end

function R.Lower(text)
	return (text:gsub("^%u", string.lower))
end

function R.EntryLine(index, entry)
	local extra = ""
	if entry.delay > 0 then
		extra = extra .. (", delay %d s"):format(entry.delay)
	end
	if entry.stop then
		extra = extra .. ", Stop"
	end
	return T.LIST_LINE:format(index, R.Named(entry.item), extra)
end

function R.SlashList(word, n)
	if not SLOTS[n] then
		print(T.WHICH:format(word, word))
		return
	end
	if word == "clear" then
		local count = Q.Clear(n)
		print(count > 0 and T.CLEARED:format(WORD[n], count) or T.CLEAR_NONE:format(WORD[n]))
		return
	end
	local from = OTHER[n]
	if #Q.List(from) == 0 then
		print(T.COPY_EMPTY:format(WORD[from]))
		return
	end
	local added = Q.Copy(n)
	print(added > 0 and T.COPIED:format(WORD[n], added, WORD[from]) or T.COPY_NONE:format(WORD[from], WORD[n]))
end

function Q.Slash(rest)
	local word = type(rest) == "string" and rest:lower():match("^%s*(%S*)") or ""
	if word == "" or word == "top" or word == "bottom" then
		local fn = Fn(ns, word == "" and "TrinketWindowToggle" or "TrinketWindowOpen")
		if fn then
			fn(word ~= "" and word or nil)
		end
	elseif word == "pause" then
		Q.SetPaused(not Q.Paused())
		print(Q.Paused() and T.PAUSED or T.RESUMED)
	elseif word == "now" then
		if not Q.Running() then
			print(T.OFF)
			return
		end
		Q.Now(nil)
		print(T.NOW)
	elseif word == "copy" or word == "clear" then
		R.SlashList(word, rest:lower():match("^%s*%S+%s+(%S+)"))
	elseif word == "list" then
		for _, n in ipairs(ORDER) do
			print(T.LIST:format(WORD[n], Q.Auto(n) and "" or T.LIST_OFF))
			local list = Q.List(n)
			if #list == 0 then
				print(T.LIST_EMPTY)
			end
			for index, entry in ipairs(list) do
				print(R.EntryLine(index, entry))
			end
		end
	else
		print(T.HELP)
	end
end

function Q.StatusLines()
	if not ns.Enabled(KEY) then
		return {}
	end
	local lines = {}
	if Q.Paused() then
		lines[#lines + 1] = T.STATUS_PAUSED
	end
	for _, n in ipairs(ORDER) do
		if not Q.Auto(n) then
			lines[#lines + 1] = T.STATUS_OFF:format(n)
		else
			local state = Q.State(n)
			local nextText = ""
			if state.next and state.nextAt then
				nextText = T.STATUS_NEXT:format(R.Named(state.next), Q.Clock(state.nextAt - Now()))
			end
			lines[#lines + 1] = T.STATUS_SLOT:format(n, state.worn and R.Named(state.worn, state.wornLink) or T.NOTHING,
				R.Lower(Q.Sentence(n, state)), nextText)
		end
	end
	return lines
end

ns.Register(KEY, {
	label = "Trinket queue",
	counted = false,
	Start = function()
		Q.Started()
	end,
	Refresh = function()
		Q.Refreshed()
	end,
	events = {
		PLAYER_ENTERING_WORLD = function()
			Q.Run(Q.Entered)
		end,
		PLAYER_REGEN_DISABLED = function()
			Q.Run(Q.Fight)
		end,
		PLAYER_REGEN_ENABLED = function()
			Q.Run(Q.Peace)
		end,
		PLAYER_EQUIPMENT_CHANGED = function(slot)
			Q.Run(Q.Equipped, slot)
		end,
		BAG_UPDATE_DELAYED = function()
			Q.Run(Q.BagsChanged)
		end,
		BAG_UPDATE_COOLDOWN = function()
			Q.Run(Q.Soon)
		end,
		ITEM_LOCK_CHANGED = function()
			Q.Run(Q.BagsChanged)
		end,
		PLAYER_ALIVE = function()
			Q.Run(Q.Soon)
		end,
		PLAYER_UNGHOST = function()
			Q.Run(Q.Soon)
		end,
		PLAYER_MOUNT_DISPLAY_CHANGED = function()
			Q.Run(Q.Soon)
		end,
		GET_ITEM_INFO_RECEIVED = function(id)
			Q.Run(Q.Loaded, id)
		end,
		ITEM_DATA_LOAD_RESULT = function(id)
			Q.Run(Q.Loaded, id)
		end,
	},
	filters = {
		PLAYER_EQUIPMENT_CHANGED = function(slot)
			return not IsSecret(slot) and (slot == SLOTS.top or slot == SLOTS.bottom)
		end,
	},
	slash = { queue = function(rest)
		Q.Slash(rest)
	end, trinkets = function(rest)
		Q.Slash(rest)
	end },
	help = { T.HELP },
	Status = function()
		return Q.StatusLines()
	end,
})
