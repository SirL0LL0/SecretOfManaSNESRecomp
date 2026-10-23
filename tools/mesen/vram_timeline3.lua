-- Boot timeline: one small file per checkpoint (the pattern that works).
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/boot/"
local f = 0
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
  if f % 50 == 0 then
    local h = io.open(out .. string.format("v2_%04d.txt", f), "w")
    h:write(string.format("frame=%d E000=%d E800=%d C000=%d 8000=%d 0000=%d\n", f,
      nz(emu.memType.snesVideoRam, 0xE000, 0x2000),
      nz(emu.memType.snesVideoRam, 0xE800, 0x2000),
      nz(emu.memType.snesVideoRam, 0xC000, 0x2000),
      nz(emu.memType.snesVideoRam, 0x8000, 0x2000),
      nz(emu.memType.snesVideoRam, 0x0000, 0x2000)))
    h:close()
  end
  if f >= 3410 then emu.stop(0) end
end, emu.eventType.endFrame)
