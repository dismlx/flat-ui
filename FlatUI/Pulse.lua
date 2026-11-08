local _, ns = ...

-- Cooldown pulse: when the cooldown of one of your spells or items ends, its icon fades in and out in the middle of the screen, on a frame of
-- the addon's own that takes no mouse and that /flatui move places (FlatUIPulse in Movers.lua). A module of its own, off by default, whose page
-- is listed under Cooldowns. Nothing of the game is changed.
--
-- What pulses: each spell of the player's spell book that is not passive and whose base cooldown (GetSpellBaseCooldown, which the client
-- has though Blizzard's documentation does not list it) is Shortest cooldown or longer, the ranks of a spell counted as one by their name as
-- on the Cooldown icons list (Cooldowns.lua); the two trinkets worn; any item the player uses, which the game names in its cooldown event
-- (SPELL_UPDATE_COOLDOWN gives the item of a cast, SpellBookDocumentation.lua:924-936, and the game's own cooldown manager reads it so,
-- CooldownViewer.lua:2182-2186), until that cooldown is over; and, when the page goes on and after a loading screen, the items in the bags
-- whose cooldown runs, one for each cooldown they share. A cooldown read out of combat that is shorter than Shortest cooldown does not pulse,
-- nor the global cooldown, nor what is left out.
--
-- The end of a cooldown is found without reading what the game withholds in a fight. The flags of a spell's cooldown are never withheld
-- (isEnabled, isActive and isOnGCD, SpellSharedDocumentation.lua:19-31), and isOnGCD is believed only inside SPELL_UPDATE_COOLDOWN, the one
-- place the game says it holds (SpellSharedDocumentation.lua:30). While a cooldown runs, an invisible Cooldown frame of the addon's own holds
-- the game's duration object of it with the global cooldown left out (C_Spell.GetSpellCooldownDuration(id, true), SpellDocumentation.lua:327-342),
-- handed on unread, and its OnCooldownDone says the cooldown is over, as on the icons of Cooldowns.lua and IconRow.lua. An item's start and
-- length are plain numbers (C_Item.GetItemCooldown, ItemDocumentation.lua:434-449, marks nothing secret), which its Cooldown frame takes.
-- A spell with charges pulses when its last charge is back, and one the game holds until a buff of it ends (isEnabled false) waits for that.
--
-- Cooldowns that end together pulse one after another, at most 32 waiting and none twice. The frame is shown only while it pulses. Its fade
-- is an animation group of the game's: an Alpha animation sets the opacity itself, from a frame at none, as the game's own alerts fade in
-- (Blizzard_FrameXML/Mainline/AlertFrameSystems.xml:1090, 1205-1206), so the frame is unseen once it ends. A timer of the length of a pulse
-- starts the next. Nothing of the module runs while nothing shows but the events it hears and the Cooldown frames, which the game runs.
-- A pulse plays Sound, or the sound a spell or item has of its own (Sound of one spell or item, /flatui pulse sound): one of the seven sounds or
-- none, kept for the character in FlatUICharDB.pulseSounds by the key of its entry, a spell by its name, so every rank shares it, an item by its ID.
--
-- Adapted from the Cooldown Pulse of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLCooldownPulse/Runtime.lua
-- and Observers.lua): its tracking of the whole spell book and the trinkets, its list of what is left out, its observers fed duration objects
-- and its queue, and its sound for one spell over the one of all (Runtime.lua:89-101, Core.lua:114-123, Editor.lua:171-207). Flat UI has one
-- look in place of its groups, styles, text, glows, growth and editor, and the sounds of its other pages in place of a choice of files and channels.

local KEY = "pulse"
local MOVER = "FlatUIPulse"
local CROP = 0.08
-- The opacity at the height of a pulse, and the share of its time it takes to come in; the rest it fades out
-- (EnhanceQoLCooldownPulse/Core.lua:13: 0.3 seconds in, 0.7 out, 0.7 at most).
local PEAK, RISE = 0.7, 0.3
-- A cooldown of this many seconds or fewer is the global cooldown (EnhanceQoLCooldownPulse/Runtime.lua:254 counts items over 2 seconds).
local GCD = 2
-- Pulses waiting at most (EnhanceQoLCooldownPulse/Runtime.lua:147), items watched at most, spells and items left out at most.
local MOST_WAITING, MOST_ITEMS, MOST_LEFT = 32, 40, 100
local MAX_ID = 2147483647
-- How far before the numbers of a cooldown its Cooldown frame may say it is over and still count, in seconds. An item used whose cooldown has
-- not run this long after (food, a drink) is forgotten.
local EARLY, FORGET = 0.1, 10
local TRINKETS = { 13, 14 }
local UNKNOWN_ICON = 134400
-- The places of the Sound choices in ns.SOUNDS (IconRow.lua), as EnemyCooldowns.lua has them.
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
-- The lines of Sound of one spell or item once one is chosen: the page's sound, no sound, then each sound of ns.SOUNDS from 3 on, and the line back
-- to what pulses, as Sound of one icon has them (Cooldowns.lua).
local SOUND_PAGE, SOUND_NONE, SOUND_BACK = 1, 2, -1
local SOUND_HELP = "/flatui pulse sound Frost Nova bell - its own sound when it pulses: page, none, spell, chimes, bell, warhorn, raid, alarm or whisper"
local HELP = {
	"/flatui pulse test - a pulse where it shows",
	"/flatui pulse ignore Frost Nova - a spell or an item that is not to pulse: a name, an ID or a shift-clicked link",
	"/flatui pulse watch Frost Nova - it pulses again",
	SOUND_HELP,
	"/flatui pulse list - what pulses, what is left out and the own sounds",
}
local NO_BOOK = "Cooldown pulse: the game has no spell book information, so only items pulse."
local NO_COOLDOWNS = "Cooldown pulse: the game has no spell cooldown information, so only items pulse."
local NO_ITEMS = "Cooldown pulse: the game has no item cooldown information, so only spells pulse."
local NO_TIMER = "Cooldown pulse: the game has no timers, so nothing pulses."
local NO_FADE = "Cooldown pulse: the game made no fade, so the icon shows without one."
local REFUSED = "Cooldown pulse: the game refused to watch a cooldown, so it may not pulse."

local IsSecret = ns.IsSecret

-- spells: the entries by name. ids: the entry of each spell ID, false for a spell of none. items: the entries by item ID. queue: the entries
-- waiting to pulse; current: the one that pulses; token: the pulse a timer belongs to. watching: the entry of each Cooldown frame; free: the
-- Cooldown frames no entry holds. left: what is left out, by spell ID, spell name and item ID. An entry is { kind = "spell" or "item", key,
-- id, name, ranks (spells), cooling (true, false, or nil when unknown), last (the rank whose cooldown runs), length, start (items), short,
-- charged, observer, and for items worn, used (when), seen (its cooldown ran) and held (the game holds its cooldown) }. known: the IDs of
-- the items whose cooldown was watched to its end and that are watched no longer, which the lists still show (P.Listed).
local P = { spells = {}, ids = {}, items = {}, known = {}, queue = {}, token = 0, watching = setmetatable({}, { __mode = "k" }), free = {},
	left = { ids = {}, names = {}, items = {} } }
ns.Pulse = P
-- The words of the sounds in the order of ns.SOUNDS. P.soundFor, set by Sound of one spell or item, is the key of the entry whose sound it offers
-- next; nil while it offers what pulses.
P.WORDS = {}
for word, index in pairs(KITS) do
	P.WORDS[index] = word
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- Values the game gives ----------------------------------------------------------------------------------------------------------------

-- The first answer of a game call, or nil when the call is missing, fails or is withheld.
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

-- A value of a kind, or nil when it is withheld or of another kind.
function P.Plain(value, kind)
	if not IsSecret(value) and type(value) == kind then
		return value
	end
	return nil
end

-- A flag of the game's, true or false, or nil when it is withheld or missing.
function P.Flag(value)
	return P.Plain(value, "boolean")
end

function P.Whole(value)
	return P.Plain(value, "number") ~= nil and value > 0 and value <= MAX_ID and value == math.floor(value)
end

function P.Timers()
	return type(C_Timer) == "table" and type(C_Timer.After) == "function"
end

-- fn after `seconds`, or at once on a client without timers.
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

-- The name of a line of the lists: a spell by its ID, an item by its ID below 0.
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

-- The base cooldown of a spell in seconds (the client gives milliseconds), or nil when the game does not say.
function P.Base(id)
	local milliseconds = P.Ask(GetSpellBaseCooldown, id)
	if P.Plain(milliseconds, "number") and milliseconds == milliseconds then
		return milliseconds / 1000
	end
	return nil
end

-- What is left out -------------------------------------------------------------------------------------------------------------------

-- What this character left out: spell IDs, and item IDs below 0, none twice, at most 100. Nothing is saved for a character who left
-- nothing out; make is true to start the list.
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

-- A spell is left out with every rank of its name.
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

-- The stored IDs that stand for `id`: the same one, or for a spell another rank of the same name.
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

-- The spells and items -----------------------------------------------------------------------------------------------------------------

-- One slot of the spell book: a spell that is not passive, by name, with the ID of the rank the game does not call low (the highest) and the
-- IDs of every rank.
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

-- The spells of the book by name, or nil when the game lacks a call. The walk is the one of the Add a spell list of Cooldowns.lua: the skill
-- lines the game shows that are not of another specialisation.
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

-- The spells and trinkets watched, from the book, the rows and what is left out. An entry that stays keeps its state. A new one is looked at,
-- so a cooldown that runs already is watched to its end; it pulses nothing now.
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
		-- A spell the game gives no base cooldown is watched: what it reads when the cooldown starts says how long it is.
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

-- The entry of a spell ID: a rank in the book, else a spell of the same name (a rank the book does not list). False is kept for a spell of none.
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

-- The entry of an item, made for one the player wears or uses. Nil for an item left out. When 40 are kept, the one used longest ago that is
-- not worn and whose cooldown neither runs nor is held by the game is forgotten to make room: the game names an item each time it is used
-- (SpellBookDocumentation.lua:935), so it is watched again then (P.Used). Nil when none of the 40 can go.
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

-- The two trinkets worn are watched whatever their use (EnhanceQoLCooldownPulse/Runtime.lua:336-338 adds slots 13 and 14). One taken off stays
-- only when it was used.
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

-- An item the game says a cooldown came from.
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

-- The items in the bags whose cooldown runs (C_Container.GetContainerItemCooldown, ContainerDocumentation.lua:122-138, plain numbers), one for
-- each cooldown they share: every healing potion shares one. So a hearthstone used before a /reload still pulses. The bags are 0 to
-- NUM_BAG_SLOTS (Blizzard_FrameXMLBase/Constants.lua:168).
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

-- Reading a cooldown -----------------------------------------------------------------------------------------------------------------

-- Whether a spell's cooldown runs, the global cooldown left out. id: the rank to ask about. mode: "named" inside SPELL_UPDATE_COOLDOWN for this
-- spell, "event" inside one for every cooldown, nil anywhere else; isOnGCD is believed only in the event. A cooldown that starts is watched to
-- its end, and one that was watched and is over pulses.
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
		-- On hold until a buff of the spell ends; the cooldown starts then (SpellSharedDocumentation.lua:25).
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
		-- Every charge back is the end (SpellSharedDocumentation.lua:15: isActive is false at the most charges).
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
				-- The global cooldown. It can cover the end of a cooldown that is watched, which its Cooldown frame still tells.
				if entry.cooling then
					return
				end
				cooling = false
			elseif gcd == false then
				cooling = true
			elseif length then
				cooling = length > GCD
			elseif mode == "named" then
				-- A spell off the global cooldown may leave isOnGCD out (EnhanceQoLCooldownPulse/Runtime.lua:223-227): the cooldown of the spell
				-- the event names is its own.
				cooling = true
			end
		end
	end
	if cooling == nil then
		return
	end
	if cooling then
		-- A cooldown that runs has a length; 0 says nothing.
		if length and length <= 0 then
			length = nil
		end
		local fresh = entry.cooling ~= true or entry.last ~= id
		entry.cooling, entry.last, entry.length = true, id, length
		entry.short = length ~= nil and length < Opt("minimum")
		-- A cooldown named again may have started over; one seen in an event for every cooldown is left to its frame.
		if fresh or mode == "named" or not entry.observer then
			P.Arm(entry, info)
		end
	elseif entry.cooling then
		P.Ready(entry)
	else
		entry.cooling = false
	end
end

-- Whether an item's cooldown runs, from its plain start and length. ended: its Cooldown frame says it is over, which numbers that still run
-- overrule.
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
		-- The cooldown starts later, which the game says with BAG_UPDATE_COOLDOWN.
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

-- The Cooldown frames ----------------------------------------------------------------------------------------------------------------

-- The frame the Cooldown frames hang from: 1 by 1 at no opacity, shown, so that the game runs them unseen (EnhanceQoLCooldownPulse/Observers.lua:58-61
-- keeps its observers shown at no opacity for that).
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
	-- The game says a cooldown is over through this script and no event.
	cooldown:SetScript("OnCooldownDone", P.Finished)
	return cooldown
end

-- The Cooldown frame of an entry, made or taken from those no entry holds; nil when the game would not make one.
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

-- Hands an entry's cooldown to its Cooldown frame: for a spell the game's duration object, unread, or the numbers of `info` when the game has
-- no such object and gives them plain; for an item its plain start and length (FrameAPICooldownDocumentation.lua:281-318).
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
			-- True leaves the global cooldown out.
			got, duration = pcall(spells.GetSpellCooldownDuration, entry.last, true)
		end
		if got and duration ~= nil and cooldown.SetCooldownFromDurationObject then
			ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration, true)
		elseif type(info) == "table" and P.Plain(info.startTime, "number") and P.Plain(info.duration, "number") then
			ok = pcall(cooldown.SetCooldown, cooldown, info.startTime, info.duration)
		end
	end
	if ok then
		-- The template hides the frame (Blizzard_FrameXMLUtil/Mainline/Cooldown.xml:3), and nothing says a cooldown shows it.
		pcall(cooldown.Show, cooldown)
	else
		ns.Note(KEY, REFUSED)
		P.Disarm(entry)
	end
end

-- Takes an entry's Cooldown frame back. It is forgotten before it is cleared, so a script the clearing runs finds no entry.
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

-- A Cooldown frame says its cooldown is over. Numbers the game gives plain that say it still runs are believed over the frame.
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
			-- Watched again by the numbers, whose end is still to come, so the frame says it once more and not at once.
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
			-- A charge is back and the next one recharges: the game moves to it first (EnhanceQoLCooldownPulse/Observers.lua:21-26).
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

-- A cooldown is over: it pulses, unless it was shorter than Shortest cooldown or is left out. An item not worn is watched no longer then,
-- only listed (known), and is watched again when the game names it once more (P.Used). The cooldown of an item is the one of its spell's
-- category, which every item of the category reads, used or not: the game names the item that started it (CooldownViewerItemData.lua:174-186,
-- SpellDocumentation.lua:154-170), and the bags show it on each one (Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua:1994). A potion
-- still watched would pulse again with every potion drunk after it, and with one left out.
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

-- The pulse ----------------------------------------------------------------------------------------------------------------------------

-- In, then out: two Alpha animations one after the other (SimpleAnimAlphaAPIDocumentation.lua, SimpleAnimAPIDocumentation.lua SetOrder).
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
	return { group = group, rise = rise, fall = fall }
end

-- The frame of the pulse: an icon with Flat UI's thin border, as on the Cooldown icons, above the other frames of the screen. It takes no mouse.
function P.Frame()
	local frame = P.frame
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
	P.frame, P.icon = frame, icon
	P.outline = ns.Outline(frame, frame)
	local ok, fade = pcall(P.MakeFade, frame)
	P.fade = ok and fade or nil
	P.Size()
	return frame
end

function P.Size()
	if P.frame then
		local size = Opt("size")
		P.frame:SetSize(size, size)
	end
end

-- At the spot of the movers, which is the middle of the screen until one is saved.
function P.Place()
	local frame = P.frame
	if not frame then
		return
	end
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "CENTER")
	end
	if x then
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

-- The fade for `seconds`; false when there is none or the game refused it.
function P.Fade(seconds)
	local fade = P.fade
	if not fade then
		return false
	end
	return pcall(function()
		fade.rise:SetDuration(seconds * RISE)
		fade.fall:SetDuration(seconds * (1 - RISE))
		fade.group:Stop()
		fade.group:Play()
	end)
end

function P.Hide()
	if P.fade then
		pcall(P.fade.group.Stop, P.fade.group)
	end
	P.frame:Hide()
	P.frame:SetAlpha(0)
end

-- Shows an entry for Opt("time") seconds, with its sound (its own, none, else Sound), then the next one.
function P.Show(entry)
	if not P.Timers() then
		P.current, P.queue = nil, {}
		return
	end
	local seconds = Opt("time")
	local frame = P.Frame()
	P.Size()
	P.Place()
	P.icon:SetTexture(P.Icon(entry))
	frame:SetAlpha(0)
	frame:Show()
	if not P.Fade(seconds) then
		frame:SetAlpha(PEAK)
	end
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[P.OwnSound(entry.key) or Opt("sound")] or 0]
	if sound and ns.PlayKit then
		ns.PlayKit(sound[1], KEY)
	end
	if entry.kind == "item" then
		entry.name = P.ItemName(entry.id)
	end
	P.last = entry.name
	P.token = P.token + 1
	local token = P.token
	C_Timer.After(seconds, function()
		if token ~= P.token then
			return
		end
		if ns.Enabled(KEY) then
			ns.Try(KEY, P.Next)
		else
			pcall(P.Hide)
		end
	end)
end

-- The next pulse that waits, or none: then the frame hides.
function P.Next()
	P.current = table.remove(P.queue, 1)
	if P.current then
		P.Show(P.current)
	elseif P.frame then
		P.Hide()
	end
end

-- An entry waits for its pulse, unless it pulses or waits already, or 32 wait.
function P.Queue(entry)
	if P.current and P.current.key == entry.key then
		return
	end
	for _, waiting in ipairs(P.queue) do
		if waiting.key == entry.key then
			return
		end
	end
	if #P.queue >= MOST_WAITING then
		return
	end
	P.queue[#P.queue + 1] = entry
	if not P.current then
		P.Next()
	end
end

-- Events -----------------------------------------------------------------------------------------------------------------------------

-- SPELL_UPDATE_COOLDOWN(spellID, baseSpellID, category, startRecoveryCategory, itemID) (SpellBookDocumentation.lua:924-936): the spell whose
-- cooldown changed, or none for every cooldown (as CooldownViewer.lua:366-369 reads it), and the item a cast came from.
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

-- isOnGCD does not hold in SPELL_UPDATE_CHARGES; a spell with charges does not read it.
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

-- The book changes in bursts (SPELLS_CHANGED): it is read once, a moment after.
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

-- Off: nothing is watched and nothing shows. The Cooldown frames are kept for the next time.
function P.Stop()
	for _, entry in pairs(P.spells) do
		P.Disarm(entry)
	end
	for _, entry in pairs(P.items) do
		P.Disarm(entry)
	end
	P.spells, P.ids, P.items, P.known, P.queue, P.current, P.on = {}, {}, {}, {}, {}, nil, false
	P.token = P.token + 1
	if P.frame then
		P.Hide()
	end
	ns.ClearNote(KEY, REFUSED)
end

-- A row changed, or the page went on or off. The bags are looked at when the page goes on.
function P.Refresh()
	if not ns.Enabled(KEY) then
		P.Stop()
		return
	end
	local was = P.on
	P.on = true
	P.Build()
	P.Size()
	P.Place()
	if not was then
		P.Bags()
	end
end

-- The rows, the movers, the commands and the status --------------------------------------------------------------------------------------

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

-- The items of Leave out, /flatui pulse list and the status: those watched, and those whose cooldown was watched to its end, which pulse
-- again when the game names them; none left out.
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

-- What pulses now, spells first: a spell by the ID of its highest rank, an item by its ID below 0.
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

-- Both work in combat and with the page off, since they change what is saved; a page that is on reads the list again.
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
	-- The last one put back takes the list with it.
	local saved = ns.Character()
	if #list == 0 and type(saved) == "table" then
		saved.pulseLeftOut = nil
	end
	P.Changed()
	return true, ("%s pulses again."):format(P.Label(id))
end

-- Sounds of their own ------------------------------------------------------------------------------------------------------------------

-- The sounds this character gave spells and items (FlatUICharDB.pulseSounds), by the key of an entry: "spell:" and its name, "item:" and its ID.
-- Nothing is saved for a character who gave none; make is true to start the table.
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

-- The sound an entry pulses with of its own: a word of KITS, or none. Nil plays Sound.
function P.OwnSound(key)
	local sounds = P.Sounds()
	local word = sounds and type(key) == "string" and sounds[key] or nil
	if word == "none" or (type(word) == "string" and KITS[word]) then
		return word
	end
	return nil
end

-- Gives an entry its own sound, or with nil takes it back to Sound. The table goes with the last one.
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

-- The name of a sound of ns.SOUNDS (IconRow.lua:17-25) by its word.
function P.SoundName(word)
	if word == "none" then
		return "no sound"
	end
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[word] or 0]
	return type(sound) == "table" and sound[2] or tostring(word)
end

-- What a change of a sound is answered with.
function P.SoundSaid(name, word)
	if word == nil then
		return ("%s plays the page's sound when it pulses."):format(name)
	end
	return ("%s plays %s when it pulses."):format(name, P.SoundName(word))
end

-- What pulses, as Sound of one spell or item lists it: { line ID, name, key }, a spell by the ID of its highest rank and an item by its ID below 0,
-- as Leave out lists them. With one chosen first, the one whose sound comes next; nil when none is, or it pulses no longer.
function P.SoundRows()
	local rows, chosen = {}, nil
	for _, row in ipairs(ns.PulseCandidates()) do
		local id = row[1]
		local key = id > 0 and ("spell:" .. row[2]) or ("item:" .. -id)
		rows[#rows + 1] = { id, row[2], key }
		if P.soundFor ~= nil and key == P.soundFor then
			chosen = rows[#rows]
		end
	end
	if not chosen then
		P.soundFor = nil
	end
	return rows, chosen
end

-- Sound of one spell or item is one list for two choices, made again each time it opens: what pulses, each with its own sound when it has one,
-- and once one is chosen, the sounds for it (Sound of one icon of Cooldowns.lua works so).
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

-- Works in combat and with the page off, since it changes what is saved.
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
	return true, P.SoundSaid(chosen[2], word)
end

-- /flatui pulse sound: a spell or an item, then page, none or the word of a sound. A spell keeps its sound by its name, so every rank shares it.
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

-- The own sounds as the list says them: "Frost Nova (Bell)", sorted.
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

-- True while the pulse has a handle in the movers: while its page is on.
function ns.PulseShown()
	return ns.Enabled(KEY)
end

-- The movers set or put back its spot.
function ns.PulseMoved()
	if P.frame and ns.Enabled(KEY) then
		ns.Try(KEY, P.Place)
	end
end

-- A spell or an item from what was typed: an item link, a spell link, a spell ID, the name of a spell, or the name of an item the game knows.
-- An item comes back as its ID below 0.
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

function P.Test()
	local first
	for name, entry in pairs(P.spells) do
		if not first or name < first.name then
			first = entry
		end
	end
	P.Queue({ kind = "test", key = "test", name = "a test", icon = first and P.Icon(first) or UNKNOWN_ICON })
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
		-- It changes what is saved, so it works with the page off, as ignore and watch do.
		print(P.SoundCommand(text))
	elseif word == "test" or word == "list" then
		if not ns.Enabled(KEY) then
			print("Cooldown pulse is off. Its page is under Cooldowns.")
		elseif word == "test" then
			ns.Try(KEY, P.Test)
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
	if P.frame and not P.fade then
		lines[#lines + 1] = NO_FADE
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
	Resized = P.Place,
	events = {
		SPELL_UPDATE_COOLDOWN = P.OnCooldown,
		SPELL_UPDATE_CHARGES = P.OnCharges,
		BAG_UPDATE_COOLDOWN = P.CheckItems,
		-- A cooldown the game held in the fight may start now.
		PLAYER_REGEN_ENABLED = P.CheckItems,
		PLAYER_EQUIPMENT_CHANGED = P.Trinkets,
		SPELLS_CHANGED = P.Soon,
		PLAYER_ENTERING_WORLD = P.World,
	},
	slash = { pulse = P.Slash },
	help = HELP,
	Status = P.Status,
})
