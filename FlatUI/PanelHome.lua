local _, ns = ...

local Home = {}
ns.PanelHome = Home

local kit = ns.PanelKit
local Look = ns.PanelLook
local Nav = ns.PanelNav

local MARGIN, GAP, MAX = 24, 12, 50
local SHOWN = 3
local TILE_H, CARD_H = 64, 140

local log = {}
local undone = {}

function Home.ReloadLines()
	return ns.ReloadLines()
end

local function ReloadText(entry)
	if entry[2] == "change" then
		return ("%s applies after a reload."):format(entry[1])
	end
	return ("Turning off %s takes full effect after a reload."):format(entry[1])
end
Home.ReloadText = ReloadText

local function Where(item)
	return item.path:sub(1, 6) == "panel." and "" or ns.Profile()
end

local function Same(a, b)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) <= 1e-6 * math.max(1, math.abs(b))
	end
	return a == b
end

local function Stands(entry)
	local ok, now = pcall(ns.Get, entry.item.path)
	if not ok or ns.IsSecret(now) then
		return true
	end
	return Same(now, entry.new)
end

local function Trim()
	local count, last = 0, nil
	for index, entry in ipairs(log) do
		if not entry.batch or entry.batch ~= last then
			count = count + 1
			if count > MAX then
				for at = #log, index, -1 do
					log[at] = nil
				end
				return
			end
		end
		last = entry.batch
	end
end

function Home.Noted(item, before, after, batch)
	if type(item) ~= "table" or not item.path or before == after then
		return
	end
	undone = {}
	local where = Where(item)
	if type(batch) == "table" then
		table.insert(log, 1, { item = item, profile = where, old = before, new = after, batch = batch })
	else
		for index, entry in ipairs(log) do
			if entry.item == item and entry.profile == where then
				table.remove(log, index)
				if Same(entry.new, before) then
					before = entry.old
				end
				break
			end
		end
		if before ~= after then
			table.insert(log, 1, { item = item, profile = where, old = before, new = after })
		end
	end
	Trim()
end

function Home.Log()
	local list, profile = {}, ns.Profile()
	for _, entry in ipairs(log) do
		if (entry.profile == "" or entry.profile == profile) and Stands(entry) then
			list[#list + 1] = entry
		end
	end
	return list
end

function Home.Lines(list)
	local lines = {}
	for _, entry in ipairs(list or Home.Log()) do
		local last = lines[#lines]
		if entry.batch and last and last.batch == entry.batch then
			last.entries[#last.entries + 1] = entry
		else
			lines[#lines + 1] = { entry = entry, entries = { entry }, batch = entry.batch }
		end
	end
	return lines
end

function Home.Renamed(old, new)
	for _, entry in ipairs(log) do
		if entry.profile == old then
			entry.profile = new
		end
	end
	for _, group in ipairs(undone) do
		for _, entry in ipairs(group.entries) do
			if entry.profile == old then
				entry.profile = new
			end
		end
	end
end

local function LabelOf(entry)
	return type(entry.item.label) == "string" and entry.item.label or "a setting"
end

local function ValueOf(entry, value)
	return ns.PanelTrust and ns.PanelTrust.ValueText(entry.item, value) or "changed"
end

local function Take(entry)
	for index, other in ipairs(log) do
		if other == entry then
			table.remove(log, index)
			break
		end
	end
	ns.Set(entry.item.path, entry.old)
end

function Home.UndoText(entry)
	local old = ValueOf(entry, entry.old)
	if old == "changed" then
		return ("Undid %s."):format(LabelOf(entry))
	end
	return ("Undid %s: back to %s."):format(LabelOf(entry), old)
end

function Home.Undo(entry)
	Take(entry)
	undone[#undone + 1] = { entries = { entry } }
	return Home.UndoText(entry), entry
end

function Home.UndoBatch(batch, list)
	local taken = {}
	for _, other in ipairs(list or Home.Log()) do
		if other.batch == batch then
			Take(other)
			taken[#taken + 1] = other
		end
	end
	if #taken == 0 then
		return "Nothing to undo."
	end
	undone[#undone + 1] = { entries = taken, batch = batch }
	if #taken == 1 then
		return Home.UndoText(taken[1]), taken[1]
	end
	return ("Undid %s: %d settings back."):format(batch.label or "Reset page", #taken), taken[#taken]
end

function Home.UndoNewest()
	local list = Home.Log()
	local entry = list[1]
	if not entry then
		local lost = type(ns.LostProfile) == "function" and ns.LostProfile() or nil
		if type(lost) == "table" and lost.inUse then
			return ("Nothing to undo. Profiles > Bring back puts %s back as it was before %s."):format(lost.name, lost.what)
		end
		return "Nothing to undo."
	end
	if entry.batch then
		return Home.UndoBatch(entry.batch, list)
	end
	return Home.Undo(entry)
end

local function Redoable(entry)
	if entry.profile ~= Where(entry.item) then
		return false
	end
	local ok, now = pcall(ns.Get, entry.item.path)
	return ok and not ns.IsSecret(now) and Same(now, entry.old)
end

function Home.Redo()
	for index = #undone, 1, -1 do
		local group = undone[index]
		local redo = {}
		for _, entry in ipairs(group.entries) do
			if Redoable(entry) then
				redo[#redo + 1] = entry
			end
		end
		if #redo > 0 then
			table.remove(undone, index)
			for at = #redo, 1, -1 do
				local entry = redo[at]
				ns.Set(entry.item.path, entry.new)
				table.insert(log, 1, entry)
			end
			Trim()
			if #redo == 1 then
				local new = ValueOf(redo[1], redo[1].new)
				if new == "changed" then
					return ("Redid %s."):format(LabelOf(redo[1])), redo[1]
				end
				return ("Redid %s: %s again."):format(LabelOf(redo[1]), new), redo[1]
			end
			return ("Redid %s: %d settings again."):format(group.batch and group.batch.label or "the change", #redo), redo[#redo]
		elseif group.entries[1] and group.entries[1].profile == Where(group.entries[1].item) then
			table.remove(undone, index)
		end
	end
	return "Nothing to redo."
end

function Home.UndoReload(entry)
	if type(entry) ~= "table" then
		return
	end
	if InCombatLockdown() then
		kit.Say("Undo after the fight.")
		return
	end
	local label, path, now, was = entry[1], entry[3], entry[4], entry[5]
	if type(path) ~= "string" or was == nil then
		return
	end
	local done, err = pcall(ns.Set, path, was)
	if not done then
		geterrorhandler()(err)
	elseif ns.Get(path) == was then
		local item = ns.Def(path) or { path = path, label = label }
		local name = type(label) == "string" and label or "a setting"
		Home.Noted(item, now, was, { label = "Undo of " .. name, what = "Needs a reload's Undo" })
		kit.Say(("Undid %s: back to %s. It needs no reload now. Ctrl+Z makes it again."):format(name, ns.PanelTrust.ValueText(item, was)))
	end
	kit.Refresh()
end

local function Choose(path, label, value)
	local item = { path = path, label = label }
	for _, page in ipairs(ns.PAGES) do
		for _, row in ipairs(page) do
			if row.path == path then
				item = row
			end
		end
	end
	local before = ns.Get(path)
	ns.Set(path, value)
	Home.Noted(item, before, ns.Get(path))
end

function Home.Counts(model)
	local counts = {}
	for _, page in ipairs(ns.PAGES) do
		local entry = model.byKey[page.key]
		if entry then
			local top = Nav.Top(model, entry)
			top = top.partOf and model.byKey[top.partOf] or top
			for _, item in ipairs(page) do
				if item.path and item.kind ~= "list" and item.kind ~= "entries" and not ns.RowUnsaved(item) and ns.Get(item.path) ~= item.default then
					counts[top] = (counts[top] or 0) + 1
				end
			end
		end
	end
	return counts
end

function Home.Modules(model)
	local list = {}
	for _, group in ipairs(Nav.Groups(model)) do
		for _, entry in ipairs(group.entries) do
			if not entry.partOf then
				list[#list + 1] = entry
			end
		end
	end
	return list
end

function Home.Subtitle(model)
	local on, total = 0, 0
	for _, entry in ipairs(Home.Modules(model)) do
		total = total + 1
		if Nav.IsOn(entry) then
			on = on + 1
		end
	end
	return ("%d of %d modules on"):format(on, total)
end

local pageOf
function Home.EntryOf(model, item)
	if not pageOf or pageOf.model ~= model then
		pageOf = { model = model }
		for _, entry in ipairs(model.pages) do
			for _, row in ipairs(entry.page) do
				if row.key and pageOf[row] == nil then
					pageOf[row] = entry
				end
			end
		end
	end
	return item and pageOf[item]
end

function Home.RowOf(model, path)
	for _, entry in ipairs(model.pages) do
		for _, row in ipairs(entry.page) do
			if row.key and row.path == path then
				return Home.EntryOf(model, row), row
			end
		end
	end
	return nil
end

local function Crumb(model, item)
	local entry = Home.EntryOf(model, item)
	if not entry then
		return ""
	end
	local top = Nav.Top(model, entry)
	if top == entry then
		return entry.label
	end
	local frame = ns.PanelTabs.FrameName(entry)
	return top.label .. " > " .. (ns.PanelTabs.Label(model, entry) or entry.label) .. (frame and " > " .. frame or "")
end
Home.Crumb = Crumb

function Home.UserCount(name)
	local db = ns.Account()
	local count = 0
	for _, used in pairs(type(db) == "table" and type(db.profileOf) == "table" and db.profileOf or {}) do
		if used == name then
			count = count + 1
		end
	end
	if count == 0 and name == ns.Profile() then
		count = 1
	end
	return count
end

local function Users(name)
	local count = Home.UserCount(name)
	return count == 1 and "Used by 1 character" or ("Used by %d characters"):format(count)
end

local ACCENTS = { { "indigo", "Indigo" }, { "sage", "Sage" }, { "amber", "Amber" }, { "rose", "Rose" }, { "ice", "Ice" }, { "class", "Class colour" },
	{ "custom", "Custom" } }

local function Segmented(row, choices, path, label)
	local frame = kit.Frame(row.frame)
	frame:SetSize(#choices * 84, 24)
	frame:SetPoint("RIGHT", row.frame, "RIGHT", 0, 0)
	local paints = {}
	for index, choice in ipairs(choices) do
		local part = kit.Frame(frame)
		part:SetSize(84, 24)
		part:SetPoint("LEFT", frame, "LEFT", (index - 1) * 84, 0)
		local fill = kit.Fill(part, "BACKGROUND")
		fill:SetAllPoints(part)
		local text = kit.Label(part, "GameFontHighlight", "CENTER", 84)
		text:SetPoint("CENTER", part, "CENTER", 0, 0)
		text:SetText(choice[2])
		local hover = false
		local function Paint()
			local on = ns.Get(path) == choice[1]
			if on then
				Look.Solid(fill, "accent", 0.3)
			else
				Look.Solid(fill, hover and "hover" or "raised")
			end
			kit.Tint(text, on and "text" or "text-dim")
		end
		paints[index] = Paint
		kit.Painted(Paint)
		kit.Clickable(part, function()
			Choose(path, label, choice[1])
			kit.Refresh()
		end)
		part:SetScript("OnEnter", function()
			hover = true
			Paint()
		end)
		part:SetScript("OnLeave", function()
			hover = false
			Paint()
		end)
	end
	return function()
		for _, Paint in ipairs(paints) do
			Paint()
		end
	end
end

function Home.Build(host)
	local scroller = kit.Scroller(host.right, host.width, host.height)
	scroller.frame:SetPoint("TOPLEFT", host.right, "TOPLEFT", 0, -host.top)
	local child = scroller.child
	local view = { scroller = scroller, rows = {}, sections = {} }
	local model = host.Model()
	local inner = host.width - 2 * MARGIN
	local half = math.floor((inner - GAP) / 2)
	local rowH = kit.ROW
	local cardH = 32 + 3 * rowH + 8
	local refreshers = {}

	local function Card(width, title)
		local frame = kit.Frame(child)
		local outline = ns.Outline(frame, frame, true)
		kit.Painted(function()
			kit.Backing(outline, "card", 1, "line")
		end)
		local text = kit.Label(frame, "GameFontNormal", "LEFT", width - 32)
		text:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -9)
		text:SetText(title)
		return frame
	end

	local function Place(frame, x, y, w, h)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
		frame:SetSize(w, h)
	end

	local profile = Card(half, "Profile")
	local row = kit.NewRow(profile, 32, "Profile in use")
	local menu = kit.Dropdown(row, 190, {
		lines = host.ProfileLines,
		selected = host.Profile,
		pick = function(name)
			host.Act("UseProfile", name)
		end,
	})
	menu.frame:SetPoint("RIGHT", row.frame, "RIGHT", 0, 0)
	local users = kit.Dim(kit.Label(profile, "GameFontHighlightSmall", "LEFT", half - 32))
	users:SetPoint("TOPLEFT", profile, "TOPLEFT", 16, -(32 + rowH + 8))
	local room = half - 32 - 16
	local buttons = { { "Set up my screen", function() host.Setup() end, 5 }, { "Export", function() ns.OpenPanelShare() end, 3 },
		{ "Ready-made", function() host.Call("OpenProfiles") end, 4 } }
	local x = 16
	for _, spec in ipairs(buttons) do
		local width = math.floor(room * spec[3] / 12)
		local button = kit.Button(profile, spec[1], width, spec[2])
		button:SetPoint("TOPLEFT", profile, "TOPLEFT", x, -(cardH - 36))
		x = x + width + 8
	end
	refreshers[#refreshers + 1] = function()
		menu.SetText(host.Profile())
		users:SetText(Users(host.Profile()))
	end

	local look = Card(half, "Accent and density")
	local accentRow = kit.NewRow(look, 32, "Accent")
	local swatches = {}
	for index, choice in ipairs(ACCENTS) do
		local swatch = kit.Frame(accentRow.frame)
		swatch:SetSize(24, 24)
		swatch:SetPoint("RIGHT", accentRow.frame, "RIGHT", -((#ACCENTS - index) * 32), 0)
		local fill = kit.Fill(swatch, "BACKGROUND")
		fill:SetAllPoints(swatch)
		local mark = kit.Fill(swatch, "ARTWORK")
		mark:SetSize(14, 14)
		mark:SetPoint("CENTER", swatch, "CENTER", 0, 0)
		Nav.Cell(mark, "check")
		local function Paint()
			fill:SetColorTexture(Look.PresetRGB(choice[1]))
			mark:SetVertexColor(Look.Colour("window"))
			mark:SetShown(ns.Get("panel.accent") == choice[1])
		end
		swatches[index] = Paint
		kit.Painted(Paint)
		kit.Clickable(swatch, function()
			Choose("panel.accent", "Accent colour", choice[1])
			kit.Refresh()
		end)
		swatch:SetScript("OnEnter", function()
			kit.Tip(choice[2])
		end)
		swatch:SetScript("OnLeave", function()
			kit.Tip("")
		end)
	end
	refreshers[#refreshers + 1] = function()
		for _, Paint in ipairs(swatches) do
			Paint()
		end
	end
	refreshers[#refreshers + 1] = Segmented(kit.NewRow(look, 32 + rowH, "Density"), { { "compact", "Compact" }, { "comfortable", "Comfortable" },
		{ "roomy", "Roomy" } }, "panel.density", "Density")
	refreshers[#refreshers + 1] = Segmented(kit.NewRow(look, 32 + 2 * rowH, "Corners"), { { "square", "Square" }, { "soft", "Soft" }, { "round", "Round" } },
		"panel.corners", "Corners")

	local reload = Card(inner, "Needs a reload")
	local reloadButton = kit.Button(reload, "Reload", 88, ns.Reload)
	reloadButton:SetPoint("TOPRIGHT", reload, "TOPRIGHT", -16, -4)
	ns.SecureReload(reloadButton)
	local function Opens(frame, line)
		local fill = kit.Fill(frame, "BACKGROUND")
		fill:SetAllPoints(frame)
		fill:Hide()
		kit.Painted(function()
			Look.Solid(fill, "hover")
		end)
		local function Target()
			if line.path then
				return Home.RowOf(model, line.path)
			end
			local item = line.entry and line.entry.item
			return Home.EntryOf(model, item), item
		end
		kit.Clickable(frame, function()
			local entry, item = Target()
			if entry and host.Arrive then
				host.Arrive(entry, item)
			end
		end)
		frame:SetScript("OnEnter", function()
			fill:SetShown(Target() ~= nil)
		end)
		frame:SetScript("OnLeave", function()
			fill:Hide()
		end)
	end
	local reloadLines = {}
	for index = 1, 8 do
		local frame = kit.Frame(reload)
		frame:SetHeight(22)
		frame:SetPoint("TOPLEFT", reload, "TOPLEFT", 12, -(30 + (index - 1) * 22))
		frame:SetPoint("TOPRIGHT", reload, "TOPRIGHT", -12, -(30 + (index - 1) * 22))
		local line = { frame = frame }
		line.label = kit.Label(frame, "GameFontHighlight", "LEFT", inner - 32 - 70)
		line.label:SetPoint("LEFT", frame, "LEFT", 4, 0)
		Opens(frame, line)
		line.undo = kit.Button(frame, "Undo", 60, function()
			Home.UndoReload(line.entry)
		end)
		line.undo:SetHeight(20)
		line.undo:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
		line.undo:HookScript("OnEnter", function()
			local entry = line.entry
			if type(entry) == "table" and entry[5] ~= nil then
				local item = ns.Def(entry[3]) or { path = entry[3], label = entry[1] }
				kit.Tip(("Puts back %s: %s, as at login, so it needs no reload."):format(type(entry[1]) == "string" and entry[1] or "this setting",
					ns.PanelTrust.ValueText(item, entry[5])))
			end
		end)
		line.undo:HookScript("OnLeave", function()
			kit.Tip("")
		end)
		reloadLines[index] = line
	end

	local recent = Card(inner, "Recent changes")
	local more = kit.Frame(recent)
	more:SetSize(120, 20)
	more:SetPoint("TOPRIGHT", recent, "TOPRIGHT", -16, -8)
	local moreText = kit.Dim(kit.Label(more, "GameFontHighlightSmall", "RIGHT", 120))
	moreText:SetPoint("RIGHT", more, "RIGHT", 0, 0)
	kit.Clickable(more, function()
		view.all = not view.all
		view.Update()
	end)
	local empty = kit.Dim(kit.Label(recent, "GameFontHighlight", "LEFT", 300))
	empty:SetText("No changes yet.")
	local lines = {}
	local function Line(index)
		if lines[index] then
			return lines[index]
		end
		local frame = kit.Frame(recent)
		frame:SetHeight(rowH)
		local line = { frame = frame }
		Opens(frame, line)
		line.label = kit.Label(frame, "GameFontHighlight", "LEFT", 200)
		line.label:SetPoint("LEFT", frame, "LEFT", 0, 0)
		line.value = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", 190))
		line.value:SetPoint("LEFT", line.label, "RIGHT", 8, 0)
		local rule = kit.Fill(frame, "BORDER")
		rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		rule:SetHeight(1)
		kit.Painted(function()
			Look.Solid(rule, "line-faint")
		end)
		local undo = kit.Button(frame, "Undo", 70, function()
			if line.entry then
				local text = line.batch and Home.UndoBatch(line.batch) or Home.Undo(line.entry)
				kit.Say(text)
				kit.Refresh()
			end
		end)
		undo:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
		undo:HookScript("OnEnter", function()
			if line.entry then
				local keys = " Ctrl+Z puts back the newest change; Ctrl+Y does it again."
				if line.batch and line.count > 1 then
					kit.Tip(("Puts back the %d settings %s changed."):format(line.count, line.batch.what or "this") .. keys)
					return
				end
				local old = ns.PanelTrust.ValueText(line.entry.item, line.entry.old)
				kit.Tip((old == "changed" and "Puts back the value before this change." or ("Puts back: " .. old)) .. keys)
			end
		end)
		undo:HookScript("OnLeave", function()
			kit.Tip("")
		end)
		line.crumb = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "RIGHT", 240))
		line.crumb:SetPoint("RIGHT", undo, "LEFT", -12, 0)
		lines[index] = line
		return line
	end

	local modulesLabel = kit.Dim(kit.Label(child, "GameFontHighlight", "LEFT", 300))
	modulesLabel:SetText("Modules")
	local modulesCount = kit.Dim(kit.Label(child, "GameFontHighlight", "RIGHT", 300))
	local tileW = math.floor((inner - 3 * GAP) / 4)
	local tiles = {}
	for index, entry in ipairs(Home.Modules(model)) do
		local frame = kit.Frame(child)
		local outline = ns.Outline(frame, frame, true)
		local hover = false
		local tile = { frame = frame, entry = entry }
		kit.Painted(function()
			kit.Backing(outline, hover and "hover" or "card", 1, "line")
		end)
		tile.icon = kit.Fill(frame, "ARTWORK")
		tile.icon:SetSize(20, 20)
		tile.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
		Nav.Cell(tile.icon, Nav.CELLS[entry.key] and entry.key or "more")
		function tile.Paint()
			local r, g, b = Look.Colour(tile.live and "text" or "text-dim")
			tile.icon:SetVertexColor(r, g, b, tile.live and 0.9 or 0.45)
		end
		kit.Painted(tile.Paint)
		tile.name = kit.Label(frame, "GameFontHighlight", "LEFT", tileW - 40 - 12, true)
		tile.name:SetJustifyV("TOP")
		tile.name:SetHeight(30)
		tile.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -10)
		tile.name:SetText(entry.page and entry.page.moduleLabel or entry.label)
		tile.state = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", tileW - 40 - 52))
		tile.state:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -42)
		if entry.switchItem then
			tile.switch = Nav.Switch(frame, function()
				host.Toggle(entry.switchItem)
			end)
			tile.switch.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
		end
		kit.Clickable(frame, function()
			host.Show(entry)
		end)
		frame:SetScript("OnEnter", function()
			hover = true
			kit.Backing(outline, "hover", 1, "line")
		end)
		frame:SetScript("OnLeave", function()
			hover = false
			kit.Backing(outline, "card", 1, "line")
		end)
		tiles[index] = tile
	end

	local shape
	local function Layout(shownLines, reloadCount)
		local y = 12
		Place(profile, MARGIN, y, half, cardH)
		Place(look, MARGIN + half + GAP, y, half, cardH)
		y = y + cardH + GAP
		reload:SetShown(reloadCount > 0)
		if reloadCount > 0 then
			local height = 34 + reloadCount * 22 + 8
			Place(reload, MARGIN, y, inner, height)
			y = y + height + GAP
		end
		local height = 32 + math.max(1, shownLines) * rowH + 8
		Place(recent, MARGIN, y, inner, height)
		y = y + height + GAP + 4
		modulesLabel:ClearAllPoints()
		modulesLabel:SetPoint("TOPLEFT", child, "TOPLEFT", MARGIN, -y)
		modulesCount:ClearAllPoints()
		modulesCount:SetPoint("TOPRIGHT", child, "TOPRIGHT", -MARGIN, -y)
		y = y + 24
		for index, tile in ipairs(tiles) do
			local column, line = (index - 1) % 4, math.floor((index - 1) / 4)
			Place(tile.frame, MARGIN + column * (tileW + GAP), y + line * (TILE_H + GAP), tileW, TILE_H)
		end
		y = y + math.ceil(#tiles / 4) * (TILE_H + GAP)
		scroller.SetContent(y + 12)
	end

	function view.Update()
		for _, refresh in ipairs(refreshers) do
			refresh()
		end
		local mine = Home.Lines()
		local total = #mine
		local shownLines = view.all and total or math.min(total, SHOWN)
		more:SetShown(total > SHOWN)
		moreText:SetText(view.all and "Show fewer" or "Show all")
		empty:SetShown(total == 0)
		empty:ClearAllPoints()
		empty:SetPoint("TOPLEFT", recent, "TOPLEFT", 16, -(32 + (rowH - 14) / 2))
		for index = 1, math.max(shownLines, #lines) do
			if index <= shownLines then
				local line, group = Line(index), mine[index]
				local entry = group.entry
				line.entry, line.batch, line.count = entry, group.batch, #group.entries
				if group.batch and line.count > 1 then
					line.label:SetWidth(400)
					line.label:SetText(group.batch.label or "Reset page")
					line.value:SetText(("%d settings"):format(line.count))
					line.crumb:SetText("")
				else
					line.label:SetWidth(200)
					line.label:SetText(entry.item.label or "")
					local Value = ns.PanelTrust.ValueText
					local old, new = Value(entry.item, entry.old), Value(entry.item, entry.new)
					line.value:SetText(old ~= new and ("%s to %s"):format(old, new) or "")
					line.crumb:SetText(Crumb(model, entry.item))
				end
				line.frame:ClearAllPoints()
				line.frame:SetPoint("TOPLEFT", recent, "TOPLEFT", 16, -(32 + (index - 1) * rowH))
				line.frame:SetPoint("TOPRIGHT", recent, "TOPRIGHT", -16, -(32 + (index - 1) * rowH))
				line.frame:Show()
			elseif lines[index] then
				lines[index].entry, lines[index].batch = nil, nil
				lines[index].frame:Hide()
			end
		end
		local needed = Home.ReloadLines()
		local fight = InCombatLockdown() == true
		for index, line in ipairs(reloadLines) do
			local entry = needed[index]
			if index == #reloadLines and #needed > #reloadLines then
				line.label:SetText(("%d more"):format(#needed - #reloadLines + 1))
				line.path, line.entry = nil, nil
			else
				line.label:SetText(entry and ReloadText(entry) or "")
				line.path, line.entry = entry and entry[3], entry
			end
			line.undo:SetShown(line.entry ~= nil and line.entry[5] ~= nil)
			line.undo:SetAlpha(fight and 0.4 or 1)
			line.frame:SetShown(entry ~= nil)
		end
		local counts, on = Home.Counts(model), 0
		for _, tile in ipairs(tiles) do
			local count = counts[tile.entry] or 0
			tile.state:SetText(count == 0 and "Defaults" or ("%d changed"):format(count))
			local live = Nav.IsOn(tile.entry)
			on = on + (live and 1 or 0)
			tile.live = live
			tile.Paint()
			if tile.switch then
				tile.switch.Set(ns.Get(tile.entry.switchItem.path) == true)
			end
		end
		modulesCount:SetText(("%d on"):format(on))
		local now = ("%d:%d"):format(shownLines, math.min(#needed, #reloadLines))
		if now ~= shape then
			shape = now
			Layout(shownLines, math.min(#needed, #reloadLines))
		end
	end

	return view
end
