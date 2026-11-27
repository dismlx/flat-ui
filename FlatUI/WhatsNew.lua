local ADDON_NAME, ns = ...

local kit = ns.PanelKit
local W = { heads = {}, lines = {} }
ns.WhatsNew = W

local NAME = "FlatUIWhatsNew"
local WIDTH, PAD, MARK, GAP = 620, 16, 28, 8
local INNER = WIDTH - 2 * PAD
local CARD_PAD, INDENT, BAR = 12, 14, 16
local LIST_W = INNER - 2 * CARD_PAD
local TEXT_W = LIST_W - INDENT - BAR
local TOP = PAD + MARK + 34
local LIST_MIN, LIST_MAX = 120, 400
local HEAD_H, LINE_GAP, PART_GAP = 28, 7, 14
local OPTIONS_W, CLOSE_W = 210, 90
local FADE_IN, WAIT = 0.12, 2
local BOLD_ON, BOLD_OFF = "\001", "\002"
local FULL = "The full changelog is on CurseForge."
local EMPTY = "No notes for this version here. The full changelog is on CurseForge."
local UPDATED = "Flat UI updated to %s. /flatui new shows what changed."

local function IsText(value)
	return not ns.IsSecret(value) and type(value) == "string"
end

local function Height(text, fallback)
	local ok, height = pcall(text.GetStringHeight, text)
	if ok and ns.Finite(height) and height > 0 and height < 4000 then
		return math.ceil(height)
	end
	return fallback
end

local function Version()
	if type(C_AddOns) ~= "table" or type(C_AddOns.GetAddOnMetadata) ~= "function" then
		return nil
	end
	local ok, version = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
	if ok and IsText(version) and version ~= "" then
		return version
	end
	return nil
end
ns.WhatsNewVersion = Version

local function Parts(text)
	local parts = {}
	if IsText(text) then
		for number in text:gmatch("%d+") do
			parts[#parts + 1] = tonumber(number)
		end
	end
	return parts
end

local function Newer(a, b)
	local x, y = Parts(a), Parts(b)
	for index = 1, math.max(#x, #y) do
		local p, q = x[index] or 0, y[index] or 0
		if p ~= q then
			return p > q
		end
	end
	return false
end
W.Newer = Newer

local function Same(a, b)
	return #Parts(a) > 0 and #Parts(b) > 0 and not Newer(a, b) and not Newer(b, a)
end

function W.Data()
	local list = {}
	if type(ns.WhatsNewData) == "table" then
		for _, section in ipairs(ns.WhatsNewData) do
			if type(section) == "table" and IsText(section.version) then
				list[#list + 1] = section
			end
		end
	end
	return list
end

function W.Find(version)
	for _, section in ipairs(W.Data()) do
		if Same(section.version, version) then
			return section
		end
	end
	return nil
end

function W.Since(seen, now)
	local list = {}
	for _, section in ipairs(W.Data()) do
		if Newer(section.version, seen) and not Newer(section.version, now) then
			list[#list + 1] = section
		end
	end
	return list
end

local function Lit(text)
	local r, g, b = kit.Accent()
	if not (ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
		return (text:gsub(BOLD_ON, ""):gsub(BOLD_OFF, ""))
	end
	local function Byte(value)
		return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
	end
	local open = ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
	return (text:gsub(BOLD_ON, open):gsub(BOLD_OFF, "|r"))
end

local function Head(index)
	local head = W.heads[index]
	if not head then
		local child = W.scroller.child
		head = { text = kit.Tint(kit.Label(child, "GameFontNormal", "LEFT", LIST_W - BAR), "accent"), rule = kit.Fill(child, "BORDER") }
		head.rule:SetHeight(1)
		kit.Painted(function()
			kit.Solid(head.rule, "line-faint")
		end)
		W.heads[index] = head
	end
	return head
end

local function Line(index)
	local line = W.lines[index]
	if not line then
		local child = W.scroller.child
		line = { text = kit.Label(child, "GameFontHighlight", "LEFT", TEXT_W, true), dot = kit.Fill(child, "ARTWORK") }
		line.dot:SetSize(4, 4)
		kit.Painted(function()
			kit.Solid(line.dot, "accent")
		end)
		W.lines[index] = line
	end
	return line
end

local function Texts(section)
	local list = {}
	for _, text in ipairs(type(section.lines) == "table" and section.lines or {}) do
		if IsText(text) and text ~= "" then
			list[#list + 1] = text
		end
	end
	if #list == 0 then
		list[1] = EMPTY
	end
	return list
end

function W.Fill(sections)
	local child = W.scroller.child
	local y, heads, used = 0, 0, 0
	for _, section in ipairs(sections) do
		heads = heads + 1
		local head = Head(heads)
		head.text:ClearAllPoints()
		head.text:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
		head.text:SetText(section.version)
		head.text:Show()
		head.rule:ClearAllPoints()
		head.rule:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(y + HEAD_H - 8))
		head.rule:SetWidth(LIST_W - BAR)
		head.rule:Show()
		y = y + HEAD_H
		for _, text in ipairs(Texts(section)) do
			used = used + 1
			local line = Line(used)
			line.raw = text
			line.text:ClearAllPoints()
			line.text:SetPoint("TOPLEFT", child, "TOPLEFT", INDENT, -y)
			line.text:SetText(Lit(text))
			line.text:Show()
			line.dot:ClearAllPoints()
			line.dot:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -(y + 5))
			line.dot:Show()
			y = y + Height(line.text, 14) + LINE_GAP
		end
		y = y + PART_GAP
	end
	for index = heads + 1, #W.heads do
		W.heads[index].text:Hide()
		W.heads[index].rule:Hide()
	end
	for index = used + 1, #W.lines do
		W.lines[index].raw = nil
		W.lines[index].text:Hide()
		W.lines[index].dot:Hide()
	end
	return math.max(0, y - PART_GAP - LINE_GAP)
end

function W.Relit()
	for _, line in ipairs(W.lines) do
		if line.raw then
			line.text:SetText(Lit(line.raw))
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

local function Sound(kind)
	if type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT[kind] then
		pcall(PlaySound, SOUNDKIT[kind])
	end
end

function W.Keys(frame)
	pcall(frame.EnableKeyboard, frame, true)
	pcall(frame.SetPropagateKeyboardInput, frame, true)
	frame:SetScript("OnKeyDown", function(self, key)
		local close = key == "ESCAPE"
		if not InCombatLockdown() then
			pcall(self.SetPropagateKeyboardInput, self, not close)
		end
		if close then
			self:Hide()
		end
	end)
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, NAME)
	end
end

function W.Fights(frame)
	local listener = CreateFrame("Frame")
	ns.Own[listener] = true
	listener:RegisterEvent("PLAYER_REGEN_DISABLED")
	listener:RegisterEvent("PLAYER_REGEN_ENABLED")
	listener:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			if frame:IsShown() then
				W.state.offset = W.scroller.offset
				W.fought = W.state
				W.fighting = true
				frame:Hide()
				W.fighting = nil
				print("Flat UI: What's new comes back after the fight.")
			end
		elseif W.fought then
			local state = W.fought
			W.fought = nil
			if not frame:IsShown() then
				W.reopening = true
				W.Show(state)
				W.reopening = nil
			end
		end
	end)
end

function W.Build()
	local frame = CreateFrame("Frame", NAME, UIParent)
	ns.Own[frame] = true
	W.frame = frame
	frame:SetSize(WIDTH, 300)
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(100)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	pcall(frame.SetDontSavePosition, frame, true)
	local outline = ns.Outline(frame, frame, true)
	kit.Painted(function()
		kit.Backing(outline, "window", 0.98)
	end)
	local grip = kit.Frame(frame)
	grip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	grip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	grip:SetHeight(TOP - 6)
	grip:EnableMouse(true)
	grip:RegisterForDrag("LeftButton")
	grip:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	grip:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		pcall(frame.SetUserPlaced, frame, false)
	end)
	W.mark = kit.Fill(frame, "ARTWORK")
	W.mark:SetSize(MARK, MARK)
	W.mark:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
	W.notch = kit.Fill(frame, "OVERLAY")
	W.notch:SetSize(MARK / 3, MARK / 3)
	W.notch:SetPoint("TOPRIGHT", W.mark, "TOPRIGHT", 0, 0)
	kit.Painted(function()
		W.mark:SetColorTexture(kit.Accent())
		kit.Solid(W.notch, "window")
	end)
	W.title = kit.Label(frame, "GameFontNormalLarge", "LEFT", INNER - MARK - 12)
	W.title:SetPoint("LEFT", W.mark, "RIGHT", 12, 0)
	W.line = kit.Dim(kit.Label(frame, "GameFontHighlight", "LEFT", INNER))
	W.line:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(PAD + MARK + 10))
	W.card = kit.Frame(frame)
	W.card:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TOP)
	W.card:SetSize(INNER, LIST_MAX + 2 * CARD_PAD)
	local edge = ns.Outline(W.card, W.card, true)
	kit.Painted(function()
		kit.Backing(edge, "card", 1, "line")
	end)
	W.scroller = kit.Scroller(W.card, LIST_W, LIST_MAX)
	W.scroller.frame:SetPoint("TOPLEFT", W.card, "TOPLEFT", CARD_PAD, -CARD_PAD)
	W.close = kit.Button(frame, "Close", CLOSE_W, function()
		frame:Hide()
	end)
	W.close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
	W.options = kit.Button(frame, "Open Flat UI's options", OPTIONS_W, W.Options, true)
	W.options:SetPoint("RIGHT", W.close, "LEFT", -GAP, 0)
	W.foot = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", INNER - OPTIONS_W - CLOSE_W - 2 * GAP))
	W.foot:SetPoint("LEFT", frame, "BOTTOMLEFT", PAD, PAD + kit.BUTTON / 2)
	W.foot:SetText("Open it again with /flatui new.")
	frame:SetScript("OnShow", function(self)
		local faded = 0
		self:SetAlpha(0)
		self:SetScript("OnUpdate", function(shown, elapsed)
			faded = faded + (ns.Finite(elapsed) and elapsed or FADE_IN)
			if faded >= FADE_IN then
				shown:SetAlpha(1)
				shown:SetScript("OnUpdate", nil)
			else
				shown:SetAlpha(faded / FADE_IN)
			end
		end)
		if not W.reopening then
			Sound("IG_MAINMENU_OPEN")
		end
	end)
	frame:SetScript("OnHide", function(self)
		self:SetScript("OnUpdate", nil)
		self:SetAlpha(1)
		if not W.fighting then
			W.fought = nil
			Sound("IG_MAINMENU_CLOSE")
		end
	end)
	W.Keys(frame)
	W.Fights(frame)
	kit.Painted(W.Relit)
	frame:Hide()
	return frame
end

function W.Update()
	local state, frame = W.state, W.frame
	if not (state and frame) then
		return
	end
	W.title:SetText(("What's new in Flat UI %s"):format(state.version))
	W.line:SetText(state.line or "")
	local tall = W.Fill(state.sections)
	local list = math.max(LIST_MIN, math.min(LIST_MAX, tall))
	W.scroller.Resize(LIST_W, list)
	W.scroller.SetContent(tall)
	W.scroller.Scroll(state.offset or 0)
	state.offset = nil
	W.card:SetHeight(list + 2 * CARD_PAD)
	frame:SetHeight(TOP + list + 2 * CARD_PAD + 14 + kit.BUTTON + PAD)
end

function W.Show(state)
	local frame = W.frame or W.Build()
	W.state = state
	W.Update()
	if not frame:IsShown() then
		if not W.reopening then
			frame:ClearAllPoints()
			frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
		end
		frame:Show()
	end
	return frame:IsShown() == true
end

local function Later(fn)
	if InCombatLockdown() then
		print("Flat UI: What's new opens after the fight.")
	end
	ns.OutOfCombat(fn)
	return true
end

local function Known()
	local data = W.Data()
	if #data == 0 then
		return ""
	end
	return (" /flatui new knows %s to %s."):format(data[#data].version, data[1].version)
end

function ns.OpenWhatsNew(version)
	local section
	if IsText(version) and version ~= "" then
		section = W.Find(version)
		if not section then
			print(("Flat UI: no notes for %s here.%s %s"):format(version, Known(), FULL))
			return false
		end
	else
		local now = Version()
		section = (now and W.Find(now)) or W.Data()[1]
	end
	if not section then
		print("Flat UI: no notes of what changed here. " .. FULL)
		return false
	end
	local older
	for _, other in ipairs(W.Data()) do
		if not older and Newer(section.version, other.version) then
			older = other.version
		end
	end
	local state = { sections = { section }, version = section.version,
		line = older and ("/flatui new %s shows an older version."):format(older) or FULL }
	return Later(function()
		W.Show(state)
	end)
end

function ns.WhatsNewCommand(rest)
	local typed = IsText(rest) and rest:match("^%s*(.-)%s*$") or ""
	if typed == "" then
		return ns.OpenWhatsNew()
	elseif not typed:find("^%d+[%.%d]*$") then
		print("Flat UI: /flatui new shows what changed in this version; /flatui new 0.5.41 shows that version.")
		return false
	end
	return ns.OpenWhatsNew(typed)
end

local function Welcoming()
	if type(ns.WelcomeWanted) ~= "function" then
		return false
	end
	local ok, wanted = pcall(ns.WelcomeWanted)
	return ok and wanted == true
end

function W.Login()
	local db, now = ns.Account(), Version()
	if type(db) ~= "table" or not now then
		return
	end
	local seen = IsText(db.seenVersion) and #Parts(db.seenVersion) > 0 and db.seenVersion or nil
	if seen and not Newer(now, seen) then
		return
	end
	db.seenVersion = now
	if not seen and ns.newInstall then
		return
	end
	local ok, mode = pcall(ns.Get, "general.whatsNew")
	mode = ok and IsText(mode) and mode or "window"
	if mode == "off" then
		return
	end
	local sections = seen and W.Since(seen, now) or {}
	if #sections == 0 then
		local first = W.Find(now)
		sections = first and { first } or {}
	end
	local Act
	if mode == "chat" or #sections == 0 or Welcoming() then
		Act = function()
			print(UPDATED:format(now))
		end
	else
		local data = W.Data()
		local oldest = data[#data]
		local line = seen and ("Updated from %s to %s."):format(seen, now) or ("Flat UI updated to %s."):format(now)
		if seen and oldest and Newer(oldest.version, seen) then
			line = line .. " Older changes are in the full changelog on CurseForge."
		end
		local state = { sections = sections, version = now, line = line }
		Act = function()
			ns.OutOfCombat(function()
				W.Show(state)
			end)
		end
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(WAIT, Act)
	else
		Act()
	end
end

local watch = CreateFrame("Frame")
ns.Own[watch] = true
watch:RegisterEvent("PLAYER_ENTERING_WORLD")
watch:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	local ok, err = pcall(W.Login)
	if not ok then
		geterrorhandler()(err)
	end
end)
