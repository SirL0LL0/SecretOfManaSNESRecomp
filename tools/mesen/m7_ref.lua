local out = "C:/Users/lollo/Downloads/SOM/work/mesen/m7_ref/"
local f = 0
local presses = { {1401,1404,"start"}, {1606,1609,"b"}, {1731,1734,"b"}, {1856,1859,"start"} }
local dumps = {}
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
  if f >= 5400 and f <= 5800 then
    local png = emu.takeScreenshot()
    local h = io.open(string.format("%sr%04d.png", out, f), "wb")
    if h then h:write(png); h:close() end
  end
  if f >= 5800 then emu.stop(0) end
end, emu.eventType.endFrame)

