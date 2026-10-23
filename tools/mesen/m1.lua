local f=0
emu.addEventCallback(function() f=f+1; if f>=100 then emu.stop(0) end end, emu.eventType.endFrame)
