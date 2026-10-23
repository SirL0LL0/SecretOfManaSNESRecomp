local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_i.txt", "w")
local irq = 0
local win = 0
local function rd(a) return emu.read(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function()
  irq = irq + 1
end, emu.callbackType.exec, 0x0104, 0x0104, emu.cpuType.snes, emu.memType.snesMemory)
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 3000 and f <= 8000 then
    if f % 240 == 0 then b.start = true end
    if f % 240 == 120 then b.b = true end
  end
  emu.setInput(b, 0)
  if f % 100 == 0 then
    local s = emu.getState()
    local t = string.format("%02X%02X%02X%02X", rd(0x7E0107), rd(0x7E0106), rd(0x7E0105), rd(0x7E0104))
    log:write(string.format("f=%d irq100=%d ps=%02X I=%d tramp=%s\n", f, irq - win, s["cpu.ps"], (s["cpu.ps"] & 4) ~= 0 and 1 or 0, t))
    log:flush()
    win = irq
  end
  if f >= 4100 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
