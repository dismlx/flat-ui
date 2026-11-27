local _, ns = ...

local secure = false
local buttons = {}
local built = {}
local overlays = {}
local befores = {}
local watcher

local function Detach()
	for _, overlay in pairs(overlays) do
		pcall(function()
			overlay:Hide()
			overlay:ClearAllPoints()
			overlay:SetParent(UIParent)
		end)
	end
end

local function Attach()
	for button, overlay in pairs(overlays) do
		pcall(function()
			overlay:SetParent(button)
			overlay:SetAllPoints(button)
			overlay:Show()
		end)
	end
end

local FIGHT_ALPHA = 0.4

local Wanted, IsSecure

local function DimAll(fight)
	local held = fight and (Wanted() or IsSecure())
	for _, button in ipairs(buttons) do
		pcall(button.SetAlpha, button, held and FIGHT_ALPHA or 1)
	end
end

local function Watch()
	if watcher then
		return
	end
	local ok, frame = pcall(CreateFrame, "Frame")
	if not ok or type(frame) ~= "table" then
		return
	end
	watcher = frame
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			Detach()
			DimAll(true)
		else
			Attach()
			DimAll(false)
		end
	end)
end

function IsSecure()
	return next(overlays) ~= nil
end

local function Forever()
	if type(GetBuildInfo) ~= "function" then
		return false
	end
	local ok, interface = pcall(function()
		return select(4, GetBuildInfo())
	end)
	return ok and type(interface) == "number" and interface >= 16000 and interface < 20000
end

function ns.ReloadIsForever()
	return Forever()
end

function Wanted()
	if secure or Forever() then
		return true
	end
	local record = ns.Account()
	return record ~= nil and record.reloadSecure == true
end

local function Press(button, down)
	local kit = ns.PanelKit
	if type(kit) == "table" and type(kit.Press) == "function" then
		pcall(kit.Press, button, down)
	end
end

local function Over(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return not ok or ns.IsSecret(over) or over ~= false
end

local function Cover(button)
	if built[button] then
		return
	end
	built[button] = true
	ns.OutOfCombat(function()
		local ok, overlay = pcall(CreateFrame, "Button", nil, button, "SecureActionButtonTemplate")
		if not ok or type(overlay) ~= "table" then
			built[button] = nil
			return
		end
		local done = pcall(function()
			ns.Own[overlay] = true
			overlay:SetAllPoints(button)
			overlay:RegisterForClicks("LeftButtonUp")
			overlay:SetAttribute("type", "macro")
			overlay:SetAttribute("macrotext", "/reload")
			overlay:SetAttribute("useOnKeyDown", false)
			overlay:SetScript("PreClick", function()
				if befores[button] then
					pcall(befores[button])
				end
			end)
			overlay:SetScript("OnEnter", function(_, ...)
				local script = button:GetScript("OnEnter")
				if script then
					script(button, ...)
				end
			end)
			overlay:SetScript("OnLeave", function(_, ...)
				local script = button:GetScript("OnLeave")
				if script then
					script(button, ...)
				end
			end)
			overlay:HookScript("OnMouseDown", function(_, mouse)
				if mouse == "LeftButton" then
					Press(button, true)
				end
			end)
			overlay:HookScript("OnMouseUp", function()
				Press(button, false)
			end)
			overlay:HookScript("OnHide", function()
				Press(button, false)
			end)
		end)
		if not done then
			overlay:Hide()
			built[button] = nil
			return
		end
		overlays[button] = overlay
		Watch()
	end)
end

function ns.SecureReload(button, before)
	if type(button) ~= "table" then
		return
	end
	if type(before) == "function" then
		befores[button] = before
	end
	local known = false
	for _, other in ipairs(buttons) do
		known = known or rawequal(other, button)
	end
	if not known then
		buttons[#buttons + 1] = button
	end
	if Wanted() then
		Cover(button)
		Watch()
		if InCombatLockdown() then
			pcall(button.SetAlpha, button, FIGHT_ALPHA)
		end
	end
end

function ns.ReloadIsSecure()
	return IsSecure()
end

local AFTER_FIGHT = "Flat UI: Reload works here again after the fight. Type /reload to reload now."

function ns.Reload()
	if InCombatLockdown() and (Wanted() or IsSecure()) then
		print(AFTER_FIGHT)
		return
	end
	if IsSecure() or type(ReloadUI) ~= "function" then
		return
	end
	if Forever() then
		print("Flat UI: Reload is blocked for add-ons here. Type /reload.")
		return
	end
	local before = ns.BlockedTotal()
	pcall(ReloadUI)
	if ns.BlockedTotal() > before then
		secure = true
		local record = ns.Account()
		if record then
			record.reloadSecure = true
		end
		print("Flat UI: Reload is blocked for add-ons here. Press Reload again.")
		for _, button in ipairs(buttons) do
			Cover(button)
		end
	end
end

local taint = { wanted = false, shown = false, ignored = false, suspended = false }
local taintBox, taintOverlay, taintWatcher

local function TaintShade(delta)
	local r, g, b = ns.Colour("general.backdrop")
	return math.min(1, math.max(0, r + delta)), math.min(1, math.max(0, g + delta)), math.min(1, math.max(0, b + delta))
end

local function TaintDetach()
	if taintOverlay then
		pcall(function()
			taintOverlay:Hide()
			taintOverlay:ClearAllPoints()
			taintOverlay:SetParent(UIParent)
		end)
	end
end

local function TaintAttach()
	if taintOverlay and taintOverlay.flatButton then
		pcall(function()
			taintOverlay:SetParent(taintOverlay.flatButton)
			taintOverlay:SetAllPoints(taintOverlay.flatButton)
			taintOverlay:Show()
		end)
	end
end

local function TaintTurnOff()
	pcall(C_CVar.SetCVar, "taintLog", "0")
end

local function TaintButton(parent, text, width)
	local button = CreateFrame("Frame", nil, parent)
	ns.Own[button] = true
	button:SetSize(width, 24)
	local outline = ns.Outline(button, button, true)
	local label = ns.OwnText(button, "OVERLAY", "GameFontHighlight")
	if label then
		label:SetPoint("CENTER", button, "CENTER", 0, 0)
		label:SetText(text)
	end
	local function Paint(hover)
		local r, g, b = TaintShade(hover and 0.17 or 0.09)
		ns.SetOutlineFill(outline, r, g, b, 1)
	end
	Paint(false)
	button:EnableMouse(true)
	button:SetScript("OnEnter", function()
		Paint(true)
	end)
	button:SetScript("OnLeave", function()
		Paint(false)
	end)
	return button
end

local function TaintBuild()
	local box = CreateFrame("Frame", "FlatUITaintLog", UIParent)
	ns.Own[box] = true
	box:SetSize(380, 124)
	box:SetFrameStrata("DIALOG")
	box:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	box:EnableMouse(true)
	local outline = ns.Outline(box, box, true)
	local r, g, b = TaintShade(0.06)
	ns.SetOutlineFill(outline, r, g, b, 1)
	local title = ns.OwnText(box, "OVERLAY", "GameFontNormal")
	if title then
		title:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -14)
		title:SetText("Taint log")
	end
	local line = ns.OwnText(box, "OVERLAY", "GameFontHighlight")
	if line then
		line:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -38)
		line:SetWidth(348)
		line:SetJustifyH("LEFT")
		line:SetWordWrap(true)
		line:SetText("taintLog is on. Flat UI leaves out the looks that follow game frames until it is off.")
	end
	local ignore = TaintButton(box, "Ignore", 90)
	ignore:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -16, 14)
	local ignoreDown = false
	ignore:SetScript("OnMouseDown", function(_, button)
		ignoreDown = button == "LeftButton"
	end)
	ignore:SetScript("OnMouseUp", function(self, button)
		local wanted = ignoreDown and button == "LeftButton"
		ignoreDown = false
		if wanted and Over(self) then
			box:Hide()
		end
	end)
	local reload = TaintButton(box, "Turn off and reload", 150)
	reload:SetPoint("RIGHT", ignore, "LEFT", -8, 0)
	local reloadDown = false
	reload:SetScript("OnMouseDown", function(_, button)
		reloadDown = button == "LeftButton"
	end)
	reload:SetScript("OnMouseUp", function(self, button)
		local wanted = reloadDown and button == "LeftButton"
		reloadDown = false
		if wanted and Over(self) then
			TaintTurnOff()
			print("Flat UI: taintLog is off. Type /reload to follow the game frames again.")
			box:Hide()
		end
	end)
	local made, overlay = pcall(CreateFrame, "Button", nil, reload, "SecureActionButtonTemplate")
	if made and type(overlay) == "table" then
		local done = pcall(function()
			ns.Own[overlay] = true
			overlay:SetAllPoints(reload)
			overlay:RegisterForClicks("LeftButtonUp")
			overlay:SetAttribute("type", "macro")
			overlay:SetAttribute("macrotext", "/reload")
			overlay:SetAttribute("useOnKeyDown", false)
			overlay:SetScript("OnEnter", function(_, ...)
				local script = reload:GetScript("OnEnter")
				if script then
					script(reload, ...)
				end
			end)
			overlay:SetScript("OnLeave", function(_, ...)
				local script = reload:GetScript("OnLeave")
				if script then
					script(reload, ...)
				end
			end)
			overlay:HookScript("OnClick", TaintTurnOff)
		end)
		if done then
			overlay.flatButton = reload
			taintOverlay = overlay
		else
			pcall(overlay.Hide, overlay)
		end
	end
	box:SetScript("OnHide", function()
		if not taint.suspended then
			taint.ignored = true
		end
	end)
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "FlatUITaintLog")
	end
	return box
end

local function TaintShow()
	if taint.ignored or InCombatLockdown() then
		return
	end
	if not taintBox then
		local ok, box = pcall(TaintBuild)
		if not ok or type(box) ~= "table" then
			return
		end
		taintBox = box
	end
	TaintAttach()
	taintBox:Show()
	taint.shown = true
end

local function TaintWatch()
	if taintWatcher then
		return
	end
	local ok, frame = pcall(CreateFrame, "Frame")
	if not ok or type(frame) ~= "table" then
		return
	end
	taintWatcher = frame
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		if not taintBox then
			if event == "PLAYER_REGEN_ENABLED" and taint.wanted then
				TaintShow()
			end
			return
		end
		if event == "PLAYER_REGEN_DISABLED" then
			taint.suspended = true
			TaintDetach()
			pcall(taintBox.Hide, taintBox)
			taint.suspended = false
		elseif taint.wanted and not taint.ignored then
			TaintShow()
		end
	end)
end

function ns.TaintReminder()
	if taint.shown or taint.ignored then
		return
	end
	taint.wanted = true
	TaintWatch()
	TaintShow()
end

local NOTICE = { name = "FlatUIReloadNotice", width = 520, height = 52, y = -40, reload = 80, undo = 60, later = 64, chars = 64, every = 0.25,
	fade = 0.2, gap = 6 }
local notice = { queued = false, wait = 0, alpha = 1 }
local VALUE, HINT = { 0.66, 0.68, 0.62 }, { 0.9, 0.72, 0.36 }

local function Finite(value)
	return type(ns.Finite) == "function" and ns.Finite(value)
end

local function NoticeText(lines)
	local names, length = {}, 0
	for _, entry in ipairs(lines) do
		local label = type(entry[1]) == "string" and entry[1] or "a setting"
		if #names > 0 and length + #label > NOTICE.chars then
			break
		end
		names[#names + 1] = label
		length = length + #label + 2
	end
	local list = table.concat(names, ", ")
	if #lines > #names then
		list = ("%s and %d more"):format(list, #lines - #names)
	end
	if #lines == 1 then
		return ("1 change needs a reload: %s."):format(list)
	end
	return ("%d changes need a reload: %s."):format(#lines, list)
end

local function NoticeWaits(fight)
	return fight == true and (Wanted() or IsSecure())
end

local function NoticeDim(fight)
	if notice.reload then
		pcall(notice.reload.SetAlpha, notice.reload, NoticeWaits(fight) and 0.4 or 1)
	end
	if notice.undo then
		local held = fight == true or (type(ns.PanelInMode) == "function" and ns.PanelInMode() == true)
		pcall(notice.undo.SetAlpha, notice.undo, held and 0.4 or 1)
	end
end

local function NoticeBlocks()
	local blocks = {}
	local function Add(left, bottom, width, height, under)
		if Finite(left) and Finite(bottom) and Finite(width) and Finite(height) and width > 0 and height > 0 then
			local top = bottom + height
			blocks[#blocks + 1] = { left, left + width, top, bottom, top + NOTICE.height + NOTICE.gap, (under or bottom) - NOTICE.gap }
			return blocks[#blocks]
		end
		return nil
	end
	local kit = ns.PanelKit
	local window = type(ns.PanelShown) == "function" and ns.PanelShown() and type(kit) == "table" and kit.Window() or nil
	if window then
		local left, bottom, width, height = kit.Rect(window)
		if Finite(bottom) and Finite(height) and height > 0 then
			local title = bottom + height - height * kit.TITLE / kit.HEIGHT
			blocks.window = Add(left, title, width, bottom + height - title, bottom)
		end
	end
	local movers, mode = ns.MoverKit, ns.MoversMode
	if type(movers) == "table" and type(movers.IsOpen) == "function" and movers.IsOpen() == true and type(kit) == "table"
		and type(mode) == "table" and type(mode.State) == "function" then
		local _, parts = mode.State()
		local bar = type(parts) == "table" and parts.bar
		local ok, shown = false, false
		if type(bar) == "table" then
			ok, shown = pcall(bar.IsVisible, bar)
		end
		if ok and shown == true then
			Add(kit.Rect(bar))
		end
	end
	local test = ns.TestMode
	if type(test) == "table" and type(test.BarRect) == "function" then
		local left, bottom, width, height = test.BarRect()
		Add(left, bottom, width, height)
	end
	return blocks
end

local function NoticeCovers(x, y, blocks)
	for _, block in ipairs(blocks) do
		if y - NOTICE.height < block[3] and y > block[4] and x + NOTICE.width > block[1] and x < block[2] then
			return true
		end
	end
	return false
end

local function NoticeNearest(x, y, blocks, screenH)
	local best
	for _, block in ipairs(blocks) do
		for side = 5, 6 do
			local at = block[side]
			if at <= screenH and at - NOTICE.height >= 0 and not NoticeCovers(x, at, blocks)
				and (best == nil or math.abs(at - y) < math.abs(best - y)) then
				best = at
			end
		end
	end
	return best
end

local function NoticeSpot()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(NOTICE.name, "TOPLEFT")
	end
	local ok, screenW, screenH = pcall(UIParent.GetSize, UIParent)
	if not (ok and Finite(screenW) and Finite(screenH)) then
		return x, y
	end
	local blocks = NoticeBlocks()
	if #blocks == 0 then
		return x, y
	end
	local fromX, fromY = x, y
	if not (Finite(x) and Finite(y)) then
		x, y = (screenW - NOTICE.width) / 2, screenH + NOTICE.y
	end
	if not NoticeCovers(x, y, blocks) then
		return fromX, fromY
	end
	local best = NoticeNearest(x, y, blocks, screenH)
	if best then
		return x, best
	end
	local window = blocks.window
	if window and NoticeCovers(x, y, { window }) then
		return x, window[5] <= screenH and window[5] or window[6]
	end
	return x, y
end

local function NoticePlace(frame)
	frame = frame or notice.frame
	local field = frame == notice.frame and "placed" or "samplePlaced"
	local protected = false
	if InCombatLockdown() then
		local ok, value = pcall(frame.IsProtected, frame)
		protected = not ok or value ~= false
	end
	if protected then
		return
	end
	local ok, x, y = pcall(NoticeSpot)
	if not ok then
		if not notice.failed then
			notice.failed = true
			geterrorhandler()(x)
		end
		x, y = nil, nil
	end
	if not (Finite(x) and Finite(y)) then
		x, y = nil, nil
	end
	local key = x and ("%.1f:%.1f"):format(x, y) or "start"
	if notice[field] == key then
		return
	end
	notice[field] = key
	pcall(function()
		frame:ClearAllPoints()
		if x then
			frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		else
			frame:SetPoint("TOP", UIParent, "TOP", 0, NOTICE.y)
		end
	end)
end

local function NoticeLater()
	notice.later = {}
	for _, entry in ipairs(ns.ReloadLines()) do
		notice.later[entry[3]] = entry[4]
	end
	notice.leaving = true
end

local function NoticeReload()
	if NoticeWaits(InCombatLockdown()) then
		print(AFTER_FIGHT)
		return
	end
	ns.Reload()
end

local function NoticeValue(path, value)
	local trust = ns.PanelTrust
	if type(trust) == "table" and type(trust.ValueText) == "function" then
		local def = type(ns.Def) == "function" and ns.Def(path) or nil
		local ok, text = pcall(trust.ValueText, type(def) == "table" and def or { path = path }, value)
		if ok and type(text) == "string" then
			return text
		end
	end
	if type(value) == "boolean" then
		return value and "On" or "Off"
	end
	return type(value) == "string" and value or "changed"
end

local function NoticeTip(owner, anchor, hint)
	if ns.Forbidden(GameTooltip) then
		return
	end
	local ok, lines = pcall(ns.ReloadLines)
	if not ok or type(lines) ~= "table" or #lines == 0 then
		return
	end
	notice.tip = owner
	pcall(function()
		GameTooltip:SetOwner(owner, anchor or "ANCHOR_BOTTOM")
		GameTooltip:SetText("Needs a reload", 1, 1, 1)
		for _, entry in ipairs(lines) do
			local label = type(entry[1]) == "string" and entry[1] or "a setting"
			GameTooltip:AddDoubleLine(label, ("%s now, %s at login"):format(NoticeValue(entry[3], entry[4]), NoticeValue(entry[3], entry[5])), 1, 1, 1,
				VALUE[1], VALUE[2], VALUE[3])
		end
		GameTooltip:AddLine(hint or ("Reload applies them. Undo puts them all back as the game runs them, with no reload. Later hides this until your "
			.. "next change that needs a reload."), HINT[1], HINT[2], HINT[3], true)
		GameTooltip:Show()
	end)
end

local function NoticeUntip(owner)
	owner = owner or notice.tip
	if not owner or ns.Forbidden(GameTooltip) then
		return
	end
	if notice.tip == owner then
		notice.tip = nil
	end
	local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, owner)
	if ok and owned == true then
		GameTooltip:Hide()
	end
end

function ns.ReloadTip(owner)
	NoticeTip(owner, "ANCHOR_TOP", "Reload applies them. Home's Needs a reload lists them too.")
end

function ns.ReloadUntip(owner)
	NoticeUntip(owner)
end

local function NoticeUndo()
	if InCombatLockdown() then
		print("Flat UI: Undo after the fight.")
		return
	end
	if type(ns.PanelInMode) == "function" and ns.PanelInMode() then
		print("Flat UI: finish or close Setup first.")
		return
	end
	local ok, lines = pcall(ns.ReloadLines)
	if not ok or type(lines) ~= "table" then
		return
	end
	local home, count = ns.PanelHome, 0
	local batch = { label = "Undo of the reload notice", what = "the notice's Undo" }
	for _, entry in ipairs(lines) do
		local path, now, was = entry[3], entry[4], entry[5]
		if type(path) == "string" and was ~= nil then
			local done, err = pcall(ns.Set, path, was)
			if not done then
				geterrorhandler()(err)
			elseif ns.Get(path) == was then
				count = count + 1
				if type(home) == "table" and type(home.Noted) == "function" then
					pcall(home.Noted, type(ns.Def) == "function" and ns.Def(path) or { path = path, label = entry[1] }, now, was, batch)
				end
			end
		end
	end
	if type(ns.RefreshPanel) == "function" then
		pcall(ns.RefreshPanel)
	end
	if count == 1 then
		print("Flat UI: put back 1 change, no reload needed.")
	elseif count > 1 then
		print(("Flat UI: put back %d changes, no reload needed."):format(count))
	end
end

local function NoticeBuild()
	local kit = ns.PanelKit
	if type(kit) ~= "table" then
		return nil
	end
	local frame = CreateFrame("Frame", NOTICE.name, UIParent)
	ns.Own[frame] = true
	frame:Hide()
	frame:SetSize(NOTICE.width, NOTICE.height)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	local outline = ns.Outline(frame, frame, true)
	kit.Painted(function()
		kit.Backing(outline, "card", 1, "accent")
	end)
	local later = kit.Button(frame, "Later", NOTICE.later, NoticeLater)
	later:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
	local undo = kit.Button(frame, "Undo", NOTICE.undo, NoticeUndo)
	undo:SetPoint("RIGHT", later, "LEFT", -6, 0)
	local reload = kit.Button(frame, "Reload", NOTICE.reload, NoticeReload, true)
	reload:SetPoint("RIGHT", undo, "LEFT", -6, 0)
	local text = kit.Label(frame, "GameFontHighlight", "LEFT", NOTICE.width - 42 - NOTICE.reload - NOTICE.undo - NOTICE.later, true)
	text:SetPoint("LEFT", frame, "LEFT", 12, 0)
	pcall(text.SetMaxLines, text, 2)
	notice.frame, notice.text, notice.reload, notice.undo = frame, text, reload, undo
	ns.SecureReload(reload)
	frame:SetScript("OnEnter", NoticeTip)
	frame:SetScript("OnLeave", NoticeUntip)
	for _, button in ipairs({ undo, later }) do
		button:HookScript("OnEnter", NoticeTip)
		button:HookScript("OnLeave", NoticeUntip)
	end
	local enter, leave = reload:GetScript("OnEnter"), reload:GetScript("OnLeave")
	reload:SetScript("OnEnter", function(self, ...)
		if enter then
			enter(self, ...)
		end
		NoticeTip(self)
	end)
	reload:SetScript("OnLeave", function(self, ...)
		NoticeUntip(self)
		if leave then
			leave(self, ...)
		end
	end)
	frame:SetScript("OnHide", function()
		NoticeUntip(nil)
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		local step = Finite(elapsed) and elapsed or 0
		if notice.leaving then
			notice.alpha = math.max(0, notice.alpha - step / NOTICE.fade)
			pcall(frame.SetAlpha, frame, notice.alpha)
			if notice.alpha <= 0 then
				notice.leaving = false
				frame:Hide()
				return
			end
		elseif notice.alpha < 1 then
			notice.alpha = math.min(1, notice.alpha + step / NOTICE.fade)
			pcall(frame.SetAlpha, frame, notice.alpha)
		end
		notice.wait = notice.wait - step
		if notice.wait <= 0 then
			notice.wait = NOTICE.every
			NoticePlace()
			NoticeDim(InCombatLockdown())
		end
	end)
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		NoticeDim(event == "PLAYER_REGEN_DISABLED")
	end)
	return frame
end

local SAMPLE_TEXT = "Sample: 2 changes need a reload: Square icons, Side tabs."
local SAMPLE_TIP = "A sample while test mode is on: this notice shows here when a change needs a reload."

local function SampleBuild()
	local kit = ns.PanelKit
	if type(kit) ~= "table" then
		return nil
	end
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:Hide()
	frame:SetSize(NOTICE.width, NOTICE.height)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetAlpha(0.75)
	local outline = ns.Outline(frame, frame, true)
	kit.Painted(function()
		kit.Backing(outline, "card", 1, "accent")
	end)
	local last = frame
	for index, spec in ipairs({ { "Later", NOTICE.later }, { "Undo", NOTICE.undo }, { "Reload", NOTICE.reload, true } }) do
		local button = kit.Button(frame, spec[1], spec[2], function() end, spec[3])
		button:EnableMouse(false)
		button:SetAlpha(0.4)
		button:SetPoint("RIGHT", last, index == 1 and "RIGHT" or "LEFT", index == 1 and -12 or -6, 0)
		last = button
	end
	local text = kit.Label(frame, "GameFontHighlight", "LEFT", NOTICE.width - 42 - NOTICE.reload - NOTICE.undo - NOTICE.later, true)
	text:SetPoint("LEFT", frame, "LEFT", 12, 0)
	pcall(text.SetMaxLines, text, 2)
	text:SetText(SAMPLE_TEXT)
	frame:SetScript("OnEnter", function(self)
		if not ns.Forbidden(GameTooltip) then
			pcall(function()
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
				GameTooltip:SetText("Reload notice", 1, 1, 1)
				GameTooltip:AddLine(SAMPLE_TIP, HINT[1], HINT[2], HINT[3], true)
				GameTooltip:Show()
			end)
		end
	end)
	frame:SetScript("OnLeave", function(self)
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, self)
		if ok and owned == true then
			GameTooltip:Hide()
		end
	end)
	frame:SetScript("OnHide", function(self)
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, self)
		if ok and owned == true then
			GameTooltip:Hide()
		end
	end)
	local wait = 0
	frame:SetScript("OnUpdate", function(self, elapsed)
		wait = wait - (Finite(elapsed) and elapsed or 0)
		if wait <= 0 then
			wait = NOTICE.every
			NoticePlace(self)
		end
	end)
	notice.sampleFrame = frame
	return frame
end

local function NoticeSample(shown)
	local frame = notice.sampleFrame
	if not shown then
		if frame then
			pcall(frame.Hide, frame)
		end
		return
	end
	if not frame then
		local made, built = pcall(SampleBuild)
		if not made or type(built) ~= "table" then
			if not made then
				geterrorhandler()(built)
			end
			return
		end
		frame = built
	end
	notice.samplePlaced = nil
	NoticePlace(frame)
	frame:Show()
end

local function NoticeRefresh()
	notice.queued = false
	local ok, lines = pcall(ns.ReloadLines)
	if not ok or type(lines) ~= "table" then
		lines = {}
	end
	NoticeSample(#lines == 0 and notice.sample == true)
	if #lines == 0 then
		notice.later = nil
		if notice.frame and notice.frame:IsShown() then
			notice.leaving = true
		end
		return
	end
	if notice.later then
		local now, fresh = {}, false
		for _, entry in ipairs(lines) do
			now[entry[3]] = true
			local held = notice.later[entry[3]]
			fresh = fresh or held == nil or held ~= entry[4]
		end
		for path in pairs(notice.later) do
			if not now[path] then
				notice.later[path] = nil
			end
		end
		if not fresh then
			return
		end
		notice.later = nil
	end
	if not notice.frame then
		local made, frame = pcall(NoticeBuild)
		if not made or type(frame) ~= "table" then
			if not made then
				geterrorhandler()(frame)
			end
			return
		end
	end
	notice.text:SetText(NoticeText(lines))
	NoticeDim(InCombatLockdown())
	notice.wait = 0
	NoticePlace()
	notice.leaving = false
	if not notice.frame:IsShown() then
		notice.alpha = 0
		pcall(notice.frame.SetAlpha, notice.frame, 0)
	elseif notice.tip then
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, notice.tip)
		if ok and owned == true then
			NoticeTip(notice.tip)
		end
	end
	notice.frame:Show()
end

function ns.ReloadNoticeUpdate()
	if notice.queued then
		return
	end
	notice.queued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, NoticeRefresh)
	else
		NoticeRefresh()
	end
end

function ns.ReloadNoticeShown()
	return true
end

function ns.ReloadNoticeMoved()
	notice.placed, notice.samplePlaced = nil, nil
	if notice.frame then
		NoticePlace()
	end
	if notice.sampleFrame and notice.sampleFrame:IsShown() then
		NoticePlace(notice.sampleFrame)
	end
end

if type(ns.TestMode) == "table" and type(ns.TestMode.Watch) == "function" then
	ns.TestMode.Watch(function(on)
		notice.sample = on == true
		ns.ReloadNoticeUpdate()
	end)
end
