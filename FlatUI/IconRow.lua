local _, ns = ...

-- A row of flat square icons with a sweep, for the modules that show cooldowns and buffs: the icon, its sweep, its border, a
-- flash and a sound when the sweep ends. This file is no module of its own. An icon is made as Cooldowns.lua makes one (three
-- frames and six textures, all in ns.Own), without a count. A number of seconds goes to the sweep as a start and a length; a
-- duration object goes to the sweep and is never read, compared or kept as a key.

local I = {}

local CROP = 0.08
local FLASH = 0.5
local SOUND_GAP = 1
local NO_SOUND = "%s: the game plays no sound, so there is the flash only."
local IsSecret = ns.IsSecret

-- The sounds the modules offer, in the order of their pickers: the sound kit and its name.
ns.SOUNDS = {
	{ 23287, "Spell alert" },
	{ 316736, "Chimes" },
	{ 316773, "Bell" },
	{ 316723, "Warhorn" },
	{ 8959, "Raid warning" },
	{ 12889, "Alarm" },
	{ 37666, "Whisper warning" },
}

-- The fonts of the Countdown number size choices (game is the font the game draws with).
local COUNT_FONTS = { small = "NumberFontNormalSmall", normal = "NumberFontNormal", large = "NumberFontNormalLarge", huge = "NumberFontNormalHuge" }

-- Sets the font of the countdown numbers of an icon (a table with a cooldown, or any table with the Cooldown frame as `frame`) to a choice of Countdown number size. The game's font is read once,
-- before the first change, and game puts it back.
function ns.IconCountdownFont(icon, choice, frame)
	local name, cooldown = COUNT_FONTS[choice], frame or icon.cooldown
	if icon.cdFont == name then
		return
	end
	local ok, text = pcall(cooldown.GetCountdownFontString, cooldown)
	text = ok and not IsSecret(text) and type(text) == "table" and text or nil
	if name then
		if icon.cdGame == nil and text then
			local read, file, size, flags = pcall(text.GetFont, text)
			icon.cdGame = read and not IsSecret(file) and type(file) == "string" and { file, size, flags or "" } or false
		end
		if pcall(cooldown.SetCountdownFont, cooldown, name) then
			icon.cdFont = name
		end
	else
		icon.cdFont = nil
		if icon.cdGame and text then
			pcall(text.SetFont, text, icon.cdGame[1], icon.cdGame[2], icon.cdGame[3])
		end
	end
end

-- Sound settings of an older build become the one list of sounds. t holds saved values by path. Sound when ready was on or off and played
-- Sound of Trackers. When it is ready again was none, flash or sound, with Ready sound (alert and horn are now spell and warhorn). With
-- legacy true, a Ready sound saved without the old row was never played and becomes none.
local RENAMED = { alert = "spell", horn = "warhorn" }
function ns.MigrateSounds(t, legacy)
	local ready, sound, own = t["enemycd.ready"], t["enemycd.sound"], t["cooldowns.readySound"]
	if type(own) == "boolean" then
		t["cooldowns.readySound"] = own and (t["trackers.kit"] or "raid") or "none"
	end
	if ready ~= nil then
		t["enemycd.flash"] = ready ~= "none"
		sound = sound or "alert"
		t["enemycd.sound"] = ready == "sound" and (RENAMED[sound] or sound) or "none"
		t["enemycd.ready"] = nil
	elseif sound ~= nil and legacy then
		t["enemycd.sound"] = "none"
	end
end

-- The colour of the border of each kind of ability (CooldownData.lua: ns.COOLDOWN_KINDS). Crowd control shares the violet of its breaks.
local COLOURS = {
	{ 1, 0.65, 0.1 },
	{ 0.3, 0.6, 1 },
	{ 0.2, 0.85, 0.8 },
	{ 0.65, 0.45, 1 },
	{ 0.65, 0.45, 1 },
	{ 1, 1, 1 },
	{ 0.4, 0.9, 0.4 },
	{ 1, 0.3, 0.3 },
	{ 1, 0.84, 0.3 },
}

-- The icons and times of the three samples that /flatui test shows.
local SAMPLES = { { 135940, 3 }, { 135964, 3 }, { 136089, 3 } }

-- The red, green and blue of a kind (1 to 9), or nothing for any other value.
function ns.KindColour(kind)
	local colour = type(kind) == "number" and not IsSecret(kind) and COLOURS[kind]
	if colour then
		return colour[1], colour[2], colour[3]
	end
end

-- True when a frame may be made on this parent now. In combat only a frame of this addon's own or UIParent is safe.
function I.CanMake(parent)
	if not InCombatLockdown() then
		return true
	end
	if parent == UIParent or ns.Own[parent] then
		return true
	end
	local ok, protected = pcall(parent.IsProtected, parent)
	return ok and not IsSecret(protected) and protected == false
end

local function Own(object)
	ns.Own[object] = true
	return object
end

-- A new icon on `parent`, or nil when the game would not allow it now. Its frame is hidden until IconSet.
function ns.IconNew(parent)
	if type(parent) ~= "table" or not I.CanMake(parent) then
		return nil
	end
	local frame = Own(CreateFrame("Frame", nil, parent))
	local texture = Own(frame:CreateTexture(nil, "ARTWORK", nil, 0))
	texture:SetAllPoints(frame)
	texture:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	local cooldown = Own(CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate"))
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetSwipeColor(0, 0, 0, 0.7)
	local icon = { frame = frame, texture = texture, cooldown = cooldown, outline = ns.Outline(frame, frame), done = 0 }
	-- The game says when a sweep has ended through this script and no event.
	cooldown:SetScript("OnCooldownDone", function()
		I.Done(icon)
	end)
	frame:Hide()
	return icon
end

-- The sweep of an icon has ended: the flash and the sound its look asks for, then its own callback.
function I.Done(icon)
	icon.done = icon.done + 1
	local look = icon.look or {}
	if look.flash then
		ns.IconFlash(icon)
	end
	if look.sound then
		ns.PlayKit(look.sound, look.key)
	end
	if type(icon.onDone) == "function" then
		pcall(icon.onDone, icon)
	end
end

-- Puts a picture and a sweep on an icon and shows it. texture: a file or a number. seconds: a number of seconds that starts at
-- `start`, or a duration object (then start is not used). look: { numbers = false hides the countdown numbers, font = a Countdown number
-- size choice, kind = 1 to 9 for the colour of the border, flash and sound for the end of the sweep, key the module a note goes to }.
function ns.IconSet(icon, texture, start, seconds, look)
	look = look or {}
	icon.look = look
	if texture ~= nil then
		icon.texture:SetTexture(texture)
	end
	local cooldown = icon.cooldown
	pcall(cooldown.SetHideCountdownNumbers, cooldown, look.numbers == false)
	if look.font ~= nil then
		ns.IconCountdownFont(icon, look.font)
	end
	if type(start) == "number" and not IsSecret(start) and type(seconds) == "number" and not IsSecret(seconds) then
		pcall(cooldown.SetCooldown, cooldown, start, seconds)
	elseif seconds ~= nil then
		pcall(cooldown.SetCooldownFromDurationObject, cooldown, seconds)
	end
	ns.SetOutlineColour(icon.outline, ns.KindColour(look.kind))
	icon.frame:Show()
	return true
end

-- Takes the sweep and the icon away.
function ns.IconClear(icon)
	pcall(icon.cooldown.Clear, icon.cooldown)
	icon.frame:Hide()
end

-- Puts icons in a row from the holder: direction "right" grows to the right from its bottom left corner, "left" to the left from
-- its bottom right corner, "center" both ways from the middle of its bottom edge. Returns the width of the row.
function ns.IconLayout(list, holder, size, spacing, direction)
	local count = #list
	local width = count > 0 and (count * size + (count - 1) * spacing) or 0
	for index, icon in ipairs(list) do
		local step = (index - 1) * (size + spacing)
		icon.frame:SetSize(size, size)
		icon.frame:ClearAllPoints()
		if direction == "left" then
			icon.frame:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -step, 0)
		elseif direction == "center" then
			icon.frame:SetPoint("BOTTOMLEFT", holder, "BOTTOM", step - width / 2, 0)
		else
			icon.frame:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", step, 0)
		end
	end
	return width
end

-- The box of `count` icons, and `extra` more units of height, for a handle that is drawn with no icon shown.
function ns.IconExtent(count, size, spacing, extra)
	local width = count > 0 and (count * size + (count - 1) * spacing) or 0
	return width, size + (extra or 0)
end

-- The flash: a white square over the icon that fades in half a second. Made with the first flash.
function ns.IconFlash(icon)
	local flash = icon.flash
	if not flash then
		flash = Own(icon.frame:CreateTexture(nil, "OVERLAY", nil, 6))
		flash:SetAllPoints(icon.frame)
		flash:SetColorTexture(1, 1, 1, 0.6)
		icon.flash = flash
		local ok, group = pcall(function()
			local made = flash:CreateAnimationGroup()
			local alpha = made:CreateAnimation("Alpha")
			alpha:SetFromAlpha(1)
			alpha:SetToAlpha(0)
			alpha:SetDuration(FLASH)
			return made
		end)
		icon.flashGroup = ok and group or false
	end
	flash:Show()
	if icon.flashGroup then
		pcall(icon.flashGroup.Play, icon.flashGroup)
	end
	icon.flashes = (icon.flashes or 0) + 1
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(FLASH, function()
			flash:Hide()
		end)
	end
end

-- Plays a sound kit, at most once a second. True when the game said it will play. A client without PlaySound, or a call that
-- fails, gives false and one note on the module `key`.
local lastPlay
I.sound = nil
function ns.PlayKit(id, key)
	local now = type(GetTime) == "function" and GetTime() or nil
	if now and lastPlay and now - lastPlay < SOUND_GAP and now >= lastPlay then
		I.sound = "throttled"
		return false
	end
	local ok, played
	if type(PlaySound) == "function" then
		ok, played = pcall(PlaySound, id)
	end
	if not ok or played ~= true then
		I.sound = ok == nil and "missing" or (ok and "refused" or "failed")
		local module = key and ns.modules[key]
		if module then
			ns.Note(key, NO_SOUND:format(module.label))
		end
		return false
	end
	lastPlay, I.sound = now, "played"
	return true
end

-- Puts sample `index` (1 to 3) on an icon, with a flash and a sound at the end of its sweep.
function ns.IconSample(icon, index, start, seconds, key)
	local sample = SAMPLES[index]
	if not sample then
		return false
	end
	return ns.IconSet(icon, sample[1], start, seconds, { kind = sample[2], flash = true, sound = ns.SOUNDS[1][1], key = key })
end

ns.IconRow = I
