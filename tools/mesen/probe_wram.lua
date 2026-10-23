local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_wram.txt", "w")
local function rd(a) return emu.read(a, emu.memType.snesMemory) end
local function dump(tag, base)
  local s = string.format("%s %06X:", tag, base)
  for i = 0, 15 do s = s .. string.format(" %02X", rd(base + i)) end
  return s
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
  if f == 3900 or f == 4000 or f == 4100 then
    log:write("f=" .. f .. "\n")
    log:write(dump("B0", 0x0100) .. "\n")
    log:write(dump("B7E", 0x7E0100) .. "\n")
    log:write(dump("B7E-A266", 0x7EA250) .. "\n")
    log:flush()
  end
  if f >= 4100 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
