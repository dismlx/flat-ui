local _, ns = ...

local KEY = "fade"
local PART = "fade"
local EVERY = 0.05
local RETURN_TIME = 0.1
local HIDDEN = 0.001

local METER_PARTS = {}
for index = 1, 3 do
	METER_PARTS[#METER_PARTS + 1] = "DamageMeterSessionWindow" .. index
	METER_PARTS[#METER_PARTS + 1] = "DamageMeterSessionWindow" .. index .. ".MinimizeContainer.SourceWindow"
end
local function PlayerPieces()
	local extra = ns.UnitFrameExtra
	if type(extra) == "table" and type(extra.pieces) == "function" then
		return extra.pieces("player")
	end
	return nil
end
local MICRO_BUTTONS = { "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton", "LegacyMicroButton",
	"QuestLogMicroButton", "HousingMicroButton", "GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton", "EJMicroButton", "HelpMicroButton",
	"StoreMicroButton", "MainMenuMicroButton", "HelpOpenWebTicketButton" }
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "BagBarExpandToggle", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
	"CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton" }
local XP_BAR = "FlatUIXpBar"
local function XpBarFrames()
	if type(ns.XpOwn) ~= "function" or type(ns.XpBarFrame) ~= "function" or not ns.XpOwn() then
		return nil
	end
	local frame = ns.XpBarFrame()
	return frame ~= nil and { { frame = frame, name = XP_BAR } } or nil
end
local function XpBarBusy()
	return type(ns.XpBarLively) == "function" and ns.XpBarLively() == true
end
local QUESTIE = "Questie_BaseFrame"
local function QuestieFrame()
	local base = rawget(_G, QUESTIE)
	if type(base) ~= "table" or ns.IsSecret(base) or ns.Forbidden(base) then
		return nil
	end
	return base
end
local function QuestieTracker()
	local base = QuestieFrame()
	return base ~= nil and { { frame = base, name = QUESTIE } } or nil
end
local BAG_WINDOWS = { "FlatUIBags", "FlatUIBank", "ContainerFrameCombinedBags", "BankFrame" }
for index = 1, 7 do
	BAG_WINDOWS[#BAG_WINDOWS + 1] = "ContainerFrame" .. index
end
local WINDOWS_ROW = { row = "bagWindows", label = "Bag windows", frames = {}, opens = true }
local ENTRIES = {
	{ bar = true, row = "main", label = "Main action bar", frames = { "MainActionBar" }, beside = { "FlatUIBar1PageUp", "FlatUIBar1PageDown", "FlatUIBar1PageNumber" }, alpha = "barsAlpha" },
	{ bar = true, row = "bar2", label = "Action bar 2", frames = { "MultiBarBottomLeft" }, alpha = "barsAlpha" },
	{ bar = true, row = "bar3", label = "Action bar 3", frames = { "MultiBarBottomRight" }, alpha = "barsAlpha" },
	{ bar = true, row = "bar4", label = "Action bar 4", frames = { "MultiBarRight" }, alpha = "barsAlpha" },
	{ bar = true, row = "bar5", label = "Action bar 5", frames = { "MultiBarLeft" }, alpha = "barsAlpha" },
	{ bar = true, row = "bar6", label = "Action bar 6", frames = { "MultiBar5" }, alpha = "barsAlpha" },
	{ bar = true, row = "bar7", label = "Action bar 7", frames = { "MultiBar6" }, alpha = "barsAlpha" },
	{ bar = true, row = "bar8", label = "Action bar 8", frames = { "MultiBar7" }, alpha = "barsAlpha" },
	{ bar = true, row = "stance", label = "Stance bar", frames = { "StanceBar" }, alpha = "barsAlpha" },
	{ bar = true, row = "pet", label = "Pet bar", frames = { "PetActionBar" }, alpha = "barsAlpha" },
	{ row = "micro", label = "Micro menu", frames = { "MicroMenuContainer" }, beside = MICRO_BUTTONS, alpha = "microAlpha" },
	{ row = "bags", label = "Bag bar", frames = { "BagsBar" }, beside = BAG_BUTTONS, alpha = "bagsAlpha" },
	WINDOWS_ROW,
	{ row = "playerFrame", label = "Player frame", frames = { "PlayerFrame.PlayerFrameContainer", "PlayerFrame.PlayerFrameContent" }, hover = "PlayerFrame",
		more = PlayerPieces },
	{ row = "petFrame", label = "Pet frame", frames = { "PetFrame" } },
	{ row = "xpBar", label = "Experience bar", frames = {}, more = XpBarFrames, busy = XpBarBusy },
	{ row = "minimapButtons", label = "Minimap buttons", hover = "MinimapCluster", more = "MapAddonButtons",
		frames = { "MinimapCluster.Tracking", "MinimapCluster.IndicatorFrame", "GameTimeFrame", "TimeManagerClockButton", "AddonCompartmentFrame" } },
	{ rule = true, targeted = true, row = "targetFrame", label = "Target frame", frames = { "TargetFrame" } },
	{ rule = true, row = "focusFrame", label = "Focus frame", frames = { "FocusFrame" } },
	{ rule = true, row = "buffs", label = "Buffs", frames = { "BuffFrame" } },
	{ rule = true, row = "objectiveTracker", label = "Objective tracker", frames = { "ObjectiveTrackerFrame" }, hover = "ObjectiveTrackerFrame.NineSlice",
		more = QuestieTracker },
	{ rule = true, row = "damageMeter", label = "Damage meter", frames = { "DamageMeter" }, beside = METER_PARTS },
}
local TRAVEL_FORMS = { [3] = true, [4] = true, [27] = true }

local weak = { __mode = "k" }
local state = { orig = setmetatable({}, weak), sent = setmetatable({}, weak), value = setmetatable({}, weak), idle = {}, found = {}, clock = 0,
	added = setmetatable({}, weak) }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function OwnRow(entry)
	if entry.bar ~= true or type(entry.more) ~= "function" or type(ns.OwnOn) ~= "function" then
		return false
	end
	local ok, on = pcall(ns.OwnOn)
	return ok and on == true
end

local function Left(entry)
	return entry.bar == true and ns.HandsOff() and not OwnRow(entry)
end

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
		return alpha, true
	end
	return 1, false
end

local Gone
local function Over(frame)
	if Gone(frame) then
		return false
	end
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

local CAST_HOLD = 1.5
local CAST_READS = { "UnitCastingInfo", "UnitChannelInfo" }
local function Casting()
	if state.castAt and GetTime() - state.castAt < CAST_HOLD then
		return true
	end
	for _, name in ipairs(CAST_READS) do
		local read = _G[name]
		if type(read) == "function" then
			local ok, spell = pcall(read, "player")
			if ok and not ns.IsSecret(spell) and type(spell) == "string" then
				return true
			end
		end
	end
	return false
end

local function Below(value, most)
	return ns.Finite(value) and ns.Finite(most) and most > 0 and value < most
end

local function Hurt()
	local okDead, dead = pcall(UnitIsDeadOrGhost, "player")
	if not okDead or ns.IsSecret(dead) or dead == true then
		return false
	end
	local okHealth, health = pcall(UnitHealth, "player")
	local okMost, most = pcall(UnitHealthMax, "player")
	if okHealth and okMost and Below(health, most) then
		return true
	end
	local okMana, mana = pcall(UnitPower, "player", 0)
	local okPool, pool = pcall(UnitPowerMax, "player", 0)
	return okMana and okPool and Below(mana, pool)
end

local function MoversOpen()
	local kit = ns.MoverKit
	return type(kit) == "table" and type(kit.IsOpen) == "function" and kit.IsOpen() == true
end

local PREVIEWS = { "ButtonStatesPreviewing", "ButtonEffectsPreviewing", "ProcPreviewing" }
local function Previewing()
	for _, name in ipairs(PREVIEWS) do
		local ask = ns[name]
		if type(ask) == "function" and ask() == true then
			return true
		end
	end
	return false
end

local HOLD_KEYS = { shift = "IsShiftKeyDown", ctrl = "IsControlKeyDown", alt = "IsAltKeyDown" }
local function KeyHeld()
	local name = HOLD_KEYS[Opt("holdKey")]
	local ask = name and rawget(_G, name)
	if type(ask) ~= "function" then
		return false
	end
	local ok, down = pcall(ask)
	if not ok or ns.IsSecret(down) or down ~= true then
		return false
	end
	if type(GetCurrentKeyBoardFocus) == "function" then
		local okFocus, focus = pcall(GetCurrentKeyBoardFocus)
		if okFocus and (ns.IsSecret(focus) or focus ~= nil) then
			return false
		end
	end
	return true
end

function ns.FadeKeyHeld()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and KeyHeld()
end

local function Wanted()
	return (Opt("combat") and Fighting()) or Holding() or FlyoutOpen() or ns.EditModeOpen() or MoversOpen()
		or (Opt("cast") == true and Casting()) or (Opt("hurt") == true and Hurt()) or KeyHeld()
end

local function Grouped()
	if type(IsInGroup) ~= "function" then
		return false
	end
	local ok, grouped = pcall(IsInGroup)
	return ok and (ns.IsSecret(grouped) or grouped == true)
end

local function Inside()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, inside = pcall(IsInInstance)
	return ok and (ns.IsSecret(inside) or inside == true)
end

local function Outside()
	if type(IsInInstance) ~= "function" then
		return true
	end
	local ok, inside = pcall(IsInInstance)
	return not (ok and not ns.IsSecret(inside) and inside == true)
end

local function Unmounted()
	if type(IsMounted) == "function" then
		local ok, mounted = pcall(IsMounted)
		if ok and not ns.IsSecret(mounted) and mounted == true then
			return false
		end
	end
	if type(GetShapeshiftFormID) == "function" then
		local ok, form = pcall(GetShapeshiftFormID)
		if ok and ns.Finite(form) and TRAVEL_FORMS[form] then
			return false
		end
	end
	return true
end

local RULES = { combat = Fighting, group = Grouped, instance = Inside, outside = Outside, unmounted = Unmounted }
local asked = {}

local function Holds(rule)
	local answer = asked[rule]
	if answer == nil then
		answer = RULES[rule]() == true
		asked[rule] = answer
	end
	return answer
end

local function Active(entry)
	local value = Opt(entry.row)
	if entry.rule then
		return RULES[value] ~= nil
	end
	return value == true
end

local function Elsewhere(frame, name)
	return (name ~= nil and ns.BarBlockFades and ns.BarBlockFades(name)) or (ns.TrackerFades and ns.TrackerFades(frame))
		or (ns.QuestieFades and ns.QuestieFades(frame)) or false
end

function Gone(frame)
	local hide = ns.HideFrames
	return type(hide) == "table" and type(hide.Holds) == "function" and hide.Holds(frame) == true
end

local function Put(frame, alpha)
	if state.sent[frame] ~= alpha then
		frame:SetAlpha(alpha)
		state.sent[frame] = alpha
	end
	state.value[frame] = alpha
end

local function Release(frame)
	local alpha = state.orig[frame]
	if alpha == nil then
		return
	end
	local sent = state.sent[frame]
	state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
	if sent ~= nil and not Gone(frame) and math.abs(Alpha(frame) - sent) < 0.01 then
		pcall(frame.SetAlpha, frame, alpha)
	end
end

local function ReleaseAll()
	for frame in pairs(state.orig) do
		Release(frame)
	end
	state.added = setmetatable({}, weak)
end

local function Under(frame, root)
	local at = frame
	for _ = 1, 20 do
		if at == root then
			return true
		elseif type(at) ~= "table" or ns.IsSecret(at) or ns.Forbidden(at) then
			return false
		end
		local ok, parent = pcall(at.GetParent, at)
		if not ok then
			return false
		end
		at = parent
	end
	return false
end

function ns.FadeLetGo(root)
	if root == nil then
		return
	end
	for frame in pairs(state.orig) do
		if Under(frame, root) then
			Release(frame)
		end
	end
end

local function Forget(row, keep)
	for frame, owner in pairs(state.added) do
		if owner == row and not (keep and keep[frame]) then
			state.added[frame] = nil
			Release(frame)
		end
	end
end

local function Added(entry)
	local list, listed, fresh = {}, {}, false
	local fn = entry.more
	if type(fn) ~= "function" then
		fn = ns[fn]
	end
	if type(fn) == "function" then
		local ok, found = pcall(fn)
		if ok and type(found) == "table" then
			for _, each in ipairs(found) do
				local frame = type(each) == "table" and each.frame or nil
				if frame ~= nil and not listed[frame] and not ns.Forbidden(frame) and type(frame.SetAlpha) == "function" then
					listed[frame] = true
					list[#list + 1] = { frame, each.name }
				end
			end
		end
	end
	Forget(entry.row, listed)
	for frame in pairs(listed) do
		fresh = fresh or state.added[frame] ~= entry.row
		state.added[frame] = entry.row
	end
	return list, fresh
end

local function Shown(frame)
	local ok, shown = pcall(frame.IsVisible, frame)
	return ok and (ns.IsSecret(shown) or shown == true)
end

local function BagWindows()
	local list = {}
	for _, name in ipairs(BAG_WINDOWS) do
		local frame = Resolve(name)
		if frame and Shown(frame) then
			list[#list + 1] = { frame = frame, name = name }
		end
	end
	return list
end

local function WindowsBusy(added)
	local split = Resolve("StackSplitFrame")
	if split and Shown(split) then
		return true
	end
	if type(GetCurrentKeyBoardFocus) ~= "function" or added == nil or #added == 0 then
		return false
	end
	local ok, at = pcall(GetCurrentKeyBoardFocus)
	if not ok or at == nil then
		return false
	elseif ns.IsSecret(at) then
		return true
	end
	local windows = {}
	for _, held in ipairs(added) do
		windows[held[1]] = true
	end
	for _ = 1, 20 do
		if ns.Forbidden(at) then
			return false
		elseif windows[at] then
			return true
		end
		local okParent, parent = pcall(at.GetParent, at)
		if not okParent then
			return false
		end
		at = parent
	end
	return false
end
WINDOWS_ROW.more, WINDOWS_ROW.busy = BagWindows, WindowsBusy

for _, entry in ipairs(ENTRIES) do
	local game = entry.bar and entry.row ~= "stance" and entry.row ~= "pet" and entry.frames[1] or nil
	if game then
		entry.more = function()
			if type(ns.OwnOn) ~= "function" or type(ns.OwnBarOf) ~= "function" then
				return nil
			end
			local okOn, on = pcall(ns.OwnOn)
			if not (okOn and on == true) then
				return nil
			end
			local okBar, own = pcall(ns.OwnBarOf, game)
			if okBar and own then
				return { { frame = own, name = game } }
			end
			return nil
		end
	end
end

local function Beside(names)
	for _, name in ipairs(names) do
		local frame = Resolve(name)
		if frame then
			local ok, shown = pcall(frame.IsVisible, frame)
			if ok and (ns.IsSecret(shown) or shown == true) and Over(frame) then
				return true
			end
		end
	end
	return false
end

function ns.FadeGiven(frame)
	return state.orig[frame]
end

function ns.FadeTakesBack(frame, alpha)
	if frame == nil or not ns.Finite(alpha) or alpha <= HIDDEN or not ns.Enabled(KEY) or ns.PartStopped(KEY, PART)
		or RULES[Opt("objectiveTracker")] == nil then
		return false
	end
	local questie = frame == QuestieFrame()
	if not questie and frame ~= Resolve("ObjectiveTrackerFrame") then
		return false
	end
	local current = Alpha(frame)
	state.orig[frame], state.value[frame], state.sent[frame] = alpha, current, current
	if questie then
		state.added[frame] = "objectiveTracker"
	end
	return true
end

local function Ease(frame, target, step, name)
	if Gone(frame) then
		state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
		return
	end
	if (ns.MapButtonOff and ns.MapButtonOff(frame)) or (ns.TrackerFades and ns.TrackerFades(frame)) or (ns.QuestieFades and ns.QuestieFades(frame)) then
		state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
		return
	end
	if ns.BarBlockFades and ns.BarBlockFades(name) then
		Release(frame)
		return
	end
	local current, known = Alpha(frame)
	if state.orig[frame] == nil then
		if current <= HIDDEN then
			return
		end
		state.orig[frame], state.value[frame] = current, current
	elseif current <= HIDDEN and (state.sent[frame] == nil or state.sent[frame] >= 0.01) then
		state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
		return
	elseif known and state.sent[frame] ~= nil and math.abs(current - state.sent[frame]) >= 0.01 then
		state.orig[frame], state.value[frame], state.sent[frame] = current, current, nil
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

local function RowFloor(entry, floor)
	local own = entry.alpha and tonumber(Opt(entry.alpha))
	if ns.Finite(own) then
		return math.min(math.max(own, 0), 100) / 100
	end
	return floor
end

local function FramesFor(entry)
	local frames = entry.cache
	if OwnRow(entry) then
		frames = {}
		for _, name in ipairs(entry.frames) do
			local frame = state.found[name]
			if frame and state.orig[frame] ~= nil then
				Release(frame)
			end
		end
	elseif not frames and Left(entry) then
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
	return frames
end

local function Hovered(entry, frames, added)
	local over = false
	local hover = entry.hover and Resolve(entry.hover)
	if hover then
		over = Over(hover)
	else
		for _, held in ipairs(frames) do
			if Over(held[1]) then
				over = true
				break
			end
		end
	end
	for _, held in ipairs(not over and added or {}) do
		if Over(held[1]) then
			over = true
			break
		end
	end
	if not over and entry.beside then
		over = Beside(entry.beside)
	end
	return over
end

local function BarsOver(early)
	local any = false
	for _, entry in ipairs(ENTRIES) do
		if entry.bar == true then
			local frames = FramesFor(entry)
			local live = not Left(entry) and Active(entry) and (#frames > 0 or entry.more ~= nil)
			local added = live and entry.more and Added(entry) or nil
			early[entry] = { frames, added }
			if live and not any and not (ns.BarBlockFades and ns.BarBlockFades(entry.frames[1])) and Hovered(entry, frames, added) then
				any = true
			end
		end
	end
	return any
end

local function Step(dt)
	if ns.PartStopped(KEY, PART) then
		state.barsOver = false
		ReleaseAll()
		return
	end
	local floor, delay, seconds = Opt("alpha") / 100, Opt("delay") / 1000, math.max(Opt("time") / 1000, 0.05)
	local step = dt / seconds
	local up = dt / math.min(seconds, RETURN_TIME)
	local always, targeted = Wanted(), Opt("target") and HasTarget()
	local procs, shown = Opt("proc") == true and type(ns.ProcUpOn) == "function", Previewing()
	local together, early = Opt("barsTogether") == true, {}
	for rule in pairs(asked) do
		asked[rule] = nil
	end
	local anyBar = together and BarsOver(early)
	for _, entry in ipairs(ENTRIES) do
		local seen = early[entry]
		local frames = seen and seen[1] or FramesFor(entry)
		if Left(entry) or not Active(entry) then
			for _, held in ipairs(frames) do
				Release(held[1])
			end
			if entry.more then
				Forget(entry.row)
			end
			state.idle[entry.row] = nil
		elseif #frames > 0 or entry.more then
			local added, fresh = nil, false
			if seen then
				added = seen[2]
			elseif entry.more then
				added, fresh = Added(entry)
			end
			local full = always or (targeted and not entry.targeted) or (entry.rule == true and Holds(Opt(entry.row)))
				or (entry.opens == true and fresh) or (entry.busy ~= nil and entry.busy(added) == true)
				or (entry.bar == true and (shown or (together and anyBar) or (procs and ns.ProcUpOn(entry.frames[1]) == true)))
			if not full then
				full = Hovered(entry, frames, added)
			end
			local idle = full and 0 or (state.idle[entry.row] or 0) + dt
			state.idle[entry.row] = idle
			local target = full and 1 or (idle >= delay and RowFloor(entry, floor) or nil)
			local by = target == 1 and up or step
			for _, held in ipairs(frames) do
				Ease(held[1], target, by, held[2])
			end
			for _, held in ipairs(added or {}) do
				Ease(held[1], target, by, held[2])
			end
		end
	end
	state.barsOver = anyBar == true
end

local function FightStarts()
	if ns.PartStopped(KEY, PART) then
		return
	end
	local combat = Opt("combat") == true
	for _, entry in ipairs(ENTRIES) do
		if Active(entry) and not Left(entry) and (combat or (entry.rule and Opt(entry.row) == "combat")) then
			state.idle[entry.row] = 0
			for _, name in ipairs(entry.frames) do
				local frame = Resolve(name)
				if frame and state.orig[frame] ~= nil and state.value[frame] < 1 and not Elsewhere(frame, name) and not Gone(frame) then
					ns.EachPart(KEY, PART, Put, frame, 1)
				end
			end
			for frame, owner in pairs(state.added) do
				if owner == entry.row and state.orig[frame] ~= nil and state.value[frame] < 1 and not Elsewhere(frame) and not Gone(frame) then
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
			for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED" }) do
				pcall(driver.RegisterUnitEvent, driver, event, "player")
			end
			driver:SetScript("OnEvent", function()
				state.castAt = GetTime()
			end)
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
		if Active(entry) and not Left(entry) and #entry.frames > 0 then
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
