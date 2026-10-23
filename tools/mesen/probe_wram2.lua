local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_wram2.txt", "w")
local wm = 0
local p80 = 0
local function rd(a) return emu.read(a, emu.memType.snesMemory) end
emu.addMemoryCallback(function(a, v)
  local s = emu.getState()
  log:write(string.format("W0104 f=%d line=%d addr=%04X val=%02X pc=%06X k=%02X\n",
    s.frameCount, s["ppu.scanline"], a, v, s["cpu.pc"], s["cpu.k"]))
  log:flush()
end, emu.callbackType.write, 0x0104, 0x0107, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(function(a, v)
  local s = emu.getState()
  local fr = s.frameCount
  if a == 0x2180 then
    p80 = p80 + 1
    if fr >= 3870 and fr <= 3905 and p80 < 200 then
      log:write(string.format("WMD f=%d val=%02X pc=%06X\n", fr, v, s["cpu.pc"]))
    end
  else
    wm = wm + 1
    if fr >= 3870 and fr <= 3905 and wm < 200 then
      log:write(string.format("WM f=%d addr=%04X val=%02X pc=%06X\n", fr, a, v, s["cpu.pc"]))
    end
  end
  if (wm + p80) % 200 == 0 then log:flush() end
end, emu.callbackType.write, 0x2180, 0x2183, emu.cpuType.snes, emu.memType.snesMemory)
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
  if f >= 3870 and f <= 3905 then
    local s = emu.getState()
    local parts = {}
    for i = 0, 7 do
      local d = s["dmaController.channel[" .. i .. "].destAddress"]
      local act = s["dmaController.channel[" .. i .. "].dmaActive"]
      local sz = s["dmaController.channel[" .. i .. "].transferSize"]
      if d ~= nil and d ~= 255 then parts[#parts + 1] = string.format("ch%d d=%02X sz=%d act=%s", i, d, sz or 0, tostring(act)) end
    end
    log:write(string.format("DMA f=%d %s\n", f, table.concat(parts, " ")))
  end
  if f >= 3905 then
    log:write(string.format("==== done wm=%d p80=%d ====\n", wm, p80))
    log:flush(); log:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
