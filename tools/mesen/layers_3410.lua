local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local done = false
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 3410 and not done then
    done = true
    local s = emu.getState()
    local h = io.open(out .. "ref_layers_3410.txt", "w")
    local keys = {}
    for k, v in pairs(s) do
      local lk = string.lower(k)
      if lk:find("layer") or lk:find("tilemap") or lk:find("bg") or lk:find("scroll") or lk:find("mode") or lk:find("interlace") then
        keys[#keys+1] = k
      end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local v = s[k]
      local tv = type(v)
      if tv == "table" then
        local n = 0
        local first = {}
        for i, x in ipairs(v) do
          n = n + 1
          if n <= 8 then first[#first+1] = tostring(x) end
        end
        h:write(string.format("%s = table(%d) [%s]\n", k, n, table.concat(first, ",")))
      else
        h:write(string.format("%s = %s\n", k, tostring(v)))
      end
    end
    h:close()
  end
  if f >= 3410 then emu.stop(0) end
end, emu.eventType.endFrame)
