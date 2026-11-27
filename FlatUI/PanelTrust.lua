local ADDON_NAME, ns = ...

-- What a row says about itself in the options window: a dot and a reset button on a changed row, the reason on a row that is off, a tooltip beside
-- the control, and the count of changed settings on the tab. The tooltip of the reset button names the value it puts back (Trust.DefaultLine), in
-- the words Trust.ValueText gives a value, which Home's Recent changes and the reload notice (Reload.lua) use too; a click on it says in the strip
-- what it put back and that Ctrl+Z takes it back (Trust.ResetText), and its arrow takes the text colour under the mouse. The widgets are the ones of
-- ns.PanelKit.

local Trust = {}
ns.PanelTrust = Trust

local SWATCH = "|TInterface\\Buttons\\WHITE8X8:12:12:0:0:8:8:0:8:0:8:%d:%d:%d|t"

local TIP_W, TIP_PAD, TIP_DELAY = 280, 10, 0.35
local tip, token = nil, 0

-- True while a saved setting is not at its default.
function Trust.Changed(item)
	local kit = ns.PanelKit
	if not item.key or item.read or item.default == nil or item.kind == "list" or item.kind == "entries" or ns.RowLive(item) then
		return false
	end
	local ok, value = pcall(kit.Read, item)
	return ok and value ~= item.default
end

-- The settings of the page of an entry that are not at their default.
function Trust.Count(entry)
	local count = 0
	for _, item in ipairs(entry and entry.page or {}) do
		if Trust.Changed(item) then
			count = count + 1
		end
	end
	return count
end

-- The line the strip shows while no tip or message does; a click on it goes to each changed row in turn (Panel.lua, ui.NextChanged).
function Trust.Status(entry)
	local count = entry and not entry.home and not entry.profiles and Trust.Count(entry) or 0
	return count > 0 and ("%d changed on this tab. Click to go to each."):format(count) or ""
end

-- The question of Reset page, which asks only while something on the tab is changed.
function Trust.Question(entry, name)
	local count = Trust.Count(entry)
	return ("Reset %d setting%s on %s?"):format(count, count == 1 and "" or "s", name)
end

-- The line a row that is off shows: the setting it needs, with the value when the row needs one choice of a setting, or off when it needs a switch
-- off. The values a row lists are those of the setting it names itself, not of one further along. The name is in the accent.
function Trust.Reason(path, item)
	local def = ns.Def(path)
	local name = def and def.label or path
	local r, g, b = ns.PanelLook.Colour("accent")
	local line = ("Needs |cff%02x%02x%02x%s|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), name)
	local wanted = item and item.needsPath == path and item.needsIn or nil
	if def and type(wanted) == "table" and #wanted == 1 and type(wanted[1]) == "boolean" then
		return line .. (wanted[1] and " on." or " off.")
	end
	if def and type(wanted) == "table" and #wanted == 1 then
		local shown = wanted[1]
		for _, choice in ipairs(type(def.choices) == "table" and def.choices or {}) do
			if choice[1] == wanted[1] and type(choice[2]) == "string" then
				shown = choice[2]
			end
		end
		line = line .. " set to " .. tostring(shown)
	end
	return line .. "."
end

local function Tip()
	if tip then
		return tip
	end
	local kit = ns.PanelKit
	tip = kit.Frame(kit.Window())
	tip:SetFrameStrata("TOOLTIP")
	local outline = ns.Outline(tip, tip, true)
	kit.Painted(function()
		kit.Backing(outline, "tooltip", 0.96, "line-strong")
	end)
	tip.need = kit.Tint(kit.Label(tip, "GameFontHighlightSmall", "LEFT", TIP_W - 2 * TIP_PAD, true), "warn")
	tip.body = kit.Dim(kit.Label(tip, "GameFontHighlightSmall", "LEFT", TIP_W - 2 * TIP_PAD, true))
	tip:Hide()
	return tip
end

function Trust.Hide()
	token = token + 1
	if tip then
		tip:Hide()
	end
end

-- The words the tooltip shows now: the body, then the line of the setting it needs. Nil while it is hidden.
function Trust.Current()
	if tip and tip:IsShown() then
		return tip.body:GetText(), tip.need:GetText()
	end
end

local function Place(owner, body, need)
	local frame = Tip()
	frame.body:SetText(body or "")
	frame.need:SetText(need or "")
	frame.body:SetShown(body ~= nil and body ~= "")
	frame.need:SetShown(need ~= nil and need ~= "")
	local width = TIP_W
	local ok, natural = pcall(frame.body.GetStringWidth, frame.body)
	if ok and type(natural) == "number" and not ns.IsSecret(natural) and not need and natural > 0 then
		width = math.min(TIP_W, math.ceil(natural) + 2 * TIP_PAD)
	end
	local inner = width - 2 * TIP_PAD
	frame.body:SetWidth(inner)
	frame.need:SetWidth(inner)
	local high = TIP_PAD
	if need and need ~= "" then
		frame.need:ClearAllPoints()
		frame.need:SetPoint("TOPLEFT", frame, "TOPLEFT", TIP_PAD, -high)
		high = high + frame.need:GetStringHeight() + 4
	end
	frame.body:ClearAllPoints()
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", TIP_PAD, -high)
	if body and body ~= "" then
		high = high + frame.body:GetStringHeight()
	end
	frame:SetSize(width, high + TIP_PAD)
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", 0, 4)
	frame:Show()
end

-- Shows the tooltip above a control after a short wait: body in the dim text, need in the warning colour. Nothing shows for no words.
function Trust.Show(owner, body, need)
	Trust.Hide()
	if (not body or body == "") and (not need or need == "") then
		return
	end
	local mine = token
	local function Open()
		if token == mine and owner:IsShown() then
			Place(owner, body, need)
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(TIP_DELAY, Open)
	else
		Open()
	end
end

-- The text of a choice's value, or nil when the row lists no text for it.
local function ChoiceLabel(def, value)
	if value == nil then
		return nil
	end
	local ok, lines = pcall(ns.Choices, def)
	for _, line in ipairs(ok and type(lines) == "table" and lines or {}) do
		if type(line) == "table" and line[1] == value and type(line[2]) == "string" and line[2] ~= "" then
			return line[2]
		end
	end
	return nil
end

local function IsColour(value)
	return type(value) == "string" and value:find("^%x%x%x%x%x%x%x%x$") ~= nil
end

-- The words for a value of a row: On or Off, the text of a choice, a number with its unit ("300 ms"), a swatch and the code of a colour
-- ("#1E1E1E", with "at 80%" for a colour with alpha), else the value itself. A row with no kind, as Home's record keeps for a change made on
-- Home, is read as its setting's row in Config.lua (ns.Def).
function Trust.ValueText(item, value)
	local def = type(item) == "table" and item or {}
	if def.kind == nil and type(def.path) == "string" and type(ns.Def) == "function" then
		local found = ns.Def(def.path)
		def = type(found) == "table" and found or def
	end
	if type(value) == "boolean" then
		return value and "On" or "Off"
	end
	local choice = def.kind == "choice" and ChoiceLabel(def, value) or nil
	if choice then
		return choice
	end
	if def.kind == "colour" and IsColour(value) then
		local r, g, b = tonumber(value:sub(3, 4), 16), tonumber(value:sub(5, 6), 16), tonumber(value:sub(7, 8), 16)
		local text = ("%s #%s"):format(SWATCH:format(r, g, b), value:sub(3):upper())
		if def.alpha == true then
			text = text .. (" at %d%%"):format(math.floor(tonumber(value:sub(1, 2), 16) * 100 / 255 + 0.5))
		end
		return text
	end
	if ns.Finite(value) then
		return ("%g%s"):format(value, type(def.unit) == "string" and def.unit or "")
	end
	if type(value) == "string" and not ns.IsSecret(value) then
		return value
	end
	return value == nil and "None" or "changed"
end

-- The tooltip of a row's reset button: the default it puts back, as "Reset to default: On", "Reset to default: 300 ms" or "Reset to default: Soft
-- shade", and for a colour a swatch of it and its code, as "Reset to the default colour: #1E1E1E". Plain "Reset to default" for anything else.
function Trust.DefaultLine(item)
	local value = item.default
	if item.kind == "colour" and IsColour(value) then
		return "Reset to the default colour: " .. Trust.ValueText(item, value)
	end
	if (item.kind == "bool" and type(value) == "boolean") or (item.kind == "number" and ns.Finite(value))
		or (item.kind == "choice" and ChoiceLabel(item, value)) then
		return "Reset to default: " .. Trust.ValueText(item, value)
	end
	return "Reset to default"
end

-- What the strip says after the reset arrow: "Reset Border colour: back to #000000. Ctrl+Z puts it back.", or "back to its default" for a value
-- with no words of its own (the kinds Trust.DefaultLine names).
function Trust.ResetText(item)
	local value, words = item.default, nil
	if (item.kind == "colour" and IsColour(value)) or (item.kind == "bool" and type(value) == "boolean") or (item.kind == "number" and ns.Finite(value))
		or (item.kind == "choice" and ChoiceLabel(item, value)) then
		words = Trust.ValueText(item, value)
	end
	return ("Reset %s: back to %s. Ctrl+Z puts it back."):format(type(item.label) == "string" and item.label or "the setting",
		words and words ~= "changed" and words or "its default")
end

-- Gives a row its dot and reset button. Returns the function that sets them: it takes the unmet need of the row, or nil. A row of setup or of the tracker editor
-- reads and writes a value of its own, so it has no dot and no reset.
function Trust.Attach(row, item)
	local kit = ns.PanelKit
	local dot, reset
	if not item.read then
		dot = kit.Fill(row.frame, "OVERLAY")
		dot:SetSize(4, 4)
		dot:SetPoint("LEFT", row.frame, "LEFT", -8, 0)
		kit.Painted(function()
			kit.Solid(dot, "accent")
		end)
		dot:Hide()
	end
	return function(unmet)
		row.need = unmet and Trust.Reason(unmet, item) or nil
		if not dot then
			return
		end
		local changed = Trust.Changed(item)
		dot:SetShown(changed)
		if changed and not reset then
			-- The strip says what the arrow put back, as Reset page and every Undo do; the write goes into Home's record, so Ctrl+Z takes it back.
			reset = kit.Button(row.frame, "", 16, function()
				if row.active then
					Trust.Hide()
					kit.Write(item, item.default)
					kit.Refresh()
					kit.Say(Trust.ResetText(item))
				end
			end)
			reset:SetHeight(16)
			reset:SetPoint("LEFT", row.frame, "LEFT", kit.CONTROL - 24, 0)
			local glyph = kit.Fill(reset, "OVERLAY")
			glyph:SetSize(10, 10)
			glyph:SetPoint("CENTER", reset, "CENTER", 0, 0)
			ns.PanelNav.Cell(glyph, "reset")
			-- The glyph takes the text colour under the mouse, as the cross of the Search box does.
			local lit = false
			local function Paint()
				glyph:SetVertexColor(ns.PanelLook.Colour(lit and "text" or "text-dim"))
			end
			kit.Painted(Paint)
			-- row.Hover keeps the fill of the button and then shows the tooltip.
			row.Hover(reset, function()
				lit = true
				Paint()
				Trust.Show(reset, Trust.DefaultLine(item))
			end, function()
				lit = false
				Paint()
			end)
		end
		if reset then
			reset:SetShown(changed)
		end
	end
end
