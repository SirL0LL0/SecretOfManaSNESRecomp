-- The game's own frame counter over time (WRAM $0180-$01E0), the alignment key.
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/align/"
local f = 0
local rows = {}
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f % 50 == 0 then
    local s = ""
    for i = 0, 0x5F do s = s .. string.char(emu.read(0x0180 + i, emu.memType.snesWorkRam)) end
    rows[#rows+1] = string.format("%d,%s", f, s:gsub(",", " "))
  end
  if f >= 3410 then
    local h = io.open(out .. "mesen_counter.csv", "w")
    h:write("frame,bytes0180\n")
    for i = 1, #rows do h:write(rows[i] .. "\n") end
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
