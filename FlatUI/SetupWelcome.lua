local _, ns = ...

local kit = ns.PanelKit
local S = ns.Setup
local D = ns.SetupDraw
local W = { tiles = {}, notes = {}, view = "start" }
ns.Welcome = W

local GAME = "Game look"
local COMBAT = "In combat. Pick a look after combat."
local WIDTH, PAD, MARK, GAP, TILE_GAP, FOOT, SAME_W = 640, 16, 28, 8, 10, 18, 200
local INNER = WIDTH - 2 * PAD
local BAND_Y, BAND_H, DRAW_H, MOST = 92, 120, 112, 1.8
local GROUND = { 0.32, 0.27, 0.20 }
local CARD_W, CARD_H, TEXT_H = 336, 112, 62
local FADE_IN = 0.12

local function IsText(value)
	return not ns.IsSecret(value) and type(value) == "string"
end

local function Height(text, fallback)
	local ok, height = pcall(text.GetStringHeight, text)
	if ok and not ns.IsSecret(height) and type(height) == "number" and height > 0 and height < 1000 then
		return math.ceil(height)
	end
	return fallback
end

function ns.WelcomeWanted()
	if not S.Offerable(true) then
		return false
	end
	return ns.Get("setup.welcomeWhen") ~= "account" or (next(ns.Account().profileOf) == nil and not (S.Store() or {}).welcomed)
end

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
	picks["general.scaleOn"] = false
	return ns.NewProfile(GAME, nil, picks, {})
end

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

function W.OpenSetup()
	local view = W.view
	W.frame:Hide()
	if type(ns.OpenSetup) == "function" then
		ns.OpenSetup(nil, view)
	end
end

function ns.WelcomeReturn(view)
	if InCombatLockdown() then
		print("Flat UI: the welcome screen opens after the fight.")
	end
	ns.OutOfCombat(function()
		W.Open(view == "after" and "after" or "start", W.finished)
	end)
end

function W.Setup()
	if W.tick then
		ns.Set("setup.newCharacter", "default")
	end
	W.OpenSetup()
end

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

function W.Used()
	if type(ns.PanelInMode) == "function" and ns.PanelInMode() then
		kit.Hide()
	end
end

function W.ReloadBefore()
	local before = {}
	for _, page in ipairs(type(ns.PAGES) == "table" and ns.PAGES or {}) do
		for _, item in ipairs(page) do
			if item.path and item.reload and IsText(item.label) and not ns.RowUnsaved(item) then
				before[item] = ns.Get(item.path)
			end
		end
	end
	return before
end

function W.ReloadSince(before)
	local lines = {}
	for _, page in ipairs(type(ns.PAGES) == "table" and ns.PAGES or {}) do
		for _, item in ipairs(page) do
			local now = before[item]
			if now ~= nil then
				local later = ns.Get(item.path)
				if item.reload == "off" and now == true and later == false or item.reload == "change" and now ~= later then
					lines[#lines + 1] = { item.label, item.reload }
				end
			end
		end
	end
	return lines
end

function W.Pick(index)
	local tile = W.tiles[index]
	if not tile then
		return
	end
	local before = W.ReloadBefore()
	local previous, shared = ns.Profile(), ns.Get("setup.newCharacter")
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
	W.ShowAfter({ name = ns.Profile() or tile.profile.label, ready = true, reloadLines = W.ReloadSince(before),
		previous = previous ~= ns.Profile() and previous or nil, shared = W.share and shared or nil })
end

function W.Back()
	local finished = W.finished or {}
	local name = finished.previous and S.FindProfile(finished.previous)
	if not name then
		return
	end
	local ok, why = ns.UseProfile(name)
	if not ok then
		W.line:SetText(tostring(why))
		return
	end
	if finished.shared ~= nil then
		ns.Set("setup.newCharacter", finished.shared)
	end
	print(("Flat UI: using %s."):format(name))
	W.frame:Hide()
end

function W.CanUndo(finished)
	if finished.new or finished.ready then
		return false
	end
	local lost = type(ns.LostProfile) == "function" and ns.LostProfile()
	return type(lost) == "table" and lost.inUse == true and lost.what == "setup's Finish"
end

function W.UndoSetup()
	local finished = W.finished or {}
	local ok, why = ns.BringBackProfile()
	if not ok then
		W.line:SetText(tostring(why))
		return
	end
	local game = finished.game
	local kept = not ns.IsSecret(game) and type(game) == "number" and game > 0
	print(("Flat UI: %s is back as it was before setup.%s"):format(tostring(ns.Profile()), kept and " Game settings setup changed stay as they are." or ""))
	W.frame:Hide()
end

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

function W.Options()
	W.frame:Hide()
	if type(ns.PanelInMode) == "function" and ns.PanelInMode() then
		kit.Hide()
	end
	if type(ns.PanelShown) ~= "function" or not ns.PanelShown() then
		ns.OpenPanel()
	end
end

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

function W.ShowAfter(finished)
	return W.Open("after", type(finished) == "table" and finished or {})
end

function ns.SetupAfter(finished)
	if InCombatLockdown() then
		return false
	end
	return W.ShowAfter(finished)
end

function ns.OpenProfiles()
	return W.Open("tiles")
end

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
	frame:SetFrameLevel(800)
	frame:EnableMouse(true)
	local outline = ns.Outline(frame, frame, true)
	kit.Painted(function()
		kit.Backing(outline, "window", 0.98)
	end)
	W.frame = frame
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	pcall(frame.SetDontSavePosition, frame, true)
	local grip = kit.Frame(frame)
	grip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	grip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + 60 + 8), 0)
	grip:SetHeight(PAD + MARK + 6)
	grip:EnableMouse(true)
	grip:RegisterForDrag("LeftButton")
	grip:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	grip:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		pcall(frame.SetUserPlaced, frame, false)
	end)
	W.close = kit.Button(frame, "Close", 60, function()
		frame:Hide()
	end)
	W.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(PAD + (MARK - kit.BUTTON) / 2))
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
	W.BuildBand(frame)
	W.caption = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", INNER))
	W.caption:SetText("Your frame as Flat UI draws it now.")
	W.setup = kit.Button(frame, "Set up my screen", INNER, W.Setup, true)
	W.ready = kit.Button(frame, "Ready-made looks", INNER, function()
		W.view, W.fromStart = "tiles", true
		W.Update()
	end)
	W.keep, W.keepText = kit.Button(frame, "Keep this look", INNER, W.Keep)
	W.same, W.sameText = kit.Button(frame, "Same as", SAME_W, W.Same)
	W.back, W.backText = kit.Button(frame, "Back", 100, function()
		W.share = false
		if W.fromStart then
			W.view = "start"
			W.Update()
		else
			W.frame:Hide()
		end
	end)
	W.shareBox, W.shareMark, W.shareLabel = Tick(frame, "Same profile on new characters", function()
		W.share = not W.share
		W.shareMark:SetShown(W.share)
	end)
	W.change = kit.Button(frame, "Change it", 110, W.OpenSetup)
	W.move = kit.Button(frame, "Move frames", 110, W.Move)
	W.options = kit.Button(frame, "Options", 90, W.Options)
	W.done = kit.Button(frame, "Done", 90, function()
		frame:Hide()
	end)
	W.backTo, W.backToText = kit.Button(frame, "Back to", SAME_W, function()
		local action = W.backAction or W.Back
		action()
	end)
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
	W.parts = { W.band, W.caption, W.setup, W.ready, W.keep, W.same, W.back, W.shareBox, W.shareLabel, W.change, W.move, W.options, W.done, W.backTo,
		W.foot, W.tickBox, W.tickLabel }
	frame:SetScript("OnShow", function()
		W.tick, W.share = false, false
		W.tickMark:Hide()
		W.shareMark:Hide()
		W.Update()
		local faded = 0
		frame:SetAlpha(0)
		frame:SetScript("OnUpdate", function(self, elapsed)
			faded = faded + ((not ns.IsSecret(elapsed) and type(elapsed) == "number") and elapsed or FADE_IN)
			if faded >= FADE_IN then
				self:SetAlpha(1)
				self:SetScript("OnUpdate", nil)
			else
				self:SetAlpha(faded / FADE_IN)
			end
		end)
		if not W.reopening and type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.IG_MAINMENU_OPEN then
			pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPEN)
		end
	end)
	local listener = CreateFrame("Frame")
	ns.Own[listener] = true
	listener:RegisterEvent("PLAYER_REGEN_DISABLED")
	listener:RegisterEvent("PLAYER_REGEN_ENABLED")
	listener:RegisterEvent("UI_SCALE_CHANGED")
	listener:RegisterEvent("DISPLAY_SIZE_CHANGED")
	frame:SetScript("OnHide", function()
		W.fought = nil
		frame:SetScript("OnUpdate", nil)
		frame:SetAlpha(1)
		if W.built and not W.fighting and type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.IG_MAINMENU_CLOSE then
			pcall(PlaySound, SOUNDKIT.IG_MAINMENU_CLOSE)
		end
	end)
	listener:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			local shown = frame:IsShown()
			local fought = shown and { view = W.view, fromStart = W.fromStart, tick = W.tick, share = W.share } or nil
			W.fighting = true
			frame:Hide()
			W.fighting = nil
			if fought then
				W.fought = fought
				print("Flat UI: the welcome screen comes back after the fight.")
			end
		elseif event == "PLAYER_REGEN_ENABLED" and W.fought then
			local fought = W.fought
			W.fought = nil
			if not frame:IsShown() then
				W.reopening = true
				W.Open(fought.view, W.finished)
				W.reopening = nil
				W.fromStart = fought.fromStart
				W.tick, W.share = fought.tick == true, fought.share == true
				W.tickMark:SetShown(W.tick)
				W.shareMark:SetShown(W.share)
			end
			W.Update()
		elseif frame:IsShown() then
			W.Update()
		end
	end)
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "FlatUIWelcome")
	end
	frame:Hide()
	W.built = true
	return frame
end

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

function W.LayoutStart(y)
	W.title:SetText("Welcome to Flat UI")
	W.line:SetText("Flat UI is on. Walk round your screen and pick how each part looks: six short stops, about two minutes.")
	y = math.max(BAND_Y, y + Height(W.line, 30) + 4)
	W.At(W.band, y)
	W.band:Show()
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
	if W.backText then
		W.backText:SetText(W.fromStart and "Back" or "Close")
	end
	W.back:Show()
	y = y + kit.BUTTON
	ShowFoot()
	return y + 20 + FOOT + PAD
end

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
	local previous = (finished.ready or finished.new) and finished.previous and S.FindProfile(finished.previous)
	local undo = not previous and W.CanUndo(finished)
	if previous or undo then
		W.backAction = undo and W.UndoSetup or W.Back
		W.backToText:SetText(undo and "Undo setup" or "Back to " .. S.Short(previous))
		W.At(W.backTo, y)
		W.backTo:Show()
		y = y + kit.BUTTON + GAP
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

function W.Open(view, finished)
	local frame = W.frame or W.Build()
	W.view = view
	W.fromStart = false
	if view == "after" then
		W.finished = finished
	end
	if frame:IsShown() then
		W.Update()
	else
		if not W.reopening then
			frame:ClearAllPoints()
			frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
		end
		frame:Show()
	end
	return frame:IsShown() == true
end

function W.Show()
	return W.Open("start")
end

function ns.WelcomeShow()
	if ns.WelcomeWanted() and not InCombatLockdown() then
		W.Open("start")
	end
end

function ns.OpenWelcome()
	if InCombatLockdown() then
		print("Flat UI: the welcome screen opens after the fight.")
	end
	ns.OutOfCombat(W.Show)
	return true
end
