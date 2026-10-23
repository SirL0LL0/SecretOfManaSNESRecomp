local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/ref_irq_oam.csv"
local f = 0
local h = io.open(out, "w")
h:write("frame,enableVerticalIrq,verticalTimer,irqFlag,needIrq,oamNonF0\n")
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
  if f >= 2300 and f <= 3600 then
    local s = emu.getState()
    local n = 0
    for i = 0, 543 do
      local v = emu.read(i, emu.memType.snesSpriteRam)
      if v ~= 0xF0 and v ~= 0x00 then n = n + 1 end
    end
    h:write(string.format("%d,%s,%s,%s,%s,%d\n",
      f,
      g(s, "internalRegisters.enableVerticalIrq"),
      g(s, "internalRegisters.verticalTimer"),
      g(s, "internalRegisters.irqFlag"),
      g(s, "internalRegisters.needIrq"),
      n))
    if f % 200 == 0 then h:flush() end
  end
  if f >= 3600 then
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
