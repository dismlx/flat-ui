local _, ns = ...

-- Consumables bar: a bar of Flat UI's own buttons for the consumables in your bags, or for the ones you choose. A module of its own, off by default,
-- whose page is in the Helpers group after Drink and health macros. A click on a button uses its item from whichever bag holds it, also in a fight.
-- Each button is drawn as the icons of Group tools and the Ping bar are (IconRow.lua, ns.IconNew): square, with a thin border on a dark background,
-- the item's icon inside, its count across the bags in the bottom right corner, the sweep of its cooldown, and its key short in the top left corner
-- while one is bound. /flatui move places the bar (FlatUIConsumeBar in Movers.lua: the corner of the bar that Grow starts from is that corner of the
-- box). No frame or setting of the game is changed.
--
-- Which buttons (Buttons, consumebar.which). Every consumable in your bags (bags, the default): each item ID of the game's Consumable class (class 0)
-- with a use (C_Item.GetItemSpell gives its spell), and the Explosives and Devices of Trade goods (class 7, subclasses 2 and 3), as Bags files them
-- with the consumables at Each kind (BagsCategories.lua), found in the backpack, the four bags and the reagent bag (C_Container.GetContainerNumSlots
-- and GetContainerItemID), never the bank, one button for each item ID. Equippable items are left out: the game's item action equips them. They
-- are sorted by kind in the order of the sections of the Bags page at Each kind (the rest of the consumables, such as healthstones and mana gems,
-- then Food and drink, Potions, Elixirs and flasks, Scrolls, Bandages, Enhancements, Explosives and devices; the subclasses BagsCategories.lua reads:
-- Potion 1, Elixir 2, Flasksphials 3, Scroll 4, Fooddrink 5, Itemenhancement 6, Bandage 7, Device 14, ItemenhancementTemporary 15), then by name,
-- an item whose name has not loaded after the named ones by its ID. The Kinds in your bags chips leave a kind out. Your list (list): only the items
-- the player chose, in his order. Your list, then the rest (both): the list, then the bag part without the items of the list.
-- Your list is kept per character in FlatUICharDB.consumeBar, item IDs in order, at most MOST_LIST. An item is added by a drop on the bar out of a
-- fight (OnReceiveDrag, or a click with an item on the cursor: GetCursorInfo; ClearCursor puts the item back in its bag once it is taken): on a
-- button of the list it goes in that place (an item of the list dropped there moves), else at the end, and while the cursor holds an item a + slot
-- of the addon's own (a plain button) ends the bar out of a fight in the modes that show the list. Add an item offers the consumables in the bags.
-- Shift+right-click on a button takes it off the list, or puts a bag button on it; Take an item off, Move an item left and Move an item right do
-- the same from the page, also in a fight and with the page off (the bar follows when it can). A drop takes only a consumable of the kinds above
-- (C.KindOf: the Consumable class, or the Explosives and Devices of Trade goods) with a use that cannot be worn, and a drop on the + slot of an item
-- of the list moves it to the end.
-- An item of the list stays on the bar when the bags hold none: its icon grey (SetDesaturated) and dim, its count a red 0, or, with An item of your
-- list with none left at Leave a gap, its icon hidden in its place. A click on such a button says "Flat UI: no <item> in your bags." in chat, at
-- most once in NONE_GAP seconds for an item. A button of the bag part whose item runs out in a fight is drawn so until the fight ends, and goes at
-- the next layout.
--
-- The secure buttons. A button is a SecureActionButtonTemplate button of the addon's own (*type1 item, so with any modifier held, item
-- "item:<id>", useOnKeyDown false, the release of the left and right button), so a left click uses the item by its ID from any bag (the game's own
-- item action), in a fight too; the right button has no type and does nothing secure. The first BOUND of them are named FlatUIConsumeButton1 to 6 for their key bindings in Bindings.xml
-- (CLICK ...:LeftButton, category Flat UI), named in the game's Key Bindings by BINDING_NAME_ globals here, as the Ping bar names its own. They lie
-- over icons of the addon's own, as Group tools' do, so an icon can be greyed, counted, swept, faded or hidden in a fight while its secure button
-- is not touched. The secure buttons make the bar protected, so the bar and its buttons are made, placed, sized, shown, hidden and given attributes
-- only out of combat: a change in a fight waits for its end (ns.OutOfCombat), and a change of the player's (a row, the list, the spot) says so once
-- a fight in chat (WAIT_LINE), as the bar block says its own. A PreClick and a PostClick of the addon's own, set as each button is made, out of
-- combat, take the type away for a left click with an item on the cursor (or right after a drop on it, which may come first) and give it back
-- after, out of combat only, as Mount key's safety swaps its macro, so such a click drops and uses nothing; in a fight they change no attribute.
-- The PostClick also reads Shift with the right button, and a left click on a button with none. With the module off the buttons lose their type
-- and item, so their keys do nothing; the bindings are the player's and stay. The bar hangs from a frame of its own that a state driver hides in
-- a pet battle (RegisterStateDriver, "[petbattle] hide; show"), as Flat UI's action buttons hide there (OwnBars.lua).
-- Counts are C_Item.GetItemCount(id, false, true) (the bags, not the bank, with the uses of an item of charges), cooldowns C_Container.
-- GetItemCooldown, else C_Item.GetItemCooldown (as TrackerKinds.lua reads them), set on the icon's Cooldown frame only when they change, and
-- whether an item can be used now C_Item.IsUsableItem, which tints the icon in the game's colours for an action button that cannot be used, or that
-- lacks mana (ButtonStates.lua's GAME). Every answer passes ns.IsSecret or ns.Finite first; a withheld answer keeps what the button showed. The
-- names come from C_Item.GetItemNameByID, and an item the client has not loaded is asked for once (C_Item.RequestLoadItemDataByID) and sorted and
-- named again when GET_ITEM_INFO_RECEIVED says it came; the icons from C_Item.GetItemInfoInstant, which needs nothing loaded.
-- Events: BAG_UPDATE_DELAYED and PLAYER_ENTERING_WORLD read the bags again, lay out out of combat, and count, grey and sweep at once, in a fight
-- too; BAG_UPDATE_COOLDOWN sweeps; SPELL_UPDATE_USABLE and PLAYER_LEVEL_UP tint; CURSOR_CHANGED brings or takes the + slot, out of combat;
-- UPDATE_BINDINGS writes the keys; PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED fade and apply what waited. No OnUpdate and no ticker.
-- Pointing at a button writes the item's tooltip in GameTooltip (SetOwner on the button, SetItemByID, AddLine, Show, and Hide when the mouse
-- leaves), with what Shift+right-click does, its key, and "None in your bags." while it has none.
-- Fade out of a fight (off by default): out of a fight the icons stay at Faded opacity, full while the mouse is over a button and in a fight. Only
-- the opacity of the icons changes, frames of the addon's own and no secure button, so in a fight too, and the faint buttons take their clicks.
-- Test mode (TestMode.lua, out of combat only): while the bar is on and would show no button, a few sample buttons, full and greyed, show where it
-- sits, with the tooltip of their item and a line that says they are samples; a click on one uses nothing.

local KEY = "consumebar"
local MOVER = "FlatUIConsumeBar"
local LABEL = "Consumables bar"
-- The box of the handle in Movers.lua: six buttons at the default size and spacing in a row, its bottom left corner above the chat window, clear of
-- the action bars. With no spot saved the bar starts there.
local BOX_W, BOX_H, BOX_X, BOX_Y = 226, 36, 20, 280
-- The most items of the list, the most buttons of the bar, and how many of the first buttons have a key binding.
local MOST_LIST, MOST_BUTTONS, BOUND = 24, 40, 6
local BUTTON = "FlatUIConsumeButton"
local IsSecret, Finite = ns.IsSecret, ns.Finite

-- Looks and lines, in one table so that no function holds many upvalues.
local K = {
	KEY_FONT = "GameFontHighlightSmall", COUNT_FONT = "NumberFontNormal", PLUS_FONT = "GameFontHighlightLarge",
	-- The text-dim of the windows (PanelLook.lua) and the warm colour of the lines of a tooltip, as Group tools has them; the red of a count of 0.
	DIM = { 0.66, 0.68, 0.62 }, WARN = { 0.9, 0.72, 0.36 }, RED = { 1, 0.3, 0.25 },
	-- The game's colours of an action button that cannot be used, or that lacks mana (ButtonStates.lua, GAME).
	UNUSABLE = { 0.4, 0.4, 0.4 }, NO_MANA = { 0.5, 0.5, 1 }, WHITE = { 1, 1, 1 },
	-- The opacity of the icon of an item with none left, how much lighter a button's background is under the mouse, the seconds between two "no
	-- item" lines for one item, how long a drop holds back the click that may follow it, and the step of a burst of item loads.
	EMPTY_ALPHA = 0.45, LIGHTER = 0.17, NONE_GAP = 5, RECENT = 0.5, SOON = 0.2,
	-- The samples of test mode: an item ID and its count (0 is greyed): Minor Healing Potion, Refreshing Spring Water, Tough Hunk of Bread and Linen
	-- Bandage.
	SAMPLES = { { 118, 5 }, { 159, 12 }, { 4540, 0 }, { 1251, 3 } },
	QUESTION = 134400,
	WAIT_LINE = "Flat UI: the consumables bar lays out again when the fight ends.",
	FIGHT_DROP = "Flat UI: drop items on the consumables bar out of a fight.",
	NONE_LINE = "Flat UI: no %s in your bags.",
	LINE_WAITING = LABEL .. ": the buttons change when the fight ends.",
	LINE_BROKEN = LABEL .. ": the game made no secure button, so the bar stays hidden.",
	LINE_COUNT = LABEL .. ": %d buttons, %d of them from your list of %d.",
	BAGS_HINT = " It shows while Buttons is Your list or Your list, then the rest.",
}

-- The kinds, in the order of the sections of the Bags page at Each kind (BagsCategories.lua: the rest of the consumables first), each with the row
-- of Kinds in your bags that keeps it on the bar.
local KINDS = {
	{ key = "other", row = "kindOther" },
	{ key = "food", row = "kindFood" },
	{ key = "potion", row = "kindPotion" },
	{ key = "elixir", row = "kindElixir" },
	{ key = "scroll", row = "kindScroll" },
	{ key = "bandage", row = "kindBandage" },
	{ key = "enhance", row = "kindEnhance" },
	{ key = "explosive", row = "kindExplosive" },
}
local KIND_AT = {}
for index, kind in ipairs(KINDS) do
	KIND_AT[kind.key] = index
end
-- The kind of each subclass of Consumable (0) and of Trade goods (7), as BagsCategories.lua has them; another subclass of Consumable is the rest.
local CONSUMABLE, TRADEGOODS = 0, 7
local SUBS = {
	[CONSUMABLE] = { [1] = "potion", [2] = "elixir", [3] = "elixir", [4] = "scroll", [5] = "food", [6] = "enhance", [7] = "bandage", [14] = "explosive",
		[15] = "enhance" },
	[TRADEGOODS] = { [2] = "explosive", [3] = "explosive" },
}
-- The backpack, the four bags and the reagent bag (Enum.BagIndex); never the bank or the keyring.
local BAGS = { 0, 1, 2, 3, 4, 5 }
-- The corner the bar grows from, by Grow: rows stack upward while it grows right or left, columns go right while it grows up or down.
local CORNER = { right = "BOTTOMLEFT", left = "BOTTOMRIGHT", up = "BOTTOMLEFT", down = "TOPLEFT" }
local SHARE = { BOTTOMLEFT = { 0, 0 }, BOTTOMRIGHT = { 1, 0 }, TOPLEFT = { 0, 1 } }
local WHICH = { bags = true, list = true, both = true }

-- The state of the bar. holder: the frame the pet battle driver hides; panel: the bar. entries: the buttons made, by place; shown: those the last
-- layout used; plus: the + slot. laid, placed: the layout and the spot in place. queued: a layout waits for the end of a fight; told: chat said so
-- this fight. scanned: the consumables of the bags, sorted. instant, uses, names: what the client said of each item ID. pending: the items asked for.
-- none: when each item last said it has none. recent: the last drop, { entry, at }. hover: the button under the mouse. fighting: between
-- PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED. cleaned: the list was cleaned this session.
local C = {
	entries = {}, shown = {}, instant = {}, uses = {}, names = {}, pending = {}, none = {},
	queued = false, told = false, broken = false, fighting = false, cleaned = false,
}
ns.ConsumeBar = C

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

-- A number row, else its default.
local function Number(key, default)
	local value = Opt(key)
	return Finite(value) and value or default
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
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

-- A function of one of the client's tables, or nil.
local function Api(space, name)
	local t = _G[space]
	local fn = type(t) == "table" and not IsSecret(t) and t[name] or nil
	return type(fn) == "function" and fn or nil
end

-- A whole number above 0, or nil.
local function Whole(value)
	if Finite(value) and value > 0 and value == math.floor(value) then
		return value
	end
	return nil
end

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

-- In a fight, or the game will not say: the secure buttons are left alone then.
local function Fighting()
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (IsSecret(fighting) or fighting == true)
end

-- True while test mode is on (TestMode.lua).
local function Testing()
	local mode = ns.TestMode
	return mode ~= nil and mode.IsOn() == true
end

local function Now()
	local now = Ask(GetTime)
	return Finite(now) and now or 0
end

-- Items ----------------------------------------------------------------------------------------------------------------------------------------

-- What the client says of an item ID at once (C_Item.GetItemInfoInstant): { icon, class, sub, slot }, or false for an ID it does not know.
function C.Instant(id)
	local known = C.instant[id]
	if known ~= nil then
		return known
	end
	local call = Api("C_Item", "GetItemInfoInstant") or (type(GetItemInfoInstant) == "function" and GetItemInfoInstant or nil)
	if not call then
		return false
	end
	local ok, found, _, _, slot, icon, class, sub = pcall(call, id)
	if not ok or IsSecret(found) or found == nil then
		known = false
	else
		known = { icon = not IsSecret(icon) and icon or nil, class = Finite(class) and class or nil, sub = Finite(sub) and sub or nil,
			slot = not IsSecret(slot) and type(slot) == "string" and slot or nil }
	end
	C.instant[id] = known
	return known
end

-- The kind of an item on the bar, or nil for an item that is no consumable.
function C.KindOf(id)
	local info = C.Instant(id)
	if not info then
		return nil
	elseif info.class == CONSUMABLE then
		return info.sub and SUBS[CONSUMABLE][info.sub] or "other"
	elseif info.class == TRADEGOODS then
		return info.sub and SUBS[TRADEGOODS][info.sub] or nil
	end
	return nil
end

-- The name of an item, or nil while the client has not loaded it: then it is asked for once, and GET_ITEM_INFO_RECEIVED brings it.
function C.Name(id)
	local name = C.names[id]
	if name then
		return name
	end
	name = Ask(Api("C_Item", "GetItemNameByID"), id)
	if type(name) ~= "string" or name == "" then
		name = Ask(GetItemInfo, id)
	end
	if type(name) == "string" and name ~= "" then
		C.names[id] = name
		return name
	end
	if not C.pending[id] then
		C.pending[id] = true
		pcall(Api("C_Item", "RequestLoadItemDataByID") or function() end, id)
	end
	return nil
end

-- The name of an item for a line: its name, else its ID.
function C.Called(id)
	return C.Name(id) or ("item %d"):format(id)
end

-- True for an item with a use, false for one without, nil while the client cannot say (not loaded). A use is kept; a lack of one only once the item
-- has loaded.
function C.HasUse(id)
	local known = C.uses[id]
	if known ~= nil then
		return known
	end
	local call = Api("C_Item", "GetItemSpell") or (type(GetItemSpell) == "function" and GetItemSpell or nil)
	if not call then
		return true
	end
	local ok, name, spell = pcall(call, id)
	if ok and ((not IsSecret(name) and type(name) == "string" and name ~= "") or Whole(spell)) then
		C.uses[id] = true
		return true
	end
	if C.Name(id) then
		C.uses[id] = false
		return false
	end
	return nil
end

-- True for an item that can be worn: the game's item action would equip it.
function C.Worn(id)
	if Ask(Api("C_Item", "IsEquippableItem"), id) == true then
		return true
	end
	local info = C.Instant(id)
	local slot = info and info.slot
	return slot ~= nil and slot ~= "" and slot ~= "INVTYPE_NON_EQUIP_IGNORE" and slot ~= "INVTYPE_NON_EQUIP"
end

-- How many the bags hold, with the uses of an item of charges and not the bank; nil when the game does not say.
function C.Count(id)
	local count = Ask(Api("C_Item", "GetItemCount") or GetItemCount, id, false, true)
	return Finite(count) and count or nil
end

function C.Icon(id)
	local info = C.Instant(id)
	return info and info.icon or K.QUESTION
end

-- The cooldown of an item: its start and length (0 for none), or nil when the game does not say.
function C.Cooldown(id)
	local call = Api("C_Container", "GetItemCooldown") or Api("C_Item", "GetItemCooldown")
	if not call then
		return nil
	end
	local ok, start, duration, enable = pcall(call, id)
	if not ok or IsSecret(start) or IsSecret(duration) or IsSecret(enable) or not (Finite(start) and Finite(duration)) then
		return nil
	end
	if duration > 0 and start > 0 and (enable == true or enable == nil or (Finite(enable) and enable ~= 0)) then
		return start, duration
	end
	return 0, 0
end

-- The consumables of the bags, each item ID once, sorted by kind and name: read again after the bags or an item's data change.
function C.Scan()
	if C.scanned then
		return C.scanned
	end
	local slots, item = Api("C_Container", "GetContainerNumSlots"), Api("C_Container", "GetContainerItemID")
	local ids, seen = {}, {}
	if slots and item then
		for _, bag in ipairs(BAGS) do
			local size = Ask(slots, bag)
			for slot = 1, Whole(size) or 0 do
				local id = Whole(Ask(item, bag, slot))
				if id and not seen[id] then
					seen[id] = true
					if C.KindOf(id) and not C.Worn(id) and C.HasUse(id) == true then
						ids[#ids + 1] = id
					end
				end
			end
		end
	end
	C.scanned = C.Sorted(ids)
	return C.scanned
end

-- Item IDs by kind, then by name, an item whose name has not loaded after the named ones of its kind, then by ID.
function C.Sorted(ids)
	local keys = {}
	for _, id in ipairs(ids) do
		local name = C.Name(id)
		keys[id] = { KIND_AT[C.KindOf(id) or "other"] or 1, name and name:lower() or nil }
	end
	table.sort(ids, function(a, b)
		local ka, kb = keys[a], keys[b]
		if ka[1] ~= kb[1] then
			return ka[1] < kb[1]
		elseif ka[2] ~= kb[2] then
			if ka[2] == nil or kb[2] == nil then
				return kb[2] == nil
			end
			return ka[2] < kb[2]
		end
		return a < b
	end)
	return ids
end

-- True while Kinds in your bags keeps a kind on the bar.
function C.KindOn(kind)
	local at = KIND_AT[kind or "other"]
	return at ~= nil and Opt(KINDS[at].row) ~= false
end

-- The list --------------------------------------------------------------------------------------------------------------------------------------

-- FlatUICharDB.consumeBar: this character's item IDs in order. An empty table that is not kept while nothing is saved, unless make is set. The first
-- read of a session cleans it: whole numbers only, each once, at most MOST_LIST.
function C.List(make)
	local char = ns.Character()
	if type(char) ~= "table" then
		return {}
	end
	local list = char.consumeBar
	if type(list) ~= "table" then
		if not make then
			return {}
		end
		list = {}
		char.consumeBar = list
	end
	if not C.cleaned then
		C.cleaned = true
		local clean, seen = {}, {}
		for _, id in ipairs(list) do
			id = Whole(id)
			if id and not seen[id] and #clean < MOST_LIST then
				seen[id] = true
				clean[#clean + 1] = id
			end
		end
		for index = #list, 1, -1 do
			list[index] = nil
		end
		for index, id in ipairs(clean) do
			list[index] = id
		end
	end
	return list
end

function C.Listed(id)
	for index, each in ipairs(C.List()) do
		if each == id then
			return index
		end
	end
	return nil
end

-- Why an item cannot go on the list, or nil when it can: it must be a consumable of a kind the bar knows (C.KindOf), with a use, that cannot be worn.
function C.Refused(id)
	local name = C.Called(id)
	if not C.Instant(id) then
		return ('No item found for "%s".'):format(tostring(id))
	elseif C.Worn(id) then
		return ("%s is worn, not used up: it belongs on your action bars."):format(name)
	elseif not C.KindOf(id) then
		return ("%s is not a consumable: the consumables bar holds consumables only."):format(name)
	elseif C.HasUse(id) == false then
		return ("%s has no use."):format(name)
	end
	return nil
end

-- Puts an item on the list at place `at` (before the item there), else at the end; an item of the list moves there. Returns true or false and the
-- line that says what happened.
function C.Insert(id, at)
	id = Whole(id)
	if not id then
		return false, "No such item."
	end
	local refused = C.Refused(id)
	if refused then
		return false, refused
	end
	local name, list = C.Called(id), C.List(true)
	local was = C.Listed(id)
	if was then
		if not at or at == was or at == was + 1 then
			return false, ("%s is on your list already."):format(name)
		end
		table.remove(list, was)
		if at > was then
			at = at - 1
		end
	elseif #list >= MOST_LIST then
		return false, ("Your list holds %d items at most."):format(MOST_LIST)
	end
	if not (Whole(at) and at <= #list + 1) then
		at = #list + 1
	end
	table.insert(list, at, id)
	C.ListChanged()
	local line = was and ("%s is now number %d of your list."):format(name, at) or ("%s is on your list of the consumables bar."):format(name)
	return true, line .. (C.Mode() == "bags" and K.BAGS_HINT or "")
end

function C.Remove(id)
	local at = Whole(id) and C.Listed(id)
	if not at then
		return false, ("%s is not on your list."):format(Whole(id) and C.Called(id) or tostring(id))
	end
	table.remove(C.List(true), at)
	C.ListChanged()
	return true, ("%s is off your list."):format(C.Called(id))
end

-- One place earlier (step -1) or later (1).
function C.Move(id, step)
	local at = Whole(id) and C.Listed(id)
	if not at then
		return false, ("%s is not on your list."):format(Whole(id) and C.Called(id) or tostring(id))
	end
	local list, to = C.List(true), at + step
	if to < 1 then
		return false, ("%s is first already."):format(C.Called(id))
	elseif to > #list then
		return false, ("%s is last already."):format(C.Called(id))
	end
	list[at], list[to] = list[to], list[at]
	C.ListChanged()
	return true, ("%s is now number %d of your list."):format(C.Called(id), to)
end

-- The list changed: the bar follows, now or when the fight ends, while the module runs.
function C.ListChanged()
	if ns.Enabled(KEY) then
		ns.Try(KEY, C.Apply, true)
	end
end

function C.Mode()
	local mode = Opt("which")
	return WHICH[mode] and mode or "bags"
end

-- The item on the cursor, or nil when it holds none.
function C.CursorItem()
	local ok, kind, id = pcall(GetCursorInfo)
	if not ok or IsSecret(kind) or kind ~= "item" or IsSecret(id) then
		return nil
	end
	return Whole(id)
end

-- What the bar holds ------------------------------------------------------------------------------------------------------------------------------

-- The buttons the rows, the list and the bags ask for, each { id, list, place }, and plus while the + slot ends the bar. With nothing to show while
-- test mode is on, its samples, each { id, sample, count }.
function C.Wanted()
	local mode, wanted, seen = C.Mode(), {}, {}
	if mode ~= "bags" then
		for place, id in ipairs(C.List()) do
			wanted[#wanted + 1] = { id = id, list = true, place = place }
			seen[id] = true
		end
	end
	if mode ~= "list" then
		for _, id in ipairs(C.Scan()) do
			if #wanted >= MOST_BUTTONS then
				break
			end
			if not seen[id] and C.KindOn(C.KindOf(id)) and (C.Count(id) or 0) > 0 then
				wanted[#wanted + 1] = { id = id }
			end
		end
	end
	if #wanted == 0 and Testing() then
		for _, sample in ipairs(K.SAMPLES) do
			wanted[#wanted + 1] = { id = sample[1], sample = true, count = sample[2] }
		end
	end
	if mode ~= "bags" and not C.fighting and #wanted < MOST_BUTTONS then
		local held = C.CursorItem()
		wanted.plus = held ~= nil and C.Refused(held) == nil
	end
	return wanted
end

-- Button size, Spacing, Buttons per row and Grow.
function C.Look()
	local size = math.max(16, math.min(80, Number("size", 36)))
	local spacing = math.max(0, math.min(40, Number("spacing", 2)))
	local per = math.max(1, math.min(MOST_BUTTONS, math.floor(Number("perRow", 12))))
	local grow = Opt("grow")
	return size, spacing, per, CORNER[grow] and grow or "right"
end

-- The layout of a list of buttons as one string: the look, the buttons and the + slot.
function C.LayoutKey(wanted)
	local size, spacing, per, grow = C.Look()
	local parts = { size, spacing, per, grow, wanted.plus and "+" or "" }
	for _, want in ipairs(wanted) do
		parts[#parts + 1] = (want.sample and "s" or want.list and "l" or "b") .. want.id
	end
	return table.concat(parts, ",")
end

-- Building ----------------------------------------------------------------------------------------------------------------------------------------

-- The holder and the bar, made the first time the bar shows, out of combat.
function C.Build()
	if C.panel then
		return true
	end
	local holder = Own(CreateFrame("Frame", nil, UIParent))
	if type(RegisterStateDriver) == "function" then
		pcall(RegisterStateDriver, holder, "visibility", "[petbattle] hide; show")
	end
	local panel = Own(CreateFrame("Frame", nil, holder))
	panel:SetFrameStrata("LOW")
	panel:SetSize(BOX_W, BOX_H)
	panel:Hide()
	C.holder, C.panel = holder, panel
	return true
end

-- A font string of the addon's own, with the shadow of the Group tools' tallies.
local function Text(parent, font, point, x, y)
	local text = ns.OwnText(parent, "OVERLAY", font)
	if text then
		text:SetPoint(point, parent, point, x, y)
		text:SetWordWrap(false)
		pcall(text.SetShadowOffset, text, 1, -1)
		pcall(text.SetShadowColor, text, 0, 0, 0, 1)
	end
	return text
end

-- The button at a place, made the first time a layout needs it: the icon (ns.IconNew), a frame over its sweep for the count and the key, and the
-- secure button over all. Nil when the game made none, or past MOST_BUTTONS.
function C.Entry(index)
	local entry = C.entries[index]
	if entry then
		return entry
	elseif C.broken or index > MOST_BUTTONS then
		return nil
	end
	local icon = ns.IconNew(C.panel)
	if not icon then
		return nil
	end
	ns.SetOutline(icon.outline, true, true)
	local top = Own(CreateFrame("Frame", nil, icon.frame))
	top:SetAllPoints(icon.frame)
	top:SetFrameLevel(icon.frame:GetFrameLevel() + 3)
	entry = { index = index, icon = icon, frame = icon.frame, texture = icon.texture, cooldown = icon.cooldown, outline = icon.outline, top = top }
	entry.countText = Text(top, K.COUNT_FONT, "BOTTOMRIGHT", -1, 2)
	entry.keyText = Text(top, K.KEY_FONT, "TOPLEFT", 2, -2)
	entry.cover = C.Cover(entry)
	if not entry.cover then
		C.broken = true
		icon.frame:Hide()
		return nil
	end
	C.entries[index] = entry
	return entry
end

-- The secure button over an icon, a child of the bar with no picture of its own, above the icon (as Group tools lays its own). The first BOUND are
-- named for their key bindings.
function C.Cover(entry)
	local name = entry.index <= BOUND and (BUTTON .. entry.index) or nil
	local made, cover = pcall(CreateFrame, "Button", name, C.panel, "SecureActionButtonTemplate")
	if not made or type(cover) ~= "table" then
		return nil
	end
	Own(cover)
	local done = pcall(function()
		cover:SetFrameLevel(entry.frame:GetFrameLevel() + 5)
		cover:EnableMouse(true)
		cover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		-- The game runs a click on the key press by default (ActionButtonUseKeyDown); the button listens for the release, as Group tools' do.
		cover:SetAttribute("useOnKeyDown", false)
		cover:SetScript("PreClick", function(_, button)
			ns.Try(KEY, C.PreClick, entry, button)
		end)
		cover:SetScript("PostClick", function(_, button)
			ns.Try(KEY, C.PostClick, entry, button)
		end)
		cover:SetScript("OnReceiveDrag", function()
			ns.Try(KEY, C.Drop, entry)
		end)
		cover:SetScript("OnEnter", function()
			ns.Try(KEY, C.Enter, entry)
		end)
		cover:SetScript("OnLeave", function()
			ns.Try(KEY, C.Leave, entry)
		end)
		cover:Hide()
	end)
	if not done then
		pcall(cover.Hide, cover)
		return nil
	end
	return cover
end

-- The + slot: a plain button of the addon's own, with a + on the dark background of the icons, that takes the item on the cursor.
function C.Plus()
	if C.plus then
		return C.plus
	end
	local button = Own(CreateFrame("Button", nil, C.panel))
	button:RegisterForClicks("LeftButtonUp")
	local plus = { frame = button, plus = true }
	plus.outline = ns.Outline(button, button)
	ns.SetOutline(plus.outline, true, true)
	plus.text = Text(button, K.PLUS_FONT, "CENTER", 0, 0)
	if plus.text then
		plus.text:SetText("+")
	end
	button:SetScript("OnReceiveDrag", function()
		ns.Try(KEY, C.Drop, plus)
	end)
	button:SetScript("OnClick", function()
		ns.Try(KEY, C.Drop, plus)
	end)
	button:SetScript("OnEnter", function()
		ns.Try(KEY, C.Enter, plus)
	end)
	button:SetScript("OnLeave", function()
		ns.Try(KEY, C.Leave, plus)
	end)
	button:Hide()
	C.plus = plus
	return plus
end

-- Gives a button the item it uses, or takes it away (samples, unused buttons): attributes, out of combat only, and only when they change.
function C.Arm(entry)
	local item = (entry.id and not entry.sample) and ("item:" .. entry.id) or nil
	if entry.armed == item then
		return
	end
	local cover = entry.cover
	if pcall(cover.SetAttribute, cover, "item", item) and pcall(cover.SetAttribute, cover, "*type1", item and "item" or nil) then
		entry.armed = item
	end
end

-- An unused button: hidden, with no item, no sweep and no tooltip.
function C.Park(entry)
	if entry.hover then
		C.Leave(entry)
	end
	entry.id, entry.list, entry.place, entry.sample, entry.sampleCount = nil, nil, nil, nil, nil
	entry.cd, entry.shownIcon, entry.lastCount, entry.empty = nil, nil, nil, nil
	pcall(entry.cooldown.Clear, entry.cooldown)
	entry.frame:Hide()
	entry.cover:Hide()
	C.Arm(entry)
end

-- Laying out ------------------------------------------------------------------------------------------------------------------------------------

-- Where the button at a place sits from the corner of the bar: along a row (or a column while it grows up or down), then across.
function C.Offset(index, per, step, grow)
	local along, across = (index - 1) % per, math.floor((index - 1) / per)
	if grow == "left" then
		return -along * step, across * step
	elseif grow == "up" then
		return across * step, along * step
	elseif grow == "down" then
		return across * step, -along * step
	end
	return along * step, across * step
end

-- Puts a frame at a place of the bar.
local function Put(frame, corner, x, y, size)
	frame:ClearAllPoints()
	frame:SetPoint(corner, C.panel, corner, x, y)
	frame:SetSize(size, size)
	frame:Show()
end

-- Gives each place its button and its item, hides the buttons left over, and lays them out and sizes the bar when the layout changed. Out of combat.
function C.Layout(wanted)
	local shown = {}
	for index, want in ipairs(wanted) do
		local entry = C.Entry(index)
		if not entry then
			break
		end
		if entry.id ~= want.id or entry.sample ~= (want.sample == true) then
			entry.cd, entry.shownIcon, entry.lastCount = nil, nil, nil
			pcall(entry.cooldown.Clear, entry.cooldown)
		end
		entry.id, entry.list, entry.place, entry.sample, entry.sampleCount = want.id, want.list == true, want.place, want.sample == true, want.count
		C.Arm(entry)
		shown[#shown + 1] = entry
	end
	for index = #shown + 1, #C.entries do
		if C.entries[index].id or C.entries[index].frame:IsShown() then
			C.Park(C.entries[index])
		end
	end
	C.shown = shown
	local plus = wanted.plus and C.Plus() or C.plus
	local key = C.LayoutKey(wanted)
	if C.laid == key then
		return
	end
	C.laid = key
	local size, spacing, per, grow = C.Look()
	local corner, step = CORNER[grow], size + spacing
	for index, entry in ipairs(shown) do
		local x, y = C.Offset(index, per, step, grow)
		Put(entry.frame, corner, x, y, size)
		Put(entry.cover, corner, x, y, size)
		ns.IconCountdownHeight(entry.icon, size, BOX_H)
		if entry.countText then
			entry.countText:SetTextHeight(math.max(8, math.floor(size * 0.36 + 0.5)))
		end
		if entry.keyText then
			entry.keyText:SetTextHeight(math.max(7, math.floor(size * 0.28 + 0.5)))
		end
	end
	local count = #shown
	if plus then
		if wanted.plus then
			count = count + 1
			local x, y = C.Offset(count, per, step, grow)
			Put(plus.frame, corner, x, y, size)
		else
			plus.frame:Hide()
		end
	end
	local long, lines = math.min(math.max(count, 1), per), math.max(1, math.ceil(count / per))
	local across, along = lines * size + (lines - 1) * spacing, long * size + (long - 1) * spacing
	if grow == "up" or grow == "down" then
		C.panel:SetSize(across, along)
	else
		C.panel:SetSize(along, across)
	end
end

-- Puts the bar at the spot of its handle, by the corner Grow starts from: that corner of the bar at that corner of the box.
function C.Place()
	local _, _, _, grow = C.Look()
	local corner = CORNER[grow]
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, corner)
	end
	if not (Finite(x) and Finite(y)) then
		local share = SHARE[corner]
		x, y = BOX_X + BOX_W * share[1], BOX_Y + BOX_H * share[2]
	end
	local key = ("%s:%.2f:%.2f"):format(corner, x, y)
	if C.placed == key then
		return
	end
	C.placed = key
	C.panel:ClearAllPoints()
	C.panel:SetPoint(corner, UIParent, "BOTTOMLEFT", x, y)
end

-- Every button hidden and without an item: the module off, or nothing to show.
function C.Retire(why)
	for _, entry in ipairs(C.entries) do
		if entry.id or entry.armed or entry.frame:IsShown() then
			C.Park(entry)
		end
	end
	if C.plus then
		C.plus.frame:Hide()
	end
	C.shown = {}
	C.laid = why
	if C.panel then
		C.panel:Hide()
	end
end

-- Lays the bar out, places it and shows it, or hides it. Only out of combat (C.Apply).
function C.Lay()
	if not ns.Enabled(KEY) then
		C.Retire("off")
		return
	end
	local wanted = C.Wanted()
	if (#wanted == 0 and not wanted.plus) or not C.Build() or C.broken then
		C.Retire("empty")
		return
	end
	C.Layout(wanted)
	if C.broken or (#C.shown == 0 and not wanted.plus) then
		C.Retire("empty")
		return
	end
	C.Place()
	C.panel:Show()
end

-- A layout in a fight waits for its end, once however many come. Should the game still say it is in a fight then, PLAYER_REGEN_ENABLED of the
-- module applies it. A module that stopped in the fight only hides the bar.
function C.Queue()
	if C.queued then
		return
	end
	C.queued = true
	ns.OutOfCombat(function()
		if Fighting() then
			return
		end
		C.queued = false
		if ns.IsStopped(KEY) then
			pcall(C.Retire, "off")
		else
			ns.Try(KEY, C.Apply)
		end
	end)
end

-- True when a layout now would change the bar: the module off while it shows, or other buttons, look or spot.
function C.WouldChange()
	if not ns.Enabled(KEY) then
		return C.laid ~= "off" and C.panel ~= nil and C.panel:IsShown()
	end
	return C.placed == nil or C.laid ~= C.LayoutKey(C.Wanted())
end

-- What the rows, the list, the bags and the spot ask for: the bar is laid out out of combat, else when the fight ends, and the counts, the greying
-- and the sweeps follow at once. tell: a change of the player's, which says once a fight in chat that the bar waits.
function C.Apply(tell)
	if Fighting() then
		if tell and not C.told and C.WouldChange() then
			C.told = true
			print(K.WAIT_LINE)
		end
		C.Queue()
	else
		C.Lay()
	end
	C.Paint()
end

-- Drawing -----------------------------------------------------------------------------------------------------------------------------------------

-- The background of a button: the Background colour of the Flat UI page, a little lighter under the mouse, as Group tools has it.
function C.Shade(entry)
	if entry.hover then
		local r, g, b = ns.Colour("general.backdrop")
		ns.SetOutlineFill(entry.outline, math.min(1, r + K.LIGHTER), math.min(1, g + K.LIGHTER), math.min(1, b + K.LIGHTER), 1)
	else
		ns.SetOutlineFill(entry.outline, nil, nil, nil, nil)
	end
end

-- The sweep of a button from its item's cooldown, set only when it changed; a withheld answer keeps the sweep there is.
function C.Sweep(entry)
	if entry.sample or not entry.id then
		return
	end
	local start, duration = C.Cooldown(entry.id)
	if start == nil then
		return
	end
	local key = duration > 0 and ("%.3f:%.3f"):format(start, duration) or "none"
	if entry.cd == key then
		return
	end
	entry.cd = key
	if duration > 0 then
		pcall(entry.cooldown.SetCooldown, entry.cooldown, start, duration)
	else
		pcall(entry.cooldown.Clear, entry.cooldown)
	end
end

-- The tint of a button's icon: the game's colours of an item that cannot be used now, or that lacks mana; white otherwise and while it has none.
function C.Tint(entry)
	local colour
	if not entry.sample and not entry.empty and entry.id then
		local ok, usable, noMana = pcall(Api("C_Item", "IsUsableItem") or IsUsableItem, entry.id)
		if ok and not IsSecret(usable) and not IsSecret(noMana) and usable == false then
			colour = noMana == true and K.NO_MANA or K.UNUSABLE
		end
	end
	colour = colour or K.WHITE
	entry.texture:SetVertexColor(colour[1], colour[2], colour[3])
end

-- The first key bound to a button's binding, short as action bars write it (ns.HotkeyText), or nil.
function C.KeyOf(index)
	if index > BOUND then
		return nil
	end
	local key = Ask(GetBindingKey, ("CLICK %s%d:LeftButton"):format(BUTTON, index))
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local text = Ask(GetBindingText, key, 1)
	text = type(text) == "string" and text ~= "" and text or key
	return type(ns.HotkeyText) == "function" and ns.HotkeyText(text) or text
end

-- Draws a button: its icon, grey and dim with none left (hidden with Leave a gap), its count, key, tint and sweep, its background, and its tooltip
-- again while the mouse is over it. Only frames and regions of the addon's own that are no secure buttons change, so in a fight too.
function C.PaintEntry(entry)
	local id = entry.id
	if not id then
		return
	end
	local count
	if entry.sample then
		count = entry.sampleCount or 0
	else
		count = C.Count(id) or entry.lastCount or 0
	end
	entry.lastCount = count
	local empty = count <= 0
	entry.empty = empty
	entry.frame:SetShown(not (empty and entry.list and Opt("empty") == "hide"))
	local icon = C.Icon(id)
	if entry.shownIcon ~= icon then
		entry.shownIcon = icon
		entry.texture:SetTexture(icon)
	end
	entry.texture:SetDesaturated(empty)
	entry.texture:SetAlpha(empty and K.EMPTY_ALPHA or 1)
	C.Tint(entry)
	local text = entry.countText
	if text then
		if Opt("count") ~= false and (count > 1 or empty or entry.list or entry.sample) then
			local colour = empty and K.RED or K.WHITE
			text:SetText(tostring(math.floor(count)))
			text:SetTextColor(colour[1], colour[2], colour[3], 1)
		else
			text:SetText("")
		end
	end
	if entry.keyText then
		entry.keyText:SetText(C.KeyOf(entry.index) or "")
	end
	C.Sweep(entry)
	C.Shade(entry)
	if entry.hover and C.Owned(entry) then
		C.Tip(entry)
	end
end

function C.Paint()
	for _, entry in ipairs(C.shown) do
		C.PaintEntry(entry)
	end
	if C.plus then
		C.Shade(C.plus)
	end
	C.Fade()
end

function C.Sweeps()
	for _, entry in ipairs(C.shown) do
		C.Sweep(entry)
	end
end

function C.Tints()
	for _, entry in ipairs(C.shown) do
		C.Tint(entry)
	end
end

-- Fade out of a fight: the icons at Faded opacity out of a fight while the mouse is over no button, else full. Icons only, so in a fight too.
function C.Fade()
	local alpha = 1
	if Opt("fade") == true and not C.fighting and not C.hover then
		alpha = math.max(0, math.min(100, Number("fadeAlpha", 40))) / 100
	end
	for _, entry in ipairs(C.shown) do
		entry.frame:SetAlpha(alpha)
	end
	if C.plus then
		C.plus.frame:SetAlpha(alpha)
	end
end

-- The tooltip ----------------------------------------------------------------------------------------------------------------------------------

function C.Tooltip()
	local tip = _G.GameTooltip
	if tip == nil or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

-- The frame a button's tooltip is owned by: its secure button, which stays where it is while its icon hides.
local function Owner(entry)
	return entry.plus and entry.frame or entry.cover
end

function C.Owned(entry)
	local tip = C.Tooltip()
	if not tip then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, Owner(entry))
	return ok and not IsSecret(owned) and owned == true
end

-- Where a tooltip opens: above the bar in the lower half of the screen, below it in the upper half, as Group tools has it.
function C.Anchor()
	local ok, _, y = pcall(C.panel.GetCenter, C.panel)
	local okHeight, height = pcall(UIParent.GetHeight, UIParent)
	if ok and okHeight and Finite(y) and Finite(height) and y < height / 2 then
		return "ANCHOR_TOP"
	end
	return "ANCHOR_BOTTOM"
end

-- The lines under the item's own tooltip.
function C.Lines(entry)
	local lines, warm = {}, {}
	if entry.plus then
		return "Drop a consumable here", { "It goes at the end of your list of the consumables bar." }, warm
	end
	if entry.sample then
		lines[1] = "Sample: your consumables show here while test mode is on."
		return nil, lines, warm
	end
	if entry.empty then
		lines[#lines + 1] = "None in your bags."
		warm[#lines] = true
	end
	if entry.list then
		lines[#lines + 1] = ("Number %d of your list. Shift+right-click: off your list."):format(entry.place or 0)
		lines[#lines + 1] = "Drop a consumable here to put it in this place."
	else
		lines[#lines + 1] = "Shift+right-click: onto your list."
	end
	local key = C.KeyOf(entry.index)
	if key then
		lines[#lines + 1] = "Key: " .. key
	end
	return nil, lines, warm
end

-- Writes the tooltip of a button: the item's own, then its lines; the + slot's title and line.
function C.Tip(entry)
	local tip = C.Tooltip()
	if not tip then
		return
	end
	local title, lines, warm = C.Lines(entry)
	pcall(function()
		tip:SetOwner(Owner(entry), C.Anchor())
		if title then
			tip:SetText(title, 1, 1, 1)
		elseif entry.id then
			tip:SetItemByID(entry.id)
		end
		for index, line in ipairs(lines) do
			local colour = warm[index] and K.WARN or K.DIM
			tip:AddLine(line, colour[1], colour[2], colour[3], true)
		end
		tip:Show()
	end)
end

function C.Enter(entry)
	entry.hover = true
	C.hover = entry
	C.Fade()
	C.Shade(entry)
	C.Tip(entry)
end

function C.Leave(entry)
	if not entry.hover then
		return
	end
	entry.hover = false
	if C.hover == entry then
		C.hover = nil
	end
	C.Fade()
	C.Shade(entry)
	if C.Owned(entry) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
end

-- Clicks and drops ------------------------------------------------------------------------------------------------------------------------------

-- True right after a drop on this button: the click that may follow it is no use of the item.
function C.Recent(entry)
	local recent = C.recent
	return recent ~= nil and recent.entry == entry and Now() - recent.at < K.RECENT
end

-- Before the game's secure code runs a left click, out of combat: with an item on the cursor (or right after a drop here) the button loses its type
-- for this click, so it drops and uses nothing. The PostClick gives the type back.
function C.PreClick(entry, button)
	entry.held = false
	if button ~= "LeftButton" or not entry.armed or Fighting() then
		return
	end
	if C.CursorItem() or C.Recent(entry) then
		if pcall(entry.cover.SetAttribute, entry.cover, "*type1", nil) then
			entry.held = true
		end
	end
end

-- After the game's secure code ran a click: the type back after a drop, the item on the cursor taken, Shift+right-click on or off the list, and a
-- line for a click on an item with none. A fight cannot start between the PreClick and this, which run in one click; if the game refuses the write,
-- the next layout gives the type back.
function C.PostClick(entry, button)
	if entry.held then
		entry.held = false
		if Fighting() or not pcall(entry.cover.SetAttribute, entry.cover, "*type1", "item") then
			entry.armed = nil
			C.Queue()
		end
	end
	if button == "RightButton" then
		if Ask(IsShiftKeyDown) == true and entry.id and not entry.sample then
			local _, line
			if entry.list then
				_, line = C.Remove(entry.id)
			else
				_, line = C.Insert(entry.id)
			end
			print("Flat UI: " .. line)
		end
		return
	end
	if C.CursorItem() then
		C.Drop(entry)
	elseif not C.Recent(entry) and entry.id and not entry.sample and entry.empty then
		C.SayNone(entry.id)
	end
end

-- "Flat UI: no Major Healing Potion in your bags.", at most once in NONE_GAP seconds for an item.
function C.SayNone(id)
	local now, last = Now(), C.none[id]
	if last and now - last < K.NONE_GAP and now >= last then
		return
	end
	C.none[id] = now
	print(K.NONE_LINE:format(C.Called(id)))
end

-- The item on the cursor goes on the list: at the place of a button of the list, else at the end. Out of combat only; the item goes back to its bag
-- once it is taken. A drop and the click that may come with it are one drop: the second is passed over (C.Recent), so a refusal is said once.
function C.Drop(entry)
	local id = C.CursorItem()
	if not id or C.Recent(entry) then
		return
	end
	if Fighting() then
		if not C.saidDrop then
			C.saidDrop = true
			print(K.FIGHT_DROP)
		end
		return
	end
	C.recent = { entry = entry, at = Now() }
	-- The + slot is the end of the list, so an item of the list dropped there moves to the end.
	local at = entry.list and entry.place or (entry.plus and #C.List() + 1) or nil
	local ok, line = C.Insert(id, at)
	if ok then
		pcall(ClearCursor)
	end
	print("Flat UI: " .. line)
end

-- The module ---------------------------------------------------------------------------------------------------------------------------------

function C.Refresh()
	C.fighting = Fighting()
	C.Apply(true)
end

-- At login, at a resize and as the module comes on: nothing is said in chat for a layout that waits.
function C.Start()
	C.fighting = Fighting()
	C.placed = nil
	C.Apply(false)
end

-- The bags changed, or a loading screen ended: they are read again.
function C.BagsChanged()
	C.scanned = nil
	C.Apply(false)
end

-- An item the bar asked for came: its name sorts and names it, once for a burst.
function C.Received(id)
	C.pending[id] = nil
	if C.soon then
		return
	end
	C.soon = true
	if not After(K.SOON, function()
		C.soon = false
		if ns.Enabled(KEY) then
			ns.Try(KEY, C.BagsChanged)
		end
	end) then
		C.soon = false
		C.BagsChanged()
	end
end

-- The cursor took or let go of an item: the + slot comes or goes, out of combat.
function C.CursorChanged()
	if not Fighting() then
		C.Apply(false)
	end
end

-- A fight starts: the icons are full, and the + slot goes.
function C.FightStarts()
	C.fighting = true
	if C.plus and C.plus.frame:IsShown() then
		C.plus.frame:Hide()
		C.laid = nil
	end
	C.Fade()
end

-- The end of a fight: a change that still waits is applied, should the game have said it was in a fight when ns.OutOfCombat ran it; should it still
-- say so now, the change waits again.
function C.AfterFight()
	C.fighting, C.told, C.saidDrop = false, false, false
	C.queued = false
	C.Apply(false)
end

function C.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if C.broken then
		lines[#lines + 1] = K.LINE_BROKEN
	end
	if C.queued then
		lines[#lines + 1] = K.LINE_WAITING
	end
	local listed = 0
	for _, entry in ipairs(C.shown) do
		if entry.list then
			listed = listed + 1
		end
	end
	lines[#lines + 1] = K.LINE_COUNT:format(#C.shown, listed, #C.List())
	return lines
end

-- The rows of the page ------------------------------------------------------------------------------------------------------------------------

-- Add an item: the consumables in the bags that are not on the list, in the bar's order, with how many you carry. Every kind, whatever Kinds in
-- your bags says. While the module does not run, no bag event reaches it, so the bags are read again for each opening of the list.
function ns.ConsumeBarCandidates()
	if not ns.ModuleOn(KEY) then
		C.scanned = nil
	end
	local rows = {}
	for _, id in ipairs(C.Scan()) do
		if not C.Listed(id) then
			rows[#rows + 1] = { id, ("%s (%d)"):format(C.Called(id), C.Count(id) or 0) }
		end
	end
	return rows
end

-- The items of the list, numbered in order.
function ns.ConsumeBarListed()
	local rows = {}
	for index, id in ipairs(C.List()) do
		rows[#rows + 1] = { id, ("%d. %s"):format(index, C.Called(id)) }
	end
	return rows
end

-- These work in combat and with the page off; the bar follows when it can (C.ListChanged).
function ns.ConsumeBarAdd(id)
	return C.Insert(id)
end

function ns.ConsumeBarRemove(id)
	return C.Remove(id)
end

function ns.ConsumeBarLeft(id)
	return C.Move(id, -1)
end

function ns.ConsumeBarRight(id)
	return C.Move(id, 1)
end

-- The movers -----------------------------------------------------------------------------------------------------------------------------------

-- True while the bar has a handle in the movers: while the module is on, shown or not.
function ns.ConsumeBarShown()
	return ns.Enabled(KEY)
end

-- The movers set or put back the spot: the bar moves there out of combat.
function ns.ConsumeBarMoved()
	C.placed = nil
	if C.panel and ns.Enabled(KEY) then
		ns.Try(KEY, C.Apply, true)
	end
end

-- The names of the key bindings in the game's Key Bindings, under Flat UI (Bindings.xml).
for index = 1, BOUND do
	_G[("BINDING_NAME_CLICK %s%d:LeftButton"):format(BUTTON, index)] = ("Consumables bar button %d"):format(index)
end

ns.Register(KEY, {
	label = LABEL,
	counted = false,
	Start = C.Start,
	Refresh = C.Refresh,
	Resized = C.Start,
	Status = C.Status,
	events = {
		BAG_UPDATE_DELAYED = C.BagsChanged,
		PLAYER_ENTERING_WORLD = C.BagsChanged,
		BAG_UPDATE_COOLDOWN = C.Sweeps,
		SPELL_UPDATE_USABLE = C.Tints,
		PLAYER_LEVEL_UP = C.Tints,
		GET_ITEM_INFO_RECEIVED = C.Received,
		CURSOR_CHANGED = C.CursorChanged,
		UPDATE_BINDINGS = C.Paint,
		PLAYER_REGEN_DISABLED = C.FightStarts,
		PLAYER_REGEN_ENABLED = C.AfterFight,
	},
	filters = {
		-- Only an item the bar asked for, and the cursor only while the + slot can show.
		GET_ITEM_INFO_RECEIVED = function(id)
			return not IsSecret(id) and C.pending[id] == true
		end,
		CURSOR_CHANGED = function()
			return C.Mode() ~= "bags"
		end,
	},
})

-- Test mode: On, Off and a pause refresh the page, which shows the samples while the bar would show no button, out of combat (C.Wanted).
if ns.TestMode then
	ns.TestMode.Register(KEY, { module = KEY, label = LABEL, refresh = true })
end
