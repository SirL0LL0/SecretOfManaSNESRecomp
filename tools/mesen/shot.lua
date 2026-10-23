local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tv/shot.png"
local f = 0
emu.addEventCallback(function()
  f = f + 1
  if f == 2550 then
    local png = emu.takeScreenshot()
    local h = io.open(out, "wb")
    if h then h:write(png); h:close() end
    emu.stop(0)
  end
end, emu.eventType.endFrame)

