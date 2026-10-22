local ADDON_NAME, ns = ...

-- The sidebar of the options window: four fixed rows, then six groups with the 22 modules, each with its icon. A group folds on a click and the
-- fold is kept per account. A module that is off shows the Off chip. Also the switch widget, and the header of a page that has the module
-- switch. Panel.lua hands the drawing of these to this file; the widgets are the ones of ns.PanelKit.

local Nav = {}
ns.PanelNav = Nav

local kit = ns.PanelKit
local Look = ns.PanelLook
local ATLAS = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Panel.tga"
local PAD = kit.PAD

-- The cell of each icon in FlatUI/Media/Panel.tga (8 columns of 64 by 64, tools/make_panel_icons.py draws them).
local CELLS = { general = 0, fonts = 1, unitframes = 2, nameplates = 3, resource = 4, castbars = 5, swing = 6, actionbars = 7, barblock = 8, blocks = 9,
	cooldowns = 10, trackers = 11, defensives = 12, partycd = 13, enemycd = 14, combattext = 15, hud = 16, windows = 17, chat = 18, movers = 19, fade = 20,
	tooltip = 21, home = 22, setup = 23, profiles = 24, chevron = 25, check = 26, search = 27, close = 28, reset = 29, eye = 30, more = 31 }
Nav.CELLS = CELLS

-- The groups, and the page key of each module in them.
Nav.GROUPS = {
	{ label = "Look", "general", "fonts" },
	{ label = "Frames", "unitframes", "nameplates", "resource", "castbars", "swing" },
	{ label = "Action bars", "actionbars", "barblock", "blocks" },
	{ label = "Combat", "cooldowns", "trackers", "defensives", "partycd", "enemycd", "combattext" },
	{ label = "Interface", "hud", "windows", "chat" },
	{ label = "Layout", "movers", "fade", "tooltip" },
}

local FIXED = { { id = "home", label = "Home", icon = "home" }, { id = "setup", label = "Flat UI setup", icon = "setup" },
	{ id = "profiles", label = "Profiles", icon = "profiles" }, { id = "move", label = "Move frames", icon = "movers" } }

local ROW_H, GROUP_H, CHILD_H, SECTION_H = 28, 20, 24, 18

-- Puts a cell of the atlas on a texture, turned over when flip is set. White line art, tinted with SetVertexColor.
function Nav.Cell(texture, name)
	local cell = CELLS[name] or CELLS.more
	local column, row = cell % 8, math.floor(cell / 8)
	texture:SetTexture(ATLAS)
	texture:SetTexCoord(column / 8, (column + 1) / 8, row / 4, (row + 1) / 4)
end

-- Pages -----------------------------------------------------------------------------------------------

-- The page a page is a tab of, or the page itself.
function Nav.Top(model, entry)
	for _ = 1, 8 do
		local up = entry and entry.parent and entry.parent ~= entry.key and model.byKey[entry.parent]
		if not up then
			break
		end
		entry = up
	end
	return entry
end

-- The pages under a module, in the order of the model.
function Nav.Children(model, top)
	local list = {}
	for _, entry in ipairs(model.pages) do
		if entry ~= top and Nav.Top(model, entry) == top then
			list[#list + 1] = entry
		end
	end
	return list
end

-- The groups that have a page: { label, entries }. A page that no group names, with the pages that are under it, goes into a last group Other,
-- so every page is reachable.
function Nav.Groups(model)
	local groups, placed = {}, {}
	for _, group in ipairs(Nav.GROUPS) do
		local list = {}
		for _, key in ipairs(group) do
			local entry = model.byKey[key]
			if entry then
				list[#list + 1] = entry
				placed[entry] = true
			end
		end
		if #list > 0 then
			groups[#groups + 1] = { label = group.label, entries = list }
		end
	end
	for _, entry in ipairs(model.pages) do
		local top = Nav.Top(model, entry)
		if top ~= entry and placed[top] then
			placed[entry] = true
		end
	end
	local rest = {}
	for pass = 1, 2 do
		for _, entry in ipairs(model.pages) do
			if not placed[entry] and (pass == 2 or Nav.Top(model, entry) == entry) then
				rest[#rest + 1] = entry
				placed[entry] = true
				for _, other in ipairs(model.pages) do
					if not placed[other] and Nav.Top(model, other) == entry then
						placed[other] = true
					end
				end
			end
		end
	end
	if #rest > 0 then
		groups[#groups + 1] = { label = "Other", entries = rest }
	end
	return groups
end

-- False while the module of a page is switched off. A page without a switch of its own is on.
function Nav.IsOn(entry)
	local item = entry and entry.switchItem
	return item == nil or ns.Get(item.path) ~= false
end

-- The group of a page, by the label of the group.
function Nav.GroupOf(model, entry)
	local top = Nav.Top(model, entry)
	for _, group in ipairs(Nav.Groups(model)) do
		for _, member in ipairs(group.entries) do
			if member == top then
				return group.label
			end
		end
	end
	return nil
end

-- The switch --------------------------------------------------------------------------------------------

-- A switch 32 by 16: the track in the accent while it is on, and the knob at the end. onClick runs on a click.
function Nav.Switch(parent, onClick)
	local frame = kit.Frame(parent)
	frame:SetSize(32, 16)
	local track = kit.Fill(frame, "BACKGROUND")
	track:SetAllPoints(frame)
	local knob = kit.Fill(frame, "ARTWORK")
	knob:SetSize(12, 12)
	local object = { frame = frame, on = false }
	local function Paint()
		Look.Solid(track, object.on and "accent" or "line")
		Look.Solid(knob, object.on and "on-accent" or "text-dim")
	end
	kit.Painted(Paint)
	function object.Set(on)
		on = on == true
		if object.placed == nil or object.on ~= on then
			object.on, object.placed = on, true
			knob:ClearAllPoints()
			knob:SetPoint(on and "RIGHT" or "LEFT", frame, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
			Paint()
		end
	end
	kit.Clickable(frame, onClick)
	object.Set(false)
	return object
end

-- The sidebar -------------------------------------------------------------------------------------------

-- host: Model() the model of the pages, Current() the page that shows (nil while a search shows), Show(entry), Setup(), Movers(), Sections(entry) the
-- list { name, number } of the open page, Scroll(entry, number), and height of the column.
function Nav.Sidebar(left, host)
	local side, pool = {}, {}
	local scroller = kit.Scroller(left, Look.SideWidth() - 1, host.height)
	scroller.frame:SetPoint("TOPLEFT", left, "TOPLEFT", 0, 0)
	side.scroller = scroller

	local function Paint(b)
		if b.kind == "divider" then
			b.fill:Show()
			Look.Solid(b.fill, "line")
			return
		end
		local lit = b.selected == true or (b.hover == true and b.onClick ~= nil and b.kind ~= "group")
		b.fill:SetShown(lit)
		if lit then
			Look.Solid(b.fill, b.selected and "raised" or "hover")
		end
		b.mark:SetShown(b.selected == true)
		b.mark:SetColorTexture(kit.Accent())
		local token = "text-dim"
		if b.kind == "group" then
			token = b.hover and "text-dim" or "text-faint"
		elseif lit and b.kind ~= "section" then
			token = "text"
		end
		kit.Tint(b.text, token)
		local r, g, blue, alpha
		if b.selected then
			r, g, blue = kit.Accent()
			alpha = 1
		else
			r, g, blue = Look.Colour(b.hover and "text" or "text-dim")
			alpha = b.hover and 1 or 0.6
		end
		if b.off and b.rail then
			alpha = alpha * 0.4
		end
		b.icon:SetVertexColor(r, g, blue, alpha)
		Look.Solid(b.chip, "line")
		kit.Tint(b.chipText, "text-faint")
	end

	-- The chip of a row: Off for a module that is off, After combat for Move frames in a fight.
	local function Chip(b)
		local label = b.status and b.status() or nil
		b.off = label == "Off"
		local show = label ~= nil and not b.rail
		b.chip:SetShown(show)
		b.chipText:SetShown(show)
		if show then
			b.chipText:SetText(label)
			b.chip:SetWidth(label == "Off" and 28 or 76)
			b.chipText:SetWidth(label == "Off" and 28 or 76)
		end
		-- The name has the row to the chip, or to the edge when there is none.
		if b.textW then
			b.text:SetWidth(show and math.max(20, b.textW - (label == "Off" and 36 or 84)) or b.textW)
		end
		Paint(b)
	end

	local function Button(index)
		if pool[index] then
			return pool[index]
		end
		local frame = kit.Frame(scroller.child)
		local b = { frame = frame }
		b.fill = kit.Fill(frame, "BACKGROUND")
		b.fill:SetAllPoints(frame)
		b.mark = kit.Fill(frame, "ARTWORK")
		b.mark:SetWidth(2)
		b.mark:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		b.mark:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		b.icon = kit.Fill(frame, "ARTWORK")
		b.text = kit.Label(frame, "GameFontHighlight", "LEFT")
		b.chip = kit.Fill(frame, "ARTWORK")
		b.chip:SetHeight(14)
		b.chip:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
		b.chipText = kit.Label(frame, "GameFontHighlightSmall", "CENTER")
		b.chipText:SetPoint("CENTER", b.chip, "CENTER", 0, 0)
		kit.Painted(function()
			Paint(b)
		end)
		frame:SetScript("OnEnter", function()
			b.hover = true
			Paint(b)
			if b.rail and b.label then
				kit.Tip(b.label)
			end
		end)
		frame:SetScript("OnLeave", function()
			b.hover = false
			Paint(b)
			if b.rail then
				kit.Tip("")
			end
		end)
		kit.Clickable(frame, function()
			if b.onClick then
				b.onClick()
			end
		end)
		pool[index] = b
		return b
	end

	function side.Layout()
		local width, mode = Look.SideWidth(), Look.Get("sidebar")
		local rail, plain = mode == "rail", mode == "names"
		local model, current = host.Model(), host.Current()
		scroller.Resize(width - 1, host.height)
		local y, index, selectedAt = 12, 0, nil
		local function Put(kind, text, spec)
			index = index + 1
			local b = Button(index)
			b.kind, b.label, b.selected, b.onClick, b.status, b.rail, b.used = kind, text, spec.selected, spec.onClick, spec.status, rail, true
			local narrow = kind == "divider"
			local rowW = narrow and (rail and 24 or width - 2 * PAD) or width - 16
			b.frame:SetSize(rowW, spec.h)
			b.frame:ClearAllPoints()
			b.frame:SetPoint("TOPLEFT", scroller.child, "TOPLEFT", narrow and (width - rowW) / 2 or 8, -y)
			local textX = 0
			b.icon:ClearAllPoints()
			b.icon:SetRotation(0)
			b.icon:Hide()
			if kind == "group" then
				Nav.Cell(b.icon, "chevron")
				-- Down when open, right when folded (the AddOn list turns its arrow the same way: AddonList.lua:920-921).
				b.icon:SetRotation(spec.folded and math.pi / 2 or 0)
				b.icon:SetSize(12, 12)
				b.icon:SetPoint("RIGHT", b.frame, "RIGHT", -8, 0)
				b.icon:Show()
				textX = 8
			elseif spec.icon and not plain then
				Nav.Cell(b.icon, spec.icon)
				b.icon:SetSize(16, 16)
				b.icon:SetPoint(rail and "CENTER" or "LEFT", b.frame, rail and "CENTER" or "LEFT", rail and 0 or 8, 0)
				b.icon:Show()
				textX = rail and 0 or 32
			else
				textX = 12 + (spec.indent or 0)
			end
			b.text:ClearAllPoints()
			b.text:SetShown(not narrow and not rail)
			b.textW = math.max(20, rowW - textX - 8)
			if not narrow and not rail then
				b.text:SetPoint("LEFT", b.frame, "LEFT", textX, 0)
				b.text:SetWidth(b.textW)
				b.text:SetFontObject(Look.FontFor((kind == "group" or kind == "section") and "GameFontHighlightSmall" or "GameFontHighlight"))
				b.text:SetText(text)
			end
			b.mark:SetShown(false)
			Chip(b)
			b.frame:Show()
			if spec.selected then
				selectedAt = y
			end
			y = y + spec.h + (spec.after or 0)
			return b
		end
		for _, fixed in ipairs(FIXED) do
			local id = fixed.id
			Put("fixed", fixed.label, {
				h = ROW_H, icon = fixed.icon,
				selected = (id == "home" and current == model.home) or (id == "profiles" and current == model.profiles),
				onClick = function()
					if id == "setup" then
						host.Setup()
					elseif id == "move" then
						host.Movers()
					else
						host.Show(id == "home" and model.home or model.profiles)
					end
				end,
				status = id == "move" and function()
					return InCombatLockdown() and "After combat" or nil
				end or nil,
			})
		end
		y = y + 6
		Put("divider", "", { h = 1, after = 9 })
		for _, group in ipairs(Nav.Groups(model)) do
			local folded = not rail and Look.Folded(group.label)
			if rail then
				Put("divider", group.label, { h = 1, after = 9 })
			else
				Put("group", group.label, { h = GROUP_H, folded = folded, onClick = function()
					Look.Fold(group.label, not folded)
					side.Layout()
				end })
			end
			if not folded then
				for _, entry in ipairs(group.entries) do
					local children = Nav.Top(model, current) == entry and Nav.Children(model, entry) or {}
					local function Under(page, depth)
						if current == page and not rail then
							for _, section in ipairs(host.Sections(page)) do
								Put("section", section.name, { h = SECTION_H, indent = depth, onClick = function()
									host.Scroll(page, section.number)
								end })
							end
						end
					end
					Put("module", entry.label, {
						h = ROW_H, icon = CELLS[entry.key] and entry.key or "more", selected = current == entry,
						onClick = function()
							host.Show(entry)
						end,
						status = function()
							return not Nav.IsOn(entry) and "Off" or nil
						end,
					})
					Under(entry, 32)
					for _, child in ipairs(children) do
						Put("child", child.label, { h = CHILD_H, indent = 32, icon = rail and "more" or nil, selected = current == child, onClick = function()
							host.Show(child)
						end })
						Under(child, 44)
					end
				end
			end
			y = y + 8
		end
		for hidden = index + 1, #pool do
			pool[hidden].frame:Hide()
			pool[hidden].used = false
		end
		scroller.SetContent(y + 8)
		if selectedAt and (selectedAt < scroller.offset or selectedAt + ROW_H > scroller.offset + scroller.height) then
			scroller.Scroll(math.max(0, selectedAt - 60))
		end
	end

	-- The chips follow the state of the modules and of the fight.
	function side.Update()
		for _, b in ipairs(pool) do
			if b.used then
				Chip(b)
			end
		end
	end

	-- Opens the group of a page.
	function side.Reveal(entry)
		local label = Nav.GroupOf(host.Model(), entry)
		if label and Look.Folded(label) then
			Look.Fold(label, false)
		end
	end
	return side
end

-- The header -----------------------------------------------------------------------------------------------

-- The line under the title of a page and, for a module that has one, its switch with the label of the setting. host.Toggle(item) flips the setting.
function Nav.Header(right, host)
	local head = {}
	local sub = kit.Dim(kit.Label(right, "GameFontHighlightSmall", "LEFT", 520))
	sub:SetPoint("TOPLEFT", right, "TOPLEFT", PAD, -42)
	head.sub = sub
	local box = kit.Frame(right)
	box:SetSize(360, 24)
	box:SetPoint("TOPRIGHT", right, "TOPRIGHT", -PAD, -18)
	local label = kit.Label(box, "GameFontHighlight", "RIGHT", 310)
	local switch = Nav.Switch(box, function()
		if head.item then
			host.Toggle(head.item)
		end
	end)
	switch.frame:SetPoint("RIGHT", box, "RIGHT", 0, 0)
	label:SetPoint("RIGHT", switch.frame, "LEFT", -10, 0)
	switch.frame:SetScript("OnEnter", function()
		if head.item then
			kit.Tip(head.item.tip)
		end
	end)
	switch.frame:SetScript("OnLeave", function()
		kit.Tip("")
	end)
	head.switch = switch
	-- The page shown, and the words under its title. A page with no switch of its own shows none.
	function head.Set(entry, text)
		head.item = entry and entry.switchItem or nil
		sub:SetText(text or "")
		box:SetShown(head.item ~= nil)
		if head.item then
			label:SetText(head.item.label)
			switch.Set(ns.Get(head.item.path) == true)
		end
	end
	function head.Update()
		if head.item then
			switch.Set(ns.Get(head.item.path) == true)
		end
	end
	return head
end
