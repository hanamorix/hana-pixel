# Motion without breaks

A **break** is any pixel that jumps, tears, pops or flickers in the loop. Detailed pixel art breaks easily, and
Claude cannot watch a GIF, so breaks are found by measurement.

## What fails
- Per-pixel displacement: columns tear.
- Row warps: rows duplicate or skip, outlines jog.
- Rigid block shifts of soft parts: the whole area pops at once.
- Integer 1/3-px steps of a whole region: the same pop.
- A soft dome centred off its part: one side shears. Cover each soft part fully.

## What works
1. **Re-render from the source at fractional offsets.** Each moving pixel is rendered fresh each frame from the
   3x source with the same shrink rule, the 3x3 window sliding continuously (edge rows and columns weighted by
   coverage). One smooth motion field per part, soft edges ≥ 12 px, a blurred figure mask so the background stays.
2. **Stamping.** Where the pose differs from the renderer's own zero-offset output, that pixel's source block
   reads as the pose colour. Clean-up edits then move with the art, and frame 1 equals the still exactly
   (self-check `BF_ZERO`: 0 px changed).
3. **De-flicker:** A→B→A over 1-2 frames keeps A (wrapping). Skip the eye box near the blink frames and the rigid
   boxes while they move (`BA_SKIP`), else it breaks the blink and the exact hands.
4. **Thin dark lines in a moving field flicker** (straps, lashes, outlines): keep fields away from them or fade
   them out before the line. The heat map finds them. A head moving under a blink makes the eyes boil: keep the
   head still when there is a blink.
5. **Rigid parts move in whole pixels** (field exactly 1): hands stay exact copies of the still. Snap offsets within
   0.03 px of a whole pixel (a blurred mask gives 0.99999), and skip orphan clean-up on whole-pixel moves. The flesh
   around them follows with a soft fade. Their step frames are big by design: list them in `BA_STEPS`.
6. **Limbs:** the part near the hand moves as a unit (forearm rigid from ~55% of its length); a wrist that lags
   the hand looks awkward. Elbow and shoulder take a share of the move.
7. **Additive layers:** a lift adds to the breathing field (max of the two), so the breathing keeps its rhythm.
8. **Effects after de-flicker,** colour only, palette-snapped. Keep an effect pixel only if it holds its colour
   ≥ 2 frames (a glint without this rule gave thousands of one-frame pops).
9. **Background motion** (water) is its own field, faded out well before the figure outline. Sideways shimmer
   plus a swell that rolls toward the shore (phase changes down the rows) reads as water; a wash moves the foam
   edge. Dry sand reads as noise when moved: give it glints instead.

## Speed and amounts (starting points)
| Motion | Start with |
|---|---|
| Loop | 48 frames at 50 ms |
| Breath | (1−cos φ)/2, ~1.5 px at the shoulders |
| Slow, subtle move of a rigid part | 1 px step every 3 frames (1 px per frame reads as rushed) |
| Bounce after a push | 2 px, period 8 frames, decay 7, second side lags 0.7 frames, gone before the loop ends |
| Settle of a soft part after breathing | lag plus one damped settle, ~0.7 px |
| Hair tips / cloth ends | 1.8-2 px, roots still, fades inside the part |

## Blink that reads well
- Four poses: open, half, near, closed, played half, near, closed, closed, near, half.
- Flat lid. The whole upper lash line drops across its full width, with lid skin filling above it; a thin liner
  crease stays at the top. The lashes move with the lid.
- Closed: the upper lash line lies on the eye's bottom curve, touching the lower lashes; no iris pixels left.
- Weaker: lashes sliding per column (jagged), lid filling under a static lash band, an almond-shaped lid.
