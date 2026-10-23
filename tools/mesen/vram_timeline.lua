-- Boot timeline on valid ranges only.
-- Mesen's snesWorkRam is addressed by CPU address, so only $0000-$1FFF (the
-- HiROM WRAM mirror) is real WRAM. snesVideoRam is a flat byte array.
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/boot/"
local f = 0
local rows = {}
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

local function nz(bt, base, n)
  local s = 0
  for i = 0, n - 1 do if bt(base + i) ~= 0 then s = s + 1 end end
  return s
end

emu.addEventCallback(function()
  if f <= 400 and (f % 2 == 0 or f <= 20) then
    rows[#rows+1] = string.format("%d,%d,%d,%d,%d", f,
      nz(emu.memType.snesVideoRam, 0xE000, 0x2000),   -- the missing block
      nz(emu.memType.snesVideoRam, 0xC000, 0x2000),   -- BG2 lower half
      nz(emu.memType.snesVideoRam, 0x8000, 0x2000),   -- BG1 chr?
      nz(emu.memType.snesVideoRam, 0x0000, 0x2000))   -- OBJ chr?
  end
  if f >= 400 then
    local h = io.open(out .. "vram_timeline.csv", "w")
    h:write("frame,vramE000_nz,vramC000_nz,vram8000_nz,vram0000_nz\n")
    for i = 1, #rows do h:write(rows[i] .. "\n") end
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
