local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local log = io.open(out .. "keys_log.txt", "w")
log:write("state keys\n"); log:flush()
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 1500 then
    local s = emu.getState()
    local keys = {}
    for k, v in pairs(s) do
      local lk = tostring(k):lower()
      if lk:find("dma") or lk:find("hdma") or lk:find("cpu%.") then
        keys[#keys + 1] = tostring(k) .. " = " .. tostring(v)
      end
    end
    table.sort(keys)
    for _, line in ipairs(keys) do log:write(line .. "\n") end
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
