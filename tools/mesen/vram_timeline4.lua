-- VRAM timeline: one small file per checkpoint.
-- emu.memType.* are constants: the accessor is emu.read(addr, memType).
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

local function nz(base, n)
  local s = 0
  for i = 0, n - 1 do if emu.read(base + i, emu.memType.snesVideoRam) ~= 0 then s = s + 1 end end
  return s
end

emu.addEventCallback(function()
  if f % 50 == 0 then
    local h = io.open(out .. string.format("v3_%04d.txt", f), "w")
    h:write(string.format("frame=%d E000-FFFF=%d E800-FFFF=%d C000-DFFF=%d 8000-9FFF=%d 0000-1FFF=%d\n", f,
      nz(0xE000, 0x2000), nz(0xE800, 0x2000), nz(0xC000, 0x2000),
      nz(0x8000, 0x2000), nz(0x0000, 0x2000)))
    h:close()
  end
  if f >= 3410 then emu.stop(0) end
end, emu.eventType.endFrame)
