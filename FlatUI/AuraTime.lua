local _, ns = ...

local FORMAT, COLOUR, TOTEM_SIZE, WARN_AT = "hud.durationFormat", "hud.durationColour", "unitframes.totemTimeSize", "hud.durationWarn"
local TENTHS_AT = "hud.durationTenths"
local FRAMES = { "BuffFrame", "DebuffFrame", "ExternalDefensivesFrame" }
local NOTE = "Unit frames: Duration format: the game withholds totem times in fights, and they keep the game's format."
local WARN, RED, CLOCK_TO = 10, { 1, 0.3, 0.3 }, 3600
local weak = { __mode = "k" }
local sized = setmetatable({}, weak)
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

function ns.AuraWarnAt()
	local warn = ns.Get(WARN_AT)
	if ns.Finite(warn) then
		return warn
	end
	return WARN
end

function ns.AuraTenthsAt()
	local under = ns.Get(TENTHS_AT)
	if ns.Finite(under) then
		return under
	end
	return 0
end

local function IsTotem(button)
	local ok, parent = pcall(button.GetParent, button)
	return ok and parent ~= nil and not ns.IsSecret(parent) and parent == _G.TotemFrame
end

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
	local format = ns.Get(FORMAT)
	local clock = format == "clock"
	if (clock or (format == "tight" and Tight())) and type(_G.SecondsToTimeAbbrev) == "function" then
		if ns.IsSecret(timeLeft) then
			if totem then
				ns.Note("unitframes", NOTE)
			end
		elseif clock and ns.Finite(timeLeft) and timeLeft < CLOCK_TO then
			if timeLeft >= 60 then
				text:SetFormattedText("%d:%02d", math.floor(timeLeft / 60), math.floor(timeLeft % 60))
			else
				text:SetFormattedText("%d", math.floor(math.max(0, timeLeft)))
			end
		elseif type(timeLeft) == "number" and Tight() then
			local game, number = _G.SecondsToTimeAbbrev(timeLeft)
			if tight[game] then
				text:SetFormattedText(tight[game], number)
			end
		end
	end
	if not totem and not ns.IsSecret(timeLeft) and type(timeLeft) == "number" and timeLeft > 0 and timeLeft < ns.AuraTenthsAt() then
		text:SetFormattedText("%.1f", timeLeft)
	end
	local mode = ns.Get(COLOUR)
	if (mode == "white" or mode == "warn")
		and not (totem and ns.Get("unitframes.totemTimer") == false and not ns.UnitFrameExtra.off("Totem timers")) then
		if mode == "warn" and not ns.IsSecret(timeLeft) and type(timeLeft) == "number" and timeLeft < ns.AuraWarnAt() then
			text:SetVertexColor(RED[1], RED[2], RED[3])
		else
			text:SetVertexColor(1, 1, 1)
		end
	end
end

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
ns.AddStart("hud", Follow)
ns.AddStart("unitframes", Follow)
