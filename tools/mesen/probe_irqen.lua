local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_irqen.txt", "w")
emu.addMemoryCallback(function(a, v)
  local s = emu.getState()
  local fr = s.frameCount
  if (fr >= 3350 and fr <= 3390) or (fr >= 3850 and fr <= 3910) then
    log:write(string.format("W4200 f=%d line=%d val=%02X pc=%06X k=%02X ps=%02X\n",
      fr, s["ppu.scanline"], v, s["cpu.pc"], s["cpu.k"], s["cpu.ps"]))
    log:flush()
  end
end, emu.callbackType.write, 0x4200, 0x4200, emu.cpuType.snes, emu.memType.snesMemory)
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
  if f == 3350 or f == 3369 or f == 3370 or f == 3857 or f == 3858 or f == 3900 or f == 3901 or f == 4000 or f == 5000 then
    local s = emu.getState()
    log:write(string.format("STATE f=%d ps=%02X I=%d k=%02X pc=%06X irqLock=%s src=%d prev=%d\n",
      f, s["cpu.ps"], (s["cpu.ps"] & 4) ~= 0 and 1 or 0, s["cpu.k"], s["cpu.pc"],
      tostring(s["cpu.irqLock"]), s["cpu.irqSource"], s["cpu.prevIrqSource"]))
    log:flush()
  end
  if f >= 5000 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
