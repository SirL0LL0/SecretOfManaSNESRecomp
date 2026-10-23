-- diagnostic: does the endFrame callback see the same frame counter?
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/boot/"
local f = 0
local rows = {}
local calls = 0
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

emu.addEventCallback(function()
  calls = calls + 1
  if calls <= 20 then
    rows[#rows+1] = string.format("call=%d f=%d e700=%d", calls, f,
      (function()
         local s = 0
         for i = 0, 255 do if emu.read(0xE700 + i, emu.memType.snesWorkRam) ~= 0 then s = s + 1 end end
         return s
       end)())
  end
  if calls >= 20 then
    local h = io.open(out .. "boot_diag.txt", "w")
    h:write("calls=" .. calls .. " f=" .. f .. " rows=" .. #rows .. "\n")
    for i = 1, #rows do h:write(rows[i] .. "\n") end
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
