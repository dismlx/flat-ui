local _, ns = ...

local I = {}

local CROP = 0.08
local FLASH = 0.5
local SOUND_GAP = 1
local NO_SOUND = "%s: the game plays no sound, so there is the flash only."
local IsSecret = ns.IsSecret

ns.SOUNDS = {
	{ 23287, "Spell alert" },
	{ 316736, "Chimes" },
	{ 316773, "Bell" },
	{ 316723, "Warhorn" },
	{ 8959, "Raid warning" },
	{ 12889, "Alarm" },
	{ 37666, "Whisper warning" },
}

local COUNT_FONTS = { small = "NumberFontNormalSmall", normal = "NumberFontNormal", large = "NumberFontNormalLarge", huge = "NumberFontNormalHuge" }

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

I.fontHeights = {}
function ns.IconFontHeight(name, fallback)
	local height = I.fontHeights[name]
	if height == nil then
		local font = _G[name]
		local ok, _, read = false, nil, nil
		if type(font) == "table" and type(font.GetFont) == "function" then
			ok, _, read = pcall(font.GetFont, font)
		end
		height = ok and ns.Finite(read) and read > 0 and read or fallback
		I.fontHeights[name] = height
	end
	return height
end

function ns.IconNumberHeight(height, size, base)
	if not (ns.Finite(height) and ns.Finite(size) and ns.Finite(base) and base > 0) then
		return height
	end
	return math.max(8, math.min(24, math.floor(height * size / base + 0.5)))
end

function ns.IconCountdownHeight(icon, size, base)
	local cooldown = icon and icon.cooldown
	if not cooldown then
		return
	end
	local ok, text = pcall(cooldown.GetCountdownFontString, cooldown)
	if not ok or IsSecret(text) or type(text) ~= "table" then
		return
	end
	if icon.cdBase == nil then
		local read, _, height = pcall(text.GetFont, text)
		icon.cdBase = read and ns.Finite(height) and height > 0 and height or false
	end
	local height = icon.cdBase and ns.IconNumberHeight(icon.cdBase, size, base)
	if height then
		pcall(text.SetTextHeight, text, height)
	end
end

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

local SAMPLES = { { 135940, 3 }, { 135964, 3 }, { 136089, 3 } }

function ns.KindColour(kind)
	local colour = type(kind) == "number" and not IsSecret(kind) and COLOURS[kind]
	if colour then
		return colour[1], colour[2], colour[3]
	end
end

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
	cooldown:SetScript("OnCooldownDone", function()
		I.Done(icon)
	end)
	frame:Hide()
	return icon
end

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
	ns.SetOutline(icon.outline, look.border ~= false, look.border ~= false)
	icon.frame:Show()
	return true
end

function ns.IconClear(icon)
	pcall(icon.cooldown.Clear, icon.cooldown)
	icon.frame:Hide()
end

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

function ns.IconExtent(count, size, spacing, extra)
	local width = count > 0 and (count * size + (count - 1) * spacing) or 0
	return width, size + (extra or 0)
end

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
			pcall(made.SetToFinalAlpha, made, true)
			made:SetScript("OnFinished", function()
				flash:Hide()
				flash:SetAlpha(1)
			end)
			return made
		end)
		icon.flashGroup = ok and group or false
	end
	local group = icon.flashGroup
	if group and group:IsPlaying() then
		pcall(group.Stop, group)
	end
	flash:SetAlpha(1)
	flash:Show()
	local playing = group and pcall(group.Play, group) or false
	icon.flashes = (icon.flashes or 0) + 1
	local mine = icon.flashes
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(playing and FLASH + 0.1 or FLASH, function()
			if icon.flashes == mine and not (group and group:IsPlaying()) then
				flash:Hide()
				flash:SetAlpha(1)
			end
		end)
	end
end

local FAINT, FAINT_WAIT, FAINT_TIME, FAINT_STEPS = 0.3, 1, 0.25, 5

function ns.IconFader(list, held)
	local fader = { alpha = 1 }
	local function Set(alpha)
		fader.alpha = alpha
		for _, entry in ipairs(list()) do
			if entry.frame then
				entry.frame:SetAlpha(alpha)
			end
		end
	end
	local function Stop()
		fader.token = nil
		local ticker = fader.ticker
		fader.ticker = nil
		if ticker and type(ticker.Cancel) == "function" then
			pcall(ticker.Cancel, ticker)
		end
	end
	function fader.Wake()
		Stop()
		if fader.alpha ~= 1 then
			Set(1)
		end
	end
	function fader.Settle()
		if held() then
			fader.Wake()
		elseif not fader.token and fader.alpha ~= FAINT then
			Set(FAINT)
		end
	end
	function fader.Faint()
		Stop()
		if held() then
			fader.Wake()
			return
		end
		local token = {}
		fader.token = token
		local function Fall()
			if fader.token ~= token then
				return
			elseif held() then
				fader.Wake()
				return
			end
			local from, step = fader.alpha, 0
			local function Step()
				if fader.token ~= token then
					return
				end
				step = step + 1
				if step >= FAINT_STEPS then
					Stop()
					Set(FAINT)
				else
					Set(from + (FAINT - from) * step / FAINT_STEPS)
				end
			end
			local ok, ticker = false, nil
			if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
				ok, ticker = pcall(C_Timer.NewTicker, FAINT_TIME / FAINT_STEPS, Step, FAINT_STEPS)
			end
			if ok and ticker then
				fader.ticker = ticker
			else
				Stop()
				Set(FAINT)
			end
		end
		if not (type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, FAINT_WAIT, Fall)) then
			Fall()
		end
	end
	return fader
end

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

function ns.IconSample(icon, index, start, seconds, key, look)
	local sample = SAMPLES[index]
	if not sample then
		return false
	end
	local flash, sound = true, ns.SOUNDS[1][1]
	if type(look) == "table" then
		flash = look.flash ~= false
		if look.sound == false then
			sound = nil
		elseif type(look.sound) == "number" then
			sound = look.sound
		end
	end
	return ns.IconSet(icon, sample[1], start, seconds, { kind = sample[2], flash = flash, sound = sound, key = key })
end

function ns.IconSamplePicture(index)
	local sample = SAMPLES[index]
	return sample and sample[1] or nil
end

local HELD = { 6, 10, 15 }

local function Copy(look)
	local copy = {}
	for key, value in pairs(look or {}) do
		copy[key] = value
	end
	return copy
end

function ns.IconSampleHeld(icon, index, key, look, texture, seconds)
	local sample = SAMPLES[index]
	if not sample then
		return false
	end
	look = Copy(look or { kind = sample[2] })
	if look.kind == true then
		look.kind = sample[2]
	end
	local quiet = look.sound == false
	local kit = type(look.sound) == "number" and look.sound or ns.SOUNDS[1][1]
	look.flash, look.key, look.sound = look.flash ~= false, key, nil
	local file = texture or sample[1]
	local held = icon.held
	if held and held.index == index and held.file == file and icon.frame:IsShown() then
		held.look = look
		local kept = Copy(look)
		kept.sound = held.kit
		return ns.IconSet(icon, file, nil, nil, kept)
	end
	local length = type(seconds) == "number" and not IsSecret(seconds) and seconds > 0 and seconds or HELD[index]
	local now = type(GetTime) == "function" and GetTime() or 0
	held = { index = index, file = file, seconds = length, ends = now + length, look = look }
	icon.held = held
	local first = Copy(look)
	local test = ns.TestMode
	if key and not quiet and type(test) == "table" and test.Sound(key .. ".sample") then
		held.kit = kit
		first.sound = held.kit
	end
	return ns.IconSet(icon, file, now, length, first)
end

function ns.IconSampleLoop(list, now)
	for _, icon in ipairs(list or {}) do
		local held = icon.held
		if held and now >= held.ends and icon.frame:IsShown() then
			held.ends, held.kit = now + held.seconds, nil
			ns.IconSet(icon, nil, now, held.seconds, held.look)
		end
	end
end

function ns.IconSampleDrop(icon)
	if not icon.held then
		return false
	end
	icon.held = nil
	ns.IconClear(icon)
	return true
end

ns.IconRow = I
