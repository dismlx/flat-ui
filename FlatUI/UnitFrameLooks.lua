local ADDON_NAME, ns = ...

-- The seven looks of the Looks section of the Unit frames page: health in class and reaction colour, a dark health bar with the colour of what is lost behind it,
-- muted colours, smaller and lighter bar text, no text on the power bar, the soft shade on bars and a shadow behind each frame. The fills, the
-- bar text and the name row of UnitFrames.lua ask this file for their colours (ns.UnitFrameExtra.healthColour, powerColour and mute), and this file adds its
-- work after the steps of that file through ns.UnitFrameExtra: a part that stops on errors counts as off here, and every function can run twice with the same
-- result. The text looks and the soft shade are in UnitFrames.lua and Core.lua, where the text and the fill are set. With Frame style One frame, this file
-- also gives the background of each bar the trough, a strip a little lighter than the plate behind the frame (darker on a light plate), so that an empty
-- bar still reads as a bar, and puts the shadow round the frame's body (ns.UnitFrameExtra.joined and body, UnitFrames.lua). It also draws Highlight under the
-- mouse of the Frame section of the bars and pictures page: the health bar of the frame under the mouse brightens a little (at the end of this file).

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Looks"

-- Muted colours keep this share of the colour and of the brightness. These numbers are stand-ins until the author picks them.
local MUTE = { colour = 0.65, bright = 0.9 }
-- The grey of the health bar while the colour shows what is lost, and its notes for /flatui status.
local DARK = 0.10
local NOTE = { class = "Looks: Health in class and reaction colour: class withheld on ", lost = "Looks: Dark health bar, colour shows what is lost: needs Background",
	shadow = "Looks: Shadow behind each frame: the game refused the texture" }
-- The trough of a bar in one frame: white at this opacity over the plate, black on a plate at least this light (0.30 red + 0.59 green + 0.11 blue).
-- 8% is a stand-in until the author picks it.
local TROUGH = { alpha = 0.08, light = 0.5 }
-- The shadow: the file, the margins that keep its soft edge at its size, how far it reaches outside the frame in units, and its colour. 8 units at 55% black are
-- stand-ins until the author picks them.
local SHADOW = { file = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Shadow.tga", margin = 16, out = 8, alpha = 0.55 }
-- The frames whose unit changes without the frame being set up again.
local CHANGING = { target = true, focus = true, tot = true, party = true, partypet = true, boss = true }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Off()
	return ns.PartStopped(KEY, PART)
end

-- Notes ------------------------------------------------------------------------------------------------------

-- How many frames say each line, so that a line stays on the status until the last frame that needs it no longer does.
local held = {}

-- Says a line for one frame in one slot, or takes back what the frame said there.
local function Say(rec, slot, text)
	local notes = rec.looksNotes
	if notes == nil then
		notes = {}
		rec.looksNotes = notes
	end
	if notes[slot] == text then
		return
	end
	local old = notes[slot]
	notes[slot] = text
	if old ~= nil then
		held[old] = held[old] - 1
		if held[old] <= 0 then
			held[old] = nil
			ns.ClearNote(KEY, old)
		end
	end
	if text ~= nil then
		held[text] = (held[text] or 0) + 1
		ns.Note(KEY, text)
	end
end

-- Colours ----------------------------------------------------------------------------------------------------

-- A colour at part of its colour and of its brightness: the grey of the same lightness and the colour between that grey and this one. Unchanged while
-- Muted colours is off.
function X.mute(r, g, b)
	if r == nil or Opt("lookMuted") ~= true or Off() then
		return r, g, b
	end
	local light = 0.30 * r + 0.59 * g + 0.11 * b
	local keep, bright = MUTE.colour, MUTE.bright
	return (light + (r - light) * keep) * bright, (light + (g - light) * keep) * bright, (light + (b - light) * keep) * bright
end

-- The class colour of a player and the reaction colour of any other unit on a frame, or nil while the client withholds what decides it. The player and the
-- pet take the class of the player.
local function FrameColour(rec)
	if rec.kind == "player" or rec.kind == "pet" then
		return ns.ClassColour()
	end
	local unit = X.unitOf(rec)
	if unit == nil then
		return nil
	end
	local ok, player = pcall(UnitIsPlayer, unit)
	if not ok or ns.IsSecret(player) or type(player) ~= "boolean" then
		return nil
	end
	if player then
		return ns.ClassColourOf(unit)
	end
	return ns.ReactionColour(unit)
end

-- The colour of the unit of a frame by what its Health bar colour row says: the reaction colour for Reaction, as FrameColour has it for Class.
local function ByColour(rec, by)
	if by == "reaction" then
		local unit = X.unitOf(rec)
		if unit == nil then
			return nil
		end
		return ns.ReactionColour(unit)
	end
	return FrameColour(rec)
end

-- True while the frame is coloured by its unit: Health bar colour of the frame is Class or Reaction, or Health in class and reaction colour is on.
local function ByUnit(rec)
	return Opt("lookClassHealth") == true or X.healthBy(rec) ~= nil
end

local function Key(r, g, b)
	return r ~= nil and ("%.3f:%.3f:%.3f"):format(r, g, b) or "none"
end

-- The fill of a bar's background while the frame is one frame: the trough, white at a little opacity over the plate, or black when the plate is light.
-- Nil, which gives the bar the general background again, while the frame is not one frame or this part is off. The plate's colour is the one
-- UnitFrames.lua paints (ns.UnitFrameExtra.backColour).
local function Trough(rec)
	if Off() or type(X.joined) ~= "function" or type(X.backColour) ~= "function" or not X.joined(rec) then
		return nil
	end
	local r, g, b = X.backColour()
	local shade = 1
	if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) and 0.30 * r + 0.59 * g + 0.11 * b >= TROUGH.light then
		shade = 0
	end
	return shade, shade, shade, TROUGH.alpha
end

-- The fill colour of a health bar. Health colour, or the colour of the unit with Health in class and reaction colour, as Muted colours has it. With Dark
-- health bar the fill is dark and the colour is the fill of the bar's border, which shows behind the part of the bar that is empty; without it the bar's
-- background is the trough in one frame, else the general background. A raid frame is not asked: the game colours it. rec.looksKey says which colour of
-- the unit the frame has now.
function X.healthColour(rec, entry)
	local r, g, b = ns.Colour(KEY .. ".healthColour")
	local live = not Off()
	local unit = nil
	if live and ByUnit(rec) then
		local ur, ug, ub = ByColour(rec, X.healthBy(rec))
		unit = Key(ur, ug, ub)
		if ur ~= nil then
			r, g, b = ur, ug, ub
		end
		Say(rec, "class", ur == nil and NOTE.class .. X.labels[rec.kind] or nil)
	else
		Say(rec, "class", nil)
	end
	rec.looksKey = unit
	r, g, b = X.mute(r, g, b)
	local lost = live and Opt("lookLostColour") == true
	-- The fill of the border is the background of the bar: with Background off there is none, and a dark bar would show nothing behind it.
	if lost and Opt("backdrop") ~= true then
		Say(rec, "lost", NOTE.lost)
		lost = false
	else
		Say(rec, "lost", nil)
	end
	if lost then
		if entry ~= nil then
			ns.SetOutlineFill(entry.outline, r, g, b, 1)
		end
		return DARK, DARK, DARK
	end
	if entry ~= nil then
		ns.SetOutlineFill(entry.outline, Trough(rec))
	end
	return r, g, b
end

-- The sky blue of a mana bar next to a blue health bar, and how near two colours must be (red, green, blue distance) to count as the same blue.
local SKY = { 0.35, 0.85, 1.00 }
local NEAR = 0.5

local function Near(r1, g1, b1, r2, g2, b2)
	return (r1 - r2) ^ 2 + (g1 - g2) ^ 2 + (b1 - b2) ^ 2 < NEAR * NEAR
end

-- The fill colour of a power bar. It starts from the colour of its power type on the Colours page (Custom power colours), else the game's. Mana bar colour
-- Sky blue changes a mana bar that is near the colour of the unit its health bar has, unless sky blue is near that colour too. Then as Muted colours has it.
function X.powerColour(rec, entry, r, g, b)
	local token = entry ~= nil and entry.bar ~= nil and entry.bar.powerToken or nil
	local pr, pg, pb = ns.PowerColour(token)
	if pr ~= nil then
		r, g, b = pr, pg, pb
	end
	if token ~= nil and not ns.IsSecret(token) and token == "MANA" and r ~= nil and Opt("manaColour") == "apart" and ByUnit(rec) and not Off()
		and not (Opt("lookLostColour") == true and Opt("backdrop") == true) and not (ns.HealthLeftFrameOn ~= nil and ns.HealthLeftFrameOn(rec)) then
		local hr, hg, hb = ByColour(rec, X.healthBy(rec))
		if hr ~= nil and Near(r, g, b, hr, hg, hb) and not Near(SKY[1], SKY[2], SKY[3], hr, hg, hb) then
			r, g, b = SKY[1], SKY[2], SKY[3]
		end
	end
	return X.mute(r, g, b)
end

-- A frame whose health bar is not flat, or that is not styled, or whose look is off, has the trough in one frame, else the general background, and no line
-- about the look. Gives back what healthColour set. The power bar has no colour of its own behind it, so it takes the trough on every pass.
local function Settle(rec, on)
	if rec.kind == "raid" then
		return
	end
	local live = on and Opt("flat") == true and not Off()
	if not (live and ByUnit(rec)) then
		Say(rec, "class", nil)
		rec.looksKey = nil
	end
	if not (live and Opt("lookLostColour") == true) then
		Say(rec, "lost", nil)
		local entry = rec.byRole.health
		if entry ~= nil then
			ns.SetOutlineFill(entry.outline, Trough(rec))
		end
	end
	local power = rec.byRole.power
	if power ~= nil then
		ns.SetOutlineFill(power.outline, Trough(rec))
	end
end

-- The unit of a frame changed: the colour of the new unit is put on the bar, once the colour of the unit is not the one on the bar.
local function Changed(rec)
	if not CHANGING[rec.kind] or not rec.made or rec.byRole.health == nil or Off() then
		return
	end
	if (not ByUnit(rec) and Opt("lookLostColour") ~= true) or Opt("flat") ~= true or not X.active(rec) then
		return
	end
	local unit = nil
	if ByUnit(rec) then
		unit = Key(ByColour(rec, X.healthBy(rec)))
	end
	if unit ~= rec.looksKey then
		X.run(X.labels[rec.kind], X.apply, rec)
	end
end

function X.unitChanged(rec)
	X.run(PART, Changed, rec)
end

function X.unitsChanged()
	for _, rec in pairs(X.records) do
		X.run(PART, Changed, rec)
	end
end

-- The shadow ------------------------------------------------------------------------------------------------

-- Keeps the middle of a texture stretching and its edges at their size. False when the client lacks either call or refuses it.
local function SliceShadow(texture)
	if type(texture.SetTextureSliceMargins) ~= "function" or type(texture.SetTextureSliceMode) ~= "function" then
		return false
	end
	local modes = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.UITextureSliceMode
	local mode = type(modes) == "table" and modes.Stretched or 0
	local margin = SHADOW.margin
	return pcall(texture.SetTextureSliceMargins, texture, margin, margin, margin, margin) and pcall(texture.SetTextureSliceMode, texture, mode)
end

-- The frame and the texture of the shadow of one frame, one level under the frame's body (UnitFrames.lua makes it), or under the frame itself where there is
-- none, so it is behind the plate and the bars. A level of 0 stays 0. False when the game refuses the texture.
local function Make(rec)
	local under = type(X.body) == "function" and X.body(rec) or nil
	if under == nil then
		under = rec.frame
	end
	local ok, level = pcall(under.GetFrameLevel, under)
	local box = X.frame(rec.frame, ok and X.number(level) and math.max(0, level - 1) or nil)
	local texture = X.layer(box, "BACKGROUND", -8, true)
	rec.shadowBox, rec.shadowTexture = box, texture
	local out = SHADOW.out
	texture:SetPoint("TOPLEFT", box, "TOPLEFT", -out, out)
	texture:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", out, -out)
	if pcall(texture.SetTexture, texture, SHADOW.file) and SliceShadow(texture) and pcall(texture.SetVertexColor, texture, 0, 0, 0, SHADOW.alpha) then
		texture:Show()
		return true
	end
	return false
end

-- Puts the box round the frame. In one frame it is the frame's body, and rec.shadowAt is "body". Otherwise its left edge is the picture's on a frame with the
-- picture on the left, its right edge the picture's on a frame with the picture on the right (a target or focus), and the edges of the health bar's slot
-- where there is no picture; its top is the name row's, or the slot's, and its bottom the power bar's, or the slot's. A point each way, on regions of the game
-- and of the addon's own frames. Out of combat only, since the regions are protected.
local function Place(rec)
	local box, parts, pic, row, power = rec.shadowBox, rec.parts, rec.pic, rec.row, rec.byRole.power
	local body = type(X.joined) == "function" and type(X.body) == "function" and X.joined(rec) and X.body(rec) or nil
	if body ~= nil then
		if rec.shadowAt ~= "body" then
			box:ClearAllPoints()
			box:SetAllPoints(body)
			rec.shadowAt = "body"
		end
		return
	end
	local slot = parts.healthBox or parts.health
	local drawn = pic ~= nil and pic.drawn == true
	local at = { drawn and parts.side == "left" and pic.frame or slot, drawn and parts.side == "right" and pic.frame or slot,
		row ~= nil and X.rowOn(rec) and row.frame or slot, power ~= nil and power.bar or slot }
	-- A box that was the body, or not placed yet, is placed again.
	local was = rec.shadowAt
	if type(was) == "table" and was[1] == at[1] and was[2] == at[2] and was[3] == at[3] and was[4] == at[4] then
		return
	end
	box:ClearAllPoints()
	box:SetPoint("LEFT", at[1], "LEFT", 0, 0)
	box:SetPoint("RIGHT", at[2], "RIGHT", 0, 0)
	box:SetPoint("TOP", at[3], "TOP", 0, 0)
	box:SetPoint("BOTTOM", at[4], "BOTTOM", 0, 0)
	rec.shadowAt = at
end

local Shadow
function Shadow(rec, on)
	if rec.kind == "raid" or not rec.made then
		return
	end
	local want = on and Opt("lookShadow") == true and not Off()
	if want and rec.shadowBox == nil and not rec.shadowFailed then
		if InCombatLockdown() then
			if not rec.shadowQueued then
				rec.shadowQueued = true
				ns.OutOfCombat(function()
					rec.shadowQueued = nil
					X.run(PART, Shadow, rec, X.active(rec))
				end)
			end
			return
		end
		if not Make(rec) then
			rec.shadowFailed = true
			Say(rec, "shadow", NOTE.shadow)
		end
	end
	local box = rec.shadowBox
	if box == nil then
		return
	end
	if want and not rec.shadowFailed and not InCombatLockdown() then
		Place(rec)
	end
	box:SetShown(want and not rec.shadowFailed and rec.shadowAt ~= nil)
end

-- The layout of a frame is done again, out of combat, with the same regions or others: the shadow follows.
local function Follow(rec)
	Shadow(rec, X.active(rec))
end

-- Highlight under the mouse ---------------------------------------------------------------------------------

-- Highlight under the mouse (on by default): a white layer of the addon's own, added to the colours under it (blend mode ADD) at HOVER.alpha, on a frame of
-- its own one level above the health bar and over the outlined bar, on each styled frame, raid frames too. The game binds UnitFrame_OnEnter in the XML of its
-- frames (Mainline/PlayerFrame.xml:471, TargetFrame.xml:370, Shared/CompactUnitFrame.xml:105), so a hook on the global would miss them, and the game's
-- scripts are not touched: a frame of the addon's own reads the frame under the mouse (GetMouseFoci, as Movers.lua does) every HOVER.every seconds while the
-- row is on and a layer is made, walks up at most HOVER.steps parents to a frame this module knows, shows that frame's layer and hides the last one. The
-- layers are made out of combat; in a fight only Show and Hide change. A layer has the shape of its bar: the rounded rectangle of Corners (UnitFrames.lua
-- Shape, the file of the radius, sliced) while the record's bars are rounded in Separate parts, else the crisp square, so no corner outside a rounded
-- border lights up; it is shaped again on the pass after Corners changes, out of combat. The stand-ins of test mode take no mouse, so they show none.
-- The pet target frame (UnitPetTarget.lua) has no record and lights its own layer by the same amount (X.hoverAlpha).
local HOVER_PART = "Mouse highlight"
local HOVER = { alpha = 0.12, every = 0.05, steps = 6, file = "Interface\\Buttons\\WHITE8X8" }
X.hoverAlpha = HOVER.alpha
-- made: the records with a layer. lit: the record whose layer shows. on: the driver runs. waited: the time since the last read.
local hover = { made = setmetatable({}, { __mode = "k" }), waited = 0 }

local function HoverOn(rec)
	return rec.made == true and Opt("hoverHighlight") == true and X.active(rec) and not ns.PartStopped(KEY, HOVER_PART)
end

-- The record of the frame under the mouse, or of the nearest of its parents this module knows, or nil.
local function Under()
	local ok, foci = pcall(GetMouseFoci)
	local frame = ok and type(foci) == "table" and not ns.IsSecret(foci) and foci[1] or nil
	for _ = 0, HOVER.steps do
		if frame == nil or ns.IsSecret(frame) or type(frame) ~= "table" then
			return nil
		end
		local rec = X.known(frame)
		if rec ~= nil then
			return rec
		end
		local okParent, parent = pcall(frame.GetParent, frame)
		frame = okParent and parent or nil
	end
	return nil
end

-- Shows the layer of one record, or of none, and hides the one that showed.
local function Light(rec)
	if rec == hover.lit then
		return
	end
	if hover.lit ~= nil and hover.lit.hoverFrame ~= nil then
		hover.lit.hoverFrame:Hide()
	end
	hover.lit = rec
	if rec ~= nil then
		rec.hoverFrame:Show()
	end
end

local Drive

local function Look()
	Drive()
	if not hover.on then
		return
	end
	local rec = Under()
	if rec ~= nil and (rec.hoverFrame == nil or not HoverOn(rec)) then
		rec = nil
	end
	Light(rec)
end

local function OnUpdate(_, elapsed)
	hover.waited = hover.waited + elapsed
	if hover.waited < HOVER.every then
		return
	end
	hover.waited = 0
	X.run(HOVER_PART, Look)
end

-- The driver runs while the row is on and a layer is made; when it stops, the layer that showed goes.
function Drive()
	local want = Opt("hoverHighlight") == true and ns.Enabled(KEY) and not ns.PartStopped(KEY, HOVER_PART) and next(hover.made) ~= nil
	if want == (hover.on == true) then
		return
	end
	hover.on = want
	if want and hover.driver == nil then
		hover.driver = X.frame(nil)
	end
	if hover.driver ~= nil then
		hover.driver:SetScript("OnUpdate", want and OnUpdate or nil)
	end
	if not want then
		Light(nil)
	end
end

-- The frame and the layer of one record, out of combat: a child of the health bar, so one level above it, on the points of the outlined bar.
local function MakeHover(rec)
	local entry = rec.byRole.health
	local box = entry and entry.target
	if box == nil or ns.Forbidden(box) or ns.Forbidden(entry.bar) then
		return
	end
	local frame = X.frame(entry.bar)
	frame:SetAllPoints(box)
	frame:Hide()
	local layer = X.layer(frame, "OVERLAY", 7)
	layer:SetTexture(HOVER.file)
	layer:SetBlendMode("ADD")
	layer:SetVertexColor(1, 1, 1, HOVER.alpha)
	layer:Show()
	rec.hoverFrame, rec.hoverLayer = frame, layer
	hover.made[rec] = true
end

-- The layer in the shape of the bar: the radius of the record's corners while they are rounded in Separate parts, else the crisp square (the plain
-- white file while the client refuses the slicing). Only when that changed, and out of combat.
local function HoverShape(rec)
	local layer = rec.hoverLayer
	local radius = not rec.joined and rec.radius or nil
	if layer == nil or rec.hoverRadius == (radius or 0) or InCombatLockdown() then
		return
	end
	rec.hoverRadius = radius or 0
	if type(X.shape) ~= "function" or not X.shape(layer, radius) then
		pcall(layer.SetTexture, layer, HOVER.file)
	end
	layer:SetBlendMode("ADD")
	layer:SetVertexColor(1, 1, 1, HOVER.alpha)
end

local Hover
function Hover(rec, on)
	local want = on and HoverOn(rec)
	if want and rec.hoverFrame == nil then
		if InCombatLockdown() then
			if not rec.hoverQueued then
				rec.hoverQueued = true
				ns.OutOfCombat(function()
					rec.hoverQueued = nil
					X.run(HOVER_PART, Hover, rec, X.active(rec))
				end)
			end
			return
		end
		MakeHover(rec)
	end
	if want then
		HoverShape(rec)
	end
	if not want and hover.lit == rec then
		Light(nil)
	end
	Drive()
end

table.insert(X.after.apply, { part = PART, fn = Settle })
table.insert(X.after.apply, { part = PART, fn = Shadow })
table.insert(X.after.apply, { part = HOVER_PART, fn = Hover })
table.insert(X.after.raid, { part = HOVER_PART, fn = Hover })
table.insert(X.after.layout, { part = PART, fn = Follow })
