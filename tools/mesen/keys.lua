local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "keys.txt", "w")
emu.addEventCallback(function()
  f = f + 1
  if f == 5 then
    local s = emu.getState()
    local keys = {}
    for k, v in pairs(s) do
      if string.sub(k, 1, 4) == "cpu." or string.find(k, "flag") or string.find(k, "emulation") then
        keys[#keys + 1] = k .. " = " .. tostring(v)
      end
    end
    table.sort(keys)
    for _, v in ipairs(keys) do log:write(v .. "\n") end
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
