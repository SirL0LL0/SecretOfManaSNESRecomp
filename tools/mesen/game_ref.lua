local out = "C:/Users/lollo/Downloads/SOM/work/mesen/game_ref/"
local f = 0
local presses = { {1401,1404,"start"}, {1606,1609,"b"}, {1731,1734,"b"}, {1856,1859,"start"} }
local dumps = { [1605]=true, [1730]=true, [1855]=true, [2060]=true, [2260]=true, [2560]=true,
                [2860]=true, [3160]=true, [3460]=true, [3860]=true }
emu.addEventCallback(function()
  local cur = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  for _, p in ipairs(presses) do
    if cur >= p[1] and cur <= p[2] then b[p[3]] = true end
  end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f = f + 1
  if dumps[f] then
    local png = emu.takeScreenshot()
    local h = io.open(string.format("%sr%04d.png", out, f), "wb")
    if h then h:write(png); h:close() end
  end
  if f >= 3860 then emu.stop(0) end
end, emu.eventType.endFrame)
