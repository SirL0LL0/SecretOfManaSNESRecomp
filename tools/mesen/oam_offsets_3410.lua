local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local done = false
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 3410 and not done then
    done = true
    local s = emu.getState()
    local h = io.open(out .. "ref_oam_offsets_3410.txt", "w")
    h:write(string.format("oamAddressOffset=%s\n", tostring(s["ppu.oamAddressOffset"])))
    for _, base in ipairs({0, 544, 1024, 2048, 4096, 8192, 12288}) do
      local nz, vis = 0, 0
      for i = 0, 543 do
        local v = emu.read(base + i, emu.memType.snesSpriteRam)
        if v ~= 0 then nz = nz + 1 end
        if (i % 4) == 1 and v ~= 0xF0 and v < 0xE0 then vis = vis + 1 end
      end
      h:write(string.format("base=%d nonzero=%d visibleY=%d\n", base, nz, vis))
    end
    h:close()
  end
  if f >= 3410 then emu.stop(0) end
end, emu.eventType.endFrame)
