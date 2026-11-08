-- All idle frames K0..K1 -> <BF_OUT>_<K0>.aseprite. Every moving pixel is re-rendered from the source at a
-- fractional offset taken from smooth motion fields. Where the pose (still or blink) differs from this renderer's own
-- zero-offset output, the pose colour is "stamped" in as a solid 3x3 source block, so frame 1 equals the still exactly
-- and clean-up edits (freckles, lips, outline) move with the art.
-- Required globals: PA_DIR (project folder, ending in \), PA_SRC (source image, exactly 3x the sprite size)
-- Optional: BF_K0, BF_K1 (frame range, default 1..48), BF_POSES (blink poses file), BF_OUT (output name prefix),
--   switches BF_PUSH (hand lift), BF_ARMS (arms ride the lift), BF_SEA (sea swell + wash), BF_JIG (constant jiggle amp),
--   amounts BF_HAIR, BF_CLOTH, BF_SWELL, BF_WASH, BF_BOUNCE, BF_LIFT (table frame -> whole px), BF_ZERO (self-check: must change 0 px)
local dir = assert(PA_DIR, "set PA_DIR = project folder ending in a path separator (\\ or /)")
local SRC = assert(PA_SRC, "set PA_SRC = source image file name (exactly 3x the sprite size)")
local K0, K1 = BF_K0 or 1, BF_K1 or 48

-- ===================== SETTINGS: re-measure every value for a new image =====================
-- Coordinates are sprite px, measured on the finished still at 8-14x zoom. The values below are an example (a 213x512 standing figure).
-- Soft edges are {start, end} ranges for smoothstep: a field fades in (or out) across that range.
local N, LINE_T = 48, 45                 -- frames per loop (50 ms each); line threshold of the shrink (same as the still)
local BLINK = {[30] = 2, [31] = 3, [32] = 4, [33] = 4, [34] = 3, [35] = 2}  -- frame -> pose (1 open, 2 half, 3 near, 4 closed)
-- Figure silhouette, hand-traced. Everything outside it (sky, sea, sand) stays still unless a background field moves it.
local FIGURE = {{48,30},{62,14},{95,4},{140,4},{176,28},{188,100},{194,170},{198,250},{200,330},{212,372},{212,512},
                {4,512},{8,440},{17,360},{25,300},{23,215},{38,192},{46,120}}
-- Breathing: rows that rise with the breath (shoulders, upper back). The head stays still (it carries the blink); the field fades out before thin dark lines.
local BREATH = {amp = 1.5, y = {132, 165, 212, 248}}               -- y = {fade in from, to, fade out from, to}
-- Soft parts: ellipse domes {cx, cy, rx, ry} that bounce after a push, held still below DOME_HOLD.
local DOMES = {{98, 398, 50, 62}, {168, 394, 44, 60}}
local DOME_HOLD = {405, 440}
-- Sway boxes: {x = {in0,in1,out0,out1}, y = {...}}; nil = open side. Tips move, roots stay; keep fades inside the part.
local HAIR = {amp = 1.8, phase = 1.4, boxes = {
  {x = {nil, nil, 50, 58}, y = {70, 195, 198, 210}},             -- strands beside the face
  {x = {146, 154, 166, 174}, y = {250, 330, 330, 340}}}}         -- strip behind the back
local CLOTH = {amp = 2.0, phase = 1.2, boxes = {
  {x = {136, 142, 156, 162}, y = {148, 182, 184, 194}},          -- hanging cloth ends near the neck
  {x = {112, 118, 134, 140}, y = {262, 294, 296, 306}}}}         -- hanging cloth ends at the back
-- Hand lift (BF_PUSH): hands + the band they hold move in WHOLE px (field exactly 1) so every hand pixel is an exact copy.
local PUSH = {
  x_in = {52, 62},            -- left edge of the pushed area
  follow = {345, 440},        -- the soft part above the hands follows, fading in down to here
  rigid_to = 480,             -- fingertips: rigid down to this row
  below = {480, 498},         -- below the fingertips the body stretches back to still
  band_y = {428, 438}, band_x = {50, 56},
  elbow = {24, 428}, wrist = {60, 448},   -- left forearm
  rigid_from = 0.55,          -- forearm moves with the hand from 55% of its length (a lagging wrist looks awkward)
  width = {12, 16},           -- forearm field half-width fade
  lift = {from = 7, every = 3, px = 3, down = 22, to = 27},  -- 1 px step every 3 frames ("subtle", not rushed)
  bounce = {amp = 2.0, period = 8, decay = 7, lag = 0.7},     -- after release; the second dome lags; dead by frame N
}
-- Arms ride the lift (BF_ARMS), on top of the breathing; share = fraction of the lift.
local ARMS = {
  elbow_share = 0.4, shoulder_share = 0.25, top = {132, 150},
  left = {88, 165, 32, 418, width = {16, 26}},                        -- shoulder -> elbow
  right = {176, 178, 190, 330, width = {12, 20}, extra = 0.15, behind = {318, 340}},  -- fades where it goes behind the body
}
-- Sea (BF_SEA): background only, stops well clear of the figure.
local SEA = {
  clear = 0.08,               -- figure-mask level where the sea field stops
  horizon = {247, 262},       -- swell fades in below the horizon
  near = {250, 320}, base = 0.25,   -- swell grows toward the shore from 25%
  split_x = 106, waterline = {360, 336},   -- waterline row of the left / right strip
  swell = 1.4, sideways = 1.2, roll = 0.18, side_phase = 0.25,
  wash = 4, wash_phase = 0.8,  -- foam edge pushed ~4 px down the wet sand once per loop
}
-- =============================================================================================

local pc = app.pixelColor
local t0 = os.clock()
local bp = app.open(dir .. (BF_POSES or "blink_poses.aseprite"))
local palObj = bp.palettes[1]
local poses = {}
for _, c in ipairs(bp.cels) do poses[c.frameNumber] = c.image end
local W, H = poses[1].width, poses[1].height
local ref = app.open(dir .. SRC)
local big = Image(ref.width, ref.height, ColorMode.RGB); big:drawSprite(ref, 1)
local RW, RH = 3 * W, 3 * H
local REF = {}
for y = 0, RH - 1 do for x = 0, RW - 1 do REF[y * RW + x] = big:getPixel(x, y) end end

local P = {}
for i = 0, #palObj - 1 do local c = palObj:getColor(i); P[#P + 1] = {c.red, c.green, c.blue} end
local memo = {}
local function nearest(r, g, b)
  local key = (r << 16) | (g << 8) | b  -- exact key: a coarse key can return a neighbouring palette colour
  local m = memo[key]
  if m then return m end
  local best, bd = 1, math.huge
  for k, p in ipairs(P) do local a, bb, c = r - p[1], g - p[2], b - p[3]; local dd = 2*a*a + 4*bb*bb + 3*c*c; if dd < bd then bd, best = dd, k end end
  m = pc.rgba(P[best][1], P[best][2], P[best][3], 255)
  memo[key] = m
  return m
end
-- fractional offsets: the 3x3 window slides continuously, edge rows/columns weighted by coverage
local function render(st, X, Y, sx, sy)
  local fy0 = math.floor(sy); local fy = sy - fy0
  local fx0 = math.floor(sx); local fx = sx - fx0
  local wy = {1 - fy, 1, 1, fy}
  local wx = {1 - fx, 1, 1, fx}
  local sr, sg, sb, sw, mL, mr, mg, mb = 0, 0, 0, 0, 1e9, 0, 0, 0
  for dy = 0, 3 do
    if wy[dy + 1] > 0.001 then
      local py = 3 * Y + dy + fy0
      if py < 0 then py = 0 elseif py >= RH then py = RH - 1 end
      for dx = 0, 3 do
        local w = wy[dy + 1] * wx[dx + 1]
        if w > 0.001 then
          local px = 3 * X + dx + fx0
          if px < 0 then px = 0 elseif px >= RW then px = RW - 1 end
          local c = (st and st[(py // 3) * W + (px // 3)]) or REF[py * RW + px]
          local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
          sr, sg, sb, sw = sr + w * r, sg + w * g, sb + w * b, sw + w
          if w >= 0.5 then
            local L = (3*r + 6*g + b) / 10
            if L < mL then mL, mr, mg, mb = L, r, g, b end
          end
        end
      end
    end
  end
  local ar, ag, ab = sr / sw, sg / sw, sb / sw
  if (3*ar + 6*ag + ab) / 10 - mL > LINE_T then return nearest(mr, mg, mb) end
  return nearest(ar // 1, ag // 1, ab // 1)
end
local function d2(a, b)
  local r, g, bl = pc.rgbaR(a) - pc.rgbaR(b), pc.rgbaG(a) - pc.rgbaG(b), pc.rgbaB(a) - pc.rgbaB(b)
  return 2*r*r + 4*g*g + 3*bl*bl
end
local function smooth(a, b, v) local t = (v - a) / (b - a); if t <= 0 then return 0 elseif t >= 1 then return 1 end; return t * t * (3 - 2 * t) end
-- soft box: factors multiplied left to right (x in, x out, y in, y out); a nil pair is an open side
local function box(xx, yy, bx)
  local v = 1
  if bx.x[1] then v = v * smooth(bx.x[1], bx.x[2], xx) end
  if bx.x[3] then v = v * (1 - smooth(bx.x[3], bx.x[4], xx)) end
  if bx.y[1] then v = v * smooth(bx.y[1], bx.y[2], yy) end
  if bx.y[3] then v = v * (1 - smooth(bx.y[3], bx.y[4], yy)) end
  return v
end
local function boxes(xx, yy, list) local m = 0; for _, bx in ipairs(list) do m = math.max(m, box(xx, yy, bx)) end; return m end

local function inside(poly, x, y)
  local c, j = false, #poly
  for i = 1, #poly do
    local xi, yi, xj, yj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
    if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then c = not c end
    j = i
  end
  return c
end
local fig = {}
for y = 0, H - 1 do for x = 0, W - 1 do fig[y * W + x] = inside(FIGURE, x + 0.5, y + 0.5) and 1 or 0 end end
local function blur(a, R)
  local t, o = {}, {}
  for y = 0, H - 1 do
    local acc, n = 0, 0
    for x = -R, W - 1 + R do
      if x + R < W and x + R >= 0 then acc = acc + a[y * W + x + R]; n = n + 1 end
      if x - R - 1 >= 0 and x - R - 1 < W then acc = acc - a[y * W + x - R - 1]; n = n - 1 end
      if x >= 0 and x < W then t[y * W + x] = acc / n end
    end
  end
  for x = 0, W - 1 do
    local acc, n = 0, 0
    for y = -R, H - 1 + R do
      if y + R < H and y + R >= 0 then acc = acc + t[(y + R) * W + x]; n = n + 1 end
      if y - R - 1 >= 0 and y - R - 1 < H then acc = acc - t[(y - R - 1) * W + x]; n = n - 1 end
      if y >= 0 and y < H then o[y * W + x] = acc / n end
    end
  end
  return o
end
fig = blur(blur(fig, 3), 3)  -- motion fades over ~12 px at the silhouette

local function seg(xx, yy, sx0, sy0, sx1, sy1)  -- position along a limb segment (0..1) and distance from it
  local ux, uy = sx1 - sx0, sy1 - sy0
  local tt = math.max(0, math.min(1, ((xx - sx0) * ux + (yy - sy0) * uy) / (ux * ux + uy * uy)))
  return tt, math.sqrt((xx - sx0 - tt * ux) ^ 2 + (yy - sy0 - tt * uy) ^ 2)
end

-- motion weights per pixel
local fV, fJL, fJR, fX, fT, fP = {}, {}, {}, {}, {}, {}
local fS, fW = {}, {}
local moving = {}
for y = 0, H - 1 do for x = 0, W - 1 do
  local xx, yy = x + 0.5, y + 0.5
  local i = y * W + x
  local f = fig[i]
  local v = box(xx, yy, {x = {}, y = BREATH.y}) * f
  local hold = 1 - smooth(DOME_HOLD[1], DOME_HOLD[2], yy)
  local jw = {0, 0}
  for k, e in ipairs(DOMES) do
    local dx, dy = (xx - e[1]) / e[3], (yy - e[2]) / e[4]
    local r2 = dx * dx + dy * dy
    if r2 < 1 then local q = 1 - r2; jw[k] = q * q * (3 - 2 * q) * hold * f end
  end
  local hs = boxes(xx, yy, HAIR.boxes) * f
  local tw = boxes(xx, yy, CLOTH.boxes) * f
  local p = 0
  if BF_PUSH then
    local vy
    if yy < PUSH.follow[2] then vy = smooth(PUSH.follow[1], PUSH.follow[2], yy)
    elseif yy <= PUSH.rigid_to then vy = 1 else vy = 1 - smooth(PUSH.below[1], PUSH.below[2], yy) end
    p = smooth(PUSH.x_in[1], PUSH.x_in[2], xx) * vy
    local band = smooth(PUSH.band_y[1], PUSH.band_y[2], yy) * ((yy <= PUSH.rigid_to) and 1 or (1 - smooth(PUSH.below[1], PUSH.below[2], yy)))
    p = math.max(p, smooth(PUSH.band_x[1], PUSH.band_x[2], xx) * band)
    local t, dist = seg(xx, yy, PUSH.elbow[1], PUSH.elbow[2], PUSH.wrist[1], PUSH.wrist[2])
    local AE, AS = BF_ARMS and ARMS.elbow_share or 0, BF_ARMS and ARMS.shoulder_share or 0
    p = math.max(p, (AE + (1 - AE) * smooth(0, PUSH.rigid_from, t)) * (1 - smooth(PUSH.width[1], PUSH.width[2], dist)))
    if BF_ARMS then
      local top = smooth(ARMS.top[1], ARMS.top[2], yy)
      local L, R = ARMS.left, ARMS.right
      local tl, dl = seg(xx, yy, L[1], L[2], L[3], L[4])
      p = math.max(p, (AS + (AE - AS) * tl) * (1 - smooth(L.width[1], L.width[2], dl)) * top)
      local tr, dr = seg(xx, yy, R[1], R[2], R[3], R[4])
      p = math.max(p, (AS + R.extra * tr) * (1 - smooth(R.width[1], R.width[2], dr)) * top * (1 - smooth(R.behind[1], R.behind[2], yy)))
    end
    p = p * f
  end
  local sw, ww = 0, 0
  if BF_SEA then
    local bg = 1 - smooth(0, SEA.clear, f)
    local wl = (xx < SEA.split_x) and SEA.waterline[1] or SEA.waterline[2]
    sw = bg * smooth(SEA.horizon[1], SEA.horizon[2], yy) * (1 - smooth(wl - 8, wl, yy)) * (SEA.base + (1 - SEA.base) * smooth(SEA.near[1], SEA.near[2], yy))
    ww = bg * smooth(wl - 30, wl - 6, yy) * (1 - smooth(wl + 8, wl + 18, yy))
  end
  fS[i], fW[i] = sw, ww
  if v > 0.001 or jw[1] > 0.001 or jw[2] > 0.001 or hs > 0.001 or tw > 0.001 or p > 0.001 or sw > 0.001 or ww > 0.001 then
    fV[i], fJL[i], fJR[i], fX[i], fT[i], fP[i] = v, jw[1], jw[2], hs, tw, p
    moving[#moving + 1] = i
  end
end end

-- stamps per pose: where the pose differs from this renderer's own zero-offset output (whole image)
local R0 = {}
local function r0(i) local v = R0[i]; if not v then v = render(nil, i % W, i // W, 0, 0); R0[i] = v end; return v end
local stamp = {}
for k = 1, #poses do
  local s, img = {}, poses[k]
  for j = 0, W * H - 1 do local c = img:getPixel(j % W, j // W); if c ~= r0(j) then s[j] = c end end
  stamp[k] = s
end

local function jig(phi)  -- constant soft-body wobble (BF_JIG); the lift bounce below replaces it when BF_PUSH is on
  local t1 = (phi - math.pi) % (2 * math.pi)
  return 1.8 * (-0.35 * math.sin(phi) + 0.4 * math.exp(-t1 / 0.9) * math.sin(4 * t1) - 0.25 * math.exp(-(phi % (2 * math.pi)) / 0.9) * math.sin(4 * phi))
end
local LIFT = BF_LIFT or {}
if not BF_LIFT then
  local L = PUSH.lift
  for f = L.from, L.to do LIFT[f] = math.min(1 + (f - L.from) // L.every, L.px, (L.px - 1) - (f - L.down) // L.every) end
end
local spr = Sprite(W, H, ColorMode.RGB)
spr:setPalette(palObj)
local layer = spr.layers[1]; layer.name = "Art"
local stats = {}
for k = K0, K1 do
  local phi = 2 * math.pi * (k - 1) / N
  local b = (1 - math.cos(phi)) / 2
  local JA = BF_JIG or 0
  local jL, jR = JA * (4 / 3) * jig(phi), JA * (4 / 3) * jig(phi - 0.35)
  local hair = (BF_HAIR or HAIR.amp) * math.sin(phi - HAIR.phase)
  local cloth = (BF_CLOTH or CLOTH.amp) * math.sin(phi - CLOTH.phase)
  local Hp = BF_PUSH and (LIFT[k] or 0) or 0
  local b0 = PUSH.lift.to + 1
  if BF_PUSH and k >= b0 then
    local Bc = PUSH.bounce
    local A, T, tau = BF_BOUNCE or Bc.amp, Bc.period, Bc.decay
    local function bounce(t) if t <= 0 then return 0 end; return -A * math.exp(-t / tau) * math.sin(2 * math.pi * t / T) end
    jL, jR = bounce(k - b0), bounce(k - (b0 + Bc.lag))
  end
  local pi = BLINK[k] or 1
  local pose, st = poses[pi], stamp[pi]
  local img = pose:clone()
  local moved, n = {}, 0
  for _, i in ipairs(moving) do
    local x, y = i % W, i // W
    local sy = 3 * (BREATH.amp * b * fV[i] + jL * fJL[i] + jR * fJR[i] + Hp * fP[i])
    local sx = 3 * (hair * fX[i] + cloth * fT[i])
    if fS[i] > 0.001 or fW[i] > 0.001 then
      -- swell rolls toward the shore (phase runs down the rows); the wash pushes the foam edge down the sand once per loop
      sy = sy + 3 * (fS[i] * (BF_SWELL or SEA.swell) * math.sin(phi - SEA.roll * y) - fW[i] * (BF_WASH or SEA.wash) * (1 - math.cos(phi - SEA.wash_phase)) / 2)
      sx = sx + 3 * fS[i] * SEA.sideways * math.sin(phi + SEA.side_phase * y)
    end
    -- blurred masks give 0.99999 instead of 1: snap near-whole-pixel offsets so rigid parts stay exact copies
    local ry = 3 * math.floor(sy / 3 + 0.5); if math.abs(sy - ry) < 0.03 then sy = ry end
    if math.abs(sx) < 0.03 then sx = 0 end
    if BF_ZERO then sx, sy = 0, 0; img:drawPixel(x, y, render(st, x, y, 0, 0)); n = n + 1
    elseif math.abs(sy) > 0.05 or math.abs(sx) > 0.05 then
      img:drawPixel(x, y, render(st, x, y, sx, sy)); n = n + 1
      if not (sx == 0 and sy % 3 == 0) then moved[i] = true end  -- whole-pixel moves are exact copies: never "clean" them
    end
  end
  local cleaned = img:clone()  -- merge lone orphan pixels the fractional render made
  for i in pairs(moved) do
    local x, y = i % W, i // W
    local c = img:getPixel(x, y)
    if x > 0 and y > 0 and x < W - 1 and y < H - 1 and c ~= pose:getPixel(x, y) then
      local orphan, best, bd = true, nil, math.huge
      for dy = -1, 1 do for dx = -1, 1 do if dx ~= 0 or dy ~= 0 then
        local nc = img:getPixel(x + dx, y + dy)
        if nc == c then orphan = false end
        local dd = d2(c, nc); if dd < bd then bd, best = dd, nc end
      end end end
      if orphan and bd < 3600 then cleaned:drawPixel(x, y, best) end
    end
  end
  local fi = k - K0 + 1
  if fi > 1 then spr:newEmptyFrame() end
  spr:newCel(layer, fi, cleaned, Point(0, 0))
  spr.frames[fi].duration = 0.05
  stats[#stats + 1] = n
end
spr:saveAs(dir .. string.format("%s_%02d.aseprite", BF_OUT or "frames", K0))
print(string.format("frames %d-%d done in %.1fs; moving px %d; re-rendered per frame: %s", K0, K1, os.clock() - t0, #moving, table.concat(stats, " ")))
