--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - ITEM Delete Take
* Version: 0.3
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]] 
--======================================================================
console = 0
function Msg(value, line)
  if console == 1 then
    reaper.ShowConsoleMsg(tostring(value))
    if line == 0 then
      reaper.ShowConsoleMsg("\n")
    else
      reaper.ShowConsoleMsg("\n-----\n")
    end
  end
end

local info   = debug.getinfo(1,'S');
script_path  = info.source:match[[^@?(.*[\/])[^\/]-$]]

reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_SAVETRACK'), 0)

local gsub      = string.gsub
local gmatch    = string.gmatch
local match     = string.match
local format    = string.format
local insert    = table.insert
local items     = {}

local cItem = reaper.GetSelectedMediaItem(proj, 0)

if not cItem then return reaper.defer(function () end) end

local takes   = {} 
local tStrRec = {}

local cTake        = reaper.GetActiveTake( cItem )
local name         = reaper.GetTakeName( cTake )
local subTkName    = match(name, '(.-)%sTK:%d+$')
local tkName       = subTkName or name
local sTkName      = tkName:gsub("%s+", "")
local r, old_chunk = reaper.GetItemStateChunk(cItem, "", false)
local fileOrig     = match(old_chunk, '[%\n]FILE%s+[\"](.-)[\"][%\n]')

------------------------------------------------------------------
-- FUNCTIONS
------------------------------------------------------------------
local function GetItemType( item, getsectiontype )

  local take   = reaper.GetActiveTake(item)
  if not take then return false, "UNKNOW" end
  local source = reaper.GetMediaItemTake_Source(take)
  local type   = reaper.GetMediaSourceType(source, "")

  if type ~= "SECTION" then
    return false, type
  else
    if not getsectiontype then
      return true, type
    else
      local r, chunk     = reaper.GetItemStateChunk(item, "", false)
      for type in  gmatch(chunk, '<SOURCE%s+(.-)[\r]-[%\n]') do
        if type ~= "SECTION" then
          return true, type
        end
      end
    end
  end
  
end

local function GetItemAction(cItem)

  local r, action     = reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_ACTION', '', false)

  if r then 
    return action 
  else
    old_action = ""
    local r, isRec      = reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_RECORDING', '', false)
    local r, isRecMute  = reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_RECMUTE', '', false)
    local r, isMon      = reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_MON', '', false)
    if isRec     == "1" then 
      reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_ACTION', '1', true) 
      reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_RECORDING', '', true)
      old_action = "1"
    else 
      reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_RECORDING', '', true) 
    end
    if isRecMute == "1" then 
      reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_ACTION', '2', true) 
      reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_RECMUTE', '', true) 
      old_action = "2"
    else 
      reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_RECMUTE', '', true) 
    end
    if isMon     == "1" then 
      reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_ACTION', '3', true) 
      reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_MON', '', true) 
      old_action = "3"
    else 
      reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_MON', '', true) 
    end
    return old_action
  end
end

local function CreateTableAllItems()

  local count = reaper.CountMediaItems( proj )

  for i = 0, count - 1 do

    local cItem       = reaper.GetMediaItem(proj, i)
    local _, type         = GetItemType( cItem, true )
    
    if type ~= "UNKNOW" and type ~= "RPP_PROJECT" and type ~= "VIDEO" and type ~= "CLICK" and type ~= "LTC" and type ~= "VIDEOEFFECT" then

      local cTake       = reaper.GetMediaItemTake(cItem, 0)
      local name        = reaper.GetTakeName( cTake )
      local subTkName   = match(name, '(.-)%sTK:%d+$')
      local tkName      = subTkName or name
      local tkIdx       = match(name, '%d+$')
      local iLock       = reaper.GetMediaItemInfo_Value(cItem,"C_LOCK")
      local iLen        = reaper.GetMediaItemInfo_Value(cItem,"D_LENGTH")
      local lenQN       = reaper.TimeMap2_timeToQN( proj, iLen ) * 960
      local action        = GetItemAction(cItem)
      local source         = reaper.GetMediaItemTake_Source(cTake)
      local _, _, _, mode = reaper.PCM_Source_GetSectionInfo( source )

      items[#items+1] = { 
        cItem       = cItem, 
        cTake       = cTake, 
        tkName      = tkName ,
        tkIdx       = tkIdx,
        iLock       = iLock ,
        isRecord    = isRecord,
        isRecMute   = isRecMute,
        lenQN       = lenQN,
        type        = type,
        mode        = mode,
      }

    end

  end
end

function PropagateAudio(sTkName, source, oldSoffs, oldLen )

  for i = 1, #items do

    local v = items[i]

      if v.tkName == sTkName then

        if v.iLock ~= 1 then

          local r, iChunk = reaper.GetItemStateChunk(v.cItem, "", false) -- coppy item chunk

          if v.mode then

            -- local new_chunk = gsub(iChunk, '<SOURCE%s+.->', "<SOURCE SECTION\n".."LENGTH "..oldLen.."\n".."STARTPOS "..oldSoffs.."\n".."MODE  ".."2".."\n".."<SOURCE WAVE\n".."FILE \""..oldSource.."\"".."\n>\n", 1)
            -- reaper.SetItemStateChunk(v.cItem, new_chunk, true) 
            -- reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )
            ------------------------------------------------------------------
            reaper.BR_SetTakeSourceFromFile2( v.cTake, source, false, true )
            reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )
            reaper.BR_SetMediaSourceProperties( v.cTake, true, 0, oldLen, 0, true )
            -- reaper.SetMediaItemTakeInfo_Value( v.cTake, 'D_PLAYRATE', 1 )

          else

            -- local str = "<SOURCE SECTION\n".."LENGTH "..oldLen.."\n".."STARTPOS "..oldSoffs.."\n".."<SOURCE WAVE\n".."FILE "..oldSource.."\n>\n"
            -- local new_chunk = gsub(iChunk, '<SOURCE%s+.->', str, 1)
            -- reaper.SetItemStateChunk(v.cItem, new_chunk, true) 
            -- reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )
            ------------------------------------------------------------------
            reaper.BR_SetTakeSourceFromFile2( v.cTake, source, false, true )
            reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )
            -- reaper.SetMediaItemTakeInfo_Value( v.cTake, 'D_PLAYRATE', 1 )

          end
        end      
      end
  end
  reaper.Main_OnCommand(40047, 0)
  reaper.UpdateArrange()
end

function PropagateMIDI(tkName, key)

  for i = 1, #items do

    local v = items[i]

    if v.tkName == tkName then

      local _, chunk    = reaper.GetItemStateChunk(v.cItem, '', false)

      if v.type == "MIDI" then
         local new_chunk   = gsub(chunk, '<SOURCE%s+.->[\r]-[%\n]', "<SOURCE MIDI\n".."E "..v.lenQN.." b0 7b 00".."\n>\n", 1)
         reaper.SetItemStateChunk(v.cItem, new_chunk, true) 
         reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', tkName, true )
      elseif v.type == "MIDIPOOL" then
         local new_chunk   = gsub(chunk, '<SOURCE%s+.->[\r]-[%\n]', "<SOURCE MIDIPOOL\n".."E "..v.lenQN.." b0 7b 00".."\n>\n", 1)
         reaper.SetItemStateChunk(v.cItem, new_chunk, true) 
         reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', tkName, true )
      end

    end
  end
end

function GetNumForLoopTakes( cTake )

  for i = 0, 500 do

    retval, key, val = reaper.EnumProjExtState( 0, cTake, i )
    if retval == false then return i+1 end
    takes[i+1] = val

  end

end

function drawMenu(menuName)

  local SHIFT_X = -50;
    local SHIFT_Y = 15;
  local x,y = reaper.GetMousePosition();
  local x,y =  x+(SHIFT_X or 0),y+(SHIFT_Y or 0);

  gfx.init('',0,0,0,x,y)
  
------------------------------------------------------------------

  local str = ''
  local str_2 = ''

  for i = 0, 1000 do
    retval, key, val = reaper.EnumProjExtState( 0, sTkName, i )
    if retval == false then  break end
    str = str.."|Delete - "..tkName.." - Take "..string.format("%d", key)
  end

  retval = gfx.showmenu(str)

  if retval > 0 then
    _, key, str_val = reaper.EnumProjExtState( 0, sTkName, string.format("%.0f", retval-1 ) )
    for substring in gmatch(str_val, '([^,]+)') do insert(tStrRec, substring) end
      yesno =  reaper.MB( "Delete \""..tkName.." TK:"..string.format("%.0f", key ).."\"".." and its media file: "..tStrRec[1], "Delete take and source files (no undo!)", 4 )
    if yesno == 6 then

      if tStrRec[4] == "AUDIO" then
        reaper.SetProjExtState( 0, sTkName, key, "" )
        os.remove(tStrRec[1])
        os.remove(tStrRec[1]..".reapeaks")
        if tStrRec[1] == fileOrig then
          local source = script_path.."clean_audio.wav"
          PropagateAudio(tkName, source, tStrRec[2], tStrRec[3])
        end

      elseif tStrRec[4] == "MIDI" then
        reaper.SetProjExtState( 0, sTkName, key, "" )
        os.remove(tStrRec[1])
        if tStrRec[5] == name then
          PropagateMIDI(tkName, key)
        end
      end
    else
      return
    end
  end
end

CreateTableAllItems()
drawMenu()

reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_RESTORETRACK'), 0)
