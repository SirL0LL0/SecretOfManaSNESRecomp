local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_osc.txt", "w")
local function rd(a) return emu.read(a, emu.memType.snesMemory) end
local function tramp()
  return string.format("%02X%02X%02X%02X", rd(0x7E0107), rd(0x7E0106), rd(0x7E0105), rd(0x7E0104))
end
local function nmitramp()
  return string.format("%02X%02X%02X%02X", rd(0x7E0103), rd(0x7E0102), rd(0x7E0101), rd(0x7E0100))
end
local hits = 0
emu.addMemoryCallback(function()
  if f >= 3890 and f <= 3905 and hits < 30 then
    log:write(string.format("EXEC0104 f=%d tramp=%s nmi=%s\n", f, tramp(), nmitramp()))
    hits = hits + 1
    log:flush()
  end
end, emu.callbackType.exec, 0x0104, 0x0104, emu.cpuType.snes, emu.memType.snesMemory)
emu.addEventCallback(function()
  f = f + 1
  if f >= 3890 and f <= 3905 then
    log:write(string.format("INPUT f=%d tramp=%s\n", f, tramp()))
    log:flush()
  end
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 3000 and f <= 8000 then
    if f % 240 == 0 then b.start = true end
    if f % 240 == 120 then b.b = true end
  end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f >= 3890 and f <= 3905 then
    log:write(string.format("END f=%d tramp=%s\n", f, tramp()))
    log:flush()
  end
  if f >= 3905 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
