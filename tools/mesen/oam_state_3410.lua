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
    local h = io.open(out .. "ref_oam_keys_3410.txt", "w")
    for k, v in pairs(s) do
      local lk = string.lower(k)
      if lk:find("oam") or lk:find("sprite") or lk:find("obj") or lk:find("setini") or lk:find("hires") or lk:find("interlace") then
        h:write(string.format("%s=%s\n", k, tostring(v)))
      end
    end
    h:close()
  end
  if f >= 3410 then emu.stop(0) end
end, emu.eventType.endFrame)
