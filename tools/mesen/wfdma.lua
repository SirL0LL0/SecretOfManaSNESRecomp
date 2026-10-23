local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tv/wfdma.txt"
local f = 0
local presses = { {2500, "start"}, {2804, "b"}, {3200, "b"}, {3400, "start"}, {3700, "b"}, {3800, "start"} }
local log = io.open(out, "w")
emu.addEventCallback(function()
  local inp = { a=false, b=false, x=false, y=false, start=false, select=false,
                up=false, down=false, left=false, right=false, l=false, r=false }
  for _, p in ipairs(presses) do
    if f >= p[1] and f < p[1] + 4 then inp[p[2]] = true end
  end
  if f >= 8000 and f < 11000 and (f % 60) < 4 then inp.b = true end
  emu.setInput(inp, 0)
end, emu.eventType.inputPolled)
-- DMA channel registers 43x0-43x6 and the MDMAEN trigger
emu.addMemoryCallback(function(addr, value)
  if f >= 10800 and f < 10806 then
    log:write(string.format("%d %04X %02X\n", f, addr, value))
  end
end, emu.callbackType.write, 0x420B, 0x420B)
emu.addMemoryCallback(function(addr, value)
  if f >= 10800 and f < 10806 then
    log:write(string.format("%d %04X %02X\n", f, addr, value))
  end
end, emu.callbackType.write, 0x4340, 0x437F)
emu.addMemoryCallback(function(addr, value)
  if f >= 10800 and f < 10806 and value == 0x7F then
    local s = emu.getState()
    local sp = s["cpu.sp"]
    local st = ""
    for k = 1, 12 do st = st .. string.format("%02X ", emu.read(sp + k, emu.memType.snesMemory)) end
    log:write(string.format("PC %d %02X:%04X S=%04X stack: %s\n", f, s["cpu.k"], s["cpu.pc"], sp, st))
  end
end, emu.callbackType.write, 0x4374, 0x4374)
emu.addEventCallback(function()
  f = f + 1
  if f >= 10806 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)


