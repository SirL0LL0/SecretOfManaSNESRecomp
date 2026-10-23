-- Mesen2 investigation: T-It prologue bottom area (v3, flat state keys)
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local shotDir = out .. "shots/"

local f = 0
local shotEvery = {}
for i = 3500, 3720, 4 do shotEvery[i] = true end
for i = 3600, 3660, 1 do shotEvery[i] = true end
for i = 3990, 4010, 2 do shotEvery[i] = true end
for i = 4490, 4510, 2 do shotEvery[i] = true end
for i = 4990, 5010, 2 do shotEvery[i] = true end
for _, i in ipairs({1000, 1990, 2100, 2500, 2800, 3100, 3400}) do shotEvery[i] = true end

local regLog = io.open(out .. "regwrites.tsv", "w")
regLog:write("frame\tscanline\tcycle\taddr\tvalue\n")

local irqLog = io.open(out .. "irq.tsv", "w")
irqLog:write("frame\tscanline\tcycle\n")

local digest = io.open(out .. "digest.tsv", "w")
digest:write("frame\temuFrame\tbgMode\tbg3pri\thiRes\tinterlace\toverscan\tscanline\tmainLayers\tsubLayers\tcolorMath\tbrightness\tforceBlank\th0\tv0\th1\tv1\th2\tv2\th3\tv3\ttm0\ttm1\ttm2\ttm3\n")

local function G(s, k) return s["ppu." .. k] end
local function L(s, i, k) return s["ppu.layers[" .. i .. "]." .. k] end

local function H(v) return string.format("%02X", v or 0) end
local function W(v) return string.format("%04X", v or 0) end

local function stateLine()
  local s = emu.getState()
  local v = {}
  local function add(x) v[#v + 1] = tostring(x) end
  add(s.frameCount)
  add(G(s, "bgMode"))
  add(G(s, "mode1Bg3Priority") and 1 or 0)
  add(G(s, "hiResMode") and 1 or 0)
  add(G(s, "screenInterlace") and 1 or 0)
  add(G(s, "overscanMode") and 1 or 0)
  add(G(s, "scanline"))
  add(H(G(s, "mainScreenLayers")))
  add(H(G(s, "subScreenLayers")))
  add(H(G(s, "colorMathEnabled")))
  add(G(s, "screenBrightness"))
  add(G(s, "forcedBlank") and 1 or 0)
  for i = 0, 3 do add(L(s, i, "hscroll")); add(L(s, i, "vscroll")) end
  for i = 0, 3 do add(W(L(s, i, "tilemapAddress"))) end
  return table.concat(v, "\t")
end

local function shot(tag)
  local png = emu.takeScreenshot()
  local h = io.open(shotDir .. "shot_" .. tag .. ".png", "wb")
  if h then h:write(png); h:close() end
end

local function dumpBytes(name, mt, startAddr, len)
  local h = io.open(out .. name, "wb")
  local t = {}
  for i = 0, len - 1 do t[#t + 1] = string.char(emu.read(startAddr + i, mt)) end
  h:write(table.concat(t)); h:close()
end

local function dumpInfo(tag)
  local h = io.open(out .. "info_" .. tag .. ".txt", "w")
  local s = emu.getState()
  h:write(stateLine() .. "\n")
  h:write(string.format("colorMath: addSub=%d halve=%d sub=%d fixed=%d\n",
    G(s, "colorMathAddSubscreen") and 1 or 0, G(s, "colorMathHalveResult") and 1 or 0,
    G(s, "colorMathSubtractMode") and 1 or 0, G(s, "fixedColor")))
  h:write(string.format("layerSizes: dw=%d/%d/%d/%d dh=%d/%d/%d/%d large=%d/%d/%d/%d chr=%04X/%04X/%04X/%04X\n",
    L(s,0,"doubleWidth") and 1 or 0, L(s,1,"doubleWidth") and 1 or 0, L(s,2,"doubleWidth") and 1 or 0, L(s,3,"doubleWidth") and 1 or 0,
    L(s,0,"doubleHeight") and 1 or 0, L(s,1,"doubleHeight") and 1 or 0, L(s,2,"doubleHeight") and 1 or 0, L(s,3,"doubleHeight") and 1 or 0,
    L(s,0,"largeTiles") and 1 or 0, L(s,1,"largeTiles") and 1 or 0, L(s,2,"largeTiles") and 1 or 0, L(s,3,"largeTiles") and 1 or 0,
    L(s,0,"chrAddress"), L(s,1,"chrAddress"), L(s,2,"chrAddress"), L(s,3,"chrAddress")))
  h:close()
  dumpBytes("cgram_" .. tag .. ".bin", emu.memType.snesCgRam, 0, 512)
  dumpBytes("vram_" .. tag .. ".bin", emu.memType.snesVideoRam, 0, 65536)
  dumpBytes("oam_" .. tag .. ".bin", emu.memType.snesSpriteRam, 0, 544)
  dumpBytes("wram_" .. tag .. ".bin", emu.memType.snesWorkRam, 0, 131072)
end

local function onFrame()
  f = f + 1
  digest:write(string.format("%d\t", f) .. stateLine() .. "\n")
  if shotEvery[f] then shot(string.format("%04d", f)) end
  if f == 3620 or f == 3700 or f == 4000 or f == 4500 or f == 5000 then
    dumpInfo(string.format("%04d", f))
  end
  if f % 100 == 0 then digest:flush(); regLog:flush(); irqLog:flush() end
  if f >= 5050 then
    digest:flush(); regLog:flush(); irqLog:flush()
    digest:close(); regLog:close(); irqLog:close()
    emu.stop(0)
  end
end

local function onInput()
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 900 and f < 904 then b.start = true end
  if f >= 2004 and f < 2008 then b.b = true end
  if f >= 2308 and f < 2312 then b.right = true end
  if f >= 2512 and f < 2516 then b.b = true end
  if f >= 2716 and f < 2720 then b.start = true end
  emu.setInput(b, 0)
end

emu.addEventCallback(onFrame, emu.eventType.endFrame)
emu.addEventCallback(onInput, emu.eventType.inputPolled)

emu.addEventCallback(function()
  local s = emu.getState()
  if s.frameCount >= 2000 then
    irqLog:write(string.format("%d\t%d\t%d\n", s.frameCount, G(s, "scanline"), s["cpu.cycleCount"]))
  end
end, emu.eventType.irq)

local function regcb(addr, value)
  local s = emu.getState()
  if s.frameCount >= 2000 then
    regLog:write(string.format("%d\t%d\t%d\t%04X\t%02X\n", s.frameCount, G(s, "scanline"), s["cpu.cycleCount"], addr, value))
  end
end
emu.addMemoryCallback(regcb, emu.callbackType.write, 0x2100, 0x2100, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(regcb, emu.callbackType.write, 0x2105, 0x2105, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(regcb, emu.callbackType.write, 0x210D, 0x2114, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(regcb, emu.callbackType.write, 0x212C, 0x2133, emu.cpuType.snes, emu.memType.snesMemory)

local m = io.open(out .. "started2.txt", "w")
m:write("script started\n")
m:close()
