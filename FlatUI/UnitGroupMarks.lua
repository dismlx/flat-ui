local _, ns = ...

-- Marks on the game's party and raid frames: the colour of a debuff the player can dispel on a border just inside the health bar, with the icon of its
-- type on a party frame, and the raid marker of the unit of a raid frame. All are textures of the addon's own on a frame of its own over the game's
-- frame, made and anchored out of combat; in a fight only their colour, opacity and visibility change.
--
-- What the player can dispel is the client's own aura filter HARMFUL|RAID: "harmful auras the player can dispel" (Blizzard_FrameXMLUtil/
-- AuraUtil.lua:275), which the game's party frames (Shared/PartyMemberFrame.lua:143) and raid frames (Blizzard_PrivateAurasUI.lua:486) use for their
-- own dispel debuffs. Forever also has DISPELLABLE, but that token is "dispellable, regardless of whether the player's raid can dispel them"
-- (AuraUtil.lua:287), so it is not used. C_UnitAuras.GetAuraSlots carries no secret predicate (UnitAuraDocumentation.lua:303-322), so whether a
-- member has such a debuff is a plain answer in a fight too. Its type may be withheld (GetAuraDataBySlot is SecretWhenUnitAuraRestricted, :226-243):
-- it is never read then. GetAuraDispelTypeColor maps the type of the aura to a colour through a step curve of the addon's own (:263-285), and the
-- colour goes as it is to SetVertexColor, which takes withheld values (SimpleRegionAPIDocumentation.lua:191-203) on a texture with an image file,
-- as HealthColour.lua does with its curve. The four type icons of a party frame lie on one spot, each with a curve of its own whose opacity is 1 at
-- its type alone, so the one of the debuff's type is the one that shows, whatever the game withholds. The aura is the first the filter gives. Where
-- the instance ID of the aura is withheld the border is white and no icon shows; /flatui status says so. The game's raid frames draw their own type
-- icons and overlay for dispellable debuffs (raidFramesDispelIndicatorType, Blizzard_PrivateAurasUI.lua:421-435, 650-688), so the icon is on party
-- frames only. Each frame hears UNIT_AURA for its own unit on a frame of the addon's own (RegisterUnitEvent), so the payload, which the game may
-- withhold (UnitAuraDocumentation.lua:644-655), is never read; a burst is read once, a moment after the first. A frame the game hid hears nothing until
-- the game draws it again.
--
-- The game's raid frames have no raid marker (Shared/CompactUnitFrame.xml:3-111). The game gives the index of a marker to addons only withheld
-- (GetRaidTargetIndex, RaidMarkersDocumentation.lua:55-69, SecretReturns), and SetSpriteSheetCell takes a withheld index (SimpleTextureBaseAPIDocumentation
-- .lua:565-578), as the game's own SetRaidTargetIconTexture hands it on (Mainline/TargetFrame.lua:697-701). The index is never read: the icon shows
-- only when the game took it, and a unit with no marker answers nothing, which the call does not take (its cell is not nilable). RAID_TARGET_UPDATE
-- draws the markers again.
--
-- The ready check and the aggro highlight are the game's own on its raid frames (CompactUnitFrame.lua:907-932, 1366-1446): Flat UI keeps the
-- ready check as it is and already gives the colour of the aggro highlight to the health bar border (Threat border, UnitFrames.lua). That border,
-- just outside the bar, also has the colour of the target on a raid frame and of the top debuff on a party frame (UnitFrames.lua:1480-1497), and the
-- game's own outlines for aggro and the target are faded under it (UnitFrames.lua:332-336, 2293-2295, 2302), so the dispel border lies inside the
-- bar and never over it. The game too keeps its dispel overlay, a frame of its own (Blizzard_PrivateAurasUI.lua:841-846,
-- Blizzard_PrivateAurasUI.xml:33-41), apart from the textures of its aggro and target outlines (Shared/CompactUnitFrame.xml:46-51).
-- This follows EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLUnitFrames/UF_GroupFrames.lua:8833-8862, 11626-11780;
-- UF_GroupFrames_Helper.lua:1990-2077): its dispel tint by a step colour curve over GetAuraDispelTypeColor and its raid icon on group frames, drawn
-- here on the game's frames. Its own group frames, glows, overlays and the filter token are left out, as said above.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local DISPEL, MARKER = "Dispel highlight", "Raid frame marker"
local FILTER = "HARMFUL|RAID"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MARKER_FILE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
-- The thickness of the border in screen pixels, the size of a type icon and of a raid marker in units, and the wait before a burst of events is read.
local RIM_PX, ICON, MARK, SOON = 2, 12, 14, 0.1
-- The dispel types, the number the game gives each (the x of the curves), and their colours: the game's DEBUFF_TYPE colours (AuraUtil.lua:4-10), as
-- Hud.lua has them. A debuff whose type the game withholds with its instance ID has the border in white.
local TYPES = { "Magic", "Curse", "Disease", "Poison" }
local TYPE_ID = { Magic = 1, Curse = 2, Disease = 3, Poison = 4 }
local COLOURS = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 } }
local UNKNOWN = { 1, 1, 1 }
local LAST_ID = 5
local ATLAS = "RaidFrame-Icon-Debuff"
local NOTE_BLIND = "Unit frames: Dispel highlight: the game would not say which debuffs a member has, so no border shows."
local NOTE_TYPE = "Unit frames: Dispel highlight: the game withheld the type of a debuff you can dispel, so its border is white."

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

-- A field of a table the game gave, or nil when it is missing, cannot be read or is withheld.
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

-- A line for /flatui status while what it says holds for any frame: per line, the frames it holds for.
local saying = { [NOTE_BLIND] = setmetatable({}, { __mode = "k" }), [NOTE_TYPE] = setmetatable({}, { __mode = "k" }) }

local function Say(text, rec, on)
	saying[text][rec] = on or nil
	if next(saying[text]) ~= nil then
		ns.Note(KEY, text)
	else
		ns.ClearNote(KEY, text)
	end
end

-- A frame that shows nothing has nothing to say.
local function Quiet(rec)
	Say(NOTE_BLIND, rec, false)
	Say(NOTE_TYPE, rec, false)
end

-- The unit a frame shows: the one a raid frame displays (a vehicle), else its own.
local function UnitOfFrame(rec)
	local shown = Field(rec.frame, "displayedUnit")
	if type(shown) == "string" and shown ~= "" then
		return shown
	end
	return X.unitOf(rec)
end

-- Debuffs you can dispel ------------------------------------------------------------------------------------------------------------------------

-- The curves: one for the colour of the border, and one for each type icon, white (or the colour of the type, for a client without the icon art)
-- with an opacity of 1 at its own type and 0 at every other. Made once; false when the client has no curves or refuses them.
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

-- A colour the game gave, onto a texture: its numbers go as they are, withheld or not. False when the client refuses.
local function Tint(texture, colour)
	if colour == nil or IsSecret(colour) or type(colour) ~= "table" then
		return false
	end
	return (pcall(function()
		texture:SetVertexColor(colour:GetRGBA())
	end))
end

-- The colour the game gives an aura through a curve, or nil.
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

-- True when the client has the calls that read the debuffs of a unit by slot. Without them nothing is made.
local function Readable()
	local units = C_UnitAuras
	return type(units) == "table" and not IsSecret(units) and type(units.GetAuraSlots) == "function" and type(units.GetAuraDataBySlot) == "function"
end

-- The first debuff on a unit that the player can dispel: nil for none, false when the game would not say, else its instance ID (a plain number) or
-- true for one whose ID is withheld, and the aura the game gave.
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
		-- There is one, and the game would not give it.
		return true, nil
	elseif aura == nil then
		-- The slot went between the two calls (AuraUtil.lua:100): nothing is there now.
		return nil
	end
	local id = Field(aura, "auraInstanceID")
	if ns.Finite(id) then
		return id, aura
	end
	return true, aura
end

-- The border, four edges of an image file just inside the slot of the health bar, and on a party frame the four type icons at the right end of
-- the bar, a sublevel over the edges, which cross them. Made out of combat, as a child of the slot, above the outline of Flat UI.
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
		-- Not snapped, as the edges of the outline are not (Edge, Core.lua): snapping could move an edge a pixel onto the outline.
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
	rec.dispel = d
	return d
end

-- The edges, in the thickness of the border in screen pixels, laid out again out of combat when that thickness changed. They lie inside the slot:
-- Flat UI's outline lies just outside it on a frame under this one (PlaceEdgesNow, Core.lua) and keeps its colour of threat or the target.
-- Inside the bar the edges also stay inside a raid frame, whose bar is 1 unit in from its edges (Shared/CompactUnitFrame.lua:1906-1907), while
-- raid frames touch (Shared/CompactRaidGroup.lua:113, 142). A type icon sits 1 unit left of the right edge, over the top and bottom edges.
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
	for _, edge in ipairs(d.edges) do
		edge:Hide()
	end
	for _, icon in pairs(d.icons or {}) do
		icon:Hide()
	end
end

-- The rows that apply to a frame now: the border, and the icon on a party frame.
local function Wanted(rec, on)
	if not on or not rec.made or ns.PartStopped(KEY, DISPEL) or not Readable() then
		return false, false
	end
	return Opt("dispelBorder") == true, rec.kind == "party" and Opt("dispelIcon") == true
end

-- The icon of a type whose name the game gave, or none.
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
				-- The game would not map this aura: the icon of a type it named, or none.
				PlainIcon(d, name)
				return
			end
		end
	end
end

-- True when the game hid the frame itself: a party frame in a raid or beside raid-style party frames, which keeps its party unit and the game's
-- UNIT_AURA for it (PartyMemberFrameMixin:UpdateMember, Mainline/PartyMemberFrame.lua:403, 446-451; Shared/PartyFrame.lua:47-49, 160-169), or a raid
-- frame whose unit is gone (CompactUnitFrame_UpdateVisible, Shared/CompactUnitFrame.lua:520-535). Nothing on it can be seen, so it hears no auras.
-- Each time the game shows a party frame it runs UnitFrame_Update after (Mainline/PartyMemberFrame.lua:463-471, Shared/PartyFrame.lua:64-69, 163-165),
-- and it shows a raid frame only in CompactUnitFrame_UpdateAll (Shared/CompactUnitFrame.lua:435-441); Flat UI follows both to Dispel
-- (UnitFrames.lua:2366-2372, 3105, 3115-3121), which hears the unit again. The frame's own flag is read, not whether it can be seen: the raid frame
-- manager shows the container of the raid frames again with no call Flat UI follows (Blizzard_CompactRaidFrames/Mainline/
-- Blizzard_CompactRaidFrameManager.lua:995-1004, 1027-1032; Blizzard_CompactRaidFrameContainer.lua:80-84).
local function Hidden(rec)
	local ok, shown = pcall(rec.frame.IsShown, rec.frame)
	return ok and not IsSecret(shown) and shown == false
end

local Hear

-- Reads the unit of a frame and draws what it found. A frame with nothing to show, or that the game hid, stops hearing its unit.
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
	local id, aura = First(unit)
	-- The game would not say, or withheld the debuff it has: read again once it stops withholding (Reread, below).
	d.withheld = id == false or id == true
	Say(NOTE_BLIND, rec, id == false)
	if not id then
		Clear(d)
		Say(NOTE_TYPE, rec, false)
		return
	end
	Draw(rec, d, unit, id, aura)
end

-- The frames whose unit changed its debuffs, read together a moment after the first.
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

-- What the game withholds of a debuff ends with the restriction that withholds it: a fight, an encounter, a challenge mode or a PvP match
-- (SecretWhenUnitAuraRestricted, SecretPredicatesDocumentation.lua:80-82). A debuff that stays sends no UNIT_AURA then, so a frame read while it was
-- withheld would keep its white border (or none), its hidden icon and its line in /flatui status until its auras next change. Each such frame is
-- read again when the fight ends, as the game's raid frames and aura containers read all their auras again then (Blizzard_PrivateAurasUI.lua:
-- 542-544, 712-713; Blizzard_CustomAuraContainer.lua:589-605), and when one of those restrictions is over, which the game says once it has ended
-- (ADDON_RESTRICTION_STATE_CHANGED, RestrictedActionsDocumentation.lua:96-107; RestrictedActionsConstantsDocumentation.lua:13, 26-29), for an
-- encounter or a match that outlasts the fight. Both come at the end of a fight, as one burst. A frame read plainly keeps what it shows: read at
-- the end of a fight inside an encounter, it would only be withheld.
local function Reread()
	for _, rec in pairs(X.records) do
		if rec.dispel and rec.dispel.withheld then
			Soon(rec)
		end
	end
end

-- True when a restriction that withholds auras has ended.
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

-- The frame of the addon's own that hears UNIT_AURA for the unit of one game frame, and nothing once it has no unit.
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
	d.unit, d.heard = unit, nil
	if unit == nil then
		return
	end
	if type(ear.RegisterUnitEvent) == "function" then
		local ok, done = pcall(ear.RegisterUnitEvent, ear, "UNIT_AURA", unit)
		d.heard = ok and (IsSecret(done) or done ~= false) or nil
	end
	-- A client that cannot hear one unit: every change of auras reads this frame again.
	if not d.heard then
		d.heard = pcall(ear.RegisterEvent, ear, "UNIT_AURA") or nil
	end
end

local function Dispel(rec, on)
	if rec.kind ~= "party" and rec.kind ~= "raid" then
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
		-- Made out of combat, on a frame the game protects.
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

-- Raid markers -------------------------------------------------------------------------------------------------------------------------------------

local function MakeMarker(rec)
	local frame = rec.frame
	local ok, level = pcall(frame.GetFrameLevel, frame)
	local holder = X.frame(frame, ok and X.number(level) and level + 6 or nil)
	holder:SetAllPoints(frame)
	local icon = Own(holder:CreateTexture(nil, "OVERLAY", nil, 7))
	icon:SetTexture(MARKER_FILE)
	icon:SetSize(MARK, MARK)
	icon:SetPoint("TOP", frame, "TOP", 0, -1)
	icon:Hide()
	rec.marker = { holder = holder, icon = icon }
	return rec.marker
end

-- The cell of the marker on the sheet of the eight icons, 4 by 4 (Mainline/TargetFrame.lua:697-701). True when the icon shows a marker.
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
	if rec.kind ~= "raid" then
		return
	end
	local live = on and rec.made and not ns.PartStopped(KEY, MARKER) and Opt("raidFrameMarker") == true and type(GetRaidTargetIndex) == "function"
	local m = rec.marker
	if not live then
		if m then
			m.icon:Hide()
		end
		return
	end
	if m == nil then
		if InCombatLockdown() then
			if not rec.markerQueued then
				rec.markerQueued = true
				ns.OutOfCombat(function()
					rec.markerQueued = nil
					X.run(MARKER, Marker, rec, X.active(rec))
				end)
			end
			return
		end
		MakeMarker(rec)
	end
	DrawMarker(rec)
end

ns.AddEvent(KEY, "RAID_TARGET_UPDATE", function()
	for _, rec in pairs(X.records) do
		if rec.kind == "raid" and rec.marker then
			X.run(MARKER, Marker, rec, X.active(rec))
		end
	end
end)

-- A frame that has a new unit hears that unit, and is read and marked again.
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
end

-- X.unitsChanged is not followed. UnitFrames.lua runs it for a new target or focus, a new target of either, a change of faction and a change of
-- the group. The first three change neither the debuffs of a member nor its marker: on a new target the game's raid frames redo only their
-- highlight, name, border and widgets (Shared/CompactUnitFrame.lua:79-83), and on UNIT_FACTION its party frames only their PvP icon
-- (Mainline/PartyMemberFrame.lua:657-660). A change of the group reaches every frame through the game's own calls. A raid frame or a raid-style
-- party frame runs CompactUnitFrame_UpdateAll, and so after.raid below, on GROUP_ROSTER_UPDATE (CompactUnitFrame.lua:73-74; CompactRaidGroup.lua:47,
-- CompactPartyFrame.lua:181, Blizzard_CompactRaidFrameContainer.lua:448), when it is given a new unit (CompactUnitFrame.lua:276) and each time it
-- is set up (:313-315), which the raid-style party frame does with all its frames, its pets included, on GROUP_ROSTER_UPDATE (CompactPartyFrame.lua
-- :9, 35-37, 175-209). A party frame runs UnitFrame_Update, and so X.unitChanged above, from UpdateMember on GROUP_ROSTER_UPDATE (Mainline/
-- PartyMemberFrame.lua:446-471, 650-651); one it hides there (:447-450, 472-477) is read again when it shows.
table.insert(X.after.apply, { part = DISPEL, fn = Dispel })
table.insert(X.after.apply, { part = MARKER, fn = Marker })
table.insert(X.after.raid, { part = DISPEL, fn = Dispel })
table.insert(X.after.raid, { part = MARKER, fn = Marker })
