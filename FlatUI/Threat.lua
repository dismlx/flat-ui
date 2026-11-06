local _, ns = ...

-- Threat list: a small window of Flat UI's own with the members of the group by their threat on the enemy the player fights, highest first:
-- one bar each, in the class colour of the member (a pet in its owner's colour, a shade darker), with the share of what pulls aggro. The game
-- gives that share as scaledPercentage of UnitDetailedThreatSituation (UnitDocumentation.lua:1086-1106), beside rawPercentage, the share of the
-- tank's threat that the game's own threat number on the target frame shows (Mainline/UnitFrame.lua:1030-1031). At 100% the enemy turns to that
-- member, wherever the member stands, so a full bar is aggro. The enemy is the player's target, else the target of the target (a healer who
-- targets the tank), never a player and never a dead one. The list shows only in a fight (PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED,
-- UnitDocumentation.lua:3887, 3893), in a group, in a dungeon or raid, or also alone as Show says, and it is hidden while no member is on the
-- threat table of the enemy. Out of a fight the module
-- hears only the start of one: a frame of the addon's own hears the target (PLAYER_TARGET_CHANGED, UNIT_TARGET for the target:
-- UnitDocumentation.lua:3976, 4871) only in a fight Show allows, the threat events and the pets (UNIT_THREAT_LIST_UPDATE,
-- UNIT_THREAT_SITUATION_UPDATE, UNIT_PET: UnitDocumentation.lua:4891-4910, 4451) only while there is an enemy, and a step of one second runs
-- only while the list shows, or while the target of the target is an enemy nobody is on yet, as no event says when that one is pulled (T.Draw).
-- A burst of events is drawn once, a moment after the first. The window and its bars are made the first time they show.
-- The game withholds the threat of a member on some enemies: a query of the player, the pet or an ally against a target that is no boss is
-- generally not secret (SecretPredicatesDocumentation.lua:165-168, ShouldUnitThreatValuesBeSecret in SecretPredicateAPIDocumentation.lua:415-430),
-- so a boss is where it is. A withheld value is never read, compared or added: it goes as it is to SetValue of the bar and to SetFormattedText
-- of its text, which take it (SimpleStatusBarAPIDocumentation.lua:355-365, SimpleFontStringAPIDocumentation.lua:539-548). Nothing can be sorted
-- on it, so then the members keep the order of the group, the player first in a party, and the pets come after all of them: Number of bars
-- leaves out a pet before a member, so the five bars of the default show every member of a party. /flatui status says so. A member's name and
-- the enemy's go to SetText the same way when the game withholds them (SimpleFontStringAPIDocumentation.lua:664-673).
-- The window is a child of UIParent in the LOW strata with a flat background and a thin border in the colours of the Flat UI page, as the data
-- panels have, its bars in the bar texture of that page; it takes no mouse and hides with the interface. /flatui move places it (FlatUIThreat in
-- Movers.lua: the window's top left corner is the top left corner of the box). /flatui threat shows sample bars for a few seconds, out of
-- combat. Nothing of the game is changed.
-- Built on the threat meter of EnhanceQoL's damage meter by Philipp Barth (R41Z0R), adapted with his permission
-- (EnhanceQoLDamageMeter/DamageMeter.lua:2841-2936, 7345-7368, 7450-7468): the enemy it reads, the units of the group with their pets, the
-- events that draw it again and the wait that draws a burst once. Its meter windows, its focus and focus target, and its share of the tank's
-- threat sorted on raw threat are left out: that share is worked out from the raw threat, which a withheld value does not allow, while the
-- game's scaled percentage needs no sum and says when aggro changes hands.

local KEY = "threat"
local MOVER = "FlatUIThreat"
-- The box of the handle in Movers.lua: the room of five bars at the default size, and where it is with no spot saved, right of the middle.
local BOX_W, BOX_H, BOX_X, BOX_Y = 188, 112, 420, 0
-- Units inside the edge of the window, between two bars, and between the end of a bar and its text.
local PAD, GAP, INSET = 4, 2, 4
-- A burst of events is drawn once, this long after the first. The step while the list shows. How long /flatui threat shows.
local STEP, TICK, TEST_TIME = 0.2, 1, 8
local MOST_ROWS = 10
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- The text-dim of the windows (PanelLook.lua) for the enemy's name, the track behind a fill, the colour of a member whose class the game
-- withholds, and how much darker a pet's bar is than its owner's.
local DIM = { 0.66, 0.68, 0.62 }
local TRACK = { 0.2, 0.2, 0.2, 0.5 }
local GREY = { 0.6, 0.6, 0.6 }
local PET = 0.7
-- What the frame of the addon's own hears in a fight Show allows, and while there is an enemy.
local FIGHT_EVENTS = { "PLAYER_TARGET_CHANGED" }
local ENEMY_EVENTS = { "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_PET" }
local LINE_WITHHELD = "Threat list: the game withheld the threat on the last enemy, so its bars kept the order of the group, the pets after the members."
local LINE_MISSING = "Threat list: this client has no UnitDetailedThreatSituation, so the list stays hidden."
local HELP = { "/flatui threat - sample bars of the threat list for a few seconds, out of combat" }
-- The bars of /flatui threat: a name, a class, the share, and true for a pet. false is the player, by name and class.
local SAMPLE = {
	{ "Tank", "WARRIOR", 100 }, { false, nil, 86 }, { "Mage", "MAGE", 71 }, { "Rogue", "ROGUE", 63 }, { "Hunter", "HUNTER", 52 },
	{ "Wolf", "HUNTER", 40, true }, { "Warlock", "WARLOCK", 33 }, { "Voidwalker", "WARLOCK", 24, true }, { "Priest", "PRIEST", 12 }, { "Druid", "DRUID", 6 },
}

local IsSecret = ns.IsSecret
-- frame: the window, outline its background and border, title the enemy's name. rows: the bars. listener: the frame that hears the events, and
-- heard: what it hears. fighting: true between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED. pending: a draw waits. ticker: the token of the
-- step. sample: the token of /flatui threat while it shows. placed: the spot the window was put at, laid: the layout of its bars. withheld: the
-- game withheld the threat on the last enemy read.
local T = { rows = {}, heard = {}, fighting = false, withheld = false }
ns.ThreatList = T

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

-- The text is as high as the bar allows, as on the bars of the trackers (TrackerShapes.lua).
local function TextHeight(height)
	return math.max(7, math.min(14, height - 4))
end

-- Whether the player is in a fight now, for a first look; a withheld answer counts as out of combat, as for the cursor ring (CursorRing.lua).
local function InFight()
	local value = Ask(UnitAffectingCombat, "player")
	if type(value) == "boolean" then
		return value
	end
	return Ask(InCombatLockdown) == true
end

-- A timer of the client, false when there is none or it raises.
local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

-- Where and on what --------------------------------------------------------------------------------------------------------------------------

-- True when Show lets the list show now: in a group, in a dungeon or raid, or anywhere.
function T.Allowed()
	local show = Opt("show")
	if show == "always" then
		return true
	elseif show == "instance" then
		local ok, inside, kind = pcall(IsInInstance)
		return ok and not IsSecret(inside) and inside == true and not IsSecret(kind) and (kind == "party" or kind == "raid")
	end
	return Ask(IsInGroup) == true
end

-- True for a unit with a threat table the group can be on: it exists, can be attacked, is no player and is not dead.
function T.Enemy(unit)
	return Ask(UnitExists, unit) == true and Ask(UnitCanAttack, "player", unit) == true and Ask(UnitIsPlayer, unit) ~= true
		and Ask(UnitIsDeadOrGhost, unit) ~= true
end

-- The enemy whose threat the list shows: the target, else the target of the target.
function T.Mob()
	if T.Enemy("target") then
		return "target"
	elseif T.Enemy("targettarget") then
		return "targettarget"
	end
	return nil
end

-- The members of the group in its order, each { unit, owner, pet }: in a raid raid1 to raid40, the player among them; else the player, then
-- party1 to party4. With Pets on, each pet comes after its owner.
function T.Members()
	local list, pets = {}, Opt("pets") == true
	local function Member(unit, pet)
		list[#list + 1] = { unit = unit, owner = unit }
		if pets then
			list[#list + 1] = { unit = pet, owner = unit, pet = true }
		end
	end
	if Ask(IsInRaid) == true then
		for index = 1, Count(GetNumGroupMembers, 40) do
			Member("raid" .. index, "raidpet" .. index)
		end
	else
		Member("player", "pet")
		if Ask(IsInGroup) == true then
			for index = 1, Count(GetNumSubgroupMembers, 4) do
				Member("party" .. index, "partypet" .. index)
			end
		end
	end
	return list
end

-- The members on the threat table of the enemy, each { member, order, scaled, value, withheld }, and true when the game withheld a value. The
-- game answers nothing for a member who is not on the table (MayReturnNothing; isTanking, status, scaledPercentage, rawPercentage, rawThreat).
-- Plain shares are sorted, highest first, the raw threat and then the order of the group deciding a tie. A withheld share is kept as it is for
-- the bar and its text, and then the entries are sorted on what Flat UI knows of them alone: the members first, then the pets, each in the order
-- of the group. T.Members puts each pet right after its owner, and in that order a pet would take the bar of the last member of a party.
function T.Scan(mob)
	local entries, withheld = {}, false
	for order, member in ipairs(T.Members()) do
		if Ask(UnitExists, member.unit) == true then
			local ok, _, _, scaled, _, value = pcall(UnitDetailedThreatSituation, member.unit, mob)
			if ok then
				if IsSecret(scaled) or IsSecret(value) then
					withheld = true
					entries[#entries + 1] = { member = member, order = order, scaled = scaled, withheld = true }
				elseif ns.Finite(scaled) then
					entries[#entries + 1] = { member = member, order = order, scaled = math.max(0, math.min(100, scaled)), value = ns.Finite(value) and value or 0 }
				end
			end
		end
	end
	if not withheld then
		table.sort(entries, function(a, b)
			if a.scaled ~= b.scaled then
				return a.scaled > b.scaled
			elseif a.value ~= b.value then
				return a.value > b.value
			end
			return a.order < b.order
		end)
	else
		table.sort(entries, function(a, b)
			local petA, petB = a.member.pet == true, b.member.pet == true
			if petA ~= petB then
				return petB
			end
			return a.order < b.order
		end)
	end
	return entries, withheld
end

-- The bars of /flatui threat.
function T.Sample()
	local entries = {}
	for order, spec in ipairs(SAMPLE) do
		entries[order] = { sample = spec, order = order, scaled = spec[3] }
	end
	return entries
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

-- The colour of a bar: the class colour of the member, a pet's owner's a shade darker, grey where the game withholds the class.
function T.Colour(entry)
	local r, g, b, pet
	local spec = entry.sample
	if spec then
		if spec[1] == false then
			r, g, b = ns.ClassColour()
		else
			r, g, b = ClassRGB(spec[2])
		end
		pet = spec[4] == true
	else
		r, g, b = ns.ClassColourOf(entry.member.owner)
		pet = entry.member.pet == true
	end
	if not r then
		r, g, b = GREY[1], GREY[2], GREY[3]
	end
	if pet then
		return r * PET, g * PET, b * PET
	end
	return r, g, b
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

-- The window, made the first time it shows: a frame of the addon's own on UIParent with a flat background and a thin border, and the line for
-- the enemy's name.
function T.Frame()
	if T.frame then
		return T.frame
	end
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	frame:SetFrameStrata("LOW")
	frame:SetSize(BOX_W, BOX_H)
	frame:Hide()
	T.frame = frame
	T.outline = ns.Outline(frame, frame, true)
	local title = ns.OwnText(frame, "OVERLAY", FONT)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + INSET, -PAD)
	title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + INSET), -PAD)
	T.title = title
	return frame
end

-- Bar number index, made the first time the list needs it: a track, the fill, the name on the left and the share on the right.
function T.Row(index)
	local row = T.rows[index]
	if row then
		return row
	end
	local bar = Own(CreateFrame("StatusBar", nil, T.frame))
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
	row = { bar = bar, track = track, name = name, share = share }
	T.rows[index] = row
	return row
end

-- The bar texture of the Flat UI page, and the height of the text, on one bar. A texture the game refuses leaves a flat fill.
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
		row.text = text
	end
end

-- Lays out the enemy's name and n bars, and sizes the window to them. A layout that is already in place is left as it is.
function T.Layout(n)
	local width, height = Number("barWidth", 180), Number("barHeight", 16)
	local text = TextHeight(height)
	local file = ns.BarTexture() or WHITE
	for index = 1, n do
		Paint(T.Row(index), file, text)
	end
	local key = ("%s:%s:%s"):format(n, width, height)
	if T.laid == key then
		return
	end
	T.laid = key
	local top = PAD + text + 2 + GAP
	T.title:SetTextHeight(text)
	for index = 1, n do
		local bar = T.rows[index].bar
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", T.frame, "TOPLEFT", PAD, -(top + (index - 1) * (height + GAP)))
		bar:SetSize(width, height)
	end
	T.frame:SetSize(width + 2 * PAD, top + n * height + (n - 1) * GAP + PAD)
end

-- Writes one bar: its colour, its name and its share. A withheld share goes to the bar and to its text untouched.
function T.Fill(row, entry)
	local r, g, b = T.Colour(entry)
	row.bar:SetStatusBarColor(r, g, b, 1)
	local spec = entry.sample
	if spec and spec[1] ~= false then
		row.name:SetText(spec[1])
	else
		SetName(row.name, spec and "player" or entry.member.unit)
	end
	if entry.withheld then
		if not pcall(row.bar.SetValue, row.bar, entry.scaled) then
			row.bar:SetValue(0)
		end
		if not pcall(row.share.SetFormattedText, row.share, "%.0f%%", entry.scaled) then
			row.share:SetText("")
		end
	else
		row.bar:SetValue(entry.scaled)
		row.share:SetText(("%d%%"):format(math.floor(entry.scaled + 0.5)))
	end
	row.bar:Show()
end

-- Puts the window at the spot of its handle: its top left corner at the top left corner of the box.
function T.Place()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "TOPLEFT")
	end
	local key = x and ("%.2f:%.2f"):format(x, y) or "start"
	if T.placed == key then
		return
	end
	T.placed = key
	local frame = T.frame
	frame:ClearAllPoints()
	if x then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	else
		frame:SetPoint("TOPLEFT", UIParent, "CENTER", BOX_X - BOX_W / 2, BOX_Y + BOX_H / 2)
	end
end

-- Shows the bars of the entries, as many as Number of bars allows, with the name of the enemy (Sample for /flatui threat), or hides the window
-- when there are none. The step runs while the list of an enemy shows, and also while the target of the target is an enemy nobody is on yet:
-- the game names the enemy whose threat list changed by a token of its own (UNIT_THREAT_LIST_UPDATE, UnitDocumentation.lua:4889-4898; Blizzard
-- hears it for a frame's own unit, CompactUnitFrame.lua:349-350, and draws its target of target in an OnUpdate, Mainline/TargetFrame.lua:893-899),
-- never as the target of the target, and a member who fights another enemy keeps its threat situation, the highest on any enemy
-- (CompactUnitFrame.lua:624-626). So when a healer's tank pulls the next enemy in a fight, with no nameplate on it, no event says so. The
-- player's own target is named in that event, so for it the list waits for the event.
function T.Draw(mob, entries)
	local n = math.min(entries and #entries or 0, Number("rows", 5), MOST_ROWS)
	if n < 1 then
		if T.frame then
			T.frame:Hide()
		end
		T.Tick(mob == "targettarget")
		return
	end
	T.Frame()
	T.Layout(n)
	for index = 1, n do
		T.Fill(T.rows[index], entries[index])
	end
	for index = n + 1, #T.rows do
		T.rows[index].bar:Hide()
	end
	if mob then
		SetName(T.title, mob)
	else
		T.title:SetText("Sample")
	end
	T.Place()
	T.frame:Show()
	T.Tick(mob ~= nil)
end

-- Listening ---------------------------------------------------------------------------------------------------------------------------------

function T.OnEvent(event, unit)
	-- Heard for every unit where the client cannot hear one: only the player's target counts.
	if event == "UNIT_TARGET" and (IsSecret(unit) or unit ~= "target") then
		return
	end
	T.Soon()
end

function T.Listener()
	if not T.listener then
		local frame = Own(CreateFrame("Frame"))
		frame:SetScript("OnEvent", function(_, event, unit)
			ns.Try(KEY, T.OnEvent, event, unit)
		end)
		T.listener = frame
	end
	return T.listener
end

-- Starts or stops hearing an event, for one unit alone where the client can.
local function Hear(event, on, unit)
	on = on == true
	if on == (T.heard[event] ~= nil) or (not on and not T.listener) then
		return
	end
	local frame = T.Listener()
	if not on then
		pcall(frame.UnregisterEvent, frame, event)
		T.heard[event] = nil
		return
	end
	if unit and type(frame.RegisterUnitEvent) == "function" then
		local ok, done = pcall(frame.RegisterUnitEvent, frame, event, unit)
		if ok and (IsSecret(done) or done ~= false) then
			T.heard[event] = unit
			return
		end
	end
	if pcall(frame.RegisterEvent, frame, event) then
		T.heard[event] = true
	end
end

local function HearAll(events, on)
	for _, event in ipairs(events) do
		Hear(event, on)
	end
end

-- Draws again a moment later, once for a burst of events.
function T.Soon()
	if T.pending then
		return
	end
	T.pending = true
	if not After(STEP, function()
		ns.Try(KEY, T.Update)
	end) then
		T.Update()
	end
end

-- A step of one second while the list of an enemy shows, or while the target of the target has nobody on its list yet (T.Draw), for what no event
-- announces. A client without NewTicker gets a timer that sets the next one while the token is the step's, as the data panels have it
-- (DataPanels.lua).
function T.Tick(on)
	if on and not T.ticker then
		local token = {}
		T.ticker = token
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, TICK, function()
				ns.Try(KEY, T.Update)
			end)
			token.handle = ok and ticker or nil
		end
		if not token.handle then
			local function Again()
				if T.ticker == token then
					ns.Try(KEY, T.Update)
					if T.ticker == token and not After(TICK, Again) then
						T.ticker = nil
					end
				end
			end
			if not After(TICK, Again) then
				T.ticker = nil
			end
		end
	elseif not on and T.ticker then
		local handle = T.ticker.handle
		T.ticker = nil
		if handle and type(handle.Cancel) == "function" then
			pcall(handle.Cancel, handle)
		end
	end
end

-- What the list shows now, drawn: the target is heard only in a fight Show allows, the threat events only while there is an enemy.
function T.Update()
	T.pending = nil
	local on = ns.Enabled(KEY)
	local fighting = on and T.fighting and type(UnitDetailedThreatSituation) == "function" and T.Allowed()
	HearAll(FIGHT_EVENTS, fighting)
	Hear("UNIT_TARGET", fighting, "target")
	local mob = fighting and T.Mob() or nil
	HearAll(ENEMY_EVENTS, mob ~= nil)
	if mob then
		local entries, withheld = T.Scan(mob)
		T.withheld = withheld
		T.Draw(mob, entries)
	elseif on and T.sample and not T.fighting then
		T.Draw(nil, T.Sample())
	else
		T.Draw(nil, nil)
	end
end

function T.Fight(on)
	T.fighting = on
	if on then
		T.sample = nil
	end
	T.Update()
end

-- Off, or stopped: the window hides, the frame hears nothing and the step ends.
function T.Off()
	T.sample, T.fighting, T.pending, T.withheld = nil, false, nil, false
	HearAll(FIGHT_EVENTS, false)
	HearAll(ENEMY_EVENTS, false)
	Hear("UNIT_TARGET", false)
	T.Tick(false)
	if T.frame then
		T.frame:Hide()
	end
end

function T.Refresh()
	T.pending, T.placed, T.laid = nil, nil, nil
	if not ns.Enabled(KEY) then
		T.Off()
		return
	end
	T.fighting = InFight()
	T.Update()
end

-- /flatui threat: the sample bars for a few seconds, out of combat.
function T.Slash()
	if not ns.Enabled(KEY) then
		print("Threat list: turn on Show the threat list first.")
		return
	end
	if T.fighting or InFight() then
		print("Threat list: the sample shows out of combat.")
		return
	end
	local token = {}
	T.sample = token
	ns.Try(KEY, T.Update)
	local function Done()
		if T.sample == token then
			T.sample = nil
			ns.Try(KEY, T.Update)
		end
	end
	if not After(TEST_TIME, Done) then
		Done()
	end
end

function T.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if type(UnitDetailedThreatSituation) ~= "function" then
		lines[#lines + 1] = LINE_MISSING
	end
	if T.withheld then
		lines[#lines + 1] = LINE_WITHHELD
	end
	return lines
end

-- The movers ----------------------------------------------------------------------------------------------------------------------------------

-- True while the list has a handle in the movers: while the module is on, in a fight or not.
function ns.ThreatListShown()
	return ns.Enabled(KEY)
end

-- The movers set or put back the spot.
function ns.ThreatListMoved()
	T.placed = nil
	if T.frame and ns.Enabled(KEY) then
		ns.Try(KEY, T.Place)
	end
end

ns.Register(KEY, {
	label = "Threat list",
	counted = false,
	Start = T.Refresh,
	Refresh = T.Refresh,
	Resized = T.Refresh,
	Status = T.Status,
	events = {
		PLAYER_REGEN_DISABLED = function()
			T.Fight(true)
		end,
		PLAYER_REGEN_ENABLED = function()
			T.Fight(false)
		end,
		-- Out of a fight there is nothing to show; the start of one reads the group.
		GROUP_ROSTER_UPDATE = function()
			if T.fighting then
				T.Soon()
			end
		end,
		PLAYER_ENTERING_WORLD = function()
			T.fighting = InFight()
			T.Update()
		end,
	},
	slash = { threat = T.Slash },
	help = HELP,
})
