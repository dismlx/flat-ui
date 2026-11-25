local _, ns = ...

-- Healer mana: a small window of Flat UI's own with the mana of the healers of the group, one bar each in the order of the group, in the class
-- colour of the member, with the share of mana left. A healer is a member whose role is healer (UnitGroupRolesAssigned, UnitDocumentation.lua:
-- 1318-1332), or, while nobody in the group has that role, a member with no role of a class that heals (Priest, Paladin, Shaman and Druid, as
-- Setup.lua lists them): in a group that uses the healer role, a member who set none is most likely no healer, as H.Read says. The share is
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
-- Drinking before his share, from C_UnitAuras.GetAuraDataBySpellName with a plain answer only. With Dim healers out of range, the bar of a
-- healer who is not the player (UnitIsUnit, plain answers only) and not offline or dead fades to 45% while UnitInRange says he is out of range,
-- also in a fight: that answer is always withheld (UnitDocumentation.lua UnitInRange), so it goes as it is to SetAlphaFromBoolean of the bar,
-- which takes it, as the party frames dim (UnitExtras.lua); a client that refuses leaves the bars bright and says so in /flatui status. The window shows in a dungeon or raid, or in
-- any group, as Show says, while the group has a healer; it is drawn again on a step of half a second only while it shows, and the group is
-- read again when it changes (GROUP_ROSTER_UPDATE, PLAYER_ROLES_ASSIGNED, PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA; a burst is read once,
-- a moment after the first).
-- The window is a child of UIParent in the LOW strata in the look of the Threat list (Threat.lua): a flat background and a thin border in the
-- colours of the Flat UI page, its bars in Bar texture (the bar texture of that page by default); it takes no mouse and hides with the
-- interface. It fades in over 0.15 seconds as it shows and out over 0.35 as it hides, as the Threat list does (H.Showing); showing again while it
-- fades out stops the fade at once, and turning the module off hides it at once. /flatui move places it (FlatUIHealerMana in Movers.lua: the
-- window's top left corner is the top left corner of the box). /flatui healers shows sample bars for a few seconds, the Shaman out of range;
-- while test mode is on (TestMode.lua) they stay, drawn with the rows at each refresh.
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
-- The red wash of a bar below Low mana at.
local LOW = { 0.85, 0.15, 0.1, 0.45 }
-- The spell whose name is the buff of drinking (Drink), and the cup, cropped as Flat UI's icons are.
local DRINK_SPELL, DRINK_ICON, CROP = 430, "Interface\\Icons\\INV_Drink_07", 0.08
local LINE_MISSING = "Healer mana: this client has no UnitPowerPercent, so the list stays hidden."
local LINE_LOW = "Healer mana: the game refused the red wash of Low mana at, so a bar may not turn red."
local LINE_RANGE = "Healer mana: the game refused to fade a bar by its answer about range, so healers out of range stay bright."
-- The opacity of the bar of a healer out of range, and how long the window fades in as it shows and out as it hides.
local FAR = 0.45
local FADE_IN, FADE_OUT = 0.15, 0.35
local HELP = { "/flatui healers - sample bars of the healer mana list for a few seconds" }
-- The bars of /flatui healers: a name, a class, the share of mana, whether the member drinks and whether he is out of range.
local SAMPLE = { { "Priest", "PRIEST", 82 }, { "Druid", "DRUID", 47, true }, { "Shaman", "SHAMAN", 15, false, true } }

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

-- True while a unit has the buff of drinking, from a plain answer only.
local function Drinking(unit)
	local name = DrinkName()
	local auras = C_UnitAuras
	if not name or type(auras) ~= "table" or IsSecret(auras) then
		return false
	end
	local aura = Ask(auras.GetAuraDataBySpellName, unit, name, "HELPFUL")
	return type(aura) == "table"
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

-- True for a healer: the role says so, or the member has no role and is of a class that heals, and then the second answer is true. A withheld
-- role counts as none.
function H.Healer(unit)
	local role = Ask(UnitGroupRolesAssigned, unit)
	if role == "HEALER" then
		return true, false
	elseif role == "TANK" or role == "DAMAGER" then
		return false, false
	end
	local class = Ask(UnitClassBase, unit)
	return type(class) == "string" and HEALERS[class] == true, true
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

-- Shows the window, fading in when it was hidden and stopping a fade out at once, or fades it out; at once with now or with no fades.
function H.Showing(on, now)
	local frame, fadeIn, fadeOut = H.frame, H.fadeIn, H.fadeOut
	if not frame then
		return
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
	return frame
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
		row.low:SetAlpha(sample[3] < at and 1 or 0)
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
		bar:SetAlpha(sample[5] == true and FAR or 1)
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

-- Bar texture, and the height of the text and of the cup, on one bar. A texture the game refuses leaves a flat fill.
local function Paint(row, file, text)
	if row.file ~= file then
		local ok, done = pcall(row.bar.SetStatusBarTexture, row.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(row.bar.SetStatusBarTexture, row.bar, WHITE)
		end
		row.file = file
	end
	if row.text ~= text then
		row.name:SetTextHeight(text)
		row.share:SetTextHeight(text)
		row.drink:SetSize(text, text)
		row.text = text
	end
end

-- Lays out the title and n bars, and sizes the window to them. A layout that is already in place is left as it is. The text is as high as the bar
-- allows, as on the Threat list.
function H.Layout(n)
	local width, height = Number("barWidth", 150), Number("barHeight", 16)
	local text = math.max(7, math.min(14, height - 4))
	local file = ns.BarTexture(Opt("barTexture")) or WHITE
	for index = 1, n do
		Paint(H.Row(index), file, text)
	end
	local key = ("%s:%s:%s"):format(n, width, height)
	if H.laid == key then
		return
	end
	H.laid = key
	local top = PAD + text + 2 + GAP
	H.title:SetTextHeight(text)
	for index = 1, n do
		local bar = H.rows[index].bar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", H.frame, "TOPLEFT", PAD, -(top + (index - 1) * (height + GAP)))
		bar:SetSize(width, height)
	end
	H.frame:SetSize(width + 2 * PAD, top + n * height + (n - 1) * GAP + PAD)
end

-- Writes one bar: the class colour, the name and the share of mana, the red wash below Low mana at, the cup while the member drinks and its
-- fade out of range; the share goes to the bar, its text and the wash untouched. A sample is a table of SAMPLE.
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
		local cup = drinks and sample[4] == true
		row.name:SetText(sample[1])
		row.bar:SetValue(sample[3])
		row.share:SetText((cup and "Drinking %d%%" or "%d%%"):format(sample[3]))
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
		row.share:SetText(word)
		H.Cup(row, false)
		return
	end
	local cup = drinks and AurasOpen() and Drinking(unit)
	H.Cup(row, cup)
	local ok, share = pcall(UnitPowerPercent, unit, MANA, false, Hundred())
	if not ok or not pcall(row.bar.SetValue, row.bar, share) then
		row.bar:SetValue(0)
	end
	if not ok or not pcall(row.share.SetFormattedText, row.share, cup and "Drinking %.0f%%" or "%.0f%%", share) then
		row.share:SetText(cup and "Drinking" or "")
	end
end

-- True while the sample bars show: /flatui healers holds them for a few seconds (H.sample), and test mode (TestMode.lua) while it is on.
function H.Sampling()
	local mode = ns.TestMode
	return H.sample ~= nil or (mode ~= nil and mode.IsOn() == true)
end

-- Puts the window at the spot of its handle: its top left corner at the top left corner of the box.
function H.Place()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "TOPLEFT")
	end
	local key = x and ("%.2f:%.2f"):format(x, y) or "start"
	if H.placed == key then
		return
	end
	H.placed = key
	local frame = H.frame
	frame:ClearAllPoints()
	if x then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	else
		frame:SetPoint("TOPLEFT", UIParent, "CENTER", BOX_X - BOX_W / 2, BOX_Y + BOX_H / 2)
	end
end

-- Shows a bar for each healer, as many as Number of bars allows (the samples for /flatui healers), or hides the window when there are none.
function H.Draw()
	local samples = H.Sampling() and SAMPLE or nil
	local list = samples or H.healers
	local n = math.min(#list, Number("rows", 5), MOST_ROWS)
	if n < 1 then
		H.Showing(false)
		H.Tick(false)
		return
	end
	H.Frame()
	H.Layout(n)
	for index = 1, n do
		if samples then
			H.Fill(H.rows[index], nil, samples[index])
		else
			H.Fill(H.rows[index], list[index])
		end
	end
	for index = n + 1, #H.rows do
		H.rows[index].bar:Hide()
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
		for index = 1, math.min(n, #H.rows) do
			H.Fill(H.rows[index], H.healers[index])
		end
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
	H.pending, H.placed, H.laid = nil, nil, nil
	if not ns.Enabled(KEY) then
		H.sample, H.healers = nil, {}
		H.Tick(false)
		H.Showing(false, true)
		return
	end
	H.Update()
end

-- /flatui healers: the sample bars for a few seconds.
function H.Slash()
	if not ns.Enabled(KEY) then
		print("Healer mana: turn on Show healer mana first.")
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
	events = { GROUP_ROSTER_UPDATE = Soon, PLAYER_ROLES_ASSIGNED = Soon, PLAYER_ENTERING_WORLD = Soon, ZONE_CHANGED_NEW_AREA = Soon },
	slash = { healers = H.Slash },
	help = HELP,
})

-- Test mode: the sample bars while it is on (H.Sampling), drawn with the rows at each refresh of the page; Off refreshes the page, which draws the
-- healers of the group again or hides the window.
if ns.TestMode then
	ns.TestMode.Register("healermana", { module = KEY, label = "Healer mana", refresh = true })
end
