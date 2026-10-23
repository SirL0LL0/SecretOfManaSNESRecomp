local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_dbr.txt", "w")
local function rd(a) return emu.read(a, emu.memType.snesMemory) end
local function dump(tag, base)
  local s = string.format("%s %06X:", tag, base)
  for i = 0, 15 do s = s .. string.format(" %02X", rd(base + i)) end
  return s
end
emu.addMemoryCallback(function(a, v)
  local s = emu.getState()
  local fr = s.frameCount
  if (fr >= 3350 and fr <= 3400) or (fr >= 3840 and fr <= 3900) then
    log:write(string.format("W f=%d line=%d addr=%04X val=%02X pc=%06X k=%02X dbr=%02X\n",
      fr, s["ppu.scanline"], a, v, s["cpu.pc"], s["cpu.k"], s["cpu.dbr"]))
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
  if f == 3900 then
    log:write("END 3900\n")
    log:write(dump("7E0100", 0x7E0100) .. "\n")
    log:write(dump("7F0100", 0x7F0100) .. "\n")
    log:flush()
  end
  if f >= 3900 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
