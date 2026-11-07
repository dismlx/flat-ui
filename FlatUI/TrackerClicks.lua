local _, ns = ...

-- Click to apply: out of combat, a click on a tracker fixes what it shows. A group buff tracker (TrackerGroup.lua) casts its buff on a member who
-- lacks it, and a weapon tracker puts a poison, stone or oil on its weapon. This follows the click-to-apply icons of the Class Buff Reminder of
-- EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLClassBuffReminder/ClassBuffReminder.lua:1960-2063): a secure
-- button over the icon, given its attributes out of combat. Where EnhanceQoL writes a macro that uses the item and then the hand's slot, the
-- button here has the item and the slot as attributes of the template's own, and runs no macro text. An item tracker takes no click: it counts
-- an item in the bags (C_Item.GetItemCount, ItemDocumentation.lua:451-468; TrackerKinds.lua:1121-1153), and a use (type item, below) only
-- lowers that count, so a click on a Healthstone or Mana gem tracker that is fine would spend the stone or the gem, and one that is missing has
-- nothing to use. EnhanceQoL's healthstone icon likewise shows only while the bags hold no stone, and its click casts Create Healthstone
-- (ClassBuffReminder.lua:3827-3839).
-- The click is a secure button of Flat UI's own (SecureActionButtonTemplate), made as Reload.lua:93 and ErrandsRanks.lua:510 make theirs: made,
-- shown, hidden, moved and given attributes only out of combat. It lies over a tracker's frame, as its child, only while the tracker is drawn
-- live and shown and has something to fix. A secure child makes the frames above it protected (Reload.lua:14-17), so at PLAYER_REGEN_DISABLED,
-- before the lockdown, every button leaves its tracker as Reload.lua's Detach does: hidden, its points cleared, its parent UIParent. Nothing of
-- the trackers is protected in a fight, and nothing on the buttons changes there. The game's secure code does the rest (Blizzard_FrameXML/
-- SecureTemplates.lua): type spell casts the spell attribute by name on the unit attribute (396-405), type item uses an item string through
-- C_Item.UseItemByName (418-439; Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua:1212-1236), and target-slot then puts what the item asks a
-- target for on that inventory slot, in the same click (759-784). The button takes the release of the left button (useOnKeyDown false, 802-829).
-- PreClick, which runs before that code and out of combat, chooses again from what the bags, the spell book and the group hold now, and takes the
-- type away when nothing is left to do, as ErrandsRanks.lua's PreClick does (754-770). No field is written on a button and none of the game's
-- frames is touched; the button reads and writes nothing of the click path of the game's action buttons (TaintScan.lua). Only GameTooltip is
-- written, the lines of the button's own tooltip while the mouse is over it.

local KEY = "trackers"
local IsSecret = ns.IsSecret

-- SLOTS: the inventory slot of each weapon tracker's hand (INVSLOT_MAINHAND, INVSLOT_OFFHAND, INVSLOT_RANGED, Blizzard_FrameXMLBase/
-- Constants.lua:151-153) and its words. CONSUMABLES: the weapon poisons, sharpening stones, weightstones and oils a weapon tracker with none of
-- its own in the bags uses, each kind from its strongest; the class lists of ClassData.lua name the strongest of some, and every ID was checked
-- against the classic item table of Questie (classicItemDB 10.0.0). A click uses only one the bags hold. KINDS: by the saved word of the Click to
-- apply row, the kinds of tracker that take a click. ATTRIBUTES: the attributes a click sets; the others stay as the template has them.
-- EDGED: the sharpening stones that only an edged weapon takes, and EDGES the subclasses of an edged weapon; BLUNT: the weightstones that only a
-- blunt weapon takes, and BLUNTS the subclasses of a blunt one (Enum.ItemWeaponSubclass, ItemConstantsDocumentation.lua:618-648). The game puts
-- the spell of such an item only on a weapon whose subclass is in the spell's mask (SpellEquippedItems of the classic era tables, build
-- 1.15.7.61582; the table that JustAC generates from Forever's own client data gives the same masks, Data/ForeverConsumables.lua:208-243):
-- Sharpen Blade I to V (2828, 2829, 2830, 9900, 16138), the spells of the Rough to the Dense Sharpening Stone and of Forever's second Rough
-- Sharpening Stone, 287978, have mask 33219, the one- and two-handed axes and swords, polearms and daggers; Enhance Blunt Weapon I to V (3112,
-- 3113, 3114, 9903, 16622), the spells of the Rough to the Dense Weightstone, have mask 9264, the one- and two-handed maces, staves and fist
-- weapons. The Elemental Sharpening Stone (its spell 22756, mask 42483, also that of Forever's second one, 287980), the Consecrated Sharpening
-- Stone (28891, mask 1097203), the poisons and the oils take every melee weapon, and are in neither list. WEAPON: the item class of a weapon
-- (Enum.ItemClass.Weapon, ItemConstantsDocumentation.lua:278).
local K = {
	SLOTS = { main = { 16, "main hand" }, off = { 17, "off hand" }, ranged = { 18, "ranged weapon" } },
	EDGED = { [12404] = true, [7964] = true, [2871] = true, [2863] = true, [2862] = true, [287978] = true },
	EDGES = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [15] = true },
	BLUNT = { [12643] = true, [7965] = true, [3241] = true, [3240] = true, [3239] = true },
	BLUNTS = { [4] = true, [5] = true, [10] = true, [13] = true },
	WEAPON = 2,
	CONSUMABLES = {
		-- Instant Poison VI to I, Deadly Poison V to I, Wound Poison IV to I, Mind-numbing Poison III to I, Crippling Poison II and I.
		8928, 8927, 8926, 6950, 6949, 6947, 20844, 8985, 8984, 2893, 2892, 10922, 10921, 10920, 10918, 9186, 6951, 5237, 3776, 3775,
		-- Consecrated, Elemental, Dense, Solid, Heavy, Coarse and Rough Sharpening Stone; Dense, Solid, Heavy, Coarse and Rough Weightstone.
		23122, 18262, 12404, 7964, 2871, 2863, 2862, 12643, 7965, 3241, 3240, 3239,
		-- Blessed, Brilliant, Wizard, Lesser and Minor Wizard Oil; Brilliant, Lesser and Minor Mana Oil; Shadow Oil and Frost Oil.
		23123, 20749, 20750, 20746, 20744, 20748, 20747, 20745, 3824, 3829,
	},
	KINDS = { none = {}, group = { group = true }, all = { group = true, weapon = true } },
	ATTRIBUTES = { "type", "spell", "unit", "item", "target-slot" },
	REFUSED = "Trackers: the game would not make a secure button, so a click on a tracker does nothing.",
	MAX_ID = 2147483647, LEVEL = 10,
	USAGE = "/flatui tracker use 1 Instant Poison - the item a click on weapon tracker 1 puts on the weapon, or clear for the first one the bags hold",
}
-- buttons: the button of each tracker that has one, by the id of its entry; free: buttons no tracker has. owner, set, parent, shown and level, by
-- button: the id it is for, the attributes it was given, the frame it lies over, whether it is shown and the frame level it was given. fighting:
-- between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED. refused: the game would not make a button.
local S = {
	buttons = {}, free = {}, owner = setmetatable({}, { __mode = "k" }), set = setmetatable({}, { __mode = "k" }),
	parent = setmetatable({}, { __mode = "k" }), shown = setmetatable({}, { __mode = "k" }), level = setmetatable({}, { __mode = "k" }),
	fighting = false, watcher = nil, refused = false,
}

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Whole(value)
	return Plain(value, "number") and value >= 1 and value <= K.MAX_ID and value == math.floor(value)
end

-- The first answer of a game call, or nil when the call is missing, raises or is withheld.
local function Ask(call, ...)
	if type(call) ~= "function" then
		return nil
	end
	local ok, answer = pcall(call, ...)
	if ok and not IsSecret(answer) then
		return answer
	end
	return nil
end

local function Items()
	return type(C_Item) == "table" and C_Item or {}
end

-- True when the bags hold the item (C_Item.GetItemCount, ItemDocumentation.lua:451-468).
local function Carried(id)
	local count = Ask(Items().GetItemCount, id, false, false)
	return Plain(count, "number") and count > 0
end

local function ItemName(id)
	local name = Ask(Items().GetItemNameByID, id)
	return Plain(name, "string") and name ~= "" and name or ("item " .. id)
end

local function SpellName(id)
	local name = Ask(type(C_Spell) == "table" and C_Spell.GetSpellName, id)
	return Plain(name, "string") and name ~= "" and name or nil
end

-- True when the player knows the spell (SpellBookDocumentation.lua:738-770).
local function Known(id)
	local book = type(C_SpellBook) == "table" and C_SpellBook or {}
	return Ask(book.IsSpellKnown, id) == true or Ask(book.IsSpellKnownOrInSpellBook, id) == true
end

-- True when the spell has a place in the player's spell book (C_SpellBook.FindSpellBookSlotForSpell, SpellBookDocumentation.lua:73-93), as a
-- class spell has. A profession's recipe the player has learnt is a spell the player knows, but it is not in the spell book.
local function InBook(id)
	local book = type(C_SpellBook) == "table" and C_SpellBook or {}
	return Plain(Ask(book.FindSpellBookSlotForSpell, id), "number")
end

-- What a click does --------------------------------------------------------------------------------------------------------------------

local function PutOn(id, slot)
	return { type = "item", item = "item:" .. id, ["target-slot"] = slot[1] }, ("puts %s on your %s"):format(ItemName(id), slot[2])
end

local function Cast(id)
	local name = SpellName(id)
	if not name then
		return nil
	end
	return { type = "spell", spell = name }, ("casts %s"):format(name)
end

-- The subclass of the weapon in the hand's slot (GetInventoryItemID, and the class and subclass, the sixth and seventh answers of
-- C_Item.GetItemInfoInstant, ItemDocumentation.lua:659-680), or nil when the slot holds no weapon or the game does not say.
local function Held(slot)
	local ok, id = pcall(GetInventoryItemID, "player", slot[1])
	if not ok or not Whole(id) then
		return nil
	end
	local got, _, _, _, _, _, class, subclass = pcall(Items().GetItemInfoInstant, id)
	if got and Plain(class, "number") and class == K.WEAPON and Plain(subclass, "number") then
		return subclass
	end
	return nil
end

-- True when the weapon held takes the item: a sharpening stone of EDGED only an edged weapon, a weightstone of BLUNT only a blunt one, any other
-- item every weapon. A weapon the game does not name is taken to take every item.
local function Fits(id, held)
	if held == nil then
		return true
	elseif K.EDGED[id] then
		return K.EDGES[held] == true
	elseif K.BLUNT[id] then
		return K.BLUNTS[held] == true
	end
	return true
end

-- A weapon tracker: the item or spell set with /flatui tracker use, else the spell of its list that last put an enchant on the hand (a shaman's
-- imbue, kept in the entry as applied by TrackerKinds.lua), else the last spell of its list the player knows and has in the spell book (the
-- newest last in the class list), else the first item of its list in the bags, else the strongest weapon poison, stone or oil in the bags (not
-- for a ranged weapon, which takes none). An item the weapon in the hand cannot take is passed over (Fits). A shaman's list holds spell IDs and
-- the other class lists hold item IDs, and one ID can be both. Taken as an item, an imbue's ID has the click equip or use that item in place of
-- the imbue: type item equips an item that can be worn and is not worn yet, and uses any other (Blizzard_FrameXML/SecureTemplates.lua:431-437).
-- Rockbiter Weapon rank 4 and the Blackened Defias Armor are both 10399, Flametongue Weapon rank 3 and the Plans: Ebon Shiv both 8030,
-- Flametongue Weapon rank 5 and the Sergeant's Cloak both 16341. So the spells come first: every shaman has Rockbiter Weapon from level 1, and a
-- shaman's list never gets to its items. Taken as a spell, an item's ID has the click cast that spell: Crippling Poison II and the Leatherworking
-- recipe Green Leather Bracers are both 3776, the Greater Firestone and the Enchanting recipe Enchant Chest - Lesser Stats both 13700, and a
-- learnt recipe is a known spell. So a spell counts only from the spell book, which holds no recipe. Instant Poison VI, 8928, is also the
-- druid's Moonfire, a rogue never has.
local function Weapon(entry)
	local slot = K.SLOTS[entry.slot]
	if not slot then
		return nil
	end
	local held = Held(slot)
	if Whole(entry.use) and Carried(entry.use) and Fits(entry.use, held) then
		return PutOn(entry.use, slot)
	end
	if Whole(entry.useSpell) and Known(entry.useSpell) then
		return Cast(entry.useSpell)
	end
	if Whole(entry.applied) and Known(entry.applied) then
		return Cast(entry.applied)
	end
	local apply = type(entry.apply) == "table" and entry.apply or {}
	local spell
	for _, id in ipairs(apply) do
		if Whole(id) and Known(id) and InBook(id) then
			spell = id
		end
	end
	if spell then
		return Cast(spell)
	end
	for _, id in ipairs(apply) do
		if Whole(id) and Carried(id) and Fits(id, held) then
			return PutOn(id, slot)
		end
	end
	if entry.slot ~= "ranged" then
		for _, id in ipairs(K.CONSUMABLES) do
			if Carried(id) and Fits(id, held) then
				return PutOn(id, slot)
			end
		end
	end
	return nil
end

-- The attributes a click on the tracker sets now and what it does in words ("casts Arcane Intellect on Jaina"), or nil when there is nothing to do.
-- With now set (a click, the mouse over the button) a group is looked at afresh; a pass takes the look the tracker was drawn from.
local function Choose(entry, now)
	if entry.kind == "weapon" then
		return Weapon(entry)
	elseif entry.kind == "group" and type(ns.TrackerGroupChoice) == "function" then
		return ns.TrackerGroupChoice(entry, now)
	end
	return nil
end

-- The kind takes a click: the page is on, the tracker is on and the Click to apply row names its kind.
local function Allowed(entry)
	local kinds = K.KINDS[ns.Get(KEY .. ".click")] or K.KINDS.none
	return ns.Enabled(KEY) and entry.on ~= false and kinds[entry.kind] == true
end

-- The tracker has something a click fixes, as it is drawn now: live and shown, a weapon or group buff that is low or missing.
local function Fixable(entry, reading, how, record)
	if how ~= "live" or type(record) ~= "table" or record.alpha ~= 1 or type(reading) ~= "table" then
		return false
	end
	local state = reading.state
	return state == "low" or state == "missing"
end

local function Find(id)
	for _, entry in ipairs(id and type(ns.TrackerEntries) == "function" and ns.TrackerEntries() or {}) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- The buttons ----------------------------------------------------------------------------------------------------------------------------

-- Gives the button the attributes of a click, or takes them all away with nil; only the ones that change are set. Out of combat only.
local function Give(button, action)
	local set = S.set[button]
	for _, key in ipairs(K.ATTRIBUTES) do
		local value = action and action[key] or nil
		if set[key] ~= value and pcall(button.SetAttribute, button, key, value) then
			set[key] = value
		end
	end
end

-- The button leaves the frame it lies over: hidden, its points cleared, its parent UIParent, as Reload.lua:15-24 does before a fight.
local function Detach(button)
	if S.parent[button] == nil and not S.shown[button] then
		return
	end
	pcall(function()
		button:Hide()
		button:ClearAllPoints()
		button:SetParent(UIParent)
	end)
	S.parent[button], S.shown[button], S.level[button] = nil, nil, nil
end

local function DetachAll()
	if InCombatLockdown() then
		return
	end
	for _, button in pairs(S.buttons) do
		Detach(button)
	end
end

-- The button lies over the frame and above its parts (the sweep, the count, a bar's plate), and is shown.
local function Attach(button, frame)
	if S.parent[button] ~= frame then
		Detach(button)
		local ok = pcall(function()
			button:SetParent(frame)
			button:SetAllPoints(frame)
		end)
		if not ok then
			Detach(button)
			return
		end
		S.parent[button] = frame
	end
	local got, level = pcall(frame.GetFrameLevel, frame)
	if got and Plain(level, "number") and ns.Finite(level) and S.level[button] ~= level + K.LEVEL then
		if pcall(button.SetFrameLevel, button, level + K.LEVEL) then
			S.level[button] = level + K.LEVEL
		end
	end
	if not S.shown[button] and pcall(button.Show, button) then
		S.shown[button] = true
	end
end

local function Watch()
	if S.watcher then
		return
	end
	local ok, frame = pcall(CreateFrame, "Frame")
	if not ok or type(frame) ~= "table" then
		return
	end
	ns.Own[frame] = true
	S.watcher = frame
	S.fighting = InCombatLockdown() and true or false
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
	-- The lockdown starts after PLAYER_REGEN_DISABLED is handled, so the buttons can still leave their trackers; the next pass after the fight
	-- brings them back (Trackers.lua asks for one at PLAYER_REGEN_ENABLED).
	frame:SetScript("OnEvent", function(_, event)
		S.fighting = event == "PLAYER_REGEN_DISABLED"
		if S.fighting then
			DetachAll()
		end
	end)
end

-- The tooltip of the button: the tracker and what a click does now. Only GameTooltip is written, and only while the mouse is over the button.
local function Enter(button)
	local tip = GameTooltip
	local entry = Find(S.owner[button])
	if type(tip) ~= "table" or ns.Forbidden(tip) or not entry or S.fighting or InCombatLockdown() then
		return
	end
	local _, text = Choose(entry, true)
	pcall(function()
		tip:SetOwner(button, "ANCHOR_TOP")
		tip:SetText(type(ns.TrackerLabel) == "function" and ns.TrackerLabel(entry) or "Tracker", 1, 1, 1)
		tip:AddLine(text and ("A click " .. text .. ".") or "Nothing to do now.", 0.8, 0.8, 0.8, true)
		tip:Show()
	end)
end

local function Leave(button)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	if ok and not IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

-- Out of combat, before the game's secure code runs the click: the attributes of what is to be done now, or none when nothing is.
local function PreClick(button)
	if S.fighting or InCombatLockdown() then
		return
	end
	local entry = Find(S.owner[button])
	local action = nil
	if entry and Allowed(entry) then
		action = Choose(entry, true)
	end
	Give(button, action)
end

-- A button for the tracker: a free one, or a new one made out of combat. Nil when the game refuses one, which is said once in the status.
local function Make(id)
	local button = table.remove(S.free)
	if not button then
		if S.refused or InCombatLockdown() then
			return nil
		end
		local ok, made = pcall(CreateFrame, "Button", nil, UIParent, "SecureActionButtonTemplate")
		if not ok or type(made) ~= "table" then
			S.refused = true
			ns.Note(KEY, K.REFUSED)
			return nil
		end
		local done = pcall(function()
			ns.Own[made] = true
			made:Hide()
			made:RegisterForClicks("LeftButtonUp")
			-- The game runs a click on the key press by default (ActionButtonUseKeyDown); the button listens for the release.
			made:SetAttribute("useOnKeyDown", false)
			made:SetScript("PreClick", PreClick)
			made:SetScript("OnEnter", Enter)
			made:SetScript("OnLeave", Leave)
		end)
		if not done then
			pcall(made.Hide, made)
			S.refused = true
			ns.Note(KEY, K.REFUSED)
			return nil
		end
		S.set[made] = {}
		button = made
		Watch()
	end
	S.buttons[id], S.owner[button] = button, id
	return button
end

-- The tracker's button goes back to the free ones, with no attributes and over nothing.
local function Release(id)
	local button = S.buttons[id]
	if not button then
		return
	end
	S.buttons[id], S.owner[button] = nil, nil
	Detach(button)
	Give(button, nil)
	S.free[#S.free + 1] = button
end

-- What Trackers.lua calls --------------------------------------------------------------------------------------------------------------

-- After a tracker is drawn: its button lies over it with the attributes of what a click does now, or it has none. Nothing in a fight: fighting is
-- the trackers' own word for it, set at PLAYER_REGEN_DISABLED before their pass, so a pass at the start of a fight makes no button.
function ns.TrackerClickStep(entry, reading, how, record, fighting)
	if fighting or S.fighting or InCombatLockdown() or type(entry) ~= "table" or type(entry.id) ~= "string" then
		return
	end
	local action
	if Allowed(entry) and Fixable(entry, reading, how, record) then
		action = Choose(entry)
	end
	if not action then
		Release(entry.id)
		return
	end
	local button = S.buttons[entry.id] or Make(entry.id)
	if button then
		Give(button, action)
		Attach(button, record.frame)
	end
end

-- Once per pass, with the trackers that are on (none while the page is off): the buttons of the others are freed. Out of the lockdown only; at
-- the start of a fight it only hides and frees, as the watcher does.
function ns.TrackerClickSweep(entries)
	if InCombatLockdown() then
		return
	end
	local on = {}
	for _, entry in ipairs(ns.Enabled(KEY) and type(entries) == "table" and entries or {}) do
		on[entry.id] = true
	end
	for id in pairs(S.buttons) do
		if not on[id] then
			Release(id)
		end
	end
end

-- The line of /flatui tracker check, for a tracker of a kind that takes a click while the row lets it.
function ns.TrackerClickLine(entry)
	if type(entry) ~= "table" or not Allowed(entry) then
		return nil
	end
	local button = S.buttons[entry.id]
	if button and S.shown[button] then
		local _, text = Choose(entry)
		return "Click: " .. (text and (text .. ".") or "nothing to do now.")
	end
	return "Click: none now. A click is offered out of combat while the tracker has something to fix."
end

-- /flatui tracker use: the item a click on a weapon tracker puts on the weapon, or a spell it casts. An item by ID, link or name (the bags
-- first: C_Container.GetContainerNumSlots and GetContainerItemInfo, ContainerDocumentation.lua:192-206, 313-326), else a spell by name or ID.
local function ItemOf(text)
	local id = tonumber(text:match("^%d+$") or text:match("|Hitem:(%d+)") or text:match("^item:(%d+)"))
	if Whole(id) then
		return id
	end
	local wanted, containers = text:lower(), type(C_Container) == "table" and C_Container or {}
	local bags = Plain(NUM_BAG_SLOTS, "number") and NUM_BAG_SLOTS or 4
	for bag = 0, bags do
		local slots = Ask(containers.GetContainerNumSlots, bag)
		for slot = 1, Plain(slots, "number") and slots or 0 do
			local info = Ask(containers.GetContainerItemInfo, bag, slot)
			local item = type(info) == "table" and info.itemID
			local name = type(info) == "table" and info.itemName
			if Whole(item) and Plain(name, "string") and name:lower() == wanted then
				return item
			end
		end
	end
	local known = Ask(Items().GetItemInfoInstant, text)
	return Whole(known) and known or nil
end

local function SpellOf(text)
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	if not id then
		local info = Ask(type(C_Spell) == "table" and C_Spell.GetSpellInfo, text)
		id = type(info) == "table" and info.spellID or nil
	end
	return Whole(id) and SpellName(id) and id or nil
end

if type(ns.TrackerWord) == "function" then
	ns.TrackerWord("use", function(text)
		local number, rest = text:match("^(%d+)%s*(.-)$")
		if not number then
			return K.USAGE
		end
		local entry = (type(ns.TrackerEntries) == "function" and ns.TrackerEntries() or {})[tonumber(number)]
		if not entry then
			return ("No tracker numbered %s."):format(number)
		elseif entry.kind ~= "weapon" then
			return ("Tracker %s is not a weapon tracker."):format(number)
		end
		local function Done(line)
			if type(ns.TrackerDirty) == "function" then
				ns.TrackerDirty()
			end
			return ("Tracker %s: %s"):format(number, line)
		end
		if rest == "" or rest:lower() == "clear" then
			entry.use, entry.useSpell = nil, nil
			return Done("a click uses the first item of its list that the bags hold.")
		end
		local item = ItemOf(rest)
		if item then
			entry.use, entry.useSpell = item, nil
			return Done(("a click puts %s on the weapon."):format(ItemName(item)))
		end
		local spell = SpellOf(rest)
		if spell then
			entry.use, entry.useSpell = nil, spell
			return Done(("a click casts %s."):format(SpellName(spell)))
		end
		return ('No item or spell found for "%s".'):format(rest)
	end)
end

ns.AddStatus(KEY, function()
	local count = 0
	for _ in pairs(S.shown) do
		count = count + 1
	end
	if count == 0 or not ns.Enabled(KEY) then
		return {}
	end
	return { ("Click to apply: %d %s a click now."):format(count, count == 1 and "tracker takes" or "trackers take") }
end)
