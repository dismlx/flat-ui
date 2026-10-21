local _, ns = ...

-- A row of flat square icons for the spells the player picks. The icons are frames of this addon's
-- own, and the game draws their sweep and countdown from a duration object that goes from one game
-- call to another without being read. The icons of the game's own cooldown manager get the same
-- square look by restyling their art. Frames are made and laid out out of combat; the sweep, the
-- dimming and the count are Cooldown, texture and font string calls, which are allowed in combat.
-- The row hangs from the spot the movers saved for it, or else from the Position setting.

local KEY = "cooldowns"
local PART = "cooldown manager icons"
-- The name of the row among the saved spots of the movers.
local MOVER = "FlatUICooldowns"
local MAX_SPELLS = 40
local MAX_ID = 2147483647
local CROP = 0.08
-- The game lays the manager's icons out with their frames overlapping by this much at its
-- default padding, so a square icon the size of its frame would touch its neighbours.
local INSET = 2
-- Units between the resource display and the row, and below the middle of the screen.
local GAP = 4
local SCREEN_Y = -160
-- Seconds between looks at the icons that are dimmed, and at the cooldown manager.
local RECHECK = 0.2
local SWEEP = 1
local UNKNOWN_ICON = 134400
local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
-- The bars of the personal resource display, lowest first.
local RESOURCE_BARS = { "AlternatePowerBar", "PowerBar", "HealthBarsContainer" }
local ITEM_OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"
local ITEM_MASK = "UI-HUD-CoolDownManager-Mask"
local SQUARE_SWEEP = "Interface\\ChatFrame\\ChatFrameBackground"
local ROUND_SWEEP = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local NO_POSITION = "Cooldown icons: the personal resource display cannot be used, so the row is in the middle of the screen."
local NO_SWEEP = "Cooldown icons: the game hides cooldown times and has no other way to draw them, so icons dim without a sweep."
local SWEEP_REFUSED = "Cooldown icons: the game refused to draw cooldown sweeps, so icons dim without a sweep."
local NO_COOLDOWNS = "Cooldown icons: the game has no spell cooldown information, so the row shows no cooldowns."
local NO_SOUND = "Cooldown icons: the game played no sound, so Sound when ready is silent."
local RAID_WARNING = 8959
local NO_BOOK = "Cooldown icons: the game has no spell book information, so Add a spell lists nothing."
local NO_BINDS = "Cooldown icons: the game has no action bar key information, so Keybind on icons shows no keys."
local NO_TRINKETS = "Cooldown icons: the game has no equipment information, so Equipped trinkets shows nothing."
local NO_ITEM_SWEEP = "Cooldown icons: the game hides trinket cooldowns, so trinket icons show no sweep."
local NO_COUNT_FONT = "Cooldown icons: the game refused the font of the icon text, so Charge count size and Keybind size are not applied."
local NO_NUMBERS_FONT = "Cooldown icons: the game refused the countdown font, so Countdown number size is not applied."
-- The fonts of the countdown numbers, and of the key on an icon.
local NO_GAME_FONT = "Cooldown icons: the game's countdown font could not be read, so Countdown number size keeps the last size chosen until /reload."
local NUMBER_FONTS = { small = "NumberFontNormalSmall", normal = "NumberFontNormal", large = "NumberFontNormalLarge", huge = "NumberFontNormalHuge" }
local KEYBIND_FONT = "NumberFontNormalSmallGray"
local BIND_PART, FLASH_PART, TRINKET_PART, FONT_PART = "keybinds", "ready flash", "trinkets", "countdown size"
-- The flash when a cooldown ends goes from this opacity to none in this many seconds.
local FLASH_FROM, FLASH_TIME = 0.6, 0.4
local TRINKET_SLOTS = { 13, 14 }
-- The first action bar slot of each bar of twelve and the key bindings of its buttons (MultiActionBars.lua:1-9 for the pages,
-- Blizzard_Keybindings.lua:321-335 for the bars; slot = (page - 1) * 12 + button). The main bar shows page 2 or a
-- bonus bar (stealth, forms, stances) through the same buttons, which keep their ACTIONBUTTON bindings
-- (ActionBarController.lua:167-170, ActionButton.lua:497-501), so slots 13-24 and 73-132 map to ACTIONBUTTON too.
local BAR_SLOTS = { { 1, "ACTIONBUTTON" }, { 13, "ACTIONBUTTON" }, { 73, "ACTIONBUTTON" }, { 85, "ACTIONBUTTON" }, { 97, "ACTIONBUTTON" },
	{ 109, "ACTIONBUTTON" }, { 121, "ACTIONBUTTON" }, { 25, "MULTIACTIONBAR3BUTTON" }, { 37, "MULTIACTIONBAR4BUTTON" }, { 49, "MULTIACTIONBAR2BUTTON" },
	{ 61, "MULTIACTIONBAR1BUTTON" }, { 145, "MULTIACTIONBAR5BUTTON" }, { 157, "MULTIACTIONBAR6BUTTON" }, { 169, "MULTIACTIONBAR7BUTTON" } }

local HELP = {
	"/flatui cooldown add 2094 - a spell ID, a name or a shift-clicked spell",
	"/flatui cooldown remove 2094",
	"/flatui cooldown list",
}

local IsSecret = ns.IsSecret

local holder
-- Every icon made, in row order, and the ones on screen.
local icons, shown = {}, {}
-- The cooldown manager's icons this part has styled.
local items = setmetatable({}, { __mode = "k" })
local layoutQueued, sweepQueued = false, false
local sinceRecheck, sinceSweep = 0, 0
-- True from PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED.
local fighting = false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The first answer of a game call, or nil when the call is missing, fails or is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not IsSecret(answer) then
		return answer
	end
	return nil
end

-- A field of a frame, or nil when it is missing, cannot be read or is withheld.
local function Field(frame, key)
	local ok, value = pcall(function()
		return frame[key]
	end)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- The crop of the row's icons, as a fraction of the picture.
local function Crop()
	return Opt("crop") / 100
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function IsTrue(value)
	return not IsSecret(value) and value == true
end

local function Whole(value)
	return Plain(value, "number") and value > 0 and value <= MAX_ID and value == math.floor(value)
end

-- The spells ----------------------------------------------------------------------------------

-- The saved spell IDs of this character: whole numbers above 0, none twice, at most 40.
local function List()
	local saved = ns.Character()
	if not saved then
		return {}
	end
	local old = saved.cooldowns
	local list, seen = {}, {}
	if type(old) == "table" then
		for _, id in ipairs(old) do
			if Whole(id) and not seen[id] and #list < MAX_SPELLS then
				seen[id] = true
				list[#list + 1] = id
			end
		end
		local same = true
		for key in pairs(old) do
			same = same and list[key] ~= nil and list[key] == old[key]
		end
		if same and #list == #old then
			return old
		end
	end
	saved.cooldowns = list
	return list
end

local function SpellName(spellID)
	local name = Ask(C_Spell and C_Spell.GetSpellName, spellID)
	if Plain(name, "string") and name ~= "" then
		return name
	end
	return nil
end

local function Name(spellID)
	return SpellName(spellID) or ("Spell " .. spellID)
end

-- A spell the character has lost stays in the list and comes back when it is known again.
local function Known(spellID)
	local book = C_SpellBook
	if book then
		for _, call in ipairs({ "IsSpellKnownOrInSpellBook", "IsSpellKnown" }) do
			local known = Ask(book[call], spellID)
			if type(known) == "boolean" then
				return known
			end
		end
	end
	return true
end

local function HasCooldown(spellID)
	local milliseconds = Ask(GetSpellBaseCooldown, spellID)
	if Plain(milliseconds, "number") then
		return milliseconds > 0
	end
	return true
end

-- The spell book, or nil when the game lacks a call the list of spells to pick from needs.
local function SpellBook()
	local book = C_SpellBook
	if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo
		and Enum and Enum.SpellBookSpellBank and Enum.SpellBookItemType then
		return book
	end
	return nil
end

-- The picked spells the character knows, in the order they were picked.
local function Spells()
	local spells = {}
	for _, id in ipairs(List()) do
		if Known(id) then
			spells[#spells + 1] = id
		end
	end
	return spells
end

-- A spell ID or a spell link, without asking the game whether the spell exists.
local function Parse(text)
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	return Whole(id) and id or nil
end

local function Resolve(text)
	text = text:match("^%s*(.-)%s*$")
	local id = Parse(text)
	if not id and text ~= "" then
		local info = Ask(C_Spell and C_Spell.GetSpellInfo, text)
		if type(info) == "table" then
			id = info.spellID
		end
	end
	if Whole(id) and SpellName(id) then
		return id
	end
	return nil
end

-- The icons ------------------------------------------------------------------------------------

local function DrawSweep(record, info, cooling, recharging)
	local spells, cooldown, spellID = C_Spell, record.cooldown, record.spell
	if info == nil then
		cooldown:Clear()
		return
	end
	if spells.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
		local ok, duration
		if recharging and spells.GetSpellChargeDuration then
			ok, duration = pcall(spells.GetSpellChargeDuration, spellID)
		else
			-- True leaves the global cooldown out.
			ok, duration = pcall(spells.GetSpellCooldownDuration, spellID, true)
		end
		if ok and duration ~= nil then
			-- The game may refuse a duration object; the icon then dims without a sweep.
			if pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration, true) then
				-- The template hides the frame, and nothing says this call shows it.
				if cooling or recharging then
					cooldown:Show()
				end
			else
				cooldown:Clear()
				ns.Note(KEY, SWEEP_REFUSED)
			end
		else
			cooldown:Clear()
		end
		return
	end
	-- The numbers are drawn only where the game has no duration object and withholds nothing.
	local start, length, rate = info.startTime, info.duration, info.modRate
	if cooling and Plain(start, "number") and Plain(length, "number") then
		cooldown:SetCooldown(start, length, Plain(rate, "number") and rate or 1)
	else
		cooldown:Clear()
		if cooling then
			ns.Note(KEY, NO_SWEEP)
		end
	end
end

-- One white square over the icon that fades out, played when a cooldown ends.
local function Flash(record)
	local flash = record.flash
	if flash == nil then
		local texture = record.top:CreateTexture(nil, "OVERLAY", nil, 0)
		ns.Own[texture] = true
		texture:SetAllPoints(record.frame)
		texture:SetColorTexture(1, 1, 1, 1)
		texture:Hide()
		local group = texture:CreateAnimationGroup()
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(FLASH_FROM)
		fade:SetToAlpha(0)
		fade:SetDuration(FLASH_TIME)
		group:SetScript("OnFinished", function()
			texture:Hide()
		end)
		flash = { texture = texture, group = group }
		record.flash = flash
	end
	flash.group:Stop()
	flash.texture:Show()
	flash.group:Play()
end

-- The text sizes of the icon: the charge count, and the key when there is one.
local function TextSizes(record)
	local count = ns.TextStyle(record.count, { percent = Opt("countSize") })
	local key = record.bind == nil or ns.TextStyle(record.bind, { percent = Opt("keybindSize") })
	if count == false or key == false then
		ns.Note(KEY, NO_COUNT_FONT)
	end
end

-- The countdown font, set when the choice changes. The game's own font is read once from the countdown's
-- font string (Cooldown:GetCountdownFontString, FrameAPICooldownDocumentation.lua:78-89; SimpleFont GetFont,
-- SimpleFontAPIDocumentation.lua:62) before the first change, and As the game has it puts it back.
local function GameFont(cooldown)
	local fs = Ask(cooldown.GetCountdownFontString, cooldown)
	if fs == nil then
		return false
	end
	local ok, file, size, flags = pcall(fs.GetFont, fs)
	if ok and Plain(file, "string") and Plain(size, "number") and (flags == nil or Plain(flags, "string")) then
		return { file, size, flags or "" }
	end
	return false
end

local function NumbersFont(record)
	local name = NUMBER_FONTS[Opt("numbersFont")]
	local cooldown = record.cooldown
	if name == nil then
		if record.font ~= nil then
			record.font = nil
			local saved = record.gameFont
			local fs = saved and Ask(cooldown.GetCountdownFontString, cooldown)
			if not (fs and pcall(fs.SetFont, fs, saved[1], saved[2], saved[3])) then
				ns.Note(KEY, NO_GAME_FONT)
			end
		end
		return
	end
	if record.font == name then
		return
	end
	if record.gameFont == nil then
		record.gameFont = GameFont(cooldown)
	end
	record.font = name
	if not (cooldown.SetCountdownFont and pcall(cooldown.SetCountdownFont, cooldown, name)) then
		ns.Note(KEY, NO_NUMBERS_FONT)
	end
end

-- The look of an icon from its state: dimming, opacity, border, sweep, numbers and the flash. Only
-- texture, frame and Cooldown calls on this addon's own frames, which are allowed in combat.
local function Look(record, cooling, secret, active)
	local texture, cooldown, frame = record.texture, record.cooldown, record.frame
	if Opt("dim") then
		if secret then
			texture:SetDesaturated(Opt("dimDesat") and active)
			texture:SetVertexColor(1, 1, 1)
		else
			local level = cooling and 1 - Opt("dimDarkness") / 100 or 1
			texture:SetDesaturated(cooling and Opt("dimDesat"))
			texture:SetVertexColor(level, level, level)
		end
	else
		texture:SetDesaturated(false)
		texture:SetVertexColor(1, 1, 1)
	end
	local coolAlpha, readyAlpha = Opt("coolAlpha") / 100, Opt("readyAlpha") / 100
	if secret and frame.SetAlphaFromBoolean then
		frame:SetAlphaFromBoolean(active, coolAlpha, readyAlpha)
	else
		frame:SetAlpha(cooling and coolAlpha or readyAlpha)
	end
	local border = Opt("border")
	ns.SetOutline(record.outline, border, border)
	if border and Opt("borderState") and not secret then
		ns.SetOutlineColour(record.outline, ns.Colour(KEY .. (cooling and ".coolingColour" or ".readyColour")))
	else
		ns.SetOutlineColour(record.outline, nil, nil, nil)
	end
	if cooldown.SetHideCountdownNumbers then
		cooldown:SetHideCountdownNumbers(not Opt("numbers"))
	end
	ns.EachPart(KEY, FONT_PART, NumbersFont, record)
	local sweep, sweepAlpha = Opt("sweep"), Opt("sweepAlpha")
	if record.sweep ~= sweep then
		record.sweep = sweep
		cooldown:SetDrawSwipe(sweep)
	end
	if record.sweepAlpha ~= sweepAlpha then
		record.sweepAlpha = sweepAlpha
		cooldown:SetSwipeColor(0, 0, 0, sweepAlpha / 100)
	end
	TextSizes(record)
	if cooling then
		record.readyPlayed = nil
	elseif record.dimmed and Opt("flash") then
		ns.EachPart(KEY, FLASH_PART, Flash, record)
	end
	record.dimmed = cooling
end

-- An item's start and duration in seconds, or nil when the game has no answer or withholds it.
local function ItemCooldown(itemID)
	local call = C_Item and C_Item.GetItemCooldown
	if type(call) ~= "function" then
		return nil
	end
	local ok, start, duration = pcall(call, itemID)
	if ok and Plain(start, "number") and Plain(duration, "number") then
		return start, duration
	end
	return nil
end

-- True while an item's cooldown runs, false when it is over, nil when the game does not say; then the
-- start and the duration.
local function ItemCooling(itemID)
	local start, duration = ItemCooldown(itemID)
	local now = Ask(GetTime)
	if start == nil or not Plain(now, "number") then
		return nil
	end
	return duration > 0 and start + duration > now, start, duration
end

-- A trinket: the sweep from the item's cooldown, and the same look as a spell's.
local function UpdateItem(record)
	local cooldown = record.cooldown
	local cooling, start, duration = ItemCooling(record.item)
	if cooling ~= nil then
		ns.ClearNote(KEY, NO_ITEM_SWEEP)
	end
	if cooling then
		cooldown:SetCooldown(start, duration)
	else
		cooldown:Clear()
		if cooling == nil then
			ns.Note(KEY, type(C_Item) == "table" and C_Item.GetItemCooldown and NO_ITEM_SWEEP or NO_TRINKETS)
		end
	end
	record.count:SetText("")
	Look(record, cooling == true, false, cooling == true)
end

-- Safe in combat: only the sweep, the dimming and the count change.
local function Update(record)
	if record.item then
		ns.EachPart(KEY, TRINKET_PART, UpdateItem, record)
		return
	end
	local spells = C_Spell
	if not (spells and spells.GetSpellCooldown) then
		return
	end
	local spellID, cooldown = record.spell, record.cooldown
	local ok, info = pcall(spells.GetSpellCooldown, spellID)
	if not ok then
		cooldown:Clear()
		error(info, 0)
	end
	if IsSecret(info) or type(info) ~= "table" then
		info = nil
	end
	-- The game never withholds these two. A withheld one goes to the texture as it is.
	local active = info and info.isActive
	local secret = IsSecret(active)
	local cooling = not secret and active == true and not IsTrue(info.isOnGCD)
	local charges = Ask(spells.GetSpellCharges, spellID)
	local maximum = type(charges) == "table" and charges.maxCharges
	local hasCharges = Plain(maximum, "number") and maximum > 1
	DrawSweep(record, info, cooling, hasCharges and not cooling and IsTrue(charges.isActive))
	if hasCharges then
		-- The count is text the game formats, handed on unread.
		local counted, text = pcall(spells.GetSpellDisplayCount, spellID)
		if counted and (IsSecret(text) or type(text) == "string") then
			record.count:SetText(text)
		else
			record.count:SetText("")
		end
	else
		record.count:SetText("")
	end
	Look(record, cooling, secret, active)
end

-- One sound when a dimmed icon's cooldown is over. The global cooldown does not count, and a cooldown
-- the game does not answer for plays nothing.
local function Ready(record)
	if not (record.dimmed and not record.readyPlayed and Opt("readySound")) then
		return
	end
	if record.item then
		if ItemCooling(record.item) ~= false then
			return
		end
	else
		local info = Ask(C_Spell and C_Spell.GetSpellCooldown, record.spell)
		if type(info) ~= "table" or (IsTrue(info.isActive) and not IsTrue(info.isOnGCD)) then
			return
		end
	end
	record.readyPlayed = true
	local kits = ns.TrackerKits
	local ok, played = pcall(PlaySound, kits and kits[ns.Get("trackers.kit")] or RAID_WARNING)
	if not ok or (not IsSecret(played) and played == false) then
		ns.Note(KEY, NO_SOUND)
	end
end

local function UpdateAll()
	for _, record in ipairs(shown) do
		ns.Each(KEY, Ready, record)
		ns.Each(KEY, Update, record)
	end
end

local function StillCooling(record)
	if record.item then
		return ItemCooling(record.item) == true
	end
	local info = Ask(C_Spell and C_Spell.GetSpellCooldown, record.spell)
	return type(info) == "table" and IsTrue(info.isActive) and not IsTrue(info.isOnGCD)
end

-- No event says a cooldown has ended, so the icons that are dimmed are looked at again. Only the
-- end of the cooldown changes what they show, and then they are updated in full.
local function Recheck()
	for _, record in ipairs(shown) do
		if record.dimmed and not StillCooling(record) then
			ns.Each(KEY, Ready, record)
			ns.Each(KEY, Update, record)
		end
	end
end

-- The cooldown manager ----------------------------------------------------------------------

local function ItemMask(item)
	local icon = item.Icon
	if icon and not IsSecret(icon) and icon.GetMaskTexture then
		local mask = Ask(icon.GetMaskTexture, icon, 1)
		if mask ~= nil then
			return mask
		end
	end
	return ns.RegionWithAtlas(item, ITEM_MASK)
end

-- Every SetPoint replaces the point of the same name, so no point is ever cleared.
local function Corners(part, anchor, inset)
	part:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -inset)
	part:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset, inset)
end

-- The icon of the manager is round: a mask, a thick overlay and a round sweep. The game sets the
-- icon's texture, colour and desaturation and the sweep's colour, and never the things changed here.
local function StyleItem(item, on)
	local icon = item.Icon
	local own = items[item]
	if not own then
		if not on or icon == nil or IsSecret(icon) then
			return
		end
		own = { outline = ns.Outline(item, icon), overlay = ns.RegionWithAtlas(item, ITEM_OVERLAY), mask = ItemMask(item) }
		items[item] = own
		ns.Count(KEY)
		if not own.overlay then
			ns.Note(KEY, "Cooldown manager icons: the default frame was not found and is still shown.")
		end
		if not own.mask then
			ns.Note(KEY, "Cooldown manager icons: the round mask was not found, so corners stay rounded.")
		end
	end
	if own.on == on then
		return
	end
	own.on = on
	ns.SetOutline(own.outline, on, false)
	ns.SetFaded(own.overlay, on)
	Corners(icon, item, on and INSET or 0)
	if on then
		icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	else
		icon:SetTexCoord(0, 1, 0, 1)
	end
	if own.mask then
		if on then
			pcall(icon.RemoveMaskTexture, icon, own.mask)
		else
			pcall(icon.AddMaskTexture, icon, own.mask)
		end
	end
	local anchor = on and icon or item
	local cooldown, range = item.Cooldown, item.OutOfRange
	if not ns.Forbidden(cooldown) then
		Corners(cooldown, anchor, 0)
		if cooldown.SetSwipeTexture then
			cooldown:SetSwipeTexture(on and SQUARE_SWEEP or ROUND_SWEEP)
		end
	end
	if range and not IsSecret(range) then
		Corners(range, anchor, 0)
	end
end

local function StyleViewer(viewer)
	local pool = viewer.itemFramePool
	if IsSecret(pool) or type(pool) ~= "table" or not pool.EnumerateActive then
		return
	end
	for item in pool:EnumerateActive() do
		local styled = items[item]
		if not ns.Forbidden(item) and not (styled and styled.on) then
			ns.EachPart(KEY, PART, StyleItem, item, true)
		end
	end
end

local function Viewer(name)
	local viewer = _G[name]
	if viewer ~= nil and not ns.Forbidden(viewer) then
		return viewer
	end
	return nil
end

local function HasViewer()
	for _, name in ipairs(VIEWERS) do
		if Viewer(name) then
			return true
		end
	end
	return false
end

-- False only while every viewer plainly says it is hidden. The icons of a viewer the game hides
-- are styled soon after it is shown.
local function ViewerShown()
	for _, name in ipairs(VIEWERS) do
		local viewer = Viewer(name)
		if viewer then
			local ok, visible = pcall(viewer.IsShown, viewer)
			if not ok or IsSecret(visible) or visible ~= false then
				return true
			end
		end
	end
	return false
end

-- New icons are found by looking, since a hook on the viewer would run inside code that handles
-- values the client withholds. Icons that are no longer wanted styled are put back, including
-- the ones the game has returned to its pool.
local function LookAtManager()
	local on = ns.Enabled(KEY) and Opt("manager") and not ns.PartStopped(KEY, PART)
	if on then
		for _, name in ipairs(VIEWERS) do
			local viewer = Viewer(name)
			if viewer then
				ns.EachPart(KEY, PART, StyleViewer, viewer)
			end
		end
		return
	end
	for item, styled in pairs(items) do
		if styled.on and not ns.Forbidden(item) then
			pcall(StyleItem, item, false)
		end
	end
end

local function QueueSweep()
	if sweepQueued then
		return
	end
	sweepQueued = true
	ns.OutOfCombat(function()
		sweepQueued = false
		if ns.IsStopped(KEY) then
			pcall(LookAtManager)
		else
			ns.Try(KEY, LookAtManager)
		end
	end)
end

-- The game handles the same events, so its icons are looked at on the next frame.
local function QueueSweepSoon()
	if next(items) ~= nil or HasViewer() then
		if C_Timer and C_Timer.After then
			C_Timer.After(0, QueueSweep)
		else
			QueueSweep()
		end
	end
end

-- The row ------------------------------------------------------------------------------------

local function OnUpdate(_, elapsed)
	sinceRecheck = sinceRecheck + elapsed
	sinceSweep = sinceSweep + elapsed
	if sinceRecheck >= RECHECK then
		sinceRecheck = 0
		ns.Try(KEY, Recheck)
	end
	if sinceSweep >= SWEEP then
		sinceSweep = 0
		if ns.Enabled(KEY) and Opt("manager") and ViewerShown() then
			QueueSweep()
		end
	end
end

local function Holder()
	if not holder then
		holder = CreateFrame("Frame", nil, UIParent)
		ns.Own[holder] = true
		holder:SetSize(1, 1)
		holder:SetScript("OnUpdate", OnUpdate)
	end
	return holder
end

local function Acquire(index)
	local record = icons[index]
	if record then
		return record
	end
	local frame = CreateFrame("Frame", nil, holder)
	ns.Own[frame] = true
	local texture = frame:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[texture] = true
	texture:SetAllPoints(frame)
	local crop = Crop()
	texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	-- A plain square sweep: the template's has no file, and no edge line or flash is drawn.
	local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	ns.Own[cooldown] = true
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	local sweepAlpha = Opt("sweepAlpha")
	cooldown:SetSwipeColor(0, 0, 0, sweepAlpha / 100)
	-- The count sits on a frame above the sweep.
	local top = CreateFrame("Frame", nil, frame)
	ns.Own[top] = true
	top:SetAllPoints(frame)
	top:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	local count = top:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	ns.Own[count] = true
	count:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", -2, 2)
	record = { frame = frame, texture = texture, cooldown = cooldown, count = count, top = top, outline = ns.Outline(frame, frame),
		sweep = true, sweepAlpha = sweepAlpha }
	-- The game says when a cooldown has ended through this script and no event.
	cooldown:SetScript("OnCooldownDone", function()
		if ns.Enabled(KEY) then
			ns.Each(KEY, Ready, record)
			ns.Each(KEY, Update, record)
		end
	end)
	icons[index] = record
	ns.Count(KEY)
	return record
end

-- The lowest bar of the personal resource display that is shown. The display is as high as its bars
-- and the space the game leaves between them, which joined bars do without.
local function LowestBar(display)
	for _, key in ipairs(RESOURCE_BARS) do
		local bar = Field(display, key)
		if not ns.Forbidden(bar) and Ask(bar.IsShown, bar) == true then
			return bar
		end
	end
	return display
end

-- At the spot set with the movers, else under the personal resource display, or in the middle of the
-- screen when that is missing, forbidden or has no position.
local function Place()
	local x, y = Opt("x"), Opt("y")
	local spotX, spotY = ns.MoverSpot(MOVER, "CENTER")
	if spotX then
		ns.ClearNote(KEY, NO_POSITION)
		holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", spotX, spotY)
		return
	end
	local anchored = false
	if Opt("place") == "resource" then
		local display = PersonalResourceDisplayFrame
		if display ~= nil and not ns.Forbidden(display) then
			-- Under the bars, the row hangs from the Your buffs row when that is there.
			local over = type(ns.OwnBuffsHolder) == "function" and ns.OwnBuffsHolder("below") or nil
			if over then
				holder:SetPoint("CENTER", over, "BOTTOM", x, y - GAP)
			else
				holder:SetPoint("CENTER", LowestBar(display), "BOTTOM", x, y - GAP)
			end
			-- A frame anchored to one that has no position has no rectangle either. A client
			-- that cannot say is taken to have one.
			local ok, left = pcall(holder.GetLeft, holder)
			anchored = not ok or IsSecret(left) or left ~= nil
		end
		if anchored then
			ns.ClearNote(KEY, NO_POSITION)
		else
			ns.Note(KEY, NO_POSITION)
		end
	else
		ns.ClearNote(KEY, NO_POSITION)
	end
	if not anchored then
		holder:SetPoint("CENTER", UIParent, "CENTER", x, y + SCREEN_Y)
	end
end

local function SpellIcon(spellID)
	local file = Ask(C_Spell and C_Spell.GetSpellTexture, spellID)
	if Plain(file, "number") or Plain(file, "string") then
		return file
	end
	return UNKNOWN_ICON
end

-- A row that is wanted and a call the game lacks: the status says so. Only what needs the call
-- is switched off.
local function CheckGame()
	if not (C_Spell and C_Spell.GetSpellCooldown) then
		ns.Note(KEY, NO_COOLDOWNS)
	end
end

-- The icon of an item.
local function ItemIcon(itemID)
	local file = Ask(C_Item and C_Item.GetItemIconByID, itemID)
	if Plain(file, "number") or Plain(file, "string") then
		return file
	end
	return UNKNOWN_ICON
end

-- The item IDs of the equipped trinkets, in slot order, when the row is to show them.
local function Trinkets()
	local list = {}
	if not Opt("trinkets") or ns.PartStopped(KEY, TRINKET_PART) then
		return list
	end
	if type(GetInventoryItemID) ~= "function" then
		ns.Note(KEY, NO_TRINKETS)
		return list
	end
	ns.ClearNote(KEY, NO_TRINKETS)
	for _, slot in ipairs(TRINKET_SLOTS) do
		local id = Ask(GetInventoryItemID, "player", slot)
		if Whole(id) then
			list[#list + 1] = id
		end
	end
	return list
end

-- The row's opacity out of combat.
local function Idle()
	if holder then
		holder:SetAlpha(not fighting and Opt("idleAlpha") / 100 or 1)
	end
end

-- The key bound to the first action bar button that holds a spell, as the game writes it on its own buttons
-- (ActionButton.lua:498-501), or nothing.
local function BindingText(spellID)
	local slots = Ask(C_ActionBar and C_ActionBar.FindSpellActionButtons, spellID)
	if type(slots) ~= "table" then
		return ""
	end
	for _, slot in ipairs(slots) do
		for _, bar in ipairs(BAR_SLOTS) do
			if Plain(slot, "number") and slot >= bar[1] and slot < bar[1] + 12 then
				local key = Ask(GetBindingKey, bar[2] .. (slot - bar[1] + 1))
				local text = Plain(key, "string") and Ask(GetBindingText, key, 1)
				if Plain(text, "string") and text ~= "" then
					return text
				end
			end
		end
	end
	return ""
end

local function Keybind(record)
	if not Opt("keybind") or not record.spell then
		if record.bind then
			record.bind:SetText("")
		end
		return
	end
	if not (C_ActionBar and C_ActionBar.FindSpellActionButtons and GetBindingKey and GetBindingText) then
		ns.Note(KEY, NO_BINDS)
		return
	end
	if record.bind == nil then
		local bind = record.top:CreateFontString(nil, "OVERLAY", KEYBIND_FONT)
		ns.Own[bind] = true
		bind:SetPoint("TOPRIGHT", record.top, "TOPRIGHT", -2, -2)
		record.bind = bind
	end
	record.bind:SetText(BindingText(record.spell))
	TextSizes(record)
end

-- The keys on the icons, from the bindings and the action bars. Nothing on an icon once the part has stopped.
local function Binds()
	local stopped = ns.PartStopped(KEY, BIND_PART)
	for _, record in ipairs(shown) do
		if not stopped then
			ns.EachPart(KEY, BIND_PART, Keybind, record)
		elseif record.bind then
			pcall(record.bind.SetText, record.bind, "")
		end
	end
end

-- Runs out of combat. The row hangs from the middle of the holder; icon i of a row of k icons is
-- a step of size plus spacing from the one before it.
local function Layout()
	local on = ns.Enabled(KEY)
	local spells = on and Spells() or {}
	local entries = {}
	for _, id in ipairs(spells) do
		entries[#entries + 1] = { spell = id }
	end
	for _, id in ipairs(on and Trinkets() or {}) do
		entries[#entries + 1] = { item = id }
	end
	if #entries == 0 then
		ns.ClearNote(KEY, NO_POSITION)
	end
	if #entries == 0 and not (on and Opt("manager") and HasViewer()) then
		if holder then
			holder:Hide()
		end
		shown = {}
		for _, record in ipairs(icons) do
			record.dimmed, record.readyPlayed = nil, nil
		end
		return
	end
	Holder():Show()
	if #spells > 0 then
		CheckGame()
	end
	if #entries > 0 then
		Place()
	end
	Idle()
	local size, spacing, perRow = Opt("size"), Opt("spacing"), Opt("perRow")
	local step, grow, above = size + spacing, Opt("grow"), Opt("rows") == "up"
	shown = {}
	local crop = Crop()
	for index, entry in ipairs(entries) do
		local record = Acquire(index)
		if record.spell ~= entry.spell or record.item ~= entry.item then
			record.dimmed, record.readyPlayed = nil, nil
		end
		record.spell, record.item = entry.spell, entry.item
		record.texture:SetTexture(entry.spell and SpellIcon(entry.spell) or ItemIcon(entry.item))
		record.texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		local frame = record.frame
		frame:SetSize(size, size)
		local row, column = math.floor((index - 1) / perRow), (index - 1) % perRow
		local inRow = math.min(perRow, #entries - row * perRow)
		local x
		if grow == "right" then
			x = column * step
		elseif grow == "left" then
			x = -size - column * step
		else
			x = -(inRow * size + (inRow - 1) * spacing) / 2 + column * step
		end
		frame:ClearAllPoints()
		if above then
			frame:SetPoint("BOTTOMLEFT", holder, "CENTER", x, row * step)
		else
			frame:SetPoint("TOPLEFT", holder, "CENTER", x, -row * step)
		end
		frame:Show()
		shown[#shown + 1] = record
	end
	for index = #entries + 1, #icons do
		icons[index].frame:Hide()
	end
	UpdateAll()
	Binds()
end

-- One layout at a time, when combat allows.
local function QueueLayout()
	if layoutQueued then
		return
	end
	layoutQueued = true
	ns.OutOfCombat(function()
		layoutQueued = false
		if ns.IsStopped(KEY) then
			pcall(Layout)
		else
			ns.Try(KEY, Layout)
		end
	end)
end

-- The frames of the icons on the row and the frame they hang from, for the handle of the movers.
-- Nothing while the page is off.
function ns.CooldownRow()
	local frames = {}
	if holder and ns.Enabled(KEY) then
		for _, record in ipairs(shown) do
			frames[#frames + 1] = record.frame
		end
	end
	return frames, holder
end

-- The movers set or put back the spot of the row.
function ns.CooldownsMoved()
	QueueLayout()
end

-- Picking spells ----------------------------------------------------------------------------

-- Lines with the same name get the rank or other text the game shows beside the name.
local function Distinguish(rows)
	local seen = {}
	for _, row in ipairs(rows) do
		seen[row[2]] = (seen[row[2]] or 0) + 1
	end
	for _, row in ipairs(rows) do
		if seen[row[2]] > 1 then
			local subtext = Ask(C_Spell and C_Spell.GetSpellSubtext, row[1])
			if Plain(subtext, "string") and subtext ~= "" then
				row[2] = row[2] .. " (" .. subtext .. ")"
			end
		end
	end
end

-- The known, active, highest rank spells that have a cooldown and are not picked yet, by name.
function ns.CooldownCandidates()
	local rows = {}
	local book = SpellBook()
	if not book then
		-- The list is empty, so the status says why. With the page off the list cannot be opened.
		if ns.Enabled(KEY) then
			ns.Note(KEY, NO_BOOK)
		end
		return rows
	end
	local bank, spellType = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType.Spell
	local listed, named = {}, {}
	for _, id in ipairs(List()) do
		listed[id] = true
		-- A rank trained since has another ID and the same name. A spell not known has no icon on
		-- the row, so its name keeps nothing out.
		if Known(id) then
			named[Name(id)] = true
		end
	end
	local lines = Ask(book.GetNumSpellBookSkillLines)
	for line = 1, Plain(lines, "number") and lines or 0 do
		local skill = Ask(book.GetSpellBookSkillLineInfo, line)
		if type(skill) == "table" and skill.shouldHide ~= true and skill.offSpecID == nil
			and Plain(skill.itemIndexOffset, "number") and Plain(skill.numSpellBookItems, "number") then
			for slot = skill.itemIndexOffset + 1, skill.itemIndexOffset + skill.numSpellBookItems do
				local item = Ask(book.GetSpellBookItemInfo, slot, bank)
				if type(item) == "table" and item.itemType == spellType and item.isPassive ~= true and item.isOffSpec ~= true then
					local id = item.spellID or item.actionID
					if Whole(id) and not listed[id] and Ask(book.IsSpellBookItemLowRank, slot, bank) ~= true and HasCooldown(id) then
						local label = Plain(item.name, "string") and item.name ~= "" and item.name or Name(id)
						if not named[label] then
							listed[id] = true
							rows[#rows + 1] = { id, label }
						end
					end
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
	Distinguish(rows)
	return rows
end

-- The picked spells in row order, so opening the list also shows what is picked.
function ns.CooldownPicked()
	local rows = {}
	for _, id in ipairs(List()) do
		rows[#rows + 1] = { id, Name(id) }
	end
	Distinguish(rows)
	for _, row in ipairs(rows) do
		if not Known(row[1]) then
			row[2] = row[2] .. " (not known)"
		end
	end
	return rows
end

-- Both work in combat and with the page off, since they change what is saved and nothing on screen.
function ns.CooldownAdd(spellID)
	if not (Whole(spellID) and SpellName(spellID)) then
		return false, ('No spell found for "%s".'):format(tostring(spellID))
	end
	local list = List()
	for _, id in ipairs(list) do
		if id == spellID then
			return false, ("%s is already picked."):format(Name(spellID))
		end
	end
	if #list >= MAX_SPELLS then
		return false, ("%d spells is the most."):format(MAX_SPELLS)
	end
	list[#list + 1] = spellID
	QueueLayout()
	return true, ("Added %s."):format(Name(spellID))
end

function ns.CooldownRemove(spellID)
	local list = List()
	for index, id in ipairs(list) do
		if id == spellID then
			table.remove(list, index)
			QueueLayout()
			return true, ("Removed %s."):format(Name(spellID))
		end
	end
	return false, ("%s is not picked."):format(Name(spellID))
end

local function Slash(rest)
	local word, text = rest:match("^(%S*)%s*(.-)$")
	word = word:lower()
	if (word == "add" or word == "remove") and text ~= "" then
		-- A picked spell can be removed by its ID even when the game no longer has a name for it.
		local id = (word == "remove" and Parse(text)) or Resolve(text)
		if not id then
			print(('No spell found for "%s".'):format(text))
			return
		end
		local _, message = (word == "add" and ns.CooldownAdd or ns.CooldownRemove)(id)
		print(message)
	elseif word == "list" then
		local list = List()
		if #list == 0 then
			print("No spells picked.")
		end
		for index, id in ipairs(list) do
			print(("%d. %s (%d)%s"):format(index, Name(id), id, Known(id) and "" or ", not known"))
		end
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

local function Refresh()
	-- The row goes at once when the page is switched off in combat and comes back at once when it
	-- is switched on; the layout waits.
	if holder and not ns.Enabled(KEY) then
		holder:Hide()
	elseif holder and shown[1] then
		holder:Show()
	end
	fighting = InCombatLockdown() == true
	Idle()
	QueueLayout()
	QueueSweep()
	UpdateAll()
	Binds()
end

local function UpdateItems()
	for _, record in ipairs(shown) do
		if record.item then
			ns.Each(KEY, Ready, record)
			ns.Each(KEY, Update, record)
		end
	end
end

-- A spell learned or lost, a new talent set or a new login changes the row, and the game lays
-- its own icons out again.
local function Changed()
	QueueLayout()
	QueueSweepSoon()
end

ns.Register(KEY, {
	label = "Cooldowns",
	Start = Refresh,
	Refresh = Refresh,
	Resized = QueueLayout,
	events = {
		SPELL_UPDATE_COOLDOWN = UpdateAll,
		SPELL_UPDATE_CHARGES = UpdateAll,
		BAG_UPDATE_COOLDOWN = UpdateItems,
		PLAYER_EQUIPMENT_CHANGED = QueueLayout,
		UPDATE_BINDINGS = Binds,
		ACTIONBAR_SLOT_CHANGED = Binds,
		PLAYER_REGEN_DISABLED = function()
			fighting = true
			Idle()
		end,
		PLAYER_REGEN_ENABLED = function()
			fighting = false
			Idle()
		end,
		SPELLS_CHANGED = Changed,
		PLAYER_TALENT_UPDATE = Changed,
		ACTIVE_TALENT_GROUP_CHANGED = Changed,
		PLAYER_ENTERING_WORLD = Changed,
		COOLDOWN_VIEWER_DATA_LOADED = QueueSweepSoon,
		EDIT_MODE_LAYOUTS_UPDATED = QueueSweepSoon,
	},
	slash = { cooldown = Slash },
	help = HELP,
})
