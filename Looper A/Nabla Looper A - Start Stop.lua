--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - Start Stop
* Version: 0.3
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]]
--======================================================================
local console = 0
local version = "v.0.3.0"

local reaper = reaper
local proj = proj

local function Msg(value, line)
  if console == 1 then
    reaper.ShowConsoleMsg(tostring(value))
    if line == 0 then
      reaper.ShowConsoleMsg("\n")
    else
      reaper.ShowConsoleMsg("\n-----\n")
    end
  end
end

local separator
function IsProjectSaved()
  if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
        separator = "\\"
    else
        separator = "/"
    end
  local _, project_path_name = reaper.EnumProjects(-1, "")
  if project_path_name ~= "" then
    local project_path = project_path_name:match("(.*"..separator..")")
    return project_path, separator
  else
    local display = reaper.ShowMessageBox("You need to save the project to execute Nabla Looper.", "File Export", 1)
    if display == 1 then
      reaper.Main_OnCommand(40022, 0) -- SAVE AS PROJECT
      return IsProjectSaved()
    end
  end
end

local project_path, sep = IsProjectSaved()

local _, _, sec, cmd, _, _, _ = reaper.get_action_context()
reaper.SetToggleCommandState( sec, cmd, 1 )
reaper.RefreshToolbar2( sec, cmd )

local format    = string.format
local match     = string.match
local gsub      = string.gsub
local gmatch    = string.gmatch
local find      = string.find
local sub       = string.sub
local concat    = table.concat
local insert    = table.insert
local items_table = {}
local flags = {}
local item_start_position_table = {}
local item_end_position_table = {}
local practice = {}
local reaper_user_options_table = {}
local rec_items_table = {}
local rec_tracks_table = {}
local selected = false
local idxStart
local idxEnd
local idxEndMon
local idxStartMonMIDI
local idxStartMonAUDIO
local newsiEnd, sredItemEnd

SafeMode = SafeMode
StartTime = StartTime
BufferTime = BufferTime
PreservePDC = PreservePDC
PracticeMode = PracticeMode

local function GetSetNablaConfigs()
  local vars = {
    {'SafeMode',    'SAFE_MODE',    'true' },
    {'StartTime',   'START_TIME',   '1'    },
    {'BufferTime',  'BUFFER_TIME',  '1'    },
    {'PreservePDC', 'PRESERVE_PDC', 'true' },
    {'PracticeMode','PRACTICE_MODE', 'false'},
  }
  for i = 1, #vars do
    local name = vars[i][1]
    local section = vars[i][2]
    local value      = vars[i][3]
    _G[name] = reaper.GetExtState( 'NABLA_LOOPER_A', section )
    if _G[name] == "" or _G[name] == nil then
      reaper.SetExtState( 'NABLA_LOOPER_A', section, value, true )
      _G[name] = value
    end
  end
end

local function GetItemType( item, getsectiontype )
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

local function CreateItemsTable()
    local count = reaper.CountMediaItems(proj)
    for i = 0, count - 1 do
        local code_item           = reaper.GetMediaItem(proj, i)
        local section, item_type   = GetItemType( code_item, true )
        if not CheckIfItemTypeIsAudioOrMIDI(item_type) then goto next end
        local item_position          = tonumber(format("%.3f", reaper.GetMediaItemInfo_Value(code_item,"D_POSITION")))
        local str_item_position      = "start"..gsub(tostring(item_position), "%.+","")
        local item_length            = reaper.GetMediaItemInfo_Value(code_item,"D_LENGTH")
        local item_end_position      = tonumber(format("%.3f", item_position+item_length))
        local str_item_end_position  = "end"..gsub(tostring(item_end_position), "%.+","")
        local item_action            = GetItemAction(code_item)
        local code_take              = reaper.GetActiveTake( code_item )
        local take_name              = reaper.GetTakeName( code_take )
        local is_nabla_take          = match(take_name, '(.-)%sTK:%d+$')
        take_name                    = is_nabla_take or take_name
        local variable_take_name     = take_name:gsub("%s+", "")
        local take_index             = match(take_name, '%d+$')
        local code_track             = reaper.GetMediaItem_Track( code_item )
        local track_rec_input        = reaper.GetMediaTrackInfo_Value(code_track, 'I_RECINPUT')
        local track_rec_mode         = reaper.GetMediaTrackInfo_Value( code_track, 'I_RECMODE' )
        local item_lock              = reaper.GetMediaItemInfo_Value( code_item, 'C_LOCK')
        local source                 = reaper.GetMediaItemTake_Source(code_take)
        local _, _, _, mode          = reaper.PCM_Source_GetSectionInfo( source )
        items_table[#items_table+1] = {
            code_item             = code_item,
            item_position         = item_position,
            item_end_position     = item_end_position,
            str_item_position     = str_item_position,
            str_item_end_position = str_item_end_position,
            item_action           = item_action,
            item_length           = item_length,
            code_take             = code_take,
            take_name             = take_name,
            take_index            = take_index,
            code_track            = code_track,
            track_rec_input       = track_rec_input,
            variable_take_name    = variable_take_name,
            buffer                = 0,
            record                = 0,
            mode                  = mode,
            track_rec_mode        = track_rec_mode,
            item_type             = item_type,
            item_lock             = item_lock,
            section               = section,
            source                = source
        }
        ::next::
    end
    table.sort(items_table, function(a,b) return a.item_position < b.item_position end)
end

local function AddItemInfoToRecItemsTable(i, v)
  rec_items_table[#rec_items_table+1] = {
        item_index = i,
        item_position = v.item_position,
        item_end_position = v.item_end_position
    }
end

local function SetBufferVariable(v)
    for j = 1, #items_table do
        local m = items_table[j]
        if v.take_name == m.take_name then
            if m.item_position >= v.item_end_position-0.1 and m.item_position <= v.item_end_position+0.1 then
                v.buffer = 1
            end
        end
    end
end

local function CreateTableForEachVariableTakeName(v)
  flags[v.variable_take_name] = true
  _G[ v.variable_take_name ] = {}
  for j = 1, #items_table do
    local m = items_table[j]
    if v.take_name == m.take_name then
      _G[ v.variable_take_name ][ #_G[ v.variable_take_name ] + 1 ] = {item_index = j }
    end
  end
end

local function CreateTablesForSameItemStartPositions()
  for i = 1, #item_start_position_table do
    local item_position  = item_start_position_table[i].item_position
    local str_item_position = item_start_position_table[i].str_item_position
    _G[ str_item_position ] = {}
    for j = 1, #items_table do
      if items_table[j].item_action ~= "0" and items_table[j].item_action ~= "" then
        if item_position == items_table[j].item_position then
          _G[ str_item_position ][ #_G[ str_item_position ] + 1 ] = { item_index = j }
        end
      end
    end
  end
end

local function CreateTablesForSameItemEndPositions()
  for i = 1, #item_end_position_table do
    local item_end_position  = item_end_position_table[i].item_end_position
    local str_item_end_position = item_end_position_table[i].str_item_end_position
    _G[ str_item_end_position ] = {}
    for j = 1, #items_table do
      if items_table[j].item_action ~= "0" and items_table[j].item_action ~= "" then
        if item_end_position == items_table[j].item_end_position then
          _G[ str_item_end_position ][ #_G[ str_item_end_position ] + 1 ] = { item_index = j }
        end
      end
    end
  end
end

local function AddItemPositionInfoToItemPositionTables(i, v)
  if not flags["start"..v.item_position] then
    flags["start"..v.item_position] = true
    item_start_position_table[ #item_start_position_table + 1 ]  = {
            item_index = i,
            str_item_position = v.str_item_position,
            item_position = v.item_position
        }
  end
  if not flags["end"..v.item_end_position] then
    flags["end"..v.item_end_position] = true
    item_end_position_table[ #item_end_position_table + 1 ] = {
            item_index = i,
            str_item_end_position = v.str_item_end_position,
            item_end_position = v.item_end_position
        }
  end
end

local function AddTrackInfoToTracksRecTable(v)
  if not flags[v.code_track] then
    flags[v.code_track] = true
    rec_tracks_table[ #rec_tracks_table + 1 ] = {
            code_track = v.code_track,
            track_rec_input = v.track_rec_input,
            track_rec_mode = v.track_rec_mode,
            item_action = v.item_action
        }
  end
end

local function CreateMainTables()
    for i = 1, #items_table do
        local v = items_table[i]
        if not flags[v.variable_take_name] then CreateTableForEachVariableTakeName(v) end
        -- if v.item_action ~= '0' then
            if v.item_action ~= "monitor" then AddItemInfoToRecItemsTable(i, v) end
            AddTrackInfoToTracksRecTable(v)
            AddItemPositionInfoToItemPositionTables(i, v)
            SetBufferVariable(v)
        -- end
    end
    table.sort(item_start_position_table, function(a,b) return a.item_position < b.item_position end)
    table.sort(item_end_position_table, function(a,b) return a.item_end_position < b.item_end_position end)
    table.sort(rec_items_table, function(a,b) return a.item_position < b.item_position end)
    CreateTablesForSameItemStartPositions()
    CreateTablesForSameItemEndPositions()
end

local function SetActionTracksConfig()
  for i = 1, #rec_tracks_table do
    local v = rec_tracks_table[i]
    if v.item_action == "record" then
      if v.track_rec_mode >= 7 and v.track_rec_mode <= 9 or v.track_rec_mode == 16 then
        reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMODE', 0 )
      end
      reaper.SetMediaTrackInfo_Value( v.code_track, 'B_FREEMODE', 0 )
      reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMONITEMS', 1 )
      reaper.SetMediaTrackInfo_Value( v.code_track , 'I_RECMON', 0 )
      reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECARM', 0 )
    elseif v.item_action == 'record mute' then
      if v.track_rec_mode ~= 0 then reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMODE', 0 ) end
      reaper.SetMediaTrackInfo_Value( v.code_track, 'B_FREEMODE', 0 )
      reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMONITEMS', 1 )
      reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECARM', 0 )
    end
    if v.item_action == "monitor" then
      reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMODE', 2 )
      reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMON', 0 )
      reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECARM', 1 )
    end
  end
end

local function SetReaperNablaOptions()
  local reaper_nabla_options_table = {
    { item_action = 41078, setstate = "off" }, -- FX: Auto-float new FX windows
    { item_action = 40041, setstate = "off"}, -- Options: Toggle auto-crossfades
    { item_action = 41117, setstate = "off"}, -- Options: Toggle trim behind items when editing
    { item_action = 41330, setstate = "__" }, -- Options: New recording splits existing items and creates new takes (default)
    { item_action = 41186, setstate = "__" }, -- Options: New recording trims existing items behind new recording (tape mode)
    { item_action = 41329, setstate = "on" }, -- Options: New recording creates new media items in separate lanes (layers)
    -- { item_action = 40036, setstate = "on" }, -- View: Toggle auto-view-scroll during playback
    -- { item_action = 41817, setstate = "on" }, -- View: Continuous scrolling during playback
  }
  for i = 1, #reaper_nabla_options_table do
    local v = reaper_nabla_options_table[i]
    local state = reaper.GetToggleCommandState( v.item_action )
    reaper_user_options_table[i] = { item_action = v.item_action, state = state }
    if     state == 1 and v.setstate == 'off' then
      reaper.Main_OnCommand(v.item_action, 0)
    elseif state == 0 and v.setstate == "on" then
      reaper.Main_OnCommand(v.item_action, 0)
    end
  end
end

local function RestoreReaperUserOptions()
  for i = 1, #reaper_user_options_table do
    local v = reaper_user_options_table[i]
    local state = reaper.GetToggleCommandState( v.item_action )
    if v.state ~= state then
      reaper.Main_OnCommand(v.item_action, 0)
    end
  end
end

local function GetIDByScriptName(scriptName)
  if type(scriptName)~="string"then
    error("expects a 'string', got "..type(scriptName),2)
  end
  local file = io.open(reaper.GetResourcePath()..'/reaper-kb.ini','r');
  if not file then
    return -1
  end
  local scrName = gsub(gsub(scriptName, 'Script:%s+',''), "[%%%[%]%(%)%*%+%-%.%?%^%$]",function(s)return"%"..s;end);
  for var in file:lines() do;
    if match(var, scrName) then
      local id = "_" .. gsub(gsub(match(var, ".-%s+.-%s+.-%s+(.-)%s"),'"',""), "'","")
      return id
    else
    end
  end
  return -1
end

local function GetCC(cc)
  return cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3
end

local function ExportMidiFile(take_name, take, variable_take_name, newidx, strToStore) -- local (i, j, item, take, track)
  if project_path == "" then return end
  local item_take_source = reaper.GetMediaItemTake_Source(take)
  -- interpolate CC points
  local retval, _, ccs, _ = reaper.MIDI_CountEvts(take)
  if ccs > 0 then
    -- Store CC by types
    local midi_cc = {}
    for j = 0, ccs - 1 do
      local cc = {}
      retval, cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3 = reaper.MIDI_GetCC(take, j)
      if not midi_cc[cc.msg2] then midi_cc[cc.msg2] = {} end
      table.insert(midi_cc[cc.msg2], cc)
    end
    -- Look for consecutive CC
    local cc_events = {}
    local cc_events_len_init = 0
    for _, val in pairs(midi_cc) do
      -- GET SELECTED NOTES (from 0 index)
      for k = 1, #val - 1 do
        local _, _, a_ppqpos, a_chanmsg, a_chan, a_msg2, a_msg3 = GetCC(val[k])
        local _, _, b_ppqpos, _, _, _, b_msg3 = GetCC(val[k+1])
        -- INSERT NEW CCs
        local interval = (b_ppqpos - a_ppqpos) / 32  -- CHANGED FROM ORIGINAL, so it just puts points every 32 ppq
        local time_interval = (b_ppqpos - a_ppqpos) / interval
        for z = 1, interval - 1 do
          local cc_events_len = cc_events_len_init + 1
          cc_events[cc_events_len] = {}
          local c_ppqpos = a_ppqpos + time_interval * z
          local c_msg3 = math.floor( ( (b_msg3 - a_msg3) / interval * z + a_msg3 )+ 0.5 )
          cc_events[cc_events_len].ppqpos = c_ppqpos
          cc_events[cc_events_len].chanmsg = a_chanmsg
          cc_events[cc_events_len].chan = a_chan
          cc_events[cc_events_len].msg2 = a_msg2
          cc_events[cc_events_len].msg3 = c_msg3
        end
      end
    end
    -- Insert Events
    for _, cc in ipairs(cc_events) do
      reaper.MIDI_InsertCC(take, selected, false, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3)
    end
  end

  local audio = {
        "midi",
        "MIDI",
        "Midi",
        "Audio",
        "audio",
        "AUDIO",
        "Media",
        "media",
        "MEDIA",
        ""
    }
  for i = 1, #audio do
    local midi_path = project_path..audio[i]..sep..take_name..".mid"
    retval = reaper.CF_ExportMediaSource(item_take_source, midi_path)
    if retval == true then
      if PracticeMode == 'false' then
        reaper.SetProjExtState(proj, variable_take_name, newidx, midi_path..strToStore)
        break
      else
        practice[#practice+1] = midi_path
        break
      end
    end
  end
  reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(reaper.GetMediaItemTake_Item(take)), reaper.GetMediaItemTake_Item(take) )
end

local function SetFXName(track, fx, new_name)
  if not new_name then return end
  if not track or not tonumber(fx) then return end
  local edited_line, edited_line_id, segm
  -- get ref guid
  local FX_GUID = reaper.TrackFX_GetFXGUID( track, fx )
  if not FX_GUID then return else FX_GUID = sub(gsub(FX_GUID,'-',''), 2,-2) end
  local plug_type = reaper.TrackFX_GetIOSize( track, fx )
  -- get chunk t
  local _, chunk = reaper.GetTrackStateChunk( track, '', false )
  local t = {} for line in gmatch(chunk, "[^\r\n]+") do t[#t+1] = line end
  -- find edit line
  local search
  for i = #t, 1, -1 do
    local t_check = gsub(t[i], '-','')
    if find(t_check, FX_GUID) then search = true  end
    if find(t[i], '<') and search and not find(t[i],'JS_SER') then
      edited_line = sub(t[i], 2)
      edited_line_id = i
      break
    end
  end
  -- parse line
  if not edited_line then return end
  local t1 = {}
  for word in gmatch(edited_line,'[%S]+') do t1[#t1+1] = word end
  local t2 = {}
  for i = 1, #t1 do
    segm = t1[i]
    if not q then t2[#t2+1] = segm else t2[#t2] = t2[#t2]..' '..segm end
    if find(segm,'"') and not find(segm,'""') then if not q then q = true else q = nil end end
  end
  if plug_type == 2 then t2[3] = '"'..new_name..'"' end -- if JS
  if plug_type == 3 then t2[5] = '"'..new_name..'"' end -- if VST
  local out_line = concat(t2,' ')
  t[edited_line_id] = '<'..out_line
  local out_chunk = concat(t,'\n')
  --msg(out_chunk)
  reaper.SetTrackStateChunk( track, out_chunk, false )
end

local function InsertReaDelay()
  reaper.Undo_BeginBlock()
  for i = 1, #rec_tracks_table do
    local v = rec_tracks_table[i]
    if v.item_action ~= 'monitor' then
      if v.track_rec_input < 4096 then
        local isFx = reaper.TrackFX_AddByName( v.code_track, 'ReaDelay', false, -1000 )
        reaper.TrackFX_SetParam( v.code_track, isFx, 0, 1 )
        reaper.TrackFX_SetParam( v.code_track, isFx, 1, 0 )
        reaper.TrackFX_SetParam( v.code_track, isFx, 13, 0 )
        SetFXName(v.code_track, isFx, 'Nabla ReaDelay')
      end
    end
  end
  reaper.Undo_EndBlock("Insert Nabla ReaDelay", -1)
end

local function SetPDC( set )
  reaper.Undo_BeginBlock()
  local tStrRec = {}
  for i = 1, #rec_tracks_table do
    local v = rec_tracks_table[i]
    if v.item_action ~= 'monitor' then
      local _, trChunk = reaper.GetTrackStateChunk(v.code_track, '', false)
      local strRec = match(trChunk, 'REC%s+.-[%\n]')
      for substring in gmatch(strRec, "%S+") do insert(tStrRec, substring) end

      local function set_pdc( str )
        local new_strRec = gsub(trChunk, 'REC%s+.-[%\n]', str, 1)
        reaper.SetTrackStateChunk(v.code_track, new_strRec, true)
        for j = 1, #tStrRec do tStrRec[j] = nil end
      end

      if set == 'true' then
        tStrRec[7] = "1"
        local new_strRec = concat(tStrRec, " ")
        set_pdc( new_strRec )
      else
        tStrRec[7] = "0"
        local new_strRec = concat(tStrRec, " ")
        set_pdc( new_strRec )
      end
    end
  end
  reaper.Undo_EndBlock("--> START ARRANGED MODE", -1)
end

local function RemoveReaDelay()
  for i = 1, #rec_tracks_table do
    local v = rec_tracks_table[i]
    if v.track_rec_input < 4096 then
      reaper.TrackFX_Delete( v.code_track, reaper.TrackFX_AddByName( v.code_track, 'Nabla ReaDelay', false, 0 ) )
    end
  end
end

local function GetNumForLoopTakes( code_take )
  local newKey = 0
  for i = 0, 500 do
    local retval, key, _ = reaper.EnumProjExtState( 0, code_take, i )
    if retval == false then return tonumber(newKey) + 1 end
    newKey = key
  end
end

local function AtExitActions()
  reaper.Undo_BeginBlock()
  reaper.OnStopButton()
  reaper.Main_OnCommand(40345, 0) -- Send all notes off to all MIDI outputs/plug-item_start_position_table
  local _, _, _, actual_cmd, _, _, _ = reaper.get_action_context()
  reaper.SetToggleCommandState( sec, actual_cmd, 0 )
  reaper.RefreshToolbar2( sec, actual_cmd )
  for i = 1, #rec_tracks_table do
    local v = rec_tracks_table[i]
    if v.track_rec_mode ~= 2 then
      reaper.SetMediaTrackInfo_Value( v.code_track , 'I_RECMON', 1 )
      reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMODE', v.track_rec_mode )
      reaper.SetMediaTrackInfo_Value( v.code_track,  'I_RECARM', 0 )
    end
  end
  if PracticeMode == "true" then
    for j = 1, #practice do
      os.remove(practice[j])
    end
    reaper.Undo_BeginBlock()
    local scriptName = "Script: Nabla Looper A - ITEM Clear.lua"
    local idbyscript = GetIDByScriptName(scriptName)
    reaper.Main_OnCommand(reaper.NamedCommandLookup(idbyscript),0)
    reaper.Undo_EndBlock("--> END ARRANGED MODE", -1)
  end
  if SafeMode == "true" then RemoveReaDelay() end
  RestoreReaperUserOptions()
  reaper.Undo_EndBlock("--> END ARRANGED MODE", -1)
end

local function errorHandler(errObject)
  reaper.OnStopButton()
  local byLine = "([^\r\n]*)\r?\n?"
  local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
  local err = errObject   and string.match(errObject, trimPath)
  or  "Couldn't get error message."
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

local function SetReaDelayTime(code_track, item_length)
  reaper.TrackFX_SetParam( code_track, reaper.TrackFX_AddByName( code_track, 'Nabla ReaDelay', false, 0 ), 4, (reaper.TimeMap_timeToQN_abs( 0, item_length )*2)/256 )
end

-- local function OnReaDelay(code_track)
  -- reaper.TrackFX_SetParam( code_track, reaper.TrackFX_AddByName( code_track, 'Nabla ReaDelay', false, 0 ), 13, 1 )
-- end

local function OffReaDelayDefer(str_item_end_position, redItemEnd)
  xpcall( function()
    if str_item_end_position then
      newsiEnd = str_item_end_position
      sredItemEnd = redItemEnd
    end
    if reaper.GetPlayPosition() > sredItemEnd then
      for i = 1, #_G[ newsiEnd ] do
        reaper.Undo_BeginBlock()
        local v = items_table[ _G[newsiEnd][i].item_index ]
        if v.buffer == 1 then
          reaper.TrackFX_SetParam( v.code_track, reaper.TrackFX_AddByName( v.code_track, 'Nabla ReaDelay', false, 0 ), 13, 0 )
        end
        reaper.Undo_EndBlock("End Buffer: " .. v.take_name, -1)
      end
      return
    end
    if reaper.GetPlayState() == 0 then return else reaper.defer(OffReaDelayDefer) end
  end, errorHandler)
end

local function SetItemReverseMode(v)
  reaper.SelectAllMediaItems(proj, false)
  reaper.SetMediaItemSelected(v.code_item, true)
  reaper.Main_OnCommand(41051, 0) -- Item properties: Toggle take reverse
  reaper.SetMediaItemTakeInfo_Value( v.code_take, 'D_STARTOFFS', 0 )
end

local function CreateNewSourceForItem(v, section, take_name, take_index)
  local pcm_section = reaper.PCM_Source_CreateFromType("SECTION")
  reaper.SetMediaItemTake_Source(v.code_take, pcm_section)
  local _, chunk = reaper.GetItemStateChunk(v.code_item, "", false)
  local new_chunk   = gsub(chunk, '<SOURCE%s+.->', section .. "\n>" )
  reaper.SetItemStateChunk(v.code_item, new_chunk, true)
  reaper.GetSetMediaItemTakeInfo_String( v.code_take, 'P_NAME', take_name.." TK:"..take_index, true )
end

local function PropagateAudio(variable_take_name, section, take_name, take_index)
  for i = 1, #_G[variable_take_name] do
    local v = items_table[ _G[variable_take_name][i].item_index ]
    if v.item_lock ~= 1 then
      CreateNewSourceForItem(v, section, take_name, take_index)
      if v.mode then SetItemReverseMode(v) end
      if v.source then reaper.PCM_Source_Destroy(v.source) end
    end
  end
  reaper.Main_OnCommand(40047, 0) -- Peaks: Build any missing peaks
end

local function PropagateMIDI(variable_take_name, section, newidx)
  for i = 1, #_G[variable_take_name] do
    local v = items_table[ _G[variable_take_name][i].item_index ]
    local pcm_section = reaper.PCM_Source_CreateFromType("MIDI")
    reaper.SetMediaItemTake_Source(v.code_take, pcm_section)
    local _, chunk = reaper.GetItemStateChunk(v.code_item, "", false)
    local new_chunk   = gsub(chunk, '<SOURCE%s+.->', section .. "\n>" )
    reaper.SetItemStateChunk( v.code_item, new_chunk, true)
    reaper.GetSetMediaItemTakeInfo_String(v.code_take, 'P_NAME', v.take_name.." TK:"..format("%d", newidx), true )
    if v.source then reaper.PCM_Source_Destroy(v.source) end
  end
end

local function WaitForEnd()
  if reaper.GetPlayState() == 0 then return else reaper.defer(WaitForEnd) end
end

local function ArmTracksByGroupTimes( str_item_position )
  for i = 1, #_G[ str_item_position ] do
    reaper.Undo_BeginBlock()
    local v = items_table[ _G[str_item_position][i].item_index ]
    reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMON', 0 )
    reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECARM', 1 )
    if SafeMode == 'true' then SetReaDelayTime( v.code_track, v.item_length) end
    reaper.Undo_EndBlock("Recording: "..v.take_name, -1)
  end
end

local function ActivateRecording()
  xpcall( function()
    if idxStart == nil or idxStart > #item_start_position_table then return else
        local item_position  = item_start_position_table[idxStart].item_position
        local str_item_position = item_start_position_table[idxStart].str_item_position
        if reaper.GetPlayPosition() >= item_position - StartTime then
          if not flags[str_item_position.."ipos"] then
            flags[str_item_position.."ipos"] = true
            idxStart = idxStart + 1
            ArmTracksByGroupTimes( str_item_position )
          end
        end
      end
      if reaper.GetPlayState() == 0 then return else reaper.defer(ActivateRecording) end
    end, errorHandler)
end

local function ArmTrackMonitorGroupMIDI(str_item_position)
  for i = 1, #_G[ str_item_position ] do
    local v = items_table[ _G[str_item_position][i].item_index ]
    if v.track_rec_input >= 4096 then
      reaper.Undo_BeginBlock()
      if v.item_action == "record" or v.item_action == "monitor" then
        reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMON', 1 )
      elseif v.item_action == "record mute" then
        reaper.SetMediaTrackInfo_Value( v.code_track, 'B_MUTE', 1 )
        reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMON', 1 )
      end
      reaper.Undo_EndBlock("On Monitor: "..v.take_name, -1)
    end
  end
end

local function ArmTrackMonitorGroupAudio(str_item_position)
  for i = 1, #_G[ str_item_position ] do
    local v = items_table[ _G[str_item_position][i].item_index ]
    if v.track_rec_input < 4096 then
      reaper.Undo_BeginBlock()
      if v.item_action == "record" or v.item_action == "monitor" then
        reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMON', 1 )
      elseif v.item_action == "record mute" then
        reaper.SetMediaTrackInfo_Value( v.code_track, 'B_MUTE', 1 )
        reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMON', 1 )
      end
      reaper.Undo_EndBlock("On Monitor: "..v.take_name, -1)
    end
  end
end

local function ActivateMonitorMIDI()
  xpcall( function()
    if idxStartMonMIDI == nil or idxStartMonMIDI > #item_start_position_table then return end
    local item_position  = item_start_position_table[idxStartMonMIDI].item_position
    if reaper.GetPlayPosition() >= item_position - 0.1 then -- For MIDI Tracks
      local str_item_position = item_start_position_table[idxStartMonMIDI].str_item_position
      if not flags["monMIDI"..str_item_position] then
        flags["monMIDI"..str_item_position] = true
        idxStartMonMIDI = idxStartMonMIDI + 1
        ArmTrackMonitorGroupMIDI(str_item_position)
      end
    end
    if reaper.GetPlayState() ~= 0 then
      reaper.defer(ActivateMonitorMIDI)
    end
  end, errorHandler)
end

local function ActivateMonitorAUDIO()
  xpcall( function()
    if idxStartMonAUDIO == nil or idxStartMonAUDIO > #item_start_position_table then return end
    local item_position  = item_start_position_table[idxStartMonAUDIO].item_position
    local str_item_position = item_start_position_table[idxStartMonAUDIO].str_item_position
    if reaper.GetPlayPosition() >= item_position - 0.02 then -- For AUDIO Tracks
      if not flags["monAUDIO"..str_item_position] then
        flags["monAUDIO"..str_item_position] = true
        idxStartMonAUDIO = idxStartMonAUDIO + 1
        ArmTrackMonitorGroupAudio(str_item_position)
      end
    end
    if reaper.GetPlayState() ~= 0 then
      reaper.defer(ActivateMonitorAUDIO)
    end
  end, errorHandler)
end

local function GetNewAudioLoopToPropagate(addedItem, v)
  reaper.PreventUIRefresh(1)
  reaper.ApplyNudge( 0, 1, 1, 1, v.item_position, 0, 0 ) -- start
  reaper.ApplyNudge( 0, 1, 3, 1, v.item_end_position, 0, 0 ) -- end
  local newTake     = reaper.GetActiveTake(addedItem)
  local addedSoffs  = reaper.GetMediaItemTakeInfo_Value( newTake, 'D_STARTOFFS')
  local addedSource = reaper.GetMediaItemTake_Source( newTake )
  local filename    = reaper.GetMediaSourceFileName( addedSource, '' )
  reaper.Main_OnCommand(40547, 0) -- Item properties: Loop section of audio item source
  local _, chunk    = reaper.GetItemStateChunk(addedItem, "", false)
  local section     = match(chunk, '<SOURCE%s+.->')
  reaper.DeleteTrackMediaItem( v.code_track, addedItem )
  reaper.PreventUIRefresh(-1)
  return section, filename, addedSoffs
end

local function IsPracticeMode(filename, addedSoffs, v)
  if PracticeMode == 'false' then
    local strToStore = filename..","..addedSoffs..","..v.item_length..",AUDIO,"..v.take_name.." TK:"..GetNumForLoopTakes( v.variable_take_name) .. ",_"
    reaper.SetProjExtState(proj, v.variable_take_name, format("%03d",GetNumForLoopTakes( v.variable_take_name )), strToStore)
  else
    practice[#practice+1] = filename
  end
end

local function GetNewLoopMIDIToPropagate(addedItem, v)
  reaper.PreventUIRefresh(1)
  reaper.SetMediaItemInfo_Value( addedItem, 'B_LOOPSRC', 0)
  reaper.SplitMediaItem( addedItem, v.item_position )
  reaper.DeleteTrackMediaItem( v.code_track, addedItem )
  local item_to_propagate = reaper.GetSelectedMediaItem(0, 0)
  reaper.SplitMediaItem( item_to_propagate, v.item_end_position )
  local delSplitItem = reaper.GetSelectedMediaItem(0, 1)
  if delSplitItem then
    reaper.DeleteTrackMediaItem( v.code_track, delSplitItem )
  end
  reaper.SetMediaItemInfo_Value( item_to_propagate, 'B_LOOPSRC', 1)
  reaper.SetMediaItemSelected(item_to_propagate, true)
  local code_take  = reaper.GetActiveTake(item_to_propagate)
  local newidx = format("%03d",GetNumForLoopTakes( v.variable_take_name ))
  local _, chunk    = reaper.GetItemStateChunk(item_to_propagate, "", false)
  local section     = match(chunk, '<SOURCE%s+.->')
  reaper.PreventUIRefresh(-1)
  return section, newidx, code_take
end

local function ActionWhenFinishAudioLoopRecording(v)
    Msg('ActionWhenFinishAudioLoopRecording')
    reaper.Undo_BeginBlock()
    reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECARM', 0 )
    reaper.SelectAllMediaItems( 0, false )
    reaper.Main_OnCommand(40670, 0) -- Record: Add recorded media to project
    local addedItem = reaper.GetSelectedMediaItem(0, 0)
    if addedItem then
        if v.track_rec_input < 4096 then
            local section, filename, addedSoffs = GetNewAudioLoopToPropagate(addedItem, v)
            PropagateAudio(v.variable_take_name, section, v.take_name, GetNumForLoopTakes( v.variable_take_name ))
            IsPracticeMode(filename, addedSoffs, v)
        else
            local section, newidx, code_take = GetNewLoopMIDIToPropagate(addedItem, v)
            PropagateMIDI( v.variable_take_name, section, newidx )
            reaper.GetSetMediaItemTakeInfo_String( code_take, 'P_NAME', v.variable_take_name.." "..newidx, true )
            local strToStore = ",_,"..v.item_length..",MIDI,"..v.take_name.." TK:"..GetNumForLoopTakes( v.variable_take_name ) .. ",_"
            ExportMidiFile(v.variable_take_name.." "..newidx, code_take, v.variable_take_name, newidx, strToStore )
        end
        reaper.Undo_EndBlock("Propagate: "..v.take_name .. " TK:" .. GetNumForLoopTakes( v.variable_take_name ), -1)
    end
end

local function DeactivateRecording()
    xpcall( function()
        local pPos = reaper.GetPlayPosition()
        if idxEnd == nil or idxEnd > #item_end_position_table then return end
        local item_end_position  = item_end_position_table[idxEnd].item_end_position
        if pPos >= item_end_position-0.01 then
            Msg(item_end_position)
            local str_item_end_position = item_end_position_table[idxEnd].str_item_end_position
            Msg(str_item_end_position)
            if flags[str_item_end_position.."endRec"] then reaper.defer(DeactivateRecording) end
            Msg('Here')
            flags[str_item_end_position.."endRec"] = true
            idxEnd = idxEnd + 1
            for i = 1, #_G[ str_item_end_position ] do
                local v = items_table[ _G[str_item_end_position][i].item_index ]
                Msg(v.item_action)
                if v.item_action == "record" or v.item_action == "record mute" then
                    ActionWhenFinishAudioLoopRecording(v)
                end
            end
        end
        if reaper.GetPlayState() == 0 then return else reaper.defer(DeactivateRecording) end
        end, errorHandler)
end

local function ActionsForDeactivateMonitor(str_item_end_position, i)
    reaper.Undo_BeginBlock()
    local v = items_table[ _G[str_item_end_position][i].item_index ]
    local function rec_monitor_off() reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMON', 0 ) end
    local function track_mute_off()  reaper.SetMediaTrackInfo_Value( v.code_track, 'B_MUTE', 0 ) end
    local function track_rec_mode()  reaper.SetMediaTrackInfo_Value( v.code_track, 'I_RECMODE', 2 ) end
    if SafeMode == 'true' then
        if v.buffer == 1 then
            if v.item_action == "record" then
                if v.track_rec_input < 4096 then
                    reaper.TrackFX_SetParam( v.code_track, reaper.TrackFX_AddByName( v.code_track, 'Nabla ReaDelay', false, 0 ), 13, 1 )
                end
                rec_monitor_off()
                OffReaDelayDefer( v.str_item_end_position, v.item_end_position + BufferTime )
            elseif v.item_action == "record mute" then
                if v.track_rec_input < 4096 then
                    reaper.TrackFX_SetParam( v.code_track, reaper.TrackFX_AddByName( v.code_track, 'Nabla ReaDelay', false, 0 ), 13, 1 )
                end
                track_mute_off()
                OffReaDelayDefer( v.str_item_end_position, v.item_end_position + BufferTime )
            elseif v.item_action == "monitor" then
                rec_monitor_off()
                track_rec_mode()
            end
        else
            if v.item_action == "record" or v.item_action == "record mute" then
                rec_monitor_off()
            elseif v.item_action == "monitor" then
                rec_monitor_off()
                track_rec_mode()
            end
        end
    else
        if v.item_action == "record" then
                rec_monitor_off()
        elseif v.item_action == "record mute" then
                track_mute_off()
        elseif v.item_action == "monitor" then
                rec_monitor_off()
                track_rec_mode()
        end
    end
    reaper.Undo_EndBlock("Off Monitor: "..v.take_name, -1)
end

local function DeactivateMonitor()
    xpcall( function()
        local pPos = reaper.GetPlayPosition()
        if idxEndMon == nil or idxEndMon > #item_end_position_table then return end
        local item_end_position  = item_end_position_table[idxEndMon].item_end_position
        if pPos >= item_end_position-0.1 then
            local str_item_end_position = item_end_position_table[idxEndMon].str_item_end_position
            if flags[str_item_end_position.."endMon"] then reaper.defer(DeactivateMonitor) end
            flags[str_item_end_position.."endMon"] = true
            idxEndMon = idxEndMon + 1
            for i = 1, #_G[ str_item_end_position ] do
                ActionsForDeactivateMonitor(str_item_end_position, i)
            end
        end
        if reaper.GetPlayState() == 0 then return else reaper.defer(DeactivateMonitor) end
        end, errorHandler)
end

local function SetStartIdxs()
    for i = 1, #item_start_position_table do
        local item_position  = item_start_position_table[i].item_position
        if item_position - 0.1 > reaper.GetCursorPosition() then
            idxStart         = i
            idxStartMonMIDI  = i
            idxStartMonAUDIO = i
            break
        end
    end
end

local function SetEndIdxs()
    for i = 1, #item_end_position_table do
        local item_end_position  = item_end_position_table[i].item_end_position
        if item_end_position - 0.1 > reaper.GetCursorPosition() then
            idxEnd    = i
            idxEndMon = i
            break
        end
    end
end

local function Main()
    local playState = reaper.GetPlayState()
    if playState == 2 then return end
    CreateItemsTable()
    CreateMainTables()
    SetActionTracksConfig()
    GetSetNablaConfigs()
    SetReaperNablaOptions()
    SetPDC( PreservePDC )
    if SafeMode == "true" then xpcall( InsertReaDelay, errorHandler) end
    SetStartIdxs()
    SetEndIdxs()
    reaper.Main_OnCommand(40252, 0)
    reaper.CSurf_OnRecord()
    -- Start Defer Functions --
    ActivateRecording()
    ActivateMonitorMIDI()
    ActivateMonitorAUDIO()
    DeactivateMonitor()
    DeactivateRecording()
    WaitForEnd()
end

Main()
reaper.atexit(AtExitActions)
