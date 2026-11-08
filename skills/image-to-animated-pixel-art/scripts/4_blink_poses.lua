-- Blink poses (SETTINGS below are traced per image; globals BP_IN, BP_OUT): the whole upper lash mass comes DOWN with the lid, across the full width of the lashes.
-- Per column: rows from lidTop to the lash line become lid skin (only where the open eye is dark lash/liner or
-- the eye opening), and a clean 2 px lash line follows a smooth hand-set curve. Closed: the curve is the bottom
-- of the eye, so the upper lashes meet the lower ones. Half: halfway between the open lash line and that curve.
-- A thin crease of liner above lidTop stays. Curves traced from 14x views of the still (example values shown).
local dir = assert(PA_DIR, "set PA_DIR = project folder ending in a path separator (\\ or /)")
local spr = app.open(dir .. assert(BP_IN, "set BP_IN = finished still .aseprite"))
local pc = app.pixelColor
local open = spr.cels[1].image
local function rgb(h) return pc.rgba(h >> 16, (h >> 8) & 255, h & 255, 255) end
local function lum(c) return (3 * pc.rgbaR(c) + 6 * pc.rgbaG(c) + pc.rgbaB(c)) / 10 end
-- eye openings (first/last row per column), so light eye-white pixels also get covered
local opening = {}
local function span(x0, x1, r0, r1) for x = x0, x1 do opening[x] = {r0, r1} end end
span(94, 94, 89, 90); span(95, 95, 88, 91); span(96, 96, 88, 92); span(97, 100, 87, 92)
span(101, 103, 87, 91); span(104, 104, 87, 90); span(105, 105, 88, 89)
span(70, 70, 93, 96); span(71, 72, 93, 97); span(73, 73, 94, 97); span(74, 74, 95, 97); span(75, 75, 96, 96)
local EYES = {
  { -- right (larger) eye; x0 = first column of the closed-lash curve
    x0 = 88, curve = {89, 90, 90, 91, 91, 91, 91, 92, 92, 92, 92, 92, 92, 92, 91, 91, 91, 91, 91, 91, 91, 90, 90},
    lower = {90, 91, 91, 91, 91, 91, 92, 92, 93, 93, 93, 93, 93, 92, 92, 92, 92, 92, 92, 92, 92, 91, 91},
    -- almond lid top, used only with USE_ARC = true. A flat lid read better in testing: leave it off.
    lidArc = {89, 88, 87, 86, 86, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 86, 86, 87, 88, 89},
    openLine = 86, lidTop = 85, shade = rgb(0xB87D63), lid = rgb(0xD2A487), deep = rgb(0xC9967A), strand = true,
  },
  { -- left (small) eye, in shadow
    x0 = 66, curve = {95, 95, 96, 96, 97, 97, 97, 97, 97, 97, 96},
    lower = {98, 98, 98, 98, 98, 98, 98, 98, 98, 98, 97},
    lidArc = {96, 95, 94, 93, 92, 91, 91, 91, 92, 93, 94},
    openLine = 92, lidTop = 90, shade = rgb(0x8A503C), lid = rgb(0xA8745F), deep = rgb(0x9A604A),
  },
}
local LASH = rgb(0x0E0D0E)
local STRAND = {}
for _, h in ipairs({0x87B2B7, 0x6C9AA5, 0x716158}) do STRAND[rgb(h)] = true end
local function covered(x, y)
  local o = opening[x]
  return (o and y >= o[1] and y <= o[2]) or lum(open:getPixel(x, y)) < 110
end
local function pose(frac)
  local img = open:clone()
  for _, e in ipairs(EYES) do
    for i, b in ipairs(e.curve) do
      local x = e.x0 + i - 1
      -- half uses the traced curve; nearly closed and closed travel to the lower lash row so the lashes meet
      local target = (USE_LOWER and frac > 0.5) and e.lower[i] or b
      local line = math.floor(e.openLine + (target - e.openLine) * frac + 0.5)  -- bottom row of the lash line
      local first = true
      for y = ((USE_ARC and e.lidArc) and e.lidArc[i] or e.lidTop), line - 2 do
        if covered(x, y) then
          img:drawPixel(x, y, first and e.shade or (y == line - 2 and e.deep or e.lid)); first = false
        end
      end
      img:drawPixel(x, line - 1, LASH); img:drawPixel(x, line, LASH)
      if e.strand then -- the hair strand crossing this eye stays in front of the lid
        for y = 78, 100 do local o = open:getPixel(x, y); if STRAND[o] then img:drawPixel(x, y, o) end end
      end
    end
  end
  return img
end
local half, near, closed = pose(0.5), pose(0.75), pose(1.0)
local s = Sprite(open.width, open.height, ColorMode.RGB)
s:setPalette(spr.palettes[1])
s.cels[1].image = open
s:newEmptyFrame(); s:newCel(s.layers[1], 2, half, Point(0, 0))
s:newEmptyFrame(); s:newCel(s.layers[1], 3, near, Point(0, 0))
s:newEmptyFrame(); s:newCel(s.layers[1], 4, closed, Point(0, 0))
s:saveAs(dir .. (BP_OUT or "blink_poses.aseprite"))
print("ok")
