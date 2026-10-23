local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local log = io.open(out .. "state_log2.txt", "w")
log:write("tree state log 2\n"); log:flush()
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  local s = emu.getState()
  if f >= 1498 and f <= 1502 then
    log:write(string.format("STATE f=%d bg=%s tm=%02X\n", f, tostring(s["ppu.bgMode"]), s["ppu.mainScreenLayers"] or 0))
    for i = 0, 3 do
      log:write(string.format("  BG%d h=%d v=%d map=%04X\n", i + 1,
        s["ppu.layers[" .. i .. "].hscroll"] or -1,
        s["ppu.layers[" .. i .. "].vscroll"] or -1,
        s["ppu.layers[" .. i .. "].tilemapAddress"] or 0))
    end
    log:flush()
  end
  if f >= 1502 then log:write("DONE\n"); log:flush(); log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
