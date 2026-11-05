-- Settings for the Auto Shot bar. Change them here, in Actions > On Init.
aura_env.tolerance = 0.15 -- seconds late before a shot counts as clipped (latency and frame time)
aura_env.maxLate   = 3.0  -- a gap longer than this is a pause (out of range, line of sight), not a clip
aura_env.windup    = 0.5  -- the last part of the swing in which moving delays the shot
aura_env.flash     = 2.0  -- seconds the "CLIPPED +x.xx s" message stays on the bar
aura_env.sound     = true -- play a short sound on a clip

-- Ranged range checks of the client, used by the range text too.
if C_SwingTimer and C_SwingTimer.EnableRangeCheck then
  pcall(C_SwingTimer.EnableRangeCheck, 0, true)
  pcall(C_SwingTimer.EnableRangeCheck, 2, true)
end
