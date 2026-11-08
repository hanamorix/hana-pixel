-- Local re-render of boxes from the source with a different line threshold, using the still's own palette.
-- Globals: LR_IN, LR_OUT (file names), LR_T (line threshold), LR_BOXES {{x,y,w,h},...}
local dir = assert(PA_DIR, "set PA_DIR = project folder ending in a path separator (\\ or /)")
local pc = app.pixelColor
local ref = app.open(dir .. assert(PA_SRC, "set PA_SRC = source image (exactly 3x the sprite size)"))
local big = Image(ref.width, ref.height, ColorMode.RGB); big:drawSprite(ref, 1)
local spr = app.open(dir .. LR_IN)
local pal = spr.palettes[1]
local P = {}
for i = 0, #pal - 1 do local c = pal:getColor(i); P[#P+1] = {c.red, c.green, c.blue} end
if LR_ACC then -- extra accent colours, also added to the sprite palette
  local np = #pal; pal:resize(np + #LR_ACC)
  for k, a in ipairs(LR_ACC) do pal:setColor(np + k - 1, Color{r = a[1], g = a[2], b = a[3]}); P[#P+1] = a end
  spr:setPalette(pal)
end
local function nearest(r, g, b)
  local best, bd = 1, math.huge
  for k, p in ipairs(P) do local a, bb, c = r - p[1], g - p[2], b - p[3]; local d = 2*a*a + 4*bb*bb + 3*c*c; if d < bd then bd, best = d, k end end
  return P[best]
end
local img = spr.cels[1].image
local n = 0
for _, bx in ipairs(LR_BOXES) do
  for y = bx[2], bx[2] + bx[4] - 1 do for x = bx[1], bx[1] + bx[3] - 1 do
    local sr, sg, sb, mL, mr, mg, mb = 0, 0, 0, 1e9, 0, 0, 0
    for dy = 0, 2 do for dx = 0, 2 do
      local c = big:getPixel(x*3+dx, y*3+dy)
      local r, g, b = pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c)
      sr, sg, sb = sr + r, sg + g, sb + b
      local L = (3*r + 6*g + b) / 10
      if L < mL then mL, mr, mg, mb = L, r, g, b end
    end end
    local ar, ag, ab = sr / 9, sg / 9, sb / 9
    if (3*ar + 6*ag + ab) / 10 - mL > LR_T then
      local p = nearest(mr, mg, mb)
      local nc = pc.rgba(p[1], p[2], p[3], 255)
      if img:getPixel(x, y) ~= nc then img:drawPixel(x, y, nc); n = n + 1 end
    elseif LR_FULL then -- also re-render non-line blocks from the block average
      local p = nearest(ar, ag, ab)
      local nc = pc.rgba(p[1], p[2], p[3], 255)
      if img:getPixel(x, y) ~= nc then img:drawPixel(x, y, nc); n = n + 1 end
    end
  end end
end
spr:saveAs(dir .. LR_OUT)
print(LR_OUT, "line pixels changed", n)
