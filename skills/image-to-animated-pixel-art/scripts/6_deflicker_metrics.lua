-- De-flicker BA_IN (default frames_01.aseprite; eyes excluded near the blink), measure pops and jumps, save BA_OUT.aseprite.
local dir = assert(PA_DIR, "set PA_DIR = project folder ending in a path separator (\\ or /)")
local spr = app.open(dir .. (BA_IN or "frames_01.aseprite"))
local N = #spr.frames
local W, H = spr.width, spr.height
local fr = {}
for _, c in ipairs(spr.cels) do fr[c.frameNumber] = c.image:clone() end
-- SETTINGS per image (example values): eye box and the frames around the blink
local function inEyes(x, y) return x >= 58 and x < 114 and y >= 76 and y < 102 end
-- the blink (frames 30-35) must not be smoothed away; frames 28..37 cover every window that touches it
local function nearBlink(k) return k >= 28 and k <= 37 end
local function fix()
  local f = 0
  for k = 1, N do
    local p, c1, c2, nx = fr[(k - 2) % N + 1], fr[k], fr[k % N + 1], fr[(k + 1) % N + 1]
    local skipEyes = nearBlink(k)
    for y = 0, H - 1 do for x = 0, W - 1 do
      local a, b1 = p:getPixel(x, y), c1:getPixel(x, y)
      if b1 ~= a and not (skipEyes and inEyes(x, y)) and not (BA_SKIP and BA_SKIP(k, x, y)) then
        local c2p = c2:getPixel(x, y)
        if c2p == a then c1:drawPixel(x, y, a); f = f + 1
        elseif c2p == b1 and nx:getPixel(x, y) == a then c1:drawPixel(x, y, a); c2:drawPixel(x, y, a); f = f + 2 end
      end
    end end
  end
  return f
end
local log = {}
for it = 1, 6 do local f = fix(); log[#log + 1] = f; if f == 0 then break end end
-- jump check counts soft pixels only: rigid whole-pixel steps (BA_SKIP boxes, e.g. lifting hands) are big by design
local pops, pops2, per = 0, 0, {}
for k = 1, N do
  local a, b, c, d = fr[k], fr[k % N + 1], fr[(k + 1) % N + 1], fr[(k + 2) % N + 1]
  local n = 0
  for y = 0, H - 1 do for x = 0, W - 1 do
    local pa, pb = a:getPixel(x, y), b:getPixel(x, y)
    if pa ~= pb then
      if not (BA_SKIP and (BA_SKIP(k, x, y) or BA_SKIP(k % N + 1, x, y))) then n = n + 1 end
      local pcc = c:getPixel(x, y)
      if pcc == pa then pops = pops + 1 elseif pcc == pb and d:getPixel(x, y) == pa then pops2 = pops2 + 1 end
    end
  end end
  per[k] = n
end
-- BA_STEPS = {[k] = true} for frames k -> k+1 where a rigid part takes a whole-pixel step: big by design (the
-- flesh it pushes steps with it), so they are left out of the ratio and listed instead. Everything else must be <= 2x median.
local sorted, steps = {}, {}
for k = 1, N do if BA_STEPS and BA_STEPS[k] then steps[#steps + 1] = k .. ":" .. per[k] else sorted[#sorted + 1] = per[k] end end
table.sort(sorted)
local M = #sorted
print("step frames (excluded): " .. table.concat(steps, " "))
local out = Sprite(W, H, ColorMode.RGB)
out:setPalette(spr.palettes[1])
local layer = out.layers[1]; layer.name = "Art"
for k = 1, N do
  if k > 1 then out:newEmptyFrame() end
  out:newCel(layer, k, fr[k], Point(0, 0))
  out.frames[k].duration = 0.05
end
local tag = out:newTag(1, N); tag.name = "idle"
out:saveAs(dir .. (BA_OUT or "idle") .. ".aseprite")
print("deflicker fixes per pass: " .. table.concat(log, ", "))
print(string.format("1-frame pops %d, 2-frame pops %d", pops, pops2))
print("changed px frame->next: " .. table.concat(per, " "))
-- guide, not a hard gate: a clean loop scored 2.04 here, on its blink frame. Look at every listed frame and name its cause.
local med = sorted[(M + 1) // 2]
local over = {}
for k = 1, N do if not (BA_STEPS and BA_STEPS[k]) and per[k] > 2 * med then over[#over + 1] = k .. ":" .. per[k] end end
print(string.format("changed px (no steps): median %d, max %d, ratio %.2f; frames over 2x median: %s",
  med, sorted[M], sorted[M] / math.max(1, med), #over > 0 and table.concat(over, " ") or "none"))
