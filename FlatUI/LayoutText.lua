local _, ns = ...

-- The Flat UI layout as Edit Mode import text, for a player whose game does not keep the layout this addon writes. A list row on the Movers
-- page opens a small window holding the text; the player copies it, opens Edit Mode, chooses Import in the layout list and pastes it.
-- Nothing is saved or activated on this path: the layout table is read (ns.LayoutSpots.FlatEntry) and handed to
-- C_EditMode.ConvertLayoutInfoToString, which only makes the text (EditModeManagerDocumentation.lua:11-23, its argument is
-- AllowedWhenUntainted, so an addon-built table is accepted and the answer is a plain string). The check is the call itself: where the game
-- returns no string, a line says so and no window opens. The same call, with the text copied the same way, is EllesmereUI's profile export
-- (EllesmereUI/EllesmereUI_Profiles.lua:4660-4667, which selects the text on a short timer after setting it).

local TITLE = "Flat UI layout"
local HELP = "Copy this, open Edit Mode, choose Import in the layout list, paste it and name it Flat UI."

-- The window, in one table: frame, scroll, edit. Built once, out of combat.
local win = nil

local function Say(text)
	print(text)
end

function ns.LayoutTextLines()
	return { { 1, "Show as import text" } }
end

local function Select(edit)
	edit:SetFocus()
	edit:HighlightText()
end

local function Build()
	local ok, frame = pcall(CreateFrame, "Frame", "FlatUILayoutText", UIParent)
	if not ok or type(frame) ~= "table" then
		return nil
	end
	ns.Own[frame] = true
	frame:SetSize(460, 220)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	local outline = ns.Outline(frame, frame, true)
	ns.SetOutlineFill(outline, 0.09, 0.09, 0.09, 0.95)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
	title:SetText(TITLE)
	local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	help:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
	help:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
	help:SetJustifyH("LEFT")
	help:SetText(HELP)
	local okScroll, scroll = pcall(CreateFrame, "ScrollFrame", nil, frame)
	local okEdit, edit = pcall(CreateFrame, "EditBox", nil, scroll)
	local okButton, button = pcall(CreateFrame, "Frame", nil, frame)
	if not okScroll or not okEdit or not okButton or type(scroll) ~= "table" or type(edit) ~= "table" or type(button) ~= "table" then
		return nil
	end
	ns.Own[scroll] = true
	ns.Own[edit] = true
	ns.Own[button] = true
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -62)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 40)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject("ChatFontNormal")
	edit:SetWidth(430)
	scroll:SetScrollChild(edit)
	edit:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	button:SetSize(64, 20)
	button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
	local face = ns.Outline(button, button, true)
	ns.SetOutlineFill(face, 0.2, 0.2, 0.2, 1)
	local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetText("Close")
	button:EnableMouse(true)
	button:SetScript("OnMouseUp", function(_, which)
		if which == "LeftButton" then
			frame:Hide()
		end
	end)
	if type(UISpecialFrames) == "table" then
		UISpecialFrames[#UISpecialFrames + 1] = "FlatUILayoutText"
	end
	frame:Hide()
	return { frame = frame, scroll = scroll, edit = edit, button = button }
end

local function Open(text)
	if not win then
		win = Build()
	end
	if not win then
		Say("The layout text window could not be made.")
		return
	end
	win.edit:SetText(text)
	win.frame:Show()
	if C_Timer and C_Timer.After then
		C_Timer.After(0.05, function()
			Select(win.edit)
		end)
	else
		Select(win.edit)
	end
end

function ns.LayoutTextShow()
	if InCombatLockdown() then
		Say("The layout text is made after combat.")
		return
	end
	if ns.EditModeOpen() then
		Say("Close Edit Mode first.")
		return
	end
	if not C_EditMode or type(C_EditMode.ConvertLayoutInfoToString) ~= "function" then
		Say("Edit Mode cannot make import text here.")
		return
	end
	local spots = ns.LayoutSpots
	local entry = nil
	if type(spots) == "table" and type(spots.FlatEntry) == "function" then
		entry = spots.FlatEntry()
	end
	if entry == nil then
		Say("No layout to show.")
		return
	end
	local ok, text = pcall(C_EditMode.ConvertLayoutInfoToString, entry)
	if not ok or text == nil or ns.IsSecret(text) or type(text) ~= "string" then
		Say("The game would not make import text.")
		return
	end
	Open(text)
end

function ns.LayoutTextPick(id)
	if id == 1 then
		ns.LayoutTextShow()
	end
end
