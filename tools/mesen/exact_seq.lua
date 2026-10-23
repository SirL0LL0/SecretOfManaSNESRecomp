local out = "C:/Users/lollo/Downloads/SOM/work/mesen/exact/"
local f = 0
local log = io.open(out .. "exact_log.txt", "w")
local irq = 0
local c1cf = 0
local a266 = 0
local tmw = 0
local function rd(a) return emu.read(a, emu.memType.snesMemory) end
local function tramp()
  return string.format("%02X%02X%02X%02X", rd(0x7E0107), rd(0x7E0106), rd(0x7E0105), rd(0x7E0104))
end
local function ppu()
  local s = emu.getState()
  return string.format("mode=%s tm=%02X bg3pri=%s", tostring(s["ppu.bgMode"]),
    s["ppu.mainScreenLayers"] or 0, tostring(s["ppu.mode1Bg3Priority"]))
end
emu.addMemoryCallback(function()
  irq = irq + 1
end, emu.callbackType.exec, 0x0104, 0x0104, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function()
  c1cf = c1cf + 1
end, emu.callbackType.exec, 0xC1CF, 0xC1CF, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function()
  a266 = a266 + 1
end, emu.callbackType.exec, 0x7EA266, 0x7EA266, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function(a, v)
  tmw = tmw + 1
  if f >= 3300 and f <= 4300 then
    log:write(string.format("W212C f=%d val=%02X tramp=%s\n", f, v, tramp()))
    log:flush()
  end
end, emu.callbackType.write, 0x212C, 0x212C, emu.cpuType.snes, emu.memType.snesMemory)

local function press(name, len)
  return function(fr) return fr >= name and fr < name + len end
end
-- exact recomp sequence boundaries
local seq = {
  { 900, 4, "start" },
  { 2004, 4, "b" },
  { 2308, 4, "right" },
  { 2512, 4, "b" },
  { 2716, 4, "start" },
}
local shotAt = { 3300, 3400, 3500, 3550, 3600, 3625, 3650, 3700, 3750, 3800, 3850, 3900, 3950, 4000, 4050, 4100, 4200, 4300 }

emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  for _, p in ipairs(seq) do
    if f >= p[1] and f < p[1] + p[2] then b[p[3]] = true end
  end
  emu.setInput(b, 0)
  for _, s in ipairs(shotAt) do
    if f == s then
      local path = out .. string.format("m_%d.png", f)
      emu.takeScreenshot(path)
      log:write(string.format("SHOT f=%d %s tramp=%s irq=%d c1cf=%d a266=%d tmw=%d\n",
        f, ppu(), tramp(), irq, c1cf, a266, tmw))
      log:flush()
    end
  end
  if f == 3300 or f == 3400 or f == 3500 or f == 3600 or f == 3700 or f == 3800 or f == 3900 or f == 4000 or f == 4100 or f == 4200 or f == 4300 then
    log:write(string.format("FRAME f=%d %s tramp=%s irq=%d c1cf=%d a266=%d tmw=%d\n",
      f, ppu(), tramp(), irq, c1cf, a266, tmw))
    log:flush()
  end
  if f >= 4300 then
    log:write(string.format("DONE irq=%d c1cf=%d a266=%d tmw=%d\n", irq, c1cf, a266, tmw))
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.inputPolled)
