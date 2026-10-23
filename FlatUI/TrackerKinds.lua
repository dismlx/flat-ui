local _, ns = ...

-- The kinds of tracker that are not a buff. Each is registered with ns.TrackerKind and Trackers.lua draws, lays out, checks, saves and
-- sounds it like a buff. The first kind is the enchant on a weapon: a shaman's imbue, a rogue's poison, a sharpening stone or an oil.
-- The game gives the enchants of a weapon slot as a list of tables, with the time left in milliseconds, and does not hide them in a fight
-- (C_Item.GetWeaponEnchantInfo, ItemDocumentation.lua:1141-1154, takes no withheld value back). Every field is still tested with
-- IsSecret before it is compared, and a field that is withheld leaves the tracker unknown.

local KEY = "trackers"
local IsSecret = ns.IsSecret

-- SLOTS: by the saved word of a slot, the name of the tracker, the words it is typed with, the slot of Enum.WeaponSlot (MainHand, OffHand,
-- Ranged: ItemConstantsDocumentation.lua:819-828) and the inventory slot of its item (BuffFrame.lua:30-34).
-- ORDER: the slots as the page lists them.
-- ENCHANT: the types of Enum.ItemEnchantType that are counted when the enum is missing: Permanent 1, Temporary 2, Imbue 3.
-- NO_CALL: the line of the status when the game has no answer for a weapon.
local K = {
	SLOTS = {
		main = { name = "Main hand enchant", words = { "main", "main hand", "mainhand" }, slot = 0, item = 16, hand = "main hand" },
		off = { name = "Off hand enchant", words = { "off", "off hand", "offhand" }, slot = 1, item = 17, hand = "off hand" },
		ranged = { name = "Ranged enchant", words = { "ranged" }, slot = 2, item = 18, hand = "ranged" },
	},
	ORDER = { "main", "off", "ranged" },
	PERMANENT = 1, NONE = 0,
	NO_CALL = "Trackers: the game gave no weapon enchant information, so weapon trackers show a grey icon.",
	MAX_NAME = 40, MAX_APPLY = 40, MAX_ID = 2147483647, MAX_SPELLS = 40,
}
-- What was known of each tracker of these kinds, by the id of its entry: the length and end of the enchant on the weapon, the last reading
-- in words for the check, the last icon of a totem, the casts of the player and the last PLAYER_TOTEM_UPDATE of each slot.
local mem = { lengths = {}, last = {}, icons = {}, casts = {}, pending = {} }

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

-- A field of a table, and whether the game withholds it.
local function Field(object, key)
	local ok, value = pcall(function()
		return object[key]
	end)
	if not ok then
		return nil, false
	end
	if IsSecret(value) then
		return nil, true
	end
	return value, false
end

local function Now()
	local ok, now = pcall(GetTime)
	if ok and Plain(now, "number") then
		return now
	end
	return 0
end

-- The slot of Enum.WeaponSlot for a saved word, the game's own number when it has the enum.
local function GameSlot(word)
	local names = { main = "MainHand", off = "OffHand", ranged = "Ranged" }
	local slots = type(Enum) == "table" and type(Enum.WeaponSlot) == "table" and Enum.WeaponSlot or {}
	local number = slots[names[word]]
	if Plain(number, "number") then
		return number
	end
	return K.SLOTS[word].slot
end

local function ItemTexture(word)
	local ok, texture = pcall(GetInventoryItemTexture, "player", K.SLOTS[word].item)
	if ok and (Plain(texture, "number") or Plain(texture, "string")) then
		return texture
	end
	return nil
end

-- The enchants of a slot as a list of tables: nil and a word when the call is missing, raises, is withheld or gives no table. The
-- game gives a list of tables; one table with the fields of an enchant is taken as a list of one.
local function EnchantList(slot)
	local call = type(C_Item) == "table" and C_Item.GetWeaponEnchantInfo
	if type(call) ~= "function" then
		return nil, "the call is missing"
	end
	local ok, answer = pcall(call, slot)
	if not ok then
		return nil, "the call raised an error"
	elseif IsSecret(answer) then
		return nil, "the game hid the answer"
	elseif type(answer) ~= "table" then
		return nil, "the game gave no table"
	end
	local own = Field(answer, "hasEnchant")
	if own ~= nil then
		return { answer }
	end
	local list = {}
	pcall(function()
		for _, item in pairs(answer) do
			list[#list + 1] = item
		end
	end)
	return list
end

-- The enchant to show out of a list: the first temporary one with time left, else the first permanent one. Also the words of the check:
-- { found, type, seconds, raw } of what was found, and whether some field was withheld.
local function Choose(list)
	local temporary, permanent, hidden
	local temporaryType, permanentType = nil, nil
	for _, item in ipairs(list) do
		if IsSecret(item) then
			hidden = true
		elseif type(item) == "table" then
			local has, hiddenHas = Field(item, "hasEnchant")
			local kind, hiddenKind = Field(item, "enchantType")
			local left, hiddenLeft = Field(item, "timeLeft")
			if hiddenHas or hiddenKind or hiddenLeft then
				hidden = true
			elseif has == true then
				local raw = Plain(left, "number") and left or 0
				local type_ = Plain(kind, "number") and kind or nil
				if type_ ~= K.NONE then
					if type_ == K.PERMANENT then
						if not permanent then
							permanent, permanentType = item, type_
						end
					elseif raw > 0 and not temporary then
						temporary, temporaryType = item, type_
					end
				end
			end
		end
	end
	if temporary then
		return temporary, temporaryType, false, hidden
	elseif permanent then
		return permanent, permanentType, true, hidden
	end
	return nil, nil, false, hidden
end

-- The words the check gives for a weapon tracker.
local function Remember(entry, found)
	mem.last[entry.id] = found
end

-- The reading of the enchant on the weapon of a tracker's slot: { state, hidden = false, count, expires, length, icon, id }. The game never hides
-- a weapon enchant, so hidden is always false.
local function Read(entry)
	local word = entry.slot
	local id = entry.id
	if word == "off" then
		local call = type(C_PaperDollInfo) == "table" and C_PaperDollInfo.OffhandHasWeapon
		local ok, has = false, nil
		if type(call) == "function" then
			ok, has = pcall(call)
		end
		if not ok or IsSecret(has) or has ~= true then
			Remember(entry, { word = "no weapon in the off hand" })
			return { state = "unknown", hidden = false }
		end
	end
	local list, why = EnchantList(GameSlot(word))
	if not list then
		ns.Note(KEY, K.NO_CALL)
		Remember(entry, { word = why })
		return { state = "unknown", hidden = false }
	end
	local item, kind, isPermanent, hidden = Choose(list)
	if not item then
		mem.lengths[id] = nil
		if hidden then
			Remember(entry, { word = "a field was withheld" })
			return { state = "unknown", hidden = false }
		end
		Remember(entry, { found = false })
		return { state = "missing", hidden = false, icon = ItemTexture(word) }
	end
	local charges, enchantID, iconID = Field(item, "charges"), Field(item, "enchantID"), Field(item, "enchantIconID")
	local left = Field(item, "timeLeft")
	local raw = Plain(left, "number") and left or 0
	local seconds = raw / 1000
	local count = Plain(charges, "number") and charges > 0 and charges or nil
	local icon = Plain(iconID, "number") and iconID > 0 and iconID or ItemTexture(word)
	local reading = { state = "fine", hidden = false, count = count, icon = icon, id = Plain(enchantID, "number") and enchantID or nil }
	Remember(entry, { found = true, type = kind, seconds = (not isPermanent) and seconds or nil, raw = raw, count = count })
	local low = ns.TrackerValue(entry, "low")
	local lowTime = ns.TrackerValue(entry, "lowTime")
	if count and low > 0 and count <= low then
		reading.state = "low"
	end
	if isPermanent then
		return reading
	end
	-- The end of the enchant is kept while it moves by a second or less, so that one timer is set for it and not one for each look; a
	-- longer move is a new enchant, or a new application of the same one, and the length is seen again.
	local now = Now()
	local ends = now + seconds
	local kept = mem.lengths[id]
	if not kept or kept.id ~= reading.id then
		kept = { id = reading.id, length = seconds, ends = ends }
	elseif ends > kept.ends + 1 then
		kept = { id = reading.id, length = seconds, ends = ends }
	elseif ends < kept.ends - 1 then
		kept.ends = ends
	else
		ends = kept.ends
	end
	kept.length = math.max(kept.length, seconds)
	mem.lengths[id] = kept
	reading.expires, reading.length = ends, kept.length
	if lowTime > 0 then
		if ends - now <= lowTime then
			reading.state = "low"
		elseif type(ns.TrackerWake) == "function" then
			ns.TrackerWake(entry, ends - lowTime)
		end
	end
	return reading
end

-- True when the entry is a weapon tracker with a slot of the three; the name is the slot's own when none was given, and the spells that put
-- the enchant on are whole numbers.
local function Clean(entry)
	if not K.SLOTS[entry.slot] then
		return false
	end
	if not (type(entry.name) == "string" and #entry.name >= 1 and #entry.name <= K.MAX_NAME) then
		entry.name = K.SLOTS[entry.slot].name
	end
	if entry.apply ~= nil then
		local apply, seen = {}, {}
		for _, id in ipairs(type(entry.apply) == "table" and entry.apply or {}) do
			if type(id) == "number" and id >= 1 and id <= K.MAX_ID and id == math.floor(id) and not seen[id] and #apply < K.MAX_APPLY then
				seen[id] = true
				apply[#apply + 1] = id
			end
		end
		entry.apply = #apply > 0 and apply or nil
	end
	return true
end

-- The slot a typed word stands for: main, off hand, ranged.
local function SlotOf(text)
	local wanted = tostring(text or ""):lower():match("^%s*(.-)%s*$")
	for _, word in ipairs(K.ORDER) do
		for _, spelling in ipairs(K.SLOTS[word].words) do
			if wanted == spelling then
				return word
			end
		end
	end
	return nil
end

-- The fields of a new weapon tracker for a word, or nil and the line to print.
local function Add(argument, entries)
	local word = SlotOf(argument)
	if not word then
		return nil, "Which weapon? main, off or ranged."
	end
	for _, entry in ipairs(entries) do
		if entry.kind == "weapon" and entry.slot == word then
			return nil, "Already tracked."
		end
	end
	return { slot = word, name = K.SLOTS[word].name }, ("Added %s."):format(K.SLOTS[word].name)
end

local function Label(entry)
	local info = K.SLOTS[entry.slot]
	if type(entry.name) == "string" and entry.name ~= "" then
		return entry.name
	end
	return info and info.name or "Weapon enchant"
end

local function Icon(entry)
	return K.SLOTS[entry.slot] and ItemTexture(entry.slot) or nil
end

-- The line of the check: the slot, whether an enchant was found, its type and the time left with the number the game gave.
local function Lines(entry)
	local info = K.SLOTS[entry.slot]
	local last = mem.last[entry.id]
	local hand = info and info.hand or "unknown slot"
	if not last then
		return { ("Weapon enchant: %s, not read yet."):format(hand) }
	elseif last.word then
		return { ("Weapon enchant: %s, %s."):format(hand, last.word) }
	elseif not last.found then
		return { ("Weapon enchant: %s, found no."):format(hand) }
	end
	local time = last.seconds and ("%d s left (the game gave %d)"):format(math.floor(last.seconds), math.floor(last.raw)) or "no time limit"
	local charges = last.count and (", %d charges"):format(last.count) or ""
	return { ("Weapon enchant: %s, found yes, type %s, %s%s."):format(hand, last.type and ("%d"):format(last.type) or "not given", time, charges) }
end

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("weapon", {
		Read = Read, Clean = Clean, Add = Add, Label = Label, Icon = Icon, Lines = Lines,
		events = { "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED", "UNIT_INVENTORY_CHANGED" },
		what = "weapon enchant", hiddenAble = false,
	})
end

-- Totems and the pet ------------------------------------------------------------------------------------------------------------------

-- The totem slots as the game numbers them (Constants.lua:226-229: fire 1, earth 2, water 3, air 4) and the name each tracker is shown by.
-- A slot the game hides (C_Secrets.ShouldTotemSlotBeSecret, SecretPredicateAPIDocumentation.lua:188-200) gives GetTotemInfo withheld values
-- (TotemDocumentation.lua:59-80), and the tracker is then drawn by calls that take a withheld value and are never read back: the sweep from the
-- duration object of the slot (GetTotemDuration has no withheld tag), the time text from a duration text binding, the icon handed to
-- Texture:SetTexture, and the presence by SetAlphaFromBoolean on frames (SimpleFrameAPIDocumentation.lua:1145-1155).
-- SETTLE: seconds after PLAYER_TOTEM_UPDATE before a hidden slot is judged, so that the cast that put the totem down has been heard.
-- WINDOW: seconds before the event within which a cast of the player is taken as the one that put the totem down.
-- PARTS: the ways of drawing a hidden totem, each with a switch of its own: when the game refuses one it is off for good and the line says so.
-- off and worked: by the word of a part, whether it is switched off and whether it ever worked.
local T = {
	NUMBERS = { fire = 1, earth = 2, water = 3, air = 4 },
	NAMES = { fire = "Fire totem", earth = "Earth totem", water = "Water totem", air = "Air totem" },
	ORDER = { "fire", "earth", "water", "air" },
	SETTLE = 0.5, WINDOW = 1,
	PARTS = { "sweep", "bar", "time", "icon", "presence" },
	NO_INFO = "Trackers: the game gave no totem information, so totem trackers show a grey icon.",
	REFUSED = {
		sweep = "Trackers: the game refused a sweep from the totem's duration, so a hidden totem shows no sweep.",
		bar = "Trackers: the game refused a timer on a bar, so a hidden totem shows no timer on its bar.",
		time = "Trackers: the game refused the time text of a totem, so a hidden totem shows no time.",
		icon = "Trackers: the game refused the icon of a hidden totem, so it shows the last known icon.",
		presence = "Trackers: the game refused a part of a hidden totem, so a totem in a slot the game hides shows the last known look, or is hidden, as In fights without the game's icon says.",
	},
	off = {}, worked = {},
}

local function Truth(call, ...)
	local ok, answer = pcall(call, ...)
	if ok and not IsSecret(answer) and type(answer) == "boolean" then
		return answer
	end
	return nil
end

-- Whether the game hides a slot: false when it says no or has no such call, true when it says yes, raises or does not answer a boolean.
local function SlotHidden(slot)
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldTotemSlotBeSecret
	if type(call) ~= "function" then
		return false
	end
	local ok, answer = pcall(call, slot)
	if not ok or IsSecret(answer) or type(answer) ~= "boolean" then
		return true
	end
	return answer
end

-- What GetTotemInfo says of an open slot: { have, start, duration, icon }, nil and a word when the call fails, nil and "hidden" when any
-- answer is withheld. A slot the game answers nothing for has no totem, as the game's own totem frame takes it.
local function TotemInfo(slot)
	local ok, have, _, start, duration, icon = pcall(GetTotemInfo, slot)
	if not ok then
		return nil, "the call is missing or raised an error"
	elseif IsSecret(have) or IsSecret(start) or IsSecret(duration) or IsSecret(icon) then
		return nil, "hidden"
	elseif have == nil then
		return { have = false }
	elseif type(have) ~= "boolean" then
		return nil, "the game gave no boolean"
	end
	local info = { have = have }
	if have then
		info.start = Plain(start, "number") and start or nil
		info.duration = Plain(duration, "number") and duration or nil
		info.icon = (Plain(icon, "number") or Plain(icon, "string")) and icon or nil
	end
	return info
end

local function TotemRead(entry)
	local id, slot = entry.id, T.NUMBERS[entry.slot]
	local hidden = SlotHidden(slot)
	local info, why
	if not hidden then
		info, why = TotemInfo(slot)
		hidden = why == "hidden"
	end
	if hidden then
		mem.last[id] = { hidden = true }
		return { state = "unknown", hidden = true, totem = slot }
	elseif not info then
		ns.Note(KEY, T.NO_INFO)
		mem.last[id] = { word = why }
		return { state = "unknown", hidden = false }
	elseif not info.have then
		mem.last[id] = { have = false }
		return { state = "missing", hidden = false, icon = mem.icons[id] }
	end
	mem.icons[id] = info.icon or mem.icons[id]
	local reading = { state = "fine", hidden = false, icon = info.icon }
	local seconds
	if info.start and info.duration and info.duration > 0 then
		reading.expires, reading.length = info.start + info.duration, info.duration
		seconds = reading.expires - Now()
		local lowTime = ns.TrackerValue(entry, "lowTime")
		if lowTime > 0 then
			if seconds <= lowTime then
				reading.state = "low"
			elseif type(ns.TrackerWake) == "function" then
				ns.TrackerWake(entry, reading.expires - lowTime)
			end
		end
	end
	mem.last[id] = { have = true, seconds = seconds }
	return reading
end

-- A part of the drawing of a hidden totem: runs the call, and when the game refuses it the part is off for good, with one line.
local function Try(part, call)
	if T.off[part] then
		return false
	end
	if not pcall(call) then
		T.off[part] = true
		ns.Note(KEY, T.REFUSED[part])
		return false
	end
	T.worked[part] = true
	return true
end

local function SpellTexture(id)
	local call = type(C_Spell) == "table" and C_Spell.GetSpellTexture
	if id == nil or type(call) ~= "function" then
		return nil
	end
	local ok, texture = pcall(call, id)
	if ok and (Plain(texture, "number") or Plain(texture, "string")) then
		return texture
	end
	return nil
end

-- The icon of the missing look: the last totem seen, else the first spell listed, else the question mark.
local function LookIcon(entry)
	return mem.icons[entry.id] or SpellTexture(type(entry.spells) == "table" and entry.spells[1] or nil) or 134400
end

-- Takes the parts of a hidden totem away: what the game shows is the record's own look again.
local function Release(record, hid)
	if not hid.live then
		return
	end
	hid.live = false
	pcall(function()
		hid.absent:Hide()
		hid.present:Hide()
		if hid.sweep then
			hid.sweep:Clear()
		end
		hid.time:SetText("")
		if hid.body then
			record.file = nil
		end
		if hid.binding then
			hid.binding:Disable()
		end
	end)
end

-- Red, green and blue of the tracker's colour for the bar of a hidden totem: its own, else the page's, else blue.
local function BarColour(entry)
	local hex = ns.TrackerValue(entry, "colour")
	if type(hex) == "string" and #hex == 8 then
		local r, g, b = tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), tonumber(hex:sub(7, 8), 16)
		if r and g and b then
			return r / 255, g / 255, b / 255
		end
	end
	return 0.302, 0.6, 0.902
end

-- The parts of a hidden totem on a record, made the first time one is wanted, which can be in a fight (plain and Cooldown frames are open to
-- addons there). Two frames of the record sit over the host, one for a totem that is there and one for the missing look, neither a child of
-- the other so that the alpha of one never reaches the other. An icon has them over the icon; a bar or text has them over its body, the first
-- with a bar and a time string of its own, so that the drawing of the body is left alone.
local function Frames(record, entry)
	local shape = record.shape
	local body = shape ~= "icon" and record.parts[shape] and record.parts[shape].body or nil
	local host = body or record.frame
	local hid = record.hid
	if hid and hid.host == host then
		return hid
	elseif hid then
		Release(record, hid)
	end
	hid = { host = host, body = body }
	hid.Leave = function()
		Release(record, hid)
	end
	local level = host:GetFrameLevel() + 6
	local absent = CreateFrame("Frame", nil, record.frame)
	ns.Own[absent] = true
	absent:SetAllPoints(host)
	absent:SetFrameLevel(level)
	hid.absent = absent
	hid.look = absent:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[hid.look] = true
	hid.look:SetAllPoints(absent)
	hid.look:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	hid.look:SetDesaturated(true)
	hid.look:SetVertexColor(0.851, 0.251, 0.251)
	hid.word = absent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	ns.Own[hid.word] = true
	hid.word:SetPoint("CENTER", absent, "CENTER", 0, 0)
	hid.word:SetText("Missing")
	local present = CreateFrame("Frame", nil, record.frame)
	ns.Own[present] = true
	present:SetAllPoints(host)
	present:SetFrameLevel(level)
	hid.present = present
	if body then
		hid.texture = record.texture
		if shape == "bar" then
			local bar = CreateFrame("StatusBar", nil, present)
			ns.Own[bar] = true
			bar:SetAllPoints(present)
			bar:SetStatusBarTexture(ns.BarTexture(ns.Get("trackers.barTexture")) or "Interface/Buttons/WHITE8X8")
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(0)
			bar:SetStatusBarColor(BarColour(entry))
			hid.bar = bar
		end
		hid.time = present:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		ns.Own[hid.time] = true
		hid.time:SetPoint("RIGHT", present, "RIGHT", -1, 0)
	else
		hid.texture = present:CreateTexture(nil, "ARTWORK", nil, 0)
		ns.Own[hid.texture] = true
		hid.texture:SetAllPoints(present)
		hid.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		hid.sweep = CreateFrame("Cooldown", nil, present, "CooldownFrameTemplate")
		ns.Own[hid.sweep] = true
		hid.sweep:SetAllPoints(present)
		hid.sweep:SetDrawEdge(false)
		hid.sweep:SetDrawBling(false)
		hid.sweep:SetSwipeColor(0, 0, 0, 0.7)
		hid.sweep:SetHideCountdownNumbers(true)
		hid.time = present:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		ns.Own[hid.time] = true
		hid.time:SetPoint("CENTER", present, "CENTER", 0, 0)
	end
	record.hid = hid
	return hid
end

-- The text of the time left, bound to a duration object by the game; red under Low at, white from there on. The colour is left out when the
-- game refuses a curve, which leaves the time itself.
local function Binding(hid, seconds)
	if not hid.binding then
		hid.binding = C_DurationUtil.CreateDurationTextBinding()
		hid.binding:SetFontString(hid.time)
	end
	if hid.curve ~= seconds then
		hid.curve = seconds
		pcall(function()
			if seconds > 0 then
				local curve = C_CurveUtil.CreateColorCurve()
				curve:SetType(Enum.LuaCurveType.Step)
				curve:AddPoint(0, CreateColor(0.851, 0.251, 0.251, 1))
				curve:AddPoint(seconds, CreateColor(1, 1, 1, 1))
				hid.binding:SetTextColorCurve(curve, Enum.DurationTextBindingProperty.RemainingDuration)
			else
				hid.binding:ClearTextColorCurve()
			end
		end)
	end
end

-- The options of a bar that runs down with the time left, as the game bar passes them (SimpleStatusBarConstantsDocumentation.lua:52).
local function BarOptions()
	local direction = type(Enum) == "table" and type(Enum.StatusBarTimerDirection) == "table" and Enum.StatusBarTimerDirection.RemainingTime
	local interpolation = type(Enum) == "table" and type(Enum.StatusBarInterpolation) == "table" and Enum.StatusBarInterpolation.Immediate
	return interpolation or 0, direction or 1
end

-- Draws the hidden totem of a record: true when the presence was drawn, which is the part that cannot be left out. The withheld answer of
-- GetTotemInfo goes straight into the calls that take it and is never read.
local function TotemHidden(entry, record, reading)
	local hid = record.hid
	if reading.state ~= "unknown" or reading.hidden ~= true then
		if hid then
			Release(record, hid)
		end
		return false
	end
	local slot = T.NUMBERS[entry.slot]
	if T.off.presence or not slot then
		if hid and hid.live then
			Release(record, hid)
		end
		return false
	end
	local made, frames = pcall(Frames, record, entry)
	if not made then
		T.off.presence = true
		ns.Note(KEY, T.REFUSED.presence)
		return false
	end
	hid = frames
	local ok, have, _, _, _, icon = pcall(GetTotemInfo, slot)
	if not ok or not (IsSecret(have) or type(have) == "boolean") then
		Release(record, hid)
		return false
	end
	local gave, duration = pcall(GetTotemDuration, slot)
	if not gave or IsSecret(duration) or duration == nil then
		duration = nil
	end
	if not hid.live then
		hid.live = true
		hid.absent:Show()
		hid.present:Show()
	end
	if not Try("presence", function()
		hid.present:SetAlphaFromBoolean(have, 1, 0)
		hid.absent:SetAlphaFromBoolean(have, 0, 1)
	end) then
		Release(record, hid)
		return false
	end
	hid.look:SetTexture(LookIcon(entry))
	hid.word:SetShown(ns.TrackerValue(entry, "missing") == "word")
	if not Try("icon", function() hid.texture:SetTexture(icon) end) then
		hid.texture:SetTexture(LookIcon(entry))
	end
	if duration then
		if hid.sweep then
			Try("sweep", function() hid.sweep:SetCooldownFromDurationObject(duration) end)
		end
		if hid.bar then
			Try("bar", function() hid.bar:SetTimerDuration(duration, BarOptions()) end)
		end
		if ns.TrackerValue(entry, "numbers") then
			Try("time", function()
				Binding(hid, ns.TrackerValue(entry, "lowTime"))
				hid.binding:SetDuration(duration)
				hid.binding:Enable()
			end)
		end
	end
	return true
end

-- The listed spells of the totem trackers of a slot, and whether any tracker of the slot has a list.
local function TotemSpells(slot)
	local set, any = {}, false
	for _, entry in ipairs(ns.TrackerEntries()) do
		if entry.kind == "totem" and T.NUMBERS[entry.slot] == slot then
			for _, id in ipairs(entry.spells or {}) do
				set[id] = true
				any = true
			end
		end
	end
	return set, any
end

-- A cast of the player: kept for 2 seconds with its moment, so that the end of a totem can be told from the putting down of one.
local function TotemCast(spellID)
	local now = Now()
	local casts = { { id = spellID, at = now } }
	for _, cast in ipairs(mem.casts) do
		if now - cast.at <= 2 then
			casts[#casts + 1] = cast
		end
	end
	mem.casts = casts
end

-- Whether the player cast a totem spell of a slot around a moment: a spell in a tracker's list, or any spell when the slot has no list.
local function CastNear(slot, at)
	local set, any = TotemSpells(slot)
	for _, cast in ipairs(mem.casts) do
		if cast.at >= at - T.WINDOW and cast.at <= at + T.SETTLE + 0.01 and (not any or set[cast.id]) then
			return true
		end
	end
	return false
end

-- A totem of a slot the game hides changed: a slot that is open is judged by the reading, and a hidden one by this event. The sound is the
-- tracker's own, and is left out when the player put a totem down around the event.
local function TotemEvent(event, ...)
	if event ~= "PLAYER_TOTEM_UPDATE" then
		return
	end
	local slot = ...
	if IsSecret(slot) or type(slot) ~= "number" then
		return
	end
	-- A slot that is open is read by the tracker, and its drop has the usual two passes.
	if not SlotHidden(slot) then
		return
	end
	local at = Now()
	mem.pending[slot] = at
	local function Judge()
		if mem.pending[slot] ~= at or not SlotHidden(slot) or CastNear(slot, at) then
			return
		end
		for _, entry in ipairs(ns.TrackerEntries()) do
			if entry.kind == "totem" and T.NUMBERS[entry.slot] == slot and entry.on ~= false then
				ns.TrackerSound(entry)
			end
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(T.SETTLE, Judge)
	end
end

local function WholeList(list, most)
	local clean, seen = {}, {}
	for _, id in ipairs(type(list) == "table" and list or {}) do
		if type(id) == "number" and id > 0 and id <= K.MAX_ID and id == math.floor(id) and not seen[id] and #clean < most then
			seen[id] = true
			clean[#clean + 1] = id
		end
	end
	return #clean > 0 and clean or nil
end

local function TotemClean(entry)
	if not T.NUMBERS[entry.slot] then
		return false
	end
	if not (type(entry.name) == "string" and #entry.name >= 1 and #entry.name <= K.MAX_NAME) then
		entry.name = T.NAMES[entry.slot]
	end
	if entry.spells ~= nil then
		entry.spells = WholeList(entry.spells, K.MAX_APPLY)
	end
	return true
end

local function TotemAdd(argument, entries)
	local wanted = tostring(argument or ""):lower():gsub("%s*totem%s*$", ""):match("^%s*(.-)%s*$")
	if not T.NUMBERS[wanted] then
		return nil, "Which totem? fire, earth, water or air."
	end
	for _, entry in ipairs(entries) do
		if entry.kind == "totem" and entry.slot == wanted then
			return nil, "Already tracked."
		end
	end
	return { slot = wanted, name = T.NAMES[wanted] }, ("Added %s."):format(T.NAMES[wanted])
end

local function TotemLabel(entry)
	if type(entry.name) == "string" and entry.name ~= "" then
		return entry.name
	end
	return T.NAMES[entry.slot] or "Totem"
end

local function TotemIcon(entry)
	return mem.icons[entry.id]
end

local function Word(part)
	return T.off[part] and "refused" or (T.worked[part] and "accepted" or "not tried")
end

-- The line of the check: the slot, whether the game hides it, and for an open slot whether there is a totem and the time left; for a hidden
-- one what each way of drawing it did.
local function TotemLines(entry)
	local last = mem.last[entry.id]
	local slot = entry.slot or "unknown"
	if not last then
		return { ("Totem: %s, not read yet."):format(slot) }
	elseif last.word then
		return { ("Totem: %s open, %s."):format(slot, last.word) }
	elseif last.hidden then
		local parts = {}
		for _, part in ipairs(T.PARTS) do
			parts[#parts + 1] = part .. " " .. Word(part)
		end
		return { ("Totem: %s hidden by the game. Drawn by its own calls: %s."):format(slot, table.concat(parts, ", ")) }
	elseif not last.have then
		return { ("Totem: %s open, have no."):format(slot) }
	end
	local time = last.seconds and ("%d s left"):format(math.max(0, math.floor(last.seconds))) or "no time given"
	return { ("Totem: %s open, have yes, %s."):format(slot, time) }
end

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("totem", {
		Read = TotemRead, Clean = TotemClean, Add = TotemAdd, Label = TotemLabel, Icon = TotemIcon, Lines = TotemLines,
		Hidden = TotemHidden, Event = TotemEvent, Cast = TotemCast,
		events = { "PLAYER_TOTEM_UPDATE" },
		what = "totem",
	})
end

-- The pet. A pet is there when UnitExists says so and it is not dead (UnitIsDead). The buffs of the unless list excuse a missing pet, such as
-- Demonic Sacrifice, and are only known while the game gives buff information. Happiness is the first answer of C_PetInfo.GetPetHappiness
-- (PetInfoDocumentation.lua:35-45): 1 mad, 2 neutral, 3 happy, as PetHappiness.lua:1-6 names them; it is low under 3 (not happy) when the tracker has happy.
-- UNIT_PET is heard for the player and UNIT_HAPPINESS for the pet (Blizzard_FrameXML/PetHappiness.lua:29-32); the death and the return of the player are
-- events of the trackers already.
local P = { NAME = "Pet", HAPPY = 3, MAX_UNLESS = 8 }

local function Happiness()
	local call = type(C_PetInfo) == "table" and C_PetInfo.GetPetHappiness
	if type(call) ~= "function" then
		return nil
	end
	local ok, happiness = pcall(call)
	if ok and not IsSecret(happiness) and type(happiness) == "number" then
		return happiness
	end
	return nil
end

local function SummonIcon(entry)
	for _, id in ipairs(entry.summon or {}) do
		local texture = SpellTexture(id)
		if texture then
			return texture
		end
	end
	return nil
end

local function PetRead(entry)
	local id = entry.id
	local exists = Truth(UnitExists, "pet")
	local dead = false
	if exists then
		dead = Truth(UnitIsDead, "pet")
	end
	local happiness = Happiness()
	local last = { exists = exists, happiness = happiness }
	if exists then
		last.dead = dead
	end
	mem.last[id] = last
	local icon = SummonIcon(entry)
	if exists == nil or dead == nil then
		return { state = "unknown", hidden = false, icon = icon }
	elseif exists and not dead then
		local state = "fine"
		if entry.happy == true and happiness and happiness < P.HAPPY then
			state = "low"
		end
		return { state = state, hidden = false, icon = icon }
	end
	if type(entry.unless) == "table" and #entry.unless > 0 and type(ns.TrackerBuffOn) == "function" then
		local on = ns.TrackerBuffOn(entry.unless)
		if on == true then
			last.excused = true
			return { state = "fine", hidden = false, icon = icon }
		elseif on == nil then
			return { state = "unknown", hidden = false, icon = icon }
		end
	end
	return { state = "missing", hidden = false, icon = icon }
end

local function PetClean(entry)
	if not (type(entry.name) == "string" and #entry.name >= 1 and #entry.name <= K.MAX_NAME) then
		entry.name = P.NAME
	end
	entry.summon = WholeList(entry.summon, K.MAX_APPLY)
	entry.unless = WholeList(entry.unless, P.MAX_UNLESS)
	if entry.happy ~= true then
		entry.happy = nil
	end
	return true
end

local function PetAdd(_, entries)
	for _, entry in ipairs(entries) do
		if entry.kind == "pet" then
			return nil, "Already tracked."
		end
	end
	return { name = P.NAME }, "Added Pet."
end

local function PetLabel(entry)
	if type(entry.name) == "string" and entry.name ~= "" then
		return entry.name
	end
	return P.NAME
end

local function Say(value)
	return value == true and "yes" or (value == false and "no" or "not known")
end

local function PetLines(entry)
	local last = mem.last[entry.id]
	if not last then
		return { "Pet: not read yet." }
	end
	local happiness = last.happiness and ("%d"):format(last.happiness) or "not given"
	local text = ("Pet: exists %s, dead %s, happiness %s"):format(Say(last.exists), Say(last.dead), happiness)
	if last.excused then
		text = text .. ", excused by a buff"
	end
	return { text .. "." }
end

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("pet", {
		Read = PetRead, Clean = PetClean, Add = PetAdd, Label = PetLabel, Icon = SummonIcon, Lines = PetLines,
		events = { "UNIT_PET", "UNIT_HAPPINESS" },
		unitEvents = { UNIT_PET = "player", UNIT_HAPPINESS = "pet" },
		what = "pet", hiddenAble = false,
	})
end

-- Items, ammunition, tracking, stances and forms ---------------------------------------------------------------------------------------

-- An item is counted with C_Item.GetItemCount(item, false, true) and its cooldown comes from C_Item.GetItemCooldown (ItemDocumentation.lua:434-468;
-- neither answer is withheld). The ammunition is the count of inventory slot 0 (INVSLOT_AMMO, Constants.lua:135) while UnitUsesAmmo says the
-- player uses ammunition (UnitDocumentation.lua:3359; PaperDollFrame.lua:1499, 2149). Tracking is the list of C_Minimap.GetTrackingInfo
-- (MinimapDocumentation.lua:61-68, 103-116, 308-319). A stance or form is GetShapeshiftFormInfo(index), which gives texture, isActive,
-- isCastable and spellID as the stance bar takes them (StanceBar.lua:66-71). The game documents no return types of the last one, so each
-- answer is taken by its type, and a withheld one leaves the tracker unknown.
-- MAX_*: the most items of a tracker, the most spells of a form tracker and the most lines of the item picker.
-- ICON: the question mark, for what has no icon of its own. AMMO: the inventory slot of the ammunition.
local I = {
	MAX_ITEMS = 40, MAX_FORMS = 8, MAX_BAG_LINES = 100, ICON = 134400, AMMO = 0,
	NO_COUNT = "Trackers: the game gave no item count, so item trackers show a grey icon.",
	NAMES = { ammo = "Ammunition", tracking = "Tracking", form = "Stance or form" },
}

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

local function Many(number, noun)
	return ("%d %s%s"):format(number, noun, number == 1 and "" or "s")
end

local function Fileish(value)
	return Plain(value, "number") or Plain(value, "string")
end

local function Whole(value)
	return Plain(value, "number") and value >= 1 and value <= K.MAX_ID and value == math.floor(value)
end

-- The name of an entry, or the default when it has none of one to forty characters.
local function Named(entry, default)
	if not (type(entry.name) == "string" and #entry.name >= 1 and #entry.name <= K.MAX_NAME) then
		entry.name = default
	end
end

-- The count of one item in the bags, nil when the game gives no number.
local function ItemCount(id)
	local count = Ask(type(C_Item) == "table" and C_Item.GetItemCount, id, false, true)
	if Plain(count, "number") and count >= 0 then
		return count
	end
	return nil
end

-- The icon of an item: the game's icon call, else the fifth answer of GetItemInfoInstant (ItemDocumentation.lua:659-680).
local function ItemIcon(id)
	local items = type(C_Item) == "table" and C_Item or {}
	local icon = Ask(items.GetItemIconByID, id)
	if Fileish(icon) then
		return icon
	end
	if type(items.GetItemInfoInstant) == "function" then
		local ok, _, _, _, _, instant = pcall(items.GetItemInfoInstant, id)
		if ok and Fileish(instant) then
			return instant
		end
	end
	return nil
end

-- The cooldown of an item: start and duration when it is running, else nil and a word.
local function ItemCooldown(id)
	local items, containers = type(C_Item) == "table" and C_Item or {}, type(C_Container) == "table" and C_Container or {}
	local call = type(items.GetItemCooldown) == "function" and items.GetItemCooldown or containers.GetItemCooldown
	if type(call) ~= "function" then
		return nil, "not given"
	end
	local ok, start, duration, enable = pcall(call, id)
	if not ok or IsSecret(start) or IsSecret(duration) or IsSecret(enable) or not (Plain(start, "number") and Plain(duration, "number")) then
		return nil, "not given"
	elseif duration > 0 and (enable == true or (Plain(enable, "number") and enable ~= 0)) then
		return start, duration
	end
	return nil, "none"
end

-- Fine, low or missing for a count. A tracker's own Low at counts a count at that number or under as low, and 0 never. Without one an item
-- is low under the Item minimum and ammunition at the Ammunition minimum or under.
local function Level(entry, count, ammo)
	if count <= 0 then
		return "missing"
	elseif entry.low ~= nil then
		return (entry.low > 0 and count <= entry.low) and "low" or "fine"
	end
	local page = ns.Get(KEY .. (ammo and ".ammoMin" or ".itemMin"))
	if not Plain(page, "number") then
		return "fine"
	elseif ammo then
		return (page > 0 and count <= page) and "low" or "fine"
	end
	return count < page and "low" or "fine"
end

-- The words of the low line of the check.
local function LowWords(entry, ammo)
	if entry.low ~= nil then
		return entry.low > 0 and ("at %d or fewer"):format(entry.low) or "never"
	end
	local page = ns.Get(KEY .. (ammo and ".ammoMin" or ".itemMin"))
	if not Plain(page, "number") then
		return "not known"
	elseif ammo then
		return page > 0 and ("at %d or fewer"):format(page) or "never"
	end
	return ("under %d"):format(page)
end

local function ItemRead(entry)
	local id, total, answered, counted = entry.id, 0, 0, nil
	for _, item in ipairs(entry.items or {}) do
		local count = ItemCount(item)
		if count then
			answered = answered + 1
			total = total + count
			if count > 0 and not counted then
				counted = item
			end
		end
	end
	local icon = ItemIcon(counted or (entry.items or {})[1] or 0) or mem.icons[id]
	mem.icons[id] = icon
	if answered == 0 then
		ns.Note(KEY, I.NO_COUNT)
		mem.last[id] = { word = "the game gave no count" }
		return { state = "unknown", hidden = false, icon = icon }
	end
	local reading = { state = Level(entry, total, false), hidden = false, count = total, icon = icon }
	local last = { count = total }
	if counted then
		local start, duration = ItemCooldown(counted)
		if start then
			reading.expires, reading.length = start + duration, duration
			last.cooldown = "running"
		else
			last.cooldown = duration
		end
	end
	mem.last[id] = last
	return reading
end

local function ItemClean(entry)
	entry.items = WholeList(entry.items, I.MAX_ITEMS)
	if not entry.items then
		return false
	end
	Named(entry, "Item " .. entry.items[1])
	return true
end

local function ItemIcons(entry)
	return mem.icons[entry.id] or ItemIcon((entry.items or {})[1] or 0)
end

local function ItemLines(entry)
	local last = mem.last[entry.id]
	local ids = table.concat(entry.items or {}, ", ")
	if not last then
		return { ("Item: IDs %s, not read yet."):format(ids) }
	elseif last.word then
		return { ("Item: IDs %s, %s."):format(ids, last.word) }
	end
	return { ("Item: IDs %s, count %d, low %s, cooldown %s."):format(ids, last.count, LowWords(entry, false), last.cooldown or "none") }
end

-- The items in the bags, each once: { id, name }, sorted by name, at most 100. Bags 0 to NUM_BAG_SLOTS and the reagent bag after them
-- (Constants.lua:168-170); C_Container.GetContainerNumSlots and GetContainerItemInfo (ContainerDocumentation.lua:192-206, 313-326, 764-781).
local function BagItems()
	local rows, seen = {}, {}
	local containers = type(C_Container) == "table" and C_Container or {}
	local bags = Plain(NUM_BAG_SLOTS, "number") and NUM_BAG_SLOTS or 4
	if Plain(NUM_REAGENTBAG_SLOTS, "number") and NUM_REAGENTBAG_SLOTS > 0 then
		bags = bags + NUM_REAGENTBAG_SLOTS
	end
	for bag = 0, bags do
		local slots = Ask(containers.GetContainerNumSlots, bag)
		for slot = 1, Plain(slots, "number") and slots or 0 do
			local info = Ask(containers.GetContainerItemInfo, bag, slot)
			if type(info) == "table" then
				local id, name = Field(info, "itemID"), Field(info, "itemName")
				if Whole(id) and not seen[id] and Plain(name, "string") and name ~= "" then
					seen[id] = true
					rows[#rows + 1] = { id, name }
				end
			end
		end
	end
	table.sort(rows, function(a, b)
		local first, second = a[2]:lower(), b[2]:lower()
		if first ~= second then
			return first < second
		end
		return a[1] < b[1]
	end)
	while #rows > I.MAX_BAG_LINES do
		rows[#rows] = nil
	end
	return rows
end

-- The ID of an item typed as an ID, a shift-clicked link or a name: a name is looked for in the bags first, then asked of the game.
local function ItemId(argument)
	if Plain(argument, "number") then
		return Whole(argument) and argument or nil
	end
	local text = tostring(argument or ""):match("^%s*(.-)%s*$")
	local id = tonumber(text:match("^%d+$") or text:match("|Hitem:(%d+)") or text:match("^item:(%d+)"))
	if Whole(id) then
		return id
	end
	local wanted = text:lower()
	if wanted == "" then
		return nil
	end
	for _, row in ipairs(BagItems()) do
		if row[2]:lower() == wanted then
			return row[1], row[2]
		end
	end
	local known = Ask(type(C_Item) == "table" and C_Item.GetItemInfoInstant, text)
	return Whole(known) and known or nil
end

local function ItemName(id, name)
	if name then
		return name
	end
	for _, row in ipairs(BagItems()) do
		if row[1] == id then
			return row[2]
		end
	end
	local known = Ask(type(C_Item) == "table" and C_Item.GetItemNameByID, id)
	if Plain(known, "string") and known ~= "" and #known <= K.MAX_NAME then
		return known
	end
	return "Item " .. id
end

local function ItemAdd(argument, entries)
	local id, name = ItemId(argument)
	if not id then
		return nil, "Which item? A name, an item ID or a shift-clicked item."
	end
	for _, entry in ipairs(entries) do
		for _, listed in ipairs(entry.kind == "item" and entry.items or {}) do
			if listed == id then
				return nil, "Already tracked."
			end
		end
	end
	name = ItemName(id, name)
	return { name = name, items = { id } }, ("Added %s."):format(name)
end

-- The lines of the Add an item row: each item in the bags that no tracker lists.
function ns.TrackerItemCandidates()
	local tracked = {}
	for _, entry in ipairs(ns.TrackerEntries()) do
		for _, id in ipairs(entry.kind == "item" and entry.items or {}) do
			tracked[id] = true
		end
	end
	local rows = {}
	for _, row in ipairs(BagItems()) do
		if not tracked[row[1]] then
			rows[#rows + 1] = row
		end
	end
	return rows
end

function ns.TrackerAddItem(id)
	return ns.TrackerAddKind("item", id)
end

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("item", {
		Read = ItemRead, Clean = ItemClean, Add = ItemAdd, Icon = ItemIcons, Lines = ItemLines,
		events = { "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN" },
		what = "item", hiddenAble = false,
	})
end

-- Ammunition: fine, with no count, while the player uses none.
local function AmmoIcon()
	local icon = Ask(GetInventoryItemTexture, "player", I.AMMO)
	return Fileish(icon) and icon or I.ICON
end

local function AmmoRead(entry)
	local id = entry.id
	local uses = Truth(UnitUsesAmmo, "player")
	local icon = AmmoIcon()
	if uses == nil then
		mem.last[id] = { word = "uses ammo not known" }
		return { state = "unknown", hidden = false, icon = icon }
	elseif not uses then
		mem.last[id] = { uses = false }
		return { state = "fine", hidden = false, icon = icon }
	end
	local count = Ask(GetInventoryItemCount, "player", I.AMMO)
	if not (Plain(count, "number") and count >= 0) then
		mem.last[id] = { uses = true, word = "slot 0 gave no count" }
		return { state = "unknown", hidden = false, icon = icon }
	end
	mem.last[id] = { uses = true, count = count }
	return { state = Level(entry, count, true), hidden = false, count = count, icon = icon }
end

local function AmmoLines(entry)
	local last = mem.last[entry.id]
	if not last then
		return { "Ammunition: not read yet." }
	elseif last.word then
		return { ("Ammunition: %s."):format(last.word) }
	elseif not last.uses then
		return { "Ammunition: uses ammo no." }
	end
	return { ("Ammunition: uses ammo yes, slot %d count %d, low %s."):format(I.AMMO, last.count, LowWords(entry, true)) }
end

-- A kind with one tracker and no fields of its own: its Clean gives the name, its Add adds it once.
local function Single(kind)
	return function(entry)
		Named(entry, I.NAMES[kind])
		return true
	end, function(_, entries)
		for _, entry in ipairs(entries) do
			if entry.kind == kind then
				return nil, "Already tracked."
			end
		end
		return { name = I.NAMES[kind] }, ("Added %s."):format(I.NAMES[kind])
	end
end

local AmmoClean, AmmoAdd = Single("ammo")

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("ammo", {
		Read = AmmoRead, Clean = AmmoClean, Add = AmmoAdd, Icon = AmmoIcon, Lines = AmmoLines,
		events = { "UNIT_INVENTORY_CHANGED", "BAG_UPDATE_DELAYED" },
		what = "ammunition", hiddenAble = false,
	})
end

-- Tracking: fine while any minimap tracking is on, missing when none is, unknown when the game lists none or gives no answer.
local function TrackingRead(entry)
	local id = entry.id
	local types = Ask(type(C_Minimap) == "table" and C_Minimap.GetNumTrackingTypes)
	if not (Plain(types, "number") and types >= 1) then
		local number = Plain(types, "number") and types or nil
		mem.last[id] = { types = number, word = number and "the game lists none" or "the game gave no list" }
		return { state = "unknown", hidden = false, icon = mem.icons[id] }
	end
	local active, hidden = nil, false
	for index = 1, math.floor(types) do
		local ok, info = pcall(C_Minimap.GetTrackingInfo, index)
		if not ok or IsSecret(info) or type(info) ~= "table" then
			hidden = true
		else
			local on, withheld = Field(info, "active")
			if withheld or (on ~= true and on ~= false) then
				hidden = true
			elseif on and not active then
				active = info
			end
		end
	end
	if active then
		local name, texture = Field(active, "name"), Field(active, "texture")
		if Fileish(texture) then
			mem.icons[id] = texture
		end
		mem.last[id] = { types = types, active = Plain(name, "string") and name or "not named" }
		return { state = "fine", hidden = false, icon = mem.icons[id] }
	elseif hidden then
		mem.last[id] = { types = types, word = "an answer was withheld" }
		return { state = "unknown", hidden = false, icon = mem.icons[id] }
	end
	mem.last[id] = { types = types }
	return { state = "missing", icon = mem.icons[id], hidden = false }
end

local function TrackingLines(entry)
	local last = mem.last[entry.id]
	if not last then
		return { "Tracking: not read yet." }
	end
	local types = last.types and Many(last.types, "type") or "not known"
	if last.word then
		return { ("Tracking: %s, %s."):format(types, last.word) }
	end
	return { ("Tracking: %s, active %s."):format(types, last.active or "none") }
end

local TrackingClean, TrackingAdd = Single("tracking")

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("tracking", {
		Read = TrackingRead, Clean = TrackingClean, Add = TrackingAdd, Icon = function(entry) return mem.icons[entry.id] end, Lines = TrackingLines,
		events = { "MINIMAP_UPDATE_TRACKING" },
		what = "tracking", hiddenAble = false,
	})
end

-- Stances and forms: GetShapeshiftFormInfo(index) for each of GetNumShapeshiftForms() gives { texture, isActive, isCastable, spellID }. An
-- active flag is a boolean, 1 or 0, and anything else leaves the tracker unknown.
local function FormInfo(index)
	local ok, texture, active, _, spell = pcall(GetShapeshiftFormInfo, index)
	if not ok or IsSecret(texture) or IsSecret(active) or IsSecret(spell) then
		return nil
	end
	if active == 1 then
		active = true
	elseif active == 0 or active == nil then
		active = false
	elseif type(active) ~= "boolean" then
		return nil
	end
	return { texture = Fileish(texture) and texture or nil, active = active, spell = Whole(spell) and spell or nil }
end

local function FormCount()
	local count = Ask(GetNumShapeshiftForms)
	return Plain(count, "number") and count >= 0 and math.floor(count) or nil
end

local function FormRead(entry)
	local id = entry.id
	local count = FormCount()
	if not count or count == 0 then
		mem.last[id] = { forms = count, word = count and "the character has none" or "the game gave no count" }
		return { state = "unknown", hidden = false, icon = mem.icons[id] }
	end
	local listed = {}
	for _, spell in ipairs(entry.spells or {}) do
		listed[spell] = true
	end
	local any = entry.spells ~= nil and #entry.spells > 0
	local active, found, hidden = nil, nil, false
	for index = 1, count do
		local info = FormInfo(index)
		if not info then
			hidden = true
		elseif info.active then
			active = active or index
			if not found and (not any or (info.spell and listed[info.spell])) then
				found = info
			end
		end
	end
	mem.last[id] = { forms = count, active = active }
	if found then
		mem.icons[id] = found.texture or mem.icons[id]
		return { state = "fine", hidden = false, icon = mem.icons[id] }
	elseif hidden then
		mem.last[id].word = "an answer was withheld"
		return { state = "unknown", hidden = false, icon = mem.icons[id] }
	end
	return { state = "missing", hidden = false, icon = mem.icons[id] or SpellTexture((entry.spells or {})[1]) }
end

local function FormClean(entry)
	entry.spells = WholeList(entry.spells, I.MAX_FORMS)
	Named(entry, I.NAMES.form)
	return true
end

local function FormIcon(entry)
	return mem.icons[entry.id] or SpellTexture((entry.spells or {})[1])
end

-- The forms the character has: { index, spellID, name }, the name the game's own for the spell, else Form and the number.
local function Forms()
	local rows = {}
	for index = 1, FormCount() or 0 do
		local info = FormInfo(index)
		if info and info.spell then
			local name = Ask(type(C_Spell) == "table" and C_Spell.GetSpellName, info.spell)
			rows[#rows + 1] = { index, info.spell, Plain(name, "string") and name ~= "" and name or ("Form " .. index) }
		end
	end
	return rows
end

-- What is added: a table { index } is the form at that place, a number or digits is a spell ID, text is the name of a form the character has.
local function FormAdd(argument, entries)
	local spell, name
	if type(argument) == "table" then
		for _, row in ipairs(Forms()) do
			if row[1] == argument.index then
				spell, name = row[2], row[3]
			end
		end
	elseif Plain(argument, "number") or tostring(argument or ""):match("^%s*%d+%s*$") then
		spell = tonumber(argument)
		name = Whole(spell) and Ask(type(C_Spell) == "table" and C_Spell.GetSpellName, spell) or nil
	else
		local wanted = tostring(argument or ""):lower():match("^%s*(.-)%s*$")
		for _, row in ipairs(Forms()) do
			if wanted ~= "" and row[3]:lower() == wanted then
				spell, name = row[2], row[3]
			end
		end
	end
	if not Whole(spell) then
		return nil, "Which stance or form? One of the forms you have, or a spell ID."
	end
	for _, entry in ipairs(entries) do
		for _, listed in ipairs(entry.kind == "form" and entry.spells or {}) do
			if listed == spell then
				return nil, "Already tracked."
			end
		end
	end
	name = Plain(name, "string") and name ~= "" and #name <= K.MAX_NAME and name or ("Form " .. spell)
	return { name = name, spells = { spell } }, ("Added %s."):format(name)
end

local function FormLines(entry)
	local last = mem.last[entry.id]
	if not last then
		return { "Forms: not read yet." }
	end
	local count = last.forms and Many(last.forms, "form") or "not known"
	if last.word and not last.active then
		return { ("Forms: %s, %s."):format(count, last.word) }
	end
	return { ("Forms: %s, active %s."):format(count, last.active and ("%d"):format(last.active) or "none") }
end

-- The lines of the Add a stance or form row, and the pick of one.
function ns.TrackerFormCandidates()
	local rows = {}
	for _, row in ipairs(Forms()) do
		rows[#rows + 1] = { row[1], row[3] }
	end
	return rows
end

function ns.TrackerAddForm(index)
	return ns.TrackerAddKind("form", { index = index })
end

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("form", {
		Read = FormRead, Clean = FormClean, Add = FormAdd, Icon = FormIcon, Lines = FormLines,
		events = { "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS" },
		what = "stance or form", hiddenAble = false,
	})
end

-- The player's own debuff on the target. It is read like a buff: ns.DebuffReading (Trackers.lua) asks C_UnitAuras.GetUnitAuras("target",
-- "HARMFUL|PLAYER") (UnitAuraDocumentation.lua:493-511) and GetAuraDataBySpellName with the same filter (UnitAuraDocumentation.lua:245-262) while the
-- game gives aura values, and the game's own icon is an aura container on the target with that filter. A harmful aura of a unit the player can attack
-- may be matched by spell ID, one of a unit the player can assist may not (Blizzard_AuraContainerUtil.lua:64-86). The tracker is wanted only while
-- the target can be attacked and is alive. PLAYER_TARGET_CHANGED makes the game's own icon look again (Blizzard_AuraContainer.lua:50-54, which names
-- target changes) and drops the reading kept from the last target.
local function DebuffRead(entry)
	local reading = ns.DebuffReading(entry)
	mem.last[entry.id] = { found = reading.found, source = reading.source }
	return reading
end

local function DebuffClean(entry)
	return ns.TrackerCleanSpells(entry) == true
end

-- The spell a typed or picked argument stands for: an ID, a spell link, a name, and the name the game gives it.
local function DebuffSpell(argument)
	local text = tostring(argument or ""):match("^%s*(.-)%s*$")
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	if not id and text ~= "" then
		local info = Ask(type(C_Spell) == "table" and C_Spell.GetSpellInfo, text)
		id = type(info) == "table" and info.spellID or nil
	end
	local name = Whole(id) and Ask(type(C_Spell) == "table" and C_Spell.GetSpellName, id) or nil
	if Whole(id) and Plain(name, "string") and name ~= "" and #name <= K.MAX_NAME then
		return id, name
	end
	return nil
end

-- Adds the spell with every rank of its name that the spell book lists, as a buff is added.
local function DebuffAdd(argument, entries)
	local id, name = DebuffSpell(argument)
	if not id and tostring(argument or ""):match("^%s*$") then
		return nil, "Name a spell."
	end
	if not id then
		return nil, ('No spell found for "%s".'):format(tostring(argument or ""))
	end
	for _, entry in ipairs(entries) do
		if entry.kind == "debuff" then
			for _, listed in ipairs(entry.spells) do
				if listed == id then
					return nil, ("%s is already tracked."):format(name)
				end
			end
			for _, text in ipairs(entry.names) do
				if text == name then
					return nil, ("%s is already tracked."):format(name)
				end
			end
		end
	end
	local spells, seen = { id }, { [id] = true }
	for _, rank in ipairs(type(ns.TrackerRanks) == "function" and ns.TrackerRanks(name) or {}) do
		if not seen[rank] and #spells < K.MAX_SPELLS then
			seen[rank] = true
			spells[#spells + 1] = rank
		end
	end
	return { name = name, names = { name }, spells = spells }, ("Added %s."):format(name)
end

-- 0 while there is no target the player can attack. An answer the game withholds leaves the tracker as its reading says.
local function DebuffWanted()
	if ns.TrackerTarget() == "none" then
		return 0
	end
	return nil
end

local function DebuffEvent(event)
	if event ~= "PLAYER_TARGET_CHANGED" then
		return
	end
	for _, entry in ipairs(type(ns.TrackerEntries) == "function" and ns.TrackerEntries() or {}) do
		if entry.kind == "debuff" then
			ns.TrackerUnkeep(entry.id)
		end
	end
	local slots = ns.TrackerSlots
	if type(slots) == "table" and type(slots.Retarget) == "function" then
		slots.Retarget()
	end
end

local function DebuffLines(entry)
	local target = ns.TrackerTarget()
	local last = mem.last[entry.id]
	local lines = { target == nil and "Target: not known." or ("Target: attackable %s."):format(target == "attackable" and "yes" or "no") }
	if last and last.found then
		lines[#lines + 1] = ("Found by: %s%s."):format(last.found, last.source and (", source " .. last.source) or "")
	end
	return lines
end

-- The pick of a spell on the Add a debuff on the target row.
function ns.TrackerAddDebuff(id)
	return ns.TrackerAddKind("debuff", id)
end

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("debuff", {
		Read = DebuffRead, Clean = DebuffClean, Add = DebuffAdd, Lines = DebuffLines, Wanted = DebuffWanted, Event = DebuffEvent,
		events = { "PLAYER_TARGET_CHANGED" },
		slot = { unit = "target", filter = "HARMFUL|PLAYER" },
		what = "debuff on the target",
	})
end

-- The lines of the Add a check row: each is a number, the place of a check in the list of every kind of check, and the name it is shown by.
-- A kind adds its checks after the ones here.
local PICKS = {}
for number, word in ipairs(K.ORDER) do
	PICKS[number] = { "weapon", word, K.SLOTS[word].name }
end
for _, word in ipairs(T.ORDER) do
	PICKS[#PICKS + 1] = { "totem", word, T.NAMES[word] }
end
PICKS[#PICKS + 1] = { "pet", "", P.NAME }
PICKS[#PICKS + 1] = { "ammo", "", I.NAMES.ammo }
PICKS[#PICKS + 1] = { "tracking", "", I.NAMES.tracking }

function ns.TrackerOtherCandidates()
	local rows = {}
	for number, pick in ipairs(PICKS) do
		rows[#rows + 1] = { number, pick[3] }
	end
	return rows
end

function ns.TrackerAddOther(number)
	local pick = type(number) == "number" and PICKS[number]
	if not pick then
		return false, "Not added."
	end
	return ns.TrackerAddKind(pick[1], pick[2])
end
