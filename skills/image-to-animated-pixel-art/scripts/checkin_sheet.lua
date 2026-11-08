-- Side-by-side sheet: source crop | each listed sprite crop, each sprite pixel as SC x SC.
-- Globals: SH_X, SH_Y, SH_W, SH_H (sprite px), SH_FILES (list of .aseprite names), SH_OUT, SH_SC (default 6)
local dir = assert(PA_DIR, "set PA_DIR = project folder ending in a path separator (\\ or /)")
local SC = SH_SC or 6
local n = #SH_FILES + 1
local gap = 8
local out = Image(n * SH_W * SC + (n - 1) * gap, SH_H * SC, ColorMode.RGB)
out:clear(app.pixelColor.rgba(255, 255, 255, 255))
local ref = app.open(dir .. assert(PA_SRC, "set PA_SRC = source image (exactly 3x the sprite size)"))
local big = Image(ref.width, ref.height, ColorMode.RGB); big:drawSprite(ref, 1)
local s = SC / 3
for y = 0, SH_H * SC - 1 do for x = 0, SH_W * SC - 1 do
  out:drawPixel(x, y, big:getPixel(math.floor(SH_X * 3 + x / s), math.floor(SH_Y * 3 + y / s)))
end end
for i, f in ipairs(SH_FILES) do
  local spr = app.open(dir .. f)
  local im = Image(spr.width, spr.height, ColorMode.RGB); im:drawSprite(spr, SH_FRAME or 1)
  local ox = i * (SH_W * SC + gap)
  for y = 0, SH_H - 1 do for x = 0, SH_W - 1 do
    local c = im:getPixel(SH_X + x, SH_Y + y)
    for dy = 0, SC - 1 do for dx = 0, SC - 1 do out:drawPixel(ox + x * SC + dx, y * SC + dy, c) end end
  end end
end
out:saveAs(dir .. SH_OUT)
print("saved", SH_OUT, out.width .. "x" .. out.height)
