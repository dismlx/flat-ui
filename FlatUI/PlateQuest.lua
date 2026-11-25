local _, ns = ...

-- Quest mark on enemies you need for a quest, a part of Nameplates.lua (ns.PlateExtra): a small quest mark (the game's QuestNormal atlas, else its
-- AvailableQuestIcon file) beside the health bar of an enemy that is no player and that the game says belongs to a quest in the player's log
-- (C_QuestLog.UnitIsRelatedToActiveQuest, QuestLogDocumentation.lua:1287-1300, a plain bool with no withheld answer, read as SparkleGlow.lua reads
-- it), on by default (Quest mark on enemies you need for a quest, the Marks and icons tab of Nameplates), Quest mark size big and at Quest mark
-- position:
--   Left, past the threat value while it sits left of the bar (PlateThreatText.lua, ns.PlateThreatTexts: the value is anchored by its right end and
--   an empty value has no width, so the mark follows the number as it grows, in a fight too), else past the game's raid marker and its elite or
--   rare icon: anchored to the left of the plate's ClassificationFrame, which hangs left of the RaidTargetFrame, while both say they take no room
--   while hidden (CollapsesLayout, a plain true; collapsesLayout, Blizzard_NamePlates.xml:186-199), so the mark follows them in a fight too, else
--   left of the health bars. With Raid marker off the marker frame is 1 across (Nameplates.lua's Marker), so it keeps no room either.
--   Right, past the name of the enemy's target while that text is made (it sits after the threat value on the right, PlateThreatText.lua's After),
--   else past the threat value on the right, else past the level frame while it shows and Level box is not Hidden (which only fades it), else past
--   the health bar.
--   Above, over the name (the top of the health bars while the name is inside them), where the plate's debuffs and the Overpower icon
--   (PlateOverpower.lua, a level above) also sit.
-- A text of PlateThreatText.lua that takes a new anchor places the mark again (ns.PlateQuestPlace), so a text made after the mark still has it clear.
-- With Kill count beside the quest mark (on by default) a small gold count such as 3/8 sits beside the mark (left of it at Left, right of it at
-- Right and Above) on an enemy a kill objective of the log names: the objectives are read again with the quest log (C_QuestLog.GetNumQuestLogEntries,
-- GetQuestIDForLogIndex and GetQuestObjectives, QuestLogDocumentation.lua:1581-1592), and the first unfinished "monster" objective whose text
-- starts with the enemy's name (UnitName, which is withheld only while the unit's identity is, UnitDocumentation.lua:2489-2504; the game writes
-- "Name slain: 3/8" in every language) gives its count. An enemy that only drops a quest item, or whose name is withheld, shows the mark alone.
-- The count is a font string of the mark's frame, outlined, in Text font, at 0.8 of Quest mark size.
-- On an enemy someone else has tapped (UnitIsTapDenied and not UnitPlayerControlled, as PlateThreat.lua and the game's CompactUnitFrame read it)
-- the mark and its count are grey and faint, and bright again once the tap drops (UNIT_FACTION, which the game's plate also hears for it).
-- A mark fades in over FADE_IN seconds and out over FADE_OUT as its objective is done; a plate that leaves or is handed out again clears at once.
-- No mark shows on a plate in name-only or widgets-only mode, nor on a unit the player cannot attack (UnitCanAttack). The game is asked again as a
-- plate shows and, merged onto the next frame, on QUEST_LOG_UPDATE and the player's UNIT_QUEST_LOG_CHANGED, over every plate (ns.EachPlate): a mark
-- goes once that objective is done. With Leave quest marks to Questie (on by default) the part stands down while Questie is loaded, since Questie
-- draws its own icons on quest enemies (C_AddOns.IsAddOnLoaded, asked again as Questie loads after Flat UI, as QuestieSkin.lua hears it).
-- Combat: the mark is a frame of Flat UI's own, a child of the plate's unit frame so it moves, fades and hides with the plate, made, sized and
-- anchored only out of combat on a plate the game may protect (ns.MaybeProtected, Movers.lua), as the Overpower icon is: it is made on each plate
-- that is no player's as the plate shows while the row is on, and kept when the plate goes, so a plate the game hands out again in a fight has it.
-- In a fight only its alpha, its fade (an animation of its own frame, as PlateOverpower.lua plays its pulse), its grey and the count's text
-- change. A plate first seen in a fight gets its mark when the fight ends; /flatui status counts those and the marks shown. Nothing of the game is
-- written: every call on the game only reads.

local KEY = "nameplates"
local PART = "Quest mark"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

-- SIZE: the mark when the row gives no size. GAP: nameplate units between the mark and what it stands beside. LEVEL: frame levels above the
-- plate's unit frame, under the Overpower icon's. ATLAS and FILE: the mark's art, the atlas first. EVENTS: what makes the plates be asked again
-- (UNIT_FACTION only for the plate of its unit). COUNT: the count's size, a share of the mark's; COUNT_GAP: units between the two; GOLD and GREY: its
-- colours. TAPPED: the opacity of a tapped enemy's mark. FADE_IN and FADE_OUT: the seconds a mark fades in and out. ENTRIES: the most quest log
-- lines read. ADDON: the folder of Questie.
local K = {
	SIZE = 14, GAP = 2, LEVEL = 15,
	ATLAS = "QuestNormal", FILE = "Interface\\GossipFrame\\AvailableQuestIcon",
	EVENTS = { "QUEST_LOG_UPDATE", "UNIT_FACTION" },
	COUNT = 0.8, COUNT_GAP = 1, GOLD = { 1, 0.82, 0 }, GREY = { 0.6, 0.6, 0.6 }, TAPPED = 0.4,
	FADE_IN = 0.15, FADE_OUT = 0.3, ENTRIES = 100, ADDON = "Questie",
}

-- recs[unitFrame]: holder (the mark's frame), icon (its texture), count (its kill count), countBase (the font object's file), countFont and
-- countText (what the count was given), fade and fadeAnim (the fade's animation group and its Alpha animation, nil on a client without them) and fadeTo (the alpha it ends at),
-- to, point, relative, size and side (what it was anchored to, by which points, its size and the count's side), tapped (the grey look is on),
-- shown, waiting (for the end of a fight). Kept when the plate leaves, so a plate's mark is made once.
local recs = setmetatable({}, { __mode = "k" })
-- owns[unitFrame]: what Nameplates.lua keeps of the plate (its show and layout hooks pass it), for Level box Hidden (own.levelFade).
local owns = setmetatable({}, { __mode = "k" })
-- S: frame (the file's own, false when it could not be made), on (the events are heard), queued (a look at every plate waits for the next frame),
-- atlas (the atlas exists, nil before it is asked), counts (the unfinished kill objectives of the log, { text, have, need }, nil while Kill count
-- beside the quest mark is off), and the count of plates that waited for the end of a fight, for /flatui status.
local S = { frame = nil, on = false, queued = false, atlas = nil, counts = nil, waited = 0 }
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

-- True while Leave quest marks to Questie has the part stand down.
local function Yielding()
	return Opt("questMarkQuestie") == true and QuestieLoaded()
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

-- What the mark stands beside, the point of the mark and the point of that region, and the offsets, for a position.
local function Target(unitFrame, place)
	local bars = Region(unitFrame, "HealthBarsContainer")
	if place == "above" then
		local name = Region(unitFrame, "name")
		return (NameInside() and bars or name) or bars, "BOTTOM", "TOP", 0, K.GAP
	end
	local value, side, target = Texts(unitFrame)
	if place == "right" then
		local after = target or (side == "right" and value) or nil
		if after then
			return after, "LEFT", "RIGHT", K.GAP, 0
		end
		local own = owns[unitFrame]
		local level = Region(unitFrame, "PlayerLevelDiffFrame")
		local shown = level and not (type(own) == "table" and own.levelFade) and Ask(level.IsShown, level) == true
		return shown and level or bars, "LEFT", "RIGHT", K.GAP, 0
	end
	if value and side == "left" then
		return value, "RIGHT", "LEFT", -K.GAP, 0
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

-- Sizes and anchors the mark when its size, its position or what it stands beside changed, out of combat on a plate that may be protected. The
-- count goes on the far side of the mark from the bar: left of it at Left, right of it at Right and Above.
local function Place(unitFrame, rec)
	local size = Opt("questMarkSize")
	size = type(size) == "number" and size > 0 and size or K.SIZE
	local place = Opt("questMarkPlace")
	local to, point, relative, x, y = Target(unitFrame, place)
	local side = place == "left" and "left" or "right"
	if to == nil or (rec.to == to and rec.point == point and rec.relative == relative and rec.size == size and rec.side == side) then
		return
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return
	end
	local holder = rec.holder
	holder:SetSize(size, size)
	if rec.to ~= to or rec.point ~= point or rec.relative ~= relative then
		holder:ClearAllPoints()
		holder:SetPoint(point, to, relative, x, y)
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
	rec.to, rec.point, rec.relative, rec.size, rec.side = to, point, relative, size, side
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

-- The mark faded in or out over FADE_IN or FADE_OUT seconds, or set at once (now, or a client without the animation). A fade still running stops
-- first; the animation ends at the alpha it was played for, and OnFinished sets that alpha too.
local function Fade(rec, show, now)
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
	holder:SetAlpha(1 - alpha)
	if not pcall(group.Play, group) then
		holder:SetAlpha(alpha)
	end
end

-- now: at once, for a plate that leaves or a part that stands down, which also cuts short a fade out still running.
local function Hide(rec, now)
	if not rec.holder then
		return
	end
	if rec.shown then
		rec.shown = nil
		Fade(rec, false, now)
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
		local colour = tapped and K.GREY or K.GOLD
		count:SetTextColor(colour[1], colour[2], colour[3], 1)
		count:SetAlpha(tapped and K.TAPPED or 1)
	end
end

-- The kill count of the first unfinished kill objective whose text starts with the enemy's name, or nothing.
local function Count(rec, unit)
	local count = rec.count
	if not count then
		return
	end
	local text = ""
	local list = Opt("questMarkCount") == true and S.counts or nil
	local name = list and #list > 0 and Ask(UnitName, unit) or nil
	if Plain(name, "string") and name ~= "" then
		for _, entry in ipairs(list) do
			if entry.text:find(name, 1, true) == 1 then
				text = ("%d/%d"):format(entry.have, entry.need)
				break
			end
		end
	end
	if rec.countText ~= text then
		rec.countText = text
		count:SetText(text)
	end
end

-- One plate: its mark made and placed out of combat on every plate that is no player's, so a later enemy on it has one in a fight, and shown while
-- the game says a quest needs the enemy.
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
		Count(rec, unit)
		if not rec.shown then
			rec.shown = true
			Fade(rec, true)
		end
	else
		Hide(rec)
	end
end

-- The unfinished kill objectives of the quest log, read again while Kill count beside the quest mark is on. A header line has no quest (0 or nil).
local function Objectives()
	local quests = C_QuestLog
	if Opt("questMarkCount") ~= true or not Plain(quests, "table") then
		S.counts = nil
		return
	end
	local list = {}
	local entries = Ask(quests.GetNumQuestLogEntries)
	entries = ns.Finite(entries) and math.min(entries, K.ENTRIES) or 0
	for index = 1, entries do
		local id = Ask(quests.GetQuestIDForLogIndex, index)
		local objectives = ns.Finite(id) and id > 0 and Ask(quests.GetQuestObjectives, id) or nil
		if Plain(objectives, "table") then
			for _, objective in ipairs(objectives) do
				if Plain(objective, "table") and Plain(objective.type, "string") and objective.type == "monster"
					and not (Plain(objective.finished, "boolean") and objective.finished) and Plain(objective.text, "string")
					and ns.Finite(objective.numFulfilled) and ns.Finite(objective.numRequired) and objective.numRequired > 0 then
					list[#list + 1] = { text = objective.text, have = math.floor(objective.numFulfilled), need = math.floor(objective.numRequired) }
				end
			end
		end
	end
	S.counts = list
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
	return ("Quest marks on nameplates: %d shown, %d plates waited for the end of a fight for their mark."):format(shown, S.waited)
end
