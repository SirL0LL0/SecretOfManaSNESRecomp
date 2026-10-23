local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local log = io.open(out .. "dmawrites_all_log.txt", "w")
log:write("dma writes all\n"); log:flush()

emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

local function cb(addr, value)
  if f <= 1500 then
    local s = emu.getState()
    log:write(string.format("W%04X f=%d scan=%d v=%02X pc=%04X\n",
      addr, f, s["ppu.scanline"] or -1, value, s["cpu.pc"] or 0))
    log:flush()
  end
end
emu.addMemoryCallback(cb, emu.callbackType.write, 0x4330, 0x437F, emu.cpuType.snes, emu.memType.snesMemory)

emu.addEventCallback(function()
  if f >= 1500 then log:write("DONE\n"); log:flush(); log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
