local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_tramp.txt", "w")
local n = 0
emu.addMemoryCallback(function(a, v)
  local s = emu.getState()
  local fr = s.frameCount
  local line = s["ppu.scanline"]
  if fr >= 3880 and fr <= 4020 and n < 400 then
    log:write(string.format("WR f=%d line=%d cyc=%d addr=%04X val=%02X pc=%06X k=%02X dbr=%02X\n",
      fr, line, s["cpu.cycleCount"], a, v, s["cpu.pc"], s["cpu.k"], s["cpu.dbr"]))
    n = n + 1
    log:flush()
  end
end, emu.callbackType.write, 0x0104, 0x0107, emu.cpuType.snes, emu.memType.snesMemory)
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
  if f >= 4020 then log:flush(); log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
