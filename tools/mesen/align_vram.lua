-- Reference VRAM every 100 frames: the alignment key for the timeline.
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/align/"
local f = 0
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f % 100 == 0 then
    local v = io.open(out .. string.format("v%04d.bin", f), "wb")
    for i = 0, 65535 do v:write(string.char(emu.read(i, emu.memType.snesVideoRam))) end
    v:close()
  end
  if f >= 3410 then emu.stop(0) end
end, emu.eventType.endFrame)
