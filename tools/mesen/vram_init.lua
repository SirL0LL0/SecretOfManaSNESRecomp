-- Frame 0 VRAM (initial state) + the valid WRAM mirror at the name entry.
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

emu.addEventCallback(function()
  if f == 1 then
    local v = io.open(out .. "vram_f0001.bin", "wb")
    for i = 0, 65535 do v:write(string.char(emu.read(i, emu.memType.snesVideoRam))) end
    v:close()
  end
  if f == 3410 then
    local w = io.open(out .. "wram_mirror_3410.bin", "wb")
    for i = 0, 8191 do w:write(string.char(emu.read(i, emu.memType.snesWorkRam))) end
    w:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
