-- Colour-only effects on the assembled loop (run AFTER de-flicker so it can't erase them):
-- squash light on the shine spots while the hands lift, a diagonal gloss glint over highlight skin (frames 30-47), sea sparkles.
-- FX_IN -> FX_OUT. Nothing moves; every colour is snapped to the sprite palette.
local dir = assert(PA_DIR, "set PA_DIR = project folder ending in a path separator (\\ or /)")
local spr = app.open(dir .. assert(FX_IN, "set FX_IN"))
local pc = app.pixelColor
local W, H, N = spr.width, spr.height, #spr.frames
local pal = spr.palettes[1]
local P = {}
for i = 0, #pal - 1 do local c = pal:getColor(i); P[#P + 1] = {c.red, c.green, c.blue} end
local memo = {}
local function nearest(r, g, b)
  r, g, b = math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5)
  local key = (r << 16) | (g << 8) | b
  if memo[key] then return memo[key] end
  local best, bd = 1, math.huge
  for k, p in ipairs(P) do local a, bb, c = r - p[1], g - p[2], b - p[3]; local d = 2*a*a + 4*bb*bb + 3*c*c; if d < bd then bd, best = d, k end end
  memo[key] = pc.rgba(P[best][1], P[best][2], P[best][3], 255)
  return memo[key]
end
local function smooth(a, b, v) local t = (v - a) / (b - a); if t <= 0 then return 0 elseif t >= 1 then return 1 end; return t * t * (3 - 2 * t) end
local function L(c) return (3 * pc.rgbaR(c) + 6 * pc.rgbaG(c) + pc.rgbaB(c)) / 10 end
local function toward(c, t, a)  -- blend colour c toward target t by a, snapped to the palette
  if a <= 0.001 then return c end
  local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
  return nearest(r + (t[1] - r) * a, g + (t[2] - g) * a, b + (t[3] - b) * a)
end
local COOL, WARM = {233, 246, 246}, {242, 230, 213}
local function isSkin(c) local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c); return r > g and g > b and r - b > 30 end
local function isSea(c) return pc.rgbaB(c) >= pc.rgbaR(c) - 10 end

-- ===================== SETTINGS: re-measure for a new image (example values shown) =====================
-- LIFT must match PUSH.lift in 5_animation_frames.lua; spots, face, hands, sea windows and sand glints (section 4) are sprite px.
-- lift per frame -> squash amount, eased so the light swells and fades
local LIFT = {}
for f = 7, 27 do LIFT[f] = math.min(1 + (f - 7) // 3, 3, 2 - (f - 22) // 3) end
local SQ = FX_SQ or 0.55
local GL = FX_GL or 0.4
local spots = {{98, 375, 16, 13}, {160, 375, 12, 12}}  -- centre x, y, radius x, y
local face = function(x, y) return x >= 40 and x <= 140 and y >= 30 and y <= 140 end
local hands = function(x, y) return x >= 36 and x <= 200 and y >= 420 and y <= 490 end

-- sparkle sites: brightest crest per sea window, alternating left / right
local base = spr.cels[1].image
local wins = {{2, 250, 14, 30}, {204, 255, 8, 20}, {2, 300, 14, 30}, {203, 290, 8, 20}, {2, 350, 14, 30}, {2, 395, 14, 22}}
local sites = {}
for _, w in ipairs(wins) do
  local bx, by, bl = nil, nil, -1
  for y = w[2], w[2] + w[4] - 1 do for x = w[1], w[1] + w[3] - 1 do
    local c = base:getPixel(x, y)
    local ok = isSea(c)
    for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do ok = ok and isSea(base:getPixel(x + d[1], y + d[2])) end
    if ok and L(c) > bl then bl, bx, by = L(c), x, y end
  end end
  if bx then sites[#sites + 1] = {bx, by} end
end
local SP_START = {3, 11, 19, 27, 37, 43}
local SP_SHAPE = {"dot", "cross", "cross", "dot"}

-- glint colours per frame first, so a pixel is only lit if it holds that colour >= 2 frames (no 1-frame sparkle at the band edges)
local G = {}
for k = 30, 47 do
  local img, gk = spr.cels[k].image, {}
  local c0 = 150 + (k - 30) * (560 / 17)
  for y = 120, H - 1 do for x = 0, W - 1 do
    local g = math.exp(-((x + y - c0) / 28) ^ 2)
    if g > 0.05 and not face(x, y) and not hands(x, y) then
      local c = img:getPixel(x, y)
      if isSkin(c) then
        local nc = toward(c, WARM, GL * g * smooth(170, 212, L(c)))  -- lit skin only; shadows untouched
        if nc ~= c then gk[y * W + x] = nc end
      end
    end
  end end
  G[k] = gk
end
local log = {}
for k = 1, N do
  local img = spr.cels[k].image
  local out = img:clone()
  local changed = 0
  -- 1) squash light: shine spots brighter and a little larger while lifted
  local s = SQ * (LIFT[k] or 0) / 3
  if s > 0 then
    for _, sp in ipairs(spots) do
      for y = sp[2] - sp[4] - 2, sp[2] + sp[4] + 2 do for x = sp[1] - sp[3] - 2, sp[1] + sp[3] + 2 do
        local dx, dy = (x - sp[1]) / sp[3], (y - sp[2]) / sp[4]
        local w = 1 - smooth(0.45, 1, math.sqrt(dx * dx + dy * dy))
        local c = img:getPixel(x, y)
        if w > 0 and isSkin(c) or (w > 0 and L(c) >= 225) then
          local nc = toward(c, COOL, s * w * smooth(190, 232, L(c)))
          if nc ~= c then out:drawPixel(x, y, nc); changed = changed + 1 end
        end
      end end
    end
  end
  -- 2) gloss glint: a soft diagonal band sweeps top-left -> bottom-right over highlight skin, once per loop
  -- 18 frames (0.9 s) and a wide band: each pixel stays lit ~2 frames, so it glides instead of flashing
  if G[k] then
    local pv, nx = G[k - 1] or {}, G[k + 1] or {}
    for i, nc in pairs(G[k]) do
      if pv[i] == nc or nx[i] == nc then out:drawPixel(i % W, i // W, nc); changed = changed + 1 end
    end
  end
  -- 3) sea sparkles: dot, cross, cross, dot
  for i, st in ipairs(sites) do
    local t = k - SP_START[i]
    local shape = SP_SHAPE[t + 1]
    if shape then
      local x, y = st[1], st[2]
      out:drawPixel(x, y, nearest(COOL[1], COOL[2], COOL[3])); changed = changed + 1
      if shape == "cross" then
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local c = out:getPixel(x + d[1], y + d[2])
          out:drawPixel(x + d[1], y + d[2], toward(c, COOL, 0.6)); changed = changed + 1
        end
      end
    end
  end
  -- 4) sand glints: a single grain catches the light for 2 frames, staggered (well clear of the figure outline)
  if FX_SAND then
    local SG = {{4, 388, 6}, {209, 350, 15}, {2, 430, 24}, {206, 378, 33}, {5, 472, 40}, {211, 364, 46}}
    for _, g in ipairs(SG) do
      local t = k - g[3]
      if t == 0 or t == 1 then
        local c = out:getPixel(g[1], g[2])
        out:drawPixel(g[1], g[2], toward(c, WARM, t == 0 and 0.85 or 0.5)); changed = changed + 1
      end
    end
  end
  spr.cels[k].image = out
  log[#log + 1] = changed
end
spr:saveAs(dir .. assert(FX_OUT, "set FX_OUT"))
local ss = {}
for _, s in ipairs(sites) do ss[#ss + 1] = s[1] .. "," .. s[2] end
print("sparkle sites: " .. table.concat(ss, " "))
print("fx px per frame: " .. table.concat(log, " "))
