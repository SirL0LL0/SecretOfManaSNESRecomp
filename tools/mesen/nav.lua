local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local shotDir = out .. "nav/"
local f = 0

local regLog = io.open(out .. "nav_regwrites.tsv", "w")
regLog:write("frame\tscanline\tcycle\taddr\tvalue\n")
local digest = io.open(out .. "nav_digest.tsv", "w")
digest:write("frame\temuFrame\tbgMode\tbg3pri\thiRes\tinterlace\toverscan\tscanline\tmainLayers\tsubLayers\tcolorMath\tbrightness\tforceBlank\th0\tv0\th1\tv1\th2\tv2\th3\tv3\ttm0\ttm1\ttm2\ttm3\n")

local function G(s, k) return s["ppu." .. k] end
local function L(s, i, k) return s["ppu.layers[" .. i .. "]." .. k] end
local function H(v) return string.format("%02X", v or 0) end
local function W(v) return string.format("%04X", v or 0) end
local function stateLine()
  local s = emu.getState()
  local v = {}
  local function add(x) v[#v + 1] = tostring(x) end
  add(s.frameCount); add(G(s,"bgMode")); add(G(s,"mode1Bg3Priority") and 1 or 0)
  add(G(s,"hiResMode") and 1 or 0); add(G(s,"screenInterlace") and 1 or 0); add(G(s,"overscanMode") and 1 or 0)
  add(G(s,"scanline")); add(H(G(s,"mainScreenLayers"))); add(H(G(s,"subScreenLayers"))); add(H(G(s,"colorMathEnabled")))
  add(G(s,"screenBrightness")); add(G(s,"forcedBlank") and 1 or 0)
  for i = 0, 3 do add(L(s,i,"hscroll")); add(L(s,i,"vscroll")) end
  for i = 0, 3 do add(W(L(s,i,"tilemapAddress"))) end
  return table.concat(v, "\t")
end

local function shot(tag)
  local png = emu.takeScreenshot()
  local h = io.open(shotDir .. "n_" .. tag .. ".png", "wb")
  if h then h:write(png); h:close() end
end

emu.addEventCallback(function()
  f = f + 1
  digest:write(string.format("%d\t", f) .. stateLine() .. "\n")
  if f >= 3000 and f <= 9500 and f % 100 == 0 then shot(string.format("%04d", f)) end
  if f % 200 == 0 then digest:flush(); regLog:flush() end
  if f >= 9500 then digest:flush(); regLog:flush(); digest:close(); regLog:close(); emu.stop(0) end
end, emu.eventType.endFrame)

emu.addEventCallback(function()
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 3000 and f <= 8000 then
    if f % 240 == 0 then b.start = true end
    if f % 240 == 120 then b.b = true end
  end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

local function regcb(addr, value)
  local s = emu.getState()
  regLog:write(string.format("%d\t%d\t%d\t%04X\t%02X\n", s.frameCount, G(s,"scanline"), s["cpu.cycleCount"], addr, value))
end
emu.addMemoryCallback(regcb, emu.callbackType.write, 0x2100, 0x2100, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(regcb, emu.callbackType.write, 0x2105, 0x2105, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(regcb, emu.callbackType.write, 0x210D, 0x2114, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(regcb, emu.callbackType.write, 0x212C, 0x2133, emu.cpuType.snes, emu.memType.snesMemory)
