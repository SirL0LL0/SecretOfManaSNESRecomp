local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local done = false
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  if f >= 3105 and f < 3109 then b.start = true end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 3410 and not done then
    done = true
    -- raw PPU registers $2100..$2140
    local h = io.open(out .. "ref_name_regs_3410.txt", "w")
    for a = 0x2100, 0x2140 do
      local v = emu.read(a, emu.memType.snesRegister)
      h:write(string.format("$%04X = %02X\n", a, v))
    end
    h:close()
    -- full PPU state
    local s = emu.getState()
    local keys = {}
    for k, v in pairs(s) do keys[#keys+1] = k end
    table.sort(keys)
    local h2 = io.open(out .. "ref_name_state_3410.txt", "w")
    for _, k in ipairs(keys) do
      local v = s[k]
      if type(v) == "table" then
        local first = {}
        for i, x in ipairs(v) do if i <= 8 then first[#first+1] = tostring(x) end end
        h2:write(string.format("%s = [%s]\n", k, table.concat(first, ",")))
      else
        h2:write(string.format("%s = %s\n", k, tostring(v)))
      end
    end
    h2:close()
  end
  if f >= 3410 then emu.stop(0) end
end, emu.eventType.endFrame)
