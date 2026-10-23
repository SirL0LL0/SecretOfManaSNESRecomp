local out = "C:/Users/lollo/Downloads/SOM/work/mesen/exact/"
local f = 0
local log = io.open(out .. "events.txt", "w")
local irqn = 0
local c1cf = 0
local a266 = 0
local function rd(a) return emu.read(a, emu.memType.snesDebug) end
local function tramp()
  return string.format("%02X%02X%02X%02X", rd(0x7E0107), rd(0x7E0106), rd(0x7E0105), rd(0x7E0104))
end
local function st()
  local s = emu.getState()
  return string.format("pc=%06X k=%02X ps=%02X e=%s line=%s",
    s["cpu.pc"] or 0, s["cpu.k"] or 0, s["cpu.ps"] or 0,
    tostring(s["cpu.emulationMode"]), tostring(s["ppu.scanline"]))
end
emu.addEventCallback(function(cpu)
  irqn = irqn + 1
  if f >= 3300 and f <= 4300 and irqn < 600 then
    log:write(string.format("IRQ f=%d %s tramp=%s\n", f, st(), tramp()))
    if irqn % 20 == 0 then log:flush() end
  end
end, emu.eventType.irq)
emu.addEventCallback(function(cpu)
  if f >= 3300 and f <= 4300 then
    log:write(string.format("START f=%d tramp=%s\n", f, tramp()))
  end
end, emu.eventType.startFrame)
emu.addEventCallback(function(cpu)
  if f >= 3300 and f <= 4300 then
    log:write(string.format("END f=%d tramp=%s\n", f, tramp()))
  end
  if f >= 4300 then
    log:write(string.format("DONE irq=%d c1cf=%d a266=%d\n", irqn, c1cf, a266))
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
emu.addMemoryCallback(function()
  c1cf = c1cf + 1
end, emu.callbackType.exec, 0xC1CF, 0xC1CF, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function()
  a266 = a266 + 1
end, emu.callbackType.exec, 0x7EA266, 0x7EA266, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function(a, v)
  log:write(string.format("W212C f=%d line=%s val=%02X tramp=%s\n", f, tostring(emu.getState()["ppu.scanline"]), v, tramp()))
  log:flush()
end, emu.callbackType.write, 0x212C, 0x212C, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function(a, v)
  local s = emu.getState()
  log:write(string.format("WTRAMP f=%d line=%s addr=%04X val=%02X pc=%06X k=%02X dbr=%02X\n",
    f, tostring(s["ppu.scanline"]), a, v, s["cpu.pc"] or 0, s["cpu.k"] or 0, s["cpu.dbr"] or 0))
  log:flush()
end, emu.callbackType.write, 0x0104, 0x0107, emu.cpuType.snes, emu.memType.snesMemory)

local seq = {
  { 900, 4, "start" },
  { 2004, 4, "b" },
  { 2308, 4, "right" },
  { 2512, 4, "b" },
  { 2716, 4, "start" },
}
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  for _, p in ipairs(seq) do
    if f >= p[1] and f < p[1] + p[2] then b[p[3]] = true end
  end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
