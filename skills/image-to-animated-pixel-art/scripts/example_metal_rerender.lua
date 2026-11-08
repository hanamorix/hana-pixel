-- Worked example: re-render metal (here gold chains) from block averages, with shade bands taken from the source. Read and adapt; not run as is.
local dir = assert(PA_DIR, "set PA_DIR = project folder ending in a path separator (\\ or /)")
local spr = app.activeSprite
local pc = app.pixelColor
local W, H = spr.width, spr.height
local palObj = spr.palettes[1]
local P = {}
for i = 0, #palObj - 1 do local c = palObj:getColor(i); P[#P + 1] = {c.red, c.green, c.blue} end
local function nearest(r, g, b)
  local best, bd = 1, math.huge
  for k, p in ipairs(P) do local a, bb, c = r - p[1], g - p[2], b - p[3]; local dd = 2*a*a + 4*bb*bb + 3*c*c; if dd < bd then bd, best = dd, k end end
  return pc.rgba(P[best][1], P[best][2], P[best][3], 255)
end
local ramp = {0x4A2A0C, 0x865218, 0xBE842A, 0xE4B44C, 0xFFE696}
local rampC, gold = {}, {}
for i, h in ipairs(ramp) do rampC[i] = pc.rgba(h >> 16, (h >> 8) & 255, h & 255, 255); gold[rampC[i]] = true end
-- step boundaries from the source's own gold brightness spread
local TH = {60, 110, 142, 172}
local function toRamp(L) for i = 1, 4 do if L < TH[i] then return rampC[i] end end; return rampC[5] end
local ref = app.open(dir .. assert(PA_SRC, "set PA_SRC"))
local big = Image(ref.width, ref.height, ColorMode.RGB); big:drawSprite(ref, 1)
app.activeSprite = spr
local img = spr.cels[1].image
local out = img:clone()
local protect = {{88,104,30,20}, {132,104,30,20}, {110,140,34,16}, {226,268,30,40}}
local function prot(x, y) for _, r in ipairs(protect) do if x >= r[1] and x < r[1]+r[3] and y >= r[2] and y < r[2]+r[4] then return true end end; return false end
local area = {}
for y = 0, H - 1 do for x = 0, W - 1 do
  if gold[img:getPixel(x, y)] then
    for dy = -1, 1 do for dx = -1, 1 do local xx, yy = x + dx, y + dy; if xx >= 0 and yy >= 0 and xx < W and yy < H then area[yy * W + xx] = true end end end
  end
end end
for idx in pairs(area) do
  local x, y = idx % W, idx // W
  if not prot(x, y) then
    local sr, sg, sb, mL = 0, 0, 0, 1e9
    for dy = 0, 2 do for dx = 0, 2 do
      local c = big:getPixel(3*x+dx, 3*y+dy)
      local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
      sr, sg, sb = sr + r, sg + g, sb + b
      local L = (3*r + 6*g + b) / 10; if L < mL then mL = L end
    end end
    local r, g, b = sr / 9, sg / 9, sb / 9
    local L = (3*r + 6*g + b) / 10
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local sat = mx > 0 and (mx - mn) / mx or 0
    local hue = (mx ~= mn and mx == r) and 60 * ((g - b) / (mx - mn)) or -1
    local nc
    if mx == r and hue >= 15 and hue <= 55 and sat >= 0.45 then nc = toRamp(L)
    elseif L < 75 or (L - mL > 55 and mL < 70) then nc = rampC[1]
    else nc = nearest(r, g, b) end
    out:drawPixel(x, y, nc)
  end
end
local s = Sprite(W, H, ColorMode.RGB); s:setPalette(palObj); s.cels[1].image = out
s:saveAs(dir .. "metal_test.aseprite")
print("ok")