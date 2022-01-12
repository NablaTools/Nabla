--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - ITEM Start Stop
* Version: 0.3
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]] 
--======================================================================
console = 1
title = 'Nabla Looper A - ITEM Start Stop.lua'
version = "v.0.3.0"

local info   = debug.getinfo(1,'S');
local script_path  = info.source:match[[^@?(.*[\/])[^\/]-$]]

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
------------------------------------------------------------------
-- IS PROJECT SAVED
------------------------------------------------------------------
function IsProjectSaved()
	if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then separator = "\\" else separator = "/" end
	retval, project_path_name = reaper.EnumProjects(-1, "")
	if project_path_name ~= "" then
		dir = project_path_name:match("(.*"..separator..")")
		project_saved = true
		return project_saved, dir, separator
	else
		display = reaper.ShowMessageBox("You need to save the project to execute Nabla Looper.", "File Export", 1)
		if display == 1 then
			reaper.Main_OnCommand(40022, 0) -- SAVE AS PROJECT
			return IsProjectSaved()
		end
	end
end

saved, dir, sep = IsProjectSaved()

------------------------------------------------------------------
-- SET ON TOGGLE COMMAND STATE
------------------------------------------------------------------
local function setActionState(state)
	local _, _, sec, cmd, _, _, _ = reaper.get_action_context()
	reaper.SetToggleCommandState( sec, cmd, state )
	reaper.RefreshToolbar2( sec, cmd )
end

setActionState(1)
------------------------------------------------------------------
-- VARIABLES AND TABLES
------------------------------------------------------------------
local format    = string.format
local match     = string.match
local gsub      = string.gsub
local gmatch    = string.gmatch
local find      = string.find
local sub       = string.sub
local concat    = table.concat
local insert    = table.insert
local items      = {}
local recTracks  = {}
local flags      = {}
local startTimes = {}
local endTimes   = {}
local practice   = {}
local originalConfigs = {}
local recItems   = {}
local selected = false -- new notes are selected
------------------------------------------------------------------
-- GET/SET EXT STATES
------------------------------------------------------------------
local function GetSetNablaConfigs()
	local vars = { 
		{'safeMode',    'SAFE_MODE',    'true'  }, 
		{'startTime',   'START_TIME',   '1'     }, 
		{'bufferTime',  'BUFFER_TIME',  '1'     },
		{'preservePDC', 'PRESERVE_PDC', 'true'  }, 
		{'performance', 'PERFORMANCE',  '1'     }, 
		{'recordFdbk',  'RECORD_FDBK',  '3'     }, 
		{'recColor',    'REC_COLOR',    '1,0,0' }, 
		{'monColor',    'MON_COLOR',    '0,0,1' }, 
		{'tkMrkColor',  'TKMRK_COLOR',  '0,1,0' },
		{'practiceMode','PRACTICE_MODE', 'false' },
	}
	for i = 1, #vars do
		local varName = vars[i][1]
		local section = vars[i][2]
		local id      = vars[i][3]
		_G[varName] = reaper.GetExtState( 'NABLA_LOOPER_A', section )
		if _G[varName] == "" or _G[varName] == nil then
			reaper.SetExtState( 'NABLA_LOOPER_A', section, id, true )
			_G[varName] = id
		end
	end
end

local function GetItemType( item, getsectiontype ) -- MediaItem* item, boolean* getsectiontype
	local take   = reaper.GetActiveTake(item)
	if not take then return false, "UNKNOW" end
	local source = reaper.GetMediaItemTake_Source(take)
	local sourceType = reaper.GetMediaSourceType(source, "")
	-- Return: boolean isSection, if getsectiontype then return string SECTION TYPE, if not then return "SECTION".
	if sourceType ~= "SECTION" then
		return false, sourceType
	else
		if not getsectiontype then
			return true, sourceType
		else
			local r, chunk = reaper.GetItemStateChunk(item, "", false)
			for sourceType in  gmatch(chunk, '<SOURCE%s+(.-)[\r]-[%\n]') do
				if sourceType ~= "SECTION" then
					return true, sourceType
				end
			end
		end
	end
end

local function GetItemAction(codeItem)
	local retval, action = reaper.GetSetMediaItemInfo_String(codeItem, 'P_EXT:ITEM_ACTION', '', false)
	if retval then 
		return action 
	else
		return ''
	end
end

------------------------------------------------------------------
-- TABLA ALL ITEMS
------------------------------------------------------------------
local function CreateTableAllItems()
	local count = reaper.CountMediaItems(proj)
	for i = 0, count - 1 do
		local codeItem           = reaper.GetMediaItem(proj, i)
		local section, itemType   = GetItemType( codeItem, true )
		if itemType ~= "UNKNOW" and itemType ~= "RPP_PROJECT" and itemType ~= "VIDEO" and itemType ~= "CLICK" and itemType ~= "LTC" and itemType ~= "VIDEOEFFECT" then
			local itemStart       = tonumber(format("%.3f", reaper.GetMediaItemInfo_Value(codeItem,"D_POSITION")))
			local itemStartStr    = "i"..gsub(tostring(itemStart), "%.+","")
			local itemLength      = reaper.GetMediaItemInfo_Value(codeItem,"D_LENGTH")
			local itemEnd         = tonumber(format("%.3f", itemStart+itemLength))
			local itemEndStr      = "o"..gsub(tostring(itemEnd), "%.+","")
			local action          = GetItemAction(codeItem)
			local codeTake        = reaper.GetActiveTake( codeItem )
			local name            = reaper.GetTakeName( codeTake )
			local subTkName       = match(name, '(.-)%sTK:%d+$')
			local tkName          = subTkName or name
			local sTkName         = tkName:gsub("%s+", "")
			local tkIdx           = match(tkName, '%d+$')
			local codeTrack          = reaper.GetMediaItem_Track( codeItem )
			local trRecInput      = reaper.GetMediaTrackInfo_Value(codeTrack, 'I_RECINPUT')
			local trRecMode       = reaper.GetMediaTrackInfo_Value( codeTrack, 'I_RECMODE' )
			local itemLock        = reaper.GetMediaItemInfo_Value( codeItem, 'C_LOCK')
			local source                             = reaper.GetMediaItemTake_Source(codeTake)
			local _, _, _, mode = reaper.PCM_Source_GetSectionInfo( source )
			items[#items+1] = {
				codeItem     = codeItem, 
				itemStart    = itemStart, 
				itemEnd      = itemEnd, 
				itemStartStr = itemStartStr, 
				itemEndStr   = itemEndStr,
				action       = action,
				itemLength   = itemLength, 
				codeTake     = codeTake, 
				tkName       = tkName, 
				tkIdx        = tkIdx,
				codeTrack    = codeTrack,
				trRecInput   = trRecInput, 
				sTkName      = sTkName, 
				buffer       = 0,
				record       = 0,
				mode         = mode,
				trRecMode    = trRecMode,
				itemType     = itemType,
				itemLock     = itemLock,
				section      = section,
				source       = source,
			}
		end
	end
	table.sort(items, function(a,b) return a.itemStart < b.itemStart end) 
end

------------------------------------------------------------------
-- SET BUFFER, CREATE TABLE TRIGGERS, SET RECORD TRACK CONFIGS
------------------------------------------------------------------

local function AddToRecordingItemsTable(i, v)
	recItems[#recItems+1] = {idx = i, itemStart = v.itemStart, itemEnd = v.itemEnd}
end

local function SetIfBuffer(m, v)
	if v.tkName == m.tkName then
		if m.itemStart >= v.itemEnd-0.1 and m.itemStart <= v.itemEnd+0.1 then
			v.buffer = 1
		end
	end
end

local function AddToGroupItemsByNameTable(v)
	flags[v.sTkName] = true
	_G[ v.sTkName ] = {}
	for j = 1, #items do
		local m = items[j]
		if v.tkName == m.tkName then
			_G[ v.sTkName ][ #_G[ v.sTkName ] + 1 ] = {idx = j }
		end
	end
end

local function AddToStartTimesTable()
	for i = 1, #startTimes do
		local itemStart  = startTimes[i].itemStart
		local itemStartStr = startTimes[i].itemStartStr
		_G[ itemStartStr ] = {}
		for j = 1, #items do
			if items[j].action ~= "0" and items[j].action ~= "" then
				if itemStart == items[j].itemStart then
					_G[ itemStartStr ][ #_G[ itemStartStr ] + 1 ] = { idx = j }
				end
			end
		end
	end
	-- Debug startTimes Tables
	for i = 1, #startTimes do
		local itemStartStr = startTimes[i].itemStartStr
		Msg( "At start position: "..startTimes[i].itemStart, 0 )
		for j = 1, #_G[ itemStartStr ] do
			local index = items[ _G[itemStartStr][j].idx ]
			Msg( "--> Arm: "..index.tkName, 0 )
		end
	end
end

local function AddToEndTimesTable(v)
	for i = 1, #endTimes do
		local itemEnd  = endTimes[i].itemEnd
		local itemEndStr = endTimes[i].itemEndStr
		_G[ itemEndStr ] = {}
		for j = 1, #items do
			if items[j].action ~= "0" and items[j].action ~= "" then
				if itemEnd == items[j].itemEnd then
					_G[ itemEndStr ][ #_G[ itemEndStr ] + 1 ] = { idx = j }
				end
			end
		end
	end
	-- Debug endTimes Tables
	for i = 1, #endTimes do
		local itemEndStr = endTimes[i].itemEndStr
		Msg( "At end position: "..endTimes[i].itemEnd, 0 )
		for j = 1, #_G[ itemEndStr ] do
			local index = items[ _G[itemEndStr][j].idx ]
			Msg( "--> Unarm: "..index.tkName, 0 )
		end
	end
end

local function AddToActionTimesTable(i, v)
	if not flags["sta"..v.itemStart] then
		flags["sta"..v.itemStart] = true
		startTimes[ #startTimes + 1 ]  = {idx = i, itemStartStr = v.itemStartStr, itemStart = v.itemStart } 
	end
	if not flags["end"..v.itemEnd] then
		flags["end"..v.itemEnd] = true
		endTimes[ #endTimes + 1 ] = {idx = i, itemEndStr = v.itemEndStr, itemEnd = v.itemEnd }
	end
end

local function AddToActionTracksTable(v)
	if not flags[v.codeTrack] then
		flags[v.codeTrack] = true
		recTracks[ #recTracks + 1 ] = { codeTrack = v.codeTrack, trRecInput = v.trRecInput, trRecMode = v.trRecMode, action = v.action}
	end
end

local function CreateActionsTables()
	for i = 1, #items do
		local v = items[i]
		if v.action ~= '' then 
			if v.action ~= 'monitor' then AddToRecordingItemsTable(i, v) end
			AddToActionTracksTable(v)
			AddToActionTimesTable(i, v)
			for j = 1, #items do
				local m = items[j]
				SetIfBuffer(m, v)
				if not flags[v.sTkName] then AddToGroupItemsByNameTable(v, m, j) end
			end
		end
	end
	table.sort(startTimes, function(a,b) return a.itemStart < b.itemStart end) 
	table.sort(endTimes, function(a,b) return a.itemEnd < b.itemEnd end) 
	table.sort(recItems, function(a,b) return a.itemStart < b.itemStart end)
	AddToStartTimesTable()
	AddToEndTimesTable()
end

local function prepareRecordTrack(v)
	if v.trRecMode >= 7 and v.trRecMode <= 9 or v.trRecMode == 16 then
		reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMODE', 0 )
	end       
	reaper.SetMediaTrackInfo_Value( v.codeTrack, 'B_FREEMODE', 0 )
	reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMONITEMS', 1 )
	reaper.SetMediaTrackInfo_Value( v.codeTrack , 'I_RECMON', 0 )
	reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECARM', 0 )
end

local function prepareRecordMuteTrack(v)
	if v.trRecMode ~= 0 then
		reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMODE', 0 )
	end       
	reaper.SetMediaTrackInfo_Value( v.codeTrack, 'B_FREEMODE', 0 )
	reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMONITEMS', 1 )
	reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECARM', 0 )
end

local function prepareMonitorTrack(v)
	reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMODE', 2 )
	reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 0 )
	reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECARM', 1 )
end

local function SetActionTracksConfig()
	for i = 1, #recTracks do
		local v = recTracks[i]
		if v.action == 'record' then
			prepareRecordTrack(v)
		elseif v.action == 'record mute' then
			prepareRecordMuteTrack(v)
		end
		if v.action == 'monitor' then
			prepareMonitorTrack(v)
		end
	end
end

----------------------------------------------------------------
-- SET/RESTORE REAPER DAW CONFIGS
------------------------------------------------------------------
local function SetReaperConfigs()
	local tActions = {
		{ action = 40036, setstate = "on" }, -- View: Toggle auto-view-scroll during playback
		{ action = 41817, setstate = "on" }, -- View: Continuous scrolling during playback
		{ action = 41078, setstate = "off" }, -- FX: Auto-float new FX windows
		{ action = 40041, setstate = "off"}, -- Options: Toggle auto-crossfades
		{ action = 41117, setstate = "off"}, -- Options: Toggle trim behind items when editing
		{ action = 41330, setstate = "__" }, -- Options: New recording splits existing items and creates new takes (default)
		{ action = 41186, setstate = "__" }, -- Options: New recording trims existing items behind new recording (tape mode)
		{ action = 41329, setstate = "on" }, -- Options: New recording creates new media items in separate lanes (layers)
	}
	for i = 1, #tActions do
		local v = tActions[i]
		local state = reaper.GetToggleCommandState( v.action )
		originalConfigs[i] = { action = v.action, state = state }
		if state == 1 and v.setstate == 'off' then
			reaper.Main_OnCommand(v.action, 0)
		elseif state == 0 and v.setstate == "on" then
			reaper.Main_OnCommand(v.action, 0)
		end
	end
end

local function RestoreConfigs()
	for i = 1, #originalConfigs do
		local v = originalConfigs[i]
		local state = reaper.GetToggleCommandState( v.action )
		if v.state ~= state then
			reaper.Main_OnCommand(v.action, 0)
		end
	end
end

local function GetIDByScriptName(scriptName)
	local file = io.open(reaper.GetResourcePath()..'/reaper-kb.ini','r'); 
	if not file then return -1 end
	local scrName = gsub(gsub(scriptName, 'Script:%s+',''), "[%%%[%]%(%)%*%+%-%.%?%^%$]",function(s)return"%"..s;end);
	for var in file:lines() do;
		if match(var, scrName) then
			local id = "_" .. gsub(gsub(match(var, ".-%s+.-%s+.-%s+(.-)%s"),'"',""), "'","")
			return id
		end
	end
	return -1
end

-- Modified from X-Raym's action: Insert CC linear ramp events between selected ones if consecutive
local function GetCC(take, cc)
	return cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3
end

local function ExportMidiFile(take_name, take, sTkName, newidx, strToStore) -- local (i, j, item, take, track)
	if dir == "" then return end
	local src = reaper.GetMediaItemTake_Source(take)
	local retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
	if ccs > 0 then
		local midi_cc = {}
		for j = 0, ccs - 1 do
			local cc = {}
			retval, cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3 = reaper.MIDI_GetCC(take, j)
			if not midi_cc[cc.msg2] then midi_cc[cc.msg2] = {} end
			table.insert(midi_cc[cc.msg2], cc)
		end
		local cc_events = {}
		local cc_events_len = 0
		for key, val in pairs(midi_cc) do
			for k = 1, #val - 1 do
				a_selected, a_muted, a_ppqpos, a_chanmsg, a_chan, a_msg2, a_msg3 = GetCC(take, val[k])
				b_selected, b_muted, b_ppqpos, b_chanmsg, b_chan, b_msg2, b_msg3 = GetCC(take, val[k+1])
				local interval = (b_ppqpos - a_ppqpos) / 32  -- CHANGED FROM ORIGINAL, so it just puts points every 32 ppq
				local time_interval = (b_ppqpos - a_ppqpos) / interval
				for z = 1, interval - 1 do
					local cc_events_len = cc_events_len + 1
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
		for i, cc in ipairs(cc_events) do
			reaper.MIDI_InsertCC(take, selected, false, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3)
		end
	end

	local audio = { "midi", "MIDI", "Midi", "Audio", "audio", "AUDIO", "Media", "media", "MEDIA", ""}
	for i = 1, #audio do
		local fn = dir..audio[i]..sep..take_name..".mid"
		retval = reaper.CF_ExportMediaSource(src, fn)
		if retval == true then 
			if practiceMode == 'false' then
				reaper.SetProjExtState(proj, sTkName, newidx, fn..strToStore) 
				break 
			else
				practice[#practice+1] = fn
				break 
			end
		end
	end
	local mediaItemTake = reaper.GetMediaItemTake_Item(take)
	local mediaItemTrack = reaper.GetMediaItem_Track(mediaItemTake)
	reaper.DeleteTrackMediaItem(mediaItemTrack, mediaItemTake )
end

local function SetFXName(track, fx, new_name)
	if not new_name then return end
	local edited_line,edited_line_id, segm
	if not track or not tonumber(fx) then return end
	local FX_GUID = reaper.TrackFX_GetFXGUID( track, fx )
	if not FX_GUID then return else FX_GUID = sub(gsub(FX_GUID,'-',''), 2,-2) end
	local plug_type = reaper.TrackFX_GetIOSize( track, fx )
	local retval, chunk = reaper.GetTrackStateChunk( track, '', false )
	local t = {} for line in gmatch(chunk, "[^\r\n]+") do t[#t+1] = line end
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
	reaper.SetTrackStateChunk( track, out_chunk, false )
end

local function InsertReaDelay()
	reaper.Undo_BeginBlock()
	for i = 1, #recTracks do
		local v = recTracks[i]
		if v.action ~= 'monitor' then
			if v.trRecInput < 4096 then
				local isFx = reaper.TrackFX_AddByName( v.codeTrack, 'ReaDelay', false, -1000 )
				reaper.TrackFX_SetParam( v.codeTrack, isFx, 0, 1 )
				reaper.TrackFX_SetParam( v.codeTrack, isFx, 1, 0 )
				reaper.TrackFX_SetParam( v.codeTrack, isFx, 13, 0 )
				SetFXName(v.codeTrack, isFx, 'Nabla ReaDelay')
			end
		end
	end
	reaper.Undo_EndBlock("Insert Nabla ReaDelay", -1)
end

local function SetPDC( set )
	reaper.Undo_BeginBlock()
	local tableStringRec = {}
	for i = 1, #recTracks do
		local v = recTracks[i]
		if v.action ~= 'monitor' then
			local r, trChunk = reaper.GetTrackStateChunk(v.codeTrack, '', false)
			local strRec = match(trChunk, 'REC%s+.-[%\n]')
			for substring in gmatch(strRec, "%S+") do insert(tableStringRec, substring) end

			local function set_pdc( str )
				local new_strRec = gsub(trChunk, 'REC%s+.-[%\n]', str, 1)
				reaper.SetTrackStateChunk(v.codeTrack, new_strRec, true)
				for j = 1, #tableStringRec do tableStringRec[j] = nil end
			end

			if set == 'true' then
				tableStringRec[7] = "1"
				local new_strRec = concat(tableStringRec, " ")
				set_pdc( new_strRec )
			else
				tableStringRec[7] = "0"
				local new_strRec = concat(tableStringRec, " ")
				set_pdc( new_strRec )
			end
		end
	end
	reaper.Undo_EndBlock("--> START ARRANGED MODE", -1)
end

local function RemoveReaDelay()
	for i = 1, #recTracks do
		local v = recTracks[i]
		if v.trRecInput < 4096 then
			reaper.TrackFX_Delete( v.codeTrack, reaper.TrackFX_AddByName( v.codeTrack, 'Nabla ReaDelay', false, 0 ) )
		end
	end
end

local function GetNumForLoopTakes( codeTake )
	local newKey = 0
	for i = 0, 1000 do
		local retval, key, val = reaper.EnumProjExtState( 0, codeTake, i )
		if retval == false then return tonumber(newKey) + 1 end
		newKey = key
	end
end

local function restoreRecordTracks()
	for i = 1, #recTracks do
		local v = recTracks[i]
		if v.trRecMode ~= 2 then
			reaper.SetMediaTrackInfo_Value( v.codeTrack , 'I_RECMON', 1 )
			reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMODE', v.trRecMode )
			reaper.SetMediaTrackInfo_Value( v.codeTrack,  'I_RECARM', 0 )
		end
	end
end

local function callClearScript()
	for j = 1, #practice do os.remove(practice[j]) end
	local scriptName = "Script: Nabla Looper A - ITEM Clear.lua"
	local idbyscript = GetIDByScriptName(scriptName)
	reaper.Main_OnCommand(reaper.NamedCommandLookup(idbyscript),0)
end

local function AtExitActions()
	reaper.Undo_BeginBlock()
	reaper.OnStopButton()
	reaper.Main_OnCommand(40345, 0) -- Send all notes off to all MIDI outputs/plug-ins
	setActionState(0)
	restoreRecordTracks()
	if practiceMode == "true" then callClearScript() end
	if safeMode == "true" then RemoveReaDelay() end
	RestoreConfigs()
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

local function SetReaDelayTime(codeTrack, itemLength, trRecInput)
	reaper.TrackFX_SetParam( codeTrack, reaper.TrackFX_AddByName( codeTrack, 'Nabla ReaDelay', false, 0 ), 4, (reaper.TimeMap_timeToQN_abs( 0, itemLength )*2)/256 )
end

local function OnReaDelay(codeTrack)
	reaper.TrackFX_SetParam( codeTrack, reaper.TrackFX_AddByName( codeTrack, 'Nabla ReaDelay', false, 0 ), 13, 1 )
end

local function OffReaDelayDefer(itemEndStr, redItemEnd)
	xpcall( function()
		if itemEndStr then
			newsiEnd = itemEndStr
			sredItemEnd = redItemEnd
		end
		if reaper.GetPlayPosition() > sredItemEnd then
			for i = 1, #_G[ newsiEnd ] do
				reaper.Undo_BeginBlock()
				local v = items[ _G[newsiEnd][i].idx ]
				if v.buffer == 1 then
					reaper.TrackFX_SetParam( v.codeTrack, reaper.TrackFX_AddByName( v.codeTrack, 'Nabla ReaDelay', false, 0 ), 13, 0 )
				end
				reaper.Undo_EndBlock("End Buffer: " .. v.tkName, -1)
			end
			return
		end
		if reaper.GetPlayState() == 0 then return else reaper.defer(OffReaDelayDefer) end
	end, errorHandler)
end

local function SetItemReverseMode(v)
	reaper.SelectAllMediaItems(proj, false)
	reaper.SetMediaItemSelected(v.codeItem, true)
	reaper.Main_OnCommand(41051, 0) -- Item properties: Toggle take reverse
	reaper.SetMediaItemTakeInfo_Value( v.codeTake, 'D_STARTOFFS', 0 )
end

local function CreateNewSourceForItem(v, section, tkName, tkIdx)
	local pcm_section = reaper.PCM_Source_CreateFromType("SECTION")
	reaper.SetMediaItemTake_Source(v.codeTake, pcm_section)
	local r, chunk = reaper.GetItemStateChunk(v.codeItem, "", false) 
	local new_chunk   = gsub(chunk, '<SOURCE%s+.->', section .. "\n>" )
	reaper.SetItemStateChunk(v.codeItem, new_chunk, true) 
	reaper.GetSetMediaItemTakeInfo_String( v.codeTake, 'P_NAME', tkName.." TK:"..tkIdx, true )
end

local function PropagateAudio(sTkName, section, tkName, tkIdx)
	for i = 1, #_G[sTkName] do
		local v = items[ _G[sTkName][i].idx ]
		if v.itemLock ~= 1 then
			CreateNewSourceForItem(v, section, tkName, tkIdx)
			if v.mode then SetItemReverseMode(v) end
			if v.source then reaper.PCM_Source_Destroy(v.source) end
		end
	end
	reaper.Main_OnCommand(40047, 0) -- Peaks: Build any missing peaks
end

local function PropagateMIDI(sTkName, section, newidx)
	for i = 1, #_G[sTkName] do
		local v = items[ _G[sTkName][i].idx ]
		local pcm_section = reaper.PCM_Source_CreateFromType("MIDI")
		reaper.SetMediaItemTake_Source(v.codeTake, pcm_section)
		local r, chunk = reaper.GetItemStateChunk(v.codeItem, "", false) 
		local new_chunk   = gsub(chunk, '<SOURCE%s+.->', section .. "\n>" )
		reaper.SetItemStateChunk( v.codeItem, new_chunk, true)
		reaper.GetSetMediaItemTakeInfo_String(v.codeTake, 'P_NAME', v.tkName.." TK:"..format("%d", newidx), true )
		if v.source then reaper.PCM_Source_Destroy(v.source) end
	end
end

local function WaitForEnd()
	if reaper.GetPlayState() == 0 then return else reaper.defer(WaitForEnd) end
end

local function ArmTracksByGroupTimes( itemStartStr )
	for i = 1, #_G[ itemStartStr ] do
		reaper.Undo_BeginBlock()
		local v = items[ _G[itemStartStr][i].idx ]
		reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 0 )
		reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECARM', 1 )
		if safeMode == 'true' then SetReaDelayTime( v.codeTrack, v.itemLength, v.trRecInput) end
		reaper.Undo_EndBlock("Recording: "..v.tkName, -1)
	end
end

local function ActivateRecording()
	xpcall( function()
		if idxStart == nil or idxStart > #startTimes then 
			return 
		else
			local itemStart  = startTimes[idxStart].itemStart
			local itemStartStr = startTimes[idxStart].itemStartStr
			if reaper.GetPlayPosition() >= itemStart - startTime then 
				if not flags[itemStartStr.."ipos"] then
					flags[itemStartStr.."ipos"] = true
					idxStart = idxStart + 1
					ArmTracksByGroupTimes( itemStartStr )
				end
			end
		end
		if reaper.GetPlayState() == 0 then return else reaper.defer(ActivateRecording) end
	end, errorHandler)
end

local function ArmTrackMonitorGroupMIDI(itemStartStr)
	for i = 1, #_G[ itemStartStr ] do
		local v = items[ _G[itemStartStr][i].idx ]
		if v.trRecInput >= 4096 then
			reaper.Undo_BeginBlock()
			if v.action == 'record' or v.action == 'monitor' then
				reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 1 )
			elseif v.action == 'record mute' then
				reaper.SetMediaTrackInfo_Value( v.codeTrack, 'B_MUTE', 1 )
				reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 1 )
			end
			reaper.Undo_EndBlock("On Monitor: "..v.tkName, -1)
		end
	end
end

local function ArmTrackMonitorGroupAudio(itemStartStr)
	for i = 1, #_G[ itemStartStr ] do
		local v = items[ _G[itemStartStr][i].idx ]
		if v.trRecInput < 4096 then
			reaper.Undo_BeginBlock()
			if v.action == 'record' or v.action == 'monitor' then
				reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 1 )
			elseif v.action == 'record mute' then
				reaper.SetMediaTrackInfo_Value( v.codeTrack, 'B_MUTE', 1 )
				reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 1 )
			end
			reaper.Undo_EndBlock("On Monitor: "..v.tkName, -1)
		end
	end
end

local function ActivateMonitorMIDI()
	xpcall( function()
		if idxStartMonMIDI == nil or idxStartMonMIDI > #startTimes then return end
		local itemStart  = startTimes[idxStartMonMIDI].itemStart
		if reaper.GetPlayPosition() >= itemStart - 0.1 then -- For MIDI Tracks
			local itemStartStr = startTimes[idxStartMonMIDI].itemStartStr
			if not flags["monMIDI"..itemStartStr] then
				flags["monMIDI"..itemStartStr] = true 
				idxStartMonMIDI = idxStartMonMIDI + 1
				ArmTrackMonitorGroupMIDI(itemStartStr)
			end
		end
		if reaper.GetPlayState() == 0 then return else reaper.defer(ActivateMonitorMIDI) end
	end, errorHandler)
end

local function ActivateMonitorAUDIO()
	xpcall( function()
		if idxStartMonAUDIO == nil or idxStartMonAUDIO > #startTimes then return end
		local itemStart  = startTimes[idxStartMonAUDIO].itemStart
		local itemStartStr = startTimes[idxStartMonAUDIO].itemStartStr
		if reaper.GetPlayPosition() >= itemStart - 0.02 then -- For AUDIO Tracks
			if not flags["monAUDIO"..itemStartStr] then 
				flags["monAUDIO"..itemStartStr] = true
				idxStartMonAUDIO = idxStartMonAUDIO + 1
				ArmTrackMonitorGroupAudio(itemStartStr)
			end
		end
		if reaper.GetPlayState() == 0 then return else reaper.defer(ActivateMonitorAUDIO) end
	end, errorHandler)
end

local function WorkWithNewAudioLoop(v, addedItem)
	reaper.PreventUIRefresh(1)
	reaper.ApplyNudge( 0, 1, 1, 1, v.itemStart, 0, 0 ) -- start
	reaper.ApplyNudge( 0, 1, 3, 1, v.itemEnd, 0, 0 ) -- end
	local newTake     = reaper.GetActiveTake(addedItem)
	local addedSoffs  = reaper.GetMediaItemTakeInfo_Value( newTake, 'D_STARTOFFS')
	local addedSource = reaper.GetMediaItemTake_Source( newTake )
	local filename    = reaper.GetMediaSourceFileName( addedSource, '' )
	reaper.Main_OnCommand(40547, 0) -- Item properties: Loop section of audio item source
	local r, chunk    = reaper.GetItemStateChunk(addedItem, "", false)
	local section     = match(chunk, '<SOURCE%s+.->')
	reaper.DeleteTrackMediaItem( v.codeTrack, addedItem )
	reaper.PreventUIRefresh(-1)
	PropagateAudio(v.sTkName, section, v.tkName, GetNumForLoopTakes( v.sTkName ))
	if practiceMode == 'false' then
		local strToStore = filename..","..addedSoffs..","..v.itemLength..",AUDIO,"..v.tkName.." TK:"..GetNumForLoopTakes( v.sTkName) .. ",_"
		reaper.SetProjExtState(proj, v.sTkName, format("%03d",GetNumForLoopTakes( v.sTkName )), strToStore)
	else
		practice[#practice+1] = filename
	end
end

local function WorkWithNewMIDILoop(v, addedItem)
	reaper.PreventUIRefresh(1)
	reaper.SetMediaItemInfo_Value( addedItem, 'B_LOOPSRC', 0) 
	reaper.SplitMediaItem( addedItem, v.itemStart )
	reaper.DeleteTrackMediaItem( v.codeTrack, addedItem )
	local addedItem = reaper.GetSelectedMediaItem(0, 0)
	reaper.SplitMediaItem( addedItem, v.itemEnd )
	local delSplitItem = reaper.GetSelectedMediaItem(0, 1)
	if delSplitItem then
		reaper.DeleteTrackMediaItem( v.codeTrack, delSplitItem ) 
	end
	reaper.SetMediaItemInfo_Value( addedItem, 'B_LOOPSRC', 1)
	reaper.SetMediaItemSelected(addedItem, true)
	local codeTake  = reaper.GetActiveTake(addedItem)
	local newidx = format("%03d",GetNumForLoopTakes( v.sTkName ))
	local r, chunk    = reaper.GetItemStateChunk(addedItem, "", false)
	local section     = match(chunk, '<SOURCE%s+.->')
	PropagateMIDI( v.sTkName, section, newidx ) 
	reaper.GetSetMediaItemTakeInfo_String( codeTake, 'P_NAME', v.sTkName.." "..newidx, true )
	local strToStore = ",_,"..v.itemLength..",MIDI,"..v.tkName.." TK:"..GetNumForLoopTakes( v.sTkName ) .. ",_"
	ExportMidiFile(v.sTkName.." "..newidx, codeTake, v.sTkName, newidx, strToStore )
	reaper.PreventUIRefresh(-1)
end

local function AddNewLoop(v)
	reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECARM', 0 )
	reaper.SelectAllMediaItems( 0, false )
	reaper.Main_OnCommand(40670, 0) -- Record: Add recorded media to project
	return reaper.GetSelectedMediaItem(0, 0)
end

local function DeactivateRecording()
	xpcall( function()
		local pPos = reaper.GetPlayPosition()
		if idxEnd == nil or idxEnd > #endTimes then return end
		local itemEnd  = endTimes[idxEnd].itemEnd
		if pPos >= itemEnd-0.01 then 
			local itemEndStr = endTimes[idxEnd].itemEndStr
			if not flags[itemEndStr.."endRec"] then flags[itemEndStr.."endRec"] = true
				idxEnd = idxEnd + 1
				for i = 1, #_G[ itemEndStr ] do
					reaper.Undo_BeginBlock()
					local v = items[ _G[itemEndStr][i].idx ]
					if v.action == 'record' or v.action == 'record mute' then
						local addedItem = AddNewLoop(v)
						if addedItem then
							if v.trRecInput < 4096 then
								WorkWithNewAudioLoop(v, addedItem)
							else
								WorkWithNewMIDILoop(v, addedItem)
							end
						end
						reaper.Undo_EndBlock("Propagate: "..v.tkName .. " TK:" .. GetNumForLoopTakes( v.sTkName ), -1)
					end
				end
			end
		end
		if reaper.GetPlayState() == 0 then return else reaper.defer(DeactivateRecording) end
	end, errorHandler) 
end

local function DeactivateMonitor()
	xpcall( function()
		local pPos = reaper.GetPlayPosition()
		if idxEndMon == nil or idxEndMon > #endTimes then return end
		local itemEnd  = endTimes[idxEndMon].itemEnd
		------------------------------------------------------------------
		if pPos >= itemEnd-0.1 then 
			local itemEndStr = endTimes[idxEndMon].itemEndStr
			if not flags[itemEndStr.."endMon"] then
				flags[itemEndStr.."endMon"] = true
				idxEndMon = idxEndMon + 1
				for i = 1, #_G[ itemEndStr ] do
					reaper.Undo_BeginBlock()
					local v = items[ _G[itemEndStr][i].idx ]
					if safeMode == 'true' then
						if v.buffer == 1 then
							if v.action == 'record' then
								if v.trRecInput < 4096 then
									reaper.TrackFX_SetParam( v.codeTrack, reaper.TrackFX_AddByName( v.codeTrack, 'Nabla ReaDelay', false, 0 ), 13, 1 )
								end
								reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 0 )
								OffReaDelayDefer( v.itemEndStr, v.itemEnd + bufferTime, v.codeTrack )
							elseif v.action == 'record mute' then
								if v.trRecInput < 4096 then
									reaper.TrackFX_SetParam( v.codeTrack, reaper.TrackFX_AddByName( v.codeTrack, 'Nabla ReaDelay', false, 0 ), 13, 1 )
								end
								reaper.SetMediaTrackInfo_Value( v.codeTrack, 'B_MUTE', 0 )
								OffReaDelayDefer( v.itemEndStr, v.itemEnd + bufferTime, v.codeTrack )
							elseif v.action == 'monitor' then
								reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 0 )
								reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMODE', 2 )
							end
						else
							if v.action == 'record' or v.action == 'record mute' then
								reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 0 )
							elseif v.action == 'monitor' then
								reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 0 )
								reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMODE', 2 )
							end
						end
					else
						if v.action == 'record' then
							reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 0 )
						elseif v.action == 'record mute' then
							reaper.SetMediaTrackInfo_Value( v.codeTrack, 'B_MUTE', 0 )
						elseif v.action == 'monitor' then
							reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMON', 0 )
							reaper.SetMediaTrackInfo_Value( v.codeTrack, 'I_RECMODE', 2 )
						end
					end
					reaper.Undo_EndBlock("Off Monitor: "..v.tkName, -1)
				end
			end
		end
		------------------------------------------------------------------
		if reaper.GetPlayState() == 0 then return else reaper.defer(DeactivateMonitor) end
	end, errorHandler) 
end

local function Main()
	local pState = reaper.GetPlayState()
	if pState ~= 5 then
		CreateTableAllItems()
		CreateActionsTables()
		SetActionTracksConfig()
		GetSetNablaConfigs()
		SetReaperConfigs()
		SetPDC( preservePDC )
		if safeMode == "true" then xpcall( InsertReaDelay, errorHandler) end
		------------------------------------------------------------------
		for i = 1, #startTimes do
			local itemStart  = startTimes[i].itemStart
			if itemStart - 0.1 > reaper.GetCursorPosition() then
				idxStart         = i
				idxStartMonMIDI  = i
				idxStartMonAUDIO = i
				break
			end
		end
		------------------------------------------------------------------
		for i = 1, #endTimes do
			local itemEnd  = endTimes[i].itemEnd
			if itemEnd - 0.1 > reaper.GetCursorPosition() then
				idxEnd    = i
				idxEndMon = i
				break
			end
		end
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
end

Main()
reaper.atexit(AtExitActions)
