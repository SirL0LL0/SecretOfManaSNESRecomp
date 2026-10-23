-- Records which ROM pages (256 bytes) the CPU reads / executes per phase.
-- Phase A: frames 1-2049 (logos, credits), phase B: 2050-6200 (tree intro).
-- Output: one line per page: <A|B> <R|X> <page hex>
local out_path = os.getenv("ROMPAGES_OUT") or "C:/Users/lollo/Downloads/SOM/work/mesen/rompages.txt"
local f = 0
local seen = {}
emu.addEventCallback(function()
  emu.setInput({ a=false, b=false, x=false, y=false, start=false, select=false,
                 up=false, down=false, left=false, right=false, l=false, r=false }, 0)
end, emu.eventType.inputPolled)
local function phase() return f < 2050 and "A" or "B" end
local function note(kind, addr)
  local k = phase() .. " " .. kind .. " " .. string.format("%04X", (addr >> 8) & 0xFFFF)
  seen[k] = true
end
emu.addMemoryCallback(function(a) note("R", a) end, emu.callbackType.read, 0xC00000, 0xFFFFFF)
emu.addMemoryCallback(function(a) note("X", a) end, emu.callbackType.exec, 0xC00000, 0xFFFFFF)
emu.addEventCallback(function()
  f = f + 1
  if f >= 6200 then
    local h = io.open(out_path, "w")
    for k in pairs(seen) do h:write(k, "\n") end
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
