local _, ns = ...

local TM = {}
ns.TestMode = TM

local events = CreateFrame("Frame")
ns.Own[events] = true
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

local S = { on = false, source = nil, paused = false, epoch = 0, group = "party", moving = true, wanted = nil }
local entries, entryById, standins, standinById, heard = {}, {}, {}, {}, {}
local watchers = {}
local ui = { notes = {} }
local clock = { poll = 0, bar = 0 }

local POLL, BAR_EVERY = 0.25, 0.5
local UNDER_PANEL = 300
local BAR_W, BAR_H, TOP = 1044, 40, -8
local DOUBLE = 0.3
local FADE_IN, FADE_OUT = 0.15, 0.2
local SOURCES = { panel = "options", movers = "/flatui move", slash = "/flatui test", key = "key" }
local GROUPS = { { "solo", "Solo", 0 }, { "party", "Party", 4 }, { "raid10", "Raid 10", 10 }, { "raid20", "Raid 20", 20 }, { "raid40", "Raid 40", 40 } }
local GROUP_SIZE = { solo = 0, party = 4, raid10 = 10, raid20 = 20, raid40 = 40 }
local CORNERS = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }
local STRATA = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true,
	TOOLTIP = true }
local SAY = {
	combat = "Flat UI: test mode comes on when the fight ends.",
	stays = "Flat UI: test mode stays off.",
	setup = "Flat UI: finish or close Setup first.",
	pause = "Flat UI: test mode pauses for combat.",
	line = "Samples fill in for hidden frames; your real frames take over when they show. Esc > Edit Mode shows the game's own previews.",
	windows = "Open a game window (C, P, N...) to see its look change.",
	place = "%s: no place yet (open Edit Mode once)",
}
local TIPS = {
	solo = { "Solo", "No party or raid samples: you alone, with your target, focus and pet." },
	party = { "Party", "Four sample party members, while you are in no group." },
	raid10 = { "Raid 10", "10 sample members in groups, as Edit Mode lays them out, while you are in no raid." },
	raid20 = { "Raid 20", "20 sample members in groups, as Edit Mode lays them out, while you are in no raid." },
	raid40 = { "Raid 40", "40 sample members in groups, as Edit Mode lays them out, while you are in no raid." },
	moving = { "Moving", "Casts fill, health drifts and cooldowns run. Off holds every sample still, so a look can be judged." },
	Bags = { "Bags", "Opens or closes Flat UI's bag window, as /flatui bags." },
	Bank = { "Bank", "Opens or closes your bank window, as /flatui bank: live at the banker, else as you last left it." },
	Gear = { "Gear", "Opens or closes the Gear comparison window, as /flatui gear." },
	Finder = { "Finder", "Opens or closes the item finder, as the Find button of the Gear comparison window." },
	Queue = { "Queue", "Opens or closes the Trinket queue window, as /flatui queue." },
	Move = { "Move", "Opens /flatui move with these samples, so each frame can be placed where it shows. Press it again to close it." },
	Title = { "Test mode bar", "Drag the bar to move it; it stays there. Double-click here to put it back." },
	End = { "End", "Turns test mode off. Nothing was saved." },
}

local function Report(err)
	local handler = type(geterrorhandler) == "function" and geterrorhandler()
	if type(handler) == "function" then
		handler(err)
	end
end

local function Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		Report(err)
	end
	return ok
end

local function Fn(value)
	return type(value) == "function" and value or nil
end

local function Fighting()
	return InCombatLockdown() == true
end

local function Run(entry, name, ...)
	local fn = entry[name]
	if fn then
		return ns.Try(entry.module, fn, ...)
	end
	return true
end

local function StartEntry(entry)
	if entry.running or not ns.ModuleOn(entry.module) then
		return false
	end
	entry.running, entry.acc = true, 0
	Run(entry, "Start")
	return true
end

local function StopEntry(entry)
	if not entry.running then
		return false
	end
	entry.running = false
	Run(entry, "Stop")
	return true
end

local function Refresh(list)
	local done = {}
	for _, entry in ipairs(list) do
		if entry.refresh and not done[entry.module] then
			done[entry.module] = true
			ns.RefreshModule(entry.module)
		end
	end
end

local function StartAll()
	local started = {}
	for _, entry in ipairs(entries) do
		if StartEntry(entry) then
			started[#started + 1] = entry
		end
	end
	Refresh(started)
end

local function StopAll()
	local stopped = {}
	for _, entry in ipairs(entries) do
		if StopEntry(entry) then
			stopped[#stopped + 1] = entry
		end
	end
	Refresh(stopped)
end

local function Tell(path)
	local list = {}
	for _, entry in ipairs(entries) do
		if entry.running then
			if entry.Changed then
				ns.Try(entry.module, entry.Changed, path)
			end
			list[#list + 1] = entry
		end
	end
	Refresh(list)
end

local function Read(frame, method)
	local ok, value = pcall(frame[method], frame)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function GameFrame(si)
	local frame = _G[si.game]
	if type(frame) ~= "table" or ns.IsSecret(frame) or ns.Forbidden(frame) then
		return nil
	end
	return frame
end

local function Scale(frame)
	local mine, base = Read(frame, "GetEffectiveScale"), Read(UIParent, "GetEffectiveScale")
	if ns.Finite(mine) and ns.Finite(base) and mine > 0 and base > 0 then
		return mine / base
	end
	return 1
end

local function Offstage(si, frame, left, bottom, height)
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[si.game] or nil
	if type(info) ~= "table" or not info.system or info.keptHidden then
		return false
	end
	if ns.MoverShown(frame) == true or (type(ns.MoverSaved) == "function" and ns.MoverSaved(si.game)) then
		return false
	end
	if info.stack == true then
		return true
	end
	local top = Read(UIParent, "GetHeight")
	return ns.Finite(top) and math.abs(left) < 0.5 and math.abs(bottom + height - top) < 0.5
end

local function HiddenByPage(si, frame)
	local hide = ns.HideFrames
	if type(hide) ~= "table" then
		return false
	end
	if type(hide.Key) == "function" and type(hide.Hidden) == "function" then
		local key = hide.Key(si.game)
		if key ~= nil and hide.Hidden(key) == true then
			return true
		end
	end
	return type(hide.Holds) == "function" and hide.Holds(frame) == true
end

local function HideStandIn(si)
	si.shown = false
	if si.holder then
		si.holder:SetScript("OnUpdate", nil)
		si.holder:Hide()
	end
end

local function Broken(si, err)
	if not si.broken then
		si.broken = true
		Report(("Flat UI test mode, stand-in %s: %s"):format(si.id, tostring(err)))
	end
	HideStandIn(si)
end

local function Rule(si, fn)
	local ok, answer = pcall(fn)
	if not ok then
		Broken(si, answer)
		return nil
	end
	return answer == true
end

local function Want(si)
	if si.broken or not TM.IsOn() or not ns.ModuleOn(si.module) or type(ns.MoverRect) ~= "function" or type(ns.MoverShown) ~= "function" then
		return false
	end
	local frame = GameFrame(si)
	if not frame or HiddenByPage(si, frame) then
		return false
	end
	if si.gate and not Rule(si, si.gate) then
		return false
	end
	local real
	if si.real then
		real = Rule(si, si.real)
		if real == nil then
			return false
		end
	else
		real = ns.MoverShown(frame) == true
	end
	if real then
		return false
	end
	local left, bottom, width, height = ns.MoverRect(frame)
	if not (ns.Finite(left) and ns.Finite(bottom) and ns.Finite(width) and ns.Finite(height)) then
		return false
	end
	if Offstage(si, frame, left, bottom, height) then
		return "offstage"
	end
	return true, left, bottom, width, height, Scale(frame), frame
end

local function Place(si, frame)
	local holder, at, k = si.holder, si.at, si.at.k
	local share = CORNERS[si.corner]
	holder:SetScale(k)
	holder:ClearAllPoints()
	holder:SetPoint(si.corner, UIParent, "BOTTOMLEFT", (at.l + at.w * share[1]) / k, (at.b + at.h * share[2]) / k)
	if si.fit then
		holder:SetSize(math.max(1, at.w / k), math.max(1, at.h / k))
	end
	local strata = Read(frame, "GetFrameStrata")
	strata = type(strata) == "string" and STRATA[strata] and strata or "MEDIUM"
	holder:SetFrameStrata(strata)
	local level = Read(frame, "GetFrameLevel")
	if ns.Finite(level) and level >= 0 then
		holder:SetFrameLevel(math.min(level, strata == "HIGH" and UNDER_PANEL or 9000))
	end
end

local function Paint(si)
	local w, h
	if si.fit then
		w, h = math.max(1, si.at.w / si.at.k), math.max(1, si.at.h / si.at.k)
	end
	local ok, width, height = ns.Viewing(ns.LiveView, si.Paint, si.holder, w, h)
	if not ok then
		Broken(si, width)
		return false
	end
	if not si.fit and ns.Finite(width) and ns.Finite(height) and width > 0 and height > 0 then
		si.holder:SetSize(width, height)
	end
	return true
end

local function Animating(si)
	if si.holder then
		si.holder:SetScript("OnUpdate", (si.shown and si.Animate and S.moving) and si.tick or nil)
	end
end

local function ShowStandIn(si, frame)
	if not si.holder then
		local holder = CreateFrame("Frame", nil, UIParent)
		ns.Own[holder] = true
		holder:EnableMouse(false)
		holder:SetSize(1, 1)
		holder:Hide()
		si.holder = holder
		if si.Build then
			local ok, err = pcall(si.Build, holder)
			if not ok then
				Broken(si, err)
				return
			end
		end
	end
	Place(si, frame)
	if not Paint(si) then
		return
	end
	si.holder:Show()
	si.shown = true
	Animating(si)
end

local function Moved(at, l, b, w, h, k)
	return math.abs(at.l - l) > 0.01 or math.abs(at.b - b) > 0.01 or math.abs(at.w - w) > 0.01 or math.abs(at.h - h) > 0.01
		or math.abs(at.k - k) > 0.0001
end

local function Poll()
	local notes = {}
	for _, si in ipairs(standins) do
		local want, l, b, w, h, k, frame = Want(si)
		if want == true then
			local at = si.at
			if not si.shown then
				at.l, at.b, at.w, at.h, at.k = l, b, w, h, k
				ShowStandIn(si, frame)
			elseif Moved(at, l, b, w, h, k) then
				at.l, at.b, at.w, at.h, at.k = l, b, w, h, k
				Place(si, frame)
				Paint(si)
			end
		else
			if si.shown then
				HideStandIn(si)
			end
			if want == "offstage" then
				notes[#notes + 1] = SAY.place:format(si.label)
			end
		end
	end
	ui.notes = notes
end

local function PaintShown()
	for _, si in ipairs(standins) do
		if si.shown and not si.broken then
			Paint(si)
		end
	end
end

local function HideStandIns()
	for _, si in ipairs(standins) do
		HideStandIn(si)
	end
	ui.notes = {}
end

local function Word(word)
	for _, module in pairs(ns.modules or {}) do
		local command = type(module) == "table" and type(module.slash) == "table" and module.slash[word]
		if type(command) == "function" then
			Safe(command, "")
			return
		end
	end
end

local function Finder()
	if type(ns.GearSearchToggle) == "function" then
		Safe(ns.GearSearchToggle)
	end
end

local function Tip(owner, key)
	local tip = TIPS[key]
	if not tip or ns.Forbidden(GameTooltip) then
		return
	end
	ui.tipOwner = owner
	pcall(function()
		GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
		GameTooltip:SetText(tip[1], 1, 1, 1)
		GameTooltip:AddLine(tip[2], 0.66, 0.68, 0.62, true)
		GameTooltip:Show()
	end)
end

local function Untip(owner)
	owner = owner or ui.tipOwner
	if not owner or ns.Forbidden(GameTooltip) then
		return
	end
	if ui.tipOwner == owner then
		ui.tipOwner = nil
	end
	local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, owner)
	if ok and owned == true then
		GameTooltip:Hide()
	end
end

local function PaintBar()
	local look = ns.PanelLook
	for _, segment in ipairs(ui.segments) do
		local chosen = S.group == segment.id
		local hover = segment.hover == true and not chosen
		look.Backing(segment.outline, chosen and "accent" or hover and "hover" or "card", chosen and 0.18 or 1, chosen and "accent" or "line")
		ns.PanelKit.Tint(segment.label, (chosen or hover) and "text" or "text-dim")
	end
	if ui.toggleHover then
		look.Solid(ui.track, S.moving and "accent-hover" or "hover")
	else
		look.Solid(ui.track, S.moving and "accent" or "raised")
	end
	look.Solid(ui.knob, S.moving and "on-accent" or "text-dim")
	if ui.placeKnob then
		ui.placeKnob(S.moving == true)
	else
		ui.knob:ClearAllPoints()
		ui.knob:SetPoint("LEFT", ui.toggle, "LEFT", S.moving and 18 or 2, 0)
	end
end

local function BarSpot()
	local kit = ns.MoverKit
	local movers = type(kit) == "table" and type(kit.IsOpen) == "function" and kit.IsOpen() == true
	local y = movers and TOP - 46 or TOP
	local panel = ns.PanelKit
	local window = type(ns.PanelShown) == "function" and ns.PanelShown() and type(panel) == "table" and panel.Window() or nil
	if not window then
		return "top", y
	end
	local _, bottom, _, height = panel.Rect(window)
	local screen, tall = Read(UIParent, "GetHeight"), Read(ui.bar, "GetHeight")
	if not (ns.Finite(bottom) and ns.Finite(height) and ns.Finite(screen) and ns.Finite(tall)) or height <= 0 then
		return "top", y
	end
	local top = bottom + height
	local title = top - height * panel.TITLE / panel.HEIGHT
	local barTop = screen + y
	if barTop - tall >= top or barTop <= title then
		return "top", y
	end
	if top + tall - TOP <= screen then
		return "above", window
	end
	return "below", window
end

local function Kept(make)
	local db = type(ns.Account) == "function" and ns.Account() or nil
	if type(db) ~= "table" then
		return nil
	end
	if type(db.testBar) ~= "table" then
		if not make then
			return nil
		end
		db.testBar = {}
	end
	return db.testBar
end

local function Load()
	local kept = not S.loaded and Kept(false)
	if type(ns.Account) == "function" and type(ns.Account()) == "table" then
		S.loaded = true
	end
	if kept and type(kept.group) == "string" and GROUP_SIZE[kept.group] then
		S.group = kept.group
	end
end

local function KeepPlace()
	local bar = ui.bar
	local ok, point, relative, relativePoint, x, y = pcall(bar.GetPoint, bar, 1)
	if not (ok and type(point) == "string" and not ns.IsSecret(point) and CORNERS[point] and type(relativePoint) == "string"
		and not ns.IsSecret(relativePoint) and CORNERS[relativePoint] and ns.Finite(x) and ns.Finite(y)) then
		return
	end
	if relative ~= nil and relative ~= UIParent then
		return
	end
	local kept = Kept(true)
	if kept then
		kept.point, kept.relative, kept.x, kept.y = point, relativePoint, x, y
	end
end

local function KeptPlace()
	local kept = Kept(false)
	if not (kept and type(kept.point) == "string" and CORNERS[kept.point] and type(kept.relative) == "string" and CORNERS[kept.relative]
		and ns.Finite(kept.x) and ns.Finite(kept.y)) then
		return
	end
	ui.bar:ClearAllPoints()
	ui.bar:SetPoint(kept.point, UIParent, kept.relative, kept.x, kept.y)
	ui.dragged = true
end

local function PlaceBar()
	if ui.dragged then
		return
	end
	local spot, at = BarSpot()
	if ui.spot == spot and ui.at == at then
		return
	end
	ui.spot, ui.at = spot, at
	ui.bar:ClearAllPoints()
	if spot == "above" then
		ui.bar:SetPoint("BOTTOM", at, "TOP", 0, -TOP)
	elseif spot == "below" then
		ui.bar:SetPoint("TOP", at, "BOTTOM", 0, TOP)
	else
		ui.bar:SetPoint("TOP", UIParent, "TOP", 0, at)
	end
end

local function UpdateBar()
	if not ui.bar then
		return
	end
	ui.title:SetText(S.paused and "Test mode: paused for combat" or "Test mode")
	ui.live:SetShown(not S.paused)
	PaintBar()
	local text = SAY.line
	if not S.paused then
		local look = ns.PanelLook
		if type(ns.PanelShown) == "function" and ns.PanelShown() and not (ns.PanelInMode and ns.PanelInMode()) and look and look.Page() == "windows" then
			text = text .. " " .. SAY.windows
		end
		for _, note in ipairs(ui.notes) do
			text = text .. "\n" .. note
		end
	end
	ui.line:SetText(text)
	local height = ui.line:GetStringHeight()
	ui.bar:SetHeight(BAR_H + (ns.Finite(height) and height or 12) + 10)
	PlaceBar()
end

local function BuildBar()
	local kit, look = ns.PanelKit, ns.PanelLook
	local bar = kit.Frame(UIParent)
	bar:SetFrameStrata("DIALOG")
	bar:SetSize(BAR_W, BAR_H + 22)
	bar:EnableMouse(true)
	bar:SetMovable(true)
	bar:SetClampedToScreen(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	bar:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		ui.dragged = true
		Safe(KeepPlace)
	end)
	local outline = ns.Outline(bar, bar, true)
	kit.Painted(function()
		look.Backing(outline, "card", 1, "line-strong")
	end)
	ui.title = kit.Label(bar, "GameFontNormal", "LEFT", 190)
	ui.title:SetPoint("LEFT", bar, "TOPLEFT", 12, -BAR_H / 2)
	local grip = kit.Frame(bar)
	grip:SetSize(190, BAR_H)
	grip:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	grip:EnableMouse(true)
	grip:RegisterForDrag("LeftButton")
	grip:SetScript("OnDragStart", function()
		bar:StartMoving()
	end)
	grip:SetScript("OnDragStop", function()
		bar:StopMovingOrSizing()
		ui.dragged = true
		Safe(KeepPlace)
	end)
	grip:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" then
			return
		end
		local now = GetTime()
		if ui.clicked and now - ui.clicked <= DOUBLE then
			ui.clicked = nil
			ui.dragged, ui.spot, ui.at = false, nil, nil
			local kept = Kept(false)
			if kept then
				kept.point, kept.relative, kept.x, kept.y = nil, nil, nil, nil
			end
			Safe(PlaceBar)
		else
			ui.clicked = now
		end
	end)
	grip:SetScript("OnEnter", function()
		Tip(grip, "Title")
	end)
	grip:SetScript("OnLeave", function()
		Untip(grip)
	end)
	local live = kit.Frame(bar)
	live:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	live:SetSize(BAR_W - 76, BAR_H)
	ui.live = live
	local group = kit.Dim(kit.Label(live, "GameFontHighlightSmall", "LEFT"))
	group:SetPoint("LEFT", live, "LEFT", 206, 0)
	group:SetText("Group")
	ui.segments = {}
	for index, choice in ipairs(GROUPS) do
		local segment = kit.Frame(live)
		segment:SetSize(54, 24)
		segment:SetPoint("LEFT", live, "LEFT", 246 + (index - 1) * 54, 0)
		local entry = { id = choice[1], outline = ns.Outline(segment, segment, true) }
		entry.label = kit.Label(segment, "GameFontHighlightSmall", "CENTER")
		entry.label:SetPoint("CENTER", segment, "CENTER", 0, 0)
		entry.label:SetText(choice[2])
		kit.Clickable(segment, function()
			TM.SetGroup(choice[1])
		end)
		segment:SetScript("OnEnter", function()
			entry.hover = true
			PaintBar()
			Tip(segment, choice[1])
		end)
		segment:SetScript("OnLeave", function()
			entry.hover = false
			PaintBar()
			Untip(segment)
		end)
		ui.segments[index] = entry
	end
	local moving = kit.Dim(kit.Label(live, "GameFontHighlightSmall", "LEFT"))
	moving:SetPoint("LEFT", live, "LEFT", 532, 0)
	moving:SetText("Moving")
	local toggle = kit.Frame(live)
	toggle:SetSize(32, 16)
	toggle:SetPoint("LEFT", live, "LEFT", 578, 0)
	ui.toggle = toggle
	ui.track = kit.Fill(toggle, "BACKGROUND")
	ui.track:SetAllPoints(toggle)
	ui.knob = kit.Fill(toggle, "ARTWORK")
	ui.knob:SetSize(12, 12)
	ui.placeKnob = type(kit.Slider) == "function" and kit.Slider(ui.knob, toggle, toggle) or nil
	kit.Clickable(toggle, function()
		TM.SetMoving(not S.moving)
		if type(kit.SwitchClick) == "function" then
			kit.SwitchClick(S.moving == true)
		end
	end)
	toggle:SetScript("OnEnter", function()
		ui.toggleHover = true
		PaintBar()
		Tip(toggle, "moving")
	end)
	toggle:SetScript("OnLeave", function()
		ui.toggleHover = false
		PaintBar()
		Untip(toggle)
	end)
	local function Tipped(made, key)
		made:HookScript("OnEnter", function()
			Tip(made, key)
		end)
		made:HookScript("OnLeave", function()
			Untip(made)
		end)
	end
	local x = 622
	for _, button in ipairs({ { "Bags", 50, function() Word("bags") end }, { "Bank", 50, function() Word("bank") end },
		{ "Gear", 50, function() Word("gear") end }, { "Finder", 60, Finder }, { "Queue", 50, function() Word("queue") end },
		{ "Move", 54, function() Word("move") end } }) do
		local made = kit.Button(live, button[1], button[2], button[3])
		made:SetPoint("LEFT", live, "LEFT", x, 0)
		Tipped(made, button[1])
		x = x + button[2] + 4
	end
	local finish = kit.Button(bar, "End", 56, function()
		TM.Off("toggle")
	end, true)
	finish:SetPoint("RIGHT", bar, "TOPRIGHT", -12, -BAR_H / 2)
	Tipped(finish, "End")
	local function Gone()
		Untip(nil)
		ui.toggleHover = false
		for _, entry in ipairs(ui.segments) do
			entry.hover = false
		end
	end
	bar:SetScript("OnHide", Gone)
	live:SetScript("OnHide", Gone)
	ui.line = kit.Dim(kit.Label(bar, "GameFontHighlightSmall", "LEFT", BAR_W - 24, true))
	ui.line:SetPoint("TOPLEFT", bar, "TOPLEFT", 12, -BAR_H)
	kit.Painted(PaintBar)
	ui.bar = bar
end

local function BarRect()
	local bar = ui.bar
	if not bar or Read(bar, "IsVisible") ~= true or type(ns.PanelKit) ~= "table" then
		return nil
	end
	local left, bottom, width, height = ns.PanelKit.Rect(bar)
	if not (ns.Finite(left) and ns.Finite(bottom) and ns.Finite(width) and ns.Finite(height)) then
		return nil
	end
	return left, bottom, width, height, ui.dragged and "dragged" or ui.spot or "top"
end

local function Fade(show)
	local bar = ui.bar
	local shown = bar:IsShown() == true
	if (show and shown and not ui.fadingOut) or (not show and (not shown or ui.fadingOut)) then
		return
	end
	local ok, alpha = pcall(bar.GetAlpha, bar)
	local at = shown and ok and ns.Finite(alpha) and alpha or (show and 0 or 1)
	local span = show and FADE_IN or FADE_OUT
	ui.fadingOut = not show
	bar:SetAlpha(at)
	bar:Show()
	bar:SetScript("OnUpdate", function(self, elapsed)
		local step = (ns.Finite(elapsed) and elapsed or span) / span
		at = show and math.min(1, at + step) or math.max(0, at - step)
		self:SetAlpha(at)
		if show and at >= 1 then
			self:SetScript("OnUpdate", nil)
		elseif not show and at <= 0 then
			self:SetScript("OnUpdate", nil)
			ui.fadingOut = false
			self:Hide()
			self:SetAlpha(1)
		end
	end)
end

local function Controls()
	if S.on then
		if not ui.bar and type(ns.PanelKit) == "table" then
			Safe(BuildBar)
			if ui.bar then
				ui.bar:Hide()
				Safe(KeptPlace)
			end
		end
		if ui.bar then
			Safe(Fade, true)
			Safe(UpdateBar)
		end
	elseif ui.bar then
		Untip(nil)
		Safe(Fade, false)
	end
	if type(ns.RefreshPanel) == "function" then
		Safe(ns.RefreshPanel)
	end
	local mode = ns.MoversMode
	if type(mode) == "table" and type(mode.TestChanged) == "function" then
		Safe(mode.TestChanged)
	end
	local on = TM.IsOn()
	for _, fn in ipairs(watchers) do
		Safe(fn, on)
	end
end

local function Frame(_, elapsed)
	if not TM.IsOn() then
		events:SetScript("OnUpdate", nil)
		return
	end
	if S.dirty then
		S.dirty = false
		Safe(PaintShown)
	end
	clock.poll = clock.poll + elapsed
	if clock.poll >= POLL then
		clock.poll = 0
		Safe(Poll)
	end
	clock.bar = clock.bar + elapsed
	if clock.bar >= BAR_EVERY then
		clock.bar = 0
		Safe(UpdateBar)
	end
	if S.moving then
		local now = GetTime()
		for _, entry in ipairs(entries) do
			if entry.running and entry.Tick then
				entry.acc = entry.acc + elapsed
				if entry.acc >= entry.every then
					entry.acc = 0
					ns.Try(entry.module, entry.Tick, now)
				end
			end
		end
	end
end

local function Begin()
	Load()
	S.dirty = false
	clock.poll, clock.bar = 0, 0
	StartAll()
	events:SetScript("OnUpdate", Frame)
	Safe(Poll)
	Controls()
end

local function Finish()
	StopAll()
	events:SetScript("OnUpdate", nil)
	HideStandIns()
	Controls()
end

local function Pause()
	if not S.on or S.paused then
		return
	end
	S.paused = true
	S.epoch = S.epoch + 1
	Finish()
	print(SAY.pause)
end

local function StillOpen(source)
	source = source or S.source
	if source == "panel" then
		local mode = ns.MoversMode
		return (type(ns.PanelShown) == "function" and ns.PanelShown() == true)
			or (type(mode) == "table" and type(mode.Holding) == "function" and mode.Holding() == true)
	elseif source == "movers" then
		local kit = ns.MoverKit
		return type(kit) == "table" and type(kit.IsOpen) == "function" and kit.IsOpen() == true
	end
	return true
end

local function Resume()
	if not (S.on and S.paused) or Fighting() then
		return
	end
	if not StillOpen() then
		TM.Off(S.source)
		return
	end
	S.paused = false
	S.epoch = S.epoch + 1
	Begin()
end

function TM.IsOn()
	return S.on and not S.paused
end

function TM.On(source)
	if S.on then
		return true
	end
	if Fighting() then
		if S.wanted then
			S.wanted = nil
			print(SAY.stays)
		else
			S.wanted = SOURCES[source] and source or "slash"
			print(SAY.combat)
		end
		return false
	end
	if type(ns.PanelInMode) == "function" and ns.PanelInMode() then
		print(SAY.setup)
		return false
	end
	S.on, S.source, S.paused = true, SOURCES[source] and source or "slash", false
	S.epoch = S.epoch + 1
	heard = {}
	Begin()
	return true
end

function TM.Off(why)
	if not S.on then
		if S.wanted and why == "toggle" then
			S.wanted = nil
			print(SAY.stays)
		end
		return
	end
	S.on, S.source, S.paused = false, nil, false
	S.epoch = S.epoch + 1
	Finish()
end

function TM.Toggle(source)
	if S.on then
		TM.Off("toggle")
		return false
	end
	return TM.On(source)
end

function TM.Pass(source)
	if S.on and SOURCES[source] then
		S.source = source
	end
end

function TM.Source()
	return S.on and S.source or nil
end

function TM.Wanted()
	return not S.on and S.wanted or nil
end

function TM.Drop(source)
	if S.wanted and (source == nil or S.wanted == source) then
		S.wanted = nil
		return true
	end
	return false
end

function TM.Epoch()
	return S.epoch
end

function TM.Group()
	return S.group
end

function TM.GroupSize()
	return GROUP_SIZE[S.group]
end

function TM.SetGroup(group)
	Load()
	if not GROUP_SIZE[group] or group == S.group then
		return false
	end
	S.group = group
	local kept = Kept(true)
	if kept then
		kept.group = group
	end
	if TM.IsOn() then
		Tell("test.group")
		Safe(Poll)
		S.dirty = true
	end
	Safe(UpdateBar)
	return true
end

function TM.Moving()
	return S.moving
end

function TM.SetMoving(on)
	S.moving = on == true
	for _, si in ipairs(standins) do
		Animating(si)
	end
	if TM.IsOn() then
		Tell("test.moving")
	end
	Safe(UpdateBar)
end

function TM.Sound(id)
	if id == nil or heard[id] then
		return false
	end
	heard[id] = true
	return true
end

function TM.Shown(id)
	local si = standinById[id]
	return si ~= nil and si.shown == true
end

function TM.Changed(path)
	if not TM.IsOn() then
		return
	end
	local started = {}
	for _, entry in ipairs(entries) do
		local on = ns.ModuleOn(entry.module)
		if entry.running and not on then
			StopEntry(entry)
		elseif not entry.running and on and StartEntry(entry) then
			started[#started + 1] = entry
		end
		if entry.running and entry.Changed then
			ns.Try(entry.module, entry.Changed, path)
		end
	end
	Refresh(started)
	S.dirty = true
end

function TM.Repaint()
	if TM.IsOn() then
		S.dirty = true
	end
end

function TM.Watch(fn)
	if type(fn) ~= "function" then
		return false
	end
	watchers[#watchers + 1] = fn
	return true
end

function TM.Status()
	if not S.on then
		return nil
	end
	local running, shown = 0, 0
	for _, entry in ipairs(entries) do
		running = running + (entry.running and 1 or 0)
	end
	for _, si in ipairs(standins) do
		shown = shown + (si.shown and 1 or 0)
	end
	return ("Test mode: %s (%s), %d samples, %d stand-ins shown"):format(S.paused and "paused for combat" or "on", SOURCES[S.source] or "?",
		running, shown)
end

function TM.BarRect()
	return BarRect()
end

function TM.Register(id, spec)
	if type(id) ~= "string" or entryById[id] or type(spec) ~= "table" or type(spec.module) ~= "string" then
		return false
	end
	local every = spec.every
	local entry = { id = id, module = spec.module, label = type(spec.label) == "string" and spec.label or id, refresh = spec.refresh == true,
		Start = Fn(spec.Start), Stop = Fn(spec.Stop), Changed = Fn(spec.Changed), Tick = Fn(spec.Tick), acc = 0,
		every = ns.Finite(every) and every > 0 and every or 1 }
	entries[#entries + 1] = entry
	entryById[id] = entry
	ns.AddStart(spec.module, function()
		if TM.IsOn() and StartEntry(entry) then
			Refresh({ entry })
		end
	end)
	return true
end

function TM.StandIn(spec)
	if type(spec) ~= "table" or type(spec.id) ~= "string" or standinById[spec.id] or type(spec.module) ~= "string" or type(spec.game) ~= "string"
		or type(spec.Paint) ~= "function" then
		return false
	end
	local si = { id = spec.id, module = spec.module, game = spec.game, label = type(spec.label) == "string" and spec.label or spec.id,
		corner = CORNERS[spec.corner] and spec.corner or "TOPLEFT", fit = spec.fit == true, gate = Fn(spec.gate), real = Fn(spec.real),
		Build = Fn(spec.Build), Paint = spec.Paint, Animate = Fn(spec.Animate), at = {}, shown = false }
	si.tick = function(_, elapsed)
		local ok, err = pcall(si.Animate, si.holder, elapsed, GetTime())
		if not ok then
			Broken(si, err)
		end
	end
	standins[#standins + 1] = si
	standinById[si.id] = si
	return true
end

local function Wished()
	local source = S.wanted
	if not source or S.on or Fighting() then
		return
	end
	S.wanted = nil
	if not StillOpen(source) or (source == "panel" and type(ns.PanelInMode) == "function" and ns.PanelInMode()) then
		return
	end
	TM.On(source)
end

events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		Safe(Pause)
	elseif event == "PLAYER_REGEN_ENABLED" and S.wanted and not S.on then
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				Safe(Wished)
			end)
		else
			Safe(Wished)
		end
	elseif event == "PLAYER_REGEN_ENABLED" and S.on and S.paused then
		local epoch = S.epoch
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if S.epoch == epoch then
					Safe(Resume)
				end
			end)
		else
			Safe(Resume)
		end
	end
end)

local BUTTON = "FlatUITestButton"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"
_G["BINDING_NAME_" .. BINDING] = "Flat UI test mode"

do
	local ok, button = pcall(CreateFrame, "Button", BUTTON, UIParent)
	if ok and type(button) == "table" then
		ns.Own[button] = true
		pcall(button.RegisterForClicks, button, "LeftButtonUp")
		button:SetScript("OnClick", function()
			Safe(TM.Toggle, "key")
		end)
	end
end
