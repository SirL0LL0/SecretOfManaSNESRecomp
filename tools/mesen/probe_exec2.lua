local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_exec2.txt", "w")
local n = 0
local function add(tag, start, finish)
  local ok, err = pcall(function()
    emu.addMemoryCallback(function(a, v)
      if n < 60 then
        local s = emu.getState()
        log:write(string.format("%s a=%06X pc=%06X k=%02X\n", tag, a, s["cpu.pc"], s["cpu.k"]))
        n = n + 1
      end
    end, emu.callbackType.exec, start, finish, emu.cpuType.snes, emu.memType.snesMemory)
  end)
  if not ok then log:write(tag .. " ERROR " .. tostring(err) .. "\n") end
end
add("C14CD2", 0xC14CD2, 0xC14CD2)
add("C10000-1FFFF", 0xC10000, 0xC1FFFF)
add("00C1CF", 0x00C1CF, 0x00C1CF)
add("000000-00FFFF", 0x000000, 0x00FFFF)
add("8004", 0x8004, 0x8004)
add("C1CFrange", 0xC1CF, 0xC1CF)
emu.addEventCallback(function()
  f = f + 1
  if f >= 10 then log:flush(); log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
