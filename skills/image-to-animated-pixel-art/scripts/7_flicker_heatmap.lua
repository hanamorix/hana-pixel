-- Flicker heat map of an animation (HM_IN): red = pixel changes >= 8 times per loop, orange >= 4. -> HM_OUT (default heat.png)
local dir = assert(PA_DIR, "set PA_DIR = project folder ending in a path separator (\\ or /)")
local spr = app.open(dir .. HM_IN)
local pc = app.pixelColor
local N, W, H = #spr.frames, spr.width, spr.height
local fr = {}
for _, c in ipairs(spr.cels) do fr[c.frameNumber] = c.image end
local heat = Image(W * 2, H * 2, ColorMode.RGB)
local hot, warm = 0, 0
for y = 0, H - 1 do for x = 0, W - 1 do
  local n = 0
  for k = 1, N do if fr[k]:getPixel(x, y) ~= fr[k % N + 1]:getPixel(x, y) then n = n + 1 end end
  local c = fr[1]:getPixel(x, y)
  local g = ((3*pc.rgbaR(c) + 6*pc.rgbaG(c) + pc.rgbaB(c)) // 10) // 2 + 60
  local col = pc.rgba(g, g, g, 255)
  if n >= 8 then col = pc.rgba(255, 0, 0, 255); hot = hot + 1 elseif n >= 4 then col = pc.rgba(255, 170, 0, 255); warm = warm + 1 end
  for dy = 0, 1 do for dx = 0, 1 do heat:drawPixel(x*2+dx, y*2+dy, col) end end
end end
heat:saveAs(dir .. (HM_OUT or "heat.png"))
print("hot px (>=8 changes)", hot, "warm px (4-7)", warm)
