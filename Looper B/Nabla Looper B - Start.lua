-- Nabla Looper Manual Mode
local version = 'v0.3'
local console = 0
local reaper = reaper
local proj = proj

function Msg(value, line)
  if console == 1 then
    reaper.ShowConsoleMsg(tostring(value))
    if line == 0 then
      -- reaper.ShowConsoleMsg()
    else
      reaper.ShowConsoleMsg("\n")
    end
  end
end

local _, _, sec, cmd, _, _, _ = reaper.get_action_context()
reaper.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
reaper.RefreshToolbar2( sec, cmd )
------------------------------------------------------------------
local match     = string.match
local gsub      = string.gsub
local gmatch    = string.gmatch
local find      = string.find
local sub       = string.sub
local lower     = string.lower
local concat    = table.concat
local insert    = table.insert

local tItemsData 	   = {}
local storedConfigs  = {}
local tSelectedTracks = {}
------------------------------------------------------------------
-- GET TRACK MODE
------------------------------------------------------------------
local recTracks = {}

local function GetTrackLoopMode(track)
  if not track then return false end
  local _, name  = reaper.GetTrackName(track)
  local name     = lower(name)
  local action   = match(name, '^%[(.-)%]')
  if not action then return false end
  return action
end

local function CreateTableRecordingTracks()
  local numTracks = reaper.GetNumTracks()
  if numTracks == 0 then return end
  for i = 0, numTracks-1 do
    local track    = reaper.GetTrack(proj, i)
    local mode     = GetTrackLoopMode(track)
    if mode then
      local _, name       = reaper.GetTrackName(track)
      local name          = match(name, '%[.-%]%s?(.*)') or name
      local trRecInput    = reaper.GetMediaTrackInfo_Value(track, 'I_RECINPUT')
      local trMonItems    = reaper.GetMediaTrackInfo_Value(track, 'I_RECMONITEMS')
      local trFreeMode    = reaper.GetMediaTrackInfo_Value(track, 'B_FREEMODE')
      recTracks[#recTracks+1] = {
        track 		 = track, 
        name  		 = name, 
        mode  		 = mode, 
        trRecInput = trRecInput, 
        trMonItems = trMonItems,
        trFreeMode = trFreeMode,
      }
    end
  end
end

local function GetSetNablaConfigs()
  local vars = {
    {	'safeMode',    'SAFE_MODE',    'true'	},
    {'linkTriggers',    'LINK_TRIGGERS',    '1'    },
    {	'preservePDC', 'PRESERVE_PDC', 'true'	},
  }
  for i=1, #vars do
    local varName = vars[i][1] 
    _G[varName] = reaper.GetExtState( 'NABLA_LOOPER_MANUAL', vars[i][2] )
    if _G[varName] == "" or _G[varName] == nil then
      reaper.SetExtState( 'NABLA_LOOPER_MANUAL', vars[i][2], vars[i][3], true )
      _G[varName] = vars[i][3]
    end
  end	
end

local function GetIDByScriptName(scriptName)
  if type(scriptName)~="string"then 
    error("expects a 'string', got "..type(scriptName),2) 
  end;
  local file = io.open(reaper.GetResourcePath()..'/reaper-kb.ini','r'); 
  if not file then 
    return -1 
  end;
  local scrName = gsub(gsub(scriptName, 'Script:%s+',''), "[%%%[%]%(%)%*%+%-%.%?%^%$]",function(s)return"%"..s;end);
  for var in file:lines() do;
    if match(var, scrName) then
      id = "_"..gsub(gsub(match(var, ".-%s+.-%s+.-%s+(.-)%s"),'"',""), "'","")
      return id
    else
    end
  end;
  return -1;
end

local function StoreSelectedTracks()
  for i = 0, reaper.CountSelectedTracks(proj)-1 do
    local cTrack = reaper.GetSelectedTrack(proj, i)
    tSelectedTracks[cTrack] = true
  end
end

local function UnselectAllTracks()
  for i = 0, reaper.GetNumTracks()-1 do
    reaper.SetMediaTrackInfo_Value(reaper.CSurf_TrackFromID(i, false), "I_SELECTED", 0)
  end
  reaper.UpdateArrange()
end

local function RestoreSelectedTracks()
  UnselectAllTracks()
  for cTrack in pairs( tSelectedTracks ) do
    reaper.SetTrackSelected( cTrack, 1)
  end
end

local function UnarmTracks()
  local numTracks = reaper.GetNumTracks()
  for i=0, numTracks-1 do
    local cTrack = reaper.GetTrack(proj, i) 
    local trRecMode = reaper.GetMediaTrackInfo_Value( cTrack, 'I_RECMODE' )
    if trRecMode ~= 2 then
      reaper.SetMediaTrackInfo_Value( cTrack, 'I_RECARM', 0 )
      reaper.SetMediaTrackInfo_Value( cTrack, 'I_RECMON', 1 )
    end
  end
end


local function SetTrackFreeMode()
  for i=1, #recTracks do
    local v = recTracks[i]
    local trRecMode = reaper.GetMediaTrackInfo_Value( v.track, 'I_RECMODE' )
    if trRecMode ~= 2 then
      reaper.SetMediaTrackInfo_Value( v.track, 'B_FREEMODE', 1 )
    end
  end
end

local function SetFXName(track, fx, new_name)
  if not new_name then return end
  local edited_line,edited_line_id, segm
  -- get ref guid
  if not track or not tonumber(fx) then return end
  local FX_GUID = reaper.TrackFX_GetFXGUID( track, fx )
  if not FX_GUID then return else FX_GUID = sub(gsub(FX_GUID,'-',''), 2,-2) end
  local plug_type = reaper.TrackFX_GetIOSize( track, fx )
  -- get chunk t
  local retval, chunk = reaper.GetTrackStateChunk( track, '', false )
  local t = {} 
  for line in gmatch(chunk, "[^\r\n]+") do t[#t+1] = line end
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
  local out_line = table.concat(t2,' ')
  t[edited_line_id] = '<'..out_line
  local out_chunk = table.concat(t,'\n')
  reaper.SetTrackStateChunk( track, out_chunk, false )
end

local function InsertReaDelay()
  reaper.Undo_BeginBlock()
  for i = 1, #recTracks do
    local v = recTracks[i]
    if v.trRecInput < 4096 then
      local isFx = reaper.TrackFX_AddByName(  v.track, 'ReaDelay', false, -1 )
      reaper.TrackFX_SetParam(  v.track, isFx, 0, 1 )
      reaper.TrackFX_SetParam(  v.track, isFx, 1, 0 )
      reaper.TrackFX_SetParam(  v.track, isFx, 4, 1 )
      reaper.TrackFX_SetParam(  v.track, isFx, 13, 0 )
      SetFXName( v.track, isFx, 'Nabla ReaDelay')
      reaper.TrackFX_CopyToTrack(  v.track, isFx,  v.track, 0, true )
    end
  end
  reaper.Undo_EndBlock("Inser ReaDelay", -1)
end

local function RemoveReaDelay()
  reaper.Undo_BeginBlock()
  for i = 1, #recTracks do
    reaper.TrackFX_Delete( recTracks[i].track, reaper.TrackFX_AddByName( recTracks[i].track, 'Nabla ReaDelay', false, 0 ) )
  end
  reaper.Undo_EndBlock("Remove ReaDelay", -1)
end

local function SetPreservePDC( set )
  reaper.Undo_BeginBlock()
  local tStrRec = {}
  for i = 1, #recTracks do
    local v = recTracks[i]
    local r, trChunk = reaper.GetTrackStateChunk( v.track, '', false)
    local strRec = match(trChunk, 'REC%s+.-%s+.-%s+.-%s+.-%s+.-%s+.-%s+.-[%\n]')
    for substring in gmatch(strRec, "%S+") do insert(tStrRec, substring) end
    local function set_pdc( str )
      local new_strRec = gsub(trChunk, 'REC%s+.-[%\n]', str, 1)
      reaper.SetTrackStateChunk( v.track, new_strRec, true)
      for k in pairs( tStrRec ) do tStrRec[k] = nil end
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
  reaper.Undo_EndBlock("Set Track PDC", -1)
end

local function SetReaperConfigs()
  local tActions = {
    { action = 41078, setstate = "off"}, -- FX: Auto-float new FX windows
    { action = 40041, setstate = "off"}, -- Options: Toggle auto-crossfades
    { action = 41117, setstate = "off"}, -- Options: Toggle trim behind items when editing
    { action = 40036, setstate = "on" }, -- View: Toggle auto-view-scroll during playback
    { action = 41817, setstate = "on" }, -- View: Continuous scrolling during playback
    { action = 41330, setstate = "__" }, -- Options: New recording splits existing items and creates new takes (default)
    { action = 41186, setstate = "__" }, -- Options: New recording trims existing items behind new recording (tape mode)
    { action = 41329, setstate = "on" }, -- Options: New recording creates new media items in separate lanes (layers)
    { action = 'trimmidionsplit', setstate = 32 },
    { action = 'opencopyprompt',  setstate = 1  },
    { action = 'stopprojlen',     setstate = 0  },
  }

  for i = 1, #tActions do
    local v = tActions[i]
    if v.action == 'trimmidionsplit' then
      local val = reaper.SNM_GetIntConfigVar( "trimmidionsplit", 0 )
      storedConfigs[i] = { action = "trimmidionsplit", state = val }
      if val ~= 1 then reaper.SNM_SetIntConfigVar( "trimmidionsplit", 1 ) end
      goto next
    elseif v.action == 'opencopyprompt' then
      local val = reaper.SNM_GetIntConfigVar( "opencopyprompt", 0 )
      storedConfigs[i] = { action = "opencopyprompt", state = val }
      if val ~= 32 then reaper.SNM_SetIntConfigVar( "opencopyprompt", 32 ) end
      goto next
    elseif v.action == "stopprojlen" then
      local val = reaper.SNM_GetIntConfigVar( "stopprojlen", 0 )
      storedConfigs[i] = { action = "stopprojlen", state = val }
      if val ~= 0 then reaper.SNM_SetIntConfigVar( "stopprojlen", 0 ) end
      goto next
    end

    local state = reaper.GetToggleCommandState( v.action )
    storedConfigs[i] = { action = v.action, state = state }
    if     state == 1 and v.setstate == 'off' then
      reaper.Main_OnCommand(v.action, 0)
    elseif state == 0 and v.setstate == "on" then
      reaper.Main_OnCommand(v.action, 0)
    end
    ::next::
  end
end

local function RestoreReaperConfigs()
  for i = 1, #storedConfigs do
    local v = storedConfigs[i]
    if v.action == "trimmidionsplit" then
      local val = reaper.SNM_GetIntConfigVar( "trimmidionsplit", 0 )
      if val ~= v.state then reaper.SNM_SetIntConfigVar( "trimmidionsplit", v.state ) end
      goto next
    elseif v.action == "opencopyprompt" then
      local val = reaper.SNM_GetIntConfigVar( "opencopyprompt", 0 )
      if val ~= v.state then reaper.SNM_SetIntConfigVar( "opencopyprompt", v.state ) end
      goto next
    elseif v.action == "stopprojlen" then
      local val = reaper.SNM_GetIntConfigVar( "stopprojlen", 0 )
      if val ~= v.state then reaper.SNM_SetIntConfigVar( "stopprojlen", v.state ) end
      goto next
    end

    local state = reaper.GetToggleCommandState( v.action )
    if v.state ~= state then
      reaper.Main_OnCommand(v.action, 0)
    end
    ::next::
  end
end

local function AtExitActions()
  local _, _, sec, cmd, _, _, _ = reaper.get_action_context()
  reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set ON
  reaper.RefreshToolbar2( sec, cmd )
  reaper.OnStopButton()
  RemoveReaDelay()
  UnarmTracks()
  RestoreReaperConfigs()
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
    "Nabla MM:      \t".. version .."\n"..
    "Reaper:      \t"..reaper.GetAppVersion().."\n"..
    "Platform:    \t"..reaper.GetOS()
  )
end

local function StoreItemDataDefer()
  xpcall( function()
    local numItems = reaper.CountMediaItems(proj)
    if numItems ~= #tItemsData then
      -- CLEAR TABLE
      for i=1,#tItemsData do tItemsData[i] = nil end
      -- UPDATE TABLE
      for i=0, numItems-1 do
        local codeItem = reaper.GetMediaItem(proj, i)
        local iPos = reaper.GetMediaItemInfo_Value(codeItem,"D_POSITION")
        local lengthItem = reaper.GetMediaItemInfo_Value(codeItem,"D_LENGTH")
        local iEnd = iPos+lengthItem
        local _, lastMeasure, _, _, _ = reaper.TimeMap2_timeToBeats( proj, iEnd )
        tItemsData[#tItemsData+1] = {
          a	= codeItem,
          c	= lengthItem,
          e	= lastMeasure-1,
        }
      end
    end
    if reaper.GetPlayState() == 0 then return else reaper.defer(StoreItemDataDefer) end
  end, errorHandler)
end

local function MainDefer()
  xpcall( function()
    for i=1, #tItemsData do
      local pPos = reaper.GetPlayPosition()
      local _, currentMeasure, _, _, _ = reaper.TimeMap2_timeToBeats( proj, pPos )
      if currentMeasure == tItemsData[i].lengthItem then
        tItemsData[i].lengthItem = currentMeasure+1
        if tItemsData[i].codeItem then
          local lengthItem = reaper.GetMediaItemInfo_Value(tItemsData[i].codeItem,"D_LENGTH")
          reaper.SetMediaItemInfo_Value(tItemsData[i].codeItem,"D_LENGTH", lengthItem+reaper.TimeMap2_beatsToTime(proj, 0, 1) )
        end
      end
    end
    local pState = reaper.GetPlayState()
    if pState == 0 then return else reaper.defer(MainDefer) end
  end, errorHandler)
end

local function main()
  local pState = reaper.GetPlayState()
  -- Msg("-- Manual Mode --", 1)
  if pState == 0 then
    if linkTriggers == 'true' then
      reaper.CSurf_OnRecord()
      local scriptName = "Script: Nabla Looper B - Main.lua"
      local idbyscript = GetIDByScriptName(scriptName)
      reaper.Main_OnCommand(reaper.NamedCommandLookup(idbyscript),0)
      -- Msg("Script: Nabla Looper Manual Trigger Actions.lua ID: " .. idbyscript, 1)
    else
      reaper.CSurf_OnPlay()
    end
    StoreItemDataDefer()
    MainDefer()
  end
end

CreateTableRecordingTracks()
StoreSelectedTracks()
xpcall(GetSetNablaConfigs, errorHandler)
xpcall(SetReaperConfigs, errorHandler)
xpcall(SetTrackFreeMode, errorHandler)
if safeMode    == 'true' then xpcall(InsertReaDelay, errorHandler) end
SetPreservePDC(preservePDC)
xpcall(RestoreSelectedTracks, errorHandler)
xpcall(main, errorHandler)
reaper.atexit( AtExitActions )
