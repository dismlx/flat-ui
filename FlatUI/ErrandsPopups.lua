local _, ns = ...

local E = ns.Errands
local part = E.Part({ label = "Popups" })

local SUMMON_RETRY = 1
local SUMMON_LOOK, SUMMON_LOOKS = 0.1, 50
local RES_MARGIN = 0.2
local RELEASE_WAIT, RELEASE_TRIES = 0.5, 20
local DELETE_WORDS = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }
local CONFIRMS = { CONFIRM_PURCHASE_TOKEN_ITEM = "confirmTokens", CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL = "confirmTradeable" }
local HIGH_COST = 1500000
local KEYS = {
	shift = { label = "Shift", down = function() return IsShiftKeyDown end },
	ctrl = { label = "Ctrl", down = function() return IsControlKeyDown end },
	alt = { label = "Alt", down = function() return IsAltKeyDown end },
}

local followed = false
local protectedButton = false
local covers, coverPopup = {}, {}
local summon = 0
local resurrection = 0
local release = { deaths = 0 }
local lastAccepted
local missed = {}

local Field = E.PopupField
local Popups = E.Popups

local function Usable(frame)
	return type(frame) == "table" and not ns.Forbidden(frame) and frame or nil
end

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

local function Missed(what)
	if not missed[what] then
		missed[what] = true
		missed[#missed + 1] = ("Popups: %s not found, so it is left as the game has it."):format(what)
	end
end

local function Key()
	return KEYS[E.Opt("releaseKey")] or KEYS.shift
end

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

local function CoverWanted(button)
	local popup = coverPopup[button]
	return ns.Enabled("errands") and not ns.PartStopped("errands", part.label) and popup ~= nil and E.Shown(popup)
		and Field(popup, "which") == "DEATH" and E.Shown(button) and Guarded()
end

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
	local ok, level = pcall(button.GetFrameLevel, button)
	if not ok or type(level) ~= "number" or ns.IsSecret(level) then
		return nil
	end
	cover = CreateFrame("Frame", nil, button)
	ns.Own[cover] = true
	cover:Hide()
	cover:SetAllPoints(button)
	cover:SetFrameLevel(level + 5)
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

local function Guard()
	local ok, err = pcall(GuardNow)
	if not ok then
		HideCovers()
		error(err, 0)
	end
end

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
				local ok, text = pcall(box.GetText, box)
				if ok and not ns.IsSecret(text) and text == "" and pcall(box.SetText, box, word) then
					pcall(box.ClearFocus, box)
				end
			end
		end
	end
end

local function HighCost()
	local n = MERCHANT_HIGH_PRICE_COST
	return ns.Finite(n) and n > 0 and n or HIGH_COST
end

local function BuyTokens(popup)
	local frame = MerchantFrame
	local index, count = Field(frame, "itemIndex"), Field(frame, "count")
	if not ns.Finite(index) or index < 1 or (count ~= nil and (not ns.Finite(count) or count < 1)) then
		return
	end
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

local function MayRelease()
	if not E.On("releaseBattleground") then
		return false
	end
	local death = false
	for _, popup in ipairs(Popups()) do
		death = death or popup.which == "DEATH"
	end
	if not death then
		return false
	end
	local inside, kind = E.Ask(IsInInstance)
	if inside ~= true or kind ~= "pvp" or E.Ask(IsActiveBattlefieldArena) == true then
		return false
	end
	local info = C_DeathInfo
	if type(info) ~= "table" or type(info.GetSelfResurrectOptions) ~= "function" then
		return false
	end
	local ok, options = pcall(info.GetSelfResurrectOptions)
	if not ok or ns.IsSecret(options) or (options ~= nil and (type(options) ~= "table" or #options > 0)) then
		return false
	end
	return true
end

local function TryRelease(at, tries)
	if at ~= release.deaths or release.done == at or not MayRelease() then
		return
	end
	if E.Ask(UnitIsDeadOrGhost, "player") ~= true or E.Ask(UnitIsGhost, "player") == true then
		return
	end
	if E.Ask(HasNoReleaseAura) == true or E.Ask(IsFalling) == true then
		if tries > 1 then
			C_Timer.After(RELEASE_WAIT, function()
				E.Run(part, TryRelease, at, tries - 1)
			end)
		end
		return
	end
	if not E.Call(RepopMe) then
		return
	end
	release.done = at
	lastAccepted = "a release in a battleground"
	E.Say("Released your spirit (battleground).")
end

local function ReleaseInBattleground()
	local at = release.deaths
	if release.asked == at or release.done == at or not MayRelease() then
		return
	end
	release.asked = at
	C_Timer.After(RELEASE_WAIT, function()
		if ns.Enabled("errands") then
			E.Run(part, TryRelease, at, RELEASE_TRIES)
		end
	end)
end

local function PopupShown()
	Guard()
	FillDelete()
	Confirm()
	ReleaseInBattleground()
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

local function Follow()
	if followed then
		return
	end
	local shown = ns.FollowGlobal("StaticPopup_Show", OnShow)
	local hidden = ns.FollowGlobal("StaticPopup_Hide", OnHide)
	followed = shown == true and hidden == true
end

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

local function CloseSummon(at, tries)
	if at ~= summon then
		return
	end
	if OpenSummon() == nil then
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

local function TryResurrection(at, offerer, again)
	if at ~= resurrection or E.Opt("resurrect") ~= true or not ns.Enabled("errands") then
		return
	end
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
	if E.Ask(UnitIsDeadOrGhost, "player") ~= true then
		return
	end
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
E.Listen(part, "PLAYER_DEAD", function()
	release.deaths = release.deaths + 1
	C_Timer.After(0, function()
		if ns.Enabled("errands") then
			E.Run(part, Guard)
			E.Run(part, ReleaseInBattleground)
		end
	end)
end)

E.Listen(part, "PLAYER_ENTERING_WORLD", function()
	C_Timer.After(RELEASE_WAIT, function()
		if ns.Enabled("errands") then
			E.Run(part, ReleaseInBattleground)
		end
	end)
end)

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
	if E.Opt("releaseBattleground") == true then
		does[#does + 1] = "releases at once in battlegrounds"
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
