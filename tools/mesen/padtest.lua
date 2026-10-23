local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local h = io.open(out .. "padread.tsv", "w")
h:write("frame\tscanline\taddr\tvalue\n")
local f = 0
local seen = 0
emu.addEventCallback(function()
  f = f + 1
  if f >= 600 then h:flush(); h:close(); emu.stop(0) end
end, emu.eventType.endFrame)
emu.addEventCallback(function()
  local b = { a=false, b=false, x=false, y=false, start=true, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
local function cb(addr, value)
  local s = emu.getState()
  if s.frameCount >= 400 then
    h:write(string.format("%d\t%d\t%04X\t%02X\n", s.frameCount, s["ppu.scanline"], addr, value))
  end
end
emu.addMemoryCallback(cb, emu.callbackType.read, 0x4218, 0x4219, emu.cpuType.snes, emu.memType.snesMemory)
