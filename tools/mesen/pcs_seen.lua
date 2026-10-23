local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/ref_pcs.txt"
local f = 0
local seen = {}
local h = io.open(out, "w")
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f >= 2540 and f <= 2700 then
    local s = emu.getState()
    local pc = s["cpu.pc"]
    if pc and not seen[pc] then
      seen[pc] = true
      h:write(string.format("f=%d pc=%06X\n", f, pc))
    end
  end
  if f >= 2700 then
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
