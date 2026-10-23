local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/name_entry_shots/"
local f = 0
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  if f >= 3100 and f < 3104 then b.start = true end
  emu.setInput(b, 0)
  if f >= 3100 and f <= 3810 and (f % 10 == 0) then
    local png = emu.takeScreenshot()
    local h = io.open(string.format("%sref_%04d.png", out, f), "wb")
    if h then
      h:write(png)
      h:close()
    end
  end
  if f >= 3810 then emu.stop(0) end
end, emu.eventType.inputPolled)
