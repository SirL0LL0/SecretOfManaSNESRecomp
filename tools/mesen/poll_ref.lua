local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/ref_poll.txt"
local f = 0
local h = io.open(out, "w")
local counts = {}
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f >= 2540 and f <= 2740 then
    local s = emu.getState()
    local ir = s["internalRegisters"]
    h:write(string.format("%d,%s,%s,%s\n", f,
      tostring(ir and ir.enableVerticalIrq),
      tostring(ir and ir.verticalTimer),
      tostring(ir and ir.irqFlag)))
  end
  if f >= 2740 then
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
