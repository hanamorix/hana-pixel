---
name: image-to-animated-pixel-art
description: Use when turning an image or illustration into detailed pixel art in Aseprite, or animating such pixel art (idle loop, breathing, blink, hair or cloth sway, soft-body jiggle, hands or limbs moving, shine, water), through the Aseprite MCP.
---

# Image to animated pixel art

The result must stay **true to source**: fix what the shrink to pixel size damaged, never invent detail. In motion
the enemy is **breaks**: any pixel that jumps, tears, pops or flickers. Claude cannot watch a GIF, so every showing
is preceded by **measured checks**, never by "it looks fine in a still".

If the user keeps pixel-art preferences (in their CLAUDE.md or a file it points to), read them first; they
override the defaults here. Needs the Aseprite MCP: [references/aseprite-mcp.md](references/aseprite-mcp.md).
Read when you reach that stage: [references/still-recipe.md](references/still-recipe.md),
[references/motion-and-breaks.md](references/motion-and-breaks.md).

## Workflow

Every check-in is one message: a side-by-side image (source | before | after, or a GIF plus a cropped flip-book)
and one question. Copy the current file to `_vN` before every change, so a rejected round is reverted from it.
Each round makes exactly the change asked for and nothing else.

1. **Brief.** Ask what is wanted before planning: which parts move, how much and how fast, what stays still, what
   is protected. Write a short plan file (half a page) and get a yes. Done when the user approved the plan.
2. **Source.** Crop or resize the source so its size is exactly 3x the target sprite (about 200-260 px wide).
   The scripts assume 3x.
3. **Still** (`1_still.lua`, then fixes with `2_local_rerender.lua`, `3_join_outline.lua`). Measure the
   parameters in still-recipe.md for this image. Check-ins in order: hands, then face and eyes, then outlines,
   metal and background. Done when each part is approved and the still is saved as `*_still_FINAL`.
4. **Blink poses** (`4_blink_poses.lua`, eye spans traced by hand at 14x). Show all four poses side by side plus
   a blink GIF in one check-in, built as in motion-and-breaks.md. Done when approved.
5. **Motion** (`5_animation_frames.lua`). Fill its SETTINGS block from measurements on the still, run with
   `BF_ZERO = true` first (must change 0 px), then the real run, then `6_deflicker_metrics.lua`.
   Pass the checks below, then show the full GIF plus a cropped flip-book of the moving part.
6. **Effects** (`8_effects.lua`, colour only, after de-flicker). Check, then show.
7. **Extras** one request at a time (arms, water, ...), each with its own check-in.
8. **Final.** Copy to `*_FINAL` (`.aseprite` + 3x GIF), keeping earlier finals.

## Checks before every animation check-in

| Check | Pass | Where |
|---|---|---|
| Zero-offset render equals the pose | 0 px changed with `BF_ZERO` | 5 |
| Rigid parts (hands) exact | each frame's box, shifted back by its whole-px lift, equals the still: 0 px | own Lua compare |
| One-frame pops (A→B→A) | none outside the blink and effects | 6 prints them |
| Jumps | step frames listed in `BA_STEPS` are excluded; every other frame ≤ ~2x median changed px, and any frame over it has a named cause | 6 |
| Heat map | no red (≥ 8 changes per loop) on outlines, straps, lashes, eyes | `7_flicker_heatmap.lua` |
| Effects | every effect pixel holds ≥ 2 frames; the changed-px count is above 0 (a weak blend can snap back to the same palette colour) | 8 prints counts |
| Closed eye | no iris colour left on the closed frames | `view_sprite` at 12x |
| Flip-book | 8-16 frames of hands, face and every moving edge at 6x+ look continuous | `view_sprite` region + frames |

## Scripts (`scripts/`)

Every script needs `PA_DIR` (project folder, ending in the path separator: `\` on Windows, `/` on macOS) and
`PA_SRC` (source image file name) set first, plus its own globals listed in its header. Run them through
`run_lua_script` with a short launcher; `<skill>` is this skill's base directory, given when the skill loads:

```lua
PA_DIR, PA_SRC = [[/path/to/project/]], "reference.jpg"
BF_POSES, BF_OUT, BF_PUSH = "blink_poses.aseprite", "frames", true
dofile([[<skill>/scripts/5_animation_frames.lua]])
```

| Script | Does |
|---|---|
| `1_still.lua` | 3x3 line-preserving shrink, k-means palette + accents, freckle pass, orphan merge |
| `2_local_rerender.lua` | re-render boxes at another line threshold or with extra colours (hands, lips) |
| `3_join_outline.lua` | join dotted outlines where the source has a thin line |
| `4_blink_poses.lua` | open, half, near, closed poses (eye spans in the file are per image) |
| `5_animation_frames.lua` | all frames; every coordinate lives in its SETTINGS block (example values included) |
| `6_deflicker_metrics.lua` | de-flicker, pops, jump check (`BA_SKIP` rigid boxes, `BA_STEPS` step frames) |
| `7_flicker_heatmap.lua` | heat map PNG |
| `8_effects.lua` | squash light, glint, sea sparkles, sand glints (SETTINGS block per image) |
| `checkin_sheet.lua` | source / before / after sheet for a region |
| `example_metal_rerender.lua` | worked example only: metal re-rendered with shade bands from the source |

`5_animation_frames.lua` holds the motion types met so far (breathing band, soft domes, sway boxes, rigid
whole-pixel push, limb segments, sea). A new image with different moving parts adds a field there.
