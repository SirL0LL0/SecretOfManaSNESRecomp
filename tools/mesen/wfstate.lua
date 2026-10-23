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
    local s = emu.getState()
    local h = io.open("C:/Users/lollo/Downloads/SOM/work/mesen/tv/wfstate.txt", "w")
    local keys = {}
    for k, v in pairs(s) do if string.find(k, "^snes.ppu") or string.find(k, "^ppu") then table.insert(keys, k) end end
    table.sort(keys)
    for _, k in ipairs(keys) do h:write(k .. "=" .. tostring(s[k]) .. "\n") end
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)

