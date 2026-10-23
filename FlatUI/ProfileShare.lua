local ADDON_NAME, ns = ...

-- Profiles page, Share: a pasted profile text is read before it is imported (name, build, number of settings and positions, a warning when it was
-- made for another screen size), what to import is chosen, and a profile is exported by module. The rows are the widgets of ns.PanelKit and sit at
-- the end of the page. The functions of Core.lua that read and write the text are ns.ProfilePreview, ns.ImportProfile and ns.ExportProfile.

local Share = {}
ns.ProfileShare = Share

local state = { settings = true, positions = true, as = "new", name = "" }

local function Text(value)
	return type(value) == "string" and value or ""
end

-- The size of the screen in pixels, or 0 and 0.
local function Screen()
	if type(GetPhysicalScreenSize) == "function" then
		local ok, width, height = pcall(GetPhysicalScreenSize)
		if ok and type(width) == "number" and type(height) == "number" and not ns.IsSecret(width) and not ns.IsSecret(height)
			and width > 0 and width < 1e6 and height > 0 and height < 1e6 then
			return math.floor(width + 0.5), math.floor(height + 0.5)
		end
	end
	return 0, 0
end

-- The line under the name of a pasted profile.
function Share.Summary(preview)
	local parts = {}
	if preview.name ~= "" then
		parts[#parts + 1] = preview.name
	end
	if preview.version ~= "" then
		parts[#parts + 1] = "Flat UI " .. preview.version
	end
	parts[#parts + 1] = ("%d settings"):format(preview.settings)
	parts[#parts + 1] = ("%d positions"):format(preview.spots)
	return table.concat(parts, ", ")
end

-- The warning for a profile made on another screen size, or nil.
function Share.Warning(preview)
	local width, height = Screen()
	if preview.spots > 0 and preview.width > 0 and width > 0 and (preview.width ~= width or preview.height ~= height) then
		return ("Made for %d x %d. This screen is %d x %d. Check the positions after the import."):format(preview.width, preview.height, width, height)
	end
	return nil
end

-- A name for a new profile made of a pasted one: its own name, then with 2 to 9 after it, else Imported.
function Share.NewName(preview)
	-- Cut at 28 characters, not bytes: a continuation byte of UTF-8 belongs to the character before it.
	local base = preview.name ~= "" and preview.name:match("^" .. ("[^\128-\191][\128-\191]*"):rep(28)) or preview.name
	base = base ~= "" and base or "Imported"
	for number = 1, 9 do
		local candidate = number == 1 and base or ("%s %d"):format(base, number)
		if not ns.ProfileNameCheck or ns.ProfileNameCheck(candidate) then
			return candidate
		end
	end
	return "Imported"
end

-- The module keys and names the export can be limited to: the pages that are not under another page.
function Share.Modules()
	local list = {}
	for _, page in ipairs(type(ns.PAGES) == "table" and ns.PAGES or {}) do
		if not page.parent and type(page.key) == "string" and type(page.label) == "string" then
			list[#list + 1] = { key = page.key, label = page.label }
		end
	end
	return list
end

-- The set of modules an export can be limited to, with the saved prefix of every page under a chosen page added: Your buffs saves as ownbuffs.* and is
-- a page under Resource, so it goes with Resource.
function Share.Cover(picked)
	local pages = type(ns.PAGES) == "table" and ns.PAGES or {}
	local parentOf, top = {}, {}
	for _, page in ipairs(pages) do
		parentOf[page.key] = page.parent
		top[page.key] = not page.parent
	end
	local covered = {}
	for key, on in pairs(picked) do
		covered[key] = on
	end
	for _, page in ipairs(pages) do
		if page.parent then
			local root = page.key
			for _ = 1, 8 do
				root = parentOf[root] or root
			end
			local prefix = page.owner or page.key
			if picked[root] and not top[prefix] then
				covered[prefix] = true
			end
		end
	end
	return covered
end

-- Called with the paste field of Import profile: the preview and the rows under it follow its text.
function Share.Watch(field)
	state.field = field
	field:SetScript("OnTextChanged", function()
		if state.Refresh then
			state.Refresh()
		end
	end)
end

-- What the pasted text holds, or nil when the field is empty or the text is not a profile.
local function Preview()
	local text = Text(state.field and state.field:GetText())
	if text ~= state.seen then
		state.seen = text
		state.preview = nil
		if text:find("%S") and type(ns.ProfilePreview) == "function" then
			local ok, preview = pcall(ns.ProfilePreview, text)
			state.preview = ok and preview or nil
		end
		if state.preview then
			state.name = Share.NewName(state.preview)
			if state.nameField then
				state.nameField:SetText(state.name)
			end
		end
	end
	return state.preview
end

-- Imports the pasted text with what is chosen. False when the text has no preview, which leaves the paste field to the plain import.
function Share.Import(text)
	local preview = Preview()
	local kit = state.kit
	if not (preview and kit) then
		return false
	end
	if not (state.settings or state.positions) then
		kit.Say("Choose what to import.")
		return true
	end
	local opts = { settings = state.settings, spots = state.positions }
	local function Run()
		local ok, done, message = pcall(ns.ImportProfile, text, opts)
		if not ok then
			geterrorhandler()(done)
			kit.Say("That did not work.")
		else
			kit.Say(Text(message) ~= "" and message or (done and "Profile imported." or "That did not work."))
			if done then
				state.field:SetText("")
			end
		end
		kit.Refresh()
	end
	if state.as == "new" then
		opts.newName = Text(state.nameField and state.nameField:GetText() or state.name):match("^%s*(.-)%s*$")
		Run()
	else
		kit.Ask(('Replace "%s" with the pasted settings?'):format(Text(ns.Profile and ns.Profile())), Run)
	end
	return true
end

-- Adds the rows below y to the page of `child` and returns the y below the shown ones. `scroller` has the page height, `updates` gets a function that
-- reads the rows again. The rows that depend on a pasted text or an open list are shown and placed by Layout.
function Share.Build(kit, child, y, updates, scroller, paste)
	state = { settings = true, positions = true, as = "new", name = "", field = state.field, kit = kit, chosen = {}, listed = false }
	if state.field then
		Share.Watch(state.field)
	end
	local rows = {}

	-- A switch at the left of a row: the switch of the options pages, reading and writing through get and set.
	local function Switch(row, get, set)
		local draw = kit.Bool(row, { read = get, write = set })
		draw()
		updates[#updates + 1] = draw
	end

	local function Add(label, show)
		local row = kit.NewRow(child, y, label)
		row.frame:Hide()
		rows[#rows + 1] = { row = row, show = show }
		return row
	end

	local function Note(row)
		local note = kit.Dim(kit.Label(row.frame, "GameFontHighlightSmall", "LEFT", kit.ROW_W - kit.CONTROL))
		note:SetPoint("LEFT", row.frame, "LEFT", kit.CONTROL, 0)
		return note
	end

	-- Export by module: one row, and the Modules button opens the list of modules under the other rows.
	-- The paste row (Import profile), when given, moves under it so the import rows follow the paste field.
	local at = paste and y - kit.ROW or y
	local fixed = kit.NewRow(child, at, "Export by module")
	if paste then
		paste.Place(at + kit.ROW)
	end
	local out = kit.Field(fixed.frame, kit.FIELD, 0)
	out:SetPoint("LEFT", fixed.frame, "LEFT", kit.CONTROL, 0)
	fixed.Hover(out)
	local choose = kit.Button(fixed.frame, "Modules", kit.SMALL, function()
		state.listed = not state.listed
		kit.Refresh()
	end)
	choose:SetPoint("LEFT", fixed.frame, "LEFT", kit.CONTROL + kit.FIELD + 10, 0)
	fixed.Hover(choose)
	y = at + (paste and 2 or 1) * kit.ROW
	local base = y

	-- A pasted profile: what it is, and what to import.
	local function Pasted() return Preview() ~= nil end
	local summary = Note(Add("Pasted profile", Pasted))
	local warning = Note(Add("Screen", function()
		local preview = Preview()
		return preview ~= nil and Share.Warning(preview) ~= nil
	end))
	local settings = Add("Settings", Pasted)
	Switch(settings, function() return state.settings end, function(on) state.settings = on end)
	local settingsCount = Note(settings)
	settingsCount:SetPoint("LEFT", settings.frame, "LEFT", kit.CONTROL + 44, 0)
	local positions = Add("Frame positions", Pasted)
	Switch(positions, function() return state.positions end, function(on) state.positions = on end)
	local positionsCount = Note(positions)
	positionsCount:SetPoint("LEFT", positions.frame, "LEFT", kit.CONTROL + 44, 0)
	local into = Add("Import as", Pasted)
	local menu = kit.Dropdown(into, kit.FIELD, {
		lines = function()
			return { { "new", "New profile" }, { "replace", "Replace " .. Text(ns.Profile and ns.Profile()) } }
		end,
		selected = function() return state.as end,
		pick = function(id)
			state.as = id
			kit.Refresh()
		end,
	})
	menu.frame:SetPoint("LEFT", into.frame, "LEFT", kit.CONTROL, 0)
	local named = kit.Field(into.frame, kit.FIELD, 32)
	named:SetPoint("LEFT", into.frame, "LEFT", kit.CONTROL + kit.FIELD + 10, 0)
	into.Hover(named)
	state.nameField = named
	local go = Add("Import now", Pasted)
	local button = kit.Button(go.frame, "Import selected", 130, function()
		Share.Import(Text(state.field and state.field:GetText()))
	end, true)
	button:SetPoint("LEFT", go.frame, "LEFT", kit.CONTROL, 0)
	go.Hover(button)

	-- The modules an export can hold.
	local function Listed() return state.listed end
	local exportSpots = true
	Switch(Add("Frame positions", Listed), function() return exportSpots end, function(on) exportSpots = on end)
	for _, module in ipairs(Share.Modules()) do
		state.chosen[module.key] = true
		Switch(Add(module.label, Listed), function() return state.chosen[module.key] == true end, function(on) state.chosen[module.key] = on end)
	end
	local export = Add("Export chosen", Listed)
	local run = kit.Button(export.frame, "Export chosen", 130, function()
		local picked = {}
		for key, on in pairs(state.chosen) do
			if on then
				picked[key] = true
			end
		end
		local ok, text = pcall(ns.ExportProfile, { modules = Share.Cover(picked), spots = exportSpots })
		if ok and Text(text) ~= "" then
			out:SetText(text)
			out:SetFocus()
			out:HighlightText()
			kit.Say("Press Ctrl+C to copy.")
		else
			if not ok then
				geterrorhandler()(text)
			end
			kit.Say("That did not work.")
		end
	end)
	run:SetPoint("LEFT", export.frame, "LEFT", kit.CONTROL, 0)
	export.Hover(run)

	-- Shows the rows that apply and places them one under the other.
	local function Layout()
		local preview = Preview()
		if preview then
			summary:SetText(Share.Summary(preview))
			warning:SetText(Share.Warning(preview) or "")
			settingsCount:SetText(tostring(preview.settings))
			positionsCount:SetText(tostring(preview.spots))
			menu.SetText(state.as == "new" and "New profile" or "Replace " .. Text(ns.Profile and ns.Profile()))
			named:SetShown(state.as == "new")
		end
		local top = base
		for _, entry in ipairs(rows) do
			local on = entry.show()
			entry.row.frame:SetShown(on)
			if on then
				entry.row.Place(top)
				top = top + kit.ROW
			end
		end
		scroller.SetContent(top + kit.PAD)
		return top
	end
	state.Refresh = Layout
	updates[#updates + 1] = Layout
	return Layout()
end
