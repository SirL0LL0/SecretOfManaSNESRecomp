local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local log = io.open(out .. "table_log.txt", "w")
log:write("table probe\n"); log:flush()
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 1500 then
    local function r(a) return emu.read(a, emu.memType.snesMemory) end
    log:write(string.format("420C: 00420C=%02X 420C=%02X\n", r(0x00420C), r(0x420C)))
    log:write(string.format("0104: 7E0104=%02X 000104=%02X\n", r(0x7E0104), r(0x000104)))
    for i = 0, 10 do
      log:write(string.format("DMA6 %04X=%02X\n", 0x4330 + i, r(0x004330 + i)))
    end
    local adr = r(0x004332) | (r(0x004333) << 8)
    local bank = r(0x004334)
    log:write(string.format("DMA6 table=%02X:%04X\n", bank, adr))
    local tab = (bank << 16) | adr
    for i = 0, 47 do
      log:write(string.format("T%02X=%02X\n", i, r(tab + i)))
    end
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
