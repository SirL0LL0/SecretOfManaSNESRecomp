local out = io.open("C:/Users/lollo/Downloads/SOM/work/mesen/apuports.txt", "w")
local f = 0
local seen = {}
emu.addEventCallback(function()
  emu.setInput({ a=false, b=false, x=false, y=false, start=false, select=false,
                 up=false, down=false, left=false, right=false, l=false, r=false }, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f = f + 1
  if f >= 6800 then out:close(); emu.stop(0) end
end, emu.eventType.endFrame)
local function key(kind, addr, value)
  local s = emu.getState()
  local pc = string.format("%02X%04X", s["cpu.k"] or 0, s["cpu.pc"] or 0)
  local k = string.format("%s pc=%s %04X=%02X", kind, pc, addr & 0xFFFF, value)
  local seg = (f < 1000) and "L1" or ((f >= 5900) and "L2" or nil)
  if seg then
    local kk = seg .. " " .. k
    if not seen[kk] then seen[kk] = f; out:write(string.format("%s f=%d %s\n", seg, f, k)) end
  end
end
emu.addMemoryCallback(function(a, v) key("R", a, v) end, emu.callbackType.read, 0x2140, 0x2143)
emu.addMemoryCallback(function(a, v) key("W", a, v) end, emu.callbackType.write, 0x2140, 0x2143)
