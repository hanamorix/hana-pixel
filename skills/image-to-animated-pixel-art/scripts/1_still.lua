-- Base still (globals ST_T, ST_K, ST_ACC, ST_OUT, ST_FRECKLES, FR_*): 3x3 line-preserving shrink, k-means palette from the shrunk colours, nearest colour, orphan merge.
local dir = assert(PA_DIR, "set PA_DIR = project folder ending in a path separator (\\ or /)")
local F, LINE_T, K = 3, ST_T or 45, ST_K or 50
local ACC = ST_ACC or {}
local OUTNAME = ST_OUT or "still"
local pc = app.pixelColor
local ref = app.open(dir .. assert(PA_SRC, "set PA_SRC = source image (exactly 3x the sprite size)"))
local big = Image(ref.width, ref.height, ColorMode.RGB); big:drawSprite(ref, 1)
local W, H = ref.width // F, ref.height // F
-- 1. shrink to raw block colours
local raw, lines, isLine = {}, 0, {}
local bavg = {}  -- block average {r,g,b,L}
for y = 0, H - 1 do for x = 0, W - 1 do
  local sr, sg, sb, mL, mr, mg, mb = 0, 0, 0, 1e9, 0, 0, 0
  for dy = 0, F - 1 do for dx = 0, F - 1 do
    local c = big:getPixel(x*F+dx, y*F+dy)
    local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
    sr, sg, sb = sr + r, sg + g, sb + b
    local L = (3*r + 6*g + b) / 10
    if L < mL then mL, mr, mg, mb = L, r, g, b end
  end end
  local ar, ag, ab = sr / 9, sg / 9, sb / 9
  local aL = (3*ar + 6*ag + ab) / 10
  bavg[#bavg+1] = {ar, ag, ab, aL}
  if aL - mL > LINE_T then raw[#raw+1] = {mr, mg, mb}; lines = lines + 1; isLine[#raw] = true
  else raw[#raw+1] = {ar // 1, ag // 1, ab // 1} end
end end
-- 1b. freckles: >=3 of 9 pixels reddish and 22+ darker than the surrounding skin -> their average colour
local freck = 0
if ST_FRECKLES ~= false then
  for y = 1, H - 2 do for x = 1, W - 2 do
    local i = y*W + x + 1
    if not isLine[i] then
      local nr, ng, nL = 0, 0, 0
      for dy = -1, 1 do for dx = -1, 1 do local a = bavg[i + dy*W + dx]; nr, ng, nL = nr + a[1], ng + a[2], nL + a[4] end end
      nr, ng, nL = nr / 9, ng / 9, nL / 9
      if nr > ng + 25 and nL > 120 then
        local fr, fg, fb, n = 0, 0, 0, 0
        for dy = 0, 2 do for dx = 0, 2 do
          local c = big:getPixel(x*F+dx, y*F+dy)
          local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
          if (3*r + 6*g + b) / 10 < nL - (FR_D or 22) and r - g > 45 and r > 120 then fr, fg, fb, n = fr + r, fg + g, fb + b, n + 1 end
        end end
        if n >= (FR_N or 3) then
          -- push the freckle colour away from the surrounding skin so 2-4 px source dots still read at 1/3 size
          local k, sr, sg, sb = FR_BOOST or 1, 0, 0, 0
          for dy = -1, 1 do for dx = -1, 1 do local a = bavg[i + dy*W + dx]; sr, sg, sb = sr + a[1], sg + a[2], sb + a[3] end end
          sr, sg, sb = sr / 9, sg / 9, sb / 9
          local function cl(v) return math.max(0, math.min(255, v // 1)) end
          raw[i] = {cl(sr + (fr/n - sr)*k), cl(sg + (fg/n - sg)*k), cl(sb + (fb/n - sb)*k)}; freck = freck + 1
        end
      end
    end
  end end
end
local function d2(a, b) local r, g, bl = a[1]-b[1], a[2]-b[2], a[3]-b[3]; return 2*r*r + 4*g*g + 3*bl*bl end
-- 2. k-means (k-means++ init, fixed seed) on every 3rd block colour
math.randomseed(7)
local S = {}
for i = 1, #raw, 3 do S[#S+1] = raw[i] end
local C = {S[math.random(#S)]}
local dmin = {}
for i = 1, #S do dmin[i] = d2(S[i], C[1]) end
while #C < K do
  local tot = 0; for i = 1, #S do tot = tot + dmin[i] end
  local t, acc, pick = math.random() * tot, 0, #S
  for i = 1, #S do acc = acc + dmin[i]; if acc >= t then pick = i; break end end
  C[#C+1] = {S[pick][1], S[pick][2], S[pick][3]}
  for i = 1, #S do local d = d2(S[i], C[#C]); if d < dmin[i] then dmin[i] = d end end
end
local K0 = K
for _, a in ipairs(ACC) do C[#C+1] = a end
K = #C
for it = 1, 12 do
  local acc = {}
  for k = 1, K do acc[k] = {0, 0, 0, 0} end
  for i = 1, #S do
    local best, bd = 1, math.huge
    for k = 1, K do local d = d2(S[i], C[k]); if d < bd then bd, best = d, k end end
    local a = acc[best]; a[1], a[2], a[3], a[4] = a[1]+S[i][1], a[2]+S[i][2], a[3]+S[i][3], a[4]+1
  end
  for k = 1, K0 do local a = acc[k]; if a[4] > 0 then C[k] = {a[1]//a[4], a[2]//a[4], a[3]//a[4]} end end -- accents stay fixed
end
-- 3. nearest colour
local img = Image(W, H, ColorMode.RGB)
for y = 0, H - 1 do for x = 0, W - 1 do
  local c = raw[y*W + x + 1]
  local best, bd = 1, math.huge
  for k = 1, K do local d = d2(c, C[k]); if d < bd then bd, best = d, k end end
  img:drawPixel(x, y, pc.rgba(C[best][1], C[best][2], C[best][3], 255))
end end
-- 4. orphan merge
local function cd(a, b)
  local r, g, bl = pc.rgbaR(a) - pc.rgbaR(b), pc.rgbaG(a) - pc.rgbaG(b), pc.rgbaB(a) - pc.rgbaB(b)
  return 2*r*r + 4*g*g + 3*bl*bl
end
local out, merged = img:clone(), 0
for y = 0, H - 1 do for x = 0, W - 1 do
  local c = img:getPixel(x, y)
  local orphan, best, bd = true, nil, math.huge
  for dy = -1, 1 do for dx = -1, 1 do if dx ~= 0 or dy ~= 0 then
    local nx, ny = x + dx, y + dy
    if nx >= 0 and ny >= 0 and nx < W and ny < H then
      local nc = img:getPixel(nx, ny)
      if nc == c then orphan = false end
      local dd = cd(c, nc); if dd < bd then bd, best = dd, nc end
    end
  end end end
  if orphan and bd < 3600 then out:drawPixel(x, y, best); merged = merged + 1 end
end end
local spr = Sprite(W, H, ColorMode.RGB)
local pal = Palette(K)
table.sort(C, function(a, b) return (3*a[1]+6*a[2]+a[3]) < (3*b[1]+6*b[2]+b[3]) end)
for k = 1, K do pal:setColor(k - 1, Color{r = C[k][1], g = C[k][2], b = C[k][3]}) end
spr:setPalette(pal)
spr.layers[1].name = "Art"
spr.cels[1].image = out
spr:saveAs(dir .. OUTNAME .. "_base.aseprite")
spr:saveAs(dir .. OUTNAME .. ".aseprite")
print(W .. "x" .. H, "colours", K, "line blocks", lines, "freckle blocks", freck, "orphans merged", merged)
