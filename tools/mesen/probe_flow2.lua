local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_flow2.txt", "w")
local n = 0
local function rd(addr) return emu.read(addr, emu.memType.snesMemory) end
local function dump(addr, cnt)
  local s = string.format("%06X:", addr)
  for i = 0, cnt - 1 do s = s .. string.format(" %02X", rd(addr + i)) end
  return s
end
emu.addMemoryCallback(function(a, v)
  if n < 20 then
    local s = emu.getState()
    log:write(string.format("V104 frame=%d line=%d pc=%06X k=%02X ps=%02X e=%s dbr=%02X d=%04X\n",
      s.frameCount, s["ppu.scanline"], s["cpu.pc"], s["cpu.k"], s["cpu.ps"], tostring(s["cpu.emulationMode"]), s["cpu.dbr"], s["cpu.d"]))
    log:write("  RAM0100 " .. dump(0x0100, 16) .. "\n")
    log:write("  ROMC1CF " .. dump(0xC1CF, 16) .. "\n")
    log:write("  ROMC0A8 " .. dump(0xC0A8, 16) .. "\n")
    n = n + 1
    log:flush()
  end
end, emu.callbackType.exec, 0x0104, 0x0104, emu.cpuType.snes, emu.memType.snesMemory)
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
  if f >= 25 then log:flush(); log:close(); emu.stop(0) end
end, emu.eventType.inputPolled)
