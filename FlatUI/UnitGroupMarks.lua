local _, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local DISPEL, MARKER, LEADER, AIM, REZ = "Dispel highlight", "Raid frame marker", "Leader icons", "Target border", "Resurrection icon"
local AFK = "AFK word"
local FILTER = "HARMFUL|RAID"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MARKER_FILE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local RIM_PX, ICON, MARK, SOON = 2, 12, 14, 0.1
local PARTY_MARK, LEAD, LEAD_IN, LEAD_DOWN = 16, 10, 3, 16
local LEADER_ATLAS, LEADER_FILE, ASSISTANT_FILE = "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-AssistantIcon"
local SELF = { player = "player", target = "target", focus = "focus" }
local MARKER_ROWS = { raid = "raidFrameMarker", party = "partyFrameMarker" }
local TYPES = { "Magic", "Curse", "Disease", "Poison" }
local TYPE_ID = { Magic = 1, Curse = 2, Disease = 3, Poison = 4 }
local COLOURS = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 } }
local UNKNOWN = { 1, 1, 1 }
local LAST_ID = 5
local ATLAS = "RaidFrame-Icon-Debuff"
local NOTE_BLIND = "Unit frames: Dispel highlight: the game would not say which debuffs a member has, so no border shows."
local NOTE_TYPE = "Unit frames: Dispel highlight: the game withheld the type of a debuff you can dispel, so its border is white."
local NOTE_LEAD = "Unit frames: Leader icons: the game would not set the icons from its answer about the leader, so they do not show."
local NOTE_AIM = "Unit frames: Border for your target: the game would not set the outline from its answer about your target, so the party frames have none."

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Field(object, key)
	if object == nil or IsSecret(object) or type(object) ~= "table" then
		return nil
	end
	local ok, value = pcall(function()
		return object[key]
	end)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local saying = { [NOTE_BLIND] = setmetatable({}, { __mode = "k" }), [NOTE_TYPE] = setmetatable({}, { __mode = "k" }), [NOTE_LEAD] = setmetatable({}, { __mode = "k" }),
	[NOTE_AIM] = setmetatable({}, { __mode = "k" }) }

local function Say(text, rec, on)
	saying[text][rec] = on or nil
	if next(saying[text]) ~= nil then
		ns.Note(KEY, text)
	else
		ns.ClearNote(KEY, text)
	end
end

local function Quiet(rec)
	Say(NOTE_BLIND, rec, false)
	Say(NOTE_TYPE, rec, false)
end

local function UnitOfFrame(rec)
	if SELF[rec.kind] then
		return SELF[rec.kind]
	end
	local shown = Field(rec.frame, "displayedUnit")
	if type(shown) == "string" and shown ~= "" then
		return shown
	end
	return X.unitOf(rec)
end

local curves = {}

local function AtlasExists(name)
	local api = C_Texture
	if type(api) ~= "table" or IsSecret(api) or type(api.GetAtlasInfo) ~= "function" then
		return false
	end
	local ok, info = pcall(api.GetAtlasInfo, name)
	return ok and not IsSecret(info) and info ~= nil
end

local function Curves()
	if curves.made then
		return curves.ok
	end
	curves.made = true
	curves.art = AtlasExists(ATLAS .. "Magic")
	curves.ok = pcall(function()
		local function Step()
			local curve = C_CurveUtil.CreateColorCurve()
			curve:SetType(Enum.LuaCurveType.Step)
			return curve
		end
		local border = Step()
		for x = 0, LAST_ID do
			local kind = TYPES[x]
			local c = kind and COLOURS[kind] or UNKNOWN
			border:AddPoint(x, CreateColor(c[1], c[2], c[3], 1))
		end
		local icons = {}
		for _, kind in ipairs(TYPES) do
			local icon = Step()
			local c = curves.art and UNKNOWN or COLOURS[kind]
			for x = 0, LAST_ID do
				icon:AddPoint(x, CreateColor(c[1], c[2], c[3], x == TYPE_ID[kind] and 1 or 0))
			end
			icons[kind] = icon
		end
		curves.border, curves.icons = border, icons
	end)
	return curves.ok
end

local function Tint(texture, colour)
	if colour == nil or IsSecret(colour) or type(colour) ~= "table" then
		return false
	end
	return (pcall(function()
		texture:SetVertexColor(colour:GetRGBA())
	end))
end

local function TypeColour(unit, id, curve)
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.GetAuraDispelTypeColor
	if type(call) ~= "function" or curve == nil then
		return nil
	end
	local ok, colour = pcall(call, unit, id, curve)
	if ok then
		return colour
	end
	return nil
end

local function Readable()
	local units = C_UnitAuras
	return type(units) == "table" and not IsSecret(units) and type(units.GetAuraSlots) == "function" and type(units.GetAuraDataBySlot) == "function"
end

local function First(unit)
	if not Readable() then
		return nil
	end
	local units = C_UnitAuras
	local ok, _, slot = pcall(units.GetAuraSlots, unit, FILTER, 1)
	if not ok or IsSecret(slot) then
		return false
	elseif slot == nil then
		return nil
	elseif not ns.Finite(slot) then
		return false
	end
	local found, aura = pcall(units.GetAuraDataBySlot, unit, slot)
	if not found or IsSecret(aura) then
		return true, nil
	elseif aura == nil then
		return nil
	end
	local id = Field(aura, "auraInstanceID")
	if ns.Finite(id) then
		return id, aura
	end
	return true, aura
end

local BLINK_LOW, BLINK_STEP = 0.2, 0.1

local function Blink(holder)
	if type(holder.CreateAnimationGroup) ~= "function" then
		return nil
	end
	local okGroup, group = pcall(holder.CreateAnimationGroup, holder)
	local made = okGroup and group ~= nil
	for order = 1, 6 do
		local from, to = 1, BLINK_LOW
		if order % 2 == 0 then
			from, to = BLINK_LOW, 1
		end
		local okFade, fade = false, nil
		if made then
			okFade, fade = pcall(group.CreateAnimation, group, "Alpha")
		end
		made = okFade and fade ~= nil and pcall(fade.SetFromAlpha, fade, from) and pcall(fade.SetToAlpha, fade, to)
			and pcall(fade.SetDuration, fade, BLINK_STEP) and pcall(fade.SetOrder, fade, order)
	end
	if not made then
		return nil
	end
	pcall(group.SetScript, group, "OnFinished", function()
		pcall(holder.SetAlpha, holder, 1)
	end)
	return group
end

X.blink = Blink

local function StopBlink(d)
	if d.flash then
		pcall(d.flash.Stop, d.flash)
	end
	pcall(d.holder.SetAlpha, d.holder, 1)
end

local function MakeDispel(rec)
	local entry = rec.byRole.health
	local box = entry and entry.target
	if box == nil or ns.Forbidden(box) then
		return nil
	end
	local ok, level = pcall(box.GetFrameLevel, box)
	local holder = X.frame(box, ok and X.number(level) and level + 3 or nil)
	holder:SetAllPoints(box)
	local d = { holder = holder, box = box, edges = {} }
	for index = 1, 4 do
		local edge = Own(holder:CreateTexture(nil, "OVERLAY", nil, 6))
		edge:SetTexture(WHITE)
		pcall(edge.SetSnapToPixelGrid, edge, false)
		pcall(edge.SetTexelSnappingBias, edge, 0)
		edge:Hide()
		d.edges[index] = edge
	end
	if rec.kind == "party" then
		Curves()
		d.icons = {}
		for _, kind in ipairs(TYPES) do
			local icon = Own(holder:CreateTexture(nil, "OVERLAY", nil, 7))
			if not (curves.art and pcall(icon.SetAtlas, icon, ATLAS .. kind)) then
				icon:SetTexture(WHITE)
			end
			icon:SetSize(ICON, ICON)
			icon:Hide()
			d.icons[kind] = icon
		end
	end
	d.flash = Blink(holder)
	rec.dispel = d
	return d
end

local function PlaceDispel(d)
	local t = ns.Pixels(d.holder, RIM_PX)
	if d.placed == t then
		return
	end
	d.placed = t
	local box = d.box
	local top, bottom, left, right = d.edges[1], d.edges[2], d.edges[3], d.edges[4]
	top:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	top:SetHeight(t)
	bottom:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	bottom:SetHeight(t)
	left:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -t)
	left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, t)
	left:SetWidth(t)
	right:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -t)
	right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, t)
	right:SetWidth(t)
	for _, icon in pairs(d.icons or {}) do
		icon:SetPoint("RIGHT", box, "RIGHT", -1 - t, 0)
	end
end

local function Clear(d)
	d.rim = nil
	StopBlink(d)
	for _, edge in ipairs(d.edges) do
		edge:Hide()
	end
	for _, icon in pairs(d.icons or {}) do
		icon:Hide()
	end
end

local function Wanted(rec, on)
	if not on or not rec.made or ns.PartStopped(KEY, DISPEL) or not Readable() then
		return false, false
	elseif SELF[rec.kind] then
		return Opt("dispelBorder") == true and Opt("dispelSelf") == true, false
	end
	return Opt("dispelBorder") == true, rec.kind == "party" and Opt("dispelIcon") == true
end

local function PlainIcon(d, name)
	for _, kind in ipairs(TYPES) do
		local icon = d.icons[kind]
		local c = curves.art and UNKNOWN or COLOURS[kind]
		icon:SetVertexColor(c[1], c[2], c[3], 1)
		icon:SetShown(kind == name)
	end
end

local function Draw(rec, d, unit, id, aura)
	local border, icon = Wanted(rec, X.active(rec))
	local withheld = type(id) ~= "number"
	local name = Field(aura, "dispelName")
	name = type(name) == "string" and COLOURS[name] and name or nil
	if border then
		local coloured = not withheld and Curves()
		if coloured then
			local colour = TypeColour(unit, id, curves.border)
			for _, edge in ipairs(d.edges) do
				coloured = Tint(edge, colour) and coloured
			end
		end
		if not coloured then
			local c = name and COLOURS[name] or UNKNOWN
			for _, edge in ipairs(d.edges) do
				edge:SetVertexColor(c[1], c[2], c[3], 1)
			end
		end
		Say(NOTE_TYPE, rec, not coloured and name == nil)
	else
		Say(NOTE_TYPE, rec, false)
	end
	for _, edge in ipairs(d.edges) do
		edge:SetShown(border)
	end
	d.rim = border or nil
	if d.icons == nil then
		return
	end
	if not icon then
		for _, texture in pairs(d.icons) do
			texture:Hide()
		end
	elseif withheld or not Curves() then
		PlainIcon(d, name)
	else
		for _, kind in ipairs(TYPES) do
			local texture = d.icons[kind]
			if Tint(texture, TypeColour(unit, id, curves.icons[kind])) then
				texture:Show()
			else
				PlainIcon(d, name)
				return
			end
		end
	end
end

local function Hidden(rec)
	if SELF[rec.kind] then
		return false
	end
	local ok, shown = pcall(rec.frame.IsShown, rec.frame)
	return ok and not IsSecret(shown) and shown == false
end

local function Foe(rec, unit)
	if (rec.kind ~= "target" and rec.kind ~= "focus") or type(UnitCanAssist) ~= "function" then
		return false
	end
	local ok, can = pcall(UnitCanAssist, "player", unit)
	return ok and not IsSecret(can) and can == false
end

local Hear

local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local SOUND_GAP = 2
local lastSound = nil

local function Chime(rec)
	if (rec.kind ~= "party" and rec.kind ~= "raid") or Opt("dispelBorder") ~= true then
		return
	end
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[Opt("dispelSound")] or 0]
	local now = type(GetTime) == "function" and GetTime() or nil
	if sound == nil or now == nil or (lastSound ~= nil and now - lastSound < SOUND_GAP and now >= lastSound) then
		return
	end
	if ns.PlayKit(sound[1]) then
		lastSound = now
	end
end

function ns.DispelSoundPicked(path)
	if type(path) ~= "string" or not (type(ns.PanelShown) == "function" and ns.PanelShown() == true) then
		return
	end
	local okFight, fighting = pcall(InCombatLockdown)
	if not okFight or IsSecret(fighting) or fighting == true then
		return
	end
	local kit = KITS[ns.Get(path)]
	local sound = kit and ns.SOUNDS and ns.SOUNDS[kit]
	if sound and type(ns.PlayKit) == "function" then
		ns.PlayKit(sound[1])
	end
end

local function Read(rec)
	local d = rec.dispel
	if d == nil then
		return
	end
	local border, icon = Wanted(rec, X.active(rec))
	local unit = d.unit
	if not (border or icon) or unit == nil or Hidden(rec) then
		d.withheld = nil
		Clear(d)
		Hear(rec, d, nil)
		Quiet(rec)
		return
	end
	if Foe(rec, unit) then
		d.withheld = nil
		Clear(d)
		Quiet(rec)
		return
	end
	local id, aura = First(unit)
	d.withheld = id == false or id == true
	Say(NOTE_BLIND, rec, id == false)
	local landed = false
	if id ~= false then
		local has = id ~= nil
		landed = has and d.had == false
		if landed then
			Chime(rec)
		end
		d.had = has
	end
	if not id then
		Clear(d)
		Say(NOTE_TYPE, rec, false)
		return
	end
	Draw(rec, d, unit, id, aura)
	if landed and d.rim and d.flash and (rec.kind == "party" or rec.kind == "raid") and Opt("dispelFlash") == true then
		pcall(d.flash.Stop, d.flash)
		pcall(d.flash.Play, d.flash)
	end
end

local dirty, pending = setmetatable({}, { __mode = "k" }), false

local function Pass()
	pending = false
	local list = {}
	for rec in pairs(dirty) do
		list[#list + 1] = rec
	end
	for _, rec in ipairs(list) do
		dirty[rec] = nil
		X.run(DISPEL, Read, rec)
	end
end

local function Soon(rec)
	dirty[rec] = true
	if pending then
		return
	end
	pending = true
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" or not pcall(C_Timer.After, SOON, Pass) then
		Pass()
	end
end

local function Reread()
	for _, rec in pairs(X.records) do
		if rec.dispel and rec.dispel.withheld then
			Soon(rec)
		end
	end
end

local function AurasOpenAgain(kind, state)
	local kinds = type(Enum) == "table" and Enum.AddOnRestrictionType or nil
	local states = type(Enum) == "table" and Enum.AddOnRestrictionState or nil
	if IsSecret(kind) or IsSecret(state) or type(kinds) ~= "table" or type(states) ~= "table" or state ~= states.Inactive then
		return false
	end
	return kind == kinds.Combat or kind == kinds.Encounter or kind == kinds.ChallengeMode or kind == kinds.PvPMatch
end

ns.AddEvent(KEY, "PLAYER_REGEN_ENABLED", Reread)
ns.AddEvent(KEY, "ADDON_RESTRICTION_STATE_CHANGED", Reread, AurasOpenAgain)

function Hear(rec, d, unit)
	if d.unit == unit and (d.heard or unit == nil) then
		return
	end
	local ear = d.ear
	if ear == nil then
		ear = Own(CreateFrame("Frame"))
		ear:SetScript("OnEvent", function()
			Soon(rec)
		end)
		d.ear = ear
	end
	pcall(ear.UnregisterAllEvents, ear)
	if d.unit ~= unit then
		d.had = nil
	end
	d.unit, d.heard = unit, nil
	if unit == nil then
		return
	end
	if type(ear.RegisterUnitEvent) == "function" then
		local ok, done = pcall(ear.RegisterUnitEvent, ear, "UNIT_AURA", unit)
		d.heard = ok and (IsSecret(done) or done ~= false) or nil
	end
	if not d.heard then
		d.heard = pcall(ear.RegisterEvent, ear, "UNIT_AURA") or nil
	end
end

local function Dispel(rec, on)
	if rec.kind ~= "party" and rec.kind ~= "raid" and SELF[rec.kind] == nil then
		return
	end
	local border, icon = Wanted(rec, on)
	local d = rec.dispel
	if not (border or icon) then
		if d then
			Clear(d)
			Hear(rec, d, nil)
			Quiet(rec)
		end
		return
	end
	if d == nil then
		if InCombatLockdown() then
			if not rec.dispelQueued then
				rec.dispelQueued = true
				ns.OutOfCombat(function()
					rec.dispelQueued = nil
					X.run(DISPEL, Dispel, rec, X.active(rec))
				end)
			end
			return
		end
		d = MakeDispel(rec)
		if d == nil then
			return
		end
		PlaceDispel(d)
	elseif not InCombatLockdown() then
		PlaceDispel(d)
	end
	Hear(rec, d, not Hidden(rec) and UnitOfFrame(rec) or nil)
	Soon(rec)
end

local function Retarget(kind)
	for _, rec in pairs(X.records) do
		if rec.kind == kind and rec.dispel then
			Soon(rec)
		end
	end
end

local TELL_MARKS = "Flat UI: party and raid frame marks change when the fight ends."

local function AfterFight(rec, flag, part, fn)
	if rec[flag] then
		return
	end
	rec[flag] = true
	X.tell(TELL_MARKS)
	ns.OutOfCombat(function()
		rec[flag] = nil
		X.run(part, fn, rec, X.active(rec))
	end)
end

local function Holder(rec)
	if rec.over == nil then
		local frame = rec.frame
		local ok, level = pcall(frame.GetFrameLevel, frame)
		local holder = X.frame(frame, ok and X.number(level) and level + 6 or nil)
		holder:SetAllPoints(frame)
		rec.over = holder
	end
	return rec.over
end

local function FromAnswer(region, call, ...)
	local set = nil
	if type(call) == "function" and type(region.SetAlphaFromBoolean) ~= "function" then
		set = false
	elseif type(call) == "function" then
		local ok, answer = pcall(call, ...)
		if ok and (IsSecret(answer) or type(answer) == "boolean") then
			set = pcall(region.SetAlphaFromBoolean, region, answer, 1, 0)
		end
	end
	if set ~= true then
		pcall(region.SetAlpha, region, 0)
	end
	return set
end

local function Plain(call, unit)
	if type(call) ~= "function" or unit == nil then
		return nil
	end
	local ok, answer = pcall(call, unit)
	if ok and not IsSecret(answer) and type(answer) == "boolean" then
		return answer
	end
	return nil
end

local function HealthBar(rec)
	local entry = rec.byRole.health
	return entry and entry.target or rec.parts.health
end

local function MarkerSpot(rec)
	if rec.kind ~= "party" then
		return rec.frame, "TOP", -1
	end
	local pic, portrait = rec.pic, rec.parts.portrait
	if pic ~= nil and pic.drawn then
		return pic.frame, "CENTER", 0
	elseif portrait ~= nil and not (pic ~= nil and pic.none) then
		return portrait, "CENTER", 0
	elseif pic ~= nil and pic.none and not X.joined(rec) then
		if pic.side ~= nil then
			return pic.frame, "CENTER", 0
		elseif portrait ~= nil then
			return portrait, "CENTER", 0
		end
	end
	return HealthBar(rec), "CENTER", 0
end

local function PlaceMarker(rec)
	local m = rec.marker
	local to, point, y = MarkerSpot(rec)
	if to == nil or m.to == to then
		return true
	elseif InCombatLockdown() then
		return false
	end
	m.icon:ClearAllPoints()
	m.icon:SetPoint(point, to, "TOP", 0, y)
	m.to = to
	return true
end

local function MakeMarker(rec)
	local holder = Holder(rec)
	local icon = Own(holder:CreateTexture(nil, "OVERLAY", nil, 7))
	icon:SetTexture(MARKER_FILE)
	local size = rec.kind == "party" and PARTY_MARK or MARK
	icon:SetSize(size, size)
	icon:Hide()
	rec.marker = { holder = holder, icon = icon }
	PlaceMarker(rec)
	return rec.marker
end

local function Cell(icon, index)
	if type(icon.SetSpriteSheetCell) == "function" then
		return (pcall(icon.SetSpriteSheetCell, icon, index, 4, 4))
	elseif ns.Finite(index) then
		local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
		return (pcall(icon.SetTexCoord, icon, column / 4, (column + 1) / 4, row / 4, (row + 1) / 4))
	end
	return false
end

local function DrawMarker(rec)
	local m = rec.marker
	if m == nil then
		return
	end
	local unit = UnitOfFrame(rec)
	local shown = false
	if unit ~= nil and type(GetRaidTargetIndex) == "function" then
		local ok, index = pcall(GetRaidTargetIndex, unit)
		if ok and (IsSecret(index) or (ns.Finite(index) and index >= 1 and index <= 8 and index == math.floor(index))) then
			shown = Cell(m.icon, index)
		end
	end
	m.icon:SetShown(shown)
end

local function Marker(rec, on)
	local row = MARKER_ROWS[rec.kind]
	if row == nil then
		return
	end
	local live = on and rec.made and not ns.PartStopped(KEY, MARKER) and Opt(row) == true and type(GetRaidTargetIndex) == "function"
	local m = rec.marker
	if not live then
		if m then
			m.icon:Hide()
		end
		return
	end
	if m == nil then
		if InCombatLockdown() then
			AfterFight(rec, "markerQueued", MARKER, Marker)
			return
		end
		MakeMarker(rec)
	elseif not PlaceMarker(rec) then
		AfterFight(rec, "markerQueued", MARKER, Marker)
	end
	DrawMarker(rec)
end

local function Follow(rec)
	if rec.marker ~= nil and not PlaceMarker(rec) then
		AfterFight(rec, "markerQueued", MARKER, Marker)
	end
end

ns.AddEvent(KEY, "RAID_TARGET_UPDATE", function()
	for _, rec in pairs(X.records) do
		if MARKER_ROWS[rec.kind] and rec.marker then
			X.run(MARKER, Marker, rec, X.active(rec))
		end
	end
end)

local REZ_SIZE, REZ_BAR, REZ_LOW, REZ_BEAT = 20, 14, 0.45, 1
local REZ_ATLAS = "RaidFrame-Icon-Rez"

local function PlaceRez(rec)
	local r = rec.rezIcon
	local to = MarkerSpot(rec)
	local onBar = to ~= nil and to == HealthBar(rec)
	if to == nil or (r.to == to and r.onBar == onBar) then
		return true
	elseif InCombatLockdown() then
		return false
	end
	r.icon:ClearAllPoints()
	if onBar then
		r.icon:SetSize(REZ_BAR, REZ_BAR)
		r.icon:SetPoint("LEFT", to, "LEFT", 1, 0)
	else
		r.icon:SetSize(REZ_SIZE, REZ_SIZE)
		r.icon:SetPoint("CENTER", to, "CENTER", 0, 0)
	end
	r.to, r.onBar = to, onBar
	return true
end

local function RezBeat(frame)
	if type(frame.CreateAnimationGroup) ~= "function" then
		return nil
	end
	local okGroup, group = pcall(frame.CreateAnimationGroup, frame)
	local made = okGroup and group ~= nil and pcall(group.SetLooping, group, "REPEAT")
	for order, alphas in ipairs({ { 1, REZ_LOW }, { REZ_LOW, 1 } }) do
		local okFade, fade = false, nil
		if made then
			okFade, fade = pcall(group.CreateAnimation, group, "Alpha")
		end
		made = okFade and fade ~= nil and pcall(fade.SetFromAlpha, fade, alphas[1]) and pcall(fade.SetToAlpha, fade, alphas[2])
			and pcall(fade.SetDuration, fade, REZ_BEAT / 2) and pcall(fade.SetOrder, fade, order)
	end
	return made and group or nil
end

local function MakeRez(rec)
	local holder = Holder(rec)
	local frame = X.frame(holder)
	frame:SetAllPoints(holder)
	local icon = Own(frame:CreateTexture(nil, "OVERLAY", nil, 6))
	icon:SetSize(REZ_SIZE, REZ_SIZE)
	icon:SetAlpha(0)
	icon:Hide()
	local r = { frame = frame, icon = icon, beat = RezBeat(frame) }
	r.art = AtlasExists(REZ_ATLAS) and pcall(icon.SetAtlas, icon, REZ_ATLAS) or false
	rec.rezIcon = r
	PlaceRez(rec)
	return r
end

local function Breathe(r, dead)
	local beat = r.beat
	if beat == nil then
		return
	end
	local ok, playing = pcall(beat.IsPlaying, beat)
	playing = ok and not IsSecret(playing) and playing == true
	if dead and not playing then
		pcall(beat.Play, beat)
	elseif not dead then
		if playing then
			pcall(beat.Stop, beat)
		end
		pcall(r.frame.SetAlpha, r.frame, 1)
	end
end

local function Rez(rec, on)
	if rec.kind ~= "party" then
		return
	end
	local r = rec.rezIcon
	if not (on and rec.made and not ns.PartStopped(KEY, REZ) and Opt("partyRezIcon") == true and type(_G.UnitHasIncomingResurrection) == "function") then
		if r then
			r.icon:Hide()
			Breathe(r, false)
		end
		return
	end
	if r == nil then
		if InCombatLockdown() then
			AfterFight(rec, "rezQueued", REZ, Rez)
			return
		end
		r = MakeRez(rec)
	elseif not PlaceRez(rec) then
		AfterFight(rec, "rezQueued", REZ, Rez)
	end
	if not r.art then
		return
	end
	local unit = X.unitOf(rec)
	if unit ~= nil then
		FromAnswer(r.icon, _G.UnitHasIncomingResurrection, unit)
	else
		pcall(r.icon.SetAlpha, r.icon, 0)
	end
	Breathe(r, Plain(_G.UnitIsDeadOrGhost, unit) == true)
	r.icon:Show()
end

local function FollowRez(rec)
	if rec.rezIcon ~= nil and not PlaceRez(rec) then
		AfterFight(rec, "rezQueued", REZ, Rez)
	end
end

ns.AddEvent(KEY, "INCOMING_RESURRECT_CHANGED", function()
	for _, rec in pairs(X.records) do
		if rec.kind == "party" and rec.made then
			X.run(REZ, Rez, rec, X.active(rec))
		end
	end
end)

local AFK_EVENTS = { "PLAYER_FLAGS_CHANGED", "UNIT_CONNECTION", "UNIT_HEALTH" }
local AFK_GREY = 0.8
local AFK_IN, AFK_OUT, AFK_EVERY = 0.2, 0.3, 15

local function Away(unit)
	local away = Plain(_G.UnitIsAFK, unit)
	if away ~= true then
		return away, away
	end
	return true, Plain(_G.UnitIsDeadOrGhost, unit) ~= true and Plain(_G.UnitIsConnected, unit) ~= false
end

local function Now()
	local ok, now = pcall(GetTime)
	if ok and ns.Finite(now) then
		return now
	end
	return nil
end

local function AfkWord(a)
	local word, now = a.word, Now()
	if a.since ~= nil and now ~= nil then
		local gone = now - a.since
		if gone >= 3600 then
			word = ("%s %dh"):format(a.word, math.floor(gone / 3600))
		elseif gone >= 60 then
			word = ("%s %dm"):format(a.word, math.floor(gone / 60))
		end
	end
	if a.said ~= word then
		a.said = word
		a.text:SetText(word)
	end
end

local counting = setmetatable({}, { __mode = "k" })
local afkTicker = nil

local function CountAfk()
	for a in pairs(counting) do
		if a.since ~= nil then
			AfkWord(a)
		else
			counting[a] = nil
		end
	end
	if next(counting) == nil and afkTicker ~= nil then
		pcall(afkTicker.Cancel, afkTicker)
		afkTicker = nil
	end
end

local function Counting(a)
	counting[a] = a.since ~= nil or nil
	if a.since ~= nil and afkTicker == nil and type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
		local ok, ticker = pcall(C_Timer.NewTicker, AFK_EVERY, function()
			X.run(AFK, CountAfk)
		end)
		afkTicker = ok and ticker or nil
	end
end

local function AfkFades(text)
	local ok, fadeIn, fadeOut = pcall(function()
		local come = text:CreateAnimationGroup()
		local rise = come:CreateAnimation("Alpha")
		rise:SetFromAlpha(0)
		rise:SetToAlpha(1)
		rise:SetDuration(AFK_IN)
		local go = text:CreateAnimationGroup()
		local fall = go:CreateAnimation("Alpha")
		fall:SetFromAlpha(1)
		fall:SetToAlpha(0)
		fall:SetDuration(AFK_OUT)
		pcall(go.SetToFinalAlpha, go, true)
		go:SetScript("OnFinished", function()
			text:Hide()
			text:SetAlpha(1)
		end)
		return come, go
	end)
	if ok then
		return fadeIn, fadeOut
	end
	return nil, nil
end

local function SetAway(a, away, fade)
	if a.away == away then
		return
	end
	a.away = away
	local text, fadeIn, fadeOut = a.text, a.fadeIn, a.fadeOut
	if fadeIn and fadeIn:IsPlaying() then
		pcall(fadeIn.Stop, fadeIn)
	end
	if away then
		if fadeOut and fadeOut:IsPlaying() then
			pcall(fadeOut.Stop, fadeOut)
		end
		AfkWord(a)
		text:SetAlpha(1)
		text:Show()
		if fadeIn then
			pcall(fadeIn.Play, fadeIn)
		end
	else
		if not (fade and fadeOut and text:IsShown()) then
			if fadeOut and fadeOut:IsPlaying() then
				pcall(fadeOut.Stop, fadeOut)
			end
			text:Hide()
			text:SetAlpha(1)
		elseif not fadeOut:IsPlaying() and not pcall(fadeOut.Play, fadeOut) then
			text:Hide()
		end
	end
end

local function ShowAfk(a)
	if a.unit == nil then
		a.since = nil
		SetAway(a, false, false)
		Counting(a)
		return
	end
	local flag, shows = Away(a.unit)
	if flag == nil then
		return
	end
	a.since = flag and (a.since or Now()) or nil
	SetAway(a, shows, true)
	Counting(a)
end

local function ListenAfk(a, unit)
	if a.unit == unit then
		return
	end
	pcall(a.ear.UnregisterAllEvents, a.ear)
	a.unit = unit
	a.since = nil
	SetAway(a, false, false)
	Counting(a)
	if unit == nil then
		return
	end
	for _, event in ipairs(AFK_EVENTS) do
		local ok = type(a.ear.RegisterUnitEvent) == "function" and pcall(a.ear.RegisterUnitEvent, a.ear, event, unit)
		if not ok then
			pcall(a.ear.RegisterEvent, a.ear, event)
		end
	end
end

local AFK_RAID_UP = 3

local function PlaceAfk(rec)
	local a = rec.afk
	if rec.kind == "raid" then
		local status = X.path(rec.frame, "statusText")
		local to = status or rec.frame
		if a.to == to then
			return true
		elseif InCombatLockdown() then
			return false
		end
		a.text:ClearAllPoints()
		if status ~= nil then
			a.text:SetPoint("CENTER", status, "CENTER", 0, 0)
		else
			a.text:SetPoint("BOTTOM", rec.frame, "BOTTOM", 0, AFK_RAID_UP)
		end
		a.to, a.onBar = to, false
		return true
	end
	local to = MarkerSpot(rec)
	local onBar = to ~= nil and to == HealthBar(rec)
	if to == nil or (a.to == to and a.onBar == onBar) then
		return true
	elseif InCombatLockdown() then
		return false
	end
	a.text:ClearAllPoints()
	if onBar then
		a.text:SetPoint("LEFT", to, "LEFT", 2, 0)
	else
		a.text:SetPoint("BOTTOM", to, "BOTTOM", 0, 2)
	end
	a.to, a.onBar = to, onBar
	return true
end

local function StatusSize(rec, a)
	local status = X.path(rec.frame, "statusText")
	if status == nil or a.base == nil then
		return nil
	end
	local ok, _, size = pcall(status.GetFont, status)
	if ok and ns.Finite(size) and size > 0 then
		return math.max(50, math.min(200, size / a.base * 100))
	end
	return nil
end

local function StyleAfk(a, rec)
	local percent = rec.kind == "raid" and (StatusSize(rec, a) or 100) or tonumber(Opt("smallTextSize")) or 100
	local spec = { percent = percent }
	if type(X.ownSpec) == "function" then
		spec = X.ownSpec("bar", spec)
	end
	if spec.flags == nil then
		spec.flags = "OUTLINE"
	end
	spec.r, spec.g, spec.b = AFK_GREY, AFK_GREY, AFK_GREY
	ns.TextStyle(a.text, spec)
end

local function MakeAfk(rec)
	local text = ns.OwnText(Holder(rec), "OVERLAY", "GameFontNormalSmall")
	if text == nil then
		return nil
	end
	local word = type(_G.AFK) == "string" and not IsSecret(_G.AFK) and _G.AFK ~= "" and _G.AFK or "AFK"
	text:SetText(word)
	text:SetTextColor(AFK_GREY, AFK_GREY, AFK_GREY)
	text:Hide()
	local ear = Own(CreateFrame("Frame"))
	local okFont, _, base = pcall(text.GetFont, text)
	local a = { text = text, ear = ear, word = word, said = word, base = okFont and ns.Finite(base) and base > 0 and base or nil }
	a.fadeIn, a.fadeOut = AfkFades(text)
	ear:SetScript("OnEvent", function()
		X.run(AFK, ShowAfk, a)
	end)
	rec.afk = a
	PlaceAfk(rec)
	return a
end

local AFK_ROWS = { party = "partyAfk", raid = "raidAfk" }

local function Afk(rec, on)
	local row = AFK_ROWS[rec.kind]
	if row == nil then
		return
	end
	local a = rec.afk
	if not (on and rec.made and not ns.PartStopped(KEY, AFK) and Opt(row) == true and type(_G.UnitIsAFK) == "function") then
		if a then
			ListenAfk(a, nil)
		end
		return
	end
	if a == nil then
		if InCombatLockdown() then
			AfterFight(rec, "afkQueued", AFK, Afk)
			return
		end
		a = MakeAfk(rec)
		if a == nil then
			return
		end
	elseif not PlaceAfk(rec) then
		AfterFight(rec, "afkQueued", AFK, Afk)
	end
	StyleAfk(a, rec)
	ListenAfk(a, X.unitOf(rec))
	ShowAfk(a)
end

local function FollowAfk(rec)
	if rec.afk ~= nil and not PlaceAfk(rec) then
		AfterFight(rec, "afkQueued", AFK, Afk)
	end
end

local function LeaderSide(rec)
	local role = X.path(rec.frame, "roleIcon")
	if role ~= nil and X.ask(role, "GetPoint", 1) == "TOPRIGHT" then
		return "TOPLEFT", LEAD_IN
	end
	return "TOPRIGHT", -LEAD_IN
end

local function PlaceLeader(rec)
	local l = rec.leader
	local point, x = LeaderSide(rec)
	if l.point == point then
		return true
	elseif InCombatLockdown() then
		return false
	end
	for _, icon in ipairs(l.icons) do
		icon:ClearAllPoints()
		icon:SetPoint(point, rec.frame, point, x, -LEAD_DOWN)
	end
	l.point = point
	return true
end

local function MakeLeader(rec)
	local holder = Holder(rec)
	local function Icon(sublevel)
		local icon = Own(holder:CreateTexture(nil, "OVERLAY", nil, sublevel))
		icon:SetSize(LEAD, LEAD)
		icon:SetAlpha(0)
		icon:Hide()
		return icon
	end
	local l = { assistant = Icon(5), leader = Icon(6) }
	l.icons = { l.assistant, l.leader }
	if not (AtlasExists(LEADER_ATLAS) and pcall(l.leader.SetAtlas, l.leader, LEADER_ATLAS)) then
		l.leader:SetTexture(LEADER_FILE)
	end
	l.assistant:SetTexture(ASSISTANT_FILE)
	rec.leader = l
	PlaceLeader(rec)
	return l
end

local function Leader(rec, on)
	if rec.kind ~= "raid" then
		return
	end
	local l = rec.leader
	if not (on and rec.made and not ns.PartStopped(KEY, LEADER) and Opt("raidLeaderIcon") == true and type(_G.UnitIsGroupLeader) == "function") then
		if l then
			l.leader:Hide()
			l.assistant:Hide()
		end
		Say(NOTE_LEAD, rec, false)
		return
	end
	if l == nil then
		if InCombatLockdown() then
			AfterFight(rec, "leaderQueued", LEADER, Leader)
			return
		end
		l = MakeLeader(rec)
	elseif not PlaceLeader(rec) then
		AfterFight(rec, "leaderQueued", LEADER, Leader)
	end
	local unit = X.unitOf(rec)
	local lead, help = nil, nil
	if unit ~= nil then
		lead = FromAnswer(l.leader, _G.UnitIsGroupLeader, unit)
		help = FromAnswer(l.assistant, _G.UnitIsGroupAssistant, unit)
	else
		pcall(l.leader.SetAlpha, l.leader, 0)
		pcall(l.assistant.SetAlpha, l.assistant, 0)
	end
	l.leader:Show()
	l.assistant:Show()
	Say(NOTE_LEAD, rec, lead == false or help == false)
end

local function AimMargin(rec)
	local t = ns.Pixels(rec.frame, ns.Get("general.thickness"))
	return (ns.Finite(t) and t or 1) + 1
end

local function MakeAim(rec)
	local frame = rec.frame
	local ok, level = pcall(frame.GetFrameLevel, frame)
	local box = X.frame(frame, ok and X.number(level) and level + 1 or nil)
	local placed = X.cover(rec, box, AimMargin(rec))
	box:SetAlpha(0)
	local outline = ns.Outline(box, box)
	if outline == nil then
		box:Hide()
		return nil
	end
	ns.KeepOutline(outline)
	ns.SetOutline(outline, true, false)
	rec.aim = { box = box, outline = outline, placed = placed }
	return rec.aim
end

local function PlaceAim(rec)
	local a = rec.aim
	if a ~= nil then
		a.placed = X.cover(rec, a.box, AimMargin(rec), a.placed)
	end
end

local function Aim(rec, on)
	if rec.kind ~= "party" then
		return
	end
	local a = rec.aim
	if not (on and rec.made and not ns.PartStopped(KEY, AIM) and Opt("targetBorder") == "own" and type(_G.UnitIsUnit) == "function") then
		if a then
			a.box:Hide()
		end
		Say(NOTE_AIM, rec, false)
		return
	end
	if a == nil then
		if InCombatLockdown() then
			AfterFight(rec, "aimQueued", AIM, Aim)
			return
		end
		a = MakeAim(rec)
		if a == nil then
			return
		end
	end
	ns.SetOutlineColour(a.outline, ns.Colour(KEY .. ".targetColour"))
	local unit = X.unitOf(rec)
	local set = nil
	if unit ~= nil then
		set = FromAnswer(a.box, _G.UnitIsUnit, unit, "target")
	else
		pcall(a.box.SetAlpha, a.box, 0)
	end
	a.box:Show()
	Say(NOTE_AIM, rec, set == false)
end

local function GroupChanged()
	for _, rec in pairs(X.records) do
		if rec.leader then
			X.run(LEADER, Leader, rec, X.active(rec))
		end
		if rec.aim then
			X.run(AIM, Aim, rec, X.active(rec))
		end
	end
end

ns.AddEvent(KEY, "GROUP_ROSTER_UPDATE", GroupChanged)
ns.AddEvent(KEY, "PARTY_LEADER_CHANGED", GroupChanged)
ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	Retarget("target")
	for _, rec in pairs(X.records) do
		if rec.aim then
			X.run(AIM, Aim, rec, X.active(rec))
		end
	end
end)
ns.AddEvent(KEY, "PLAYER_FOCUS_CHANGED", function()
	Retarget("focus")
end)

local wasUnit = X.unitChanged
function X.unitChanged(rec)
	if wasUnit ~= nil then
		wasUnit(rec)
	end
	if rec.dispel then
		X.run(DISPEL, Dispel, rec, X.active(rec))
	end
	if rec.marker then
		X.run(MARKER, Marker, rec, X.active(rec))
	end
	if rec.aim then
		X.run(AIM, Aim, rec, X.active(rec))
	end
	if rec.rezIcon then
		X.run(REZ, Rez, rec, X.active(rec))
	end
	if rec.afk then
		X.run(AFK, Afk, rec, X.active(rec))
	end
end

ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.IsStopped(KEY) then
		return {}
	end
	local rims, aims, group = 0, 0, false
	for _, rec in pairs(X.records) do
		group = group or (rec.made == true and (rec.kind == "party" or rec.kind == "raid"))
		if rec.dispel and rec.dispel.rim then
			rims = rims + 1
		end
		if rec.aim and X.ask(rec.aim.box, "IsShown") == true then
			aims = aims + 1
		end
	end
	local lines = {}
	if rims > 0 then
		lines[#lines + 1] = ("Dispel border: on %d %s now"):format(rims, rims == 1 and "frame" or "frames")
	end
	if group then
		local aim = Opt("targetBorder")
		if aim == "own" then
			lines[#lines + 1] = ("Border for your target: own colour, with an outline ready on %d party %s"):format(aims, aims == 1 and "frame" or "frames")
		else
			lines[#lines + 1] = "Border for your target: " .. (aim == "off" and "off" or "as the game has it")
		end
	end
	return lines
end)

table.insert(X.after.apply, { part = DISPEL, fn = Dispel })
table.insert(X.after.apply, { part = MARKER, fn = Marker })
table.insert(X.after.apply, { part = LEADER, fn = Leader })
table.insert(X.after.apply, { part = AIM, fn = Aim })
table.insert(X.after.apply, { part = REZ, fn = Rez })
table.insert(X.after.apply, { part = AFK, fn = Afk })
table.insert(X.after.raid, { part = DISPEL, fn = Dispel })
table.insert(X.after.raid, { part = MARKER, fn = Marker })
table.insert(X.after.raid, { part = LEADER, fn = Leader })
table.insert(X.after.raid, { part = AFK, fn = Afk })
table.insert(X.after.picture, { part = MARKER, fn = Follow })
table.insert(X.after.picture, { part = REZ, fn = FollowRez })
table.insert(X.after.picture, { part = AFK, fn = FollowAfk })
table.insert(X.after.layout, { part = AIM, fn = PlaceAim })
table.insert(X.after.layout, { part = MARKER, fn = Follow })
table.insert(X.after.layout, { part = REZ, fn = FollowRez })
table.insert(X.after.layout, { part = AFK, fn = FollowAfk })
