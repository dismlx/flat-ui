function(allstates, event, ...)
  local e = aura_env
  local now = GetTime()
  if event == "FRAME_UPDATE" and now < (e.nextTick or 0) then return false end
  e.nextTick = now + 0.1

  local function plain(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
  end

  local function hide()
    if allstates[""] and allstates[""].show then
      allstates[""].show, allstates[""].changed = false, true
      return true
    end
    return false
  end

  local ok, attackable = pcall(function()
    return UnitExists("target") and not UnitIsDeadOrGhost("target") and UnitCanAttack("player", "target")
  end)
  if not ok or not plain(attackable) or not attackable then
    e.last = nil
    return hide()
  end

  -- The client's own reach of a weapon: 0 is the main hand, 2 the ranged weapon.
  local function swingRange(kind)
    if C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange then
      local okR, r = pcall(C_SwingTimer.IsTargetWithinSwingRange, kind)
      if okR and plain(r) and type(r) == "boolean" then return r end
    end
  end
  local function spellRange(id)
    if C_Spell and C_Spell.IsSpellInRange then
      local okR, r = pcall(C_Spell.IsSpellInRange, id, "target")
      if okR and plain(r) then
        if type(r) == "boolean" then return r end
        if type(r) == "number" then return r == 1 end
      end
    end
  end

  local melee = swingRange(0)
  if melee == nil then melee = spellRange(2973) end -- Raptor Strike
  local ranged = swingRange(2)
  if ranged == nil then ranged = spellRange(75) end -- Auto Shot

  local zone
  if melee then
    zone = 1
  elseif ranged then
    zone = 3
  else
    local minR, maxR
    if WeakAuras.GetRange then
      local okG, a, b = pcall(WeakAuras.GetRange, "target", true)
      if okG and plain(a) and plain(b) then minR, maxR = a, b end
    end
    if type(maxR) == "number" and maxR <= e.deadMax then
      zone = 2
    elseif type(minR) == "number" and minR >= e.farMin then
      zone = 4
    elseif melee == false and ranged == false then
      -- No estimate: coming out of melee is the dead zone, coming out of shot range is too far.
      zone = (e.last == 1 or e.last == 2) and 2 or 4
    else
      zone = 0
    end
  end
  e.last = zone

  local old = allstates[""]
  if old and old.show and old.zone == zone then return false end
  allstates[""] = {
    show = true,
    changed = true,
    progressType = "static",
    name = e.labels[zone],
    zone = zone,
  }
  return true
end
