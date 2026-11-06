local _, ns = ...

-- Spell ranks: after training, a line at the top of the screen names the action buttons that hold a lower rank of a spell the spell book now
-- knows higher, with an Uprank and reload button. Its click puts the new ranks on those slots (C_Spell.PickupSpell, PlaceAction, ClearCursor)
-- and its secure /reload macro reloads the interface in the same click. No slot is written anywhere else. The game raises ACTIONBAR_SLOT_CHANGED,
-- ACTIONBAR_SHOWGRID, ACTIONBAR_HIDEGRID and CURSOR_CHANGED inside the call that changes a slot or the cursor (SynchronousEvent,
-- ActionBarFrameDocumentation.lua, CursorDocumentation.lua), so its buttons and bars write action, flashing, showAllButtons and their list of
-- shown buttons under the caller (ActionButton.lua:529-553, ActionBar.lua:144-171, 198-217): fields the click of an action button reads, and
-- which the game writes again only behind a read of them, so they would taint every later update of the button, in a fight too. The reload in
-- the same click throws all of that away before any later click or fight reads it; LayoutSpots.lua keeps its one risky write in its Reload
-- click for the same reason.
-- The ranks come from the spell book by name and number: the best rank the book lists of each name (the first number of its rank text), and a
-- slot is offered when it holds a spell of that name with a lower number. Only the player's own pages are read (slots 1 to 120 and 145 to 180),
-- and only spells: macros, items, flyouts, mounts and pets are never touched, nor a rank the player keeps (/flatui rank, kept for the account in
-- FlatUIDB.errands.ranks), nor a name whose top rank two spells share. Out of combat only: the line hides and its secure button leaves it before
-- the lockdown, and both come back after the fight. The click asks again about the fight, the cursor, Edit Mode and the quick keybind mode, and a
-- click that cannot uprank cancels its own reload and says why. Never under the gamepad interface. Later keeps a plan from coming back by itself
-- until the plan changes; after the reload one line in chat says what the game took.
-- The lines about learned spells: the game's four (ERR_LEARN_SPELL_S, ERR_LEARN_ABILITY_S, ERR_LEARN_PASSIVE_S, ERR_SPELL_UNLEARNED_S) are dropped
-- from the chat windows through the game's own chat filter registry (ChatFrameUtil.AddMessageEventFilter), which calls the filter securely and
-- only with a message the addon may read. No line is changed, only dropped, and by default one line in their place names what was learned.
-- Both follow EnhanceQoL (its AutoRankUp, and the learn and unlearn filter of its chat module), adapted with the permission of its author.

local E = ns.Errands
local part = E.Part({ label = "Spell ranks" })

-- The action slots of the player's own pages: the six pages of the main bar and its four stance and form pages, then bars 6 to 8 (OwnBars.lua's
-- bases 144, 156, 168). The possess, vehicle and override pages between them are the game's own.
local SLOT_RANGES = { { 1, 120 }, { 145, 180 } }
-- Seconds after the last learned rank before the line is offered.
local OFFER_WAIT = 1.5
-- Seconds between two looks at the trainer window, and the looks before the wait gives up.
local WATCH, WATCH_MOST = 1, 600
-- The line is read again this long after a slot or the spell book changed.
local REFRESH = 0.2
-- Seconds after the last dropped line before the one line in their place.
local SUMMARY_WAIT = 2
-- Seconds after the start of the part before the note of the last click is read.
local AFTER_RELOAD = 1
-- How many names the summary, the line, the tooltip and the line after the reload give before "and N more".
local CHAT_NAMES, NOTICE_NAMES, TIP_SPELLS, NOTE_NAMES = 4, 2, 8, 3
-- Under the line of LayoutSpots.lua (TOP, -90, 30 high).
local NOTICE_WIDTH, NOTICE_HEIGHT, NOTICE_Y = 360, 30, -126
local UPRANK_WIDTH, LATER_WIDTH, GAP = 124, 60, 4
local MAX_RANK = 1000
-- The game's own words, the last one for an unlearned spell.
local LINES = { "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S", "ERR_SPELL_UNLEARNED_S" }
local FAILED = "Flat UI: Spell ranks failed. /flatui status shows why."

-- The line: { frame, text, uprank, later, overlay }. broken: the line or its secure button could not be made, and is not tried again.
local notice
local broken = false
-- A hide asked for in the lockdown waits for its end, once.
local hideQueued = false
-- Inside the swaps of a click, and whether a pickup or a placement was made in this click.
local swapping, touched = false, false
-- Slots placed in this session: any at all means a click whose reload did not follow.
local placedSession = 0
-- The wait after a learned rank: when the last one was learned, whether a look is due, how many looks so far, and which wait is the latest.
local learnedAt, watching, looks, watchToken = nil, false, 0, 0
-- The line hidden by a fight ("resume"), and an offer asked for in a fight.
local suspended, queued
local refreshToken = 0
-- { count, kept } after the reload, for /flatui status. afterDone: the note of the last click was read this session.
local lastUpranked
local afterDone = false
-- Put new ranks on your bars at the last refresh.
local wasOn = false
local filtering = false
-- { { pattern, unlearned } }, built once.
local patterns
-- The spells of the dropped lines until the summary.
local heard = { learned = {}, unlearned = {}, seen = {}, token = 0 }

local HideNotice, ShowNotice, ScheduleRefresh, Explain, Usable, Offer, Filter, PreClick, PostClick

-- Reading ranks -------------------------------------------------------------------------------------------------------------------------------

local function Whole(v)
	return ns.Finite(v) and v > 0 and v % 1 == 0
end

-- A field of a table the game gave, or nil when it cannot be read or is withheld.
local function Field(t, key)
	local ok, value = pcall(function()
		return t[key]
	end)
	if not ok or ns.IsSecret(value) then
		return nil
	end
	return value
end

local function SpellName(id)
	local name = E.Ask(type(C_Spell) == "table" and C_Spell.GetSpellName, id)
	return type(name) == "string" and name ~= "" and name or nil
end

local function Subtext(id)
	local text = E.Ask(type(C_Spell) == "table" and C_Spell.GetSpellSubtext, id)
	return type(text) == "string" and text or nil
end

-- The rank of a rank text: its first number ("Rank 3", "Rang 3", "Ранг 3", "等级 3"). Nil for a text with none ("Racial", "Apprentice", "").
local function RankNumber(text)
	if ns.IsSecret(text) or type(text) ~= "string" then
		return nil
	end
	local n = tonumber(text:match("(%d+)"))
	return n and n >= 1 and n < MAX_RANK and n or nil
end

local function Buttons(n)
	return n == 1 and "button" or "buttons"
end

-- "A", "A and B", "A, B and C", "A, B, C, D and 3 more".
local function Join(list, most)
	local n = #list
	if n == 0 then
		return ""
	elseif n > most then
		return table.concat(list, ", ", 1, most) .. (" and %d more"):format(n - most)
	elseif n == 1 then
		return list[1]
	end
	return table.concat(list, ", ", 1, n - 1) .. " and " .. list[n]
end

-- "Fireball (Rank 4)", or the name alone for a spell with no rank text.
local function WithRank(name, text)
	if type(text) == "string" and text ~= "" then
		return name .. " (" .. text .. ")"
	end
	return name
end

-- "Name (Rank text)", the name alone without a rank text, or "Spell <id>" for a spell the game does not name.
local function Label(id)
	local name = SpellName(id)
	if not name then
		return "Spell " .. tostring(id)
	end
	return WithRank(name, Subtext(id))
end

-- Each item's name once, in plan order.
local function UniqueNames(list)
	local names, seen = {}, {}
	for _, item in ipairs(list) do
		if not seen[item.name] then
			seen[item.name] = true
			names[#names + 1] = item.name
		end
	end
	return names
end

-- The spell book, or nil when the game lacks a call the walk through it needs. The walk is Trackers.lua's, copied: that file keeps its own local.
local function Book()
	local book = C_SpellBook
	if type(book) == "table" and type(book.GetNumSpellBookSkillLines) == "function" and type(book.GetSpellBookSkillLineInfo) == "function"
		and type(book.GetSpellBookItemInfo) == "function" and type(Enum) == "table" and type(Enum.SpellBookSpellBank) == "table"
		and type(Enum.SpellBookItemType) == "table" then
		return book
	end
	return nil
end

-- Calls visit(slot, item) for each spell of the player the book lists: the Player bank, no hidden or off-spec line, no passive, no off-spec item.
local function WalkBook(book, visit)
	local bank, spellType = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType.Spell
	local lines = E.Ask(book.GetNumSpellBookSkillLines)
	for line = 1, ns.Finite(lines) and math.min(lines, 50) or 0 do
		local skill = E.Ask(book.GetSpellBookSkillLineInfo, line)
		if type(skill) == "table" then
			local offset, count = Field(skill, "itemIndexOffset"), Field(skill, "numSpellBookItems")
			if Field(skill, "shouldHide") ~= true and Field(skill, "offSpecID") == nil and ns.Finite(offset) and ns.Finite(count) then
				for slot = offset + 1, offset + math.min(count, 500) do
					local item = E.Ask(book.GetSpellBookItemInfo, slot, bank)
					if type(item) == "table" and Field(item, "itemType") == spellType and Field(item, "isPassive") ~= true and Field(item, "isOffSpec") ~= true then
						visit(slot, item)
					end
				end
			end
		end
	end
end

-- The best rank the book knows of each spell name: best[name] = { id, base, rank, text, bookSlot, tie }. The book may hide lower ranks; only the
-- best one counts here. An item whose rank text has no number is left out, and a name whose top rank two spells share is marked tie.
local function Best()
	local best = {}
	local book = Book()
	if not book then
		return best
	end
	WalkBook(book, function(slot, item)
		local base = Field(item, "actionID")
		local id = Field(item, "spellID")
		if not Whole(id) then
			id = base
		end
		if not Whole(id) then
			return
		end
		local name = SpellName(id)
		if not name then
			local named = Field(item, "name")
			name = type(named) == "string" and named ~= "" and named or nil
		end
		local text = Field(item, "subName")
		if type(text) ~= "string" or text == "" then
			text = Subtext(id)
		end
		local rank = RankNumber(text)
		if not name or not rank then
			return
		end
		local top = best[name]
		if not top or rank > top.rank then
			best[name] = { id = id, base = Whole(base) and base or id, rank = rank, text = text, bookSlot = slot }
		elseif rank == top.rank and id ~= top.id then
			top.tie = true
		end
	end)
	return best
end

-- Kept ranks: FlatUIDB.errands.ranks[spellID] = true, account-wide beside the sell and keep lists of the items (E.Kept is the item list, not this).
local function Ranks()
	local lists = E.Lists()
	if not lists then
		return nil
	end
	lists.ranks = type(lists.ranks) == "table" and lists.ranks or {}
	return lists.ranks
end

local function RankKept(id)
	local ranks = Ranks()
	return ranks ~= nil and ranks[id] == true
end

-- The plan --------------------------------------------------------------------------------------------------------------------------------------

local function Pickups()
	return (type(C_Spell) == "table" and type(C_Spell.PickupSpell) == "function") or type(PickupSpell) == "function"
		or (type(C_SpellBook) == "table" and type(C_SpellBook.PickupSpellBookItem) == "function")
end

-- The call that drops the cursor's action into a slot: PlaceAction, or C_ActionBar.PutActionInSlot on a client that has only that.
local function Placer()
	if type(PlaceAction) == "function" then
		return PlaceAction
	elseif type(C_ActionBar) == "table" and type(C_ActionBar.PutActionInSlot) == "function" then
		return C_ActionBar.PutActionInSlot
	end
	return nil
end

-- What the client lacks for the errand: "book" (the spell book walk or the spell names), "client" (the slots, a pickup, a drop or the cursor),
-- or nil.
local function Unavailable()
	if not Book() or type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" or type(C_Spell.GetSpellSubtext) ~= "function" then
		return "book"
	end
	if type(GetActionInfo) ~= "function" or not Pickups() or not Placer() or type(GetCursorInfo) ~= "function" or type(ClearCursor) ~= "function" then
		return "client"
	end
	return nil
end

-- What a click would do now: one item per slot that holds a lower rank of a spell the book knows higher, in slot order. A slot whose value the
-- client withholds is left out (E.Ask gives nil), and so is a pet's spell.
local function Plan()
	local plan = {}
	if Unavailable() then
		return plan
	end
	local best = Best()
	if next(best) == nil then
		return plan
	end
	for _, range in ipairs(SLOT_RANGES) do
		for slot = range[1], range[2] do
			local kind, id, sub = E.Ask(GetActionInfo, slot)
			if kind == "spell" and Whole(id) and sub ~= "pet" then
				local name = SpellName(id)
				local top = name and best[name]
				if top and not top.tie and id ~= top.id and id ~= top.base and not RankKept(id) then
					local fromText = Subtext(id)
					local from = RankNumber(fromText)
					if from and from < top.rank then
						plan[#plan + 1] = { slot = slot, old = id, new = top.id, base = top.base, bookSlot = top.bookSlot, name = name,
							from = from, to = top.rank, fromText = fromText, toText = top.text }
					end
				end
			end
		end
	end
	return plan
end

local function Signature(plan)
	local parts = {}
	for _, item in ipairs(plan) do
		parts[#parts + 1] = item.slot .. ":" .. item.new
	end
	return table.concat(parts, ",")
end

-- The plan declined with Later, kept for the character until the plan changes.
local function Later()
	local char = ns.Character()
	local sig = type(char) == "table" and char.errandsRanksLater or nil
	return type(sig) == "string" and sig or nil
end

local function SetLater(sig)
	local char = ns.Character()
	if type(char) == "table" then
		char.errandsRanksLater = sig
	end
end

local function Wanted()
	return ns.Enabled("errands") and E.Opt("uprank") == true and not ns.PartStopped("errands", part.label)
end

-- Whether the cursor holds something. Read with a plain pcall, since E.Ask makes a cursor the client will not say about look empty: that one
-- counts as busy.
local function Busy()
	if type(GetCursorInfo) ~= "function" then
		return true
	end
	local ok, kind = pcall(GetCursorInfo)
	if not ok or ns.IsSecret(kind) or kind ~= nil then
		return true
	end
	return E.Ask(CursorHasItem) == true or E.Ask(CursorHasSpell) == true
end

-- Why a click could not uprank now, or nil.
local function Refusal()
	if not Wanted() then
		return "off"
	end
	local missing = Unavailable()
	if missing then
		return missing
	elseif E.Gamepad() then
		return "gamepad"
	elseif E.Fighting() then
		return "fight"
	elseif Busy() then
		return "cursor"
	elseif type(ns.EditModeOpen) == "function" and ns.EditModeOpen() then
		return "editmode"
	elseif E.Ask(KeybindFrames_InQuickKeybindMode) == true then
		return "keybind"
	end
	return nil
end

-- What the player is told, by reason. Printed, since the player clicked or typed.
local ANSWER = {
	client = "Flat UI: this client cannot put spells on your bars.",
	book = "Flat UI: the spell book cannot be read here.",
	button = "Flat UI: the Uprank button could not be made here.",
	gamepad = "Flat UI: the Uprank button cannot be reached under the gamepad interface. Drag new ranks from the spell book.",
	fight = "Flat UI: not in a fight. The line comes back after it.",
	cursor = "Flat UI: put down what the cursor holds first.",
	editmode = "Flat UI: close Edit Mode first.",
	keybind = "Flat UI: close the quick keybind mode first.",
	nothing = "Flat UI: every spell on your bars has its highest rank.",
}

local function Answer(why)
	if why == "off" then
		if not ns.Enabled("errands") then
			return "Flat UI: Errands is off. Tick Run errands on the Errands page."
		end
		return "Flat UI: Put new ranks on your bars is off on the Levelling tab of the Errands page."
	end
	return ANSWER[why]
end

-- The line ----------------------------------------------------------------------------------------------------------------------------------

local function Showing()
	return notice ~= nil and E.Shown(notice.frame)
end

-- The secure button sits on Uprank only while the line shows out of combat: a secure child makes the frames above it protected, so the line
-- could not be hidden in a fight while it is there (Reload.lua does the same). Neither runs in the lockdown.
local function Detach()
	if not notice or E.InCombat() then
		return
	end
	pcall(function()
		notice.overlay:Hide()
		notice.overlay:ClearAllPoints()
		notice.overlay:SetParent(UIParent)
	end)
end

local function Attach()
	if not notice or E.InCombat() then
		return
	end
	pcall(function()
		notice.overlay:SetParent(notice.uprank)
		notice.overlay:SetAllPoints(notice.uprank)
		notice.overlay:Show()
	end)
	-- Above the flat button, so the player's click reaches the secure one.
	pcall(function()
		local level = notice.uprank:GetFrameLevel()
		if ns.Finite(level) then
			notice.overlay:SetFrameLevel(level + 2)
		end
	end)
end

-- Whether the line may stay up: asked every frame while it shows.
local function Keep()
	return Wanted() and not E.Gamepad()
end

-- Made once, out of combat, at the first offer. The layout is that of LayoutSpots.lua's line, the secure button that of Reload.lua.
local function Build()
	if notice then
		return true
	end
	if broken or E.InCombat() then
		return false
	end
	local ok, made = pcall(function()
		local frame = CreateFrame("Frame", nil, UIParent)
		ns.Own[frame] = true
		frame:SetSize(NOTICE_WIDTH, NOTICE_HEIGHT)
		frame:SetPoint("TOP", UIParent, "TOP", 0, NOTICE_Y)
		-- Above the options window (HIGH, Panel.lua).
		frame:SetFrameStrata("DIALOG")
		pcall(frame.SetClampedToScreen, frame, true)
		local outline = ns.Outline(frame, frame, true)
		if outline then
			ns.SetOutlineFill(outline, 0.09, 0.09, 0.09, 0.95)
		end
		local text = ns.OwnText(frame, "OVERLAY", "GameFontHighlight")
		text:SetPoint("LEFT", frame, "LEFT", 10, 0)
		local uprank = E.Button(frame, "Uprank and reload", UPRANK_WIDTH, function()
			-- Only reached while the secure button is not on top of it.
			print("Flat UI: the Uprank button is not ready. Try again in a moment.")
		end, function(owner)
			E.Run(part, Explain, owner)
		end)
		uprank:SetPoint("RIGHT", frame, "RIGHT", -GAP, 0)
		local later = E.Button(frame, "Later", LATER_WIDTH, function()
			E.Run(part, function()
				SetLater(Signature(Plan()))
				HideNotice()
			end)
		end)
		later:SetPoint("RIGHT", uprank, "LEFT", -GAP, 0)
		-- Made on UIParent and hidden, so the line is protected only while Attach puts the secure button on it.
		local overlay = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
		ns.Own[overlay] = true
		overlay:Hide()
		overlay:SetFrameStrata("DIALOG")
		overlay:RegisterForClicks("LeftButtonUp")
		overlay:SetAttribute("type", "macro")
		overlay:SetAttribute("macrotext", "/reload")
		-- The game runs a click on the key press by default (ActionButtonUseKeyDown); the button listens for the release.
		overlay:SetAttribute("useOnKeyDown", false)
		overlay:SetScript("PreClick", PreClick)
		overlay:SetScript("PostClick", PostClick)
		-- The hover of the flat button under it still runs: its look and its tooltip.
		overlay:SetScript("OnEnter", function(_, ...)
			local got, script = pcall(uprank.GetScript, uprank, "OnEnter")
			if got and type(script) == "function" then
				script(uprank, ...)
			end
		end)
		overlay:SetScript("OnLeave", function(_, ...)
			local got, script = pcall(uprank.GetScript, uprank, "OnLeave")
			if got and type(script) == "function" then
				script(uprank, ...)
			end
		end)
		-- A line that is no longer wanted hides itself while it shows, so a part that stopped, or the gamepad interface turned on, cannot leave a
		-- live reload button on the screen (as Errands.Button's Keep does).
		frame:SetScript("OnUpdate", function()
			local fine, keep = pcall(Keep)
			if not fine or not keep then
				pcall(HideNotice)
			end
		end)
		frame:Hide()
		return { frame = frame, text = text, uprank = uprank, later = later, overlay = overlay }
	end)
	if not ok or type(made) ~= "table" then
		broken = true
		return false
	end
	notice = made
	return true
end

-- The line, for the test.
function ns.ErrandsRanksNotice()
	return notice
end

-- Greyed while a click could not uprank: it still sits under the secure button, whose click then says why and cancels its own reload.
Usable = function()
	if notice and not swapping then
		notice.uprank.SetUsable(Refusal() == nil)
	end
end

ShowNotice = function(plan)
	if E.InCombat() or not Build() then
		return false
	end
	local n = #plan
	notice.text:SetText(("New ranks for %d %s: %s."):format(n, Buttons(n), Join(UniqueNames(plan), NOTICE_NAMES)))
	local okWidth, width = pcall(notice.text.GetStringWidth, notice.text)
	if okWidth and ns.Finite(width) then
		notice.frame:SetWidth(math.max(NOTICE_WIDTH, math.ceil(width) + UPRANK_WIDTH + LATER_WIDTH + 30))
	end
	hideQueued = false
	Attach()
	Usable()
	notice.frame:Show()
	if E.TipOwned(notice.uprank) then
		Explain(notice.uprank)
	end
	return true
end

HideNotice = function()
	if not notice then
		return
	end
	if E.InCombat() then
		if not hideQueued then
			hideQueued = true
			ns.OutOfCombat(function()
				if hideQueued then
					pcall(HideNotice)
				end
			end)
		end
		return
	end
	hideQueued = false
	Detach()
	notice.frame:Hide()
end

-- A reason as a sentence of the tooltip: the answer without "Flat UI: ".
local function Sentence(line)
	local text = line:gsub("^Flat UI: ", "")
	return text:sub(1, 1):upper() .. text:sub(2)
end

Explain = function(owner)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local plan = Plan()
	tip:SetOwner(owner, "ANCHOR_BOTTOM", 0, -4)
	tip:SetText("Uprank and reload")
	local function Line(text)
		tip:AddLine(text, 1, 1, 1, true)
	end
	-- One line per spell, in plan order.
	local order, byName = {}, {}
	for _, item in ipairs(plan) do
		local entry = byName[item.name]
		if not entry then
			entry = { item = item, count = 0 }
			byName[item.name] = entry
			order[#order + 1] = entry
		end
		entry.count = entry.count + 1
	end
	for index, entry in ipairs(order) do
		if index > TIP_SPELLS then
			Line(("And %d more."):format(#order - TIP_SPELLS))
			break
		end
		local item = entry.item
		local from = item.fromText ~= nil and item.fromText ~= "" and item.fromText or ("Rank " .. item.from)
		local to = item.toText ~= nil and item.toText ~= "" and item.toText or ("Rank " .. item.to)
		local text = ("%s: %s to %s"):format(item.name, from, to)
		if entry.count > 1 then
			text = text .. (", %d buttons"):format(entry.count)
		end
		Line(text)
	end
	Line("The interface reloads in the same click, so the game's bars stay clean.")
	Line("Macros, items and the ranks you keep stay as they are.")
	local why = Refusal()
	if why and Answer(why) then
		Line(Sentence(Answer(why)))
	end
	tip:Show()
end

-- The click -----------------------------------------------------------------------------------------------------------------------------------

-- The first of the client's pickups that exists, and only that one. True when the call was taken.
local function Pickup(item)
	if type(C_Spell) == "table" and type(C_Spell.PickupSpell) == "function" then
		return E.Call(C_Spell.PickupSpell, item.new)
	elseif type(PickupSpell) == "function" then
		return E.Call(PickupSpell, item.new)
	elseif type(C_SpellBook) == "table" and type(C_SpellBook.PickupSpellBookItem) == "function" and Whole(item.bookSlot) then
		return E.Call(C_SpellBook.PickupSpellBookItem, item.bookSlot, Enum.SpellBookSpellBank.Player)
	end
	return false
end

-- Whether the cursor holds the new rank: GetCursorInfo gives "spell" and the spell's ID fourth.
local function CursorSpell(item)
	local ok, kind, _, _, id = pcall(GetCursorInfo)
	if not ok or ns.IsSecret(kind) or ns.IsSecret(id) or kind ~= "spell" then
		return false
	end
	return id == item.new or id == item.base
end

-- The swaps, in the player's click on the secure button. True when the reload must go ahead: from the first pickup on, values written under this
-- call are on the game's bars, so whatever follows, the reload comes. The note for after the reload is written before an error is raised again.
local function Uprank()
	local why = Refusal()
	if why then
		print(Answer(why))
		return false
	end
	local plan = Plan()
	if #plan == 0 then
		print(ANSWER.nothing)
		return false
	end
	local done, refused, slots = 0, 0, {}
	swapping = true
	local ok, err = pcall(function()
		for _, item in ipairs(plan) do
			local kind, id = E.Ask(GetActionInfo, item.slot)
			-- A slot that changed since the plan is left.
			if kind == "spell" and id == item.old then
				touched = true
				if Pickup(item) and CursorSpell(item) then
					E.Call(Placer(), item.slot)
					-- The old rank the drop put on the cursor goes.
					E.Call(ClearCursor)
					local nowKind, nowId = E.Ask(GetActionInfo, item.slot)
					if nowKind == "spell" and (nowId == item.new or nowId == item.base) then
						done = done + 1
						slots[item.slot] = { id = nowId, name = WithRank(item.name, item.toText) }
					else
						refused = refused + 1
					end
				else
					E.Call(ClearCursor)
					refused = refused + 1
				end
			end
		end
	end)
	swapping = false
	-- The cursor was empty when the click began, so it is left empty.
	if Busy() then
		E.Call(ClearCursor)
	end
	placedSession = placedSession + done
	if touched then
		local char = ns.Character()
		if type(char) == "table" then
			char.errandsUpranked = { refused = refused, slots = slots }
		end
	end
	if not ok then
		error(err, 0)
	end
	if not touched then
		print(ANSWER.nothing)
	end
	return touched
end

-- The secure button's PreClick. A click that cannot uprank runs nothing: its type is taken away for that click, so no reload follows.
PreClick = function(self)
	touched = false
	local go = false
	E.Run(part, function()
		go = Uprank()
	end)
	if touched then
		go = true
	end
	if not go then
		pcall(self.SetAttribute, self, "type", nil)
	end
end

-- Only reached for good when no reload followed (a cancelled click): the line is read again on the next frame, outside the click, since a frame
-- is not hidden or moved inside its own click.
PostClick = function(self)
	pcall(self.SetAttribute, self, "type", "macro")
	if type(C_Timer) == "table" then
		pcall(C_Timer.After, 0, function()
			E.Run(part, ScheduleRefresh)
		end)
	end
end

-- When the line is offered ------------------------------------------------------------------------------------------------------------------

-- The line is read again a moment after a slot or the spell book changed: an empty plan hides it.
ScheduleRefresh = function()
	refreshToken = refreshToken + 1
	local token = refreshToken
	C_Timer.After(REFRESH, function()
		E.Run(part, function()
			if token ~= refreshToken or not Showing() then
				return
			end
			if not Keep() then
				HideNotice()
				return
			end
			local plan = Plan()
			if #plan == 0 then
				HideNotice()
			else
				ShowNotice(plan)
			end
		end)
	end)
end

-- Shows the line, or says why not: "off", "client", "book", "button", "gamepad", "fight" (asked again after the fight), "nothing" or "later".
-- kind: "training", "login", "turnedOn", "released", "asked" or "resume". Only the automatic ones respect a declined plan.
Offer = function(kind)
	if not Wanted() then
		return "off"
	end
	local missing = Unavailable()
	if missing then
		return missing
	end
	if broken then
		return "button"
	end
	if E.Gamepad() then
		HideNotice()
		return "gamepad"
	end
	if E.Fighting() then
		-- What the player asked for wins over what training asked for.
		if not queued or kind == "asked" then
			queued = kind
		end
		return "fight"
	end
	local plan = Plan()
	if #plan == 0 then
		HideNotice()
		return "nothing"
	end
	if (kind == "training" or kind == "login") and Later() == Signature(plan) then
		return "later"
	end
	if not ShowNotice(plan) then
		return "button"
	end
	return nil
end

local function Now()
	local now = E.Ask(GetTime)
	return ns.Finite(now) and now or nil
end

-- The look after a learned rank: it waits while less than OFFER_WAIT has passed since the last one, or while the trainer window shows.
local function Look(token)
	if token ~= watchToken then
		return
	end
	if not learnedAt then
		watching = false
		return
	end
	local now = Now()
	local waited = now and ns.Finite(learnedAt) and now - learnedAt or OFFER_WAIT
	if (waited < OFFER_WAIT or E.Shown(ClassTrainerFrame)) and looks < WATCH_MOST then
		looks = looks + 1
		C_Timer.After(WATCH, function()
			E.Run(part, Look, token)
		end)
		return
	end
	learnedAt, watching = nil, false
	Offer("training")
end

-- One wait at a time; now: a look at once (the trainer closed), which takes the place of the one waiting.
local function Watch(now)
	if watching and not now then
		return
	end
	watching = true
	watchToken = watchToken + 1
	local token = watchToken
	if now then
		Look(token)
	else
		looks = 0
		C_Timer.After(OFFER_WAIT, function()
			E.Run(part, Look, token)
		end)
	end
end

-- A rank learned: a spell with a rank number starts the wait. One with none (Attack, a profession) starts nothing.
local function Learned(spellID)
	if not Wanted() or not Whole(spellID) or not RankNumber(Subtext(spellID)) then
		return
	end
	learnedAt = Now() or 0
	if Showing() then
		ScheduleRefresh()
	end
	Watch(false)
end

-- After the reload ----------------------------------------------------------------------------------------------------------------------------

-- The note the click left: which slots took which rank. Read once, and cleared whatever follows; every value is checked, since a saved variable
-- can be edited.
local function AfterReload()
	local char = ns.Character()
	if type(char) ~= "table" or char.errandsUpranked == nil then
		return
	end
	local note = char.errandsUpranked
	char.errandsUpranked = nil
	if type(note) ~= "table" then
		return
	end
	local list = {}
	if type(note.slots) == "table" then
		for slot, entry in pairs(note.slots) do
			if Whole(slot) and type(entry) == "table" and Whole(entry.id) then
				list[#list + 1] = slot
			end
		end
	end
	table.sort(list)
	local count, kept, names, seen = 0, 0, {}, {}
	for _, slot in ipairs(list) do
		local entry = note.slots[slot]
		local kind, id = E.Ask(GetActionInfo, slot)
		if kind == "spell" and id == entry.id then
			count = count + 1
			local name = entry.name
			if type(name) == "string" and name ~= "" and not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		else
			kept = kept + 1
		end
	end
	if Whole(note.refused) then
		kept = kept + note.refused
	end
	lastUpranked = { count = count, kept = kept }
	if count > 0 then
		local line = #names > 0 and ("Put new ranks on %d %s: %s."):format(count, Buttons(count), Join(names, NOTE_NAMES))
			or ("Put new ranks on %d %s."):format(count, Buttons(count))
		if kept > 0 then
			line = line .. (" The game kept the old rank on %d."):format(kept)
		end
		E.Say(line)
	elseif kept > 0 then
		E.Say(("The game kept the old rank on %d %s."):format(kept, Buttons(kept)))
	end
end

-- The lines about learned spells ----------------------------------------------------------------------------------------------------------------

-- A pattern for a line of the game's: "%s" and "%1$s" capture the spell, "%d" and "%1$d" match a number.
-- "You have learned a new spell: %s."  ->  "^You have learned a new spell: (.+)%.$"
local function Pattern(format)
	if ns.IsSecret(format) or type(format) ~= "string" or format == "" then
		return nil
	end
	local escaped = format:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	escaped = escaped:gsub("%%%%%d+%%%$s", "(.+)"):gsub("%%%%s", "(.+)"):gsub("%%%%%d+%%%$d", "%%d+"):gsub("%%%%d", "%%d+")
	return "^" .. escaped .. "$"
end

local function Patterns()
	if patterns then
		return patterns
	end
	local list = {}
	for index, name in ipairs(LINES) do
		local pattern = Pattern(_G[name])
		if pattern then
			list[#list + 1] = { pattern = pattern, unlearned = index == #LINES }
		end
	end
	patterns = list
	return list
end

-- Only the latest timer prints, so the line comes a moment after the last dropped line.
local function Flush(token)
	if token ~= heard.token then
		return
	end
	local parts = {}
	if #heard.learned > 0 then
		parts[#parts + 1] = "Learned " .. Join(heard.learned, CHAT_NAMES) .. "."
	end
	if #heard.unlearned > 0 then
		parts[#parts + 1] = "Unlearned " .. Join(heard.unlearned, CHAT_NAMES) .. "."
	end
	heard = { learned = {}, unlearned = {}, seen = {}, token = heard.token }
	-- A change to Hidden, or Errands turned off, before the timer drops the line.
	if #parts > 0 and ns.Enabled("errands") and E.Opt("learnedLines") == "summary" then
		E.Say(table.concat(parts, " "))
	end
end

-- The filter runs once for each chat window that shows the line, so a line is counted once by its lineID (or its text and the time).
local function Heard(what, unlearned, lineID, msg)
	local key = Whole(lineID) and lineID or (msg .. "@" .. tostring(E.Ask(GetTime)))
	if heard.seen[key] then
		return
	end
	heard.seen[key] = true
	local list = unlearned and heard.unlearned or heard.learned
	local known = false
	for _, name in ipairs(list) do
		known = known or name == what
	end
	if not known then
		list[#list + 1] = what
	end
	heard.token = heard.token + 1
	local token = heard.token
	C_Timer.After(SUMMARY_WAIT, function()
		E.Run(part, Flush, token)
	end)
end

-- True to drop a line: one of the game's four, while the row hides them. A line is never changed. What it names (the spell, or its link) is kept
-- for the summary only.
local function Drop(msg, lineID)
	if not ns.Enabled("errands") or ns.PartStopped("errands", part.label) then
		return false
	end
	local mode = E.Opt("learnedLines")
	if mode ~= "hide" and mode ~= "summary" then
		return false
	end
	if ns.IsSecret(msg) or type(msg) ~= "string" then
		return false
	end
	for _, entry in ipairs(Patterns()) do
		local what = msg:match(entry.pattern)
		if what then
			if mode == "summary" then
				Heard(what, entry.unlearned, lineID, msg)
			end
			return true
		end
	end
	return false
end

-- The game's registry calls it with the chat frame, the event and the event's values, lineID 11th. One value back: no line is rewritten.
Filter = function(_, _, msg, _, _, _, _, _, _, _, _, _, lineID)
	local drop = false
	E.Run(part, function()
		drop = Drop(msg, lineID)
	end)
	return drop
end

-- The game's own chat filter registry: ChatFrameUtil on this client, ChatFrame_AddMessageEventFilter on an older one, or nil.
local function Registry()
	if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.AddMessageEventFilter) == "function" and type(ChatFrameUtil.RemoveMessageEventFilter) == "function" then
		return ChatFrameUtil.AddMessageEventFilter, ChatFrameUtil.RemoveMessageEventFilter
	end
	if type(ChatFrame_AddMessageEventFilter) == "function" and type(ChatFrame_RemoveMessageEventFilter) == "function" then
		return ChatFrame_AddMessageEventFilter, ChatFrame_RemoveMessageEventFilter
	end
	return nil
end

-- The filter is given once and taken back with the same function value.
local function SetFilter(on)
	local add, remove = Registry()
	if not add then
		filtering = false
		return
	end
	if on and not filtering then
		filtering = E.Call(add, "CHAT_MSG_SYSTEM", Filter)
	elseif not on and filtering then
		E.Call(remove, "CHAT_MSG_SYSTEM", Filter)
		filtering = false
	end
end

local function FilterWanted()
	return ns.Enabled("errands") and E.Opt("learnedLines") ~= "game"
end

-- Events ------------------------------------------------------------------------------------------------------------------------------------

for _, event in ipairs({ "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB" }) do
	E.Listen(part, event, Learned)
end
E.Listen(part, "TRAINER_CLOSED", function()
	if learnedAt then
		Watch(true)
	end
end)
-- The mainline trainer opens and closes through the interaction manager.
E.Listen(part, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
	local trainer = type(Enum) == "table" and type(Enum.PlayerInteractionType) == "table" and Enum.PlayerInteractionType.Trainer or nil
	if learnedAt and trainer ~= nil and not ns.IsSecret(kind) and kind == trainer then
		Watch(true)
	end
end)
-- Runs before the lockdown, so the line can still be hidden and its secure button taken off.
E.Listen(part, "PLAYER_REGEN_DISABLED", function()
	if Showing() then
		suspended = "resume"
		HideNotice()
	end
end)
E.Listen(part, "PLAYER_REGEN_ENABLED", function()
	local kind = queued or suspended
	queued, suspended = nil, nil
	if kind then
		Offer(kind)
	end
end)
-- It comes for every change of the cursor, so the plan is not read again here.
E.Listen(part, "CURSOR_CHANGED", function()
	if Showing() then
		Usable()
	end
end)
for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED" }) do
	E.Listen(part, event, function()
		if not swapping and Showing() then
			ScheduleRefresh()
		end
	end)
end
E.Listen(part, "INPUT_DEVICE_INTERFACE_TRANSITION", function()
	if E.Gamepad() then
		HideNotice()
	end
end)

function part.Start()
	wasOn = Wanted()
	SetFilter(FilterWanted())
	C_Timer.After(AFTER_RELOAD, function()
		E.Run(part, function()
			if not afterDone then
				afterDone = true
				AfterReload()
			end
			Offer("login")
		end)
	end)
end

-- The row or the page turned on offers the line; turned off, the line goes and nothing waits. The filter follows Lines about learned spells.
function part.Refresh()
	local on = Wanted()
	if on and not wasOn then
		wasOn = true
		Offer("turnedOn")
	elseif not on then
		wasOn = false
		learnedAt, queued, suspended = nil, nil, nil
		HideNotice()
	end
	SetFilter(FilterWanted())
end

-- Kept ranks, Uprank now and the slash words ---------------------------------------------------------------------------------------------

-- Rows of a list: { id, label }, by name, then rank.
local function Sorted(rows)
	table.sort(rows, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		elseif a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.id < b.id
	end)
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { row.id, row.label }
	end
	return list
end

-- Every distinct ranked spell on the player's slots that is not kept, so a rank can be kept before the next one is learned.
local function Candidates()
	local rows, seen = {}, {}
	for _, range in ipairs(SLOT_RANGES) do
		for slot = range[1], range[2] do
			local kind, id, sub = E.Ask(GetActionInfo, slot)
			if kind == "spell" and Whole(id) and sub ~= "pet" and not seen[id] then
				seen[id] = true
				local name, text = SpellName(id), Subtext(id)
				local rank = RankNumber(text)
				if name and rank and not RankKept(id) then
					rows[#rows + 1] = { id = id, name = name, rank = rank, label = WithRank(name, text) }
				end
			end
		end
	end
	return Sorted(rows)
end

local function KeptRows()
	local rows = {}
	for id, on in pairs(Ranks() or {}) do
		if on == true and Whole(id) then
			rows[#rows + 1] = { id = id, name = SpellName(id) or ("Spell " .. id), rank = RankNumber(Subtext(id)) or 0, label = Label(id) }
		end
	end
	return Sorted(rows)
end

-- Kept ranks change only what is saved, so they work in a fight too.
local function KeepRank(id)
	local ranks = Ranks()
	if not ranks then
		return false, FAILED
	end
	local name = SpellName(id)
	if not name then
		return false, ('Flat UI: no spell found for "%s".'):format(tostring(id))
	end
	local label = Label(id)
	if ranks[id] == true then
		return false, ("Flat UI: %s is kept already."):format(label)
	end
	if not RankNumber(Subtext(id)) then
		return false, ("Flat UI: %s has no ranks."):format(name)
	end
	ranks[id] = true
	if Showing() then
		ScheduleRefresh()
	end
	return true, ("Flat UI: %s stays on your bars."):format(label)
end

local function UnkeepRank(id)
	local ranks = Ranks()
	local label = Label(id)
	if not ranks or ranks[id] ~= true then
		return false, ("Flat UI: %s is not kept."):format(label)
	end
	ranks[id] = nil
	Offer("released")
	return true, ("Flat UI: %s is replaced again when a higher rank is known."):format(label)
end

-- The panel calls these through a plain pcall; the work runs as a part of the module, so its errors count toward stopping the part.
local function Guarded(fn, ...)
	local ok, message = false, nil
	if not E.Run(part, function(...)
		ok, message = fn(...)
	end, ...) then
		return false, FAILED
	end
	return ok, message
end

function ns.ErrandsRankCandidates()
	local rows = {}
	E.Run(part, function()
		rows = Candidates()
	end)
	return rows
end

function ns.ErrandsRanksKept()
	local rows = {}
	E.Run(part, function()
		rows = KeptRows()
	end)
	return rows
end

function ns.ErrandsRankKeep(id)
	return Guarded(KeepRank, id)
end

function ns.ErrandsRankUnkeep(id)
	return Guarded(UnkeepRank, id)
end

function ns.ErrandsUprankLines()
	return { { 1, "Offer the new ranks now" } }
end

function ns.ErrandsUprankNow(id)
	if id ~= 1 then
		return false, nil
	end
	return Guarded(function()
		local why = Offer("asked")
		return why == nil, why and Answer(why) or nil
	end)
end

-- The ID of what was typed: a number, a shift-clicked spell link, or "spell:ID".
local function SpellId(text)
	text = tostring(text or ""):match("^%s*(.-)%s*$")
	local id = tonumber(text:match("^(%d+)$") or text:match("|Hspell:(%d+)") or text:match("spell:(%d+)"))
	return Whole(id) and id or nil
end

local function RankCommand(rest)
	if type(rest) ~= "string" or rest:match("^%s*$") then
		local labels = {}
		for _, row in ipairs(KeptRows()) do
			labels[#labels + 1] = row[2]
		end
		if #labels == 0 then
			return "Flat UI: no rank is kept, every lower rank is offered."
		end
		return ("Flat UI: ranks kept on your bars: %s."):format(Join(labels, #labels))
	end
	local id = SpellId(rest)
	if not id then
		return "Flat UI: name the rank with its spell link (shift-click it in your spell book) or its spell ID."
	end
	local _, message
	if RankKept(id) then
		_, message = UnkeepRank(id)
	else
		_, message = KeepRank(id)
	end
	return message
end

-- /flatui uprank: the line and its button now, whatever was declined. In a fight it comes after the fight.
E.slash.uprank = function()
	local _, message = ns.ErrandsUprankNow(1)
	if type(message) == "string" then
		print(message)
	end
end
-- /flatui rank: keep a rank, or stop keeping it; alone, the kept ranks.
E.slash.rank = function(rest)
	local message
	if not E.Run(part, function()
		message = RankCommand(rest)
	end) then
		message = FAILED
	end
	if type(message) == "string" then
		print(message)
	end
end
E.help[#E.help + 1] = "/flatui uprank - offer the new spell ranks for your bars now, with a button that reloads"
E.help[#E.help + 1] = "/flatui rank <spell> - keep that rank of a spell on your bars, or stop keeping it; shift-click it in your spell book to name it"

-- In a real session the line can only show when a click placed ranks and its reload did not come: /flatui taint may then name ActionButtonN.action.
ns.ClickPathReporter(function()
	if placedSession > 0 then
		return ("Click path: Flat UI put new ranks on %d action %s and no reload followed. /reload clears what that left."):format(placedSession,
			placedSession == 1 and "slot" or "slots")
	end
	return nil
end)

function part.Status()
	local lines = {}
	local on, mode = E.Opt("uprank") == true, E.Opt("learnedLines")
	local does = {}
	if on then
		local kept = 0
		for id, value in pairs(Ranks() or {}) do
			if value == true and Whole(id) then
				kept = kept + 1
			end
		end
		does[#does + 1] = kept > 0 and ("offers new ranks for your bars after training (%d kept)"):format(kept) or "offers new ranks for your bars after training"
	end
	if mode == "hide" then
		does[#does + 1] = "hides the lines about learned spells"
	elseif mode == "summary" then
		does[#does + 1] = "sums up the lines about learned spells"
	end
	if #does == 0 then
		return lines
	end
	lines[1] = "Spell ranks: " .. table.concat(does, ", ") .. "."
	if on and not Showing() then
		local waiting = #Plan()
		if waiting > 0 then
			lines[#lines + 1] = ("Spell ranks: %d %s can take a higher rank. /flatui uprank offers it."):format(waiting, Buttons(waiting))
		end
	end
	if lastUpranked and lastUpranked.count > 0 then
		local line = ("Spell ranks: put new ranks on %d %s at the last reload."):format(lastUpranked.count, Buttons(lastUpranked.count))
		if lastUpranked.kept > 0 then
			line = line .. (" The game kept the old rank on %d."):format(lastUpranked.kept)
		end
		lines[#lines + 1] = line
	elseif lastUpranked and lastUpranked.kept > 0 then
		lines[#lines + 1] = ("Spell ranks: the game kept the old rank on %d %s at the last reload."):format(lastUpranked.kept, Buttons(lastUpranked.kept))
	end
	if on then
		local missing = Unavailable()
		if missing == "client" then
			lines[#lines + 1] = "Spell ranks: this client cannot put spells on your bars, so new ranks are left to you."
		elseif missing == "book" then
			lines[#lines + 1] = "Spell ranks: the spell book cannot be read here, so new ranks are left to you."
		elseif broken then
			lines[#lines + 1] = "Spell ranks: the Uprank button could not be made, so new ranks are left to you."
		elseif E.Gamepad() then
			lines[#lines + 1] = "Spell ranks: no Uprank button while the gamepad interface is on."
		end
	end
	if mode ~= "game" then
		if not Registry() then
			lines[#lines + 1] = "Spell ranks: this client takes no chat filter from add-ons, so the lines about learned spells stay."
		elseif #Patterns() == 0 then
			lines[#lines + 1] = "Spell ranks: the game's words for learned spells are missing, so those lines stay."
		end
	end
	return lines
end
