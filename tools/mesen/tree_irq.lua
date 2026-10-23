local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local irq_count = 0
local log = io.open(out .. "irq_log.txt", "w")
log:write("frame irq_count scanline pc\n"); log:flush()

emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

emu.addEventCallback(function(cpu)
  irq_count = irq_count + 1
  local s = emu.getState()
  if f >= 900 and f <= 2500 then
    log:write(string.format("%d irq scan=%s pc=%04X k=%02X\n", f,
      tostring(s["ppu.scanline"]), s["cpu.pc"] or 0, s["cpu.k"] or 0))
    log:flush()
  end
end, emu.eventType.irq)

emu.addEventCallback(function()
  if f >= 900 and f <= 2500 then
    log:write(string.format("%d count=%d\n", f, irq_count))
    log:flush()
  end
  irq_count = 0
  if f >= 2500 then log:write("DONE\n"); log:flush(); log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
