local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tv/wfram.txt"
local f = 0
local presses = { {2500, "start"}, {2804, "b"}, {3200, "b"}, {3400, "start"}, {3700, "b"}, {3800, "start"} }
local log = io.open(out, "w")
emu.addEventCallback(function()
  local inp = { a=false, b=false, x=false, y=false, start=false, select=false,
                up=false, down=false, left=false, right=false, l=false, r=false }
  for _, p in ipairs(presses) do
    if f >= p[1] and f < p[1] + 4 then inp[p[2]] = true end
  end
  if f >= 8000 and f < 11000 and (f % 60) < 4 then inp.b = true end
  emu.setInput(inp, 0)
end, emu.eventType.inputPolled)
local function rd(a) return emu.read(a, emu.memType.snesWorkRam) end
emu.addEventCallback(function()
  f = f + 1
  if f >= 10800 and f < 10812 then
    local s = string.format("%d 9A=%02X |", f, rd(0x9A))
    for e = 0, 3 do
      s = s .. " "
      for k = 0, 15 do s = s .. string.format("%02X", rd(0x18200 + 16 * e + k)) end
    end
    log:write(s .. "\n")
  end
  if f >= 10812 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
