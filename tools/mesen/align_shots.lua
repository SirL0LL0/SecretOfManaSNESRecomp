-- Reference screenshots along the intro (same input: Start at 2500).
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/align/"
local shots = { [2075]=1, [2100]=1, [2150]=1, [2300]=1, [2400]=1, [2500]=1,
                [2550]=1, [2600]=1, [2800]=1, [3000]=1 }
local f = 0
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if shots[f] then
    local png = emu.takeScreenshot()
    local h = io.open(out .. string.format("shot_%04d.png", f), "wb")
    if h then h:write(png); h:close() end
  end
  if f >= 3000 then emu.stop(0) end
end, emu.eventType.endFrame)
