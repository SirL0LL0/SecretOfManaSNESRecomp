local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/ref_romprobe.txt"
local h = io.open(out, "w")
local addrs = { 0xC02065, 0xC021D3, 0xC0219E, 0xC021AF, 0xC025F6, 0xC303B6, 0xC14CCF, 0xC300D9 }
for _, a in ipairs(addrs) do
  local bytes = {}
  for i = 0, 15 do
    local ok, v = pcall(function() return emu.read(a + i, emu.memType.snesPrgRom) end)
    bytes[#bytes+1] = (ok and v ~= nil) and string.format("%02X", v) or "??"
  end
  h:write(string.format("$%06X: %s\n", a, table.concat(bytes, " ")))
end
h:close()
emu.stop(0)
