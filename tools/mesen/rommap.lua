local out = "C:/Users/lollo/Downloads/SOM/work/mesen/tree/"
local h = io.open(out .. "ref_rommap.txt", "w")
-- Read the SNES CPU bus at several bank/address pairs through the debug
-- memory API, using the "snesMemory" type which maps the CPU address space.
local probes = {
  { 0xC00009, "C0:0009" },
  { 0xC00000, "C0:0000" },
  { 0xC02065, "C0:2065" },
  { 0x000009, "00:0009" },
  { 0x400009, "40:0009" },
  { 0x800009, "80:0009" },
  { 0xC14CCF, "C0:4CCF" },
  { 0xC300D9, "C0:00D9" },
}
for _, p in ipairs(probes) do
  local bytes = {}
  for i = 0, 15 do
    local ok, v = pcall(function() return emu.read(p[1] + i, emu.memType.snesPrgRom) end)
    bytes[#bytes+1] = (ok and v ~= nil) and string.format("%02X", v) or "??"
  end
  h:write(string.format("%s ($%06X): %s\n", p[2], p[1], table.concat(bytes, " ")))
end
h:close()
emu.stop(0)
