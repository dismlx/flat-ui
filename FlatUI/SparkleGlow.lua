local ADDON_NAME, ns = ...

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local GLOW, STAR, RING = MEDIA .. "Glow.tga", MEDIA .. "Star.tga", MEDIA .. "Ring.tga"
local SIZE, BELOW = 128, -40
local GOLD, LIGHT = { 1, 0.78, 0.22 }, { 1, 0.93, 0.62 }
local COLOURS = {
	Mine = { 1, 0.55, 0.25 }, GatherHerbs = { 0.45, 0.95, 0.35 }, Quest = GOLD, QuestRepeatable = GOLD, QuestTurnIn = GOLD, QuestInteract = GOLD,
	quest = GOLD, LootAll = { 0.95, 0.95, 1 }, Pickup = { 0.95, 0.95, 1 }, PickLock = { 0.95, 0.95, 1 },
}
local STAR_WHITE = 0.55
local STARS = {
	{ x = -34, y = 12, size = 40, time = 1.5, turn = 90 },
	{ x = 30, y = 24, size = 30, time = 1.9, turn = -90 },
	{ x = -10, y = -28, size = 34, time = 1.7, turn = -90 },
	{ x = 26, y = -14, size = 24, time = 2.2, turn = 90 },
}
local CURSORS = { "Mine", "GatherHerbs", "Quest", "QuestRepeatable", "QuestTurnIn", "QuestInteract", "LootAll", "Pickup", "PickLock" }
local KINDS = {}
for _, name in ipairs(CURSORS) do
	KINDS[name:lower()] = name
end
local EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_SOFT_INTERACT_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }
local FADE_IN, SOUND_EVERY = 0.25, 2
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local SOUND_CHANNEL = "Gameplay SFX"

local holder, groups, fadeIn, landed
local lastSound = -math.huge
local tinted = { main = {}, light = {} }
local anchor, anchorUnit
local listener, hearing, probe
local cursorIDs
local seen, broken
local Stop

local function Wanted()
	return ns.Get("general.questSparkle") == true and ns.Get("general.sparkleGlow") == true
end

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

local function PlateOf(unit)
	local plates = _G.C_NamePlate
	local plate = type(plates) == "table" and Ask(plates.GetNamePlateForUnit, unit) or nil
	if ns.Forbidden(plate) then
		return nil
	end
	return plate
end

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
	local found
	for kind, name in pairs(KINDS) do
		if text:find(kind, 1, true) and (not found or #name > #found) then
			found = name
		end
	end
	return found
end

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
	local landing = frame:CreateAnimationGroup()
	local rise = landing:CreateAnimation("Alpha")
	rise:SetFromAlpha(0)
	rise:SetToAlpha(1)
	rise:SetDuration(FADE_IN)
	rise:SetSmoothing("OUT")
	holder, groups, fadeIn = frame, made, landing
end

local function Sound(choice)
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[choice] or 0]
	if type(sound) == "table" and type(PlaySound) == "function" then
		pcall(PlaySound, sound[1], SOUND_CHANNEL)
	end
end

local function Chime()
	local choice = ns.Get("general.sparkleGlowSound")
	if type(choice) ~= "string" or not KITS[choice] or InCombatLockdown() then
		return
	end
	local now = Ask(_G.GetTime)
	if not ns.Finite(now) or now - lastSound < SOUND_EVERY then
		return
	end
	lastSound = now
	Sound(choice)
end

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
	if not holder then
		return
	end
	local landing = not holder:IsShown() or anchor ~= landed
	holder:Show()
	Play(true)
	if landing then
		landed = anchor
		if fadeIn then
			fadeIn:Stop()
			fadeIn:Play()
		end
		Chime()
	end
end

local function Grow()
	if not holder or InCombatLockdown() then
		return
	end
	local size = ns.Get("general.sparkleGlowSize")
	size = ns.Finite(size) and math.max(50, math.min(200, size)) or 100
	local scale = size / 100
	holder:SetScale(scale)
	if anchor then
		holder:ClearAllPoints()
		holder:SetPoint("CENTER", anchor, "BOTTOM", 0, BELOW / scale)
	end
end

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
	Grow()
end

local function Detach()
	if holder and anchor then
		Hide()
		holder:ClearAllPoints()
		holder:SetParent(UIParent)
	end
	anchor, anchorUnit = nil, nil
end

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
		local plate, kind = Match(unit)
		if plate == nil then
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
	Grow()
end

function ns.SparkleGlowChanged()
	local ok, err = pcall(Apply)
	if not ok then
		Stop(err)
	end
end

function Setting(name)
	local cvar = _G.C_CVar
	if type(cvar) ~= "table" or type(cvar.GetCVar) ~= "function" then
		return nil
	end
	local text = Ask(cvar.GetCVar, name)
	local number = type(text) == "string" and tonumber(text) or nil
	return ns.Finite(number) and number or nil
end

local KEY_ON, KEY_ANY = 2, 3
local SHOW_ALL = { "SoftTargetIconEnemy", "SoftTargetIconInteract", "SoftTargetIconGameObject", "SoftTargetLowPriorityIcons" }
local HINT_LINE = "Flat UI: Glow on the nearest object shows only with the game's Interact Key on. Turn on what the glow needs, on the World and "
	.. "cursor page, sets it up."

local function Ready()
	local key = Setting("SoftTargetInteract")
	if key == nil then
		return nil
	end
	return key >= KEY_ON and Setting("SoftTargetIconGameObject") ~= 0
end

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

function ns.SparkleGlowSoundPicked(path)
	if type(path) ~= "string" or InCombatLockdown() or not (type(ns.PanelShown) == "function" and ns.PanelShown() == true) then
		return
	end
	local kit = KITS[ns.Get(path)]
	local sound = kit and ns.SOUNDS and ns.SOUNDS[kit]
	if sound and type(ns.PlayKit) == "function" then
		ns.PlayKit(sound[1])
	end
end

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
		return false, "Flat UI: the game did not take every setting. Tick Enable Interact Key in its Controls options and set Interact Key Icons to "
			.. "Show All in Accessibility."
	elseif #changed == 0 then
		return true, "Flat UI: Enable Interact Key and Interact Key Icons are on already."
	end
	return true, ("Flat UI: %s on. The glow shows on the next herb, vein or quest object near you."):format(table.concat(changed, " and "))
end

function ns.SparkleGlowStatus()
	if broken then
		return "Glow on the nearest object: stopped. " .. broken
	end
	if not Wanted() then
		return nil
	end
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
