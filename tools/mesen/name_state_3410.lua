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
  if f == 3410 then
    local png = emu.takeScreenshot()
    local h = io.open(out .. "ref_name_3410.png", "wb")
    if h then h:write(png); h:close() end
  end
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 3410 and not done then
    done = true
    local function dump(name, mt, n)
      local h = io.open(string.format("%sref_name_%s.bin", out, name), "wb")
      for i = 0, n - 1 do h:write(string.char(emu.read(i, mt))) end
      h:close()
    end
    dump("oam", emu.memType.snesSpriteRam, 544)
    dump("vram", emu.memType.snesVideoRam, 65536)
    dump("cgram", emu.memType.snesCgRam, 512)
    local s = emu.getState()
    local keys = {}
    for k, v in pairs(s) do
      local lk = string.lower(k)
      if lk:find("layer") or lk:find("tilemap") or lk:find("bgmode") or lk:find("hires") or lk:find("interlace") or lk:find("oam") or lk:find("mainScreen") or lk:find("subScreen") or lk:find("mode7") then
        keys[#keys+1] = k
      end
    end
    table.sort(keys)
    local h = io.open(out .. "ref_name_layers_3410.txt", "w")
    for _, k in ipairs(keys) do
      local v = s[k]
      if type(v) == "table" then
        local first = {}
        for i, x in ipairs(v) do if i <= 8 then first[#first+1] = tostring(x) end end
        h:write(string.format("%s = [%s]\n", k, table.concat(first, ",")))
      else
        h:write(string.format("%s = %s\n", k, tostring(v)))
      end
    end
    h:close()
  end
  if f >= 3410 then emu.stop(0) end
end, emu.eventType.endFrame)
