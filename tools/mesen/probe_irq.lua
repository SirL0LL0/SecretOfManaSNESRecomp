local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_irq.txt", "w")
local counts = { c1cf = 0, c1d7 = 0, c1da = 0, c1e1 = 0, v104 = 0, tm = 0, mode = 0 }
local samples = 0
local function rd(addr) return emu.read(addr, emu.memType.snesMemory) end
local function ex(name)
  counts[name] = counts[name] + 1
  if samples < 40 then
    local s = emu.getState()
    log:write(string.format("EXEC %s frame=%d line=%d cyc=%d v=%02X\n",
      name, s.frameCount, s["ppu.scanline"], s["cpu.cycleCount"], rd(0xF1)))
    samples = samples + 1
  end
end
emu.addMemoryCallback(function() ex("c1cf") end, emu.callbackType.exec, 0xC1CF, 0xC1CF, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function() ex("c1d7") end, emu.callbackType.exec, 0xC1D7, 0xC1D7, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function() ex("c1da") end, emu.callbackType.exec, 0xC1DA, 0xC1DA, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function() ex("c1e1") end, emu.callbackType.exec, 0xC1E1, 0xC1E1, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function() ex("v104") end, emu.callbackType.exec, 0x0104, 0x0104, emu.cpuType.snes, emu.memType.snesMemory)
local function wr(name, a, v)
  counts[name] = counts[name] + 1
  if f >= 3800 and f <= 4020 then
    local s = emu.getState()
    log:write(string.format("WR %s frame=%d line=%d cyc=%d val=%02X\n", name, s.frameCount, s["ppu.scanline"], s["cpu.cycleCount"], v))
  end
end
emu.addMemoryCallback(function(a, v) wr("tm", a, v) end, emu.callbackType.write, 0x212C, 0x212C, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function(a, v) wr("mode", a, v) end, emu.callbackType.write, 0x2105, 0x2105, emu.cpuType.snes, emu.memType.snesMemory)
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
    local s = string.format("C1CF:")
    for i = 0, 23 do s = s .. string.format(" %02X", rd(0xC1CF + i)) end
    log:write(s .. "\n")
    log:flush()
  end
  if f >= 4100 then
    local parts = {}
    for k, v in pairs(counts) do parts[#parts + 1] = k .. "=" .. v end
    table.sort(parts)
    log:write("==== done " .. table.concat(parts, " ") .. " ====\n")
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
