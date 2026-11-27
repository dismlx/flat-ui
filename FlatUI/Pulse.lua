local _, ns = ...

local KEY = "pulse"
local MOVER = "FlatUIPulse"
local CROP = 0.08
local PEAK, RISE = 0.7, 0.3
local GROW, NAME_GAP, NAME_FONT = 1.25, 4, "GameFontHighlightLarge"
local GCD = 2
local MOST_WAITING, MOST_ITEMS, MOST_LEFT = 32, 40, 100
local MAX_ID = 2147483647
local EARLY, FORGET = 0.1, 10
local TRINKETS = { 13, 14 }
local UNKNOWN_ICON = 134400
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local SOUND_PAGE, SOUND_NONE, SOUND_BACK = 1, 2, -1
local SOUND_HELP = "/flatui pulse sound Frost Nova bell - its own sound when it pulses: page, none, spell, chimes, bell, warhorn, raid, alarm or whisper"
local SPOTS = { { mover = MOVER, size = "size", x = 0 }, { mover = MOVER .. "2", size = "size2", x = -120 }, { mover = MOVER .. "3", size = "size3", x = 120 } }
local MOST_SPOTS, SPOT_BACK = #SPOTS, -1
local SPOT_HELP = "/flatui pulse spot Frost Nova 2 - the spot it pulses at: 1, 2 or 3"
local HELP = {
	"/flatui pulse test - a pulse at each spot in use",
	"/flatui pulse ignore Frost Nova - a spell or an item that is not to pulse: a name, an ID or a shift-clicked link",
	"/flatui pulse watch Frost Nova - it pulses again",
	SOUND_HELP,
	SPOT_HELP,
	"/flatui pulse list - what pulses, what is left out and the own sounds and spots",
}
local NO_BOOK = "Cooldown pulse: the game has no spell book information, so only items pulse."
local NO_COOLDOWNS = "Cooldown pulse: the game has no spell cooldown information, so only items pulse."
local NO_ITEMS = "Cooldown pulse: the game has no item cooldown information, so only spells pulse."
local NO_TIMER = "Cooldown pulse: the game has no timers, so nothing pulses."
local NO_FADE = "Cooldown pulse: the game made no fade, so the icon shows without one."
local REFUSED = "Cooldown pulse: the game refused to watch a cooldown, so it may not pulse."

local IsSecret = ns.IsSecret

local P = { spells = {}, ids = {}, items = {}, known = {}, spots = {}, watching = setmetatable({}, { __mode = "k" }), free = {},
	left = { ids = {}, names = {}, items = {} } }
ns.Pulse = P
P.WORDS = {}
for word, index in pairs(KITS) do
	P.WORDS[index] = word
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

function P.Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not IsSecret(answer) then
		return answer
	end
	return nil
end

function P.Plain(value, kind)
	if not IsSecret(value) and type(value) == kind then
		return value
	end
	return nil
end

function P.Flag(value)
	return P.Plain(value, "boolean")
end

function P.Whole(value)
	return P.Plain(value, "number") ~= nil and value > 0 and value <= MAX_ID and value == math.floor(value)
end

function P.Timers()
	return type(C_Timer) == "table" and type(C_Timer.After) == "function"
end

function P.After(seconds, fn)
	if P.Timers() then
		C_Timer.After(seconds, fn)
	else
		fn()
	end
end

function P.SpellName(id)
	local name = P.Ask(C_Spell and C_Spell.GetSpellName, id)
	if P.Plain(name, "string") and name ~= "" then
		return name
	end
	return nil
end

function P.ItemName(id)
	local name = P.Ask(C_Item and C_Item.GetItemNameByID, id)
	if P.Plain(name, "string") and name ~= "" then
		return name
	end
	return "Item " .. id
end

function P.Label(id)
	if id > 0 then
		return P.SpellName(id) or ("Spell " .. id)
	end
	return P.ItemName(-id)
end

function P.Icon(entry)
	local file
	if entry.kind == "item" then
		file = P.Ask(C_Item and C_Item.GetItemIconByID, entry.id)
	elseif entry.kind == "spell" then
		file = P.Ask(C_Spell and C_Spell.GetSpellTexture, entry.id)
	else
		file = entry.icon
	end
	if P.Plain(file, "number") or P.Plain(file, "string") then
		return file
	end
	return UNKNOWN_ICON
end

function P.Base(id)
	local milliseconds = P.Ask(GetSpellBaseCooldown, id)
	if P.Plain(milliseconds, "number") and milliseconds == milliseconds then
		return milliseconds / 1000
	end
	return nil
end

function P.Left(make)
	local saved = ns.Character()
	if type(saved) ~= "table" or (saved.pulseLeftOut == nil and not make) then
		return {}
	end
	local list, seen = {}, {}
	for _, id in ipairs(type(saved.pulseLeftOut) == "table" and saved.pulseLeftOut or {}) do
		if type(id) == "number" and id ~= 0 and math.abs(id) <= MAX_ID and id == math.floor(id) and not seen[id] and #list < MOST_LEFT then
			seen[id] = true
			list[#list + 1] = id
		end
	end
	saved.pulseLeftOut = (#list > 0 or make) and list or nil
	return list
end

function P.ReadLeft()
	local left = { ids = {}, names = {}, items = {} }
	for _, id in ipairs(P.Left()) do
		if id > 0 then
			left.ids[id] = true
			local name = P.SpellName(id)
			if name then
				left.names[name] = true
			end
		else
			left.items[-id] = true
		end
	end
	P.left = left
end

function P.LeftOut(entry)
	local left = P.left
	if entry.kind == "item" then
		return left.items[entry.id] == true
	elseif entry.kind ~= "spell" then
		return false
	end
	if left.names[entry.name] then
		return true
	end
	for id in pairs(entry.ranks or {}) do
		if left.ids[id] then
			return true
		end
	end
	return false
end

function P.Matches(list, id)
	local name = id > 0 and P.SpellName(id) or nil
	local found = {}
	for index, other in ipairs(list) do
		if other == id or (name and other > 0 and P.SpellName(other) == name) then
			found[#found + 1] = index
		end
	end
	return found
end

function P.BookSlot(found, book, slot, bank, spellType)
	local item = P.Ask(book.GetSpellBookItemInfo, slot, bank)
	if type(item) ~= "table" or item.itemType ~= spellType or item.isPassive == true or item.isOffSpec == true then
		return
	end
	local id = item.spellID or item.actionID
	if not P.Whole(id) then
		return
	end
	local name = P.Plain(item.name, "string") and item.name ~= "" and item.name or P.SpellName(id)
	if not name then
		return
	end
	local spell = found[name]
	if not spell then
		spell = { ranks = {} }
		found[name] = spell
	end
	spell.ranks[id] = true
	if P.Ask(book.IsSpellBookItemLowRank, slot, bank) ~= true then
		spell.id, spell.top = id, true
	elseif not spell.top then
		spell.id = id
	end
end

function P.Book()
	local book = C_SpellBook
	if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank
		and Enum.SpellBookItemType) then
		return nil
	end
	local bank, spellType = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType.Spell
	local found = {}
	local lines = P.Ask(book.GetNumSpellBookSkillLines)
	for line = 1, P.Plain(lines, "number") or 0 do
		local skill = P.Ask(book.GetSpellBookSkillLineInfo, line)
		if type(skill) == "table" and skill.shouldHide ~= true and skill.offSpecID == nil and P.Plain(skill.itemIndexOffset, "number")
			and P.Plain(skill.numSpellBookItems, "number") then
			for slot = skill.itemIndexOffset + 1, skill.itemIndexOffset + skill.numSpellBookItems do
				P.BookSlot(found, book, slot, bank, spellType)
			end
		end
	end
	return found
end

function P.Build()
	P.ReadLeft()
	local found = P.Book()
	P.noBook = found == nil
	if not (C_Spell and C_Spell.GetSpellCooldown) then
		found = nil
	end
	local minimum = Opt("minimum")
	local old, fresh = P.spells, {}
	P.spells, P.ids = {}, {}
	for name, spell in pairs(found or {}) do
		local base = P.Base(spell.id)
		if base == nil or (base > 0 and base >= minimum) then
			local entry = old[name] or { kind = "spell", key = "spell:" .. name, name = name }
			entry.id, entry.ranks = spell.id, spell.ranks
			if not (entry.last and spell.ranks[entry.last]) then
				entry.last = spell.id
			end
			if not P.LeftOut(entry) then
				P.spells[name] = entry
				for id in pairs(spell.ranks) do
					P.ids[id] = entry
				end
				if old[name] == nil then
					fresh[#fresh + 1] = entry
				end
			end
		end
	end
	for name, entry in pairs(old) do
		if P.spells[name] ~= entry then
			P.Disarm(entry)
		end
	end
	for id, entry in pairs(P.items) do
		if P.LeftOut(entry) then
			P.Disarm(entry)
			P.items[id] = nil
		end
	end
	for _, entry in ipairs(fresh) do
		ns.Each(KEY, P.CheckSpell, entry, nil, nil)
	end
	P.Trinkets()
end

function P.Entry(id)
	if not P.Whole(id) then
		return nil
	end
	local entry = P.ids[id]
	if entry == nil then
		local name = P.SpellName(id)
		entry = name and P.spells[name] or false
		P.ids[id] = entry
	end
	return entry or nil
end

function P.Item(id)
	local entry = P.items[id]
	if entry then
		return entry
	end
	if P.left.items[id] then
		return nil
	end
	local count, oldest = 0, nil
	for _, other in pairs(P.items) do
		count = count + 1
		if not (other.worn or other.held or other.cooling == true) and (oldest == nil or (other.used or 0) < (oldest.used or 0)) then
			oldest = other
		end
	end
	if count >= MOST_ITEMS then
		if not oldest then
			return nil
		end
		P.Disarm(oldest)
		P.items[oldest.id] = nil
	end
	entry = { kind = "item", key = "item:" .. id, id = id, name = P.ItemName(id) }
	P.items[id] = entry
	return entry
end

function P.Trinkets()
	local worn = {}
	for _, slot in ipairs(TRINKETS) do
		local id = P.Ask(GetInventoryItemID, "player", slot)
		if P.Whole(id) then
			worn[id] = true
		end
	end
	for id, entry in pairs(P.items) do
		if entry.worn and not worn[id] then
			entry.worn = nil
			if not entry.used then
				P.Disarm(entry)
				P.items[id] = nil
			end
		end
	end
	for id in pairs(worn) do
		local entry = P.Item(id)
		if entry and not entry.worn then
			entry.worn = true
			ns.Each(KEY, P.CheckItem, entry)
		end
	end
end

function P.Used(id)
	local entry = P.Item(id)
	if entry then
		entry.used = P.Plain(P.Ask(GetTime), "number") or entry.used or 0
		ns.Each(KEY, P.CheckItem, entry)
	end
end

function P.Shared(start, length)
	return ("%.1f:%.1f"):format(start, length)
end

function P.Bags()
	local container = C_Container
	local now = P.Ask(GetTime)
	if not (container and container.GetContainerNumSlots and container.GetContainerItemID and container.GetContainerItemCooldown
		and P.Plain(now, "number")) then
		return
	end
	local minimum, shared = Opt("minimum"), {}
	for _, entry in pairs(P.items) do
		if entry.cooling == true and entry.start then
			shared[P.Shared(entry.start, entry.length)] = true
		end
	end
	for bag = 0, P.Plain(NUM_BAG_SLOTS, "number") or 4 do
		local slots = P.Ask(container.GetContainerNumSlots, bag)
		for slot = 1, P.Plain(slots, "number") or 0 do
			local id = P.Ask(container.GetContainerItemID, bag, slot)
			if P.Whole(id) and not P.items[id] and not P.left.items[id] then
				local ok, start, length = pcall(container.GetContainerItemCooldown, bag, slot)
				if ok and P.Plain(start, "number") and P.Plain(length, "number") and length > GCD and length >= minimum and start + length > now then
					local key = P.Shared(start, length)
					if not shared[key] then
						shared[key] = true
						P.Used(id)
					end
				end
			end
		end
	end
end

function P.CheckSpell(entry, id, mode)
	local spells = C_Spell
	if not (spells and spells.GetSpellCooldown) then
		return
	end
	id = id or entry.last or entry.id
	local info = P.Ask(spells.GetSpellCooldown, id)
	if type(info) ~= "table" then
		return
	end
	if P.Flag(info.isEnabled) == false then
		if entry.cooling then
			entry.cooling = nil
			P.Disarm(entry)
		end
		return
	end
	local cooling, length
	local charges = P.Ask(spells.GetSpellCharges, id)
	local most = type(charges) == "table" and P.Plain(charges.maxCharges, "number") or nil
	if most and most > 1 then
		entry.charged = true
		cooling = P.Flag(charges.isActive)
		length = P.Plain(charges.cooldownDuration, "number")
	else
		entry.charged = nil
		local active, gcd = P.Flag(info.isActive), nil
		if mode then
			gcd = P.Flag(info.isOnGCD)
		end
		length = P.Plain(info.duration, "number")
		if active == false then
			cooling = false
		elseif active == true then
			if gcd == true then
				if entry.cooling then
					return
				end
				cooling = false
			elseif gcd == false then
				cooling = true
			elseif length then
				cooling = length > GCD
			elseif mode == "named" then
				cooling = true
			end
		end
	end
	if cooling == nil then
		return
	end
	if cooling then
		if length and length <= 0 then
			length = nil
		end
		local fresh = entry.cooling ~= true or entry.last ~= id
		entry.cooling, entry.last, entry.length = true, id, length
		entry.short = length ~= nil and length < Opt("minimum")
		if fresh or mode == "named" or not entry.observer then
			P.Arm(entry, info)
		end
	elseif entry.cooling then
		P.Ready(entry)
	else
		entry.cooling = false
	end
end

function P.CheckItem(entry, ended)
	local call = C_Item and C_Item.GetItemCooldown
	if type(call) ~= "function" then
		return
	end
	local ok, start, length, enabled = pcall(call, entry.id)
	local now = P.Ask(GetTime)
	if not (ok and P.Plain(start, "number") and P.Plain(length, "number") and P.Plain(now, "number")) then
		return
	end
	entry.held = P.Flag(enabled) == false
	if entry.held then
		return
	end
	if length > GCD and start + length > now + (ended and EARLY or 0) then
		local fresh = entry.cooling ~= true or entry.start ~= start or entry.length ~= length
		entry.cooling, entry.start, entry.length, entry.seen = true, start, length, true
		entry.short = length < Opt("minimum")
		if fresh or ended or not entry.observer then
			P.Arm(entry)
		end
	elseif entry.cooling == true then
		P.Ready(entry)
	else
		entry.cooling = false
	end
end

function P.Holder()
	local holder = P.holder
	if not holder then
		holder = CreateFrame("Frame", nil, UIParent)
		ns.Own[holder] = true
		holder:SetSize(1, 1)
		holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
		holder:SetAlpha(0)
		holder:EnableMouse(false)
		P.holder = holder
	end
	return holder
end

function P.MakeObserver()
	local holder = P.Holder()
	local cooldown = CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
	ns.Own[cooldown] = true
	for _, call in ipairs({ "SetDrawSwipe", "SetDrawEdge", "SetDrawBling" }) do
		if cooldown[call] then
			pcall(cooldown[call], cooldown, false)
		end
	end
	if cooldown.SetHideCountdownNumbers then
		pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
	end
	cooldown:SetScript("OnCooldownDone", P.Finished)
	return cooldown
end

function P.Observer(entry)
	local cooldown = entry.observer
	if cooldown then
		return cooldown
	end
	cooldown = table.remove(P.free)
	if not cooldown then
		local ok, made = pcall(P.MakeObserver)
		if not ok then
			ns.Note(KEY, REFUSED)
			return nil
		end
		cooldown = made
	end
	entry.observer = cooldown
	P.watching[cooldown] = entry
	return cooldown
end

function P.Arm(entry, info)
	local cooldown = P.Observer(entry)
	if not cooldown then
		return
	end
	local ok = false
	if entry.kind == "item" then
		ok = pcall(cooldown.SetCooldown, cooldown, entry.start, entry.length)
	else
		local spells, got, duration = C_Spell or {}, false, nil
		if entry.charged and spells.GetSpellChargeDuration then
			got, duration = pcall(spells.GetSpellChargeDuration, entry.last)
		elseif spells.GetSpellCooldownDuration then
			got, duration = pcall(spells.GetSpellCooldownDuration, entry.last, true)
		end
		if got and duration ~= nil and cooldown.SetCooldownFromDurationObject then
			ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration, true)
		elseif type(info) == "table" and P.Plain(info.startTime, "number") and P.Plain(info.duration, "number") then
			ok = pcall(cooldown.SetCooldown, cooldown, info.startTime, info.duration)
		end
	end
	if ok then
		pcall(cooldown.Show, cooldown)
	else
		ns.Note(KEY, REFUSED)
		P.Disarm(entry)
	end
end

function P.Disarm(entry)
	local cooldown = entry.observer
	if not cooldown then
		return
	end
	entry.observer = nil
	P.watching[cooldown] = nil
	pcall(cooldown.Clear, cooldown)
	pcall(cooldown.Hide, cooldown)
	P.free[#P.free + 1] = cooldown
end

function P.Finished(cooldown)
	local entry = P.watching[cooldown]
	if entry and entry.observer == cooldown and ns.Enabled(KEY) then
		ns.Try(KEY, P.Done, entry)
	end
end

function P.Done(entry)
	if entry.cooling ~= true then
		return
	end
	if entry.kind == "item" then
		P.CheckItem(entry, true)
		return
	end
	local spells = C_Spell or {}
	local info = P.Ask(spells.GetSpellCooldown, entry.last)
	if type(info) == "table" then
		if P.Flag(info.isEnabled) == false then
			entry.cooling = nil
			P.Disarm(entry)
			return
		end
		local start, length, now = P.Plain(info.startTime, "number"), P.Plain(info.duration, "number"), P.Plain(P.Ask(GetTime), "number")
		if not entry.charged and start and length and now and length > GCD and start + length > now + EARLY then
			local cooldown = P.Observer(entry)
			if cooldown and pcall(cooldown.SetCooldown, cooldown, start, length) then
				pcall(cooldown.Show, cooldown)
				return
			end
		end
	end
	if entry.charged then
		local charges = P.Ask(spells.GetSpellCharges, entry.last)
		if type(charges) == "table" and P.Flag(charges.isActive) == true then
			P.After(0, function()
				if entry.cooling == true and ns.Enabled(KEY) then
					ns.Try(KEY, P.Arm, entry)
				end
			end)
			return
		end
	end
	P.Ready(entry)
end

function P.Ready(entry)
	entry.cooling = false
	P.Disarm(entry)
	if entry.kind == "item" and not entry.worn and P.items[entry.id] == entry then
		P.items[entry.id], P.known[entry.id] = nil, true
	end
	if not entry.short and not P.LeftOut(entry) then
		P.Queue(entry)
	end
end

function P.MakeFade(frame)
	local group = frame:CreateAnimationGroup()
	local rise = group:CreateAnimation("Alpha")
	rise:SetOrder(1)
	rise:SetFromAlpha(0)
	rise:SetToAlpha(PEAK)
	local fall = group:CreateAnimation("Alpha")
	fall:SetOrder(2)
	fall:SetFromAlpha(PEAK)
	fall:SetToAlpha(0)
	local made, grow = pcall(function()
		local scale = group:CreateAnimation("Scale")
		scale:SetOrder(2)
		scale:SetOrigin("CENTER", 0, 0)
		scale:SetScaleFrom(1, 1)
		scale:SetScaleTo(1, 1)
		return scale
	end)
	return { group = group, rise = rise, fall = fall, grow = made and grow or nil }
end

function P.InUse()
	local count = tonumber(Opt("spots"))
	if count == nil or count < 1 then
		return 1
	end
	return math.min(MOST_SPOTS, math.floor(count))
end

function P.Spot(index)
	local spot = P.spots[index]
	if not spot then
		local spec = SPOTS[index]
		spot = { index = index, mover = spec.mover, size = spec.size, x = spec.x, queue = {}, token = 0 }
		P.spots[index] = spot
	end
	return spot
end

function P.Frame(spot)
	local frame = spot.frame
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(false)
	frame:SetAlpha(0)
	frame:Hide()
	local icon = frame:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[icon] = true
	icon:SetAllPoints(frame)
	icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	spot.frame, spot.icon = frame, icon
	local name = ns.OwnText(frame, "OVERLAY", NAME_FONT)
	if name then
		name:SetPoint("TOP", frame, "BOTTOM", 0, -NAME_GAP)
		name:SetWordWrap(false)
		pcall(name.SetShadowOffset, name, 1, -1)
		pcall(name.SetShadowColor, name, 0, 0, 0, 1)
		spot.name = name
	end
	spot.outline = ns.Outline(frame, frame, true)
	local ok, fade = pcall(P.MakeFade, frame)
	spot.fade = ok and fade or nil
	P.Size(spot)
	return frame
end

function P.Size(spot)
	if spot.frame then
		local size = Opt(spot.size)
		spot.frame:SetSize(size, size)
	end
end

function P.Place(spot)
	local frame = spot.frame
	if not frame then
		return
	end
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(spot.mover, "CENTER")
	end
	if x then
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", spot.x, 0)
	end
end

function P.PlaceAll()
	for _, spot in pairs(P.spots) do
		P.Place(spot)
	end
end

function P.Peak()
	local alpha = Opt("alpha")
	if ns.Finite(alpha) and alpha >= 30 and alpha <= 100 then
		return alpha / 100
	end
	return PEAK
end

function P.NameColour(entry)
	local id = entry.kind == "item" and entry.id or entry.item
	if not P.Plain(id, "number") or type(C_Item) ~= "table" then
		return 1, 1, 1
	end
	local quality = P.Ask(C_Item.GetItemQualityByID, id)
	if not (ns.Finite(quality) and quality >= 0) then
		return 1, 1, 1
	end
	if type(C_Item.GetItemQualityColor) == "function" then
		local ok, r, g, b = pcall(C_Item.GetItemQualityColor, quality)
		if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
			return r, g, b
		end
	end
	local colours = ITEM_QUALITY_COLORS
	local colour = type(colours) == "table" and colours[quality] or nil
	if type(colour) == "table" and ns.Finite(colour.r) and ns.Finite(colour.g) and ns.Finite(colour.b) then
		return colour.r, colour.g, colour.b
	end
	return 1, 1, 1
end

function P.Fade(spot, seconds)
	local fade = spot.fade
	if not fade then
		return false
	end
	local peak = P.Peak()
	return pcall(function()
		fade.rise:SetDuration(seconds * RISE)
		fade.rise:SetToAlpha(peak)
		fade.fall:SetFromAlpha(peak)
		fade.fall:SetDuration(seconds * (1 - RISE))
		if fade.grow then
			local to = Opt("grow") == true and GROW or 1
			fade.grow:SetDuration(seconds * (1 - RISE))
			fade.grow:SetScaleTo(to, to)
		end
		fade.group:Stop()
		fade.group:Play()
	end)
end

function P.Hide(spot)
	if spot.fade then
		pcall(spot.fade.group.Stop, spot.fade.group)
	end
	spot.frame:Hide()
	spot.frame:SetAlpha(0)
end

function P.Show(spot, entry)
	if not P.Timers() then
		spot.current, spot.queue = nil, {}
		return
	end
	local seconds = Opt("time")
	local frame = P.Frame(spot)
	P.Size(spot)
	P.Place(spot)
	if entry.kind == "item" then
		entry.name = P.ItemName(entry.id)
	end
	spot.icon:SetTexture(P.Icon(entry))
	if spot.name then
		local size = Opt(spot.size)
		spot.name:SetText(Opt("name") ~= false and (entry.label or entry.name) or "")
		spot.name:SetTextHeight(math.max(10, math.floor((ns.Finite(size) and size or 72) / 5)))
		spot.name:SetTextColor(P.NameColour(entry))
	end
	frame:SetAlpha(0)
	frame:Show()
	if not P.Fade(spot, seconds) then
		frame:SetAlpha(P.Peak())
	end
	local sound = not entry.quiet and ns.SOUNDS and ns.SOUNDS[KITS[P.OwnSound(entry.soundKey or entry.key) or Opt("sound")] or 0]
	if sound and ns.PlayKit then
		ns.PlayKit(sound[1], KEY)
	end
	P.last = entry.name
	spot.token = spot.token + 1
	local token = spot.token
	C_Timer.After(seconds, function()
		if token ~= spot.token then
			return
		end
		if ns.Enabled(KEY) then
			ns.Try(KEY, P.Next, spot)
		else
			pcall(P.Hide, spot)
		end
	end)
end

function P.Next(spot)
	spot.current = table.remove(spot.queue, 1)
	if spot.current then
		P.Show(spot, spot.current)
	elseif spot.frame then
		P.Hide(spot)
	end
end

function P.Clear(spot)
	spot.queue, spot.current = {}, nil
	spot.token = spot.token + 1
	if spot.frame then
		P.Hide(spot)
	end
end

function P.Layout()
	local count = P.InUse()
	for index, spot in pairs(P.spots) do
		if index > count then
			P.Clear(spot)
		end
		P.Size(spot)
		P.Place(spot)
	end
end

function P.SpotOf(entry)
	local index = entry.spot or P.OwnSpot(entry.key) or 1
	if index > P.InUse() then
		index = 1
	end
	return P.Spot(index)
end

function P.Queue(entry)
	local spot = P.SpotOf(entry)
	if spot.current and spot.current.key == entry.key then
		return
	end
	for _, waiting in ipairs(spot.queue) do
		if waiting.key == entry.key then
			return
		end
	end
	if #spot.queue >= MOST_WAITING then
		return
	end
	spot.queue[#spot.queue + 1] = entry
	if not spot.current then
		P.Next(spot)
	end
end

function P.OnCooldown(spellID, baseSpellID, _, _, itemID)
	if P.Whole(itemID) then
		P.Used(itemID)
	end
	if IsSecret(spellID) or spellID == nil then
		for _, entry in pairs(P.spells) do
			ns.Each(KEY, P.CheckSpell, entry, nil, "event")
		end
		return
	end
	local entry, id = P.Entry(spellID), spellID
	if not entry then
		entry, id = P.Entry(baseSpellID), baseSpellID
	end
	if entry then
		ns.Each(KEY, P.CheckSpell, entry, id, "named")
	end
end

function P.OnCharges()
	for _, entry in pairs(P.spells) do
		if entry.charged then
			ns.Each(KEY, P.CheckSpell, entry, nil, nil)
		end
	end
end

function P.CheckItems()
	local now = P.Plain(P.Ask(GetTime), "number")
	for id, entry in pairs(P.items) do
		ns.Each(KEY, P.CheckItem, entry)
		if now and not (entry.worn or entry.seen or entry.held) and type(entry.used) == "number" and now - entry.used > FORGET then
			P.Disarm(entry)
			P.items[id] = nil
		end
	end
end

function P.Soon()
	if P.soon then
		return
	end
	P.soon = true
	P.After(0.5, function()
		P.soon = false
		if ns.Enabled(KEY) then
			ns.Try(KEY, P.Build)
		end
	end)
end

function P.World()
	P.Build()
	P.Bags()
end

function P.Stop()
	for _, entry in pairs(P.spells) do
		P.Disarm(entry)
	end
	for _, entry in pairs(P.items) do
		P.Disarm(entry)
	end
	P.spells, P.ids, P.items, P.known, P.on = {}, {}, {}, {}, false
	for _, spot in pairs(P.spots) do
		P.Clear(spot)
	end
	ns.ClearNote(KEY, REFUSED)
end

function P.Refresh()
	if not ns.Enabled(KEY) then
		P.Stop()
		return
	end
	local was = P.on
	P.on = true
	P.Build()
	P.Layout()
	if not was then
		P.Bags()
	end
end

local function Sorted(rows)
	table.sort(rows, function(a, b)
		local first, second = a[2]:lower(), b[2]:lower()
		if first ~= second then
			return first < second
		end
		return a[1] < b[1]
	end)
	return rows
end

function P.Listed()
	local ids = {}
	for id in pairs(P.known) do
		if not P.left.items[id] then
			ids[id] = true
		end
	end
	for id in pairs(P.items) do
		ids[id] = true
	end
	return ids
end

function ns.PulseCandidates()
	local spells, items = {}, {}
	for name, entry in pairs(P.spells) do
		spells[#spells + 1] = { entry.id, name }
	end
	for id in pairs(P.Listed()) do
		items[#items + 1] = { -id, P.ItemName(id) }
	end
	Sorted(spells)
	for _, row in ipairs(Sorted(items)) do
		spells[#spells + 1] = row
	end
	return spells
end

function ns.PulseIgnored()
	local rows = {}
	for _, id in ipairs(P.Left()) do
		rows[#rows + 1] = { id, P.Label(id) }
	end
	return Sorted(rows)
end

function P.Changed()
	if ns.Enabled(KEY) then
		ns.Try(KEY, P.Build)
	end
end

function ns.PulseIgnore(id)
	if type(id) ~= "number" or not P.Whole(math.abs(id)) then
		return false, "Choose a spell or an item."
	end
	local list = P.Left(true)
	if #P.Matches(list, id) > 0 then
		return false, ("%s is already left out."):format(P.Label(id))
	end
	if #list >= MOST_LEFT then
		return false, ("%d is the most that can be left out."):format(MOST_LEFT)
	end
	list[#list + 1] = id
	P.Changed()
	return true, ("%s no longer pulses."):format(P.Label(id))
end

function ns.PulseUnignore(id)
	if type(id) ~= "number" or not P.Whole(math.abs(id)) then
		return false, "Choose a spell or an item."
	end
	local list = P.Left()
	local found = P.Matches(list, id)
	if #found == 0 then
		return false, ("%s is not left out."):format(P.Label(id))
	end
	for index = #found, 1, -1 do
		table.remove(list, found[index])
	end
	local saved = ns.Character()
	if #list == 0 and type(saved) == "table" then
		saved.pulseLeftOut = nil
	end
	P.Changed()
	return true, ("%s pulses again."):format(P.Label(id))
end

function P.Sounds(make)
	local saved = ns.Character()
	if type(saved) ~= "table" then
		return nil
	end
	if type(saved.pulseSounds) ~= "table" then
		saved.pulseSounds = make and {} or nil
	end
	return saved.pulseSounds
end

function P.OwnSound(key)
	local sounds = P.Sounds()
	local word = sounds and type(key) == "string" and sounds[key] or nil
	if word == "none" or (type(word) == "string" and KITS[word]) then
		return word
	end
	return nil
end

function P.SetOwnSound(key, word)
	local sounds = P.Sounds(word ~= nil)
	if not sounds then
		return
	end
	sounds[key] = word
	if next(sounds) == nil then
		ns.Character().pulseSounds = nil
	end
end

function P.SoundName(word)
	if word == "none" then
		return "no sound"
	end
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[word] or 0]
	return type(sound) == "table" and sound[2] or tostring(word)
end

function P.SoundSaid(name, word)
	if word == nil then
		return ("%s plays the page's sound when it pulses."):format(name)
	end
	return ("%s plays %s when it pulses."):format(name, P.SoundName(word))
end

function P.Chosen(field)
	local rows, chosen = {}, nil
	for _, row in ipairs(ns.PulseCandidates()) do
		local id = row[1]
		local key = id > 0 and ("spell:" .. row[2]) or ("item:" .. -id)
		rows[#rows + 1] = { id, row[2], key }
		if P[field] ~= nil and key == P[field] then
			chosen = rows[#rows]
		end
	end
	if not chosen then
		P[field] = nil
	end
	return rows, chosen
end

function P.SoundRows()
	return P.Chosen("soundFor")
end

function ns.PulseSoundLines()
	local rows, chosen = P.SoundRows()
	local lines = {}
	if not chosen then
		for _, row in ipairs(rows) do
			local own = P.OwnSound(row[3])
			lines[#lines + 1] = { row[1], own and ("%s (%s)"):format(row[2], P.SoundName(own)) or row[2] }
		end
		return lines
	end
	lines[1] = { SOUND_PAGE, chosen[2] .. ": the page's sound" }
	lines[2] = { SOUND_NONE, chosen[2] .. ": no sound" }
	for index, word in ipairs(P.WORDS) do
		lines[#lines + 1] = { SOUND_NONE + index, chosen[2] .. ": " .. P.SoundName(word) }
	end
	lines[#lines + 1] = { SOUND_BACK, "Another spell or item" }
	return lines
end

function ns.PulseSoundPick(id)
	local rows, chosen = P.SoundRows()
	if not chosen then
		for _, row in ipairs(rows) do
			if row[1] == id then
				P.soundFor = row[3]
				return true, ("%s: open the list again to choose its sound."):format(row[2])
			end
		end
		return false, "That spell or item does not pulse."
	end
	P.soundFor = nil
	local word
	if id == SOUND_NONE then
		word = "none"
	elseif type(id) == "number" and id > SOUND_NONE and P.WORDS[id - SOUND_NONE] then
		word = P.WORDS[id - SOUND_NONE]
	elseif id ~= SOUND_PAGE then
		return true, nil
	end
	P.SetOwnSound(chosen[3], word)
	ns.Try(KEY, P.Preview, chosen)
	return true, P.SoundSaid(chosen[2], word)
end

function P.SoundCommand(text)
	local name, said = text:match("^%s*(.-)%s+(%S+)%s*$")
	said = said and said:lower()
	if not (name and name ~= "" and (said == "page" or said == "none" or KITS[said])) then
		return SOUND_HELP
	end
	local id = P.Resolve(name)
	if not id then
		return ('No spell or item found for "%s".'):format(name)
	end
	local label = P.Label(id)
	local key = id > 0 and ("spell:" .. label) or ("item:" .. -id)
	local word = said ~= "page" and said or nil
	P.SetOwnSound(key, word)
	return P.SoundSaid(label, word)
end

function P.SoundList()
	local own = {}
	for key in pairs(P.Sounds() or {}) do
		local word = P.OwnSound(key)
		local kind, rest = tostring(key):match("^(%a+):(.+)$")
		local label = kind == "item" and P.ItemName(tonumber(rest) or 0) or rest
		if word and label then
			own[#own + 1] = ("%s (%s)"):format(label, P.SoundName(word))
		end
	end
	table.sort(own)
	return own
end

function P.SpotTable(make)
	local saved = ns.Character()
	if type(saved) ~= "table" then
		return nil
	end
	if type(saved.pulseSpots) ~= "table" then
		saved.pulseSpots = make and {} or nil
	end
	return saved.pulseSpots
end

function P.OwnSpot(key)
	local spots = P.SpotTable()
	local index = spots and type(key) == "string" and spots[key] or nil
	if type(index) == "number" and index >= 2 and index <= MOST_SPOTS and index == math.floor(index) then
		return index
	end
	return nil
end

function P.SetOwnSpot(key, index)
	if index == 1 then
		index = nil
	end
	local spots = P.SpotTable(index ~= nil)
	if not spots then
		return
	end
	spots[key] = index
	if next(spots) == nil then
		ns.Character().pulseSpots = nil
	end
end

function P.SpotSaid(name, index)
	if index > P.InUse() then
		return ("%s pulses at spot %d once Pulse spots has it, and at spot 1 until then."):format(name, index)
	end
	return ("%s pulses at spot %d."):format(name, index)
end

function ns.PulseSpotLines()
	local rows, chosen = P.Chosen("spotFor")
	local lines = {}
	if not chosen then
		for _, row in ipairs(rows) do
			local own = P.OwnSpot(row[3])
			lines[#lines + 1] = { row[1], own and ("%s (spot %d)"):format(row[2], own) or row[2] }
		end
		return lines
	end
	for index = 1, P.InUse() do
		lines[#lines + 1] = { index, ("%s: spot %d"):format(chosen[2], index) }
	end
	lines[#lines + 1] = { SPOT_BACK, "Another spell or item" }
	return lines
end

function ns.PulseSpotPick(id)
	local rows, chosen = P.Chosen("spotFor")
	if not chosen then
		for _, row in ipairs(rows) do
			if row[1] == id then
				P.spotFor = row[3]
				return true, ("%s: open the list again to choose its spot."):format(row[2])
			end
		end
		return false, "That spell or item does not pulse."
	end
	P.spotFor = nil
	if type(id) ~= "number" or id < 1 or id > MOST_SPOTS or id ~= math.floor(id) then
		return true, nil
	end
	P.SetOwnSpot(chosen[3], id)
	ns.Try(KEY, P.Preview, chosen)
	return true, P.SpotSaid(chosen[2], id)
end

function P.SpotCommand(text)
	local name, said = text:match("^%s*(.-)%s+(%d+)%s*$")
	local index = tonumber(said or "")
	if not (name and name ~= "" and index and index >= 1 and index <= MOST_SPOTS) then
		return SPOT_HELP
	end
	local id = P.Resolve(name)
	if not id then
		return ('No spell or item found for "%s".'):format(name)
	end
	local label = P.Label(id)
	local key = id > 0 and ("spell:" .. label) or ("item:" .. -id)
	P.SetOwnSpot(key, index)
	return P.SpotSaid(label, index)
end

function P.SpotList()
	local own = {}
	for key in pairs(P.SpotTable() or {}) do
		local index = P.OwnSpot(key)
		local kind, rest = tostring(key):match("^(%a+):(.+)$")
		local label = kind == "item" and P.ItemName(tonumber(rest) or 0) or rest
		if index and label then
			own[#own + 1] = ("%s (spot %d)"):format(label, index)
		end
	end
	table.sort(own)
	return own
end

function ns.PulseShown()
	return ns.Enabled(KEY)
end

function ns.PulseShown2()
	return ns.Enabled(KEY) and P.InUse() >= 2
end

function ns.PulseShown3()
	return ns.Enabled(KEY) and P.InUse() >= 3
end

function ns.PulseMoved()
	if ns.Enabled(KEY) then
		ns.Try(KEY, P.PlaceAll)
	end
end

function P.Resolve(text)
	text = text:match("^%s*(.-)%s*$")
	local item = tonumber(text:match("item:(%d+)") or "")
	if P.Whole(item) then
		return -item
	end
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)") or "")
	if not id and text ~= "" then
		local info = P.Ask(C_Spell and C_Spell.GetSpellInfo, text)
		if type(info) == "table" then
			id = P.Plain(info.spellID, "number")
		end
	end
	if P.Whole(id) and P.SpellName(id) then
		return id
	end
	item = text ~= "" and P.Ask(C_Item and C_Item.GetItemInfoInstant, text) or nil
	if P.Whole(item) then
		return -item
	end
	return nil
end

function P.Test(quiet)
	local names = {}
	for name in pairs(P.spells) do
		names[#names + 1] = name
	end
	table.sort(names)
	local count = P.InUse()
	for index = 1, count do
		local name = names[index] or names[1]
		local entry = name and P.spells[name]
		local label = name or "Cooldown pulse"
		if count > 1 then
			label = ("Spot %d: %s"):format(index, label)
		end
		P.Queue({ kind = "test", key = "test", name = "a test", label = label, icon = entry and P.Icon(entry) or UNKNOWN_ICON, spot = index,
			quiet = quiet == true or index > 1 })
	end
end

function P.Preview(chosen)
	local mode = ns.TestMode
	if InCombatLockdown() or not ns.Enabled(KEY) or (mode and mode.IsOn()) or type(chosen) ~= "table" or not P.Plain(chosen[1], "number") then
		return
	end
	local id = chosen[1]
	local index = P.OwnSpot(chosen[3]) or 1
	if index > P.InUse() then
		index = 1
	end
	P.DropTests(P.Spot(index))
	P.Queue({ kind = "test", key = "test", name = "a test", label = chosen[2], icon = P.Icon({ kind = id > 0 and "spell" or "item", id = math.abs(id) }),
		spot = index, soundKey = chosen[3], item = id < 0 and -id or nil })
end

function ns.PulseLookChanged(path)
	ns.Try(KEY, P.Refresh)
	local mode = ns.TestMode
	if ns.Enabled(KEY) and not InCombatLockdown() and not (mode and mode.IsOn()) then
		P.Test(path ~= KEY .. ".sound")
	end
end

function P.TestStep()
	local mode = ns.TestMode
	P.Test(not (mode ~= nil and mode.Sound("pulse")))
end

function P.DropTests(spot)
	for index = #spot.queue, 1, -1 do
		if spot.queue[index].kind == "test" then
			table.remove(spot.queue, index)
		end
	end
	if spot.current and spot.current.kind == "test" then
		spot.token = spot.token + 1
		P.Next(spot)
	end
end

function P.TestEnd()
	for _, spot in pairs(P.spots) do
		P.DropTests(spot)
	end
end

function P.List()
	local names, items, left = {}, {}, {}
	for name in pairs(P.spells) do
		names[#names + 1] = name
	end
	for id in pairs(P.Listed()) do
		items[#items + 1] = P.ItemName(id)
	end
	for _, row in ipairs(ns.PulseIgnored()) do
		left[#left + 1] = row[2]
	end
	table.sort(names)
	table.sort(items)
	print(("Cooldown pulse, spells: %s"):format(#names > 0 and table.concat(names, ", ") or "none"))
	print(("Cooldown pulse, items: %s"):format(#items > 0 and table.concat(items, ", ") or "none"))
	print(("Cooldown pulse, left out: %s"):format(#left > 0 and table.concat(left, ", ") or "none"))
	local own = P.SoundList()
	print(("Cooldown pulse, own sounds: %s"):format(#own > 0 and table.concat(own, ", ") or "none"))
	local spots = P.SpotList()
	print(("Cooldown pulse, own spots: %s"):format(#spots > 0 and table.concat(spots, ", ") or "none"))
end

function P.Slash(rest)
	local word, text = rest:match("^(%S*)%s*(.-)$")
	word = word:lower()
	if (word == "ignore" or word == "watch") and text ~= "" then
		local id = P.Resolve(text)
		if not id then
			print(('No spell or item found for "%s".'):format(text))
			return
		end
		local _, message = (word == "ignore" and ns.PulseIgnore or ns.PulseUnignore)(id)
		print(message)
	elseif word == "sound" then
		print(P.SoundCommand(text))
	elseif word == "spot" then
		print(P.SpotCommand(text))
	elseif word == "test" or word == "list" then
		if not ns.Enabled(KEY) then
			print("Cooldown pulse is off. Its page is under Cooldowns.")
		elseif word == "test" then
			ns.Try(KEY, P.Test, false)
		else
			ns.Try(KEY, P.List)
		end
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

local function Many(count, word)
	return ("%d %s%s"):format(count, word, count == 1 and "" or "s")
end

function P.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	local spells, items, left = 0, 0, #P.Left()
	for _ in pairs(P.spells) do
		spells = spells + 1
	end
	for _ in pairs(P.Listed()) do
		items = items + 1
	end
	lines[1] = ("Cooldown pulse: %s and %s watched%s."):format(Many(spells, "spell"), Many(items, "item"), left > 0 and (", " .. left .. " left out") or "")
	if not (C_Spell and C_Spell.GetSpellCooldown) then
		lines[#lines + 1] = NO_COOLDOWNS
	elseif P.noBook then
		lines[#lines + 1] = NO_BOOK
	end
	if not (C_Item and C_Item.GetItemCooldown) then
		lines[#lines + 1] = NO_ITEMS
	end
	if not P.Timers() then
		lines[#lines + 1] = NO_TIMER
	end
	for _, spot in pairs(P.spots) do
		if spot.frame and not spot.fade then
			lines[#lines + 1] = NO_FADE
			break
		end
	end
	local count = P.InUse()
	if count > 1 then
		local own = 0
		for key in pairs(P.SpotTable() or {}) do
			local index = P.OwnSpot(key)
			if index and index <= count then
				own = own + 1
			end
		end
		lines[#lines + 1] = ("Cooldown pulse: %d spots, %s."):format(count, own == 1 and "1 spell or item at a spot of its own"
			or (own .. " spells and items at spots of their own"))
	end
	if P.last then
		lines[#lines + 1] = ("Cooldown pulse: the last was %s."):format(P.last)
	end
	return lines
end

ns.Register(KEY, {
	label = "Cooldown pulse",
	counted = false,
	Start = P.Refresh,
	Refresh = P.Refresh,
	Resized = P.PlaceAll,
	events = {
		SPELL_UPDATE_COOLDOWN = P.OnCooldown,
		SPELL_UPDATE_CHARGES = P.OnCharges,
		BAG_UPDATE_COOLDOWN = P.CheckItems,
		PLAYER_REGEN_ENABLED = P.CheckItems,
		PLAYER_EQUIPMENT_CHANGED = P.Trinkets,
		SPELLS_CHANGED = P.Soon,
		PLAYER_ENTERING_WORLD = P.World,
	},
	slash = { pulse = P.Slash },
	help = HELP,
	Status = P.Status,
})

if ns.TestMode then
	ns.TestMode.Register("pulse", { module = KEY, label = "Cooldown pulse", every = 3, Start = P.TestStep, Tick = P.TestStep, Stop = P.TestEnd })
end
