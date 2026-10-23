local _, ns = ...

-- The welcome screen: what a new character sees at login in place of the offer panel, and what /flatui welcome opens. It has two views in one window:
-- three buttons (Set up Flat UI, Use a ready-made profile, Skip) and the ready-made profile tiles. The layout, when it shows, what Skip keeps, the
-- size and the tick are settings of the setup page (Config.lua). The tiles, the profile in use and the flag come from Setup.lua (S.Presets, S.UseReady,
-- S.Flag). Nothing here runs in combat.

local kit = ns.PanelKit
local S = ns.Setup
local W = { tiles = {} }
ns.Welcome = W

local GAME = "Game look"
local COMBAT = "In combat. Pick a profile after combat."
local PAD, MARK, TILE_GAP, FOOT = 16, 28, 10, 18
-- The size of a drawn card (SetupDraw.lua) and the room under it for a name and a line of three rows.
local CARD_W, CARD_H, TEXT_H = 336, 112, 62

local function Size()
	return tonumber(ns.Get("setup.welcomeSize")) == 640 and 640 or 520
end

-- True for a character the screen is for: the offer rule of Setup.lua with Profile on a new character at Show profiles, and with First login on
-- the account only while no character of the account has a profile.
function ns.WelcomeWanted()
	if not S.Offerable(true) then
		return false
	end
	return ns.Get("setup.welcomeWhen") ~= "account" or (next(ns.Account().profileOf) == nil and not (S.Store() or {}).welcomed)
end

-- Puts the profile named Game look in use: the profile of that name as it is, else a new one with every module off. Returns true, or false and why.
function W.GameLook()
	local found = S.FindProfile(GAME)
	if found then
		return ns.UseProfile(found)
	end
	local picks = {}
	for path, def in pairs(S.Defs()) do
		if def.key == "enabled" and def.kind == "bool" and def.default == true then
			picks[path] = false
		end
	end
	return ns.NewProfile(GAME, nil, picks)
end

-- Every button ends here: the flag is set and the screen closes. A ticked "Do not show on new characters" makes Default profile the choice for later
-- characters, unless the box of the profile step already named a profile for them.
function W.Done(named)
	S.Flag()
	local store = S.Store(true)
	if store then
		store.welcomed = true
	end
	if W.tick and not (named and W.share) and ns.Get("setup.welcomeTick") == "on" then
		ns.Set("setup.newCharacter", "default")
	end
	W.frame:Hide()
end

function W.Skip()
	if ns.Get("setup.welcomeSkip") == "game" then
		if InCombatLockdown() then
			W.line:SetText("In combat. Skip after combat.")
			return
		end
		local ok, why = W.GameLook()
		if not ok then
			W.line:SetText(tostring(why))
			return
		end
		print(("Flat UI: using %s. Restyled action bars and windows change after /reload."):format(S.FindProfile(GAME) or GAME))
	end
	W.Done()
end

function W.Pick(index)
	local tile = W.tiles[index]
	if not tile then
		return
	end
	local ok, why = S.UseReady(tile.profile.id)
	if not ok then
		W.line:SetText(why == "combat" and COMBAT or tostring(why))
		return
	end
	if W.share then
		ns.Set("setup.newCharacter", "preset:" .. tile.profile.id)
	end
	W.Done(true)
end

-- The building ---------------------------------------------------------------------------------------------

local function Tick(parent, text, onClick)
	local box = kit.Frame(parent)
	box:SetSize(18, 18)
	local edge = ns.Outline(box, box, true)
	local mark = kit.Fill(box, "ARTWORK")
	mark:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
	mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
	local label = kit.Label(parent, "GameFontHighlightSmall", "LEFT", 220)
	label:SetText(text)
	kit.Painted(function()
		kit.Backing(edge, "raised")
		mark:SetColorTexture(kit.Accent())
	end)
	kit.Clickable(box, onClick)
	mark:Hide()
	return box, mark, label
end

function W.BuildTiles(frame)
	for index, profile in ipairs(S.Presets()) do
		local entry = { profile = profile, values = profile.values }
		local tile = kit.Frame(frame)
		local edge = ns.Outline(tile, tile, true)
		kit.Painted(function()
			kit.Backing(edge, "raised")
		end)
		entry.frame = tile
		entry.card = ns.SetupDraw.Card(tile, ns.SetupDraw.CardView(function()
			return entry.values
		end))
		entry.card.frame:SetPoint("TOPLEFT", tile, "TOPLEFT", 0, 0)
		entry.name = kit.Label(tile, "GameFontNormal", "LEFT")
		entry.name:SetText(profile.label)
		entry.line = kit.Dim(kit.Label(tile, "GameFontHighlightSmall", "LEFT", nil, true))
		entry.line:SetText(profile.line)
		-- The tag is on a frame of its own, above every frame of the picture.
		local tag = kit.Frame(tile)
		tag:SetFrameLevel(tile:GetFrameLevel() + 10)
		tag:SetSize(88, 16)
		tag:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -4, -4)
		local back = kit.Fill(tag, "BACKGROUND")
		back:SetAllPoints(tag)
		kit.Painted(function()
			kit.Solid(back, "window", 0.9)
		end)
		entry.tagText = kit.Label(tag, "GameFontHighlightSmall", "CENTER", 88)
		entry.tagText:SetPoint("CENTER", tag, "CENTER", 0, 0)
		tag:Hide()
		entry.tag = tag
		kit.Clickable(tile, function()
			W.Pick(index)
		end)
		tile:SetScript("OnEnter", function()
			ns.SetOutlineColour(edge, kit.Accent())
		end)
		tile:SetScript("OnLeave", function()
			ns.SetOutlineColour(edge, nil, nil, nil)
		end)
		W.tiles[index] = entry
	end
end

function W.Build()
	local frame = CreateFrame("Frame", "FlatUIWelcome", UIParent)
	ns.Own[frame] = true
	frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
	frame:SetFrameStrata("HIGH")
	-- Above the options window, which is in the same strata.
	frame:SetFrameLevel(200)
	frame:EnableMouse(true)
	local outline = ns.Outline(frame, frame, true)
	kit.Painted(function()
		kit.Backing(outline, "window", 0.98)
	end)
	W.frame = frame
	-- The mark: an accent square with a notch cut from one corner.
	W.mark = kit.Fill(frame, "ARTWORK")
	W.mark:SetSize(MARK, MARK)
	W.notch = kit.Fill(frame, "OVERLAY")
	W.notch:SetSize(MARK / 3, MARK / 3)
	W.notch:SetPoint("TOPRIGHT", W.mark, "TOPRIGHT", 0, 0)
	kit.Painted(function()
		W.mark:SetColorTexture(kit.Accent())
		kit.Solid(W.notch, "window")
	end)
	W.title = kit.Label(frame, "GameFontNormalLarge", "LEFT", 400)
	W.title:SetText("Welcome to Flat UI")
	W.line = kit.Label(frame, "GameFontHighlight", "LEFT")
	W.setup = kit.Button(frame, "Set up Flat UI", 100, function()
		W.Done()
		ns.OpenSetup()
	end, true)
	W.ready = kit.Button(frame, "Use a ready-made profile", 100, function()
		W.view = "tiles"
		W.Update()
	end)
	W.step = kit.Button(frame, "Set up step by step", 180, function()
		W.Done()
		ns.OpenSetup()
	end, true)
	W.skip = kit.Button(frame, "Skip", 100, W.Skip)
	W.same, W.sameText = kit.Button(frame, "Same as", 200, function()
		local name = W.sameName
		if not name then
			return
		end
		if InCombatLockdown() then
			W.line:SetText(COMBAT)
			return
		end
		local ok, why = ns.UseProfile(name)
		if not ok then
			W.line:SetText(tostring(why))
			return
		end
		print(("Flat UI: using %s."):format(S.FindProfile(name) or name))
		if W.share then
			ns.Set("setup.newCharacter", S.ShareMode(S.FindProfile(name) or name))
		end
		W.Done(true)
	end)
	W.back = kit.Button(frame, "Back", 100, function()
		W.view, W.share = "buttons", false
		W.Update()
	end)
	W.shareBox, W.shareMark, W.shareLabel = Tick(frame, "Same profile on new characters", function()
		W.share = not W.share
		W.shareMark:SetShown(W.share)
	end)
	W.foot = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", 220))
	W.foot:SetText("Open it later with /flatui setup.")
	W.foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD + 2)
	W.tickBox, W.tickMark, W.tickLabel = Tick(frame, "Do not show on new characters", function()
		W.tick = not W.tick
		W.tickMark:SetShown(W.tick)
	end)
	W.tickBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
	W.tickLabel:SetPoint("RIGHT", W.tickBox, "LEFT", -8, 0)
	W.tickLabel:SetJustifyH("RIGHT")
	frame:SetScript("OnShow", function()
		W.tick, W.share = false, false
		W.tickMark:Hide()
		W.shareMark:Hide()
		W.view = ns.Get("setup.welcomeLayout") == "tiles" and "tiles" or "buttons"
		W.Update()
	end)
	-- The events go to a frame of their own: the screen hides itself, and a hidden frame still hears them.
	local listener = CreateFrame("Frame")
	ns.Own[listener] = true
	listener:RegisterEvent("PLAYER_REGEN_DISABLED")
	listener:RegisterEvent("UI_SCALE_CHANGED")
	listener:RegisterEvent("DISPLAY_SIZE_CHANGED")
	listener:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			frame:Hide()
		elseif frame:IsShown() then
			W.Update()
		end
	end)
	-- Escape closes it and chooses nothing, so it shows again at the next login.
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "FlatUIWelcome")
	end
	frame:Hide()
	return frame
end

-- Lays the view out and reads the profiles again: the size, the line, the buttons or the tiles, the tick. The height fits what is shown.
function W.Update()
	local frame = W.frame
	if not frame then
		return
	end
	local width = Size()
	local inner = width - 2 * PAD
	local tiles = W.view == "tiles"
	local function At(object, y, x)
		object:ClearAllPoints()
		object:SetPoint("TOPLEFT", frame, "TOPLEFT", x or PAD, -y)
	end
	W.mark:ClearAllPoints()
	W.mark:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
	W.title:ClearAllPoints()
	W.title:SetPoint("LEFT", W.mark, "RIGHT", 12, 0)
	local y = PAD + MARK + 14
	W.line:SetWidth(inner)
	At(W.line, y)
	if tiles then
		W.line:SetText(InCombatLockdown() and COMBAT or (ns.Get("setup.welcomeLayout") == "tiles" and "Pick a profile, or set one up step by step." or S.PICK_LINE))
	else
		W.line:SetText("Pick how Flat UI looks on this character.")
	end
	y = y + 26
	for _, object in ipairs({ W.setup, W.ready, W.step, W.skip, W.back, W.same, W.shareBox, W.shareLabel }) do
		object:Hide()
	end
	for _, entry in ipairs(W.tiles) do
		entry.frame:Hide()
	end
	if tiles then
		if #W.tiles == 0 then
			W.BuildTiles(frame)
		end
		local across = (inner - 2 * TILE_GAP) / 3
		local scale = across / CARD_W
		local picture = math.floor(CARD_H * scale + 0.5)
		local high = picture + TEXT_H
		local pick, using, db = S.Recommend(), ns.Profile(), ns.Account()
		for index, entry in ipairs(W.tiles) do
			local found = S.FindProfile(entry.profile.label)
			local saved = found and type(db) == "table" and type(db.profiles) == "table" and db.profiles[found]
			entry.values = saved and saved.options or entry.profile.values
			local tag = (found and found == using and "In use") or (entry.profile.id == pick and "Recommended") or nil
			entry.tag:SetShown(tag ~= nil)
			entry.tagText:SetText(tag or "")
			entry.frame:SetSize(across, high)
			At(entry.frame, y + math.floor((index - 1) / 3) * (high + TILE_GAP), PAD + ((index - 1) % 3) * (across + TILE_GAP))
			entry.card.frame:SetScale(scale)
			entry.name:ClearAllPoints()
			entry.name:SetPoint("TOPLEFT", entry.frame, "TOPLEFT", 8, -(picture + 4))
			entry.line:ClearAllPoints()
			entry.line:SetPoint("TOPLEFT", entry.frame, "TOPLEFT", 8, -(picture + 22))
			entry.line:SetWidth(across - 16)
			entry.frame:Show()
			entry.card.Paint()
		end
		y = y + math.ceil(#W.tiles / 3) * (high + TILE_GAP) + 2
		At(W.shareBox, y)
		W.shareLabel:ClearAllPoints()
		W.shareLabel:SetPoint("LEFT", W.shareBox, "RIGHT", 8, 0)
		W.shareMark:SetShown(W.share == true)
		W.shareBox:Show()
		W.shareLabel:Show()
		W.sameName = S.MostUsed()
		if W.sameName then
			W.sameText:SetText("Same as " .. S.Short(W.sameName))
			At(W.same, y - 4, width - PAD - W.same:GetWidth())
			W.same:Show()
		end
		y = y + 28
		local first = ns.Get("setup.welcomeLayout") == "tiles" and W.step or W.back
		At(first, y)
		W.skip:SetWidth(100)
		At(W.skip, y, PAD + first:GetWidth() + 8)
		first:Show()
	else
		for index, button in ipairs({ W.setup, W.ready, W.skip }) do
			button:SetWidth(inner)
			At(button, y + (index - 1) * (kit.BUTTON + 8))
			button:Show()
		end
		y = y + 2 * (kit.BUTTON + 8)
	end
	W.skip:Show()
	y = y + kit.BUTTON
	local ticked = ns.Get("setup.welcomeTick") == "on"
	W.tickBox:SetShown(ticked)
	W.tickLabel:SetShown(ticked)
	frame:SetSize(width, y + 20 + FOOT + PAD)
end

function W.Show()
	local frame = W.frame or W.Build()
	frame:Show()
end

-- At login, a second after the other windows: the screen for a character it is for. Setup.lua hands it here.
function ns.WelcomeShow()
	if ns.WelcomeWanted() and not InCombatLockdown() then
		W.Show()
	end
end

-- /flatui welcome: the screen, for any character. Nothing is chosen until a button is pressed.
function ns.OpenWelcome()
	if InCombatLockdown() then
		print("The welcome screen opens after combat.")
	end
	ns.OutOfCombat(W.Show)
	return true
end