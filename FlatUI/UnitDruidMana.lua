local _, ns = ...

-- Druid mana in forms (on by default, Player frame page): a thin bar of Flat UI's own with a druid's mana under the power bar of the player frame,
-- while the druid is in Bear, Dire Bear or Cat Form. A druid in those forms sees no mana on Forever. The game's alternate power bar loads there
-- (Blizzard_UnitFrame/Blizzard_UnitFrame.toc:90-93 has no ExcludeLoadGameType camelot, unlike the class bars at 75-78, 86-89 and 94-97, and
-- Camelot/PlayerFrame.lua:58 and 99 ask for it), but its pairs give a druid mana only beside Lunar Power, which Forever's druids do not have
-- (Mainline/AlternatePowerBar.lua:2-5, 17-26). In Aquatic, Travel and Moonkin Form the power stays mana and the frame's own bar shows it, so the
-- bar shows only while UnitPowerType says plainly that the power is not mana (UnitDocumentation.lua:2859-2878, no secret tag; Enum.PowerType.Mana
-- is 0, PowerTypeConstantsDocumentation.lua:25), and a withheld answer keeps what shows. It is made for a druid alone (UnitClass plainly DRUID).
-- The bar: a StatusBar 4 pixels high, in the fill of the frame's power bar (Power bar texture, else the bar texture of the Flat UI page; a white
-- image for a solid fill) and the colour of mana (ns.PowerColour, with Muted colours as the frame's bars have it), with Flat UI's outline in the
-- look of the Unit frames page. A status bar with a texture takes withheld values and one without refuses them (HealthColour.lua, Probe), so it
-- always has one. It is fed UnitPowerMax and UnitPower of mana unread (SecretWhenUnitPowerMaxRestricted and SecretWhenUnitPowerRestricted,
-- UnitDocumentation.lua:2732-2734 and 2801-2803), which SetMinMaxValues and SetValue take (SimpleStatusBarAPIDocumentation.lua:229-237,
-- 355-363). It hangs under the power bar (ManaBarArea.ManaBar, 124 by 10 at TOPLEFT 87,-61 of the frame, Camelot/PlayerFrame.lua:91-96) as wide
-- as it. With Frame style Separate parts, or on a player frame Flat UI does not style, it hangs as far under it as the power bar hangs under the
-- health bar there: the two borders, at least 1 unit (Gap, UnitFrameCells.lua), so wherever Flat UI or the game puts the power bar the three bars
-- look alike. In one frame (ns.UnitFrameExtra.joined, UnitFrames.lua) it hangs under the whole frame, outside it: the frame's margin (a border
-- thickness and Space between parts), its border, the space and the bar's own border, so three thicknesses and twice the space in pixels. Its
-- frame is a frame of the addon's own on the frame that holds the bars (PlayerFrameContentMain), so it fades with the content of the frame, which
-- Fading fades (Fade.lua:70), and stays when Power bar makes the power bar transparent (UnitParts.lua, Power). It is made and laid out out of
-- combat, on a frame the game protects; it is no protected frame itself, so it shows and hides in a fight. It hears UNIT_POWER_UPDATE and
-- UNIT_MAXPOWER of mana and UNIT_DISPLAYPOWER for the player on a frame of its own (RegisterUnitEvent, as UnitGroupMarks.lua hears the auras of
-- one member, so no other unit's power reaches Flat UI; UnitDocumentation.lua:4234-4243, 4406-4416, 4551-4561), and UPDATE_SHAPESHIFT_FORM
-- (SpellBookDocumentation.lua:989-994), only while it is wanted. The game's player frame is not changed: no field written, no method called.
-- This follows EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLResourceBars/Init.lua:19, resourceBarsDruidFixedMana, a
-- Forever and TBC option whose bar is not in the package; EnhanceQoLUnitFrames/UF_Helper.lua:1773-1823, a druid's second power is mana, shown
-- while the main power is not): the mana of a druid in forms, here a bar under the game's player frame.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Druid mana"
-- The power type of mana (Enum.PowerType.Mana) and its token, the height of the bar in screen pixels, and the fill of a solid bar.
local MANA, TOKEN, HEIGHT_PX = 0, "MANA", 4
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- The blue of a mana bar whose colour the game does not give (UnitFrames.lua, COLOUR.mana).
local BLUE = { 0, 0, 1 }
-- The events of the player's power, heard for the player alone, and the change of form.
local UNIT_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }
local EVENTS = { "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" }
local LINE_SHOWN = "Unit frames: Druid mana: shown under the player frame while your power is not mana."
local LINE_WAITS = "Unit frames: Druid mana: the bar waits for the end of the fight."
local LINE_REFUSED = "Unit frames: Druid mana: the game refused the texture of the bar, so it does not show."

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True for a druid: UnitClass gives the class file plainly (UnitDocumentation.lua:911-928).
local function Druid()
	if type(UnitClass) ~= "function" then
		return false
	end
	local ok, _, class = pcall(UnitClass, "player")
	return ok and not IsSecret(class) and class == "DRUID"
end

-- True while the bar is wanted: the module on, the row on, the part not stopped, and the player a druid.
local function Wanted()
	return ns.Enabled(KEY) and Opt("druidMana") == true and not ns.PartStopped(KEY, PART) and Druid()
end

-- The fill of the bar: the texture of the frame's power bar, a white image for a solid fill.
local function File()
	local file = X.fillFile("power")
	if file == nil then
		file = ns.BarTexture()
	end
	return file or WHITE
end

-- The frame the bar hangs from: the outlined power bar of a styled frame, else the game's power bar.
local function Anchor(rec)
	local entry = rec.byRole and rec.byRole.power
	return entry and entry.target or rec.parts.power
end

-- The frame, the bar and its outline, made once out of combat. Nil when the player frame has no bar to hang it from, or when the game refuses the
-- texture the bar needs, which is not tried again.
local function Make(rec)
	local parent, anchor = rec.parts.badges or rec.parts.owner, Anchor(rec)
	if parent == nil or anchor == nil or ns.Forbidden(parent) or ns.Forbidden(anchor) then
		return nil
	end
	local holder = X.frame(parent)
	holder:Hide()
	local bar = CreateFrame("StatusBar", nil, holder)
	ns.Own[bar] = true
	bar:SetAllPoints(holder)
	local d = { holder = holder, bar = bar, shown = false, form = false }
	local ok, done = pcall(bar.SetStatusBarTexture, bar, WHITE)
	if not ok or (not IsSecret(done) and done == false) then
		rec.druidRefused = true
		ns.Note(KEY, LINE_REFUSED)
		return nil
	end
	d.file = WHITE
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	d.outline = ns.Outline(holder, bar)
	rec.druidMana = d
	return d
end

-- Where the bar hangs: the bar it hangs from, the gap under it and the height, in the units of the frame, and the key of that layout. Nil when there
-- is no bar to hang from. In one frame the gap clears the frame's margin and border, and the key says so, so a change of Frame style hangs it again.
local function Layout(rec, d)
	local anchor = Anchor(rec)
	if anchor == nil or ns.Forbidden(anchor) then
		return nil
	end
	local t = ns.Get("general.thickness")
	t = ns.Finite(t) and t or 1
	local joined = type(X.joined) == "function" and X.joined(rec) == true
	local gap
	if joined then
		gap = ns.Pixels(d.holder, 3 * t + 2 * (tonumber(Opt("powerSpace")) or 0))
	else
		gap = math.max(1, ns.Pixels(d.holder, 2 * t))
	end
	local tall = ns.Pixels(d.holder, HEIGHT_PX)
	return anchor, gap, tall, ("%.3f:%.3f"):format(gap, tall) .. (joined and ":body" or "")
end

-- True while the bar hangs as the layout says.
local function Placed(rec, d)
	local anchor, _, _, key = Layout(rec, d)
	return anchor == nil or (d.placed == key and d.anchor == anchor)
end

-- Hangs the bar under the power bar, again only when the border thickness, the space, the scale, the frame style or the bar it hangs from changed.
local function Place(rec, d)
	local anchor, gap, tall, key = Layout(rec, d)
	if anchor == nil or (d.placed == key and d.anchor == anchor) then
		return
	end
	local holder = d.holder
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
	holder:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -gap)
	holder:SetHeight(tall)
	d.placed, d.anchor = key, anchor
end

-- The fill, the colour of mana and the outline as the frame's bars have them.
local function Paint(d)
	local file = File()
	if d.file ~= file then
		local ok, done = pcall(d.bar.SetStatusBarTexture, d.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(d.bar.SetStatusBarTexture, d.bar, WHITE)
		end
		d.file = file
	end
	local r, g, b = ns.PowerColour(TOKEN)
	if r == nil then
		r, g, b = BLUE[1], BLUE[2], BLUE[3]
	end
	if type(X.mute) == "function" then
		r, g, b = X.mute(r, g, b)
	end
	pcall(d.bar.SetStatusBarColor, d.bar, r, g, b, 1)
	if d.outline then
		ns.SetOutlineEdges(d.outline, Opt("barBorder") ~= false)
		X.outline(d.outline, true, Opt("backdrop"))
	end
end

-- The mana and its most, unread, onto the bar.
local function Feed(d)
	local okMost, most = pcall(UnitPowerMax, "player", MANA)
	if okMost then
		pcall(d.bar.SetMinMaxValues, d.bar, 0, most)
	end
	local ok, mana = pcall(UnitPower, "player", MANA)
	if ok then
		pcall(d.bar.SetValue, d.bar, mana)
	end
end

-- True while the power is plainly not mana. A withheld or missing answer keeps the last one.
local function InForm(d)
	local ok, kind = pcall(UnitPowerType, "player")
	if ok and ns.Finite(kind) then
		d.form = kind ~= MANA
	end
	return d.form == true
end

-- Shows the bar while the druid's power is not mana, with the mana on it.
local function Show(d)
	local show = Wanted() and InForm(d)
	if d.shown ~= show then
		d.holder:SetShown(show)
		d.shown = show
	end
	if show then
		Feed(d)
	end
end

local function OnEvent(d, event, unit, token)
	if event:find("^UNIT_") and not IsSecret(unit) and unit ~= "player" then
		return
	end
	if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
		-- Another power of the player changed: the mana did not.
		if not IsSecret(token) and token ~= TOKEN then
			return
		end
		if d.shown then
			Feed(d)
		end
		return
	end
	Show(d)
end

-- The frame of the addon's own that hears the player's power while the bar is wanted, and nothing when it is not.
local function Hear(d, on)
	if (d.hearing or false) == on then
		return
	end
	local ear = d.ear
	if ear == nil then
		if not on then
			return
		end
		ear = CreateFrame("Frame")
		ns.Own[ear] = true
		ear:SetScript("OnEvent", function(_, event, ...)
			X.run(PART, OnEvent, d, event, ...)
		end)
		d.ear = ear
	end
	pcall(ear.UnregisterAllEvents, ear)
	d.hearing = false
	if not on then
		return
	end
	for _, event in ipairs(UNIT_EVENTS) do
		local ok, done = false, nil
		if type(ear.RegisterUnitEvent) == "function" then
			ok, done = pcall(ear.RegisterUnitEvent, ear, event, "player")
		end
		-- A client that cannot hear one unit: every unit's event comes, and OnEvent keeps the player's.
		if not (ok and (IsSecret(done) or done ~= false)) then
			pcall(ear.RegisterEvent, ear, event)
		end
	end
	for _, event in ipairs(EVENTS) do
		pcall(ear.RegisterEvent, ear, event)
	end
	d.hearing = true
end

-- The bar of the player frame: made for a druid out of combat, laid out out of combat, and shown in any form whose power is not mana.
local function DruidMana(rec)
	if rec.kind ~= "player" then
		return
	end
	local d = rec.druidMana
	if not Wanted() then
		if d then
			d.holder:Hide()
			d.shown = false
			Hear(d, false)
		end
		return
	end
	if d == nil then
		if rec.druidRefused then
			return
		end
		if InCombatLockdown() then
			-- Made on a frame the game protects, which waits for the end of the fight once.
			if not rec.druidQueued then
				rec.druidQueued = true
				ns.OutOfCombat(function()
					rec.druidQueued = nil
					X.run(PART, DruidMana, rec)
				end)
			end
			return
		end
		d = Make(rec)
		if d == nil then
			return
		end
	end
	if not InCombatLockdown() then
		Place(rec, d)
	elseif not rec.druidPlaceQueued and not Placed(rec, d) then
		rec.druidPlaceQueued = true
		ns.OutOfCombat(function()
			rec.druidPlaceQueued = nil
			X.run(PART, DruidMana, rec)
		end)
	end
	Paint(d)
	Hear(d, true)
	Show(d)
end

-- The player frame's record is made for the frame whatever its row says, but the steps after a frame's work run only for a frame Flat UI styles,
-- so each Refresh looks at it as well: the bar also hangs under the game's own frame.
local function OnRefresh()
	local rec = X.known(_G.PlayerFrame)
	if rec then
		DruidMana(rec)
	end
end

ns.AddStatus(KEY, function()
	local rec = X.known(_G.PlayerFrame)
	if not (rec and Wanted()) then
		return {}
	end
	if rec.druidMana == nil then
		return rec.druidQueued and { LINE_WAITS } or {}
	end
	return { LINE_SHOWN }
end)

table.insert(X.after.apply, { part = PART, fn = DruidMana })
table.insert(X.after.refresh, { part = PART, fn = OnRefresh })
