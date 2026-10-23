-- When does WRAM $E700 fill up? Full WRAM snapshots on a coarse grid.
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/early/"
local f = 0
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

local function dumpWram(tag)
  local h = io.open(out .. "w" .. tag .. ".bin", "wb")
  for i = 0, 131071 do h:write(string.char(emu.read(i, emu.memType.snesWorkRam))) end
  h:close()
end

emu.addEventCallback(function()
  if f == 200 or f == 400 or f == 600 or f == 800 or f == 1000 or f == 1200 or f == 1400 then
    dumpWram(string.format("%04d", f))
  end
  if f >= 1400 then emu.stop(0) end
end, emu.eventType.endFrame)
