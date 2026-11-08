local _, ns = ...

-- Errands of the game's popups (the StaticPopup dialogs), followed with hooksecurefunc on StaticPopup_Show and StaticPopup_Hide.
--
-- Hold a key to release: while the game's death popup (DEATH) shows where Release guard applies, a frame of the addon's own lies over its
-- Release Spirit button and takes the clicks, with the key to hold written on it, until the key is held (MODIFIER_STATE_CHANGED). Nothing of
-- the game's button changes: its alpha, its script and its state are as the game left them. The second button (a soulstone or a
-- reincarnation) is not covered, and neither are the game's own timer, a macro or a gamepad press. The cover fails open: it is made hidden,
-- and it stays laid (its OnUpdate looks every frame) only while the module and this part are on, the popup under it is still the death popup
-- and its button is shown. Every frame it also asks for the key: held, or not told, its mouse, shade and label are off and a click goes to
-- the game's button; not held, they are on. So a key-up the game did not report (a window change with Alt held) cannot leave the button
-- uncovered for the rest of that death. When the game does not say whether the key is held as the popup shows, there is no cover. Under
-- the gamepad interface, whose own press of the button no mouse cover can stop, there is no cover either.
-- Accept summons: CONFIRM_SUMMON is answered with C_SummonInfo.ConfirmSummon when the game's own popup would let you: not in a fight and while
-- PlayerCanTeleport, tried every second while the summon is open (time left and a summoner). The game does not close its summon popup after
-- an accept made by code, and a stale one cancels the next summon when the game reuses it; so once the game says the summon is no longer
-- open, the popup is hidden with StaticPopup_Hide, looked for every SUMMON_LOOK seconds for SUMMON_LOOKS tries, and only while it is the one
-- popup shown.
-- Accept resurrections: RESURRECT_REQUEST is answered with AcceptResurrect unless the one who offers it is in combat or dead (or the game does
-- not say), and only once the game's wait after recent deaths (GetCorpseRecoveryDelay) is over, while the request is still the same
-- (ResurrectGetOfferer).
-- The game's popups of a resurrection are left to the game, which closes them when you are alive again.
-- Type DELETE: the word the game asks for before it deletes a good item (DELETE_GOOD_ITEM and DELETE_GOOD_QUEST_ITEM) is written in its box,
-- whose focus is then cleared, so a click on Yes deletes and a stray Enter does not.
-- Buy with tokens without asking: the game's question before it takes items or currency for a purchase (CONFIRM_PURCHASE_TOKEN_ITEM,
-- Blizzard_StaticPopup_Game/GameDialogDefs.lua:383-399, shown from Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua:786-877) buys
-- BuyMerchantItem(MerchantFrame.itemIndex, MerchantFrame.count) on Yes; count may be nil, one purchase. The two fields are read, never written,
-- the popup is hidden with StaticPopup_Hide, and only once that hid it is the item bought with the same call: the popup has no OnUpdate that
-- closes it, so a purchase made first could leave its Yes up to buy again. One that also costs 150 gold or more (the price of
-- C_MerchantFrame.GetItemInfo for the count over its bundle, at or over MERCHANT_HIGH_PRICE_COST, MerchantFrame.lua:672) is left to the
-- player, since for an item with an extended cost the game never asks about its gold (MerchantFrame.lua:790-799, 836-876).
-- Sell loot still tradeable without asking: the game's question before it sells loot you could still trade (CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL,
-- GameDialogDefs.lua:2213-2231, shown on MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL, MerchantFrame.lua:110-112) sells the item on the cursor with
-- SellCursorItem while CursorHasItem plainly says it holds one; the popup is hidden after, and closes by itself once the cursor is empty (its
-- OnUpdate). Both act only on the one popup shown, while the merchant window is open and never in a fight; no button of a popup is clicked.
-- CONFIRM_HIGH_COST_ITEM and CONFIRM_ACCEPT_SOCKETS stay with the player.
-- These follow EnhanceQoL's popup helpers, adapted with the permission of its author. The two merchant answers follow EnhanceQoL by Philipp Barth
-- (R41Z0R), adapted with his permission (EnhanceQoL/EnhanceQoL.lua:3862-3866, 3912-3975).

local E = ns.Errands
local part = E.Part({ label = "Popups" })

-- Seconds between two tries of a summon that cannot be taken yet.
local SUMMON_RETRY = 1
-- After an accepted summon: how often, and how many times, the summon popup is looked at.
local SUMMON_LOOK, SUMMON_LOOKS = 0.1, 50
-- Seconds added to the game's wait before a resurrection is taken.
local RES_MARGIN = 0.2
local DELETE_WORDS = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }
-- The merchant's questions the two rows answer, and the row of each.
local CONFIRMS = { CONFIRM_PURCHASE_TOKEN_ITEM = "confirmTokens", CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL = "confirmTradeable" }
-- The gold from which a purchase is left to the player, when the game does not say (MERCHANT_HIGH_PRICE_COST, MerchantFrame.lua:672).
local HIGH_COST = 1500000
local KEYS = {
	shift = { label = "Shift", down = function() return IsShiftKeyDown end },
	ctrl = { label = "Ctrl", down = function() return IsControlKeyDown end },
	alt = { label = "Alt", down = function() return IsAltKeyDown end },
}

local followed = false
-- The game says the release button is protected, so it takes no cover.
local protectedButton = false
-- Per release button of a popup: the cover laid over it, and the popup it belongs to.
local covers, coverPopup = {}, {}
-- The summon being tried: counts up at each new summon, so a try of an older one stops.
local summon = 0
local resurrection = 0
-- What /flatui status says.
local lastAccepted
-- Notes said once: a popup whose button or box was not found.
local missed = {}

local Field = E.PopupField
local Popups = E.Popups

local function Usable(frame)
	return type(frame) == "table" and not ns.Forbidden(frame) and frame or nil
end

-- The first button of a popup, by its global name (StaticPopup1Button1) or its key.
local function FirstButton(popup)
	local button = Usable(_G[popup.name .. "Button1"]) or Usable(Field(popup.frame, "button1")) or Usable(Field(popup.frame, "Button1"))
	if not button then
		local container = Field(popup.frame, "ButtonContainer")
		if type(container) == "table" then
			local list = Field(container, "Buttons")
			button = Usable(Field(container, "Button1")) or (type(list) == "table" and Usable(Field(list, 1))) or nil
		end
	end
	return button
end

local function EditBoxOf(popup)
	return Usable(_G[popup.name .. "EditBox"]) or Usable(Field(popup.frame, "editBox")) or Usable(Field(popup.frame, "EditBox"))
end

-- Keeps for /flatui status that a part of a popup was not found, so its errand cannot be done on this client.
local function Missed(what)
	if not missed[what] then
		missed[what] = true
		missed[#missed + 1] = ("Popups: %s not found, so it is left as the game has it."):format(what)
	end
end

-- Release guard -----------------------------------------------------------------------------------------------------------------------------

local function Key()
	return KEYS[E.Opt("releaseKey")] or KEYS.shift
end

-- Whether the key is held: true or false, or nil when the game does not say (no function, an error, a withheld answer).
local function KeyState()
	local fn = Key().down()
	if type(fn) ~= "function" then
		return nil
	end
	local ok, down = pcall(fn)
	if not ok or ns.IsSecret(down) then
		return nil
	end
	return down == true or down == 1
end

-- Whether the guard applies where you are: everywhere, or in dungeons and raids. Never under the gamepad interface.
local function Guarded()
	if E.Gamepad() then
		return false
	end
	local where = E.Opt("releaseGuard")
	if where == "always" then
		return true
	elseif where ~= "instances" then
		return false
	end
	local inside, kind = E.Ask(IsInInstance)
	return inside == true and (kind == "party" or kind == "raid")
end

-- Whether a cover may stay laid: read by the cover itself, outside the part, so a stopped part cannot leave it over another popup.
local function CoverWanted(button)
	local popup = coverPopup[button]
	return ns.Enabled("errands") and not ns.PartStopped("errands", part.label) and popup ~= nil and E.Shown(popup)
		and Field(popup, "which") == "DEATH" and E.Shown(button) and Guarded()
end

-- The cover takes clicks only while the game says the key is not held; held, or not told, a click goes to the game's button.
local function Arm(cover, held)
	local armed = held == false
	cover:EnableMouse(armed)
	if cover.shade then
		cover.shade:SetShown(armed)
	end
	if cover.label then
		cover.label:SetShown(armed)
	end
end

local function Cover(button)
	local cover = covers[button]
	if cover then
		return cover
	end
	if ns.MaybeProtected and ns.MaybeProtected(button) then
		protectedButton = true
		return nil
	end
	-- Above the button, or not at all: a cover under it would take no click.
	local ok, level = pcall(button.GetFrameLevel, button)
	if not ok or type(level) ~= "number" or ns.IsSecret(level) then
		return nil
	end
	cover = CreateFrame("Frame", nil, button)
	ns.Own[cover] = true
	cover:Hide()
	cover:SetAllPoints(button)
	cover:SetFrameLevel(level + 5)
	-- The shade under the label: a lower layer, so the words are always drawn over it.
	local shade = cover:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[shade] = true
	shade:SetAllPoints(cover)
	shade:SetColorTexture(0, 0, 0, 0.7)
	local label = ns.OwnText(cover, "OVERLAY", "GameFontHighlightSmall")
	if label then
		label:SetPoint("CENTER", cover, "CENTER", 0, 0)
	end
	cover.shade, cover.label = shade, label
	cover:EnableMouse(true)
	-- The clicks the cover takes do nothing.
	cover:SetScript("OnMouseDown", function() end)
	cover:SetScript("OnMouseUp", function() end)
	cover:SetScript("OnUpdate", function()
		local ok, wanted = pcall(CoverWanted, button)
		if not ok or not wanted then
			cover:Hide()
			return
		end
		Arm(cover, KeyState())
	end)
	covers[button] = cover
	return cover
end

local function HideCovers()
	for _, cover in pairs(covers) do
		cover:Hide()
	end
end

-- Lays the cover over the release button of a shown death popup, or takes it away; called on every show and hide of a popup and when a key
-- goes down or up.
local function GuardNow()
	local wanted = ns.Enabled("errands") and Guarded()
	local held
	if wanted then
		held = KeyState()
	end
	local seen = {}
	for _, popup in ipairs(Popups()) do
		if popup.which == "DEATH" and wanted and held ~= nil then
			local button = FirstButton(popup)
			if not button then
				Missed("the Release Spirit button of the death popup")
			elseif E.Shown(button) then
				seen[button] = true
				coverPopup[button] = popup.frame
				local cover = Cover(button)
				if cover then
					if cover.label then
						cover.label:SetText(("Hold %s to release"):format(Key().label))
					end
					cover:Show()
					Arm(cover, held)
				end
			end
		end
	end
	for button, cover in pairs(covers) do
		if not seen[button] then
			cover:Hide()
		end
	end
end

-- A pass that fails takes every cover away before the error goes on.
local function Guard()
	local ok, err = pcall(GuardNow)
	if not ok then
		HideCovers()
		error(err, 0)
	end
end

-- Type DELETE -------------------------------------------------------------------------------------------------------------------------------

local function FillDelete()
	if not E.On("deleteWord") then
		return
	end
	local word = DELETE_ITEM_CONFIRM_STRING
	if type(word) ~= "string" or ns.IsSecret(word) or word == "" then
		return
	end
	for _, popup in ipairs(Popups()) do
		if DELETE_WORDS[popup.which] then
			local box = EditBoxOf(popup)
			if not box then
				Missed("the box of the delete popup")
			else
				-- Only an empty box: the game empties it when the popup shows, and what the player typed is never written over.
				local ok, text = pcall(box.GetText, box)
				if ok and not ns.IsSecret(text) and text == "" and pcall(box.SetText, box, word) then
					-- No focus, so a stray Enter does not delete: a click on Yes does.
					pcall(box.ClearFocus, box)
				end
			end
		end
	end
end

-- Buy with tokens and Sell loot still tradeable without asking ------------------------------------------------------------------------------

local function HighCost()
	local n = MERCHANT_HIGH_PRICE_COST
	return ns.Finite(n) and n > 0 and n or HIGH_COST
end

-- The token popup: the item it names is bought once the popup is hidden, unless its gold reaches HighCost or anything about it is unclear.
local function BuyTokens(popup)
	local frame = MerchantFrame
	local index, count = Field(frame, "itemIndex"), Field(frame, "count")
	if not ns.Finite(index) or index < 1 or (count ~= nil and (not ns.Finite(count) or count < 1)) then
		return
	end
	-- The popup's data names the item the game asked about (MerchantFrame.lua:856-877): a field left from an older question is no answer.
	local data = Field(popup.frame, "data")
	if type(data) == "table" then
		local named = Field(data, "index")
		if named ~= nil and named ~= index then
			return
		end
	end
	local info = type(C_MerchantFrame) == "table" and E.Ask(C_MerchantFrame.GetItemInfo, index) or nil
	if type(info) ~= "table" then
		return
	end
	local price, bundle = Field(info, "price"), Field(info, "stackCount")
	if not ns.Finite(price) or price < 0 or not ns.Finite(bundle) or bundle < 1 then
		return
	end
	local items = count or bundle
	if price * items / bundle >= HighCost() then
		return
	end
	local link = E.Ask(GetMerchantItemLink, index)
	if type(BuyMerchantItem) ~= "function" or not E.HideAlone(popup.which) then
		return
	end
	if not E.Call(BuyMerchantItem, index, count) then
		return
	end
	local what = (items > 1 and (items .. " ") or "") .. (type(link) == "string" and link ~= "" and link or "the item")
	lastAccepted = "a purchase of " .. what
	E.Say(("Bought %s with items or currency."):format(what))
end

-- The question before a sale of loot you could still trade: the item on the cursor is sold, then the popup hidden.
local function SellTradeable(popup)
	if type(SellCursorItem) ~= "function" or E.Ask(CursorHasItem) ~= true then
		return
	end
	local kind, _, link = E.Ask(GetCursorInfo)
	if not E.Call(SellCursorItem) then
		return
	end
	E.HideAlone(popup.which)
	local what = kind == "item" and type(link) == "string" and link ~= "" and link or "the item"
	lastAccepted = "the sale of " .. what
	E.Say(("Sold %s, which you could still have traded."):format(what))
end

-- Only the one popup shown, only while the merchant window is open, never in a fight.
local function Confirm()
	local shown = Popups()
	if #shown ~= 1 then
		return
	end
	local popup = shown[1]
	local row = CONFIRMS[popup.which]
	if not row or not E.On(row) or E.Fighting() or not E.Shown(MerchantFrame) then
		return
	end
	if popup.which == "CONFIRM_PURCHASE_TOKEN_ITEM" then
		BuyTokens(popup)
	else
		SellTradeable(popup)
	end
end

local function PopupShown()
	Guard()
	FillDelete()
	Confirm()
end

local function OnShow()
	if ns.PartStopped("errands", part.label) then
		HideCovers()
		return
	end
	E.Run(part, PopupShown)
end

local function OnHide()
	if ns.PartStopped("errands", part.label) then
		HideCovers()
		return
	end
	E.Run(part, Guard)
end

-- Each follow is made once (ns.FollowGlobal skips a function it already has), and tried again until both are in.
local function Follow()
	if followed then
		return
	end
	local shown = ns.FollowGlobal("StaticPopup_Show", OnShow)
	local hidden = ns.FollowGlobal("StaticPopup_Hide", OnHide)
	followed = shown == true and hidden == true
end

-- Summons -----------------------------------------------------------------------------------------------------------------------------------

-- The summon that is open: its summoner, or nil when none is (no time left, or no summoner).
local function OpenSummon()
	local info = C_SummonInfo
	if type(info) ~= "table" then
		return nil
	end
	local left, who = E.Ask(info.GetSummonConfirmTimeLeft), E.Ask(info.GetSummonConfirmSummoner)
	if type(left) ~= "number" or left <= 0 or type(who) ~= "string" or who == "" then
		return nil
	end
	return who
end

-- After an accepted summon: once the game says it is no longer open, its popup is hidden, which runs no OnCancel; a newer summon stops the look.
local function CloseSummon(at, tries)
	if at ~= summon then
		return
	end
	if OpenSummon() == nil then
		-- Only while it is the one popup shown; beside another one it is left to run out (E.HideAlone).
		E.HideAlone("CONFIRM_SUMMON")
		return
	end
	if tries > 1 then
		C_Timer.After(SUMMON_LOOK, function()
			E.Run(part, CloseSummon, at, tries - 1)
		end)
	end
end

local function TrySummon(at)
	if at ~= summon or E.Opt("summons") ~= true or not ns.Enabled("errands") then
		return
	end
	local info = C_SummonInfo
	if type(info) ~= "table" or type(info.ConfirmSummon) ~= "function" then
		return
	end
	local who = OpenSummon()
	if not who then
		return
	end
	-- The game's own popup keeps Accept off in a fight and while you cannot be teleported (on a flight path): try again in a moment.
	if E.Fighting() or (type(PlayerCanTeleport) == "function" and E.Ask(PlayerCanTeleport) ~= true) then
		C_Timer.After(SUMMON_RETRY, function()
			E.Run(part, TrySummon, at)
		end)
		return
	end
	local where = E.Ask(info.GetSummonConfirmAreaName)
	if not E.Call(info.ConfirmSummon) then
		return
	end
	local text = "Accepted a summon from " .. who
	if type(where) == "string" and where ~= "" then
		text = text .. " to " .. where
	end
	lastAccepted = "a summon from " .. who
	E.Say(text .. ".")
	C_Timer.After(SUMMON_LOOK, function()
		E.Run(part, CloseSummon, at, SUMMON_LOOKS)
	end)
end

-- Resurrections -----------------------------------------------------------------------------------------------------------------------------

-- The unit of the one who offers a resurrection: a unit token, or a name looked for in the group.
local function UnitOf(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if E.Ask(UnitExists, name) == true then
		return name
	end
	local function Is(unit)
		local own, realm = E.Ask(UnitName, unit)
		if type(own) ~= "string" then
			return false
		end
		return name == own or (type(realm) == "string" and realm ~= "" and name == own .. "-" .. realm)
	end
	local raid = E.Ask(IsInRaid) == true
	local count = raid and E.Ask(GetNumGroupMembers) or E.Ask(GetNumSubgroupMembers)
	for index = 1, type(count) == "number" and count or 0 do
		local unit = (raid and "raid" or "party") .. index
		if Is(unit) then
			return unit
		end
	end
	return nil
end

-- again: a try after the game's wait, which needs the request to be still the same one.
local function TryResurrection(at, offerer, again)
	if at ~= resurrection or E.Opt("resurrect") ~= true or not ns.Enabled("errands") then
		return
	end
	-- Only the same request: a newer one, or none at all, leaves this one. The first try may go on when the game does not say: the event
	-- itself says the offer is open.
	local now = type(ResurrectGetOfferer) == "function" and E.Ask(ResurrectGetOfferer) or nil
	if again and now ~= offerer then
		return
	elseif now ~= nil and now ~= offerer then
		return
	end
	local unit = UnitOf(offerer)
	if unit and (E.Ask(UnitAffectingCombat, unit) ~= false or E.Ask(UnitIsDeadOrGhost, unit) ~= false) then
		return
	end
	-- Nothing to accept unless you are dead or a ghost.
	if E.Ask(UnitIsDeadOrGhost, "player") ~= true then
		return
	end
	-- The game greys Accept while its wait after recent deaths runs: take it once the wait is over, if the game can then say the request
	-- is still the same.
	local wait = E.Ask(GetCorpseRecoveryDelay)
	if type(wait) == "number" and wait > 0 then
		if type(ResurrectGetOfferer) == "function" then
			C_Timer.After(wait + RES_MARGIN, function()
				E.Run(part, TryResurrection, at, offerer, true)
			end)
		end
		return
	end
	if not E.Call(AcceptResurrect) then
		return
	end
	local named = type(offerer) == "string" and offerer ~= ""
	lastAccepted = named and ("a resurrection from " .. offerer) or "a resurrection"
	E.Say(named and ("Accepted a resurrection from %s."):format(offerer) or "Accepted a resurrection.")
end

E.Listen(part, "CONFIRM_SUMMON", function()
	summon = summon + 1
	if E.Opt("summons") == true then
		local at = summon
		C_Timer.After(0, function()
			if ns.Enabled("errands") then
				E.Run(part, TrySummon, at)
			end
		end)
	end
end)
E.Listen(part, "CANCEL_SUMMON", function()
	summon = summon + 1
end)
E.Listen(part, "RESURRECT_REQUEST", function(offerer)
	resurrection = resurrection + 1
	if E.Opt("resurrect") == true and not ns.IsSecret(offerer) then
		TryResurrection(resurrection, offerer)
	end
end)
E.Listen(part, "MODIFIER_STATE_CHANGED", Guard)
E.Listen(part, "INPUT_DEVICE_INTERFACE_TRANSITION", Guard)
-- A backstop: the death popup shows on PLAYER_DEAD, and a pass a frame later lays the cover even if a follow was missed.
E.Listen(part, "PLAYER_DEAD", function()
	C_Timer.After(0, function()
		if ns.Enabled("errands") then
			E.Run(part, Guard)
		end
	end)
end)

-- A summon or a resurrection still open at the start (after a /reload, whose loading screen sends neither event again) is tried once.
function part.Start()
	Follow()
	Guard()
	if E.Opt("summons") == true and OpenSummon() then
		summon = summon + 1
		local at = summon
		C_Timer.After(0, function()
			E.Run(part, TrySummon, at)
		end)
	end
	local offerer = type(ResurrectGetOfferer) == "function" and E.Ask(ResurrectGetOfferer) or nil
	if E.Opt("resurrect") == true and type(offerer) == "string" and offerer ~= "" then
		resurrection = resurrection + 1
		TryResurrection(resurrection, offerer)
	end
end

function part.Refresh()
	Follow()
	if not ns.Enabled("errands") then
		HideCovers()
		return
	end
	Guard()
end

function part.Status()
	local does = {}
	local where = E.Opt("releaseGuard")
	if where == "always" or where == "instances" then
		does[#does + 1] = ("hold %s to release%s"):format(Key().label, where == "instances" and " in dungeons and raids" or "")
	end
	if E.Opt("summons") == true then
		does[#does + 1] = "accepts summons"
	end
	if E.Opt("resurrect") == true then
		does[#does + 1] = "accepts resurrections"
	end
	if E.Opt("deleteWord") == true then
		does[#does + 1] = "types DELETE"
	end
	if E.Opt("confirmTokens") == true then
		does[#does + 1] = "buys with tokens without asking"
	end
	if E.Opt("confirmTradeable") == true then
		does[#does + 1] = "sells loot still tradeable without asking"
	end
	if #does == 0 then
		return {}
	end
	local line = "Popups: " .. table.concat(does, ", ") .. "."
	if lastAccepted then
		line = line .. " Last accepted " .. lastAccepted .. "."
	end
	local lines = { line }
	if (where == "always" or where == "instances") and E.Gamepad() then
		lines[#lines + 1] = "Popups: Hold a key to release does not apply under the gamepad interface."
	elseif (where == "always" or where == "instances") and KeyState() == nil then
		lines[#lines + 1] = ("Popups: Release Spirit is not covered: the game does not say whether %s is held."):format(Key().label)
	elseif (where == "always" or where == "instances") and protectedButton then
		lines[#lines + 1] = "Popups: Release Spirit is not covered: the game says its button is protected."
	end
	for _, line in ipairs(missed) do
		lines[#lines + 1] = line
	end
	return lines
end
