--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - ITEM Toggle Record
* Version: 0.3
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]] 
--======================================================================
------------------------------------------------------------------
-- GET/SET CONFIGURATIONS
------------------------------------------------------------------
local match     = string.match
local floor     = math.floor
local match     = string.match
local vars = { 
  {'recordFdbk',  'RECORD_FDBK',  '3'     }, 
  {'recColor',    'REC_COLOR',    '1,0,0' }, 
  {'monColor',    'MON_COLOR',    '0,0,1' }, 
  {'tkMrkColor',  'TKMRK_COLOR',  '0,1,0' },
}

for i=1, #vars do
  local varName = vars[i][1] 
  _G[varName] = reaper.GetExtState( 'NABLA_LOOPER_A', vars[i][2] )
  if _G[varName] == "" or _G[varName] == nil then
    reaper.GetExtState( 'NABLA_LOOPER_A', vars[i][2], vars[i][3], true )
    _G[varName] = vars[i][3]
  end
end
------------------------------------------------------------------
reaper.Undo_BeginBlock()
local sItems = reaper.CountSelectedMediaItems(0)
for i=0, sItems-1 do
  local cItem = reaper.GetSelectedMediaItem(0, i)
  local cTake = reaper.GetMediaItemTake(cItem, 0)
  if not cTake then
    goto next
  end
  local r, action = reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_ACTION', '', false)
  if action == 'record' then
    if recordFdbk == '2' or recordFdbk == '3' then
      local numTkMarkers =  reaper.GetNumTakeMarkers( cTake )
      for j=0, numTkMarkers-1 do
        local  retval, name, color = reaper.GetTakeMarker( cTake, j )
        if name == "Record" then
          reaper.DeleteTakeMarker( cTake, j )
        end
      end
    end
    if recordFdbk == '1' or recordFdbk == '3' then
     reaper.SetMediaItemInfo_Value( cItem, 'I_CUSTOMCOLOR', 0 )
    end
    reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_ACTION', '', true)
  else
    local numTkMarkers =  reaper.GetNumTakeMarkers( cTake )
    for j=0, numTkMarkers-1 do

      local  retval, name, color = reaper.GetTakeMarker( cTake, j )

      if name == "Monitor" or name == "Rec Mute" then
        reaper.DeleteTakeMarker( cTake, j )
      end

    end
    if recordFdbk == '1' or recordFdbk == '3' then
      local tColor = {match(recColor, "^([^,]+),([^,]+),([^,]+)$")}
      local r,g,b = tonumber(tColor[1])*255, tonumber(tColor[2])*255, tonumber(tColor[3])*255
      reaper.SetMediaItemInfo_Value( cItem, 'I_CUSTOMCOLOR', reaper.ColorToNative(floor(r+0.5), floor(g+0.5), floor(b+0.5))|0x1000000 )
    end
    if recordFdbk == '2' or recordFdbk == '3' then
      local tTkColor = {match(tkMrkColor, "^([^,]+),([^,]+),([^,]+)$")}
      local r,g,b = tonumber(tTkColor[1])*255, tonumber(tTkColor[2])*255, tonumber(tTkColor[3])*255
      local startoffs = reaper.GetMediaItemTakeInfo_Value( cTake, 'D_STARTOFFS' )
      reaper.SetTakeMarker( cTake, -1, 'Record', startoffs, reaper.ColorToNative(floor(r+0.5), floor(g+0.5), floor(b+0.5))|0x1000000 )
    end
    reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_ACTION', 'record', true)
  end  
    ::next::
end --
reaper.UpdateArrange()
reaper.Undo_EndBlock("Toggle Recording Item", -1)
