local _, ns = ...

-- Healer mana: a small window of Flat UI's own with the mana of the healers of the group, one bar each in the order of the group, in the class
-- colour of the member, with the share of mana left. A healer is a member whose role is healer (UnitGroupRolesAssigned, UnitDocumentation.lua:
-- 1318-1332), or, while nobody in the group has that role, a member with no role of a class that heals (Priest, Paladin, Shaman and Druid, as
-- Setup.lua lists them): in a group that uses the healer role, a member who set none is most likely no healer, as H.Read says. The guess by
-- class leaves out the player while his role reads tank, or damage with talent points spent (ns.PlayerRole, ns.PlayerTree: a Retribution
-- paladin, a Feral druid, a Shadow priest), and anyone else while the game gives him its tank aura (a Righteous Fury paladin, a bear), plain
-- answers only (H.Healer); it is read again as talents change and as each fight ends, so a tank who took his form for the pull drops off. The share is
-- UnitPowerPercent of the member's mana through the game's curve to 100 (UnitDocumentation.lua:2838-2857, CurveConstants.lua:9-12), as
-- UnitText.lua writes a power share, so a druid in a form shows mana too. The game may withhold it (SecretWhenUnitPowerRestricted): it is never
-- read, compared or added, and goes as it is to SetValue of the bar and to SetFormattedText of its text, which take it
-- (SimpleStatusBarAPIDocumentation.lua:355-365, SimpleFontStringAPIDocumentation.lua:539-548), as the Threat list does. A member offline or dead
-- has an empty bar with the word, from plain answers only. Below Low mana at a bar takes a red wash, also in a fight while the game withholds
-- the share: the share goes through a step curve of Flat UI's own (C_CurveUtil.CreateCurve, Enum.LuaCurveType.Step: 1 below the limit, 0
-- from it, as HealthColour.lua's low health border has it) and its answer, withheld or not, to SetAlpha of the wash, which takes it
-- (SimpleRegionAPIDocumentation.lua: SetAlpha, AllowedWhenTainted); a client that refuses leaves the wash off and says so in /flatui status.
-- With Show who is drinking, out of combat and while the game lets auras be read (C_Secrets.ShouldAurasBeSecret false, as Trackers read the
-- buffs of the group), a member with the buff named as spell 430 (Drink, in the client's language: C_Spell.GetSpellName) shows a cup and
-- the seconds left on his drink before his share, "18s 47%", from C_UnitAuras.GetAuraDataBySpellName and its expirationTime with plain answers
-- only, counting down at each step of half a second until he stands; where the game gives no plain time it reads "Drinking 47%".
-- With Dim healers out of range, the bar of a healer who is not the player (UnitIsUnit, plain answers only) and not offline or dead fades to
-- 45% while UnitInRange says he is out of range, also in a fight: that answer is always withheld (UnitDocumentation.lua UnitInRange), so it goes as it is to SetAlphaFromBoolean of the bar,
-- which takes it, as the party frames dim (UnitExtras.lua); a client that refuses leaves the bars bright and says so in /flatui status. The window shows in a dungeon or raid, or in
-- any group, as Show says, while the group has a healer; it is drawn again on a step of half a second only while it shows, and the group is
-- read again when it changes (GROUP_ROSTER_UPDATE, PLAYER_ROLES_ASSIGNED, PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, and for the guess by
-- class PLAYER_TALENT_UPDATE, CHARACTER_POINTS_CHANGED and PLAYER_REGEN_ENABLED; a burst is read once, a moment after the first).
-- A bar glides to each new share (Enum.StatusBarInterpolation.ExponentialEaseOut, as the Threat list and the pet target bar have it), a withheld one
-- too, while it shows the same healer (his unit token); a bar that turns to another healer, comes back from Offline or Dead or from hiding as the
-- list shrank, a sample, a list that just showed or a client with no interpolation takes the value at once.
-- While the game gives every share of the healers shown plainly (out of a fight, as a rule), the title reads their average, "Healer mana 64%",
-- the members offline or dead left out, in the red of the wash while it is under Low mana at; as soon as one share is withheld it reads Healer
-- mana alone, as nothing withheld is added. The three samples read 48%. Ready to pull: out of a fight, with no healer shown offline or dead,
-- once the lowest of those plain shares is at Ready at (90%) or above, the title turns green and reads "Healer mana 97% · ready", gives a
-- short soft pulse of its opacity (H.Pulse) as it turns so, and Sound when ready (None by default) plays once; it rings again only after a
-- healer was seen under Ready at out of a fight, so a login, a zone-in, a refresh or the list showing again with full healers stays quiet
-- (H.Ready). A title too wide for the window takes a shorter form, "Healers 97% · ready", then "97% · ready" (and "Healers 64%", "64%"), so
-- the word ready is never cut. In test mode the samples read ready for READY_TIME seconds after each run of the sample Druid's drink
-- (H.SamplePhase), with their ready shares, no cup and none out of range, and Sound when ready plays once each time test mode comes on;
-- /flatui healers alone is never ready.
-- The window is a child of UIParent in the LOW strata in the look of the Threat list (Threat.lua): a flat background and a thin border in the
-- colours of the Flat UI page, its bars in Bar texture (the bar texture of that page by default); it takes no mouse and hides with the
-- interface. It fades in over 0.15 seconds as it shows and out over 0.35 as it hides, as the Threat list does (H.Showing); showing again while it
-- fades out stops the fade at once, and turning the module off hides it at once. /flatui move places it (FlatUIHealerMana in Movers.lua: the
-- window's top left corner is the top left corner of the box, or with Bars stack Up its bottom left corner the bottom left corner of the box, so
-- a list above the action bars grows upward). /flatui healers shows sample bars for a few seconds, the Shaman out of range, out of a fight only;
-- while test mode is on (TestMode.lua) they stay, drawn with the rows at each refresh and each second, so the sample Druid's drink counts down
-- from 18s to 1s, the samples read ready for 4 seconds, and it starts again. With test mode's Group at Raid 10, 20 or 40 the sample holds
-- eight healers (SAMPLE_RAID), so Number of bars and Bars stack Up can be judged; Solo and Party keep the three.
-- Nothing of the game is changed.
-- This follows the Healer Mana indicator of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoL/Submodules/
-- GroupTools.lua:485-713): the healers of the group by their role, their mana share through UnitPowerPercent and the curve to 100, and the
-- dungeon or raid rule. Its lines of text, fonts, alignment and name width are bars in the look of the Threat list here, and while nobody in the
-- group has the healer role a member with no role is counted by class, since groups on Forever often have no roles.

local KEY = "healermana"
local MOVER = "FlatUIHealerMana"
-- The box of the handle in Movers.lua: the room of three bars at the default size, and where it is with no spot saved, right of the middle and
-- under the Threat list.
local BOX_W, BOX_H, BOX_X, BOX_Y = 158, 76, 420, -130
-- Units inside the edge of the window, between two bars, and between the end of a bar and its text.
local PAD, GAP, INSET = 4, 2, 4
-- A burst of events is read once, this long after the first. The step while the list shows. How long /flatui healers shows.
local STEP, TICK, TEST_TIME = 0.2, 0.5, 8
-- The most bars: one for each member of a full raid (MAX_RAID_MEMBERS, Blizzard_FrameXMLBase/Shared/Constants.lua:1), as H.Read reads raid1
-- to raid40. A raid of forty often has more than ten healers, and more than twenty by class when nobody has a role, so Number of bars can show
-- each of them, as EnhanceQoL writes a line for every healer (EnhanceQoL/Submodules/GroupTools.lua:680-686).
local MOST_ROWS = 40
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TITLE = "Healer mana"
-- The power type of mana (Enum.PowerType.Mana).
local MANA = 0
-- The classes that heal (Setup.lua, S.HEALERS).
local HEALERS = { PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true }
-- The text-dim of the windows (PanelLook.lua) for the title, the track behind a fill, and the colour of a member whose class the game withholds,
-- as the Threat list has them.
local DIM = { 0.66, 0.68, 0.62 }
local TRACK = { 0.2, 0.2, 0.2, 0.5 }
local GREY = { 0.6, 0.6, 0.6 }
-- The red wash of a bar below Low mana at, and the green of the title once the healers are ready to pull (the green of Group tools' ready check).
local LOW = { 0.85, 0.15, 0.1, 0.45 }
local READY = { 0.4, 0.9, 0.4 }
-- The places of the Sound when ready choices in ns.SOUNDS (IconRow.lua), as the Threat list has them.
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
-- The spell whose name is the buff of drinking (Drink), and the cup, cropped as Flat UI's icons are.
local DRINK_SPELL, DRINK_ICON, CROP = 430, "Interface\\Icons\\INV_Drink_07", 0.08
local LINE_MISSING = "Healer mana: this client has no UnitPowerPercent, so the list stays hidden."
local LINE_LOW = "Healer mana: the game refused the red wash of Low mana at, so a bar may not turn red."
local LINE_RANGE = "Healer mana: the game refused to fade a bar by its answer about range, so healers out of range stay bright."
-- The opacity of the bar of a healer out of range, and how long the window fades in as it shows and out as it hides.
local FAR = 0.45
local FADE_IN, FADE_OUT = 0.15, 0.35
local HELP = { "/flatui healers - sample bars of the healer mana list for a few seconds" }
-- The bars of /flatui healers: a name, a class, the share of mana, whether the member drinks, whether he is out of range, and the share he
-- shows while test mode previews Ready to pull (H.SamplePhase). With test mode's Group a raid the sample holds eight healers (SAMPLE_RAID), so
-- Number of bars and Bars stack Up can be judged.
local SAMPLE = { { "Priest", "PRIEST", 82, false, false, 96 }, { "Druid", "DRUID", 47, true, false, 100 }, { "Shaman", "SHAMAN", 15, false, true, 93 } }
local SAMPLE_RAID = { SAMPLE[1], SAMPLE[2], SAMPLE[3], { "Paladin", "PALADIN", 91, false, false, 98 }, { "Priest", "PRIEST", 64, false, false, 95 },
	{ "Druid", "DRUID", 38, false, false, 97 }, { "Shaman", "SHAMAN", 73, false, false, 100 }, { "Paladin", "PALADIN", 22, false, false, 94 } }
-- The seconds left on the sample Druid's drink: in test mode they count down from it to 1, then the samples read ready for READY_TIME seconds,
-- and it starts again.
local SAMPLE_DRINK, READY_TIME = 18, 4
-- The shorter forms of the title, tried in turn while the one written does not fit the window (H.Title): with the average, and ready to pull.
local TITLE_FORMS = { TITLE .. " %d%%", "Healers %d%%", "%d%%" }
local READY_FORMS = { TITLE .. " %d%% · ready", "Healers %d%% · ready", "%d%% · ready" }
-- The pulse of the title as it turns ready: its opacity dips to this twice, each dip PULSE_STEP seconds down and as long up.
local PULSE_LOW, PULSE_STEP = 0.4, 0.2

local IsSecret = ns.IsSecret
-- frame: the window, title its line. rows: the bars. healers: the units of the healers, read from the group. pending: a read waits. ticker: the
-- token of the step. sample: the token of /flatui healers while it shows. placed: the spot the window was put at, laid: the layout of its bars.
local H = { rows = {}, healers = {} }
ns.HealerMana = H

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- A number row, else its default.
local function Number(key, default)
	local value = Opt(key)
	return ns.Finite(value) and value or default
end

-- A count the game gives, as a whole number from 0 to most.
local function Count(fn, most)
	local value = Ask(fn)
	if ns.Finite(value) and value > 0 then
		return math.min(math.floor(value), most)
	end
	return 0
end

-- A timer of the client, false when there is none or it raises.
local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

-- The step curve of the red wash: 1 below Low mana at, 0 from it, made again when the row changes. Nil when the client has none or refuses it,
-- which is noted for the status.
local function LowCurve(at)
	if H.step ~= nil and H.stepAt == at then
		return H.step or nil
	end
	H.stepAt = at
	local ok, curve = pcall(function()
		local made = C_CurveUtil.CreateCurve()
		made:SetType(Enum.LuaCurveType.Step)
		made:AddPoint(0, 1)
		made:AddPoint(at / 100, 0)
		return made
	end)
	H.step = ok and curve or false
	H.lowRefused = not ok or nil
	return H.step or nil
end

-- Whether other units' auras may be read now: out of combat, and while the game says aura values are open.
local function AurasOpen()
	if Ask(InCombatLockdown) ~= false then
		return false
	end
	local secrets = C_Secrets
	local call = type(secrets) == "table" and not IsSecret(secrets) and secrets.ShouldAurasBeSecret or nil
	if type(call) ~= "function" then
		return true
	end
	return Ask(call) == false
end

-- The name of the buff of drinking in the client's language, or nil.
local function DrinkName()
	if H.drinkName == nil then
		local spells = C_Spell
		local name = type(spells) == "table" and not IsSecret(spells) and Ask(spells.GetSpellName, DRINK_SPELL) or nil
		H.drinkName = type(name) == "string" and name ~= "" and name or false
	end
	return H.drinkName or nil
end

-- True while a unit has the buff of drinking, from a plain answer only, and then when the drink ends on the clock of GetTime (expirationTime of
-- its AuraData, read so by Blizzard_AuraContainer/Blizzard_AuraButton.lua:166), or nil when the game gives no plain time.
local function Drinking(unit)
	local name = DrinkName()
	local auras = C_UnitAuras
	if not name or type(auras) ~= "table" or IsSecret(auras) then
		return false
	end
	local aura = Ask(auras.GetAuraDataBySpellName, unit, name, "HELPFUL")
	if type(aura) ~= "table" then
		return false
	end
	local ok, ends = pcall(function()
		return aura.expirationTime
	end)
	if ok and not IsSecret(ends) and ns.Finite(ends) and ends > 0 then
		return true, ends
	end
	return true, nil
end

-- The seconds left on a drink that ends at ends, whole and rounded up, or nil when there is no plain time or it is over.
local function DrinkLeft(ends)
	local now = ends and Ask(GetTime)
	if not ns.Finite(now) or ends <= now then
		return nil
	end
	return math.ceil(ends - now)
end

-- The curve that turns a share of 1 into 100, or nil when the client has none.
local function Hundred()
	local constants = CurveConstants
	if type(constants) ~= "table" or IsSecret(constants) then
		return nil
	end
	local ok, curve = pcall(function()
		return constants.ScaleTo100
	end)
	if ok and not IsSecret(curve) and curve ~= nil then
		return curve
	end
	return nil
end

-- Who and when -----------------------------------------------------------------------------------------------------------------------------------

-- True when Show lets the list show now: in a dungeon or raid, or in any group.
function H.Allowed()
	if Ask(IsInGroup) ~= true then
		return false
	elseif Opt("show") == "group" then
		return true
	end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and not IsSecret(inside) and inside == true and not IsSecret(kind) and (kind == "party" or kind == "raid")
end

-- True when a member of a class that heals is plainly no healer now, for the guess by class: the player, when ns.PlayerRole (Core.lua: the
-- tank stance, form or aura nameplate threat reads, else the talents) says tank, or says damage while ns.PlayerTree finds points in a tree, so a
-- Retribution paladin or a Shadow priest is left out and a low-level healer with no points spent keeps the guess; anyone else, while the game
-- gives him its tank aura (UnitHasEffectivelyTankAura, his tank stance, form or aura, plain for party members as nameplate threat reads it,
-- PlateThreat.lua), so a Righteous Fury paladin or a bear tank is left out. A withheld or missing answer keeps the guess.
local function NoHealer(unit)
	if Ask(UnitIsUnit, unit, "player") == true then
		local ok, role = pcall(ns.PlayerRole)
		if not ok or IsSecret(role) then
			return false
		elseif role == "tank" then
			return true
		elseif role == "damage" and type(ns.PlayerTree) == "function" then
			local fine, tree = pcall(ns.PlayerTree)
			return fine and ns.Finite(tree) and true or false
		end
		return false
	end
	return Ask(UnitHasEffectivelyTankAura, unit) == true
end

-- True for a healer: the role says so, or the member has no role and is of a class that heals and is not plainly something else now (NoHealer),
-- and then the second answer is true. A withheld role counts as none.
function H.Healer(unit)
	local role = Ask(UnitGroupRolesAssigned, unit)
	if role == "HEALER" then
		return true, false
	elseif role == "TANK" or role == "DAMAGER" then
		return false, false
	end
	local class = Ask(UnitClassBase, unit)
	if type(class) ~= "string" or HEALERS[class] ~= true then
		return false, true
	elseif NoHealer(unit) then
		return false, true
	end
	return true, true
end

-- The healers of the group in its order: in a raid raid1 to raid40, the player among them; else the player, then party1 to party4. A member with
-- no role counts by class only while nobody in the group has the healer role. Each player sets their own role, in the listing of the group finder
-- or in the poll the leader starts (Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Listing.lua:579-593, 626-629, Mainline/RolePoll.lua:
-- 131-135), and one who sets none reads as NONE (Blizzard_LFGVanilla_Listing.lua:597-600). In a group where someone took the healer role, a
-- member with none is most likely no healer: the game counts one as damage (Blizzard_FrameXMLUtil/PartyUtil.lua:110-115) and shows the power
-- bars of healers by the role alone (Blizzard_UnitFrame/Shared/CompactUnitFrame.lua:1889-1891), as EnhanceQoL counts the role only
-- (EnhanceQoL/Submodules/GroupTools.lua:636-641). So a guess by class neither adds a bar nor takes the place of a healer under Number of bars.
function H.Read()
	local byRole, byClass = {}, {}
	local function Member(unit)
		if Ask(UnitExists, unit) == true then
			local healer, guessed = H.Healer(unit)
			if healer then
				local list = guessed and byClass or byRole
				list[#list + 1] = unit
			end
		end
	end
	if Ask(IsInRaid) == true then
		for index = 1, Count(GetNumGroupMembers, 40) do
			Member("raid" .. index)
		end
	elseif Ask(IsInGroup) == true then
		Member("player")
		for index = 1, Count(GetNumSubgroupMembers, 4) do
			Member("party" .. index)
		end
	end
	return #byRole > 0 and byRole or byClass
end

-- Drawing -----------------------------------------------------------------------------------------------------------------------------------

-- Red, green and blue of a class by its file name, or nil.
local function ClassRGB(class)
	local colours = RAID_CLASS_COLORS
	if type(class) ~= "string" or type(colours) ~= "table" or IsSecret(colours) then
		return nil
	end
	local colour = colours[class]
	if type(colour) ~= "table" or IsSecret(colour) then
		return nil
	end
	local r, g, b = colour.r, colour.g, colour.b
	if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return nil
end

-- Writes the name of a unit, or nothing; a withheld name goes to the text as it is.
local function SetName(text, unit)
	local ok, name = pcall(UnitName, unit)
	if ok and (IsSecret(name) or type(name) == "string") then
		text:SetText(name)
	else
		text:SetText("")
	end
end

-- The fades of a window of the addon's own: an Alpha animation from 0 to 1, and one from 1 to 0 that hides the window as it ends and puts its
-- opacity back. Nil for each where the client makes none. The Threat list has the same (Threat.lua).
local function Fades(frame)
	local ok, fadeIn, fadeOut = pcall(function()
		local come = frame:CreateAnimationGroup()
		local rise = come:CreateAnimation("Alpha")
		rise:SetFromAlpha(0)
		rise:SetToAlpha(1)
		rise:SetDuration(FADE_IN)
		local go = frame:CreateAnimationGroup()
		local fall = go:CreateAnimation("Alpha")
		fall:SetFromAlpha(1)
		fall:SetToAlpha(0)
		fall:SetDuration(FADE_OUT)
		pcall(go.SetToFinalAlpha, go, true)
		go:SetScript("OnFinished", function()
			frame:Hide()
			frame:SetAlpha(1)
		end)
		return come, go
	end)
	if ok then
		return fadeIn, fadeOut
	end
	return nil, nil
end

-- Sets the value of a bar, gliding to it where the client has the interpolation (Threat.lua has the same), at once with now or where it has not.
-- A withheld value goes as it is, as to SetValue. False when the client refuses the value.
local function Glide(bar, value, now)
	local list = not now and type(Enum) == "table" and Enum.StatusBarInterpolation or nil
	local how = type(list) == "table" and list.ExponentialEaseOut or nil
	if how ~= nil and pcall(bar.SetValue, bar, value, how) then
		return true
	end
	return (pcall(bar.SetValue, bar, value))
end

-- Shows the window, fading in when it was hidden and stopping a fade out at once, or fades it out; at once with now or with no fades. Hiding
-- forgets whose share each bar shows, so the next one takes its value at once.
function H.Showing(on, now)
	local frame, fadeIn, fadeOut = H.frame, H.fadeIn, H.fadeOut
	if not frame then
		return
	end
	if not on then
		for _, row in ipairs(H.rows) do
			row.who = nil
		end
		-- A list that shows again with full healers does not ring Sound when ready (H.Ready).
		H.armed = nil
	end
	local fading = fadeOut ~= nil and fadeOut:IsPlaying()
	if on then
		if fading then
			pcall(fadeOut.Stop, fadeOut)
			frame:SetAlpha(1)
		end
		if not frame:IsShown() then
			frame:SetAlpha(1)
			frame:Show()
			if fadeIn and not now then
				pcall(fadeIn.Play, fadeIn)
			end
		end
		return
	end
	if fadeIn and fadeIn:IsPlaying() then
		pcall(fadeIn.Stop, fadeIn)
	end
	if now or not fadeOut or not frame:IsShown() then
		if fading then
			pcall(fadeOut.Stop, fadeOut)
		end
		frame:Hide()
		frame:SetAlpha(1)
	elseif not fading and not pcall(fadeOut.Play, fadeOut) then
		frame:Hide()
	end
end

-- The window, made the first time it shows: a frame of the addon's own on UIParent with a flat background and a thin border, and its title.
function H.Frame()
	if H.frame then
		return H.frame
	end
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	frame:SetFrameStrata("LOW")
	frame:SetSize(BOX_W, BOX_H)
	frame:Hide()
	H.frame = frame
	H.outline = ns.Outline(frame, frame, true)
	local title = ns.OwnText(frame, "OVERLAY", FONT)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + INSET, -PAD)
	title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + INSET), -PAD)
	title:SetText(TITLE)
	H.title = title
	H.fadeIn, H.fadeOut = Fades(frame)
	H.pulse = H.Pulse(title)
	return frame
end

-- The soft pulse of the title as it turns ready (H.Title): an animation of the addon's own on its own FontString, two dips of its opacity to
-- PULSE_LOW and back, 0.8 seconds in all, ending at full; nil where the client refuses.
function H.Pulse(title)
	local ok, group = pcall(function()
		local made = title:CreateAnimationGroup()
		for order = 1, 4 do
			local step = made:CreateAnimation("Alpha")
			local down = order % 2 == 1
			step:SetFromAlpha(down and 1 or PULSE_LOW)
			step:SetToAlpha(down and PULSE_LOW or 1)
			step:SetDuration(PULSE_STEP)
			step:SetOrder(order)
		end
		return made
	end)
	return ok and group or nil
end

-- Bar number index, made the first time the list needs it: a track, the fill, the name on the left and the share on the right.
function H.Row(index)
	local row = H.rows[index]
	if row then
		return row
	end
	local bar = Own(CreateFrame("StatusBar", nil, H.frame))
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	local track = Own(bar:CreateTexture(nil, "BACKGROUND", nil, -7))
	track:SetAllPoints(bar)
	track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
	local share = ns.OwnText(bar, "OVERLAY", FONT)
	share:SetJustifyH("RIGHT")
	share:SetWordWrap(false)
	share:SetPoint("RIGHT", bar, "RIGHT", -INSET, 0)
	local name = ns.OwnText(bar, "OVERLAY", FONT)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	name:SetPoint("LEFT", bar, "LEFT", INSET, 0)
	name:SetPoint("RIGHT", share, "LEFT", -INSET, 0)
	-- The red wash over the whole bar, under the text, and the cup left of the share.
	local low = Own(bar:CreateTexture(nil, "OVERLAY", nil, -8))
	low:SetAllPoints(bar)
	low:SetColorTexture(LOW[1], LOW[2], LOW[3], LOW[4])
	low:SetAlpha(0)
	local drink = Own(bar:CreateTexture(nil, "OVERLAY", nil, 1))
	drink:SetTexture(DRINK_ICON)
	drink:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	drink:SetPoint("RIGHT", share, "LEFT", -2, 0)
	drink:Hide()
	row = { bar = bar, track = track, name = name, share = share, low = low, drink = drink, drinking = false }
	H.rows[index] = row
	return row
end

-- Shows or hides the cup of a bar; the name ends at the cup while it shows, else at the share.
function H.Cup(row, on)
	if row.drinking == on then
		return
	end
	row.drinking = on
	row.drink:SetShown(on)
	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row.bar, "LEFT", INSET, 0)
	row.name:SetPoint("RIGHT", on and row.drink or row.share, "LEFT", -INSET, 0)
end

-- The red wash of a bar: shown below Low mana at, from the plain share of a sample or the share through the step curve, withheld or not. Off
-- with Low mana at 0, for a member offline or dead, and where the client refuses.
function H.Wash(row, unit, sample, word)
	local at = Number("lowAt", 30)
	if at <= 0 or word then
		row.low:SetAlpha(0)
		return
	end
	if sample then
		row.low:SetAlpha(H.SampleShare(sample, H.SamplePhase()) < at and 1 or 0)
		return
	end
	local curve = LowCurve(at)
	if not curve then
		row.low:SetAlpha(0)
	elseif not pcall(function()
		row.low:SetAlpha(UnitPowerPercent(unit, MANA, false, curve))
	end) then
		row.low:SetAlpha(0)
		H.lowRefused = true
	end
end

-- Dim healers out of range: the bar of a member who is not the player fades to FAR while UnitInRange says he is out of range, its answer, withheld
-- or not, going as it is to SetAlphaFromBoolean of the bar. Full opacity for the player, a word (offline, dead), with the row off and where the
-- client has no answer; a client that refuses is noted for the status. A sample is out of range by its fifth field.
function H.Range(row, unit, sample, word)
	local bar = row.bar
	if Opt("range") == false or word then
		bar:SetAlpha(1)
		return
	end
	if sample then
		bar:SetAlpha(sample[5] == true and H.SamplePhase() ~= "ready" and FAR or 1)
		return
	end
	if Ask(UnitIsUnit, unit, "player") ~= false or type(UnitInRange) ~= "function" or type(bar.SetAlphaFromBoolean) ~= "function" then
		bar:SetAlpha(1)
		return
	end
	local ok, inRange = pcall(UnitInRange, unit)
	if not ok or not (IsSecret(inRange) or type(inRange) == "boolean") then
		bar:SetAlpha(1)
	elseif pcall(bar.SetAlphaFromBoolean, bar, inRange, 1, FAR) then
		H.rangeRefused = nil
	else
		bar:SetAlpha(1)
		H.rangeRefused = true
	end
end

-- Bar texture, and the height of the text and of the cup, on one bar. A texture the game refuses leaves a flat fill. The heights are given on
-- every draw, a few calls: Fonts, which starts after this module at login (MODULE_ORDER in Core.lua), may set the font object of the text again
-- (Fonts.lua), and a string can take its font object's height back, as the Threat list has it.
local function Paint(row, file, text)
	if row.file ~= file then
		local ok, done = pcall(row.bar.SetStatusBarTexture, row.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(row.bar.SetStatusBarTexture, row.bar, WHITE)
		end
		row.file = file
	end
	row.name:SetTextHeight(text)
	row.share:SetTextHeight(text)
	row.drink:SetSize(text, text)
end

-- Lays out the title and n bars, and sizes the window to them. The heights of the text are given each time (Paint); a layout that is already in
-- place is left as it is. The text is as high as the bar allows, as on the Threat list.
function H.Layout(n)
	local width, height = Number("barWidth", 150), Number("barHeight", 16)
	local text = math.max(7, math.min(14, height - 4))
	local file = ns.BarTexture(Opt("barTexture")) or WHITE
	for index = 1, n do
		Paint(H.Row(index), file, text)
	end
	H.title:SetTextHeight(text)
	local key = ("%s:%s:%s"):format(n, width, height)
	if H.laid == key then
		return
	end
	H.laid = key
	-- A new width or text height may fit another form of the title (H.Title).
	H.titled = nil
	local top = PAD + text + 2 + GAP
	for index = 1, n do
		local bar = H.rows[index].bar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", H.frame, "TOPLEFT", PAD, -(top + (index - 1) * (height + GAP)))
		bar:SetSize(width, height)
	end
	H.frame:SetSize(width + 2 * PAD, top + n * height + (n - 1) * GAP + PAD)
end

-- Where the samples are: in test mode (H.sampleStart, set as it starts) the seconds left on the sample Druid's drink, SAMPLE_DRINK down to 1,
-- one a second, then "ready" for READY_TIME seconds, while every sample reads its ready share, and again; for /flatui healers alone
-- SAMPLE_DRINK, never ready.
function H.SamplePhase()
	local now = H.sampleStart and Ask(GetTime)
	if not ns.Finite(now) or now < H.sampleStart then
		return SAMPLE_DRINK
	end
	local into = math.floor(now - H.sampleStart) % (SAMPLE_DRINK + READY_TIME)
	if into >= SAMPLE_DRINK then
		return "ready"
	end
	return SAMPLE_DRINK - into
end

-- The share a sample shows: its ready share while the samples are ready, at least Ready at so the preview turns ready whatever it is set to,
-- else its share.
function H.SampleShare(sample, phase)
	if phase == "ready" then
		return math.min(100, math.max(sample[6], Number("readyAt", 90)))
	end
	return sample[3]
end

-- The samples: eight healers while test mode is on with a raid as its Group (TestMode.lua: TM.Group), else three.
function H.Samples()
	local mode = ns.TestMode
	local group = mode and mode.IsOn() == true and mode.Group() or nil
	if type(group) == "string" and group:find("^raid") then
		return SAMPLE_RAID
	end
	return SAMPLE
end

-- Writes one bar: the class colour, the name and the share of mana, the red wash below Low mana at, the cup while the member drinks and its
-- fade out of range; the share goes to the bar, its text and the wash untouched. A sample is a table of SAMPLE. The bar glides to a share of the
-- same healer it showed (row.who) in a window that shows, else takes it at once. A plain share is added to the average of the title (H.sum,
-- H.count) and kept when it is the lowest (H.least, for Ready at); a withheld one marks it as unknown (H.hidden).
function H.Fill(row, unit, sample)
	local r, g, b
	if sample then
		r, g, b = ClassRGB(sample[2])
	else
		r, g, b = ns.ClassColourOf(unit)
	end
	if not r then
		r, g, b = GREY[1], GREY[2], GREY[3]
	end
	row.bar:SetStatusBarColor(r, g, b, 1)
	row.bar:Show()
	local drinks = Opt("drinking") ~= false
	if sample then
		local phase = H.SamplePhase()
		local value = H.SampleShare(sample, phase)
		local cup = drinks and sample[4] == true and phase ~= "ready"
		row.name:SetText(sample[1])
		row.bar:SetValue(value)
		row.who = nil
		H.sum, H.count = (H.sum or 0) + value, (H.count or 0) + 1
		H.least = math.min(H.least or value, value)
		if cup then
			row.share:SetText(("%ds %d%%"):format(phase, value))
		else
			row.share:SetText(("%d%%"):format(value))
		end
		H.Wash(row, nil, sample)
		H.Cup(row, cup)
		H.Range(row, nil, sample)
		return
	end
	SetName(row.name, unit)
	local word = nil
	if Ask(UnitIsConnected, unit) == false then
		word = "Offline"
	elseif Ask(UnitIsDeadOrGhost, unit) == true then
		word = "Dead"
	end
	H.Wash(row, unit, nil, word)
	H.Range(row, unit, nil, word)
	if word then
		row.bar:SetValue(0)
		row.who = nil
		row.share:SetText(word)
		H.Cup(row, false)
		-- A healer who is offline or dead is not ready to pull (H.Ready).
		H.away = true
		return
	end
	local cup, ends = false, nil
	if drinks and AurasOpen() then
		cup, ends = Drinking(unit)
	end
	H.Cup(row, cup)
	local left = cup and DrinkLeft(ends) or nil
	local ok, share = pcall(UnitPowerPercent, unit, MANA, false, Hundred())
	local jump = row.who ~= unit or not H.frame:IsShown()
	row.who = unit
	if not ok or not Glide(row.bar, share, jump) then
		row.bar:SetValue(0)
	end
	if ok and not IsSecret(share) and ns.Finite(share) then
		H.sum, H.count = (H.sum or 0) + share, (H.count or 0) + 1
		H.least = math.min(H.least or share, share)
	else
		H.hidden = true
	end
	local written
	if left then
		written = ok and pcall(row.share.SetFormattedText, row.share, "%ds %.0f%%", left, share)
	else
		written = ok and pcall(row.share.SetFormattedText, row.share, cup and "Drinking %.0f%%" or "%.0f%%", share)
	end
	if not written then
		row.share:SetText(left and ("%ds"):format(left) or (cup and "Drinking" or ""))
	end
end

-- Ready to pull: true out of a fight, with none of the healers shown offline or dead (H.away), every share plain and the lowest (H.least) at
-- Ready at or above; never with Ready at 0. A plain lowest share under Ready at, out of a fight, arms Sound when ready (H.armed), which plays
-- once as the healers turn ready and again only after one of them dropped under it: so a login, a zone-in or a refresh with full healers is
-- quiet (H.Refresh and the window hiding disarm it). The samples are ready only in the ready part of test mode's loop (H.SamplePhase), where
-- Sound when ready plays once each time test mode comes on (TM.Sound); /flatui healers alone is never ready.
function H.Ready(average)
	local at = Number("readyAt", 90)
	if average == nil or at <= 0 or H.away or Ask(InCombatLockdown) ~= false or not ns.Finite(H.least) then
		return false
	end
	if H.Sampling() then
		if H.SamplePhase() ~= "ready" or H.least < at then
			return false
		end
		local sound, mode = ns.SOUNDS[KITS[Opt("readySound")] or 0], ns.TestMode
		if sound and mode and mode.IsOn() == true and mode.Sound("healermana.ready") then
			ns.PlayKit(sound[1], KEY)
		end
		return true
	end
	if H.least < at then
		H.armed = true
		return false
	end
	if H.armed then
		H.armed = nil
		local sound = ns.SOUNDS[KITS[Opt("readySound")] or 0]
		if sound then
			ns.PlayKit(sound[1], KEY)
		end
	end
	return true
end

-- True when the title's text is wider than its room, the width of a bar less INSET at each end (H.Frame, H.Layout): measured with
-- GetUnboundedStringWidth, else as IsTruncated says (SimpleFontStringAPIDocumentation.lua:442-454), as CastRank.lua asks it.
local function TitleCut(title)
	local room = Number("barWidth", 150) - 2 * INSET
	local ok, width = pcall(title.GetUnboundedStringWidth, title)
	if ok and not IsSecret(width) and ns.Finite(width) and width > 0 then
		return width > room + 0.5
	end
	if type(title.IsTruncated) == "function" then
		local asked, cut = pcall(title.IsTruncated, title)
		return asked and not IsSecret(cut) and cut == true
	end
	return false
end

-- The title: with the average of the plain shares H.Fill added (H.sum, H.count) and none withheld (H.hidden), "Healer mana 64%", in the red of the
-- wash while under Low mana at; once the healers are ready to pull (H.Ready) "Healer mana 97% · ready" in green, which wins over the red; else
-- Healer mana alone in the text-dim. A form that does not fit the window gives way to a shorter one ("Healers 97% · ready", then
-- "97% · ready"; "Healers 64%", then "64%"), so the word ready is never the part cut. As it turns ready (it was written not ready before, so not
-- as the window first shows or after a refresh) the title gives its soft pulse (H.Pulse), a FontString of the addon's own, in a fight too.
-- Written only when it changes, or when the form written is cut and a shorter one remains.
function H.Title()
	local count, average = H.count or 0, nil
	if count > 0 and not H.hidden then
		average = math.floor((H.sum or 0) / count + 0.5)
	end
	local at = Number("lowAt", 30)
	local low = average ~= nil and at > 0 and average < at
	local ready = H.Ready(average)
	local key = average and ("%d:%s:%s"):format(average, tostring(low), tostring(ready)) or "plain"
	local forms = ready and READY_FORMS or (average and TITLE_FORMS or nil)
	if H.titled == key and not (forms and (H.form or 1) < #forms and TitleCut(H.title)) then
		return
	end
	local form = H.titled == key and (H.form or 1) + 1 or 1
	H.titled = key
	local colour = ready and READY or low and LOW or DIM
	H.title:SetTextColor(colour[1], colour[2], colour[3], 1)
	if forms then
		H.title:SetFormattedText(forms[form], average)
		while form < #forms and TitleCut(H.title) do
			form = form + 1
			H.title:SetFormattedText(forms[form], average)
		end
	else
		H.title:SetText(TITLE)
	end
	H.form = form
	if ready and H.readyShown == false and H.pulse then
		pcall(H.pulse.Stop, H.pulse)
		pcall(H.pulse.Play, H.pulse)
	end
	H.readyShown = ready
end

-- Starts a new average for the title (H.Title).
local function Average()
	H.sum, H.count, H.hidden, H.least, H.away = 0, 0, false, nil, false
end

-- True while the sample bars show: /flatui healers holds them for a few seconds (H.sample), and test mode (TestMode.lua) while it is on.
function H.Sampling()
	local mode = ns.TestMode
	return H.sample ~= nil or (mode ~= nil and mode.IsOn() == true)
end

-- Puts the window at the spot of its handle: its top left corner at the top left corner of the box, or with Bars stack Up its bottom left corner at
-- the bottom left corner of the box, so more bars push the title up (as Rolls stack has it for the loot rolls, Hud.lua). The bars inside keep
-- their order, the title on top.
function H.Place()
	local corner = Opt("grow") == "up" and "BOTTOMLEFT" or "TOPLEFT"
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, corner)
	end
	local key = (x and ("%.2f:%.2f"):format(x, y) or "start") .. ":" .. corner
	if H.placed == key then
		return
	end
	H.placed = key
	local frame = H.frame
	frame:ClearAllPoints()
	if x then
		frame:SetPoint(corner, UIParent, "BOTTOMLEFT", x, y)
	elseif corner == "BOTTOMLEFT" then
		frame:SetPoint(corner, UIParent, "CENTER", BOX_X - BOX_W / 2, BOX_Y - BOX_H / 2)
	else
		frame:SetPoint(corner, UIParent, "CENTER", BOX_X - BOX_W / 2, BOX_Y + BOX_H / 2)
	end
end

-- Shows a bar for each healer, as many as Number of bars allows (the samples for /flatui healers), or hides the window when there are none.
function H.Draw()
	local samples = H.Sampling() and H.Samples() or nil
	local list = samples or H.healers
	local n = math.min(#list, Number("rows", 5), MOST_ROWS)
	if n < 1 then
		H.Showing(false)
		H.Tick(false)
		H.readyShown = nil
		return
	end
	H.Frame()
	H.Layout(n)
	Average()
	for index = 1, n do
		if samples then
			H.Fill(H.rows[index], nil, samples[index])
		else
			H.Fill(H.rows[index], list[index])
		end
	end
	H.Title()
	-- A bar that hides forgets its healer, so it takes his share at once when it shows again (H.Fill).
	for index = n + 1, #H.rows do
		H.rows[index].bar:Hide()
		H.rows[index].who = nil
	end
	H.Place()
	H.Showing(true)
	H.Tick(not samples)
end

-- Reading -----------------------------------------------------------------------------------------------------------------------------------

-- Who the list shows now, and the list drawn.
function H.Update()
	H.pending = nil
	local on = ns.Enabled(KEY) and type(UnitPowerPercent) == "function"
	local sampling = H.Sampling()
	if on and not sampling and H.Allowed() then
		H.healers = H.Read()
	else
		H.healers = {}
	end
	if on or sampling then
		H.Draw()
	elseif H.frame then
		H.Showing(false)
		H.Tick(false)
	end
end

-- Reads the group again a moment later, once for a burst of events.
function H.Soon()
	if H.pending then
		return
	end
	H.pending = true
	if not After(STEP, function()
		ns.Try(KEY, H.Update)
	end) then
		H.Update()
	end
end

-- A step of half a second while the list of a group shows: the shares are drawn again, and nothing is read but them. A client without NewTicker
-- gets a timer that sets the next one while the token is the step's, as the Threat list has it.
local function Step()
	if H.frame and #H.healers > 0 and not H.Sampling() then
		local n = math.min(#H.healers, Number("rows", 5), MOST_ROWS)
		Average()
		for index = 1, math.min(n, #H.rows) do
			H.Fill(H.rows[index], H.healers[index])
		end
		H.Title()
	end
end

function H.Tick(on)
	if on and not H.ticker then
		local token = {}
		H.ticker = token
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, TICK, function()
				ns.Try(KEY, Step)
			end)
			token.handle = ok and ticker or nil
		end
		if not token.handle then
			local function Again()
				if H.ticker == token then
					ns.Try(KEY, Step)
					if H.ticker == token and not After(TICK, Again) then
						H.ticker = nil
					end
				end
			end
			if not After(TICK, Again) then
				H.ticker = nil
			end
		end
	elseif not on and H.ticker then
		local handle = H.ticker.handle
		H.ticker = nil
		if handle and type(handle.Cancel) == "function" then
			pcall(handle.Cancel, handle)
		end
	end
end

function H.Refresh()
	H.pending, H.placed, H.laid, H.armed, H.readyShown = nil, nil, nil, nil, nil
	if not ns.Enabled(KEY) then
		H.sample, H.healers = nil, {}
		H.Tick(false)
		H.Showing(false, true)
		return
	end
	H.Update()
end

-- /flatui healers: the sample bars for a few seconds, out of a fight only (a withheld answer counts as a fight), so they never take the place of
-- the real bars while they matter.
function H.Slash()
	if not ns.Enabled(KEY) then
		print("Healer mana: turn on Show healer mana first.")
		return
	end
	if Ask(InCombatLockdown) ~= false then
		print("Healer mana: the sample shows out of combat.")
		return
	end
	local token = {}
	H.sample = token
	ns.Try(KEY, H.Update)
	local function Done()
		if H.sample == token then
			H.sample = nil
			ns.Try(KEY, H.Update)
		end
	end
	if not After(TEST_TIME, Done) then
		Done()
	end
end

function H.Status()
	local lines = {}
	if ns.Enabled(KEY) and type(UnitPowerPercent) ~= "function" then
		lines[#lines + 1] = LINE_MISSING
	end
	if ns.Enabled(KEY) and H.lowRefused and Number("lowAt", 30) > 0 then
		lines[#lines + 1] = LINE_LOW
	end
	if ns.Enabled(KEY) and H.rangeRefused and Opt("range") ~= false then
		lines[#lines + 1] = LINE_RANGE
	end
	return lines
end

-- The movers ----------------------------------------------------------------------------------------------------------------------------------

-- True while the list has a handle in the movers: while the module is on.
function ns.HealerManaShown()
	return ns.Enabled(KEY)
end

-- The movers set or put back the spot.
function ns.HealerManaMoved()
	H.placed = nil
	if H.frame and ns.Enabled(KEY) then
		ns.Try(KEY, H.Place)
	end
end

local function Soon()
	H.Soon()
end

ns.Register(KEY, {
	label = "Healer mana",
	counted = false,
	Start = H.Refresh,
	Refresh = H.Refresh,
	Resized = H.Refresh,
	Status = H.Status,
	events = { GROUP_ROSTER_UPDATE = Soon, PLAYER_ROLES_ASSIGNED = Soon, PLAYER_ENTERING_WORLD = Soon, ZONE_CHANGED_NEW_AREA = Soon,
		PLAYER_TALENT_UPDATE = Soon, CHARACTER_POINTS_CHANGED = Soon, PLAYER_REGEN_ENABLED = Soon },
	slash = { healers = H.Slash },
	help = HELP,
})

-- Test mode: the sample bars while it is on (H.Sampling), drawn with the rows at each refresh of the page; Off refreshes the page, which draws the
-- healers of the group again or hides the window. Its ticker draws them each second, out of a fight, so the sample Druid's drink counts down
-- from the moment test mode started and the samples then read ready for a few seconds (H.SamplePhase).
if ns.TestMode then
	ns.TestMode.Register("healermana", {
		module = KEY,
		label = "Healer mana",
		refresh = true,
		every = 1,
		Start = function()
			H.sampleStart = Ask(GetTime)
		end,
		Stop = function()
			H.sampleStart = nil
		end,
		Tick = function()
			if Ask(InCombatLockdown) == false then
				H.Update()
			end
		end,
	})
end
