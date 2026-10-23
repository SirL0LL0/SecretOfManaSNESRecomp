-- WRAM mirror snapshots around the boot decompression.
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/boot/"
local marks = { [11]=1, [14]=1, [15]=1, [18]=1, [20]=1, [25]=1, [30]=1, [40]=1, [60]=1, [100]=1, [200]=1 }
local f = 0
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

emu.addEventCallback(function()
  if marks[f] then
    local w = io.open(out .. string.format("m%04d.bin", f), "wb")
    for i = 0, 8191 do w:write(string.char(emu.read(i, emu.memType.snesWorkRam))) end
    w:close()
  end
  if f >= 200 then emu.stop(0) end
end, emu.eventType.endFrame)
