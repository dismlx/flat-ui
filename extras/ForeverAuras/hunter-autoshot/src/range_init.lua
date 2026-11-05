-- Settings for the range text. Change them here, in Actions > On Init.
aura_env.deadMax = 10 -- a range estimate up to this many yards, out of melee and out of shot range, is the dead zone
aura_env.farMin  = 30 -- a range estimate from this many yards, out of shot range, is too far
aura_env.labels = {
  [0] = "|cffffffffRANGE ?|r",
  [1] = "|cffff8000MELEE|r",
  [2] = "|cffff2020DEAD ZONE|r",
  [3] = "|cff20ff20IN RANGE|r",
  [4] = "|cff909090OUT OF RANGE|r",
}

if C_SwingTimer and C_SwingTimer.EnableRangeCheck then
  pcall(C_SwingTimer.EnableRangeCheck, 0, true)
  pcall(C_SwingTimer.EnableRangeCheck, 2, true)
end
