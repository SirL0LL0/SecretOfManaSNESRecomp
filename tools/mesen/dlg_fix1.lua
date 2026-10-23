local out = "C:/Users/lollo/Downloads/SOM/work/mesen/dlg_fix1/"
local f = 0
local presses = { {1401,1404,"start"}, {1606,1609,"b"}, {1731,1734,"b"}, {1856,1859,"start"}, {6047,6050,"b"}, {6248,6251,"b"}, {6449,6452,"b"}, {6650,6653,"b"}, {6851,6854,"b"}, {7052,7055,"b"}, {7253,7256,"b"}, {7454,7457,"b"}, {7655,7658,"b"}, {7856,7859,"b"}, {8057,8060,"b"}, {8258,8261,"b"} }
emu.addEventCallback(function()
  local cur = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  for _, p in ipairs(presses) do
    if cur >= p[1] and cur <= p[2] then b[p[3]] = true end
  end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f = f + 1
  if (f >= 7200 and f <= 7700 and f % 10 == 0) then
    local png = emu.takeScreenshot()
    local h = io.open(string.format("%sr%04d.png", out, f), "wb")
    if h then h:write(png); h:close() end
  end
  if f >= 7700 then emu.stop(0) end
end, emu.eventType.endFrame)

