local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 1500 then
    local h = io.open(out .. "ref_wram_1500_end.bin", "wb")
    local chunk = {}
    for i = 0, 131071 do
      chunk[#chunk + 1] = string.char(emu.read(0x7E0000 + i, emu.memType.snesMemory))
      if #chunk >= 4096 then h:write(table.concat(chunk)); chunk = {} end
    end
    if #chunk > 0 then h:write(table.concat(chunk)) end
    h:close()
    local l = io.open(out .. "wram_log_end.txt", "w")
    l:write("wrote ref_wram_1500_end.bin\n"); l:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
