local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/green/"
local f = 0

emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
  if f >= 1500 and f <= 2200 and (f % 10 == 0) then
    local png = emu.takeScreenshot()
    local h = io.open(string.format("%sref_%04d.png", out, f), "wb")
    if h then h:write(png); h:close() end
  end
  if f >= 2200 then emu.stop(0) end
end, emu.eventType.inputPolled)
