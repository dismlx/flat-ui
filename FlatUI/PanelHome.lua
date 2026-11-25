local _, ns = ...

-- The Home page of the options window: the profile in use, the accent and density, the last changes of the session with Undo, the modules
-- with their switches, and the changes that need a reload. A recent change says what it was, from the value before to the value now ("Off to On",
-- "300 ms to 450 ms"), in the words of the reset arrow's tooltip (ns.PanelTrust.ValueText), and its Undo names the value it puts back. A click on a
-- recent change or on a line of Needs a reload opens the tab of its setting, scrolls to the row and flashes it, as a search result does
-- (host.Arrive). Also the record of the changes made in the window, which Panel.lua feeds.

local Home = {}
ns.PanelHome = Home

local kit = ns.PanelKit
local Look = ns.PanelLook
local Nav = ns.PanelNav

local MARGIN, GAP, MAX = 24, 12, 50
local SHOWN = 3
local TILE_H, CARD_H = 64, 140

-- The record --------------------------------------------------------------------------------------------

local log = {}

-- The changes that need a reload, as ns.ReloadLines (Core.lua) gives them from the values at login, so a change made before the window was opened,
-- in setup, by a profile switch or a slash command, is listed too. Entries { label, field, path, value, was }, was being the value at login.
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

-- Where a setting is saved: a key of the window is kept for the account, any other key in the profile in use.
local function Where(item)
	return item.path:sub(1, 6) == "panel." and "" or ns.Profile()
end

-- A change made in the window: the setting, the profile it was saved in, the value it had and the value it has. A setting has one line: a new change
-- to it replaces the line and keeps the first value, so a slider that moves 20 times is one line, and a change back to the first value takes the line away.
function Home.Noted(item, before, after)
	if type(item) ~= "table" or not item.path or before == after then
		return
	end
	local where = Where(item)
	for index, entry in ipairs(log) do
		if entry.item == item and entry.profile == where then
			table.remove(log, index)
			before = entry.old
			break
		end
	end
	if before ~= after then
		table.insert(log, 1, { item = item, profile = where, old = before, new = after })
	end
	while #log > MAX do
		table.remove(log)
	end
end

-- The changes made in the profile in use and in the window, newest first. A change made in another profile is not listed.
function Home.Log()
	local list, profile = {}, ns.Profile()
	for _, entry in ipairs(log) do
		if entry.profile == "" or entry.profile == profile then
			list[#list + 1] = entry
		end
	end
	return list
end

-- Puts a setting back to the value it had before the change.
function Home.Undo(entry)
	for index, other in ipairs(log) do
		if other == entry then
			table.remove(log, index)
			break
		end
	end
	ns.Set(entry.item.path, entry.old)
end

-- A change made on Home goes into the record like the same change on the Flat UI page: with the row of Config.lua of the key.
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

-- The number of settings of each module that are not at their default, by the page of the module. A setting that the game or a function of ns holds is
-- not counted.
function Home.Counts(model)
	local counts = {}
	for _, page in ipairs(ns.PAGES) do
		local entry = model.byKey[page.key]
		if entry then
			local top = Nav.Top(model, entry)
			-- A page of the sidebar that is part of another module counts on that module's tile.
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

-- The modules as the sidebar lists them: the entries of the groups, in order. A page of the sidebar that holds part of another module (Buffs
-- and debuffs of Minimap and HUD) is no module of its own: it has its module's switch, and the module has one tile.
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

-- "17 of 24 modules on".
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

-- The page of the sidebar a row of a page is on, or nil.
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

-- The row of the options pages that sets a saved path, and its page, or nil.
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

-- The words that say where a setting is: its module, and the page when that is a tab of the module.
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

local function Users(name)
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
	return count == 1 and "Used by 1 character" or ("Used by %d characters"):format(count)
end

-- The page ------------------------------------------------------------------------------------------------

local ACCENTS = { { "indigo", "Indigo" }, { "sage", "Sage" }, { "amber", "Amber" }, { "rose", "Rose" }, { "ice", "Ice" }, { "class", "Class colour" },
	{ "custom", "Custom" } }

-- A row of segments for a choice of the look: the chosen one in the accent. Returns the function that paints it again.
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

-- host: Model(), right, width, top and height of the column, Show(entry), Arrive(entry, item), Setup(), Call(name), Act(name, ...), ProfileLines(),
-- Profile(), Toggle(item).
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

	-- Profile
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
	-- The three buttons share the room by the length of their text (the third field, in twelfths), so Set up my screen fits at every density.
	-- Ready-made opens the welcome screen's ready-made looks (SetupWelcome.lua).
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

	-- Accent and density
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

	-- Needs a reload
	local reload = Card(inner, "Needs a reload")
	local reloadButton = kit.Button(reload, "Reload", 88, ns.Reload)
	reloadButton:SetPoint("TOPRIGHT", reload, "TOPRIGHT", -16, -4)
	ns.SecureReload(reloadButton)
	-- A line of a setting lights up under the mouse, and a click opens its row (Open). line.path, or line.entry of a recent change, names it.
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
		line.label = kit.Label(frame, "GameFontHighlight", "LEFT", inner - 32)
		line.label:SetPoint("LEFT", frame, "LEFT", 4, 0)
		Opens(frame, line)
		reloadLines[index] = line
	end

	-- Recent changes
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
		-- What the change was: the value before it to the value now.
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
				Home.Undo(line.entry)
				kit.Refresh()
			end
		end)
		undo:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
		-- Its tip in the strip names the value it puts back; the hover fill of kit.Button stays (HookScript on a frame of Flat UI's own).
		undo:HookScript("OnEnter", function()
			if line.entry then
				kit.Tip("Puts back: " .. ns.PanelTrust.ValueText(line.entry.item, line.entry.old))
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

	-- Modules
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
		-- The icon is in the colour of the text, fainter when the module is off.
		function tile.Paint()
			local r, g, b = Look.Colour(tile.live and "text" or "text-dim")
			tile.icon:SetVertexColor(r, g, b, tile.live and 0.9 or 0.45)
		end
		kit.Painted(tile.Paint)
		-- The name has two lines to the right edge. The state and the switch are under it.
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
		-- The recent changes
		local mine = Home.Log()
		local total = #mine
		local shownLines = view.all and total or math.min(total, SHOWN)
		more:SetShown(total > SHOWN)
		moreText:SetText(view.all and "Show fewer" or "Show all")
		empty:SetShown(total == 0)
		empty:ClearAllPoints()
		empty:SetPoint("TOPLEFT", recent, "TOPLEFT", 16, -(32 + (rowH - 14) / 2))
		for index = 1, math.max(shownLines, #lines) do
			if index <= shownLines then
				local line, entry = Line(index), mine[index]
				line.entry = entry
				line.label:SetText(entry.item.label or "")
				local Value = ns.PanelTrust.ValueText
				line.value:SetText(("%s to %s"):format(Value(entry.item, entry.old), Value(entry.item, entry.new)))
				line.crumb:SetText(Crumb(model, entry.item))
				line.frame:ClearAllPoints()
				line.frame:SetPoint("TOPLEFT", recent, "TOPLEFT", 16, -(32 + (index - 1) * rowH))
				line.frame:SetPoint("TOPRIGHT", recent, "TOPRIGHT", -16, -(32 + (index - 1) * rowH))
				line.frame:Show()
			elseif lines[index] then
				lines[index].entry = nil
				lines[index].frame:Hide()
			end
		end
		-- What needs a reload
		local needed = Home.ReloadLines()
		for index, line in ipairs(reloadLines) do
			local entry = needed[index]
			if index == #reloadLines and #needed > #reloadLines then
				line.label:SetText(("%d more"):format(#needed - #reloadLines + 1))
				line.path = nil
			else
				line.label:SetText(entry and ReloadText(entry) or "")
				line.path = entry and entry[3]
			end
			line.frame:SetShown(entry ~= nil)
		end
		-- The modules
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
