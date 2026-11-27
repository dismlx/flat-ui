local _, ns = ...

local KEY = "actionbars"

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

local PLATES = {
	{ "MainActionBar", "main" }, { "MultiBarBottomLeft", "extra" }, { "MultiBarBottomRight", "extra" }, { "MultiBarRight", "extra" },
	{ "MultiBarLeft", "extra" }, { "MultiBar5", "extra" }, { "MultiBar6", "extra" }, { "MultiBar7", "extra" },
	{ "StanceBar", "stance" }, { "PetActionBar", "pet" },
}
local plates = {}
local plateFailed = false
local withheldBy = setmetatable({}, { __mode = "k" })

local groups = setmetatable({}, { __mode = "k" })
local styled = setmetatable({}, { __mode = "k" })
local queued = setmetatable({}, { __mode = "k" })
local DIVIDER_EVERY = 0.25
local PLATE_EVERY = 0.2
local dividers = { clock = 0 }

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

local function FadeArt(button, on)
	ns.SetFaded(Texture(button, "NormalTexture", "GetNormalTexture"), on)
	ns.SetFaded(button.SlotArt, on)
	ns.SetFaded(button.SlotBackground, on)
	ns.SetFaded(button.overlayTex, on)
	ns.SetFaded(button.style, on)
end

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

local function Fill(button)
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

local function EdgesWanted(button)
	return Opt("border") or (marks[button] ~= nil and IsOn(button))
end

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

local lookSaid = { line = "Flat UI: action buttons take their new look when the fight ends.",
	keys = { "backdrop", "crop", "border", "empty", "emptyAlpha", "hoverColour", "pressedColour", "checkedColour" } }

function lookSaid.Check()
	local parts = {}
	for _, key in ipairs(lookSaid.keys) do
		parts[#parts + 1] = tostring(ns.Get(KEY .. "." .. key))
	end
	local sig = table.concat(parts, ";")
	if lookSaid.sig ~= nil and sig ~= lookSaid.sig and not lookSaid.told and InCombatLockdown() and type(ns.PanelShown) == "function"
		and ns.PanelShown() == true then
		lookSaid.told = true
		print(lookSaid.line)
	end
	lookSaid.sig = sig
end

local gameLookFrame = CreateFrame("Frame")
ns.Own[gameLookFrame] = true
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
	pcall(gameLookFrame.RegisterEvent, gameLookFrame, event)
end
gameLookFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		lookSaid.told = nil
	end
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
		local pr, pg, pb = ns.Colour(KEY .. ".pressedColour")
		Tint(Texture(button, "PushedTexture", "GetPushedTexture"), icon, pr, pg, pb, 0.25, true)
	end
end

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
	ns.SetOutlineEdges(own.outline, drawn or Opt("border"))
	return drawn
end

local function Hear()
	heard = false
	for _, fn in ipairs(listeners) do
		pcall(fn)
	end
end

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
			pcall(Layout, button)
		else
			ns.Each(KEY, Layout, button)
		end
	end)
end

local function Remember(button, group)
	groups[button] = group
end

local passQueued = false

local Plates

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

local function SyncOwn()
	if not OwnOn() then
		return false
	end
	Attach()
	local fresh = false
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

local function PlateBar(name)
	if OwnOn() and type(ns.OwnBarOf) == "function" then
		local ok, own = pcall(ns.OwnBarOf, name)
		if ok and type(own) == "table" then
			return own
		end
	end
	return _G[name]
end

local function PlateAnchor(state, bar)
	state.anchor = bar
	state.frame:ClearAllPoints()
	state.frame:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
	state.frame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
end

local function PlateSync(state, bar)
	local ok, visible = pcall(bar.IsVisible, bar)
	if ok and not ns.IsSecret(visible) and type(visible) == "boolean" and state.shown ~= visible then
		state.shown = visible
		state.frame:SetShown(visible)
	end
	local fine, alpha = pcall(bar.GetAlpha, bar)
	if fine and not ns.IsSecret(alpha) and type(alpha) == "number" and state.alpha ~= alpha then
		state.alpha = alpha
		state.frame:SetAlpha(alpha)
	end
end

local function Plate(entry)
	local name = entry[1]
	local bar = PlateBar(name)
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
				plates[name] = { frame = made }
				PlateAnchor(plates[name], bar)
				ns.Each(KEY, function()
					plates[name].outline = ns.Outline(made, made, true)
				end)
				if plates[name].outline then
					ns.SetOutline(plates[name].outline, true, true)
				end
			end)
			if not done then
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
	if state.anchor ~= bar and not InCombatLockdown() then
		PlateAnchor(state, bar)
	end
	local r, g, b = ns.Colour(KEY .. ".plateColour")
	ns.SetOutlineFill(state.outline, r, g, b, Opt("plateAlpha") / 100)
	PlateSync(state, bar)
end

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
			state.shown = false
			state.frame:Hide()
		end
	end
	PlateWatcher(any)
end

local function PlateStep(_, elapsed)
	if not plateWatch.on or ns.IsStopped(KEY) then
		return
	end
	for _, entry in ipairs(PLATES) do
		local state = plates[entry[1]]
		if state and state.outline and plateWatch.wanted[entry[1]] and state.anchor then
			PlateSync(state, state.anchor)
		end
	end
	plateWatch.clock = plateWatch.clock + elapsed
	if plateWatch.clock < PLATE_EVERY then
		return
	end
	plateWatch.clock = 0
	for _, entry in ipairs(PLATES) do
		local name = entry[1]
		if PlateWanted(entry) ~= (plateWatch.wanted[name] == true) then
			Plates()
			return
		end
		local state = plates[name]
		if state and state.outline and plateWatch.wanted[name] then
			local bar = PlateBar(name)
			if state.anchor ~= bar and not InCombatLockdown() then
				Plates()
				return
			end
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

local function FillAll()
	for button in pairs(groups) do
		if styled[button] then
			ns.Each(KEY, Fill, button)
		end
	end
end

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

local function FadeDividers(bar, hide, force)
	for _, key in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
		local pool = bar[key]
		if pool and pool.EnumerateActive then
			for divider in pool:EnumerateActive() do
				local ok, alpha = pcall(divider.GetAlpha, divider)
				if force or not hide or not ok or ns.IsSecret(alpha) or alpha ~= 0 then
					ns.SetFaded(divider, hide)
				end
			end
		end
	end
end

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

local function Watch()
	if watched or type(EventRegistry) ~= "table" or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	watched = pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", RestyleLater, dividers)
end

local function Refresh()
	lookSaid.Check()
	ns.Each(KEY, StyleBar)
	Plates()
	local own = OwnOn()
	SyncOwn()
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
	if type(ns.ButtonTextRefresh) == "function" then
		ns.ButtonTextRefresh()
	end
	if type(ns.OwnPagerChanged) == "function" then
		pcall(ns.OwnPagerChanged)
	end
end

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

function ns.OwnButtonsChanged()
	Changed()
	RestyleLater()
end

function ns.ButtonIsOwn(button)
	return OwnBarOf(button) ~= nil
end

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

function ns.ButtonsFor(kind, key)
	local found = (kind == "spell" or kind == "item") and Map()[kind][key] or nil
	local list = {}
	for index, button in ipairs(found or {}) do
		list[index] = button
	end
	return list
end

function ns.ActionButtonGroup(button)
	return button ~= nil and groups[button] or nil
end

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

function ns.ButtonSamples()
	local list = {}
	if not OwnOn() then
		return list
	end
	local buttons = OwnList()
	for bar = 1, 8 do
		for _, button in ipairs(buttons) do
			if #list >= 4 then
				return list
			end
			if OwnBarOf(button) == bar then
				local okShown, shown = pcall(button.IsVisible, button)
				local st = type(ns.OwnState) == "function" and ns.OwnState(button)
				if okShown and not ns.IsSecret(shown) and shown == true and type(st) == "table" and st.has == true then
					list[#list + 1] = button
				end
			end
		end
	end
	return list
end

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
		PLAYER_SPECIALIZATION_CHANGED = RestyleLater,
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

local function Sample(force)
	if not OwnOn() then
		return
	end
	local list = ns.ButtonSamples()
	if type(ns.ButtonEffectsSample) == "function" then
		ns.ButtonEffectsSample({ cast = list[1], interrupt = list[2], aim = list[3], glow = list[2] }, force)
	end
	local sweep = list[4] or list[#list]
	if sweep and type(ns.ButtonStatesSample) == "function" then
		ns.ButtonStatesSample(sweep, force)
	end
end

local function SampleOff()
	if type(ns.ButtonEffectsSampleOff) == "function" then
		ns.ButtonEffectsSampleOff()
	end
	if type(ns.ButtonStatesSampleOff) == "function" then
		ns.ButtonStatesSampleOff()
	end
end

local SAMPLE_COLOURS = { ["castbars.castColour"] = true, ["castbars.channelColour"] = true, ["castbars.interruptedColour"] = true,
	["castbars.playerClass"] = true, ["castbars.flat"] = true }
local SAMPLE_ROWS = { ["actionbars.castAnim"] = { "cast", 1 }, ["actionbars.interruptAnim"] = { "interrupt", 2 }, ["actionbars.aimAnim"] = { "aim", 3 },
	["actionbars.proc"] = { "glow", 2 }, ["actionbars.procColour"] = { "glow", 2 } }

local function Hold(held)
	if type(ns.ButtonEffectsSampleHold) == "function" then
		ns.ButtonEffectsSampleHold(held)
	end
	if type(ns.ButtonStatesSampleHold) == "function" then
		ns.ButtonStatesSampleHold(held)
	end
end

local function Still()
	local mode = ns.TestMode
	return mode ~= nil and type(mode.Moving) == "function" and not mode.Moving()
end

local function SampleChanged(path)
	if path == "*" then
		Sample(true)
		return
	end
	if path == "test.moving" then
		local held = Still()
		Hold(held)
		if held then
			Sample(true)
		end
		return
	end
	if type(path) ~= "string" or not OwnOn() then
		return
	end
	local row = SAMPLE_ROWS[path]
	if SAMPLE_COLOURS[path] then
		if type(ns.ButtonEffectsSampleLook) == "function" then
			ns.ButtonEffectsSampleLook()
		end
	elseif row then
		local button = ns.ButtonSamples()[row[2]]
		if button and type(ns.ButtonEffectsSample) == "function" then
			ns.ButtonEffectsSample({ [row[1]] = button })
		end
	elseif type(ns.ButtonStatesTint) == "function" and ns.ButtonStatesTint(ns.ButtonSamples()[1], path) then
		return
	elseif path:match("^actionbars%.") then
		local list = ns.ButtonSamples()
		local button = list[4] or list[#list]
		if button and type(ns.ButtonStatesSample) == "function" then
			ns.ButtonStatesSample(button)
		end
	end
end

if ns.TestMode then
	ns.TestMode.Register("actionbars", {
		module = KEY,
		label = "Action buttons",
		every = 5,
		Start = function()
			if Still() then
				Hold(true)
			end
			Sample(true)
		end,
		Tick = function()
			Sample(true)
		end,
		Stop = SampleOff,
		Changed = SampleChanged,
	})
end
