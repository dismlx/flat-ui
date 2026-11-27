local ADDON_NAME, ns = ...

local TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Ring.tga"
local MODES = { always = true, combat = true, shake = true }
local FIGHT_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }
local CHANNEL = { UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true }
local ENDED = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true }
local COOLDOWN_EVENT = "SPELL_UPDATE_COOLDOWN"
local GCD_SPELL = 61304
local GCD_SHARE = 0.8
local MOST_REFUSED = 3
local FADE_IN, FADE_OUT = 0.15, 0.3
local SHAKE_STEP, SHAKE_TURNS, SHAKE_WINDOW, SHAKE_HOLD = 8, 4, 0.5, 0.6
local GROW, GROW_UP, GROW_END = 1.5, 0.15, 0.6
local PREVIEW = 1.2
local PREVIEW_ROWS = { ["general.cursorRing"] = true, ["general.cursorRingSize"] = true, ["general.cursorRingColour"] = true,
	["general.cursorRingClass"] = true }
local SWIPE_ROWS = { ["general.cursorRingCast"] = true, ["general.cursorRingCastColour"] = true, ["general.cursorRingGcd"] = true,
	["general.cursorRingGcdColour"] = true }
local SWIPE_PREVIEW = 2.6

local ring
local art
local listener
local fighting = false
local lastX, lastY, lastScale
local fade
local fadeAlpha, looking, shownAlpha = 1, false, nil
local broken
local swipes, refused = {}, { cast = 0, gcd = 0 }
local hearer
local hearing = { cast = false, gcd = false }
local gcdExists
local stopped
local shake = { turns = {} }
local grow
local grownScale = 1
local previewUntil

local function Mode()
	local mode = ns.Get("general.cursorRing")
	return MODES[mode] and mode or nil
end

local function InFight()
	if type(UnitAffectingCombat) == "function" then
		local ok, value = pcall(UnitAffectingCombat, "player")
		if ok and not ns.IsSecret(value) and type(value) == "boolean" then
			return value
		end
	end
	return InCombatLockdown() == true
end

local function Testing()
	local test = ns.TestMode
	return test ~= nil and test.IsOn() == true
end

local function Previewing()
	if previewUntil == nil then
		return false
	end
	local now = GetTime()
	return ns.Finite(now) and now < previewUntil
end

local function Wanted()
	local mode = Mode()
	if broken or mode == nil then
		return false
	end
	return mode == "always" or mode == "shake" or fighting or Testing() or Previewing()
end

local function Unseen()
	return Mode() == "shake" and not Testing() and not Previewing()
end

local function Follow(frame)
	if type(GetCursorPosition) ~= "function" then
		return
	end
	local read, x, y = pcall(GetCursorPosition)
	local ok, scale = pcall(frame.GetEffectiveScale, frame)
	if not (read and ns.Finite(x) and ns.Finite(y) and ok and ns.Finite(scale)) or scale <= 0 then
		return
	end
	if x == lastX and y == lastY and scale == lastScale then
		return
	end
	lastX, lastY, lastScale = x, y, scale
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local Stop

local function Looking()
	if type(IsMouselooking) ~= "function" then
		return false
	end
	local ok, value = pcall(IsMouselooking)
	return ok and not ns.IsSecret(value) and value == true
end

local function Alpha(frame)
	local alpha = looking and 0 or fadeAlpha
	if alpha ~= shownAlpha then
		shownAlpha = alpha
		frame:SetAlpha(alpha)
	end
end

local function Fade(to, duration)
	local start = GetTime()
	if fadeAlpha == to or not ns.Finite(start) then
		fade, fadeAlpha = nil, to
		return
	end
	fade = { from = fadeAlpha, to = to, start = start, duration = duration * math.abs(to - fadeAlpha) }
end

local function Scale(frame, scale)
	if scale ~= grownScale then
		grownScale = scale
		frame:SetScale(scale)
	end
end

local function Settle(frame)
	grow, shake.edge, shake.way, shake.hold = nil, nil, nil, nil
	shake.turns = {}
	Scale(frame, 1)
end

local function Shake(frame, now)
	local unseen = Unseen()
	if not unseen and Mode() ~= "shake" and ns.Get("general.cursorRingShake") ~= true then
		if grow or grownScale ~= 1 then
			Settle(frame)
		end
		return
	end
	local read, x = pcall(GetCursorPosition)
	local okScale, scale = pcall(UIParent.GetEffectiveScale, UIParent)
	if read and ns.Finite(x) and okScale and ns.Finite(scale) and scale > 0 then
		local step = SHAKE_STEP * scale
		if shake.edge == nil then
			shake.edge = x
		elseif shake.way == nil then
			if math.abs(x - shake.edge) >= step then
				shake.way, shake.edge = x > shake.edge and 1 or -1, x
			end
		elseif (x - shake.edge) * shake.way > 0 then
			shake.edge = x
		elseif math.abs(x - shake.edge) >= step then
			shake.way, shake.edge = -shake.way, x
			local turns = {}
			for _, at in ipairs(shake.turns) do
				if now - at <= SHAKE_WINDOW then
					turns[#turns + 1] = at
				end
			end
			turns[#turns + 1] = now
			shake.turns = turns
			if #turns >= SHAKE_TURNS and not grow then
				grow, shake.turns, shake.hold = now, {}, nil
				if unseen then
					if fadeAlpha == 0 and not fade then
						grow = now - GROW_UP
					end
					Fade(1, FADE_IN)
				end
			end
		end
	end
	if not grow then
		if unseen and fadeAlpha > 0 and not fade and not (shake.hold and now < shake.hold) then
			shake.hold = nil
			Fade(0, FADE_OUT)
		end
		return
	end
	local t = now - grow
	if not ns.Finite(t) or t >= GROW_END or t < 0 then
		grow = nil
		shake.hold = unseen and now + SHAKE_HOLD or nil
		Scale(frame, 1)
		return
	end
	local curve
	if t < GROW_UP then
		curve = math.sin(t / GROW_UP * math.pi / 2)
	else
		local back = (t - GROW_UP) / (GROW_END - GROW_UP)
		curve = (1 - back) * (1 - back)
	end
	Scale(frame, 1 + GROW * curve)
end

local Show

local function Hidden(frame)
	fade = nil
	Settle(frame)
	frame:Hide()
	frame:SetScript("OnUpdate", nil)
end

local function Tick(frame)
	if previewUntil ~= nil and not Previewing() then
		previewUntil = nil
		Show(Wanted())
		if not frame:IsShown() then
			return
		end
	end
	local now = Looking()
	if now ~= looking then
		looking = now
		lastX = nil
		Settle(frame)
		if Unseen() then
			fade, fadeAlpha = nil, 0
		end
	end
	if fade then
		local share = fade.duration > 0 and (GetTime() - fade.start) / fade.duration or 1
		if not ns.Finite(share) or share >= 1 then
			fadeAlpha = fade.to
			fade = nil
			if fadeAlpha == 0 and Mode() ~= "shake" then
				Hidden(frame)
				return
			end
		else
			fadeAlpha = fade.from + (fade.to - fade.from) * math.max(share, 0)
		end
	end
	Alpha(frame)
	if not looking then
		local time = GetTime()
		if ns.Finite(time) then
			Shake(frame, time)
		end
		if shownAlpha ~= 0 then
			Follow(frame)
		end
	end
end

local function Step(frame)
	local ok, err = pcall(Tick, frame)
	if not ok then
		Stop(err)
	end
end

local function Make()
	if ring then
		return ring
	end
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:Hide()
	frame:SetFrameStrata("TOOLTIP")
	frame:EnableMouse(false)
	local texture = frame:CreateTexture(nil, "OVERLAY", nil, 0)
	ns.Own[texture] = true
	texture:SetTexture(TEXTURE)
	texture:SetAllPoints(frame)
	pcall(texture.SetSnapToPixelGrid, texture, false)
	pcall(texture.SetTexelSnappingBias, texture, 0)
	ring, art = frame, texture
	return frame
end

local function Look()
	local size = ns.Get("general.cursorRingSize")
	if ns.Finite(size) and size > 0 then
		ring:SetSize(size, size)
	end
	local r, g, b
	if ns.Get("general.cursorRingClass") == true then
		r, g, b = ns.ClassColour()
	end
	if not r then
		r, g, b = ns.Colour("general.cursorRingColour")
	end
	art:SetVertexColor(r, g, b, 1)
end

local function GcdExists()
	if gcdExists == nil then
		local spells, ok, yes = C_Spell, false, nil
		if type(spells) == "table" and not ns.IsSecret(spells) and type(spells.DoesSpellExist) == "function" then
			ok, yes = pcall(spells.DoesSpellExist, GCD_SPELL)
		end
		gcdExists = ok and not ns.IsSecret(yes) and yes == true
	end
	return gcdExists
end

local function CastOn()
	return ns.Get("general.cursorRingCast") == true and refused.cast < MOST_REFUSED and Mode() ~= "shake"
end

local function GcdOn()
	return ns.Get("general.cursorRingGcd") == true and refused.gcd < MOST_REFUSED and Mode() ~= "shake" and GcdExists()
end

local function Swipe(kind)
	local cooldown = swipes[kind]
	if cooldown then
		return cooldown
	end
	cooldown = CreateFrame("Cooldown", nil, ring, "CooldownFrameTemplate")
	ns.Own[cooldown] = true
	pcall(cooldown.EnableMouse, cooldown, false)
	for _, call in ipairs({ { "SetDrawSwipe", true }, { "SetDrawEdge", false }, { "SetDrawBling", false }, { "SetHideCountdownNumbers", true } }) do
		if type(cooldown[call[1]]) == "function" then
			pcall(cooldown[call[1]], cooldown, call[2])
		end
	end
	if type(cooldown.SetSwipeTexture) == "function" then
		pcall(cooldown.SetSwipeTexture, cooldown, TEXTURE)
	end
	if kind == "gcd" then
		cooldown:ClearAllPoints()
		cooldown:SetPoint("CENTER", ring, "CENTER", 0, 0)
		if type(cooldown.SetReverse) == "function" then
			pcall(cooldown.SetReverse, cooldown, false)
		end
	end
	swipes[kind] = cooldown
	return cooldown
end

local function SwipeLook(kind, path)
	local cooldown = swipes[kind]
	local r, g, b = ns.Colour(path)
	if type(cooldown.SetSwipeColor) == "function" then
		pcall(cooldown.SetSwipeColor, cooldown, r, g, b, 1)
	end
	if kind == "gcd" then
		local size = ns.Get("general.cursorRingSize")
		if ns.Finite(size) and size > 0 then
			cooldown:SetSize(size * GCD_SHARE, size * GCD_SHARE)
		end
	end
end

local function Rest(cooldown)
	pcall(cooldown.Clear, cooldown)
	pcall(cooldown.Hide, cooldown)
end

local Hear

local function Hand(kind, duration)
	local cooldown = swipes[kind]
	if pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration, true) then
		pcall(cooldown.Show, cooldown)
		return
	end
	refused[kind] = refused[kind] + 1
	Rest(cooldown)
	if refused[kind] >= MOST_REFUSED then
		Hear(hearing.cast and CastOn(), hearing.gcd and GcdOn())
	end
end

local function Duration(fn)
	if type(fn) ~= "function" then
		return false
	end
	local ok, duration = pcall(fn, "player")
	if ok and (ns.IsSecret(duration) or duration ~= nil) then
		return true, duration
	end
	return false
end

local function Running(channelFirst)
	local first, second = UnitCastingDuration, UnitChannelDuration
	if channelFirst then
		first, second = second, first
	end
	local got, duration = Duration(first)
	if got then
		return true, duration, channelFirst
	end
	got, duration = Duration(second)
	if got then
		return true, duration, not channelFirst
	end
	return false
end

local function ArmCast(event)
	local cooldown = swipes.cast
	if not cooldown then
		return
	end
	if ENDED[event] then
		Rest(cooldown)
		return
	end
	local got, duration, channel = Running(CHANNEL[event] == true)
	if not got then
		Rest(cooldown)
		return
	end
	if type(cooldown.SetReverse) == "function" then
		pcall(cooldown.SetReverse, cooldown, not channel)
	end
	Hand("cast", duration)
end

local function ArmGcd()
	local cooldown, spells = swipes.gcd, C_Spell
	if not cooldown then
		return
	end
	local ok, duration = false, nil
	if type(spells) == "table" and not ns.IsSecret(spells) and type(spells.GetSpellCooldownDuration) == "function" then
		ok, duration = pcall(spells.GetSpellCooldownDuration, GCD_SPELL)
	end
	if not (ok and (ns.IsSecret(duration) or duration ~= nil)) then
		Rest(cooldown)
		return
	end
	Hand("gcd", duration)
end

local StopProgress

local function OnProgress(_, event, unit)
	local ok, err = pcall(function()
		if event == COOLDOWN_EVENT then
			ArmGcd()
		elseif not ns.IsSecret(unit) and unit == "player" then
			ArmCast(event)
		end
	end)
	if not ok then
		StopProgress(err)
	end
end

function Hear(cast, gcd)
	if (cast or gcd) and not hearer then
		hearer = CreateFrame("Frame")
		ns.Own[hearer] = true
		hearer:SetScript("OnEvent", OnProgress)
	end
	if not hearer then
		return
	end
	if cast ~= hearing.cast then
		for _, event in ipairs(CAST_EVENTS) do
			if not cast then
				pcall(hearer.UnregisterEvent, hearer, event)
			else
				local ok, done = false, nil
				if type(hearer.RegisterUnitEvent) == "function" then
					ok, done = pcall(hearer.RegisterUnitEvent, hearer, event, "player")
				end
				if not ok or (not ns.IsSecret(done) and done == false) then
					pcall(hearer.RegisterEvent, hearer, event)
				end
			end
		end
		hearing.cast = cast
	end
	if gcd ~= hearing.gcd then
		pcall(gcd and hearer.RegisterEvent or hearer.UnregisterEvent, hearer, COOLDOWN_EVENT)
		hearing.gcd = gcd
	end
end

local function Progress(on)
	if stopped then
		return
	end
	local cast, gcd = on and CastOn(), on and GcdOn()
	if cast then
		Swipe("cast")
		SwipeLook("cast", "general.cursorRingCastColour")
	end
	if gcd then
		Swipe("gcd")
		SwipeLook("gcd", "general.cursorRingGcdColour")
	end
	Hear(cast, gcd)
	if cast then
		ArmCast(nil)
	elseif swipes.cast then
		Rest(swipes.cast)
	end
	if gcd then
		ArmGcd()
	elseif swipes.gcd then
		Rest(swipes.gcd)
	end
end

function StopProgress(err)
	if stopped then
		return
	end
	pcall(Hear, false, false)
	for _, cooldown in pairs(swipes) do
		pcall(Rest, cooldown)
	end
	stopped = tostring(err)
	geterrorhandler()(err)
end

local function Swipes(on)
	local ok, err = pcall(Progress, on)
	if not ok then
		StopProgress(err)
	end
end

function Show(on)
	local fades, unseen = Mode() == "combat" and not Previewing(), Unseen()
	if on then
		local frame = Make()
		Look()
		if not frame:IsShown() then
			lastX, lastY, lastScale = nil, nil, nil
			looking, shownAlpha = Looking(), nil
			fadeAlpha, fade = (fades or unseen) and 0 or 1, nil
			if fades then
				Fade(1, FADE_IN)
			end
			Alpha(frame)
			if not looking then
				Follow(frame)
			end
			frame:SetScript("OnUpdate", Step)
			frame:Show()
		elseif unseen then
		elseif not fades then
			fade, fadeAlpha = nil, 1
			Alpha(frame)
		elseif (fade and fade.to == 0) or (not fade and fadeAlpha < 1) then
			Fade(1, FADE_IN)
		end
	elseif ring and ring:IsShown() then
		if not fades then
			Hidden(ring)
		elseif not (fade and fade.to == 0) then
			Fade(0, FADE_OUT)
			if not fade then
				Hidden(ring)
			end
		end
	end
	Swipes(on)
end

local function OnFight(_, event)
	fighting = event == "PLAYER_REGEN_DISABLED"
	Show(Wanted())
end

local function Listen(on)
	if on and not listener then
		listener = CreateFrame("Frame")
		ns.Own[listener] = true
		listener:SetScript("OnEvent", function(...)
			local ok, err = pcall(OnFight, ...)
			if not ok then
				Stop(err)
			end
		end)
	end
	if listener then
		for _, event in ipairs(FIGHT_EVENTS) do
			if on then
				listener:RegisterEvent(event)
			else
				listener:UnregisterEvent(event)
			end
		end
	end
end

function Stop(err)
	if broken then
		return
	end
	broken = tostring(err)
	fade = nil
	pcall(Listen, false)
	pcall(Progress, false)
	if ring then
		pcall(ring.SetScript, ring, "OnUpdate", nil)
		pcall(ring.Hide, ring)
	end
	geterrorhandler()(err)
end

local function Apply()
	if broken then
		return
	end
	local mode = Mode()
	fighting = mode == "combat" and InFight() or false
	Listen(mode == "combat")
	Show(Wanted())
end

local function Sample(force)
	if broken or stopped or not (ring and ring:IsShown() and (force or Testing())) or Running(false) then
		return
	end
	local now = GetTime()
	for kind, on in pairs({ cast = CastOn(), gcd = GcdOn() }) do
		local cooldown = on and swipes[kind]
		if cooldown and type(cooldown.SetCooldown) == "function" then
			if kind == "cast" and type(cooldown.SetReverse) == "function" then
				pcall(cooldown.SetReverse, cooldown, true)
			end
			if pcall(cooldown.SetCooldown, cooldown, now, kind == "cast" and 2.5 or 1.5) then
				pcall(cooldown.Show, cooldown)
			end
		end
	end
end

function ns.CursorRingChanged(path)
	local mode = Mode()
	local shown = type(path) == "string" and not broken and not InCombatLockdown() and type(ns.PanelShown) == "function" and ns.PanelShown() == true
	local swipe = shown and SWIPE_ROWS[path] and (mode == "always" or mode == "combat") and not InFight()
	if shown and PREVIEW_ROWS[path] and (mode == "combat" or mode == "shake") then
		previewUntil = GetTime() + PREVIEW
	elseif swipe then
		previewUntil = math.max(previewUntil or 0, GetTime() + SWIPE_PREVIEW)
	end
	local ok, err = pcall(Apply)
	if not ok then
		Stop(err)
	elseif swipe then
		pcall(Sample, true)
	end
end

function ns.CursorRingSample()
	Sample(false)
end

local function ProgressStatus()
	if stopped then
		return "Its cast and global cooldown progress stopped: " .. stopped
	end
	local said = {}
	if ns.Get("general.cursorRingCast") == true and refused.cast >= MOST_REFUSED then
		said[#said + 1] = "The game did not take the time of your casts, so the ring shows no cast progress until /reload."
	end
	if ns.Get("general.cursorRingGcd") == true then
		if not GcdExists() then
			said[#said + 1] = "This game has no global cooldown spell, so the ring shows no global cooldown."
		elseif refused.gcd >= MOST_REFUSED then
			said[#said + 1] = "The game did not take the global cooldown, so the ring shows none until /reload."
		end
	end
	return #said > 0 and table.concat(said, " ") or nil
end

function ns.CursorRingStatus()
	if broken then
		return "Cursor ring: stopped. " .. broken
	end
	local mode = Mode()
	local line
	if mode == "always" then
		line = "Cursor ring: on, always."
	elseif mode == "combat" then
		line = "Cursor ring: on, in combat only."
	elseif mode == "shake" then
		line = "Cursor ring: on, when you shake the mouse."
	else
		return nil
	end
	local ok, more = pcall(ProgressStatus)
	if ok and more then
		line = line .. " " .. more
	end
	return line
end
