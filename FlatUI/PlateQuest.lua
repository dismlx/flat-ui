local _, ns = ...

local KEY = "nameplates"
local PART = "Quest mark"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local K = {
	SIZE = 14, GAP = 2, ROW_GAP = 1, LEVEL = 15,
	ATLAS = "QuestNormal", FILE = "Interface\\GossipFrame\\AvailableQuestIcon",
	EVENTS = { "QUEST_LOG_UPDATE", "UNIT_FACTION" },
	COUNT = 0.8, COUNT_GAP = 1, GOLD = { 1, 0.82, 0 }, GREY = { 0.6, 0.6, 0.6 }, GREEN = { 0.3, 0.9, 0.35 }, WHITE = { 1, 1, 1 }, POP = 1.6,
	POP_SECONDS = 0.3, TAPPED = 0.4,
	FADE_IN = 0.15, FADE_OUT = 0.3, ENTRIES = 100, ADDON = "Questie",
}

local recs = setmetatable({}, { __mode = "k" })
local owns = setmetatable({}, { __mode = "k" })
local S = { frame = nil, on = false, queued = false, atlas = nil, counts = nil, done = nil, waited = 0 }
local Draw

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

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

local function QuestieLoaded()
	local addons = C_AddOns
	if Plain(addons, "table") and type(addons.IsAddOnLoaded) == "function" then
		return Ask(addons.IsAddOnLoaded, K.ADDON) == true
	end
	return Ask(rawget(_G, "IsAddOnLoaded"), K.ADDON) == true
end

local function Asked()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and Opt("questMark") == true
end

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

local function Yielding()
	return Opt("questMarkQuestie") == true and QuestieLoaded() and QuestieDraws()
end

local function Wanted()
	return Asked() and not Yielding()
end

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

local function NameInside()
	local options, constants = NamePlateSetupOptions, NamePlateConstants
	local styles = Plain(constants, "table") and constants.NAME_ANCHOR_STYLES
	local style = Plain(options, "table") and options.unitNameAnchorStyle
	return Plain(styles, "table") and Plain(style, "number") and style == styles.InsideHealthBar
end

local function Collapses(frame)
	return frame ~= nil and Ask(frame.CollapsesLayout, frame) == true
end

local function AuraRow(unitFrame, side)
	if type(ns.PlateAuraRow) ~= "function" then
		return nil
	end
	local ok, row = pcall(ns.PlateAuraRow, unitFrame, side)
	return ok and type(row) == "table" and row or nil
end

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

local function OverpowerIcon(unitFrame)
	if type(ns.PlateOverpowerIcon) ~= "function" then
		return nil
	end
	local ok, icon = pcall(ns.PlateOverpowerIcon, unitFrame)
	return ok and type(icon) == "table" and icon or nil
end

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

local function CountColour(rec)
	local count = rec.count
	if count then
		local colour = rec.popping and K.WHITE or (rec.complete and K.GREEN or (rec.tapped and K.GREY or K.GOLD))
		count:SetTextColor(colour[1], colour[2], colour[3], 1)
	end
end

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
	local count = ns.OwnText(holder, "OVERLAY", "SystemFont_NamePlate")
	if count then
		local ok, file = pcall(count.GetFont, count)
		rec.countBase = ok and Plain(file, "string") and file or nil
		count:SetTextColor(K.GOLD[1], K.GOLD[2], K.GOLD[3], 1)
		count:SetText("")
		rec.count, rec.countText = count, ""
		MakeCountPop(rec)
	end
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

local function Slip(unitFrame)
	if Opt("questMarkPlace") == "above" and type(ns.PlateSlipPlace) == "function" then
		pcall(ns.PlateSlipPlace, unitFrame)
	end
end

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
		local before = rec.countText
		rec.countText = text
		count:SetText(text)
		if rec.shown and before ~= nil and before ~= "" and text ~= "" then
			PopCount(rec)
		end
	end
end

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
			Slip(unitFrame)
		end
	else
		local was = rec.shown
		local entry = was and rec.count and Objective(unit, rec.objective) or nil
		if entry and entry.done then
			Count(rec, entry)
			Hide(rec, false, true)
		else
			Hide(rec)
		end
		if was and not rec.shown then
			Slip(unitFrame)
		end
	end
end

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

local function StandDown()
	for unitFrame, rec in pairs(recs) do
		local was = rec.shown
		pcall(Hide, rec, true)
		if was then
			Slip(unitFrame)
		end
	end
end

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

function ns.PlateQuestAbove(unitFrame)
	local rec = unitFrame ~= nil and recs[unitFrame]
	if S.on and rec and rec.holder and rec.shown and rec.to ~= nil and Opt("questMarkPlace") == "above" then
		return rec.holder
	end
	return nil
end

function ns.PlateQuestPlace(unitFrame)
	local rec = unitFrame ~= nil and recs[unitFrame]
	if S.on and rec and rec.holder then
		ns.EachPart(KEY, PART, Draw, unitFrame)
	end
end

EXTRA.show[#EXTRA.show + 1] = function(unitFrame, own)
	owns[unitFrame] = own
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
ns.AddEvent(KEY, "ADDON_LOADED", function()
	ns.EachPart(KEY, PART, Sync)
end, function(name)
	return not ns.IsSecret(name) and name == K.ADDON
end)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
	ns.AddEvent(KEY, event, function()
		ns.EachPart(KEY, PART, Sync)
	end)
end
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
