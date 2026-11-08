# Still: from source image to pixel art

The goal is the source at 1/3 size with its lines, colours and small marks still readable. Every fix re-renders
from the source; drawing by hand is the last resort, and never for fingers.

## Base render (`1_still.lua`)
1. **Shrink 3x3, line-preserving.** L = (3r+6g+b)/10. If the block's average L minus its darkest pixel's L is
   above the **line threshold**, take the darkest pixel (keeps line art), else the block average.
2. **Palette from the image:** k-means (k-means++ init, fixed seed) on the shrunk block colours, plus **accents**
   for colours the averaging greys out (eye colour, warm near-white shine, metal ramp, freckle tones).
   Colour distance 2·dr²+4·dg²+3·db². The nearest-colour cache uses the exact RGB as its key (a coarse key returns
   neighbouring colours).
3. **Freckle pass** (when the image has freckles or small marks): a block with ≥ 2 reddish source pixels (r−g > 45)
   that are ≥ 14 darker than the 3x3-block neighbourhood is pushed 1.7x away from the surrounding skin.
4. **Orphan merge:** a pixel with no same-colour 8-neighbour takes its closest neighbour's colour if distance < 3600.

## Measure per image
| Parameter | How to choose | Examples |
|---|---|---|
| Line threshold | start at 45; raise if skin gets noisy, lower if thin outlines go dotted | 55, 45 |
| k | 40-60 plus accents | 32+11, 60+6 |
| Accents | colours the shrink greys out, sampled from the source | eye colour, warm white, metal ramp, freckles, lips |
| Protect boxes | eyes, mouth, hands: excluded from global remaps and outline joining | |
| Metal | shine dies under the darkest-pixel rule: re-render from block averages with shade bands from the source's own brightness spread (`example_metal_rerender.lua`) | gold chains |
| Local thresholds | faint lines (fingers, nails): re-render only the line pixels in that box at 35-40 | hands at 35 |

## Fixes, each its own check-in (`2_local_rerender.lua`, `3_join_outline.lua`)
- **Hands:** re-render the line pixels in the hand box at threshold 35-40. Drawn fingers look worse than rendered ones.
- **Lips merged into skin:** add 2-3 lip tones sampled from the source, re-render the mouth box.
- **Dotted outlines:** mark source pixels on thin dark lines (L < 140, 35 below the 7x7 mean, warm r > b+10); a
  sprite block with ≥ 2 such pixels becomes outline; bridge 1-px gaps; dark warm palette colours only; skip
  face and hands.
- **Global colour remaps** (e.g. a gold hue remap) skip the protect boxes: otherwise brown eyelids and skin
  outlines turn gold.
- **Background:** a majority filter smooths noise but flattens lace and texture; apply it lightly and only where
  the source is plain.
- **Warm highlights:** check the palette has a warm white near the source's brightest skin highlight; without one,
  shine snaps to a cold cyan-white.
- **Strands across the face:** a light hair strand can render as a dark line (the darkest-pixel rule catches its
  shadow). Check strands over skin at 8x and re-render that box at a higher threshold if needed.

## Check-in sheet
`checkin_sheet.lua`: source | before | after for one region, each sprite pixel as a 6x block.
