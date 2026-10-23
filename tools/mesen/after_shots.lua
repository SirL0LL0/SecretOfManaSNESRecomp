-- Reference screenshots after the name entry, same input as the recomp run.
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/after/"
local f = 0
local shots = { [3800]=1, [4100]=1, [4600]=1, [5100]=1 }
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  if f >= 3105 and f < 3109 then b.start = true end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if shots[f] then
    local png = emu.takeScreenshot()
    local h = io.open(out .. string.format("ref_%04d.png", f), "wb")
    if h then h:write(png); h:close() end
  end
  if f >= 5100 then emu.stop(0) end
end, emu.eventType.endFrame)
