local _, ns = ...

-- Setup drawings of the action bar steps: mock-action-row (Action buttons), mock-bar-block (Bar block), mock-block-places (Class, buffs and
-- consumables bars) and mock-fade (Fading). Each is { build(stage), draw(stage), parts }: build makes the frames once on the stage (a frame, or a table
-- with a frame field), draw reads the settings through ns.Get only, so under a draft view it draws the draft, and parts maps a saved path to the region
-- the setting changes, for the bracket that marks it. The frames and textures are the addon's own (ns.Own) and are laid out here from the settings
-- the modules read: the game's action bars cannot be styled twice. A button is the icon, the outline ns.Outline gives it on the Action bars page
-- (ns.SetOutlineArea), the game's own slot art when the page does not restyle it, and the flat tints, key, count and sweep of the page. The block
-- drawings place bars with the arithmetic of BarBlock.lua (Plan, AroundSpots) and Blocks.lua (Where). Sizes are the game's: a button is 45 units, a
-- stance or pet button 30 (ActionButtonTemplate.xml:20 and 198-204, with the key and count anchors at 85-94), a bar of the block is as wide as its sample buttons. A drawing larger than the stage is scaled down as a whole; the
-- outline edges keep their pixel width (ns.Outline), and the names of bars are on a layer that is not scaled. The game's own art (the slot, the bar art, the
-- end caps, the dividers and the button states) is drawn with its atlas where C_Texture.GetAtlasInfo answers for it, and as plain grey with one Game look
-- label where it does not.

local AREA = "actionbars"
local STAGE_W, STAGE_H = 658, 204
local SIZE, SMALL, GAP = 45, 30, 2
local XP_H, XP_SPACER = 10, -1
local EDGE, COLUMN_GAP, LOOSE_ALPHA, LABEL_H = 4, 36, 0.5, 16
local ICON = "Interface\\Icons\\"
local ICONS = { "Ability_Warrior_Charge", "Spell_Holy_HolyBolt", "Spell_Fire_FireBolt02", "Spell_Nature_HealingTouch", "Spell_Frost_FrostBolt02",
	"Ability_Rogue_Eviscerate", "Spell_Shadow_ShadowBolt", "INV_Potion_54", "Ability_Hunter_SniperShot", "Spell_Nature_Rejuvenation", "Ability_Stealth",
	"Spell_Holy_PowerWordShield" }
-- The buttons of each bar in a drawing: the game lets Edit Mode give every bar its own number of buttons.
local BUTTONS = { main = 12, bar2 = 10, bar3 = 8, bar4 = 6, bar5 = 6, bar6 = 12, bar7 = 10, bar8 = 8, stance = 4, pet = 10 }
-- The game's art, by atlas (Blizzard_ActionBar/Mainline: ActionButtonTemplate.xml:33 and 146-164, MainActionBar.xml:10-18 and 53, MainMenuBarEndCaps.xml:14-31),
-- and the plain grey drawn where the client does not answer for the atlas.
local ATLAS = { slot = "ui-hud-actionbar-iconframe-slot", art = "UI-HUD-ActionBar-Frame", capLeft = "ui-hud-actionbar-gryphon-left",
	capRight = "ui-hud-actionbar-gryphon-right", divTop = "UI-HUD-ActionBar-Frame-Divider-ThreeSlice-EdgeTop",
	divMid = "_UI-HUD-ActionBar-Frame-Divider-Threeslice-Center", divBottom = "UI-HUD-ActionBar-Frame-Divider-ThreeSlice-EdgeBottom" }
local STATE_ATLAS = { pressed = "UI-HUD-ActionBar-IconFrame-Down", hover = "UI-HUD-ActionBar-IconFrame-Mouseover", checked = "UI-HUD-ActionBar-IconFrame-Mouseover",
	flash = "UI-HUD-ActionBar-IconFrame-Flash" }
local GREY, GREY_ART, GREY_CAP = { 0.5, 0.5, 0.5, 1 }, { 0.3, 0.3, 0.3, 1 }, { 0.42, 0.42, 0.42, 1 }
local GREY_STATE = { pressed = { 0.15, 0.15, 0.15, 0.5 }, hover = { 0.8, 0.8, 0.8, 0.35 }, checked = { 0.8, 0.8, 0.8, 0.5 }, flash = { 0.8, 0.8, 0.8, 0.5 } }
-- The tints of a button state in Flat UI (ActionBars.lua:Place).
local FLAT_STATE = { pressed = { 1, 1, 1, 0.25 }, hover = { 1, 1, 1, 0.2 }, checked = { 1, 0.82, 0, 0.3 }, flash = { 1, 0, 0, 0.3 } }
local BLOCKS = { { name = "Class spells", bar = "classBar", place = "classPlace" }, { name = "Buffs to apply", bar = "buffsBar", place = "buffsPlace" },
	{ name = "Consumables", bar = "consumablesBar", place = "consumablesPlace" } }
local FADERS = { { "main", "Main action bar", "bar" }, { "bar2", "Action bar 2", "bar" }, { "bar3", "Action bar 3", "bar" }, { "bar4", "Action bar 4", "bar" },
	{ "bar5", "Action bar 5", "bar" }, { "bar6", "Action bar 6", "bar" }, { "bar7", "Action bar 7", "bar" }, { "bar8", "Action bar 8", "bar" },
	{ "stance", "Stance bar", "stance" }, { "pet", "Pet bar", "pet" }, { "micro", "Micro menu", "micro" }, { "bags", "Bag bar", "bags" },
	{ "playerFrame", "Player frame", "player" }, { "petFrame", "Pet frame", "pet frame" }, { "minimapButtons", "Minimap buttons", "map" } }

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Frame(parent)
	return Own(CreateFrame("Frame", nil, parent))
end

local function Tex(parent, layer, sub)
	return Own(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
end

local function Text(parent, font)
	return Own(parent:CreateFontString(nil, "OVERLAY", font))
end

local function Colour(texture, c, a)
	texture:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1)
end

local function HasAtlas(name)
	local api = C_Texture
	if type(api) ~= "table" or type(api.GetAtlasInfo) ~= "function" then
		return false
	end
	local asked, info = pcall(api.GetAtlasInfo, name)
	return asked and info ~= nil
end

-- Paints a texture with the game's atlas where the client answers for it, and with the grey colour where it does not. Returns true for the grey.
local function GameLook(texture, atlas, grey)
	if HasAtlas(atlas) then
		texture:SetAtlas(atlas)
		return false
	end
	Colour(texture, grey)
	return true
end

-- The frame a drawing is made on: the stage itself, or the frame field of a table that holds it.
local function Root(stage)
	if type(stage) == "table" and type(stage.SetPoint) ~= "function" and stage.frame ~= nil then
		return stage.frame
	end
	return stage
end

-- The view the framework draws under, when it gives one: an outline then follows it and not the profile in use.
local function ViewOf(stage)
	local view = type(stage) == "table" and type(stage.SetPoint) ~= "function" and stage.view or nil
	if view == nil and type(ns.SetupDraw) == "table" then
		view = ns.SetupDraw.view
	end
	return view
end

-- An outline of an instance: kept, and set to the view the instance is drawn under.
local function Outlined(inst, outline)
	if outline then
		inst.outlines[#inst.outlines + 1] = outline
		if inst.view ~= nil and type(ns.SetOutlineView) == "function" then
			ns.SetOutlineView(outline, inst.view)
		end
	end
	return outline
end

-- Takes the view of this draw: the outlines made before follow it too.
local function SetView(inst, stage)
	inst.view = ViewOf(stage)
	if inst.view ~= nil and type(ns.SetOutlineView) == "function" then
		for _, outline in ipairs(inst.outlines) do
			ns.SetOutlineView(outline, inst.view)
		end
	end
end

-- The marks of the last draw, for the framework to read from the drawing.
local function Publish(drawing, inst)
	for path, region in pairs(inst.parts) do
		drawing.parts[path] = region
	end
end

-- One instance of a drawing for each stage it is built on.
local function Instances()
	return setmetatable({}, { __mode = "k" })
end

local function Look()
	local hr, hg, hb = ns.Colour(AREA .. ".hoverColour")
	local pr, pg, pb = ns.Colour(AREA .. ".pressedColour")
	local cr, cg, cb = ns.Colour(AREA .. ".checkedColour")
	return { enabled = ns.Get(AREA .. ".enabled") == true, square = ns.Get(AREA .. ".square") == true, crop = ns.Get(AREA .. ".crop"),
		backdrop = ns.Get(AREA .. ".backdrop") == true, tints = ns.Get(AREA .. ".tints") == true, border = ns.Get(AREA .. ".border") == true,
		empty = ns.Get(AREA .. ".empty"), emptyAlpha = ns.Get(AREA .. ".emptyAlpha"),
		states = { hover = { hr, hg, hb, 0.2 }, pressed = { pr, pg, pb, 0.25 }, checked = { cr, cg, cb, 0.3 } } }
end

local function Group(id)
	return (id == "main" or id == "pet" or id == "stance") and id or "extra"
end

local function BarLabel(id)
	if id == "stance" then
		return "Stance bar"
	elseif id == "pet" then
		return "Pet bar"
	end
	local bar = ns.BarFrames and ns.BarFrames[id]
	return bar and bar.label or id
end

local function BarWidth(id, size)
	local n = BUTTONS[id] or 12
	return n * (size or SIZE) + (n - 1) * GAP
end

-- Buttons ------------------------------------------------------------------------------------------------------------------------------------------

-- A button of an action bar. full: with the tints, key, count and sweep of the Action buttons drawing. The key sits where the game puts it
-- (ActionButtonTemplate.xml:15-16 and 200-201).
local function NewButton(inst, parent, size, index, full)
	local b = { size = size }
	b.frame = Frame(parent)
	b.frame:SetSize(size, size)
	b.slot = Tex(b.frame, "BACKGROUND", -7)
	b.slot:SetAllPoints(b.frame)
	b.icon = Tex(b.frame, "ARTWORK", 0)
	b.icon:SetTexture(ICON .. ICONS[(index - 1) % #ICONS + 1])
	b.outline = Outlined(inst, ns.SetOutlineArea(ns.Outline(b.frame, b.icon), AREA))
	if full then
		b.tint = Tex(b.frame, "OVERLAY", 1)
		b.sweep = Tex(b.frame, "OVERLAY", 2)
		Colour(b.sweep, { 0, 0, 0, 0.64 })
		b.sweepText = Text(b.frame, "NumberFontNormal")
		b.sweepText:SetPoint("CENTER", b.frame, "CENTER", 0, 0)
		b.key = Text(b.frame, "NumberFontNormalSmallGray")
		b.keyX, b.keyY = size == SMALL and -3 or -4, size == SMALL and -4 or -5
		b.key:SetPoint("TOPRIGHT", b.frame, "TOPRIGHT", b.keyX, b.keyY)
		-- The game's box: frame width - 8 by 10, right justified, one line (ActionButtonTemplate.xml:85-91, ActionButton.lua:512-515).
		b.key:SetSize(size - 8, 10)
		b.key:SetJustifyH("RIGHT")
		b.key:SetWordWrap(false)
		b.name = Text(b.frame, "GameFontHighlightSmall")
		b.name:SetPoint("BOTTOM", b.frame, "BOTTOM", 0, size == SMALL and 2 or 4)
		b.count = Text(b.frame, "NumberFontNormal")
		b.count:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", -5, 5)
	end
	return b
end

-- Paints a button from the Action bars page. look.on: this group is restyled. state: pressed, hover, checked or flash.
-- Returns true when something of the game's look is drawn as grey.
local function PaintButton(b, look, state)
	local on = look.on
	local square = on and look.square
	local standin = false
	b.slot:SetShown(not on)
	if not on then
		standin = GameLook(b.slot, ATLAS.slot, GREY)
	end
	b.icon:ClearAllPoints()
	if square then
		b.icon:SetAllPoints(b.frame)
	else
		local inset = math.floor(b.size * 0.08 + 0.5)
		b.icon:SetPoint("TOPLEFT", b.frame, "TOPLEFT", inset, -inset)
		b.icon:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", -inset, inset)
	end
	local crop = on and look.crop / 100 or 0
	b.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	b.icon:SetShown(not b.empty)
	if b.outline then
		ns.SetOutline(b.outline, on, on and look.backdrop)
		ns.SetOutlineEdges(b.outline, look.border)
		-- An empty slot of the main and extra bars: faint or hidden.
		local alpha
		if on and b.emptyOn and b.empty and look.empty ~= "show" then
			alpha = look.empty == "hidden" and 0 or look.emptyAlpha / 100
		end
		ns.SetOutlineAlpha(b.outline, alpha, alpha)
		if type(ns.RepaintOutline) == "function" then
			ns.RepaintOutline(b.outline)
		end
	end
	if b.tint then
		local flat = state and on and look.tints
		b.tint:SetShown(state ~= nil)
		if state then
			b.tint:ClearAllPoints()
			b.tint:SetAllPoints(flat and b.icon or b.frame)
			if flat then
				Colour(b.tint, look.states[state] or FLAT_STATE[state])
			elseif GameLook(b.tint, STATE_ATLAS[state], GREY_STATE[state]) then
				standin = true
			end
		end
		-- The sweep fits the icon when the icons are square, and keeps the game's own size of it otherwise.
		b.sweep:SetShown(b.cooling == true)
		b.sweepText:SetShown(b.cooling == true)
		b.sweep:ClearAllPoints()
		b.sweep:SetAllPoints(square and b.icon or b.frame)
	end
	return standin
end

-- A bar: a holder with up to `max` buttons in a row, and a name over it on the layer that is not scaled.
local function NewBar(inst, size, max)
	local bar = { size = size, buttons = {} }
	bar.frame = Frame(inst.box)
	bar.frame:SetSize(size, size)
	for index = 1, max do
		local b = NewButton(inst, bar.frame, size, index)
		b.frame:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", (index - 1) * (size + GAP), 0)
		bar.buttons[index] = b
	end
	bar.back = Tex(inst.labels, "BACKGROUND", 0)
	Colour(bar.back, { 0, 0, 0, 0.6 })
	bar.text = Text(inst.labels, "GameFontHighlightSmall")
	bar.text:SetPoint("CENTER", bar.frame, "CENTER", 0, 0)
	bar.back:SetPoint("CENTER", bar.text, "CENTER", 0, 0)
	return bar
end

-- Shows a bar of `id` at x, y in the box, with the alpha of the scene. Returns true when it draws grey for the game's art.
local function SetBar(inst, bar, item, look, x, y)
	local n = math.min(#bar.buttons, BUTTONS[item.id] or #bar.buttons)
	bar.frame:SetSize(n * bar.size + (n - 1) * GAP, bar.size)
	bar.frame:ClearAllPoints()
	bar.frame:SetPoint("BOTTOMLEFT", inst.box, "BOTTOMLEFT", x, y)
	bar.frame:SetAlpha(item.alpha)
	bar.frame:Show()
	look.on = look.enabled and ns.Get(AREA .. "." .. Group(item.id)) == true
	local standin = false
	for index, b in ipairs(bar.buttons) do
		b.frame:SetShown(index <= n)
		if index <= n and PaintButton(b, look) then
			standin = true
		end
	end
	local label = item.label or BarLabel(item.id)
	bar.text:SetText(label)
	bar.back:SetSize(bar.text:GetStringWidth() + 10, 14)
	bar.text:Show()
	bar.back:Show()
	return standin
end

local function HideBar(bar)
	bar.frame:Hide()
	bar.text:Hide()
	bar.back:Hide()
end

-- An experience bar: a dark bar with a fill.
local function NewXp(inst)
	local xp = { frame = Frame(inst.box) }
	xp.back = Tex(xp.frame, "BACKGROUND", -7)
	xp.back:SetAllPoints(xp.frame)
	Colour(xp.back, { 0.07, 0.07, 0.09, 1 })
	xp.fill = Tex(xp.frame, "ARTWORK", 0)
	xp.fill:SetPoint("TOPLEFT", xp.frame, "TOPLEFT", 0, 0)
	xp.fill:SetPoint("BOTTOMLEFT", xp.frame, "BOTTOMLEFT", 0, 0)
	xp.outline = Outlined(inst, ns.SetOutlineArea(ns.Outline(xp.frame, xp.frame), "hud"))
	xp.label = Text(inst.labels, "GameFontHighlightSmall")
	xp.label:SetPoint("CENTER", xp.frame, "CENTER", 0, 0)
	return xp
end

local XP_LOOK = { xp1 = { 0.58, 0.2, 0.75, 1, 0.6, "Status bar 1" }, xp2 = { 0.15, 0.6, 0.25, 1, 0.8, "Status bar 2" } }

local function SetXp(inst, xp, item, x, y)
	local look = XP_LOOK[item.key]
	xp.frame:SetSize(item.w, item.h or XP_H)
	xp.frame:ClearAllPoints()
	xp.frame:SetPoint("BOTTOMLEFT", inst.box, "BOTTOMLEFT", x, y)
	xp.frame:SetAlpha(item.alpha)
	xp.frame:Show()
	xp.fill:SetWidth(math.max(1, item.w * look[5]))
	Colour(xp.fill, look)
	xp.label:SetText(look[6])
	xp.label:Show()
	if type(ns.RepaintOutline) == "function" then
		ns.RepaintOutline(xp.outline)
	end
end

-- The frame the drawing is made of: a box that is scaled to fit the stage, and a layer over it with the names of the bars, above the box.
local function NewInstance(stage)
	local root = Root(stage)
	local inst = { root = root, view = ViewOf(stage), outlines = {}, parts = {} }
	inst.box = Frame(root)
	inst.labels = Frame(root)
	inst.labels:SetAllPoints(root)
	inst.labels:SetFrameLevel(inst.box:GetFrameLevel() + 100)
	inst.gameLabel = Text(inst.labels, "GameFontHighlightSmall")
	inst.gameLabel:SetPoint("BOTTOM", root, "BOTTOM", 0, 3)
	inst.gameLabel:SetText("Game look")
	inst.gameLabel:Hide()
	return inst
end

-- The one Game look label of a drawing: shown while any of the game's art in it is drawn as grey.
local function Standin(inst, on)
	inst.gameLabel:SetShown(on == true)
end

-- Sizes the box to w by h units, scales it to fit what is left of the stage after `room` units at the left for names, and centres it.
local function Fit(inst, w, h, room)
	room = room or 0
	w, h = math.max(1, w), math.max(1, h)
	local scale = math.min(1, (STAGE_W - room - 8) / w, (STAGE_H - 4 - LABEL_H) / h)
	inst.box:SetScale(scale)
	inst.box:SetSize(w, h)
	inst.box:ClearAllPoints()
	inst.box:SetPoint("CENTER", inst.root, "CENTER", room / 2 / scale, LABEL_H / 2 / scale)
	inst.scale = scale
	return scale
end

-- mock-action-row -----------------------------------------------------------------------------------------------------------------------------------

local ACTION_ROWS = { { "Main", "main", 12, SIZE }, { "Extra", "extra", 12, SIZE }, { "Pet", "pet", 10, SMALL }, { "Stance", "stance", 10, SMALL } }
local CAP_W, CAP_H, DIVIDER_W, ART_PAD, ROW_GAP, LABEL_ROOM = 40, 38, 12, 5, 10, 64
local ROW_X = ART_PAD + CAP_W
local ACTION_W = 12 * SIZE + 11 * GAP + 2 * ROW_X
local ACTION_H = 2 * ART_PAD + 2 * SIZE + 2 * SMALL + 3 * ROW_GAP
-- Which button of a row has which state, what it counts and which slot is empty: the same on every row.
local STATES = { [2] = "pressed", [3] = "hover", [4] = "checked", [6] = "flash" }
local KEYS = { main = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }, extra = { "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", KEY_BUTTON4 or "Mouse Button 4", KEY_NUMPAD1 or "Num Pad 1" } }
local COUNTS = { main = { [5] = "20", [10] = "3" }, extra = { [2] = "5" } }
local NAMES = { main = { [5] = "Heal", [8] = "Pot" }, extra = { [3] = "Aim" } }
-- The bars of the Button text page by row, and where its position choices anchor the hotkey.
local TEXT_GROUP = { main = "main", extra = "side", pet = "other", stance = "other" }
local TEXT_POINTS = { topright = "TOPRIGHT", topleft = "TOPLEFT", top = "TOP", center = "CENTER", bottomleft = "BOTTOMLEFT", bottom = "BOTTOM", bottomright = "BOTTOMRIGHT" }
-- The buttons of the main row that show a state of Colours and cooldowns: not enough power, cannot use, out of range.
local USES = { [9] = "mana", [10] = "unusable", [11] = "range" }
local COUNT_FONTS = { small = "NumberFontNormalSmall", normal = "NumberFontNormal", large = "NumberFontNormalLarge", huge = "NumberFontNormalHuge" }
local USE_GAME = { mana = { 0.5, 0.5, 1 }, unusable = { 0.4, 0.4, 0.4 } }

local ACTION = { parts = {}, built = Instances() }

-- A divider of the main bar (MainActionBar.lua:117-155): the game's three slices, 12 wide, centred on the gap between two buttons, or a thin grey bar.
local function NewDivider(holder, cut)
	local atlas = HasAtlas(ATLAS.divTop) and HasAtlas(ATLAS.divMid) and HasAtlas(ATLAS.divBottom)
	local d = { frame = Frame(holder), standin = not atlas }
	d.frame:SetSize(atlas and DIVIDER_W or GAP, SIZE)
	d.frame:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", cut * (SIZE + GAP) - (atlas and 7 or GAP), 0)
	d.mid = Tex(d.frame, "ARTWORK", 3)
	if atlas then
		d.top, d.bottom = Tex(d.frame, "ARTWORK", 3), Tex(d.frame, "ARTWORK", 3)
		d.top:SetSize(DIVIDER_W, 14)
		d.top:SetPoint("TOP", d.frame, "TOP", 0, 0)
		d.bottom:SetSize(DIVIDER_W, 15)
		d.bottom:SetPoint("BOTTOM", d.frame, "BOTTOM", 0, 0)
		d.mid:SetPoint("TOPLEFT", d.top, "BOTTOMLEFT", 0, 0)
		d.mid:SetPoint("BOTTOMRIGHT", d.bottom, "TOPRIGHT", 0, 0)
		GameLook(d.top, ATLAS.divTop, GREY_CAP)
		GameLook(d.mid, ATLAS.divMid, GREY_CAP)
		GameLook(d.bottom, ATLAS.divBottom, GREY_CAP)
	else
		d.mid:SetAllPoints(d.frame)
		Colour(d.mid, GREY_CAP)
	end
	return d
end

function ACTION.build(stage)
	local inst = NewInstance(stage)
	ACTION.built[inst.root] = inst
	inst.rows = {}
	local top = ACTION_H - ART_PAD
	for index, row in ipairs(ACTION_ROWS) do
		local n, size = row[3], row[4]
		local holder = Frame(inst.box)
		holder:SetSize(n * size + (n - 1) * GAP, size)
		holder:SetPoint("BOTTOMLEFT", inst.box, "BOTTOMLEFT", ROW_X, top - size)
		top = top - size - ROW_GAP
		local entry = { key = row[2], holder = holder, buttons = {}, size = size }
		for position = 1, n do
			local b = NewButton(inst, holder, size, position, true)
			b.frame:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", (position - 1) * (size + GAP), 0)
			b.state = index == 1 and STATES[position] or nil
			b.empty = position == n
			b.emptyOn = row[2] == "main" or row[2] == "extra"
			b.cooling = index == 1 and position == 8
			b.use = index == 1 and USES[position] or nil
			if b.cooling then
				b.sweepText:SetText("8")
			end
			local key = KEYS[row[2]]
			b.keyLong = key and key[position] or ""
			b.key:SetText(b.keyLong)
			local count = COUNTS[row[2]]
			b.count:SetText(count and count[position] or "")
			local names = NAMES[row[2]]
			b.name:SetText(names and names[position] or "")
			entry.buttons[position] = b
		end
		entry.label = Text(inst.labels, "GameFontHighlightSmall")
		entry.label:SetPoint("RIGHT", holder, "LEFT", -(ROW_X + 6), 0)
		entry.label:SetText(row[1])
		-- The flat panel behind a bar (Bar backgrounds).
		entry.plate = Tex(holder, "BACKGROUND", -6)
		entry.plate:SetPoint("TOPLEFT", holder, "TOPLEFT", -4, 4)
		entry.plate:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 4, -4)
		if index == 1 then
			entry.art = Tex(holder, "BACKGROUND", -8)
			entry.art:SetPoint("TOPLEFT", holder, "TOPLEFT", -ART_PAD, ART_PAD)
			entry.art:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", ART_PAD, -ART_PAD)
			entry.artStandin = GameLook(entry.art, ATLAS.art, GREY_ART)
			entry.capLeft = Tex(holder, "BACKGROUND", -7)
			entry.capLeft:SetSize(CAP_W, CAP_H)
			entry.capLeft:SetPoint("BOTTOMRIGHT", entry.art, "BOTTOMLEFT", 0, 0)
			entry.capRight = Tex(holder, "BACKGROUND", -7)
			entry.capRight:SetSize(CAP_W, CAP_H)
			entry.capRight:SetPoint("BOTTOMLEFT", entry.art, "BOTTOMRIGHT", 0, 0)
			local left = GameLook(entry.capLeft, ATLAS.capLeft, GREY_CAP)
			local right = GameLook(entry.capRight, ATLAS.capRight, GREY_CAP)
			entry.capStandin = left or right
			-- The game puts a divider between every two shown buttons of the main bar.
			entry.dividers = {}
			for cut = 1, n - 1 do
				entry.dividers[cut] = NewDivider(holder, cut)
			end
		end
		inst.rows[index] = entry
	end
	Fit(inst, ACTION_W, ACTION_H, LABEL_ROOM)
	local main = inst.rows[1]
	-- The red border that Mark action buttons puts on the button of a low or missing tracker.
	main.mark = Tex(main.buttons[7].frame, "OVERLAY", 4)
	main.mark:SetPoint("TOPLEFT", main.buttons[7].frame, "TOPLEFT", -2, 2)
	main.mark:SetPoint("BOTTOMRIGHT", main.buttons[7].frame, "BOTTOMRIGHT", 2, -2)
	Colour(main.mark, { 1, 0.1, 0.1, 1 })
	main.mark:Hide()
	-- What the Glows and animations page shows: a proc glow on the second button, the rotation helper highlight on the third, the cast fill on the
	-- fourth, the interrupt flash on the fifth, and the artwork of the first extra button.
	local fx = {}
	fx.proc = Tex(main.buttons[2].frame, "BACKGROUND", -6)
	fx.assist = Tex(main.buttons[3].frame, "OVERLAY", 5)
	fx.assist:SetAllPoints(main.buttons[3].frame)
	fx.cast = Tex(main.buttons[4].frame, "OVERLAY", 5)
	fx.cast:SetPoint("BOTTOMLEFT", main.buttons[4].frame, "BOTTOMLEFT", 0, 0)
	fx.cast:SetPoint("TOPRIGHT", main.buttons[4].frame, "RIGHT", 0, 0)
	fx.interrupt = Tex(main.buttons[5].frame, "OVERLAY", 5)
	fx.interrupt:SetAllPoints(main.buttons[5].frame)
	fx.art = Tex(inst.rows[2].buttons[1].frame, "BACKGROUND", -6)
	fx.art:SetPoint("TOPLEFT", inst.rows[2].buttons[1].frame, "TOPLEFT", -5, 5)
	fx.art:SetPoint("BOTTOMRIGHT", inst.rows[2].buttons[1].frame, "BOTTOMRIGHT", 5, -5)
	Colour(fx.assist, { 0.4, 0.7, 1, 0.35 })
	Colour(fx.cast, { 1, 1, 1, 0.3 })
	Colour(fx.interrupt, { 1, 0.1, 0.1, 0.45 })
	Colour(fx.art, { 0.55, 0.45, 0.25, 1 })
	main.fx = fx
	local parts = inst.parts
	parts["trackers.mark"] = main.buttons[7].frame
	parts["actionbars.enabled"] = inst.box
	parts["actionbars.main"], parts["actionbars.extra"] = main.holder, inst.rows[2].holder
	parts["actionbars.pet"], parts["actionbars.stance"] = inst.rows[3].holder, inst.rows[4].holder
	parts["actionbars.backdrop"], parts["actionbars.crop"], parts["actionbars.square"] = main.buttons[1].frame, main.buttons[1].icon, main.buttons[1].icon
	parts["actionbars.tints"] = main.buttons[3].frame
	parts["actionbars.frame"], parts["actionbars.caps"], parts["actionbars.dividers"] = main.art, main.capLeft, main.dividers[1].frame
	for _, key in ipairs({ "lookOwn", "lookBorder", "lookBack", "lookBackAlpha" }) do
		parts["actionbars." .. key] = main.buttons[1].frame
	end
	for _, key in ipairs({ "border", "empty", "emptyAlpha", "hoverColour", "pressedColour", "checkedColour", "plate", "plateColour", "plateAlpha", "totem", "ability" }) do
		parts["actionbars." .. key] = main.buttons[1].frame
	end
	for _, key in ipairs({ "hotkeyShow", "hotkeySize", "hotkeyOwn", "hotkeyColour", "hotkeyPoint", "hotkeyX", "hotkeyY", "nameShow", "nameSize", "countSize", "textOutline" }) do
		parts["actionbars." .. key] = main.buttons[5].frame
	end
	parts["actionbars.hotkeyText"] = inst.rows[2].buttons[9].frame
	for _, key in ipairs({ "usableOwn", "manaColour", "unusableColour", "rangeTint", "rangeColour", "sweep", "sweepOwn", "sweepAlpha", "cdFont", "cdGrey" }) do
		parts["actionbars." .. key] = main.buttons[1].frame
	end
	for _, key in ipairs({ "proc", "procColour", "assist", "castAnim", "interruptAnim", "abilityArt" }) do
		parts["actionbars." .. key] = main.buttons[1].frame
	end
	Publish(ACTION, inst)
	return inst
end

-- The hotkey, macro name and count of a button as the Button text page sets them. A bar that is not restyled keeps the game's text.
local function PaintText(entry, b, on)
	local group = TEXT_GROUP[entry.key]
	local function Opt(key)
		return ns.Get(AREA .. "." .. key)
	end
	local function Shows(choice)
		return not on or choice == "all" or choice == group
	end
	local flags = on and type(ns.OutlineFlags) == "function" and ns.OutlineFlags(Opt("textOutline")) or nil
	local hot, name = Shows(Opt("hotkeyShow")), Shows(Opt("nameShow"))
	b.key:SetText(on and Opt("hotkeyText") == "short" and type(ns.HotkeyText) == "function" and ns.HotkeyText(b.keyLong) or b.keyLong)
	b.key:SetAlpha(hot and 1 or 0)
	b.name:SetAlpha(name and 1 or 0)
	local spec = on and hot and { percent = Opt("hotkeySize"), flags = flags } or nil
	if spec and Opt("hotkeyOwn") then
		spec.r, spec.g, spec.b = ns.Colour(AREA .. ".hotkeyColour")
	end
	ns.TextStyle(b.key, spec)
	ns.TextStyle(b.name, on and name and { percent = Opt("nameSize"), flags = flags } or nil)
	ns.TextStyle(b.count, on and { percent = Opt("countSize"), flags = flags } or nil)
	local custom = on and (Opt("hotkeyPoint") ~= "topright" or Opt("hotkeyX") ~= 0 or Opt("hotkeyY") ~= 0)
	local point = custom and TEXT_POINTS[Opt("hotkeyPoint")] or "TOPRIGHT"
	b.key:ClearAllPoints()
	b.key:SetPoint(point, b.frame, point, custom and Opt("hotkeyX") or b.keyX, custom and Opt("hotkeyY") or b.keyY)
end

function ACTION.draw(stage)
	local inst = ACTION.built[Root(stage)] or ACTION.build(stage)
	SetView(inst, stage)
	local look = Look()
	local standin = false
	local pr, pg, pb = ns.Colour(AREA .. ".plateColour")
	local plated = ns.Get(AREA .. ".plate") == true
	for _, entry in ipairs(inst.rows) do
		look.on = look.enabled and ns.Get(AREA .. "." .. entry.key) == true
		entry.plate:SetShown(plated and look.on)
		Colour(entry.plate, { pr, pg, pb, ns.Get(AREA .. ".plateAlpha") / 100 })
		for _, b in ipairs(entry.buttons) do
			if PaintButton(b, look, b.state) then
				standin = true
			end
			PaintText(entry, b, look.on)
		end
	end
	-- Colours and cooldowns, on the main row only: pet and stance buttons keep the game's colours.
	local main = inst.rows[1]
	local own, tint, sweepOwn, grey = ns.Get(AREA .. ".usableOwn") == true, ns.Get(AREA .. ".rangeTint") == true, ns.Get(AREA .. ".sweepOwn") == true, ns.Get(AREA .. ".cdGrey") == true
	local on = look.enabled and ns.Get(AREA .. ".main") == true
	for _, b in ipairs(main.buttons) do
		local colour = { 1, 1, 1 }
		if b.use == "range" then
			if on and tint then
				colour = { ns.Colour(AREA .. ".rangeColour") }
			end
		elseif b.use ~= nil then
			colour = USE_GAME[b.use]
			if on and own then
				colour = { ns.Colour(AREA .. (b.use == "mana" and ".manaColour" or ".unusableColour")) }
			end
		end
		b.icon:SetVertexColor(colour[1], colour[2], colour[3])
		if b.cooling then
			b.sweep:SetShown(not (on and ns.Get(AREA .. ".sweep") ~= true))
			Colour(b.sweep, { 0, 0, 0 }, on and sweepOwn and ns.Get(AREA .. ".sweepAlpha") / 100 or 0.64)
			b.sweepText:SetFontObject(on and COUNT_FONTS[ns.Get(AREA .. ".cdFont")] or "NumberFontNormal")
		end
		b.icon:SetDesaturated(on and grey and b.cooling == true)
	end
	-- The art of the main bar is the game's, and goes only while Restyle action bars is on.
	local art = not (look.enabled and ns.Get(AREA .. ".frame") == true)
	main.art:SetShown(art)
	local caps = not (look.enabled and ns.Get(AREA .. ".caps") == true)
	main.capLeft:SetShown(caps)
	main.capRight:SetShown(caps)
	main.mark:SetShown(ns.Get("trackers.mark") == true)
	-- The rows of Glows and animations: the game's look while Restyle action bars is off.
	local fx, fxOn = main.fx, look.enabled
	local proc = fxOn and ns.Get(AREA .. ".proc") or "game"
	fx.proc:ClearAllPoints()
	if proc == "border" then
		fx.proc:SetPoint("TOPLEFT", main.buttons[2].frame, "TOPLEFT", -2, 2)
		fx.proc:SetPoint("BOTTOMRIGHT", main.buttons[2].frame, "BOTTOMRIGHT", 2, -2)
		local r, g, b = ns.Colour(AREA .. ".procColour")
		Colour(fx.proc, { r, g, b, 1 })
	else
		fx.proc:SetPoint("TOPLEFT", main.buttons[2].frame, "TOPLEFT", -5, 5)
		fx.proc:SetPoint("BOTTOMRIGHT", main.buttons[2].frame, "BOTTOMRIGHT", 5, -5)
		Colour(fx.proc, { 1, 0.9, 0.5, 0.55 })
	end
	fx.proc:SetShown(proc ~= "off")
	fx.assist:SetShown(not fxOn or ns.Get(AREA .. ".assist") == true)
	fx.cast:SetShown(not fxOn or ns.Get(AREA .. ".castAnim") == true)
	fx.interrupt:SetShown(not fxOn or ns.Get(AREA .. ".interruptAnim") == true)
	fx.art:SetShown(not fxOn or ns.Get(AREA .. ".abilityArt") == true)
	local dividers = not (look.enabled and ns.Get(AREA .. ".dividers") == true)
	for _, divider in ipairs(main.dividers) do
		divider.frame:SetShown(dividers)
	end
	Standin(inst, standin or (art and main.artStandin) or (caps and main.capStandin) or (dividers and main.dividers[1].standin))
	Publish(ACTION, inst)
end

-- Scenes of the block drawings ---------------------------------------------------------------------------------------------------------------------

-- A scene is a list of items { kind, id, key, label, x, y, w, h, alpha } in the units of the game, y up, and a list of loose items with no place.
-- kind: bar (a bar of 45 unit buttons), small (a stance or pet bar), xp (an experience bar), panel (the background of the block).

-- The ids of the bars in the rows of the Bar block page, in order: none and a bar already in a row are left out.
local function BlockIds()
	local ids, seen = {}, {}
	for index = 1, 6 do
		local id = ns.Get("barblock.slot" .. index)
		if BUTTONS[id] and id ~= "stance" and id ~= "pet" and not seen[id] then
			seen[id] = true
			ids[#ids + 1] = id
		end
	end
	return ids
end

-- The rows of the block and the bars it places, from BarBlock.lua Plan: gap, width, height, and each row's left and bottom from the first bar.
local function BlockPlan(on)
	local ids = on and BlockIds() or { "main", "bar2", "bar3" }
	local gap = (on and ns.Get("barblock.ownGap") == true) and ns.Get("barblock.barGap") or GAP
	local plan = { rows = {}, gap = gap, width = 0, height = 0 }
	for index, id in ipairs(ids) do
		local w = BarWidth(id)
		plan.rows[index] = { id = id, w = w }
		plan.width = math.max(plan.width, w)
		plan.height = plan.height + SIZE + (index > 1 and gap or 0)
	end
	local align = on and ns.Get("barblock.align") or "center"
	local down = on and ns.Get("barblock.direction") == "down"
	local used = down and plan.height or 0
	for _, row in ipairs(plan.rows) do
		if down then
			row.y = used - SIZE
			used = row.y - gap
		else
			row.y = used
			used = used + SIZE + gap
		end
		row.x = align == "left" and 0 or align == "right" and plan.width - row.w or (plan.width - row.w) / 2
	end
	return plan
end

-- The size of a status bar of the drawing, and the space between the two: the game's (the block's width, XP_H and XP_SPACER), or those of Flat UI's own
-- experience bar (XpBar.lua) when the page puts it in their place.
local function XpSize(width)
	if ns.Get("hud.enabled") == true and ns.Get("hud.xpOwn") == "flat" then
		return 1192 * ns.Get("hud.xpWidth") / 100, ns.Get("hud.xpHeight"), ns.Get("hud.xpGap")
	end
	return width, XP_H, XP_SPACER
end

-- The bars hung above the block (BarBlock.lua AroundSpots): the two experience bars, then the stance bar on the left and the pet bar on the right,
-- the pet bar on a row of its own above when the stance bar is wider than half the block. Returns the items and the top of the last row.
local function Around(plan, alpha)
	local width = plan.width > 0 and plan.width or 12 * SIZE + 11 * GAP
	local xw, xh, spacer = XpSize(width)
	local size = { xp1 = { xw, xh }, xp2 = { xw, xh }, stance = { BarWidth("stance", SMALL), SMALL }, pet = { BarWidth("pet", SMALL), SMALL } }
	local rows = { { { "xp2", "centre" } }, { { "xp1", "centre" }, closer = true }, { { "stance", "left" }, { "pet", "right" } } }
	if size.stance[1] > width / 2 then
		rows[3] = { { "stance", "left" } }
		rows[4] = { { "pet", "right" } }
	end
	local items, cursor, any = {}, plan.height, false
	for _, row in ipairs(rows) do
		local height = 0
		for _, entry in ipairs(row) do
			height = math.max(height, size[entry[1]][2])
		end
		local bottom = cursor + ((row.closer and any and height > 0) and spacer or plan.gap)
		for _, entry in ipairs(row) do
			local key = entry[1]
			local w = size[key][1]
			local x = entry[2] == "centre" and (width - w) / 2 or entry[2] == "right" and width - w or 0
			items[#items + 1] = { kind = key:find("^xp") and "xp" or "small", key = key, id = key, x = x, y = bottom, w = w, h = size[key][2], alpha = alpha }
		end
		cursor, any = bottom + height, true
	end
	return items, cursor
end

-- The same bars with no place: the game puts them where the game puts them.
local function LooseAround(plan)
	local width = plan.width > 0 and plan.width or 12 * SIZE + 11 * GAP
	local loose = {}
	local xw, xh = XpSize(width)
	for _, key in ipairs({ "xp2", "xp1", "stance", "pet" }) do
		local xp = key:find("^xp") ~= nil
		loose[#loose + 1] = { kind = xp and "xp" or "small", key = key, id = key, w = xp and xw or BarWidth(key, SMALL), h = xp and xh or SMALL }
	end
	return loose
end

-- The Action bar block with what the Bar block page says: items, loose items, the plan and the top of the bars above it.
local function BlockScene(on)
	local plan = BlockPlan(on)
	local fade = on and ns.Get("barblock.fade") == true
	local alpha = fade and ns.Get("barblock.fadeTo") / 100 or 1
	local scene = { plan = plan, items = {}, loose = {} }
	if on and ns.Get("barblock.background") == true and #plan.rows > 0 then
		local pad = ns.Get("barblock.backgroundPad")
		scene.items[#scene.items + 1] = { kind = "panel", x = -pad, y = -pad, w = plan.width + 2 * pad, h = plan.height + 2 * pad, alpha = alpha }
	end
	for _, row in ipairs(plan.rows) do
		scene.items[#scene.items + 1] = { kind = "bar", id = row.id, x = row.x, y = row.y, w = row.w, h = SIZE, alpha = alpha }
	end
	if on and ns.Get("barblock.others") == "above" and #plan.rows > 0 then
		local around, top = Around(plan, alpha)
		for _, item in ipairs(around) do
			scene.items[#scene.items + 1] = item
		end
		scene.top = top
	else
		scene.loose = LooseAround(plan)
	end
	return scene
end

-- The pieces of a scene: the panel, the bars, the stance and pet bars and the experience bars, made once.
local function NewPool(inst, bars)
	local pool = { bar = {}, small = {}, xp = {} }
	pool.panel = Frame(inst.box)
	pool.panel:SetFrameLevel(inst.box:GetFrameLevel())
	pool.outline = Outlined(inst, ns.Outline(pool.panel, pool.panel, true))
	for index = 1, bars do
		pool.bar[index] = NewBar(inst, SIZE, 12)
	end
	for index = 1, 3 do
		pool.small[index] = NewBar(inst, SMALL, 10)
	end
	for index = 1, 2 do
		pool.xp[index] = NewXp(inst)
	end
	pool.column = Text(inst.labels, "GameFontHighlightSmall")
	pool.column:SetText("Left to the game")
	pool.column:Hide()
	inst.pool = pool
	return pool
end

-- Lays a scene out: loose items go in a dim column at the right, the whole is moved to the bottom left of the box and the box is fitted to the stage.
local function Compose(inst, items, loose)
	local pool = inst.pool
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local function Grow(item)
		minX, minY = math.min(minX, item.x), math.min(minY, item.y)
		maxX, maxY = math.max(maxX, item.x + item.w), math.max(maxY, item.y + item.h)
	end
	for _, item in ipairs(items) do
		Grow(item)
	end
	local columnX, columnY = #items > 0 and maxX + COLUMN_GAP or 0, #items > 0 and minY or 0
	for _, item in ipairs(loose) do
		item.x, item.y, item.alpha = columnX, columnY, LOOSE_ALPHA
		columnY = columnY + item.h + 10
		Grow(item)
	end
	if #loose > 0 then
		-- Room over the column for its name.
		Grow({ x = columnX, y = columnY - 10, w = 1, h = 16 })
	end
	local all = {}
	for _, item in ipairs(items) do
		all[#all + 1] = item
	end
	for _, item in ipairs(loose) do
		all[#all + 1] = item
	end
	local used = { bar = 0, small = 0, xp = 0 }
	local look = Look()
	if #all > 0 then
		Fit(inst, maxX - minX + 2 * EDGE, maxY - minY + 2 * EDGE)
	else
		Fit(inst, 1, 1)
	end
	local panelUsed, standin = false, false
	for _, item in ipairs(all) do
		local x, y = item.x - minX + EDGE, item.y - minY + EDGE
		item.piece = nil
		if item.kind == "panel" then
			pool.panel:SetSize(item.w, item.h)
			pool.panel:ClearAllPoints()
			pool.panel:SetPoint("BOTTOMLEFT", inst.box, "BOTTOMLEFT", x, y)
			pool.panel:SetAlpha(item.alpha)
			pool.panel:Show()
			if type(ns.RepaintOutline) == "function" then
				ns.RepaintOutline(pool.outline)
			end
			panelUsed, item.piece = true, pool.panel
		else
			used[item.kind] = used[item.kind] + 1
			local piece = pool[item.kind][used[item.kind]]
			if piece then
				if item.kind == "xp" then
					SetXp(inst, piece, item, x, y)
				elseif SetBar(inst, piece, item, look, x, y) then
					standin = true
				end
				item.piece = piece.frame
			end
		end
	end
	if not panelUsed then
		pool.panel:Hide()
	end
	pool.column:SetShown(#loose > 0)
	if #loose > 0 then
		pool.column:ClearAllPoints()
		pool.column:SetPoint("BOTTOMLEFT", inst.box, "BOTTOMLEFT", columnX - minX + EDGE, columnY - 10 - minY + EDGE + 2)
	end
	Standin(inst, standin)
	for kind, list in pairs({ bar = pool.bar, small = pool.small, xp = pool.xp }) do
		for index = used[kind] + 1, #list do
			if kind == "xp" then
				list[index].frame:Hide()
				list[index].label:Hide()
			else
				HideBar(list[index])
			end
		end
	end
end

local function PieceOf(items, id)
	for _, item in ipairs(items) do
		if item.id == id and item.piece then
			return item.piece
		end
	end
end

-- mock-bar-block ------------------------------------------------------------------------------------------------------------------------------------

local BLOCK = { parts = {}, built = Instances() }

function BLOCK.build(stage)
	local inst = NewInstance(stage)
	BLOCK.built[inst.root] = inst
	NewPool(inst, 6)
	BLOCK.draw(stage)
	return inst
end

function BLOCK.draw(stage)
	local inst = BLOCK.built[Root(stage)]
	if not inst then
		return BLOCK.build(stage)
	end
	SetView(inst, stage)
	local scene = BlockScene(ns.Get("barblock.enabled") == true)
	Compose(inst, scene.items, scene.loose)
	local parts, pool = inst.parts, inst.pool
	local function Piece(id)
		return id and PieceOf(scene.items, id) or nil
	end
	parts["barblock.enabled"] = inst.box
	for index = 1, 6 do
		parts["barblock.slot" .. index] = Piece(ns.Get("barblock.slot" .. index)) or inst.box
	end
	local first, second = pool.bar[1].frame, (pool.bar[2] and pool.bar[2].frame) or pool.bar[1].frame
	parts["barblock.direction"], parts["barblock.fade"], parts["barblock.fadeTo"] = first, first, first
	parts["barblock.align"], parts["barblock.ownGap"], parts["barblock.barGap"] = second, second, second
	parts["barblock.others"] = Piece("stance") or Piece("xp1") or inst.box
	parts["barblock.background"], parts["barblock.backgroundPad"] = pool.panel, pool.panel
	Publish(BLOCK, inst)
end

-- mock-block-places ---------------------------------------------------------------------------------------------------------------------------------

local PLACES = { parts = {}, built = Instances() }

local function PlacesScene()
	local on = ns.Get("barblock.enabled") == true
	local scene = on and BlockScene(true) or nil
	local items, loose, ref, fromId = {}, {}, nil, nil
	local block = scene ~= nil and #scene.plan.rows > 0
	if block then
		items, loose = scene.items, scene.loose
		ref = { left = 0, bottom = 0, right = scene.plan.width, top = scene.plan.height, above = scene.top }
		-- The Bar block page keeps the pet bar over the block when it holds the bars above; otherwise the pet bar is set on this page.
		for index = #loose, 1, -1 do
			if loose[index].key == "pet" then
				table.remove(loose, index)
			end
		end
	else
		fromId = BUTTONS[ns.Get("blocks.from")] and ns.Get("blocks.from") or "main"
		local w = BarWidth(fromId)
		items[1] = { kind = "bar", id = fromId, x = 0, y = 0, w = w, h = SIZE, alpha = 1 }
		ref = { left = 0, bottom = 0, right = w, top = SIZE }
	end
	if ns.Get("blocks.enabled") ~= true then
		return items, {}, scene
	end
	local inBlock = {}
	for _, row in ipairs(block and scene.plan.rows or {}) do
		inBlock[row.id] = true
	end
	local gap, used, claimed = ns.Get("blocks.gap"), {}, {}
	local function Hang(item, place)
		if place == "free" then
			loose[#loose + 1] = item
			return
		end
		local taken = used[place] or 0
		item.x, item.y = ns.BlockWhere(ref, place, item.w, item.h, gap, taken)
		used[place] = taken + ((place:find("above", 1, true) or place:find("below", 1, true)) and item.h or item.w) + gap
		items[#items + 1] = item
	end
	for _, entry in ipairs(BLOCKS) do
		local id = ns.Get("blocks." .. entry.bar)
		if BUTTONS[id] and id ~= "main" and not claimed[id] then
			claimed[id] = true
			if not inBlock[id] and id ~= fromId then
				Hang({ kind = "bar", id = id, label = entry.name, w = BarWidth(id), h = SIZE, alpha = 1, block = entry.bar }, ns.Get("blocks." .. entry.place))
			end
		end
	end
	local pet = ns.Get("blocks.petPlace")
	local owned = block and ns.Get("barblock.others") == "above"
	if not owned then
		Hang({ kind = "small", id = "pet", key = "pet", w = BarWidth("pet", SMALL), h = SMALL, alpha = 1 }, pet == "game" and "free" or pet)
	end
	return items, loose, scene
end

function PLACES.build(stage)
	local inst = NewInstance(stage)
	PLACES.built[inst.root] = inst
	NewPool(inst, 9)
	PLACES.draw(stage)
	return inst
end

function PLACES.draw(stage)
	local inst = PLACES.built[Root(stage)]
	if not inst then
		return PLACES.build(stage)
	end
	SetView(inst, stage)
	local items, loose = PlacesScene()
	Compose(inst, items, loose)
	local parts = inst.parts
	local all = {}
	for _, list in ipairs({ items, loose }) do
		for _, item in ipairs(list) do
			all[#all + 1] = item
		end
	end
	local function Piece(bar)
		for _, item in ipairs(all) do
			if item.block == bar and item.piece then
				return item.piece
			end
		end
		return inst.box
	end
	parts["blocks.enabled"], parts["blocks.gap"] = inst.box, inst.box
	parts["blocks.from"] = items[1] and items[1].piece or inst.box
	parts["blocks.classBar"], parts["blocks.classPlace"] = Piece("classBar"), Piece("classBar")
	parts["blocks.buffsBar"], parts["blocks.buffsPlace"] = Piece("buffsBar"), Piece("buffsBar")
	parts["blocks.consumablesBar"], parts["blocks.consumablesPlace"] = Piece("consumablesBar"), Piece("consumablesBar")
	parts["blocks.petPlace"] = PieceOf(all, "pet") or inst.box
	Publish(PLACES, inst)
end

-- mock-fade -----------------------------------------------------------------------------------------------------------------------------------------

local TILE_W, TILE_H, TILE_PITCH, TILE_ROW = 124, 28, 130, 46
local FADE_W = 5 * TILE_PITCH
local FADE_H = 34 + 12 + 3 * TILE_ROW
local FADE = { parts = {}, built = Instances() }

-- What a faded part looks like: icons for a bar, a row of buttons for the micro menu, and so on, on a body that fades as one.
local function TileArt(inst, tile, kind, index)
	local body = tile.body
	local function Icons(count, size, from)
		for position = 1, count do
			local icon = Tex(body, "ARTWORK", 0)
			icon:SetSize(size, size)
			icon:SetPoint("LEFT", body, "LEFT", 6 + (position - 1) * (size + 2), 0)
			icon:SetTexture(ICON .. ICONS[(from + position - 2) % #ICONS + 1])
		end
	end
	local function Block(w, h, x, y, c)
		local block = Tex(body, "ARTWORK", 0)
		block:SetSize(w, h)
		block:SetPoint("LEFT", body, "LEFT", x, y)
		Colour(block, c, 1)
	end
	if kind == "bar" then
		Icons(5, 20, index)
	elseif kind == "stance" then
		Icons(4, 20, 3)
	elseif kind == "pet" then
		Icons(5, 16, 5)
	elseif kind == "micro" then
		for position = 1, 8 do
			Block(10, 20, 6 + (position - 1) * 12, 0, { 0.45, 0.4, 0.3 })
		end
	elseif kind == "bags" then
		Block(24, 24, 6, 0, { 0.5, 0.36, 0.2 })
		for position = 1, 4 do
			Block(18, 18, 36 + (position - 1) * 21, 0, { 0.42, 0.3, 0.17 })
		end
	elseif kind == "player" then
		Block(22, 22, 6, 0, { 0.3, 0.45, 0.7 })
		Block(76, 9, 34, 5, { 0.18, 0.72, 0.3 })
		Block(76, 6, 34, -5, { 0.2, 0.4, 0.85 })
	elseif kind == "pet frame" then
		Block(16, 16, 6, 0, { 0.55, 0.4, 0.25 })
		Block(50, 7, 28, 3, { 0.18, 0.72, 0.3 })
	elseif kind == "map" then
		for position = 1, 3 do
			Block(10, 10, 80 + (position - 1) * 12, 0, { 0.7, 0.62, 0.4 })
		end
	end
end

function FADE.build(stage)
	local inst = NewInstance(stage)
	FADE.built[inst.root] = inst
	inst.tiles = {}
	Fit(inst, FADE_W, FADE_H)
	-- Two sample buttons: one at full opacity and one at the faded opacity.
	inst.samples = {}
	for index = 1, 2 do
		local holder = Frame(inst.box)
		holder:SetSize(28, 28)
		holder:SetPoint("TOPLEFT", inst.box, "TOPLEFT", 6 + (index - 1) * 200, -3)
		local b = NewButton(inst, holder, 28, index + 1)
		b.frame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		local label = Text(inst.labels, "GameFontHighlightSmall")
		label:SetPoint("LEFT", holder, "RIGHT", 10, 0)
		label:SetText(index == 1 and "Full opacity" or "Faded opacity")
		inst.samples[index] = { holder = holder, button = b, label = label }
	end
	for position, entry in ipairs(FADERS) do
		local column, row = (position - 1) % 5, math.floor((position - 1) / 5)
		local tile = { key = entry[1] }
		tile.holder = Frame(inst.box)
		tile.holder:SetSize(TILE_W, TILE_H)
		tile.holder:SetPoint("TOPLEFT", inst.box, "TOPLEFT", column * TILE_PITCH, -(34 + 12 + row * TILE_ROW))
		tile.body = Frame(tile.holder)
		tile.body:SetAllPoints(tile.holder)
		local back = Tex(tile.body, "BACKGROUND", -7)
		back:SetAllPoints(tile.body)
		Colour(back, { 0.1, 0.1, 0.12, 1 })
		tile.outline = Outlined(inst, ns.SetOutlineArea(ns.Outline(tile.body, tile.body), "hud"))
		TileArt(inst, tile, entry[3], position)
		tile.label = Text(inst.labels, "GameFontHighlightSmall")
		tile.label:SetPoint("TOP", tile.holder, "BOTTOM", 0, -3)
		tile.label:SetText(entry[2])
		inst.tiles[position] = tile
		inst.parts["fade." .. entry[1]] = tile.body
	end
	inst.parts["fade.enabled"], inst.parts["fade.alpha"] = inst.box, inst.samples[2].holder
	Publish(FADE, inst)
	return inst
end

function FADE.draw(stage)
	local inst = FADE.built[Root(stage)] or FADE.build(stage)
	SetView(inst, stage)
	local enabled = ns.Get("fade.enabled") == true
	local alpha = ns.Get("fade.alpha") / 100
	local look = Look()
	look.on = look.enabled and ns.Get(AREA .. ".main") == true
	local standin = false
	for index, sample in ipairs(inst.samples) do
		sample.holder:SetAlpha((index == 2 and enabled) and alpha or 1)
		if PaintButton(sample.button, look) then
			standin = true
		end
	end
	Standin(inst, standin)
	inst.samples[2].label:SetText(enabled and ("Faded opacity " .. ns.Get("fade.alpha") .. "%") or "Faded opacity")
	for _, tile in ipairs(inst.tiles) do
		tile.body:SetAlpha((enabled and ns.Get("fade." .. tile.key) == true) and alpha or 1)
		if type(ns.RepaintOutline) == "function" then
			ns.RepaintOutline(tile.outline)
		end
	end
end

ns.SetupDrawings = ns.SetupDrawings or {}
ns.SetupDrawings["mock-action-row"] = ACTION
ns.SetupDrawings["mock-bar-block"] = BLOCK
ns.SetupDrawings["mock-block-places"] = PLACES
ns.SetupDrawings["mock-fade"] = FADE
