local _, ns = ...

-- The time text of an aura button: no space between the number and the unit, white, and the size of the totem times. One function of the game writes all of
-- it: AuraButtonMixin:UpdateDuration sets the text with SecondsToTimeAbbrev and the colour with three numbers on every tick (BuffFrame.lua:1387-1401). The
-- function is followed after the game's call (ns.FollowTable on the mixin, which the totem buttons call by table, TotemFrame.lua:70-71, and which every
-- button made later copies). The buttons of BuffFrame, DebuffFrame and ExternalDefensivesFrame were made before this file loads with the game's own copy, so
-- each of them is followed once (ns.Follow, the same hook on the button, BuffFrame.lua:191-197, 1235); a button that already holds the followed function is
-- left out, so nothing runs twice. Nothing is read back from the text. The unit format of a locale that keeps a space in its cooldown form keeps its space.
-- A totem time the game withholds in a fight is not formatted, and /flatui status says so. The time size of a totem is set once and set again only when the
-- row changes: the totem path sets no font (TotemFrame.lua:70-71).

local FORMAT, COLOUR, TOTEM_SIZE = "hud.durationFormat", "hud.durationColour", "unitframes.totemTimeSize"
local FRAMES = { "BuffFrame", "DebuffFrame", "ExternalDefensivesFrame" }
local NOTE = "Unit frames: Duration format: the game withholds totem times in fights, and they keep the game's format."
local weak = { __mode = "k" }
-- The percent last set on a totem time, per button.
local sized = setmetatable({}, weak)
-- The formats of the game with the space after %d removed, by the game's format: built once, false when the locale keeps its space.
local tight = nil

local function Tight()
	if tight == nil then
		tight = false
		local cooldown = _G.COOLDOWN_DURATION_MIN
		if type(cooldown) == "string" and not cooldown:find("%%d%s") then
			local map = {}
			for _, name in ipairs({ "SECOND", "MINUTE", "HOUR", "DAY" }) do
				local text = _G[name .. "_ONELETTER_ABBR"]
				if type(text) == "string" then
					map[text] = (text:gsub("(%%d)%s+", "%1"))
				end
			end
			tight = map
		end
	end
	return tight or nil
end

local function IsTotem(button)
	local ok, parent = pcall(button.GetParent, button)
	return ok and parent ~= nil and not ns.IsSecret(parent) and parent == _G.TotemFrame
end

-- Runs after the game's UpdateDuration of a button, on every tick.
local function After(button, timeLeft)
	if ns.Forbidden(button) or button.isExample then
		return
	end
	local text = button.Duration
	if type(text) ~= "table" or ns.IsSecret(text) then
		return
	end
	local ok, shown = pcall(text.IsShown, text)
	if not ok or ns.IsSecret(shown) or shown ~= true then
		return
	end
	local totem = IsTotem(button)
	local on = ns.Enabled(totem and "unitframes" or "hud")
	if totem then
		local want = on and ns.Get(TOTEM_SIZE) or 100
		if type(want) == "number" and (sized[button] or 100) ~= want and ns.TextSize(text, want) then
			sized[button] = want ~= 100 and want or nil
		end
	end
	if not on then
		return
	end
	if ns.Get(FORMAT) == "tight" and Tight() and type(_G.SecondsToTimeAbbrev) == "function" then
		if ns.IsSecret(timeLeft) then
			if totem then
				ns.Note("unitframes", NOTE)
			end
		elseif type(timeLeft) == "number" then
			local game, number = _G.SecondsToTimeAbbrev(timeLeft)
			if tight[game] then
				text:SetFormattedText(tight[game], number)
			end
		end
	end
	-- A colour with no fourth number resets the opacity, which would show a totem time that Totem time left hides with SetAlpha(0) (UnitExtras.lua:297-299).
	-- The same condition as KeepTimer (UnitExtras.lua:305-309): a stopped Totems part hides nothing, so its time takes the white.
	if ns.Get(COLOUR) == "white" and not (totem and ns.Get("unitframes.totemTimer") == false and not ns.UnitFrameExtra.off("Totem timers")) then
		text:SetVertexColor(1, 1, 1)
	end
end

-- Follows the mixin and the buttons the game made before this file loaded. It can run again: each button and the mixin are followed once.
local function Follow()
	local mixin = _G.AuraButtonMixin
	local made = type(mixin) == "table" and not ns.IsSecret(mixin)
	if made then
		ns.FollowTable(mixin, "UpdateDuration", After)
	end
	for _, name in ipairs(FRAMES) do
		local frame = _G[name]
		local list = type(frame) == "table" and not ns.IsSecret(frame) and frame.auraFrames
		if type(list) == "table" and not ns.IsSecret(list) then
			for _, button in ipairs(list) do
				if type(button) == "table" and not ns.IsSecret(button) and (not made or button.UpdateDuration ~= mixin.UpdateDuration) then
					ns.Follow(button, "UpdateDuration", After)
				end
			end
		end
	end
end

ns.AddEvent("hud", "PLAYER_ENTERING_WORLD", Follow)
ns.AddEvent("unitframes", "PLAYER_ENTERING_WORLD", Follow)
-- A page turned on after the loading screen starts with no such event.
ns.AddStart("hud", Follow)
ns.AddStart("unitframes", Follow)
