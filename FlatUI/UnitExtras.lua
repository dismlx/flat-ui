local ADDON_NAME, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PARTY, RAIDRANGE, RAID, PREDICT, TOTEM, MENU = "Party range", "Raid range", "Raid frame parts", "Heal prediction", "Totem timers", "Target menu"
local GAME_ALPHA, TICK = 0.5, 0.25
local NOTE = "Unit frames: Party range: a member out of range and a member whose range the game does not report are both dimmed."

local Fade, Off = X.fade, X.off

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Note(part, text)
	ns.Note(KEY, ("Unit frames: %s: %s"):format(part, text))
end

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

local HANG = 43

function X.cover(rec, region, margin, placed)
	local body = X.joined(rec) and X.body(rec) or nil
	local key = ("%s:%.3f"):format(body and "body" or "parts", margin)
	if placed == key then
		return key
	end
	region:ClearAllPoints()
	if body ~= nil then
		region:SetPoint("TOPLEFT", body, "TOPLEFT", -margin, margin)
		region:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", margin, -margin)
	elseif rec.kind == "party" then
		region:SetPoint("TOPLEFT", rec.frame, "TOPLEFT", 0, 0)
		region:SetPoint("BOTTOMRIGHT", rec.frame, "TOPRIGHT", 0, -(HANG + margin))
	else
		region:SetAllPoints(rec.frame)
	end
	return key
end

local function ShadeMargin(rec)
	local t = ns.Pixels(rec.frame, ns.Get("general.thickness"))
	return ns.Finite(t) and t or 1
end

local function Make(rec)
	local ok, level = pcall(rec.frame.GetFrameLevel, rec.frame)
	local box = X.frame(rec.frame, ok and X.number(level) and level + 10 or nil)
	rec.rangePlaced = X.cover(rec, box, ShadeMargin(rec))
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
	local dark = 1 - Opt("partyRangeOpacity") / 100
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
	if rec.kind ~= "party" and rec.kind ~= "partypet" then
		return
	end
	local want = on and not Off(PARTY) and Opt("partyRangeDim") == true
	if rec.kind ~= "party" then
	elseif want then
		ns.Note(KEY, NOTE)
	else
		ns.ClearNote(KEY, NOTE)
		Problem(nil)
	end
	if rec.rangeBox == nil then
		if not want then
			return
		end
		if InCombatLockdown() then
			X.tell("Flat UI: party members dim by range when the fight ends.")
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

local function PlaceRange(rec)
	if rec.rangeBox ~= nil then
		rec.rangePlaced = X.cover(rec, rec.rangeBox, ShadeMargin(rec), rec.rangePlaced)
	end
end

local function RaidRange(rec, on)
	if rec.kind ~= "raid" then
		return
	end
	local frame = rec.frame
	local percent = on and not Off(RAIDRANGE) and Opt("raidRangeAlpha") or 50
	local state = frame.outOfRange
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

local function RaidParts(rec, on)
	if rec.kind ~= "raid" then
		return
	end
	local frame, live = rec.frame, on and not Off(RAID)
	Fade(RAID, X.path(frame, "roleIcon"), live and (Opt("raidRoleIcon") == false or X.roleLeftOut(rec)))
	Fade(RAID, X.path(frame, "name"), live and Opt("raidName") == false)
	Fade(RAID, X.path(frame, "statusText"), live and Opt("raidStatusText") == false)
end

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

local menuHooked = setmetatable({}, { __mode = "k" })

local function Gamepad()
	local input = _G.InputUtil
	if type(input) ~= "table" or ns.IsSecret(input) or type(input.IsGamepadUIEnabled) ~= "function" then
		return false
	end
	local ok, on = pcall(input.IsGamepadUIEnabled)
	return ok and not ns.IsSecret(on) and on == true
end

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

local seen = setmetatable({}, { __mode = "k" })
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

function X.afterTotems()
	if Opt("totemTimer") == false or Opt("totemSwipe") == false then
		X.run(TOTEM, Totems)
	end
end

local NAMEFIT, FIT_FLOOR = "Long names", 0.75
local fitNote = nil
local function FitNote(text)
	if fitNote == text then
		return
	end
	if fitNote ~= nil then
		ns.ClearNote(KEY, fitNote)
	end
	fitNote = text
	if text ~= nil then
		ns.Note(KEY, text)
	end
end
local unmeasured = setmetatable({}, { __mode = "k" })
local function Measured(rec, ok)
	unmeasured[rec] = not ok or nil
	FitNote(next(unmeasured) ~= nil and "Unit frames: Long names: the game did not give the width of the name, so a long name stays cut with dots." or nil)
end
local FIT_ROW = { tot = "totNameFit", pet = "petNameFit", party = "partyNameFit", partypet = "partyNameFit", boss = "bossNameFit" }
local function FitName(rec)
	local fit = FIT_ROW[rec.kind]
	if fit == nil then
		return
	end
	if rec.row == nil or not X.rowOn(rec) then
		Measured(rec, true)
		return
	end
	local name = rec.row.name
	pcall(name.SetTextScale, name, 1)
	if Opt(fit) ~= "shrink" then
		Measured(rec, true)
		return
	end
	local okNeed, need = pcall(name.GetUnboundedStringWidth, name)
	local okRoom, room = pcall(name.GetWidth, name)
	if not (okNeed and okRoom and X.number(need) and X.number(room) and room > 0) then
		Measured(rec, false)
		return
	end
	Measured(rec, true)
	if need > room then
		pcall(name.SetTextScale, name, math.max(FIT_FLOOR, room / need))
	end
end

table.insert(X.after.rowText, { part = NAMEFIT, fn = FitName })
table.insert(X.after.layout, { part = NAMEFIT, fn = FitName })
table.insert(X.after.apply, { part = PARTY, fn = PartyRange })
table.insert(X.after.layout, { part = PARTY, fn = PlaceRange })
table.insert(X.after.apply, { part = RAID, fn = RaidParts })
table.insert(X.after.apply, { part = RAIDRANGE, fn = RaidRange })
table.insert(X.after.apply, { part = PREDICT, fn = Predict })
table.insert(X.after.apply, { part = RAID, fn = Hook })
table.insert(X.after.apply, { part = MENU, fn = TargetMenu })
table.insert(X.after.raid, { part = RAID, fn = RaidParts })
table.insert(X.after.raid, { part = RAIDRANGE, fn = RaidRange })
table.insert(X.after.raid, { part = PREDICT, fn = Predict })
table.insert(X.after.refresh, { part = TOTEM, fn = Totems })
