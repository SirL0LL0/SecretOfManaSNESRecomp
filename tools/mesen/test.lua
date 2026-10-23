local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local function dump(t, prefix, depth)
  if depth > 3 then return end
  local keys = {}
  for k in pairs(t) do keys[#keys+1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local v = t[k]
    if type(v) == "table" then
      emu.log(prefix .. tostring(k) .. " = {")
      dump(v, prefix .. "  ", depth + 1)
      emu.log(prefix .. "}")
    else
      emu.log(prefix .. tostring(k) .. " = " .. tostring(v))
    end
  end
end

local f = 0
local function onEndFrame()
  f = f + 1
  if f == 5 then
    local h = io.open(out .. "state.txt", "w")
    h:write("frame=" .. f .. "\n")
    h:close()
    local s = emu.getState()
    local g = io.open(out .. "state_keys.txt", "w")
    local function dump2(t, prefix, depth)
      if depth > 3 then return end
      local keys = {}
      for k in pairs(t) do keys[#keys+1] = k end
      table.sort(keys)
      for _, k in ipairs(keys) do
        local v = t[k]
        if type(v) == "table" then
          g:write(prefix .. tostring(k) .. " = {\n")
          dump2(v, prefix .. "  ", depth + 1)
          g:write(prefix .. "}\n")
        else
          g:write(prefix .. tostring(k) .. " = " .. tostring(v) .. "\n")
        end
      end
    end
    dump2(s, "", 0)
    g:close()
    local png = emu.takeScreenshot()
    local p = io.open(out .. "shot5.png", "wb")
    p:write(png)
    p:close()
    local sz = emu.getScreenSize()
    local q = io.open(out .. "screensize.txt", "w")
    for k, v in pairs(sz) do q:write(tostring(k) .. "=" .. tostring(v) .. "\n") end
    q:close()
    emu.stop(0)
  end
end

emu.addEventCallback(onEndFrame, emu.eventType.endFrame)
local m = io.open(out .. "started.txt", "w")
m:write("script started\n")
m:close()
