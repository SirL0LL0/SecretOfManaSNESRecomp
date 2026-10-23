local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tv/wfppu.txt"
local f = 0
local presses = { {2500, "start"}, {2804, "b"}, {3200, "b"}, {3400, "start"}, {3700, "b"}, {3800, "start"} }
local log = io.open(out, "w")
emu.addEventCallback(function()
  local inp = { a=false, b=false, x=false, y=false, start=false, select=false,
                up=false, down=false, left=false, right=false, l=false, r=false }
  for _, p in ipairs(presses) do
    if f >= p[1] and f < p[1] + 4 then inp[p[2]] = true end
  end
  if f >= 8000 and f < 11000 and (f % 60) < 4 then inp.b = true end
  emu.setInput(inp, 0)
end, emu.eventType.inputPolled)
local watch = { [0x420C]=1, [0x2105]=1, [0x212C]=1, [0x212D]=1, [0x2130]=1, [0x2131]=1, [0x2132]=1,
                [0x210F]=1, [0x2110]=1, [0x2111]=1, [0x2112]=1, [0x2107]=1, [0x2108]=1, [0x2109]=1 }
emu.addMemoryCallback(function(addr, value)
  if f == 10801 and watch[addr] then
    local s = emu.getState()
    log:write(string.format("%d %04X %02X pc=%02X:%04X\n", f, addr, value, s["cpu.k"], s["cpu.pc"]))
  end
end, emu.callbackType.write, 0x2100, 0x420C)
emu.addMemoryCallback(function(addr, value)
  if f == 10801 then
    log:write(string.format("%d %04X %02X dma\n", f, addr, value))
  end
end, emu.callbackType.write, 0x4300, 0x437F)
local function rd(a) return emu.read(a, emu.memType.snesWorkRam) end
emu.addEventCallback(function()
  f = f + 1
  if f == 10801 then log:write(string.format("WRAM 2C=%02X 29=%02X EC=%02X\n", rd(0x2C), rd(0x29), rd(0xEC))) end
  if f >= 10802 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
