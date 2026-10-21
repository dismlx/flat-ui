local _, ns = ...

-- Fading: the action bars, the stance and pet bars, the micro menu, the bag bar, the player and pet frames and the minimap buttons go to a
-- low opacity while nothing asks for them, and back to full when something does. The one thing written on a game frame is its alpha
-- (SetAlpha, which the documentation leaves open to addons and does not mark protected:
-- Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1133-1142). The alpha a frame had is read before the first write and put
-- back when the module, the row or the part goes off. A faded frame still takes clicks and shows tooltips, since alpha does not touch the mouse.
--
-- One frame of the addon's own runs every 0.05 s while the module is on. A row is at full opacity while the mouse is over the row's hover frame,
-- in a fight (with In combat ticked), with a target (With a target ticked), while the cursor holds something, while the spell flyout is open and in Edit Mode.
-- Otherwise it stays where it is until Wait before fading has passed, then eases to Faded opacity over Fade time. A frame is written only when its value changes.
-- A frame whose alpha something else holds at 0 (the hidden minimap buttons) is left alone, and a frame the action bar block fades is left to that fade.
-- The frames are the game's own: MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7, StanceBar,
-- PetActionBar, MicroMenuContainer, BagsBar, PlayerFrame.PlayerFrameContainer and PlayerFrame.PlayerFrameContent (parentKeys of PlayerFrame with no global name: Blizzard_UnitFrame/Mainline/PlayerFrame.xml:23 and :68; the pet frame, totems and cast bar stay as they are),
-- PetFrame, and under MinimapCluster the Tracking and IndicatorFrame frames, GameTimeFrame, TimeManagerClockButton and AddonCompartmentFrame
-- (Blizzard_Minimap/Mainline/Minimap.xml:3, 60 and 96, GameTime.xml:3, AddonCompartment.xml:3, Blizzard_TimeManager/Mainline/Blizzard_TimeManager.xml:178).
-- ExtraActionBarFrame, the swing timers and the resource display are left out because the game or Edit Mode sets their alpha.

local KEY = "fade"
local PART = "fade"
local EVERY = 0.05
-- An alpha at or under this is a frame something else holds hidden.
local HIDDEN = 0.001

-- row: the setting that switches it. frames: names in the game, a dotted name reaching down from a global. hover: the frame whose rectangle
-- counts as under the mouse (the frames themselves when it is left out).
local ENTRIES = {
	{ bar = true, row = "main", label = "Main action bar", frames = { "MainActionBar" } },
	{ bar = true, row = "bar2", label = "Action bar 2", frames = { "MultiBarBottomLeft" } },
	{ bar = true, row = "bar3", label = "Action bar 3", frames = { "MultiBarBottomRight" } },
	{ bar = true, row = "bar4", label = "Action bar 4", frames = { "MultiBarRight" } },
	{ bar = true, row = "bar5", label = "Action bar 5", frames = { "MultiBarLeft" } },
	{ bar = true, row = "bar6", label = "Action bar 6", frames = { "MultiBar5" } },
	{ bar = true, row = "bar7", label = "Action bar 7", frames = { "MultiBar6" } },
	{ bar = true, row = "bar8", label = "Action bar 8", frames = { "MultiBar7" } },
	{ bar = true, row = "stance", label = "Stance bar", frames = { "StanceBar" } },
	{ bar = true, row = "pet", label = "Pet bar", frames = { "PetActionBar" } },
	{ bar = true, row = "micro", label = "Micro menu", frames = { "MicroMenuContainer" } },
	{ bar = true, row = "bags", label = "Bag bar", frames = { "BagsBar" } },
	{ row = "playerFrame", label = "Player frame", frames = { "PlayerFrame.PlayerFrameContainer", "PlayerFrame.PlayerFrameContent" }, hover = "PlayerFrame" },
	{ row = "petFrame", label = "Pet frame", frames = { "PetFrame" } },
	{ row = "minimapButtons", label = "Minimap buttons", hover = "MinimapCluster",
		frames = { "MinimapCluster.Tracking", "MinimapCluster.IndicatorFrame", "GameTimeFrame", "TimeManagerClockButton", "AddonCompartmentFrame" } },
}

-- bar: a game action bar, or a frame its layout hangs from (micro menu, bag bar). While Leave the game's action bars alone is on the row does nothing, and a bar this module faded is given its alpha back.
-- orig: the alpha a frame had before the first write. sent: the last alpha written. value: where the ease is. idle: seconds a row has had nothing to keep it
-- at full. found: the frames reached by name. clock: seconds since the last step.
local weak = { __mode = "k" }
local state = { orig = setmetatable({}, weak), sent = setmetatable({}, weak), value = setmetatable({}, weak), idle = {}, found = {}, clock = 0 }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True for a row of a game action bar that is left alone now.
local function Left(entry)
	return entry.bar == true and ns.HandsOff()
end

-- The frame behind a name, or nil while the game has not made it or it cannot be touched.
local function Resolve(name)
	local frame = state.found[name]
	if frame then
		return frame
	end
	local first, rest = name:match("^([^.]+)%.?(.*)$")
	local at = _G[first]
	for key in rest:gmatch("[^.]+") do
		if type(at) ~= "table" or ns.IsSecret(at) then
			return nil
		end
		local ok, child = pcall(function()
			return at[key]
		end)
		at = ok and child or nil
	end
	if type(at) == "table" and not ns.IsSecret(at) and not ns.Forbidden(at) and type(at.SetAlpha) == "function" then
		state.found[name] = at
		return at
	end
	return nil
end

local function Alpha(frame)
	local ok, alpha = pcall(frame.GetAlpha, frame)
	if ok and ns.Finite(alpha) then
		return alpha
	end
	return 1
end

-- A withheld answer counts as the frame being under the mouse, so that it stays shown.
local function Over(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and (ns.IsSecret(over) or over == true)
end

local function Holding()
	if type(GetCursorInfo) ~= "function" then
		return false
	end
	local ok, kind = pcall(GetCursorInfo)
	return ok and (ns.IsSecret(kind) or kind ~= nil)
end

local function FlyoutOpen()
	local flyout = _G.SpellFlyout
	if type(flyout) ~= "table" or ns.IsSecret(flyout) or ns.Forbidden(flyout) then
		return false
	end
	local ok, shown = pcall(flyout.IsShown, flyout)
	return ok and (ns.IsSecret(shown) or shown == true)
end

local function Fighting()
	if InCombatLockdown() then
		return true
	end
	if type(UnitAffectingCombat) ~= "function" then
		return false
	end
	local ok, fighting = pcall(UnitAffectingCombat, "player")
	return ok and (ns.IsSecret(fighting) or fighting == true)
end

local function HasTarget()
	if type(UnitExists) ~= "function" then
		return false
	end
	local ok, exists = pcall(UnitExists, "target")
	return ok and (ns.IsSecret(exists) or exists == true)
end

-- What keeps every row at full opacity, whatever the mouse does.
local function Wanted()
	return (Opt("combat") and Fighting()) or (Opt("target") and HasTarget()) or Holding() or FlyoutOpen() or ns.EditModeOpen()
end

-- The write. It raises when the game refuses, which ns.EachPart counts for the part.
local function Put(frame, alpha)
	if state.sent[frame] ~= alpha then
		frame:SetAlpha(alpha)
		state.sent[frame] = alpha
	end
	state.value[frame] = alpha
end

-- A frame goes back to the alpha it had, unless something else has set its own since.
local function Release(frame)
	local alpha = state.orig[frame]
	if alpha == nil then
		return
	end
	local sent = state.sent[frame]
	state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
	if sent ~= nil and math.abs(Alpha(frame) - sent) < 0.01 then
		pcall(frame.SetAlpha, frame, alpha)
	end
end

local function ReleaseAll()
	for frame in pairs(state.orig) do
		Release(frame)
	end
end

-- The alpha a frame had before this module wrote on it, for the action bar block, which takes over the bars it holds.
function ns.FadeGiven(frame)
	return state.orig[frame]
end

-- One frame toward the wanted alpha. A target of nil holds the frame where it is.
local function Ease(frame, target, step, name)
	-- A button the minimap page switches off stays off whatever Fading says.
	if ns.MapButtonOff and ns.MapButtonOff(frame) then
		state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
		return
	end
	if ns.BarBlockFades and ns.BarBlockFades(name) then
		Release(frame)
		return
	end
	local current = Alpha(frame)
	if state.orig[frame] == nil then
		if current <= HIDDEN then
			return
		end
		state.orig[frame], state.value[frame] = current, current
	elseif current <= HIDDEN and (state.sent[frame] == nil or state.sent[frame] > HIDDEN) then
		-- Something else hides it now.
		state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
		return
	end
	local value = state.value[frame]
	if target == nil then
		return
	elseif value < target then
		value = math.min(target, value + step)
	elseif value > target then
		value = math.max(target, value - step)
	end
	if value ~= (state.sent[frame] or state.orig[frame]) then
		ns.EachPart(KEY, PART, Put, frame, value)
	end
end

local function Step(dt)
	if ns.PartStopped(KEY, PART) then
		ReleaseAll()
		return
	end
	local floor, delay, seconds = Opt("alpha") / 100, Opt("delay") / 1000, math.max(Opt("time") / 1000, 0.05)
	local step = dt / seconds
	local always = Wanted()
	for _, entry in ipairs(ENTRIES) do
		local frames = entry.cache
		if not frames and Left(entry) then
			frames = {}
			for _, name in ipairs(entry.frames) do
				local frame = state.found[name]
				if frame then
					frames[#frames + 1] = { frame, name }
				end
			end
		elseif not frames then
			frames = {}
			for _, name in ipairs(entry.frames) do
				local frame = Resolve(name)
				if frame then
					frames[#frames + 1] = { frame, name }
				end
			end
			if #frames == #entry.frames then
				entry.cache = frames
			end
		end
		if Left(entry) or not Opt(entry.row) then
			for _, held in ipairs(frames) do
				Release(held[1])
			end
			state.idle[entry.row] = nil
		elseif #frames > 0 then
			local full = always
			if not full then
				local hover = entry.hover and Resolve(entry.hover)
				if hover then
					full = Over(hover)
				else
					for _, held in ipairs(frames) do
						if Over(held[1]) then
							full = true
							break
						end
					end
				end
			end
			local idle = full and 0 or (state.idle[entry.row] or 0) + dt
			state.idle[entry.row] = idle
			local target = full and 1 or (idle >= delay and floor or nil)
			for _, held in ipairs(frames) do
				Ease(held[1], target, step, held[2])
			end
		end
	end
end

-- The fight starts: every row with In combat ticked is at full opacity now, not after the ease. With In combat off a fight raises nothing.
local function FightStarts()
	if not Opt("combat") or ns.PartStopped(KEY, PART) then
		return
	end
	for _, entry in ipairs(ENTRIES) do
		if Opt(entry.row) and not Left(entry) then
			state.idle[entry.row] = 0
			for _, name in ipairs(entry.frames) do
				local frame = Resolve(name)
				if frame and state.orig[frame] ~= nil and state.value[frame] < 1 and not (ns.BarBlockFades and ns.BarBlockFades(name)) then
					ns.EachPart(KEY, PART, Put, frame, 1)
				end
			end
		end
	end
end

local driver

local function Tick(_, elapsed)
	state.clock = state.clock + elapsed
	if state.clock < EVERY then
		return
	end
	local dt = state.clock
	state.clock = 0
	ns.Try(KEY, Step, dt)
end

local function Refresh()
	if ns.Enabled(KEY) then
		if not driver then
			driver = CreateFrame("Frame")
			ns.Own[driver] = true
			driver:SetScript("OnUpdate", Tick)
		end
		driver:Show()
		Step(0)
	else
		if driver then
			driver:Hide()
		end
		ReleaseAll()
		state.idle = {}
	end
end

-- The lines of /flatui status: how many frames the module holds and fades, and the rows the game has no frame for.
local function Status()
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) then
		return {}
	end
	local held, faded = 0, 0
	for frame, original in pairs(state.orig) do
		held = held + 1
		if (state.sent[frame] or original) < original - 0.001 then
			faded = faded + 1
		end
	end
	local lines = { ("Fading: %d %s, %d faded"):format(held, held == 1 and "frame" or "frames", faded) }
	local missing = {}
	for _, entry in ipairs(ENTRIES) do
		if Opt(entry.row) and not Left(entry) then
			local any = false
			for _, name in ipairs(entry.frames) do
				any = any or Resolve(name) ~= nil
			end
			if not any then
				missing[#missing + 1] = entry.label
			end
		end
	end
	if #missing > 0 then
		lines[#lines + 1] = "Fading: no frame found for " .. table.concat(missing, ", ")
	end
	return lines
end

ns.Register(KEY, {
	label = "Fading",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	Status = Status,
	events = { PLAYER_REGEN_DISABLED = FightStarts },
})

-- /flatui status names a game action bar this module has faded in this session.
ns.ClickPathReporter(function()
	local names = {}
	for _, entry in ipairs(ENTRIES) do
		if entry.bar then
			for _, name in ipairs(entry.frames) do
				local frame = state.found[name]
				if frame ~= nil and state.orig[frame] ~= nil then
					names[#names + 1] = entry.label
				end
			end
		end
	end
	if #names > 0 then
		return "Click path: Flat UI faded " .. table.concat(names, ", ") .. "."
	end
	return nil
end)
