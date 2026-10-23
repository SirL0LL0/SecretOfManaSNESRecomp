local out = "C:/Users/lollo/Downloads/SOM/work/mesen/jp/shots/"
local f = 0
emu.addEventCallback(function()
  emu.setInput({ a=false, b=false, x=false, y=false, start=false, select=false,
                 up=false, down=false, left=false, right=false, l=false, r=false }, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f = f + 1
  if f % 100 == 0 then
    local png = emu.takeScreenshot()
    local h = io.open(string.format("%sr%04d.png", out, f), "wb")
    if h then h:write(png); h:close() end
  end
  if f >= 6400 then emu.stop(0) end
end, emu.eventType.endFrame)


