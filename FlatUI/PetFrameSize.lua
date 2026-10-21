local _, ns = ...

-- The size of the pet frame, as a percent of the player frame or of the normal size.
-- The pet frame hangs in a container under the player frame, and the container lays out its children at
-- their own scale. The game gives the pet frame a scale only in UpdatePetFrameScale: the Frame Size of
-- Edit Mode's pet frame divided by the scale of the player frame, then the container is laid out again
-- (EditModeSystemTemplates.lua:2686-2697). The game keeps the pet frame at its own Frame Size on screen
-- even when Flat UI has scaled the player frame, so the pet frame comes out larger than a shrunk player frame.
-- This sets the scale with SetScaleBase, the engine's own call. No method of the pet frame is hooked: UpdatePetFrameScale is called when Edit
-- Mode applies a layout (EDIT_MODE_LAYOUTS_UPDATED, PLAYER_SPECIALIZATION_CHANGED, the spectate override layouts, the revert buttons inside
-- Edit Mode), so the size is put back one frame after those events and after Edit Mode closes. The pet frame's OnShow is followed as well, which
-- the game does not need for this (ManagedFrameMixin.OnShow only adds the frame to its container, ManagedFrameSystem.lua:17-19) (EllesmereUI follows Edit Mode in the same way,
-- with post-hooks on ApplySystemAnchor and a one-frame wait: EllesmereUI/EllesmereUIActionBars/EUI_UnlockMode_Positions.lua:2717-2745, and moves no frame from inside the
-- game's call). It is not a module: the unit frames module calls
-- ns.PetFrameSize whenever it applies its settings, and the movers call it after the player frame's
-- scale is set or put back.

local KEY = "unitframes"
local PART = "petsize"
local MIN, MAX = 0.1, 5
local TOLERANCE = 0.0005

-- given is the scale the game set last, and what the pet frame gets back. ours is the scale this file
-- wrote last. puts counts the times the size was put back after the game set a scale.
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

-- The scale the pet frame gets, or nil when the setting is off or a scale cannot be read.
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

-- A frame outside the container hangs from its own anchors, whose offsets are measured at the scale the
-- frame had. After a new scale the offsets are divided again, so the frame stays where it was, as the
-- game does in SetScaleOverride (EditModeSystemTemplates.lua:121-135). SetPointBase is the engine's call;
-- the Lua SetPoint is Edit Mode's and writes its anchor flags (EditModeSystemTemplates.lua:146-150).
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

-- Writes a scale with the engine's call, never SetScale, which is Edit Mode's. The container is marked
-- for a layout out of combat; Layout itself is the game's.
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
			-- The game has set a scale of its own since this file wrote one; that is the scale to give back when the setting goes off.
			state.given, fromGame = current, true
		elseif state.given == nil then
			state.given = current
		end
		state.ours = scale
		Put(frame, scale, fromGame)
	elseif state.ours then
		-- Back to the scale the game gave last.
		state.ours = nil
		local given = state.given
		state.given = nil
		if given then
			Put(frame, given)
		end
	end
end

function Apply(fromGame)
	local frame = Frame()
	if not frame or ns.EditModeOpen() then
		return
	end
	if InCombatLockdown() and ns.MaybeProtected(frame) then
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
		-- The part stopped: the pet frame gets the game's scale back.
		pcall(Write, frame, fromGame)
	end
end

-- One frame after the game set a scale: Write reads the scale it gave from the frame, and the size goes back on it.
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

-- The line of /flatui status, or nothing while the setting is off.
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

-- The pet frame can be set up after the module starts.
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
