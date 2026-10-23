local ADDON_NAME, ns = ...

-- What a row says about itself in the options window: a dot and a reset button on a changed row, the reason on a row that is off, a tooltip beside
-- the control, and the count of changed settings on the tab. The widgets are the ones of ns.PanelKit.

local Trust = {}
ns.PanelTrust = Trust

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

-- The line the strip shows while no tip or message does.
function Trust.Status(entry)
	local count = entry and not entry.home and not entry.profiles and Trust.Count(entry) or 0
	return count > 0 and ("%d changed on this tab"):format(count) or ""
end

-- The question of Reset page.
function Trust.Question(entry, name)
	local count = Trust.Count(entry)
	if count == 0 then
		return "Reset every setting on this page?"
	end
	return ("Reset %d setting%s on %s?"):format(count, count == 1 and "" or "s", name)
end

-- The line a row that is off shows: the setting it needs, with the value when the row needs one choice of a setting. The name is in the accent.
function Trust.Reason(path, item)
	local def = ns.Def(path)
	local name = def and def.label or path
	local r, g, b = ns.PanelLook.Colour("accent")
	local line = ("Needs |cff%02x%02x%02x%s|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), name)
	local wanted = item and item.needsIn
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
			reset = kit.Button(row.frame, "", 16, function()
				if row.active then
					Trust.Hide()
					kit.Write(item, item.default)
					kit.Refresh()
				end
			end)
			reset:SetHeight(16)
			reset:SetPoint("LEFT", row.frame, "LEFT", kit.CONTROL - 24, 0)
			local glyph = kit.Fill(reset, "OVERLAY")
			glyph:SetSize(10, 10)
			glyph:SetPoint("CENTER", reset, "CENTER", 0, 0)
			ns.PanelNav.Cell(glyph, "reset")
			kit.Painted(function()
				glyph:SetVertexColor(ns.PanelLook.Colour("text-dim"))
			end)
			-- Hover runs the fill of the button and then shows the tooltip.
			local enter, leave = reset:GetScript("OnEnter"), reset:GetScript("OnLeave")
			row.Hover(reset, function()
				if enter then
					enter(reset)
				end
				Trust.Show(reset, "Reset to default")
			end, function()
				if leave then
					leave(reset)
				end
			end)
		end
		if reset then
			reset:SetShown(changed)
		end
	end
end
