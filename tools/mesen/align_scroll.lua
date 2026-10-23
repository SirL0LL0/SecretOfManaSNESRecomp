-- Reference scroll timeline with the same input as the recomp run (Start at 2500).
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/align/"
local f = 0
local log = io.open(out .. "mesen_scroll.csv", "w")
log:write("frame,vscroll0,hscroll0,vscroll1,hscroll1,m7v,m7h,bgmode\n")
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f >= 2000 and f <= 3000 and f % 25 == 0 then
    local s = emu.getState()
    log:write(string.format("%d,%s,%s,%s,%s,%s,%s,%s\n", f,
      tostring(s["ppu.layers[0].vscroll"]), tostring(s["ppu.layers[0].hscroll"]),
      tostring(s["ppu.layers[1].vscroll"]), tostring(s["ppu.layers[1].hscroll"]),
      tostring(s["ppu.mode7.vscroll"]), tostring(s["ppu.mode7.hscroll"]),
      tostring(s["ppu.bgMode"])))
    log:flush()
  end
  if f >= 3000 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
