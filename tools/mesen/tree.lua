local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local shotAt = {900,950,1000,1050,1100,1150,1200,1250,1300,1350,1400,1450,1500}
local log = io.open(out .. "tree_log.txt", "w")
log:write("script loaded\n"); log:flush()
local function shot(tag)
  local png = emu.takeScreenshot()
  local h = io.open(out .. "ref_" .. tag .. ".png", "wb")
  if h then h:write(png); h:close() end
end
emu.addEventCallback(function()
  f = f + 1
  for _, s in ipairs(shotAt) do
    if f == s then
      shot(tostring(f))
      log:write(string.format("SHOT %d\n", f)); log:flush()
    end
  end
  if f >= 1500 then log:write("done\n"); log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
