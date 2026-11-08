local _, ns = ...

-- The threat look of a nameplate (Nameplates, Threat): a ring in the threat colour around the health bar, the threat colour on the health bar
-- border and a fade of the enemies whose threat you want. The threat core (PlateThreat.lua, ns.PlateThreat) reads the threat of each plate and says
-- when it changes; this file draws what that state says and asks the game nothing about threat. Before the core is there every row here does nothing.
-- The ring is a frame of Flat UI's own on the health bar with an outline of its own (ns.Outline), made and anchored out of combat on a plate the game
-- may protect, as the low health border is (HealthColour.lua); in a fight only its colour and visibility change, which are texture calls.
-- The border is a slot of the plate's border colour in Nameplates.lua (ns.PlateThreatBorder): below the target, the focus and the mouseover, above
-- the colours of Elite, Rare and Boss.
-- The fade is the alpha of the game's nameplate unit frame (SetAlpha: not a protected function, and it takes withheld values from addons,
-- Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1133-1142), read first (GetAlpha, 276-288) and put back when the plate loses its
-- fade, leaves, or the row, the page or the module goes off. The game sets that alpha itself at the end of CompactUnitFrame_UpdateCenterStatusIcon
-- (Blizzard_UnitFrame/Shared/CompactUnitFrame.lua:1492-1518) to its range alpha, which is 1 on nameplates, since their fadeOutOfRange is false
-- (CompactUnitFrame.lua:1056-1066; Blizzard_NamePlates/Blizzard_NamePlateFrameOptions.lua:52 and 83). It runs that call on UNIT_FLAGS, UNIT_PHASE,
-- UNIT_CTR_OPTIONS, UNIT_OTHER_PARTY_CHANGED and the INCOMING_ events (CompactUnitFrame.lua:154-168) and in UpdateAll (463 and 472), which a plate
-- runs when it gets its unit (Blizzard_NamePlates/Blizzard_NamePlateBase.lua:69, CompactUnitFrame.lua:276). That call is followed and the fade set
-- again after it, as the raid frames' range opacity is (UnitExtras.lua). The fade multiplies with the game's own nameplate alphas and with Dim other
-- nameplates, which stay as they are.

local KEY = "nameplates"
local RING, BORDER, FADE = "threat ring", "threat border", "threat fade"
local HOOK = "CompactUnitFrame_UpdateCenterStatusIcon"
-- The edges of the ring in screen pixels, and its gap from the health bar beyond the border thickness, which clears the 2 px border of an Elite or a Rare.
local RING_PX, GAP_PX = 2, 2

-- Per unit frame: levelBox (Flat UI's square level box sits beside the bar, from the layout hook), ring ({ frame, outline, right: the frame its right
-- side follows, d: its gap, shown }), waiting (the plate waits for the end of a fight), border (the colour given to Nameplates.lua) and fade ({ orig:
-- the alpha the frame had, sent: the alpha written }). A record is kept when the plate leaves, so its ring is made once.
local recs = setmetatable({}, { __mode = "k" })
-- followed: the game's opacity call is followed; missing: the client has none. subscribed: the core tells this file of each change.
local followed, missing, subscribed = false, false, false
local RunPart, Wait, OnStatusIcon

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Record(frame)
	local rec = recs[frame]
	if rec == nil then
		rec = {}
		recs[frame] = rec
	end
	return rec
end

-- The frame itself, or nil when it is missing, withheld or forbidden.
local function Usable(frame)
	if not ns.Forbidden(frame) then
		return frame
	end
	return nil
end

-- The health bar and the level frame of a plate, as Nameplates.lua finds them, each tested before anything is read from it.
local function Bar(frame)
	local container = Usable(frame.HealthBarsContainer)
	return container and Usable(container.healthBar) or nil
end

local function Level(frame)
	return Usable(frame.PlayerLevelDiffFrame)
end

-- False for a friendly plate while Restyle friendly nameplates is off, as for the rest of the plate's look.
local function Styled(frame)
	local friend = frame.isFriend
	return Opt("friendly") == true or ns.IsSecret(friend) or friend ~= true
end

-- Whether this file may draw on a plate at all.
local function PlateOn(frame)
	return ns.Enabled(KEY) and ns.IsPlate(frame) and Styled(frame)
end

local function Off(part)
	return not ns.Enabled(KEY) or ns.PartStopped(KEY, part)
end

-- True on a plate the game shows as its name alone, with no health bar (Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua:561-587).
local function NameOnly(frame)
	local only = frame.showOnlyName
	return not ns.IsSecret(only) and only == true
end

-- The threat core while it is there and active (Restyle nameplates and Threat on nameplates on, its part running), else nil.
local function Core()
	local PT = ns.PlateThreat
	if type(PT) ~= "table" or type(PT.Active) ~= "function" or type(PT.Get) ~= "function" then
		return nil
	end
	local ok, active = pcall(PT.Active)
	if ok and active == true then
		return PT
	end
	return nil
end

-- The state the core kept of a plate at its last read, without a call to the game; nil while the core is not there or not active.
local function StateOf(frame)
	local PT = Core()
	if PT == nil then
		return nil
	end
	local read, state = pcall(PT.Get, frame)
	if read and type(state) == "table" then
		return state
	end
	return nil
end

-- Red, green and blue of a state: the colour of a unit tapped by another player (Threat Plates' glow for a tapped unit), else the colour of the state's row.
local function StateColour(state)
	if state.tapped == true then
		return ns.Colour("general.reactionTapped")
	end
	local PT = ns.PlateThreat
	if type(PT) ~= "table" or type(PT.Colour) ~= "function" then
		return nil
	end
	local ok, r, g, b = pcall(PT.Colour, state)
	if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return nil
end

-- The plates of the target and the focus. The plate frames are compared, so no unit comparison the client can withhold is needed.
local function Marks()
	return { target = ns.PlateUnitFrame("target"), focus = ns.PlateUnitFrame("focus") }
end

-- The ring -------------------------------------------------------------------------------------------------------------------------------------------

-- The ring's distance from the health bar, in the bar's units: the general border thickness and two pixels more.
local function Gap(bar)
	local thickness = ns.Get("general.thickness")
	return ns.Pixels(bar, (ns.Finite(thickness) and thickness or 1) + GAP_PX)
end

-- Four points, as the frame of the level box border has them (LevelSpan, Nameplates.lua): the left, top and bottom of the health bar and the right of
-- the bar, or of the level frame while Flat UI's square level box sits beside the bar, each moved out by the gap. Each SetPoint replaces the point of
-- its name, so a refused call leaves the anchors the ring had.
local function Anchor(ring, bar, right)
	local d = Gap(bar)
	local holder = ring.frame
	local ok = pcall(function()
		holder:SetPoint("LEFT", bar, "LEFT", -d, 0)
		holder:SetPoint("TOP", bar, "TOP", 0, d)
		holder:SetPoint("BOTTOM", bar, "BOTTOM", 0, -d)
		holder:SetPoint("RIGHT", right, "RIGHT", d, 0)
	end)
	if ok then
		ring.right, ring.d = right, d
	end
end

-- True while a frame laid out on these parts of the plate would be refused: in a fight, on a frame the game may protect (ns.MaybeProtected, Movers.lua).
local function Locked(bar, level)
	return InCombatLockdown() and (ns.MaybeProtected(bar) or (level ~= nil and ns.MaybeProtected(level)))
end

-- The ring of a plate, made the first time the plate needs one. In a fight on a plate the game may protect, it waits for the end of the fight.
local function Make(frame, rec)
	local bar = Bar(frame)
	if bar == nil then
		return nil
	end
	local level = rec.levelBox and Level(frame) or nil
	if Locked(bar, level) then
		Wait(frame, rec)
		return nil
	end
	local holder = CreateFrame("Frame", nil, bar)
	ns.Own[holder] = true
	local ring = { frame = holder }
	rec.ring = ring
	Anchor(ring, bar, level or bar)
	-- Four edges just outside the frame, on a holder that ignores the plate's scale, without a backdrop, and drawn without borders too.
	local outline = ns.Outline(holder, holder)
	ring.outline = outline
	ns.SetOutlineThickness(outline, RING_PX)
	ns.KeepOutline(outline)
	ns.SetOutline(outline, false, false)
	return ring
end

-- Anchors the ring again when the level box came or went or the gap changed, only out of combat.
local function Place(frame, rec)
	local ring, bar = rec.ring, Bar(frame)
	if ring == nil or bar == nil then
		return
	end
	local right = rec.levelBox and Level(frame) or bar
	if ring.right == right and ring.d ~= nil and math.abs(ring.d - Gap(bar)) < 0.01 then
		return
	end
	if InCombatLockdown() then
		Wait(frame, rec)
		return
	end
	Anchor(ring, bar, right)
end

local function HideRing(_, rec)
	local ring = rec.ring
	if ring ~= nil and ring.shown then
		ring.shown = nil
		ns.SetOutline(ring.outline, false, false)
	end
end

-- Whether a state has a ring: every state with Every threat state; threat changing hands and threat you do not want with When the enemy needs you.
local function Rings(state)
	local mode = Opt("threatGlow")
	return mode == "all" or (mode == "needs" and (state.want == "changing" or state.want == "bad"))
end

-- place: anchor the ring again first where needed.
local function Ring(frame, rec, state, place)
	if place then
		Place(frame, rec)
	end
	local r, g, b
	if state ~= nil and not Off(RING) and PlateOn(frame) and not NameOnly(frame) and Rings(state) then
		r, g, b = StateColour(state)
	end
	if r == nil then
		HideRing(frame, rec)
		return
	end
	local ring = rec.ring or Make(frame, rec)
	if ring == nil then
		return
	end
	ns.SetOutlineColour(ring.outline, r, g, b)
	if not ring.shown then
		ring.shown = true
		ns.SetOutline(ring.outline, true, false)
	end
end

-- After a fight: the ring a plate waited for is made while Threat glow still asks for rings, so it is there in the next fight, and anchored again.
local function Ready(frame, rec)
	if rec.ring == nil and Opt("threatGlow") ~= "off" and Core() ~= nil and not Off(RING) and PlateOn(frame) then
		Make(frame, rec)
	end
	Ring(frame, rec, StateOf(frame), true)
end

function Wait(frame, rec)
	if rec.waiting then
		return
	end
	rec.waiting = true
	ns.OutOfCombat(function()
		rec.waiting = nil
		if recs[frame] == rec and not ns.Forbidden(frame) then
			RunPart(RING, Ready, frame, rec)
		end
	end)
end

-- The border ------------------------------------------------------------------------------------------------------------------------------------------

local function ClearBorder(frame, rec)
	if rec.border ~= nil then
		rec.border = nil
		ns.PlateThreatBorder(frame, nil)
	end
end

-- The threat colour on the health bar border. It shows only while Health bar border is on, since Mark colours that outline.
local function Border(frame, rec, state)
	local r, g, b
	if state ~= nil and Opt("threatBorder") == true and not Off(BORDER) and PlateOn(frame) then
		r, g, b = StateColour(state)
	end
	if r == nil then
		ClearBorder(frame, rec)
		return
	end
	local now = rec.border
	if now ~= nil and now[1] == r and now[2] == g and now[3] == b then
		return
	end
	rec.border = ns.PlateThreatBorder(frame, r, g, b) and { r, g, b } or nil
end

-- The fade --------------------------------------------------------------------------------------------------------------------------------------------

-- The alpha of a frame when the client gives a real number, else 1.
local function ReadAlpha(frame)
	local ok, alpha = pcall(frame.GetAlpha, frame)
	if ok and ns.Finite(alpha) then
		return alpha
	end
	return 1
end

-- The frame goes back to the alpha it had, unless something else has given it one of its own since the write: the game's own call, which is then the
-- alpha it should have.
local function Release(frame, rec)
	local fade = rec.fade
	if fade == nil then
		return
	end
	rec.fade = nil
	if fade.sent == nil then
		return
	end
	local ok, now = pcall(frame.GetAlpha, frame)
	if ok and ns.Finite(now) and math.abs(now - fade.sent) > 0.01 then
		return
	end
	pcall(frame.SetAlpha, frame, fade.orig)
end

-- Follows the game's opacity call, once, the first time a plate fades. Without it the game's next write ends a fade until the threat changes again.
local function Install()
	if followed or missing then
		return
	end
	if ns.FollowGlobal(HOOK, OnStatusIcon) then
		followed = true
	else
		missing = true
	end
end

-- The alpha of an enemy held for you: a plate whose threat you want (good, or held by another tank) that is neither your target nor your focus takes
-- Opacity of enemies held for you; nil for every other plate, which keeps its own. At 100% nothing is written.
local function FadeAlpha(frame, state, marks)
	if state == nil or Opt("threatFade") ~= true or Off(FADE) or not PlateOn(frame) then
		return nil
	end
	if state.want ~= "good" and state.want ~= "offtank" then
		return nil
	end
	marks = marks or Marks()
	if frame == marks.target or frame == marks.focus then
		return nil
	end
	local percent = Opt("threatFadeAlpha")
	if not ns.Finite(percent) or percent >= 100 then
		return nil
	end
	return math.max(percent, 0) / 100
end

-- fromGame: the game has just set the frame's alpha itself, and that is the one to put back.
local function Fade(frame, rec, state, marks, fromGame)
	local alpha = FadeAlpha(frame, state, marks)
	if alpha == nil then
		Release(frame, rec)
		return
	end
	Install()
	local fade = rec.fade
	if fade == nil then
		fade = { orig = ReadAlpha(frame) }
		rec.fade = fade
	elseif fromGame then
		fade.orig, fade.sent = ReadAlpha(frame), nil
	end
	if fade.sent ~= alpha then
		-- A refusal is counted by the part, which stops after enough plates and gives every plate its alpha back.
		if not pcall(frame.SetAlpha, frame, alpha) then
			error("the game refused the opacity of a nameplate", 0)
		end
		fade.sent = alpha
	end
end

-- The game has set the alpha of a compact unit frame, a raid frame as well as a plate: a plate this file fades gets its fade again.
function OnStatusIcon(frame)
	if frame == nil or ns.IsSecret(frame) then
		return
	end
	local rec = recs[frame]
	if rec ~= nil and rec.fade ~= nil then
		RunPart(FADE, Fade, frame, rec, StateOf(frame), nil, true)
	end
end

-- Drawing ---------------------------------------------------------------------------------------------------------------------------------------------

-- What each part puts back on a plate.
local PUT_BACK = { [RING] = HideRing, [BORDER] = ClearBorder, [FADE] = Release }

-- Runs one part on one plate inside its own failure count. While the part or the module is stopped it only puts its look back, and a part that has just
-- stopped puts it back on every plate, as PlateColours.lua does.
function RunPart(part, fn, frame, rec, ...)
	local back = PUT_BACK[part]
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, part) then
		pcall(back, frame, rec)
	elseif not ns.EachPart(KEY, part, fn, frame, rec, ...) and ns.PartStopped(KEY, part) then
		for other, kept in pairs(recs) do
			pcall(back, other, kept)
		end
	end
end

-- The three parts of one plate from its state. No state puts each back.
local function Draw(frame, rec, state, marks, place)
	RunPart(RING, Ring, frame, rec, state, place)
	RunPart(BORDER, Border, frame, rec, state)
	RunPart(FADE, Fade, frame, rec, state, marks)
end

-- Every plate with a unit from its state, and every other plate drawn before put back. place: anchor the rings again where needed.
local function DrawAll(place)
	local marks, seen = Marks(), {}
	ns.EachPlate(function(frame)
		seen[frame] = true
		local state, rec = StateOf(frame), recs[frame]
		if rec ~= nil or state ~= nil then
			Draw(frame, rec or Record(frame), state, marks, place)
		end
	end)
	for frame, rec in pairs(recs) do
		if not seen[frame] and not ns.Forbidden(frame) then
			Draw(frame, rec, nil, marks)
		end
	end
end

-- The target or the focus changed: they never fade, and the plate that was one may fade now.
local function FadeAll()
	if Opt("threatFade") ~= true then
		return
	end
	local marks = Marks()
	ns.EachPlate(function(frame)
		local state, rec = StateOf(frame), recs[frame]
		if rec ~= nil or state ~= nil then
			RunPart(FADE, Fade, frame, rec or Record(frame), state, marks)
		end
	end)
end

-- The core's listener: a plate's state changed, came or went. None puts the look back.
local function OnChange(frame, state)
	if frame == nil or ns.IsSecret(frame) or type(frame) ~= "table" or ns.Forbidden(frame) then
		return
	end
	if type(state) ~= "table" then
		state = nil
	end
	local rec = recs[frame]
	if rec == nil and state == nil then
		return
	end
	Draw(frame, rec or Record(frame), state)
end

-- The core loads before this file (FlatUI.toc), and is asked for its changes the first time a plate shows or the plates are drawn again.
local function Subscribe()
	if subscribed then
		return
	end
	local PT = ns.PlateThreat
	if type(PT) == "table" and type(PT.OnChange) == "function" then
		subscribed = (pcall(PT.OnChange, OnChange))
	end
end

-- Hooks into the plates -------------------------------------------------------------------------------------------------------------------------------

local extra = ns.PlateExtra
-- Runs after LevelBox, with Nameplates.lua's own record of the plate: the ring follows the level box, and hides on a plate that shows its name alone.
extra.layout[#extra.layout + 1] = function(frame, own)
	local box = type(own) == "table" and own.levelBox == true
	local rec = recs[frame]
	if rec == nil then
		if not box then
			return
		end
		rec = Record(frame)
	end
	rec.levelBox = box
	local state = StateOf(frame)
	if rec.ring ~= nil or state ~= nil then
		RunPart(RING, Ring, frame, rec, state, true)
	end
end
extra.show[#extra.show + 1] = function(frame, own)
	Subscribe()
	local state, rec = StateOf(frame), recs[frame]
	if rec == nil and state == nil then
		return
	end
	rec = rec or Record(frame)
	if type(own) == "table" then
		rec.levelBox = own.levelBox == true
	end
	Draw(frame, rec, state)
end
extra.leave[#extra.leave + 1] = function(frame)
	-- The game takes the plate back for another unit: the ring hides, the border slot is cleared and the alpha goes back.
	local rec = recs[frame]
	if rec ~= nil then
		Draw(frame, rec, nil)
	end
end
extra.refresh[#extra.refresh + 1] = function()
	Subscribe()
	DrawAll(true)
end

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", FadeAll)
ns.AddEvent(KEY, "PLAYER_FOCUS_CHANGED", FadeAll)
