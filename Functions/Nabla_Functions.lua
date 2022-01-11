-- Activate takes by Name
function active_take_x(str)
  local NumItems=reaper.CountMediaItems( 0 )
  for i=0, NumItems-1 do
    local CodeItem=reaper.GetMediaItem( 0, i )
    local NumTakes = reaper.GetMediaItemNumTakes( CodeItem )
    for i=0, NumTakes-1 do
      local CodeTake = reaper.GetMediaItemTake( CodeItem, i )
      local TakeName = reaper.GetTakeName( CodeTake )
      if TakeName:lower():match("^(" .. str .. ")") then
        reaper.SetActiveTake( CodeTake )
        reaper.UpdateArrange()
      end
    end 
  end
end

-- Wait for next measure 
function wait_next_measure(measures,str)
  local state = reaper.GetPlayState()
  local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
  if measures ~= nil then
    mea = measures
    str_s = str
  end
  if state==1 then
    local play = reaper.GetPlayPosition()
    local retval, measures_actual, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats( 0, play+0.1 )
    reaper.SetToggleCommandState( sec, cmd, 1 )
    reaper.RefreshToolbar2( sec, cmd ) 
    if mea ~= measures_actual then
      local str = str_s
      active_take_x(str)
      reaper.SetToggleCommandState( sec, cmd, 0 )
      reaper.RefreshToolbar2( sec, cmd )     
      return
    end
  end
  reaper.defer(wait_next_measure)
end