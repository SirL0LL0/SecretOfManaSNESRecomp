local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local log = io.open(out .. "table_log2.txt", "w")
log:write("table probe 2\n"); log:flush()
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 1500 then
    local function rd(a, t) return emu.read(a, t or emu.memType.snesMemory) end
    log:write(string.format("420C snes=%02X debug=%02X 7E0104=%02X\n",
      rd(0x00420C), rd(0x00420C, emu.memType.snesDebug), rd(0x7E0104)))
    for i = 0, 10 do
      log:write(string.format("DMA6 %04X mem=%02X dbg=%02X\n", 0x4330 + i,
        rd(0x004330 + i), rd(0x004330 + i, emu.memType.snesDebug)))
    end
    for i = 0, 47 do
      log:write(string.format("T%02X=%02X\n", i, rd(0x7F0056 + i)))
    end
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
