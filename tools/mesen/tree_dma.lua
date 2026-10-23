local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local f = 0
local log = io.open(out .. "dma_log.txt", "w")
log:write("tree dma probe\n"); log:flush()

local function rd(a, t) return emu.read(a, t or emu.memType.snesMemory) end

local function dumpChannel(n, s)
  local p = "dmaController.channel[" .. n .. "]."
  log:write(string.format("CH%d dest=%02X src=%04X bank=%02X table=%04X mode=%d size=%04X line=%02X fin=%s ind=%s\n",
    n,
    s[p .. "destAddress"] or 0,
    s[p .. "srcAddress"] or 0,
    s[p .. "srcBank"] or 0,
    s[p .. "hdmaTableAddress"] or 0,
    s[p .. "transferMode"] or 0,
    s[p .. "transferSize"] or 0,
    s[p .. "hdmaLineCounterAndRepeat"] or 0,
    tostring(s[p .. "hdmaFinished"]),
    tostring(s[p .. "hdmaIndirectAddressing"])))
  local bank = s[p .. "srcBank"] or 0
  local adr = s[p .. "srcAddress"] or 0
  local base = (bank << 16) | adr
  local bytes = {}
  for i = 0, 47 do
    bytes[#bytes + 1] = string.format("%02X", rd(base + i))
  end
  log:write("  table " .. string.format("%02X:%04X", bank, adr) .. " = " .. table.concat(bytes, " ") .. "\n")
end

emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
  if f == 1499 or f == 1500 then
    local s = emu.getState()
    log:write(string.format("INPUT f=%d hdmaChannels=%02X hdmaPending=%s scan=%d\n",
      f, s["dmaController.hdmaChannels"] or 0,
      tostring(s["dmaController.hdmaPending"]), s["ppu.scanline"] or -1))
    for n = 4, 7 do dumpChannel(n, s) end
    for i = 0, 3 do
      log:write(string.format("  BG%d h=%d v=%d\n", i + 1,
        s["ppu.layers[" .. i .. "].hscroll"] or -1,
        s["ppu.layers[" .. i .. "].vscroll"] or -1))
    end
    log:flush()
  end
  if f >= 1500 then log:write("DONE\n"); log:flush(); log:close(); emu.stop(0) end
end, emu.eventType.inputPolled)
