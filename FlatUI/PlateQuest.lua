local _, ns = ...

-- Quest mark on enemies you need for a quest, a part of Nameplates.lua (ns.PlateExtra): a small quest mark (the game's QuestNormal atlas, else its
-- AvailableQuestIcon file) beside the health bar of an enemy that is no player and that the game says belongs to a quest in the player's log
-- (C_QuestLog.UnitIsRelatedToActiveQuest, QuestLogDocumentation.lua:1287-1300, a plain bool with no withheld answer, read as SparkleGlow.lua reads
-- it), on by default (Quest mark on enemies you need for a quest, the Marks and icons tab of Nameplates), Quest mark size big and at Quest mark
-- position:
--   Left, past the threat value while it sits left of the bar (PlateThreatText.lua, ns.PlateThreatTexts: the value is anchored by its right end and
--   an empty value has no width, so the mark follows the number as it grows, in a fight too), else past the row of the enemy's buffs while the
--   game shows it (ns.PlateAuraRow: it grows left from the elite or rare icon and is 1 across while empty, so the mark moves out as buffs come and
--   go), else past the game's raid marker and its elite or rare icon: anchored to the left of the plate's ClassificationFrame, which hangs left of
--   the RaidTargetFrame, while both say they take no room while hidden (CollapsesLayout, a plain true; collapsesLayout,
--   Blizzard_NamePlates.xml:186-199), so the mark follows them in a fight too, else left of the health bars. With Raid marker off the marker frame is 1 across (Nameplates.lua's Marker), so it keeps no room either.
--   Right, past the name of the enemy's target while that text is made (it sits after the threat value on the right, PlateThreatText.lua's After),
--   else past the threat value on the right, else past the row of the enemy's crowd control icons while the game shows it (ns.PlateAuraRow), else
--   past the level frame while it shows and Level box is not Hidden (which only fades it), else past the health bar.
--   Above, over the row of the enemy's debuffs while the game shows it, else over the name (the top of the health bars while the name is inside
--   them), on the guide frame PlateOverpower.lua keeps on each plate (ns.PlateDebuffTop), so the mark rises as the row wraps, in a fight too, and
--   leaves the debuffs clear; over the threat value while it shows above the plate (it stands on that guide too); and over the Overpower icon while
--   it shows or fades on the plate (ns.PlateOverpowerIcon), dropping back once it has faded.
-- Quest mark horizontal and vertical offset move the mark and its count from there.
-- A text of PlateThreatText.lua that takes a new anchor, and the Overpower icon as it shows and once it has gone, place the mark again
-- (ns.PlateQuestPlace), so a text made after the mark still has it clear.
-- With Kill count beside the quest mark (on by default) a small gold count such as 3/8 sits beside the mark (left of it at Left, right of it at
-- Right and Above) on an enemy a kill objective of the log names: the objectives are read again with the quest log (C_QuestLog.GetNumQuestLogEntries,
-- GetQuestIDForLogIndex and GetQuestObjectives, QuestLogDocumentation.lua:1581-1592), and the unfinished "monster" objective whose text starts
-- with the enemy's name (UnitName, which is withheld only while the unit's identity is, UnitDocumentation.lua:2489-2504; the game writes
-- "Name slain: 3/8" in every language) gives its count: of several, the one with no letter right after the name and the shortest rest, so one
-- enemy's name that starts another's ("Plaguehound" and "Plaguehound Runt") takes its own objective. An enemy that only drops a quest item, or
-- whose name is withheld, shows the mark alone. The finished kill objectives are kept too: as the last kill counts, the marks of the other plates
-- of that enemy read need/need (8/8) in green and pop before they fade (the fade waits for the pop to settle), and a mark the game still shows for
-- another objective of the quest keeps its green 8/8; an unfinished objective of the same name comes first. A finished objective counts only on a
-- plate that was counting it as it was done (each objective has a key, its quest and its place in the quest, which the plate keeps while it counts
-- it, rec.objective, until it leaves): a plate that comes into view later, marked for another quest of that enemy (an item it drops), shows the
-- mark alone, not a green count that reads as done.
-- The count is a font string of the mark's frame, outlined, in Text font, at 0.8 of Quest mark size. As a kill counts, the count on every other
-- plate of that enemy pops (grows to 1.6 of its size and settles back over 0.3 seconds, white until it ends, then gold, green once the objective is
-- done, or grey on a tapped enemy).
-- On an enemy someone else has tapped (UnitIsTapDenied and not UnitPlayerControlled, as PlateThreat.lua and the game's CompactUnitFrame read it)
-- the mark and its count are grey and faint, and bright again once the tap drops (UNIT_FACTION, which the game's plate also hears for it).
-- A mark fades in over FADE_IN seconds and out over FADE_OUT as its objective is done (after the pop of its finished count); a plate that leaves or
-- is handed out again clears at once.
-- No mark shows on a plate in name-only or widgets-only mode, nor on a unit the player cannot attack (UnitCanAttack). The game is asked again as a
-- plate shows and, merged onto the next frame, on QUEST_LOG_UPDATE and the player's UNIT_QUEST_LOG_CHANGED, over every plate (ns.EachPlate): a mark
-- goes once that objective is done. With Leave quest marks to Questie (on by default) the part stands down while Questie is loaded and draws its own
-- icons on quest enemies (C_AddOns.IsAddOnLoaded, asked again as Questie loads after Flat UI, as QuestieSkin.lua hears it). Questie draws none while
-- its own nameplate icons are off, nor inside an instance on this game (QuestieDraws), so the marks then show: asked again as you zone in and out
-- (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA) and as a plate shows, which catches a change of Questie's option. ns.PlateQuestYields tells setup's
-- drawing and test mode's sample whether the marks are left to Questie now.
-- Combat: the mark is a frame of Flat UI's own, a child of the plate's unit frame so it moves, fades and hides with the plate, made, sized and
-- anchored only out of combat on a plate the game may protect (ns.MaybeProtected, Movers.lua), as the Overpower icon is: it is made on each plate
-- that is no player's as the plate shows while the row is on, and kept when the plate goes, so a plate the game hands out again in a fight has it.
-- In a fight only its alpha, its fade (an animation of its own frame, as PlateOverpower.lua plays its pulse), its grey and the count's text, colour
-- and pop change. A plate first seen in a fight gets its mark when the fight ends; /flatui status counts those and the marks shown. Nothing of the
-- game is written: every call on the game only reads.

local KEY = "nameplates"
local PART = "Quest mark"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

-- SIZE: the mark when the row gives no size. GAP: nameplate units between the mark and what it stands beside, ROW_GAP beside a row of the game's
-- aura icons (which keeps 5 of its own from what it hangs on). LEVEL: frame levels above the plate's unit frame, under the Overpower icon's. ATLAS
-- and FILE: the mark's art, the atlas first. EVENTS: what makes the plates be asked again (UNIT_FACTION only for the plate of its unit). COUNT: the
-- count's size, a share of the mark's; COUNT_GAP: units between the two; GOLD and GREY: its colours, GREEN its colour once the objective is done,
-- WHITE its colour as it pops, and POP and POP_SECONDS the pop of a count that goes up (from POP of its size back to whole). TAPPED: the opacity
-- of a tapped enemy's mark. FADE_IN and FADE_OUT: the seconds a mark fades in and out. ENTRIES: the most quest log lines read. ADDON: the folder
-- of Questie.
local K = {
	SIZE = 14, GAP = 2, ROW_GAP = 1, LEVEL = 15,
	ATLAS = "QuestNormal", FILE = "Interface\\GossipFrame\\AvailableQuestIcon",
	EVENTS = { "QUEST_LOG_UPDATE", "UNIT_FACTION" },
	COUNT = 0.8, COUNT_GAP = 1, GOLD = { 1, 0.82, 0 }, GREY = { 0.6, 0.6, 0.6 }, GREEN = { 0.3, 0.9, 0.35 }, WHITE = { 1, 1, 1 }, POP = 1.6,
	POP_SECONDS = 0.3, TAPPED = 0.4,
	FADE_IN = 0.15, FADE_OUT = 0.3, ENTRIES = 100, ADDON = "Questie",
}

-- recs[unitFrame]: holder (the mark's frame), icon (its texture), count (its kill count), countBase (the font object's file), countFont and
-- countText (what the count was given), countPop (the count's pop, nil on a client without it) and popping (it plays), fade and fadeAnim (the
-- fade's animation group and its Alpha animation, nil on a client without them) and fadeTo (the alpha it ends at),
-- to, point, relative, size, side, ox and oy (what it was anchored to, by which points, its size, the count's side and the two offsets), tapped
-- (the grey look is on), complete (the count reads a finished objective, green), shown, waiting (for the end of a fight). Kept when the plate
-- leaves, so a plate's mark is made once.
local recs = setmetatable({}, { __mode = "k" })
-- owns[unitFrame]: what Nameplates.lua keeps of the plate (its show and layout hooks pass it), for Level box Hidden (own.levelFade).
local owns = setmetatable({}, { __mode = "k" })
-- S: frame (the file's own, false when it could not be made), on (the events are heard), queued (a look at every plate waits for the next frame),
-- atlas (the atlas exists, nil before it is asked), counts (the unfinished kill objectives of the log, { text, have, need }) and done (the finished
-- ones, { text, have = need, need, done = true }), both nil while Kill count beside the quest mark is off, and the count of plates that waited for
-- the end of a fight, for /flatui status.
local S = { frame = nil, on = false, queued = false, atlas = nil, counts = nil, done = nil, waited = 0 }
local Draw

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

-- True when the client has the mark's atlas (as Nameplates.lua's AtlasExists asks), asked once.
local function HasAtlas()
	if S.atlas == nil then
		S.atlas = false
		local api = C_Texture
		if Plain(api, "table") then
			if type(api.GetAtlasExists) == "function" then
				S.atlas = Ask(api.GetAtlasExists, K.ATLAS) == true
			elseif type(api.GetAtlasInfo) == "function" then
				S.atlas = Ask(api.GetAtlasInfo, K.ATLAS) ~= nil
			end
		end
	end
	return S.atlas
end

-- True while Questie is loaded (or loading).
local function QuestieLoaded()
	local addons = C_AddOns
	if Plain(addons, "table") and type(addons.IsAddOnLoaded) == "function" then
		return Ask(addons.IsAddOnLoaded, K.ADDON) == true
	end
	return Ask(rawget(_G, "IsAddOnLoaded"), K.ADDON) == true
end

-- The row and the page want marks.
local function Asked()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and Opt("questMark") == true
end

-- False while Questie says it draws no icons on nameplates now (facts read from Questie's QuestieNameplate, whose NameplateCreated draws nothing):
-- its own nameplate icons are off (Questie.db.profile.nameplateEnabled a plain false), or on this game inside an instance (Questie.IsForever and
-- IsInInstance both a plain true). Each step is read in a pcall with its type checked; anything that cannot be read counts as drawing.
local function QuestieDraws()
	local ok, draws = pcall(function()
		local questie = rawget(_G, K.ADDON)
		if not Plain(questie, "table") then
			return true
		end
		local db = questie.db
		local profile = Plain(db, "table") and db.profile or nil
		local enabled = Plain(profile, "table") and profile.nameplateEnabled or nil
		if Plain(enabled, "boolean") and enabled == false then
			return false
		end
		local forever = questie.IsForever
		return not (Plain(forever, "boolean") and forever and Ask(IsInInstance) == true)
	end)
	return not ok or draws ~= false
end

-- True while Leave quest marks to Questie has the part stand down: Questie is loaded and draws its own icons on quest enemies here.
local function Yielding()
	return Opt("questMarkQuestie") == true and QuestieLoaded() and QuestieDraws()
end

local function Wanted()
	return Asked() and not Yielding()
end

-- The mark's frame ------------------------------------------------------------------------------------------------------------------------------

-- SetPoint and ClearAllPoints are protected (SimpleScriptRegionResizingAPIDocumentation.lua:22-30, 135-139): on a plate that may be protected nothing
-- is made, sized or anchored in a fight. Movers.lua has ns.MaybeProtected; before it loads every frame counts as protected.
local function Locked(unitFrame)
	return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(unitFrame))
end

local function Region(owner, key)
	if owner == nil or ns.Forbidden(owner) then
		return nil
	end
	local region = owner[key]
	if ns.IsSecret(region) or type(region) ~= "table" or ns.Forbidden(region) then
		return nil
	end
	return region
end

-- True when the game puts the name inside the health bar (as Nameplates.lua's NameInside reads it).
local function NameInside()
	local options, constants = NamePlateSetupOptions, NamePlateConstants
	local styles = Plain(constants, "table") and constants.NAME_ANCHOR_STYLES
	local style = Plain(options, "table") and options.unitNameAnchorStyle
	return Plain(styles, "table") and Plain(style, "number") and style == styles.InsideHealthBar
end

-- True for a frame that says it takes no room while hidden (CollapsesLayout, SimpleScriptRegionAPIDocumentation.lua:60-70).
local function Collapses(frame)
	return frame ~= nil and Ask(frame.CollapsesLayout, frame) == true
end

-- The row of the game's aura icons on a side of a plate (left the enemy's buffs, right its crowd control), from PlateThreatText.lua, or nil.
local function AuraRow(unitFrame, side)
	if type(ns.PlateAuraRow) ~= "function" then
		return nil
	end
	local ok, row = pcall(ns.PlateAuraRow, unitFrame, side)
	return ok and type(row) == "table" and row or nil
end

-- The threat value, the side it sits on and the enemy's target of a plate, from PlateThreatText.lua, or nothing.
local function Texts(unitFrame)
	if type(ns.PlateThreatTexts) ~= "function" then
		return nil
	end
	local ok, value, side, target = pcall(ns.PlateThreatTexts, unitFrame)
	if not ok then
		return nil
	end
	return value, side, target
end

-- The guide of PlateOverpower.lua over a plate (ns.PlateDebuffTop): its top is the top of the enemy's debuffs while their row shows, else of the name.
-- Also true while its anchors wait for the end of a fight.
local function DebuffTop(unitFrame)
	if type(ns.PlateDebuffTop) ~= "function" then
		return nil, false
	end
	local ok, guide, stale = pcall(ns.PlateDebuffTop, unitFrame)
	if not ok or type(guide) ~= "table" then
		return nil, ok and stale == true
	end
	return guide, stale == true
end

-- The Overpower icon of a plate while it shows or fades (PlateOverpower.lua, ns.PlateOverpowerIcon), or nil.
local function OverpowerIcon(unitFrame)
	if type(ns.PlateOverpowerIcon) ~= "function" then
		return nil
	end
	local ok, icon = pcall(ns.PlateOverpowerIcon, unitFrame)
	return ok and type(icon) == "table" and icon or nil
end

-- What the mark stands beside, the point of the mark and the point of that region, and the offsets, for a position; for Above also true while the
-- guide it stands on waits for the end of a fight. Above stands over the Overpower icon while it shows, else over the threat value while it shows
-- above the plate (it stands on the guide too), else on the guide.
local function Target(unitFrame, place)
	local bars = Region(unitFrame, "HealthBarsContainer")
	local value, side, target = Texts(unitFrame)
	if place == "above" then
		local guide, stale = DebuffTop(unitFrame)
		local over = OverpowerIcon(unitFrame) or (side == "above" and Ask(value.IsShown, value) == true and value) or guide
		if over then
			return over, "BOTTOM", "TOP", 0, K.GAP, stale
		end
		local name = Region(unitFrame, "name")
		return (NameInside() and bars or name) or bars, "BOTTOM", "TOP", 0, K.GAP, stale
	end
	if place == "right" then
		local after = target or (side == "right" and value) or nil
		if after then
			return after, "LEFT", "RIGHT", K.GAP, 0
		end
		local cc = AuraRow(unitFrame, "right")
		if cc then
			return cc, "LEFT", "RIGHT", K.ROW_GAP, 0
		end
		local own = owns[unitFrame]
		local level = Region(unitFrame, "PlayerLevelDiffFrame")
		local shown = level and not (type(own) == "table" and own.levelFade) and Ask(level.IsShown, level) == true
		return shown and level or bars, "LEFT", "RIGHT", K.GAP, 0
	end
	if value and side == "left" then
		return value, "RIGHT", "LEFT", -K.GAP, 0
	end
	local buffs = AuraRow(unitFrame, "left")
	if buffs then
		return buffs, "RIGHT", "LEFT", -K.ROW_GAP, 0
	end
	local class, marker = Region(unitFrame, "ClassificationFrame"), Region(unitFrame, "RaidTargetFrame")
	if Collapses(class) and Collapses(marker) then
		return class, "RIGHT", "LEFT", -K.GAP, 0
	end
	return bars, "RIGHT", "LEFT", -K.GAP, 0
end

local function Wait(unitFrame)
	local rec = recs[unitFrame]
	if rec == nil then
		rec = {}
		recs[unitFrame] = rec
	end
	if rec.waiting then
		return
	end
	rec.waiting = true
	S.waited = S.waited + 1
	ns.OutOfCombat(function()
		rec.waiting = nil
		if S.on and recs[unitFrame] == rec and not ns.Forbidden(unitFrame) then
			ns.EachPart(KEY, PART, Draw, unitFrame)
		end
	end)
end

-- The count's colour: white while its pop plays, else green once it reads a finished objective, else grey on an enemy someone else has tapped,
-- else gold.
local function CountColour(rec)
	local count = rec.count
	if count then
		local colour = rec.popping and K.WHITE or (rec.complete and K.GREEN or (rec.tapped and K.GREY or K.GOLD))
		count:SetTextColor(colour[1], colour[2], colour[3], 1)
	end
end

-- The count's pop as a kill counts: a Scale animation of the count from POP of its size back to whole, from its middle (a font string scales by its
-- vertices, as CombatCues.lua pops its lines), white while it plays. Not protected, so it plays in a fight. Nil when the client will not make it.
local function MakeCountPop(rec)
	local count = rec.count
	local ok, group = pcall(function()
		local modes = Enum and Enum.FontStringScaleAnimationMode
		pcall(count.SetScaleAnimationMode, count, modes and modes.Vertex or 1)
		local made = count:CreateAnimationGroup()
		ns.Own[made] = true
		local grow = made:CreateAnimation("Scale")
		ns.Own[grow] = true
		grow:SetScaleFrom(K.POP, K.POP)
		grow:SetScaleTo(1, 1)
		grow:SetDuration(K.POP_SECONDS)
		grow:SetOrigin("CENTER", 0, 0)
		pcall(grow.SetSmoothing, grow, "OUT")
		local function Done()
			rec.popping = nil
			CountColour(rec)
		end
		made:SetScript("OnFinished", Done)
		made:SetScript("OnStop", Done)
		return made
	end)
	rec.countPop = ok and type(group) == "table" and group or nil
end

-- The count pops: white, grown, and back to its colour as it settles.
local function PopCount(rec)
	local group = rec.countPop
	if not group then
		return
	end
	pcall(group.Stop, group)
	rec.popping = true
	CountColour(rec)
	if not pcall(group.Play, group) then
		rec.popping = nil
		CountColour(rec)
	end
end

-- The mark of a plate, made the first time the plate needs one; nil while it waits for the end of a fight.
local function Make(unitFrame)
	local rec = recs[unitFrame]
	if rec and rec.holder then
		return rec
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return nil
	end
	rec = rec or {}
	recs[unitFrame] = rec
	local holder = CreateFrame("Frame", nil, unitFrame)
	ns.Own[holder] = true
	holder:SetSize(K.SIZE, K.SIZE)
	holder:SetAlpha(0)
	local icon = holder:CreateTexture(nil, "OVERLAY")
	ns.Own[icon] = true
	icon:SetAllPoints(holder)
	if not (HasAtlas() and pcall(icon.SetAtlas, icon, K.ATLAS)) then
		icon:SetTexture(K.FILE)
	end
	rec.holder, rec.icon = holder, icon
	-- The kill count, in the font object's file until Text font names another.
	local count = ns.OwnText(holder, "OVERLAY", "SystemFont_NamePlate")
	if count then
		local ok, file = pcall(count.GetFont, count)
		rec.countBase = ok and Plain(file, "string") and file or nil
		count:SetTextColor(K.GOLD[1], K.GOLD[2], K.GOLD[3], 1)
		count:SetText("")
		rec.count, rec.countText = count, ""
		MakeCountPop(rec)
	end
	-- The fade: one Alpha animation of the mark's own frame, which ends at the alpha it was played for.
	local made, group = pcall(holder.CreateAnimationGroup, holder)
	local anim
	if made and type(group) == "table" then
		ns.Own[group] = true
		local ok, alpha = pcall(group.CreateAnimation, group, "Alpha")
		anim = ok and type(alpha) == "table" and alpha or nil
	end
	if anim then
		ns.Own[anim] = true
		pcall(group.SetToFinalAlpha, group, true)
		group:SetScript("OnFinished", function()
			holder:SetAlpha(rec.fadeTo or 0)
		end)
		rec.fade, rec.fadeAnim = group, anim
	end
	return rec
end

-- The count's font: Text font (the font object's file at the game's choice) at COUNT of the mark's size, outlined. Not protected, so also in a fight.
local function CountFont(rec)
	local count = rec.count
	if not count then
		return
	end
	local face = Opt("textFace")
	local file = face ~= "default" and type(ns.FontFile) == "function" and ns.FontFile(face) or nil
	if not Plain(file, "string") then
		file = rec.countBase
	end
	if not Plain(file, "string") then
		return
	end
	local px = math.max(6, (rec.size or K.SIZE) * K.COUNT)
	local key = file .. "|" .. px
	if rec.countFont ~= key and pcall(count.SetFont, count, file, px, "OUTLINE") then
		rec.countFont = key
	end
end

-- Sizes and anchors the mark when its size, its position, its offsets or what it stands beside changed, out of combat on a plate that may be
-- protected. Quest mark horizontal and vertical offset move it, and the count with it. The count goes on the far side of the mark from the bar:
-- left of it at Left, right of it at Right and Above.
local function Place(unitFrame, rec)
	local size = Opt("questMarkSize")
	size = type(size) == "number" and size > 0 and size or K.SIZE
	local place = Opt("questMarkPlace")
	local ox, oy = Opt("questMarkX"), Opt("questMarkY")
	ox, oy = ns.Finite(ox) and ox or 0, ns.Finite(oy) and oy or 0
	local to, point, relative, x, y, stale = Target(unitFrame, place)
	local side = place == "left" and "left" or "right"
	if stale then
		Wait(unitFrame)
	end
	local moved = rec.to ~= to or rec.point ~= point or rec.relative ~= relative or rec.ox ~= ox or rec.oy ~= oy
	if to == nil or not (moved or rec.size ~= size or rec.side ~= side) then
		return
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return
	end
	local holder = rec.holder
	holder:SetSize(size, size)
	if moved then
		holder:ClearAllPoints()
		holder:SetPoint(point, to, relative, x + ox, y + oy)
	end
	local count = rec.count
	if count and rec.side ~= side then
		count:ClearAllPoints()
		if side == "left" then
			count:SetPoint("RIGHT", holder, "LEFT", -K.COUNT_GAP, 0)
		else
			count:SetPoint("LEFT", holder, "RIGHT", K.COUNT_GAP, 0)
		end
	end
	local level = Ask(unitFrame.GetFrameLevel, unitFrame)
	if type(level) == "number" then
		pcall(holder.SetFrameLevel, holder, level + K.LEVEL)
	end
	rec.to, rec.point, rec.relative, rec.size, rec.side, rec.ox, rec.oy = to, point, relative, size, side, ox, oy
end

-- True for a plate whose unit is an enemy that is no player, outside name-only and widgets-only mode, that the game says a quest of the log needs.
local function Needed(unitFrame)
	local unit = unitFrame.unit
	if not Plain(unit, "string") then
		return false
	end
	local only, widgets = unitFrame.showOnlyName, unitFrame.widgetsOnlyMode
	if (Plain(only, "boolean") and only) or (Plain(widgets, "boolean") and widgets) then
		return false
	end
	if Ask(UnitIsPlayer, unit) == true or Ask(UnitCanAttack, "player", unit) ~= true then
		return false
	end
	local quests = C_QuestLog
	return Plain(quests, "table") and Ask(quests.UnitIsRelatedToActiveQuest, unit) == true
end

-- The mark faded in or out over FADE_IN or FADE_OUT seconds, or set at once (now, or a client without the animation). late: a fade out waits
-- POP_SECONDS first, so a finished count's pop settles before the mark goes; every other fade starts at once. A fade still running stops first;
-- the animation ends at the alpha it was played for, and OnFinished sets that alpha too.
local function Fade(rec, show, now, late)
	local holder, group, anim = rec.holder, rec.fade, rec.fadeAnim
	local alpha = show and 1 or 0
	rec.fadeTo = alpha
	if group then
		pcall(group.Stop, group)
	end
	if now or not (group and anim) then
		holder:SetAlpha(alpha)
		return
	end
	pcall(anim.SetFromAlpha, anim, 1 - alpha)
	pcall(anim.SetToAlpha, anim, alpha)
	pcall(anim.SetDuration, anim, show and K.FADE_IN or K.FADE_OUT)
	pcall(anim.SetStartDelay, anim, (late and not show) and K.POP_SECONDS or 0)
	holder:SetAlpha(1 - alpha)
	if not pcall(group.Play, group) then
		holder:SetAlpha(alpha)
	end
end

-- now: at once, for a plate that leaves or a part that stands down, which also cuts short a fade out still running, and forgets a finished count.
-- late: the fade waits for the pop of a finished count (Fade).
local function Hide(rec, now, late)
	if not rec.holder then
		return
	end
	if now then
		rec.objective = nil
	end
	if now and rec.complete then
		rec.complete = nil
		CountColour(rec)
	end
	if rec.shown then
		rec.shown = nil
		Fade(rec, false, now, late)
	elseif now then
		Fade(rec, false, true)
	end
end

-- Grey and faint on an enemy someone else has tapped, set only when that changes. Texture and text calls on frames of Flat UI's own, so also in a
-- fight.
local function Tapped(rec, unit)
	local tapped = Ask(UnitIsTapDenied, unit) == true and Ask(UnitPlayerControlled, unit) ~= true
	if tapped == (rec.tapped == true) then
		return
	end
	rec.tapped = tapped
	pcall(rec.icon.SetDesaturated, rec.icon, tapped)
	rec.icon:SetAlpha(tapped and K.TAPPED or 1)
	local count = rec.count
	if count then
		CountColour(rec)
		count:SetAlpha(tapped and K.TAPPED or 1)
	end
end

-- The kill objective that names this enemy, unfinished (S.counts) or finished (S.done), of those whose text starts with its name: one where no
-- letter follows the name first (a space or a colon: "Plaguehound slain" for a Plaguehound, not "Plaguehounds"), then the one whose rest, without
-- its count and punctuation, is the shortest (" slain" before " Runt slain", so a Plaguehound is not counted on the Plaguehound Runts' objective),
-- the first in the log on a tie, an unfinished one before a finished one. A finished one is taken only when it is `keep` (the key of the objective
-- the plate was counting, rec.objective), so a plate that comes into view for another quest of the same enemy shows no finished count. Nil while
-- Kill count is off or the enemy's name is withheld.
local function Objective(unit, keep)
	local counts, done = S.counts, S.done
	if Opt("questMarkCount") ~= true or not ((counts and #counts > 0) or (done and #done > 0)) then
		return nil
	end
	local name = Ask(UnitName, unit)
	if not (Plain(name, "string") and name ~= "") then
		return nil
	end
	local best, bestLetter, bestLength
	for _, list in ipairs({ counts or {}, (keep ~= nil and done) or {} }) do
		for _, entry in ipairs(list) do
			local words = entry.text
			if (not entry.done or entry.key == keep) and words:find(name, 1, true) == 1 then
				local rest = words:sub(#name + 1)
				local letter = rest:find("^%a") ~= nil
				local length = #(rest:gsub("[%s%d/:]+$", ""))
				if best == nil or (bestLetter and not letter) or (letter == bestLetter and length < bestLength) then
					best, bestLetter, bestLength = entry, letter, length
				end
			end
		end
	end
	return best
end

-- The kill count of the objective given (Objective), or nothing: have/need while it is unfinished, need/need in green once it is done. The plate
-- keeps the key of the unfinished objective it counts (rec.objective), which lets it keep that objective's green count as it is done.
local function Count(rec, entry)
	local count = rec.count
	if not count then
		return
	end
	if entry == nil then
		rec.objective = nil
	elseif not entry.done then
		rec.objective = entry.key
	end
	local text = entry and ("%d/%d"):format(entry.have, entry.need) or ""
	local complete = entry and entry.done or nil
	if rec.complete ~= complete then
		rec.complete = complete
		CountColour(rec)
	end
	if rec.countText ~= text then
		-- A count that changes on a mark that shows is a kill that counted: it pops. Not as it first comes, nor as it goes.
		local before = rec.countText
		rec.countText = text
		count:SetText(text)
		if rec.shown and before ~= nil and before ~= "" and text ~= "" then
			PopCount(rec)
		end
	end
end

-- One plate: its mark made and placed out of combat on every plate that is no player's, so a later enemy on it has one in a fight, and shown while
-- the game says a quest needs the enemy. A mark that goes as its kill objective is done first reads need/need in green and pops, and fades once the
-- pop settles.
function Draw(unitFrame)
	if not S.on or ns.Forbidden(unitFrame) then
		return
	end
	local unit = unitFrame.unit
	local rec = recs[unitFrame]
	if not (rec and rec.holder) and Plain(unit, "string") and Ask(UnitIsPlayer, unit) ~= true then
		rec = Make(unitFrame)
	end
	if not (rec and rec.holder) then
		return
	end
	Place(unitFrame, rec)
	local want = rec.to ~= nil and Needed(unitFrame)
	if want then
		CountFont(rec)
		Tapped(rec, unit)
		Count(rec, Objective(unit, rec.objective))
		if not rec.shown then
			rec.shown = true
			Fade(rec, true)
		end
	else
		local entry = rec.shown and rec.count and Objective(unit, rec.objective) or nil
		if entry and entry.done then
			Count(rec, entry)
			Hide(rec, false, true)
		else
			Hide(rec)
		end
	end
end

-- The kill objectives of the quest log, unfinished and finished, read again while Kill count beside the quest mark is on. A header line has no
-- quest (0 or nil).
local function Objectives()
	local quests = C_QuestLog
	if Opt("questMarkCount") ~= true or not Plain(quests, "table") then
		S.counts, S.done = nil, nil
		return
	end
	local list, done = {}, {}
	local entries = Ask(quests.GetNumQuestLogEntries)
	entries = ns.Finite(entries) and math.min(entries, K.ENTRIES) or 0
	for index = 1, entries do
		local id = Ask(quests.GetQuestIDForLogIndex, index)
		local objectives = ns.Finite(id) and id > 0 and Ask(quests.GetQuestObjectives, id) or nil
		if Plain(objectives, "table") then
			for n, objective in ipairs(objectives) do
				-- The key of the objective: its quest and its place in the quest, since its text carries the count.
				local key = id .. ":" .. n
				local kill = Plain(objective, "table") and Plain(objective.type, "string") and objective.type == "monster"
					and Plain(objective.text, "string") and ns.Finite(objective.numRequired) and objective.numRequired > 0
				local finished = kill and Plain(objective.finished, "boolean") and objective.finished
				if finished then
					local need = math.floor(objective.numRequired)
					done[#done + 1] = { key = key, text = objective.text, have = need, need = need, done = true }
				elseif kill and ns.Finite(objective.numFulfilled) then
					list[#list + 1] = { key = key, text = objective.text, have = math.floor(objective.numFulfilled),
						need = math.floor(objective.numRequired) }
				end
			end
		end
	end
	S.counts, S.done = list, done
end

-- Every plate asked again: the quest log changed.
local function LookAll()
	S.queued = false
	if S.on then
		pcall(Objectives)
	end
	if S.on and type(ns.EachPlate) == "function" then
		ns.EachPlate(function(unitFrame)
			ns.EachPart(KEY, PART, Draw, unitFrame)
		end)
	end
end

-- The looks of one frame's quest log events are merged onto the next frame.
local function Queue()
	if S.queued then
		return
	end
	S.queued = true
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, LookAll) then
		return
	end
	LookAll()
end

-- Everything hidden at once: the row, the page or the part went off, or the part left the marks to Questie.
local function StandDown()
	for _, rec in pairs(recs) do
		pcall(Hide, rec, true)
	end
end

-- UNIT_FACTION comes as a tap starts or drops: only the plate of a nameplate unit is drawn again, at once.
local function Faction(unit)
	if not (Plain(unit, "string") and unit:find("^nameplate%d") and type(ns.PlateUnitFrame) == "function") then
		return
	end
	local unitFrame = ns.PlateUnitFrame(unit)
	local rec = unitFrame and recs[unitFrame]
	if rec and rec.holder then
		ns.EachPart(KEY, PART, Draw, unitFrame)
	end
end

local function OnEvent(_, event, unit)
	if event == "UNIT_FACTION" then
		Faction(unit)
		return
	end
	if event == "UNIT_QUEST_LOG_CHANGED" and not (Plain(unit, "string") and unit == "player") then
		return
	end
	Queue()
end

local function Frame()
	if S.frame == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			S.frame = false
			return nil
		end
		ns.Own[frame] = true
		frame:SetScript("OnEvent", OnEvent)
		S.frame = frame
	end
	return S.frame or nil
end

local function Hear(on)
	local frame = Frame()
	if not frame then
		return
	end
	for _, event in ipairs(K.EVENTS) do
		pcall(on and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
	end
	if not on then
		pcall(frame.UnregisterEvent, frame, "UNIT_QUEST_LOG_CHANGED")
	elseif not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, "UNIT_QUEST_LOG_CHANGED", "player")) then
		pcall(frame.RegisterEvent, frame, "UNIT_QUEST_LOG_CHANGED")
	end
end

-- Starts or stops the part as the row, the page and the part say, and places and asks every plate again.
local function Sync()
	local want = Wanted() and Frame() ~= nil
	if want ~= S.on then
		S.on = want
		Hear(want)
		if not want then
			StandDown()
		end
	end
	if want then
		LookAll()
	end
end

-- A text of PlateThreatText.lua took a new anchor: the plate's mark is placed again past it (out of combat on a plate that may be protected).
function ns.PlateQuestPlace(unitFrame)
	local rec = unitFrame ~= nil and recs[unitFrame]
	if S.on and rec and rec.holder then
		ns.EachPart(KEY, PART, Draw, unitFrame)
	end
end

-- Hooks into the plates ------------------------------------------------------------------------------------------------------------------------

EXTRA.show[#EXTRA.show + 1] = function(unitFrame, own)
	owns[unitFrame] = own
	-- A change of Questie's own nameplate option is seen at the next plate that shows.
	if Wanted() ~= S.on then
		ns.EachPart(KEY, PART, Sync)
	end
	if S.on then
		ns.EachPart(KEY, PART, Draw, unitFrame)
	end
end
EXTRA.layout[#EXTRA.layout + 1] = function(unitFrame, own)
	owns[unitFrame] = own
	local rec = recs[unitFrame]
	if S.on and rec and rec.holder then
		ns.EachPart(KEY, PART, Draw, unitFrame)
	end
end
EXTRA.leave[#EXTRA.leave + 1] = function(unitFrame)
	local rec = recs[unitFrame]
	if rec then
		Hide(rec, true)
	end
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	local ok = ns.EachPart(KEY, PART, Sync)
	if not ok and (ns.PartStopped(KEY, PART) or not ns.Enabled(KEY)) then
		S.on = false
		pcall(Hear, false)
		pcall(StandDown)
	end
end
-- Questie loads after Flat UI: the part looks again whether to leave the marks to it.
ns.AddEvent(KEY, "ADDON_LOADED", function()
	ns.EachPart(KEY, PART, Sync)
end, function(name)
	return not ns.IsSecret(name) and name == K.ADDON
end)
-- Questie draws no nameplate icons inside an instance on this game: as you zone in and out the part starts or stands down.
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
	ns.AddEvent(KEY, event, function()
		ns.EachPart(KEY, PART, Sync)
	end)
end
-- True while the marks are left to Questie (Leave quest marks to Questie on, Questie loaded and drawing its own icons here), for setup's drawing and
-- test mode's sample plate (SetupDrawPlates.lua's P.Look), which then show no mark either.
function ns.PlateQuestYields()
	return Yielding()
end
EXTRA.status[#EXTRA.status + 1] = function()
	if not S.on then
		if Asked() and Yielding() then
			return "Quest marks on nameplates: left to Questie."
		end
		return nil
	end
	local shown = 0
	for _, rec in pairs(recs) do
		if rec.shown then
			shown = shown + 1
		end
	end
	local line = ("Quest marks on nameplates: %d shown, %d plates waited for the end of a fight for their mark."):format(shown, S.waited)
	if Opt("questMarkQuestie") == true and QuestieLoaded() then
		line = line .. " Questie draws no nameplate icons here, so Flat UI's quest marks show."
	end
	return line
end
