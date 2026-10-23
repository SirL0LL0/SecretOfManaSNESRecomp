local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tv/wfvram.bin"
local f = 0
local presses = { {2500, "start"}, {2804, "b"}, {3200, "b"}, {3400, "start"}, {3700, "b"}, {3800, "start"} }

emu.addEventCallback(function()
  local inp = { a=false, b=false, x=false, y=false, start=false, select=false,
                up=false, down=false, left=false, right=false, l=false, r=false }
  for _, p in ipairs(presses) do
    if f >= p[1] and f < p[1] + 4 then inp[p[2]] = true end
  end
  if f >= 8000 and f < 11000 and (f % 60) < 4 then inp.b = true end
  emu.setInput(inp, 0)
end, emu.eventType.inputPolled)
local function rd(a) return emu.read(a, emu.memType.snesWorkRam) end
emu.addEventCallback(function()
  f = f + 1
  if f == 10801 then
    local h = io.open(out, "wb")
    for a = 0, 0xFFFF do h:write(string.char(emu.read(a, emu.memType.snesVideoRam))) end
    h:close()
    local w = io.open("C:/Users/lollo/Downloads/SOM/work/mesen/tv/wfwram.bin", "wb")
    for a = 0, 0x1FFFF do w:write(string.char(emu.read(a, emu.memType.snesWorkRam))) end
    w:close()
    local c = io.open("C:/Users/lollo/Downloads/SOM/work/mesen/tv/wfcgram.bin", "wb")
    for a = 0, 0x1FF do c:write(string.char(emu.read(a, emu.memType.snesCgRam))) end
    c:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
