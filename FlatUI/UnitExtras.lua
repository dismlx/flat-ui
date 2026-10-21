local ADDON_NAME, ns = ...

-- Range, heal prediction and shields, the parts of a raid frame and the timers of the totem buttons. Raid frames follow the game's own range opacity with a value of
-- their own: the game's answer about range is withheld from addon code, so it is handed to SetAlphaFromBoolean and never read. Party frames get a black layer
-- of the addon's own that a timer of the addon's own darkens by the same withheld answer. The prediction and shield segments, the parts of a raid frame and the
-- parts of a totem button are regions the game shows and hides and never fades, so off is a change of opacity to 0 and on gives back the opacity they had
-- (X.fade, UnitParts.lua). This file adds its work after the steps of UnitFrames.lua through ns.UnitFrameExtra: a part that stops on errors counts as off here,
-- and every function can run twice with the same result. The menu of a right-click on the target frame opens at the cursor, as the player and focus menus do.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PARTY, RAIDRANGE, RAID, PREDICT, TOTEM, MENU = "Party range", "Raid range", "Raid frame parts", "Heal prediction", "Totem timers", "Target menu"
-- The game's own opacity for a raid frame out of range and in range (CompactUnitFrame.lua:1066), and how often the party layers look at range, in seconds.
local GAME_ALPHA, TICK = 0.5, 0.25
local NOTE = "Unit frames: Party range: a member out of range and a member whose range the game does not report are both dimmed."

local Fade, Off = X.fade, X.off

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- A line for /flatui status about a part that could not do its work for a reason of the client.
local function Note(part, text)
	ns.Note(KEY, ("Unit frames: %s: %s"):format(part, text))
end

-- The line about what keeps the party layers from dimming, which goes when they dim again or are off.
local problem = nil
local function Problem(text)
	if problem == text then
		return
	end
	if problem ~= nil then
		ns.ClearNote(KEY, problem)
	end
	problem = text
	if text ~= nil then
		ns.Note(KEY, text)
	end
end

-- Party range ------------------------------------------------------------------------------------------------

-- The layer of a party member: a frame of the addon's own above the member, with one black texture, made out of combat. It starts transparent.
local function Make(rec)
	local ok, level = pcall(rec.frame.GetFrameLevel, rec.frame)
	local box = X.frame(rec.frame, ok and X.number(level) and level + 10 or nil)
	box:SetAllPoints(rec.frame)
	local shade = X.layer(box, "OVERLAY", 7)
	shade:SetColorTexture(0, 0, 0, 1)
	shade:SetAlpha(0)
	shade:Show()
	rec.rangeBox, rec.rangeShade = box, shade
	local waited = 0
	box:SetScript("OnUpdate", function(_, elapsed)
		waited = waited + (X.number(elapsed) and elapsed or 0)
		if waited >= TICK then
			waited = 0
			X.run(PARTY, X.rangeLook, rec)
		end
	end)
end

-- The shade is clear for a member in range and as dark as Out of range dimming says for any other answer, a withheld one included.
function X.rangeLook(rec)
	local shade = rec.rangeShade
	if shade == nil or Off(PARTY) or Opt("partyRangeDim") ~= true then
		return
	end
	local unit = X.unitOf(rec)
	if unit == nil then
		pcall(shade.SetAlpha, shade, 0)
		return
	end
	if type(_G.UnitInRange) ~= "function" then
		pcall(shade.SetAlpha, shade, 0)
		Problem("Unit frames: Party range: this client gives no answer about range, so members are not dimmed.")
		return
	end
	local ok, inRange = pcall(UnitInRange, unit)
	local dark = Opt("partyRangeAlpha") / 100
	if type(shade.SetAlphaFromBoolean) ~= "function" then
		pcall(shade.SetAlpha, shade, 0)
		Problem("Unit frames: Party range: this client cannot set an opacity from an answer about range, so members are not dimmed.")
	elseif ok and (ns.IsSecret(inRange) or type(inRange) == "boolean") then
		if pcall(shade.SetAlphaFromBoolean, shade, inRange, 0, dark) then
			Problem(nil)
		else
			pcall(shade.SetAlpha, shade, 0)
			Problem("Unit frames: Party range: the game refused to set the opacity of the layer from its answer about range.")
		end
	else
		pcall(shade.SetAlpha, shade, 0)
	end
end

local function PartyRange(rec, on)
	if rec.kind ~= "party" then
		return
	end
	local want = on and not Off(PARTY) and Opt("partyRangeDim") == true
	if want then
		ns.Note(KEY, NOTE)
	else
		ns.ClearNote(KEY, NOTE)
		Problem(nil)
	end
	if rec.rangeBox == nil then
		if not want then
			return
		end
		-- The layer is made out of combat, on a frame the game protects.
		if InCombatLockdown() then
			if not rec.rangeQueued then
				rec.rangeQueued = true
				ns.OutOfCombat(function()
					rec.rangeQueued = nil
					X.run(PARTY, PartyRange, rec, X.active(rec))
				end)
			end
			return
		end
		Make(rec)
	end
	rec.rangeBox:SetShown(want)
	if want then
		X.rangeLook(rec)
	end
end

-- Raid frames -------------------------------------------------------------------------------------------------

-- The opacity of a raid frame by its own range answer: Out of range opacity when the game says the unit is out of range, 100% otherwise. The answer is never
-- tested, only handed on. At 50% the game's own opacity is back, set from the same answer, and nothing is called while the row has never left 50%.
local function RaidRange(rec, on)
	if rec.kind ~= "raid" then
		return
	end
	local frame = rec.frame
	local percent = on and not Off(RAIDRANGE) and Opt("raidRangeAlpha") or 50
	local state = frame.outOfRange
	-- The game's answer is a boolean or a withheld one; nothing was answered while the game fades nothing or has not looked yet.
	if not ns.IsSecret(state) and type(state) ~= "boolean" then
		rec.rangeSet = nil
		return
	end
	local alpha = percent ~= 50 and percent / 100 or (rec.rangeSet and GAME_ALPHA or nil)
	if alpha == nil then
		return
	end
	rec.rangeSet = percent ~= 50 or nil
	if type(frame.SetAlphaFromBoolean) ~= "function" or not pcall(frame.SetAlphaFromBoolean, frame, state, alpha, 1) then
		rec.rangeSet = nil
		if percent ~= 50 then
			Note(RAIDRANGE, "the game refused to set the opacity of a raid frame from its answer about range, which stays as the game has it.")
		end
	end
end

-- The role icon, the name and the status text of a raid frame.
local function RaidParts(rec, on)
	if rec.kind ~= "raid" then
		return
	end
	local frame, live = rec.frame, on and not Off(RAID)
	Fade(RAID, X.path(frame, "roleIcon"), live and Opt("raidRoleIcon") == false)
	Fade(RAID, X.path(frame, "name"), live and Opt("raidName") == false)
	Fade(RAID, X.path(frame, "statusText"), live and Opt("raidStatusText") == false)
end

-- Heal prediction and shields -------------------------------------------------------------------------------

-- Per row: the segments of a unit frame, which hang from its health bar (the pet's are globals named PetFrame and the key), and the textures of a raid frame.
local SEGMENTS = {
	{ opt = "healPrediction", keys = { "MyHealPredictionBar", "OtherHealPredictionBar" }, raid = { "myHealPrediction", "otherHealPrediction" } },
	{ opt = "absorbShield", keys = { "TotalAbsorbBar", "OverAbsorbGlow" }, raid = { "totalAbsorb", "totalAbsorbOverlay", "overAbsorbGlow" } },
	{ opt = "healAbsorb", keys = { "HealAbsorbBar", "OverHealAbsorbGlow" },
		raid = { "myHealAbsorb", "myHealAbsorbOverlay", "myHealAbsorbLeftShadow", "myHealAbsorbRightShadow", "overHealAbsorbGlow" } },
}

local function Predict(rec, on)
	local live = on and not Off(PREDICT)
	local frame = rec.frame
	for _, row in ipairs(SEGMENTS) do
		local hide = live and Opt(row.opt) == false
		if rec.kind == "raid" then
			for _, key in ipairs(row.raid) do
				Fade(PREDICT, X.path(frame, key), hide)
			end
		else
			for _, key in ipairs(row.keys) do
				Fade(PREDICT, X.path(rec.parts.health, key) or (rec.kind == "pet" and X.path(_G, "PetFrame" .. key)) or nil, hide)
			end
		end
	end
end

-- The game draws these parts of a raid frame again with its own updates.
local RAID_FOLLOWS = {
	CompactUnitFrame_UpdateName = RaidParts, CompactUnitFrame_UpdateStatusText = RaidParts, CompactUnitFrame_UpdateRoleIcon = RaidParts,
	CompactUnitFrame_UpdateHealPrediction = Predict, CompactUnitFrame_UpdateCenterStatusIcon = RaidRange,
}
local RAID_PARTS = { CompactUnitFrame_UpdateName = RAID, CompactUnitFrame_UpdateStatusText = RAID, CompactUnitFrame_UpdateRoleIcon = RAID,
	CompactUnitFrame_UpdateHealPrediction = PREDICT, CompactUnitFrame_UpdateCenterStatusIcon = RAIDRANGE }
local followed = {}

local function Follow(name)
	local fn = RAID_FOLLOWS[name]
	return function(frame)
		if frame == nil or ns.IsSecret(frame) then
			return
		end
		local rec = X.known(frame)
		if rec ~= nil and rec.kind == "raid" and rec.made then
			X.run(RAID_PARTS[name], fn, rec, X.active(rec))
		end
	end
end

-- The hooks are made when a raid frame is first styled.
local function Hook(rec)
	if rec.kind ~= "raid" then
		return
	end
	for name in pairs(RAID_FOLLOWS) do
		if not followed[name] then
			local made = Follow(name)
			followed[name] = ns.FollowGlobal(name, made) == true
		end
	end
end

-- Target menu -------------------------------------------------------------------------------------------------

-- The game opens the menu of the target frame at the cursor and then moves it to the right side of the frame (TargetFrame_OpenMenu,
-- Blizzard_UnitFrame/Mainline/TargetFrame.lua:670-673), while the player and focus menus stay at the cursor (PlayerFrame.lua:79-97, TargetFrame.lua:1145-1153).
-- A hook on the click runs after the game's script, so the menu is open and placed by then; it is put back at the cursor with the game's own call for the
-- player menu (Blizzard_SharedXML/InputUtil.lua:239-252). The game's attributes and scripts of the frame are not written, and a menu that hangs from a
-- protected frame is not moved in combat.
local menuHooked = setmetatable({}, { __mode = "k" })

local function Gamepad()
	local input = _G.InputUtil
	if type(input) ~= "table" or ns.IsSecret(input) or type(input.IsGamepadUIEnabled) ~= "function" then
		return false
	end
	local ok, on = pcall(input.IsGamepadUIEnabled)
	return ok and not ns.IsSecret(on) and on == true
end

-- The menu that is open, when its first point is the one TargetFrame_OpenMenu gave it: LEFT of the frame's RIGHT side.
local function BesideFrame(frame)
	local manager = _G.Menu
	if type(manager) ~= "table" or ns.IsSecret(manager) or type(manager.GetManager) ~= "function" then
		return nil
	end
	local ok, open = pcall(function() return manager.GetManager():GetOpenMenu() end)
	if not ok or type(open) ~= "table" or ns.IsSecret(open) or ns.Forbidden(open) then
		return nil
	end
	local fine, point, relative, relativePoint = pcall(open.GetPoint, open, 1)
	if fine and point == "LEFT" and relative == frame and relativePoint == "RIGHT" then
		return open
	end
	return nil
end

local function AtCursor(frame)
	local menu = BesideFrame(frame)
	local input = _G.InputUtil
	if menu ~= nil and type(input) == "table" and type(input.AnchorRegionToCursor) == "function" then
		pcall(input.AnchorRegionToCursor, menu, "TOPLEFT")
	end
end

local function OnTargetClick(frame, button, down)
	if ns.IsSecret(button) or ns.IsSecret(down) or button ~= "RightButton" or down == true or InCombatLockdown() or Gamepad() then
		return
	end
	local rec = X.known(frame)
	if rec ~= nil and rec.made and ns.Enabled(KEY) and X.active(rec) and not Off(MENU) then
		X.run(MENU, AtCursor, frame)
	end
end

local function TargetMenu(rec)
	if rec.kind == "target" and not menuHooked[rec.frame] and type(rec.frame.HookScript) == "function" then
		menuHooked[rec.frame] = pcall(rec.frame.HookScript, rec.frame, "PostClick", OnTargetClick)
	end
end

-- Totems -----------------------------------------------------------------------------------------------------

-- The buttons seen, so that a button the game has released gets its opacity back too.
local seen = setmetatable({}, { __mode = "k" })
-- The game colours the time left of a totem button again with every tick of its OnUpdate, which gives the text the opacity of a colour with no
-- fourth number. TotemButtonMixin:OnUpdate calls AuraButtonMixin.UpdateDuration by that name (Blizzard_UnitFrame/Mainline/TotemFrame.lua:71), so the
-- function of that table is followed, not a method of a button or of its text (EllesmereUI hooks no text of a Blizzard frame, and treats a hook
-- on a table of functions as safe: EllesmereUIBlizzardSkin_WindowPacks.lua:3188-3190). The timer text of a button the addon has not seen is left alone.
-- Mixin copies functions when a frame is created, so aura buttons made after this runs copy the followed UpdateDuration, and KeepTimer then runs
-- once per player buff per tick. It is cheap, and the seen check filters it.
local timerFollowed = false

local function KeepTimer(button)
	if not ns.IsSecret(button) and seen[button] and ns.Enabled(KEY) and Opt("totemTimer") == false and not Off(TOTEM) then
		Fade(TOTEM, X.path(button, "Duration"), true)
	end
end

local function FollowTimers()
	local mixin = _G.AuraButtonMixin
	if timerFollowed or type(hooksecurefunc) ~= "function" or type(mixin) ~= "table" or ns.IsSecret(mixin) or type(mixin.UpdateDuration) ~= "function" then
		return
	end
	timerFollowed = pcall(hooksecurefunc, mixin, "UpdateDuration", KeepTimer)
end

local function Totem(button, live)
	local timer = X.path(button, "Duration")
	local hide = live and Opt("totemTimer") == false
	if hide then
		FollowTimers()
	end
	Fade(TOTEM, timer, hide)
	Fade(TOTEM, X.path(button, "Icon", "Cooldown"), live and Opt("totemSwipe") == false)
end

local function Totems()
	local live = ns.Enabled(KEY) and not Off(TOTEM)
	local frame = _G.TotemFrame
	local pool = frame ~= nil and not ns.Forbidden(frame) and frame.totemPool
	if type(pool) == "table" and not ns.IsSecret(pool) and type(pool.EnumerateActive) == "function" then
		for button in pool:EnumerateActive() do
			seen[button] = true
		end
	end
	for button in pairs(seen) do
		Totem(button, live)
	end
end

-- The game lays the buttons out again and sets their text and swipe; the unit frames file calls this after each of its passes over the buttons,
-- one frame after the game's call.
function X.afterTotems()
	if Opt("totemTimer") == false or Opt("totemSwipe") == false then
		X.run(TOTEM, Totems)
	end
end

table.insert(X.after.apply, { part = PARTY, fn = PartyRange })
table.insert(X.after.apply, { part = RAID, fn = RaidParts })
table.insert(X.after.apply, { part = RAIDRANGE, fn = RaidRange })
table.insert(X.after.apply, { part = PREDICT, fn = Predict })
table.insert(X.after.apply, { part = RAID, fn = Hook })
table.insert(X.after.apply, { part = MENU, fn = TargetMenu })
table.insert(X.after.raid, { part = RAID, fn = RaidParts })
table.insert(X.after.raid, { part = RAIDRANGE, fn = RaidRange })
table.insert(X.after.raid, { part = PREDICT, fn = Predict })
table.insert(X.after.refresh, { part = TOTEM, fn = Totems })
