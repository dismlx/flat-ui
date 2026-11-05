local _, ns = ...

-- Errands of the game's popups (the StaticPopup dialogs), followed with hooksecurefunc on StaticPopup_Show and StaticPopup_Hide.
--
-- Hold a key to release: while the game's death popup (DEATH) shows where Release guard applies, a frame of the addon's own lies over its
-- Release Spirit button and takes the clicks, with the key to hold written on it, until the key is held (MODIFIER_STATE_CHANGED). Nothing of
-- the game's button changes: its alpha, its script and its state are as the game left them. The second button (a soulstone or a
-- reincarnation) is not covered, and neither are the game's own timer, a macro or a gamepad press. The cover fails open: it is made hidden, and
-- it is laid, and stays (its OnUpdate looks every frame), only while the module and this part are on, the popup under it is still the death
-- popup, its button is shown, and the game says the key is not held: when the game does not say whether the key is held, there is no cover.
-- Under the gamepad interface, whose own press of the button no mouse cover can stop, there is no cover either.
-- Accept summons: CONFIRM_SUMMON is answered with C_SummonInfo.ConfirmSummon when the game's own popup would let you: not in a fight and while
-- PlayerCanTeleport, tried every second while the summon is open (time left and a summoner).
-- Accept resurrections: RESURRECT_REQUEST is answered with AcceptResurrect unless the one who offers it is in combat or dead (or the game does
-- not say), and only once the game's wait after recent deaths (GetCorpseRecoveryDelay) is over, while the request is still the same
-- (ResurrectGetOfferer).
-- The game's popups of a summon or a resurrection are left to the game, which closes them or lets them run out: Flat UI never calls
-- StaticPopup_Hide, which would run the popup code, shared with popups whose Accept is restricted, under Flat UI's name.
-- Type DELETE: the word the game asks for before it deletes a good item (DELETE_GOOD_ITEM and DELETE_GOOD_QUEST_ITEM) is written in its box,
-- whose focus is then cleared, so a click on Yes deletes and a stray Enter does not.
-- These follow EnhanceQoL's popup helpers, adapted with the permission of its author.

local E = ns.Errands
local part = E.Part({ label = "Popups" })

local POPUPS = 4
-- Seconds between two tries of a summon that cannot be taken yet.
local SUMMON_RETRY = 1
-- Seconds added to the game's wait before a resurrection is taken.
local RES_MARGIN = 0.2
local DELETE_WORDS = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }
local KEYS = {
	shift = { label = "Shift", down = function() return IsShiftKeyDown end },
	ctrl = { label = "Ctrl", down = function() return IsControlKeyDown end },
	alt = { label = "Alt", down = function() return IsAltKeyDown end },
}

local followed = false
-- Per release button of a popup: the cover laid over it, and the popup it belongs to.
local covers, coverPopup = {}, {}
-- The summon being tried: counts up at each new summon, so a try of an older one stops.
local summon = 0
local resurrection = 0
-- What /flatui status says.
local lastAccepted
-- Notes said once: a popup whose button or box was not found.
local missed = {}
-- The game did not say whether the key is held, at the last guard pass.
local noKey = false

local function Count()
	local n = STATICPOPUP_NUMDIALOGS
	if type(n) == "number" and not ns.IsSecret(n) and n >= 1 and n <= 10 then
		return n
	end
	return POPUPS
end

local function Field(frame, key)
	local ok, value = pcall(function()
		return frame[key]
	end)
	if not ok or ns.IsSecret(value) then
		return nil
	end
	return value
end

-- The shown popups of the game: { frame, name, which }.
local function Popups()
	local list = {}
	for index = 1, Count() do
		local name = "StaticPopup" .. index
		local frame = _G[name]
		if E.Shown(frame) then
			list[#list + 1] = { frame = frame, name = name, which = Field(frame, "which") }
		end
	end
	return list
end

local function Usable(frame)
	return type(frame) == "table" and not ns.Forbidden(frame) and frame or nil
end

-- The first button of a popup, by its global name (StaticPopup1Button1) or its key.
local function FirstButton(popup)
	local button = Usable(_G[popup.name .. "Button1"]) or Usable(Field(popup.frame, "button1")) or Usable(Field(popup.frame, "Button1"))
	if not button then
		local container = Field(popup.frame, "ButtonContainer")
		button = type(container) == "table" and Usable(Field(container, "Button1")) or nil
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

-- Whether a cover may stay shown: read by the cover itself, outside the part, so a stopped part cannot leave it over another popup.
local function CoverWanted(button)
	local popup = coverPopup[button]
	return ns.Enabled("errands") and not ns.PartStopped("errands", part.label) and popup ~= nil and E.Shown(popup)
		and Field(popup, "which") == "DEATH" and E.Shown(button) and Guarded() and KeyState() == false
end

local function Cover(button)
	local cover = covers[button]
	if cover then
		return cover
	end
	if ns.MaybeProtected and ns.MaybeProtected(button) then
		Missed("the Release Spirit button of the death popup, which is protected,")
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
	local shade = cover:CreateTexture(nil, "OVERLAY", nil, 0)
	ns.Own[shade] = true
	shade:SetAllPoints(cover)
	shade:SetColorTexture(0, 0, 0, 0.7)
	local label = ns.OwnText(cover, "OVERLAY", "GameFontHighlightSmall")
	if label then
		label:SetPoint("CENTER", cover, "CENTER", 0, 0)
	end
	cover.label = label
	cover:EnableMouse(true)
	-- The clicks the cover takes do nothing.
	cover:SetScript("OnMouseDown", function() end)
	cover:SetScript("OnMouseUp", function() end)
	cover:SetScript("OnUpdate", function()
		local ok, wanted = pcall(CoverWanted, button)
		if not ok or not wanted then
			cover:Hide()
		end
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
		noKey = held == nil
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
					cover:SetShown(not held)
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
				local ok, text = pcall(box.GetText, box)
				if ok and not ns.IsSecret(text) and text ~= word and pcall(box.SetText, box, word) then
					-- No focus, so a stray Enter does not delete: a click on Yes does.
					pcall(box.ClearFocus, box)
				end
			end
		end
	end
end

local function PopupShown()
	Guard()
	FillDelete()
end

local function Follow()
	if followed then
		return
	end
	followed = true
	ns.FollowGlobal("StaticPopup_Show", function()
		if ns.PartStopped("errands", part.label) then
			HideCovers()
			return
		end
		E.Run(part, PopupShown)
	end)
	ns.FollowGlobal("StaticPopup_Hide", function()
		if ns.PartStopped("errands", part.label) then
			HideCovers()
			return
		end
		E.Run(part, Guard)
	end)
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

function part.Start()
	Follow()
	Guard()
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
	elseif (where == "always" or where == "instances") and noKey then
		lines[#lines + 1] = ("Popups: Release Spirit is not covered: the game does not say whether %s is held."):format(Key().label)
	end
	for _, line in ipairs(missed) do
		lines[#lines + 1] = line
	end
	return lines
end
