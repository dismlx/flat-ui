function(allstates, event, clips, lost)
  if event ~= "FA_HUNTER_CLIPS" then return false end
  clips, lost = tonumber(clips) or 0, tonumber(lost) or 0
  allstates[""] = {
    show = true,
    changed = true,
    progressType = "static",
    name = string.format("Clips: %d  (%.2fs lost)", clips, lost),
    stacks = clips,
  }
  return true
end
