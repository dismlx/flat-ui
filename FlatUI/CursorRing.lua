local ADDON_NAME, ns = ...

-- Cursor ring (general.cursorRing on the Flat UI page): a ring of the addon's own around the mouse pointer, so it is found at a glance, always or
-- only in combat, in the size and colour of its rows. It is one frame of the addon's own on UIParent, in the TOOLTIP strata, that takes no mouse
-- and holds one texture, Media/Ring.tga (a white ring, 128 by 128, its edges 61 and 51 pixels from the centre, tinted with SetVertexColor). The
-- frame is made the first time the ring shows. While it is shown, its OnUpdate script reads the cursor (GetCursorPosition, in screen pixels:
-- InputDocumentation.lua:30-38) and moves the frame only when the cursor or the scale has moved; while it is hidden it has no script, so nothing
-- runs. It hides with UIParent. In combat only, a frame of the addon's own listens to PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED, and only
-- while that choice is made. Nothing of the game is changed. Not a module: Core.lua applies the rows at login and when the profile changes, and
-- the rows call ns.CursorRingChanged themselves.
-- Cast progress on the ring (general.cursorRingCast, on) and Global cooldown on the ring (general.cursorRingGcd, off), each with a colour row: two
-- Cooldown frames of the ring's own (CooldownFrameTemplate, which sets all points and hides them: Blizzard_FrameXMLUtil/Mainline/Cooldown.xml:3),
-- made the first time one of the rows is on while the ring shows. Each draws Media/Ring.tga as its swipe (SetSwipeTexture) in its row's colour
-- (SetSwipeColor), with no edge, bling or numbers; the uiobjects.yaml of build 70790 lists SetSwipeTexture, SetReverse, SetDrawEdge, SetDrawBling and
-- SetHideCountdownNumbers on the Cooldown widget. The cast's covers the ring; the global cooldown's is a fifth smaller, just inside it. While the ring
-- shows, a frame of the addon's own hears the player's UNIT_SPELLCAST_START, STOP, FAILED, INTERRUPTED, DELAYED, CHANNEL_START, CHANNEL_UPDATE and
-- CHANNEL_STOP, and SPELL_UPDATE_COOLDOWN. It hands the duration object of UnitCastingDuration('player') or UnitChannelDuration('player')
-- (UnitDocumentation.lua:811-868) to the cast's swipe, which fills for a cast and empties for a channel (SetReverse), and that of
-- C_Spell.GetSpellCooldownDuration(61304), the global cooldown (SpellDocumentation.lua:327-342), to the other, with SetCooldownFromDurationObject
-- (FrameAPICooldownDocumentation.lua:308-318), as the trackers and the cooldown pulse do with Cooldown frames of their own. Nothing the game gives is
-- read or compared. A cast that stops is cleared (Clear); one that fails or is interrupted asks the game again, since the game says so too of a
-- second spell tried while a cast goes on, which keeps its swipe. A delayed cast and a changed channel are asked again. The global cooldown shows
-- only where C_Spell.DoesSpellExist(61304) says the spell exists (SpellDocumentation.lua:46-60). No event is heard while the ring is hidden. A swipe
-- the game refuses on three casts or global cooldowns is left out until /reload, and /flatui status says so.
-- It follows the cursor ring of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoL/Modules/Mouse/Mouse.lua:1882-1925,
-- 2185-2258): the ring and its combat rule, and its cast and global cooldown swipes (Mouse.lua:845-937, 958-1060 and 1164-1230), fed duration objects
-- in place of the start and end times, which the game may withhold. The centre dot, the right-click rule and the dots that run round the ring are left out.

local TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Ring.tga"
local MODES = { always = true, combat = true }
local FIGHT_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
-- The player's cast events, those of a channel, those of a cast or channel that has ended, and the event of the cooldowns.
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }
local CHANNEL = { UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true }
local ENDED = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true }
local COOLDOWN_EVENT = "SPELL_UPDATE_COOLDOWN"
-- The global cooldown spell (EnhanceQoL/Modules/Mouse/Mouse.lua:45).
local GCD_SPELL = 61304
-- The size of the global cooldown's swipe against the ring's: the ring's band lies 51 to 61 pixels of 64 from the centre, so at 0.8 the inner band
-- ends a pixel or so inside it.
local GCD_SHARE = 0.8
-- Refusals of a swipe after which it is left out until /reload.
local MOST_REFUSED = 3

local ring
-- The texture of the ring.
local art
-- The frame that hears the start and the end of a fight while the ring shows in combat only.
local listener
-- True between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED.
local fighting = false
-- Where the ring was last put, in the cursor's pixels and the frame's scale.
local lastX, lastY, lastScale
-- The error that stopped the ring, or nil.
local broken
-- The progress swipes: swipes.cast and swipes.gcd, the Cooldown frames; refused, per swipe the refusals of the game; hearer, the frame that hears
-- the cast events; hearing, the events it hears now; gcdExists, nil until asked; stopped, the error that stopped the swipes alone.
local swipes, refused = {}, { cast = 0, gcd = 0 }
local hearer
local hearing = { cast = false, gcd = false }
local gcdExists
local stopped

local function Mode()
	local mode = ns.Get("general.cursorRing")
	return MODES[mode] and mode or nil
end

-- Whether the player is in a fight now, for the ring's first look. A withheld answer counts as out of combat.
local function InFight()
	if type(UnitAffectingCombat) == "function" then
		local ok, value = pcall(UnitAffectingCombat, "player")
		if ok and not ns.IsSecret(value) and type(value) == "boolean" then
			return value
		end
	end
	return InCombatLockdown() == true
end

local function Wanted()
	local mode = Mode()
	if broken or mode == nil then
		return false
	end
	return mode == "always" or fighting
end

-- Puts the centre of the ring on the cursor.
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

local function Step(frame)
	local ok, err = pcall(Follow, frame)
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
	-- A ring that moves by parts of a pixel is not pulled onto the pixel grid, so it does not jump.
	pcall(texture.SetSnapToPixelGrid, texture, false)
	pcall(texture.SetTexelSnappingBias, texture, 0)
	ring, art = frame, texture
	return frame
end

-- The size and colour of the rows.
local function Look()
	local size = ns.Get("general.cursorRingSize")
	if ns.Finite(size) and size > 0 then
		ring:SetSize(size, size)
	end
	local r, g, b = ns.Colour("general.cursorRingColour")
	art:SetVertexColor(r, g, b, 1)
end

-- Progress on the ring ----------------------------------------------------------------------------------------------------------------------------

-- True where the game has the global cooldown spell. Asked once.
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
	return ns.Get("general.cursorRingCast") == true and refused.cast < MOST_REFUSED
end

local function GcdOn()
	return ns.Get("general.cursorRingGcd") == true and refused.gcd < MOST_REFUSED and GcdExists()
end

-- The Cooldown frame of a swipe, made once on the ring.
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
	-- The global cooldown empties, as the game's own cooldown swipes do; the cast's way is set for each cast.
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

-- The colour of a swipe, and the size of the inner one.
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

-- A swipe with nothing to show.
local function Rest(cooldown)
	pcall(cooldown.Clear, cooldown)
	pcall(cooldown.Hide, cooldown)
end

local Hear

-- A duration object handed on, or the game refused it: the third refusal leaves the swipe out until /reload, and its events are no longer heard.
local function Hand(kind, duration)
	local cooldown = swipes[kind]
	if pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration, true) then
		-- The template hides the frame, and nothing says a cooldown shows it (Pulse.lua does the same).
		pcall(cooldown.Show, cooldown)
		return
	end
	refused[kind] = refused[kind] + 1
	Rest(cooldown)
	if refused[kind] >= MOST_REFUSED then
		Hear(hearing.cast and CastOn(), hearing.gcd and GcdOn())
	end
end

-- The duration object a call of the game gives for the player, handed on unread. False when the call fails or gives nothing.
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

-- The cast or channel under way, the channel asked first after a channel's own events; true for a channel as the third answer.
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

-- The cast's swipe after an event of the player's casts, or with no event when the ring shows: a cast fills the ring, a channel empties it.
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

-- The global cooldown's swipe. A cooldown of nought clears it (clearIfZero).
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

-- The events of the swipes that are on, and none of the others. A client that cannot hear an event for one unit hears it for every unit, and the
-- handler keeps the player's.
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

-- The swipes follow the ring and their rows: made, coloured, heard and given what runs now while the ring shows, cleared and deaf while it is hidden.
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

-- An error stops the swipes alone until the next /reload, with a line for /flatui status; the ring goes on.
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

-- The ring -----------------------------------------------------------------------------------------------------------------------------------------

local function Show(on)
	if on then
		local frame = Make()
		Look()
		if not frame:IsShown() then
			lastX, lastY, lastScale = nil, nil, nil
			Follow(frame)
			frame:SetScript("OnUpdate", Step)
			frame:Show()
		end
	elseif ring and ring:IsShown() then
		ring:Hide()
		ring:SetScript("OnUpdate", nil)
	end
	Swipes(on)
end

local function OnFight(_, event)
	fighting = event == "PLAYER_REGEN_DISABLED"
	Show(Wanted())
end

-- The start and the end of a fight are heard only while the ring shows in combat only.
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

-- An error stops the ring until the next /reload, with a line for /flatui status.
function Stop(err)
	if broken then
		return
	end
	broken = tostring(err)
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

-- A row of the ring changed, the player logged in, or the profile changed.
function ns.CursorRingChanged()
	local ok, err = pcall(Apply)
	if not ok then
		Stop(err)
	end
end

-- What /flatui status adds about the swipes, or nil when all is well.
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

-- The line of /flatui status, or nil while the ring is off.
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
	else
		return nil
	end
	local ok, more = pcall(ProgressStatus)
	if ok and more then
		line = line .. " " .. more
	end
	return line
end
