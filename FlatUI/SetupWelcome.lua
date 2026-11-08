local _, ns = ...

-- The welcome screen: what a new character sees at login and what /flatui welcome opens. It is also the one picker of the ready-made looks
-- (ns.OpenProfiles: /flatui profiles, Ready-made on Home, the Profiles page and the list of setup open it) and the card that says what setup's Finish or
-- a look did (ns.SetupAfter). One frame of Flat UI's own with three views: start (the player's frame drawn as the profile in use draws it, then Set up
-- my screen, Ready-made looks and Keep this look), tiles (a drawn card of each ready-made look: a click puts it in use) and after (the profile in use,
-- what needs a reload, then Reload, Change it, Move frames, Options and Done). The tiles, the profile in use and the flag come from Setup.lua
-- (S.Presets, S.UseReady, S.Flag), the drawings from SetupDraw.lua (D.PaintIn with the frames build's mock-player, D.Card). When the screen shows and
-- what Keep this look keeps are settings in the Setup section of the Flat UI page (Config.lua). It hides when a fight starts, and no look is put in
-- use in one.

local kit = ns.PanelKit
local S = ns.Setup
local D = ns.SetupDraw
local W = { tiles = {}, notes = {}, view = "start" }
ns.Welcome = W

local GAME = "Game look"
local COMBAT = "In combat. Pick a look after combat."
local WIDTH, PAD, MARK, GAP, TILE_GAP, FOOT, SAME_W = 640, 16, 28, 8, 10, 18, 200
local INNER = WIDTH - 2 * PAD
-- The band of the start view: its top, its height and the box the drawing fits in, at most 1.8 times its size (SetupDraw.lua, D.PaintIn).
local BAND_Y, BAND_H, DRAW_H, MOST = 92, 120, 112, 1.8
-- The ground behind the drawing while SetupDraw.lua gives none.
local GROUND = { 0.32, 0.27, 0.20 }
-- The size of a drawn card (SetupDraw.lua) and the room under it for a name and a line of three rows.
local CARD_W, CARD_H, TEXT_H = 336, 112, 62

local function IsText(value)
	return not ns.IsSecret(value) and type(value) == "string"
end

-- The height of a text as it wraps now, or `fallback` when the client does not say.
local function Height(text, fallback)
	local ok, height = pcall(text.GetStringHeight, text)
	if ok and not ns.IsSecret(height) and type(height) == "number" and height > 0 and height < 1000 then
		return math.ceil(height)
	end
	return fallback
end

-- True for a character the screen is for: the offer rule of Setup.lua with Profile on a new character at its first line ("ask", the welcome screen),
-- and with First login on the account only while no character of the account has a profile.
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

-- A choice of the screen ends here: the flag is set and the screen closes, or with `keep` stays for the after view. A ticked "Do not show on new
-- characters" makes Default profile the choice for later characters, unless the box of the tiles already named a profile for them.
function W.Done(named, keep)
	S.Flag()
	local store = S.Store(true)
	if store then
		store.welcomed = true
	end
	if W.tick and not (named and W.share) then
		ns.Set("setup.newCharacter", "default")
	end
	if not keep then
		W.frame:Hide()
	end
end

-- The screen closes and Flat UI setup opens (Setup.lua), at this character's draft or at its first stop.
function W.OpenSetup()
	W.frame:Hide()
	if type(ns.OpenSetup) == "function" then
		ns.OpenSetup()
	end
end

-- Set up my screen sets no flag: setup left without a choice keeps no draft, so the screen comes back at the next login. The tick still counts.
function W.Setup()
	if W.tick then
		ns.Set("setup.newCharacter", "default")
	end
	W.OpenSetup()
end

-- Keep this look: the profile in use as it is, or with Keep this look uses at The game's look, the profile named Game look.
function W.Keep()
	local game = ns.Get("setup.welcomeSkip") == "game"
	if game then
		if InCombatLockdown() then
			W.line:SetText(COMBAT)
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
	if game then
		W.Used()
	end
end

-- After a look is put in use here (a tile, Same as, Use the game's look): setup, while it has the options window, closes so the screen shows the look.
-- Its draft is kept, and the next opening (Change it) starts it on the look.
function W.Used()
	if type(ns.PanelInMode) == "function" and ns.PanelInMode() then
		kit.Hide()
	end
end

-- A click on a tile: its look is put in use (S.UseReady sets the flag and says it in chat), and the after view says which. In combat the line says so
-- and nothing changes.
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
	W.Done(true, true)
	W.Used()
	W.ShowAfter({ name = ns.Profile() or tile.profile.label, ready = true })
end

-- Same as: the profile most characters of the account use, put in use as it is.
function W.Same()
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
	local used = S.FindProfile(name) or name
	print(("Flat UI: using %s."):format(used))
	if W.share then
		ns.Set("setup.newCharacter", S.ShareMode(used))
	end
	W.Done(true)
	W.Used()
end

-- Move frames: the screen closes and the handles open, as /flatui move opens them.
function W.Move()
	W.frame:Hide()
	local module = ns.modules and ns.modules.movers
	local command = module and module.slash and module.slash.move
	if type(command) == "function" then
		local ok, err = pcall(command, "")
		if not ok then
			geterrorhandler()(err)
		end
	end
end

-- Options: the screen closes and the options window opens at its pages. A setup that has the window leaves it first.
function W.Options()
	W.frame:Hide()
	if type(ns.PanelInMode) == "function" and ns.PanelInMode() then
		kit.Hide()
	end
	if type(ns.PanelShown) ~= "function" or not ns.PanelShown() then
		ns.OpenPanel()
	end
end

-- The Reload button of the after view, made the first time a reload is needed and only out of combat: Reload.lua lays its secure button over it
-- then (ns.SecureReload) and takes it off the screen while a fight lasts.
function W.ReloadButton()
	if not W.reload and not InCombatLockdown() then
		W.reload = kit.Button(W.frame, "Reload", 90, function()
			ns.Reload()
		end)
		if type(ns.SecureReload) == "function" then
			ns.SecureReload(W.reload)
		end
	end
	return W.reload
end

-- What the after view says first: the look put in use, the new profile, or the profile saved and how many characters use it.
function W.AfterLine(finished)
	local name = IsText(finished.name) and finished.name ~= "" and finished.name or tostring(ns.Profile())
	if finished.ready then
		return ("%s is in use."):format(name)
	elseif finished.new then
		return ("%s is your new profile, now in use."):format(name)
	end
	local users = finished.users
	if not ns.IsSecret(users) and type(users) == "number" and users > 1 then
		return ("%s is saved. %d characters use it."):format(name, users)
	end
	return ("%s is saved."):format(name)
end

-- The notes of the after view, one a line: each setting that needs a reload (S.ReloadText of an entry of S.ReloadLines, or the sentence itself), each
-- game setting the game kept (its text, or an entry { text, path, value }), each problem of the lists that ran at Finish. The second answer is true
-- when a reload is needed.
function W.AfterNotes(finished)
	local texts, reload = {}, false
	local function List(value)
		return type(value) == "table" and value or {}
	end
	for _, entry in ipairs(List(finished.reloadLines)) do
		local ok, text = IsText(entry), entry
		if type(entry) == "table" and type(S.ReloadText) == "function" then
			ok, text = pcall(S.ReloadText, entry)
		end
		if ok and IsText(text) and text ~= "" then
			texts[#texts + 1] = text
			reload = true
		end
	end
	for _, entry in ipairs(List(finished.kept)) do
		local text = type(entry) == "table" and entry.text or entry
		if IsText(text) and text ~= "" then
			texts[#texts + 1] = ("The game kept %s."):format(text)
		end
	end
	for _, text in ipairs(List(finished.problems)) do
		if IsText(text) and text ~= "" then
			texts[#texts + 1] = text
		end
	end
	return texts, reload
end

-- The after view, for what setup's Finish or a tile did: `finished` is { name, new, ready, users, reloadLines, kept, problems } (Setup.lua, S.Finish).
function W.ShowAfter(finished)
	return W.Open("after", type(finished) == "table" and finished or {})
end

-- Setup's Finish hands over here once the options window has closed, so the card sits over the screen it changed. Out of combat only, as Finish is.
function ns.SetupAfter(finished)
	if InCombatLockdown() then
		return false
	end
	return W.ShowAfter(finished)
end

-- The ready-made looks: the tiles view, for any character. Nothing is chosen until a click.
function ns.OpenProfiles()
	return W.Open("tiles")
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
	local card, cardView = D and D.Card, D and D.CardView
	for index, profile in ipairs(S.Presets()) do
		local entry = { profile = profile, values = profile.values }
		local tile = kit.Frame(frame)
		local edge = ns.Outline(tile, tile, true)
		kit.Painted(function()
			kit.Backing(edge, "raised")
		end)
		entry.frame = tile
		-- The picture of the look; without the card of SetupDraw.lua the tile keeps its name and line.
		if type(card) == "function" and type(cardView) == "function" then
			entry.card = card(tile, cardView(function()
				return entry.values
			end))
		else
			entry.card = { frame = kit.Frame(tile), Paint = function() end }
		end
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

-- The band of the start view: the ground, and over it a holder that clips a stage of its own, which draws under the profile in use (ns.LiveView).
function W.BuildBand(frame)
	local band = kit.Frame(frame)
	band:SetSize(INNER, BAND_H)
	local ground = kit.Fill(band, "BACKGROUND")
	ground:SetAllPoints(band)
	local colour = D and type(D.GROUND) == "table" and type(D.GROUND[3]) == "number" and D.GROUND or GROUND
	ground:SetColorTexture(colour[1], colour[2], colour[3], 1)
	local holder = kit.Frame(band)
	holder:SetAllPoints(band)
	holder:SetClipsChildren(true)
	W.band = band
	if D and type(D.Context) == "function" then
		W.ctx = D.Context(holder, ns.LiveView)
	end
end

-- Draws the player's frame in the band as the profile in use draws it: the drawing mock-player of the frames build, fitted with D.PaintIn. True when it
-- drew; without either the band shows its ground only.
function W.Paint()
	if not (W.ctx and type(D.PaintIn) == "function") then
		return false
	end
	local ok, painted = pcall(D.PaintIn, W.ctx, "mock-player", INNER, DRAW_H, MOST)
	if not ok then
		geterrorhandler()(painted)
		return false
	end
	return painted == true
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
	W.line = kit.Label(frame, "GameFontHighlight", "LEFT", INNER, true)
	-- The start view: the band, its caption and three buttons.
	W.BuildBand(frame)
	W.caption = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", INNER))
	W.caption:SetText("Your frame as Flat UI draws it now.")
	W.setup = kit.Button(frame, "Set up my screen", INNER, W.Setup, true)
	W.ready = kit.Button(frame, "Ready-made looks", INNER, function()
		W.view = "tiles"
		W.Update()
	end)
	W.keep, W.keepText = kit.Button(frame, "Keep this look", INNER, W.Keep)
	-- The tiles view: the tiles are made the first time it shows (W.BuildTiles).
	W.same, W.sameText = kit.Button(frame, "Same as", SAME_W, W.Same)
	W.back = kit.Button(frame, "Back", 100, function()
		W.view, W.share = "start", false
		W.Update()
	end)
	W.shareBox, W.shareMark, W.shareLabel = Tick(frame, "Same profile on new characters", function()
		W.share = not W.share
		W.shareMark:SetShown(W.share)
	end)
	-- The after view: Reload is made the first time a reload is needed (W.ReloadButton).
	W.change = kit.Button(frame, "Change it", 110, W.OpenSetup)
	W.move = kit.Button(frame, "Move frames", 110, W.Move)
	W.options = kit.Button(frame, "Options", 90, W.Options)
	W.done = kit.Button(frame, "Done", 90, function()
		frame:Hide()
	end)
	-- The foot and the tick, under the start and tiles views.
	W.foot = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", 220))
	W.foot:SetText("Open it again with /flatui setup.")
	W.foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD + 2)
	W.tickBox, W.tickMark, W.tickLabel = Tick(frame, "Do not show on new characters", function()
		W.tick = not W.tick
		W.tickMark:SetShown(W.tick)
	end)
	W.tickBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
	W.tickLabel:SetPoint("RIGHT", W.tickBox, "LEFT", -8, 0)
	W.tickLabel:SetJustifyH("RIGHT")
	-- Every part a view may show, hidden before each layout.
	W.parts = { W.band, W.caption, W.setup, W.ready, W.keep, W.same, W.back, W.shareBox, W.shareLabel, W.change, W.move, W.options, W.done, W.foot,
		W.tickBox, W.tickLabel }
	-- The view is set before the screen shows (W.Open); the ticks start empty each time.
	frame:SetScript("OnShow", function()
		W.tick, W.share = false, false
		W.tickMark:Hide()
		W.shareMark:Hide()
		W.Update()
	end)
	-- The events go to a frame of their own: the screen hides itself, and a hidden frame still hears them.
	local listener = CreateFrame("Frame")
	ns.Own[listener] = true
	listener:RegisterEvent("PLAYER_REGEN_DISABLED")
	listener:RegisterEvent("PLAYER_REGEN_ENABLED")
	listener:RegisterEvent("UI_SCALE_CHANGED")
	listener:RegisterEvent("DISPLAY_SIZE_CHANGED")
	listener:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			frame:Hide()
		elseif frame:IsShown() then
			W.Update()
		end
	end)
	-- Escape closes it and chooses nothing, so the start view shows again at the next login.
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "FlatUIWelcome")
	end
	frame:Hide()
	return frame
end

-- Puts a part of the screen at y below its top, at x (PAD when nil).
function W.At(object, y, x)
	object:ClearAllPoints()
	object:SetPoint("TOPLEFT", W.frame, "TOPLEFT", x or PAD, -y)
end

local function ShowFoot()
	W.foot:Show()
	W.tickBox:Show()
	W.tickLabel:Show()
	W.tickMark:SetShown(W.tick == true)
end

-- The start view: the line, the band with the player's frame (painted on every layout), its caption, the three buttons, the foot and the tick.
function W.LayoutStart(y)
	W.title:SetText("Welcome to Flat UI")
	W.line:SetText("Flat UI is on. Walk round your screen and pick how each part looks: six short stops, about two minutes.")
	y = math.max(BAND_Y, y + Height(W.line, 30) + 4)
	W.At(W.band, y)
	W.band:Show()
	-- The caption only describes a frame that was drawn.
	W.caption:SetShown(W.Paint())
	y = y + BAND_H + 6
	W.At(W.caption, y)
	y = y + 24
	W.keepText:SetText(ns.Get("setup.welcomeSkip") == "game" and "Use the game's look" or "Keep this look")
	for index, button in ipairs({ W.setup, W.ready, W.keep }) do
		W.At(button, y + (index - 1) * (kit.BUTTON + GAP))
		button:Show()
	end
	y = y + 3 * kit.BUTTON + 2 * GAP
	ShowFoot()
	return y + 20 + FOOT + PAD
end

-- The tiles view: a drawn card of each ready-made look, three to a row, with its name, its line and a tag (In use, else Suggested), then the box that
-- gives new characters the same look, Same as, Back, the foot and the tick.
function W.LayoutTiles(y)
	W.title:SetText("Ready-made looks")
	W.line:SetText(InCombatLockdown() and COMBAT or "Click a look to use it.")
	y = y + 26
	if #W.tiles == 0 then
		W.BuildTiles(W.frame)
	end
	local across = (INNER - 2 * TILE_GAP) / 3
	local scale = across / CARD_W
	local picture = math.floor(CARD_H * scale + 0.5)
	local high = picture + TEXT_H
	local pick, using, db = S.Recommend(), ns.Profile(), ns.Account()
	for index, entry in ipairs(W.tiles) do
		local found = S.FindProfile(entry.profile.label)
		local saved = found and type(db) == "table" and type(db.profiles) == "table" and db.profiles[found]
		entry.values = saved and saved.options or entry.profile.values
		local tag = (found and found == using and "In use") or (entry.profile.id == pick and "Suggested") or nil
		entry.tag:SetShown(tag ~= nil)
		entry.tagText:SetText(tag or "")
		entry.frame:SetSize(across, high)
		W.At(entry.frame, y + math.floor((index - 1) / 3) * (high + TILE_GAP), PAD + ((index - 1) % 3) * (across + TILE_GAP))
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
	W.At(W.shareBox, y)
	W.shareLabel:ClearAllPoints()
	W.shareLabel:SetPoint("LEFT", W.shareBox, "RIGHT", 8, 0)
	W.shareMark:SetShown(W.share == true)
	W.shareBox:Show()
	W.shareLabel:Show()
	W.sameName = S.MostUsed()
	if W.sameName then
		W.sameText:SetText("Same as " .. S.Short(W.sameName))
		W.At(W.same, y - 4, WIDTH - PAD - SAME_W)
		W.same:Show()
	end
	y = y + 28
	W.At(W.back, y)
	W.back:Show()
	y = y + kit.BUTTON
	ShowFoot()
	return y + 20 + FOOT + PAD
end

-- The after view: what is in use now, a note a line, then the buttons in a row (Reload only when a reload is needed, Change it only after a look).
-- No foot and no tick.
function W.LayoutAfter(y)
	local finished = W.finished or {}
	W.title:SetText("Your screen is set")
	W.line:SetText(W.AfterLine(finished))
	y = y + Height(W.line, 16) + 12
	local texts, reload = W.AfterNotes(finished)
	for index, text in ipairs(texts) do
		local note = W.notes[index]
		if not note then
			note = kit.Label(W.frame, "GameFontHighlight", "LEFT", INNER, true)
			W.notes[index] = note
		end
		note:SetText(text)
		W.At(note, y)
		note:Show()
		y = y + Height(note, 16) + 6
	end
	if #texts > 0 then
		y = y + 6
	end
	local x = PAD
	local function Put(button, width)
		W.At(button, y, x)
		button:Show()
		x = x + width + GAP
	end
	local button = reload and W.ReloadButton()
	if button then
		Put(button, 90)
	end
	if finished.ready then
		Put(W.change, 110)
	end
	Put(W.move, 110)
	Put(W.options, 90)
	Put(W.done, 90)
	return y + kit.BUTTON + PAD
end

-- Lays out the view the screen is in and reads everything again: the title, the line, then the parts of the start, tiles or after view. The height
-- fits what is shown.
function W.Update()
	local frame = W.frame
	if not frame then
		return
	end
	for _, part in ipairs(W.parts) do
		part:Hide()
	end
	for _, entry in ipairs(W.tiles) do
		entry.frame:Hide()
	end
	for _, note in ipairs(W.notes) do
		note:Hide()
	end
	if W.reload then
		W.reload:Hide()
	end
	W.mark:ClearAllPoints()
	W.mark:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
	W.title:ClearAllPoints()
	W.title:SetPoint("LEFT", W.mark, "RIGHT", 12, 0)
	local y = PAD + MARK + 14
	W.At(W.line, y)
	local layout = (W.view == "tiles" and W.LayoutTiles) or (W.view == "after" and W.LayoutAfter) or W.LayoutStart
	frame:SetSize(WIDTH, layout(y))
end

-- Shows the screen in a view: "start", "tiles" or "after" (with what was done), built the first time. Returns true when it shows.
function W.Open(view, finished)
	local frame = W.frame or W.Build()
	W.view = view
	if view == "after" then
		W.finished = finished
	end
	if frame:IsShown() then
		W.Update()
	else
		frame:Show()
	end
	return frame:IsShown() == true
end

function W.Show()
	return W.Open("start")
end

-- At login, a second after the other windows: the start view, for a character it is for. Setup.lua hands it here.
function ns.WelcomeShow()
	if ns.WelcomeWanted() and not InCombatLockdown() then
		W.Open("start")
	end
end

-- /flatui welcome: the start view, for any character. Nothing is chosen until a button is pressed.
function ns.OpenWelcome()
	if InCombatLockdown() then
		print("The welcome screen opens after combat.")
	end
	ns.OutOfCombat(W.Show)
	return true
end
