local out = "C:/Users/lollo/Downloads/SOM/work/mesen/"
local f = 0
local log = io.open(out .. "probe_flow.txt", "w")
local n = 0
local function st(tag, addr)
  local s = emu.getState()
  log:write(string.format("%s addr=%06X pc=%06X k=%02X ps=%02X e=%s dbr=%02X d=%04X\n",
    tag, addr, s["cpu.pc"], s["cpu.k"], s["cpu.ps"], tostring(s["cpu.emulationMode"]), s["cpu.dbr"], s["cpu.d"]))
  n = n + 1
end
local function cb(tag)
  return function(a, v) if n < 80 then st(tag, a) end end
end
emu.addMemoryCallback(cb("V104"), emu.callbackType.exec, 0x0104, 0x0104, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(cb("V105"), emu.callbackType.exec, 0x0105, 0x0105, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(cb("V107"), emu.callbackType.exec, 0x0107, 0x0107, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(cb("C1CF"), emu.callbackType.exec, 0x00C1CF, 0x00C1CF, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(cb("C1D0"), emu.callbackType.exec, 0x00C1D0, 0x00C1D0, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(cb("BANKC1"), emu.callbackType.exec, 0xC1C1CF, 0xC1C1CF, emu.cpuType.snes, emu.memType.snesMemory)
emu.addMemoryCallback(cb("BANK7E"), emu.callbackType.exec, 0x7EC1CF, 0x7EC1CF, emu.cpuType.snes, emu.memType.snesMemory)
emu.addEventCallback(function()
  f = f + 1
  local b = { a=false, b=false, x=false, y=false, start=false, select=false,
              up=false, down=false, left=false, right=false, l=false, r=false }
  emu.setInput(b, 0)
  if f >= 25 then log:flush(); log:close(); emu.stop(0) end
end, emu.eventType.inputPolled)
