local f = 0
emu.addEventCallback(function()
  f = f + 1
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 100 then
    local s = emu.getState()
    local h = io.open("C:/Users/lollo/Downloads/SOM/work/mesen/tree/ref_state_keys.txt", "w")
    local keys = {}
    for k, v in pairs(s) do keys[#keys+1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local v = s[k]
      if type(v) ~= "table" then
        h:write(string.format("%s = %s\n", k, tostring(v)))
      else
        h:write(string.format("%s = <table %d>\n", k, #v))
      end
    end
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
