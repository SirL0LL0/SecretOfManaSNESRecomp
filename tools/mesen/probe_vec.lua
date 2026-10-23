local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_vec.txt", "w")
local counts = { c1cf = 0, d5c1 = 0, c0a8 = 0, a266 = 0 }
local function rd(a) return emu.read(a, emu.memType.snesMemory) end
local function ex(name)
  counts[name] = counts[name] + 1
end
emu.addMemoryCallback(function() ex("c1cf") end, emu.callbackType.exec, 0xC1CF, 0xC1CF, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function() ex("d5c1") end, emu.callbackType.exec, 0xD5C1, 0xD5C1, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function() ex("c0a8") end, emu.callbackType.exec, 0xC0A8, 0xC0A8, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function() ex("a266") end, emu.callbackType.exec, 0x7EA266, 0x7EA266, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function(a, v)
  local s = emu.getState()
  local fr = s.frameCount
  if fr >= 3880 and fr <= 4020 then
    local op = rd(0x0104)
    local b1, b2, b3 = rd(0x0105), rd(0x0106), rd(0x0107)
    log:write(string.format("V104 f=%d line=%d op=%02X target=%02X%02X%02X v=%02X\n", fr, s["ppu.scanline"], op, b3, b2, b1, rd(0xF1)))
  end
end, emu.callbackType.exec, 0x0104, 0x0104, emu.cpuType.snes, emu.memType.snesMemory)
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
  if f >= 4100 then
    local parts = {}
    for k, v in pairs(counts) do parts[#parts + 1] = k .. "=" .. v end
    table.sort(parts)
    log:write("==== done " .. table.concat(parts, " ") .. " ====\n")
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
