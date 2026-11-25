local ADDON_NAME, ns = ...

-- Glow on the nearest object (general.sparkleGlow on the World and cursor page, under World; on, with Quest item sparkle): a strong golden sparkle of Flat
-- UI's own on the object the game's Interact Key would use, while its cursor marks a herb, a vein, a quest object or loot. The game tracks that
-- object as the unit softinteract and, while it gives it a nameplate, puts the plate over the object; its own nameplate code finds that plate the
-- same way, by UnitIsUnit with softinteract (Blizzard_NamePlates/Blizzard_NamePlates.lua:187-219). The game gives a game object that plate only
-- while the player's Interact Key is on (Enable Interact Key in its Controls options, Controls.lua:72-86, or a gamepad) and its interact icons take
-- in objects (Interact Key Icons at Show All in Accessibility, Accessibility.lua:175-222, or a gamepad, Blizzard_Gamepad/Core.lua:28); without the
-- icons a world object gets no nameplate, as ForeverLootSparkles and NodeSight Sparkles found in the client. The glow's row changes neither: they
-- are the player's choices, the Interact Key's variable is secure (cvars.yaml of build 70790:3866), and a plate for every object would change
-- what the player sees of the key. So this row writes no game setting, and the sparkle shows only where the game already shows such a plate.
-- Turn on what the glow needs (general.sparkleSetup, a list row) sets both when the player picks it, out of a fight, as the game's own options
-- write them: softTargetInteract to Enum.SoftTargetEnableFlags.Any unless the key is on already (Controls.lua:78-80), and the four variables of
-- Interact Key Icons at Show All to 1 (Accessibility.lua:196-201), with C_CVar.SetCVar; a line in chat says what it changed. Once for the
-- account (FlatUIDB.sparkleHint), at the first look of a session while the glow is on and the Interact Key is off, one line in chat points to it.
-- The plate is found among the nameplates the game shows (C_NamePlate.GetNamePlates, and C_NamePlate.GetNamePlateForUnit for the unit of
-- NAME_PLATE_UNIT_ADDED: NamePlateDocumentation.lua:11-25) by UnitIsGameObject and UnitIsUnit(unit, "softinteract") (UnitDocumentation.lua:
-- 1993-2006), looked at again at NAME_PLATE_UNIT_ADDED, NAME_PLATE_UNIT_REMOVED, PLAYER_SOFT_INTERACT_CHANGED (UnitDocumentation.lua:3909-3919),
-- PLAYER_ENTERING_WORLD and the end of a fight. What kind of object it is comes from its cursor: SetUnitCursorTexture puts it on a hidden texture
-- of Flat UI's own (UnitDocumentation.lua:595-612), whose file or atlas names Mine, GatherHerbs, a Quest cursor, LootAll, Pickup or PickLock
-- (Interface\Cursor, the same with Unable in front while the player cannot use it yet; the names Forever's client has, as Lueur read them from it,
-- and a file ID is looked up with and without .blp, as Lueur does), or C_QuestLog.UnitIsRelatedToActiveQuest says it belongs to a quest of the
-- player's (QuestLogDocumentation.lua:1287-1300). A chair, a door or a mailbox gets nothing, and so does a chest the game gives a lever's cursor,
-- as Lueur saw one get on Forever. An answer the game withholds counts as no.
-- The sparkle is one frame of Flat UI's own that takes no mouse, parented to that plate at the plate's frame level, under the game's unit frame,
-- and anchored under it (SetParent, SetFrameLevel, SetPoint on its own frame), so it follows the object, its distance and its fade, and hides with
-- it. It is put on a plate and taken off one only out of combat, as Flat UI does with every frame on a plate that may be protected: in a fight it
-- stays on the object it was on, it hides when that plate goes, and a new object gets it when the fight ends. Inside are textures of its own,
-- drawn with the ADD blend in gold: Media/Glow.tga, a soft round glow, and Media/Star.tga, a four-pointed glint (both 64 by 64 and white), and
-- Media/Ring.tga, the cursor ring's. The glow swells and brightens and back, a ring grows out of the object and fades, and four stars twinkle as
-- they turn a quarter, each an AnimationGroup of its own texture (Alpha, Scale and Rotation animations, SimpleAnimAlphaAPIDocumentation.lua,
-- SimpleAnimScaleAPIDocumentation.lua, SimpleAnimRotationAPIDocumentation.lua), played only while the sparkle shows. With Glow colour at By what
-- it is (general.sparkleGlowColour; Gold, the look above, by default), the cursor that told the object's kind also gives its colour (COLOURS):
-- herbs green, ore copper, quest objects gold, loot, things to pick up and locked chests white; the stars are that colour, lighter. The
-- textures are tinted again (SetVertexColor) only when the colour changes.
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
-- Glow colour By what it is: the colour of each cursor of CURSORS (quest, the object of a quest of the player's, is gold), and how far the stars
-- go from it towards white, as LIGHT does from GOLD.
local COLOURS = {
	Mine = { 1, 0.55, 0.25 }, GatherHerbs = { 0.45, 0.95, 0.35 }, Quest = GOLD, QuestRepeatable = GOLD, QuestTurnIn = GOLD, QuestInteract = GOLD,
	quest = GOLD, LootAll = { 0.95, 0.95, 1 }, Pickup = { 0.95, 0.95, 1 }, PickLock = { 0.95, 0.95, 1 },
}
local STAR_WHITE = 0.55
-- The stars: where each is from the middle, its size, the time of one twinkle and the way it turns.
local STARS = {
	{ x = -34, y = 12, size = 40, time = 1.5, turn = 90 },
	{ x = 30, y = 24, size = 30, time = 1.9, turn = -90 },
	{ x = -10, y = -28, size = 34, time = 1.7, turn = -90 },
	{ x = 26, y = -14, size = 24, time = 2.2, turn = 90 },
}
-- The cursor files of the objects that get the sparkle (Interface\Cursor): ore, herbs, quest objects, loot, things to pick up and locked chests.
local CURSORS = { "Mine", "GatherHerbs", "Quest", "QuestRepeatable", "QuestTurnIn", "QuestInteract", "LootAll", "Pickup", "PickLock" }
local KINDS = {}
for _, name in ipairs(CURSORS) do
	KINDS[name:lower()] = name
end
local EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_SOFT_INTERACT_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }

-- The frame of the sparkle (made the first time it shows) and its animations; the plate it is on and the unit of that plate. Its textures for
-- the colour: tinted.main (the glow and the ring) and tinted.light (the stars), and tinted.colour, the colour they have now.
local holder, groups
local tinted = { main = {}, light = {} }
local anchor, anchorUnit
-- The frame that hears the events while the row is on, whether it hears them, and the hidden texture that takes an object's cursor.
local listener, hearing, probe
-- The cursor files of CURSORS by file ID (their names), read the first time a cursor comes as a file ID.
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

-- The name of a cursor of CURSORS, from a file ID, a path or an atlas name, or nil.
local function Glows(texture)
	if type(texture) == "number" then
		if cursorIDs == nil then
			cursorIDs = {}
			for _, name in ipairs(CURSORS) do
				for _, prefix in ipairs({ "", "Unable" }) do
					local path = "Interface\\Cursor\\" .. prefix .. name
					for _, file in ipairs({ path, path .. ".blp" }) do
						local id = Ask(_G.GetFileIDFromPath, file)
						if ns.Finite(id) and id > 0 then
							cursorIDs[id] = name
						end
					end
				end
			end
		end
		return cursorIDs[texture]
	end
	if type(texture) ~= "string" or texture == "" then
		return nil
	end
	local text = texture:lower()
	local file = (text:match("([^\\/]+)$") or text):gsub("%.blp$", ""):gsub("^unable", "")
	if KINDS[file] then
		return KINDS[file]
	end
	-- An atlas of the gamepad's cursors names the cursor inside a longer name; the longest name found wins, so QuestTurnIn is not Quest.
	local found
	for kind, name in pairs(KINDS) do
		if text:find(kind, 1, true) and (not found or #name > #found) then
			found = name
		end
	end
	return found
end

-- What an object that gets the sparkle is: "quest" for one of a quest of the player's, else the name of its cursor of CURSORS (ore, herbs, a
-- quest or loot); nil for any other.
local function Sparkles(unit)
	local quests = _G.C_QuestLog
	if type(quests) == "table" and Ask(quests.UnitIsRelatedToActiveQuest, unit) == true then
		return "quest"
	end
	if not probe then
		probe = listener:CreateTexture(nil, "ARTWORK")
		ns.Own[probe] = true
		probe:Hide()
	end
	if Ask(_G.SetUnitCursorTexture, probe, unit, nil, true) ~= true then
		return nil
	end
	return Glows(Ask(probe.GetTexture, probe)) or Glows(probe.GetAtlas and Ask(probe.GetAtlas, probe) or nil)
end

-- The plate of a unit when the unit is the game object the Interact Key would use and gets the sparkle, and what it is (Sparkles), else nil.
local function Match(unit)
	if type(unit) ~= "string" or ns.IsSecret(unit) then
		return nil
	end
	if Ask(_G.UnitIsGameObject, unit) ~= true or Ask(_G.UnitIsUnit, unit, "softinteract") ~= true then
		return nil
	end
	local plate = PlateOf(unit)
	local kind = plate and Sparkles(unit)
	if kind then
		return plate, kind
	end
	return nil
end

-- The plate, unit and kind of that object among the shown nameplates, or nil.
local function Find()
	local plates = _G.C_NamePlate
	local shown = type(plates) == "table" and Ask(plates.GetNamePlates) or nil
	if type(shown) ~= "table" then
		return nil
	end
	for _, plate in ipairs(shown) do
		if not ns.Forbidden(plate) then
			local unitFrame = plate.UnitFrame
			if not ns.Forbidden(unitFrame) then
				-- Match tests the unit with ns.IsSecret before anything else.
				local unit = unitFrame.unit
				local found, kind = Match(unit)
				if found == plate then
					return plate, unit, kind
				end
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
	tinted.main, tinted.light, tinted.colour = {}, {}, GOLD
	local glow = Art(frame, GLOW, "BACKGROUND", SIZE, GOLD)
	tinted.main[#tinted.main + 1] = glow
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
	tinted.main[#tinted.main + 1] = ring
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
		tinted.light[#tinted.light + 1] = star
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

-- The colour of the sparkle: gold, or with Glow colour By what it is, the colour of what the object is. Written only when it changes.
local function Tint(kind)
	local colour = ns.Get("general.sparkleGlowColour") == "kind" and COLOURS[kind] or GOLD
	if not holder or colour == tinted.colour then
		return
	end
	tinted.colour = colour
	for _, texture in ipairs(tinted.main) do
		texture:SetVertexColor(colour[1], colour[2], colour[3])
	end
	local r, g, b = LIGHT[1], LIGHT[2], LIGHT[3]
	if colour ~= GOLD then
		r, g, b = colour[1] + (1 - colour[1]) * STAR_WHITE, colour[2] + (1 - colour[2]) * STAR_WHITE, colour[3] + (1 - colour[3]) * STAR_WHITE
	end
	for _, texture in ipairs(tinted.light) do
		texture:SetVertexColor(r, g, b)
	end
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
	local plate, unit, kind = Find()
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
	Tint(kind)
	Show()
end

local function OnEvent(_, event, unit)
	if broken or not Wanted() then
		return
	end
	if event == "NAME_PLATE_UNIT_ADDED" then
		-- Only the new plate is looked at: the others did not change.
		local plate, kind = Match(unit)
		if plate == nil then
			return
		end
		if plate ~= anchor then
			if InCombatLockdown() then
				-- The object the sparkle is on is no longer the one the Interact Key would use.
				Hide()
				return
			end
			Attach(plate, unit)
		end
		anchorUnit = unit
		Tint(kind)
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

local Setting, Hint

local function Apply()
	if broken then
		return
	end
	if not Wanted() then
		Off()
		return
	end
	Hint()
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
function Setting(name)
	local cvar = _G.C_CVar
	if type(cvar) ~= "table" or type(cvar.GetCVar) ~= "function" then
		return nil
	end
	local text = Ask(cvar.GetCVar, name)
	local number = type(text) == "string" and tonumber(text) or nil
	return ns.Finite(number) and number or nil
end

-- Turn on what the glow needs --------------------------------------------------------------------------------------------------------------

-- Enum.SoftTargetEnableFlags: Kbm 2 and Any 3 (SoftTargetConstantsDocumentation.lua:5-17): from Kbm up the key works with the keyboard and mouse.
local KEY_ON, KEY_ANY = 2, 3
-- The four variables the game's Interact Key Icons sets to 1 at Show All (Accessibility.lua:196-201).
local SHOW_ALL = { "SoftTargetIconEnemy", "SoftTargetIconInteract", "SoftTargetIconGameObject", "SoftTargetLowPriorityIcons" }
local HINT_LINE = "Flat UI: Glow on the nearest object shows only with the game's Interact Key on. Turn on what the glow needs, on the World and cursor page, sets it up."

-- Whether the key is on and the icons take in objects; nil on a client without the Interact Key.
local function Ready()
	local key = Setting("SoftTargetInteract")
	if key == nil then
		return nil
	end
	return key >= KEY_ON and Setting("SoftTargetIconGameObject") ~= 0
end

-- The one line in chat, once for the account, at the first look of a session while the glow is on and the key is off.
local hintLooked = false
function Hint()
	if hintLooked then
		return
	end
	hintLooked = true
	local db = ns.Account()
	local key = Setting("SoftTargetInteract")
	if type(db) ~= "table" or db.sparkleHint ~= nil or key == nil or key >= KEY_ON then
		return
	end
	db.sparkleHint = true
	print(HINT_LINE)
end

-- The lines of the row: what a pick does, or that it is done.
function ns.SparkleGlowSetupLines()
	local ready = Ready()
	if ready == nil then
		return { { 3, "This client has no Interact Key" } }
	elseif ready then
		return { { 2, "Already on: Enable Interact Key and Interact Key Icons" } }
	end
	return { { 1, "Turn on Enable Interact Key and Interact Key Icons: Show All" } }
end

local function Write(name, value)
	local cvar = _G.C_CVar
	if type(cvar) ~= "table" or type(cvar.SetCVar) ~= "function" then
		return false
	end
	local ok, done = pcall(cvar.SetCVar, name, value)
	return ok and done ~= false
end

-- Sets what the glow needs, out of a fight, and says what it changed.
function ns.SparkleGlowSetup(id)
	if id == 2 then
		return true, "Flat UI: Enable Interact Key and Interact Key Icons are on already."
	elseif id ~= 1 then
		return false, id == 3 and "Flat UI: this client has no Interact Key." or nil
	end
	if InCombatLockdown() then
		return false, "Flat UI: not in a fight. Pick it again after the fight."
	end
	local changed, failed = {}, false
	local key = Setting("SoftTargetInteract")
	if key ~= nil and key < KEY_ON then
		local flags = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.SoftTargetEnableFlags or nil
		local any = type(flags) == "table" and not ns.IsSecret(flags) and ns.Finite(flags.Any) and flags.Any or KEY_ANY
		if Write("softTargetInteract", tostring(any)) then
			changed[#changed + 1] = "Enable Interact Key"
		else
			failed = true
		end
	end
	local icons = false
	for _, name in ipairs(SHOW_ALL) do
		if Setting(name) ~= 1 then
			if Write(name, "1") then
				icons = true
			else
				failed = true
			end
		end
	end
	if icons then
		changed[#changed + 1] = "Interact Key Icons: Show All"
	end
	ns.SparkleGlowChanged()
	if failed then
		return false, "Flat UI: the game did not take every setting. Tick Enable Interact Key in its Controls options and set Interact Key Icons to Show All in Accessibility."
	elseif #changed == 0 then
		return true, "Flat UI: Enable Interact Key and Interact Key Icons are on already."
	end
	return true, ("Flat UI: %s on. The glow shows on the next herb, vein or quest object near you."):format(table.concat(changed, " and "))
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
		return "Glow on the nearest object: on. It shows once Enable Interact Key is ticked in the game's Controls options and Interact Key Icons is at Show All in Accessibility: Turn on what the glow needs sets both."
	end
	if Setting("SoftTargetIconGameObject") == 0 then
		return "Glow on the nearest object: on. It shows once Interact Key Icons is at Show All in the game's Accessibility options: Turn on what the glow needs sets it."
	end
	return "Glow on the nearest object: on. No herb, vein or quest object near you has had a nameplate from the game yet."
end
