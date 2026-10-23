local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local targets = { [2100]=true, [2200]=true, [2300]=true, [2400]=true, [2500]=true, [2600]=true, [2800]=true, [3000]=true, [3500]=true, [4000]=true }
local log = io.open(out .. "ref_scroll_log.txt", "w")
log:write("frame scanline bgmode main sub bright vscroll0 hscroll0 vscroll1 hscroll1 m7v m7h\n"); log:flush()
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if targets[f] then
    local s = emu.getState()
    log:write(string.format("%d %s %s %s %s %s %s %s %s %s %s %s\n", f,
      tostring(s["ppu.scanline"]), tostring(s["ppu.bgMode"]), tostring(s["ppu.mainScreenLayers"]),
      tostring(s["ppu.subScreenLayers"]), tostring(s["ppu.screenBrightness"]),
      tostring(s["ppu.layers[0].vscroll"]), tostring(s["ppu.layers[0].hscroll"]),
      tostring(s["ppu.layers[1].vscroll"]), tostring(s["ppu.layers[1].hscroll"]),
      tostring(s["ppu.mode7.vscroll"]), tostring(s["ppu.mode7.hscroll"])))
    log:flush()
  end
  if f >= 4000 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
