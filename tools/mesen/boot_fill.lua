-- Boot: exact frame where the low WRAM ($0200+) is filled.
local out = "C:/Users/lolly/Downloads/SOM/work/mesen/tree/boot/"
local f = 0
local last = -1
local rows = {}
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

local function nzWram(base, n)
  local s = 0
  for i = 0, n - 1 do if emu.read(base + i, emu.memType.snesWorkRam) ~= 0 then s = s + 1 end end
  return s
end

emu.addEventCallback(function()
  local n = nzWram(0x0200, 0x1E00)
  if n ~= last then
    rows[#rows+1] = string.format("f=%d wram0200_nz=%d", f, n)
    last = n
  end
  if f >= 120 then
    local h = io.open(out .. "boot_fill.txt", "w")
    for i = 1, #rows do h:write(rows[i] .. "\n") end
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
