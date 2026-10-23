local f=0; local ip=0
local h=io.open("C:/Users/lollo/Downloads/SOM/work/mesen/t7.txt","w")
emu.addEventCallback(function()
  ip=ip+1
  local b={a=false,b=false,x=false,y=false,start=false,select=false,up=false,down=false,left=false,right=false,l=false,r=false}
  local ok,err=pcall(function() emu.setInput(b,0) end)
  if ip<5 then h:write("inputPolled "..ip.." ok="..tostring(ok).." err="..tostring(err).."\n"); h:flush() end
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f=f+1
  if f==10 then
    local g=emu.getInput(0)
    local keys={}
    for k,v in pairs(g) do keys[#keys+1]=tostring(k).."="..tostring(v) end
    h:write("getInput: "..table.concat(keys,",").."\n")
    h:close(); emu.stop(0)
  end
end, emu.eventType.endFrame)
