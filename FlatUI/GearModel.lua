local _, ns = ...

local G = {}
ns.GearModel = G

local IsSecret, Finite = ns.IsSecret, ns.Finite

local K = {
	AMMO = 0, MAIN = 16, OFF = 17, RANGED = 18, LAST = 19,
	LABEL = { [0] = "Ammo", "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger 1", "Finger 2",
		"Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged", "Tabard" },
	BOTH = "both hands",
	EQUIP = {
		INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WAIST = 6, INVTYPE_LEGS = 7,
		INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_CLOAK = 15, INVTYPE_WEAPONMAINHAND = 16, INVTYPE_RANGED = 18,
		INVTYPE_RANGEDRIGHT = 18, INVTYPE_THROWN = 18, INVTYPE_FINGER = "pair", INVTYPE_TRINKET = "pair", INVTYPE_2HWEAPON = "two",
		INVTYPE_WEAPON = "one", INVTYPE_WEAPONOFFHAND = "offweapon", INVTYPE_SHIELD = "off", INVTYPE_HOLDABLE = "off", INVTYPE_AMMO = "ammo",
	},
	PAIR = { INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 } },
	NONE = { INVTYPE_RELIC = true, INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true },
	TWO_HAND = "INVTYPE_2HWEAPON", SHIELD = "INVTYPE_SHIELD",
	WEAPON = 2, DAGGER = 15,
	FIRES = { [2] = 2, [18] = 2, [3] = 3 },
	RANGED_LINES = { [45] = true, [46] = true, [176] = true, [226] = true, [228] = true }, UNARMED = 162,
	FORMS = { [1] = "cat", [5] = "bear", [8] = "bear" }, PAW_LEAST = 1,
	UNARMED_SPEED = 2.0,
	HIT = { [6] = "melee", [7] = "ranged", [8] = "spell" }, CRIT = { [9] = "melee", [10] = "ranged", [11] = "spell" },
	HASTE = { melee = 18, ranged = 19, spell = 20 }, EXPERTISE = 24,
	SIZE = { [6] = "hit", [7] = "hit", [8] = "hit", [9] = "crit", [10] = "crit", [11] = "crit", [18] = "haste", [19] = "haste", [20] = "haste",
		[24] = "expertise" },
	STRENGTH_BLOCK = 20,
	STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }, RATED = { [1] = true, [2] = true, [4] = true },
	UNCOUNTED = { [3] = "your health", [5] = "your regeneration" },
	PIERCE = { [0] = { "Spell Piercing", "magic" }, [3] = { "Fire Piercing", "Fire" }, [4] = { "Nature Piercing", "Nature" },
		[5] = { "Frost Piercing", "Frost" }, [6] = { "Shadow Piercing", "Shadow" }, [7] = { "Arcane Piercing", "Arcane" } },
	PIERCE_NOTE = "%s %s (only a %s damage spell rolled on the Spell line takes it, and none is compared)",
	TRIGGERS = { use = "use effect", proc = "chance on hit", equip = "equip effect" },
	SEAL = { two = 1.2, one = 0.85, at = 2.0, step = 0.2 }, PPM = { ["seal of command"] = 7 },
	PER_SECOND = { auto = true, shot = true, wand = true, seal = true, proc = true },
	HEALS = { heal = true, hot = true }, LASTING = { dot = true, hot = true, channel = true },
	KINDS = { melee = true, ranged = true, spell = true },
	MAX_LEVEL = 60,
	CACHE = 64, SHORT = 60, LINES = 60, NONE_UNDER = 0.05,
	USAGE = 43, ON_USE = 44, ON_EQUIP = 45, ON_PROC = 46, RED_LEAST = 0.9, OTHER_MOST = 0.25,
	MODES = { cast = true, second = true, threat = true },
	UNITS = { tooltip = "a cast", cast = "a cast", second = "a second", threat = "threat a cast" },
	STRINGS = {
		DAMAGE_TEMPLATE = "%s - %s Damage", DAMAGE_TEMPLATE_WITH_SCHOOL = "%s - %s %s Damage", SINGLE_DAMAGE_TEMPLATE = "%s Damage",
		SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL = "%s %s Damage", PLUS_DAMAGE_TEMPLATE = "+ %s - %s Damage",
		PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL = "+%s - %s %s Damage", SPEED = "Speed", SHIELD_BLOCK_TEMPLATE = "%s Block",
		AMMO_DAMAGE_TEMPLATE = "Adds %s damage per second", LARGE_NUMBER_SEPERATOR = ",", DECIMAL_SEPERATOR = ".",
		ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:", ITEM_SPELL_TRIGGER_ONPROC = "Chance on hit:", ITEM_SPELL_TRIGGER_ONUSE = "Use:",
		ITEM_SET_NAME = "%s (%d/%d)", ITEM_RANDOM_ENCHANT = "<Random additional stats>", ITEM_CLASSES_ALLOWED = "Classes: %s",
		ITEM_RACES_ALLOWED = "Races: %s", ITEM_UNIQUE = "Unique", ITEM_UNIQUE_EQUIPPABLE = "Unique-Equipped",
	},
	STATS_TABLES = { "sp", "crit", "haste", "rating", "stat", "dmg", "rdmg", "speed" },
	WHY = {
		data = "The gear comparison has no spell data.", item = "No item to compare.", worn = "This item is not worn.",
		none = "Not compared: it gives your spells nothing the comparison counts.", loading = "The game has not loaded this item yet.",
		twoHand = "Needs a one-hand weapon; not compared.", dual = "An off-hand weapon needs you to dual wield; not compared.",
		ammo = "The game does not use ammunition for you; not compared.", unique = "You wear as many of its kind as the game allows; not compared.",
		fires = "You wear no ranged weapon that fires this ammunition; not compared.",
		weapon = "Flat UI could not read this weapon's damage and speed.", combat = "Gear lines show out of combat.",
		stats = "The game has not given your stats yet.", empty = "That slot is empty.",
		notCompared = "Flat UI cannot work this spell out.", pet = "An item does not change your pet's spells.",
		rank = "Flat UI's data has no rank of this spell.", inputs = "Flat UI has not read your hit table yet.",
		withheld = "The game withheld part of your hit table.", threat = "Its threat on Forever is not known.",
		baseLoading = "The game has not loaded the item to compare against yet.",
		baseUnread = "Flat UI could not read the item to compare against.",
		baseSlot = "It does not go in the same slot as %s; not compared.",
	},
	TOTAL_KINDS = { "damage", "healing", "threat" }, WEIGHT_MOST = 5, WEIGHT = 1,
	MINUTE = 60, GCD = 1.5, GUESSED = 0.1, ROLE_KIND = { healer = "healing", tank = "threat" },
	ROTATION_KEEP = 1,
	SKILL_NOTE = "%s %d/%d: until you raise it you miss more", SKILL_ANY = "Weapon skill",
}

local function Index(t, key)
	return t[key]
end

local function Field(t, key)
	if t == nil or IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(Index, t, key)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Num(value)
	if Finite(value) then
		return value
	end
	return nil
end

local function Text(value)
	if not IsSecret(value) and type(value) == "string" then
		return value
	end
	return nil
end

local function Table(value)
	if value ~= nil and not IsSecret(value) and type(value) == "table" then
		return value
	end
	return nil
end

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil, "missing"
	end
	local ok, value = pcall(fn, ...)
	if not ok then
		return nil, "refused"
	elseif IsSecret(value) then
		return nil, "withheld"
	end
	return value
end

local function Api(space, name)
	local fn = Field(_G[space], name)
	if type(fn) == "function" then
		return fn
	end
	return nil
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok then
		return value
	end
	return nil
end

local function EnumValue(group, name, fallback)
	return Num(Field(Field(_G.Enum, group), name)) or fallback
end

local function InCombat()
	return Call(InCombatLockdown) == true
end

local function StatsPlain()
	local secret, why = Call(Api("C_Secrets", "ShouldUnitStatsBeSecret"))
	if why == "missing" then
		return true
	end
	return secret == false
end

local function Model()
	local M = ns.SpellModel
	if type(M) == "table" then
		return M
	end
	return nil
end

local function Data()
	local D = ns.SpellData
	if type(D) == "table" and type(D.MODEL) == "table" then
		return D
	end
	return nil
end

local function Calc()
	local C = ns.HitTableCalc
	if type(C) == "table" and type(C.Inputs) == "function" and type(C.Table) == "function" then
		return C
	end
	return nil
end

local function Copy(t)
	local out = {}
	if type(t) == "table" then
		for key, value in pairs(t) do
			out[key] = value
		end
	end
	return out
end

local function Pick(t, index)
	if type(t) == "table" then
		return t[index]
	end
	return t
end

local function AddOnce(list, text)
	for _, have in ipairs(list) do
		if have == text then
			return
		end
	end
	list[#list + 1] = text
end

local function Signed(value)
	if value == math.floor(value) then
		return ("%+d"):format(value)
	end
	return ("%+.1f"):format(value)
end

local function Word(name)
	return Text(_G[name]) or K.STRINGS[name]
end

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

local function Escape(text)
	return (text:gsub(MAGIC, "%%%0"))
end

local function Compile(template)
	local parts, order, count, at, size = { "^" }, {}, 0, 1, #template
	while at <= size do
		local char = template:sub(at, at)
		if char == "%" and template:sub(at + 1, at + 1) == "%" then
			parts[#parts + 1] = "%%"
			at = at + 2
		elseif char == "%" then
			local first, last, position = template:find("^%%(%d+)%$[%-%+ #0]*%d*%.?%d*[sdifgu]", at)
			if not first then
				first, last = template:find("^%%[%-%+ #0]*%d*%.?%d*[sdifgu]", at)
			end
			if not first then
				return nil
			end
			count = count + 1
			order[count] = tonumber(position) or count
			parts[#parts + 1] = "(.-)"
			at = last + 1
		else
			parts[#parts + 1] = char:find(MAGIC) and "%" .. char or char
			at = at + 1
		end
	end
	parts[#parts + 1] = "$"
	return { text = table.concat(parts), order = order }
end

local patterns = {}

local function Pattern(name)
	local found = patterns[name]
	if found == nil then
		local template = Word(name)
		found = template and Compile(template) or false
		patterns[name] = found
	end
	return found or nil
end

local function Match(name, text)
	local pattern = text and Pattern(name)
	if not pattern then
		return nil
	end
	local found = { text:match(pattern.text) }
	if found[1] == nil then
		return nil
	end
	local values = {}
	for index, position in ipairs(pattern.order) do
		values[position] = found[index]
	end
	return values
end

local function Number(text)
	if type(text) ~= "string" then
		return nil
	end
	local thousands, decimal = Word("LARGE_NUMBER_SEPERATOR"), Word("DECIMAL_SEPERATOR")
	local plain = text
	if thousands and thousands ~= "" and thousands ~= decimal then
		plain = plain:gsub(Escape(thousands), "")
	end
	if decimal and decimal ~= "" and decimal ~= "." then
		plain = plain:gsub(Escape(decimal), ".")
	end
	plain = plain:match("^%s*([%+%-]?%d*%.?%d+)%s*$")
	return Num(plain and tonumber(plain))
end

local function Starts(text, word)
	return word ~= nil and word ~= "" and text:sub(1, #word) == word
end

local function Short(text)
	if #text <= K.SHORT then
		return text
	end
	local cut = K.SHORT - 3
	while cut > 1 do
		local byte = text:byte(cut + 1)
		if not (byte and byte >= 128 and byte < 192) then
			break
		end
		cut = cut - 1
	end
	local head = text:sub(1, cut)
	local space = head:match("^.*()%s")
	if space and space > cut / 2 then
		head = head:sub(1, space - 1)
	end
	head = head:gsub("[%s,;:%-]+$", "")
	return head .. "..."
end

local function Instant(item)
	local fn = Api("C_Item", "GetItemInfoInstant")
	if not fn or item == nil then
		return nil
	end
	local ok, id, _, _, loc, _, class, subclass = pcall(fn, item)
	if not ok then
		return nil
	end
	return Num(id), Text(loc), Num(class), Num(subclass)
end

local function NameOf(link)
	local fn = Api("C_Item", "GetItemInfo")
	if not fn or not link then
		return nil
	end
	local ok, name, _, quality = pcall(fn, link)
	if not ok then
		return nil
	end
	return Text(name), Num(quality)
end

local function Byte(value)
	return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
end

local function Coloured(link)
	local name, quality = NameOf(link)
	if not name then
		return nil
	end
	local fn = quality and Api("C_Item", "GetItemQualityColor")
	if fn then
		local ok, r, g, b = pcall(fn, quality)
		if ok and Finite(r) and Finite(g) and Finite(b) then
			return ("|cff%02x%02x%02x%s|r"):format(Byte(r), Byte(g), Byte(b), name)
		end
	end
	return name
end

local function LinkID(link)
	local id = link and link:match("item:(%d+)")
	return Num(id and tonumber(id))
end

local function EnchantOf(link)
	local id = link and tonumber(link:match("item:%-?%d+:(%d+)") or "")
	if Num(id) and id > 0 then
		return id
	end
	return nil
end

local function Into(source, out)
	for key, value in pairs(source) do
		if Text(key) and Finite(value) then
			out[key] = value
		end
	end
end

local statsOf, statsKept = {}, 0

local function ItemStats(link)
	if not link then
		return {}
	end
	local kept = statsOf[link]
	if kept then
		return kept
	end
	local out = {}
	local got = Table(Call(Api("C_Item", "GetItemStats"), link))
	if got then
		pcall(Into, got, out)
		if statsKept >= K.CACHE * 4 then
			statsOf, statsKept = {}, 0
		end
		statsOf[link], statsKept = out, statsKept + 1
	end
	return out
end

local function Clean(value)
	local text = Text(value)
	if not text then
		return nil
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:match("^%s*(.-)%s*$")
	if text == "" then
		return nil
	end
	return text
end

local function Red(colour)
	local r, g, b = Num(Field(colour, "r")), Num(Field(colour, "g")), Num(Field(colour, "b"))
	return r ~= nil and g ~= nil and b ~= nil and r >= K.RED_LEAST and g <= K.OTHER_MOST and b <= K.OTHER_MOST
end

local function TipLines(given, link, slot)
	local lines = Table(given)
	if not lines then
		local data
		if slot then
			data = Call(Api("C_TooltipInfo", "GetInventoryItem"), "player", slot)
		elseif link then
			data = Call(Api("C_TooltipInfo", "GetHyperlink"), link)
		end
		lines = Table(Field(data, "lines"))
	end
	local out = {}
	for index = 1, K.LINES do
		local line = Table(Field(lines, index))
		if not line then
			break
		end
		out[#out + 1] = { left = Clean(Field(line, "leftText")), right = Clean(Field(line, "rightText")), kind = Num(Field(line, "type")),
			red = Red(Field(line, "leftColor")) }
	end
	return out
end
G.TipLines = TipLines

local function Range(name, text)
	local values = Match(name, text)
	local low, high = values and Number(values[1]), values and Number(values[2])
	if low and high then
		return low, high
	end
	return nil
end

local function Single(name, text)
	local values = Match(name, text)
	return values and Number(values[1]) or nil
end

local function ReadDamage(text, found)
	if not text then
		return
	end
	if found.speed == nil then
		local word = Word("SPEED")
		local rest = word and text:match("^" .. Escape(word) .. "%s+(.+)$")
		local speed = rest and Number(rest)
		if speed then
			found.speed = speed
			return
		end
	end
	local low, high = Range("PLUS_DAMAGE_TEMPLATE", text)
	if not low then
		low, high = Range("PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL", text)
	end
	if low then
		if found.plusMin == nil then
			found.plusMin, found.plusMax = low, high
		end
		return
	end
	if found.min ~= nil then
		return
	end
	low, high = Range("DAMAGE_TEMPLATE", text)
	if not low then
		low, high = Range("DAMAGE_TEMPLATE_WITH_SCHOOL", text)
	end
	if not low then
		low = Single("SINGLE_DAMAGE_TEMPLATE", text) or Single("SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL", text)
		high = low
	end
	if low then
		found.min, found.max = low, high
	end
end

local function WeaponOf(item)
	local found = {}
	for _, line in ipairs(item.lines) do
		ReadDamage(line.left, found)
		ReadDamage(line.right, found)
	end
	local speed = found.speed
	if not (speed and speed > 0) then
		return nil
	end
	if not found.min then
		local dps = Num(item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT)
		if not dps then
			return nil
		end
		found.min, found.max = dps * speed, dps * speed
	end
	local C = Calc()
	local line = C and Num((Ask(C.LineOf, item.id))) or nil
	return { link = item.link, id = item.id, min = found.min, max = found.max, plusMin = found.plusMin, plusMax = found.plusMax, speed = speed,
		class = item.class, subclass = item.subclass, loc = item.loc, line = line, twoHand = item.loc == K.TWO_HAND,
		dagger = item.subclass == EnumValue("ItemWeaponSubclass", "Dagger", K.DAGGER) }
end

local function LineNumber(lines, name)
	for _, line in ipairs(lines) do
		local value = line.left and Single(name, line.left)
		if value then
			return value
		end
	end
	return nil
end

local function ItemOf(link, given, slot)
	if not link then
		return nil, K.WHY.item, true
	end
	local id, loc, class, subclass = Instant(link)
	if not id then
		return nil, K.WHY.item, true
	end
	local name = NameOf(link)
	if not name then
		Call(Api("C_Item", "RequestLoadItemDataByID"), id)
		return nil, K.WHY.loading, true
	end
	local item = { link = link, id = id, loc = loc, class = class, subclass = subclass, name = name }
	item.stats = ItemStats(link)
	item.lines = TipLines(given, not slot and link or nil, slot)
	if class == EnumValue("ItemClass", "Weapon", K.WEAPON) and not slot then
		item.weapon = WeaponOf(item)
		if not item.weapon then
			return nil, K.WHY.weapon, false
		end
	end
	if loc == K.SHIELD and not slot then
		item.block = LineNumber(item.lines, "SHIELD_BLOCK_TEMPLATE")
		item.unread = item.block == nil and "the shield's block (Flat UI could not read it)" or nil
	elseif loc == "INVTYPE_AMMO" and not slot then
		item.ammo = LineNumber(item.lines, "AMMO_DAMAGE_TEMPLATE")
		item.unread = item.ammo == nil and "the ammunition's damage (Flat UI could not read it)" or nil
	end
	return item
end

local function SetLine(text)
	local values = Match("ITEM_SET_NAME", text)
	return values ~= nil and Number(values[2]) ~= nil and Number(values[3]) ~= nil
end

local function Explaining(stats, D)
	local names = {}
	local defs = Table(D.STATS) or {}
	for key in pairs(stats) do
		local def = Table(defs[key])
		if def and Text(def.t) then
			names[#names + 1] = def.t
		end
	end
	for _, pair in ipairs(Table(D.STAT_PAIRS) or {}) do
		if Text(pair.t) and (stats[pair[1]] ~= nil or stats[pair[2]] ~= nil) then
			names[#names + 1] = pair.t
		end
	end
	return names
end

local function Explained(text, names)
	for _, name in ipairs(names) do
		if Match(name, text) then
			return true
		end
	end
	return false
end

local function Trigger(item, text, word, phrase)
	local rest = Starts(text, word) and (text:sub(#word + 1):gsub("^%s+", "")) or text
	local name = Text(item.name)
	if not name then
		return Short(text)
	end
	return ("%s's %s (%s)"):format(name, phrase, Short(rest))
end

local function Notes(item, info, replaced)
	local D = Data()
	if not (D and item) then
		return
	end
	if item.unread and not replaced then
		AddOnce(info.notCounted, item.unread)
	end
	local names = Explaining(item.stats, D)
	local equip, use, proc = Word("ITEM_SPELL_TRIGGER_ONEQUIP"), Word("ITEM_SPELL_TRIGGER_ONUSE"), Word("ITEM_SPELL_TRIGGER_ONPROC")
	local random = Word("ITEM_RANDOM_ENCHANT")
	for _, line in ipairs(item.lines) do
		local text = line.left
		if text then
			if text == random then
				info.random = info.random or not replaced
			elseif SetLine(text) then
				if not replaced then
					AddOnce(info.notCounted, Short(text))
				end
			elseif line.kind == K.ON_USE or Starts(text, use) then
				AddOnce(info.notCounted, Trigger(item, text, use, K.TRIGGERS.use))
			elseif line.kind == K.ON_PROC or Starts(text, proc) then
				AddOnce(info.notCounted, Trigger(item, text, proc, K.TRIGGERS.proc))
			elseif line.kind == K.ON_EQUIP or Starts(text, equip) then
				if not Explained(text, names) then
					AddOnce(info.notCounted, Trigger(item, text, equip, K.TRIGGERS.equip))
				end
			elseif not replaced and line.red and line.kind == K.USAGE and info.notYet == nil and not Match("ITEM_CLASSES_ALLOWED", text)
				and not Match("ITEM_RACES_ALLOWED", text) then
				info.notYet = text
			end
		end
	end
	if replaced then
		return
	end
	local defs, keys = Table(D.STATS) or {}, {}
	for key in pairs(Table(item.stats) or {}) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local def, amount = Table(defs[key]), Num(item.stats[key])
		local stat = def and def[1] == "stat" and Num(def[2])
		if stat and K.UNCOUNTED[stat] and amount and amount ~= 0 then
			AddOnce(info.notCounted, ("%s %s (%s)"):format(Signed(amount), K.STAT_NAMES[stat], K.UNCOUNTED[stat]))
		end
	end
end

local function LinkAt(state, slot)
	local links = state.links
	return type(links) == "table" and Text(links[slot]) or nil
end

local function Worn(state, slot)
	local weapons = state.weapons
	local weapon = type(weapons) == "table" and weapons[slot] or nil
	return type(weapon) == "table" and weapon or nil
end

local function WeaponMean(state, slot)
	local weapon = Worn(state, slot)
	if not weapon then
		return nil
	end
	local low, high, speed = Num(weapon.min), Num(weapon.max), Num(weapon.speed)
	if not (low and high and speed and speed > 0) then
		return nil
	end
	local mean = (low + high) / 2
	local plusLow, plusHigh = Num(weapon.plusMin), Num(weapon.plusMax)
	if plusLow and plusHigh then
		mean = mean + (plusLow + plusHigh) / 2
	end
	return mean, speed, weapon
end

local function TwoHandWorn(state)
	local weapon = Worn(state, K.MAIN)
	return state.twoHand == true or (weapon ~= nil and weapon.twoHand == true)
end

local function AmmoFor(state)
	local ammo, weapon = Num(state.ammo), Worn(state, K.RANGED)
	if not (ammo and ammo > 0 and weapon) then
		return 0, false
	end
	local sub, kind = Num(weapon.subclass), Num(state.ammoKind)
	if sub == nil or kind == nil or K.FIRES[sub] == kind then
		return ammo, false
	elseif K.FIRES[sub] and state.ammoStandIn then
		return ammo, true
	end
	return 0, false
end

local function SlotOfLink(state, link)
	for slot = K.AMMO, K.LAST do
		if LinkAt(state, slot) == link then
			return slot
		end
	end
	return nil
end

local function SlotOfItem(state, item)
	local guid = Text(Field(item, "guid"))
	if guid then
		local location = Call(Api("C_Item", "GetItemLocation"), guid)
		local slot = Num(Field(location, "equipmentSlotIndex"))
		if slot then
			return slot
		end
		local link = Text((Call(Api("C_Item", "GetItemLinkByGUID"), guid)))
		return link and SlotOfLink(state, link) or nil
	end
	local link = Text(Field(item, "hyperlink"))
	return link and SlotOfLink(state, link) or nil
end

local function GameSlots(state, link, guid)
	if InCombat() then
		return nil
	end
	local fn = Api("C_TooltipComparison", "GetItemComparisonInfo")
	if not fn then
		return nil
	end
	local info = Table(Call(fn, guid and { guid = guid } or { hyperlink = link }))
	if not info then
		return nil
	end
	local named, order = {}, {}
	local slot = SlotOfItem(state, Field(info, "item"))
	if slot then
		named[slot], order[1] = true, slot
	end
	local method = Num(Field(info, "method")) or 0
	if method <= 1 then
		local more = Table(Field(info, "additionalItems"))
		for index = 1, 4 do
			local other = Field(more, index)
			if other == nil then
				break
			end
			slot = SlotOfItem(state, other)
			if slot and not named[slot] then
				named[slot], order[#order + 1] = true, slot
			end
		end
	end
	if #order == 0 then
		return nil
	end
	return named, order
end

local function Fits(state, ammoKind)
	local weapon = Worn(state, K.RANGED)
	local kind, sub = Num(ammoKind), weapon and Num(weapon.subclass)
	if weapon and not sub then
		return true
	end
	return kind == nil or (sub ~= nil and K.FIRES[sub] == kind)
end

local function Groups(state, loc, sub)
	local kind = K.EQUIP[loc]
	if type(kind) == "number" then
		return { { kind } }
	elseif kind == "pair" then
		local pair = K.PAIR[loc]
		return { { pair[1] }, { pair[2] } }
	elseif kind == "two" then
		return { { K.MAIN, K.OFF } }
	elseif kind == "one" then
		if TwoHandWorn(state) then
			return { { K.MAIN } }, true
		elseif state.dual == true then
			return { { K.MAIN }, { K.OFF } }
		end
		return { { K.MAIN } }
	elseif kind == "off" or kind == "offweapon" then
		if TwoHandWorn(state) then
			return nil, K.WHY.twoHand, false
		elseif kind == "offweapon" and state.dual ~= true then
			return nil, K.WHY.dual, true
		end
		return { { K.OFF } }
	elseif kind == "ammo" then
		if Call(Api("C_PaperDollInfo", "AmmoNeeded")) ~= true or Call(_G.UnitUsesAmmo, "player") == false then
			return nil, K.WHY.ammo, true
		elseif not Fits(state, sub) then
			return nil, K.WHY.fires, false
		end
		return { { K.AMMO } }
	end
	return nil, K.WHY.worn, true
end

local function UniqueOf(id, lines)
	local unique, count, category = false, nil, nil
	local fn = Api("C_Item", "GetItemUniquenessByID")
	if fn and id then
		local ok, isUnique, _, limit, categoryID = pcall(fn, id)
		if ok then
			unique = not IsSecret(isUnique) and isUnique == true
			count, category = Num(limit), Num(categoryID)
		end
	end
	if not unique and lines then
		local once, equipped = Word("ITEM_UNIQUE"), Word("ITEM_UNIQUE_EQUIPPABLE")
		for _, line in ipairs(lines) do
			if line.left ~= nil and (line.left == once or line.left == equipped) then
				unique = true
				break
			end
		end
	end
	if category and category <= 0 then
		category = nil
	end
	return unique, count, category
end

local function KeepUnique(state, id, groups, lines)
	if #groups < 2 or not id then
		return groups
	end
	local unique, count, category = UniqueOf(id, lines)
	if unique then
		for _, group in ipairs(groups) do
			for _, slot in ipairs(group) do
				if LinkID(LinkAt(state, slot)) == id then
					return { group }
				end
			end
		end
	end
	if not (category and count and count > 0) then
		return groups
	end
	local worn, holders = 0, {}
	for slot = 1, K.LAST do
		local other = LinkID(LinkAt(state, slot))
		if other then
			local _, _, otherCategory = UniqueOf(other, nil)
			if otherCategory == category then
				worn, holders[slot] = worn + 1, true
			end
		end
	end
	if worn < count then
		return groups
	end
	local kept = {}
	for _, group in ipairs(groups) do
		for _, slot in ipairs(group) do
			if holders[slot] then
				kept[#kept + 1] = group
				break
			end
		end
	end
	return kept
end

local function Label(slots)
	if #slots > 1 then
		return K.BOTH
	end
	return K.LABEL[slots[1]] or "?"
end

local function Candidates(state, link, id, loc, lines, guid, sub)
	if not loc or loc == "" then
		return nil, K.WHY.worn, true
	elseif K.NONE[loc] then
		return nil, K.WHY.none, true
	end
	local groups, second, quiet = Groups(state, loc, sub)
	if not groups then
		return nil, second, quiet
	end
	local offEmpty = second == true
	groups = KeepUnique(state, id, groups, lines)
	if #groups == 0 then
		return nil, K.WHY.unique, false
	end
	local named, order = GameSlots(state, link, guid)
	local place = {}
	for index, slot in ipairs(order or {}) do
		place[slot] = index
	end
	local list = {}
	for _, slots in ipairs(groups) do
		local empty, all, first = true, named ~= nil, nil
		for _, slot in ipairs(slots) do
			if LinkAt(state, slot) then
				empty = false
				if not (named and named[slot]) then
					all = false
				end
			end
			first = first or place[slot]
		end
		list[#list + 1] = { slots = slots, label = Label(slots), empty = empty, game = all, offEmpty = offEmpty, rank = first or (100 + slots[1]) }
	end
	table.sort(list, function(a, b)
		return a.rank < b.rank
	end)
	for _, candidate in ipairs(list) do
		candidate.rank = nil
	end
	return list
end

function G.Candidates(link, guid, lines)
	link = Text(link)
	if not link then
		return nil, K.WHY.item, true
	end
	local M = Model()
	local state = Table(M and Ask(M.State)) or {}
	local id, loc, _, sub = Instant(link)
	local tipLines
	if loc and (K.PAIR[loc] or loc == "INVTYPE_WEAPON") then
		tipLines = TipLines(lines, link, nil)
	end
	return Candidates(state, link, id, loc, tipLines, Text(guid), sub)
end

local function BaseSlots(loc, slots)
	local first = type(slots) == "table" and Num(slots[1]) or nil
	local equip = loc and K.EQUIP[loc]
	if not (first and equip) then
		return nil
	end
	local fits
	if equip == "two" then
		if first == K.MAIN then
			return { K.MAIN, K.OFF }
		end
		return nil
	elseif type(equip) == "number" then
		fits = equip == first
	elseif equip == "pair" then
		fits = K.PAIR[loc][1] == first or K.PAIR[loc][2] == first
	elseif equip == "one" then
		fits = first == K.MAIN or first == K.OFF
	elseif equip == "ammo" then
		fits = first == K.AMMO
	else
		fits = first == K.OFF
	end
	if fits then
		return { first }
	end
	return nil
end

function G.BaseSlots(base, candidate)
	local _, loc = Instant(Text(base))
	return BaseSlots(loc, Table(Field(candidate, "slots")))
end

local held = { registered = false, inputs = nil, sizes = false }

local function RatingPct(rating, amount, size)
	if amount == 0 then
		return 0
	end
	local sign, value = amount < 0 and -1 or 1, math.abs(amount)
	local got = Call(GetCombatRatingBonusForCombatRatingValue, rating, value)
	if Finite(got) then
		return sign * got
	end
	held.sizes = true
	local D = Data()
	local ratings = D and Table(D.MODEL.ratings)
	local fixed = Num(size) or Num(ratings and ratings[K.SIZE[rating]])
	if fixed and fixed > 0 then
		return sign * value / fixed
	end
	return 0
end

local function HasteScale(stats, rating, amount, size)
	if not amount or amount == 0 then
		return 1
	end
	local worn = Num(Field(stats.rating, rating))
	local now = worn and RatingPct(rating, worn, size) or 0
	local with = worn and RatingPct(rating, math.max(0, worn + amount), size) or RatingPct(rating, amount, size)
	local scale = (1 + now / 100) / (1 + with / 100)
	if Finite(scale) and scale > 0 then
		return scale
	end
	return 1
end

local function FormOf(state)
	return K.FORMS[Num(state.form) or 0]
end

local function OwnSpeed(state, slot)
	local D = Data()
	local form = FormOf(state)
	if slot == K.MAIN and form and D then
		return Num(Field(D.MODEL.form, form)) or K.UNARMED_SPEED
	end
	local _, speed = WeaponMean(state, slot)
	if speed then
		return speed
	elseif slot == K.MAIN then
		return K.UNARMED_SPEED
	end
	return nil
end

local function OffFactor(state, stats)
	local D = Data()
	local fallback = D and Num(D.MODEL.offHand) or 0.5
	if state.dual ~= true or not D then
		return fallback
	end
	local mean, speed = WeaponMean(state, K.OFF)
	local damage = Table(stats.dmg) or {}
	local low, high, pct = Num(damage.offMin), Num(damage.offMax), Num(damage.pct)
	if not (mean and low and high and pct and pct > 0) then
		return fallback
	end
	local part = mean + (Num(stats.ap) or 0) / (Num(D.MODEL.apPerDps) or 14) * speed
	if part <= 0 then
		return fallback
	end
	local factor = ((low + high) / 2 / pct - (Num(damage.flat) or 0)) / part
	if Finite(factor) and factor > 0 and factor <= 1.5 then
		return factor
	end
	return fallback
end

local function CopyState(state)
	local copy = Copy(state)
	copy.links, copy.weapons, copy.enchants, copy.temp = Copy(state.links), Copy(state.weapons), Copy(state.enchants), Copy(state.temp)
	return copy
end

local function CopyStats(stats)
	local copy = Copy(stats)
	for _, key in ipairs(K.STATS_TABLES) do
		copy[key] = Copy(stats[key])
	end
	copy.swap = { hit = { melee = 0, ranged = 0, spell = 0 }, crit = { melee = 0, ranged = 0, spell = 0 }, expertise = 0, skill = {}, pen = 0,
		castScale = 1, changed = {} }
	return copy
end

local function Wear(state, state2, item, slots)
	for _, slot in ipairs(slots) do
		state2.links[slot], state2.weapons[slot], state2.enchants[slot] = nil, nil, nil
	end
	local slot = slots[1]
	if not item then
		if slot == K.MAIN then
			state2.twoHand, state2.dual = false, false
		elseif slot == K.OFF then
			state2.shield, state2.shieldBlock, state2.dual = false, nil, false
		elseif slot == K.AMMO then
			state2.ammo, state2.ammoKind = nil, nil
		end
		return
	end
	state2.links[slot], state2.enchants[slot] = item.link, EnchantOf(item.link)
	if slot == K.AMMO then
		state2.ammo, state2.ammoKind = item.ammo or state.ammo, item.subclass
		return
	end
	if item.weapon then
		state2.weapons[slot] = item.weapon
	end
	if slot == K.RANGED then
		state2.ammoStandIn = true
	end
	if slot == K.MAIN then
		state2.twoHand = item.weapon ~= nil and item.weapon.twoHand == true
		if state2.twoHand then
			state2.shield, state2.shieldBlock, state2.dual = false, nil, false
		else
			state2.dual = state.dual == true
		end
	elseif slot == K.OFF then
		state2.shield = item.loc == K.SHIELD
		state2.shieldBlock = state2.shield and (item.block or state.shieldBlock) or nil
		state2.dual = item.weapon ~= nil
	end
end

local function Sums(delta, info, D)
	local sums = { stat = {}, school = {}, rating = {}, size = {}, skill = {}, ap = 0, rap = 0, sp = 0, spd = 0, heal = 0, wdmg = 0, bv = 0,
		pen = 0 }
	local defs = Table(D.STATS) or {}
	local keys = {}
	for key in pairs(delta) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local amount, def = delta[key], Table(defs[key])
		local kind = def and def[1]
		if amount ~= 0 and kind then
			if kind == "stat" and Num(def[2]) then
				sums.stat[def[2]] = (sums.stat[def[2]] or 0) + amount
			elseif kind == "school" and Num(def[2]) then
				sums.school[def[2]] = (sums.school[def[2]] or 0) + amount
			elseif kind == "rating" and Table(def[2]) then
				for _, rating in ipairs(def[2]) do
					sums.rating[rating], sums.size[rating] = (sums.rating[rating] or 0) + amount, Num(def[3])
				end
			elseif kind == "skill" and Num(def[2]) then
				sums.skill[def[2]] = (sums.skill[def[2]] or 0) + amount
			elseif kind == "vs" and Text(def[2]) then
				AddOnce(info.vs, ("Against %s: %s %s"):format(def[2], Signed(amount), def[3] == "ap" and "attack power" or "spell damage"))
			elseif kind == "note" and Text(def[2]) then
				AddOnce(info.notCounted, ("%s %s"):format(def[2], Signed(amount)))
			elseif kind == "pen" then
				sums.pen = sums.pen + (def[2] == nil and amount or 0)
				info.pierce = info.pierce or {}
				info.pierce[#info.pierce + 1] = { Num(def[2]) or 0, amount }
			elseif sums[kind] ~= nil and type(sums[kind]) == "number" then
				sums[kind] = sums[kind] + amount
			end
		end
	end
	return sums
end

local function Primary(stats, stats2, sums, info)
	local swap = stats2.swap
	for stat = 1, 5 do
		local amount = sums.stat[stat]
		if amount and amount ~= 0 then
			stats2.stat[stat] = (Num(stats2.stat[stat]) or 0) + amount
			if K.RATED[stat] then
				local per = Table(Field(stats.per, stat))
				local ap, rap = per and Num(per.ap), per and Num(per.rap)
				local crit, spellCrit = per and Num(per.crit), per and Num(per.spellCrit)
				if not (ap or rap or crit or spellCrit) then
					AddOnce(info.notCounted, ("%s (your stats were not read yet)"):format(K.STAT_NAMES[stat]))
				else
					stats2.ap = (Num(stats2.ap) or 0) + (ap or 0) * amount
					stats2.rap = (Num(stats2.rap) or 0) + (rap or 0) * amount
					swap.crit.melee = swap.crit.melee + (crit or 0) * amount
					swap.crit.ranged = swap.crit.ranged + (crit or 0) * amount
					swap.crit.spell = swap.crit.spell + (spellCrit or 0) * amount
				end
			end
		end
	end
end

local function Powers(stats2, sums)
	stats2.ap = (Num(stats2.ap) or 0) + sums.ap
	stats2.rap = (Num(stats2.rap) or 0) + sums.ap + sums.rap
	for school = 2, 7 do
		stats2.sp[school] = (Num(stats2.sp[school]) or 0) + sums.sp + sums.spd + (sums.school[school] or 0)
	end
	stats2.heal = (Num(stats2.heal) or 0) + sums.sp + sums.heal
	if sums.wdmg ~= 0 then
		stats2.dmg.flat = (Num(stats2.dmg.flat) or 0) + sums.wdmg
		stats2.rdmg.flat = (Num(stats2.rdmg.flat) or 0) + sums.wdmg
	end
end

local function Ratings(stats2, sums)
	local swap = stats2.swap
	for rating, amount in pairs(sums.rating) do
		local pct = RatingPct(rating, amount, sums.size[rating])
		if K.HIT[rating] then
			swap.hit[K.HIT[rating]] = swap.hit[K.HIT[rating]] + pct
		elseif K.CRIT[rating] then
			swap.crit[K.CRIT[rating]] = swap.crit[K.CRIT[rating]] + pct
		elseif rating == K.EXPERTISE then
			swap.expertise = swap.expertise + pct
		end
	end
	for kind, gain in pairs(swap.crit) do
		local now = Num(stats2.crit[kind])
		if now then
			stats2.crit[kind] = now + gain
		end
	end
	for line, gain in pairs(sums.skill) do
		swap.skill[line] = gain
	end
end

local function Speeds(state, stats, state2, stats2, sums)
	local melee = HasteScale(stats, K.HASTE.melee, sums.rating[K.HASTE.melee], sums.size[K.HASTE.melee])
	local ranged = HasteScale(stats, K.HASTE.ranged, sums.rating[K.HASTE.ranged], sums.size[K.HASTE.ranged])
	stats2.swap.castScale = HasteScale(stats, K.HASTE.spell, sums.rating[K.HASTE.spell], sums.size[K.HASTE.spell])
	local speed = stats2.speed
	local ownNow, hasted = OwnSpeed(state, K.MAIN), Num(Field(stats.speed, "main"))
	local ratio = (hasted and ownNow and ownNow > 0) and hasted / ownNow or 1
	speed.main = OwnSpeed(state2, K.MAIN) * ratio * melee
	local offWith = state2.dual == true and OwnSpeed(state2, K.OFF) or nil
	if offWith then
		local offNow, offHasted = OwnSpeed(state, K.OFF), Num(Field(stats.speed, "off"))
		local offRatio = (state.dual == true and offNow and offHasted) and offHasted / offNow or ratio
		speed.off = offWith * offRatio * melee
	else
		speed.off = nil
	end
	local rangedWith = OwnSpeed(state2, K.RANGED)
	if rangedWith then
		local rangedNow = OwnSpeed(state, K.RANGED)
		local rangedHasted = Num(Field(stats.speed, "ranged")) or Num(Field(stats.rdmg, "speed"))
		if rangedNow and rangedHasted then
			speed.ranged = rangedWith * (rangedHasted / rangedNow) * ranged
		else
			local haste, quiver = Num(Field(stats.haste, "ranged")) or 0, Num(Field(stats.haste, "quiver")) or 0
			speed.ranged = rangedWith / ((1 + haste / 100) * (1 + quiver / 100)) * ranged
		end
	else
		speed.ranged = nil
	end
	stats2.rdmg.speed = speed.ranged
end

local function Block(state, stats, state2, stats2, sums, offChanges)
	if state2.shield ~= true then
		stats2.block = nil
		return
	end
	local strength = Num(Field(stats.stat, 1)) or 0
	local with = strength + (sums.stat[1] or 0)
	local fromStrength = math.floor(with / K.STRENGTH_BLOCK) - math.floor(strength / K.STRENGTH_BLOCK)
	local now = Num(stats.block)
	if state.shield == true and now then
		local old, new = Num(state.shieldBlock) or 0, Num(state2.shieldBlock) or 0
		stats2.block = now + (offChanges and new - old or 0) + sums.bv + fromStrength
	else
		stats2.block = (Num(state2.shieldBlock) or 0) + math.floor(with / K.STRENGTH_BLOCK) + sums.bv
	end
end

local function Swap(state, stats, item, slots, info)
	local D = Data()
	local state2, stats2 = CopyState(state), CopyStats(stats)
	stats2.swap.offFactor = OffFactor(state, stats)
	local delta = {}
	for key, value in pairs(item and item.stats or {}) do
		delta[key] = value
	end
	local offChanges = false
	for _, slot in ipairs(slots) do
		offChanges = offChanges or slot == K.OFF
		stats2.swap.changed[slot] = true
		for key, value in pairs(ItemStats(LinkAt(state, slot))) do
			delta[key] = (delta[key] or 0) - value
		end
	end
	Wear(state, state2, item, slots)
	local sums = Sums(delta, info, D)
	stats2.swap.pen = sums.pen
	Primary(stats, stats2, sums, info)
	Powers(stats2, sums)
	Ratings(stats2, sums)
	Speeds(state, stats, state2, stats2, sums)
	Block(state, stats, state2, stats2, sums, offChanges)
	return state2, stats2
end

local function NewInfo()
	return { notCounted = {}, vs = {}, skills = {} }
end

local function BaseItem(base)
	local item, why = ItemOf(base, nil, nil)
	if item then
		return item
	elseif why == K.WHY.loading then
		return nil, K.WHY.baseLoading, true
	end
	return nil, K.WHY.baseUnread, false
end

local function BaseSwap(state, stats, baseItem, slots, info)
	local baseSlots = BaseSlots(baseItem.loc, slots)
	if not baseSlots then
		return nil
	end
	Notes(baseItem, info, true)
	local stateB, statsB = Swap(state, stats, baseItem, baseSlots, NewInfo())
	return stateB, statsB, baseSlots
end

function G.With(state, stats, link, candidate, lines, opts)
	local info = NewInfo()
	state, stats = Table(state) or {}, Table(stats)
	local slots = Table(Field(candidate, "slots"))
	local item, why, quiet = ItemOf(Text(link), lines)
	if not item or not stats or not slots then
		info.why, info.quiet = why or (not stats and K.WHY.stats) or K.WHY.item, quiet
		return nil, nil, info
	end
	local base, stateB, statsB = Text(Field(opts, "base")), nil, nil
	if base then
		local baseItem, baseWhy = BaseItem(base)
		local baseSlots
		if baseItem then
			stateB, statsB, baseSlots = BaseSwap(state, stats, baseItem, slots, info)
			baseWhy = not stateB and K.WHY.baseSlot:format(Coloured(base) or baseItem.name) or nil
		end
		if not stateB then
			info.why, info.quiet = baseWhy, false
			return nil, nil, info
		end
		info.base, info.baseSlots = base, baseSlots
	end
	Notes(item, info)
	local state2, stats2 = Swap(state, stats, item, slots, info)
	return state2, stats2, info, stateB, statsB
end

function G.Without(state, stats, slot)
	local info = NewInfo()
	state, stats, slot = Table(state) or {}, Table(stats), Num(slot)
	local link = slot and LinkAt(state, slot)
	if not link or not stats then
		info.why, info.quiet = not stats and K.WHY.stats or K.WHY.empty, true
		return nil, nil, info
	end
	local slots = { slot }
	if slot == K.MAIN and TwoHandWorn(state) then
		slots = { K.MAIN, K.OFF }
	end
	local worn = ItemOf(link, nil, slot)
	if worn then
		Notes(worn, info)
	end
	local state2, stats2 = Swap(state, stats, nil, slots, info)
	return state2, stats2, info
end

function G.OffFactor(state, stats)
	return OffFactor(Table(state) or {}, Table(stats) or {})
end

local function Role(state)
	local role = state and Text(state.role)
	if role then
		return role
	end
	local ok, found = pcall(ns.PlayerRole)
	return ok and Text(found) or "damage"
end

local rotationKept = {}

local function Rotation(state, role)
	state = Table(state) or {}
	role = Text(role) or Role(state)
	local now, form = Num((Call(GetTime))), Num(state.form)
	local kept = rotationKept[role]
	if kept and now and kept.form == form and now >= kept.at and now - kept.at < K.ROTATION_KEEP then
		return kept.value or nil
	end
	local value = false
	local class = Text(state.class) or Text((Call(UnitClassBase, "player")))
	local picks = class and Table(Field(Field(ns.RotationData, "CLASS"), class))
	if picks and role ~= "healer" then
		local spec, place
		local forms = Table(picks.forms)
		if form and forms and Text(forms[form]) then
			spec = forms[form]
		elseif role == "tank" then
			spec = Text(picks.tank)
		else
			place = Num((Ask(ns.PlayerTree)))
			spec = place and Text(Field(picks.trees, place))
		end
		local found = spec and Table(Field(picks.specs, spec))
		if found then
			value = { id = class .. "." .. spec, label = Text(found.label) or spec, stand = place ~= nil and Field(picks.stand, place) == true,
				abilities = Table(found.abilities) or {}, swings = Table(found.swings) or {} }
		end
	end
	if now then
		rotationKept[role] = { at = now, form = form, value = value }
	end
	return value or nil
end

function G.Rotation(role)
	local M = Model()
	local found = Rotation(M and Table(Ask(M.State)) or {}, Text(role))
	if found then
		return { id = found.id, label = found.label, stand = found.stand }
	end
	return nil
end

local function Spec(opts, state)
	local level = Num(state.level) or Num((Call(UnitLevel, "player"))) or K.MAX_LEVEL
	local against = opts.against or ns.Get("chat.gearAgainst") or "auto"
	if against == "auto" then
		against = level >= K.MAX_LEVEL and "boss" or "level"
	end
	if against ~= "boss" then
		against = "level"
	end
	local facing = opts.facing or ns.Get("chat.gearFacing") or "role"
	if facing == "role" then
		facing = Role(state) == "tank" and "front" or "behind"
	end
	if facing ~= "front" then
		facing = "behind"
	end
	local rules = opts.rules or ns.Get("chat.gearRules") or "hittable"
	if rules == "hittable" then
		rules = ns.Get("hud.hitTableRules")
	end
	if rules ~= "game" then
		rules = "classic"
	end
	local lowRank = opts.lowRank
	if lowRank == nil then
		lowRank = ns.Get("chat.spellLowRank") ~= false
	end
	local full = opts.full == true
	return { against = against, facing = facing, rules = rules, lowRank = lowRank == true, full = full,
		key = against .. "|" .. facing .. "|" .. rules .. "|" .. tostring(lowRank == true) .. "|" .. tostring(full) }
end

local function RangedWorn(C)
	local id = Num((Call(GetInventoryItemID, "player", K.RANGED)))
	if not id then
		return false
	end
	local line = Num((Ask(C.LineOf, id)))
	return line ~= nil and K.RANGED_LINES[line] == true
end

local function ReadInputs()
	local C = Calc()
	if not C then
		return
	end
	local level = Num((Call(UnitLevel, "player"))) or K.MAX_LEVEL
	local spec = Spec({}, { level = level })
	local ok, inputs = pcall(C.Inputs, { kinds = K.KINDS, rangedWithout = not RangedWorn(C), against = spec.against, facing = spec.facing })
	if ok and Table(inputs) then
		held.inputs = inputs
	end
end

local function AfterRead()
	pcall(ReadInputs)
end

local function Register()
	if held.registered then
		return true
	end
	local M = Model()
	if not (M and type(M.AfterRead) == "function") then
		return false
	end
	held.registered = pcall(M.AfterRead, AfterRead) == true
	return held.registered
end

function G.Inputs()
	Register()
	return held.inputs
end

local function InputsNow(M)
	Register()
	if held.inputs then
		return held.inputs
	end
	if type(M.Mark) == "function" then
		pcall(M.Mark, "stats")
	end
	Ask(M.Stats)
	if not held.inputs and not InCombat() and StatsPlain() then
		ReadInputs()
	end
	return held.inputs
end

local function Full(C, line, most)
	local got = Table(Ask(C.SkillLine, line))
	return most + (got and Num(got.modifier) or 0)
end

local function LineSkill(C, line, most, full)
	if full then
		return Full(C, line, most)
	end
	return Num((Ask(C.Skill, line))) or most
end

local function Adjust(state, stats, inputs, spec, C)
	local copy = Copy(inputs)
	local level = Num(inputs.level) or K.MAX_LEVEL
	local target = Table(Ask(C.Target, spec.against, level))
	copy.target = target or inputs.target
	copy.front, copy.facingUnsure = spec.facing == "front", false
	local most, full = level * 5, spec.full == true
	local melee, ranged = Table(inputs.melee), Table(inputs.ranged)
	if melee then
		local m = Copy(melee)
		copy.melee = m
		m.skill = (full and Num(m.skill) and m.line) and Full(C, m.line, most) or m.skill
		m.offSkill = (full and Num(m.offSkill) and m.offLine) and Full(C, m.offLine, most) or m.offSkill
	end
	if ranged then
		local r = Copy(ranged)
		copy.ranged = r
		r.skill = (full and Num(r.skill) and r.line and not r.noWeapon) and Full(C, r.line, most) or r.skill
	end
	local swap = Table(stats.swap)
	if not swap then
		return copy
	end
	local changed = Table(swap.changed) or {}
	if melee then
		local m = copy.melee
		local before = m.skill
		m.hit = Num(m.hit) and m.hit + swap.hit.melee or nil
		m.crit = Num(m.crit) and m.crit + swap.crit.melee or nil
		m.expertise = Num(m.expertise) and m.expertise + swap.expertise or nil
		if not inputs.feral and changed[K.MAIN] then
			local weapon = Worn(state, K.MAIN)
			local line = weapon and Num(weapon.line) or (weapon == nil and K.UNARMED or nil)
			if line and line ~= melee.line then
				m.line, m.skill = line, LineSkill(C, line, most, full)
			end
		end
		if not inputs.feral and (changed[K.MAIN] or changed[K.OFF]) then
			m.dual = state.dual == true
		end
		m.skill = Num(m.skill) and m.skill + (swap.skill[m.line] or 0) or nil
		m.moved = m.skill ~= before
		if m.dual then
			if not melee.dual then
				m.offHit, m.offExpertise, m.offSkill = melee.hit, melee.expertise, most
			end
			local offWeapon = changed[K.OFF] and Worn(state, K.OFF) or nil
			local offLine = offWeapon and Num(offWeapon.line)
			if offLine and (offLine ~= melee.offLine or not melee.dual) then
				m.offLine, m.offSkill = offLine, LineSkill(C, offLine, most, full)
			end
			m.offSkill = Num(m.offSkill) and m.offSkill + (swap.skill[m.offLine] or 0) or nil
			m.offHit = Num(m.offHit) and m.offHit + swap.hit.melee or nil
			m.offExpertise = Num(m.offExpertise) and m.offExpertise + swap.expertise or nil
		else
			m.offSkill, m.offLine, m.offHit, m.offExpertise = nil, nil, nil, nil
		end
	end
	if ranged then
		local r = copy.ranged
		r.hit = Num(r.hit) and r.hit + swap.hit.ranged or nil
		r.crit = Num(r.crit) and r.crit + swap.crit.ranged or nil
		if not inputs.feral and changed[K.RANGED] then
			local weapon = Worn(state, K.RANGED)
			local line = weapon and Num(weapon.line)
			if line and K.RANGED_LINES[line] then
				if line ~= ranged.line or ranged.noWeapon then
					r.line, r.noWeapon, r.unknown = line, nil, nil
					r.skill = LineSkill(C, line, most, full)
				end
			elseif weapon == nil and ranged.skill ~= nil then
				r.line, r.noWeapon, r.unknown, r.skill = nil, true, nil, most
			end
		end
		r.skill = Num(r.skill) and r.skill + (swap.skill[r.line] or 0) or nil
	end
	local spell = Table(inputs.spell)
	if spell then
		local s = Copy(spell)
		copy.spell = s
		s.hit = Num(s.hit) and s.hit + swap.hit.spell or nil
		s.crit = Num(s.crit) and s.crit + swap.crit.spell or nil
		s.pen = Num(s.pen) and s.pen + (Num(swap.pen) or 0) or nil
	end
	return copy
end

local tables = setmetatable({}, { __mode = "k" })

local function TableFor(state, stats, inputs, spec, C, version)
	local key = spec.key .. "|" .. version
	local kept = tables[stats]
	if kept and kept.key == key and kept.inputs == inputs and kept.state == state then
		return kept.read
	end
	local adjusted = Adjust(state, stats, inputs, spec, C)
	local read = Table(Ask(C.Table, { special = true, rules = spec.rules }, adjusted)) or { lines = {}, gaps = {}, assumed = {} }
	read.mainMoved = Field(adjusted.melee, "moved") == true
	tables[stats] = { key = key, inputs = inputs, state = state, read = read }
	return read
end

local function FindLine(read, id)
	for _, line in ipairs(Table(read.lines) or {}) do
		if line.id == id then
			return line
		end
	end
	return nil
end

local function Share(value)
	if value == false then
		return 0
	end
	local number = Num(value)
	return number and number / 100 or nil
end

local function Basis(ctx, letter)
	if letter == "e" then
		ctx.estimate = true
	elseif letter == "m" and ctx.basis == "c" then
		ctx.basis = "m"
	end
end

local function ThreatBasis(ctx, letter)
	if letter == "e" then
		ctx.threatEstimate = true
	elseif letter == "m" and ctx.threatBasis == "c" then
		ctx.threatBasis = "m"
	end
end

local function Worse(a, b)
	if a == "e" or b == "e" then
		return "e"
	elseif a == "m" or b == "m" then
		return "m"
	end
	return "c"
end

local function Letter(b, rank)
	if type(b) == "string" and #b > 1 then
		return b:sub(rank, rank)
	end
	return b
end

local auraKept = {}

local function AuraUp(spellID)
	local aura, why = Call(Api("C_UnitAuras", "GetPlayerAuraBySpellID"), spellID)
	if why == "missing" then
		return false
	elseif why then
		return auraKept[spellID]
	elseif aura ~= nil then
		auraKept[spellID] = true
		return true
	end
	local secret, asked = Call(Api("C_Secrets", "ShouldSpellAuraBeSecret"), spellID)
	if secret == false or (asked == "missing" and not InCombat()) then
		auraKept[spellID] = false
		return false
	end
	return auraKept[spellID]
end

local critByKey

local function CritTalents(D)
	if critByKey then
		return critByKey
	end
	critByKey = {}
	for _, talent in ipairs(Table(D.CRIT) or {}) do
		for _, key in ipairs(Table(talent.spells) or {}) do
			local list = critByKey[key] or {}
			list[#list + 1] = talent
			critByKey[key] = list
		end
	end
	return critByKey
end

local function CritMultiplier(ctx, roll)
	local base = Num(Field(ctx.model.crit, roll)) or 2
	local extra = 0
	for _, talent in ipairs(CritTalents(ctx.D)[ctx.entry.key] or {}) do
		local ranks = Table(talent.r) or {}
		local aura = Num(talent.aura)
		if aura then
			local up = AuraUp(aura)
			if up then
				extra = extra + (Num(ranks[1]) or 1)
			elseif up == nil then
				ctx.estimate = true
			end
		else
			local rank = Num(Field(ctx.state.talents, talent.talent))
			if rank and rank >= 1 then
				extra = extra + (Num(ranks[math.floor(rank)]) or 0)
			end
		end
	end
	return 1 + (base - 1) * (1 + extra)
end

local function Glancing(ctx, line)
	local glance, target = Table(ctx.model.glance) or {}, Table(ctx.read.target)
	local level, skill = target and Num(target.level), Num(line.skill)
	local lowA, lowB, lowMax = Num(glance.lowA), Num(glance.lowB), Num(glance.lowMax)
	local highA, highB, highMin, highMax = Num(glance.highA), Num(glance.highB), Num(glance.highMin), Num(glance.highMax)
	if not (level and skill and lowA and lowB and lowMax and highA and highB and highMin and highMax) then
		return nil
	end
	local d = level * 5 - skill
	local low = math.max(0, math.min(lowMax, lowA - lowB * d))
	local high = math.min(highMax, math.max(highMin, highA - highB * d))
	return (low + high) / 2
end

local function OnSwing(ctx, line, m)
	local parts = line and Table(line.parts)
	if not parts then
		return nil
	end
	local miss, dodge, parry, glance, crit = Share(parts.miss), Share(parts.dodge), Share(parts.parry), Share(parts.glance), Share(parts.crit)
	if not (miss and dodge and parry and glance and crit) then
		return nil
	end
	local g = 1
	if glance > 0 then
		g = Glancing(ctx, line)
		if not g then
			return nil
		end
	end
	local landed = 1 - miss - dodge - parry
	return landed + (m - 1) * crit - glance * (1 - g), landed
end

local schoolPiercing = setmetatable({}, { __mode = "k" })

local function SchoolPiercing(ctx, school)
	local links = Table(ctx.state.links)
	if not links then
		return 0
	end
	local kept = schoolPiercing[links]
	if not kept then
		kept = {}
		local defs, whole = Table(Field(ctx.D, "STATS")) or {}, true
		for _, link in pairs(links) do
			local text = Text(link)
			local stats = ItemStats(text)
			if text and statsOf[text] ~= stats then
				whole = false
			end
			for key, amount in pairs(stats) do
				local def = Table(defs[key])
				local at = def and def[1] == "pen" and Num(def[2])
				if at and Num(amount) then
					kept[at] = (kept[at] or 0) + amount
				end
			end
		end
		if whole then
			schoolPiercing[links] = kept
		end
	end
	return kept[school] or 0
end

local function Unresisted(ctx, line)
	local parts = line and Table(line.parts)
	local resist = parts and parts.resist
	if ctx.physical or resist == false then
		return 1
	end
	local schools = Table(ctx.entry.sch) or { ctx.entry.school }
	ctx.pierced = schools
	local C, target, level = Calc(), Table(ctx.read.target), Num(ctx.read.level)
	if not (Num(resist) and Num(line.pen) and C and level) then
		return nil
	end
	local most
	for _, school in ipairs(schools) do
		if Num(school) and school >= 2 then
			local pen = SchoolPiercing(ctx, school)
			most = most and math.max(most, pen) or pen
		end
	end
	resist = Num(Ask(C.Resist, level, level, target ~= nil and target.player == true, line.pen + (most or 0)))
	return resist and 1 - resist / 100 or nil
end

local function OnSpell(line, m)
	local parts = line and Table(line.parts)
	local hit, crit = parts and Share(parts.hit), parts and Share(parts.crit)
	if not (hit and crit) then
		return nil
	end
	return hit * (1 + crit * (m - 1)), hit
end

local function OnWeapon(line, m, entry)
	local parts = line and Table(line.parts)
	if not parts then
		return nil
	end
	local hit, block, crit = Share(parts.hit), Share(parts.block), Share(parts.crit)
	if not (hit and block and crit) then
		return nil
	end
	local nb, nd, nm = entry and entry.nb, entry and entry.nd, entry and entry.nm
	if nd then
		local miss = Share(parts.miss)
		if not miss then
			return nil
		end
		hit, block = 1 - miss, 0
	elseif nb then
		hit, block = hit + block, 0
	end
	if nm and not nd then
		local miss = Share(parts.miss)
		if not miss then
			return nil
		end
		hit = hit + miss
	elseif nm then
		hit = 1
	end
	return hit * (1 + crit * (m - 1)) + block, hit + block
end

local function LineFactor(ctx)
	local entry = ctx.entry
	if K.HEALS[entry.cmp] then
		local line = FindLine(ctx.read, "spell")
		local crit = line and Share(Field(line.parts, "crit"))
		if not crit then
			return nil
		end
		return 1 + crit * (CritMultiplier(ctx, "spell") - 1), 1
	end
	local roll = entry.roll
	if roll == "spell" then
		if ctx.physical then
			ctx.estimate, ctx.lineEstimate = true, true
		end
		local line = FindLine(ctx.read, "spell")
		local factor, land = OnSpell(line, CritMultiplier(ctx, "spell"))
		local kept = factor and (ctx.entry.cmp == "threat" and 1 or Unresisted(ctx, line))
		return kept and factor * kept or nil, land
	elseif roll == "ranged" then
		if ctx.read.noRanged then
			ctx.estimate, ctx.lineEstimate = true, true
		end
		return OnWeapon(FindLine(ctx.read, "ranged"), CritMultiplier(ctx, "ranged"), entry)
	end
	return OnWeapon(FindLine(ctx.read, "special"), CritMultiplier(ctx, "special"), entry)
end

local function Base(ctx, index, mean)
	local rank = ctx.rank
	mean = mean or Num(Pick(rank.bm, index))
	if not mean then
		return 0
	end
	local gain = Num(Pick(rank.bl, index))
	if gain and gain ~= 0 then
		local from = Num(Pick(rank.lv, index)) or Num(rank[2]) or ctx.level
		local cap = Num(Pick(rank.mx, index))
		local level = ctx.level
		if cap and cap > 0 then
			level = math.min(level, cap)
		end
		mean = mean + gain * (math.max(from, level) - from)
	end
	return mean
end

local function LowRank(ctx)
	local rule = ctx.model.downrank
	local learned = Num(ctx.rank[2])
	if not (ctx.lowRank and rule and learned) then
		return 1
	end
	local over = ctx.level - learned - (Num(rule.grace) or 0)
	if over <= 0 then
		return 1
	end
	ctx.estimate = true
	return math.max(0, 1 - (Num(rule.step) or 0) * over)
end

local function SchoolPower(stats, school)
	if not Finite(school) or school < 2 then
		return 0
	end
	return Num(Field(stats.sp, school)) or 0
end

local function SpellPower(ctx, part)
	if part[1] == "heal" then
		return Num(ctx.stats.heal) or 0
	end
	local schools = Table(part.sch) or Table(ctx.entry.sch)
	if schools then
		local least
		for _, school in ipairs(schools) do
			local power = SchoolPower(ctx.stats, school)
			least = least and math.min(least, power) or power
		end
		return least or 0
	end
	return SchoolPower(ctx.stats, ctx.entry.school)
end

local function Amount(ctx, part, index)
	local stat = part[1]
	if part.per == "self" or stat == "wpn" then
		return 0
	end
	Basis(ctx, part.b)
	local coef = Num(Pick(ctx.rank.c, index)) or Num(part[2]) or 0
	local base = Base(ctx, index)
	if part.per == "cp" then
		local points = Table(part.cp)
		base = base + (Num(ctx.rank.cpb) or 0) * 5
		coef = points and Num(points[5]) or coef * 5
	end
	local stats = ctx.stats
	if stat == "sp" or stat == "heal" then
		return base + coef * LowRank(ctx) * SpellPower(ctx, part)
	elseif stat == "ap" then
		return base + coef * (Num(stats.ap) or 0)
	elseif stat == "rap" then
		return base + coef * (Num(stats.rap) or 0)
	elseif stat == "bv" then
		return base + coef * (Num(stats.block) or 0)
	end
	return base
end

local function PartAmount(ctx, part, index)
	local amount = Amount(ctx, part, index)
	local free = Num(part.free)
	if free and amount ~= 0 then
		ctx.estimate = true
		return amount * free
	end
	return amount
end

local function HandMean(ctx, slot, form)
	local mean, speed = WeaponMean(ctx.state, slot)
	form = form or ctx.form
	if slot == K.MAIN and form then
		local swing = Num(Field(ctx.model.form, form)) or 1
		local paw = mean and speed and mean / speed * swing or K.PAW_LEAST
		return math.max(K.PAW_LEAST, paw), swing
	end
	if mean then
		return mean, speed
	elseif slot == K.MAIN then
		ctx.estimate = true
		return 0, K.UNARMED_SPEED
	end
	return nil
end

local function StrikeSpeed(ctx, part, slot, own)
	if ctx.form then
		return own
	end
	local spd, norm = part.spd or "actual", Table(ctx.model.norm) or {}
	if spd == "norm" then
		local weapon = Worn(ctx.state, slot)
		if weapon and weapon.twoHand then
			return Num(norm.two) or own
		elseif weapon and weapon.dagger then
			return Num(norm.dagger) or own
		end
		return Num(norm.one) or own
	elseif spd == "nranged" then
		return Num(norm.ranged) or own
	elseif spd == "cat" or spd == "bear" then
		return Num(Field(ctx.model.form, spd)) or own
	end
	return own
end

local function HandStrike(ctx, part, index, slot)
	local form = (part.spd == "cat" or part.spd == "bear") and slot == K.MAIN and part.spd or nil
	local mean, own = HandMean(ctx, slot, form)
	if not own then
		return nil
	end
	local power, damage
	if slot == K.RANGED then
		power, damage = Num(ctx.stats.rap) or 0, Table(ctx.stats.rdmg) or {}
		local ammo, standIn = AmmoFor(ctx.state)
		mean = mean + ammo * own
		if standIn then
			ctx.estimate = true
		end
	else
		power, damage = Num(ctx.stats.ap) or 0, Table(ctx.stats.dmg) or {}
	end
	local flat = ctx.physical and (Num(damage.flat) or 0) or 0
	local pct = ctx.physical and (Num(damage.pct) or 1) or 1
	local weapon = mean + power / ctx.perDps * StrikeSpeed(ctx, part, slot, own)
	if slot == K.OFF then
		weapon = weapon * ctx.offFactor
	end
	local multiple = Num(Pick(ctx.rank.w, index)) or Num(part[2]) or 1
	local main = Worn(ctx.state, K.MAIN)
	if Num(part.dg) and main and main.dagger == true then
		multiple = part.dg
	end
	return (weapon + flat + Base(ctx, index)) * multiple * pct
end

local function WeaponPart(ctx, part, index)
	local hand, value = part.h or "main", nil
	if hand == "both" then
		local main = HandStrike(ctx, part, index, K.MAIN)
		local off = main and ctx.state.dual == true and HandStrike(ctx, part, index, K.OFF) or nil
		value = main and main + (off or 0) or nil
	else
		value = HandStrike(ctx, part, index, hand == "off" and K.OFF or hand == "ranged" and K.RANGED or K.MAIN)
	end
	if value ~= nil then
		Basis(ctx, part.b)
	end
	return value
end

local function CastSeconds(ctx)
	local info = Num(ctx.id) and Table(Call(Api("C_Spell", "GetSpellInfo"), ctx.id))
	local ms = Num(Field(info, "castTime")) or Num(ctx.rank.ct)
	if not ms or ms < 0 then
		ms = 0
	end
	return math.max(ms / 1000 * ctx.castScale, Num(ctx.model.gcd) or 1.5)
end

local function Duration(ctx)
	local du = Num(ctx.rank.du)
	if du and du > 0 then
		return du / 1000
	end
	for index, part in ipairs(Table(ctx.entry.parts) or {}) do
		local ticks, period = Num(Pick(ctx.rank.n, index)) or Num(part.n), Num(part.p)
		if ticks and period and ticks > 0 and period > 0 then
			return ticks * period
		end
	end
	return nil
end

local function Speed(ctx, hand, slot)
	local speed = Num(Field(ctx.stats.speed, hand))
	if speed and speed > 0 then
		return speed
	end
	local _, own = HandMean(ctx, slot)
	return own or K.UNARMED_SPEED
end

local EXPECT = {}

local function Suits(entry, part)
	if K.HEALS[entry.cmp] then
		return part[1] == "heal"
	end
	return part[1] ~= "heal"
end

local function MainWeapon(entry)
	for _, part in ipairs(Table(entry.parts) or {}) do
		if part[1] == "wpn" and part.h ~= "off" then
			return true
		end
	end
	return false
end

local function Wears(ctx)
	local needs = ctx.entry.needs
	if needs == "dagger" then
		local main = Worn(ctx.state, K.MAIN)
		return main ~= nil and main.dagger == true
	elseif needs == "shield" then
		return ctx.state.shield == true
	end
	return true
end

local function Damage(ctx)
	local entry, amount, missing = ctx.entry, 0, not Wears(ctx)
	local spare = MainWeapon(entry)
	for index, part in ipairs(Table(entry.parts) or {}) do
		if not Suits(entry, part) then
		elseif part[1] == "wpn" then
			local value = WeaponPart(ctx, part, index)
			if value ~= nil then
				amount = amount + value
			elseif not (part.h == "off" and spare) then
				missing = true
			end
		else
			amount = amount + PartAmount(ctx, part, index) * ctx.pct
		end
	end
	local factor, land = LineFactor(ctx)
	if missing then
		factor, land = 0, 0
	elseif not factor then
		ctx.why = K.WHY.withheld
		return
	end
	ctx.cast, ctx.land = amount * factor, land
	if entry.nx then
		return
	end
	ctx.time = K.LASTING[entry.cmp] and Duration(ctx) or CastSeconds(ctx)
	if ctx.time and ctx.time > 0 then
		ctx.second = ctx.cast / ctx.time
	end
end

EXPECT.spell, EXPECT.dot, EXPECT.channel, EXPECT.heal, EXPECT.hot = Damage, Damage, Damage, Damage, Damage
EXPECT.apstrike, EXPECT.finisher = Damage, Damage

local function SwingMean(ctx, slot)
	local mean, own = HandMean(ctx, slot)
	if not own then
		return nil
	end
	local damage = Table(ctx.stats.dmg) or {}
	local weapon = mean + (Num(ctx.stats.ap) or 0) / ctx.perDps * own
	if slot == K.OFF then
		weapon = weapon * ctx.offFactor
	end
	return (weapon + (Num(damage.flat) or 0)) * (Num(damage.pct) or 1)
end

function EXPECT.auto(ctx)
	ctx.perSecond = true
	local main = FindLine(ctx.read, "main")
	local dual = main ~= nil
	main = main or FindLine(ctx.read, "swing")
	local m = CritMultiplier(ctx, "swing")
	local factor = OnSwing(ctx, main, m)
	local swing = SwingMean(ctx, K.MAIN)
	if not (factor and swing) then
		ctx.why = K.WHY.withheld
		return
	end
	local hit = swing * factor
	local cast, second = hit, hit / Speed(ctx, "main", K.MAIN)
	if dual then
		local offFactor, offSwing = OnSwing(ctx, FindLine(ctx.read, "off"), m), SwingMean(ctx, K.OFF)
		if offFactor and offSwing then
			local offHit = offSwing * offFactor
			cast, second = cast + offHit, second + offHit / Speed(ctx, "off", K.OFF)
		end
	end
	ctx.cast, ctx.second = cast, second
	if ctx.swap and ctx.read.mainMoved == true then
		ctx.estimate = true
	end
end

function EXPECT.strike(ctx)
	Damage(ctx)
	if not (ctx.entry.nx and ctx.cast) then
		return
	end
	local m = Num(Field(ctx.model.crit, "swing")) or 2
	local factor, swing = OnSwing(ctx, FindLine(ctx.read, "main") or FindLine(ctx.read, "swing"), m), SwingMean(ctx, K.MAIN)
	if factor and swing then
		ctx.swing, ctx.swings = swing * factor, 1 / Speed(ctx, "main", K.MAIN)
	end
end

function EXPECT.shot(ctx)
	ctx.perSecond = true
	local mean, own = HandMean(ctx, K.RANGED)
	if not own then
		ctx.cast, ctx.second = 0, 0
		return
	end
	local damage = Table(ctx.stats.rdmg) or {}
	local ammo, standIn = AmmoFor(ctx.state)
	if standIn then
		ctx.estimate = true
	end
	local shot = (mean + ammo * own + (Num(ctx.stats.rap) or 0) / ctx.perDps * own + (Num(damage.flat) or 0)) * (Num(damage.pct) or 1)
	local factor = OnWeapon(FindLine(ctx.read, "ranged"), CritMultiplier(ctx, "ranged"), ctx.entry)
	if not factor then
		ctx.why = K.WHY.withheld
		return
	end
	ctx.cast = shot * factor
	ctx.second = ctx.cast / Speed(ctx, "ranged", K.RANGED)
end

function EXPECT.wand(ctx)
	ctx.perSecond, ctx.estimate = true, true
	local mean, own = HandMean(ctx, K.RANGED)
	if not own then
		ctx.cast, ctx.second = 0, 0
		return
	end
	local factor = OnSpell(FindLine(ctx.read, "spell"), CritMultiplier(ctx, "spell"))
	if not factor then
		ctx.why = K.WHY.withheld
		return
	end
	ctx.cast = mean * (Num(Field(ctx.stats.rdmg, "pct")) or 1) * factor
	ctx.second = ctx.cast / Speed(ctx, "ranged", K.RANGED)
end

local function Landed(ctx)
	local swing = FindLine(ctx.read, "main") or FindLine(ctx.read, "swing")
	local _, landed = OnSwing(ctx, swing, 2)
	return landed
end

function EXPECT.seal(ctx)
	ctx.perSecond, ctx.estimate = true, true
	local index, part = 1, nil
	for at, each in ipairs(Table(ctx.entry.parts) or {}) do
		if each[1] == "sp" then
			index, part = at, each
			break
		end
	end
	local _, own = HandMean(ctx, K.MAIN)
	local two = TwoHandWorn(ctx.state)
	local seal = K.SEAL
	local hand = two and seal.two or seal.one - seal.step * math.max(0, seal.at - own)
	local share = part and (two and Num(part.two) or Num(part[2])) or 0
	local hit = Base(ctx, index, Num(ctx.rank.sv)) / 100 * own * hand + share * LowRank(ctx) * SchoolPower(ctx.stats, ctx.entry.school)
	local special = FindLine(ctx.read, "special")
	local crit = special and Share(Field(special.parts, "crit"))
	local landed = Landed(ctx)
	if not (crit and landed) then
		ctx.why = K.WHY.withheld
		return
	end
	ctx.cast = hit * (1 + crit * (CritMultiplier(ctx, "special") - 1))
	ctx.second = ctx.cast * landed / Speed(ctx, "main", K.MAIN)
end

local function OnSwings(entry)
	return K.PER_SECOND[entry.cmp] == true and (entry.cmp ~= "proc" or K.PPM[entry.key] ~= nil)
end

function EXPECT.proc(ctx)
	Damage(ctx)
	ctx.second, ctx.time = nil, nil
	if not OnSwings(ctx.entry) then
		return
	end
	ctx.perSecond, ctx.estimate = true, true
	local rate, landed = K.PPM[ctx.entry.key], Landed(ctx)
	local _, own = HandMean(ctx, K.MAIN)
	if ctx.cast and landed and own then
		ctx.second = ctx.cast * rate / 60 * landed * own / Speed(ctx, "main", K.MAIN)
	end
end

function EXPECT.threat(ctx)
	local _, land = LineFactor(ctx)
	if ctx.entry.roll == nil then
		land = 1
	end
	ctx.land = land
	ctx.time = CastSeconds(ctx)
end

local function Multiplier(ctx)
	local M = Model()
	if not (M and type(M.Multiplier) == "function") then
		return 1
	end
	local ok, value, _, basis = pcall(M.Multiplier, ctx.entry, ctx.state)
	if not ok or not Finite(value) then
		return 1
	end
	ThreatBasis(ctx, basis)
	return value
end

local function ThreatFlat(ctx, spec)
	local rank = ctx.rankIndex
	local value = Num(Pick(spec.v, rank)) or 0
	local gain = Num(Pick(spec.pl, rank))
	if gain and gain ~= 0 then
		local from = Num(ctx.rank[2]) or ctx.level
		local cap = Num(Pick(spec.mx, rank))
		local level = ctx.level
		if cap and cap > 0 then
			level = math.min(level, cap)
		end
		value = value + gain * (math.max(from, level) - from)
	end
	return value
end

local function InForms(form, forms)
	form = Num(form) or 0
	if type(forms) == "number" then
		return forms == form
	end
	for _, each in ipairs(Table(forms) or {}) do
		if each == form then
			return true
		end
	end
	return false
end

local function ThreatParts(ctx, spec)
	local kind, rank = spec and spec.k, ctx.rankIndex
	if spec then
		ThreatBasis(ctx, Letter(spec.b, rank))
	end
	if K.HEALS[ctx.entry.cmp] and (kind == nil or kind == "heal") then
		local paladin = Num(Field(ctx.D.HEAL_THREAT, ctx.entry.key))
		return paladin or (kind == "heal" and Num(Pick(spec.v, rank))) or Num(ctx.model.healThreat) or 0.5, 0
	elseif kind == nil then
		return 1, 0
	elseif kind == "mult" then
		return Num(Pick(spec.v, rank)) or 1, 0
	elseif kind == "bonus" then
		return 1, ThreatFlat(ctx, spec)
	elseif kind == "flat" then
		return 0, ThreatFlat(ctx, spec)
	elseif kind == "more" then
		ctx.threatEstimate = true
		return Num(Pick(spec.v, rank)) or 1, 0
	elseif kind == "drop" then
		return 0, -math.abs(ThreatFlat(ctx, spec))
	elseif kind == "temp" then
		return 0, -math.abs(ThreatFlat(ctx, spec)), true
	elseif kind == "caster" then
		if spec.forms ~= nil and not InForms(ctx.state.form, spec.forms) then
			return 0, 0
		end
		return 0, (Num(Pick(spec.v, rank)) or 2) * ctx.level
	elseif kind == "none" then
		return 0, 0
	end
	return nil
end

local function ThreatFlags(ctx, T, flat)
	if T ~= 0 then
		ctx.threatEstimate = ctx.threatEstimate or ctx.estimate
		ThreatBasis(ctx, ctx.basis)
	end
	if flat and ctx.lineEstimate then
		ctx.threatEstimate = true
	end
end

local function Threat(ctx)
	local spec = Table(ctx.entry.threat)
	local T, F, alone = ThreatParts(ctx, spec)
	if T == nil then
		if spec and spec.k == "unknown" then
			ctx.threatWhy = K.WHY.threat
		end
		return
	end
	local G = alone and 1 or Multiplier(ctx)
	if ctx.perSecond then
		if ctx.second then
			ctx.threat = ctx.second * T * G
			ctx.threatSecond = ctx.threat
		end
		ThreatFlags(ctx, T, false)
		return
	end
	local A = spec and Num(spec.ap) or 0
	if A ~= 0 then
		ThreatBasis(ctx, spec.apb)
	end
	local kind = spec and spec.k
	local whole = kind == "drop" or kind == "temp"
	local land = whole and 1 or ctx.land
	ThreatFlags(ctx, T, (F ~= 0 or A ~= 0) and not whole)
	local flat = 0
	if F ~= 0 or A ~= 0 then
		if not land then
			ctx.why = ctx.why or K.WHY.withheld
			return
		end
		flat = land * (F + A * (Num(ctx.stats.ap) or 0))
	end
	ctx.threat = (ctx.cast or 0) * T * G + flat * G
	if ctx.time and ctx.time > 0 and not ctx.entry.nx then
		ctx.threatSecond = ctx.threat / ctx.time
	end
	if ctx.swing then
		ctx.swingThreat = ctx.swing * G
	end
end

local function RankOf(entry, line)
	local ranks = Table(entry.ranks)
	if not ranks then
		return nil
	end
	local index = Num(line.rank)
	if index and Table(ranks[index]) then
		return index, ranks[index]
	end
	local id = Num(line.id)
	if id then
		for at, rank in ipairs(ranks) do
			if rank[1] == id then
				return at, rank
			end
		end
	end
	local M = Model()
	local best = M and Num((Ask(M.Highest, entry)))
	if best and Table(ranks[best]) then
		return best, ranks[best]
	end
	if #ranks > 0 then
		return #ranks, ranks[#ranks]
	end
	return nil
end

function G.Expect(line, state, stats, opts)
	local result = {}
	line = Table(line)
	local entry = line and Table(line.entry)
	local fn = entry and EXPECT[entry.cmp]
	if not fn then
		result.why = K.WHY.notCompared
		return result
	elseif entry.pet then
		result.why = K.WHY.pet
		return result
	end
	local D, C = Data(), Calc()
	stats = Table(stats)
	if not (D and C) then
		result.why = K.WHY.data
		return result
	elseif not stats then
		result.why = K.WHY.stats
		return result
	end
	state, opts = Table(state) or {}, Table(opts) or {}
	local rankIndex, rank = RankOf(entry, line)
	if not rank then
		result.why = K.WHY.rank
		return result
	end
	local M = Model()
	local inputs = Table(opts.inputs) or G.Inputs() or (M and InputsNow(M))
	if not inputs then
		result.why = K.WHY.inputs
		return result
	end
	local spec = Spec(opts, state)
	local swap = Table(stats.swap)
	local version = tostring(M and Ask(M.Version))
	local physical = entry.school == 1
	local damage
	if entry.roll == "ranged" then
		damage = Table(stats.rdmg) or {}
	else
		damage = Table(stats.dmg) or {}
	end
	local ctx = { D = D, model = D.MODEL, entry = entry, rank = rank, rankIndex = rankIndex, id = Num(line.id) or Num(rank[1]),
		level = Num(inputs.level) or Num(state.level) or K.MAX_LEVEL, state = state, stats = stats, swap = swap, inputs = inputs,
		read = TableFor(state, stats, inputs, spec, C, version), lowRank = spec.lowRank, basis = "c", estimate = false, threatBasis = "c",
		threatEstimate = false, lineEstimate = false, form = FormOf(state), physical = physical, pct = physical and (Num(damage.pct) or 1) or 1,
		castScale = swap and Num(swap.castScale) or 1, offFactor = swap and Num(swap.offFactor) or OffFactor(state, stats),
		perDps = Num(D.MODEL.apPerDps) or 14 }
	fn(ctx)
	if not ctx.why then
		Threat(ctx)
	end
	result.cast, result.second, result.threat, result.threatSecond = Num(ctx.cast), Num(ctx.second), Num(ctx.threat), Num(ctx.threatSecond)
	result.basis = ctx.estimate and "e" or ctx.basis
	result.estimate = ctx.estimate == true
	result.threatBasis = ctx.threatEstimate and "e" or ctx.threatBasis
	result.threatEstimate = ctx.threatEstimate == true
	result.perSecond = ctx.perSecond == true
	result.swing, result.swingThreat, result.swings = Num(ctx.swing), Num(ctx.swingThreat), Num(ctx.swings)
	result.why, result.threatWhy = ctx.why, ctx.threatWhy
	result.pierced = ctx.pierced
	return result
end

function G.Figure(line, role, mode)
	local entry = Table(Field(line, "entry"))
	local cmp = entry and entry.cmp
	if not (cmp and EXPECT[cmp]) or entry.pet then
		return nil
	elseif cmp == "threat" or mode == "threat" then
		return "threat"
	elseif mode == "second" then
		if entry.nx then
			return nil
		end
		return "second"
	elseif mode == "cast" then
		return OnSwings(entry) and "second" or "cast"
	elseif role == "tank" then
		return "threat"
	elseif OnSwings(entry) then
		return "dps"
	end
	return "cast"
end

local function FigureOf(result, figure)
	if figure == "dps" or figure == "second" then
		return result.second
	elseif figure == "threat" then
		return result.threat
	end
	return result.cast
end

local function Change(row)
	if Finite(row.now) and Finite(row.with) and row.now ~= 0 then
		return (row.with - row.now) / math.abs(row.now) * 100
	end
	return nil
end

local nowKept = { stamp = nil, values = {} }

local function Now(line, state, stats, opts, stamp)
	if nowKept.stamp ~= stamp then
		nowKept.stamp, nowKept.values = stamp, {}
	end
	local key = tostring(line.entry.key) .. "#" .. tostring(line.rank or line.id)
	local value = nowKept.values[key]
	if not value then
		value = G.Expect(line, state, stats, opts)
		nowKept.values[key] = value
	end
	return value
end

local function Rows(chosen, state, stats, state2, stats2, work, reverse, fresh)
	local rows = {}
	local opts = work.opts
	for _, line in ipairs(chosen) do
		local figure = G.Figure(line, work.role, work.mode)
		local row = { line = line, figure = figure }
		if figure then
			local worn = fresh and G.Expect(line, state, stats, opts) or Now(line, state, stats, opts, work.stamp)
			local other = G.Expect(line, state2, stats2, opts)
			if reverse then
				worn, other = other, worn
			end
			row.now, row.with = FigureOf(worn, figure), FigureOf(other, figure)
			if figure == "threat" then
				row.nowEstimate, row.withEstimate = worn.threatEstimate == true, other.threatEstimate == true
				row.basis = Worse(worn.threatBasis, other.threatBasis)
			else
				row.nowEstimate, row.withEstimate = worn.estimate == true, other.estimate == true
				row.basis = Worse(worn.basis, other.basis)
			end
			row.estimate = row.nowEstimate or row.withEstimate
			row.perSecond = figure == "dps" or figure == "second" or (figure == "threat" and (worn.perSecond == true or other.perSecond == true))
			if (figure == "cast" or figure == "threat") and worn.swings and other.swings then
				local field = figure == "threat" and "swingThreat" or "swing"
				row.nowSwing, row.withSwing, row.nowSwings, row.withSwings = worn[field], other[field], worn.swings, other.swings
			end
			row.why = worn.why or other.why or (figure == "threat" and (worn.threatWhy or other.threatWhy)) or nil
			row.pierced = Table(other.pierced) or Table(worn.pierced)
		end
		rows[#rows + 1] = row
	end
	return rows
end

local function PierceNotes(info, rows)
	for _, pierce in ipairs(Table(info.pierce) or {}) do
		local school, taken = pierce[1], false
		for _, row in ipairs(rows) do
			local pierced = Table(row.pierced)
			if pierced and school == 0 then
				taken = true
			elseif pierced then
				for _, at in ipairs(pierced) do
					taken = taken or at == school
				end
			end
		end
		if not taken then
			local name = K.PIERCE[school] or K.PIERCE[0]
			AddOnce(info.notCounted, K.PIERCE_NOTE:format(name[1], Signed(pierce[2]), name[2]))
		end
	end
	info.pierce = nil
end

local Minute

local function Mean(rows, limit, role, mode, rotation)
	local any, moved, n = false, false, 0
	for _, row in ipairs(rows) do
		if row.figure and Finite(row.now) and Finite(row.with) then
			any, n = true, n + 1
			local change = Change(row)
			if (change and math.abs(change) >= K.NONE_UNDER) or (row.now == 0 and row.with ~= 0) then
				moved = true
			end
		end
	end
	local sums = Minute(rows, {}, limit and n > limit + 1 and limit or nil, rotation)
	local kind = K.ROLE_KIND[role]
	if kind == "threat" and mode ~= "threat" and mode ~= "tooltip" then
		kind = nil
	end
	local mean
	for _, each in ipairs({ kind or "damage", "damage", "healing", "threat" }) do
		local sum = sums[each]
		if sum and sum.now ~= 0 then
			mean = (sum.with - sum.now) / math.abs(sum.now) * 100
			break
		end
	end
	return mean, any and not moved
end

local function Header(candidate, state, unit)
	local names = {}
	for _, slot in ipairs(candidate.slots) do
		local link = LinkAt(state, slot)
		local name = link and Coloured(link)
		if name then
			names[#names + 1] = name
		end
	end
	if #names == 0 then
		if candidate.label == K.BOTH then
			return ("In your empty hands, %s:"):format(unit)
		end
		return ("In your empty %s slot, %s:"):format(candidate.label, unit)
	elseif candidate.offEmpty then
		return ("Instead of %s, off hand empty, %s:"):format(table.concat(names, " and "), unit)
	end
	return ("Instead of %s (%s), %s:"):format(table.concat(names, " and "), candidate.label, unit)
end

local function Merge(into, from)
	for _, text in ipairs(from) do
		AddOnce(into, text)
	end
end

local function SkillNotes(info, states, slots, inputs)
	local C = Calc()
	inputs = Table(inputs) or {}
	if not C or inputs.feral then
		return
	end
	local most = (Num(inputs.level) or K.MAX_LEVEL) * 5
	for _, state in ipairs(states) do
		for _, slot in ipairs(slots) do
			local weapon = (slot == K.MAIN or slot == K.OFF or slot == K.RANGED) and Worn(state, slot) or nil
			local line = weapon and Num(weapon.line)
			local got = line and Table(Ask(C.SkillLine, line))
			local rank = got and Num(got.rank)
			if rank and rank < most then
				AddOnce(info.skills, K.SKILL_NOTE:format(Text(got.name) or K.SKILL_ANY, math.floor(rank), math.floor(most)))
			end
		end
	end
end

local function Replaced(state, slots, info)
	for _, slot in ipairs(slots) do
		local link = LinkAt(state, slot)
		local worn = link and ItemOf(link, nil, slot)
		if worn then
			Notes(worn, info, true)
		end
	end
end

local function Instead(result, link, opts, chosen, state, stats, work)
	local data = Table(opts.data)
	local item, why, quiet = ItemOf(link, data and Field(data, "lines"))
	if not item then
		result.why, result.quiet = why, quiet
		return why ~= K.WHY.loading
	end
	local baseItem, loading
	if work.base then
		baseItem, why, loading = BaseItem(work.base)
		if not baseItem then
			result.why, result.quiet = why, false
			return not loading
		end
	end
	Notes(item, result)
	local list
	list, why, quiet = Candidates(state, link, item.id, item.loc, item.lines, Text(Field(data, "guid")) or Text(opts.guid), item.subclass)
	if not list then
		result.why, result.quiet = why, quiet
		return true
	end
	local best, bestMean = nil, nil
	for _, candidate in ipairs(list) do
		local info = NewInfo()
		local nowState, nowStats, baseSlots = state, stats, nil
		if baseItem then
			nowState, nowStats, baseSlots = BaseSwap(state, stats, baseItem, candidate.slots, info)
		end
		if nowState then
			local state2, stats2 = Swap(state, stats, item, candidate.slots, info)
			if not baseItem then
				Replaced(state, candidate.slots, info)
			end
			SkillNotes(info, { nowState, state2 }, candidate.slots, work.opts.inputs)
			candidate.base, candidate.baseSlots = work.base, baseSlots
			candidate.rows = Rows(chosen, nowState, nowStats, state2, stats2, work, false, baseItem ~= nil)
			PierceNotes(info, candidate.rows)
			candidate.mean, candidate.noChange = Mean(candidate.rows, work.limit, work.role, work.mode, work.rotation)
			candidate.rotation = work.rotation or false
			candidate.header, candidate.notCounted, candidate.vs = Header(candidate, nowState, work.unit), info.notCounted, info.vs
			candidate.skills = info.skills
			local index = #result.candidates + 1
			if best == nil or (candidate.mean ~= nil and (bestMean == nil or candidate.mean > bestMean)) then
				best, bestMean = index, candidate.mean
			end
			result.candidates[index] = candidate
		end
	end
	if not best then
		result.why, result.quiet = K.WHY.baseSlot:format(Coloured(work.base) or baseItem.name), false
		return true
	end
	local chosenOne = result.candidates[best]
	result.best, result.header, result.noChange = best, chosenOne.header, chosenOne.noChange
	for at = 0, #result.candidates do
		local candidate = at == 0 and chosenOne or result.candidates[at]
		Merge(result.notCounted, candidate.notCounted)
		Merge(result.vs, candidate.vs)
		Merge(result.skills, candidate.skills)
	end
	return true
end

local function WhatItGives(result, slot, chosen, state, stats, work)
	local link = LinkAt(state, slot)
	if not link then
		result.why, result.quiet = K.WHY.empty, true
		return true
	end
	local slots = { slot }
	if slot == K.MAIN and TwoHandWorn(state) then
		slots = { K.MAIN, K.OFF }
	end
	local worn = ItemOf(link, nil, slot)
	if worn then
		Notes(worn, result)
	end
	local state2, stats2, baseName
	if work.base then
		local baseItem, why, loading = BaseItem(work.base)
		if not baseItem then
			result.why, result.quiet = why, false
			return not loading
		end
		baseName = Coloured(work.base) or baseItem.name
		state2, stats2 = BaseSwap(state, stats, baseItem, slots, result)
		if not state2 then
			result.why, result.quiet = K.WHY.baseSlot:format(baseName), false
			return true
		end
	else
		state2, stats2 = Swap(state, stats, nil, slots, result)
	end
	SkillNotes(result, { state, state2 }, slots, work.opts.inputs)
	local candidate = { slots = slots, label = Label(slots), empty = false, game = true, offEmpty = false, base = work.base, skills = result.skills }
	candidate.rows = Rows(chosen, state, stats, state2, stats2, work, true, false)
	PierceNotes(result, candidate.rows)
	candidate.mean, candidate.noChange = Mean(candidate.rows, work.limit, work.role, work.mode, work.rotation)
	candidate.rotation = work.rotation or false
	if baseName then
		candidate.header = ("What it gives your spells instead of %s, %s:"):format(baseName, work.unit)
	else
		candidate.header = ("What it gives your spells, %s:"):format(work.unit)
	end
	result.candidates[1], result.best, result.header, result.noChange = candidate, 1, candidate.header, candidate.noChange
	return true
end

local function Chosen(lines)
	lines = Table(lines)
	if not lines and type(ns.GearChosen) == "function" then
		lines = Table(Ask(ns.GearChosen))
	end
	local out = {}
	for _, line in ipairs(lines or {}) do
		if Table(line) and Table(line.entry) then
			out[#out + 1] = line
		end
	end
	return out
end

local function Auras(D)
	local parts = {}
	for _, talent in ipairs(Table(D.CRIT) or {}) do
		local aura = Num(talent.aura)
		if aura then
			local up = AuraUp(aura)
			parts[#parts + 1] = aura .. (up == true and "+" or up == false and "-" or "?")
		end
	end
	return table.concat(parts, ",")
end

local cache, kept, last, lastKept = {}, {}, {}, {}

local function Store(store, order, key, value)
	if store[key] == nil then
		order[#order + 1] = key
		if #order > K.CACHE then
			store[table.remove(order, 1)] = nil
		end
	end
	store[key] = value
end

function G.Compare(itemOrSlot, lines, opts)
	opts = Table(opts) or {}
	local mode = K.MODES[opts.mode] and opts.mode or "tooltip"
	local result = { candidates = {}, notCounted = {}, vs = {}, skills = {} }
	local M, D, C = Model(), Data(), Calc()
	if not (M and D and C) then
		result.why, result.quiet = K.WHY.data, true
		return result
	end
	Register()
	local slot = Num(itemOrSlot)
	local link = not slot and Text(itemOrSlot) or nil
	if not (slot or link) then
		result.why, result.quiet = K.WHY.item, true
		return result
	end
	local state = Table(Ask(M.State)) or {}
	local base = Text(opts.base)
	local subject = (slot and ("slot " .. slot .. " " .. (LinkAt(state, slot) or "")) or link) .. "|" .. (base or "")
	local stats = Table(Ask(M.Stats))
	local again = subject .. "|" .. mode
	result.base = base
	if InCombat() or (stats and stats.old == true) then
		if last[again] then
			local before = Copy(last[again])
			before.old = true
			return before
		end
		result.why = K.WHY.combat
		return result
	elseif not stats then
		result.why = K.WHY.stats
		return result
	end
	local spec = Spec(opts, state)
	local role = Text(opts.role) or Role(state)
	local rotation = Rotation(state, role)
	local listVersion = Num(opts.listVersion) or Num(type(ns.GearListVersion) == "function" and Ask(ns.GearListVersion)) or 0
	local key = table.concat({ subject, tostring(Ask(M.Version)), tostring(listVersion), mode, spec.key, role, Auras(D),
		rotation and rotation.id or "" }, "|")
	if cache[key] then
		return cache[key]
	end
	local inputs = Table(opts.inputs) or InputsNow(M)
	if not inputs then
		result.why = K.WHY.stats
		return result
	end
	local most = Num(opts.most) or Num(ns.Get("chat.gearMost")) or 5
	local work = { mode = mode, role = role, unit = K.UNITS[mode], limit = mode == "tooltip" and most or nil, base = base, rotation = rotation,
		opts = { against = spec.against, facing = spec.facing, rules = spec.rules, lowRank = spec.lowRank, inputs = inputs, full = true },
		stamp = table.concat({ tostring(Ask(M.Version)), spec.key, tostring(inputs), tostring(stats), tostring(state) }, "|") }
	local chosen = Chosen(lines)
	local keep
	if slot then
		keep = WhatItGives(result, slot, chosen, state, stats, work)
	else
		keep = Instead(result, link, opts, chosen, state, stats, work)
	end
	result.sizes = held.sizes
	if keep then
		Store(cache, kept, key, result)
		Store(last, lastKept, again, result)
	end
	return result
end

local function WeightOf(value)
	value = Num(value)
	if value then
		return math.max(0, math.min(K.WEIGHT_MOST, value))
	end
	return nil
end

local function LineKey(line)
	local entry = Table(Field(line, "entry"))
	local key = Text(Field(line, "key")) or (entry and Text(entry.key))
	if not key then
		return nil
	end
	return key .. "#" .. tostring(Num(Field(line, "rank")) or Num(Field(line, "id")) or ""), key
end

local function Weights(lines)
	local by = {}
	for _, line in ipairs(Table(lines) or {}) do
		local weight = Table(line) and WeightOf(line.weight)
		if weight then
			by[line] = weight
			local exact, key = LineKey(line)
			if exact then
				by[exact] = weight
				if by[key] == nil then
					by[key] = weight
				end
			end
		end
	end
	return by
end

local function TotalKind(row)
	if row.figure == "threat" then
		return "threat"
	end
	local entry = Table(Field(row.line, "entry"))
	if entry and K.HEALS[entry.cmp] then
		return "healing"
	end
	return "damage"
end

local function LineName(line)
	local entry = Table(Field(line, "entry"))
	return Text(Field(line, "name")) or (entry and Text(entry.key)) or "?"
end

local function Uses(value, swing, swings, uses, share)
	if Finite(swing) and Finite(swings) and swings > 0 then
		local most = K.MINUTE * swings
		if share then
			uses = share * most
		end
		return (value - swing) * math.min(uses, most)
	end
	return value * uses
end

function Minute(rows, weights, limit, rotation)
	local gcd = Num(Field(Field(Data(), "MODEL"), "gcd")) or K.GCD
	local abilities = rotation and Table(rotation.abilities)
	local shares = rotation and Table(Field(rotation.swings, "next"))
	local counted, casts, rotated, shown, sums = {}, {}, {}, 0, {}
	for _, row in ipairs(rows) do
		if Table(row) and row.figure and Finite(row.now) and Finite(row.with) then
			shown = shown + 1
			if not limit or shown <= limit then
				local line = Table(row.line)
				local exact, key = LineKey(line)
				local weight = (line and weights[line]) or (exact and weights[exact]) or (key and weights[key]) or WeightOf(Field(line, "weight"))
					or K.WEIGHT
				local kind = TotalKind(row)
				local sum = sums[kind] or { now = 0, with = 0, moved = 0, guessed = 0, n = 0 }
				sums[kind] = sum
				local change = Change(row)
				if change then
					local pct = change / 100
					if not sum.best or pct > sum.best.pct then
						sum.best = { name = LineName(line), pct = pct }
					end
					if not sum.worst or pct < sum.worst.pct then
						sum.worst = { name = LineName(line), pct = pct }
					end
				end
				if weight > 0 then
					local one = { row = row, weight = weight, kind = kind }
					counted[#counted + 1] = one
					if row.perSecond ~= true then
						casts[kind] = (casts[kind] or 0) + 1
						local used = abilities and key and Table(abilities[key])
						one.uses = used and Num(used.m) or 0
						one.share = shares and key and Num(shares[key]) or nil
						if one.uses > 0 or one.share then
							rotated[kind] = true
						end
					end
				end
			end
		end
	end
	for _, one in ipairs(counted) do
		local row, weight = one.row, one.weight
		local now, with
		if row.perSecond == true then
			now, with = row.now * K.MINUTE * weight, row.with * K.MINUTE * weight
		elseif rotated[one.kind] then
			if one.uses > 0 or one.share then
				now = Uses(row.now, row.nowSwing, row.nowSwings, one.uses, one.share) * weight
				with = Uses(row.with, row.withSwing, row.withSwings, one.uses, one.share) * weight
			end
		else
			local uses = K.MINUTE / gcd / casts[one.kind]
			now = Uses(row.now, row.nowSwing, row.nowSwings, uses) * weight
			with = Uses(row.with, row.withSwing, row.withSwings, uses) * weight
		end
		if now and with then
			local sum = sums[one.kind]
			local moved = math.abs(with - now)
			sum.now, sum.with, sum.moved, sum.n = sum.now + now, sum.with + with, sum.moved + moved, sum.n + 1
			if row.estimate == true then
				sum.guessed = sum.guessed + moved
			end
		end
	end
	for kind, sum in pairs(sums) do
		sum.rotation = rotated[kind] == true
	end
	return sums
end

function G.Totals(candidate, lines, opts)
	local out = {}
	candidate, opts = Table(candidate), Table(opts) or {}
	if candidate and Table(candidate.candidates) then
		candidate = Table(candidate.candidates[Num(candidate.best) or 1])
	end
	local rows = candidate and Table(candidate.rows)
	if not rows then
		return out
	end
	local rotation = candidate.rotation
	if rotation == nil then
		local M = Model()
		rotation = Rotation(M and Table(Ask(M.State)) or {}, Text(opts.role))
	end
	local sums = Minute(rows, Weights(lines), Num(opts.limit), Table(rotation))
	for _, kind in ipairs(K.TOTAL_KINDS) do
		local sum = sums[kind]
		if sum and sum.now ~= 0 then
			out[kind] = { pct = (sum.with - sum.now) / math.abs(sum.now), now = sum.now, with = sum.with, n = sum.n,
				estimate = sum.guessed > 0 and sum.guessed >= K.GUESSED * sum.moved, best = sum.best, worst = sum.worst,
				rotation = sum.rotation == true }
		end
	end
	return out
end

ns.AddStart("chat", Register)
