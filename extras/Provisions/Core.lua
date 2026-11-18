-- Provisions: one button for each kind of consumable (healing potion, mana potion, healthstone, food, drink,
-- bandage, buff food), whatever its rank or name. Each kind is a per-character macro of the addon's own
-- ("Prov Heal" and so on) and a secure button of its own (ProvisionsHealButton and so on) that Key Bindings can
-- bind, both kept on the best item in the bags, out of combat only.
--
-- Game calls this file makes, as the client's interface source documents them (build 70938):
--   C_Item.GetItemCount (ItemDocumentation), C_Item.IsUsableItem, C_Item.GetItemIconByID, C_Item.GetItemNameByID
--   GetNumMacros, GetMacroInfo, CreateMacro, EditMacro(index, nil, nil, body) which keeps the name and icon
--   (Blizzard_MacroUI.lua), DeleteMacro; Constants.MacroConsts (MacroConstantsDocumentation: 120 account, 30 per
--   character macros, the character's after the account's).
--   C_SkillInfo.GetSkillLineInfoByID / GetSkillLineInfo (SkillInfoDocumentation; the Camelot SkillsFrame reads them).
--   C_UnitAuras.GetPlayerAuraBySpellID (UnitAuraDocumentation: SecretWhenUnitAuraRestricted, so read out of combat
--   only and a withheld answer is "unknown").
--   SecureActionButtonTemplate with type "macro" and "macrotext" runs C_Macro.RunMacroText (SecureTemplates.lua,
--   SECURE_ACTIONS.macro); a key binding clicks it on key down or up as ActionButtonUseKeyDown says, so it hears both.
-- Every one of them is called under pcall: a call that fails counts as no answer.

local ADDON, ns = ...

local ITEMS = ns.ITEMS or {}
local BUFF_SPELLS = ns.BUFF_SPELLS or {}

local KINDS = { "heal", "mana", "stone", "food", "drink", "bandage", "buff" }
ns.KINDS = KINDS

local INFO = {
	heal = { macro = "Prov Heal", button = "ProvisionsHealButton", label = "Healing potion", none = "healing potion" },
	mana = { macro = "Prov Mana", button = "ProvisionsManaButton", label = "Mana potion", none = "mana potion" },
	stone = { macro = "Prov Stone", button = "ProvisionsStoneButton", label = "Healthstone", none = "healthstone" },
	food = { macro = "Prov Food", button = "ProvisionsFoodButton", label = "Food", none = "food" },
	drink = { macro = "Prov Drink", button = "ProvisionsDrinkButton", label = "Drink", none = "drink" },
	bandage = { macro = "Prov Bandage", button = "ProvisionsBandageButton", label = "Bandage", none = "bandage" },
	buff = { macro = "Prov Buff Food", button = "ProvisionsBuffFoodButton", label = "Buff food", none = "buff food" },
}
ns.INFO = INFO

-- Kinds that a press can use in a fight, where the macro cannot be rewritten: only these get "/use" lines for the
-- items after the best (see Body). Food, drink and buff food cannot be eaten in a fight, and out of one the macro
-- is rewritten as soon as the bags change.
local IN_COMBAT = { heal = true, mana = true, stone = true }

-- The question mark icon (fileID 134400, QUESTION_MARK_ICON); "#showtooltip item:" replaces it with the item's.
local ICON = 134400
local MAX_BODY = 255
local function MacroLimits()
	local account, character = 120, 30
	if type(Constants) == "table" and type(Constants.MacroConsts) == "table" then
		account = Constants.MacroConsts.MAX_ACCOUNT_MACROS or account
		character = Constants.MacroConsts.MAX_CHARACTER_MACROS or character
	end
	return account, character
end

-- Classes without mana: their mana potion and drink buttons are off until turned on.
local NO_MANA = { WARRIOR = true, ROGUE = true }

-- Buff food stats: names, and a rough worth of one point of each, to rank buffs of different stats against one
-- another for the "Any" choice (one point of a primary stat = 1).
local STATS = {
	{ key = "sta", name = "Stamina", worth = 1 },
	{ key = "str", name = "Strength", worth = 1 },
	{ key = "agi", name = "Agility", worth = 1 },
	{ key = "int", name = "Intellect", worth = 1 },
	{ key = "spi", name = "Spirit", worth = 1 },
	{ key = "stats", name = "All stats", worth = 5 },
	{ key = "ap", name = "Attack power", worth = 0.5 },
	{ key = "rap", name = "Ranged attack power", worth = 0.4 },
	{ key = "crit", name = "Critical strike", worth = 14 },
	{ key = "spell", name = "Spell damage", worth = 0.86 },
	{ key = "spellcrit", name = "Spell critical strike", worth = 14 },
	{ key = "healing", name = "Healing power", worth = 0.45 },
	{ key = "mp5", name = "Mana regeneration", worth = 2.5 },
	{ key = "hp5", name = "Health regeneration", worth = 2.5 },
	{ key = "armor", name = "Armor", worth = 0.07 },
	{ key = "resist", name = "Resistance", worth = 1 },
	{ key = "rating", name = "Rating", worth = 1 },
	{ key = "speed", name = "Movement speed", worth = 0 },
	{ key = "skill", name = "Profession skill", worth = 0 },
	{ key = "other", name = "Other", worth = 0 },
}
local STAT = {}
for _, s in ipairs(STATS) do
	STAT[s.key] = s
end
ns.STATS, ns.STAT = STATS, STAT

-- Auto: the stats each class wants first, in order; then Stamina, then the strongest of any.
local AUTO = {
	WARRIOR = { "sta", "str", "ap", "agi", "crit", "armor" },
	PALADIN = { "sta", "str", "int", "healing", "spi", "mp5" },
	HUNTER = { "agi", "ap", "rap", "crit", "int" },
	ROGUE = { "agi", "ap", "crit", "str" },
	PRIEST = { "int", "spi", "mp5", "healing", "spell" },
	SHAMAN = { "int", "mp5", "spi", "healing", "spell", "agi" },
	MAGE = { "int", "spi", "mp5", "spell", "spellcrit" },
	WARLOCK = { "int", "spi", "mp5", "spell", "sta" },
	DRUID = { "int", "spi", "mp5", "healing", "sta", "agi" },
}
ns.AUTO = AUTO

-- The items of each kind. A buff food is a kind of its own: Food and Drink never take one, unless the fallback
-- option lets them when the bags hold no plain food or drink. An item that is food and drink is in both lists.
local LIST = {}
local FALLBACK = { food = {}, drink = {} }
for _, kind in ipairs(KINDS) do
	LIST[kind] = {}
end
for id, rec in pairs(ITEMS) do
	if rec.buff then
		table.insert(LIST.buff, id)
		if rec.food then
			table.insert(FALLBACK.food, id)
		end
		if rec.drink then
			table.insert(FALLBACK.drink, id)
		end
	else
		for _, kind in ipairs(KINDS) do
			if rec[kind] then
				table.insert(LIST[kind], id)
			end
		end
	end
end

-- Saved variables (ProvisionsDB for the account: the panel's place; ProvisionsCharDB per character: the kinds
-- and options, and the macros the addon made).
local db, cdb
local playerClass

local function Opt(key)
	return cdb and cdb[key]
end
ns.Opt = Opt

function ns.KindOn(kind)
	if not cdb then
		return false
	end
	local v = cdb.kinds[kind]
	if v == nil then
		if (kind == "mana" or kind == "drink") and NO_MANA[playerClass or ""] then
			return false
		end
		return true
	end
	return v
end

-- Chat lines said once a session, by key.
local said = {}
local function Say(text)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "|cff88c0ffProvisions|r: " .. text)
	end
end
local function SayOnce(key, text)
	if said[key] then
		return
	end
	said[key] = true
	Say(text)
end
ns.Say = Say

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, ...)
end

local function Secret(v)
	if type(issecretvalue) == "function" then
		local ok, s = pcall(issecretvalue, v)
		return not ok or s
	end
	return false
end

local function InCombat()
	local ok, v = Call(InCombatLockdown)
	return not ok or v
end
ns.InCombat = InCombat

local function Count(id)
	if not (C_Item and C_Item.GetItemCount) then
		return 0
	end
	local ok, n = pcall(C_Item.GetItemCount, id)
	if ok and type(n) == "number" and not Secret(n) then
		return n
	end
	return 0
end
ns.Count = Count

local function PlayerLevel()
	local ok, level = Call(UnitLevel, "player")
	if ok and type(level) == "number" and level > 0 then
		return level
	end
	return nil
end

-- The player's First Aid rank: the highest rank among the skill lines bandages need (and their parent). nil when
-- the game gives no answer, 0 when it answers and the player has none.
local function FirstAidRank()
	if not C_SkillInfo then
		return nil
	end
	local wanted, rank, answered = {}, nil, false
	for _, id in ipairs(ns.FIRST_AID_SKILLS or {}) do
		wanted[id] = true
		local ok, info = Call(C_SkillInfo.GetSkillLineInfoByID, id)
		if ok then
			answered = true
			if type(info) == "table" and type(info.rank) == "number" then
				rank = math.max(rank or 0, info.rank)
			end
		end
	end
	local okN, n = Call(C_SkillInfo.GetNumSkillLines)
	if okN and type(n) == "number" then
		answered = true
		for i = 1, n do
			local ok, info = Call(C_SkillInfo.GetSkillLineInfo, i)
			if ok and type(info) == "table" and wanted[info.skillID] and type(info.rank) == "number" then
				rank = math.max(rank or 0, info.rank)
			end
		end
	end
	if rank then
		return rank
	end
	return answered and 0 or nil
end

-- Whether the player can use an item now: its level, its First Aid rank, and for items of some areas only
-- (battleground rations and bandages) the game's own answer.
local function CanUse(id, rec, level, firstAid)
	if level and rec.level and rec.level > level then
		return false
	end
	if rec.firstAid and firstAid and rec.firstAid > firstAid then
		return false
	end
	if rec.zone or (rec.firstAid and not firstAid) then
		if not (C_Item and C_Item.IsUsableItem) then
			return false
		end
		local ok, usable = pcall(C_Item.IsUsableItem, id)
		return ok and usable and not Secret(usable) and true or false
	end
	return true
end

local function BuffWorth(rec)
	local worth = 0
	for key, amount in pairs(rec.buff or {}) do
		worth = worth + (STAT[key] and STAT[key].worth or 0) * amount
	end
	return worth
end

-- The order of items of a kind: conjured first (option), then the most restored (for buff food: the most of the
-- chosen stat, or the strongest buff), then the lowest item ID, so that two items alike always come in one order
-- whatever the counts in the bags.
local function Sorter(kind, stat)
	local conjuredFirst = Opt("conjuredFirst")
	return function(a, b)
		local ra, rb = ITEMS[a], ITEMS[b]
		if conjuredFirst then
			local ca, cb = ra.conjured and 1 or 0, rb.conjured and 1 or 0
			if ca ~= cb then
				return ca > cb
			end
		end
		local va, vb
		if kind == "buff" then
			if stat then
				va, vb = ra.buff[stat] or 0, rb.buff[stat] or 0
			else
				va, vb = BuffWorth(ra), BuffWorth(rb)
			end
			if va == vb then
				va, vb = (ra.food or 0) + (ra.drink or 0), (rb.food or 0) + (rb.drink or 0)
			end
		else
			va, vb = ra[kind] or 0, rb[kind] or 0
		end
		if va ~= vb then
			return va > vb
		end
		return a < b
	end
end

-- The items of a list that the bags hold and the player can use now.
local function Carried(list, level, firstAid, filter)
	local out = {}
	for _, id in ipairs(list) do
		local rec = ITEMS[id]
		if (not filter or filter(rec)) and Count(id) > 0 and CanUse(id, rec, level, firstAid) then
			table.insert(out, id)
		end
	end
	return out
end

-- What a kind uses now: { best = id, rest = { ids in order }, note = text or nil, stat = key or nil }.
local function Choose(kind, level, firstAid)
	local state = { rest = {} }
	local items
	if kind == "buff" then
		local choice = Opt("buffChoice") or "auto"
		local order
		if choice == "auto" then
			order = {}
			for _, key in ipairs(AUTO[playerClass or ""] or {}) do
				table.insert(order, key)
			end
			table.insert(order, "sta")
		elseif choice ~= "any" then
			order = { choice }
		end
		for _, key in ipairs(order or {}) do
			items = Carried(LIST.buff, level, firstAid, function(rec)
				return (rec.buff[key] or 0) > 0
			end)
			if #items > 0 then
				state.stat = key
				break
			end
		end
		if not state.stat then
			items = Carried(LIST.buff, level, firstAid)
			if #items > 0 and choice == "auto" then
				state.note = "No buff food of your class's stats in your bags: using the strongest of any."
			elseif #items > 0 and choice ~= "any" then
				state.note = "No " .. (STAT[choice] and STAT[choice].name or choice)
					.. " food in your bags: using the strongest of any."
			end
		end
		table.sort(items, Sorter("buff", state.stat))
	else
		items = Carried(LIST[kind] or {}, level, firstAid)
		if #items == 0 and FALLBACK[kind] and Opt("buffFallback") then
			items = Carried(FALLBACK[kind], level, firstAid)
			if #items > 0 then
				state.note = "No plain " .. INFO[kind].none .. ": using buff food."
			end
		end
		table.sort(items, Sorter(kind))
	end
	state.best = items[1]
	-- The items after the best, for the "/use" lines of a kind used in a fight: only those of the best one's
	-- shared cooldown (see Body).
	local best = state.best and ITEMS[state.best]
	if best and IN_COMBAT[kind] and best.cd then
		for i = 2, #items do
			if ITEMS[items[i]].cd == best.cd then
				table.insert(state.rest, items[i])
			end
		end
	end
	return state
end

-- The text of a kind's macro (and of its button's macrotext).
--
-- "#showtooltip item:<best>" gives the button the best item's icon, count and tooltip; "/use item:<id>" uses an
-- item by its ID (SlashCommands.lua: /use parses "item:<id>" and calls SecureCmdUseItem, ChatFrameUtil.lua:1228,
-- which calls C_Item.UseItemByName), so it works in every language and for every rank.
--
-- Why the later "/use" lines are safe: they are written only for healing potions, mana potions and healthstones,
-- and only for items that share the best one's cooldown category (the data's cd: ItemEffect.SpellCategoryID, kept
-- only when the category has a cooldown, ItemEffect.CategoryCoolDownMSec or SpellCooldowns.CategoryRecoveryTime:
-- two minutes for potions and healthstones). The game keeps cooldowns by category (C_Spell.
-- GetLastCategoryCooldownSource, "the most recent spellID and itemID that started a cooldown in this category",
-- SpellDocumentation.lua:154-170; SPELL_UPDATE_COOLDOWN names the category, SpellBookDocumentation.lua:925-936).
-- The lines of one press run in order, each a /use (SlashCommands.lua, SLASH_COMMAND.USE, then SecureCmdUseItem,
-- ChatFrameUtil.lua:1228), and each item's spell is instant (the generator keeps cd only for an item whose spell has
-- a cast time of 0, SpellMisc and SpellCastTimes): the best one's use starts the category's cooldown, so the next
-- line's item is "not ready yet" (LE_GAME_ERR_ITEM_COOLDOWN, UIErrorsFrame.lua:72) and nothing more is used. When
-- the best is gone from the bags its line does nothing and the next one fires: that is the point, a press in a
-- fight still works after the best runs out and before the macro can be rewritten. Bandages, food and drink get
-- the best item only (bandages share no cooldown; food and drink cannot be used in a fight).
local function Body(kind, state)
	if not state.best then
		-- Nothing to use: a press clicks the kind's own button, which says so in chat. No #showtooltip, so the
		-- macro keeps the question mark icon.
		return "/click " .. INFO[kind].button
	end
	local lines = { "#showtooltip item:" .. state.best }
	if kind == "bandage" then
		if Opt("bandageSelf") then
			table.insert(lines, "/use [@player] item:" .. state.best)
		else
			table.insert(lines, "/use [@mouseover,help,nodead][help,nodead][@player] item:" .. state.best)
		end
	else
		table.insert(lines, "/use item:" .. state.best)
	end
	local length = string.len(table.concat(lines, "\n"))
	for _, id in ipairs(state.rest) do
		local line = "/use item:" .. id
		if length + 1 + string.len(line) > MAX_BODY then
			break
		end
		table.insert(lines, line)
		length = length + 1 + string.len(line)
	end
	return table.concat(lines, "\n")
end

-- A macro body Provisions writes, to know its own macro again when ProvisionsCharDB lost its name.
local function OurBody(kind, body)
	if type(body) ~= "string" then
		return false
	end
	body = body:gsub("%s+$", "")
	if body == "/click " .. INFO[kind].button then
		return true
	end
	local first = true
	for line in body:gmatch("[^\n]+") do
		if first then
			if not line:match("^#showtooltip item:%d+$") then
				return false
			end
			first = false
		elseif not (line:match("^/use item:%d+$") or line:match("^/use %[[^%]]*%][^/]* ?item:%d+$")) then
			return false
		end
	end
	return not first
end

------------------------------------------------------------------------------------------------------------------
-- The buttons.

local buttons = {}
local states = {}
ns.states = states
local lastSaid = {}

local function OnPostClick(self)
	local kind = self.provisionsKind
	if not kind or (states[kind] and states[kind].body) then
		return
	end
	local now = GetTime and GetTime() or 0
	if lastSaid[kind] and now - lastSaid[kind] < 3 then
		return
	end
	lastSaid[kind] = now
	if not ns.KindOn(kind) then
		Say(INFO[kind].label .. " is turned off (/prov).")
	else
		Say("No " .. INFO[kind].none .. " in your bags.")
	end
end

local function MakeButtons()
	for _, kind in ipairs(KINDS) do
		if not buttons[kind] then
			-- No parent, size or place: the button is never drawn and never under the mouse; a key binding or
			-- "/click" clicks it.
			local ok, b = pcall(CreateFrame, "Button", INFO[kind].button, nil, "SecureActionButtonTemplate")
			if ok and b then
				b.provisionsKind = kind
				pcall(b.RegisterForClicks, b, "AnyUp", "AnyDown")
				pcall(b.SetScript, b, "PostClick", OnPostClick)
				buttons[kind] = b
			end
		end
	end
end

local function SetButton(kind, body)
	local b = buttons[kind]
	if not b then
		return
	end
	pcall(b.RegisterForClicks, b, "AnyUp", "AnyDown")
	if body then
		pcall(b.SetAttribute, b, "type", "macro")
		pcall(b.SetAttribute, b, "macrotext", body)
	else
		pcall(b.SetAttribute, b, "type", nil)
		pcall(b.SetAttribute, b, "macrotext", nil)
	end
end

------------------------------------------------------------------------------------------------------------------
-- The macros: per character, found by name among the character's macros.

local function FindMacro(name)
	local account = MacroLimits()
	local ok, _, numCharacter = Call(GetNumMacros)
	if not ok or type(numCharacter) ~= "number" then
		return nil, nil, nil
	end
	for i = account + 1, account + numCharacter do
		local okI, n, _, body = Call(GetMacroInfo, i)
		if okI and n == name then
			return i, body, numCharacter
		end
	end
	return nil, nil, numCharacter
end

-- Whether an action slot or the cursor holds the macro (a delete would change that slot inside the addon's call).
local function OnBar(index, name)
	local okC, what, value = Call(GetCursorInfo)
	if okC and what == "macro" and (value == index or value == name) then
		return true
	end
	for slot = 1, 180 do
		local ok, kind, id = Call(GetActionInfo, slot)
		if ok and kind == "macro" then
			if id == index then
				return true
			end
			local text
			if C_ActionBar and C_ActionBar.GetActionText then
				local okT, t = pcall(C_ActionBar.GetActionText, slot)
				text = okT and t or nil
			end
			if text == name then
				return true
			end
		end
	end
	return false
end

local full = false
local waitingDelete = false

local function WriteMacro(kind, body)
	local name = INFO[kind].macro
	local index, current, numCharacter = FindMacro(name)
	if index then
		if cdb.made[kind] ~= name then
			if OurBody(kind, current) then
				cdb.made[kind] = name
			else
				SayOnce("taken:" .. kind, "a macro named \"" .. name .. "\" is not one of Provisions' own, so it is left alone. "
					.. "Rename it to let Provisions make its " .. INFO[kind].label .. " macro.")
				return
			end
		end
		if (current or ""):gsub("%s+$", "") ~= body then
			Call(EditMacro, index, nil, nil, body)
		end
		return
	end
	if numCharacter == nil then
		return
	end
	local _, maxCharacter = MacroLimits()
	if numCharacter >= maxCharacter then
		full = true
		SayOnce("full", "your character's macro list is full (" .. maxCharacter .. "). Delete one and Provisions makes "
			.. "its macros then.")
		return
	end
	local ok = Call(CreateMacro, name, ICON, body, true)
	if ok then
		cdb.made[kind] = name
	end
end

local function RemoveMacro(kind)
	local name = INFO[kind].macro
	local index, current = FindMacro(name)
	if not index then
		cdb.made[kind] = nil
		return
	end
	if cdb.made[kind] ~= name and not OurBody(kind, current) then
		return
	end
	if OnBar(index, name) then
		waitingDelete = true
		SayOnce("bar:" .. kind, "\"" .. name .. "\" is turned off but is on an action bar (or the cursor), so it stays "
			.. "for now. Take it off the bar and Provisions deletes it.")
		return
	end
	Call(DeleteMacro, index)
	cdb.made[kind] = nil
end

------------------------------------------------------------------------------------------------------------------
-- The food buff the player has now (out of combat only).

-- Returns a table { spell, stats, points, expires } when a food buff of the data is on the player, false when
-- none is, nil when the game withholds the answer.
local function ActiveBuff()
	if InCombat() or not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
		return nil
	end
	for spell, stats in pairs(BUFF_SPELLS) do
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spell)
		if not ok or Secret(aura) then
			return nil
		end
		if type(aura) == "table" then
			local expires = aura.expirationTime
			if Secret(expires) or type(expires) ~= "number" then
				expires = nil
			end
			local points = {}
			if type(aura.points) == "table" and not Secret(aura.points) then
				for i, v in ipairs(aura.points) do
					if type(v) == "number" and not Secret(v) then
						points[i] = v
					end
				end
			end
			return { spell = spell, stats = stats, points = points, expires = expires }
		end
	end
	return false
end

local function BuffText(stats, amounts)
	local parts = {}
	for i, key in ipairs(stats) do
		local amount = amounts and amounts[i]
		local name = STAT[key] and STAT[key].name or key
		if amount and amount > 0 then
			table.insert(parts, name .. " +" .. amount)
		else
			table.insert(parts, name)
		end
	end
	return table.concat(parts, ", ")
end
ns.BuffText = BuffText

-- The buff food row's line about the buff on the player: what it is, its time left, and whether eating the chosen
-- food would replace it, and with something weaker.
function ns.BuffLine(state)
	local active = ActiveBuff()
	if active == nil then
		return "Food buff on you: unknown (the game did not say)."
	end
	if not active then
		return nil
	end
	local text = "Well Fed: " .. BuffText(active.stats, active.points)
	if active.expires and active.expires > 0 and GetTime then
		local left = active.expires - GetTime()
		if left > 0 then
			text = text .. string.format(", %d:%02d left", math.floor(left / 60), math.floor(left % 60))
		end
	end
	local best = state and state.best and ITEMS[state.best]
	if best and best.buff then
		local key, amount = active.stats[1], active.points[1]
		local new = key and best.buff[key]
		if new and amount and #active.stats == 1 and new < amount then
			text = text .. ". Eating would replace it with a weaker one."
		elseif best.buffSpell == active.spell and new and amount and new == amount then
			text = text .. ". Eating renews it."
		else
			text = text .. ". Eating would replace it."
		end
	end
	return text
end

------------------------------------------------------------------------------------------------------------------
-- The run: written only out of combat, never while the game's macro window is open.

local pending, scheduled = false, false
local Run

local function Schedule(delay)
	if scheduled then
		return
	end
	scheduled = true
	if C_Timer and C_Timer.After then
		C_Timer.After(delay or 0.2, function()
			scheduled = false
			Run()
		end)
	else
		scheduled = false
		Run()
	end
end
ns.Schedule = Schedule

local function MacroWindowShown()
	local frame = rawget(_G, "MacroFrame")
	if type(frame) == "table" and type(frame.IsShown) == "function" then
		local ok, shown = pcall(frame.IsShown, frame)
		return ok and shown
	end
	return false
end

local events

Run = function()
	if not cdb then
		return
	end
	if InCombat() then
		pending = true
		return
	end
	if MacroWindowShown() then
		-- The macro window loads the text of its macro again on UPDATE_MACROS (Blizzard_MacroUI.lua), which would
		-- throw away what the player is typing: wait for it to close.
		Schedule(1)
		return
	end
	pending = false
	full = false
	waitingDelete = false
	MakeButtons()
	local level = PlayerLevel()
	local firstAid = FirstAidRank()
	for _, kind in ipairs(KINDS) do
		local state = Choose(kind, level, firstAid)
		local on = ns.KindOn(kind)
		state.on = on
		local body = Body(kind, state)
		state.body = (on and state.best) and body or nil
		states[kind] = state
		SetButton(kind, state.body)
		if on then
			WriteMacro(kind, body)
		else
			RemoveMacro(kind)
		end
	end
	if events then
		if waitingDelete then
			events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
			events:RegisterEvent("CURSOR_CHANGED")
		else
			events:UnregisterEvent("ACTIONBAR_SLOT_CHANGED")
			events:UnregisterEvent("CURSOR_CHANGED")
		end
	end
	if ns.Refresh then
		ns.Refresh()
	end
end

function ns.MacroIndex(kind)
	local index = FindMacro(INFO[kind].macro)
	return index
end

function ns.IsFull()
	return full
end

------------------------------------------------------------------------------------------------------------------
-- Events.

events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_LEVEL_CHANGED")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("UPDATE_MACROS")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")

local function Defaults()
	if type(ProvisionsDB) ~= "table" then
		ProvisionsDB = {}
	end
	if type(ProvisionsCharDB) ~= "table" then
		ProvisionsCharDB = {}
	end
	db, cdb = ProvisionsDB, ProvisionsCharDB
	if type(cdb.kinds) ~= "table" then
		cdb.kinds = {}
	end
	if type(cdb.made) ~= "table" then
		cdb.made = {}
	end
	if cdb.buffChoice == nil then
		cdb.buffChoice = "auto"
	end
	if cdb.conjuredFirst == nil then
		cdb.conjuredFirst = true
	end
	if cdb.buffFallback == nil then
		cdb.buffFallback = false
	end
	if cdb.bandageSelf == nil then
		cdb.bandageSelf = false
	end
	ns.db, ns.cdb = db, cdb
end

events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON then
			Defaults()
			local ok, _, class = Call(UnitClass, "player")
			if ok and type(class) == "string" then
				playerClass = class
			end
			if ns.MakePanel then
				ns.MakePanel()
			end
		end
	elseif event == "PLAYER_LOGIN" then
		local ok, _, class = Call(UnitClass, "player")
		if ok and type(class) == "string" then
			playerClass = class
		end
		Schedule(0.5)
	elseif event == "PLAYER_REGEN_DISABLED" then
		if ns.HidePanel then
			ns.HidePanel()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pending then
			Schedule()
		end
	elseif event == "UPDATE_MACROS" then
		if full then
			Schedule(0.5)
		end
	elseif event == "UNIT_AURA" then
		if arg1 == "player" and ns.PanelShown and ns.PanelShown() and not InCombat() and ns.Refresh then
			ns.Refresh()
		end
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		if ns.PanelShown and ns.PanelShown() and ns.Refresh then
			ns.Refresh()
		end
	else
		-- PLAYER_ENTERING_WORLD, BAG_UPDATE_DELAYED, level and skill changes, and while a delete waits, action
		-- slot and cursor changes: write again (soon, and outside the call that raised the event).
		Schedule()
	end
end)

MakeButtons()
