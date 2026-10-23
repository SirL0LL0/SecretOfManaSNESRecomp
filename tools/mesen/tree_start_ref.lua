local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/start_ref/"
local f = 0
local target = 2500
local shots = { target + 100, target + 300, target + 500, target + 800, target + 1200, target + 1600 }

emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= target and f < target + 4 then b.start = true end
  emu.setInput(b, 0)
  for _, t in ipairs(shots) do
    if f == t then
      local png = emu.takeScreenshot()
      local h = io.open(string.format("%sref_start%d_%d.png", out, target, f), "wb")
      if h then h:write(png); h:close() end
    end
  end
  if f >= target + 1800 then emu.stop(0) end
end, emu.eventType.inputPolled)
