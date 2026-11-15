local ADDON_NAME, ns = ...

-- Glow on the nearest object (general.sparkleGlow on the Flat UI page, under World; on, with Quest item sparkle): a strong golden sparkle of Flat
-- UI's own on the object the game's Interact Key would use, while that is a herb, a vein, a chest or a quest object. The game tracks that object
-- as the unit softinteract and, while it gives it a nameplate, puts the plate over the object; its own nameplate code finds that plate the same
-- way, by UnitIsUnit with softinteract (Blizzard_NamePlates/Blizzard_NamePlates.lua:187-219). The game gives a game object that plate only while
-- the player's Interact Key is on (Enable Interact Key in its Controls options, Controls.lua:72-86, or a gamepad) and its interact icons take in
-- objects (Interact Key Icons at Show All in Accessibility, Accessibility.lua:175-222, or a gamepad, Blizzard_Gamepad/Core.lua:28); without the
-- icons a world object gets no nameplate, as ForeverLootSparkles and NodeSight Sparkles found in the client. Flat UI changes neither: they are the
-- player's choices, the Interact Key's variable is secure (cvars.yaml of build 70790:3866), and a plate for every object would change what the
-- player sees of the key. So this row writes no game setting, and the sparkle shows only where the game already shows such a plate.
-- The plate is found among the nameplates the game shows (C_NamePlate.GetNamePlates, and C_NamePlate.GetNamePlateForUnit for the unit of
-- NAME_PLATE_UNIT_ADDED: NamePlateDocumentation.lua:11-25) by UnitIsGameObject and UnitIsUnit(unit, "softinteract") (UnitDocumentation.lua:
-- 1993-2006), looked at again at NAME_PLATE_UNIT_ADDED, NAME_PLATE_UNIT_REMOVED, PLAYER_SOFT_INTERACT_CHANGED (UnitDocumentation.lua:3909-3919),
-- PLAYER_ENTERING_WORLD and the end of a fight. What kind of object it is comes from its cursor: SetUnitCursorTexture puts it on a hidden texture
-- of Flat UI's own (UnitDocumentation.lua:595-612), whose file or atlas names Mine, GatherHerbs, LootAll, PickLock or a Quest cursor
-- (Interface\Cursor, the same with Unable in front while the player cannot use it yet), or C_QuestLog.UnitIsRelatedToActiveQuest says it
-- belongs to a quest of the player's (QuestLogDocumentation.lua:1287-1300). A chair, a door or a mailbox gets nothing. An answer the game
-- withholds counts as no.
-- The sparkle is one frame of Flat UI's own that takes no mouse, parented to that plate at the plate's frame level, under the game's unit frame,
-- and anchored under it (SetParent, SetFrameLevel, SetPoint on its own frame), so it follows the object, its distance and its fade, and hides with
-- it. It is put on a plate and taken off one only out of combat, as Flat UI does with every frame on a plate that may be protected: in a fight it
-- stays on the object it was on, it hides when that plate goes, and a new object gets it when the fight ends. Inside are textures of its own,
-- drawn with the ADD blend in gold: Media/Glow.tga, a soft round glow, and Media/Star.tga, a four-pointed glint (both 64 by 64 and white), and
-- Media/Ring.tga, the cursor ring's. The glow swells and brightens and back, a ring grows out of the object and fades, and four stars twinkle as
-- they turn a quarter, each an AnimationGroup of its own texture (Alpha, Scale and Rotation animations, SimpleAnimAlphaAPIDocumentation.lua,
-- SimpleAnimScaleAPIDocumentation.lua, SimpleAnimRotationAPIDocumentation.lua), played only while the sparkle shows.
-- Nothing of the game's is written: the plate gets no field, no method call of its Lua and no hook, and its frame level and unit are only read.
-- While the row is off no event is heard, and the frame, once made, is hidden and taken off its plate. An error stops the sparkle until /reload,
-- with a line for /flatui status. Not a module: Sparkle.lua's ns.SparkleChanged calls ns.SparkleGlowChanged at login, at a change of profile and
-- when one of the rows changes. The idea of a sparkle of an addon's own on that plate is Lueur's, and ForeverLootSparkles 1.2.0 to 1.3.1 and
-- NodeSight Sparkles have it too; none of their code is used, and their writes of the Interact Key's variables are left out.

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local GLOW, STAR, RING = MEDIA .. "Glow.tga", MEDIA .. "Star.tga", MEDIA .. "Ring.tga"
-- The size of the sparkle, and how far its middle is under the bottom of the plate, in the plate's units: the plate stands over the object.
local SIZE, BELOW = 128, -40
local GOLD, LIGHT = { 1, 0.78, 0.22 }, { 1, 0.93, 0.62 }
-- The stars: where each is from the middle, its size, the time of one twinkle and the way it turns.
local STARS = {
	{ x = -34, y = 12, size = 40, time = 1.5, turn = 90 },
	{ x = 30, y = 24, size = 30, time = 1.9, turn = -90 },
	{ x = -10, y = -28, size = 34, time = 1.7, turn = -90 },
	{ x = 26, y = -14, size = 24, time = 2.2, turn = 90 },
}
-- The cursor files of the objects that get the sparkle (Interface\Cursor): ore, herbs, chests, locked chests and quest objects.
local CURSORS = { "Mine", "GatherHerbs", "LootAll", "PickLock", "Quest", "QuestRepeatable", "QuestTurnIn" }
local KINDS = {}
for _, name in ipairs(CURSORS) do
	KINDS[name:lower()] = true
end
local EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_SOFT_INTERACT_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }

-- The frame of the sparkle (made the first time it shows) and its animations; the plate it is on and the unit of that plate.
local holder, groups
local anchor, anchorUnit
-- The frame that hears the events while the row is on, whether it hears them, and the hidden texture that takes an object's cursor.
local listener, hearing, probe
-- The cursor files of CURSORS by file ID, read the first time a cursor comes as a file ID.
local cursorIDs
-- True once the sparkle has been on an object in this session. The error that stopped it, or nil.
local seen, broken
local Stop

local function Wanted()
	return ns.Get("general.questSparkle") == true and ns.Get("general.sparkleGlow") == true
end

-- The answer of a call, or nil when the client lacks the function, it raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not ns.IsSecret(answer) then
		return answer
	end
	return nil
end

-- The nameplate of a unit, or nil when there is none, the game withholds it or it is forbidden.
local function PlateOf(unit)
	local plates = _G.C_NamePlate
	local plate = type(plates) == "table" and Ask(plates.GetNamePlateForUnit, unit) or nil
	if ns.Forbidden(plate) then
		return nil
	end
	return plate
end

-- True for the name of a cursor of CURSORS, from a file ID, a path or an atlas name.
local function Glows(texture)
	if type(texture) == "number" then
		if cursorIDs == nil then
			cursorIDs = {}
			for _, name in ipairs(CURSORS) do
				for _, prefix in ipairs({ "", "Unable" }) do
					local id = Ask(_G.GetFileIDFromPath, "Interface\\Cursor\\" .. prefix .. name)
					if type(id) == "number" then
						cursorIDs[id] = true
					end
				end
			end
		end
		return cursorIDs[texture] == true
	end
	if type(texture) ~= "string" or texture == "" then
		return false
	end
	local text = texture:lower()
	local file = (text:match("([^\\/]+)$") or text):gsub("%.blp$", ""):gsub("^unable", "")
	if KINDS[file] then
		return true
	end
	-- An atlas of the gamepad's cursors names the cursor inside a longer name.
	for kind in pairs(KINDS) do
		if text:find(kind, 1, true) then
			return true
		end
	end
	return false
end

-- True for an object that gets the sparkle: one of a quest of the player's, or one whose cursor is that of ore, herbs, a chest or a quest.
local function Sparkles(unit)
	local quests = _G.C_QuestLog
	if type(quests) == "table" and Ask(quests.UnitIsRelatedToActiveQuest, unit) == true then
		return true
	end
	if not probe then
		probe = listener:CreateTexture(nil, "ARTWORK")
		ns.Own[probe] = true
		probe:Hide()
	end
	if Ask(_G.SetUnitCursorTexture, probe, unit, nil, true) ~= true then
		return false
	end
	return Glows(Ask(probe.GetTexture, probe)) or Glows(probe.GetAtlas and Ask(probe.GetAtlas, probe) or nil)
end

-- The plate of a unit when the unit is the game object the Interact Key would use and gets the sparkle, else nil.
local function Match(unit)
	if type(unit) ~= "string" or ns.IsSecret(unit) then
		return nil
	end
	if Ask(_G.UnitIsGameObject, unit) ~= true or Ask(_G.UnitIsUnit, unit, "softinteract") ~= true then
		return nil
	end
	local plate = PlateOf(unit)
	if plate and Sparkles(unit) then
		return plate
	end
	return nil
end

-- The plate and unit of that object among the shown nameplates, or nil.
local function Find()
	local plates = _G.C_NamePlate
	local shown = type(plates) == "table" and Ask(plates.GetNamePlates) or nil
	if type(shown) ~= "table" then
		return nil
	end
	for _, plate in ipairs(shown) do
		if not ns.Forbidden(plate) then
			local unitFrame = plate.UnitFrame
			local unit = not ns.Forbidden(unitFrame) and unitFrame.unit or nil
			if unit and Match(unit) == plate then
				return plate, unit
			end
		end
	end
	return nil
end

-- A texture of the sparkle: white art in a colour, added to what is under it.
local function Art(frame, file, layer, size, colour)
	local texture = frame:CreateTexture(nil, layer)
	ns.Own[texture] = true
	texture:SetTexture(file)
	texture:SetBlendMode("ADD")
	texture:SetVertexColor(colour[1], colour[2], colour[3])
	texture:SetSize(size, size)
	return texture
end

local function Build()
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetSize(SIZE, SIZE)
	frame:Hide()
	local made = {}
	-- The glow swells and brightens, and back.
	local glow = Art(frame, GLOW, "BACKGROUND", SIZE, GOLD)
	glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
	local pulse = glow:CreateAnimationGroup()
	local bright = pulse:CreateAnimation("Alpha")
	bright:SetFromAlpha(0.55)
	bright:SetToAlpha(1)
	bright:SetDuration(0.7)
	bright:SetSmoothing("IN_OUT")
	local swell = pulse:CreateAnimation("Scale")
	swell:SetScaleFrom(0.85, 0.85)
	swell:SetScaleTo(1.1, 1.1)
	swell:SetDuration(0.7)
	swell:SetSmoothing("IN_OUT")
	pulse:SetLooping("BOUNCE")
	made[#made + 1] = pulse
	-- A ring grows out of the object and fades, again and again.
	local ring = Art(frame, RING, "BORDER", SIZE / 2, GOLD)
	ring:SetPoint("CENTER", frame, "CENTER", 0, 0)
	local wave = ring:CreateAnimationGroup()
	local grow = wave:CreateAnimation("Scale")
	grow:SetScaleFrom(0.5, 0.5)
	grow:SetScaleTo(2.2, 2.2)
	grow:SetDuration(1.4)
	grow:SetSmoothing("OUT")
	local fade = wave:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.9)
	fade:SetToAlpha(0)
	fade:SetDuration(1.4)
	fade:SetSmoothing("IN")
	wave:SetLooping("REPEAT")
	made[#made + 1] = wave
	-- Each star comes up as it turns an eighth and goes out as it turns another, at its own pace; turned a quarter it looks as it began.
	for _, spot in ipairs(STARS) do
		local star = Art(frame, STAR, "ARTWORK", spot.size, LIGHT)
		star:SetPoint("CENTER", frame, "CENTER", spot.x, spot.y)
		local twinkle = star:CreateAnimationGroup()
		for order, step in ipairs({ { 0, 1, 0.4, "OUT" }, { 1, 0, 0.6, "IN" } }) do
			local alpha = twinkle:CreateAnimation("Alpha")
			alpha:SetFromAlpha(step[1])
			alpha:SetToAlpha(step[2])
			alpha:SetDuration(spot.time * step[3])
			alpha:SetSmoothing(step[4])
			alpha:SetOrder(order)
			local turn = twinkle:CreateAnimation("Rotation")
			turn:SetDegrees(spot.turn / 2)
			turn:SetDuration(spot.time * step[3])
			turn:SetOrder(order)
		end
		twinkle:SetLooping("REPEAT")
		made[#made + 1] = twinkle
	end
	holder, groups = frame, made
end

local function Play(on)
	for _, group in ipairs(groups or {}) do
		if on then
			if not group:IsPlaying() then
				group:Play()
			end
		else
			group:Stop()
		end
	end
end

local function Hide()
	if holder then
		holder:Hide()
		Play(false)
	end
end

local function Show()
	if holder then
		holder:Show()
		Play(true)
	end
end

-- Puts the sparkle under a plate. Out of combat only.
local function Attach(plate, unit)
	if not holder then
		Build()
	end
	holder:SetParent(plate)
	local level = Ask(plate.GetFrameLevel, plate)
	if ns.Finite(level) then
		holder:SetFrameLevel(level)
	end
	holder:ClearAllPoints()
	holder:SetPoint("CENTER", plate, "BOTTOM", 0, BELOW)
	anchor, anchorUnit, seen = plate, unit, true
end

-- Takes the sparkle off its plate. Out of combat only.
local function Detach()
	if holder and anchor then
		Hide()
		holder:ClearAllPoints()
		holder:SetParent(UIParent)
	end
	anchor, anchorUnit = nil, nil
end

-- Brings the sparkle in line with the object the Interact Key would use, or with its absence.
local function Evaluate()
	if broken or not Wanted() then
		return
	end
	local plate, unit = Find()
	if plate == nil then
		Hide()
		if not InCombatLockdown() then
			Detach()
		end
		return
	end
	if plate ~= anchor then
		if InCombatLockdown() then
			Hide()
			return
		end
		Attach(plate, unit)
	end
	anchorUnit = unit
	Show()
end

local function OnEvent(_, event, unit)
	if broken or not Wanted() then
		return
	end
	if event == "NAME_PLATE_UNIT_ADDED" then
		-- Only the new plate is looked at: the others did not change.
		local plate = Match(unit)
		if plate == nil then
			return
		end
		if plate ~= anchor then
			if InCombatLockdown() then
				return
			end
			Attach(plate, unit)
		end
		anchorUnit = unit
		Show()
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		if anchor and (ns.IsSecret(unit) or unit == anchorUnit) then
			Hide()
			anchorUnit = nil
			if not InCombatLockdown() then
				Detach()
			end
		end
	else
		Evaluate()
	end
end

local function Listen(on)
	if on == (hearing == true) then
		return
	end
	for _, event in ipairs(EVENTS) do
		if on then
			pcall(listener.RegisterEvent, listener, event)
		else
			pcall(listener.UnregisterEvent, listener, event)
		end
	end
	hearing = on
end

local function Off()
	if listener then
		Listen(false)
	end
	Hide()
	if InCombatLockdown() then
		ns.OutOfCombat(function()
			if broken or not Wanted() then
				Detach()
			end
		end)
	else
		Detach()
	end
end

-- An error stops the sparkle until the next /reload, with a line for /flatui status.
function Stop(err)
	if broken then
		return
	end
	broken = tostring(err)
	pcall(Off)
	geterrorhandler()(err)
end

local function Apply()
	if broken then
		return
	end
	if not Wanted() then
		Off()
		return
	end
	if not listener then
		listener = CreateFrame("Frame")
		ns.Own[listener] = true
		listener:SetScript("OnEvent", function(...)
			local ok, err = pcall(OnEvent, ...)
			if not ok then
				Stop(err)
			end
		end)
	end
	Listen(true)
	Evaluate()
end

-- One of the rows changed, the player logged in, or the profile changed.
function ns.SparkleGlowChanged()
	local ok, err = pcall(Apply)
	if not ok then
		Stop(err)
	end
end

-- The number in the text of one of the game's variables, or nil.
local function Setting(name)
	local cvar = _G.C_CVar
	if type(cvar) ~= "table" or type(cvar.GetCVar) ~= "function" then
		return nil
	end
	local text = Ask(cvar.GetCVar, name)
	local number = type(text) == "string" and tonumber(text) or nil
	return ns.Finite(number) and number or nil
end

-- The line of /flatui status, or nil while the row is off or the client has no Interact Key.
function ns.SparkleGlowStatus()
	if broken then
		return "Glow on the nearest object: stopped. " .. broken
	end
	if not Wanted() then
		return nil
	end
	-- Enum.SoftTargetEnableFlags: None 0, Gamepad 1, Kbm 2, Any 3 (SoftTargetConstantsDocumentation.lua:5-17).
	local key = Setting("SoftTargetInteract")
	if key == nil then
		return nil
	end
	if seen then
		return "Glow on the nearest object: on."
	end
	if key < 2 then
		return "Glow on the nearest object: on. It shows once Enable Interact Key is ticked in the game's Controls options and Interact Key Icons is at Show All in Accessibility."
	end
	if Setting("SoftTargetIconGameObject") == 0 then
		return "Glow on the nearest object: on. It shows once Interact Key Icons is at Show All in the game's Accessibility options."
	end
	return "Glow on the nearest object: on. No herb, vein, chest or quest object near you has had a nameplate from the game yet."
end
