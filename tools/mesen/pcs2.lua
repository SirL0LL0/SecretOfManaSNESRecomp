local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/ref_pcs2.txt"
local f = 0
local last = -1
local h = io.open(out, "w")
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f >= 2595 and f <= 2615 then
    local s = emu.getState()
    local pc = s["cpu.pc"]
    local k = s["cpu.k"]
    if pc and pc ~= last then
      h:write(string.format("f=%d k=%02X pc=%04X\n", f, k or 0, pc))
      last = pc
    end
  end
  if f >= 2615 then
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
