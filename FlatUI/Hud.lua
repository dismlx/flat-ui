local ADDON_NAME, ns = ...

local KEY = "hud"
local LABEL = "Minimap and HUD"
local MAP_MASK = "ui-hud-minimap-frame-generic-mask"
local SQUARE_MASK = "Interface\\ChatFrame\\ChatFrameBackground"
local ZOOM_EVERY, ZOOM_GLIDE = 0.5, 0.08
local MAP_BUTTONS = { { option = "btnTracking", key = "Tracking", mouse = { "Button" } },
	{ option = "btnMail", key = "IndicatorFrame", mouse = { "MailFrame", "CraftingOrderFrame" } }, { option = "btnCalendar", name = "GameTimeFrame" },
	{ option = "btnClock", name = "TimeManagerClockButton" }, { option = "btnAddons", name = "AddonCompartmentFrame" } }
local TYPE_ROWS = { Magic = "colourMagic", Curse = "colourCurse", Disease = "colourDisease", Poison = "colourPoison", Bleed = "colourOther", None = "colourOther" }
local DIEL_BORDER = "UI-HUD-Minimap-Frame-Cycle"
local CITY_ADDON = "Blizzard_HybridMinimap"
local COVER_FILE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Cover.tga"
local HEADER_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
	"CharacterReagentBag0Slot", "KeyRingButton" }
local AURA_FRAMES = { "BuffFrame", "DebuffFrame", "ExternalDefensivesFrame" }
local DEBUFF_COLOURS = {
	Magic = { 0.2, 0.6, 1 },
	Curse = { 0.6, 0, 1 },
	Disease = { 0.6, 0.4, 0 },
	Poison = { 0, 0.6, 0 },
	Bleed = { 0.8, 0, 0 },
	None = { 0.8, 0, 0 },
}
local ENCHANT_COLOUR = { 0.64, 0.21, 0.93 }
local BAR_CONTAINERS = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
local FILL_COLOURS = {
	["ui-hud-experiencebar-fill-experience"] = { 0.58, 0, 0.55 },
	["ui-hud-experiencebar-fill-rested"] = { 0, 0.39, 0.88 },
	["ui-hud-experiencebar-fill-reputation-faction-red"] = { 0.8, 0.3, 0.22 },
	["ui-hud-experiencebar-fill-reputation-faction-orange"] = { 0.75, 0.27, 0 },
	["ui-hud-experiencebar-fill-reputation-faction-yellow"] = { 0.9, 0.7, 0 },
	["ui-hud-experiencebar-fill-reputation-faction-green"] = { 0, 0.6, 0.1 },
	["ui-hud-experiencebar-fill-reputation-faction-blue"] = { 0, 0.44, 0.87 },
	["ui-hud-experiencebar-fill-honor"] = { 1, 0.24, 0 },
	["ui-hud-experiencebar-fill-artifactpower"] = { 0.9, 0.8, 0.5 },
}
local NEUTRAL_FILL = { 0.5, 0.5, 0.5 }
local DIVIDER_POOLS = { "HorizontalDividersPool", "VerticalDividersPool" }
local MICRO_BUTTONS = { "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton", "LegacyMicroButton",
	"QuestLogMicroButton", "HousingMicroButton", "GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton", "EJMicroButton",
	"StoreMicroButton", "MainMenuMicroButton", "HelpMicroButton" }
local TRACKER_MODULES = { "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker", "QuestObjectiveTracker",
	"AdventureObjectiveTracker", "AchievementObjectiveTracker", "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker",
	"ProfessionsRecipeTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker" }
local TRACKER_BAR_ART = { "BorderLeft", "BorderRight", "BorderMid", "BarFrame", "IconBG" }
local BAR_FILE = "Interface\\TargetingFrame\\UI-StatusBar"
local ROLL_FILE = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
local PANEL_FILL = { "BottomLeft", "BottomRight", "BottomEdge", "TopSection" }
local SLOT_ART = { "NormalTexture", "PushedTexture", "IconBorder" }
local ROLL_FRAMES, METER_WINDOWS = 4, 3
local ROLL = {
	game = { { "NeedButton", "TOPLEFT", "container", "TOPLEFT", 14, -7 }, { "PassButton", "LEFT", "NeedButton", "RIGHT", 6, 2 },
		{ "GreedButton", "TOP", "NeedButton", "BOTTOM", 0, 5 }, { "TransmogButton", "CENTER", "GreedButton", "CENTER", 0, 0 } },
	flat = { { "PassButton", "RIGHT", "frame", "RIGHT", -8, 5 }, { "GreedButton", "RIGHT", "PassButton", "LEFT", -2, 0 },
		{ "TransmogButton", "CENTER", "GreedButton", "CENTER", 0, 0 }, { "NeedButton", "RIGHT", "GreedButton", "LEFT", -2, 0 } },
	button = 32, flatButton = 26,
	timer = { width = 190, height = 8, x = 3, y = 2, inset = 8, lift = 6 },
	mover = "FlatUILootRolls", part = "loot roll spot", step = 100,
	moved = setmetatable({}, { __mode = "k" }),
}
local ALERT_SYSTEMS = { "LootAlertSystem", "MoneyWonAlertSystem", "HonorAwardedAlertSystem" }
local ALERT_ART = { "Background", "PvPBackground", "RatedPvPBackground", "BGAtlas", "IconBorder" }
local MIRROR_FILLS = { ["ui-castingbar-filling-standard"] = "castColour", ["ui-castingbar-filling-applyingcrafting"] = "craftColour",
	["ui-castingbar-filling-channel"] = "channelColour" }
local MIRROR_BACKGROUND = "ui-castingbar-background"
local MIRROR = { every = 0.1, red = { 1, 0.25, 0.25 } }
local WIDGET_CONTAINERS = { "UIWidgetTopCenterContainerFrame", "UIWidgetBelowMinimapContainerFrame", "UIWidgetCenterScreenContainerFrame",
	"UIWidgetPowerBarContainerFrame" }
local WIDGET_ART = { "BorderLeft", "BorderRight", "BorderCenter", "BGLeft", "BGRight", "BGCenter" }
local OPTION = { ["tracker headers"] = "trackerHeaders", ["tracker bars"] = "trackerBars", ["tracker items"] = "trackerItems", ["tracker panel"] = "trackerPanel",
	["loot window"] = "lootWindow", ["loot rolls"] = "lootRolls", alerts = "alerts", ["mirror timers"] = "mirror",
	["countdown timers"] = "countdown", ["queue status"] = "queue", ["damage meter"] = "meter", ["zone bars"] = "zoneBars" }

local minimap = {}
local edges = setmetatable({}, { __mode = "k" })
local bags = setmetatable({}, { __mode = "k" })
local auras = setmetatable({}, { __mode = "k" })
local borders = setmetatable({}, { __mode = "k" })
local fills = setmetatable({}, { __mode = "k" })
local micro = setmetatable({}, { __mode = "k" })
local dividerFrames = setmetatable({}, { __mode = "k" })
local dividerFaded = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local faded = setmetatable({}, { __mode = "k" })
local plates = setmetatable({}, { __mode = "k" })
local globalHooks = {}
local sized = setmetatable({}, { __mode = "k" })
local mapButtons = setmetatable({}, { __mode = "k" })
local xpTexts = setmetatable({}, { __mode = "k" })
local look = {}
local retry = false
local Refresh

local function On(part, option)
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, part) and ns.Get(KEY .. "." .. option) == true
end

local function Val(part, option)
	if ns.Enabled(KEY) and not ns.PartStopped(KEY, part) then
		return ns.Get(KEY .. "." .. option)
	end
	return nil
end

local function RowFile(option)
	local id = ns.Get(KEY .. "." .. option)
	if id == nil or id == "default" then
		return nil
	end
	return ns.BarFile(id) or false
end

local function Crop()
	return ns.Get(KEY .. ".crop") / 100
end

local function Size(fontString, percent, what)
	if fontString == nil or ns.IsSecret(fontString) or type(fontString) ~= "table" or type(fontString.GetFont) ~= "function" then
		return
	end
	if ns.TextStyle(fontString, { percent = percent }) == false then
		ns.Note(KEY, LABEL .. ": the game refused a new size for " .. what .. ".")
	end
end

local function Frame(name)
	local frame = _G[name]
	if frame == nil or ns.Forbidden(frame) then
		return nil
	end
	return frame
end

local function Child(frame, key)
	local value = frame[key]
	if ns.Forbidden(value) then
		return nil
	end
	return value
end

local function InFight()
	if not InCombatLockdown() then
		return false
	end
	if not retry then
		retry = true
		ns.OutOfCombat(function()
			retry = false
			ns.Try(KEY, Refresh)
		end)
	end
	return true
end

local function Later(frame)
	return InCombatLockdown() and ns.MaybeProtected(frame) and InFight()
end

local looking = false
local function Run(part, fn, ...)
	if ns.PartStopped(KEY, part) then
		pcall(fn, ...)
	elseif not ns.EachPart(KEY, part, fn, ...) and ns.PartStopped(KEY, part) and not looking then
		looking = true
		pcall(Refresh)
		looking = false
	end
end

local function Moves(key, on)
	local was = faded[key] or false
	faded[key] = on
	return on ~= was
end

local function Follow(frame, method, fn)
	local done = hooked[frame]
	if done == nil then
		done = {}
		hooked[frame] = done
	end
	if done[method] or type(hooksecurefunc) ~= "function" or type(frame[method]) ~= "function" then
		return
	end
	done[method] = true
	ns.HookMethod(frame, method, fn)
end

local soon = setmetatable({}, { __mode = "k" })
local function Soon(key, fn)
	if soon[key] then
		return
	end
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		fn()
		return
	end
	soon[key] = true
	C_Timer.After(0, function()
		soon[key] = nil
		if not ns.IsStopped(KEY) then
			fn()
		end
	end)
end

local function OnScript(frame, script, name, fn)
	local done = hooked[frame]
	if done == nil then
		done = {}
		hooked[frame] = done
	end
	if done[name] or type(frame.HookScript) ~= "function" then
		return
	end
	done[name] = true
	pcall(frame.HookScript, frame, script, function()
		Soon(fn, fn)
	end)
end

local function FadePictures(frame, hide)
	if frame == nil or ns.IsSecret(frame) or type(frame) ~= "table" or type(frame.GetRegions) ~= "function" then
		return
	end
	local ok, list = pcall(function() return { frame:GetRegions() } end)
	if not ok or ns.IsSecret(list) then
		return
	end
	for _, region in ipairs(list) do
		ns.SetFaded(region, hide)
	end
end

local function FadeDividers(frame, part, option, pieces)
	local hide = On(part, option)
	if type(pieces) == "function" then
		pieces = pieces()
	end
	if not hide and not dividerFrames[frame] then
		return
	end
	dividerFrames[frame] = true
	for _, key in ipairs(DIVIDER_POOLS) do
		local pool = frame[key]
		if pool ~= nil and not ns.IsSecret(pool) and type(pool) == "table" and pool.EnumerateActive then
			for divider in pool:EnumerateActive() do
				if pieces then
					FadePictures(divider, hide)
					if dividerFaded[divider] then
						dividerFaded[divider] = nil
						ns.SetFaded(divider, false)
					end
				else
					ns.SetFaded(divider, hide)
					dividerFaded[divider] = hide or nil
					FadePictures(divider, false)
				end
			end
		end
	end
end

local function FollowDividers(frame, part, option, pieces)
	OnScript(frame, "OnSizeChanged", "dividers", function()
		Run(part, FadeDividers, frame, part, option, pieces)
	end)
end

local function MapBorder(on, square)
	local ring = minimap.ring
	if not ring then
		local map = Frame("Minimap")
		if not on or square or not map then
			return
		end
		local ok, parent = pcall(map.GetParent, map)
		if not ok or not parent or ns.Forbidden(parent) or Later(parent) then
			return
		end
		local frame = CreateFrame("Frame", nil, parent)
		ns.Own[frame] = true
		frame:SetFrameStrata("BACKGROUND")
		frame:SetAllPoints(map)
		local disc = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
		ns.Own[disc] = true
		local mask = frame:CreateMaskTexture()
		ns.Own[mask] = true
		mask:SetAtlas(MAP_MASK)
		mask:SetAllPoints(disc)
		disc:AddMaskTexture(mask)
		ring = { frame = frame, disc = disc }
		minimap.ring = ring
		ns.Count(KEY)
	end
	local t = ns.Pixels(ring.frame, ns.Get("general.thickness"))
	ring.disc:SetPoint("TOPLEFT", ring.frame, "TOPLEFT", -t, t)
	ring.disc:SetPoint("BOTTOMRIGHT", ring.frame, "BOTTOMRIGHT", t, -t)
	local r, g, b = ns.BorderRGB()
	ring.disc:SetColorTexture(r, g, b, 1)
	ring.disc:SetShown(on and not square and not ns.Borderless())
end

local function CityMap()
	local map = _G.HybridMinimap
	if map == nil or ns.Forbidden(map) then
		return nil
	end
	return map
end

local function CityShown()
	local map = CityMap()
	if not map then
		return false
	end
	local ok, shown = pcall(map.IsShown, map)
	if not ok or ns.IsSecret(shown) or type(shown) ~= "boolean" then
		return nil
	end
	return shown
end

local function Level(frame)
	local ok, level = pcall(frame.GetFrameLevel, frame)
	if not ok or ns.IsSecret(level) or type(level) ~= "number" then
		return nil
	end
	return level
end

local function Stack(frame)
	local ok, strata = pcall(frame.GetFrameStrata, frame)
	local level = Level(frame)
	if not ok or ns.IsSecret(strata) or type(strata) ~= "string" or level == nil then
		return nil
	end
	return ("%s %d"):format(strata, level)
end

local function CityChoice()
	if ns.Enabled(KEY) and not ns.PartStopped(KEY, "minimap") then
		return ns.Get(KEY .. ".cityMap")
	end
	return nil
end

local function CoverPicture(owner)
	local texture = owner:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[texture] = true
	pcall(texture.SetSnapToPixelGrid, texture, false)
	pcall(texture.SetTexelSnappingBias, texture, 0)
	texture:SetTexture(COVER_FILE)
	texture:SetAllPoints(owner)
	return texture
end

local function MakeCover()
	local map = Frame("Minimap")
	if not map then
		return nil
	end
	local level = Level(map)
	if level == nil then
		return nil
	end
	local frame = CreateFrame("Frame", nil, map)
	ns.Own[frame] = true
	frame:SetFrameLevel(level)
	pcall(frame.SetClipsChildren, frame, true)
	frame:SetAllPoints(map)
	local rim = CreateFrame("Frame", nil, frame)
	ns.Own[rim] = true
	rim:SetFrameLevel(level)
	return { frame = frame, rim = rim, back = CoverPicture(frame), face = CoverPicture(rim) }
end

local function CityCover(wanted, border)
	local cover = minimap.cover
	if not cover then
		if not wanted or InFight() then
			return
		end
		cover = MakeCover()
		minimap.blocked = cover == nil
		if not cover then
			return
		end
		minimap.cover = cover
		ns.Count(KEY)
	end
	local rim = border and not ns.Borderless()
	if rim then
		local t = ns.Pixels(cover.frame, ns.Get("general.thickness"))
		if cover.t ~= t and not InFight() then
			cover.t = t
			cover.rim:SetPoint("TOPLEFT", cover.frame, "TOPLEFT", -t, t)
			cover.rim:SetPoint("BOTTOMRIGHT", cover.frame, "BOTTOMRIGHT", t, -t)
		end
		rim = cover.t ~= nil
	end
	local br, bg, bb = ns.Colour("general.backdrop")
	if rim then
		local r, g, b = ns.BorderRGB()
		cover.back:SetVertexColor(r, g, b, 1)
		cover.face:SetVertexColor(br, bg, bb, 1)
	else
		cover.back:SetVertexColor(br, bg, bb, 1)
	end
	cover.rim:SetShown(rim)
	cover.frame:SetShown(wanted)
	cover.on = wanted
end

local function HeaderBorder(frame, on)
	local outline = edges[frame]
	if not outline then
		if not on or Later(frame) then
			return
		end
		outline = ns.Outline(frame, frame)
		edges[frame] = outline
		ns.Count(KEY)
	end
	ns.SetOutline(outline, on, true)
end

local function BannerModes(banner)
	local modes, list = {}, banner and banner.ContentModes
	if list ~= nil and not ns.IsSecret(list) and type(list) == "table" then
		for _, mode in ipairs(list) do
			if not ns.Forbidden(mode) then
				modes[#modes + 1] = mode
			end
		end
	end
	return modes
end

local function Picture(frame, key)
	local value = frame and frame[key]
	if value == nil or ns.IsSecret(value) or type(value) ~= "table" then
		return nil
	end
	return value
end

local function Header(cluster)
	local button = cluster and Child(cluster, "ZoneTextButton")
	local plate = Picture(button, "StateTexture")
	if plate then
		return button, { plate }, Picture(button, "AddTexture")
	end
	local old = cluster and Child(cluster, "BorderTop")
	if not old then
		return nil, {}
	end
	local list = {}
	for _, piece in ipairs(HEADER_PIECES) do
		list[#list + 1] = Picture(old, piece)
	end
	return old, list
end

local GLOW_SCRIPTS = { "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp", "OnEnable", "OnDisable" }
local function FollowGlow(button, glow)
	local done = hooked[button]
	if done == nil then
		done = {}
		hooked[button] = done
	end
	if done.glow or type(button.HookScript) ~= "function" then
		return
	end
	done.glow = true
	local function Again()
		if On("minimap", "minimapArt") and not ns.IsStopped(KEY) then
			ns.SetFaded(glow, true)
		end
	end
	for _, script in ipairs(GLOW_SCRIPTS) do
		pcall(button.HookScript, button, script, Again)
	end
end

local function TrackingBox(tracking)
	local button = tracking and Child(tracking, "Button")
	if button and Picture(button, "StateTexture") then
		return button
	end
	return tracking
end

local function MapOutline(on)
	local outline = minimap.edge
	if not outline then
		local map = Frame("Minimap")
		if not on or not map or Later(map) then
			return
		end
		outline = ns.Outline(map, map)
		if not outline then
			return
		end
		minimap.edge = outline
		ns.Count(KEY)
	end
	ns.SetOutline(outline, on, false)
end

local function SetMask(map, file)
	return (pcall(map.SetMaskTexture, map, file))
end

local function ReMask()
	if not minimap.squared or ns.IsStopped(KEY) or Val("minimap", "shape") ~= "square" then
		return
	end
	local map = Frame("Minimap")
	if map and not SetMask(map, SQUARE_MASK) then
		ns.Note(KEY, LABEL .. ": the game refused the square mask, and the minimap has the game's mask.")
	end
end

local function MapShape(square)
	local map = Frame("Minimap")
	if not map then
		return false
	end
	if square then
		if not minimap.squared and not Later(map) then
			if not SetMask(map, SQUARE_MASK) then
				ns.Note(KEY, LABEL .. ": the game refused the square mask, so the minimap stays round.")
				return false
			end
			minimap.squared = true
		end
	elseif minimap.squared and not Later(map) then
		if SetMask(map, MAP_MASK) then
			minimap.squared = nil
		else
			ns.Note(KEY, LABEL .. ": the game refused to put back the round mask, so the minimap stays square.")
		end
	end
	return minimap.squared == true
end

local function ZoomLevel()
	local map = Frame("Minimap")
	if not map or type(map.GetZoom) ~= "function" then
		return nil
	end
	local ok, zoom = pcall(map.GetZoom, map)
	if ok and not ns.IsSecret(zoom) and type(zoom) == "number" then
		return zoom
	end
	return nil
end

local function Now()
	return type(GetTime) == "function" and GetTime() or 0
end

local function ZoomGlide()
	local map, zoom = Frame("Minimap"), ZoomLevel()
	if not map or zoom == nil or zoom <= 0 then
		minimap.gliding, minimap.glideTo, minimap.zoomAt = nil, nil, nil
		minimap.zoomer:Hide()
		return
	end
	local ok, over = pcall(map.IsMouseOver, map)
	if not ok or ns.IsSecret(over) or over ~= false then
		minimap.gliding, minimap.glideTo, minimap.zoomAt = nil, nil, Now()
		return
	end
	minimap.glideTo = zoom - 1
	if not pcall(map.SetZoom, map, zoom - 1) then
		minimap.gliding, minimap.glideTo, minimap.zoomAt = nil, nil, nil
		minimap.zoomer:Hide()
		ns.Note(KEY, LABEL .. ": the game refused to zoom the minimap out.")
		return
	end
	if zoom - 1 <= 0 then
		minimap.gliding, minimap.glideTo, minimap.zoomAt = nil, nil, nil
		minimap.zoomer:Hide()
	end
end

local function ZoomBack()
	local seconds = Val("minimap", "zoomReset")
	if type(seconds) ~= "number" or seconds <= 0 or minimap.zoomAt == nil then
		if minimap.zoomer then
			minimap.zoomer:Hide()
		end
		return
	end
	if Now() - minimap.zoomAt < seconds then
		return
	end
	local map = Frame("Minimap")
	if not map then
		return
	end
	local ok, over = pcall(map.IsMouseOver, map)
	if not ok or ns.IsSecret(over) or over ~= false then
		return
	end
	minimap.zoomAt, minimap.gliding = nil, true
	ZoomGlide()
end

local function ZoomStep(_, elapsed)
	minimap.zoomClock = (minimap.zoomClock or 0) + elapsed
	if minimap.zoomClock >= (minimap.gliding and ZOOM_GLIDE or ZOOM_EVERY) then
		minimap.zoomClock = 0
		Run("minimap", minimap.gliding and ZoomGlide or ZoomBack, minimap)
	end
end

local function ZoomSeen(_, fresh)
	local seconds = Val("minimap", "zoomReset")
	local zoom = ZoomLevel()
	local count = type(seconds) == "number" and seconds > 0
	minimap.zoomBlind = (count and zoom == nil) or nil
	if minimap.gliding and count and zoom ~= nil and zoom > 0 and (not fresh or zoom == minimap.glideTo) then
		return
	end
	minimap.gliding, minimap.glideTo = nil, nil
	if not count or zoom == nil or zoom == 0 then
		minimap.zoomAt = nil
		if minimap.zoomer then
			minimap.zoomer:Hide()
		end
		return
	end
	minimap.zoomAt = (fresh and Now()) or minimap.zoomAt or Now()
	if not minimap.zoomer then
		minimap.zoomer = CreateFrame("Frame")
		ns.Own[minimap.zoomer] = true
		minimap.zoomer:SetScript("OnUpdate", ZoomStep)
	end
	minimap.zoomer:Show()
end

local function MapButton(entry, cluster)
	local frame = entry.name and Frame(entry.name) or (entry.key and cluster and Child(cluster, entry.key)) or nil
	if frame == nil or type(frame.SetAlpha) ~= "function" then
		return
	end
	local targets = {}
	if entry.mouse then
		for _, key in ipairs(entry.mouse) do
			local child = Child(frame, key)
			if child ~= nil and type(child.EnableMouse) == "function" then
				targets[#targets + 1] = child
			end
		end
	elseif type(frame.EnableMouse) == "function" then
		targets[1] = frame
	end
	local off = Val("minimap", entry.option) == false
	local rec = mapButtons[frame]
	if not rec then
		if not off then
			return
		end
		local given = ns.FadeGiven and ns.FadeGiven(frame)
		local alpha = given
		if alpha == nil then
			local okAlpha, got = pcall(frame.GetAlpha, frame)
			alpha = okAlpha and got or nil
		end
		rec = { alpha = (ns.Finite(alpha) and alpha > 0.001) and alpha or 1, mice = {} }
		mapButtons[frame] = rec
		ns.Count(KEY)
	end
	if (rec.off or false) ~= off then
		frame:SetAlpha(off and 0 or rec.alpha)
		rec.off = off
	end
	for _, target in ipairs(targets) do
		local mrec = rec.mice[target]
		if not mrec then
			local okMouse, mouse = false, nil
			if type(target.IsMouseEnabled) == "function" then
				okMouse, mouse = pcall(target.IsMouseEnabled, target)
			end
			mrec = { mouse = not (okMouse and not ns.IsSecret(mouse) and mouse == false) }
			rec.mice[target] = mrec
		end
		if (mrec.off or false) ~= off and not Later(target) then
			target:EnableMouse(not off and mrec.mouse)
			mrec.off = off
		end
	end
end

function ns.MapButtonOff(frame)
	local rec = mapButtons[frame]
	return rec ~= nil and rec.off == true
end

local headerGap = { sides = {} }

function headerGap.Points(frame)
	local ok, count = pcall(frame.GetNumPoints, frame)
	if not ok or not ns.Finite(count) or count < 1 then
		return nil
	end
	local points = {}
	for i = 1, count do
		local read, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, i)
		if not read or ns.IsSecret(point) or type(point) ~= "string" or ns.IsSecret(relativePoint) or type(relativePoint) ~= "string"
			or not ns.Finite(x) or not ns.Finite(y) then
			return nil
		end
		points[i] = { point, relativeTo, relativePoint, x, y }
	end
	return points
end

function headerGap.At(frame, set)
	local points = set and headerGap.Points(frame)
	local p = points and #points == 1 and points[1]
	return p and p[1] == set[1] and p[2] == set[2] and p[3] == set[3] and math.abs(p[4] - set[4]) < 0.01 and math.abs(p[5] - set[5]) < 0.01
		or false
end

function headerGap.Hang(frame, points)
	frame:ClearAllPoints()
	for _, p in ipairs(points) do
		frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
end

function headerGap.Centre(frame)
	local ok, x, y = pcall(frame.GetCenter, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	if not ok or not okScale or not ns.Finite(x) or not ns.Finite(y) or not ns.Finite(scale) or scale <= 0 then
		return nil
	end
	return x * scale, y * scale, scale
end

function headerGap.Edges(frame)
	local okTop, top = pcall(frame.GetTop, frame)
	local okBottom, bottom = pcall(frame.GetBottom, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	if not okTop or not okBottom or not okScale or not ns.Finite(top) or not ns.Finite(bottom) or not ns.Finite(scale) or scale <= 0 then
		return nil
	end
	return top * scale, bottom * scale
end

function headerGap.Back(frame, rec)
	if rec.set and headerGap.At(frame, rec.set) then
		headerGap.Hang(frame, rec.game)
	end
	rec.set = nil
end

function headerGap.Release(plate)
	for frame, rec in pairs(headerGap.sides) do
		if not Later(frame) then
			headerGap.Back(frame, rec)
			headerGap.sides[frame] = nil
		end
	end
	if not headerGap.game then
		return
	end
	if headerGap.At(plate, headerGap.set) then
		if Later(plate) then
			return
		end
		headerGap.Hang(plate, headerGap.game)
		headerGap.moved = true
	end
	headerGap.game, headerGap.set = nil, nil
	headerGap.holder:Hide()
end

function headerGap.Take(cluster, plate)
	local points = headerGap.Points(plate)
	local okSize, width, height = pcall(plate.GetSize, plate)
	local okScale, scale = pcall(plate.GetScale, plate)
	if not points or not okSize or not okScale or not ns.Finite(width) or not ns.Finite(height) or not ns.Finite(scale) or scale <= 0 then
		ns.Note(KEY, LABEL .. ": the game does not say where the zone name is, so it stays in the game's place.")
		return false
	end
	local holder = headerGap.holder
	if not holder then
		holder = CreateFrame("Frame", nil, cluster)
		ns.Own[holder] = true
		headerGap.holder = holder
		ns.Count(KEY)
	end
	headerGap.Hang(holder, points)
	holder:SetScale(scale)
	holder:SetSize(width, height)
	holder:Show()
	headerGap.game, headerGap.set = points, nil
	return true
end

function headerGap.Sides(cluster, plate)
	return { { frame = Child(cluster, "IndicatorFrame"), from = plate, x = "LEFT", over = 0 },
		{ frame = Frame("AddonCompartmentFrame"), from = Frame("GameTimeFrame"), x = "", over = 1 } }
end

function headerGap.Side(side, plate, above, near, far)
	local frame, from = side.frame, side.from
	if not frame or not from or Later(frame) then
		return
	end
	local rec = headerGap.sides[frame]
	if not (rec and headerGap.At(frame, rec.set)) then
		local points = headerGap.Points(frame)
		if not points then
			return
		end
		rec = { game = points }
		headerGap.sides[frame] = rec
	end
	local okHeight, height = pcall(frame.GetHeight, frame)
	local okOwn, own = pcall(frame.GetEffectiveScale, frame)
	local okScale, scale = pcall(plate.GetEffectiveScale, plate)
	if not okHeight or not okOwn or not okScale or not ns.Finite(height) or not ns.Finite(own) or not ns.Finite(scale) or own <= 0 or scale <= 0 then
		return
	end
	local reach = (height - side.over) * own / scale
	if far < 1 or near >= reach or near > far then
		headerGap.Back(frame, rec)
		return
	end
	local over = math.max(side.over, height - far * scale / own)
	local set = above and { "BOTTOM" .. side.x, from, "TOP" .. side.x, 0, -over } or { "TOP" .. side.x, from, "BOTTOM" .. side.x, 0, over }
	if headerGap.At(frame, rec.set) and rec.set[1] == set[1] and math.abs(rec.set[5] - set[5]) < 0.01 then
		return
	end
	headerGap.Hang(frame, { set })
	rec.set = set
end

function headerGap.Ready()
	local manager = _G.EditModeManagerFrame
	if manager == nil or ns.Forbidden(manager) then
		return manager == nil
	end
	local ok, info = pcall(rawget, manager, "layoutInfo")
	return ok and info ~= nil
end

function headerGap.Listen()
	if headerGap.listening or type(EventRegistry) ~= "table" or ns.IsSecret(EventRegistry) or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	headerGap.listening = true
	local function Look()
		if headerGap.game or Val("minimap", "zoneGapOwn") == true then
			Soon(headerGap, headerGap.Again)
		end
	end
	pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Enter", Look, headerGap)
	pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", Look, headerGap)
	headerGap.Look = Look
end

function headerGap.Apply(cluster, border, bare)
	headerGap.moved = false
	headerGap.bare = bare
	local plate, map = cluster and Child(cluster, "ZoneTextButton"), Frame("Minimap")
	if not plate or not map or not Picture(plate, "StateTexture") then
		return
	end
	local wanted = Val("minimap", "zoneGapOwn") == true
	if wanted then
		headerGap.Listen()
	end
	if not wanted or not bare or not headerGap.Ready() or (ns.EditModeOpen and ns.EditModeOpen()) then
		headerGap.Release(plate)
		return
	end
	if Later(plate) or Later(cluster) then
		return
	end
	if not (headerGap.game and headerGap.At(plate, headerGap.set)) and not headerGap.Take(cluster, plate) then
		return
	end
	if not headerGap.probe then
		local probe = CreateFrame("Frame", nil, UIParent)
		ns.Own[probe] = true
		probe:SetWidth(1)
		probe:SetPoint("TOP", plate, "CENTER")
		probe:SetPoint("BOTTOM", UIParent, "BOTTOM")
		probe:SetScript("OnSizeChanged", function()
			if headerGap.game then
				Soon(headerGap, headerGap.Again)
			end
		end)
		headerGap.probe = probe
	end
	local hx, hy = headerGap.Centre(headerGap.holder)
	local mx, my, mapScale = headerGap.Centre(map)
	local holderTop, holderBottom = headerGap.Edges(headerGap.holder)
	local mapTop, mapBottom = headerGap.Edges(map)
	local okScale, scale = pcall(plate.GetEffectiveScale, plate)
	if not hx or not mx or not holderTop or not mapTop or not okScale or not ns.Finite(scale) or scale <= 0 then
		return
	end
	local above = hy >= my
	local band = (above and holderBottom - mapTop or mapBottom - holderTop) / scale
	local px = Val("minimap", "zoneGap")
	px = ns.Finite(px) and math.max(px, 0) or 0
	local edge = border and not ns.Borderless() and ns.Get("general.thickness") or 0
	local base = ns.Pixels(plate, edge)
	local room = above and ns.MapTextAbove and ns.MapTextAbove()
	if ns.Finite(room) and room > 0 then
		base = math.max(base, room * mapScale / scale)
	end
	local dy = math.min(base + ns.Pixels(plate, px), band)
	local dx = (hx - mx) / scale
	local point, relativePoint, y = "BOTTOM", "TOP", dy
	if not above then
		point, relativePoint, y = "TOP", "BOTTOM", -dy
	end
	local set = headerGap.set
	if not (set and set[1] == point and math.abs(set[4] - dx) < 0.01 and math.abs(set[5] - y) < 0.01 and headerGap.At(plate, set)) then
		set = { point, map, relativePoint, dx, y }
		headerGap.Hang(plate, { set })
		headerGap.set = set
		headerGap.moved = true
	end
	for _, side in ipairs(headerGap.Sides(cluster, plate)) do
		headerGap.Side(side, plate, above, dy - base, band - dy)
	end
end

function headerGap.Again()
	local cluster = Frame("MinimapCluster")
	if not cluster or not ns.Enabled(KEY) then
		return
	end
	Run("minimap", headerGap.Apply, cluster, On("minimap", "minimapBorder"), headerGap.bare)
	if headerGap.moved and ns.MapTextRefresh then
		ns.MapTextRefresh()
	end
end

function ns.MapGapRoom()
	if headerGap.game then
		Soon(headerGap, headerGap.Again)
	end
end

local function ApplyMinimap()
	local art, border = On("minimap", "minimapArt"), On("minimap", "minimapBorder")
	local choice, up = CityChoice(), CityShown() == true
	local cluster = Frame("MinimapCluster")
	local header, plates, glow = Header(cluster)
	local diel = cluster and cluster.DielFrame
	diel = diel ~= nil and not ns.Forbidden(diel) and diel or nil
	local tracking = cluster and Child(cluster, "Tracking")
	local modes = BannerModes(cluster and Child(cluster, "InstanceDifficulty"))
	local ring = art and not (choice == "ring" and up)
	local square = MapShape(Val("minimap", "shape") == "square")
	ring = ring or square
	if Moves("ring", ring) then
		ns.SetFaded(_G.MinimapCompassTexture, ring)
		ns.SetFaded(_G.MinimapCompassTextureUnderlay, ring)
	end
	if Moves("minimap", art) then
		for _, plate in ipairs(plates) do
			ns.SetFaded(plate, art)
		end
		if glow and art then
			ns.SetFaded(glow, true)
		end
		if diel then
			minimap.diel = minimap.diel or ns.RegionWithAtlas(diel, DIEL_BORDER)
			ns.SetFaded(minimap.diel, art)
		end
		ns.SetFaded(tracking and tracking.Background, art)
		for _, mode in ipairs(modes) do
			ns.SetFaded(mode.Background, art)
			ns.SetFaded(mode.Border, art)
		end
	end
	if glow and art then
		FollowGlow(header, glow)
	end
	if header then
		HeaderBorder(header, border)
	end
	if tracking then
		HeaderBorder(TrackingBox(tracking), border)
	end
	for _, mode in ipairs(modes) do
		HeaderBorder(mode, border)
	end
	MapBorder(border, square)
	MapOutline(border and square)
	CityCover(choice == "cover" and up and not square, border)
	headerGap.Apply(cluster, border, ring)
	local night = Val("minimap", "dayNight") == false
	if diel and Moves("daynight", night) then
		ns.SetFaded(diel, night)
	end
	local zone = Frame("MinimapZoneText")
	if zone then
		local hidden = Val("minimap", "zoneText") == false
		if Moves("zonename", hidden) then
			ns.SetFaded(zone, hidden)
		end
		Size(zone, Val("minimap", "zoneSize") or 100, "the zone name")
	end
	for _, entry in ipairs(MAP_BUTTONS) do
		Run("minimap", MapButton, entry, cluster)
	end
end

local function CityChanged()
	if ns.Enabled(KEY) then
		Run("minimap", ApplyMinimap)
		if headerGap.moved and ns.MapTextRefresh then
			ns.MapTextRefresh()
		end
	end
end

local function FollowCity()
	local map = CityMap()
	if not map then
		return
	end
	local done = hooked[map]
	if done == nil then
		done = {}
		hooked[map] = done
	end
	local mini = Frame("Minimap")
	if mini and type(mini.HookScript) == "function" then
		local d = hooked[mini] or {}
		hooked[mini] = d
		if not d.OnShow then
			d.OnShow = true
			mini:HookScript("OnShow", CityChanged)
		end
	end
	if type(map.HookScript) ~= "function" then
		return
	end
	for _, script in ipairs({ "OnShow", "OnHide" }) do
		if not done[script] then
			done[script] = true
			map:HookScript(script, CityChanged)
		end
	end
end

local BAG_MASKS = { "SquareMask", "Mask" }

local function ApplyBag(button)
	local on = On("bags", "bags")
	local rec = bags[button]
	if not rec then
		if not on or Later(button) then
			return
		end
		rec = { outline = ns.Outline(button, button), unmasked = {} }
		bags[button] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, true)
	ns.SetFaded(button.NormalTexture, on)
	ns.SetFaded(button.PushedTexture, on)
	ns.SetFaded(button.SlotHighlightTexture, on)
	local highlight = button.HighlightTexture
	if highlight ~= nil and not ns.IsSecret(highlight) then
		if on then
			local ok, alpha = pcall(highlight.GetAlpha, highlight)
			if ok and not ns.IsSecret(alpha) and type(alpha) == "number" and alpha > 0 then
				rec.alpha = alpha
			end
			ns.SetFaded(highlight, true)
		elseif rec.alpha then
			pcall(highlight.SetAlpha, highlight, rec.alpha)
			rec.alpha = nil
		end
	end
	if on and not rec.hover then
		rec.hover = button:CreateTexture(nil, "HIGHLIGHT", nil, 0)
		ns.Own[rec.hover] = true
		rec.hover:SetAllPoints(button)
		rec.hover:SetColorTexture(1, 1, 1, 0.2)
	end
	if rec.hover then
		rec.hover:SetShown(on)
	end
	local icon = button.icon
	if icon ~= nil and not ns.IsSecret(icon) then
		for _, key in ipairs(BAG_MASKS) do
			local mask = button[key]
			if mask ~= nil and not ns.IsSecret(mask) and (rec.unmasked[key] == true) ~= (on == true) and icon.RemoveMaskTexture and icon.AddMaskTexture then
				rec.unmasked[key] = on == true
				pcall(on and icon.RemoveMaskTexture or icon.AddMaskTexture, icon, mask)
			end
		end
		local ok, atlas = pcall(icon.GetAtlas, icon)
		if ok and not ns.IsSecret(atlas) and (atlas == nil or atlas == "") then
			if on then
				local crop = Crop()
				icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
			elseif rec.cropped then
				icon:SetTexCoord(0, 1, 0, 1)
			end
			rec.cropped = on or nil
		end
	end
end

local function BagHook(button)
	if not ns.IsStopped(KEY) and (bags[button] or On("bags", "bags")) then
		Run("bags", ApplyBag, button)
	end
end

local function BagsPass()
	for _, name in ipairs(BAG_BUTTONS) do
		local button = Frame(name)
		if button then
			BagHook(button)
		end
	end
end

local function RefreshBags()
	local on = On("bags", "bags")
	local bar = Frame("BagsBar")
	if bar then
		local pieces = ns.HandsOff
		if Moves(bar, on) then
			ns.SetFaded(bar.BorderArt, on)
		end
		if on then
			FollowDividers(bar, "bags", "bags", pieces)
		end
		Run("bags", FadeDividers, bar, "bags", "bags", pieces)
	end
	for _, name in ipairs(BAG_BUTTONS) do
		local button = Frame(name)
		if button then
			Run("bags", ApplyBag, button)
		end
	end
end

local function DebuffColour(dispel)
	local kind = ns.Get(KEY .. ".auraTypes") == true and TYPE_ROWS[dispel] and dispel or "None"
	local path = KEY .. "." .. TYPE_ROWS[kind]
	if ns.IsSet(path) then
		return ns.Colour(path)
	end
	local colour = DEBUFF_COLOURS[kind]
	return colour[1], colour[2], colour[3]
end

local function AuraColour(button)
	local kind = button.auraType
	if ns.IsSecret(kind) then
		return
	end
	if kind == "TempEnchant" then
		return ENCHANT_COLOUR[1], ENCHANT_COLOUR[2], ENCHANT_COLOUR[3]
	end
	if kind ~= "Debuff" and kind ~= "DeadlyDebuff" then
		return
	end
	local info, dispel = button.buttonInfo, nil
	if info ~= nil and not ns.IsSecret(info) and type(info) == "table" then
		dispel = info.debuffType
	end
	if ns.IsSecret(dispel) or type(dispel) ~= "string" then
		dispel = "None"
	end
	return DebuffColour(dispel)
end

local function ApplyAura(button)
	local on = On("auras", "auras")
	local rec = auras[button]
	if not rec then
		local icon = button.Icon
		if not on or icon == nil or ns.IsSecret(icon) or type(icon.SetTexCoord) ~= "function" or Later(button) then
			return
		end
		rec = { outline = ns.Outline(button, icon), icon = icon }
		auras[button] = rec
		ns.Count(KEY)
	end
	if rec.on ~= on then
		rec.on = on
		ns.SetOutline(rec.outline, on, false)
		ns.SetFaded(button.DebuffBorder, on)
		ns.SetFaded(button.TempEnchantBorder, on)
	end
	local crop = on and Crop() or nil
	if rec.crop ~= crop then
		rec.crop = crop
		if crop then
			rec.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		else
			rec.icon:SetTexCoord(0, 1, 0, 1)
		end
	end
	if on then
		ns.SetOutlineColour(rec.outline, AuraColour(button))
	else
		ns.SetOutlineColour(rec.outline, nil, nil, nil)
	end
end

local function AuraText(button)
	local duration, count = Val("auras", "durationSize") or 100, Val("auras", "countSize") or 100
	local now = duration ~= 100 or count ~= 100
	if not now and not sized[button] then
		return
	end
	sized[button] = now or nil
	Size(button.Duration, duration, "the duration of a buff")
	Size(button.Count, count, "the stack count of a buff")
end

local function StyleAuraButton(button)
	if ns.Forbidden(button) then
		return
	end
	Run("auras", ApplyAura, button)
	Run("auras", AuraText, button)
end

local function StyleAuraFrame(frame)
	local list = frame.auraFrames
	if list == nil or ns.IsSecret(list) or type(list) ~= "table" then
		return
	end
	for _, button in ipairs(list) do
		StyleAuraButton(button)
	end
end

local function RefreshAuras()
	for _, name in ipairs(AURA_FRAMES) do
		local frame = Frame(name)
		if frame then
			Run("auras", StyleAuraFrame, frame)
		end
	end
	local deadly = Frame("DeadlyDebuffFrame")
	if deadly and deadly.Debuff ~= nil then
		StyleAuraButton(deadly.Debuff)
	end
end

local function XpBorder(bar, statusBar)
	local on = On("xpbars", "xpFrame")
	local rec = borders[bar]
	if not rec then
		if not on or Later(bar) then
			return
		end
		rec = { outline = ns.Outline(bar, statusBar) }
		borders[bar] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, true)
	ns.SetFaded(statusBar.Background, on)
end

local function XpFill(statusBar)
	local rec = fills[statusBar]
	if not On("xpbars", "xpFill") then
		if rec and ns.RestoreFill(statusBar) == false then
			ns.Note(KEY, LABEL .. ": the game refused to put back the default fill of a bar.")
		end
		return
	end
	if not rec then
		rec = {}
		fills[statusBar] = rec
	end
	local region = ns.FillRegion(statusBar)
	if not region then
		return
	end
	local ok, atlas = pcall(region.GetAtlas, region)
	if ok and not ns.IsSecret(atlas) and type(atlas) == "string" and atlas ~= "" then
		rec.atlas = atlas
		rec.colour = FILL_COLOURS[atlas:lower()] or NEUTRAL_FILL
	end
	if rec.colour then
		local flat, refused = ns.FlatFill(statusBar, rec.colour[1], rec.colour[2], rec.colour[3], rec.atlas, nil, RowFile("xpTexture"))
		if flat == false and refused then
			ns.Note(KEY, LABEL .. ": the game refused a flat fill on a bar, which keeps its default fill.")
		end
	end
end

local function XpTextApply(bar)
	local overlay = bar.OverlayFrame
	local text = overlay ~= nil and not ns.IsSecret(overlay) and type(overlay) == "table" and overlay.Text or nil
	if text == nil or ns.IsSecret(text) or type(text) ~= "table" or type(text.SetText) ~= "function" then
		return
	end
	local rec = xpTexts[bar]
	local mode = Val("xpbars", "xpText")
	local line = mode == "hide" and "" or (mode ~= nil and mode ~= "game" and ns.XpLine(bar, mode) or nil)
	if line or (rec and rec.ours) then
		local ok, current = pcall(text.GetText, text)
		if ok and not ns.IsSecret(current) and type(current) == "string" and (current ~= (rec and rec.line)) then
			rec = rec or {}
			xpTexts[bar] = rec
			rec.game = current
		end
	end
	if line then
		rec = rec or {}
		xpTexts[bar] = rec
		rec.ours = true
		rec.line = line
		text:SetText(line)
	elseif rec and rec.ours then
		rec.ours, rec.line = nil, nil
		if rec.game ~= nil then
			text:SetText(rec.game)
		end
	end
end

local function XpTextSize(bar)
	local overlay = bar.OverlayFrame
	if overlay ~= nil and not ns.IsSecret(overlay) and type(overlay) == "table" then
		Size(overlay.Text, Val("xpbars", "xpTextSize") or 100, "the text of an experience bar")
	end
end

local function StyleXpBar(bar)
	local statusBar = bar.StatusBar
	if statusBar == nil or ns.Forbidden(statusBar) then
		return
	end
	Run("xpbars", XpBorder, bar, statusBar)
	Run("xpbars", XpFill, statusBar)
	Run("xpbars", XpTextApply, bar)
	Run("xpbars", XpTextSize, bar)
end

local function StyleXpContainer(container)
	local on = On("xpbars", "xpFrame")
	if on or On("xpbars", "xpDividers") then
		borders.xpTouched = true
	end
	if Moves(container, on) then
		ns.SetFaded(container.BarFrameTexture, on)
	end
	if On("xpbars", "xpDividers") then
		FollowDividers(container, "xpbars", "xpDividers")
	end
	Run("xpbars", FadeDividers, container, "xpbars", "xpDividers")
	local list = container.bars
	if list ~= nil and not ns.IsSecret(list) and type(list) == "table" then
		for _, bar in pairs(list) do
			if not ns.Forbidden(bar) then
				StyleXpBar(bar)
			end
		end
	end
end

local function XpBarsOff()
	return ns.HandsOff() or (ns.XpOwn ~= nil and ns.XpOwn())
end

local function RefreshXpBars()
	if XpBarsOff() then
		return
	end
	for _, name in ipairs(BAR_CONTAINERS) do
		local container = Frame(name)
		if container then
			Run("xpbars", StyleXpContainer, container)
		end
	end
end

local FILL_EVENTS = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_UPDATE_RESTING", "UPDATE_FACTION",
	"MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "PLAYER_MAX_LEVEL_UPDATE", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN", "HONOR_XP_UPDATE", "UNIT_PET_EXPERIENCE" }
local FILL_LATE = 3
local fillQueued, fillLateQueued = false, false

local function XpHasLine(bar)
	return not ns.Forbidden(bar) and ((Val("xpbars", "xpText") or "game") ~= "game" or (xpTexts[bar] ~= nil and xpTexts[bar].ours == true))
end

local function XpTextPass()
	if ns.IsStopped(KEY) or XpBarsOff() then
		return
	end
	for _, name in ipairs(BAR_CONTAINERS) do
		local container = Frame(name)
		local list = container ~= nil and container.bars or nil
		if list ~= nil and not ns.IsSecret(list) and type(list) == "table" then
			for _, bar in pairs(list) do
				if XpHasLine(bar) then
					Run("xpbars", XpTextApply, bar)
				end
			end
		end
	end
end

local function FillPass()
	local animating = false
	if ns.IsStopped(KEY) or XpBarsOff() then
		return false
	end
	for _, name in ipairs(BAR_CONTAINERS) do
		local container = Frame(name)
		local list = container ~= nil and container.bars or nil
		if container ~= nil then
			Run("xpbars", FadeDividers, container, "xpbars", "xpDividers")
		end
		if list ~= nil and not ns.IsSecret(list) and type(list) == "table" then
			for _, bar in pairs(list) do
				local statusBar = not ns.Forbidden(bar) and bar.StatusBar or nil
				if XpHasLine(bar) then
					Run("xpbars", XpTextApply, bar)
				end
				if statusBar ~= nil and not ns.Forbidden(statusBar) and (fills[statusBar] or On("xpbars", "xpFill")) then
					Run("xpbars", XpFill, statusBar)
					if type(statusBar.IsAnimating) == "function" then
						local ok, going = pcall(statusBar.IsAnimating, statusBar)
						if ok and going == true then
							animating = true
						end
					end
				end
			end
		end
	end
	return animating
end

local function QueueFill(later)
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		FillPass()
		return
	end
	if not fillQueued then
		fillQueued = true
		C_Timer.After(0, function()
			fillQueued = false
			FillPass()
		end)
	end
	if later and not fillLateQueued then
		fillLateQueued = true
		local function Late()
			fillLateQueued = false
			if FillPass() then
				fillLateQueued = true
				C_Timer.After(FILL_LATE, Late)
			end
		end
		C_Timer.After(FILL_LATE, Late)
	end
end

local function ApplyMicro(button)
	local on = On("micro", "micro")
	local rec = micro[button]
	if not rec then
		if not on or Later(button) then
			return
		end
		rec = { outline = ns.Outline(button, button) }
		micro[button] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, true)
	ns.SetFaded(button.Background, on)
	ns.SetFaded(button.PushedBackground, on)
	ns.SetFaded(button.Shadow, on)
	ns.SetFaded(button.PushedShadow, on)
end

local function RefreshMicro()
	local on = On("micro", "micro")
	local menu = Frame("MicroMenu")
	if menu and Moves(menu, on) then
		ns.SetFaded(menu.BorderArt, on)
		ns.SetFaded(menu.BackgroundArt, on)
	end
	for _, name in ipairs(MICRO_BUTTONS) do
		local button = Frame(name)
		if button then
			Run("micro", ApplyMicro, button)
		end
	end
end

local function Wanted(part)
	return On(part, OPTION[part])
end

local function FollowGlobal(name, fn)
	if globalHooks[name] or type(hooksecurefunc) ~= "function" or type(_G[name]) ~= "function" then
		return
	end
	globalHooks[name] = true
	hooksecurefunc(name, fn)
end

local function FollowMixin(name, method, fn)
	local mixin = _G[name]
	if mixin ~= nil and not ns.IsSecret(mixin) and type(mixin) == "table" then
		Follow(mixin, method, fn)
	end
end

local function Tint(region)
	if region == nil or ns.IsSecret(region) then
		return nil
	end
	local ok, r, g, b = pcall(region.GetVertexColor, region)
	if ok and not (ns.IsSecret(r) or ns.IsSecret(g) or ns.IsSecret(b)) and type(r) == "number" and type(g) == "number" and type(b) == "number" then
		return r, g, b
	end
end

local function Plate(part, apply, frame, target, on, backdrop)
	local rec = plates[frame]
	if not rec then
		if not on or Later(frame) then
			return nil
		end
		local outline = ns.Outline(frame, target)
		if not outline then
			return nil
		end
		rec = { part = part, apply = apply, outline = outline }
		plates[frame] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, backdrop)
	return rec
end

local function Art(rec, frame, names, on, hide)
	local was = rec.art and rec.art[frame]
	if not (on or was) then
		return
	end
	rec.art = rec.art or {}
	rec.art[frame] = on or nil
	local set = hide and ns.SetHidden or ns.SetFaded
	for _, name in ipairs(names) do
		set(frame[name], on)
	end
end

local function FillOf(bar, on, fallback, r, g, b, tinted, file)
	if on then
		local flat, refused = ns.FlatFill(bar, r, g, b, fallback, tinted, file)
		if flat == false then
			ns.Note(KEY, refused and (LABEL .. ": the game refused a flat fill on a bar, which keeps its default fill.")
				or (LABEL .. ": the default fill of a bar could not be read and is still shown."))
		end
	elseif ns.RestoreFill(bar) == false then
		ns.Note(KEY, LABEL .. ": the game refused to put back the default fill of a bar.")
	end
end

local function Restyle(part)
	local frames = {}
	for frame, rec in pairs(plates) do
		if rec.part == part then
			frames[#frames + 1] = frame
		end
	end
	for _, frame in ipairs(frames) do
		if not ns.Forbidden(frame) then
			Run(part, plates[frame].apply, frame)
		end
	end
end

local function Visit(part, apply, frames)
	if frames == nil or ns.IsSecret(frames) or type(frames) ~= "table" then
		return
	end
	for _, frame in pairs(frames) do
		if not ns.Forbidden(frame) and plates[frame] == nil then
			Run(part, apply, frame)
		end
	end
end

local function Hook(part, apply, always)
	return function(frame)
		if ns.IsStopped(KEY) or ns.Forbidden(frame) then
			return
		end
		local known = plates[frame] ~= nil
		if (always or not known) and (known or Wanted(part)) then
			Run(part, apply, frame)
		end
	end
end

local function ApplyTrackerHeader(header)
	local on = Wanted("tracker headers")
	local rec = Plate("tracker headers", ApplyTrackerHeader, header, header, on, true)
	if not rec then
		return
	end
	if header.AddAnim ~= nil then
		Art(rec, header, { "Background", "Shine", "Glow" }, on, true)
	else
		Art(rec, header, { "Background" }, on)
	end
end

local function ApplyTrackerBar(holder)
	local on = Wanted("tracker bars")
	local bar = Child(holder, "Bar")
	if not bar then
		return
	end
	local rec = Plate("tracker bars", ApplyTrackerBar, holder, bar, on, true)
	if rec then
		Art(rec, bar, TRACKER_BAR_ART, on)
		FillOf(bar, on, BAR_FILE, 1, 1, 1, true, RowFile("trackerTexture"))
	end
end

local function ApplyTrackerItem(button)
	if button.GlowAnim == nil then
		return
	end
	local on = Wanted("tracker items")
	local rec = Plate("tracker items", ApplyTrackerItem, button, button, on, true)
	if rec then
		Art(rec, button, { "NormalTexture" }, on)
		local ok, pushed = pcall(button.GetPushedTexture, button)
		ns.SetFaded(ok and pushed or nil, on)
	end
end

local function ApplyTrackerPanel(container)
	local nine = Child(container, "NineSlice")
	if nine then
		Plate("tracker panel", ApplyTrackerPanel, container, nine, Wanted("tracker panel"), true)
	end
end

do
	local DOWN, UP = 0.25, 0.2

	local function Step(state, elapsed)
		local frame = state.frame
		if frame == nil or state.target == nil then
			state.driver:Hide()
			return
		end
		state.t = state.t + (ns.Finite(elapsed) and elapsed or 0)
		local share = math.min(state.t / state.span, 1)
		local alpha = state.from + (state.target - state.from) * (1 - (1 - share) ^ 2)
		frame:SetAlpha(alpha)
		state.sent, state.broken = alpha, nil
		if share >= 1 then
			state.driver:Hide()
			if state.back then
				state.alpha, state.sent, state.target, state.back = nil, nil, nil, nil
			end
		end
	end

	function ns.TrackerEase(state, frame, target, back, run)
		state.run, state.back = run, back or nil
		local driver = state.driver
		local moving = driver ~= nil and driver:IsShown()
		if state.frame == frame and state.target == target and (moving or state.sent == target) then
			if back and not moving then
				state.alpha, state.sent, state.target, state.back = nil, nil, nil, nil
			end
			return
		end
		if not driver then
			driver = CreateFrame("Frame")
			ns.Own[driver] = true
			driver:Hide()
			driver:SetScript("OnUpdate", function(_, elapsed)
				if state.broken then
					driver:Hide()
					return
				end
				state.broken = true
				state.run(Step, state, elapsed)
			end)
			state.driver = driver
		end
		local ok, now = pcall(frame.GetAlpha, frame)
		local from = (ok and ns.Finite(now)) and now or state.sent or target
		state.frame, state.target, state.from, state.t, state.broken = frame, target, from, 0, nil
		state.span = target < from and DOWN or UP
		state.sent = from
		driver:Show()
	end

	function ns.TrackerEaseStop(state)
		if state.driver then
			state.driver:Hide()
		end
		state.target, state.back = nil, nil
	end

	local HOVER_EVERY = 0.1

	local function Watch(state)
		local part = state.hoverPart
		local ok, over = pcall(part.IsMouseOver, part)
		over = ok and (ns.IsSecret(over) or over == true)
		if over ~= state.over then
			state.over = over
			ns.TrackerEase(state, state.hoverFrame, over and (state.alpha or 1) or state.wanted, false, state.hoverRun)
		end
	end

	function ns.TrackerHover(state, frame, part, wanted, run)
		if wanted == nil or frame == nil or part == nil or type(part.IsMouseOver) ~= "function" then
			if state.hover then
				state.hover:Hide()
			end
			state.over = nil
			return
		end
		state.hoverFrame, state.hoverPart, state.wanted, state.hoverRun = frame, part, wanted, run
		local hover = state.hover
		if not hover then
			hover = CreateFrame("Frame")
			ns.Own[hover] = true
			hover:Hide()
			local waited = 0
			hover:SetScript("OnUpdate", function(_, elapsed)
				waited = waited + (ns.Finite(elapsed) and elapsed or 0)
				if waited >= HOVER_EVERY then
					waited = 0
					state.hoverRun(Watch, state)
				end
			end)
			state.hover = hover
		end
		hover:Show()
	end
end

function look.run(fn, ...)
	Run("tracker panel", fn, ...)
end

local function TrackerAlpha(_, fight)
	local frame = Frame("ObjectiveTrackerFrame")
	if not frame or type(frame.SetAlpha) ~= "function" then
		return
	end
	if fight == nil then
		fight = InCombatLockdown()
	end
	local percent = Val("tracker panel", "trackerCombat") or 100
	local wanted = fight and percent < 100 and percent / 100 or nil
	ns.TrackerHover(look, frame, wanted and Child(frame, "NineSlice"), wanted, look.run)
	if wanted ~= nil then
		if look.alpha == nil then
			local given = ns.FadeGiven and ns.FadeGiven(frame)
			local ok, alpha = pcall(frame.GetAlpha, frame)
			look.alpha = ns.Finite(given) and given or ((ok and ns.Finite(alpha)) and alpha or 1)
		end
		ns.TrackerEase(look, frame, look.over and look.alpha or wanted, false, look.run)
	elseif look.alpha ~= nil then
		if ns.FadeTakesBack and ns.FadeTakesBack(frame, look.alpha) then
			ns.TrackerEaseStop(look)
			look.alpha, look.sent = nil, nil
		else
			ns.TrackerEase(look, frame, look.alpha, true, look.run)
		end
	end
end

function ns.TrackerFades(frame)
	return look.sent ~= nil and frame ~= nil and frame == _G.ObjectiveTrackerFrame
end

local function HeaderSizes(headers)
	local percent = Val("tracker headers", "trackerHeaderSize") or 100
	for _, header in ipairs(headers) do
		if not ns.Forbidden(header) then
			Size(header.Text, percent, "a tracker heading")
		end
	end
end

local function TrackerBarsPass()
	if ns.IsStopped(KEY) or not Wanted("tracker bars") then
		return
	end
	for _, name in ipairs(TRACKER_MODULES) do
		local module = Frame(name)
		if module then
			Visit("tracker bars", ApplyTrackerBar, module.usedProgressBars)
			Visit("tracker bars", ApplyTrackerBar, module.usedTimerBars)
		end
	end
end
local ItemHook = Hook("tracker items", ApplyTrackerItem)

local function RefreshTracker()
	Restyle("tracker headers")
	Restyle("tracker bars")
	Restyle("tracker items")
	Restyle("tracker panel")
	local container = Frame("ObjectiveTrackerFrame")
	if container then
		Visit("tracker panel", ApplyTrackerPanel, { container })
	end
	Run("tracker panel", TrackerAlpha, look)
	local headers = { container and container.Header }
	local bars = Wanted("tracker bars")
	for _, name in ipairs(TRACKER_MODULES) do
		local module = Frame(name)
		if module then
			headers[#headers + 1] = module.Header
			if bars then
				OnScript(module, "OnSizeChanged", "bars", TrackerBarsPass)
			end
			Visit("tracker bars", ApplyTrackerBar, module.usedProgressBars)
			Visit("tracker bars", ApplyTrackerBar, module.usedTimerBars)
			Visit("tracker items", ApplyTrackerItem, module.usedRightEdgeFrames)
		end
	end
	Visit("tracker headers", ApplyTrackerHeader, headers)
	Run("tracker headers", HeaderSizes, headers)
	if Wanted("tracker items") then
		FollowMixin("QuestObjectiveItemButtonMixin", "SetUp", ItemHook)
	end
	if ns.QuestCountRefresh ~= nil then
		ns.QuestCountRefresh()
	end
	if ns.QuestieSkinRefresh ~= nil then
		ns.QuestieSkinRefresh()
	end
end

local function ApplyLootWindow(window)
	local on = Wanted("loot window")
	local rec = Plate("loot window", ApplyLootWindow, window, window, on, true)
	if not rec then
		return
	end
	local nine, back = Child(window, "NineSlice"), Child(window, "Bg")
	if nine then
		Art(rec, nine, HEADER_PIECES, on)
	end
	if back then
		Art(rec, back, PANEL_FILL, on)
	end
end

local function ApplyLootRow(row)
	local item = Child(row, "Item")
	if not item then
		return
	end
	local on = Wanted("loot window")
	local rec = Plate("loot window", ApplyLootRow, row, row, on, false)
	if not rec then
		return
	end
	if on and not rec.slot and not Later(item) then
		rec.slot = ns.Outline(item, item)
	end
	ns.SetOutline(rec.slot, on, on)
	Art(rec, row, { "BorderFrame" }, on)
	Art(rec, item, SLOT_ART, on)
	local icon = item.icon
	if icon ~= nil and not ns.IsSecret(icon) and (on or rec.cropped) then
		rec.cropped = on or nil
		if on then
			local crop = Crop()
			icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		else
			icon:SetTexCoord(0, 1, 0, 1)
		end
	end
	local quality = Child(row, "QualityText")
	local hide = on and ns.Get(KEY .. ".lootQualityText") ~= true
	if quality and (hide or rec.qualityHidden) then
		rec.qualityHidden = hide or nil
		ns.SetHidden(quality, hide)
	end
	local r, g, b
	if on then
		r, g, b = Tint(row.NameFrame)
	end
	ns.SetOutlineColour(rec.outline, r, g, b)
	ns.SetOutlineColour(rec.slot, r, g, b)
end

function ROLL.Ours(frame)
	for index = 1, ROLL_FRAMES do
		if rawequal(_G["GroupLootFrame" .. index], frame) then
			return true
		end
	end
	return false
end

function ROLL.Timer(frame, timer, on, rec)
	if not (on or rec.timerMoved) then
		return
	end
	rec.timerMoved = on or nil
	if ROLL.Ours(frame) then
		local spot = ROLL.timer
		timer:ClearAllPoints()
		if on then
			timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", spot.inset, spot.lift)
			timer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -spot.inset, spot.lift)
			timer:SetHeight(spot.height)
		else
			timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", spot.x, spot.y)
			timer:SetSize(spot.width, spot.height)
		end
	end
	local level = Level(frame)
	if level then
		timer:SetFrameLevel(math.max(0, level + (on and 1 or -1)))
	end
end

function ROLL.Buttons(frame, on, rec)
	local holder = Child(frame, "LootButtonContainer")
	if not holder or not ROLL.Ours(frame) or not (on or rec.buttonsMoved) then
		return
	end
	rec.buttonsMoved = on or nil
	local side = on and ROLL.flatButton or ROLL.button
	for _, spot in ipairs(on and ROLL.flat or ROLL.game) do
		local button = Child(holder, spot[1])
		local relative = spot[3] == "frame" and frame or spot[3] == "container" and holder or Child(holder, spot[3])
		if button and relative then
			button:ClearAllPoints()
			button:SetPoint(spot[2], relative, spot[4], spot[5], spot[6])
			button:SetSize(side, side)
		end
	end
end

ROLL.red, ROLL.redBar, ROLL.every = { 1, 0.25, 0.25 }, { 1, 0.2, 0.2 }, 0.1

function ROLL.Red(clock, red)
	if red == (clock.red == true) then
		return
	end
	local timer = clock.timer
	if red and clock.colour == nil then
		local ok, r, g, b = pcall(timer.GetStatusBarColor, timer)
		clock.colour = (ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) and { r, g, b } or { 1, 1, 0 }
	end
	local bar = red and ROLL.redBar or clock.colour
	if bar then
		pcall(timer.SetStatusBarColor, timer, bar[1], bar[2], bar[3])
	end
	if red then
		clock.text:SetTextColor(ROLL.red[1], ROLL.red[2], ROLL.red[3])
	else
		clock.text:SetTextColor(1, 1, 1)
	end
	clock.red = red or nil
end

function ROLL.Tick(clock, value)
	local secs
	if clock.on and Wanted("loot rolls") and ns.Get(KEY .. ".lootRollTime") == true and ns.Finite(value) and value > 0 then
		secs = math.ceil(value / 1000)
	end
	if secs == clock.secs then
		return
	end
	local was = clock.secs
	clock.secs = secs
	clock.text:SetText(secs and tostring(secs) or "")
	ROLL.Red(clock, secs ~= nil and secs < 10)
	if secs ~= nil and secs <= ROLL.warnAt and ns.Finite(was) and was > ROLL.warnAt then
		ROLL.Sound(ns.Get(KEY .. ".lootRollSound"))
	end
end

ROLL.kits, ROLL.warnAt = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }, 5

function ROLL.Sound(choice)
	local kit = ROLL.kits[choice]
	local sound = kit and type(ns.SOUNDS) == "table" and ns.SOUNDS[kit]
	if type(sound) == "table" and type(ns.PlayKit) == "function" then
		ns.PlayKit(sound[1])
	end
end

function ns.LootRollSound()
	ROLL.Sound(ns.Get(KEY .. ".lootRollSound"))
end

function ns.LootRollSoundPicked(path)
	if type(path) ~= "string" or InCombatLockdown() or not (type(ns.PanelShown) == "function" and ns.PanelShown() == true) then
		return
	end
	ROLL.Sound(ns.Get(path))
end

function ROLL.Time(frame, timer, on, rec)
	local want = on and ROLL.Ours(frame) and ns.Get(KEY .. ".lootRollTime") == true
	local clock = rec.clock
	if want and clock == nil and not Later(frame) then
		local holder = CreateFrame("Frame", nil, frame)
		ns.Own[holder] = true
		holder:SetAllPoints(frame)
		local text = ns.OwnText(holder, "OVERLAY", "GameFontHighlightSmall")
		if not text then
			rec.clock = false
			return
		end
		text:SetJustifyH("RIGHT")
		text:SetPoint("BOTTOMRIGHT", timer, "TOPRIGHT", 0, 2)
		clock = { holder = holder, text = text, timer = timer, wait = 0 }
		rec.clock = clock
		holder:SetScript("OnUpdate", function(_, elapsed)
			clock.wait = clock.wait - elapsed
			if clock.wait > 0 then
				return
			end
			clock.wait = ROLL.every
			local ok, value = pcall(timer.GetValue, timer)
			ROLL.Tick(clock, ok and value or nil)
		end)
		holder:SetScript("OnHide", function()
			ROLL.Tick(clock, nil)
		end)
	end
	if not clock then
		return
	end
	clock.on = want or nil
	if want then
		local level = Level(timer)
		if level then
			clock.holder:SetFrameLevel(level + 1)
		end
		clock.wait = 0
	else
		ROLL.Tick(clock, nil)
	end
	clock.holder:SetShown(want)
end

local function ApplyRoll(frame)
	local icon, timer = Child(frame, "IconFrame"), Child(frame, "Timer")
	if not icon then
		return
	end
	local on = Wanted("loot rolls")
	local rec = Plate("loot rolls", ApplyRoll, frame, frame, on, true)
	if not rec then
		return
	end
	if on and not rec.icon and not Later(icon) then
		rec.icon = ns.Outline(icon, icon)
	end
	ns.SetOutline(rec.icon, on, on)
	Art(rec, frame, { "Background", "Border" }, on)
	Art(rec, icon, { "Border" }, on)
	local r, g, b
	if on then
		r, g, b = Tint(frame.Border)
	end
	ns.SetOutlineColour(rec.icon, r, g, b)
	local art = icon.Icon
	if art ~= nil and not ns.IsSecret(art) and (on or rec.cropped) then
		rec.cropped = on or nil
		local crop = on and Crop() or 0
		art:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	end
	if timer then
		if on and not rec.timer and not Later(timer) then
			rec.timer = ns.Outline(timer, timer)
		end
		ns.SetOutline(rec.timer, on, false)
		FillOf(timer, on, ROLL_FILE, 1, 1, 1, true)
		ROLL.Timer(frame, timer, on, rec)
		ROLL.Time(frame, timer, on, rec)
	end
	ROLL.Buttons(frame, on, rec)
end

local RowHook, RollHook = Hook("loot window", ApplyLootRow, true), Hook("loot rolls", ApplyRoll, true)

local function LootRows(window)
	local box = Child(window, "ScrollBox")
	local target = box and Child(box, "ScrollTarget")
	if not target then
		return {}
	end
	local ok, rows = pcall(function() return { target:GetChildren() } end)
	return ok and rows or {}
end

function ROLL.Moved()
	if not (ns.Enabled(KEY) and not ns.PartStopped(KEY, ROLL.part) and ns.Enabled("movers") and type(ns.MoverSaved) == "function"
		and ns.MoverSaved(ROLL.mover)) then
		return false
	end
	local input = _G.InputUtil
	if input ~= nil and not ns.IsSecret(input) and type(input) == "table" and type(input.IsGamepadUIEnabled) == "function" then
		local ok, pad = pcall(input.IsGamepadUIEnabled)
		return ok and not ns.IsSecret(pad) and pad ~= true
	end
	return true
end

function ROLL.Anchor()
	local left, bottom = ns.MoverSpot(ROLL.mover, "BOTTOMLEFT")
	local right, top = ns.MoverSpot(ROLL.mover, "TOPRIGHT")
	if not (left and right) then
		return nil
	end
	local anchor = ROLL.anchor
	if not anchor then
		anchor = CreateFrame("Frame", nil, UIParent)
		ns.Own[anchor] = true
		ROLL.anchor = anchor
	end
	anchor:ClearAllPoints()
	anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	anchor:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
	return anchor
end

function ROLL.Place()
	local container = Frame("GroupLootContainer")
	local list = container and container.rollFrames
	if list == nil or ns.IsSecret(list) or type(list) ~= "table" then
		return
	end
	local step = container.reservedSize
	if ns.IsSecret(step) or type(step) ~= "number" or step <= 0 then
		step = ROLL.step
	end
	local anchor = ROLL.Moved() and ROLL.Anchor() or nil
	local down = ns.Get(KEY .. ".lootRollsGrow") == "down"
	for index, frame in pairs(list) do
		if type(index) == "number" and not ns.Forbidden(frame) and (anchor or ROLL.moved[frame]) then
			frame:ClearAllPoints()
			if not anchor then
				ROLL.moved[frame] = nil
				frame:SetPoint("CENTER", container, "BOTTOM", 0, step * (index - 0.5))
			elseif down then
				ROLL.moved[frame] = true
				frame:SetPoint("TOP", anchor, "TOP", 0, -step * (index - 1))
			else
				ROLL.moved[frame] = true
				frame:SetPoint("BOTTOM", anchor, "BOTTOM", 0, step * (index - 1))
			end
		end
	end
end

function ROLL.Layout()
	if not ns.IsStopped(KEY) and (ROLL.Moved() or next(ROLL.moved) ~= nil) then
		Run(ROLL.part, ROLL.Place)
	end
end

function ROLL.Spot()
	if ROLL.Moved() then
		ns.FollowGlobal("GroupLootContainer_Update", ROLL.Layout)
	end
	Run(ROLL.part, ROLL.Place)
end

local function RefreshLoot()
	Restyle("loot window")
	Restyle("loot rolls")
	local window = Frame("LootFrame")
	Visit("loot window", ApplyLootWindow, { window })
	if window then
		Visit("loot window", ApplyLootRow, LootRows(window))
	end
	local rolls = {}
	for index = 1, ROLL_FRAMES do
		rolls[index] = Frame("GroupLootFrame" .. index)
	end
	Visit("loot rolls", ApplyRoll, rolls)
	if Wanted("loot window") then
		FollowMixin("LootFrameElementMixin", "Init", RowHook)
	end
	if Wanted("loot rolls") then
		FollowGlobal("GroupLootFrame_SetupItemDisplay", RollHook)
	end
	ROLL.Spot()
end

function ns.LootRollsShown()
	return ns.Enabled(KEY)
end

function ns.LootRollsMoved()
	if not ns.IsStopped(KEY) then
		ROLL.Spot()
	end
end

function ns.LootRollsStart(x, y)
	local game = Frame("GroupLootContainer")
	local ok, shown = false, false
	if game then
		ok, shown = pcall(game.IsShown, game)
	end
	local frame = (ok and not ns.IsSecret(shown) and shown == true) and game or Frame("BottomManagedFrameContainer")
	if not frame or not UIParent then
		return x, y
	end
	local okBottom, bottom = pcall(frame.GetBottom, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	local okParent, parentScale = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (okBottom and okScale and okParent and ns.Finite(bottom) and ns.Finite(scale) and ns.Finite(parentScale) and parentScale > 0) then
		return x, y
	end
	local first = Frame("GroupLootFrame1")
	local okHeight, height = false, nil
	if first then
		okHeight, height = pcall(first.GetHeight, first)
	end
	if not (okHeight and ns.Finite(height)) then
		height = 67
	end
	return x, bottom * scale / parentScale + ROLL.step / 2 - height / 2
end

local function ApplyAlert(frame)
	local on = Wanted("alerts")
	local rec = Plate("alerts", ApplyAlert, frame, frame, on, true)
	if rec then
		Art(rec, frame, ALERT_ART, on)
	end
end

local function ActiveAlerts(system)
	local pool = system.alertFramePool
	if pool == nil or ns.IsSecret(pool) or type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then
		return
	end
	for frame in pool:EnumerateActive() do
		if not ns.Forbidden(frame) and plates[frame] == nil then
			ApplyAlert(frame)
		end
	end
end

local function RefreshAlerts()
	Restyle("alerts")
	for _, name in ipairs(ALERT_SYSTEMS) do
		local system = _G[name]
		if system ~= nil and not ns.IsSecret(system) and type(system) == "table" then
			Run("alerts", ActiveAlerts, system)
		end
	end
end

local function AlertsPass()
	if ns.IsStopped(KEY) or not Wanted("alerts") then
		return
	end
	for _, name in ipairs(ALERT_SYSTEMS) do
		local system = _G[name]
		if system ~= nil and not ns.IsSecret(system) and type(system) == "table" then
			Run("alerts", ActiveAlerts, system)
		end
	end
end

function MIRROR.Reset(clock)
	clock.last, clock.falling = nil, nil
	if clock.secs ~= nil then
		clock.secs = nil
		clock.text:SetText("")
	end
	if clock.red then
		clock.red = nil
		clock.text:SetTextColor(1, 1, 1)
	end
end

function MIRROR.Tick(clock)
	local value
	if clock.on and Wanted("mirror timers") and ns.Get(KEY .. ".mirrorTime") == true then
		local running = clock.timer.timer
		if running ~= nil and not ns.IsSecret(running) then
			local ok, seconds = pcall(clock.bar.GetValue, clock.bar)
			if ok and ns.Finite(seconds) and seconds >= 0 then
				value = seconds
			end
		end
	end
	if value == nil then
		MIRROR.Reset(clock)
		return
	end
	if clock.last ~= nil and value ~= clock.last then
		clock.falling = value < clock.last
	end
	clock.last = value
	local secs = math.ceil(value)
	if secs ~= clock.secs then
		clock.secs = secs
		clock.text:SetText(("%d:%02d"):format(math.floor(secs / 60), secs % 60))
	end
	local red = clock.falling == true and secs < 10
	if red ~= (clock.red == true) then
		clock.red = red or nil
		if red then
			clock.text:SetTextColor(MIRROR.red[1], MIRROR.red[2], MIRROR.red[3])
		else
			clock.text:SetTextColor(1, 1, 1)
		end
	end
end

function MIRROR.Time(timer, bar, on, rec)
	local want = on and ns.Get(KEY .. ".mirrorTime") == true
	local clock = rec.clock
	if want and clock == nil and not Later(timer) then
		local holder = CreateFrame("Frame", nil, timer)
		ns.Own[holder] = true
		holder:SetAllPoints(timer)
		local text = ns.OwnText(holder, "OVERLAY", "GameFontHighlightSmall")
		if not text then
			rec.clock = false
			return
		end
		text:SetJustifyH("RIGHT")
		text:SetPoint("RIGHT", bar, "BOTTOMRIGHT", -4, -7)
		clock = { holder = holder, text = text, timer = timer, bar = bar, wait = 0 }
		rec.clock = clock
		holder:SetScript("OnUpdate", function(_, elapsed)
			clock.wait = clock.wait - elapsed
			if clock.wait > 0 then
				return
			end
			clock.wait = MIRROR.every
			MIRROR.Tick(clock)
		end)
		holder:SetScript("OnHide", function()
			MIRROR.Reset(clock)
		end)
	end
	if not clock then
		return
	end
	clock.on = want or nil
	clock.wait = 0
	if not want then
		MIRROR.Reset(clock)
	end
	clock.holder:SetShown(want)
end

local function ApplyMirror(timer)
	local on = Wanted("mirror timers")
	local bar = Child(timer, "StatusBar")
	if not bar then
		return
	end
	local rec = Plate("mirror timers", ApplyMirror, timer, bar, on, true)
	if not rec then
		return
	end
	if rec.back == nil then
		rec.back = ns.RegionWithAtlas(timer, MIRROR_BACKGROUND) or false
		if not rec.back then
			ns.Note(KEY, LABEL .. ": the default background of a breath or fatigue timer was not found and is still shown.")
		end
	end
	Art(rec, timer, { "Border", "TextBorder" }, on)
	ns.SetFaded(rec.back or nil, on)
	local region = on and ns.FillRegion(bar)
	if region then
		local ok, atlas = pcall(region.GetAtlas, region)
		if ok and not ns.IsSecret(atlas) and type(atlas) == "string" and atlas ~= "" then
			rec.atlas = atlas
		end
	end
	local r, g, b = ns.Colour("castbars." .. (MIRROR_FILLS[(rec.atlas or ""):lower()] or "castColour"))
	FillOf(bar, on, rec.atlas, r, g, b)
	MIRROR.Time(timer, bar, on, rec)
end

local function ApplyCountdown(bar)
	local on = Wanted("countdown timers")
	local rec = Plate("countdown timers", ApplyCountdown, bar, bar, on, false)
	if not rec then
		return
	end
	if rec.border == nil then
		local ok, name = pcall(bar.GetName, bar)
		local region = ok and not ns.IsSecret(name) and type(name) == "string" and _G[name .. "Border"] or nil
		rec.border = region ~= nil and not ns.IsSecret(region) and region or false
		if not rec.border then
			ns.Note(KEY, LABEL .. ": the default frame of a countdown timer was not found and is still shown.")
		end
	end
	ns.SetFaded(rec.border or nil, on)
	FillOf(bar, on, BAR_FILE, 1, 1, 1, true)
end

local MirrorHook = Hook("mirror timers", ApplyMirror, true)

local function MirrorPass()
	local container = Frame("MirrorTimerContainer")
	local timers = container and container.mirrorTimers
	if timers == nil or ns.IsSecret(timers) or type(timers) ~= "table" then
		return
	end
	for _, timer in pairs(timers) do
		MirrorHook(timer)
	end
end

local function CountdownBars(tracker)
	local bars, list = {}, tracker.timerList
	if list ~= nil and not ns.IsSecret(list) and type(list) == "table" then
		for _, timer in pairs(list) do
			if not ns.Forbidden(timer) then
				bars[#bars + 1] = timer.bar
			end
		end
	end
	return bars
end

local function CountdownHook(tracker)
	if not ns.IsStopped(KEY) and not ns.Forbidden(tracker) and Wanted("countdown timers") then
		Visit("countdown timers", ApplyCountdown, CountdownBars(tracker))
	end
end

local function RefreshTimers()
	Restyle("mirror timers")
	Restyle("countdown timers")
	local container = Frame("MirrorTimerContainer")
	local timers = container and container.mirrorTimers
	Visit("mirror timers", ApplyMirror, timers)
	local tracker = Frame("TimerTracker")
	if tracker then
		Visit("countdown timers", ApplyCountdown, CountdownBars(tracker))
	end
	if Wanted("countdown timers") then
		FollowGlobal("TimerTracker_StartTimerOfType", CountdownHook)
	end
end

local function ApplyQueue(frame)
	local on = Wanted("queue status")
	local rec = Plate("queue status", ApplyQueue, frame, frame, on, true)
	local nine = rec and Child(frame, "NineSlice")
	if nine then
		Art(rec, nine, HEADER_PIECES, on)
	end
end

local function ApplyMeter(window)
	local header = window.Header
	if header == nil or ns.IsSecret(header) or type(header) ~= "table" then
		return
	end
	local on = Wanted("damage meter")
	local rec = Plate("damage meter", ApplyMeter, window, header, on, true)
	if rec then
		Art(rec, window, { "Header" }, on)
	end
end

local function ApplyZoneBar(widget)
	local bar = Child(widget, "Bar")
	if not bar or bar.BorderLeft == nil then
		return
	end
	local on = Wanted("zone bars")
	local rec = Plate("zone bars", ApplyZoneBar, widget, bar, on, true)
	if rec then
		Art(rec, bar, WIDGET_ART, on)
	end
end

local function MeterWindows()
	local windows = {}
	for index = 1, METER_WINDOWS do
		windows[index] = Frame("DamageMeterSessionWindow" .. index)
	end
	return windows
end

local function MeterPass()
	if not ns.IsStopped(KEY) and Wanted("damage meter") then
		Visit("damage meter", ApplyMeter, MeterWindows())
	end
end
local ZoneHook = Hook("zone bars", ApplyZoneBar)

local function RefreshOther()
	Restyle("queue status")
	Restyle("damage meter")
	Restyle("zone bars")
	Visit("queue status", ApplyQueue, { Frame("QueueStatusFrame") })
	Visit("damage meter", ApplyMeter, MeterWindows())
	for _, name in ipairs(WIDGET_CONTAINERS) do
		local container = Frame(name)
		if container then
			Visit("zone bars", ApplyZoneBar, container.widgetFrames)
		end
	end
	if Wanted("zone bars") then
		FollowMixin("UIWidgetTemplateStatusBarMixin", "Setup", ZoneHook)
	end
end

local function RefreshMinimap()
	Run("minimap", FollowCity)
	Run("minimap", ApplyMinimap)
	Run("minimap", ZoomSeen, minimap, false)
	if ns.MapTextRefresh then
		ns.MapTextRefresh()
	end
end

local function CityMask(map)
	local ok, canvas = pcall(Child, map, "MapCanvas")
	if not ok or canvas == nil then
		return nil
	end
	local read, use, mask = pcall(function() return canvas.useMaskTexture, canvas.maskTexture end)
	if not read or ns.IsSecret(use) or ns.IsSecret(mask) then
		return nil
	end
	return use == true and mask ~= nil
end

local function CityAsked()
	local api = _G.C_Minimap
	if type(api) ~= "table" or type(api.ShouldUseHybridMinimap) ~= "function" then
		return "unknown"
	end
	local ok, asked = pcall(api.ShouldUseHybridMinimap)
	if not ok or ns.IsSecret(asked) or type(asked) ~= "boolean" then
		return "unknown"
	end
	return asked and "yes" or "no"
end

local function CityStatus()
	if not ns.Enabled(KEY) then
		return {}
	end
	local asked = ", game asks for it: " .. CityAsked() .. "."
	local map = CityMap()
	if map == nil then
		return { "Minimap in cities: " .. (_G.HybridMinimap == nil and "city map not loaded" or "city map cannot be read") .. asked }
	end
	local shown = CityShown()
	if shown == nil then
		return { "Minimap in cities: off, the game does not say whether the city map is shown" .. asked }
	end
	if not shown then
		return { "Minimap in cities: city map not shown" .. asked }
	end
	local facts, stack, mask = {}, Stack(map), CityMask(map)
	if stack then
		facts[#facts + 1] = stack
	end
	if mask ~= nil then
		facts[#facts + 1] = mask and "game's mask set" or "game's mask not set"
	end
	local line = "city map shown" .. (#facts > 0 and (" (" .. table.concat(facts, ", ") .. ")") or "")
	local cover = minimap.cover
	if cover and cover.on then
		local at = Stack(cover.frame)
		line = line .. ", cover shown" .. (at and (" (" .. at .. ")") or "")
		local ok, seen = pcall(cover.frame.IsVisible, cover.frame)
		if ok and not ns.IsSecret(seen) and seen == false then
			line = line .. ", not visible"
		end
	else
		line = line .. ", no cover" .. (minimap.blocked and CityChoice() == "cover" and " (the game does not let the minimap be read)" or "")
	end
	return { "Minimap in cities: " .. line .. asked }
end

local function Status()
	local lines = CityStatus()
	if minimap.zoomBlind and Val("minimap", "zoomReset") ~= nil then
		lines[#lines + 1] = "Minimap zoom out: off, the game does not say the zoom level."
	end
	return lines
end

local function AurasShown()
	if _G.BuffFrame == nil and _G.DebuffFrame == nil and _G.DeadlyDebuffFrame == nil then
		return false
	end
	return On("auras", "auras") or (Val("auras", "durationSize") or 100) ~= 100 or (Val("auras", "countSize") or 100) ~= 100 or next(auras) ~= nil
end

local function HookGameEvents()
	local manager = Frame("StatusTrackingBarManager")
	if manager ~= nil and not XpBarsOff() then
		OnScript(manager, "OnEvent", "xptext", XpTextPass)
	end
	local buff = Frame("BuffFrame")
	if buff ~= nil then
		OnScript(buff, "OnEvent", "auraevents", function()
			if AurasShown() then
				RefreshAuras()
			end
		end)
	end
end

function Refresh()
	if ns.XpBarRefresh ~= nil then
		ns.XpBarRefresh()
	end
	HookGameEvents()
	RefreshMinimap()
	RefreshBags()
	RefreshAuras()
	RefreshXpBars()
	RefreshMicro()
	RefreshTracker()
	RefreshLoot()
	RefreshAlerts()
	if ns.ErrorFilterRefresh ~= nil then
		ns.ErrorFilterRefresh()
	end
	if ns.ScreenTextRefresh ~= nil then
		ns.ScreenTextRefresh()
	end
	if ns.MeterClearRefresh ~= nil then
		ns.MeterClearRefresh()
	end
	if ns.HitTableRefresh ~= nil then
		ns.HitTableRefresh()
	end
	RefreshTimers()
	RefreshOther()
	if ns.MapButtonsChanged then
		ns.MapButtonsChanged()
	end
end

ns.Register(KEY, {
	label = LABEL, Start = Refresh, Refresh = Refresh, Resized = RefreshMinimap, Status = Status,
	filters = { ADDON_LOADED = function(name) return not ns.IsSecret(name) and (name == CITY_ADDON or name == "Blizzard_TimeManager") end },
	events = {
		ADDON_LOADED = RefreshMinimap,
		PLAYER_ENTERING_WORLD = function()
			RefreshMinimap()
			QueueFill()
		end,
		MINIMAP_UPDATE_ZOOM = function() Run("minimap", ZoomSeen, minimap, true) end,
		PLAYER_REGEN_DISABLED = function() Run("tracker panel", TrackerAlpha, look, true) end,
		PLAYER_REGEN_ENABLED = function() Run("tracker panel", TrackerAlpha, look, false) end,
	},
})
for _, event in ipairs(FILL_EVENTS) do
	ns.AddEvent(KEY, event, function()
		QueueFill(true)
	end)
end

local function ForPlayer(unit) return not ns.IsSecret(unit) and (unit == "player" or unit == "vehicle") end
local function ForCVar(name) return not ns.IsSecret(name) and name == "rotateMinimap" end
local function SquareMap() return minimap.squared == true end
local function BagsStyled() return next(bags) ~= nil end
local function AlertsWanted() return _G.LootAlertSystem ~= nil and Wanted("alerts") end
local function MirrorsWanted() return _G.MirrorTimerContainer ~= nil and Wanted("mirror timers") end
local function MeterWanted() return _G.DamageMeter ~= nil and Wanted("damage meter") end
local function After(events, fn, present, filter)
	for _, event in ipairs(events) do
		ns.AddEvent(KEY, event, function()
			if present() then
				Soon(fn, fn)
			end
		end, filter)
	end
end
After({ "CVAR_UPDATE" }, ReMask, SquareMap, ForCVar)
ns.AddEvent(KEY, "EDIT_MODE_LAYOUTS_UPDATED", function()
	if headerGap.Look then
		headerGap.Look()
	end
end)
After({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_INVENTORY_ALERTS", "INVENTORY_SEARCH_UPDATE",
	"PLAYER_ENTERING_WORLD" }, BagsPass, BagsStyled)
After({ "UNIT_AURA" }, RefreshAuras, AurasShown, ForPlayer)
After({ "GROUP_ROSTER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_IN_COMBAT_CHANGED" }, RefreshAuras, AurasShown)
After({ "LOOT_ITEM_ROLL_WON", "SHOW_LOOT_TOAST", "SHOW_PVP_FACTION_LOOT_TOAST", "SHOW_RATED_PVP_REWARD_TOAST", "SHOW_LOOT_TOAST_LEGENDARY_LOOTED" },
	AlertsPass, AlertsWanted)
After({ "MIRROR_TIMER_START", "PLAYER_ENTERING_WORLD" }, MirrorPass, MirrorsWanted)
After({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET", "PLAYER_IN_COMBAT_CHANGED", "GROUP_JOINED",
	"GROUP_LEFT", "PLAYER_ENTERING_WORLD" }, MeterPass, MeterWanted)

ns.ClickPathReporter(function()
	if rawget(borders, "xpTouched") then
		return "Click path: Flat UI restyled the experience bar."
	end
	return nil
end)
