local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local done = false
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  if f >= 3105 and f < 3109 then b.start = true end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 3410 and not done then
    done = true
    local s = emu.getState()
    local h = io.open(out .. "ref_dma_3410.txt", "w")
    local keys = {}
    for k, v in pairs(s) do
      if string.lower(k):find("dma") or string.lower(k):find("irq") or string.lower(k):find("timer") then
        keys[#keys+1] = k
      end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local v = s[k]
      if type(v) == "table" then
        local first = {}
        for i, x in ipairs(v) do if i <= 8 then first[#first+1] = tostring(x) end end
        h:write(string.format("%s = [%s]\n", k, table.concat(first, ",")))
      else
        h:write(string.format("%s = %s\n", k, tostring(v)))
      end
    end
    h:close()
  end
  if f >= 3410 then emu.stop(0) end
end, emu.eventType.endFrame)
