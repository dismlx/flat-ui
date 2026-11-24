local _, ns = ...

-- Quest mark on enemies you need for a quest, a part of Nameplates.lua (ns.PlateExtra): a small quest mark (the game's QuestNormal atlas, else its
-- AvailableQuestIcon file) beside the health bar of an enemy that is no player and that the game says belongs to a quest in the player's log
-- (C_QuestLog.UnitIsRelatedToActiveQuest, QuestLogDocumentation.lua:1287-1300, a plain bool with no withheld answer, read as SparkleGlow.lua reads
-- it), on by default (Quest mark on enemies you need for a quest, the Marks and icons tab of Nameplates), Quest mark size big and at Quest mark
-- position: Left, past the game's raid marker and its elite or rare icon (anchored to the left of the plate's ClassificationFrame, which hangs left of
-- the RaidTargetFrame, both of which take no room while hidden: collapsesLayout, Blizzard_NamePlates.xml:186-199, so the mark follows them in a
-- fight too); Right, past the level frame while it shows, else past the health bar; Above, over the name (the top of the health bars while the
-- name is inside them), where the plate's debuffs and the Overpower icon (PlateOverpower.lua, a level above) also sit. No mark shows on a plate in
-- name-only or widgets-only mode, nor on a unit the player cannot attack (UnitCanAttack). The game is asked again as a plate shows and, merged onto
-- the next frame, on QUEST_LOG_UPDATE and the player's UNIT_QUEST_LOG_CHANGED, over every plate (ns.EachPlate): a mark goes once that objective is
-- done.
-- Combat: the mark is a frame of Flat UI's own, a child of the plate's unit frame so it moves, fades and hides with the plate, made, sized and
-- anchored only out of combat on a plate the game may protect (ns.MaybeProtected, Movers.lua), as the Overpower icon is: it is made on each plate
-- that is no player's as the plate shows while the row is on, and kept when the plate goes, so a plate the game hands out again in a fight has it.
-- In a fight only its alpha changes. A plate first seen in a fight gets its mark when the fight ends; /flatui status counts those and the marks
-- shown. Nothing of the game is written: every call on the game only reads.

local KEY = "nameplates"
local PART = "Quest mark"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

-- SIZE: the mark when the row gives no size. GAP: nameplate units between the mark and what it stands beside. LEVEL: frame levels above the
-- plate's unit frame, under the Overpower icon's. ATLAS and FILE: the mark's art, the atlas first. EVENTS: what makes the plates be asked again.
local K = {
	SIZE = 14, GAP = 2, LEVEL = 15,
	ATLAS = "QuestNormal", FILE = "Interface\\GossipFrame\\AvailableQuestIcon",
	EVENTS = { "QUEST_LOG_UPDATE" },
}

-- recs[unitFrame]: holder (the mark's frame), icon (its texture), to, point and size (what it was anchored to, by which point, and its size),
-- shown, waiting (for the end of a fight). Kept when the plate leaves, so a plate's mark is made once.
local recs = setmetatable({}, { __mode = "k" })
-- S: frame (the file's own, false when it could not be made), on (the events are heard), queued (a look at every plate waits for the next frame),
-- atlas (the atlas exists, nil before it is asked), and the count of plates that waited for the end of a fight, for /flatui status.
local S = { frame = nil, on = false, queued = false, atlas = nil, waited = 0 }
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

local function Wanted()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and Opt("questMark") == true
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

-- What the mark stands beside, the point of the mark and the point of that region, and the offsets, for a position.
local function Target(unitFrame, place)
	local bars = Region(unitFrame, "HealthBarsContainer")
	if place == "right" then
		local level = Region(unitFrame, "PlayerLevelDiffFrame")
		local shown = level and Ask(level.IsShown, level) == true
		return shown and level or bars, "LEFT", "RIGHT", K.GAP, 0
	elseif place == "above" then
		local name = Region(unitFrame, "name")
		return (NameInside() and bars or name) or bars, "BOTTOM", "TOP", 0, K.GAP
	end
	return Region(unitFrame, "ClassificationFrame") or Region(unitFrame, "RaidTargetFrame") or bars, "RIGHT", "LEFT", -K.GAP, 0
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
	return rec
end

-- Sizes and anchors the mark when its size, its position or what it stands beside changed, out of combat on a plate that may be protected.
local function Place(unitFrame, rec)
	local size = Opt("questMarkSize")
	size = type(size) == "number" and size > 0 and size or K.SIZE
	local to, point, relative, x, y = Target(unitFrame, Opt("questMarkPlace"))
	if to == nil or (rec.to == to and rec.point == point and rec.size == size) then
		return
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return
	end
	local holder = rec.holder
	holder:SetSize(size, size)
	if rec.to ~= to or rec.point ~= point then
		holder:ClearAllPoints()
		holder:SetPoint(point, to, relative, x, y)
	end
	local level = Ask(unitFrame.GetFrameLevel, unitFrame)
	if type(level) == "number" then
		pcall(holder.SetFrameLevel, holder, level + K.LEVEL)
	end
	rec.to, rec.point, rec.size = to, point, size
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

local function Hide(rec)
	if rec.holder and rec.shown then
		rec.shown = nil
		rec.holder:SetAlpha(0)
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
		if not rec.shown then
			rec.shown = true
			rec.holder:SetAlpha(1)
		end
	else
		Hide(rec)
	end
end

-- Every plate asked again: the quest log changed.
local function LookAll()
	S.queued = false
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

-- Everything hidden: the row, the page or the part went off.
local function StandDown()
	for _, rec in pairs(recs) do
		pcall(Hide, rec)
	end
end

local function OnEvent(_, event, unit)
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

-- Hooks into the plates ------------------------------------------------------------------------------------------------------------------------

EXTRA.show[#EXTRA.show + 1] = function(unitFrame)
	if S.on then
		ns.EachPart(KEY, PART, Draw, unitFrame)
	end
end
EXTRA.layout[#EXTRA.layout + 1] = function(unitFrame)
	local rec = recs[unitFrame]
	if S.on and rec and rec.holder then
		ns.EachPart(KEY, PART, Draw, unitFrame)
	end
end
EXTRA.leave[#EXTRA.leave + 1] = function(unitFrame)
	local rec = recs[unitFrame]
	if rec then
		Hide(rec)
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
EXTRA.status[#EXTRA.status + 1] = function()
	if not S.on then
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
