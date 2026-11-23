local _, ns = ...

-- Show thorns: what an attacker takes each time it strikes the player in melee, the damage shields, as one total a hit by school ("Thorns 45
-- (Nature 30, Arcane 15)"), on the character page of the Character window, under the right column of slots (the lowest is the second trinket,
-- Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:836-860), right-aligned, so it mirrors Show durability under the left column. The game's own
-- stats list is not touched: the text is this addon's, on a frame of its own made out of a fight on the item frame of the character page
-- (PaperDollItemsFrame, PaperDollFrame.xml:777), so it shows only on that page, as CharacterDurability.lua's does. A shield spike, which strikes
-- only on a block, follows the total ("block 20-30") and is not added to it. Pointing at the line lists each source in GameTooltip (SetOwner,
-- AddLine, AddDoubleLine, Show, and Hide only while IsOwned says the frame owns it), never in a fight, as the Compare gear button's tooltip.
-- What is read, only what the client gives addon code:
--   The worn items' tooltip lines (ns.GearModel.TipLines, C_TooltipInfo.GetInventoryItem, TooltipInfoDocumentation.lua:389-405, the lines the
--   Gear comparison reads): a line that says an attacker that strikes you takes a number of damage of a school ("Equip: When struck in combat
--   inflicts 3 Arcane damage to the attacker."), an Equip line, a Set line of a bonus that holds, or an enchantment's. A line with a chance
--   (a proc), a Use line, a Chance on hit line and the grey line of a set bonus not yet held ("(2) Set: ...") are not thorns.
--   The shield's permanent enchantment (the second field of its link, GetInventoryItemLink of the off hand): Iron, Mithril and Thorium Shield
--   Spike, physical damage on a block.
--   The player's buffs (C_UnitAuras.GetUnitAuras(player, HELPFUL), UnitAuraDocumentation.lua:495-510), only while the game shows buffs to addon
--   code (ns.Tracking.Open: C_Secrets.ShouldAurasBeSecret plainly false), as Absorbs.lua reads them. The damage shields Flat UI knows by spell ID
--   (the client rows of aura type 15 in tools/dev/spelltips/client_spells.json: Thorns and Retribution Aura, and the imp's Fire Shield): the
--   amount is the aura's first value (points[1]), else the number its tooltip gives (C_TooltipInfo.GetUnitBuffByAuraInstanceID,
--   TooltipInfoDocumentation.lua:1259-1277), else the client row's base points, shown with ~ before it. Any other buff with a time whose
--   tooltip says it deals damage of a school to attackers counts too, except one with charges (Lightning Shield, whose charges are not thorns,
--   and is left out by spell ID as well). While the game hides buffs, in a fight, the buffs last read stay and the tooltip says so.
-- Every value is tested with ns.IsSecret and ns.Finite before it is used. It is read when the settings are applied, each time the page shows,
-- and while it shows on the player's UNIT_AURA and UNIT_INVENTORY_CHANGED (heard by its own frame, RegisterUnitEvent, only while it shows),
-- PLAYER_EQUIPMENT_CHANGED and the end of a fight, a quarter of a second after the first of them, so nothing runs while the page is shut. Nothing of the game's is written,
-- and on a client without C_TooltipInfo nothing is made. Not a module: the windows module calls ns.CharacterThorns.Apply whenever it applies its
-- settings.

local KEY, PART, ROW = "windows", "thorns", "windows.thorns"
local FONT = "GameFontHighlightSmall"
-- The frame lies this far under the second trinket slot, and where the slot is not found, this far from the bottom left of the page.
local GAP, FALLBACK_X, FALLBACK_Y = -12, 24, 24
local HEIGHT, LEAST_WIDTH, PAD = 16, 40, 4
local REREAD = 0.25
local OFF_HAND, FIRST_SLOT, LAST_SLOT = 17, 1, 19
-- The tooltip line kinds of Enum.TooltipDataLineType the Gear comparison names (GearModel.lua K): Use, Equip and Chance on hit lines.
local ON_USE, ON_EQUIP, ON_PROC = 44, 45, 46
local LINES = 40
local WHITE, DIM, NONE = { 1, 1, 1 }, { 0.7, 0.7, 0.7 }, { 0.55, 0.55, 0.55 }
-- The schools in the game's order (Lua school index 1-7, SpellData.lua's SCHOOL_NAMES), English where the client has no SCHOOL_STRINGS
-- (Blizzard_FrameXMLBase/Constants.lua:48-56), and their colours as the game colours the schools of its combat log (CombatLogColors.lua:13-22).
local ENGLISH = { "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }
local SCHOOL_RGB = { { 0.7, 0.7, 0.7 }, { 1, 0.9, 0.5 }, { 1, 0.5, 0 }, { 0.3, 1, 0.3 }, { 0.5, 1, 1 }, { 0.5, 0.5, 1 }, { 1, 0.5, 1 } }
local PHYSICAL, HOLY, FIRE, NATURE = 1, 2, 3, 4
-- The damage shields by spell ID: { school, base points of the client row }. Thorns ranks 1 to 6 and Retribution Aura ranks 1 to 5 are the client
-- rows of aura type 15 (client_spells.json); the imp's Fire Shield, ranks 1 to 5, puts its shield on the one it is cast on, and has no row there.
local SHIELDS = {
	[467] = { NATURE, 3 }, [782] = { NATURE, 6 }, [1075] = { NATURE, 9 }, [8914] = { NATURE, 12 }, [9756] = { NATURE, 15 }, [9910] = { NATURE, 18 },
	[7294] = { HOLY, 5 }, [10298] = { HOLY, 8 }, [10299] = { HOLY, 12 }, [10300] = { HOLY, 16 }, [10301] = { HOLY, 20 },
	[2947] = { FIRE }, [8316] = { FIRE }, [8317] = { FIRE }, [11770] = { FIRE }, [11771] = { FIRE },
}
-- Lightning Shield, ranks 1 to 7: damage to an attacker for each of its charges, not thorns.
local NOT_THORNS = { [324] = true, [325] = true, [905] = true, [945] = true, [8134] = true, [10431] = true, [10432] = true }
-- The shield spikes by the enchantment of the shield (SpellItemEnchantment): its name and the damage of a block.
local SPIKES = { [43] = { "Iron Spike", 8, 12 }, [463] = { "Mithril Spike", 16, 20 }, [1704] = { "Thorium Spike", 20, 30 } }

local CharacterThorns = {}
ns.CharacterThorns = CharacterThorns

-- The frame, its text and the last read. broken: the game refused one of them, and nothing is tried again. waiting: the making waits for the end
-- of a fight. auras: the buffs last read, kept while the game hides them (stale). pending: a read is due shortly.
local state = { frame = nil, text = nil, broken = false, waiting = false, auras = {}, stale = false, pending = false, read = nil }

local IsSecret, Finite = ns.IsSecret, ns.Finite

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(ROW) == true and not ns.PartStopped(KEY, PART)
end

local function Usable(value)
	return value ~= nil and not IsSecret(value) and type(value) == "table"
end

-- An amount to show: a talent can give a share of a point.
local function Round(value)
	return math.floor(value + 0.5)
end

local function Plain(value, kind)
	return value ~= nil and not IsSecret(value) and type(value) == kind
end

local function Index(t, key)
	return t[key]
end

-- A field of a table the client gave, or nil when it is withheld or reading it raises.
local function Field(t, key)
	if not Usable(t) then
		return nil
	end
	local ok, value = pcall(Index, t, key)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- True when the game would refuse a frame made on this one now.
local function Blocked(frame)
	if not InCombatLockdown() then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or IsSecret(protected) or protected == true
end

-- Reading -------------------------------------------------------------------------------------------------------------------------------------

-- The client's names of the schools, lower case, by school index.
local function SchoolWords()
	local words, given = {}, _G.SCHOOL_STRINGS
	for index, english in ipairs(ENGLISH) do
		local word = Field(given, index)
		words[index] = (Plain(word, "string") and word ~= "" and word or english):lower()
	end
	return words
end

local function SchoolName(index)
	local word = Field(_G.SCHOOL_STRINGS, index)
	if Plain(word, "string") and word ~= "" then
		return word
	end
	return ENGLISH[index] or ENGLISH[PHYSICAL]
end

-- The school and amount a line of text gives for damage to an attacker: "inflicts 3 Arcane damage", "Causes 18 Nature damage", or a number of
-- damage with no school (physical). Nil when the line names none.
local function Damage(text, words)
	local lower = text:lower()
	for amount, word in lower:gmatch("(%d+) (%a+) damage") do
		for index, name in ipairs(words) do
			if word == name then
				return index, tonumber(amount)
			end
		end
	end
	local amount = lower:match("(%d+) damage")
	if amount then
		return PHYSICAL, tonumber(amount)
	end
	return nil
end

-- True when a line is about an attacker that strikes the player, with no chance in it.
local function AboutAttackers(lower)
	if lower:find("chance", 1, true) or lower:find("%", 1, true) then
		return false
	end
	return lower:find("struck", 1, true) ~= nil or lower:find("strikes you", 1, true) ~= nil or lower:find("attackers", 1, true) ~= nil
		or lower:find("to the attacker", 1, true) ~= nil
end

local function Starts(text, word)
	return Plain(word, "string") and word ~= "" and text:sub(1, #word) == word
end

-- The thorns of the worn items, from their tooltip lines, into found: { name, school, amount, kind }.
local function ReadItems(found, words)
	local lines = ns.GearModel and ns.GearModel.TipLines
	if type(lines) ~= "function" then
		return
	end
	local equip, use, proc = _G.ITEM_SPELL_TRIGGER_ONEQUIP, _G.ITEM_SPELL_TRIGGER_ONUSE, _G.ITEM_SPELL_TRIGGER_ONPROC
	for slot = FIRST_SLOT, LAST_SLOT do
		local ok, list = pcall(lines, nil, nil, slot)
		if ok and Usable(list) and list[1] then
			local name = list[1].left or ("Slot " .. slot)
			for index = 2, #list do
				local line = list[index]
				local text = line.left
				if text and line.kind ~= ON_USE and line.kind ~= ON_PROC and not Starts(text, use) and not Starts(text, proc)
					and not text:match("^%(%d+%)") and AboutAttackers(text:lower()) then
					local school, amount = Damage(text, words)
					if school and Finite(amount) and amount > 0 then
						local equipLine = line.kind == ON_EQUIP or Starts(text, equip)
						found[#found + 1] = { name = name, school = school, amount = amount, kind = equipLine and "item" or "enchant" }
					end
				end
			end
		end
	end
end

-- The shield spike on the off hand: { name, least, most, item }, or nil.
local function ReadSpike()
	local call = _G.GetInventoryItemLink
	if type(call) ~= "function" then
		return nil
	end
	local ok, link = pcall(call, "player", OFF_HAND)
	if not ok or not Plain(link, "string") then
		return nil
	end
	local enchant = tonumber(link:match("item:%-?%d+:(%d+)") or "")
	local spike = enchant and SPIKES[enchant]
	if not spike then
		return nil
	end
	local item = link:match("|h%[(.-)%]|h")
	return { name = spike[1], least = spike[2], most = spike[3], item = item }
end

-- The number of damage to attackers a buff's tooltip gives, and its school, or nil.
local function TipDamage(instance, words, strict)
	local call = Field(_G.C_TooltipInfo, "GetUnitBuffByAuraInstanceID")
	if type(call) ~= "function" then
		return nil
	end
	local ok, data = pcall(call, "player", instance)
	if not ok then
		return nil
	end
	local lines = Field(data, "lines")
	for index = 2, LINES do
		local line = Field(lines, index)
		if line == nil then
			break
		end
		local text = Field(line, "leftText")
		if Plain(text, "string") then
			local lower = text:lower()
			if not strict or (AboutAttackers(lower) and not lower:find("charge", 1, true)) then
				local school, amount = Damage(text, words)
				if school and Finite(amount) and amount > 0 then
					return amount, school
				end
			end
		end
	end
	return nil
end

-- The fields of one buff, or nothing when one is withheld.
local function AuraFields(aura)
	return aura.spellId, aura.auraInstanceID, aura.name, aura.points, aura.duration, aura.charges
end

-- The damage shields among the player's buffs: a list of { name, school, amount, guess }, or nil when the game hides buffs.
local function ReadAuras(words)
	local open = ns.Tracking and ns.Tracking.Open
	if type(open) ~= "function" or not open() then
		return nil
	end
	local call = Field(_G.C_UnitAuras, "GetUnitAuras")
	if type(call) ~= "function" then
		return nil
	end
	local ok, auras = pcall(call, "player", "HELPFUL")
	if not ok or not Usable(auras) then
		return nil
	end
	local found = {}
	for _, aura in ipairs(auras) do
		if Usable(aura) then
			local read, id, instance, name, points, duration, charges = pcall(AuraFields, aura)
			if read and Plain(id, "number") and Plain(instance, "number") and not NOT_THORNS[id] then
				name = Plain(name, "string") and name or ("Spell " .. id)
				local known = SHIELDS[id]
				if known then
					local amount = Finite(Field(points, 1)) and Field(points, 1) or nil
					local guess = false
					if not (amount and amount > 0) then
						amount = TipDamage(instance, words, false)
					end
					if not (amount and amount > 0) and known[2] then
						amount, guess = known[2], true
					end
					found[#found + 1] = { name = name, school = known[1], amount = amount, guess = guess }
				elseif Finite(duration) and duration > 0 and not (Finite(charges) and charges > 0) then
					local amount, school = TipDamage(instance, words, true)
					if amount then
						found[#found + 1] = { name = name, school = school, amount = amount, guess = false }
					end
				end
			end
		end
	end
	return found
end

-- One read: { items, auras, spike, total, schools = { [school] = amount }, stale }.
local function Read()
	local words = SchoolWords()
	local items = {}
	ReadItems(items, words)
	local auras = ReadAuras(words)
	if auras then
		state.auras, state.stale = auras, false
	else
		state.stale = #state.auras > 0
	end
	local read = { items = items, auras = state.auras, spike = ReadSpike(), total = 0, schools = {}, stale = state.stale }
	for _, list in ipairs({ items, state.auras }) do
		for _, source in ipairs(list) do
			if Finite(source.amount) then
				read.total = read.total + source.amount
				read.schools[source.school] = (read.schools[source.school] or 0) + source.amount
			end
		end
	end
	return read
end

-- The line: "Thorns 45 (Nature 30, Arcane 15)", the spike after it.
local function Words(read)
	local parts = {}
	for school = 1, #ENGLISH do
		local amount = read.schools[school]
		if amount and amount > 0 then
			parts[#parts + 1] = ("%s %d"):format(SchoolName(school), Round(amount))
		end
	end
	local text = ("Thorns %d"):format(Round(read.total))
	if #parts > 0 then
		text = ("%s (%s)"):format(text, table.concat(parts, ", "))
	end
	if read.spike then
		text = ("%s, block %d-%d"):format(text, read.spike.least, read.spike.most)
	end
	return text
end

-- Showing --------------------------------------------------------------------------------------------------------------------------------------

local function Update()
	local text, frame = state.text, state.frame
	if text == nil or frame == nil then
		return
	end
	if not Wanted() then
		pcall(text.Hide, text)
		return
	end
	local read = Read()
	state.read = read
	local colour = (read.total > 0 or read.spike) and WHITE or NONE
	pcall(text.SetTextColor, text, colour[1], colour[2], colour[3], 1)
	pcall(text.SetText, text, Words(read))
	pcall(text.Show, text)
	local ok, width = pcall(text.GetStringWidth, text)
	if ok and Finite(width) then
		pcall(frame.SetWidth, frame, math.max(LEAST_WIDTH, width + PAD))
	end
end

-- A read a moment from now, once, while the page shows.
local function Soon()
	local frame = state.frame
	if state.pending or frame == nil or not Wanted() then
		return
	end
	local ok, shown = pcall(frame.IsVisible, frame)
	if not ok or IsSecret(shown) or shown ~= true then
		return
	end
	state.pending = true
	C_Timer.After(REREAD, function()
		state.pending = false
		ns.EachPart(KEY, PART, Update)
	end)
end

local function Tooltip()
	local tip = _G.GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

local function Untip()
	local tip, frame = Tooltip(), state.frame
	if not (tip and frame) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, frame)
	if ok and not IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

local function AddSource(tip, left, school, right, colour)
	local rgb = SCHOOL_RGB[school] or WHITE
	colour = colour or WHITE
	pcall(tip.AddDoubleLine, tip, left, right, colour[1], colour[2], colour[3], rgb[1], rgb[2], rgb[3])
end

-- Each source with its school and amount, the total, and why a buff may be out of date.
local function Say()
	local tip, frame, read = Tooltip(), state.frame, state.read
	if InCombatLockdown() or not (tip and frame and read) or not pcall(tip.SetOwner, tip, frame, "ANCHOR_BOTTOMRIGHT") then
		return
	end
	pcall(tip.AddLine, tip, "Thorns", WHITE[1], WHITE[2], WHITE[3])
	pcall(tip.AddLine, tip, "The damage an attacker takes each time it strikes you in melee.", DIM[1], DIM[2], DIM[3], true)
	local any = false
	for _, source in ipairs(read.items) do
		any = true
		local where = source.kind == "enchant" and ("%s, enchantment"):format(source.name) or source.name
		AddSource(tip, where, source.school, ("%s %d"):format(SchoolName(source.school), Round(source.amount)))
	end
	for _, source in ipairs(read.auras) do
		any = true
		local amount = Finite(source.amount) and ((source.guess and "~%d" or "%d"):format(Round(source.amount))) or "?"
		AddSource(tip, ("%s (buff)"):format(source.name), source.school, ("%s %s"):format(SchoolName(source.school), amount))
	end
	if read.spike then
		any = true
		local where = read.spike.item and ("%s, %s"):format(read.spike.item, read.spike.name) or read.spike.name
		AddSource(tip, where, PHYSICAL, ("%s %d-%d on a block"):format(SchoolName(PHYSICAL), read.spike.least, read.spike.most))
	end
	if any then
		AddSource(tip, "Total a hit", nil, ("%d"):format(Round(read.total)))
	else
		pcall(tip.AddLine, tip, "Nothing you wear and no buff on you deals damage to attackers.", DIM[1], DIM[2], DIM[3], true)
	end
	if read.stale then
		pcall(tip.AddLine, tip, "Buffs as last read out of a fight: the game hides them now.", DIM[1], DIM[2], DIM[3], true)
	end
	pcall(tip.Show, tip)
end

local function Refuse(text)
	state.broken = true
	ns.Note(KEY, text)
end

local function Run(fn)
	ns.EachPart(KEY, PART, fn)
end

-- Hears the player's buffs and gear on the frame while it shows.
local function Listen(frame)
	local ok, shown = pcall(frame.IsVisible, frame)
	if ok and not IsSecret(shown) and shown == true then
		pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "player")
		pcall(frame.RegisterUnitEvent, frame, "UNIT_INVENTORY_CHANGED", "player")
	end
end

-- Makes the frame and its text on the item frame of the character page. True when they are there.
local function Make(page)
	local ok, frame = pcall(CreateFrame, "Frame", nil, page)
	if not ok or not Usable(frame) then
		Refuse("Windows: Show thorns stopped, the game refused a frame on the Character window.")
		return false
	end
	ns.Own[frame] = true
	local text = ns.OwnText(frame, "OVERLAY", FONT)
	if text == nil then
		pcall(frame.Hide, frame)
		Refuse("Windows: Show thorns stopped, the game refused a text on the Character window.")
		return false
	end
	state.frame, state.text = frame, text
	pcall(frame.SetSize, frame, LEAST_WIDTH, HEIGHT)
	local trinket = _G.CharacterTrinket1Slot
	if not (Usable(trinket) and not ns.Forbidden(trinket) and pcall(frame.SetPoint, frame, "TOPRIGHT", trinket, "BOTTOMRIGHT", 0, GAP)) then
		pcall(frame.SetPoint, frame, "BOTTOMLEFT", page, "BOTTOMLEFT", FALLBACK_X, FALLBACK_Y)
	end
	pcall(text.SetPoint, text, "RIGHT", frame, "RIGHT", 0, 0)
	pcall(text.SetJustifyH, text, "RIGHT")
	-- Over the line the mouse shows the sources; clicks go through to the page.
	pcall(frame.EnableMouse, frame, true)
	pcall(frame.SetMouseClickEnabled, frame, false)
	pcall(frame.SetScript, frame, "OnEnter", function()
		Run(Say)
	end)
	pcall(frame.SetScript, frame, "OnLeave", Untip)
	-- The player's buffs and gear are heard only while the page shows.
	pcall(frame.SetScript, frame, "OnShow", function()
		Listen(frame)
		Run(Update)
	end)
	pcall(frame.SetScript, frame, "OnHide", function()
		pcall(frame.UnregisterAllEvents, frame)
		Untip()
	end)
	pcall(frame.SetScript, frame, "OnEvent", function()
		Run(Soon)
	end)
	return true
end

local function Applied()
	if not Wanted() then
		if state.frame then
			pcall(state.frame.Hide, state.frame)
		end
		return
	end
	if state.frame == nil then
		local page = _G.PaperDollItemsFrame
		if state.broken or not Usable(_G.C_TooltipInfo) or not Usable(page) or ns.Forbidden(page) then
			return
		end
		if Blocked(page) then
			if not state.waiting then
				state.waiting = true
				ns.OutOfCombat(function()
					state.waiting = false
					CharacterThorns.Apply()
				end)
			end
			return
		end
		if not Make(page) then
			return
		end
	end
	pcall(state.frame.Show, state.frame)
	Listen(state.frame)
	Update()
end

-- Shows the frame while the row is on, or hides it.
function CharacterThorns.Apply()
	if ns.PartStopped(KEY, PART) and state.frame then
		pcall(state.frame.Hide, state.frame)
	end
	ns.EachPart(KEY, PART, Applied)
end

-- The gear changed, or a fight ended and the buffs can be read again.
local function Changed()
	if state.frame and Wanted() then
		ns.EachPart(KEY, PART, Soon)
	end
end

ns.AddEvent(KEY, "PLAYER_EQUIPMENT_CHANGED", Changed)
ns.AddEvent(KEY, "PLAYER_REGEN_ENABLED", Changed)
