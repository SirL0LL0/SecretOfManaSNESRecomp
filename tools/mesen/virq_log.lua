local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/ref_virq_log.csv"
local f = 0
local h = io.open(out, "w")
h:write("frame,enableVerticalIrq,verticalTimer,irqFlag,needIrq,irqSource,prevIrqSource,irqLock\n")
local function g(s, k)
  local v = s[k]
  if v == nil then return "nil" end
  return tostring(v)
end
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  if f >= 3105 and f < 3109 then b.start = true end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f >= 2400 and f <= 3500 then
    local s = emu.getState()
    h:write(string.format("%d,%s,%s,%s,%s,%s,%s,%s\n",
      f,
      g(s, "internalRegisters.enableVerticalIrq"),
      g(s, "internalRegisters.verticalTimer"),
      g(s, "internalRegisters.irqFlag"),
      g(s, "internalRegisters.needIrq"),
      g(s, "cpu.irqSource"),
      g(s, "cpu.prevIrqSource"),
      g(s, "cpu.irqLock")))
    if f % 200 == 0 then h:flush() end
  end
  if f >= 3500 then
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
