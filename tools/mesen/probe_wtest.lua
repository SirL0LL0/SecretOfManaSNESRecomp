local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_wtest.txt", "w")
emu.addMemoryCallback(function(a, v)
  log:write(string.format("WR16 a=%04X v=%02X f=%d\n", a, v, f))
end, emu.callbackType.write, 0x0104, 0x0107, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function(a, v)
  log:write(string.format("WR24 a=%06X v=%02X f=%d\n", a, v, f))
end, emu.callbackType.write, 0x7E0104, 0x7E0107, emu.cpuType.snes, emu.memType.snesMemory)
emu.addEventCallback(function()
  f = f + 1
  if f == 50 then
    emu.write(0x7E0104, 0xAA, emu.memType.snesMemory)
    emu.write(0x0104, 0xBB, emu.memType.snesMemory)
    log:write(string.format("after writes read 0104=%02X 7E0104=%02X\n",
      emu.read(0x0104, emu.memType.snesMemory), emu.read(0x7E0104, emu.memType.snesMemory)))
  end
  if f >= 52 then
    local s = emu.getState()
    local keys = {}
    for k, v in pairs(s) do
      if string.find(k, "dma") or string.find(k, "Dma") or string.find(k, "wram") then
        keys[#keys + 1] = k .. "=" .. tostring(v)
      end
    end
    table.sort(keys)
    for _, v in ipairs(keys) do log:write("STATE " .. v .. "\n") end
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
