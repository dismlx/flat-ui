local _, ns = ...

-- UIParent's scale is the game's UI scale. An addon that calls UIParent:SetScale changes the layout of every Blizzard action bar from
-- tainted code, and the game's next secure layout pass runs tainted: a click on an action button is then refused with
-- ADDON_ACTION_FORBIDDEN for UseAction (research/reports/2026-10-12-0.4.37, and the report of 2026-10-13). So the scale the game takes is
-- written to the game's own variables (useUiScale and uiscale), and the game applies it itself, at every login too. Only the row
-- Scale below 65% still calls SetScale, because the game's slider stops at 65%, and its tip says what that costs.

local TOLERANCE = 0.0005
-- A dragged slider sends every step. The scale is written once the value has stopped changing.
local SETTLE = 0.3
-- How near the game's answer has to be to the asked value.
local MATCH = 0.005
-- The lowest scale the game's own setting takes.
local FLOOR = 0.65
local MIN_PIXEL_SCALE, MAX_PIXEL_SCALE = 0.35, 1.15

-- The scale asked of the game, and how the last write ended: nil until checked, "ok" or "refused".
local asked, result, checking
-- True while the variables hold a scale this addon wrote.
local written = false
-- True once the game's variables were written in this session. The game applies them in a clean run at the next login, so /reload finishes it.
local liveWrite = false
-- UIParent has a scale this addon set with SetScale, and whether a reload is left to put the game's back.
local direct, reloadNote = false, false
local pending = false
local generation = 0

local function Percent(scale)
	return math.floor(scale * 100 + 0.5)
end

local function Current()
	local ok, scale = pcall(UIParent.GetScale, UIParent)
	if ok and not ns.IsSecret(scale) and type(scale) == "number" and scale > 0 then
		return scale
	end
	return nil
end

local function CVarText(name)
	if type(C_CVar) ~= "table" or type(C_CVar.GetCVar) ~= "function" then
		return nil
	end
	local ok, value = pcall(C_CVar.GetCVar, name)
	if ok and type(value) == "string" and not ns.IsSecret(value) then
		return value
	end
	return nil
end

-- The scale the game's variable gives, or nil.
local function CVarScale()
	return tonumber(CVarText("uiscale"))
end

-- The scale at which one unit is pixelSize screen pixels, and false when it is outside what is applied. Nil when the client does not
-- say how tall the screen is.
local function PixelScale()
	if type(GetPhysicalScreenSize) ~= "function" then
		return nil
	end
	local ok, _, height = pcall(GetPhysicalScreenSize)
	if not ok or not ns.Finite(height) or height <= 0 then
		return nil
	end
	local scale = ns.Get("general.pixelSize") * 768 / height
	return scale, scale >= MIN_PIXEL_SCALE and scale <= MAX_PIXEL_SCALE
end
-- Shared with the setup drawing of the Scale step, so the drawing and the applied scale use one formula.
ns.PixelScale = PixelScale

-- The scale to apply and the route: "cvar" writes the game's variables, "set" calls SetScale (only under the game's floor, and only with
-- Scale below 65% on). With no scale to apply the first answer is nil and the second says why, for the status.
local function Wanted()
	if ns.Get("general.scaleOn") ~= true then
		return nil
	end
	local below = ns.Get("general.scaleBelow") == true
	if ns.Get("general.pixelPerfect") then
		local scale, fits = PixelScale()
		if not scale then
			return nil, "noheight"
		elseif not fits then
			return nil, "nofit", scale
		elseif scale >= FLOOR then
			return scale, "cvar"
		elseif below then
			return scale, "set"
		end
		return nil, "low", scale
	end
	if below then
		return ns.Get("general.scaleSmall") / 100, "set"
	end
	return ns.Get("general.scale") / 100, "cvar"
end

-- What the game held before the first write, kept for the account.
local function Remember()
	local db = FlatUIDB
	if type(db) ~= "table" or type(db.scaleGame) == "table" then
		return
	end
	local use, scale = CVarText("useUiScale"), CVarText("uiscale")
	if use and scale then
		db.scaleGame = { use = use, scale = scale }
	end
end

local function Verify()
	if not checking then
		return
	end
	checking = false
	local use, now, shown = CVarText("useUiScale"), CVarScale(), Current()
	if use == "1" and now and math.abs(now - asked) < MATCH and (not shown or math.abs(shown - asked) < MATCH) then
		-- The game sends UI_SCALE_CHANGED itself, and the edges drawn on the frames follow it.
		result = "ok"
	else
		result = "refused"
	end
end

local function Write(value)
	if CVarText("useUiScale") == "1" and math.abs((CVarScale() or -1) - value) < TOLERANCE then
		asked, result, written = value, "ok", true
		return
	end
	if type(C_CVar) ~= "table" or type(C_CVar.SetCVar) ~= "function" then
		asked, result = value, "refused"
		return
	end
	Remember()
	asked, result, checking, written, liveWrite = value, nil, false, true, true
	-- uiscale first, so the game does not apply the old value when useUiScale turns on.
	pcall(C_CVar.SetCVar, "uiscale", ("%.10g"):format(value))
	if CVarText("useUiScale") ~= "1" then
		pcall(C_CVar.SetCVar, "useUiScale", "1")
	end
	checking = true
	if C_Timer and C_Timer.After then
		-- UI_SCALE_CHANGED checks the write when the game sends it. Without one the check is made after the wait.
		C_Timer.After(SETTLE, Verify)
		if CVarText("useUiScale") == "1" and math.abs((CVarScale() or -1) - value) < MATCH then
			Verify()
		end
	else
		Verify()
	end
end

-- Puts the game's own values back after a scale this addon wrote, in this session or an earlier one (the account keeps them in scaleGame).
local function Release()
	if direct then
		direct, reloadNote = false, true
	end
	written, asked, result, checking = false, nil, nil, false
	local db = FlatUIDB
	local game = type(db) == "table" and db.scaleGame
	if type(game) ~= "table" then
		return
	end
	db.scaleGame = nil
	if type(C_CVar) == "table" and type(C_CVar.SetCVar) == "function" then
		pcall(C_CVar.SetCVar, "uiscale", game.scale)
		pcall(C_CVar.SetCVar, "useUiScale", game.use)
		liveWrite = true
	end
end

local function SetDirect(value)
	reloadNote = false
	local current = Current()
	if current and math.abs(current - value) < TOLERANCE then
		direct = true
		return
	end
	if pcall(UIParent.SetScale, UIParent, value) then
		direct = true
		-- Setting the scale here fires no scale event.
		ns.ResizeAll()
	end
end

local function Apply()
	pending = false
	local value, route = Wanted()
	if route == "cvar" then
		if direct then
			-- UIParent holds a scale this addon set. The game puts its own back at the next /reload.
			direct, reloadNote = false, true
		end
		Write(value)
	elseif route == "set" then
		if written or type(FlatUIDB) == "table" and type(FlatUIDB.scaleGame) == "table" then
			Release()
		end
		SetDirect(value)
	else
		Release()
	end
end

-- Nothing is written in combat.
local function Queue()
	if pending then
		return
	end
	pending = true
	ns.OutOfCombat(Apply)
end

function ns.ScaleChanged(path)
	if path == "general.scaleOn" and ns.Get("general.scaleOn") and not ns.IsSet("general.scale") then
		-- Ticked for the first time: start from the scale on screen.
		local current = Current()
		if current then
			ns.Set("general.scale", Percent(current))
			if ns.NotifyOption then
				ns.NotifyOption("general.scale")
			end
		end
	end
	generation = generation + 1
	local mine = generation
	if C_Timer and C_Timer.After then
		C_Timer.After(SETTLE, function()
			if mine == generation then
				Queue()
			end
		end)
	else
		-- Without a timer every step of the slider is written.
		Queue()
	end
end

-- The percent a profile held under the game's 65% before it moved to Small scale, for the profile in use.
local function Moved()
	return ns.scaleMoved and ns.scaleMoved[ns.Profile()]
end

local function MovedLine()
	return ("%d%% is under the game's 65%%, so it is not applied."):format(Moved())
end

function ns.ScaleStatus()
	if Moved() and ns.Get("general.scaleOn") ~= true and ns.Get("general.scaleBelow") ~= true then
		return "Custom UI scale: " .. MovedLine()
	end
	if not ns.Get("general.scaleOn") then
		if reloadNote then
			return "Custom UI scale: off. /reload puts the game's scale back."
		end
		return liveWrite and "Custom UI scale: off. /reload to finish." or nil
	end
	local value, route, extra = Wanted()
	local size = ns.Get("general.pixelSize")
	local line
	if route == "noheight" then
		line = ("Pixel-perfect scale: %d px per unit. The screen height is not known, so it is not applied."):format(size)
	elseif route == "nofit" then
		line = ("Pixel-perfect scale: %d px per unit gives %d%%, outside %d%% to %d%%, so it is not applied."):format(size,
			Percent(extra), Percent(MIN_PIXEL_SCALE), Percent(MAX_PIXEL_SCALE))
	elseif route == "low" then
		line = ("Pixel-perfect scale: %d px per unit needs %d%%, under the game's %d%%, so it is not applied."):format(size,
			Percent(extra), Percent(FLOOR))
	elseif route == "set" then
		line = ("Scale below 65%%: %d%%. The game can refuse presses of its own action buttons."):format(Percent(value))
	else
		local text
		if ns.Get("general.pixelPerfect") then
			text = ("Pixel-perfect scale: %d px per unit, %d%%"):format(size, Percent(value))
		else
			text = ("Custom UI scale: %d%%"):format(Percent(value))
		end
		local now = CVarScale()
		if result == "refused" and asked and math.abs(asked - value) < TOLERANCE then
			local got = Current() or now
			line = text .. (got and (" asked, the game applied %d%%."):format(Percent(got)) or " asked, the game gave no answer.")
		elseif not pending and now and math.abs(now - value) >= TOLERANCE then
			line = text .. (" asked, the game has %d%%. Turn Custom UI scale off and on to write it."):format(Percent(now))
		else
			line = text .. "."
		end
	end
	if reloadNote then
		line = line .. " /reload puts the game's scale back."
	elseif liveWrite and route == "cvar" and not pending then
		line = line .. " /reload to finish."
	end
	if pending then
		line = line .. " Waiting for combat to end."
	end
	return line
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
pcall(frame.RegisterEvent, frame, "UI_SCALE_CHANGED")
pcall(frame.RegisterEvent, frame, "DISPLAY_SIZE_CHANGED")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" and Moved() then
		print("Flat UI: Custom scale " .. MovedLine() .. " Turn on Custom UI scale and Scale below 65% to use it.")
	end
	-- The game's events only read back: the game applies its variables itself.
	if event == "UI_SCALE_CHANGED" then
		Verify()
	end
	local _, route = Wanted()
	if route == "set" then
		-- The game puts its own scale back after these events, so the small scale is set again.
		Queue()
	elseif event == "DISPLAY_SIZE_CHANGED" and ns.Get("general.scaleOn") == true and ns.Get("general.pixelPerfect") then
		-- A pixel-perfect scale follows the screen height. The write is made only when the height gives another scale.
		Queue()
	end
end)
