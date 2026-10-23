local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local targets = {}
for i = 1400, 2600, 100 do targets[i] = true end
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if targets[f] then
    local h = io.open(string.format("%srefscan_wram_%d.bin", out, f), "wb")
    for i = 0, 0x1FFFF do h:write(string.char(emu.read(i, emu.memType.snesWorkRam))) end
    h:close()
  end
  if f >= 2600 then emu.stop(0) end
end, emu.eventType.endFrame)
