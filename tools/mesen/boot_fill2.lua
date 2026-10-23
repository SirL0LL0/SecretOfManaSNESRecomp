-- Boot: when does the low WRAM fill? Cheap 64-byte probes, one file per change.
local out = "C:/Users/lolly/Downloads/SOM/work/mesen/tree/boot/"
local f = 0
local last = ""
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

local function nz(base, n)
  local s = 0
  for i = 0, n - 1 do if emu.read(base + i, emu.memType.snesWorkRam) ~= 0 then s = s + 1 end end
  return s
end

emu.addEventCallback(function()
  local a = nz(0x0200, 64)
  local b = nz(0x1000, 64)
  local sig = a .. "/" .. b
  if sig ~= last then
    local h = io.open(out .. string.format("bf_%04d.txt", f), "w")
    h:write(string.format("f=%d wram0200_64=%d wram1000_64=%d\n", f, a, b))
    h:close()
    last = sig
  end
  if f >= 200 then emu.stop(0) end
end, emu.eventType.endFrame)
