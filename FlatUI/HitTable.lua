local ADDON_NAME, ns = ...

-- Hit table (hud.hitTable, on the Hit table page of Minimap and HUD): a small table of Flat UI's own under the player frame with the player's
-- chances against the target, worked out again as stats, gear, weapon skill, buffs, form and the target change; HitTableCalc.lua has the numbers and
-- their sources. Its row is For tanks and damage dealers by default, which shows the table while the player's role (ns.PlayerRole, Core.lua, the role
-- Flat UI setup suggests from) is tank or damage and hides it for a healer; Always and Off hold whatever the role. The row was a tick in 0.5.18:
-- Core.lua moves a saved one to Always or Off once (ns.MigrateText), and one that slips past reads the same here. Part "hit table" of the hud
-- module, which stops alone after a few faults: Hud.lua calls ns.HitTableRefresh in every refresh of the page, and everything else here runs inside
-- ns.EachPart.
--
-- The table: a title with the enemy as counted and where the player stands, the weapon skill at its right, a heading, and a line for each attack
-- (Swing, or Main and Off while dual wielding; Special; Ranged; Spell) with a column for each part of the roll that applies to a line shown: Miss,
-- Dodge, Parry, Glance, Block, Crit, Hit, and Cap, the crit cap of a swing; then Resist, the Spell line's alone, no part of the roll: the share of a
-- spell's damage resisted on average, below 0 the damage a creature takes more from the player's Spell Piercing (HitTableCalc.lua, Resist), with the
-- piercing of every school the game gives (GetSpellPenetration), the piercing of one school (Fire Piercing...) only in the gear comparison and a
-- spell tooltip's Expected line. A crit above the cap turns the crit and the cap yellow; a miss, dodge or parry down to its floor, and a resist below
-- 0, turn green. A part that does not apply is -, one the game withheld or refused is ?, and /flatui status says which, and what Resist counts.
--
-- The frame is a frame of its own on UIParent, in the LOW strata of the player frame (Mainline/PlayerFrame.xml:13), with no mouse and no name, in a
-- flat background with a thin border of the hud page's look (ns.Outline, made inside ns.EachPart). With no spot saved in the movers it hangs from a
-- rail, a second frame of its own with two points: its top left corner on the left edge Flat UI draws for the player frame (the body of One frame,
-- else Flat UI's picture while it draws one, else the game's portrait, PlayerFrame.xml:23-30, else the health bar, else the player frame) and its
-- bottom right corner on the frame the game hangs the pet frame and the totems in, PlayerBottomManagedFrameContainer (PlayerFrame.xml:477-484,
-- Shared/PlayerFrameTemplates.xml:4-31), or on the player's cast bar while Edit Mode locks it to the player frame (Shared/PlayerFrame.lua:18-48), else
-- on the player frame. The table's top left corner is the rail's bottom left one, a gap lower. So its left edge is the portrait's in either Frame
-- style, and the game lowers it as a pet frame, totems or the locked cast bar come, in a fight too, with no call from Flat UI. The gap also clears,
-- while the container is at its smallest so it holds with a pet or without one, the lowest line Flat UI draws on the player frame (the borders of its
-- power bar, health bar and picture, the body of One frame, the druid's mana bar of UnitDruidMana.lua) and the icons of a Cooldown icons row hung
-- under the player frame (Cooldowns.lua); and the auras a pet frame hangs under the container, and the spell name Flat UI's cast bar size hangs under
-- the locked bar. While the target frame or the focus frame stands beside the player frame, as Edit Mode's Classic layout puts the target frame 14
-- units right of it (Blizzard_EditMode/Mainline/EditModePresetLayouts.lua:1049-1075), the table ends before it, its text made smaller: their auras
-- and cast bar hang under them and are drawn over the table (frameLevel 500, Mainline/TargetFrame.xml:52; Mainline/TargetFrame.lua:534-558, 830-851).
-- It ends before the edge of the screen the same way. Points are set out of combat only, as Flat UI hangs every frame of its own from the player frame
-- (Core.lua); a change asked for in a fight waits once for its end (ns.OutOfCombat). /flatui move places it (FlatUIHitTable in Movers.lua, with the
-- table as its box), and a spot saved there wins; Jon Default gives every new profile one (SetupProfiles.lua). At that spot or on the rail, the
-- table steps down where it would run into the pet frame while it shows, or into test mode's sample of it (TestUnits.lua, the stand-in "pet"), and
-- the auras under them: its top a GAP under their lowest, its own spot kept for when the pet goes. On the rail the game already lowers it under a
-- pet frame in the container, so there it steps only for the sample, or for a pet frame Edit Mode or the movers put under it. /flatui status says
-- when it stepped.
--
-- Its text size is Text size (hud.hitTableSize: 70 to 200%, its ids the percent in text; a number saved while it was a slider, until 0.5.26, reads
-- as the nearest, Core.lua, Renamed), set in the options window or Flat UI setup; the table takes no mouse, so clicks and drags on it reach the
-- world under it.
--
-- What it hears: a frame of its own registers the events that change the numbers only while the table is wanted, the unit events for the player
-- and the target alone (RegisterUnitEvent), as the character sheet registers its own (Camelot/PaperDollFrame.lua:314-351). An event only marks the
-- table, and one OnUpdate on the next frame works it out once for a burst, as the sheet batches its events (Camelot/PaperDollFrame.lua:392-395). The
-- threat events and the target's own target count only when the facing they decide changes, as they come many times a second in a fight. The
-- cast bar's lock is followed with hooksecurefunc (ns.FollowGlobal, as CastBarSize.lua follows it), and a refresh of the unit frames, a layout of the
-- Cooldown icons rows (Cooldowns.lua) and a change of the cast bars' sizes (CastBarSize.lua) place the table again (ns.UnitFrameExtra.after.refresh,
-- ns.HitTableMoved). The player's UNIT_PET places it again a moment later (PET_WAIT), once the game has shown or hidden the pet frame, as do test
-- mode's On and Off (TM.Watch) and a new size of the table while a pet frame shows. At For tanks and damage dealers the role is worked out in every
-- refresh and again after an event that can change it (ROLE_EVENTS: a role the group gives, talents spent, reset or switched to the other set of dual
-- spec, a new list of the sets of talents, a level, a form, a new world, the player's auras), which the hud module hears for it (ns.AddEvent) also
-- while the table is hidden for a healer; such an event too only marks the table, and the next frame works the role out before the numbers, showing
-- or hiding the table when its answer changed.
-- While test mode is on (TestMode.lua), Show lets the table show whatever it says, and Against the target with no enemy targeted counts a boss,
-- three levels above the player.
-- As Show lets it show or hides it (an enemy targeted, lost or killed, a fight begun or over) the table fades in over 0.15 s and out over 0.35 s
-- (Visible, 0.5.36, two Alpha animations of its own frame); a refresh, test mode's On and Off and the row going off set it at once.
-- Nothing of the game's is written: its frames are read and anchored to, never changed.

local KEY, PART = "hud", "hit table"
local MOVER = "FlatUIHitTable"
local SANS = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Fonts\\IBMPlexSans-Regular.ttf"
local GAME_FONT = "Fonts\\FRIZQT__.TTF"
local FONT = "GameFontHighlightSmall"
-- The text is 11 px at 100%. Units inside the edge across and down, between two columns, after the names of the lines, and between the title and the
-- weapon skill.
local BASE, PAD_X, PAD_Y, COLUMN_GAP, NAME_GAP, TITLE_GAP = 11, 6, 4, 6, 8, 12
-- Units between what hangs under the player frame and the table's border, as Cooldown icons keeps under the frame it hangs from (Cooldowns.lua:41).
local GAP = 4
-- The height of the container the game hangs the pet frame in while it holds nothing (minimumHeight, Shared/PlayerFrameTemplates.xml:16).
local SMALLEST = 1
-- How far a pet's buffs and debuffs reach under the container while the pet frame is the last frame in it, in the pet frame's units: the row starts
-- 42 under the top of a pet frame 49 tall (Mainline/PetFrame.xml:12, 170-176), its icons 15 tall (PartyAuraFrameTemplate,
-- Shared/PartyFrameTemplates.xml:5-6), so 8 under its bottom (PET_BELOW); and the container ends 1 above that bottom, from the pet frame's
-- bottomPadding of -3 (PetFrame.xml:16) and the spacing of 2 before the container's empty last row (Shared/PlayerFrameTemplates.xml:14, 19-26;
-- Blizzard_SharedXML/LayoutFrame.lua:277-300).
local PET_BELOW = 42 + 15 - 49
local PET_AURAS = PET_BELOW + 1
-- Seconds after the player's UNIT_PET before the table looks at the pet frame again: the game shows or hides the pet frame on the next frame, as
-- UNIT_PET sets the secure state driver's timer to 0 (Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua:119-140, 142-144, 195), and test
-- mode looks at its samples every quarter second (TestMode.lua, POLL).
local PET_WAIT = 0.3
-- Where a point is on a frame, as shares of its width and height from its bottom left corner, for the table's box at a spot of the movers.
local SHARE = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }
-- The classes whose own pet the pet frame shows; for another class the room is kept only while the pet frame shows (Mind Control).
local PET_CLASSES = { HUNTER = true, WARLOCK = true }
-- The Cooldown icons rows that can hang under the player frame (Cooldowns.lua): the movers' function that gives a row's icons, its Position row, and
-- its name among the spots of the movers (CD.MOVERS, R.Opt).
local COOLDOWN_ROWS = { { "CooldownRow", "cooldowns.place", "FlatUICooldowns" }, { "CooldownRow2", "cooldowns.row2Place", "FlatUICooldowns2" },
	{ "CooldownRow3", "cooldowns.row3Place", "FlatUICooldowns3" }, { "CooldownRow4", "cooldowns.row4Place", "FlatUICooldowns4" } }
-- The game's frames the table ends before while one stands beside the player frame, and their names for /flatui status (Mainline/TargetFrame.xml:549,
-- 572).
local BESIDE = { { "TargetFrame", "target frame" }, { "FocusFrame", "focus frame" } }
-- The share of the text at 100% under which a table made to fit gets no smaller (half, the smallest Text size of the slider it was until 0.5.26),
-- and the steps of the share of Text size it is made, so the sizes it measures at stay few. Widths are kept for this many sizes at most.
local SMALLEST_TEXT, FIT_STEP, MEASURED = 0.5, 0.05, 8
-- Points of weapon skill a level, for the status line of a skill the game did not give (HitTableCalc.lua counts the same).
local PER_LEVEL = 5
-- The colours of the windows' text and states (PanelLook.lua:27-31), as Threat list and Data panels have them.
local DIM, FAINT, PLAIN = { 0.66, 0.68, 0.62 }, { 0.48, 0.50, 0.45 }, { 1, 1, 1 }
local OK, WARN = { 0.49, 0.80, 0.56 }, { 0.90, 0.72, 0.36 }
-- The columns, in the order of the roll, and Resist, a spell's damage resisted after it.
local COLUMNS = { { "miss", "Miss" }, { "dodge", "Dodge" }, { "parry", "Parry" }, { "glance", "Glance" }, { "block", "Block" }, { "crit", "Crit" },
	{ "hit", "Hit" }, { "cap", "Cap" }, { "resist", "Resist" } }
-- The widest number a cell shows, which sets the width of a column.
local WIDEST = "100.0"
-- The parts whose floor is good news: no miss (1 for spells under Classic rules), no dodge, no parry.
local FLOORED = { miss = true, dodge = true, parry = true }
-- The word of a kind of enemy in the title (ns.UnitKind).
local KIND_WORDS = { boss = "boss", elite = "elite", rare = "rare", rareelite = "rare elite" }
-- The events: the player's alone, the target's alone, and the others (UNIT_LEVEL is heard for both units). Each is in events.yaml of the client and
-- in the sheet's list or the target frame's, but the threat events, which the game's unit frames hear for their own unit (Mainline/UnitFrame.lua:1002,
-- Shared/CompactUnitFrame.lua:131-143): the player's threat situation and the target's threat list.
local PLAYER_EVENTS = { "UNIT_STATS", "UNIT_ATTACK", "UNIT_DAMAGE", "UNIT_ATTACK_SPEED", "UNIT_RANGEDDAMAGE", "UNIT_AURA", "UNIT_INVENTORY_CHANGED",
	"UNIT_DISPLAYPOWER", "UNIT_THREAT_SITUATION_UPDATE" }
local TARGET_EVENTS = { "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION", "UNIT_FLAGS", "UNIT_TARGET", "UNIT_HEALTH", "UNIT_THREAT_LIST_UPDATE" }
-- The events that change only whether the target attacks the player (HitTableCalc.lua, C.Front): they count only when the facing changes.
local FACING_EVENTS = { UNIT_THREAT_SITUATION_UPDATE = true, UNIT_THREAT_LIST_UPDATE = true, UNIT_TARGET = true }
local EVENTS = { "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "SPELL_POWER_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "WEAPON_ENCHANT_CHANGED",
	"SKILL_LINES_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "PLAYER_LEVEL_UP", "UPDATE_SHAPESHIFT_FORM",
	"PLAYER_TARGET_CHANGED", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
	"UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED" }
-- The events after which the table is placed again: a new world, the screen, the scale or Edit Mode's layout changed.
local PLACE_EVENTS = { PLAYER_ENTERING_WORLD = true, UI_SCALE_CHANGED = true, DISPLAY_SIZE_CHANGED = true, EDIT_MODE_LAYOUTS_UPDATED = true }
-- The events after which the role is worked out again at For tanks and damage dealers (ns.PlayerRole), heard through the hud module while that is
-- the row's choice, also while the table is hidden. Each is in events.yaml of the client: a role the group gives or takes back, as the game's player
-- frame hears it (Mainline/PlayerFrame.lua:63, 71, 197); talents spent or reset, and the switch to the other set of dual spec, which Forever's talent
-- window has (Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua:111-125, 144-145, 367-371), as the sheet hears them
-- (Camelot/PaperDollFrame.lua:315, 335, 340) and the talent window: it reads the points spent in each tree again on TRAIT_TREE_CURRENCY_INFO_UPDATED
-- (Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua:116, 338-342) and the set of talents once a change is applied on TRAIT_CONFIG_UPDATED
-- (:186, 343-345), and the set in use on ACTIVE_COMBAT_CONFIG_CHANGED and the list of sets on TRAIT_CONFIG_LIST_UPDATED
-- (ClassTalents/Blizzard_ClassTalentsFrame.lua:41, 46, 335-336, 340-342), so a set the client gives only after the interface loaded is read too; the
-- Cooldown Manager follows a change of set the same way (Blizzard_CooldownViewer/CooldownViewerSettingsDataProvider.lua:26-29). Then a level; a
-- stance or form; a new world. The player's UNIT_AURA is heard too, for Righteous Fury and the game's tank aura (PlateThreat.lua). A pick that waits
-- unapplied in the talent window brings TRAIT_TREE_CURRENCY_INFO_UPDATED too, and does not count: only the talents applied do (MostPoints,
-- Core.lua).
local ROLE_EVENTS = { "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
	"TRAIT_TREE_CURRENCY_INFO_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED", "TRAIT_CONFIG_LIST_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED",
	"PLAYER_LEVEL_UP", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" }
-- The roles as /flatui status names them.
local ROLE_WORDS = { tank = "a tank", healer = "a healer", damage = "a damage dealer" }
-- The lines of /flatui status.
local LINE_WHERE = {
	container = "Hit table: under the player frame.",
	frame = "Hit table: under the player frame.",
	["cast bar"] = "Hit table: under the cast bar, which Edit Mode locks to the player frame.",
	spot = "Hit table: at the spot set with the movers.",
	screen = "Hit table: the player frame cannot be used, so the table is under the middle of the screen.",
}
local LINE_WAITS = "Hit table: a change of place waits for the end of the fight."
local LINE_PET = "Hit table: lowered under the pet frame, or test mode's sample of it, which it would run into."
local LINE_SANS = "Hit table: the game did not load Flat UI Sans, so the table uses the game font."
local LINE_GAP = {
	withheld = "Hit table: the game withheld your %s, so parts of %s show ?.",
	refused = "Hit table: the game refused your %s, so parts of %s show ?.",
	missing = "Hit table: this client gives no %s, so parts of %s show ?.",
}
local LINE_ASSUMED = "Hit table: the game gave no weapon skill for your %s, so it counts %d, the most for your level."
local LINE_UNKNOWN = "Hit table: your target's level shows as ??, so it counts as level %d."
local LINE_PLAYER = "Hit table: against a player, dodge, parry and block start at 5%, since the game does not give theirs."
local LINE_NO_RANGED = "Hit table: no ranged line, since you wear no bow, gun, crossbow, thrown weapon or wand."
local LINE_RANGED_UNKNOWN = "Hit table: no ranged line, since the game did not say what your ranged slot holds."
local LINE_EMPTY = "Hit table: hidden, with no line to show."
local LINE_NO_LEVEL = "Hit table: hidden, since the game does not give your level."
local LINE_FACING = "Hit table: the game did not say whether your target attacks you, so the table counts you behind it."
local LINE_OFF_CRIT = "Hit table: the game gives one crit chance, your main hand's, so crit talents for one kind of weapon may make your off hand's crit differ."
local LINE_RESIST = "Hit table: Resist is the share of a spell's damage resisted on average, with your Spell Piercing %d. The enemy's own resistances are not known and count as none, so below 0 it is the damage a creature takes more from your piercing (Spell Vulnerability); against a player piercing does nothing below 0. Piercing of one school, as Fire Piercing, counts only in the gear comparison and the Expected line of a spell's tooltip, not here."
local LINE_RESIST_LEVEL = "Hit table: Resist counts %s%% for the levels the enemy is above you, Classic's rule and an estimate on WoW: Forever; piercing does not lower it. A spell with an effect beyond its damage, as a slow, takes no such share but pays for the levels with its higher miss, and the gear comparison leaves the share out."
local LINE_FIT = "Hit table: the text is %d%% of Text size, so the table ends before the %s. /flatui move places it elsewhere."
-- At For tanks and damage dealers: on or off, the role, and what it was read from (the third answer of ns.PlayerRole, a phrase such as "your group
-- role" or "most points in Holy"), as nameplate threat names its own (PlateThreat.lua); setup's sentence, a suggestion, is not said here.
local LINE_ROLE = "Hit table: %s, since you count as %s."
local LINE_ROLE_BY = "Hit table: %s, since you count as %s (%s)."

local IsSecret, Finite = ns.IsSecret, ns.Finite

-- frame: the table; rail: the frame it hangs from under the player frame; outline: its background and border; title and note: the first line, the
-- enemy and the weapon skill; heads: the headings; rows: the lines, each { label, cells }; probe: a text never drawn that measures widths. A text
-- is { fs, text, colour, font }: the font string and what was last written to it. fontKey, file, size: the font in use; widths: widths measured
-- with it, by text; measures: those tables by font, and measured: how many. ear: the frame that hears the events, hearing: it does, units: the units
-- each unit event counts for, alone: the unit events the client registered for those units alone, dirty: the table waits for the next frame.
-- fighting: between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED. dead: the target was dead at the last look. read: the last numbers
-- (HitTableCalc.lua). laid: the key of the layout. placed, edge, anchor: where the table was put; where: what /flatui status says of it; later: a
-- place waits for the end of the fight. room: the width the table may take under the player frame, in its own units, nil for no bound; roomBy:
-- what ends it; fit: the share of Text size the text was made to end there, nil while it has its size. hooked: the cast bar's lock is followed.
-- stepped: the table was lowered under the pet frame (PetStep); petWaits: a look at the pet frame waits after UNIT_PET.
-- sansRefused: the game refused Flat UI Sans. role and by: the player's role at the last look ("tank", "healer" or "damage", nil before the
-- first) and what ns.PlayerRole read it from; recheck: an event that can change the role came, so the next frame looks again.
local S = { heads = {}, rows = {}, widths = {}, measures = {}, measured = 0, units = {}, alone = {}, hearing = false, fighting = false, dirty = false,
	later = false, recheck = false, stepped = false, petWaits = false }
local Update, Later, Off, Dirty, Apply

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
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

-- The choice of Hit table under the player frame: "role" (For tanks and damage dealers), "on" (Always) or "off". A tick of 0.5.18 that slips past
-- the migration (Core.lua, ns.MigrateText) reads as on or off.
local function Choice()
	local value = Opt("hitTable")
	if value == true or value == "on" then
		return "on"
	elseif value == false or value == "off" then
		return "off"
	end
	return "role"
end

-- Looks at the player's role again: the role and what it was read from, its first and third answers (ns.PlayerRole, Core.lua, which only reads and
-- drops a withheld answer; the second is setup's sentence).
local function WorkOutRole()
	local role, by
	if type(ns.PlayerRole) == "function" then
		local _
		role, _, by = ns.PlayerRole()
	end
	S.role = (role == "tank" or role == "healer") and role or "damage"
	S.by = type(by) == "string" and by or nil
end

-- True while the row lets the table show: Always, or For tanks and damage dealers while the player is no healer (the role of the last look, else
-- one now).
local function Shows()
	local choice = Choice()
	if choice == "role" then
		if S.role == nil then
			WorkOutRole()
		end
		return S.role ~= "healer"
	end
	return choice == "on"
end

-- True while the table is wanted: the page on, the row letting it show, the part not stopped.
local function Wanted()
	return ns.Enabled(KEY) and Shows() and not ns.PartStopped(KEY, PART)
end

-- Runs fn as this part: a fault is counted by ns.EachPart, and three stop the part alone (each call is a new table, so each fault counts); the
-- table then hides at once and hears nothing more, as MapText.lua puts its text away.
local function Call(_, fn, ...)
	fn(...)
end

local function Safe(fn, ...)
	if ns.EachPart(KEY, PART, Call, {}, fn, ...) then
		return true
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Off)
	end
	return false
end

-- Whether the player is in a fight now, for a first look; a withheld answer counts as out of combat, as for the Threat list (Threat.lua).
local function InFight()
	local value = Ask(UnitAffectingCombat, "player")
	if type(value) == "boolean" then
		return value
	end
	return Ask(InCombatLockdown) == true
end

-- The player frame ----------------------------------------------------------------------------------------------------------------------------------

-- A field of a frame of the game, read without writing it, or nil (as UnitFrames.lua reads its parts).
local function Path(root, ...)
	local node = root
	for index = 1, select("#", ...) do
		if node == nil or IsSecret(node) or type(node) ~= "table" then
			return nil
		end
		local key = select(index, ...)
		local ok, child = pcall(function()
			return node[key]
		end)
		node = ok and not IsSecret(child) and child or nil
	end
	return node
end

-- True for a region whose left edge the client gives now, so a point set on it holds.
local function Laid(region)
	if region == nil or IsSecret(region) or type(region) ~= "table" then
		return false
	end
	local ok, left = pcall(function()
		return region:GetLeft()
	end)
	return ok and Finite(left)
end

-- True while a region is shown, by its own flag.
local function Shown(region)
	if region == nil or IsSecret(region) or type(region) ~= "table" then
		return false
	end
	local ok, shown = pcall(function()
		return region:IsShown()
	end)
	return ok and not IsSecret(shown) and shown == true
end

-- An edge of a frame in units of scale 1, its own units times its effective scale, so frames of any scale compare; nil when it cannot be read.
local function Edge(frame, method)
	if frame == nil or IsSecret(frame) or type(frame) ~= "table" then
		return nil
	end
	local ok, value, scale = pcall(function()
		return frame[method](frame), frame:GetEffectiveScale()
	end)
	if ok and Finite(value) and Finite(scale) and scale > 0 then
		return value * scale
	end
	return nil
end

local function Scale(frame)
	local ok, scale = pcall(frame.GetEffectiveScale, frame)
	return ok and Finite(scale) and scale > 0 and scale or 1
end

-- Flat UI's record of the player frame (UnitFrames.lua, which makes it whatever the Player frame row says), and the table of its helpers.
local function Record()
	local X = ns.UnitFrameExtra
	if type(X) ~= "table" or type(X.known) ~= "function" then
		return nil, X
	end
	return X.known(_G.PlayerFrame), X
end

-- The frame of Flat UI's picture on the player frame while Flat UI styles the frame and draws the picture (UnitFrames.lua, ApplyPicture sets
-- pic.drawn), else nil. That frame stays shown either way, as only its texture and outline are hidden, so its own flag says nothing.
local function Picture(rec, X)
	local pic = type(rec.pic) == "table" and rec.pic or nil
	if pic and pic.drawn == true and type(X.active) == "function" and X.active(rec) == true and Laid(pic.frame) then
		return pic.frame
	end
	return nil
end

-- The region whose left edge the table starts at: the body of One frame (UnitFrames.lua, FRAME.place), else Flat UI's picture while it draws one,
-- else the game's portrait while it shows, else the health bar, else the player frame. Each has its own border outside it, as the table has.
local function LeftEdge()
	local frame = _G.PlayerFrame
	local rec, X = Record()
	if rec then
		if type(X.joined) == "function" and X.joined(rec) == true and type(X.body) == "function" then
			local body = X.body(rec)
			if Laid(body) then
				return body
			end
		end
		local picture = Picture(rec, X)
		if picture then
			return picture
		end
	end
	local portrait = Path(frame, "PlayerFrameContainer", "PlayerPortrait")
	if Shown(portrait) and Laid(portrait) then
		return portrait
	end
	local health = rec and type(rec.parts) == "table" and rec.parts.health
		or Path(frame, "PlayerFrameContent", "PlayerFrameContentMain", "HealthBarsContainer", "HealthBar")
	if Laid(health) then
		return health
	end
	return Laid(frame) and frame or nil
end

-- The frame the table hangs under, and its name for /flatui status: the player's cast bar while Edit Mode locks it to the player frame, which the
-- game reads from attachedToPlayerFrame (Shared/PlayerFrame.lua:43, 58, 65-69; read only, as CastBarSize.lua reads it), else the container of the
-- pet frame and the totems, else the player frame.
local function Anchor()
	local bar = _G.PlayerCastingBarFrame
	if not ns.Forbidden(bar) then
		local ok, attached = pcall(function()
			return bar.attachedToPlayerFrame
		end)
		if ok and not IsSecret(attached) and attached == true then
			return bar, "cast bar"
		end
	end
	local box = _G.PlayerBottomManagedFrameContainer
	if not ns.Forbidden(box) then
		return box, "container"
	end
	local frame = _G.PlayerFrame
	if not ns.Forbidden(frame) then
		return frame, "frame"
	end
	return nil
end

-- True when the named Cooldown icons row has a spot of its own in the movers, which then holds it wherever the player put it (Cooldowns.lua, Place).
local function OwnSpot(name)
	return type(ns.MoverSaved) == "function" and ns.MoverSaved(name) == true
end

-- The lowest line Flat UI draws on or under the player frame, in units of scale 1, border is the width of one border there: under the body of One
-- frame, else under the power bar, the health bar and the picture while Flat UI styles the frame and draws them, under the druid's mana bar, whose
-- holder keeps its place in every form (UnitDruidMana.lua), and under the icons of each Cooldown icons row whose Position is under the player
-- frame and that has no spot of its own: its holder is 4 units under the frame's bottom and its icons hang from the holder's middle (Cooldowns.lua,
-- Place and R.LayoutRow), given by the movers' row functions (ns.CooldownRow, ns.CooldownRow2 to 4: nothing while the page or the row is off).
-- Nil while Flat UI draws nothing there.
local function Lowest(border)
	local low
	local function Take(region)
		local bottom = Edge(region, "GetBottom")
		if bottom then
			low = math.min(low or bottom - border, bottom - border)
		end
	end
	local rec, X = Record()
	if rec then
		if type(X.active) == "function" and X.active(rec) == true then
			if type(X.joined) == "function" and X.joined(rec) == true and type(X.body) == "function" then
				Take(X.body(rec))
			else
				local roles = type(rec.byRole) == "table" and rec.byRole or {}
				Take(type(roles.power) == "table" and roles.power.target or nil)
				Take(type(roles.health) == "table" and roles.health.target or nil)
				Take(Picture(rec, X))
			end
		end
		local mana = rec.druidMana
		if type(mana) == "table" and mana.holder ~= nil and ns.Enabled("unitframes") and ns.Get("unitframes.druidMana") == true then
			Take(mana.holder)
		end
	end
	for _, row in ipairs(COOLDOWN_ROWS) do
		local icons = ns[row[1]]
		if type(icons) == "function" and ns.Get(row[2]) == "player" and not OwnSpot(row[3]) then
			local ok, list = pcall(icons)
			if ok and type(list) == "table" then
				for _, icon in ipairs(list) do
					Take(icon)
				end
			end
		end
	end
	return low
end

-- How far a pet's auras reach under the container, in units of scale 1, for a class whose own pet the pet frame shows, or while the pet frame shows;
-- 0 otherwise.
local function PetAuras()
	local pet = _G.PetFrame
	if ns.Forbidden(pet) then
		return 0
	end
	local ok, _, class = pcall(UnitClass, "player")
	if not (ok and not IsSecret(class) and type(class) == "string" and PET_CLASSES[class]) and not Shown(pet) then
		return 0
	end
	return PET_AURAS * Scale(pet)
end

-- The pet frame while it shows, or while test mode shows its sample there (the stand-in "pet" of TestUnits.lua, at the pet frame's place and
-- scale, TM.Shown): its left, right and top edges and the lowest its auras reach (PET_BELOW under it), in units of scale 1. Nil when neither shows
-- or the pet frame has no place.
local function PetRect()
	local pet = _G.PetFrame
	if ns.Forbidden(pet) then
		return nil
	end
	local mode = ns.TestMode
	if not Shown(pet) and not (type(mode) == "table" and type(mode.Shown) == "function" and mode.Shown("pet") == true) then
		return nil
	end
	local left, right, top, bottom = Edge(pet, "GetLeft"), Edge(pet, "GetRight"), Edge(pet, "GetTop"), Edge(pet, "GetBottom")
	if not (left and right and top and bottom) then
		return nil
	end
	return left, right, top, bottom - PET_BELOW * Scale(pet)
end

-- The width of the table's own border, outside its frame, in units of scale 1: one border of the hud page's look while it has its background.
local function Border()
	if Opt("hitTableBack") == false then
		return 0
	end
	local frame = S.frame
	return (tonumber(ns.Get("general.thickness")) or 1) * ns.Pixels(frame, 1) * Scale(frame)
end

-- How far the table goes down to clear the pet frame (PetRect) when its box, border and all, from left to right and down from top `height` tall,
-- in units of scale 1, runs into the pet frame or its auras: its top then comes a GAP under their lowest. 0 when it is clear or no pet frame shows.
local function PetStep(left, right, top, height)
	local petLeft, petRight, petTop, petLow = PetRect()
	if not petLeft or left >= petRight or right <= petLeft or top <= petLow or top - height >= petTop then
		return 0
	end
	return top - petLow + GAP * Scale(S.frame)
end

-- How far the spell name hangs under the locked cast bar, in units of scale 1: with Custom player cast bar size on and Player cast bar text Below the
-- bar, Flat UI puts its top 1 unit above the bar's bottom on every cast (CastBarSize.lua, Size and PlaceText), as tall as its font, read out of
-- combat (the game's own size when the font cannot be read); 0 otherwise.
local function TextBelow(bar)
	if not (ns.Enabled("castbars") and not ns.PartStopped("castbars", "size") and ns.Get("castbars.playerSize") == true
		and ns.Get("castbars.playerText") == "below") then
		return 0
	end
	local text, height = Path(bar, "Text"), nil
	if text ~= nil then
		local ok, _, size = pcall(function()
			return text:GetFont()
		end)
		height = ok and Finite(size) and size > 0 and size or nil
	end
	return math.max(0, (height or BASE) - 1) * Scale(bar)
end

-- How far under the anchor's bottom the table's top is, in its own units: GAP and its own border, and the most of three: how far Flat UI's lines and
-- the Cooldown icons rows under the player frame reach under the anchor while the container is at its smallest; how far a pet's auras reach under the
-- container; how far the spell name hangs under the locked cast bar. The game lowers the container's bottom as a pet frame comes, and the locked
-- cast bar with it while the container shows (Shared/PlayerFrame.lua:24-27), so the anchor's bottom at the smallest is its bottom now raised by
-- what the container holds; the table then clears all of them with a pet or without one. The cast bar's top already sits 13 units under the
-- container's bottom (12 under the player frame less the container's height, Shared/PlayerFrame.lua:24-26; the container's top 25 above,
-- PlayerFrame.xml:482), past the reach of a pet's auras.
local function Offset(anchor, kind)
	local frame = S.frame
	local scale = Scale(frame)
	local pixel = ns.Pixels(frame, 1) * scale
	local thickness = tonumber(ns.Get("general.thickness")) or 1
	local below = 0
	local bottom, low = Edge(anchor, "GetBottom"), Lowest(thickness * pixel)
	if bottom and low then
		local box = _G.PlayerBottomManagedFrameContainer
		if kind == "container" or (kind == "cast bar" and Shown(box)) then
			local ok, height, boxScale = pcall(function()
				return box:GetHeight(), box:GetEffectiveScale()
			end)
			if ok and Finite(height) and Finite(boxScale) and height > SMALLEST then
				bottom = bottom + (height - SMALLEST) * boxScale
			end
		end
		below = math.max(0, bottom - low)
	end
	if kind == "container" then
		below = math.max(below, PetAuras())
	elseif kind == "cast bar" then
		below = math.max(below, TextBelow(anchor))
	end
	return (GAP * scale + (Opt("hitTableBack") ~= false and thickness * pixel or 0) + below) / scale
end

-- Keeps the width the table may take, in its own units, and what ends it; a change lays the table out again on the next frame. Nil for no bound.
local function SetRoom(room, by)
	if room ~= S.room or by ~= S.roomBy then
		S.room, S.roomBy = room, by
		Dirty()
	end
end

-- The table's height at Text size, in its own units, for the lines it shows now (Layout): the height it is measured with beside the player frame.
local function NaturalHeight()
	local size = BASE * (tonumber(Opt("hitTableSize")) or 100) / 100
	local lines = type(S.read) == "table" and #S.read.lines or 0
	return 2 * PAD_Y + math.ceil(size + 3) * (2 + math.max(1, lines))
end

-- The width the table may take under the player frame, out of combat with its points: from its left edge to a GAP short of the left edge of the
-- target frame or the focus frame that stands beside it (right of that edge, not above the player frame and not under the table), else of the edge of
-- the screen. Edit Mode's Modern layout puts the target frame 600 units right of the player frame (EditModePresetLayouts.lua:249-275), so there the
-- table keeps its size; its Classic layout puts it 14 units right of the player frame (:1049-1075), whose 232 units (PlayerFrame.xml:14) leave a
-- table at Text size too little room.
local function Room(edge, anchor, offset)
	local scale = Scale(S.frame)
	local left = Edge(edge, "GetLeft")
	if not left then
		SetRoom(nil, nil)
		return
	end
	local limit, by = Edge(UIParent, "GetRight"), "edge of the screen"
	local top, bottom = Edge(_G.PlayerFrame, "GetTop"), Edge(anchor, "GetBottom")
	local lowest = bottom and bottom - (offset + NaturalHeight()) * scale or nil
	for _, entry in ipairs(BESIDE) do
		local other = _G[entry[1]]
		if not ns.Forbidden(other) then
			local otherLeft, otherTop, otherBottom = Edge(other, "GetLeft"), Edge(other, "GetTop"), Edge(other, "GetBottom")
			if otherLeft and otherTop and otherBottom and otherLeft > left + GAP * scale and (top == nil or otherBottom < top)
				and (lowest == nil or otherTop > lowest) and (limit == nil or otherLeft < limit) then
				limit, by = otherLeft, entry[2]
			end
		end
	end
	if limit then
		SetRoom(math.floor(math.max(0, limit - left - GAP * scale) / scale), by)
	else
		SetRoom(nil, nil)
	end
end

-- Places the table, out of combat: at the spot saved in the movers, by the point it was saved by (as Data panels reads it, DataPanels.lua), else
-- under the player frame from the rail, where its width is bounded (Room), else under the middle of the screen when the player frame cannot be used.
-- At the spot or on the rail it is lowered under the pet frame, or test mode's sample of it, where it would run into it (PetStep). A place already
-- taken is not set again.
local function Place()
	local frame = S.frame
	if not frame then
		return
	end
	if InCombatLockdown() then
		Later()
		return
	end
	local spots = type(ns.Spots) == "function" and ns.Spots() or nil
	local entry = type(spots) == "table" and type(ns.CleanSpot) == "function" and ns.CleanSpot(spots[MOVER]) or nil
	local point = entry and entry.point or "TOPLEFT"
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, point)
	end
	local scale, border = Scale(frame), Border()
	local width, height = frame:GetWidth() * scale, frame:GetHeight() * scale
	if x then
		local share = SHARE[point] or SHARE.TOPLEFT
		local left, top = x * scale - width * share[1], y * scale + height * (1 - share[2])
		local step = PetStep(left - border, left + width + border, top + border, height + 2 * border) / scale
		S.stepped = step > 0
		y = y - step
		local key = ("spot:%s:%.2f:%.2f"):format(point, x, y)
		if S.placed ~= key then
			frame:ClearAllPoints()
			frame:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
			S.placed, S.edge, S.anchor = key, nil, nil
		end
		S.where = "spot"
		SetRoom(nil, nil)
		return
	end
	local anchor, kind = Anchor()
	local edge = anchor and LeftEdge() or nil
	if anchor and edge then
		local offset = Offset(anchor, kind)
		local bottom, left = Edge(anchor, "GetBottom"), Edge(edge, "GetLeft")
		local step = bottom and left and PetStep(left - border, left + width + border, bottom - offset * scale + border, height + 2 * border) / scale or 0
		S.stepped = step > 0
		offset = offset + step
		Room(edge, anchor, offset)
		local key = ("%s:%.2f"):format(kind, offset)
		if S.placed == key and S.edge == edge and S.anchor == anchor then
			S.where = kind
			return
		end
		local rail = S.rail
		local ok = pcall(function()
			rail:ClearAllPoints()
			rail:SetPoint("TOPLEFT", edge, "TOPLEFT", 0, 0)
			rail:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", rail, "BOTTOMLEFT", 0, -offset)
		end)
		if ok then
			S.placed, S.edge, S.anchor, S.where = key, edge, anchor, kind
			return
		end
	end
	if S.placed ~= "screen" then
		frame:ClearAllPoints()
		frame:SetPoint("TOP", UIParent, "CENTER", 0, -150)
		S.placed, S.edge, S.anchor = "screen", nil, nil
	end
	S.where, S.stepped = "screen", false
	SetRoom(nil, nil)
end

-- A place asked for in a fight waits once for its end.
Later = function()
	if S.later then
		return
	end
	S.later = true
	ns.OutOfCombat(function()
		S.later = false
		if S.frame and Wanted() then
			Safe(Place)
		end
	end)
end

-- Text -----------------------------------------------------------------------------------------------------------------------------------------------

-- Flat UI Sans has Latin and Cyrillic letters; any other client takes the game font (DataPanels.lua, Covers).
local function Covers()
	if ns.FontsLatin == nil or ns.FontsLatin() then
		return true
	end
	return Ask(GetLocale) == "ruRU"
end

-- The file of the game's small text, read from its font object.
local function GameFile()
	local object = _G[FONT]
	if type(object) == "table" and not IsSecret(object) then
		local ok, file = pcall(object.GetFont, object)
		if ok and not IsSecret(file) and type(file) == "string" and file ~= "" then
			return file
		end
	end
	return GAME_FONT
end

-- The font of Font and Text size, its size times fit while the table is made to end within its room (1 or nil otherwise), never under the smallest
-- Text size. A table made to fit measures at two sizes, so the widths measured are kept by font, for MEASURED fonts at most; a refusal of Flat UI
-- Sans is forgotten only when the face changes.
local function Font(fit)
	local size = BASE * (tonumber(Opt("hitTableSize")) or 100) / 100
	if fit and fit < 1 then
		size = math.max(BASE * SMALLEST_TEXT, size * fit)
	end
	local file = Opt("hitTableFont") == "sans" and Covers() and SANS or nil
	local key = ("%s:%.2f"):format(file or "game", size)
	if S.fontKey == key then
		return
	end
	local widths = S.measures[key]
	if not widths then
		if S.measured >= MEASURED then
			S.measures, S.measured = {}, 0
		end
		widths = {}
		S.measures[key], S.measured = widths, S.measured + 1
	end
	if S.file ~= file then
		S.sansRefused = false
	end
	S.fontKey, S.file, S.size, S.widths = key, file, size, widths
end

-- Gives a text the font in use once. A face the game refuses (an answer of false, or an error) leaves the game's font, and /flatui status says so
-- (DataPanels.lua, P.SetFont).
local function Dress(text)
	if text.font == S.fontKey then
		return
	end
	text.font = S.fontKey
	local fs = text.fs
	if S.file then
		local ok, set = pcall(fs.SetFont, fs, S.file, S.size, "")
		if ok and (IsSecret(set) or set ~= false) then
			return
		end
		S.sansRefused = true
	end
	pcall(fs.SetFont, fs, GameFile(), S.size, "")
end

-- A text of the table's own, one line, with the shadow the readouts of the screen have.
local function Text(parent, justify)
	local fs = ns.OwnText(parent, "OVERLAY", FONT)
	fs:SetJustifyH(justify)
	fs:SetJustifyV("MIDDLE")
	fs:SetWordWrap(false)
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	return { fs = fs }
end

-- Line number index, made the first time the table needs it: its name and a cell for each column.
local function Row(index)
	local row = S.rows[index]
	if not row then
		row = { label = Text(S.frame, "LEFT"), cells = {} }
		for column = 1, #COLUMNS do
			row.cells[column] = Text(S.frame, "RIGHT")
		end
		S.rows[index] = row
	end
	return row
end

-- The width of a text in the font in use, measured once with the probe; a client that gives none gets a guess from its length.
local function Measure(text)
	local width = S.widths[text]
	if width == nil then
		local probe = S.probe
		Dress(probe)
		probe.fs:SetText(text)
		local ok, measured = pcall(probe.fs.GetStringWidth, probe.fs)
		width = ok and Finite(measured) and measured > 0 and measured or S.size * 0.6 * #text
		S.widths[text] = width
	end
	return width
end

-- Writes a text and its colour, each only when it changed.
local function Put(text, value, colour)
	Dress(text)
	if text.text ~= value then
		text.fs:SetText(value)
		text.text = value
	end
	if text.colour ~= colour then
		text.fs:SetTextColor(colour[1], colour[2], colour[3], 1)
		text.colour = colour
	end
end

-- Puts a text at a point of the table's top left corner, as wide and as high as given, and shows it.
local function At(text, point, x, y, width, height)
	local fs = text.fs
	fs:ClearAllPoints()
	fs:SetPoint(point, S.frame, "TOPLEFT", x, y)
	fs:SetSize(width, height)
	fs:Show()
end

-- The table ----------------------------------------------------------------------------------------------------------------------------------------

-- The columns that apply to a line shown, in the order of the roll. widest adds those a line of a weapon gains from the front, Parry for a line that
-- can be dodged and Block for any (HitTableCalc.lua, Parry, Block and Ranged), so a table made to fit keeps its size as the facing changes.
local function Columns(lines, widest)
	local list = {}
	for _, column in ipairs(COLUMNS) do
		local key = column[1]
		for _, line in ipairs(lines) do
			local parts = line.parts
			if parts[key] ~= false or (widest and line.skill and (key == "block" or (key == "parry" and parts.dodge ~= false))) then
				list[#list + 1] = column
				break
			end
		end
	end
	return list
end

-- The title: the enemy as counted, and where the player stands while a line of a weapon shows.
local function Title(read)
	local target = read.target
	if not target then
		return ""
	end
	local text
	if target.boss then
		text = ("Boss, level %d"):format(target.level)
	elseif target.none then
		text = ("Level %d, no target"):format(target.level)
	else
		local kind = target.player and "player" or KIND_WORDS[target.kind]
		text = (target.unknown and "Level ?? (%d)" or "Level %d"):format(target.level) .. (kind and (" " .. kind) or "")
	end
	for _, line in ipairs(read.lines) do
		if line.skill then
			return text .. (read.front and ", in front" or ", behind")
		end
	end
	return text
end

-- The weapon skill of the lines of a weapon, a special attack's being the swing's.
local function Note(read)
	local skills = {}
	for _, line in ipairs(read.lines) do
		if line.skill and line.id ~= "special" then
			skills[#skills + 1] = ("%d"):format(math.floor(line.skill + 0.5))
		end
	end
	return #skills > 0 and ("Skill " .. table.concat(skills, " / ")) or ""
end

-- The text and colour of a cell: a resist below 0, the damage taken more, green, and one that rounds to 0 without its sign.
local function Value(line, key)
	local value = line.parts[key]
	if value == false then
		return "-", FAINT
	elseif value == nil then
		return "?", DIM
	end
	local colour = PLAIN
	if line.over and (key == "crit" or key == "cap") then
		colour = WARN
	elseif FLOORED[key] and value < (key == "miss" and line.floor or 0) + 0.05 then
		colour = OK
	elseif key == "resist" and value <= -0.05 then
		colour = OK
	end
	if math.abs(value) < 0.05 then
		value = 0
	end
	return ("%.1f"):format(value), colour
end

-- A gap of the layout, in whole units, times k, the share of Text size the text is made to fit (1 at its size).
local function Units(units, k)
	return math.max(1, math.floor(units * k + 0.5))
end

-- The sizes of the table for these columns, lines, title and note in the font in use, its gaps times k: the height of a line, the gaps inside the
-- edge, the width of the names, the width and right edge of each column, the width of the note and the room it takes beside the title, the width
-- of the names and the columns (content), and the whole width, which the title may widen.
local function Geometry(columns, lines, title, note, k)
	local g = { rowHeight = math.ceil(S.size + 3), padX = Units(PAD_X, k), padY = Units(PAD_Y, k), widths = {}, rights = {}, ids = {} }
	local nameWidth = 0
	for _, line in ipairs(lines) do
		nameWidth = math.max(nameWidth, Measure(line.label))
	end
	g.nameWidth = math.ceil(nameWidth)
	local number, gap = Measure(WIDEST), Units(COLUMN_GAP, k)
	local x = g.padX + g.nameWidth + Units(NAME_GAP, k)
	for index, column in ipairs(columns) do
		g.widths[index] = math.ceil(math.max(number, Measure(column[2])))
		x = x + g.widths[index]
		g.rights[index] = x
		x = x + gap
		g.ids[index] = column[1]
	end
	g.noteWidth = note ~= "" and math.ceil(Measure(note)) + 2 or 0
	g.besideNote = g.noteWidth > 0 and g.noteWidth + Units(TITLE_GAP, k) or 0
	g.content = (#columns > 0 and g.rights[#columns] or g.padX + g.nameWidth) + g.padX
	g.width = math.max(g.content, g.padX + math.ceil(Measure(title)) + g.besideNote + g.padX)
	return g
end

-- The share of Text size the text is made so the table ends within its room (S.room), in steps of FIT_STEP down to the smallest Text size; 1 while
-- it fits or has no bound. It is worked out from the widest columns the lines can come to show (Columns), so the size holds as the facing changes in
-- a fight, and from the names and columns alone: the title gives way instead, cut short.
local function Fit(lines)
	local room = S.room
	if not room then
		return 1
	end
	local widest = Columns(lines, Opt("hitTableFacing") == "auto")
	Font(1)
	local natural = Geometry(widest, lines, "", "", 1).content
	if natural <= room then
		return 1
	end
	local fit = math.max(FIT_STEP, math.floor(room / natural / FIT_STEP) * FIT_STEP)
	while fit > FIT_STEP do
		Font(fit)
		if S.size <= BASE * SMALLEST_TEXT or Geometry(widest, lines, "", "", fit).content <= room then
			break
		end
		fit = fit - FIT_STEP
	end
	return fit
end

-- Lays out the title, the headings and the lines as Geometry worked them out, and sizes the table to them: the names of the lines on the left, then
-- each column as wide as its heading or the widest number, its text at its right edge. Laid out again only when the font, the columns, the lines,
-- the gaps or the width change.
local function Layout(g, lines)
	local names = {}
	for index, line in ipairs(lines) do
		names[index] = line.label
	end
	local width, rowHeight, padX, padY = g.width, g.rowHeight, g.padX, g.padY
	local key = table.concat({ S.fontKey, table.concat(g.ids, ","), table.concat(names, ","), width, g.noteWidth, padX, padY }, ":")
	if S.laid == key then
		return
	end
	At(S.note, "TOPRIGHT", width - padX, -padY, math.max(1, g.noteWidth), rowHeight)
	At(S.title, "TOPLEFT", padX, -padY, math.max(1, width - 2 * padX - g.besideNote), rowHeight)
	local top = -(padY + rowHeight)
	for index, head in ipairs(S.heads) do
		if index <= #g.ids then
			At(head, "TOPRIGHT", g.rights[index], top, g.widths[index], rowHeight)
		else
			head.fs:Hide()
		end
	end
	for index = 1, math.max(#lines, #S.rows) do
		if index <= #lines then
			local row, y = Row(index), top - rowHeight * index
			At(row.label, "TOPLEFT", padX, y, g.nameWidth + 2, rowHeight)
			for column, cell in ipairs(row.cells) do
				if column <= #g.ids then
					At(cell, "TOPRIGHT", g.rights[column], y, g.widths[column], rowHeight)
				else
					cell.fs:Hide()
				end
			end
		else
			local row = S.rows[index]
			row.label.fs:Hide()
			for _, cell in ipairs(row.cells) do
				cell.fs:Hide()
			end
		end
	end
	S.frame:SetSize(width, 2 * padY + rowHeight * (2 + #lines))
	S.laid = key
	-- A new size can run the table into the pet frame or clear it: placed again while one shows or it was lowered (Place, in a fight after it).
	if S.where and (S.stepped or PetRect()) then
		Place()
	end
end

-- Writes the title, the headings and the cells.
local function Fill(columns, lines, title, note)
	Put(S.title, title, DIM)
	Put(S.note, note, DIM)
	for index, column in ipairs(columns) do
		Put(S.heads[index], column[2], DIM)
	end
	for index, line in ipairs(lines) do
		local row = S.rows[index]
		Put(row.label, line.label, DIM)
		for column, spec in ipairs(columns) do
			Put(row.cells[column], Value(line, spec[1]))
		end
	end
end

-- True while Show lets the table show: always, in combat, or with an enemy targeted, one that can be attacked and is alive (as the Threat list
-- tells an enemy, Threat.lua, T.Enemy, without leaving out players, since a duel's foe can be attacked).
-- While test mode is on (TestMode.lua) every rule lets it show.
local function Testing()
	local mode = ns.TestMode
	return mode ~= nil and mode.IsOn() == true
end

local function Allowed()
	local rule = Opt("hitTableShow")
	if rule == "always" or Testing() then
		return true
	elseif rule == "combat" then
		return S.fighting
	end
	return Ask(UnitExists, "target") == true and Ask(UnitCanAttack, "player", "target") == true and not S.dead
end

-- The fades of the table (0.5.36), as the threat list's (Threat.lua): in over FADE[1] seconds as Show lets it show, out over FADE[2] as it hides
-- it. The frame stays shown at opacity 0 at the end of a fade out, so the movers keep its box. A fade out that a new target breaks gives the
-- opacity back at once, with no flicker, and a refresh (force: a changed row, the page, the profile, test mode's On and Off) sets it at once.
local FADE = { 0.15, 0.35 }

-- The two Alpha animations of the frame, made once with it; nil where the client makes none.
local function Fades(frame)
	local ok, come, go = pcall(function()
		local fadeIn = frame:CreateAnimationGroup()
		local rise = fadeIn:CreateAnimation("Alpha")
		rise:SetFromAlpha(0)
		rise:SetToAlpha(1)
		rise:SetDuration(FADE[1])
		local fadeOut = frame:CreateAnimationGroup()
		local fall = fadeOut:CreateAnimation("Alpha")
		fall:SetFromAlpha(1)
		fall:SetToAlpha(0)
		fall:SetDuration(FADE[2])
		pcall(fadeOut.SetToFinalAlpha, fadeOut, true)
		fadeOut:SetScript("OnFinished", function()
			frame:SetAlpha(0)
		end)
		return fadeIn, fadeOut
	end)
	if ok then
		return come, go
	end
	return nil, nil
end

-- Shows the table (opacity 1) or hides it (opacity 0) with its fades; now, or a frame whose opacity is not known yet, without them. S.visible
-- is what was asked last: true, false, or nil after Off.
local function Visible(on, now)
	local frame, come, go = S.frame, S.fadeIn, S.fadeOut
	local fading = go ~= nil and go:IsPlaying()
	if on then
		if fading then
			pcall(go.Stop, go)
		end
		if S.visible ~= true then
			frame:SetAlpha(1)
			-- Only a table fully faded out fades in; one caught in its fade out is back at once.
			if come and not now and not fading and S.visible == false then
				pcall(come.Play, come)
			end
		end
	else
		if come and come:IsPlaying() then
			pcall(come.Stop, come)
		end
		-- A fade out under way goes on to its end; a frame already hidden, or a refresh, takes 0 at once.
		if now or not go or (S.visible ~= true and not fading) then
			if fading then
				pcall(go.Stop, go)
			end
			frame:SetAlpha(0)
		elseif not fading and not pcall(go.Play, go) then
			frame:SetAlpha(0)
		end
	end
	S.visible = on
end

-- Works the table out and draws it. A rule that hides it sets its opacity to 0 and leaves it laid out, so the movers find its box; while it is
-- hidden so the numbers wait, once it has been laid out, and the next event that shows it works them out. A refresh (force) lays it out all the
-- same, so its box follows a changed row. The opacity changes with a fade (Visible), and at once in a refresh.
Update = function(force)
	S.dirty = false
	local calc = ns.HitTableCalc
	if not (S.frame and Wanted()) or type(calc) ~= "table" or type(calc.Read) ~= "function" then
		return
	end
	S.dead = Ask(UnitIsDeadOrGhost, "target") == true
	local allowed = Allowed()
	if not allowed and S.laid and not force then
		Visible(false)
		return
	end
	-- Against the target, with no enemy targeted in test mode: a boss, three levels above the player, rather than a mob of the player's level.
	local against = Opt("hitTableAgainst")
	if against == "target" and Testing() and not (Ask(UnitExists, "target") == true and Ask(UnitCanAttack, "player", "target") == true and not S.dead) then
		against = "boss"
	end
	local read = calc.Read({ lines = Opt("hitTableLines"), special = Opt("hitTableSpecial") ~= false, against = against,
		facing = Opt("hitTableFacing"), rules = Opt("hitTableRules") })
	S.read = read
	local lines = read.lines
	local columns, title, note = Columns(lines), Title(read), Note(read)
	-- Within its room the table keeps its top left corner on the rail and ends before the frame beside the player frame: the text is made smaller,
	-- which a font string takes in a fight too, and the title is cut short rather than widen it.
	local fit = Fit(lines)
	Font(fit)
	local wanted = BASE * (tonumber(Opt("hitTableSize")) or 100) / 100
	S.fit = S.size < wanted - 0.005 and S.size / wanted or nil
	local g = Geometry(columns, lines, title, note, fit)
	if S.room and g.width > S.room then
		g.width = math.max(g.content, S.room)
	end
	Layout(g, lines)
	Fill(columns, lines, title, note)
	Visible(allowed and #lines > 0, force)
end

-- Events ---------------------------------------------------------------------------------------------------------------------------------------------

-- After an event that can change the role (ROLE_EVENTS): the role is looked at again, and the table shows or hides when the row's answer for it
-- changed (Apply); else the numbers are worked out again, as after any other event.
local function Recheck()
	local was = Wanted()
	WorkOutRole()
	if Wanted() ~= was then
		Apply()
	else
		Update()
	end
end

-- The work of the frame after a burst: the role first when an event that can change it came, then the numbers.
local function Work()
	if S.recheck then
		S.recheck = false
		Recheck()
	else
		Update()
	end
end

-- The OnUpdate of the ear: once, on the frame after the events of a burst.
local function Tick(ear)
	ear:SetScript("OnUpdate", nil)
	S.dirty = false
	Safe(Work)
end

-- Marks the table, and with S.recheck the role, to be worked out again on the next frame.
Dirty = function()
	if S.dirty then
		return
	end
	S.dirty = true
	local ear = S.ear
	if not (ear and pcall(ear.SetScript, ear, "OnUpdate", Tick)) then
		S.dirty = false
		Work()
	end
end

-- The player's pet came or went: the table is placed again a moment later (PET_WAIT), once the pet frame, or test mode's sample of it, has shown
-- or hidden, so it steps under the pet frame or back up (Place). Once for a burst.
local function PetSoon()
	if S.petWaits then
		return
	end
	S.petWaits = true
	local function Look()
		S.petWaits = false
		if S.frame and Wanted() then
			Safe(Place)
		end
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(PET_WAIT, Look)
	else
		Look()
	end
end

local function OnEvent(event, unit)
	local units = S.units[event]
	if units then
		-- A unit event registered for its units alone is theirs whatever its token says: the game may withhold the payload, the token with it
		-- (UNIT_AURA, UnitAuraDocumentation.lua:644-655), so it is not read. One heard for every unit, on a client that cannot hear one, counts
		-- for its own units, and when the token is withheld.
		if not S.alone[event] and not IsSecret(unit) and not (type(unit) == "string" and units[unit]) then
			return
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		S.fighting = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		S.fighting = false
	end
	-- A pet changes no number, only the place.
	if event == "UNIT_PET" then
		PetSoon()
		return
	end
	if PLACE_EVENTS[event] then
		S.placed = nil
		Place()
	end
	Dirty()
end

-- True when the facing the table counts may have changed (HitTableCalc.lua, C.Front, against the target of the last numbers): the threat events and
-- the target's own target come many times a second in a fight and count only then. Nothing to compare counts as a change; with no level read there
-- is no line to change.
local function FacingChanged()
	local read, calc = S.read, ns.HitTableCalc
	if type(read) ~= "table" or type(calc) ~= "table" or type(calc.Front) ~= "function" then
		return true
	elseif read.target == nil then
		return false
	end
	local ok, front, unsure = pcall(calc.Front, Opt("hitTableFacing"), read.target)
	return not ok or front ~= read.front or (unsure == true) ~= (read.facingUnsure == true)
end

-- Registers a unit event for its units alone where the client can, else for every unit (OnEvent keeps its own), as UnitDruidMana.lua hears the
-- player's power.
local function HearUnit(ear, event, ...)
	local units = {}
	for index = 1, select("#", ...) do
		units[select(index, ...)] = true
	end
	S.units[event] = units
	local ok, done = false, nil
	if type(ear.RegisterUnitEvent) == "function" then
		ok, done = pcall(ear.RegisterUnitEvent, ear, event, ...)
	end
	S.alone[event] = ok and (IsSecret(done) or done ~= false)
	if not S.alone[event] then
		pcall(ear.RegisterEvent, ear, event)
	end
end

-- The frame that hears the events while the table is wanted, and whose OnUpdate works out a burst (Tick), also for the role while the table is
-- hidden and the frame hears nothing: made the first time either is needed.
local function Ear()
	if S.ear then
		return S.ear
	end
	local ear = CreateFrame("Frame")
	ns.Own[ear] = true
	ear:SetScript("OnEvent", function(_, event, ...)
		-- The target's health comes many times a second in a fight and counts only when the target dies or comes back, so the rest stops
		-- here.
		if event == "UNIT_HEALTH" and (Ask(UnitIsDeadOrGhost, "target") == true) == S.dead then
			return
		end
		if FACING_EVENTS[event] and not FacingChanged() then
			return
		end
		Safe(OnEvent, event, ...)
	end)
	S.ear = ear
	return ear
end

-- The ear hears the events, and only while the table is wanted.
local function Hear(on)
	if S.hearing == on or not (on or S.ear) then
		return
	end
	local ear = Ear()
	pcall(ear.UnregisterAllEvents, ear)
	pcall(ear.SetScript, ear, "OnUpdate", nil)
	S.hearing, S.dirty = false, false
	if not on then
		return
	end
	for _, event in ipairs(PLAYER_EVENTS) do
		HearUnit(ear, event, "player")
	end
	HearUnit(ear, "UNIT_LEVEL", "player", "target")
	-- The player's pet comes or goes, as the secure state driver hears it for the pet frame (SecureStateDriver.lua:195): for the place alone.
	HearUnit(ear, "UNIT_PET", "player")
	for _, event in ipairs(TARGET_EVENTS) do
		HearUnit(ear, event, "target")
	end
	for _, event in ipairs(EVENTS) do
		pcall(ear.RegisterEvent, ear, event)
	end
	S.hearing = true
end

-- The part -------------------------------------------------------------------------------------------------------------------------------------------

-- Off, or stopped: the table hides and nothing is heard.
Off = function()
	Hear(false)
	S.dirty, S.read = false, nil
	if S.frame then
		for _, fade in ipairs({ S.fadeIn, S.fadeOut }) do
			pcall(fade.Stop, fade)
		end
		S.frame:Hide()
		S.visible = nil
	end
end

-- The table, the rail and the texts, made the first time the table is wanted.
local function Build()
	if S.frame then
		return
	end
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetFrameStrata("LOW")
	frame:EnableMouse(false)
	frame:SetSize(1, 1)
	frame:Hide()
	local rail = CreateFrame("Frame", nil, UIParent)
	ns.Own[rail] = true
	local outline = ns.Outline(frame, frame, true)
	local title, note, probe = Text(frame, "LEFT"), Text(frame, "RIGHT"), Text(frame, "LEFT")
	probe.fs:SetAlpha(0)
	local heads = {}
	for index = 1, #COLUMNS do
		heads[index] = Text(frame, "RIGHT")
	end
	S.frame, S.rail, S.outline, S.title, S.note, S.probe, S.heads = frame, rail, outline, title, note, probe, heads
	S.fadeIn, S.fadeOut = Fades(frame)
end

-- The cast bar's lock changed, the unit frames were refreshed, or the movers set or put back the spot: the table is placed again, out of combat.
local function Moved()
	if S.frame and Wanted() then
		S.placed = nil
		Safe(Place)
	end
end

-- Follows the two functions in which Edit Mode locks the cast bar to the player frame and frees it (Shared/PlayerFrame.lua:34-63), once.
local function Hook()
	if S.hooked then
		return
	end
	S.hooked = true
	ns.FollowGlobal("PlayerFrame_AttachCastBar", Moved)
	ns.FollowGlobal("PlayerFrame_DetachCastBar", Moved)
end

-- Shows the table as its rows say, or hides it. At For tanks and damage dealers the role is looked at again first, so a refresh also catches a role
-- that changed with no event, and an event that waits for the next frame has nothing more to look at.
Apply = function()
	if Choice() == "role" then
		WorkOutRole()
	end
	S.recheck = false
	if not Wanted() then
		Off()
		return
	end
	Build()
	Hook()
	Hear(true)
	S.fighting = InFight()
	local back = Opt("hitTableBack") ~= false
	ns.SetOutline(S.outline, back, back)
	S.frame:Show()
	Update(true)
	Place()
end

-- Hud.lua calls this in every refresh of the module: a changed row, the page, the profile, the module stopped. Once the part has stopped on errors,
-- the table hides.
function ns.HitTableRefresh()
	if not ns.PartStopped(KEY, PART) then
		Safe(Apply)
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Off)
	end
end

-- The movers: the table is its handle's box and the frame the handle hangs from, while it is wanted and laid out, also while Show hides it.
function ns.HitTableRow()
	if S.frame and S.laid and Wanted() then
		return { S.frame }, S.frame
	end
	return {}
end

function ns.HitTableMoved()
	Moved()
end

-- An event that can change the role: marked, and looked at on the next frame with the numbers, once for a burst (Tick on the ear, made now if the
-- table has not been wanted yet).
local function RoleEvent()
	S.recheck = true
	Ear()
	Dirty()
end

-- True while the row follows the role and the part runs: the role events count then, also while the table is hidden for a healer.
local function ByRole()
	return Choice() == "role" and not ns.PartStopped(KEY, PART)
end

local function RoleHeard()
	Safe(RoleEvent)
end

-- The role events come through the hud module (ns.AddEvent, Core.lua), which hears them only while its page is on; UNIT_AURA counts by a plain
-- "player" token alone, a withheld token passed over as the module's own aura pass does (Hud.lua, ForPlayer).
for _, event in ipairs(ROLE_EVENTS) do
	ns.AddEvent(KEY, event, RoleHeard, ByRole)
end
ns.AddEvent(KEY, "UNIT_AURA", RoleHeard, function(unit)
	return not IsSecret(unit) and unit == "player" and ByRole()
end)

-- A refresh of the unit frames can change what the player frame draws under the bars: the table is placed again after it (the steps after a refresh
-- are run inside the unit frames' own part guard; Moved runs its work in this part's).
local X = ns.UnitFrameExtra
if type(X) == "table" and type(X.after) == "table" and type(X.after.refresh) == "table" then
	table.insert(X.after.refresh, { part = PART, fn = Moved })
end

-- Status ---------------------------------------------------------------------------------------------------------------------------------------------

-- Names as a sentence lists them: a, a and b, a, b and c.
local function Join(list)
	if #list <= 1 then
		return list[1] or ""
	end
	return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end

ns.AddStatus(KEY, function()
	local lines = {}
	-- At For tanks and damage dealers, the role the table follows and what it was read from, also while it is hidden for a healer.
	if ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Choice() == "role" then
		local state = Shows() and "on" or "off"
		local word = ROLE_WORDS[S.role] or ROLE_WORDS.damage
		lines[#lines + 1] = S.by and LINE_ROLE_BY:format(state, word, S.by) or LINE_ROLE:format(state, word)
	end
	if not Wanted() then
		return lines
	end
	if S.later then
		lines[#lines + 1] = LINE_WAITS
	elseif S.where and LINE_WHERE[S.where] then
		lines[#lines + 1] = LINE_WHERE[S.where]
		if S.stepped then
			lines[#lines + 1] = LINE_PET
		end
	end
	if S.fit and S.room and S.roomBy then
		lines[#lines + 1] = LINE_FIT:format(math.floor(S.fit * 100 + 0.5), S.roomBy)
	end
	if S.sansRefused then
		lines[#lines + 1] = LINE_SANS
	end
	local read = S.read
	if not read then
		return lines
	end
	if not read.level then
		lines[#lines + 1] = LINE_NO_LEVEL
		return lines
	end
	local unknown = {}
	for _, line in ipairs(read.lines) do
		for _, column in ipairs(COLUMNS) do
			if line.parts[column[1]] == nil then
				unknown[#unknown + 1] = line.label
				break
			end
		end
	end
	for _, why in ipairs({ "withheld", "refused", "missing" }) do
		local names = {}
		for _, what in ipairs({ "hit", "crit", "expertise", "spell piercing" }) do
			if read.gaps[what] == why then
				names[#names + 1] = what
			end
		end
		if #names > 0 and #unknown > 0 then
			lines[#lines + 1] = LINE_GAP[why]:format(Join(names), Join(unknown))
		end
	end
	for _, hand in ipairs(read.assumed) do
		lines[#lines + 1] = LINE_ASSUMED:format(hand, read.level * PER_LEVEL)
	end
	-- What Resist counts, while the Spell line shows it.
	for _, line in ipairs(read.lines) do
		if line.id == "spell" and line.pen ~= nil then
			lines[#lines + 1] = LINE_RESIST:format(math.floor(line.pen + 0.5))
			local calc = ns.HitTableCalc
			local level = line.levelResist and type(calc) == "table" and type(calc.Resist) == "function"
				and calc.Resist(read.level, read.target.level, false, 0) or nil
			if level then
				lines[#lines + 1] = LINE_RESIST_LEVEL:format((("%.1f"):format(level):gsub("%.0$", "")))
			end
		end
	end
	local target = read.target
	if target and target.unknown then
		lines[#lines + 1] = LINE_UNKNOWN:format(target.level)
	end
	if target and target.player then
		lines[#lines + 1] = LINE_PLAYER
	end
	if read.facingUnsure then
		lines[#lines + 1] = LINE_FACING
	end
	if read.offCritFromMain then
		lines[#lines + 1] = LINE_OFF_CRIT
	end
	if read.noRanged then
		lines[#lines + 1] = LINE_NO_RANGED
	elseif read.rangedUnknown then
		lines[#lines + 1] = LINE_RANGED_UNKNOWN
	end
	if #read.lines == 0 then
		lines[#lines + 1] = LINE_EMPTY
	end
	return lines
end)

-- Test mode: the table shows whatever Show says, against a boss with no enemy targeted (Allowed, Update); On and Off lay it out again. After every
-- On, Off, pause and resume (TM.Watch), once test mode has shown or hidden its sample of the pet frame, the table is placed again, so it steps under
-- the sample or back up (Place).
if ns.TestMode then
	ns.TestMode.Register("hittable", { module = KEY, label = "Hit table", Start = ns.HitTableRefresh, Stop = ns.HitTableRefresh })
	if type(ns.TestMode.Watch) == "function" then
		ns.TestMode.Watch(function()
			Moved()
		end)
	end
end
