local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/ref_dma_ch.txt"
local h = io.open(out, "w")
local f = 0
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  if f >= 2500 and f < 2504 then b.start = true end
  if f >= 3105 and f < 3109 then b.start = true end
  emu.setInput(b, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  if f == 2602 then
    local s = emu.getState()
    for i = 0, 7 do
      local k = "dmaController.channel[" .. i .. "]."
      h:write(string.format("ch%d src=%s:%s dest=%s size=%s active=%s\n", i,
        tostring(s[k .. "srcBank"]), tostring(s[k .. "srcAddress"]),
        tostring(s[k .. "destAddress"]), tostring(s[k .. "transferSize"]),
        tostring(s[k .. "dmaActive"])))
    end
    h:close()
  end
  if f >= 2603 then emu.stop(0) end
end, emu.eventType.endFrame)
