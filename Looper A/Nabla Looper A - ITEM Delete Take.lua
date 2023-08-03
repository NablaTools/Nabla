--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - ITEM Delete Take
* Version: 0.3
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]]
--======================================================================
local console = 0
local reaper = reaper
local proj = proj

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
local script_path  = info.source:match[[^@?(.*[\/])[^\/]-$]]

reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_SAVETRACK'), 0)

local gsub      = string.gsub
local gmatch    = string.gmatch
local match     = string.match
local insert    = table.insert
local items     = {}

local codeItem = reaper.GetSelectedMediaItem(proj, 0)
if not codeItem then return reaper.defer(function () end) end
local tStrRec = {}

local cTake        = reaper.GetActiveTake( codeItem )
local name         = reaper.GetTakeName( cTake )
local subTkName    = match(name, '(.-)%sTK:%d+$')
local tkName       = subTkName or name
local sTkName      = tkName:gsub("%s+", "")
local _, old_chunk = reaper.GetItemStateChunk(codeItem, "", false)
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
      local _, chunk     = reaper.GetItemStateChunk(item, "", false)
      for sourceType in  gmatch(chunk, '<SOURCE%s+(.-)[\r]-[%\n]') do
        if sourceType ~= "SECTION" then
          return true, sourceType
        end
      end
    end
  end
end

local function GetItemAction(codeItem)
  local r, action     = reaper.GetSetMediaItemInfo_String(codeItem, 'P_EXT:ITEM_ACTION', '', false)
  if r then
    return action
  end
end

local function CheckIfItemTypeIsAudioOrMIDI(item_type)
    local forbidenTypes = {"UNKNOW", "RPP_PROJECT", "VIDEO", "CLICK", "LTC", "VIDEOEFFECT"}
    for i = 0, #forbidenTypes do
        if forbidenTypes[i] == item_type then
            return false
        end
    end
    return true
end

local function CreateTableAllItems()
  local count = reaper.CountMediaItems( proj )
  for i = 0, count - 1 do
    local codeItem       = reaper.GetMediaItem(proj, i)
    local _, item_type         = GetItemType( codeItem, true )
    if not CheckIfItemTypeIsAudioOrMIDI(item_type) then goto next end
    local cTake       = reaper.GetMediaItemTake(codeItem, 0)
    local name        = reaper.GetTakeName( cTake )
    local subTkName   = match(name, '(.-)%sTK:%d+$')
    local tkName      = subTkName or name
    local tkIdx       = match(name, '%d+$')
    local iLock       = reaper.GetMediaItemInfo_Value(codeItem,"C_LOCK")
    local iLen        = reaper.GetMediaItemInfo_Value(codeItem,"D_LENGTH")
    local lenQN       = reaper.TimeMap2_timeToQN( proj, iLen ) * 960
    local source         = reaper.GetMediaItemTake_Source(cTake)
    local _, _, _, mode = reaper.PCM_Source_GetSectionInfo( source )
    items[#items+1] = {
      codeItem       = codeItem,
      cTake       = cTake,
      tkName      = tkName ,
      tkIdx       = tkIdx,
      iLock       = iLock ,
      lenQN       = lenQN,
      type        = item_type,
      mode        = mode,
    }
    ::next::
  end
end

function PropagateAudio(sTkName, source, oldSoffs, oldLen )
  for i = 1, #items do
    local v = items[i]
    if v.tkName == sTkName then
      if v.iLock ~= 1 then
        if v.mode then
          reaper.BR_SetTakeSourceFromFile2( v.cTake, source, false, true )
          reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )
          reaper.BR_SetMediaSourceProperties( v.cTake, true, 0, oldLen, 0, true )
        else
          reaper.BR_SetTakeSourceFromFile2( v.cTake, source, false, true )
          reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )
        end
      end
    end
  end
  reaper.Main_OnCommand(40047, 0)
  reaper.UpdateArrange()
end

local function cleanMIDI(v, midi_type, i)
  local _, chunk    = reaper.GetItemStateChunk(v.codeItem, '', false)
  local new_chunk = gsub(chunk, '<SOURCE%s+.->[\r]-[%\n]', "<SOURCE "..midi_type.."\n".."E "..string.format("%.0f", v.lenQN).." b0 7b 00".."\n>\n", 1)
  reaper.SetItemStateChunk(v.codeItem, new_chunk, true)
  reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )
end

function PropagateMIDI(tkName, key)
  for i = 1, #items do
    local v = items[i]
    if v.tkName == tkName then
      if v.type == "MIDI" then
        cleanMIDI(v, "MIDI")
      elseif v.type == "MIDIPOOL" then
        cleanMIDI(v, "MIDIPOOL")
      end
    end
  end
  reaper.Main_OnCommand(40047, 0)
  reaper.UpdateArrange()
end

function GetNumForLoopTakes( cTake )
  for i = 0, 500 do
    retval, key, val = reaper.EnumProjExtState( 0, cTake, i )
    if retval == false then return i+1 end
    takes[i+1] = val
  end
end

function drawMenu()
  local str = ''
  local SHIFT_X = -50;
  local SHIFT_Y = 15;
  local x,y = reaper.GetMousePosition();
  local x,y =  x+(SHIFT_X or 0),y+(SHIFT_Y or 0);
  gfx.init('Delete Take',175,0,0,x,y)

  for i = 0, 10000 do
    local retval, key, _ = reaper.EnumProjExtState( 0, sTkName, i )
    if retval == false then  break end
    str = string.format("%s|Delete - %s - Take %d", str, tkName, key)
  end

  local retval = gfx.showmenu(str)

  if retval > 0 then
    local _, key, str_val = reaper.EnumProjExtState( 0, sTkName, string.format("%.0f", retval-1 ) )

    for substring in gmatch(str_val, '([^,]+)') do insert(tStrRec, substring) end

    local warningStr = "Delete take and source files (no undo!)"
    local messageFormat = "Delete \"%s TK:%.0f\" and its media file: %s"
    local message = string.format(messageFormat, tkName, key, tStrRec[1])
    
    local yesno = reaper.MB(message, warningStr, 4)
    
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
