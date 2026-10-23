local f = 0
emu.addEventCallback(function()
  f = f + 1
  if f == 2 then
    local h = io.open("C:/Users/lollo/Downloads/SOM/work/mesen/memtypes.txt", "w")
    for k, v in pairs(emu.memType) do h:write(string.format("%s=%s\n", k, tostring(v))) end
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
