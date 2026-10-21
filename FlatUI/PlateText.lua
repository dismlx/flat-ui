local _, ns = ...

-- Nameplate text and cast bar parts, added to the plates as parts of Nameplates.lua (ns.PlateExtra): whether the name shows and its colour,
-- the colour and the visibility of the health text, a health text of the addon's own in another format, the size, outline and colour of the
-- spell name, the size of the spell icon, and the spark and the shield. Every call is in a pcall; a part that fails on enough plates stops
-- alone, puts back what it changed and has a line in /flatui status. A row at its default makes no call the game did not make.

local KEY = "nameplates"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local FONT_OBJECT = "SystemFont_NamePlate"
local HEALTH_TEXTS, CAST_TEXTS = { "Text", "LeftText", "RightText" }, { "Text", "CastTargetNameText" }
local NAME, HEALTH, FORMAT, CAST, PARTS = "name text", "health text", "health text format", "cast bar text", "cast bar parts"

-- Per unit frame: nameFaded, nameSet (the colour is set here), nameGame (the colour the game gave the name, false when it was withheld),
-- htFaded, own (the health text of the addon's own), ownFont, iconSized.
local state = setmetatable({}, { __mode = "k" })
-- Per font string: the colour the game gave it, while a colour is set here.
local gameColour = setmetatable({}, { __mode = "k" })
local followName, followHealth
local waitingForCombat, queued = false, false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Soon(fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

local function St(unitFrame)
	local record = state[unitFrame]
	if record == nil then
		record = {}
		state[unitFrame] = record
	end
	return record
end

-- False for the plate of a friendly unit while Restyle friendly nameplates is off, and for every plate while the module is off.
local function OnFor(unitFrame)
	if not ns.Enabled(KEY) then
		return false
	end
	if Opt("friendly") then
		return true
	end
	local friend = unitFrame.isFriend
	return not (Plain(friend, "boolean") and friend)
end

local function White(path)
	return ns.Get(path):sub(3, 8) == "ffffff"
end

local function Region(owner, key)
	if ns.Forbidden(owner) then
		return nil
	end
	local region = owner[key]
	if ns.IsSecret(region) or type(region) ~= "table" then
		return nil
	end
	return region
end

-- The font strings of a frame that exist and have not been withheld.
local function Strings(owner, keys)
	local list = {}
	for _, key in ipairs(keys) do
		local fontString = Region(owner, key)
		if fontString then
			list[#list + 1] = fontString
		end
	end
	return list
end

-- A frame of a plate that the addon may touch.
local function Frame(owner, key)
	local frame = Region(owner, key)
	if frame and not ns.Forbidden(frame) then
		return frame
	end
end

local function CastBarOf(unitFrame)
	local container = Frame(unitFrame, "CastBarsContainer")
	return container and Frame(container, "castBar")
end

local function HealthBarOf(unitFrame)
	local container = Frame(unitFrame, "HealthBarsContainer")
	return container and Frame(container, "healthBar")
end

-- Sets the text colour of a font string after keeping the colour the game gave it; nil puts that colour back. A colour that could not be read or
-- set is raised, so that the part counts it.
local function TextColour(fontString, r, g, b)
	if r ~= nil then
		if gameColour[fontString] == nil then
			local ok, gr, gg, gb, ga = pcall(fontString.GetTextColor, fontString)
			if not ok or not (Plain(gr, "number") and Plain(gg, "number") and Plain(gb, "number")) then
				error("the text colour could not be read", 0)
			end
			gameColour[fontString] = { gr, gg, gb, Plain(ga, "number") and ga or 1 }
		end
		if not pcall(fontString.SetTextColor, fontString, r, g, b, 1) then
			error("the text colour could not be set", 0)
		end
	elseif gameColour[fontString] then
		local back = gameColour[fontString]
		gameColour[fontString] = nil
		if not pcall(fontString.SetTextColor, fontString, back[1], back[2], back[3], back[4]) then
			error("the game's text colour could not be put back", 0)
		end
	end
end

-- Whether the game lets addon code change a protected frame now.
local function Allowed(frame)
	local check = C_RestrictedActions and C_RestrictedActions.CheckAllowProtectedFunctions
	if check then
		local ok, allowed = pcall(check, frame, true)
		if ok and Plain(allowed, "boolean") then
			return allowed
		end
	end
	return not InCombatLockdown()
end

-- Name -------------------------------------------------------------------------------------

-- Whether the name shows and what colour it has. The game colours the name again after each of its updates and this runs after that
-- (fromGame), so the colour read then is the game's own and is kept for putting it back.
local function NamePart(unitFrame, st, on, fromGame)
	local name = Region(unitFrame, "name")
	if name == nil then
		return
	end
	local shown = not on or Opt("nameShow")
	if not shown or st.nameFaded then
		ns.SetFaded(name, not shown)
		st.nameFaded = not shown or nil
	end
	local mode = on and Opt("nameColour") or "game"
	local r, g, b
	if mode == "white" then
		r, g, b = 1, 1, 1
	elseif mode == "custom" then
		r, g, b = ns.Colour(KEY .. ".nameCustomColour")
	elseif mode == "reaction" then
		local unit = unitFrame.unit
		if Plain(unit, "string") then
			r, g, b = ns.ReactionColour(unit)
		end
	end
	if r ~= nil then
		if not followName then
			ns.Note(KEY, "Name colour: the game's name update cannot be followed, so the colour can go back to the game's.")
		end
		-- The game hides the name without setting a colour, so the colour is the game's only while the name is shown.
		local okShown, isShown = pcall(name.IsShown, name)
		local gameColour = fromGame and okShown and Plain(isShown, "boolean") and isShown
		if gameColour or st.nameGame == nil then
			local ok, gr, gg, gb, ga = pcall(name.GetVertexColor, name)
			if ok and Plain(gr, "number") and Plain(gg, "number") and Plain(gb, "number") then
				st.nameGame = { gr, gg, gb, Plain(ga, "number") and ga or 1 }
			else
				st.nameGame = false
			end
		end
		-- Marked before the call, so a failure still leaves a restore to do.
		st.nameSet = true
		if not pcall(name.SetVertexColor, name, r, g, b) then
			error("the name colour could not be set", 0)
		end
	elseif st.nameSet then
		local back = st.nameGame
		st.nameSet, st.nameGame = nil, nil
		if back and not pcall(name.SetVertexColor, name, back[1], back[2], back[3], back[4]) then
			error("the game's name colour could not be put back", 0)
		end
	end
end

-- Health text ------------------------------------------------------------------------------

local function AnyShown(strings)
	if #strings == 0 then
		return true
	end
	for _, fontString in ipairs(strings) do
		local ok, shown = pcall(fontString.IsShown, fontString)
		if not ok or not Plain(shown, "boolean") or shown then
			return true
		end
	end
	return false
end

-- The colour of the game's three health text strings, and which plates have them. Nameplates.lua fades them when Health text is off.
local function HealthPart(unitFrame, st, on)
	local strings = Strings(HealthBarOf(unitFrame), HEALTH_TEXTS)
	local r, g, b
	if on and not White(KEY .. ".healthTextColour") then
		r, g, b = ns.Colour(KEY .. ".healthTextColour")
	end
	for _, fontString in ipairs(strings) do
		TextColour(fontString, r, g, b)
	end
	local when, format = on and Opt("healthTextWhen") or "always", on and Opt("healthFormat") or "game"
	-- A format that stopped draws nothing, so the game's text stays.
	if ns.PartStopped(KEY, FORMAT) then
		format = "game"
	end
	local mine = when ~= "always" or format ~= "game"
	if mine or st.htFaded then
		-- isTarget comes from a unit comparison the client can withhold; only a plain boolean is used.
		local target = Plain(unitFrame.isTarget, "boolean") and unitFrame.isTarget
		local fade = (ns.Enabled(KEY) and not Opt("healthText")) or format ~= "game" or (when == "target" and not target)
		for _, fontString in ipairs(strings) do
			ns.SetFaded(fontString, fade)
		end
		st.htFaded = mine and fade or nil
	end
end

-- The format strings of the health text, which the drawings of Flat UI setup write with a plain sample in place of the unit's health.
ns.PLATE_HEALTH_FORMATS = { percent = "%.0f%%", both = "%s  %.0f%%" }

local function SetHealthText(own, format, unit)
	local formats = ns.PLATE_HEALTH_FORMATS
	if format == "value" then
		own:SetText(AbbreviateNumbers(UnitHealth(unit)))
	elseif format == "percent" then
		own:SetFormattedText(formats.percent, UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
	elseif format == "both" then
		own:SetFormattedText(formats.both, AbbreviateNumbers(UnitHealth(unit)), UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
	else
		own:SetText(AbbreviateNumbers(UnitHealthMissing(unit)))
	end
end

-- The health text of the addon's own, at the right end of the health bar, in the font of the game's own health text.
local function OwnHealthText(unitFrame, st, healthBar)
	local own = st.own
	if own == nil then
		own = ns.OwnText(unitFrame, "OVERLAY", FONT_OBJECT)
		if own == nil then
			error("the health text could not be made", 0)
		end
		st.own = own
		own:SetPoint("RIGHT", healthBar, "RIGHT", -4, 0)
	end
	local game = Region(healthBar, "RightText")
	if game then
		local ok, file, size, flags = pcall(game.GetFont, game)
		if ok and Plain(file, "string") and Plain(size, "number") and Plain(flags, "string") then
			local key = ("%s|%s|%s"):format(file, size, flags)
			if st.ownFont ~= key then
				if pcall(own.SetFont, own, file, size, flags) then
					st.ownFont = key
				end
			end
		end
	end
	return own
end

-- The format of the health text. Another format than the game's is drawn by a font string of the addon's own and the game's three strings are
-- faded (HealthPart). It follows the game's own health text: shown while any of the three is shown.
local function FormatPart(unitFrame, st, on)
	local format = on and Opt("healthFormat") or "game"
	if format == "game" then
		if st.own then
			st.own:SetText("")
			st.own:Hide()
		end
		return
	end
	local healthBar = HealthBarOf(unitFrame)
	if healthBar == nil then
		return
	end
	if not followHealth then
		ns.Note(KEY, "Health text format: the game's health update cannot be followed, so the text may not change with the health.")
	end
	local own = OwnHealthText(unitFrame, st, healthBar)
	local colourR, colourG, colourB = 1, 1, 1
	if not White(KEY .. ".healthTextColour") then
		colourR, colourG, colourB = ns.Colour(KEY .. ".healthTextColour")
	end
	own:SetTextColor(colourR, colourG, colourB, 1)
	local unit = unitFrame.unit
	local target = Plain(unitFrame.isTarget, "boolean") and unitFrame.isTarget
	local shown = Opt("healthText") and (Opt("healthTextWhen") ~= "target" or target) and Plain(unit, "string")
		and AnyShown(Strings(healthBar, HEALTH_TEXTS))
	own:SetShown(shown and true or false)
	if shown then
		SetHealthText(own, format, unit)
	end
end

-- Cast bar ---------------------------------------------------------------------------------

local function CastPart(unitFrame, st, on)
	local castBar = CastBarOf(unitFrame)
	if castBar == nil then
		return
	end
	local percent = on and Opt("castTextSize") or 100
	local flags = (on and not Opt("castTextOutline")) and "" or nil
	local r, g, b
	if on and not White(KEY .. ".castTextColour") then
		r, g, b = ns.Colour(KEY .. ".castTextColour")
	end
	for _, key in ipairs(CAST_TEXTS) do
		local spec = { percent = percent, flags = flags }
		if key == "Text" and r ~= nil then
			spec.r, spec.g, spec.b = r, g, b
		end
		if ns.TextStyle(castBar[key], spec) == false then
			error("the spell name font could not be set", 0)
		end
	end
end

local function Fade(castBar, st, key, flag, faded)
	if faded or st[flag] then
		ns.SetFaded(Region(castBar, key), faded)
		st[flag] = faded or nil
	end
end

local Layout

-- The spell icon is a percent of the size the game gives it, from NamePlateSetupOptions. In combat the game does not take a size from addon
-- code, so it is done when combat ends.
local function PartsPart(unitFrame, st, on)
	local castBar = CastBarOf(unitFrame)
	if castBar == nil then
		return
	end
	Fade(castBar, st, "Spark", "sparkFaded", on and not Opt("castSpark"))
	Fade(castBar, st, "BorderShield", "shieldFaded", on and not Opt("castShield"))
	local percent = on and Opt("castIconSize") or 100
	if percent == 100 and not st.iconSized then
		return
	end
	local options, icon = NamePlateSetupOptions, Region(castBar, "Icon")
	local width, height = Plain(options, "table") and options.castIconWidth, Plain(options, "table") and options.castIconHeight
	if icon == nil or not (Plain(width, "number") and Plain(height, "number")) then
		return
	end
	if Allowed(castBar) then
		-- Marked before the call, so a failure still leaves a restore to do.
		st.iconSized = percent ~= 100 or nil
		icon:SetSize(width * percent / 100, height * percent / 100)
	elseif not InCombatLockdown() then
		ns.Note(KEY, "Spell icon size: the game does not allow the spell icon to be resized.")
	elseif not waitingForCombat then
		waitingForCombat = true
		ns.OutOfCombat(function()
			waitingForCombat = false
			ns.EachPlate(Layout)
		end)
	end
end

-- Running the parts ------------------------------------------------------------------------

-- Every plate is laid out again on the next frame, after a part has stopped on one of them.
local function QueueAll()
	if not queued then
		queued = true
		Soon(function()
			queued = false
			ns.EachPlate(Layout)
		end)
	end
end

-- Runs one part for one plate. A part that is stopped, or a module that is off, runs with `on` false, which puts the game's look back.
local function Run(part, fn, unitFrame, ...)
	local st = St(unitFrame)
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, part) then
		pcall(fn, unitFrame, st, false, ...)
	else
		ns.EachPart(KEY, part, fn, unitFrame, st, OnFor(unitFrame), ...)
		if ns.PartStopped(KEY, part) then
			pcall(fn, unitFrame, st, false, ...)
			QueueAll()
		end
	end
end

function Layout(unitFrame)
	if ns.Forbidden(unitFrame) then
		return
	end
	Run(NAME, NamePart, unitFrame)
	Run(HEALTH, HealthPart, unitFrame)
	Run(FORMAT, FormatPart, unitFrame)
	Run(CAST, CastPart, unitFrame)
	Run(PARTS, PartsPart, unitFrame)
end

local function OnName(frame)
	if ns.IsPlate(frame) and not ns.Forbidden(frame) then
		Run(NAME, NamePart, frame, true)
	end
end

local function OnHealth(frame)
	if ns.IsPlate(frame) and not ns.Forbidden(frame) then
		Run(FORMAT, FormatPart, frame)
	end
end

local function Leave(unitFrame)
	local st = state[unitFrame]
	if st and st.own then
		pcall(st.own.SetText, st.own, "")
	end
end

local retargetQueued = false
local function Retarget()
	if retargetQueued then
		return
	end
	retargetQueued = true
	Soon(function()
		retargetQueued = false
		ns.EachPlate(function(unitFrame)
			Run(HEALTH, HealthPart, unitFrame)
			Run(FORMAT, FormatPart, unitFrame)
		end)
	end)
end

EXTRA.layout[#EXTRA.layout + 1] = Layout
EXTRA.show[#EXTRA.show + 1] = Layout
EXTRA.leave[#EXTRA.leave + 1] = Leave
followName = ns.FollowGlobal("CompactUnitFrame_UpdateName", OnName) == true
followHealth = ns.FollowGlobal("CompactUnitFrame_UpdateHealth", OnHealth) == true
ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", Retarget)
