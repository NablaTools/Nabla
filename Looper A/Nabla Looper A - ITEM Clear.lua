--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - ITEM Clear
* Version: 0.3
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]]
--======================================================================
local console = 0
local version = "0.3"
local proj = proj
local reaper = reaper

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

local match  = string.match
local gmatch = string.gmatch
local gsub   = string.gsub

local blank_audio_source = script_path.."clean_audio.wav"

local flags    = {}
local items_table    = {}
local rec_items_table = {}

local function GetItemType( item, getsectiontype ) -- MediaItem* item, boolean* getsectiontype
  local take   = reaper.GetActiveTake(item)
  if not take then return false, "UNKNOW" end
  local source = reaper.GetMediaItemTake_Source(take)
  local item_type   = reaper.GetMediaSourceType(source, "")
  if item_type ~= "SECTION" then
    return false, item_type
  else
    if not getsectiontype then
      return true, 'SECTION'
    else
      local _, chunk = reaper.GetItemStateChunk(item, "", false)
      for sectionType in  gmatch(chunk, '<SOURCE%s+(.-)[\r]-[%\n]') do
        if sectionType ~= "SECTION" then
          return true, sectionType
        end
      end
    end
  end
end

local function GetItemAction(code_item)
  local r, item_action = reaper.GetSetMediaItemInfo_String(code_item, 'P_EXT:ITEM_ACTION', '', false)
  if r then
    return item_action
  else
    return ""
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
        local code_item     = reaper.GetMediaItem(proj, i)
        local _, item_type  = GetItemType( code_item, true )
        if not CheckIfItemTypeIsAudioOrMIDI(item_type) then goto next end
        local code_take     = reaper.GetMediaItemTake(code_item, 0)
        local take_name     = reaper.GetTakeName( code_take )
        local is_nabla_take = match(take_name, '(.-)%sTK:%d+$')
        take_name           = is_nabla_take or take_name
        local item_lock = reaper.GetMediaItemInfo_Value(code_item,"C_LOCK")
        local iLen = reaper.GetMediaItemInfo_Value(code_item,"D_LENGTH")
        local lengthQN = reaper.TimeMap2_timeToQN( proj, iLen ) * 960
        local action = GetItemAction(code_item)
        local item_source = reaper.GetMediaItemTake_Source(code_take)
        local _, _, _, item_mode = reaper.PCM_Source_GetSectionInfo( item_source )
        items_table[#items_table+1] = {
            code_item  = code_item,
            code_take  = code_take,
            take_name  = take_name,
            item_lock  = item_lock,
            lengthQN   = lengthQN,
            item_type  = item_type,
            item_mode  = item_mode,
        }
        if action == 'record' or action == 'record mute' then
            rec_items_table[#rec_items_table+1] = {  take_name = take_name, iLen = iLen, lengthQN = lengthQN }
        end
        ::next::
  end
end

function CleanUp()
  reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_RESTORETRACK'), 0)
end

function ErrorHandler(errObject)
  local byLine = "([^\r\n]*)\r?\n?"
  local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
  local err = errObject   and string.match(errObject, trimPath) or  "Couldn't get error message."
  local trace = debug.traceback()
  local stack = {}
  for line in string.gmatch(trace, byLine) do
    local str = string.match(line, trimPath) or line
    stack[#stack + 1] = str
  end
  table.remove(stack, 1)
  reaper.ShowConsoleMsg(
    "Error: "..err.."\n\n"..
    "Stack traceback:\n\t"..table.concat(stack, "\n\t", 2).."\n\n"..
    "Nabla:      \t".. version .."\n"..
    "Reaper:      \t"..reaper.GetAppVersion().."\n"..
    "Platform:    \t"..reaper.GetOS()
  )
end

local function cleanMIDI(v, midi_type, i)
    local _, chunk    = reaper.GetItemStateChunk(v.code_item, '', false)
    local new_chunk = gsub(chunk, '<SOURCE%s+.->[\r]-[%\n]', "<SOURCE "..midi_type.."\n".."E "..string.format("%.0f",rec_items_table[i].lengthQN).." b0 7b 00".."\n>\n", 1)
    reaper.SetItemStateChunk(v.code_item, new_chunk, true)
    reaper.GetSetMediaItemTakeInfo_String( v.code_take, 'P_NAME', v.take_name, true )
end

local function CleanAudio(v)
    reaper.BR_SetTakeSourceFromFile2( v.code_take, blank_audio_source, false, true )
    reaper.GetSetMediaItemTakeInfo_String( v.code_take, 'P_NAME', v.take_name, true )
end

function Main()
    reaper.Undo_BeginBlock()
    if #rec_items_table <= 0 then return end
    for i = 1, #rec_items_table do
        for j = 1, #items_table do
            local v = items_table[j]
            if not flags[v.code_item] then
                if rec_items_table[i].take_name == v.take_name then
                    flags[v.code_item] = true
                    if v.item_lock ~= 1 then
                        Msg(v.item_type)
                        if v.item_type == "MIDIPOOL" then
                            cleanMIDI(v, "MIDIPOOL", i)
                        elseif v.item_type == "MIDI" then
                            cleanMIDI(v, "MIDI", i)
                        else -- If AUDIO ANY TYPE
                            CleanAudio(v)
                        end
                    end
                end
            end
        end
    end
    reaper.Main_OnCommand(40047, 0)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Clear items", -1)
end

CreateTableAllItems()
xpcall(Main, ErrorHandler)
reaper.atexit( CleanUp )
