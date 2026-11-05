function(allstates, event, ...)
  local e = aura_env
  local now = GetTime()
  local RANGED = (Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.Ranged) or 2
  local AUTO_SHOT = 75

  local function plain(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
  end
  local function num(v)
    return plain(v) and type(v) == "number" and v == v and v > 0 and v < 100
  end

  if not e.s or event == "PLAYER_ENTERING_WORLD" then
    e.s = { shotAt = nil, dur = nil, exact = false, exp = 0, repeating = false, repeatSince = 0,
            castEnd = nil, cause = nil, flashUntil = 0, msg = nil, clips = 0, lost = 0 }
  end
  local s = e.s

  local function rangedSpeed()
    local ok, speed = pcall(UnitRangedDamage, "player")
    if ok and num(speed) then return speed end
    return s.dur or 2.0
  end

  local function stats()
    WeakAuras.ScanEvents("FA_HUNTER_CLIPS", s.clips, s.lost)
  end

  -- A shot went off. exact: the duration came from the client's own swing timer.
  local function shot(duration, exact)
    if not num(duration) then duration = rangedSpeed() end
    if s.shotAt and now - s.shotAt < 0.25 then
      -- The second signal of the same shot: keep the better duration.
      if exact or not s.exact then
        s.dur, s.exp, s.exact = duration, s.shotAt + duration, exact
      end
      return
    end
    if s.shotAt and s.dur and s.repeating and s.repeatSince <= s.shotAt then
      local late = (now - s.shotAt) - s.dur
      if late > e.tolerance and late < e.maxLate then
        s.clips = s.clips + 1
        s.lost = s.lost + late
        s.msg = string.format("|cffff4040%s +%.2fs|r", s.cause or "CLIPPED", late)
        s.flashUntil = now + e.flash
        if e.sound then pcall(PlaySound, 846) end
        stats()
      end
    end
    s.shotAt, s.dur, s.exact, s.exp, s.cause = now, duration, exact, now + duration, nil
  end

  local function readCast(info)
    local ok, _, _, _, _, endMS = pcall(info, "player")
    if ok and plain(endMS) and type(endMS) == "number" and endMS > 0 then return endMS / 1000 end
  end

  if event == "PLAYER_SWING" then
    local duration, swingType = ...
    if plain(swingType) and swingType == RANGED then shot(duration, true) end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit == "player" and plain(spellID) then
      if spellID == AUTO_SHOT then shot(nil, false) else s.castEnd = nil end
    end
  elseif event == "START_AUTOREPEAT_SPELL" then
    s.repeating, s.repeatSince = true, now
  elseif event == "STOP_AUTOREPEAT_SPELL" then
    s.repeating = false
  elseif event == "UNIT_SPELLCAST_START" then
    s.castEnd = readCast(UnitCastingInfo)
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    s.castEnd = readCast(UnitChannelInfo)
  elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
      or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    s.castEnd = nil
  elseif event == "PLAYER_REGEN_DISABLED" then
    s.clips, s.lost = 0, 0
    stats()
  elseif event == "FRAME_UPDATE" then
    if now < (e.nextTick or 0) then return false end
  end
  e.nextTick = now + 0.05

  -- What the next shot is waiting on.
  local remaining = s.exp - now
  -- The ring ends where you must stand still: the wind-up, plus a lead for latency, before the shot.
  local still = e.windup + e.lead
  local stopAt = s.exp - still
  local clipping = s.repeating and s.castEnd ~= nil and s.castEnd > s.exp + e.tolerance
  if clipping then s.cause = "CLIPPED (cast)" end
  local moving = false
  if s.repeating and remaining <= still then
    local ok, speed = pcall(GetUnitSpeed, "player")
    moving = ok and plain(speed) and type(speed) == "number" and speed > 0
    if moving and not s.cause then s.cause = "DELAYED (moving)" end
  end
  local windup = s.repeating and remaining > 0 and remaining <= still
  local flash = now < s.flashUntil

  local label
  if flash then
    label = s.msg
  elseif clipping then
    label = "|cffff4040CLIPPING|r"
  elseif moving then
    label = "|cffffa000STOP MOVING|r"
  elseif windup then
    label = "|cffffff00STAND STILL|r"
  elseif not s.repeating then
    label = "|cff909090Auto Shot off|r"
  elseif remaining <= 0 then
    label = "Auto Shot ready"
  else
    label = "Auto Shot"
  end

  local show = s.repeating or remaining > 0 or flash
  local old = allstates[""]
  if old and old.show == show and old.name == label and old.expirationTime == stopAt
      and old.clipping == clipping and old.moving == moving and old.windup == windup
      and old.flash == flash and old.stacks == s.clips then
    return false
  end

  local icon = 132369
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, AUTO_SHOT)
    if ok and plain(tex) and tex then icon = tex end
  end

  allstates[""] = {
    show = show,
    changed = true,
    progressType = "timed",
    duration = math.max((s.dur or rangedSpeed()) - still, 0.1),
    expirationTime = stopAt,
    autoHide = false,
    name = label,
    icon = icon,
    stacks = s.clips,
    clipping = clipping,
    moving = moving,
    windup = windup,
    flash = flash,
  }
  return true
end
