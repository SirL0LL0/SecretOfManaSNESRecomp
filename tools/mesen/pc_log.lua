local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/ref_pc_log.csv"
local f = 0
local h = io.open(out, "w")
h:write("frame,pc,k,sp,irqFlag,enableVerticalIrq\n")
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f >= 2545 and f <= 2640 then
    local s = emu.getState()
    h:write(string.format("%d,%s,%s,%s,%s,%s\n", f,
      tostring(s["cpu.pc"]), tostring(s["cpu.k"]), tostring(s["cpu.sp"]),
      tostring(s["internalRegisters.irqFlag"]),
      tostring(s["internalRegisters.enableVerticalIrq"])))
  end
  if f >= 2640 then
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
