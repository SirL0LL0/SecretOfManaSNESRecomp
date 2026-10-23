local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local targets = { [1100]=true, [1500]=true, [2100]=true, [2500]=true }
local log = io.open(out .. "wram_at_log.txt", "w")
log:write("wram at frames\n"); log:flush()

emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

emu.addEventCallback(function()
  if targets[f] then
    local p = string.format("%sref_wram_%04d_end.bin", out, f)
    local h = io.open(p, "wb")
    local chunk = {}
    for i = 0, 131071 do
      chunk[#chunk + 1] = string.char(emu.read(0x7E0000 + i, emu.memType.snesMemory))
      if #chunk >= 4096 then h:write(table.concat(chunk)); chunk = {} end
    end
    if #chunk > 0 then h:write(table.concat(chunk)) end
    h:close()
    log:write("wrote " .. p .. "\n"); log:flush()
  end
  if f >= 2500 then log:write("DONE\n"); log:flush(); log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
