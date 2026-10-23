local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local log = io.open(out .. "state_log.txt", "w")
log:write("tree state log\n"); log:flush()

emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

emu.addEventCallback(function()
  local s = emu.getState()
  if f == 1400 or f == 1450 or f == 1500 then
    log:write(string.format("STATE f=%d bg=%s tm=%02X hires=%s interlace=%s\n", f,
      tostring(s["ppu.bgMode"]), s["ppu.mainScreenLayers"] or 0,
      tostring(s["ppu.hiResMode"]), tostring(s["ppu.screenInterlace"])))
    for i = 0, 3 do
      log:write(string.format("  BG%d h=%d v=%d map=%04X\n", i + 1,
        s["ppu.layers[" .. i .. "].hscroll"] or -1,
        s["ppu.layers[" .. i .. "].vscroll"] or -1,
        s["ppu.layers[" .. i .. "].tilemapAddress"] or 0))
    end
    log:flush()
  end
  if f >= 1500 then log:write("DONE\n"); log:flush(); log:close(); emu.stop(0) end
end, emu.eventType.endFrame)

local function regcb(addr, value)
  local s = emu.getState()
  if f >= 1400 and f <= 1500 then
    log:write(string.format("W%04X f=%d scan=%d v=%02X\n", addr, f, s["ppu.scanline"] or -1, value))
    log:flush()
  end
end
for _, a in ipairs({0x210E,0x210F,0x2110,0x2111,0x2115,0x212C,0x420C}) do
  emu.addMemoryCallback(regcb, emu.callbackType.write, a, a, emu.cpuType.snes, emu.memType.snesMemory)
end
