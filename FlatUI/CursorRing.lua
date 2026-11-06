local ADDON_NAME, ns = ...

-- Cursor ring (general.cursorRing on the Flat UI page): a ring of the addon's own around the mouse pointer, so it is found at a glance, always or
-- only in combat, in the size and colour of its rows. It is one frame of the addon's own on UIParent, in the TOOLTIP strata, that takes no mouse
-- and holds one texture, Media/Ring.tga (a white ring, 128 by 128, its edges 61 and 51 pixels from the centre, tinted with SetVertexColor). The
-- frame is made the first time the ring shows. While it is shown, its OnUpdate script reads the cursor (GetCursorPosition, in screen pixels:
-- InputDocumentation.lua:30-38) and moves the frame only when the cursor or the scale has moved; while it is hidden it has no script, so nothing
-- runs. It hides with UIParent. In combat only, a frame of the addon's own listens to PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED, and only
-- while that choice is made. Nothing of the game is changed. Not a module: Core.lua applies the rows at login and when the profile changes, and
-- the rows call ns.CursorRingChanged themselves.
-- It follows the cursor ring of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoL/Modules/Mouse/Mouse.lua:1882-1925,
-- 2185-2258): the ring and its combat rule, without the centre dot, the right-click rule and the cast and cooldown progress.

local TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Ring.tga"
local MODES = { always = true, combat = true }
local FIGHT_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

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

-- The line of /flatui status, or nil while the ring is off.
function ns.CursorRingStatus()
	if broken then
		return "Cursor ring: stopped. " .. broken
	end
	local mode = Mode()
	if mode == "always" then
		return "Cursor ring: on, always."
	elseif mode == "combat" then
		return "Cursor ring: on, in combat only."
	end
	return nil
end
