local out = "C:/Users/lollo/Downloads/SOM/work/mesen/exact/"
local f = 0
local log = io.open(out .. "banks.txt", "w")
local function rd(a) return emu.read(a, emu.memType.snesDebug) end
local function t(base)
  return string.format("%02X%02X%02X%02X", rd(base+3), rd(base+2), rd(base+1), rd(base))
end
local seq = { {900,4,"start"}, {2004,4,"b"}, {2308,4,"right"}, {2512,4,"b"}, {2716,4,"start"} }
local show = { [0]=true,[1]=true,[18]=true,[19]=true,[20]=true,[100]=true,[963]=true,[2725]=true,[2735]=true,[3241]=true,[3300]=true,[3358]=true,[3359]=true,[3360]=true,[3400]=true,[3600]=true,[3625]=true,[3700]=true,[3753]=true,[3900]=true,[4000]=true,[4292]=true,[4300]=true }
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  for _, p in ipairs(seq) do
    if f >= p[1] and f < p[1] + p[2] then b[p[3]] = true end
  end
  emu.setInput(b, 0)
  local s = emu.getState()
  if show[f] then
    log:write(string.format("f=%d ps=%02X k=%02X pc=%06X dbr=%02X irqsrc=%s\n",
      f, s["cpu.ps"] or 0, s["cpu.k"] or 0, s["cpu.pc"] or 0, s["cpu.dbr"] or 0,
      tostring(s["cpu.irqSource"])))
    log:write("  low  " .. t(0x000104) .. "\n")
    log:write("  7E   " .. t(0x7E0104) .. "\n")
    log:write("  7F   " .. t(0x7F0104) .. "\n")
    log:write("  ppu  mode=" .. tostring(s["ppu.bgMode"]) .. " tm=" .. string.format("%02X", s["ppu.mainScreenLayers"] or 0) .. " line=" .. tostring(s["ppu.scanline"]) .. "\n")
    log:flush()
  end
  if f >= 4300 then log:close(); emu.stop(0) end
end, emu.eventType.inputPolled)
