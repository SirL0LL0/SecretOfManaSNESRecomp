emu.log("hello"); local c=0; local function cb() c=c+1; if c==3 then emu.stop(4) end end; emu.addEventCallback(cb, emu.eventType.endFrame)
