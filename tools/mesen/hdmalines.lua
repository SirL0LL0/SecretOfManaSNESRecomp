local out = io.open("C:/Users/lollo/Downloads/SOM/work/mesen/hdmalines.txt", "w")
local f = 0
emu.addEventCallback(function()
  emu.setInput({ a=false, b=false, x=false, y=false, start=false, select=false,
                 up=false, down=false, left=false, right=false, l=false, r=false }, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f = f + 1
  if f >= 3545 then out:close(); emu.stop(0) end
end, emu.eventType.endFrame)
local function cb(addr, value)
  if f == 3543 then
    local s = emu.getState()
    out:write(string.format("line=%s h=%s addr=%04X val=%02X\n", tostring(s["ppu.scanline"]), tostring(s["ppu.cycle"]), addr & 0xFFFF, value))
  end
end
emu.addMemoryCallback(cb, emu.callbackType.write, 0x2110, 0x2110)
emu.addMemoryCallback(cb, emu.callbackType.write, 0x2121, 0x2121)
emu.addMemoryCallback(cb, emu.callbackType.write, 0x2126, 0x2127)
emu.addMemoryCallback(cb, emu.callbackType.write, 0x212C, 0x212D)
