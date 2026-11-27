local _, ns = ...

local KEY = "trackers"
local IsSecret = ns.IsSecret

local K = {
	SLOTS = { main = { 16, "main hand" }, off = { 17, "off hand" }, ranged = { 18, "ranged weapon" } },
	EDGED = { [12404] = true, [7964] = true, [2871] = true, [2863] = true, [2862] = true, [287978] = true },
	EDGES = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [15] = true },
	BLUNT = { [12643] = true, [7965] = true, [3241] = true, [3240] = true, [3239] = true },
	BLUNTS = { [4] = true, [5] = true, [10] = true, [13] = true },
	WEAPON = 2,
	CONSUMABLES = {
		8928, 8927, 8926, 6950, 6949, 6947, 20844, 8985, 8984, 2893, 2892, 10922, 10921, 10920, 10918, 9186, 6951, 5237, 3776, 3775,
		23122, 18262, 12404, 7964, 2871, 2863, 2862, 12643, 7965, 3241, 3240, 3239,
		23123, 20749, 20750, 20746, 20744, 20748, 20747, 20745, 3824, 3829,
	},
	KINDS = { none = {}, group = { group = true, buff = true, form = true, pet = true, item = true, tracking = true },
		all = { group = true, buff = true, form = true, pet = true, item = true, tracking = true, weapon = true } },
	PROBED = { item = true, tracking = true },
	CONJURE = {
		[5514] = 759, [5513] = 3552, [8007] = 10053, [8008] = 10054,
		[5350] = 5504, [2288] = 5505, [2136] = 5506, [3772] = 6127, [8077] = 10138, [8078] = 10139, [8079] = 10140,
		[5349] = 587, [1113] = 597, [1114] = 990, [1487] = 6129, [8075] = 10144, [8076] = 10145, [22895] = 28612,
		[5512] = 6201, [5511] = 6202, [5509] = 5699, [5510] = 11729, [9421] = 11730,
		[19004] = 6201, [19005] = 6201, [19006] = 6202, [19007] = 6202, [19008] = 5699, [19009] = 5699, [19010] = 11729, [19011] = 11729, [19012] = 11730, [19013] = 11730,
		[5232] = 693, [16892] = 20752, [16893] = 20755, [16895] = 20756, [16896] = 20757,
	},
	ATTRIBUTES = { "type", "spell", "unit", "item", "target-slot", "action", "macrotext" },
	SINGLE = { [21562] = 1243, [21564] = 1243, [27681] = 14752, [27683] = 976, [23028] = 1459, [21849] = 1126, [21850] = 1126, [25782] = 19740,
		[25916] = 19740, [25894] = 19742, [25918] = 19742, [25898] = 20217, [25895] = 1038, [25890] = 19977 },
	DAZE = { [5118] = true, [13159] = true },
	CALL = 883, REVIVE = 982,
	MODES = { defensive = "Defensive", assist = "Assist" },
	REFUSED = "Trackers: the game would not make a secure button, so a click on a tracker does nothing.",
	MAX_ID = 2147483647, LEVEL = 10,
	USAGE = "/flatui tracker use 1 Instant Poison - the item a click on weapon tracker 1 puts on the weapon, or clear for nothing chosen",
	UNCLICKED = "a click puts nothing on a weapon unless Click to apply is Buffs, forms, pet, conjuring, tracking and weapons",
}
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

local function Known(id)
	local book = type(C_SpellBook) == "table" and C_SpellBook or {}
	return Ask(book.IsSpellKnown, id) == true or Ask(book.IsSpellKnownOrInSpellBook, id) == true
end

local function InBook(id)
	local book = type(C_SpellBook) == "table" and C_SpellBook or {}
	return Plain(Ask(book.FindSpellBookSlotForSpell, id), "number")
end

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

local function Newest(family)
	local newest = nil
	for _, id in ipairs(family and family.ids or {}) do
		if Known(id) and InBook(id) then
			newest = id
		end
	end
	return newest
end

local function Short(id)
	local call = type(C_Spell) == "table" and C_Spell.IsSpellUsable
	if not Whole(id) or type(call) ~= "function" then
		return false
	end
	local ok, _, short = pcall(call, id)
	return ok and not IsSecret(short) and short == true
end

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

local function Usable(id)
	local call = type(C_Spell) == "table" and C_Spell.IsSpellUsable
	if type(call) ~= "function" then
		return true, false
	end
	local ok, usable, short = pcall(call, id)
	if not ok or IsSecret(usable) or IsSecret(short) then
		return true, false
	end
	return usable ~= false, short == true
end

local function CastSpell(id, reagent)
	local name = SpellName(id)
	if not name then
		return nil
	end
	local usable, short = Usable(id)
	if short then
		return nil, ("would cast %s, but you lack the power for it now"):format(name)
	elseif not usable then
		return nil, ("would cast %s, but %s"):format(name, reagent and "you lack its reagent" or "you cannot now")
	end
	return { type = "spell", spell = id }, ("casts %s"):format(name)
end

local function Conjure(entry)
	for _, id in ipairs(type(entry.items) == "table" and entry.items or {}) do
		local spell = Whole(id) and K.CONJURE[id]
		if spell and Known(spell) then
			return CastSpell(spell, true)
		end
	end
	return nil
end

local function Tracking()
	local id = type(ns.TrackerTrackingSpell) == "function" and ns.TrackerTrackingSpell(Known) or nil
	if Whole(id) and Known(id) then
		return CastSpell(id, false)
	end
	return nil
end

local function Choose(entry, now)
	if entry.kind == "weapon" then
		return Weapon(entry)
	elseif entry.kind == "item" then
		return Conjure(entry)
	elseif entry.kind == "tracking" then
		return Tracking()
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

local function Allowed(entry)
	local kinds = K.KINDS[ns.Get(KEY .. ".click")] or K.KINDS.none
	return ns.Enabled(KEY) and entry.on ~= false and kinds[entry.kind or "buff"] == true
end

function ns.TrackerClickCovers(entry)
	if type(entry) ~= "table" or not Allowed(entry) then
		return false
	elseif K.PROBED[entry.kind] then
		local action, text = Choose(entry)
		return action ~= nil, text
	end
	return true
end

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

local function Give(button, action)
	local set = S.set[button]
	for _, key in ipairs(K.ATTRIBUTES) do
		local value = action and action[key] or nil
		if set[key] ~= value and pcall(button.SetAttribute, button, key, value) then
			set[key] = value
		end
	end
end

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
	frame:SetScript("OnEvent", function(_, event)
		S.fighting = event == "PLAYER_REGEN_DISABLED"
		if S.fighting then
			DetachAll()
		end
	end)
end

local function Enter(button)
	local tip = GameTooltip
	local entry = Find(S.owner[button])
	if type(tip) ~= "table" or ns.Forbidden(tip) or not entry or S.fighting or InCombatLockdown() then
		return
	end
	local _, text = Choose(entry, true)
	pcall(function()
		tip:SetOwner(button, "ANCHOR_TOP")
		if ns.Get(KEY .. ".tooltips") ~= "off" and type(ns.TrackerTipLines) == "function" then
			ns.TrackerTipLines(entry, tip, true)
		else
			tip:SetText(type(ns.TrackerLabel) == "function" and ns.TrackerLabel(entry) or "Tracker", 1, 1, 1)
		end
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
	if kind == "buff" or kind == "form" or K.PROBED[kind] then
		local action, text = Choose(entry)
		if not action and not text then
			return nil
		elseif K.PROBED[kind] and not action then
			return ("Click: none now. It %s."):format(text)
		end
	end
	return "Click: none now. A click is offered out of combat while the tracker has something to fix, and for a buff while you have the power to cast it."
end

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

local function Unchosen(entry)
	local name = OwnPick(entry)
	return name and ("nothing chosen (%s now)"):format(name) or "nothing chosen (nothing to use now)"
end

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

local USE = { FIRST = -1, BACK = -2 }

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
