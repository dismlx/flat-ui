local _, ns = ...

local KEY = "hide"
local PART = "hidden frames"
local EVERY = 0.25
local WAITS = "Flat UI: hidden frames change when the fight ends."

local ENTRIES = {
	{ key = "main", bar = true, frames = { "MainActionBar" } },
	{ key = "bar2", bar = true, frames = { "MultiBarBottomLeft" } },
	{ key = "bar3", bar = true, frames = { "MultiBarBottomRight" } },
	{ key = "bar4", bar = true, frames = { "MultiBarRight" } },
	{ key = "bar5", bar = true, frames = { "MultiBarLeft" } },
	{ key = "bar6", bar = true, frames = { "MultiBar5" } },
	{ key = "bar7", bar = true, frames = { "MultiBar6" } },
	{ key = "bar8", bar = true, frames = { "MultiBar7" } },
	{ key = "stance", bar = true, frames = { "StanceBar" } },
	{ key = "pet", bar = true, frames = { "PetActionBar" } },
	{ key = "possess", bar = true, frames = { "PossessActionBar" } },
	{ key = "totem", bar = true, frames = { "MultiCastActionBarFrame" } },
	{ key = "vehicleLeave", bar = true, frames = { "MainMenuBarVehicleLeaveButton" } },
	{ key = "micro", frames = { "MicroMenu" }, box = "MicroMenuContainer" },
	{ key = "bagBar", frames = { "BagsBar" } },
	{ key = "xpBar", bar = true, frames = { "MainStatusTrackingBarContainer" } },
	{ key = "statusBar", bar = true, frames = { "SecondaryStatusTrackingBarContainer" } },
	{ key = "playerFrame", frames = { "PlayerFrame" } },
	{ key = "targetFrame", frames = { "TargetFrame" } },
	{ key = "focusFrame", frames = { "FocusFrame" } },
	{ key = "petFrame", frames = { "PetFrame" } },
	{ key = "partyFrames", frames = { "PartyFrame" } },
	{ key = "raidFrames", frames = { "CompactRaidFrameContainer" } },
	{ key = "bossFrames", frames = { "BossTargetFrameContainer" } },
	{ key = "minimap", frames = { "MinimapCluster" } },
	{ key = "mapZone", frames = { "MinimapCluster.ZoneTextButton" } },
	{ key = "mapTracking", frames = { "MinimapCluster.Tracking" } },
	{ key = "mapMail", frames = { "MinimapCluster.IndicatorFrame" } },
	{ key = "mapCalendar", frames = { "GameTimeFrame" } },
	{ key = "mapClock", frames = { "TimeManagerClockButton" } },
	{ key = "mapAddons", frames = { "AddonCompartmentFrame" } },
	{ key = "mapZoom", frames = { "Minimap.ZoomIn", "Minimap.ZoomOut" } },
	{ key = "buffs", frames = { "BuffFrame" } },
	{ key = "debuffs", frames = { "DebuffFrame" } },
	{ key = "externals", frames = { "ExternalDefensivesFrame" } },
	{ key = "castBar", frames = { "PlayerCastingBarFrame" } },
	{ key = "resource", frames = { "PersonalResourceDisplayFrame" } },
	{ key = "swingMain", frames = { "SwingTimerMainHandFrame" } },
	{ key = "swingOff", frames = { "SwingTimerOffHandFrame" } },
	{ key = "swingRanged", frames = { "SwingTimerRangedFrame" } },
	{ key = "mirrorTimers", frames = { "MirrorTimerContainer" } },
	{ key = "encounterBar", frames = { "EncounterBar" } },
	{ key = "durability", frames = { "DurabilityFrame" } },
	{ key = "archaeology", frames = { "ArcheologyDigsiteProgressBar" } },
	{ key = "alerts", toasts = true, frames = { "AlertFrame" } },
	{ key = "errors", frames = { "UIErrorsFrame" } },
	{ key = "zoneText", frames = { "ZoneTextFrame", "SubZoneTextFrame" } },
	{ key = "raidWarning", frames = { "RaidWarningFrame" } },
	{ key = "lossOfControl", frames = { "LossOfControlFrame" } },
	{ key = "talkingHead", frames = { "TalkingHeadFrame" } },
	{ key = "topWidgets", frames = { "UIWidgetTopCenterContainerFrame" } },
	{ key = "tracker", frames = { "ObjectiveTrackerFrame" } },
	{ key = "damageMeter", frames = { "DamageMeter" } },
	{ key = "queue", frames = { "QueueStatusButton" } },
	{ key = "extraAbilities", frames = { "ExtraAbilityContainer" } },
	{ key = "vehicleSeats", frames = { "VehicleSeatIndicator" } },
	{ key = "essential", frames = { "EssentialCooldownViewer" } },
	{ key = "utility", frames = { "UtilityCooldownViewer" } },
	{ key = "trackedBuffs", frames = { "BuffIconCooldownViewer" } },
	{ key = "trackedBars", frames = { "BuffBarCooldownViewer" } },
}

local BY_NAME = {}
for _, entry in ipairs(ENTRIES) do
	if entry.box and BY_NAME[entry.box] == nil then
		BY_NAME[entry.box] = entry
	end
	for _, name in ipairs(entry.frames) do
		if not name:find(".", 1, true) and BY_NAME[name] == nil then
			BY_NAME[name] = entry
		end
	end
end
local BY_KEY = {}
for _, entry in ipairs(ENTRIES) do
	BY_KEY[entry.key] = entry
end

local state = { held = {}, found = {}, told = false, waiting = false, clock = 0, toasts = setmetatable({}, { __mode = "k" }) }
local SNIPPET_HOLD = [[
	local f = self:GetFrameRef("f")
	if f then f:SetParent(self) end
]]
local SNIPPET_SHOWN = [[
	local f = self:GetFrameRef("f")
	if not f then return end
	if self:GetAttribute("show") then f:Show(true) else f:Hide(true) end
]]
local SNIPPET_BACK = [[
	local f, p = self:GetFrameRef("f"), self:GetFrameRef("p")
	if not (f and p) then return end
	local shown = self:GetAttribute("show")
	if shown then f:Hide(true) end
	f:SetParent(p)
	local strata, level = self:GetAttribute("strata"), self:GetAttribute("level")
	if strata and f:GetFrameStrata() ~= strata then f:SetFrameStrata(strata) end
	if level and f:GetFrameLevel() ~= level then f:SetFrameLevel(level) end
	if shown then f:Show(true) end
]]
local SNIPPET_FILL = [[
	self:ClearAllPoints()
	self:SetAllPoints("$parent")
]]

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Methods()
	if state.methods == nil then
		local ok, meta = pcall(GetFrameMetatable)
		state.methods = ok and type(meta) == "table" and type(meta.__index) == "table" and meta.__index or false
	end
	return state.methods or nil
end

local function Read(method, frame)
	local methods = Methods()
	if not (methods and type(methods[method]) == "function") then
		return nil
	end
	local ok, value = pcall(methods[method], frame)
	if not ok or ns.IsSecret(value) then
		return nil
	end
	return value
end

local function Call(method, frame, ...)
	local methods = Methods()
	return methods ~= nil and type(methods[method]) == "function" and (pcall(methods[method], frame, ...))
end

local function Holder()
	if state.holder ~= nil then
		return state.holder or nil
	end
	if InCombatLockdown() then
		return nil
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
	if ok and type(frame) == "table" and not ns.IsSecret(frame) then
		ns.Own[frame] = true
		frame:Hide()
		frame:SetAllPoints(UIParent)
		state.holder = frame
	else
		state.holder = false
	end
	return state.holder or nil
end

local function Protected(frame)
	return Read("IsProtected", frame) == true
end

local function Explicit(frame)
	local methods = Methods()
	if type(frame) ~= "table" or not (methods and type(methods.IsProtected) == "function") then
		return false
	end
	local ok, _, explicit = pcall(methods.IsProtected, frame)
	return ok and not ns.IsSecret(explicit) and explicit == true
end

local function Returner()
	if state.returner ~= nil then
		return state.returner or nil
	end
	if InCombatLockdown() then
		return nil
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
	if ok and type(frame) == "table" and not ns.IsSecret(frame) and pcall(frame.Execute, frame, SNIPPET_FILL) then
		ns.Own[frame] = true
		state.returner = frame
	else
		state.returner = false
	end
	return state.returner or nil
end

local function Snippet(frame, body, show, back)
	local holder = not InCombatLockdown() and not state.inside and Holder()
	if not holder then
		return false
	end
	state.inside = true
	local ok = pcall(function()
		holder:SetFrameRef("f", frame)
		holder:SetAttribute("show", show == true or nil)
		if back then
			holder:SetFrameRef("p", back.parent)
			holder:SetAttribute("strata", back.strata)
			holder:SetAttribute("level", back.level)
		end
		holder:Execute(body)
	end)
	state.inside = false
	return ok
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
	if type(at) == "table" and not ns.IsSecret(at) and not ns.Forbidden(at) and at ~= UIParent then
		state.found[name] = at
		return at
	end
	return nil
end

local function Wait()
	state.waiting = true
	if not state.told then
		state.told = true
		print(WAITS)
	end
end

local function Hold(frame, key)
	local holder = Holder()
	local parent = Read("GetParent", frame)
	if holder and parent == holder then
		if state.held[frame] then
			state.held[frame].stuck = nil
		end
		return
	elseif InCombatLockdown() then
		Wait()
		return
	elseif not (holder and parent) then
		return
	end
	local record = { parent = parent, strata = Read("GetFrameStrata", frame), level = Read("GetFrameLevel", frame), key = key }
	if type(ns.FadeLetGo) == "function" then
		pcall(ns.FadeLetGo, frame)
	end
	if Snippet(frame, SNIPPET_HOLD) and Read("GetParent", frame) == holder then
		state.held[frame] = record
	end
end

local function PutBack(frame, record, shown)
	if shown then
		Snippet(frame, SNIPPET_SHOWN, false)
	end
	if not (Call("SetParent", frame, record.parent) and Read("GetParent", frame) == record.parent) then
		return false
	end
	if record.strata and Read("GetFrameStrata", frame) ~= record.strata then
		Call("SetFrameStrata", frame, record.strata)
	end
	if ns.Finite(record.level) and Read("GetFrameLevel", frame) ~= record.level then
		Call("SetFrameLevel", frame, record.level)
	end
	if shown then
		Snippet(frame, SNIPPET_SHOWN, true)
	end
	return true
end

local function Release(frame)
	local record = state.held[frame]
	if not record or record.stuck then
		return
	elseif InCombatLockdown() then
		Wait()
		return
	end
	local holder = Holder()
	if not (holder and Read("GetParent", frame) == holder) then
		state.held[frame] = nil
		return
	end
	local shown = Read("IsShown", frame) == true
	local done
	if Protected(frame) then
		local parent = Explicit(record.parent) and record.parent or Returner()
		local back = { parent = parent, strata = record.strata, level = ns.Finite(record.level) and record.level or nil }
		done = parent ~= nil and Snippet(frame, SNIPPET_BACK, shown, back) and Read("GetParent", frame) == parent
	else
		done = PutBack(frame, record, shown)
	end
	if done then
		state.held[frame] = nil
	else
		record.stuck = true
		print(("Flat UI: %s could not be shown again. It comes back after a reload (/reload)."):format(ns.HideFrames.Label(record.key)))
	end
end

local function HoldToasts()
	if not state.toastsOn or state.inside or InCombatLockdown() or not Holder() then
		return
	end
	for _ = 1, 8 do
		local due = {}
		for toast in pairs(state.toasts) do
			if Read("IsShown", toast) == true and Read("GetParent", toast) ~= state.holder then
				due[#due + 1] = toast
			end
		end
		if #due == 0 then
			return
		end
		for _, toast in ipairs(due) do
			Snippet(toast, SNIPPET_HOLD)
		end
	end
end

local function AfterAlert(_, toast)
	if type(toast) == "table" and not ns.IsSecret(toast) and not ns.Forbidden(toast) then
		state.toasts[toast] = true
		HoldToasts()
	end
end

local function Wanted(entry)
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Opt(entry.key) == true and not (entry.bar and ns.HandsOff())
end

local function LaidOut(entry)
	local box = entry.box and Resolve(entry.box)
	if not entry.box then
		return true
	elseif not box then
		return false
	end
	local width, height = Read("GetWidth", box), Read("GetHeight", box)
	return ns.Finite(width) and ns.Finite(height) and width > 1 and height > 1
end

local function Apply()
	local any = false
	local wanted = {}
	for _, entry in ipairs(ENTRIES) do
		local on = Wanted(entry)
		any = any or on
		for _, name in ipairs(entry.frames) do
			local frame = Resolve(name)
			if frame and on and (state.held[frame] or LaidOut(entry)) then
				wanted[frame] = true
				ns.EachPart(KEY, PART, Hold, frame, entry.key)
			end
		end
	end
	state.toastsOn = Wanted(BY_KEY.alerts)
	if state.toastsOn then
		if not state.followed and type(AlertFrame) == "table" then
			state.followed = ns.Follow(AlertFrame, "AddAlertFrame", AfterAlert) == true
		end
		HoldToasts()
	end
	for frame in pairs(state.held) do
		if not wanted[frame] and not pcall(Release, frame) then
			state.held[frame] = nil
		end
	end
	return any or next(state.held) ~= nil
end

local driver = CreateFrame("Frame")
ns.Own[driver] = true
driver:Hide()

local function Run()
	state.waiting = false
	local busy = Apply()
	driver:SetShown(busy or state.waiting)
end

local function Step()
	if ns.IsStopped(KEY) then
		pcall(Run)
	else
		ns.Try(KEY, Run)
	end
end

driver:SetScript("OnUpdate", function(_, elapsed)
	state.clock = state.clock + elapsed
	if state.clock < EVERY then
		return
	end
	state.clock = 0
	if not InCombatLockdown() then
		Step()
	end
end)
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		state.told = false
	elseif state.waiting or next(state.held) ~= nil then
		Step()
	end
end)

local function Refresh()
	Run()
end

local function Status()
	local count = 0
	for _ in pairs(state.held) do
		count = count + 1
	end
	local lines = {}
	if count > 0 or ns.Enabled(KEY) then
		lines[1] = ("Hidden frames: %d %s hidden"):format(count, count == 1 and "frame" or "frames")
	end
	if state.waiting then
		lines[#lines + 1] = "Hidden frames: a change waits for the end of the fight"
	end
	local stuck = 0
	for _, record in pairs(state.held) do
		stuck = stuck + (record.stuck and 1 or 0)
	end
	if stuck > 0 then
		lines[#lines + 1] = ("Hidden frames: %d unticked %s come back after a reload"):format(stuck, stuck == 1 and "frame" or "frames")
	end
	local missing = {}
	for _, entry in ipairs(ENTRIES) do
		if Wanted(entry) then
			local any = false
			for _, name in ipairs(entry.frames) do
				any = any or Resolve(name) ~= nil
			end
			if not any then
				missing[#missing + 1] = ns.HideFrames.Label(entry.key)
			end
		end
	end
	if #missing > 0 then
		lines[#lines + 1] = "Hidden frames: no frame found for " .. table.concat(missing, ", ")
	end
	return lines
end

local H = {}
ns.HideFrames = H

function H.Label(key)
	if not state.labels then
		state.labels = {}
		for _, page in ipairs(ns.PAGES) do
			if page.key == KEY then
				for _, item in ipairs(page) do
					if item.key then
						state.labels[item.key] = item.label
					end
				end
			end
		end
	end
	return state.labels[key] or key
end

function H.Key(name)
	local entry = type(name) == "string" and BY_NAME[name] or nil
	return entry and entry.key or nil
end

function H.Left(key)
	local entry = BY_KEY[key]
	return entry ~= nil and entry.bar == true and ns.HandsOff()
end

function H.Hidden(key)
	return BY_KEY[key] ~= nil and ns.Enabled(KEY) and Opt(key) == true and not H.Left(key)
end

function H.Holds(frame)
	local holder = state.holder
	if not holder or next(state.held) == nil or type(frame) ~= "table" then
		return false
	end
	local at = frame
	for _ = 1, 20 do
		if at == holder then
			return true
		elseif at == nil or at == UIParent then
			return false
		end
		at = Read("GetParent", at)
	end
	return false
end

function H.Set(key, on)
	if not BY_KEY[key] then
		return
	end
	if on and ns.Get(KEY .. ".enabled") ~= true then
		ns.Set(KEY .. ".enabled", true)
	end
	ns.Set(KEY .. "." .. key, on == true)
	if on and H.Left(key) then
		print("Flat UI: Leave the game's action bars alone is on (Flat UI page), so " .. H.Label(key) .. " stays shown.")
	end
end

function H.Ticked(key)
	return BY_KEY[key] ~= nil and ns.Enabled(KEY) and Opt(key) == true
end

function H.Toggle(key)
	H.Set(key, not H.Ticked(key))
end

function H.HeldBy(frame)
	local holder = state.holder
	if not holder or next(state.held) == nil or type(frame) ~= "table" then
		return nil
	end
	local at = frame
	for _ = 1, 20 do
		if at == nil or at == UIParent or at == holder then
			return nil
		end
		local parent = Read("GetParent", at)
		if parent == holder then
			local record = state.held[at]
			return record and record.key or nil
		end
		at = parent
	end
	return nil
end

function H.List()
	local list = {}
	for _, entry in ipairs(ENTRIES) do
		if H.Hidden(entry.key) then
			local name = entry.box or entry.frames[1]
			list[#list + 1] = { key = entry.key, label = H.Label(entry.key), name = BY_NAME[name] == entry and name or nil }
		end
	end
	return list
end

ns.Register(KEY, {
	label = "Hidden frames",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	Status = Status,
	slash = {
		hide = function(rest)
			local text = (type(rest) == "string" and rest or ""):match("^%s*(.-)%s*$"):lower():gsub("%s+", " ")
			if text == "" then
				if type(ns.OpenPanelPage) == "function" then
					ns.OpenPanelPage(KEY)
				end
				return
			elseif text == "list" then
				local names = {}
				for _, item in ipairs(H.List()) do
					names[#names + 1] = item.label
				end
				print(#names > 0 and ("Flat UI: hidden: %s."):format(table.concat(names, ", ")) or "Flat UI: no frame is hidden.")
				return
			end
			local found, near
			for _, entry in ipairs(ENTRIES) do
				local label = tostring(H.Label(entry.key)):lower()
				if entry.key:lower() == text or label == text then
					found = entry.key
					break
				elseif not near and label:find(text, 1, true) then
					near = entry.key
				end
			end
			found = found or near
			if not found then
				print(("Flat UI: the Hidden frames page has no \"%s\". Try minimap, tracker, buffs, debuffs, castBar or /flatui hide list."):format(text))
				return
			end
			H.Toggle(found)
			if not H.Ticked(found) then
				print(("Flat UI: %s shows again."):format(H.Label(found)))
			elseif not H.Left(found) then
				print(("Flat UI: %s is hidden. /flatui hide %s shows it again."):format(H.Label(found), text))
			end
		end,
	},
	help = { "/flatui hide - the Hidden frames page of the options", "/flatui hide <frame> - hide a frame or show it again",
		"/flatui hide list - name the frames you have hidden" },
})
