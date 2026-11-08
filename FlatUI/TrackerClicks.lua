local _, ns = ...

-- Click to apply: out of combat, a click on a tracker fixes what it shows. A group buff tracker (TrackerGroup.lua) casts its buff on a member who
-- lacks it; a buff, stance or form tracker casts your own buff, stance or form on you; a pet tracker calls, revives, summons or sets the mode of
-- your pet; and a weapon tracker puts a poison, stone or oil on its weapon. This follows the click-to-apply icons of the Class Buff Reminder of
-- EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLClassBuffReminder/ClassBuffReminder.lua:1960-2063, the buttons
-- that cast the buff, use the item, apply it to the slot and summon the pet; 2043-2046, type pet with a pet bar slot; 3718-3760, what a pet click
-- does; 1586-1621, the item chosen for each weapon slot): a secure button over the icon, given its attributes out of combat. Where EnhanceQoL
-- writes a macro that uses the item and then the hand's slot, the button here has the item and the slot as attributes of the template's own, and
-- runs no macro text; the one macro text is a hunter's Call Pet, then Revive Pet. An item tracker takes no click: it counts
-- an item in the bags (C_Item.GetItemCount, ItemDocumentation.lua:451-468; TrackerKinds.lua:1467-1499), and a use (type item, below) only
-- lowers that count, so a click on a Healthstone or Mana gem tracker that is fine would spend the stone or the gem, and one that is missing has
-- nothing to use. EnhanceQoL's healthstone icon likewise shows only while the bags hold no stone, and its click casts Create Healthstone
-- (ClassBuffReminder.lua:3827-3839). A debuff tracker takes none either: the debuff is on the target, cast in a fight.
-- The click is a secure button of Flat UI's own (SecureActionButtonTemplate), made as Reload.lua:93 and ErrandsRanks.lua:510 make theirs: made,
-- shown, hidden, moved and given attributes only out of combat. It lies over a tracker's frame, as its child, only while the tracker is drawn
-- live and shown and has something to fix. A secure child makes the frames above it protected (Reload.lua:14-17), so at PLAYER_REGEN_DISABLED,
-- before the lockdown, every button leaves its tracker as Reload.lua's Detach does: hidden, its points cleared, its parent UIParent. Nothing of
-- the trackers is protected in a fight, and nothing on the buttons changes there. The game's secure code does the rest (Blizzard_FrameXML/
-- SecureTemplates.lua): type spell casts the spell attribute by name on the unit attribute (396-405), so a buff cast by its name is its highest
-- rank; type pet runs CastPetAction, which the game protects, with the pet bar slot of the action attribute (370-377); type macro runs the
-- macrotext attribute (450-463), as MountKey.lua's and GroupTools.lua's buttons do; type item uses an item string through
-- C_Item.UseItemByName (418-439; Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua:1212-1236), and target-slot then puts what the item asks a
-- target for on that inventory slot, in the same click (759-784). The button takes the release of the left button (useOnKeyDown false, 802-829).
-- PreClick, which runs before that code and out of combat, chooses again from what the bags, the spell book, the pet bar, the group and the
-- player's power hold now, and takes the type away when nothing is left to do, as ErrandsRanks.lua's PreClick does (754-770); the slot of a
-- pet click is read again there from the tokens of the pet bar (TrackerKinds.lua's PetModes), so a click never runs another pet action. No
-- field is written on a button and none of the game's frames is touched; the button reads and writes nothing of the click path of the game's
-- action buttons (TaintScan.lua). Only GameTooltip is written, the lines of the button's own tooltip while the mouse is over it.

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
-- SINGLE: by the ID of a group version, which uses a reagent, the first rank of the single-target buff a click casts in its place, so that a
-- group buff another player cast on you is answered with your own: Prayer of Fortitude as Power Word: Fortitude, Prayer of Spirit as Divine
-- Spirit, Prayer of Shadow Protection as Shadow Protection, Arcane Brilliance as Arcane Intellect, Gift of the Wild as Mark of the Wild, and the
-- greater blessings of Might, Wisdom, Kings, Salvation and Light as the blessings (the IDs of ClassData.lua:16, 35-37, 53, 68). DAZE: Aspect of
-- the Cheetah and Aspect of the Pack, which daze, never cast by a click (Forever's ranks 2 to 4 of Aspect of the Beast, 1299445-1299447, do not).
-- CALL, REVIVE: Call Pet and Revive Pet, the hunter's (ClassData.lua:23; ClassBuffReminder.lua:463-464). MODES: what a pet click sets, by the
-- word of TrackerKinds.lua's PetModes, and its words.
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
	KINDS = { none = {}, group = { group = true, buff = true, form = true, pet = true },
		all = { group = true, buff = true, form = true, pet = true, weapon = true } },
	ATTRIBUTES = { "type", "spell", "unit", "item", "target-slot", "action", "macrotext" },
	SINGLE = { [21562] = 1243, [21564] = 1243, [27681] = 14752, [27683] = 976, [23028] = 1459, [21849] = 1126, [21850] = 1126, [25782] = 19740,
		[25916] = 19740, [25894] = 19742, [25918] = 19742, [25898] = 20217, [25895] = 1038, [25890] = 19977 },
	DAZE = { [5118] = true, [13159] = true },
	CALL = 883, REVIVE = 982,
	MODES = { defensive = "Defensive", assist = "Assist" },
	REFUSED = "Trackers: the game would not make a secure button, so a click on a tracker does nothing.",
	MAX_ID = 2147483647, LEVEL = 10,
	USAGE = "/flatui tracker use 1 Instant Poison - the item a click on weapon tracker 1 puts on the weapon, or clear for nothing chosen",
	UNCLICKED = "a click puts nothing on a weapon unless Click to apply is Buffs, forms, the pet and weapons",
}
-- buttons: the button of each tracker that has one, by the id of its entry; free: buttons no tracker has. owner, set, parent, shown and level, by
-- button: the id it is for, the attributes it was given, the frame it lies over, whether it is shown and the frame level it was given. fighting:
-- between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED. refused: the game would not make a button. useFor: the id of the weapon tracker chosen
-- in the first step of Item a click puts on a weapon.
local S = {
	buttons = {}, free = {}, owner = setmetatable({}, { __mode = "k" }), set = setmetatable({}, { __mode = "k" }),
	parent = setmetatable({}, { __mode = "k" }), shown = setmetatable({}, { __mode = "k" }), level = setmetatable({}, { __mode = "k" }),
	fighting = false, watcher = nil, refused = false, useFor = nil,
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

-- The families of a buff tracker: the spells of its list grouped by their name (C_Spell.GetSpellName), in list order, which is the order of its
-- names, each { name, ids, has, daze }; and the family of each ID. A group version of SINGLE joins the family of its single-target buff, with that
-- buff's first rank in place of its own, so its own ID, which uses a reagent, is never known to the family. An ID is in a family once, so its
-- IDs keep the order of the ranks of the list, the newest last.
local function Families(entry)
	local families, of, named = {}, {}, {}
	for _, id in ipairs(type(entry.spells) == "table" and entry.spells or {}) do
		local cast = Whole(id) and (K.SINGLE[id] or id)
		local name = cast and SpellName(cast)
		if name then
			local family = named[name]
			if not family then
				family = { name = name, ids = {}, has = {}, daze = false }
				named[name] = family
				families[#families + 1] = family
			end
			if not family.has[cast] then
				family.has[cast] = true
				family.ids[#family.ids + 1] = cast
			end
			family.daze = family.daze or K.DAZE[id] == true
			of[id] = family
		end
	end
	return families, of
end

-- A family takes the click when it does not daze and the player knows one of its spells and has it in the spell book (a recipe is a known
-- spell that is not, as Weapon says).
local function Castable(family)
	if not family or family.daze then
		return false
	end
	for _, id in ipairs(family.ids) do
		if Known(id) and InBook(id) then
			return true
		end
	end
	return false
end

-- The newest spell of a family that the player knows and has in the spell book: the last one of its IDs, as Weapon takes the newest of its
-- list. It is the rank a cast by the family's name gives. Nil when there is none.
local function Newest(family)
	local newest = nil
	for _, id in ipairs(family and family.ids or {}) do
		if Known(id) and InBook(id) then
			newest = id
		end
	end
	return newest
end

-- True when the game plainly says that power alone keeps the player from casting the spell now: the second answer of C_Spell.IsSpellUsable,
-- insufficientPower (SpellDocumentation.lua:980-995, no withheld answers), asked by ID as Cooldowns.lua's power tint asks it. A missing call, an
-- error or a withheld answer does not stop a click.
local function Short(id)
	local call = type(C_Spell) == "table" and C_Spell.IsSpellUsable
	if not Whole(id) or type(call) ~= "function" then
		return false
	end
	local ok, _, short = pcall(call, id)
	return ok and not IsSecret(short) and short == true
end

-- A buff tracker: the family of the buff it last saw on the player (seen, any spell of its list, Trackers.lua's Settle), else the first family
-- of its list the player can cast, cast by its name on the player, so the game takes its highest rank. Unlike Weapon, a click never takes the
-- last family: the class lists end with the group versions, the dazing aspects and the resistance auras (ClassData.lua:15-16, 21, 35-37, 53,
-- 68). So a hunter whose tracker last saw Aspect of the Wild gets it again, and one that last saw Aspect of the Cheetah gets the first aspect
-- left. A buff the player cannot cast takes no click, nor does the family chosen while the player lacks the power for it (Short): a warrior
-- has no rage out of combat for Battle Shout, and the click would only give the game's error. The click is not moved to a cheaper family; a pass
-- or the click itself (PreClick) asks again, so a warrior with rage left from a fight still gets it.
local function Buff(entry)
	local families, of = Families(entry)
	local family = Whole(entry.seen) and of[entry.seen] or nil
	if not Castable(family) then
		family = nil
		for _, each in ipairs(families) do
			if not family and Castable(each) then
				family = each
			end
		end
	end
	if not family then
		return nil
	elseif Short(Newest(family)) then
		return nil, ("would cast %s on you, but you lack the power for it now"):format(family.name)
	end
	return { type = "spell", spell = family.name, unit = "player" }, ("casts %s on you"):format(family.name)
end

-- A stance or form tracker: the form of its list it last saw the player in (seen, kept by TrackerKinds.lua's FormRead), else the first spell of
-- its list the player knows. One with no spells takes none.
local function Form(entry)
	local spells = type(entry.spells) == "table" and entry.spells or {}
	for _, id in ipairs(spells) do
		if id == entry.seen and Known(id) then
			return Cast(id)
		end
	end
	for _, id in ipairs(spells) do
		if Whole(id) and Known(id) then
			return Cast(id)
		end
	end
	return nil
end

-- A pet tracker that is not set to happy, read afresh: a hunter's pet that is out and dead is revived; a hunter with no pet out casts Call Pet,
-- then Revive Pet in the same click for a pet that died (a macro text of those he knows: the first that the game takes is cast); a warlock with
-- no demon casts the summon he cast last (FlatUICharDB.petSummon, kept by TrackerKinds.lua's PetCast), else the first summon of the list he
-- knows; a pet low by its mode is set to Defensive, or to Assist while Defensive counts as low too, with type pet and the pet bar slot whose
-- token is that mode (TrackerKinds.lua's PetModes), and with no such slot there is no click. A pet low only by its health takes none, nor does a
-- pet a flight path or a buff excuses (fine, so nothing to fix).
local function Pet(entry)
	if entry.happy == true then
		return nil
	end
	local exists, dead = Ask(UnitExists, "pet"), nil
	if exists == true then
		dead = Ask(UnitIsDead, "pet")
	end
	if exists == true and dead == false then
		local mode, slots = nil, {}
		if type(ns.TrackerPetModes) == "function" then
			mode, slots = ns.TrackerPetModes()
		end
		local passive, defensive = ns.Get(KEY .. ".petPassive") == true, ns.Get(KEY .. ".petDefensive") == true
		if not ((mode == "passive" and passive) or (mode == "defensive" and defensive)) then
			return nil
		end
		local want = defensive and "assist" or "defensive"
		local slot = type(slots) == "table" and slots[want]
		if not Whole(slot) then
			return nil
		end
		return { type = "pet", action = slot }, ("sets your pet to %s"):format(K.MODES[want])
	elseif exists == true and dead == true and Known(K.REVIVE) then
		return Cast(K.REVIVE)
	elseif exists ~= false and dead ~= true then
		return nil
	end
	-- No pet, or a dead one that is not a hunter's.
	local lines, names = {}, {}
	for _, id in ipairs({ K.CALL, K.REVIVE }) do
		local name = Known(id) and SpellName(id)
		if name then
			lines[#lines + 1] = "/cast " .. name
			names[#names + 1] = name
		end
	end
	if #names > 0 then
		return { type = "macro", macrotext = table.concat(lines, "\n") }, ("casts %s"):format(table.concat(names, ", or when your pet is dead "))
	end
	local saved = ns.Character()
	local last = type(saved) == "table" and saved.petSummon or nil
	if Whole(last) and Known(last) then
		return Cast(last)
	end
	for _, id in ipairs(type(entry.summon) == "table" and entry.summon or {}) do
		if Whole(id) and Known(id) then
			return Cast(id)
		end
	end
	return nil
end

-- The attributes a click on the tracker sets now and what it does in words ("casts Arcane Intellect on Jaina"), or nil when there is nothing to do.
-- With now set (a click, the mouse over the button) a group is looked at afresh; a pass takes the look the tracker was drawn from. The pet and the
-- spell book are read afresh each time.
local function Choose(entry, now)
	if entry.kind == "weapon" then
		return Weapon(entry)
	elseif entry.kind == "group" and type(ns.TrackerGroupChoice) == "function" then
		return ns.TrackerGroupChoice(entry, now)
	elseif entry.kind == nil or entry.kind == "buff" then
		return Buff(entry)
	elseif entry.kind == "form" then
		return Form(entry)
	elseif entry.kind == "pet" then
		return Pet(entry)
	end
	return nil
end

-- The kind takes a click: the page is on, the tracker is on and the Click to apply row names its kind (a buff's kind is buff, or none).
local function Allowed(entry)
	local kinds = K.KINDS[ns.Get(KEY .. ".click")] or K.KINDS.none
	return ns.Enabled(KEY) and entry.on ~= false and kinds[entry.kind or "buff"] == true
end

-- The tracker has something a click fixes, as it is drawn now: live and shown (a plain alpha of 1, so never a pet tracker shown by its pet's
-- health alone, TrackerKinds.lua's PetOver), and low or missing.
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

-- The line of /flatui tracker check, for a tracker of a kind that takes a click while the row lets it. A buff or form tracker to which Choose
-- gives neither an action nor words, since the player can cast none of its spells (a dazing aspect is never cast), has no click to offer
-- whatever it shows, and no line, as a kind that takes none; for a pet or group tracker, nil only means that nothing needs a click now.
function ns.TrackerClickLine(entry)
	if type(entry) ~= "table" or not Allowed(entry) then
		return nil
	end
	local button = S.buttons[entry.id]
	if button and S.shown[button] then
		local _, text = Choose(entry)
		return "Click: " .. (text and (text .. ".") or "nothing to do now.")
	end
	local kind = entry.kind or "buff"
	if kind == "buff" or kind == "form" then
		local action, text = Choose(entry)
		if not action and not text then
			return nil
		end
	end
	return "Click: none now. A click is offered out of combat while the tracker has something to fix, and for a buff while you have the power to cast it."
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

-- What a click on a weapon tracker takes while nothing is chosen for it, as Weapon decides it now (asked with a copy of the entry that has no use
-- and no useSpell): the name of the item or the spell, or nil when the bags and the spell book hold nothing for it. So what the check
-- (TrackerKinds.lua's Chosen), Item a click puts on a weapon and /flatui tracker use say of a tracker with nothing chosen is what a click does:
-- a shaman's imbue, a rogue's poison of the list or the strongest one of CONSUMABLES. While Click to apply gives a weapon no click (of KINDS, only
-- all has weapon), a click takes nothing: nil, and UNCLICKED, the words of why, as a second answer.
local function OwnPick(entry)
	if type(entry) ~= "table" then
		return nil
	elseif not (K.KINDS[ns.Get(KEY .. ".click")] or K.KINDS.none).weapon then
		return nil, K.UNCLICKED
	end
	local copy = {}
	for key, value in pairs(entry) do
		copy[key] = value
	end
	copy.use, copy.useSpell = nil, nil
	local action = Weapon(copy)
	if type(action) ~= "table" then
		return nil
	elseif action.type == "spell" then
		return action.spell
	end
	local id = tonumber(type(action.item) == "string" and action.item:match("^item:(%d+)$") or nil)
	return Whole(id) and ItemName(id) or nil
end
ns.TrackerWeaponOwn = OwnPick

-- A weapon tracker with nothing chosen, in the words of the lines of Item a click puts on a weapon.
local function Unchosen(entry)
	local name = OwnPick(entry)
	return name and ("nothing chosen (%s now)"):format(name) or "nothing chosen (nothing to use now)"
end

-- What a click on weapon tracker number index uses from now on: the item (use) or the spell (useSpell), or with neither what it takes itself
-- (OwnPick). The line /flatui tracker use and Item a click puts on a weapon print.
local function SetUse(index, entry, item, spell)
	entry.use, entry.useSpell = item, spell
	if type(ns.TrackerDirty) == "function" then
		ns.TrackerDirty()
	end
	local line
	if item then
		line = ("a click puts %s on the weapon."):format(ItemName(item))
	elseif spell then
		line = ("a click casts %s."):format(SpellName(spell) or ("spell " .. spell))
	else
		local name, why = OwnPick(entry)
		line = why and ("nothing chosen, and %s."):format(why) or name and ("nothing chosen, so a click uses %s now."):format(name)
			or "nothing chosen, and a click finds nothing to use now."
	end
	return ("Tracker %s: %s"):format(index, line)
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
		if rest == "" or rest:lower() == "clear" then
			return SetUse(number, entry, nil, nil)
		end
		local item = ItemOf(rest)
		if item then
			return SetUse(number, entry, item, nil)
		end
		local spell = SpellOf(rest)
		if spell then
			return SetUse(number, entry, nil, spell)
		end
		return ('No item or spell found for "%s".'):format(rest)
	end)
end

-- Item a click puts on a weapon is one list for two choices, made again each time it opens, as Sound of one icon is (Cooldowns.lua:1739-1782):
-- the weapon trackers, each with what it uses now; once one is chosen, what a click can put on its weapon, then Nothing chosen and Another
-- weapon tracker. A pick sets use or useSpell as /flatui tracker use does (SetUse). The lines of the second step are an item by its ID
-- and a spell by minus its ID, beside FIRST and BACK. This follows the item EnhanceQoL lets a player choose for each weapon slot
-- (ClassBuffReminder.lua:1586-1621).
local USE = { FIRST = -1, BACK = -2 }

-- The weapon trackers, { index, entry }, and the one chosen first, or nil when none is or it has left the list.
local function WeaponTrackers()
	local rows, chosen = {}, nil
	for index, entry in ipairs(type(ns.TrackerEntries) == "function" and ns.TrackerEntries() or {}) do
		if entry.kind == "weapon" then
			rows[#rows + 1] = { index = index, entry = entry }
			if S.useFor ~= nil and entry.id == S.useFor then
				chosen = rows[#rows]
			end
		end
	end
	if not chosen then
		S.useFor = nil
	end
	return rows, chosen
end

local function TrackerName(entry)
	return type(ns.TrackerLabel) == "function" and ns.TrackerLabel(entry) or "Weapon tracker"
end

-- What a click can put on the tracker's weapon now, { id, text }: the items of its list and the weapon poisons, stones and oils of CONSUMABLES
-- (not for a ranged weapon) that the bags hold and that weapon takes (Fits), then the spells of its list the player knows and has in the spell
-- book, one line for each name, by its last ID there (the newest rank). As Weapon does, a list with such a spell (a shaman's) offers none of its
-- items: its other IDs are ranks not learnt yet, and taken as items, Rockbiter Weapon rank 4 would be the Blackened Defias Armor, Flametongue
-- Weapon rank 3 the Plans: Ebon Shiv and rank 5 the Sergeant's Cloak, which a click would then put on or use (Weapon's header). The poisons,
-- stones and oils of CONSUMABLES are offered all the same.
local function UseChoices(entry)
	local slot = K.SLOTS[entry.slot]
	local held = slot and Held(slot)
	local apply = type(entry.apply) == "table" and entry.apply or {}
	local rows, items, spells, taken, named = {}, {}, {}, {}, {}
	for _, id in ipairs(apply) do
		if Whole(id) and Known(id) and InBook(id) then
			spells[#spells + 1] = id
		else
			items[#items + 1] = id
		end
	end
	if #spells > 0 then
		items = {}
	end
	if entry.slot ~= "ranged" then
		for _, id in ipairs(K.CONSUMABLES) do
			items[#items + 1] = id
		end
	end
	for _, id in ipairs(items) do
		if Whole(id) and not taken[id] and Carried(id) and Fits(id, held) then
			taken[id] = true
			rows[#rows + 1] = { id, ItemName(id) }
		end
	end
	for _, id in ipairs(spells) do
		local name = SpellName(id)
		if name and named[name] then
			rows[named[name]][1] = -id
		elseif name then
			rows[#rows + 1] = { -id, name }
			named[name] = #rows
		end
	end
	return rows
end

-- What a weapon tracker uses now, in words: the item or spell chosen for it, else what a click takes itself (Unchosen).
local function UseWords(entry)
	if Whole(entry.use) then
		return ItemName(entry.use)
	elseif Whole(entry.useSpell) then
		return SpellName(entry.useSpell) or ("spell " .. entry.useSpell)
	end
	return Unchosen(entry)
end

function ns.TrackerUseLines()
	local rows, chosen = WeaponTrackers()
	local lines = {}
	if not chosen then
		for _, row in ipairs(rows) do
			lines[#lines + 1] = { row.index, ("%d. %s: %s"):format(row.index, TrackerName(row.entry), UseWords(row.entry)) }
		end
		return lines
	end
	local label = TrackerName(chosen.entry)
	for _, row in ipairs(UseChoices(chosen.entry)) do
		lines[#lines + 1] = { row[1], label .. ": " .. row[2] }
	end
	lines[#lines + 1] = { USE.FIRST, label .. ": " .. Unchosen(chosen.entry) }
	lines[#lines + 1] = { USE.BACK, "Another weapon tracker" }
	return lines
end

function ns.TrackerUsePick(id)
	local rows, chosen = WeaponTrackers()
	if not chosen then
		for _, row in ipairs(rows) do
			if row.index == id then
				S.useFor = row.entry.id
				return true, ("%s: open the list again to choose what a click puts on it."):format(TrackerName(row.entry))
			end
		end
		return false, "That weapon tracker is not on the list."
	end
	S.useFor = nil
	if id == USE.FIRST then
		return true, SetUse(chosen.index, chosen.entry, nil, nil)
	elseif Whole(id) then
		return true, SetUse(chosen.index, chosen.entry, id, nil)
	elseif Plain(id, "number") and id ~= USE.BACK and Whole(-id) then
		return true, SetUse(chosen.index, chosen.entry, nil, -id)
	end
	return true, nil
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
