local _, ns = ...

-- Trinket queue (0.5.36, the owner: "a slot-queuing feature like trinketmenu addon would be helpful"): a module of its own, "trinkets", on by
-- default, with the Auto queue of each slot off, so nothing is put on until the player ticks one. This file is the engine: the lists, the
-- decision, the swap, the slash words and the /flatui status lines; TrinketQueueWindow.lua is its window and TrinketQueueButtons.lua the two
-- squares beside the trinket slots of the Character window. The idea follows the trinket queue of TrinketMenu by Gello, as the owner described
-- it; none of its code or data is used.
-- The store: FlatUICharDB.trinketQueue (ns.Character, Core.lua:2992-2994), for this character alone, made at the first edit (as BagsPins.lua's
-- Store): top and bottom, ordered lists, best first, of at most MOST entries { item = item ID, delay = whole seconds 0 to 120, stop = true or nil },
-- an item at most once a list (it may be in both); paused, Pause all (true or nil, per character, so a profile switch never unpauses it); auto,
-- { top, bottom }, the Auto queue of each slot (true or nil), which the rows trinkets.autoTop and trinkets.autoBottom read and write through
-- their get and set (ns.TrinketAutoGet and ns.TrinketAutoSet; ns.Get and ns.Set route such a row, Core.lua:1080-1112, 2774-2793, and no
-- profile holds it), so a profile switch, by hand or by the Profiles page's automatic switch, never turns it on or off and an alt on the same
-- profile keeps its own; held, { top, bottom }, the item the player put on by hand in each slot, or 0 for a slot the player emptied. The first
-- read of a session cleans it, as Cooldowns.lua's Own.List does (Cooldowns.lua:612-640), and writes it back only when something changed.
-- Q.Copy puts the other slot's list at the end of a list, in its order with each Delay and Stop, passing over a trinket it holds already, and
-- Q.Clear empties a list (0.5.37): /flatui queue copy top or bottom and clear top or bottom, and the window's Copy button on an empty list.
-- When it looks: never on a ticker. An event or an edit asks for a look (Q.Soon), which comes SETTLE seconds later, once however many asked; each
-- look arms at most one timer (C_Timer.After, WL/apis.yaml:28390) for the first moment a decision can change, and a token makes an older timer
-- do nothing. Nothing runs while both Auto queue rows are off, Pause all is on, or the module or its part "swaps" is off. The module's events
-- (ns.Register, Core.lua:2497-2519): PLAYER_ENTERING_WORLD (a quiet QUIET seconds after a loading screen, when the game sends its own equipment
-- changes), PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED (UnitDocumentation.lua:3893), PLAYER_EQUIPMENT_CHANGED for slots 13 and 14
-- (PaperDollInfoDocumentation.lua:383-394), BAG_UPDATE_DELAYED, BAG_UPDATE_COOLDOWN and ITEM_LOCK_CHANGED (ContainerDocumentation.lua:671, 677,
-- 717-727), PLAYER_ALIVE and PLAYER_UNGHOST, GET_ITEM_INFO_RECEIVED and ITEM_DATA_LOAD_RESULT (as BagsData.lua:56 hears them). The player's
-- UNIT_SPELLCAST_SUCCEEDED (UnitDocumentation.lua:4845-4856) is heard on a frame of its own (RegisterUnitEvent "player", as LavaWalk hears
-- UNIT_COMBAT), only while a list has a delay or the cooldowns are read from the tooltips.
-- The gates, every one before any swap, each with a reason the window, the buttons and /flatui status say: the module and the part on
-- (ns.ModuleOn, ns.PartStopped); Pause all off; the slot's Auto queue on and its list not empty; no swap waiting for its answer; the client has
-- C_Item.EquipItemByName (WL/apis.yaml:16288-16295; there is no global EquipItemByName); no fight, InCombatLockdown (:39650) and
-- UnitAffectingCombat("player") (:42083) both plainly false, since the game changes no slot but the weapons in a fight
-- (INVSLOTS_EQUIPABLE_IN_COMBAT, Blizzard_FrameXMLBase/Constants.lua:158-162; Camelot/PaperDollFrame.lua:2557-2566); not dead or a ghost
-- (UnitIsDeadOrGhost, :42886); no cast or channel (UnitCastingInfo, UnitChannelInfo, :42211, :42249, secret under cast restrictions,
-- UnitDocumentation.lua:828-831, 870-873; the game's equipment manager waits for a cast too, Mainline/EquipmentManager.lua:260-263); nothing on
-- the cursor (CursorHasItem, GetCursorInfo, :35286, :36258), no spell waiting for its target (SpellIsTargeting, :41587), and no Sell junk
-- (ns.ErrandsSelling), Deposit or Take out (ns.Bags.Bank.Busy), clean up (ns.Bags.Sorting), trade or split box (TradeFrame, StackSplitFrame,
-- IsShown) under way, the list BagsPins.lua waits on (BagsPins.lua:834-866), each looked up when called; the worn slot not locked
-- (IsInventoryItemLocked, :39870). A withheld answer counts as the gate being shut.
-- The decision for one slot (n, slot s, its list L): the worn item w (GetInventoryItemID, Cooldowns.lua:1973 reads it the same way) stays while
-- the player put it on by hand (held), while it is in L with Stop, while its Delay has not run since its use, and while its effect runs (the game
-- holds its cooldown); else the first entry above w in L (w out of L, or an empty slot, counts below the whole list) that is usable and ready is
-- put on ("ready again"), and while w cools (a plain time left above Ready with this much left), the first one below it ("on cooldown"). A w
-- whose cooldown cannot be read is not cooling: it stays unless one above it is ready, since a trinket taken off on an unknown cooldown could
-- never come back. A slot the player emptied stays empty (held). Usable: a bag copy (bags 0 to NUM_BAG_SLOTS,
-- C_Container.GetContainerNumSlots and GetContainerItemInfo, ContainerDocumentation.lua:192, 313, 766-781, as Cooldowns.lua's Own.Bags walks
-- them) that is not locked and is bound (an unbound one would bring up the game's EQUIP_BIND question, PaperDollInfoDocumentation.lua:334-343,
-- so the queue leaves that to the player), not refused or in back-off, whose required level (C_Item.GetItemInfo's fifth answer, :16525) the
-- player has, and when the item is worn in the other slot, a second copy of an item the game plainly says is not unique
-- (C_Item.GetItemUniquenessByID, ItemDocumentation.lua:1052-1072). Ready: no use (C_Item.GetItemSpell, ItemDocumentation.lua:966-985, as
-- Cooldowns.lua's Own.HasUse asks), or at most Ready with this much left of its cooldown, or, worn, the 30 second cooldown the game starts on an
-- item with a use as it is put on (the churn guard, even at 0).
-- Cooldowns, every answer through ns.IsSecret and ns.Finite: C_Item.GetItemCooldown (ItemDocumentation.lua:434-449), else
-- GetInventoryItemCooldown("player", slot) for the worn copy and C_Container.GetContainerItemCooldown (ContainerDocumentation.lua:122-138) for a
-- bag copy; where neither is plain, the item's tooltip (C_TooltipInfo.GetInventoryItem and GetBagItem, TooltipInfoDocumentation.lua:389, 137),
-- out of combat only: its line ITEM_COOLDOWN_TIME ("Cooldown remaining: %s"), refined by the use heard and the length of the Use: line of
-- C_TooltipInfo.GetItemByID (:439; line type 44, as CharacterThorns.lua reads it). A line it cannot read is unknown, and unknown is never ready
-- and never cooling.
-- The swap (Q.Swap): C_Item.EquipItemByName(link, slot) (ItemDocumentation.lua:251-260, not protected), as the game's /equipslot
-- (SlashCommands.lua:428-444); for a second copy of an item worn in the other slot, and while the bags hold a bound and an unbound copy of the
-- item (R.Mixed: one link names both, so the game could take the unbound one), C_Container.PickupContainerItem of the chosen copy then
-- PickupInventoryItem, as the game's equipment manager does (Mainline/EquipmentManager.lua:95-116), with anything left on the cursor given back
-- (ClearCursor). Every call is in pcall. The answer is the slot's PLAYER_EQUIPMENT_CHANGED with the item in it within CONFIRM seconds, else it
-- failed: back-off of 5, 20 and 60 seconds (the end of a fight forgets the back-offs), then refused until Queue now, so a trinket the game will
-- never take (a requirement the gates do not read) is not tried again at each change of the bags or each fight. A change of a slot that no swap
-- of the queue made is a change by hand (the player, an equipment set, another addon): the slot is held until the item is used, and a slot
-- emptied by hand stays empty until a trinket goes in by hand; either hold also ends with Queue now, the slot's Auto queue turned on or Pause all
-- turned off.
-- Each swap is said in chat (Say each swap in chat) and may play a sound of ns.SOUNDS (IconRow.lua:17-25, PlaySound in pcall; not ns.PlayKit,
-- whose note speaks of a flash); picking Sound on a swap in the options window plays it once, as every sound row of Panel.lua's AddChoice does
-- (the row's own handler of 0.5.37 went in 0.5.39: it played it again and on an undo). Everything runs as the part "swaps" of the module
-- (ns.EachPart, each run with a count of its own as its first argument, as GearWindow.lua's Run), so three faults stop the swaps alone with a line
-- for /flatui status; the first fault of each kind also goes to the game's error handler. It never writes a field of a game frame, calls no
-- mixin, adds no hook, makes no secure frame and never swaps in a fight; its frames are its own.

local KEY, PART = "trinkets", "swaps"
-- The slots (INVSLOT_TRINKET1 and 2, Blizzard_FrameXMLBase/Constants.lua:148-149), their order, the other slot, the Auto queue row, the slot of
-- each row's key, and the word of each.
local SLOTS = { top = 13, bottom = 14 }
local ORDER = { "top", "bottom" }
local OTHER = { top = "bottom", bottom = "top" }
local ROW = { top = "trinkets.autoTop", bottom = "trinkets.autoBottom" }
local AUTO = { autoTop = "top", autoBottom = "bottom" }
local WORD = { top = "Top", bottom = "Bottom" }
-- Entries a list holds at most, the longest delay, and the most a cooldown may have left to count as ready (Ready with this much left).
local MOST, LONGEST, READY_MOST = 24, 120, 60
-- Seconds: the wait before a look (a slider step settles first), the wait for the game's answer to a swap and to its question of an unbound
-- trinket the player clicked, how long an answer that came later still counts, between two tries while a cast, a fight
-- the game still counts or the cursor holds the swap back, the quiet after a loading screen, the equip lockout with slack, the global cooldown
-- (Pulse.lua's GCD), the farthest a timer is armed, how often the end of a fight is tried again, and the least wait of a timer.
local TIME = { SETTLE = 0.2, CONFIRM = 2, ASK = 60, LATE = 15, RETRY = 0.5, BUSY = 1, QUIET = 3, LOCKOUT = 30.5, GCD = 2, FAR = 3600, TRIES = 10, NEAR = 0.05 }
local BACKOFF = { 5, 20, 60 }
local MAX_ID = 2147483647
-- The places of the Sound on a swap choices in ns.SOUNDS (IconRow.lua), as Pulse.lua has them.
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
-- The first letter of a time word of a tooltip, in seconds.
local UNITS = { s = 1, m = 60, h = 3600, d = 86400 }
local TRINKET, ON_USE, LINES = "INVTYPE_TRINKET", 44, 40
local T = {
	NO_CALL = "Trinket queue: this client cannot put on items (no C_Item.EquipItemByName), so nothing is swapped.",
	FALLBACK = "Trinket queue: the game did not give trinket cooldowns, so the queue reads them from the tooltips.",
	NO_SOUND = "Trinket queue: the game played no swap sound.",
	REFUSED_NOTE = "Trinket queue: the game refused %s.",
	REFUSED = "Flat UI: the game would not put on %s; the trinket queue leaves it until you press Queue now.",
	WEAR_REFUSED = "Flat UI: the game would not put on %s.",
	SWAP = "Flat UI: %s trinket: %s in place of %s (%s).",
	NOTHING = "nothing", COOLING = "on cooldown, %s", HIGHER = "ready again", EMPTY_SLOT = "the slot was empty",
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
}
-- What each reason of a slot says, and its tone for the dot of the slot's button and the window: off (grey), on (the Highlight colour), wait
-- (amber) and halt (red).
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
}

-- The words of the reasons whose sentence takes a number, without it.
local PLAIN = { delay = "Kept on for its delay", wait = "On cooldown" }

-- The reasons of a slot at rest, which a trinket the game refused turns red ("The game refused it").
local RESTING = { keep = true, wait = true, unknown = true, none = true, next = true }

-- The contract (Q, also ns.TrinketQueue), the state of the session (S, one table to keep the upvalues few), the reads (R) and the decision (D).
local Q, R, D = {}, {}, {}
local S = { pending = nil, fails = {}, nextTry = {}, refused = {}, said = {}, noted = {}, equippedAt = {}, heldAt = {}, heard = {}, uses = {},
	tipLen = {}, kinds = {}, levels = {}, loading = {}, autoWas = {}, once = {}, why = {}, untilAt = {}, nextAt = {}, next = {}, token = 0,
	soon = false, quietUntil = 0, version = 0, runs = 0, faults = {}, bags = nil, order = nil, fightTries = 0, normalised = false,
	fallback = false, listening = false, ear = nil, pattern = nil, late = nil }
ns.TrinketQueue = Q

local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

-- A function of a table, or nil.
local function Fn(source, name)
	if type(source) ~= "table" or IsSecret(source) then
		return nil
	end
	local fn = source[name]
	return type(fn) == "function" and fn or nil
end

-- pcall of a function that may be missing: false when it is.
local function Call(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, ...)
end

-- The first answer of a call, or nil when it is missing, raises or is withheld.
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

-- The part ---------------------------------------------------------------------------------------------------------------------------------------

-- A fault goes to the game's error handler once for each thing that failed, as GearWindow.lua's Report.
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

-- Runs fn as the part "swaps" with a count of its own first, so every fault counts (Core.lua:2430-2463). A part that stopped drops its timer and
-- any swap that waits.
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

-- True while the module runs and its swaps are not stopped.
function Q.Running()
	return type(ns.modules) == "table" and ns.modules[KEY] ~= nil and ns.ModuleOn(KEY) and not ns.PartStopped(KEY, PART)
end

-- The timer and the swap that waits are let go: the part stopped or the module went off.
function Q.Halt()
	S.token = S.token + 1
	S.pending = nil
	R.Ear(false)
end

-- The store ----------------------------------------------------------------------------------------------------------------------------------------

-- One list as it should be: entries with a plain whole item ID, none twice, at most MOST, each delay whole from 0 to LONGEST, stop true or nil.
-- The list itself when nothing changed.
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

-- The first read of a session cleans the store (header).
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

-- FlatUICharDB.trinketQueue, made with make; nil before the saved variables load, or when there is none and make is not set.
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

-- A slot's list, highest first. Without make, a fresh empty table when there is none, which the caller must not keep.
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

-- The place and the entry of an item in a list.
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

-- The item the player put on by hand in a slot, 0 for a slot the player emptied, or nil; and taking it away.
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

-- An edit: the version moves on and the queue looks again.
function R.Edited()
	S.version = S.version + 1
	Q.Soon()
end

-- Reads -------------------------------------------------------------------------------------------------------------------------------------------

-- The item worn in a slot, or nil for an empty one.
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

-- An item ID from an ID, a link or an item string, or nil.
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

-- True for a trinket (C_Item.GetItemInfoInstant's fourth answer, WL/apis.yaml:16569, which never waits), false for any other item, nil unknown.
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

-- The bags: per trinket, its copies { bag, slot, link, locked, bound }, and the trinkets in the order of the bags. Kept until the bags change.
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

-- The spell of an item's use, false for an item without one, nil while the client has not loaded it (as Cooldowns.lua's Own.HasUse).
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

-- The level an item needs (C_Item.GetItemInfo's fifth answer), or nil while it is not loaded.
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

-- A plain cooldown answer: its start, duration and whether the game holds it while the effect runs (enable false or 0); nil when withheld.
function R.Plain(ok, start, duration, enable)
	if not (ok and Finite(start) and Finite(duration)) then
		return nil
	end
	return start, duration, not IsSecret(enable) and (enable == false or enable == 0)
end

-- The cooldown of an item as the game gives it: C_Item.GetItemCooldown, else that of the worn copy or the bag copy (where: { worn = slot } or a
-- copy).
function R.Cooldown(id, where)
	local start, duration, held = R.Plain(Call(Fn(C_Item, "GetItemCooldown"), id))
	if start == nil and where.worn then
		start, duration, held = R.Plain(Call(GetInventoryItemCooldown, "player", where.worn))
	elseif start == nil and where.bag then
		start, duration, held = R.Plain(Call(Fn(C_Container, "GetContainerItemCooldown"), where.bag, where.slot))
	end
	return start, duration, held
end

-- The lines of a tooltip the game builds (C_TooltipInfo), or nil.
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

-- Seconds from a time of a tooltip: "1:42", or a number and the first letter of its word ("45 sec", "2 min", "1 hour"); nil when unreadable.
function R.Seconds(text)
	local m, s = text:match("(%d+):(%d%d)")
	if m then
		return tonumber(m) * 60 + tonumber(s)
	end
	local number, word = text:match("(%d+%.?%d*)%s*(%a)")
	local unit = word and UNITS[word:lower()]
	return number and unit and tonumber(number) * unit or nil
end

-- The pattern of the line the game adds while an item cools: ITEM_COOLDOWN_TIME with its magic characters escaped and %s caught, else English.
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

-- The time left that a copy's tooltip says, out of combat only: 0 without the line, nil when it cannot be read or the tooltip is not there.
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

-- The full cooldown of an item from its Use: line, "(2 Min Cooldown)", in seconds; nil while not known.
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

-- The time left of an item's cooldown (header): seconds, false for an item with no use, "held" while the game holds it as the effect runs, nil
-- unknown; then the time of its last use when known, and the plain start and duration.
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

-- Whether a game frame shows (read only, with IsShown), a withheld answer counting as shown.
function R.Shown(name)
	local frame = _G[name]
	if type(frame) ~= "table" or ns.Forbidden(frame) then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and (IsSecret(shown) or shown == true)
end

-- True for a plain true or a withheld answer of a call that exists.
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

-- The heard use ---------------------------------------------------------------------------------------------------------------------------------

-- The player cast a spell: when it is plain and is the use of a worn trinket, that trinket was used now. A withheld one is not heard.
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

-- The frame of its own that hears the player's casts, while it is wanted.
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

-- Wanted while the queue acts and a list has a delay, or the cooldowns come from the tooltips.
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

-- Refusals are forgotten: Queue now, for the items of its lists (only).
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

-- The gates --------------------------------------------------------------------------------------------------------------------------------------

-- A fight: InCombatLockdown or UnitAffectingCombat true or withheld.
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

-- The cursor and the bags busy, the list BagsPins.lua waits on (header).
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

-- The reasons that hold every slot back from a call that equips, and when to look again: nil when nothing does.
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

-- The reasons of one slot that need no reading of the gear: off, paused, Auto queue off, an empty list.
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

-- The decision -----------------------------------------------------------------------------------------------------------------------------------

-- Ready (header): no use, at most threshold seconds left, or for the worn item the cooldown the game starts as it is put on.
function D.Ready(left, start, duration, equippedAt, threshold)
	if left == false then
		return true
	end
	if Finite(left) and left <= threshold then
		return true
	end
	return Finite(start) and Finite(duration) and duration <= TIME.LOCKOUT and equippedAt ~= nil and math.abs(start - equippedAt) <= 1
end

-- A bag copy of an item the slot could take now, or nil with the time it is tried again when it waits for its back-off (header: Usable).
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

-- An entry the slot can put on now: its copy; else nil and when it may be ready (its cooldown end less the threshold, or its back-off).
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

-- The first entry from first to last the slot can put on now, and its copy; else nil, nil, when to look again and whether any was usable. The
-- earliest that may come is the slot's next (S.next, S.nextAt).
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

-- The rule for one slot (header). Answers the reason, when to look again, and for a swap the entry and the copy; S.next and S.nextAt say which
-- entry comes next and when.
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
		-- Unknown is not cooling (header): nothing lower goes on in its place.
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

-- The threshold of Ready with this much left.
function D.Threshold()
	local value = ns.Get("trinkets.ready")
	return Finite(value) and math.max(0, math.min(READY_MOST, value)) or 30
end

-- What a pass changed that the window and the buttons show.
function D.Signature()
	return ("%s/%s/%s/%s"):format(tostring(S.why.top), tostring(S.why.bottom), tostring(S.next.top), tostring(S.next.bottom))
end

-- One pass over both slots, top first, at most one swap; the other slot waits for its answer. Answers when to look again.
function D.Pass()
	local now = Now()
	local threshold = D.Threshold()
	local blocked, blockedAt = D.Blocked(now)
	local quiet = now < S.quietUntil
	local wake, before = nil, D.Signature()
	for _, n in ipairs(ORDER) do
		local why, at, entry, copy = D.Static(n), nil, nil, nil
		if why then
			S.next[n], S.nextAt[n], S.untilAt[n] = nil, nil, nil
		elseif blocked then
			why, at = blocked, blockedAt
		elseif quiet then
			why, at = "quiet", S.quietUntil
		elseif R.Locked(SLOTS[n]) then
			why = "locked"
		else
			why, at, entry, copy = D.Slot(n, now, threshold)
		end
		S.why[n] = why
		wake = Earliest(wake, at)
		if entry and copy then
			Q.Swap(n, entry.item, copy, why, false)
			blocked, blockedAt = "pending", nil
		end
	end
	if before ~= D.Signature() then
		S.version = S.version + 1
	end
	return wake
end

-- Arms the one timer for when a decision can change; any earlier timer does nothing once the token moved on.
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

-- A look: the reasons of both slots while the queue does nothing, else a pass and its timer.
function D.Look()
	if not Q.Active() then
		D.Idle()
		return
	end
	D.Arm(D.Pass())
	R.Ear(R.EarWanted())
end

-- The queue does nothing: no timer, no ear, and the reasons that say why.
function D.Idle()
	S.token = S.token + 1
	R.Ear(false)
	for _, n in ipairs(ORDER) do
		local why = D.Static(n) or "auto"
		if S.why[n] ~= why then
			S.why[n] = why
			S.version = S.version + 1
		end
	end
end

-- The swap ---------------------------------------------------------------------------------------------------------------------------------------

-- The bag copy goes into the slot by the cursor, so it is the one that moves while the same item is worn in the other slot (header).
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

-- True while the bags hold a bound and an unbound copy of an item: the same link names both, so the copy chosen goes in by the cursor.
function R.Mixed(id)
	local bound, unbound = false, false
	for _, copy in ipairs(R.Copies(id)) do
		bound = bound or copy.bound
		unbound = unbound or not copy.bound
	end
	return bound and unbound
end

-- Puts an item from a bag copy into slot n's slot (header). wear is true for a click on a row of the window, whose item the slot then holds.
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
		-- An unbound trinket the player clicked brings up the game's question, which waits for the player.
		C_Timer.After(wear and not copy.bound and TIME.ASK or TIME.CONFIRM, function()
			if S.pending == pending then
				Q.Run(Q.Failed, pending)
			end
		end)
	end
end

-- The name of an item for a line in chat: its link, else its name, else its ID.
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

-- Plays Sound on a swap (header).
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

-- The slot holds the item the swap asked for.
function Q.Confirmed(pending)
	S.pending = nil
	S.fails[pending.item], S.nextTry[pending.item] = nil, nil
	if pending.wear then
		R.Hold(pending.name, pending.item)
	else
		if ns.Get("trinkets.say") == true then
			local why = T.EMPTY_SLOT
			if pending.from and pending.why == "cooling" then
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

-- No answer within CONFIRM seconds, or the call failed: back-off, then refused (header).
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

-- Events -----------------------------------------------------------------------------------------------------------------------------------------

-- A slot changed (PLAYER_EQUIPMENT_CHANGED): the answer to a swap, or a change by hand, which holds the slot (header).
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
		-- The answer to a swap that came after CONFIRM: the swap worked after all.
		S.late = nil
		S.refused[late.item] = nil
		Q.Confirmed(late)
		return
	elseif not pending and now >= S.quietUntil and Q.Running() and Q.Auto(n) and not Q.Paused() and #Q.List(n) > 0 then
		-- A slot emptied by hand is held empty (0), so the trinket just taken off does not come straight back (header).
		R.Hold(n, worn or 0)
	end
	S.version = S.version + 1
	Q.Soon()
end

-- The fight began: the timer goes, and each slot whose Auto queue is on waits for its end.
function Q.Fight()
	S.token = S.token + 1
	for _, n in ipairs(ORDER) do
		if not D.Static(n) then
			S.why[n] = "fight"
		end
	end
	S.version = S.version + 1
end

-- The fight ended: back-offs are forgotten (refusals wait for Queue now, header), and the queue looks.
function Q.Peace()
	S.nextTry = {}
	S.fightTries = 0
	Q.Soon(true)
end

-- A loading screen ended: a quiet while the game sends its own changes of the slots.
function Q.Entered()
	S.quietUntil = Now() + TIME.QUIET
	S.bags = nil
	Q.Soon()
end

-- The bags changed (BAG_UPDATE_DELAYED) or an item's lock did (ITEM_LOCK_CHANGED): the scan is read again. Refusals stay (header).
function Q.BagsChanged()
	S.bags = nil
	Q.Soon()
end

-- True for an item of either list.
function R.Listed(id)
	for _, n in ipairs(ORDER) do
		if Q.Find(Q.List(n), id) then
			return true
		end
	end
	return false
end

-- An item loaded: what was read of it is read again.
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

-- The contract (TrinketQueueWindow.lua, TrinketQueueButtons.lua) ----------------------------------------------------------------------------------

-- True while the queue acts: it runs, Pause all is off and an Auto queue row is on.
function Q.Active()
	return Q.Running() and not Q.Paused() and (Q.Auto("top") or Q.Auto("bottom"))
end

-- Asks for a look SETTLE seconds from now, once however many ask. In combat lockdown only the fight's end asks (force), as nothing changes in one.
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

-- Pause all: off gives back the slots held by hand to the queue (header).
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

-- The rows' get and set (Config.lua names them): the Auto queue of a slot, kept per character in the store (header), never in a profile. Nil
-- before the saved variables load, so the row reads its default, off.
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

-- A slot's Auto queue (its row, which ns.Set routes to ns.TrinketAutoSet, Core.lua:2774-2793); turned on it takes back a slot held by hand.
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

-- Adds a trinket to a list, at its end or (atTop) at its top: done, and a line for the caller to say when it was not.
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

-- Moves an entry by one place (-1 up, +1 down), or to the top or the bottom (by -math.huge or math.huge).
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

-- Copies the other slot's list to the end of n's, in its order, each entry with its Delay and Stop (0.5.37): a trinket already in n's list is
-- passed over, and the copy stops at MOST. How many were added.
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

-- Empties a slot's list (0.5.37): how many entries it held.
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

-- Queue now: the hold goes, refusals and back-offs of the list are forgotten, and the next decision of the slot leaves Stop and Delay aside once.
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

-- A click on a row's icon in the window: that trinket goes on now, and the slot holds it. A bound copy first, as D.Usable takes; an unbound one
-- (the game asks itself before it binds) only while the bags hold no bound copy, so a spare that binds when worn is never taken in its place.
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
		-- Every bound copy is locked (it moves): the click waits for it.
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

-- What the window, the buttons and /flatui status show of a slot.
function Q.State(n)
	local slot = SLOTS[n]
	local worn = slot and R.Worn(slot) or nil
	local why = D.Static(n)
	if not why then
		why = S.why[n] or "keep"
		if D.Fighting() then
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

-- m:ss, from 10 minutes whole minutes ("12m"), from an hour whole hours ("2h").
function Q.Clock(seconds)
	seconds = Finite(seconds) and math.max(0, math.ceil(seconds)) or 0
	if seconds >= 3600 then
		return ("%dh"):format(math.ceil(seconds / 3600))
	elseif seconds >= 600 then
		return ("%dm"):format(math.ceil(seconds / 60))
	end
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- The tone of a slot: off, on, wait or halt (WHY); in a fight, wait whenever its Auto queue is on and the queue is not paused.
function Q.Tone(n, state)
	state = state or Q.State(n)
	if state.why == "fight" or (D.Fighting() and not D.Static(n)) then
		return "wait"
	end
	if state.refused and RESTING[state.why] then
		return "halt"
	end
	return (WHY[state.why] or WHY.keep)[1]
end

-- The sentence of a slot's state (TrinketQueueWindow.lua's state line, the buttons' tooltips, /flatui status).
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

-- What the window shows of an item: its cooldown left (R.Left: seconds, false, "held" or nil), how many copies the bags hold, the slot it is
-- worn in, whether a copy is bound, the level it needs and whether that is above the player's, its link, name, icon and quality, and the copy
-- whose tooltip it shows.
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

-- The trinkets in the bags and the two worn, each once, by name: { id, name, worn = slot name, copy }.
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

-- The words of a slot and the word for the window's foot of a fight.
function Q.Word(n)
	return WORD[n]
end

function Q.Fighting()
	return D.Fighting()
end

function Q.Threshold()
	return D.Threshold()
end

-- The module ---------------------------------------------------------------------------------------------------------------------------------

-- The window and the buttons hear of a change of the module (TrinketQueueWindow.lua, TrinketQueueButtons.lua), looked up when called.
function R.Tell()
	for _, name in ipairs({ "TrinketWindowSync", "TrinketButtonsChanged" }) do
		local ok, err = Call(Fn(ns, name))
		if not ok and err ~= nil then
			Q.Report(name, err)
		end
	end
end

-- Started: a quiet after login, the holds saved count from now, and a look.
function Q.Started()
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

-- Refreshed: a row changed, the module went on or off, or a general row settled. An Auto queue row turned on takes back its slot's hold.
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

-- A sentence with its first letter small, for the middle of a line.
function R.Lower(text)
	return (text:gsub("^%u", string.lower))
end

-- The line of an entry for /flatui queue list.
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

-- /flatui queue copy and clear, with the list they act on (0.5.37): copy bottom fills the Bottom list from the Top one; clear top empties the Top
-- list. One line in chat each.
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

-- /flatui queue and /flatui trinkets.
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

-- The lines of /flatui status, only while the module is on (header).
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
