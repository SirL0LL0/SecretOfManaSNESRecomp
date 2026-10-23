-- Boot timeline on valid ranges only, cheap probes, up to the name entry.
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/boot/"
local f = 0
local rows = {}
local le, lc, l8 = -1, -1, -1
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  if f >= 3105 and f < 3109 then b.start = true end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

local function nz(bt, base, n)
  local s = 0
  for i = 0, n - 1 do if bt(base + i) ~= 0 then s = s + 1 end end
  return s
end

emu.addEventCallback(function()
  local e = nz(emu.memType.snesVideoRam, 0xE000, 16)
  local c = nz(emu.memType.snesVideoRam, 0xC000, 16)
  local e8 = nz(emu.memType.snesVideoRam, 0xE800, 16)
  if e ~= le or c ~= lc or e8 ~= l8 then
    rows[#rows+1] = string.format("%d,%d,%d,%d", f, e, c, e8)
    le, lc, l8 = e, c, e8
  end
  if f >= 3410 then
    local h = io.open(out .. "vram_timeline2.csv", "w")
    h:write("frame,vramE000_nz16,vramC000_nz16,vramE800_nz16\n")
    for i = 1, #rows do h:write(rows[i] .. "\n") end
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
