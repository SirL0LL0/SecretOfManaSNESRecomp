local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local log = io.open(out .. "probe_log.txt", "w")
local f = 0
log:write("script loaded\n"); log:flush()
emu.addEventCallback(function()
  f = f + 1
  if f % 100 == 0 then log:write("f=" .. f .. "\n"); log:flush() end
  if f >= 600 then log:write("done\n"); log:close(); emu.stop(0) end
end, emu.eventType.inputPolled)
