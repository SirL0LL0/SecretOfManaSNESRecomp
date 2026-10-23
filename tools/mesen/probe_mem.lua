local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = io.open(out .. "probe_mem.txt", "w")
local function dump(addr, n)
  local s = string.format("%04X:", addr)
  for i = 0, n - 1 do
    local b = emu.read(addr + i, emu.memType.snesMemory)
    s = s .. string.format(" %02X", b)
  end
  f:write(s .. "\n")
end
local function ev()
  f:write("frame=" .. emu.getState().frameCount .. "\n")
  dump(0xFFE4, 28)
  dump(0xD5B4, 32)
  dump(0xD5C1, 32)
  dump(0xF124, 32)
  dump(0xC1CF, 32)
  dump(0x8000, 16)
  local st = emu.getState()
  local keys = {}
  for k, v in pairs(st) do
    if string.find(k, "cart") or string.find(k, "rom") or string.find(k, "mapping") then
      keys[#keys + 1] = k .. "=" .. tostring(v)
    end
  end
  table.sort(keys)
  for _, v in ipairs(keys) do f:write(v .. "\n") end
  f:flush()
  f:close()
  emu.stop(0)
end
emu.addEventCallback(ev, emu.eventType.endFrame)
