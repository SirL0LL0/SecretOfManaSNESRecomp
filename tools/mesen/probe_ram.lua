local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_ram.txt", "w")
local function dump(addr, n)
  local s = string.format("%04X:", addr)
  for i = 0, n - 1 do
    local b = emu.read(addr + i, emu.memType.snesMemory)
    s = s .. string.format(" %02X", b)
  end
  log:write(s .. "\n")
end
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 3000 and f <= 8000 then
    if f % 240 == 0 then b.start = true end
    if f % 240 == 120 then b.b = true end
  end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 3900 or f == 4000 or f == 5000 then
    log:write("==== frame " .. f .. " ====\n")
    dump(0x0000, 0x40)
    dump(0x0100, 0x40)
    dump(0x0200, 0x20)
    dump(0x00F0, 0x20)
    log:flush()
  end
  if f >= 5000 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
