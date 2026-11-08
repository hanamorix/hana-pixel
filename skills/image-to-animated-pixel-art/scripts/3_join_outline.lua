-- Join broken thin outlines: fill a gap pixel only where the SOURCE has a thin dark line in that block
-- and the gap bridges two existing outline pixels on opposite sides. Face and hands are skipped.
-- Globals: OL_IN, OL_OUT, OL_PASSES (default 2)
local dir = assert(PA_DIR, "set PA_DIR = project folder ending in a path separator (\\ or /)")
local pc = app.pixelColor
local ref = app.open(dir .. assert(PA_SRC, "set PA_SRC = source image (exactly 3x the sprite size)"))
local big = Image(ref.width, ref.height, ColorMode.RGB); big:drawSprite(ref, 1)
local SW, SH = ref.width, ref.height
-- luminance + integral image of the source
local Lm, I = {}, {}
for y = 0, SH - 1 do for x = 0, SW - 1 do
  local c = big:getPixel(x, y); Lm[y*SW + x] = (3*pc.rgbaR(c) + 6*pc.rgbaG(c) + pc.rgbaB(c)) / 10
end end
local IW = SW + 1
for y = 0, SH do I[y*IW] = 0 end
for x = 0, SW do I[x] = 0 end
for y = 1, SH do local run = 0; for x = 1, SW do run = run + Lm[(y-1)*SW + x-1]; I[y*IW + x] = I[(y-1)*IW + x] + run end end
local function boxMean(x, y, r)
  local x0, y0, x1, y1 = math.max(0, x-r), math.max(0, y-r), math.min(SW-1, x+r), math.min(SH-1, y+r)
  local s = I[(y1+1)*IW + x1+1] - I[y0*IW + x1+1] - I[(y1+1)*IW + x0] + I[y0*IW + x0]
  return s / ((x1-x0+1) * (y1-y0+1))
end
local spr = app.open(dir .. OL_IN)
local pal = spr.palettes[1]
local P = {}
-- only outline browns (dark, warm) so filled pixels never come out grey or teal
for i = 0, #pal - 1 do local c = pal:getColor(i); if (3*c.red + 6*c.green + c.blue) / 10 < 125 and c.red > c.blue + 10 then P[#P+1] = {c.red, c.green, c.blue} end end
local function nearest(r, g, b)
  local best, bd = 1, math.huge
  for k, p in ipairs(P) do local a, bb, c = r - p[1], g - p[2], b - p[3]; local d = 2*a*a + 4*bb*bb + 3*c*c; if d < bd then bd, best = d, k end end
  return P[best]
end
local W, H = spr.width, spr.height
-- source line info per sprite block: count of thin dark brown pixels, and the darkest one
local srcLine, srcStrong = {}, {}
for y = 0, H - 1 do for x = 0, W - 1 do
  local n, mL, mc = 0, 1e9, nil
  for dy = 0, 2 do for dx = 0, 2 do
    local sx, sy = x*3 + dx, y*3 + dy
    local L = Lm[sy*SW + sx]
    local c = big:getPixel(sx, sy)
    if L < 140 and L < boxMean(sx, sy, 3) - 35 and pc.rgbaR(c) > pc.rgbaB(c) + 10 then
      n = n + 1; if L < mL then mL, mc = L, c end
    end
  end end
  if n > 0 then srcLine[y*W + x] = mc end
  if n >= (OL_DIRECT or 99) then srcStrong[y*W + x] = true end
end end
local skip = {{55,62,80,75},{60,440,62,36},{150,440,50,40}}
local function skipped(x, y)
  for _, b in ipairs(skip) do if x >= b[1] and y >= b[2] and x < b[1]+b[3] and y < b[2]+b[4] then return true end end
  return false
end
local img = spr.cels[1].image
local function isLine(x, y)
  if x < 0 or y < 0 or x >= W or y >= H then return false end
  local c = img:getPixel(x, y); local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
  return (3*r + 6*g + b) / 10 < 125 and r > b + 10
end
-- opposite neighbour pairs (bridge across the gap pixel), incl. knight-move pairs for shallow diagonals
local PAIRS = {{-1,0,1,0},{0,-1,0,1},{-1,-1,1,1},{1,-1,-1,1},{-1,-1,1,0},{-1,0,1,1},{1,-1,-1,0},{1,0,-1,1},{-1,-1,0,1},{0,-1,1,1},{1,-1,0,1},{0,-1,-1,1}}
local total = 0
-- direct trace: blocks the source line runs well through (>= OL_DIRECT of 9 pixels) become outline
local direct = 0
for y = 0, H - 1 do for x = 0, W - 1 do
  if srcStrong[y*W + x] and not isLine(x, y) and not skipped(x, y) then
    local c = srcLine[y*W + x]; local q = nearest(pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c))
    img:drawPixel(x, y, pc.rgba(q[1], q[2], q[3], 255)); direct = direct + 1
  end
end end
print("direct", direct)
for pass = 1, OL_PASSES or 2 do
  local add = {}
  for y = 1, H - 2 do for x = 1, W - 2 do
    local sc = srcLine[y*W + x]
    if sc and not isLine(x, y) and not skipped(x, y) then
      for _, p in ipairs(PAIRS) do
        if isLine(x + p[1], y + p[2]) and isLine(x + p[3], y + p[4]) then add[#add+1] = {x, y, sc}; break end
      end
    end
  end end
  for _, a in ipairs(add) do
    local q = nearest(pc.rgbaR(a[3]), pc.rgbaG(a[3]), pc.rgbaB(a[3]))
    img:drawPixel(a[1], a[2], pc.rgba(q[1], q[2], q[3], 255))
  end
  total = total + #add
  print("pass", pass, "filled", #add)
end
spr:saveAs(dir .. OL_OUT)
print(OL_OUT, "total filled", total)
