local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local shotDir = out .. "probe/"
local f = 0
local function shot(tag)
  local png = emu.takeScreenshot()
  local h = io.open(shotDir .. "p_" .. tag .. ".png", "wb")
  if h then h:write(png); h:close() end
end
local frames = {}
for i = 1680, 2100, 20 do frames[i] = true end
emu.addEventCallback(function()
  f = f + 1
  if frames[f] then shot(string.format("%04d", f)) end
  if f >= 2100 then emu.stop(0) end
end, emu.eventType.endFrame)
emu.addEventCallback(function()
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
