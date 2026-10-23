local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_exec.txt", "w")
local hits = 0
local function rd(addr)
  return emu.read(addr, emu.memType.snesMemory)
end
local function dump(addr, n)
  local s = string.format("%04X:", addr)
  for i = 0, n - 1 do s = s .. string.format(" %02X", rd(addr + i)) end
  log:write(s .. "\n")
end
local function ex(cb, addr)
  if hits < 200 then
    local s = emu.getState()
    log:write(string.format("EXEC %s frame=%d line=%d cyc=%d f1=%02X\n",
      cb, s.frameCount, s["ppu.scanline"], s["cpu.cycleCount"], rd(0xF1)))
  end
  hits = hits + 1
end
emu.addMemoryCallback(function(a, v) ex("D5C1", a) end, emu.callbackType.exec, 0xD5C1, 0xD5C1, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function(a, v) ex("0104", a) end, emu.callbackType.exec, 0x0104, 0x0104, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function(a, v) ex("C1CF", a) end, emu.callbackType.exec, 0xC1CF, 0xC1CF, emu.cpuType.snes, emu.memType.snesMemory)

emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 3000 and f <= 8000 then
    if f % 240 == 0 then b.start = true end
    if f % 240 == 120 then b.b = true end
  end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 3900 or f == 4000 then
    log:write("==== frame " .. f .. " ====\n")
    dump(0x0100, 0x20)
    dump(0xD5C1, 0x20)
    log:flush()
  end
  if f >= 4100 then
    log:write("==== done hits=" .. hits .. " ====\n")
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
