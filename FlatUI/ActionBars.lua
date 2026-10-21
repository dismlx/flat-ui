local _, ns = ...

-- Action buttons are protected frames: their regions can be recoloured at any time, but nothing
-- may be laid out on them in combat. Everything here runs out of combat. Nothing is hooked on a button or a bar: a hook on a
-- function of a protected frame runs inside the game's secure calls, and a Hide from one on MainActionBar ends in
-- ADDON_ACTION_BLOCKED at the next fight (EllesmereUIActionBars/EllesmereUIActionBars.lua:1069-1090, 1861-1880 and 1286-1291). The art
-- of a button is set again by UpdateButtonArt only when the button loads and when Edit Mode applies Hide bar art (ActionButton.lua:1610,
-- EditModeSystemTemplates.lua:1110-1121), so every button is styled again on the next frame after the events that run those: entering
-- the world, a layout update and the end of Edit Mode. The dividers the game lays out are faded by a frame of the addon's own.

local KEY = "actionbars"

-- Button name, count, and the option that switches the group.
local BUTTONS = {
	{ "ActionButton", 12, "main" },
	{ "MultiBarBottomLeftButton", 12, "extra" },
	{ "MultiBarBottomRightButton", 12, "extra" },
	{ "MultiBarLeftButton", 12, "extra" },
	{ "MultiBarRightButton", 12, "extra" },
	{ "MultiBar5Button", 12, "extra" },
	{ "MultiBar6Button", 12, "extra" },
	{ "MultiBar7Button", 12, "extra" },
	{ "PetActionButton", 10, "pet" },
	{ "StanceButton", 10, "stance" },
	{ "PossessButton", 2, "stance" },
	{ "MultiCastActionButton", 12, "totem" },
	{ "ExtraActionButton", 1, "ability" },
}

-- The bars that can have a flat panel behind them: the frame, and the group switch that goes with it.
local PLATES = {
	{ "MainActionBar", "main" }, { "MultiBarBottomLeft", "extra" }, { "MultiBarBottomRight", "extra" }, { "MultiBarRight", "extra" },
	{ "MultiBarLeft", "extra" }, { "MultiBar5", "extra" }, { "MultiBar6", "extra" }, { "MultiBar7", "extra" },
	{ "StanceBar", "stance" }, { "PetActionBar", "pet" },
}
local plates = {}
-- Whether the last panel that was made failed.
local plateFailed = false
-- The buttons whose HasAction answer the game withheld, or gave as no true or false.
local withheldBy = setmetatable({}, { __mode = "k" })

local groups = setmetatable({}, { __mode = "k" })
local styled = setmetatable({}, { __mode = "k" })
local queued = setmetatable({}, { __mode = "k" })
-- How often the dividers of the main bar are looked at, in seconds.
local DIVIDER_EVERY = 0.25
-- How often the bars are looked at for their panels, in seconds.
local PLATE_EVERY = 0.2
local dividers = { clock = 0 }

-- Marks on buttons: marks[button][source] = { r, g, b }, source "missing", "alert" or "proc". The map of what each button holds is made when asked
-- for and dropped when a button changes. The listeners hear of that once per frame.
local marks = setmetatable({}, { __mode = "k" })
local MARK_PX = 2
local map, listeners, heard = nil, {}, false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Texture(button, key, getter)
	local texture = button[key]
	if texture == nil and button[getter] then
		local ok, found = pcall(button[getter], button)
		texture = ok and found or nil
	end
	return texture
end

local function IsOn(button)
	return ns.Enabled(KEY) and Opt(groups[button]) and true or false
end

-- Flat UI's own buttons (OwnBars.lua) are found through the contract of that file: ns.OwnOn, ns.OwnButtons, ns.OwnBar, ns.OwnSlot, ns.OwnTwin and
-- ns.OnOwnSlots, and painted through ns.OwnPainter (OwnPaint.lua). Those files load after this one, so every call is looked up when it is made.
-- ownOf[button] is the bar number of a button found to be Flat UI's own.
local ownOf = setmetatable({}, { __mode = "k" })
local ownLook = setmetatable({}, { __mode = "k" })
local ownAttached = { painter = false, slots = false }

local function OwnOn()
	if type(ns.OwnOn) ~= "function" then
		return false
	end
	local ok, on = pcall(ns.OwnOn)
	return ok and on == true
end

local function OwnList()
	if type(ns.OwnButtons) ~= "function" then
		return {}
	end
	local ok, list = pcall(ns.OwnButtons)
	return ok and type(list) == "table" and list or {}
end

-- The bar number (1 to 8) of one of Flat UI's own buttons, or nil for any other frame.
local function OwnBarOf(button)
	if type(button) ~= "table" or ns.IsSecret(button) then
		return nil
	end
	local known = ownOf[button]
	if known then
		return known
	end
	if type(ns.OwnBar) ~= "function" then
		return nil
	end
	local ok, bar = pcall(ns.OwnBar, button)
	if ok and type(bar) == "number" and not ns.IsSecret(bar) then
		return bar
	end
	return nil
end

-- The frame art Blizzard puts back whenever it updates a button.
local function FadeArt(button, on)
	ns.SetFaded(Texture(button, "NormalTexture", "GetNormalTexture"), on)
	ns.SetFaded(button.SlotArt, on)
	ns.SetFaded(button.SlotBackground, on)
	-- The element ring of a totem button and the style art of the extra action button (MultiCastActionBarFrame.xml:32, ExtraActionBar.lua:15, 34, 54).
	-- Alpha of the button's own art only; the alpha of ExtraActionBarFrame is the game's.
	ns.SetFaded(button.overlayTex, on)
	ns.SetFaded(button.style, on)
end

-- A state texture becomes a flat tint over the icon. Blizzard still shows and hides it. place: lay it over the icon as well as colouring it.
local function Tint(texture, icon, r, g, b, a, place)
	if texture == nil or ns.IsSecret(texture) then
		return
	end
	texture:SetColorTexture(r, g, b, a)
	if place then
		texture:ClearAllPoints()
		texture:SetAllPoints(icon)
	end
end

-- Whether the slot of a button holds nothing: true or false, or nil when the game does not say. Only a plain true or false counts; anything else
-- is a withheld answer and is remembered for /flatui status. The game asks the same question in ActionButton.lua:1470-1471
-- (ActionBarActionButtonMixin:HasAction) and ActionBar.lua:208.
local function Empty(button)
	local api = C_ActionBar and C_ActionBar.HasAction
	if type(api) ~= "function" then
		return nil
	end
	local action = button.action
	if ns.IsSecret(action) then
		withheldBy[button] = true
		return nil
	end
	if type(action) ~= "number" then
		return nil
	end
	local ok, has = pcall(api, action)
	if not ok or ns.IsSecret(has) or type(has) ~= "boolean" then
		withheldBy[button] = true
		return nil
	end
	withheldBy[button] = nil
	return not has
end

-- The opacity of the outline of an empty button: texture calls only, so this is allowed in combat.
local function Fill(button)
	-- The empty look of one of Flat UI's buttons is the alpha of the whole button, given by the empty painter (OwnPaint.lua).
	if OwnBarOf(button) then
		withheldBy[button] = nil
		return
	end
	local own = styled[button]
	if not own or not own.outline then
		return
	end
	local group = groups[button]
	local mode = Opt("empty")
	local alpha, back
	if IsOn(button) and (group == "main" or group == "extra") and mode ~= "show" then
		if Empty(button) then
			alpha = mode == "hidden" and 0 or Opt("emptyAlpha") / 100
			back = alpha * ns.OutlineBackdropAlpha(own.outline)
		end
	else
		withheldBy[button] = nil
	end
	ns.SetOutlineAlpha(own.outline, alpha, back)
end

-- The edges of the outline of a button: its border option, and always while a mark is drawn.
local function EdgesWanted(button)
	return Opt("border") or (marks[button] ~= nil and IsOn(button))
end

-- With Restyle action bars off, one of Flat UI's buttons is drawn as the game draws a button of a bar: the frame art at 46 by 45 and the slot art
-- (ActionButtonOverrides.lua:6-16). Plain calls on the button's own regions, out of combat.
local function GameLook(button)
	if ownLook[button] == "game" then
		return
	end
	ownLook[button] = "game"
	if type(button.SetNormalAtlas) == "function" then
		pcall(button.SetNormalAtlas, button, "UI-HUD-ActionBar-IconFrame")
	end
	if type(button.SetPushedAtlas) == "function" then
		pcall(button.SetPushedAtlas, button, "UI-HUD-ActionBar-IconFrame-Down")
	end
	for _, key in ipairs({ "NormalTexture", "PushedTexture" }) do
		local texture = Texture(button, key, key == "NormalTexture" and "GetNormalTexture" or "GetPushedTexture")
		if texture ~= nil and not ns.IsSecret(texture) and texture.SetSize then
			pcall(texture.SetSize, texture, 46, 45)
		end
	end
	if button.SlotArt ~= nil and button.SlotArt.Show then
		pcall(button.SlotArt.Show, button.SlotArt)
	end
	if button.SlotBackground ~= nil and button.SlotBackground.Hide then
		pcall(button.SlotBackground.Hide, button.SlotBackground)
	end
end

-- With Restyle action bars off the module does not run, so a plain frame gives Flat UI's buttons the game's look when the world and the fights are over.
local function GameLookAll()
	if not OwnOn() or ns.Enabled(KEY) then
		return
	end
	for _, button in ipairs(OwnList()) do
		if OwnBarOf(button) then
			GameLook(button)
		end
	end
end

local gameLookFrame = CreateFrame("Frame")
ns.Own[gameLookFrame] = true
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
	pcall(gameLookFrame.RegisterEvent, gameLookFrame, event)
end
gameLookFrame:SetScript("OnEvent", function()
	if OwnOn() and not ns.Enabled(KEY) then
		ns.OutOfCombat(GameLookAll)
	end
end)

local function Place(button)
	local icon = button.icon
	if icon == nil then
		return
	end
	local on = IsOn(button)
	local own = styled[button]
	local flat = OwnBarOf(button) ~= nil
	if flat and on then
		ownLook[button] = "flat"
	end
	if not own then
		if not on then
			if flat then
				GameLook(button)
			end
			return
		end
		own = { outline = ns.Outline(button, icon), masked = true }
		styled[button] = own
		ns.Count(KEY)
	end
	ns.SetOutline(own.outline, on, Opt("backdrop"))
	ns.SetOutlineEdges(own.outline, EdgesWanted(button))
	FadeArt(button, on)
	local crop = on and Opt("crop") / 100 or 0
	icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	-- The rounded mask goes with Blizzard's rounded frame, so it comes back with it.
	local square = on and Opt("square")
	if button.IconMask and own.masked ~= not square and icon.RemoveMaskTexture and icon.AddMaskTexture then
		own.masked = not square
		pcall(square and icon.RemoveMaskTexture or icon.AddMaskTexture, icon, button.IconMask)
	end
	if not on then
		if flat then
			GameLook(button)
		end
		return
	end
	if square and not own.square then
		own.square = true
		for _, key in ipairs({ "cooldown", "chargeCooldown", "lossOfControlCooldown" }) do
			local cooldown = button[key]
			if cooldown and not ns.Forbidden(cooldown) then
				cooldown:ClearAllPoints()
				cooldown:SetAllPoints(icon)
			end
		end
	end
	if Opt("tints") then
		local first = not own.tints
		own.tints = true
		-- Blizzard colours the equipped outline green and the attack flash red itself. The colours of the state textures come from the
		-- Highlights rows; a change is painted again here when the page refreshes, and a texture is laid over the icon once.
		if first then
			Tint(button.Border, icon, 1, 1, 1, 0.35, true)
			Tint(button.Flash, icon, 1, 0, 0, 0.3, true)
			Tint(button.NewActionTexture, icon, 1, 1, 1, 0.25, true)
			Tint(button.SpellHighlightTexture, icon, 1, 0.82, 0, 0.5, true)
		end
		local hr, hg, hb = ns.Colour(KEY .. ".hoverColour")
		local hover = ("%g,%g,%g"):format(hr, hg, hb)
		if first or own.hover ~= hover then
			own.hover = hover
			Tint(Texture(button, "HighlightTexture", "GetHighlightTexture"), icon, hr, hg, hb, 0.2, first)
		end
		local cr, cg, cb = ns.Colour(KEY .. ".checkedColour")
		local checked = ("%g,%g,%g"):format(cr, cg, cb)
		if first or own.checked ~= checked then
			own.checked = checked
			Tint(Texture(button, "CheckedTexture", "GetCheckedTexture"), icon, cr, cg, cb, 0.3, first)
		end
		-- Blizzard sets the pressed art again on every art update.
		local pr, pg, pb = ns.Colour(KEY .. ".pressedColour")
		Tint(Texture(button, "PushedTexture", "GetPushedTexture"), icon, pr, pg, pb, 0.25, true)
	end
end

-- A mark is the outline's own colour at once, and its thickness out of combat: the thickness lays out the outline's edges, which are
-- children of a protected button. In a fight the colour changes and the thickness follows when the fight ends. A button with no outline,
-- or one that is not restyled, keeps the record and is marked when it is laid out.
local markQueued = setmetatable({}, { __mode = "k" })
local DrawMark

local function Thickness(button, px)
	local own = styled[button]
	if InCombatLockdown and InCombatLockdown() then
		if not markQueued[button] then
			markQueued[button] = true
			ns.OutOfCombat(function()
				markQueued[button] = nil
				DrawMark(button)
			end)
		end
		return
	end
	ns.SetOutlineThickness(own.outline, px)
end

function DrawMark(button)
	local own, record = styled[button], marks[button]
	if not own or not own.outline then
		return false
	end
	local source = record and (record.proc or record.alert or record.missing)
	local drawn = source ~= nil and IsOn(button)
	if drawn then
		ns.SetOutlineColour(own.outline, source[1], source[2], source[3])
		Thickness(button, MARK_PX)
	else
		ns.SetOutlineColour(own.outline, nil, nil, nil)
		Thickness(button, nil)
	end
	-- A mark shows its colour and thickness with the border off.
	ns.SetOutlineEdges(own.outline, drawn or Opt("border"))
	return drawn
end

local function Hear()
	heard = false
	for _, fn in ipairs(listeners) do
		pcall(fn)
	end
end

-- The buttons hold something else: the map is made again when it is next asked for.
local function Changed()
	map = nil
	if #listeners == 0 or heard then
		return
	end
	heard = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Hear)
	else
		Hear()
	end
end

local function Layout(button)
	Place(button)
	DrawMark(button)
	Fill(button)
	Changed()
end

local function Style(button)
	if ns.Forbidden(button) then
		return
	end
	-- A button that has its outline is faded or restored at once, which is allowed in combat.
	-- One that has none yet keeps Blizzard's art until Layout has made the outline.
	if styled[button] then
		FadeArt(button, IsOn(button))
	end
	if queued[button] then
		return
	end
	queued[button] = true
	ns.OutOfCombat(function()
		queued[button] = nil
		if ns.IsStopped(KEY) then
			-- Stopped while this waited: Layout puts Blizzard's art back.
			pcall(Layout, button)
		else
			ns.Each(KEY, Layout, button)
		end
	end)
end

-- Records the group of a button. Nothing is hooked.
local function Remember(button, group)
	groups[button] = group
end

local passQueued = false

local Plates

-- The empty painter: an empty slot of one of Flat UI's buttons is drawn at the Empty buttons setting, as alpha (the fourth value). The game shows the
-- twin of an empty slot while Edit Mode's Always show buttons is on or an action is dragged (ActionBar.lua:202-217), so a shown twin means normal.
local function EmptyPainter(button, state)
	if not IsOn(button) or type(state) ~= "table" or state.empty ~= true or state.grid == true then
		return nil
	end
	local mode = Opt("empty")
	if mode ~= "faint" and mode ~= "hidden" then
		return nil
	end
	if type(ns.OwnTwin) == "function" then
		local ok, twin = pcall(ns.OwnTwin, button)
		if ok and type(twin) == "table" and not ns.IsSecret(twin) then
			local asked, shown = pcall(twin.IsShown, twin)
			if asked and shown == true then
				return nil
			end
		end
	end
	return 1, 1, 1, mode == "hidden" and 0 or Opt("emptyAlpha") / 100
end

-- The painter and the slot watch of OwnPaint.lua and OwnBars.lua are joined once they exist.
local function Attach()
	if not ownAttached.painter and type(ns.OwnPainter) == "function" then
		ownAttached.painter = pcall(ns.OwnPainter, "empty", EmptyPainter)
	end
	if not ownAttached.slots and type(ns.OnOwnSlots) == "function" then
		ownAttached.slots = pcall(ns.OnOwnSlots, function()
			Changed()
		end)
	end
end

-- Flat UI's buttons that have been built are remembered, in group main (bar 1) or extra (bars 2 to 8). True when one is new.
local function SyncOwn()
	if not OwnOn() then
		return false
	end
	Attach()
	local fresh = false
	-- The game's buttons of bars 1 to 8 are key targets only: one that was remembered before Flat UI's buttons were built is given back its look.
	for _, entry in ipairs(BUTTONS) do
		if entry[3] == "main" or entry[3] == "extra" then
			for index = 1, entry[2] do
				local twin = _G[entry[1] .. index]
				if twin ~= nil and groups[twin] ~= nil then
					groups[twin] = nil
					if styled[twin] then
						ns.OutOfCombat(function()
							Layout(twin)
							styled[twin] = nil
						end)
					end
				end
			end
		end
	end
	for _, button in ipairs(OwnList()) do
		if groups[button] == nil then
			local bar = OwnBarOf(button)
			if bar then
				ownOf[button] = bar
				groups[button] = bar == 1 and "main" or "extra"
				fresh = true
			end
		end
	end
	return fresh
end

-- What the game does to a bar, copied to its panel: shown with the bar and as faint as the bar. Only a plain answer is used. SetShown and
-- SetAlpha are calls on the addon's own frame, so this is allowed in combat.
local function PlateSync(state, bar)
	local ok, visible = pcall(bar.IsVisible, bar)
	if ok and not ns.IsSecret(visible) and type(visible) == "boolean" then
		state.frame:SetShown(visible)
	end
	local fine, alpha = pcall(bar.GetAlpha, bar)
	if fine and not ns.IsSecret(alpha) and type(alpha) == "number" then
		state.frame:SetAlpha(alpha)
	end
end

-- The flat panel behind one bar, made out of combat and shown with the bar.
local function Plate(entry)
	local name = entry[1]
	local bar = _G[name]
	local state = plates[name]
	if state == false then
		return
	end
	if state == nil then
		plates[name] = false
		ns.OutOfCombat(function()
			local done = pcall(function()
				local made = CreateFrame("Frame", nil, UIParent)
				ns.Own[made] = true
				made:SetFrameStrata("BACKGROUND")
				made:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
				made:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
				plates[name] = { frame = made }
				ns.Each(KEY, function()
					plates[name].outline = ns.Outline(made, made, true)
				end)
				if plates[name].outline then
					ns.SetOutline(plates[name].outline, true, true)
				end
			end)
			if not done then
				-- A bar whose panel failed is tried again at the next pass, and /flatui status says so.
				plates[name] = nil
				plateFailed = true
				return
			end
			plateFailed = false
			Plates()
		end)
		return
	end
	if not state.outline then
		return
	end
	local r, g, b = ns.Colour(KEY .. ".plateColour")
	ns.SetOutlineFill(state.outline, r, g, b, Opt("plateAlpha") / 100)
	PlateSync(state, bar)
end

-- Whether a bar gets a panel of its own: the bar block gives a panel to the bars it holds when its own Background panel is on.
local function PlateWanted(entry)
	local bar = _G[entry[1]]
	if bar == nil or not ns.Enabled(KEY) or not Opt("plate") or not Opt(entry[2]) or ns.Forbidden(bar) then
		return false
	end
	if type(ns.MoverHeld) == "function" and ns.Get("barblock.background") and ns.MoverHeld(entry[1]).held then
		return false
	end
	return true
end

local plateWatch = { clock = 0, wanted = {} }
local PlateWatcher

function Plates()
	local any = false
	for _, entry in ipairs(PLATES) do
		local state = plates[entry[1]]
		local wanted = PlateWanted(entry)
		plateWatch.wanted[entry[1]] = wanted
		if wanted then
			any = true
			ns.Each(KEY, Plate, entry)
		elseif state then
			state.frame:Hide()
		end
	end
	PlateWatcher(any)
end

-- The game shows, hides and fades bars on events this module does not hear (the pet bar on PET_BAR_UPDATE and UNIT_PET, PetActionBar.lua:71-80,
-- the stance bar in its Update, StanceBar.lua:30-48, Edit Mode visibility, and Fade.lua) and a bar can be held or let go by the bar block
-- at any time. A frame of the addon's own looks at the bars four times a second while Bar background is on. It reads IsVisible and GetAlpha of
-- a bar, writes SetShown and SetAlpha on the panel, and goes through Plates again when a bar's wish for a panel has changed.
local function PlateStep(_, elapsed)
	plateWatch.clock = plateWatch.clock + elapsed
	if plateWatch.clock < PLATE_EVERY then
		return
	end
	plateWatch.clock = 0
	if not plateWatch.on or ns.IsStopped(KEY) then
		return
	end
	for _, entry in ipairs(PLATES) do
		local name = entry[1]
		if PlateWanted(entry) ~= (plateWatch.wanted[name] == true) then
			Plates()
			return
		end
		local state = plates[name]
		if state and state.outline and plateWatch.wanted[name] then
			PlateSync(state, _G[name])
		end
	end
end

function PlateWatcher(any)
	local wanted = any and true or false
	plateWatch.on = wanted
	if wanted and not plateWatch.frame and not plateWatch.making then
		plateWatch.making = true
		ns.OutOfCombat(function()
			plateWatch.making = nil
			if not plateWatch.frame then
				plateWatch.frame = CreateFrame("Frame")
				ns.Own[plateWatch.frame] = true
				plateWatch.frame:SetScript("OnUpdate", PlateStep)
				plateWatch.frame:SetShown(plateWatch.on == true)
			end
		end)
	end
	if plateWatch.frame then
		plateWatch.frame:SetShown(wanted)
	end
end

-- The empty buttons are looked at again.
local function FillAll()
	for button in pairs(groups) do
		if styled[button] then
			ns.Each(KEY, Fill, button)
		end
	end
end

-- Every remembered button is styled again, in one pass.
local function Restyle()
	passQueued = false
	Plates()
	if ns.IsStopped(KEY) then
		return
	end
	SyncOwn()
	for button in pairs(groups) do
		if styled[button] or IsOn(button) then
			ns.Each(KEY, Style, button)
		end
	end
end

-- A pass on the next frame: the game's code that runs on these events has finished by then.
local function RestyleLater()
	if passQueued then
		return
	end
	passQueued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Restyle)
	else
		Restyle()
	end
end

-- hide: whether the dividers are faded or given back. force: every divider is set, not only the ones the game made visible.
local function FadeDividers(bar, hide, force)
	for _, key in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
		local pool = bar[key]
		if pool and pool.EnumerateActive then
			for divider in pool:EnumerateActive() do
				-- While the dividers are hidden, only one the game has made visible is touched.
				local ok, alpha = pcall(divider.GetAlpha, divider)
				if force or not hide or not ok or ns.IsSecret(alpha) or alpha ~= 0 then
					ns.SetFaded(divider, hide)
				end
			end
		end
	end
end

-- The dividers are laid out by the game when the grid of the bar changes, in combat as well. A frame of the addon's own looks at them four
-- times a second while the main bar is shown and Hide dividers is on, and fades any that is not faded. SetAlpha is all it calls on a divider,
-- and it reads no option: the options are read when the page is refreshed (DividerWatch).
local function DividerStep(_, elapsed)
	dividers.clock = dividers.clock + elapsed
	if dividers.clock < DIVIDER_EVERY then
		return
	end
	dividers.clock = 0
	local bar = dividers.bar
	if not dividers.on or bar == nil or ns.IsStopped(KEY) then
		return
	end
	if type(ns.MoverShown) == "function" and ns.MoverShown(bar) == false then
		return
	end
	FadeDividers(bar, true)
end

-- The frame runs only while dividers are hidden on a bar that can be touched.
local function DividerWatch(bar, hide)
	local wanted = hide == true and not ns.Forbidden(bar)
	dividers.on, dividers.bar = wanted, wanted and bar or nil
	if wanted and not dividers.frame then
		dividers.frame = CreateFrame("Frame")
		ns.Own[dividers.frame] = true
		dividers.frame:SetScript("OnUpdate", DividerStep)
	end
	if dividers.frame then
		dividers.frame:SetShown(wanted)
	end
end

local function StyleBar()
	local bar = MainActionBar
	if bar == nil or ns.Forbidden(bar) then
		return
	end
	local on = ns.Enabled(KEY)
	ns.SetFaded(bar.BorderArt, on and Opt("frame"))
	local caps = bar.EndCaps
	if caps then
		ns.SetFaded(caps.LeftEndCap and caps.LeftEndCap.Texture, on and Opt("caps"))
		ns.SetFaded(caps.RightEndCap and caps.RightEndCap.Texture, on and Opt("caps"))
	end
	local hide = on and Opt("dividers") and true or false
	FadeDividers(bar, hide, true)
	DividerWatch(bar, hide)
end

local watched = false

-- The end of Edit Mode, which applies Hide bar art again. The game triggers it from inside its own exit, so the pass waits a frame.
local function Watch()
	if watched or type(EventRegistry) ~= "table" or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	watched = pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", RestyleLater, dividers)
end

local function Refresh()
	ns.Each(KEY, StyleBar)
	Plates()
	-- With Flat UI's own buttons the game's buttons of bars 1 to 8 are hidden key targets: nothing styles them.
	local own = OwnOn()
	SyncOwn()
	-- Chosen at login, the game's buttons of bars 1 to 8 are left alone from the start, so no code of Flat UI's runs on them before its buttons exist.
	local hands = own
	if not hands and type(ns.OwnWanted) == "function" then
		local ok, wanted = pcall(ns.OwnWanted)
		hands = ok and wanted == true
	end
	for _, button in ipairs(own and OwnList() or {}) do
		if groups[button] ~= nil and not ns.Forbidden(button) then
			ns.Each(KEY, Style, button)
		end
	end
	for _, entry in ipairs(BUTTONS) do
		if not (hands and (entry[3] == "main" or entry[3] == "extra")) then
			for index = 1, entry[2] do
				local button = _G[entry[1] .. index]
				if button ~= nil and not ns.Forbidden(button) then
					Remember(button, entry[3])
					ns.Each(KEY, Style, button)
				end
			end
		end
	end
	Watch()
	-- A switch (the module, a bar group) or a profile reaches the button text here.
	if type(ns.ButtonTextRefresh) == "function" then
		ns.ButtonTextRefresh()
	end
end

-- The restyled buttons, bar by bar.
-- True when the button's group is switched on.
function ns.ButtonIsOn(button)
	return groups[button] ~= nil and IsOn(button)
end

function ns.ActionButtons()
	local list = {}
	local own = OwnOn()
	if own then
		for _, button in ipairs(OwnList()) do
			if styled[button] and groups[button] ~= nil then
				list[#list + 1] = button
			end
		end
	end
	for _, entry in ipairs(BUTTONS) do
		if not (own and (entry[3] == "main" or entry[3] == "extra")) then
			for index = 1, entry[2] do
				local button = _G[entry[1] .. index]
				if button ~= nil and styled[button] then
					list[#list + 1] = button
				end
			end
		end
	end
	return list
end

-- Flat UI's buttons failed to build: the game's buttons are styled and hooked as without them.
function ns.OwnButtonsChanged()
	Changed()
	RestyleLater()
end

-- True for one of Flat UI's own buttons.
function ns.ButtonIsOwn(button)
	return OwnBarOf(button) ~= nil
end

-- True while only Flat UI's own buttons are styled: nothing of the game's button code then needs a hook. It holds from the choice of Flat UI's
-- buttons (ns.OwnWanted), before they are built, so a session that uses them never installs the hooks.
function ns.OwnLookOnly()
	local own = OwnOn()
	if not own and type(ns.OwnWanted) == "function" then
		local ok, wanted = pcall(ns.OwnWanted)
		own = ok and wanted == true
	end
	if not own then
		return false
	end
	for _, entry in ipairs(BUTTONS) do
		if not (entry[3] == "main" or entry[3] == "extra") then
			for index = 1, entry[2] do
				local button = _G[entry[1] .. index]
				if button and styled[button] then
					return false
				end
			end
		end
	end
	return true
end

-- What a button holds: "spell", the spell ID and its name, or "item" and the item ID. A macro that casts a spell is that spell. Nothing
-- for anything else, a withheld value or a failed call. GetActionInfo answers as ActionButton.lua:921-928 and 1037-1058 read it.
function ns.ButtonAction(button)
	local action
	if OwnBarOf(button) and type(ns.OwnSlot) == "function" then
		local ok, slot = pcall(ns.OwnSlot, button)
		action = ok and slot or nil
	else
		action = button.action
	end
	if type(action) ~= "number" or ns.IsSecret(action) or type(GetActionInfo) ~= "function" then
		return nil
	end
	local ok, kind, id, sub = pcall(GetActionInfo, action)
	if not ok or ns.IsSecret(kind) or ns.IsSecret(id) or ns.IsSecret(sub) or type(id) ~= "number" then
		return nil
	end
	if kind == "item" then
		return "item", id
	end
	if (kind == "spell" or (kind == "macro" and sub == "spell")) and C_Spell and C_Spell.GetSpellName then
		local named, name = pcall(C_Spell.GetSpellName, id)
		if not named or ns.IsSecret(name) or type(name) ~= "string" then
			return nil
		end
		return "spell", id, name
	end
	return nil
end

local function Map()
	if map then
		return map
	end
	map = { spell = {}, item = {} }
	for _, button in ipairs(ns.ActionButtons()) do
		local kind, id, name = ns.ButtonAction(button)
		local key = kind == "spell" and name:lower() or kind == "item" and id or nil
		if key ~= nil then
			local list = map[kind][key] or {}
			map[kind][key] = list
			list[#list + 1] = button
		end
	end
	return map
end

-- The restyled buttons that hold a spell, by its name in lower case (every rank has the name), or an item, by its ID.
function ns.ButtonsFor(kind, key)
	local found = (kind == "spell" or kind == "item") and Map()[kind][key] or nil
	local list = {}
	for index, button in ipairs(found or {}) do
		list[index] = button
	end
	return list
end

-- The group a remembered button is in: "main", "extra", "pet", "stance", "totem" or "ability", or nil.
function ns.ActionButtonGroup(button)
	return button ~= nil and groups[button] or nil
end

-- A mark on a button from one source: "missing", "alert" or "proc", the proc over the alert over the missing. No colour takes that source's mark away, and a button
-- with none left goes back to its own outline. True when the mark is drawn, false when it is kept for the button's layout.
function ns.SetButtonMark(button, source, r, g, b)
	if button == nil or (source ~= "missing" and source ~= "proc" and source ~= "alert") then
		return false
	end
	local record = marks[button]
	if r == nil then
		if record then
			record[source] = nil
			if record.proc == nil and record.alert == nil and record.missing == nil then
				marks[button] = nil
			end
		end
	else
		record = record or {}
		record[source] = { r, g, b }
		marks[button] = record
	end
	return DrawMark(button)
end

-- fn() runs after the map of the buttons is made again, once a frame at most.
function ns.OnButtonsChanged(fn)
	if type(fn) == "function" then
		listeners[#listeners + 1] = fn
	end
end

local function Marked()
	local n = 0
	for button in pairs(marks) do
		if styled[button] and IsOn(button) then
			n = n + 1
		end
	end
	return n
end

-- The game's own code that runs on these events has finished one frame later: the empty buttons and the bars are looked at then.
local laterQueued = false

local function LaterPass()
	laterQueued = false
	Plates()
	if not ns.IsStopped(KEY) then
		FillAll()
		if SyncOwn() then
			Restyle()
		end
	end
end

local function Later()
	Changed()
	if laterQueued then
		return
	end
	laterQueued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, LaterPass)
	else
		LaterPass()
	end
end

ns.Register(KEY, {
	label = "Action bars", Start = Refresh, Refresh = Refresh,
	events = {
		ACTIONBAR_SLOT_CHANGED = Later,
		ACTIONBAR_PAGE_CHANGED = Later,
		UPDATE_BONUS_ACTIONBAR = Later,
		ACTIONBAR_SHOWGRID = Later,
		ACTIONBAR_HIDEGRID = Later,
		SPELLS_CHANGED = Changed,
		PLAYER_ENTERING_WORLD = function()
			Changed()
			RestyleLater()
		end,
		EDIT_MODE_LAYOUTS_UPDATED = RestyleLater,
		-- The game applies the layout again on this event without EDIT_MODE_LAYOUTS_UPDATED (EditModeManager.lua:203-206).
		PLAYER_SPECIALIZATION_CHANGED = RestyleLater,
		-- Flat UI's buttons made at the end of a fight (a reload in combat) are styled when it ends.
		PLAYER_REGEN_ENABLED = function()
			if OwnOn() then
				RestyleLater()
			end
		end,
	},
	Status = function()
		local n = Marked()
		local lines = n > 0 and { ("Action bars: %d marked"):format(n) } or {}
		if next(withheldBy) ~= nil then
			lines[#lines + 1] = "Empty buttons: the game withholds which buttons are empty, so they look normal."
		end
		if ns.Enabled(KEY) and Opt("empty") ~= "show" and not (C_ActionBar and type(C_ActionBar.HasAction) == "function") then
			lines[#lines + 1] = "Empty buttons: the game does not say which buttons are empty, so they look normal."
		end
		if plateFailed then
			lines[#lines + 1] = "Bar background: a panel could not be made."
		end
		if Opt("totem") and _G.MultiCastActionButton1 == nil then
			lines[#lines + 1] = "Totem bar buttons: the game has no totem bar."
		end
		if Opt("ability") and _G.ExtraActionButton1 == nil then
			lines[#lines + 1] = "Extra action button: the game has no extra action button."
		end
		return lines
	end,
})
