local _, ns = ...

-- The squares beside the trinket slots of the Character window (0.5.36): the part "slot buttons" of the trinkets module, while Buttons by the
-- trinket slots is on (trinkets.slotButtons). Two buttons of Flat UI's own, without names, made on UIParent (CreateFrame, WL/apis.yaml:35213),
-- 14 by 14 in the window's units, each hung right of its slot, 3 clear of it (SetPoint on its own frame with the slot as the frame it hangs from):
-- CharacterTrinket0Slot for the top slot and CharacterTrinket1Slot for the bottom one, 37 by 37 slots of the right column
-- (Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:850-859; Blizzard_ItemButton/ItemButtonTemplate.xml:15), which hangs 20 in from the right edge
-- of the left pane (PaperDollFrame.xml:820-822), so 3 and 14 fit. The left side of a slot is the game's: its flyout button (16 by 32, its right at
-- the slot's left less 5) and its socket display lie there (Camelot/PaperDollFrame.lua:1977-1988; PaperDollFrame.xml:141-151;
-- EquipmentFlyout.xml:28-36). Show thorns hangs under the second trinket slot, not beside it (CharacterThorns.lua:544-545).
-- They are never parented to the Character window and write nothing on it or on the slots: of CharacterFrame and the slots they read only whether
-- they are visible (IsVisible, so they hide with the slots on the Reputation and Skills tabs; IsShown for the window), the slot's scale
-- (GetEffectiveScale; where a slot is they never read, as each hangs from its slot with SetPoint), the window's strata (GetFrameStrata) and
-- whether the game protects them (IsProtected). Each takes the slot's scale against UIParent's (SetScale on its own frame, as GearButton.lua does,
-- GearButton.lua:161-178, 506-511), and lies one strata above the window's at a level of its own (GearButton.lua:553-577), so the window, which
-- the game raises when clicked, never covers it. While the game protects the window or the slot in a fight, only its alpha changes until the
-- fight's end (ns.OutOfCombat), as GearButton.lua's Blocked (GearButton.lua:120-133).
-- The driver is GearButton.lua's (GearButton.lua:611-722): a frame whose OnUpdate looks four times a second while the buttons are wanted (the module
-- runs, the part is not stopped and the row is on), started at once by ShowUIPanel and HideUIPanel, which it follows (ns.FollowGlobal,
-- hooksecurefunc; several followers of a name are fine, Core.lua's FollowOnce), and by ns.TrinketButtonsChanged (the row's changed, and each refresh
-- of the module, TrinketQueue.lua). It registers no event.
-- The look is the Windows page's: Button and slot colour, a thin border (ns.Outline, SetOutlineArea "windows"), the Highlight colour under the
-- cursor (alpha HOVER), and a dot of 6 by 6 in the middle that says the state of its slot (TrinketQueue.lua's Q.Tone): grey while the slot's Auto
-- queue is off, the Highlight colour while it is on with nothing to wait for, amber while a swap waits for a fight, a cast, the cursor, busy bags
-- or a delay (and in a fight whenever Auto queue is on), red while the queue is paused, the slot is held or stopped, or the game refused a trinket.
-- The colour is never all that says it: the tooltip says it in words.
-- Clicks: a left click opens the Trinket queue window on that slot, shows it there while the window shows the other slot, and closes it while it
-- shows this one (ns.TrinketWindowToggle, TrinketQueueWindow.lua); a Shift-click is Queue now for that slot (Q.Now, as the window's Queue now
-- button, with one line in chat, 0.5.37), which clears a red square (held, held empty, refused); a right click turns the slot's Auto queue on or
-- off (Q.SetAuto), a Shift-right click pauses or resumes every swap (Q.SetPaused); a trinket dropped on it (OnReceiveDrag), or clicked on it from
-- the cursor, goes in that slot's list (Q.Add), and one lifted from a bag or a worn slot goes back there with ClearCursor, as GearButton.lua's
-- Compare (GearButton.lua:300-356).
-- Its tooltip is GameTooltip (SetOwner, AddLine, Show, and Hide only while IsOwned says the button owns it), never in a fight (GearButton.lua:285-298).
-- While the cursor is on a button (over, from OnEnter to OnLeave or OnHide), each click and each look of the driver out of a fight says the
-- tooltip again as soon as its words changed (0.5.37): a click's change shows at once, and a cooldown or the next trinket's time counts down.
-- Everything runs as the part "slot buttons" (ns.EachPart, a count of its own first), so three faults stop the buttons alone with a line for
-- /flatui status, and they hide then. Every frame, texture and font string here is Flat UI's own. There is no movers entry: the buttons belong to
-- their slots, as the item levels on the slots have none, and the slots never move.

local KEY, PART, ROW = "trinkets", "slot buttons", "trinkets.slotButtons"
-- The slots of each list, the button's side and its gap from the slot, the dot's side, the alpha of the light under the cursor.
local SLOTS = { top = "CharacterTrinket0Slot", bottom = "CharacterTrinket1Slot" }
local ORDER = { "top", "bottom" }
local SIDE, GAP, DOT, HOVER = 14, 3, 6, 0.18
-- The stratas from the lowest, the one above the window's is the buttons' (never TOOLTIP); their level in it; how often the driver looks.
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG" }
local LEVEL, EVERY = 20, 0.25
local DIM, PLAIN = { 0.66, 0.68, 0.62 }, { 1, 1, 1 }
local TONES = { off = { 0.45, 0.45, 0.45 }, wait = { 1, 0.67, 0.2 }, halt = { 0.9, 0.3, 0.3 } }
local T = {
	TITLE = { top = "Top trinket queue", bottom = "Bottom trinket queue" },
	NEXT = "Next: %s in %s",
	PAUSED = "Pause all is on: no trinket is swapped.",
	TIPS = { "Click: the queue window.", "Shift-click: Queue now for this slot.", "Right-click: turn this slot's queue on or off.",
		"Shift-right-click: pause or resume every swap.", "Drop a trinket here to add it to this list." },
	NOW = "Flat UI: the %s trinket queue looks again now.",
	OFF = "Flat UI: the trinket queue's swaps are off. /flatui status says why.",
	REPORT = "Flat UI, Trinket queue buttons, %s: %s",
}

-- The buttons by slot ({ button, dot, hover, outline, anchored, scale, strata, level, tone, over, said: the words of the tooltip it showed });
-- the driver and its clock; whether the buttons are wanted and the window shows at the last look; whether a change waits for the end of a
-- fight; the look painted.
local B = { top = {}, bottom = {}, driver = nil, clock = 0, wanted = false, shown = false, waiting = false, look = nil, runs = 0, faults = {} }

local Start

local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

local function Fn(source, name)
	if type(source) ~= "table" or IsSecret(source) then
		return nil
	end
	local fn = source[name]
	return type(fn) == "function" and fn or nil
end

local function Q()
	local q = ns.TrinketQueue
	return type(q) == "table" and q or nil
end

local function Report(what, err)
	if B.faults[what] then
		return
	end
	B.faults[what] = true
	local handler = type(geterrorhandler) == "function" and geterrorhandler() or nil
	if type(handler) == "function" then
		pcall(handler, T.REPORT:format(tostring(what), tostring(err)))
	end
end

local function Step(_, fn, ...)
	return fn(...)
end

-- Runs fn as this part, with a count of its own first: true when it ran without a fault.
local function Run(fn, ...)
	B.runs = B.runs + 1
	local ok, err = ns.EachPart(KEY, PART, Step, B.runs, fn, ...)
	if not ok and err ~= nil then
		Report(PART, err)
	end
	return ok == true
end

local function Wanted()
	return type(ns.modules) == "table" and ns.modules[KEY] ~= nil and ns.ModuleOn(KEY) and not ns.PartStopped(KEY, PART)
		and ns.Get(ROW) == true and Q() ~= nil
end

local function Fighting()
	local ok, fighting = pcall(InCombatLockdown)
	return not ok or IsSecret(fighting) or fighting == true
end

-- True when the game would refuse a change to this frame now: in a fight, one it protects, or one that will not say.
local function Blocked(frame)
	if not Fighting() then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or IsSecret(protected) or protected == true
end

-- A frame of the game by its name, once the game has made it, while addons may read it.
local function Game(name)
	local frame = _G[name]
	if type(frame) ~= "table" or IsSecret(frame) or ns.Forbidden(frame) then
		return nil
	end
	return frame
end

local function Answer(frame, method)
	local ok, answer = pcall(frame[method], frame)
	return ok and not IsSecret(answer) and answer == true
end

-- Units of UIParent for each unit of a frame, to a thousandth, or nil.
local function Scale(frame)
	local ok, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (ok and okBase and Finite(scale) and Finite(base) and scale > 0 and base > 0) then
		return nil
	end
	return math.floor(scale / base * 1000 + 0.5) / 1000
end

-- Looks -----------------------------------------------------------------------------------------------------------------------------------------

local function RGB(path, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, path)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

-- What the look is made of now, so a change of one of those rows paints the buttons again.
local function Look()
	local pr, pg, pb = RGB("windows.panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	return ("%.3f%.3f%.3f%.3f%.3f%.3f"):format(pr, pg, pb, ar, ag, ab)
end

local function Paint(b)
	local pr, pg, pb = RGB("windows.panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	ns.SetOutlineFill(b.outline, pr, pg, pb, 1)
	ns.SetOutline(b.outline, true, true)
	b.hover:SetColorTexture(ar, ag, ab, HOVER)
	b.tone = nil
end

-- The dot in the colour of its slot's tone.
local function PaintDot(b, n)
	local q = Q()
	local tone = q and q.Tone(n) or "off"
	if b.tone == tone then
		return
	end
	b.tone = tone
	local colour = TONES[tone]
	if tone == "on" then
		local r, g, bl = RGB("windows.accent", 0.85, 0.85, 0.85)
		colour = { r, g, bl }
	end
	b.dot:SetColorTexture(colour[1], colour[2], colour[3], 1)
end

-- The tooltip ----------------------------------------------------------------------------------------------------------------------------------

local function Tooltip()
	local tip = _G.GameTooltip
	if type(tip) ~= "table" or IsSecret(tip) or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

local function Untip(b)
	local tip = Tooltip()
	if not (tip and b.button) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, b.button)
	if ok and not IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

-- The lines of a slot's tooltip, each { text, colour }: the title, the slot's state in words, the next trinket when known, Pause all, and dim
-- lines; and their words in one string, which says whether the tooltip changed.
local function Lines(q, n)
	local state = q.State(n)
	local lines = { { T.TITLE[n], PLAIN }, { q.Sentence(n, state), PLAIN } }
	if state.next and state.nextAt then
		local now = type(GetTime) == "function" and GetTime() or 0
		lines[#lines + 1] = { T.NEXT:format(q.Info(state.next).name, q.Clock(state.nextAt - now)), PLAIN }
	end
	if q.Paused() then
		lines[#lines + 1] = { T.PAUSED, TONES.halt }
	end
	for _, line in ipairs(T.TIPS) do
		lines[#lines + 1] = { line, DIM }
	end
	local words = {}
	for index, line in ipairs(lines) do
		words[index] = line[1]
	end
	return lines, table.concat(words, "\n")
end

-- The tooltip of a slot's button; never in a fight.
local function Say(b, n)
	local tip, q = Tooltip(), Q()
	if Fighting() or not (tip and q) then
		return
	end
	local lines, said = Lines(q, n)
	if not pcall(tip.SetOwner, tip, b.button, "ANCHOR_RIGHT") then
		return
	end
	for index, line in ipairs(lines) do
		local colour = line[2]
		pcall(tip.AddLine, tip, line[1], colour[1], colour[2], colour[3], index > 1 or nil)
	end
	pcall(tip.Show, tip)
	b.said = said
end

-- While the cursor is on a button, out of a fight: its tooltip is said again once its words changed (a click, a swap, a countdown), and once a
-- fight that held it back ended. Never while another frame took the tooltip.
local function Again(b, n)
	local tip, q = Tooltip(), Q()
	if not (b.over and tip and q) or Fighting() then
		return
	end
	if b.said ~= nil then
		local ok, owned = pcall(tip.IsOwned, tip, b.button)
		if not (ok and not IsSecret(owned) and owned == true) then
			return
		end
	end
	local _, said = Lines(q, n)
	if said ~= b.said then
		Say(b, n)
	end
end

-- Clicks and drops -----------------------------------------------------------------------------------------------------------------------------

-- The item on the cursor: its ID and link, or nil.
local function Held()
	if type(GetCursorInfo) ~= "function" then
		return nil
	end
	local ok, kind, id, link = pcall(GetCursorInfo)
	if not ok or IsSecret(kind) or kind ~= "item" or not Finite(id) then
		return nil
	end
	return id, not IsSecret(link) and type(link) == "string" and link or nil
end

-- True when the item on the cursor was lifted from a bag, the bank or a worn slot (header), as GearButton.lua's Lifted.
local function Lifted()
	local get, locked = Fn(_G.C_Cursor, "GetCursorItem"), Fn(_G.C_Item, "IsLocked")
	if not (get and locked) then
		return false
	end
	local ok, place = pcall(get)
	if not ok or IsSecret(place) or type(place) ~= "table" then
		return false
	end
	local slotted = false
	for _, name in ipairs({ "IsBagAndSlot", "IsEquipmentSlot" }) do
		local is = Fn(place, name)
		if is then
			local okIs, answer = pcall(is, place)
			slotted = slotted or (okIs and not IsSecret(answer) and answer == true)
		end
	end
	if not slotted then
		return false
	end
	local okLocked, held = pcall(locked, place)
	return okLocked and not IsSecret(held) and held == true
end

-- An item on the cursor goes in the slot's list, and back to its slot when it was lifted from one; a message the queue gives is printed. False
-- when the cursor holds no item.
local function Drop(n)
	local id, link = Held()
	local q = Q()
	if not (id and q) then
		return false
	end
	local done, message = q.Add(n, link or id)
	if done and Lifted() and type(ClearCursor) == "function" then
		pcall(ClearCursor)
	end
	if not done and type(message) == "string" then
		print("Flat UI: " .. message)
	end
	return true
end

local function Click(n, mouse)
	local q = Q()
	if not q or Drop(n) then
		return
	end
	local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() == true
	if mouse == "RightButton" then
		if shift then
			q.SetPaused(not q.Paused())
		else
			q.SetAuto(n, not q.Auto(n))
		end
		B[n].tone = nil
		return
	end
	-- Shift-click: Queue now for this slot (header).
	if shift then
		if not q.Running() then
			print(T.OFF)
			return
		end
		q.Now(n)
		print(T.NOW:format(n))
		B[n].tone = nil
		return
	end
	local toggle = Fn(ns, "TrinketWindowToggle")
	if toggle then
		toggle(n)
	end
end

-- Making and placing ---------------------------------------------------------------------------------------------------------------------------

local function Texture(parent, layer)
	local texture = parent:CreateTexture(nil, layer)
	ns.Own[texture] = true
	return texture
end

local function Make(n)
	local b = B[n]
	local button = CreateFrame("Button", nil, UIParent)
	ns.Own[button] = true
	button:Hide()
	button:SetSize(SIDE, SIDE)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local dot = Texture(button, "OVERLAY")
	dot:SetSize(DOT, DOT)
	dot:SetPoint("CENTER", button, "CENTER", 0, 0)
	local hover = Texture(button, "HIGHLIGHT")
	hover:SetAllPoints(button)
	b.button, b.dot, b.hover = button, dot, hover
	b.outline = ns.SetOutlineArea(ns.Outline(button, button), "windows")
	-- After a click or a drop the tooltip says the change at once (header).
	button:SetScript("OnClick", function(_, mouse)
		Run(Click, n, mouse)
		if b.over then
			Run(Say, b, n)
		end
		Start()
	end)
	button:SetScript("OnReceiveDrag", function()
		Run(Drop, n)
		if b.over then
			Run(Say, b, n)
		end
		Start()
	end)
	button:SetScript("OnEnter", function()
		b.over = true
		Run(Say, b, n)
	end)
	button:SetScript("OnLeave", function()
		b.over, b.said = false, nil
		Untip(b)
	end)
	button:SetScript("OnHide", function()
		b.over, b.said = false, nil
		Untip(b)
	end)
	Paint(b)
end

-- Hangs a button right of its slot at the slot's scale, when that changed: false while the game would refuse it or the slot has no scale.
local function Place(b, slot)
	local k = Scale(slot)
	if not (k and k > 0) then
		return false
	end
	if rawequal(b.anchored, slot) and b.scale == k then
		return true
	end
	if Blocked(slot) or Blocked(b.button) then
		return false
	end
	if b.scale ~= k then
		b.button:SetScale(k)
		b.scale = k
	end
	b.button:ClearAllPoints()
	b.button:SetPoint("LEFT", slot, "RIGHT", GAP, 0)
	b.anchored = slot
	return true
end

-- The strata above the window's, at a level of its own, looked at each time.
local function Level(b, frame)
	if Blocked(b.button) then
		return
	end
	local okStrata, strata = pcall(frame.GetFrameStrata, frame)
	strata = okStrata and not IsSecret(strata) and type(strata) == "string" and strata or "MEDIUM"
	local above = STRATA[#STRATA]
	for i, name in ipairs(STRATA) do
		if name == strata then
			above = STRATA[math.min(i + 1, #STRATA)]
			break
		end
	end
	if b.strata ~= above then
		b.button:SetFrameStrata(above)
		b.strata = above
	end
	if b.level ~= LEVEL then
		b.button:SetFrameLevel(LEVEL)
		b.level = LEVEL
	end
end

-- After a fight the driver looks again, so a change the fight held back is made (once, however many waited).
local function Later()
	if not B.waiting then
		B.waiting = true
		ns.OutOfCombat(function()
			B.waiting = false
			Start()
		end)
	end
end

-- Shows or hides a button; while the game would refuse it, only its alpha changes until the fight ends.
local function Shown(b, shown)
	local button = b.button
	if not button then
		return
	end
	if Blocked(button) then
		button:SetAlpha(shown and 1 or 0)
		Later()
		return
	end
	button:SetAlpha(1)
	local ok, now = pcall(button.IsShown, button)
	if not (ok and now == shown) then
		button:SetShown(shown)
	end
	if not shown then
		Untip(b)
	end
end

-- One look of the driver: whether the buttons are wanted (else the driver stops), whether the window shows, and each slot's button.
local function Looks()
	local frame = Game("CharacterFrame")
	B.wanted = Wanted()
	B.shown = frame ~= nil and Answer(frame, "IsShown")
	local look = B.wanted and B.shown and Look() or nil
	for _, n in ipairs(ORDER) do
		local b = B[n]
		local slot = B.shown and Game(SLOTS[n]) or nil
		local visible = B.wanted and slot ~= nil and Answer(slot, "IsVisible")
		if visible and not b.button then
			Make(n)
		end
		if b.button then
			if not visible then
				Shown(b, false)
			elseif Place(b, slot) then
				Level(b, frame)
				if look ~= B.look then
					Paint(b)
				end
				PaintDot(b, n)
				Shown(b, true)
				Again(b, n)
			else
				Later()
			end
		end
	end
	if look then
		B.look = look
	end
end

-- Hides both buttons at once, whatever the state of the part, as the part stops.
local function Off()
	for _, n in ipairs(ORDER) do
		if B[n].button then
			pcall(Shown, B[n], false)
		end
	end
end

local function Stop()
	if B.driver then
		B.driver:Hide()
	end
end

local function Drive(_, elapsed)
	B.clock = B.clock + (Finite(elapsed) and elapsed or 0)
	if B.clock < EVERY then
		return
	end
	B.clock = 0
	if not Run(Looks) then
		Off()
		Stop()
	elseif not B.wanted then
		Stop()
	end
end

-- Starts the driver, which looks on the next frame and then four times a second while the buttons are wanted; the first look hangs them again
-- and paints them in the Windows page's colours of now.
function Start()
	if not B.driver then
		B.driver = CreateFrame("Frame")
		ns.Own[B.driver] = true
		B.driver:SetScript("OnUpdate", Drive)
	end
	B.clock = EVERY
	B.look = nil
	for _, n in ipairs(ORDER) do
		B[n].anchored, B[n].tone = nil, nil
	end
	B.driver:Show()
end

-- ShowUIPanel or HideUIPanel ran on the Character window: the driver starts at once.
local function Panel(frame)
	if frame ~= nil and not IsSecret(frame) and rawequal(frame, _G.CharacterFrame) then
		Start()
	end
end

-- Buttons by the trinket slots changed (its row's changed, Config.lua), or the module refreshed (TrinketQueue.lua): the driver looks at once.
function ns.TrinketButtonsChanged()
	Start()
end

ns.FollowGlobal("ShowUIPanel", Panel)
ns.FollowGlobal("HideUIPanel", Panel)
