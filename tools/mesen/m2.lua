local f=0; local w=0
emu.addEventCallback(function() f=f+1; if f>=100 then local h=io.open("C:/Users/lollo/Downloads/SOM/work/mesen/m2.txt","w"); h:write("f="..f.." w="..w); h:close(); emu.stop(0) end end, emu.eventType.endFrame)
emu.addMemoryCallback(function(a,v) w=w+1 end, emu.callbackType.write, 0x2100, 0x213F, emu.cpuType.snes, emu.memType.snesMemory)
