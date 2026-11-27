local ADDON_NAME, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Looks"

local MUTE = { colour = 0.65, bright = 0.9 }
local DARK = 0.10
local NOTE = { class = "Looks: Health in class and reaction colour: class withheld on ", lost = "Looks: Dark health bar, colour shows what is lost: needs Background",
	shadow = "Looks: Shadow behind each frame: the game refused the texture" }
local TROUGH = { alpha = 0.08, light = 0.5 }
local SHADOW = { file = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Shadow.tga", margin = 16, out = 8, alpha = 0.55 }
local CHANGING = { target = true, focus = true, tot = true, party = true, partypet = true, boss = true }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Off()
	return ns.PartStopped(KEY, PART)
end

local held = {}

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

function X.mute(r, g, b)
	if r == nil or Opt("lookMuted") ~= true or Off() then
		return r, g, b
	end
	local light = 0.30 * r + 0.59 * g + 0.11 * b
	local keep, bright = MUTE.colour, MUTE.bright
	return (light + (r - light) * keep) * bright, (light + (g - light) * keep) * bright, (light + (b - light) * keep) * bright
end

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
	return X.reaction(unit)
end

local function ByColour(rec, by)
	if by == "reaction" then
		local unit = X.unitOf(rec)
		if unit == nil then
			return nil
		end
		return X.reaction(unit)
	end
	return FrameColour(rec)
end

local function ByUnit(rec)
	return Opt("lookClassHealth") == true or X.healthBy(rec) ~= nil
end

local function Key(r, g, b)
	return r ~= nil and ("%.3f:%.3f:%.3f"):format(r, g, b) or "none"
end

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

local SKY = { 0.35, 0.85, 1.00 }
local NEAR = 0.5

local function Near(r1, g1, b1, r2, g2, b2)
	return (r1 - r2) ^ 2 + (g1 - g2) ^ 2 + (b1 - b2) ^ 2 < NEAR * NEAR
end

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

local function SliceShadow(texture)
	if type(texture.SetTextureSliceMargins) ~= "function" or type(texture.SetTextureSliceMode) ~= "function" then
		return false
	end
	local modes = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.UITextureSliceMode
	local mode = type(modes) == "table" and modes.Stretched or 0
	local margin = SHADOW.margin
	return pcall(texture.SetTextureSliceMargins, texture, margin, margin, margin, margin) and pcall(texture.SetTextureSliceMode, texture, mode)
end

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
			if rec.shadowSeen then
				X.tell("Flat UI: frame shadows show when the fight ends.")
			end
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
	rec.shadowSeen = true
	local box = rec.shadowBox
	if box == nil then
		return
	end
	if want and not rec.shadowFailed and not InCombatLockdown() then
		Place(rec)
	end
	box:SetShown(want and not rec.shadowFailed and rec.shadowAt ~= nil)
end

local function Follow(rec)
	Shadow(rec, X.active(rec))
end

local HOVER_PART = "Mouse highlight"
local HOVER = { alpha = 0.12, every = 0.05, steps = 6, file = "Interface\\Buttons\\WHITE8X8", fadeIn = 0.08, fadeOut = 0.15 }
X.hoverAlpha = HOVER.alpha
local hover = { made = setmetatable({}, { __mode = "k" }), waited = 0 }

local function HoverOn(rec)
	return rec.made == true and Opt("hoverHighlight") == true and X.active(rec) and not ns.PartStopped(KEY, HOVER_PART)
end

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

local function Halt(group)
	if group ~= nil and group:IsPlaying() then
		pcall(group.Stop, group)
	end
end

local function Light(rec, now)
	if rec == hover.lit then
		return
	end
	local old = hover.lit
	if old ~= nil and old.hoverFrame ~= nil then
		local frame = old.hoverFrame
		Halt(old.hoverIn)
		if now or old.hoverOut == nil or not frame:IsShown() or not pcall(old.hoverOut.Play, old.hoverOut) then
			Halt(old.hoverOut)
			frame:Hide()
			frame:SetAlpha(1)
		end
	end
	hover.lit = rec
	if rec ~= nil then
		Halt(rec.hoverOut)
		rec.hoverFrame:SetAlpha(1)
		rec.hoverFrame:Show()
		if rec.hoverIn ~= nil and not now then
			pcall(rec.hoverIn.Play, rec.hoverIn)
		end
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
		Light(nil, true)
	end
end

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
	local ok, come, go = pcall(function()
		local rise = frame:CreateAnimationGroup()
		local up = rise:CreateAnimation("Alpha")
		up:SetFromAlpha(0)
		up:SetToAlpha(1)
		up:SetDuration(HOVER.fadeIn)
		local fall = frame:CreateAnimationGroup()
		local down = fall:CreateAnimation("Alpha")
		down:SetFromAlpha(1)
		down:SetToAlpha(0)
		down:SetDuration(HOVER.fadeOut)
		pcall(fall.SetToFinalAlpha, fall, true)
		fall:SetScript("OnFinished", function()
			frame:Hide()
			frame:SetAlpha(1)
		end)
		return rise, fall
	end)
	if ok then
		rec.hoverIn, rec.hoverOut = come, go
	end
	hover.made[rec] = true
end

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
		Light(nil, true)
	end
	Drive()
end

table.insert(X.after.apply, { part = PART, fn = Settle })
table.insert(X.after.apply, { part = PART, fn = Shadow })
table.insert(X.after.apply, { part = HOVER_PART, fn = Hover })
table.insert(X.after.raid, { part = HOVER_PART, fn = Hover })
table.insert(X.after.layout, { part = PART, fn = Follow })
