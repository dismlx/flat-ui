local _, ns = ...

local E = ns.Errands
local part = E.Part({ label = "Spell ranks" })

local SLOT_RANGES = { { 1, 120 }, { 145, 180 } }
local function PageSet(slot)
	if slot >= 73 and slot <= 120 then
		return math.floor((slot - 73) / 12) + 1
	end
	return 0
end
local OFFER_WAIT = 1.5
local WATCH, WATCH_MOST = 1, 600
local REFRESH = 0.2
local SUMMARY_WAIT = 2
local AFTER_RELOAD = 1
local CHAT_NAMES, NOTICE_NAMES, TIP_SPELLS, NOTE_NAMES, LEFT_NAMES = 4, 2, 8, 3, 4
local NOTICE_WIDTH, NOTICE_HEIGHT, NOTICE_Y = 360, 30, -186
local MOVER = "FlatUIUprankNotice"
local SAMPLE_TEXT = "New ranks for 3 buttons: Frostbolt, Fireball and 1 more."
local UPRANK_WIDTH, LATER_WIDTH, GAP = 124, 60, 4
local MAX_RANK = 1000
local LINES = { "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S", "ERR_SPELL_UNLEARNED_S" }
local FAILED = "Flat UI: Spell ranks failed. /flatui status shows why."
local MACRO = "/stopmacro [combat]\n/reload"

local notice
local broken = false
local sample = false
local hideQueued = false
local swapping, touched = false, false
local placedSession = 0
local learnedAt, watching, looks, watchToken = nil, false, 0, 0
local suspended, queued
local refreshToken = 0
local lastUpranked
local afterDone = false
local wasOn = false
local filtering = false
local patterns
local heard = { learned = {}, unlearned = {}, seen = {}, token = 0 }

local HideNotice, ShowNotice, ScheduleRefresh, Explain, Usable, Offer, Filter, PreClick, PostClick

local function Whole(v)
	return ns.Finite(v) and v > 0 and v % 1 == 0
end

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

local function WithRank(name, text)
	if type(text) == "string" and text ~= "" then
		return name .. " (" .. text .. ")"
	end
	return name
end

local function Label(id)
	local name = SpellName(id)
	if not name then
		return "Spell " .. tostring(id)
	end
	return WithRank(name, Subtext(id))
end

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

local function Book()
	local book = C_SpellBook
	if type(book) == "table" and type(book.GetNumSpellBookSkillLines) == "function" and type(book.GetSpellBookSkillLineInfo) == "function"
		and type(book.GetSpellBookItemInfo) == "function" and type(Enum) == "table" and type(Enum.SpellBookSpellBank) == "table"
		and type(Enum.SpellBookItemType) == "table" then
		return book
	end
	return nil
end

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

local function Pickups()
	return (type(C_Spell) == "table" and type(C_Spell.PickupSpell) == "function") or type(PickupSpell) == "function"
		or (type(C_SpellBook) == "table" and type(C_SpellBook.PickupSpellBookItem) == "function")
end

local function Placer()
	if type(PlaceAction) == "function" then
		return PlaceAction
	elseif type(C_ActionBar) == "table" and type(C_ActionBar.PutActionInSlot) == "function" then
		return C_ActionBar.PutActionInSlot
	end
	return nil
end

local function Unavailable()
	if not Book() or type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" or type(C_Spell.GetSpellSubtext) ~= "function" then
		return "book"
	end
	if type(GetActionInfo) ~= "function" or not Pickups() or not Placer() or type(GetCursorInfo) ~= "function" or type(ClearCursor) ~= "function" then
		return "client"
	end
	return nil
end

local function Plan()
	local plan, left = {}, {}
	if Unavailable() then
		return plan, left
	end
	local best = Best()
	if next(best) == nil then
		return plan, left
	end
	local held, high = {}, {}
	for _, range in ipairs(SLOT_RANGES) do
		for slot = range[1], range[2] do
			local kind, id, sub = E.Ask(GetActionInfo, slot)
			if kind == "spell" and Whole(id) and sub ~= "pet" then
				local name = SpellName(id)
				local top = name and best[name]
				if top and not top.tie then
					local isTop = id == top.id or id == top.base
					local text = isTop and top.text or Subtext(id)
					local rank = isTop and top.rank or RankNumber(text)
					if rank then
						local set = PageSet(slot)
						high[set] = high[set] or {}
						held[#held + 1] = { slot = slot, set = set, id = id, name = name, rank = rank, text = text, top = top }
						high[set][name] = math.max(high[set][name] or 0, rank)
					end
				end
			end
		end
	end
	for _, h in ipairs(held) do
		local top = h.top
		if h.rank < top.rank and not RankKept(h.id) then
			if h.rank == high[h.set][h.name] then
				plan[#plan + 1] = { slot = h.slot, old = h.id, new = top.id, base = top.base, bookSlot = top.bookSlot, name = h.name,
					from = h.rank, to = top.rank, fromText = h.text, toText = top.text }
			else
				left[#left + 1] = h
			end
		end
	end
	return plan, left
end

local function Signature(plan)
	local parts = {}
	for _, item in ipairs(plan) do
		parts[#parts + 1] = item.slot .. ":" .. item.new
	end
	return table.concat(parts, ",")
end

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
	elseif #E.Popups() > 0 then
		return "popup"
	elseif type(ns.EditModeOpen) == "function" and ns.EditModeOpen() then
		return "editmode"
	elseif E.Ask(KeybindFrames_InQuickKeybindMode) == true then
		return "keybind"
	end
	return nil
end

local ANSWER = {
	client = "Flat UI: this client cannot put spells on your bars.",
	book = "Flat UI: the spell book cannot be read here.",
	button = "Flat UI: the Uprank button could not be made here.",
	gamepad = "Flat UI: the Uprank button cannot be reached under the gamepad interface. Drag new ranks from the spell book.",
	fight = "Flat UI: not in a fight. The line comes back after it.",
	cursor = "Flat UI: put down what the cursor holds first.",
	popup = "Flat UI: answer the game's popup first.",
	editmode = "Flat UI: close Edit Mode first.",
	keybind = "Flat UI: close the quick keybind mode first.",
	nothing = "Flat UI: no button on your bars needs a new rank.",
}

local function Answer(why)
	if why == "off" then
		if not ns.Enabled("errands") then
			return "Flat UI: Errands is off. Tick Run errands on the Errands page."
		end
		return "Flat UI: Put new ranks on your bars is off on the Quests and levelling tab of the Errands page."
	end
	return ANSWER[why]
end

local function Showing()
	return notice ~= nil and not sample and E.Shown(notice.frame)
end

local function Place(frame)
	if not frame or E.InCombat() then
		return
	end
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "TOP")
	end
	frame:ClearAllPoints()
	if ns.Finite(x) and ns.Finite(y) then
		frame:SetPoint("TOP", UIParent, "BOTTOMLEFT", x, y)
	else
		frame:SetPoint("TOP", UIParent, "TOP", 0, NOTICE_Y)
	end
end

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
	pcall(function()
		local level = notice.uprank:GetFrameLevel()
		if ns.Finite(level) then
			notice.overlay:SetFrameLevel(level + 2)
		end
	end)
end

local function Keep()
	return Wanted() and not E.Gamepad()
end

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
		Place(frame)
		frame:SetFrameStrata("DIALOG")
		pcall(frame.SetClampedToScreen, frame, true)
		local outline = ns.Outline(frame, frame, true)
		if outline then
			ns.SetOutlineFill(outline, 0.09, 0.09, 0.09, 0.95)
		end
		local text = ns.OwnText(frame, "OVERLAY", "GameFontHighlight")
		text:SetPoint("LEFT", frame, "LEFT", 10, 0)
		local uprank = E.Button(frame, "Uprank and reload", UPRANK_WIDTH, function()
			print("Flat UI: the Uprank button is not ready. Try again in a moment.")
		end, function(owner)
			E.Run(part, Explain, owner)
		end)
		uprank:SetPoint("RIGHT", frame, "RIGHT", -GAP, 0)
		local later = E.Button(frame, "Later", LATER_WIDTH, function()
			E.Run(part, function()
				if not sample then
					SetLater(Signature(Plan()))
				end
				HideNotice()
			end)
		end)
		later:SetPoint("RIGHT", uprank, "LEFT", -GAP, 0)
		local overlay = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
		ns.Own[overlay] = true
		overlay:Hide()
		overlay:SetFrameStrata("DIALOG")
		overlay:RegisterForClicks("LeftButtonUp")
		overlay:SetAttribute("type", "macro")
		overlay:SetAttribute("macrotext", MACRO)
		overlay:SetAttribute("useOnKeyDown", false)
		overlay:SetScript("PreClick", PreClick)
		overlay:SetScript("PostClick", PostClick)
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

function ns.ErrandsRanksNotice()
	return notice
end

Usable = function()
	if notice and not swapping then
		notice.uprank.SetUsable(not sample and Refusal() == nil)
	end
end

local function Fit()
	local okWidth, width = pcall(notice.text.GetStringWidth, notice.text)
	if okWidth and ns.Finite(width) then
		notice.frame:SetWidth(math.max(NOTICE_WIDTH, math.ceil(width) + UPRANK_WIDTH + LATER_WIDTH + 30))
	end
end

ShowNotice = function(plan)
	if E.InCombat() or not Build() then
		return false
	end
	sample = false
	local n = #plan
	notice.text:SetText(("New ranks for %d %s: %s."):format(n, Buttons(n), Join(UniqueNames(plan), NOTICE_NAMES)))
	Fit()
	Place(notice.frame)
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
	if sample then
		sample = false
		notice.frame:Hide()
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

local function SampleOn()
	if sample or Showing() or not Wanted() or E.Gamepad() or E.InCombat() or not Build() then
		return
	end
	sample = true
	notice.text:SetText(SAMPLE_TEXT)
	Fit()
	Place(notice.frame)
	notice.uprank.SetUsable(false)
	notice.frame:Show()
end

local function SampleOff()
	if sample and notice then
		sample = false
		notice.frame:Hide()
	end
end

if type(ns.TestMode) == "table" and type(ns.TestMode.Register) == "function" then
	ns.TestMode.Register("errandsuprank", { module = "errands", label = "New spell ranks", Start = function()
		E.Run(part, SampleOn)
	end, Stop = function()
		E.Run(part, SampleOff)
	end })
end

function ns.ErrandsUprankShown()
	return E.On("uprank")
end

function ns.ErrandsUprankMoved()
	if not notice then
		return
	end
	if E.InCombat() then
		ns.OutOfCombat(function()
			if notice then
				Place(notice.frame)
			end
		end)
		return
	end
	Place(notice.frame)
end

local function Sentence(line)
	local text = line:gsub("^Flat UI: ", "")
	return text:sub(1, 1):upper() .. text:sub(2)
end

Explain = function(owner)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	Usable()
	tip:SetOwner(owner, "ANCHOR_BOTTOM", 0, -4)
	tip:SetText("Uprank and reload")
	if sample then
		tip:AddLine("A sample of test mode. After training, this line names the buttons that hold a lower rank, and this button puts the new ranks "
			.. "on them and reloads.", 1, 1, 1, true)
		tip:Show()
		return
	end
	local plan, left = Plan()
	local function Line(text)
		tip:AddLine(text, 1, 1, 1, true)
	end
	local order, byName = {}, {}
	for _, item in ipairs(plan) do
		local key = item.name .. "\0" .. item.from
		local entry = byName[key]
		if not entry then
			entry = { item = item, count = 0 }
			byName[key] = entry
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
	local lower, seen = {}, {}
	for _, h in ipairs(left) do
		local label = WithRank(h.name, h.text)
		if not seen[label] then
			seen[label] = true
			lower[#lower + 1] = label
		end
	end
	if #lower > 0 then
		Line(("Left, since a higher rank of the spell is on your bars too: %s."):format(Join(lower, LEFT_NAMES)))
	end
	Line("The interface reloads in the same click, so the game's bars stay clean.")
	Line("Macros, items and the ranks you keep stay as they are.")
	local why = Refusal()
	if why and Answer(why) then
		Line(Sentence(Answer(why)))
	end
	tip:Show()
end

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

E.PickupSpell, E.Placer, E.CursorBusy = Pickup, Placer, Busy

local function CursorSpell(item)
	local ok, kind, _, _, id = pcall(GetCursorInfo)
	if not ok or ns.IsSecret(kind) or ns.IsSecret(id) or kind ~= "spell" then
		return false
	end
	return id == item.new or id == item.base
end

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
			if kind == "spell" and id == item.old then
				touched = true
				if Pickup(item) and CursorSpell(item) then
					E.Call(Placer(), item.slot)
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

PreClick = function(self)
	touched = false
	local go = false
	E.Run(part, function()
		go = Uprank()
	end)
	if touched then
		go = true
	end
	if not go and not E.InCombat() then
		pcall(self.SetAttribute, self, "type", nil)
	end
end

PostClick = function(self)
	if not E.InCombat() then
		pcall(self.SetAttribute, self, "type", "macro")
	end
	if type(C_Timer) == "table" then
		pcall(C_Timer.After, 0, function()
			E.Run(part, ScheduleRefresh)
		end)
	end
end

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
			line = line .. (" The game kept the old rank on %d. /flatui uprank tries again."):format(kept)
		end
		E.Say(line)
	elseif kept > 0 then
		E.Say(("The game kept the old rank on %d %s. /flatui uprank tries again."):format(kept, Buttons(kept)))
	end
	if kept > 0 then
		SetLater(Signature(Plan()))
	end
end

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
	if #parts > 0 and ns.Enabled("errands") and E.Opt("learnedLines") == "summary" then
		E.Say(table.concat(parts, " "))
	end
end

local function WithLinkRank(what)
	local id = tonumber(what:match("|Hspell:(%d+)"))
	if not Whole(id) then
		return what
	end
	local shown = what:match("|h(.-)|h") or what
	if shown:find("%d") then
		return what
	end
	local text = Subtext(id)
	if RankNumber(text) then
		return what .. " (" .. text .. ")"
	end
	return what
end

local function Heard(what, unlearned, lineID, msg)
	local key = Whole(lineID) and lineID or (msg .. "@" .. tostring(E.Ask(GetTime)))
	if heard.seen[key] then
		return
	end
	heard.seen[key] = true
	what = WithLinkRank(what)
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

local function Drop(msg, lineID)
	if not ns.Enabled("errands") or ns.PartStopped("errands", part.label) then
		return false
	end
	local mode = E.Opt("learnedLines")
	if mode ~= "hide" and mode ~= "summary" then
		return false
	end
	if mode == "summary" and E.Opt("chat") == false then
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

Filter = function(_, _, msg, _, _, _, _, _, _, _, _, _, lineID)
	local drop = false
	E.Run(part, function()
		drop = Drop(msg, lineID)
	end)
	return drop
end

local function Registry()
	if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.AddMessageEventFilter) == "function" and type(ChatFrameUtil.RemoveMessageEventFilter) == "function" then
		return ChatFrameUtil.AddMessageEventFilter, ChatFrameUtil.RemoveMessageEventFilter
	end
	if type(ChatFrame_AddMessageEventFilter) == "function" and type(ChatFrame_RemoveMessageEventFilter) == "function" then
		return ChatFrame_AddMessageEventFilter, ChatFrame_RemoveMessageEventFilter
	end
	return nil
end

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

for _, event in ipairs({ "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB" }) do
	E.Listen(part, event, Learned)
end
E.Listen(part, "TRAINER_CLOSED", function()
	if learnedAt then
		Watch(true)
	end
end)
E.Listen(part, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
	local trainer = type(Enum) == "table" and type(Enum.PlayerInteractionType) == "table" and Enum.PlayerInteractionType.Trainer or nil
	if learnedAt and trainer ~= nil and not ns.IsSecret(kind) and kind == trainer then
		Watch(true)
	end
end)
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
			return "Flat UI: no rank is kept, so the highest rank of each spell on your bars is offered when you learn a higher one."
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

E.slash.uprank = function()
	local _, message = ns.ErrandsUprankNow(1)
	if type(message) == "string" then
		print(message)
	end
end
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
	local dropping = mode == "hide" or (mode == "summary" and E.Opt("chat") ~= false)
	if mode == "hide" then
		does[#does + 1] = "hides the lines about learned spells"
	elseif dropping then
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
	if dropping then
		if not Registry() then
			lines[#lines + 1] = "Spell ranks: this client takes no chat filter from add-ons, so the lines about learned spells stay."
		elseif #Patterns() == 0 then
			lines[#lines + 1] = "Spell ranks: the game's words for learned spells are missing, so those lines stay."
		end
	end
	return lines
end
