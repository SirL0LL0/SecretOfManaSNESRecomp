local f=0
emu.addEventCallback(function()
  f=f+1
  if f==5 then
    local h=io.open("C:/Users/lollo/Downloads/SOM/work/mesen/t5.txt","w")
    local s=emu.getState()
    h:write("frameCount="..tostring(s.frameCount).."\n")
    h:write("mainLayers="..tostring(s.ppu.mainScreenLayers).."\n")
    h:write("layers type="..type(s.ppu.layers).." len="..tostring(#s.ppu.layers).."\n")
    h:write("l0="..tostring(s.ppu.layers[0]).." l1="..tostring(s.ppu.layers[1]).."\n")
    local ok,err=pcall(function() return s.ppu.layers[0].hscroll end)
    h:write("pcall0 ok="..tostring(ok).." err="..tostring(err).."\n")
    local ok2,err2=pcall(function() return s.ppu.layers[1].hscroll end)
    h:write("pcall1 ok="..tostring(ok2).." err="..tostring(err2).."\n")
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
