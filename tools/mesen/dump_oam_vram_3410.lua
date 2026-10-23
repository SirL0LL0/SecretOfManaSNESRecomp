local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local targets = { [2500]=true, [3410]=true }
local done = {}
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if targets[f] and not done[f] then
    done[f] = true
    local function dump(name, mt, n)
      local h = io.open(string.format("%sref_%s_%d.bin", out, name, f), "wb")
      for i = 0, n - 1 do h:write(string.char(emu.read(i, mt))) end
      h:close()
    end
    dump("oam", emu.memType.snesSpriteRam, 544)
    dump("vram", emu.memType.snesVideoRam, 65536)
    dump("cgram", emu.memType.snesCgRam, 512)
  end
  if f >= 3410 then emu.stop(0) end
end, emu.eventType.endFrame)
