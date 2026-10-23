local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local done = {}
local frames = { [2600]=true, [2601]=true, [2602]=true, [2603]=true, [2605]=true }
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  if f >= 3105 and f < 3109 then b.start = true end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if frames[f] and not done[f] then
    done[f] = true
    local h = io.open(string.format("%sref_wram_%d.bin", out, f), "wb")
    for i = 0, 0x1FFFF do h:write(string.char(emu.read(i, emu.memType.snesWorkRam))) end
    h:close()
    local o = io.open(string.format("%sref_oam_%d.bin", out, f), "wb")
    for i = 0, 543 do o:write(string.char(emu.read(i, emu.memType.snesSpriteRam))) end
    o:close()
  end
  if f >= 2605 then emu.stop(0) end
end, emu.eventType.endFrame)
