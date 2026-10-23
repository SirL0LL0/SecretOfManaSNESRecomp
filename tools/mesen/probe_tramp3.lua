local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_tramp3.txt", "w")
local wn, vn = 0, 0
local function rd(a) return emu.read(a, emu.memType.snesMemory) end
local function dump(tag, base)
  local s = string.format("%s %06X:", tag, base)
  for i = 0, 15 do s = s .. string.format(" %02X", rd(base + i)) end
  return s
end
emu.addMemoryCallback(function(a, v)
  if wn < 100 then
    local s = emu.getState()
    log:write(string.format("WR f=%d line=%d addr=%06X val=%02X pc=%06X k=%02X\n",
      s.frameCount, s["ppu.scanline"], a, v, s["cpu.pc"], s["cpu.k"]))
    wn = wn + 1
    log:flush()
  end
end, emu.callbackType.write, 0x7E0104, 0x7E0107, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function()
  local s = emu.getState()
  if s.frameCount >= 3800 and vn < 10 then
    log:write(string.format("V104 f=%d line=%d\n", s.frameCount, s["ppu.scanline"]))
    log:write("  " .. dump("B0", 0x0100) .. "\n")
    log:write("  " .. dump("B7E", 0x7E0100) .. "\n")
    vn = vn + 1
    log:flush()
  end
end, emu.callbackType.exec, 0x0104, 0x0104, emu.cpuType.snes, emu.memType.snesMemory)
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 3000 and f <= 8000 then
    if f % 240 == 0 then b.start = true end
    if f % 240 == 120 then b.b = true end
  end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f >= 3905 then
    log:write("==== done wn=" .. wn .. " vn=" .. vn .. " ====\n")
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
