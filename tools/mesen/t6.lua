local f=0
local function try(h,name,fn)
  local ok,res=pcall(fn)
  h:write(name.." ok="..tostring(ok).." v="..tostring(res).."\n")
end
emu.addEventCallback(function()
  f=f+1
  if f==5 then
    local h=io.open("C:/Users/lollo/Downloads/SOM/work/mesen/t6.txt","w")
    local s=emu.getState()
    try(h,"frameCount",function() return s.frameCount end)
    try(h,"cpu.cycleCount",function() return s["cpu.cycleCount"] end)
    try(h,"ppu.scanline",function() return s["ppu.scanline"] end)
    try(h,"ppu.mainScreenLayers",function() return s["ppu.mainScreenLayers"] end)
    try(h,"ppu.bgMode",function() return s["ppu.bgMode"] end)
    try(h,"ppu.layers0",function() return s["ppu.layers[0].hscroll"] end)
    try(h,"ppu.layers0b",function() return s["ppu.layers[0].tilemapAddress"] end)
    try(h,"ppu.mode1Bg3Priority",function() return s["ppu.mode1Bg3Priority"] end)
    try(h,"ppu.overscanMode",function() return s["ppu.overscanMode"] end)
    try(h,"ppu.screenBrightness",function() return s["ppu.screenBrightness"] end)
    try(h,"ppu.layers0.chrAddress",function() return s["ppu.layers[0].chrAddress"] end)
    try(h,"string.format",function() return string.format("%04X", s["ppu.layers[0].tilemapAddress"]) end)
    try(h,"full",function() return string.format("%d\t%d\t%d", s.frameCount, s["ppu.bgMode"], s["ppu.mainScreenLayers"]) end)
    h:close()
    emu.stop(0)
  end
end, emu.eventType.endFrame)
