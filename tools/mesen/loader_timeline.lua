-- Timeline of the missing block: when does WRAM $E700 / VRAM $E000 fill up?
local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local done = false
local lastW = ""
local lastV = ""
local lastPc = -1
local rows = {}
local h = io.open(out .. "ref_loader_timeline.csv", "w")
h:write("frame,pc,wramE700_sum,vramE000_sum\n")

local function sum(bt, base, n)
  local s = 0
  for i = 0, n - 1 do
    s = s + bt(base + i) * (i + 1)
  end
  return s
end

emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  if f >= 3105 and f < 3109 then b.start = true end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)

emu.addEventCallback(function()
  local w = sum(emu.memType.snesWorkRam, 0xE700, 32)
  local v = sum(emu.memType.snesVideoRam, 0xE000, 32)
  local pc = lastPc
  if w ~= lastW or v ~= lastV then
    -- state only when something changed: getState() is expensive
    local s = emu.getState()
    pc = s["cpu.pc"] or s["processor.pc"] or s["cpu.PC"] or s["pc"] or -1
    rows[#rows+1] = string.format("%d,pc=%s,w=%d,v=%d", f, tostring(pc), w, v)
    h:write(rows[#rows+1] .. "\n")
    h:flush()
    lastW, lastV, lastPc = w, v, pc
  end
  if f >= 3410 then
    if not done then
      done = true
      h:close()
      local s = emu.getState()
      local h2 = io.open(out .. "ref_state_keys_all.txt", "w")
      local keys = {}
      for k, _ in pairs(s) do keys[#keys+1] = k end
      table.sort(keys)
      for _, k in ipairs(keys) do
        local v2 = s[k]
        if type(v2) == "table" then
          local first = {}
          for i, x in ipairs(v2) do if i <= 6 then first[#first+1] = tostring(x) end end
          h2:write(string.format("%s = [%s]\n", k, table.concat(first, ",")))
        else
          h2:write(string.format("%s = %s\n", k, tostring(v2)))
        end
      end
      h2:close()
    end
    emu.stop(0)
  end
end, emu.eventType.endFrame)
