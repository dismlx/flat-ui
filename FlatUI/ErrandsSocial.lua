local _, ns = ...

local E = ns.Errands
local part = E.Part({ label = "Social" })

local INVITE_LIFE = 60
local JOIN_WAIT = 10
local RETRY = 1
local DUEL_QUIET = 60

local invite = 0
local waiting, joining
local lastInvite
local duels, quiet = 0, {}
local recipient
local mailFollowed, mailMissing = false, false

local function Wanted()
	local who = E.Opt("invites")
	if ns.Enabled("errands") and (who == "friends" or who == "guild" or who == "both") then
		return who
	end
	return nil
end

local function InvitePopup()
	for _, popup in ipairs(E.Popups()) do
		if popup.which == "PARTY_INVITE" then
			return true
		end
	end
	return false
end

local function Queued()
	if type(WillAcceptInviteRemoveQueues) ~= "function" then
		return false
	end
	local ok, queued = pcall(WillAcceptInviteRemoveQueues)
	if not ok or ns.IsSecret(queued) then
		return true
	end
	return queued == true
end

local function InGroup(category)
	local grouped = E.Ask(IsInGroup, category)
	if grouped == true or grouped == false then
		return grouped
	end
	return nil
end

local function Friend(guid)
	if type(guid) ~= "string" or guid == "" then
		return false
	end
	local list = C_FriendList
	if type(list) == "table" and not ns.IsSecret(list) then
		if type(list.IsFriend) == "function" then
			if E.Ask(list.IsFriend, guid) == true then
				return true
			end
		else
			local count = E.Ask(list.GetNumFriends)
			for index = 1, type(count) == "number" and count or 0 do
				local info = E.Ask(list.GetFriendInfoByIndex, index)
				local ok, id = pcall(function()
					return type(info) == "table" and info.guid or nil
				end)
				if ok and not ns.IsSecret(id) and id == guid then
					return true
				end
			end
		end
	end
	local bnet = C_BattleNet
	return type(bnet) == "table" and not ns.IsSecret(bnet) and type(E.Ask(bnet.GetGameAccountInfoByGUID, guid)) == "table"
end

local function Full(name)
	if ns.IsSecret(name) or type(name) ~= "string" or name == "" then
		return nil
	end
	if name:find("-", 1, true) then
		return name
	end
	local realm = E.Ask(GetNormalizedRealmName)
	if type(realm) ~= "string" or realm == "" then
		local _, own = E.Ask(UnitFullName, "player")
		realm = not ns.IsSecret(own) and own or nil
	end
	return type(realm) == "string" and realm ~= "" and (name .. "-" .. realm) or nil
end

local function Guildmate(name, guid)
	if E.Ask(IsInGuild) ~= true then
		return false
	end
	if type(guid) == "string" and guid ~= "" and E.Ask(IsGuildMember, guid) == true then
		return true
	end
	local count = E.Ask(GetNumGuildMembers)
	if type(count) ~= "number" or type(GetGuildRosterInfo) ~= "function" then
		return false
	end
	local known = type(guid) == "string" and guid ~= ""
	local wanted = Full(name)
	for index = 1, count do
		local ok, member, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, id = pcall(GetGuildRosterInfo, index)
		if ok then
			if known and not ns.IsSecret(id) and type(id) == "string" and id ~= "" then
				if id == guid then
					return true
				end
			elseif wanted and Full(member) == wanted then
				return true
			end
		end
	end
	return false
end

local function AskRoster()
	local who = Wanted()
	if (who ~= "guild" and who ~= "both") or E.Ask(IsInGuild) ~= true then
		return
	end
	local count = E.Ask(GetNumGuildMembers)
	if type(count) == "number" and count > 0 then
		return
	end
	E.Call(type(C_GuildInfo) == "table" and C_GuildInfo.GuildRoster or GuildRoster)
end

local function Try(token, name, left, row)
	if token ~= invite or Wanted() ~= row then
		waiting = nil
		return
	end
	if InGroup() ~= false then
		waiting = nil
		return
	end
	if left < INVITE_LIFE and not InvitePopup() then
		waiting = nil
		return
	end
	if E.Fighting() then
		if left <= 0 then
			waiting = nil
			return
		end
		waiting = name or true
		C_Timer.After(RETRY, function()
			E.Run(part, Try, token, name, left - RETRY, row)
		end)
		return
	end
	waiting = nil
	if Queued() or not E.Call(AcceptGroup) then
		return
	end
	joining = { token = token, name = name }
	C_Timer.After(JOIN_WAIT, function()
		E.Run(part, function()
			if joining and joining.token == token then
				joining = nil
			end
		end)
	end)
end

local function Invited(name, tank, healer, damage, _, _, guid, questSession)
	invite, waiting, joining = invite + 1, nil, nil
	local who = Wanted()
	if not who or ns.IsSecret(name) or ns.IsSecret(tank) or ns.IsSecret(healer) or ns.IsSecret(damage) or ns.IsSecret(guid) or ns.IsSecret(questSession) then
		return
	end
	if tank == true or healer == true or damage == true or questSession == true then
		return
	end
	if Queued() then
		return
	end
	local known = (who ~= "guild" and Friend(guid)) or (who ~= "friends" and Guildmate(name, guid))
	if not known then
		AskRoster()
		return
	end
	if InGroup() ~= false then
		return
	end
	Try(invite, type(name) == "string" and name ~= "" and name or nil, INVITE_LIFE, who)
end

local function Joined()
	if waiting and InGroup() == true then
		invite, waiting = invite + 1, nil
	end
	if not joining or InGroup(_G.LE_PARTY_CATEGORY_HOME) ~= true then
		return
	end
	local name = joining.name
	joining = nil
	E.HideAlone("PARTY_INVITE")
	lastInvite = name and ("the invite of " .. name) or "a group invite"
	E.Say(name and ("Accepted the invite of %s."):format(name) or "Accepted a group invite.")
end

E.Listen(part, "PARTY_INVITE_REQUEST", Invited)
E.Listen(part, "PARTY_INVITE_CANCEL", function()
	invite, waiting = invite + 1, nil
end)
E.Listen(part, "GROUP_ROSTER_UPDATE", Joined)
E.Listen(part, "GROUP_JOINED", Joined)
E.Listen(part, "PLAYER_GUILD_UPDATE", AskRoster)

E.Listen(part, "DUEL_REQUESTED", function(name)
	if not E.On("declineDuels") or not E.Call(CancelDuel) then
		return
	end
	duels = duels + 1
	local who = not ns.IsSecret(name) and type(name) == "string" and name ~= "" and name or nil
	local key = who or ""
	if quiet[key] then
		return
	end
	quiet[key] = true
	C_Timer.After(DUEL_QUIET, function()
		E.Run(part, function()
			quiet[key] = nil
		end)
	end)
	E.Say(who and ("Declined a duel from %s."):format(who) or "Declined a duel.")
end)

local function NameBox()
	local box = SendMailNameEditBox
	if type(box) == "table" and not ns.Forbidden(box) then
		return box
	end
	return nil
end

local function BoxText(box)
	local ok, text = pcall(box.GetText, box)
	if ok and not ns.IsSecret(text) and type(text) == "string" then
		return text
	end
	return nil
end

local function Sent()
	if not E.On("mailRecipient") then
		return
	end
	local box = NameBox()
	local text = box and BoxText(box)
	recipient = type(text) == "string" and text ~= "" and text or nil
end

local function Emptied()
	local box = NameBox()
	if not recipient or not box or not E.On("mailRecipient") or not E.Shown(MailFrame) or BoxText(box) ~= "" then
		return
	end
	if pcall(box.SetText, box, recipient) then
		pcall(box.HighlightText, box, 0, 0)
	end
end

local function OnSent()
	E.Run(part, Sent)
end

local function OnEmptied()
	E.Run(part, Emptied)
end

local function FollowMail(atMailbox)
	if mailFollowed then
		return
	end
	local sent = ns.FollowGlobal("SendMailFrame_SendMail", OnSent)
	local emptied = ns.FollowGlobal("SendMailFrame_Reset", OnEmptied)
	mailFollowed = sent == true and emptied == true
	if mailFollowed then
		mailMissing = false
	elseif atMailbox then
		mailMissing = true
	end
end

E.Listen(part, "MAIL_SHOW", function()
	FollowMail(true)
end)
E.Listen(part, "ADDON_LOADED", function(name)
	if name == "Blizzard_MailFrame" then
		FollowMail(false)
	end
end)
E.Listen(part, "MAIL_CLOSED", function()
	recipient = nil
end)

function part.Start()
	FollowMail(false)
	AskRoster()
end

function part.Refresh()
	if Wanted() then
		AskRoster()
	else
		invite, waiting, joining = invite + 1, nil, nil
	end
	if not E.On("mailRecipient") then
		recipient = nil
	end
end

function part.Status()
	local does = {}
	local who = E.Opt("invites")
	if who == "friends" then
		does[#does + 1] = "accepts invites from friends"
	elseif who == "guild" then
		does[#does + 1] = "accepts invites from your guild"
	elseif who == "both" then
		does[#does + 1] = "accepts invites from friends and your guild"
	end
	if E.Opt("declineDuels") == true then
		does[#does + 1] = "declines duels"
	end
	if E.Opt("mailRecipient") == true then
		does[#does + 1] = "remembers the last mail recipient"
	end
	if #does == 0 then
		return {}
	end
	local line = "Social: " .. table.concat(does, ", ") .. "."
	if lastInvite then
		line = line .. " Last accepted " .. lastInvite .. "."
	end
	if duels > 0 then
		line = line .. (" Declined %d %s."):format(duels, duels == 1 and "duel" or "duels")
	end
	local lines = { line }
	if type(waiting) == "string" then
		lines[#lines + 1] = ("Social: the invite of %s waits for the fight to end."):format(waiting)
	elseif waiting then
		lines[#lines + 1] = "Social: an invite waits for the fight to end."
	end
	if (who == "friends" or who == "guild" or who == "both") and (type(AcceptGroup) ~= "function" or type(IsInGroup) ~= "function") then
		lines[#lines + 1] = "Social: this client cannot accept invites for you, so they are left to you."
	end
	if E.Opt("declineDuels") == true and type(CancelDuel) ~= "function" then
		lines[#lines + 1] = "Social: this client cannot decline duels for you."
	end
	if E.Opt("mailRecipient") == true and mailMissing then
		lines[#lines + 1] = "Social: the mail window's send calls were not found, so the last recipient is not kept."
	end
	return lines
end
