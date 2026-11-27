local _, ns = ...

local KEY = "unitframes"
local PART = "petsize"
local MIN, MAX = 0.1, 5
local TOLERANCE = 0.0005

local state = { given = nil, ours = nil, queued = false, hooked = false, watched = false, later = false, puts = 0 }
local Apply

local function Frame()
	local frame = _G.PetFrame
	if ns.Forbidden(frame) then
		return nil
	end
	local ok, setBase = pcall(function()
		return frame.SetScaleBase
	end)
	if ok and not ns.IsSecret(setBase) and type(setBase) == "function" then
		return frame
	end
	ns.Note(KEY, "Pet frame size: the game gave the pet frame no way to set its scale, so it keeps its size.")
	return nil
end

local function Read(frame, method)
	local ok, value = pcall(function()
		return frame[method](frame)
	end)
	if ok and ns.Finite(value) then
		return value
	end
	return nil
end

local function Parent(frame)
	local ok, parent = pcall(frame.GetParent, frame)
	if ok and not ns.IsSecret(parent) and type(parent) == "table" and not ns.Forbidden(parent) then
		return parent
	end
	return UIParent
end

local function Wanted(frame)
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) or not ns.Get("unitframes.petSize") then
		return nil
	end
	local percent = ns.Get("unitframes.petSizePct")
	if not ns.Finite(percent) then
		return nil
	end
	local base = Read(ns.Get("unitframes.petSizeBasis") == "screen" and UIParent or _G.PlayerFrame or UIParent, "GetEffectiveScale")
	local parent = Read(Parent(frame), "GetEffectiveScale")
	if not base or not parent or parent <= 0 then
		return nil
	end
	local scale = percent / 100 * base / parent
	if not ns.Finite(scale) then
		return nil
	end
	return math.max(MIN, math.min(MAX, scale))
end

local function Reanchor(frame, old, scale)
	if not ns.Finite(old) or old <= 0 or not ns.Finite(scale) or scale <= 0 then
		return
	end
	local ok, setPoint = pcall(function()
		return frame.SetPointBase
	end)
	if not ok or ns.IsSecret(setPoint) or type(setPoint) ~= "function" then
		return
	end
	local okCount, count = pcall(frame.GetNumPoints, frame)
	if not okCount or not ns.Finite(count) then
		return
	end
	local points = {}
	for i = 1, count do
		local okPoint, point, rel, relPoint, x, y = pcall(frame.GetPoint, frame, i)
		if okPoint and type(point) == "string" and not ns.IsSecret(point) and not ns.IsSecret(rel) and not ns.IsSecret(relPoint)
			and ns.Finite(x) and ns.Finite(y) then
			points[#points + 1] = { point, rel, relPoint, x * old / scale, y * old / scale }
		end
	end
	for _, p in ipairs(points) do
		pcall(setPoint, frame, p[1], p[2], p[3], p[4], p[5])
	end
end

local function Put(frame, scale, fromGame)
	local current = Read(frame, "GetScale")
	if current ~= nil and math.abs(current - scale) <= TOLERANCE then
		return
	end
	frame:SetScaleBase(scale)
	if fromGame then
		state.puts = state.puts + 1
	end
	if not InCombatLockdown() then
		local parent = Parent(frame)
		local ok, mark = pcall(function()
			return parent.MarkDirty
		end)
		if ok and not ns.IsSecret(mark) and type(mark) == "function" then
			pcall(mark, parent)
		else
			Reanchor(frame, current, scale)
		end
		ns.ResizeAll()
	end
end

local function Write(frame, fromGame)
	local scale = Wanted(frame)
	if scale then
		local current = Read(frame, "GetScale")
		if state.ours ~= nil and current ~= nil and math.abs(current - state.ours) > TOLERANCE then
			state.given, fromGame = current, true
		elseif state.given == nil then
			state.given = current
		end
		state.ours = scale
		Put(frame, scale, fromGame)
	elseif state.ours then
		state.ours = nil
		local given = state.given
		state.given = nil
		if given then
			Put(frame, given)
		end
	end
end

local function Pending(frame)
	local scale = Wanted(frame)
	if scale == nil then
		return state.ours ~= nil
	end
	local current = Read(frame, "GetScale")
	return current == nil or math.abs(current - scale) > TOLERANCE
end

function Apply(fromGame)
	local frame = Frame()
	if not frame or ns.EditModeOpen() then
		return
	end
	if InCombatLockdown() and ns.MaybeProtected(frame) then
		if not Pending(frame) then
			return
		end
		local extra = ns.UnitFrameExtra
		if fromGame ~= true and extra ~= nil and type(extra.tell) == "function" then
			extra.tell("Flat UI: the pet frame takes its new size when the fight ends.")
		end
		if not state.queued then
			state.queued = true
			ns.OutOfCombat(function()
				state.queued = false
				Apply()
			end)
		end
		return
	end
	if not ns.EachPart(KEY, PART, Write, frame, fromGame) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) then
		ns.Note(KEY, "Unit frames: the game refused a size on the pet frame.")
		if state.ours and state.given then
			pcall(frame.SetScaleBase, frame, state.given)
		end
		state.ours = nil
	elseif ns.PartStopped(KEY, PART) and state.ours then
		pcall(Write, frame, fromGame)
	end
end

local function Game()
	state.later = false
	Apply(true)
end

local function Soon()
	if state.later then
		return
	end
	state.later = true
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" or not pcall(C_Timer.After, 0, Game) then
		Game()
	end
end

local function Watch()
	if state.watched or type(EventRegistry) ~= "table" or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	state.watched = pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", function()
		Soon()
	end, state)
end

local function Hook()
	if state.hooked or not ns.Enabled(KEY) or not ns.Get("unitframes.petSize") then
		return
	end
	local frame = Frame()
	if not frame then
		return
	end
	if type(frame.HookScript) == "function" then
		state.hooked = pcall(frame.HookScript, frame, "OnShow", Soon)
	end
	Watch()
end

function ns.PetFrameSize()
	Hook()
	Apply()
end

function ns.PetFrameSizeStatus()
	if not state.hooked or not ns.Enabled(KEY) or not ns.Get("unitframes.petSize") then
		return nil
	end
	if ns.EditModeOpen() then
		return "Pet frame size: left to Edit Mode"
	end
	if state.queued then
		return "Pet frame size: waits for the end of combat"
	end
	local percent = ns.Get("unitframes.petSizePct")
	local basis = ns.Get("unitframes.petSizeBasis") == "screen" and "normal size" or "player frame"
	local puts = state.puts == 1 and "put back once" or ("put back %d times"):format(state.puts)
	return ("Pet frame size: %d%% of the %s, %s"):format(percent, basis, puts)
end

local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
pcall(events.RegisterEvent, events, "EDIT_MODE_LAYOUTS_UPDATED")
pcall(events.RegisterEvent, events, "PLAYER_SPECIALIZATION_CHANGED")
events:SetScript("OnEvent", function(_, event)
	if event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
		Soon()
	else
		ns.PetFrameSize()
	end
end)
