-- Fine-grained boot timeline: when does WRAM $E700 fill up?
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/boot/"
local f = 0
local rows = {}
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

local function nz(bt, base, n)
  local s = 0
  for i = 0, n - 1 do if bt(base + i) ~= 0 then s = s + 1 end end
  return s
end

emu.addEventCallback(function()
  if f <= 300 and (f % 5 == 0 or f <= 30) then
    rows[#rows+1] = string.format("%d,%d,%d,%d", f,
      nz(emu.memType.snesWorkRam, 0xE700, 0x1900),
      nz(emu.memType.snesWorkRam, 0x4A00, 0x3600),
      nz(emu.memType.snesVideoRam, 0xE000, 0x2000))
  end
  if f >= 300 then
    local h = io.open(out .. "boot_timeline.csv", "w")
    h:write("frame,wramE700_nz,wram4A00_nz,vramE000_nz\n")
    for i = 1, #rows do h:write(rows[i] .. "\n") end
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
