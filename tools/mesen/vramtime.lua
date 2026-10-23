local out = io.open("C:/Users/lollo/Downloads/SOM/work/mesen/vramtime.txt", "w")
local f = 0
emu.addEventCallback(function()
  emu.setInput({ a=false, b=false, x=false, y=false, start=false, select=false,
                 up=false, down=false, left=false, right=false, l=false, r=false }, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f = f + 1
  if f >= 2070 then out:close(); emu.stop(0) end
end, emu.eventType.endFrame)
local function cb(addr, value)
  if f >= 1100 and (addr == 0x2117 or addr == 0x420C or addr == 0x2116) then
    local s = emu.getState()
    out:write(string.format("f=%d line=%s addr=%04X val=%02X\n", f, tostring(s["ppu.scanline"]), addr & 0xFFFF, value))
  end
end
emu.addMemoryCallback(cb, emu.callbackType.write, 0x2116, 0x2117)
emu.addMemoryCallback(cb, emu.callbackType.write, 0x420B, 0x420C)
emu.addMemoryCallback(cb, emu.callbackType.write, 0x2100, 0x2100)


