# Hunter Auto Shot + Range (ForeverAuras)

A [ForeverAuras](https://www.curseforge.com/wow/addons/foreverauras) group for hunters in WoW: Forever. It is not part of Flat UI and is not packaged with it.

## Import

1. Copy all of [`import.txt`](import.txt). It is one line that starts with `!WA:2!`.
2. In game, type `/fa`, click **Import**, paste the line and click **Import** again.
3. ForeverAuras warns that the group has custom code. That is the code in [`src/`](src).

The group loads for hunters only. It sits under the centre of the screen; drag the group to move it.

## What it shows

**Auto Shot ring.** A hollow ring fills clockwise up to your next Auto Shot. It is nearly full in the last 0.5 s, the window in which the shot goes off without a clip as long as you stand still and are not casting. The timing comes from the client's own swing timer (`PLAYER_SWING`), with `UNIT_SPELLCAST_SUCCEEDED` for Auto Shot as a backup.

| Ring colour | Text under the ring | Meaning |
| --- | --- | --- |
| Blue | Auto Shot | The swing is running. |
| Yellow | Auto Shot | The last 0.5 s before the shot. Stand still. |
| Orange | STOP MOVING | You are moving in that last 0.5 s, so the shot is held back. |
| Red | CLIPPING | A cast you started ends after the shot was due. |
| Red | CLIPPED (cast) +0.42s | The last shot fired 0.42 s late. The text says why: a cast, moving, or just DELAYED. It shows for 2 s and plays a sound. |

The seconds to the shot are inside the ring.

**Range text**, above the ring. It shows MELEE, DEAD ZONE, IN RANGE or OUT OF RANGE for an enemy target.
- Melee range and shot range come from the client's weapon range checks (`C_SwingTimer.IsTargetWithinSwingRange`).
- If those give nothing, Raptor Strike and Auto Shot range are used.
- In combat the client can withhold the yard estimate. Then the text guesses from your last zone: leaving melee means the dead zone, leaving shot range means too far.

**Clip counter**, below the ring. It shows the clips and time lost in the current fight, and resets when combat starts.

## Settings

Open the aura, then **Actions > On Init**:
- **Auto Shot:** `tolerance` sets how late a shot can be before it counts as a clip (0.15 s by default). Also `maxLate`, `windup`, `flash` and `sound`.
- **Range:** `deadMax` and `farMin` set the yard limits.

## Rebuild

`src/` holds the trigger code. `src/encode.py` builds `import.txt` again from it. It needs Python 3 and `pip install lupa`.

```
python3 extras/ForeverAuras/hunter-autoshot/src/encode.py
```

It encodes the group the way ForeverAuras exports one: LibSerialize, then DEFLATE, then LibDeflate's print encoding. It decodes the result again to check it, and compiles every code block with Lua 5.1.
