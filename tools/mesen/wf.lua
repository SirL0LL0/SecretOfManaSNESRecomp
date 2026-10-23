local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tv/"
local f = 0
local presses = { {2500, "start"}, {2804, "b"}, {3200, "b"}, {3400, "start"}, {3700, "b"}, {3800, "start"} }
emu.addEventCallback(function()
  local inp = { a=false, b=false, x=false, y=false, start=false, select=false,
                up=false, down=false, left=false, right=false, l=false, r=false }
  for _, p in ipairs(presses) do
    if f >= p[1] and f < p[1] + 4 then inp[p[2]] = true end
  end
  if f >= 8000 and f < 11000 and (f % 60) < 4 then inp.b = true end
  emu.setInput(inp, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f = f + 1
  if f >= 9000 and f % 150 == 0 and f <= 13500 then
    local png = emu.takeScreenshot()
    local h = io.open(string.format("%swf_%05d.png", out, f), "wb")
    if h then h:write(png); h:close() end
  end
  if f >= 13500 then emu.stop(0) end
end, emu.eventType.endFrame)



