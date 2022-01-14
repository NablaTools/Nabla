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
	local _, _, sec, cmd, _, _, _ = reaper.get_action_context()
	if measures ~= nil then
		mea = measures
		str_s = str
	end
	if state==1 then
		local play = reaper.GetPlayPosition()
		local _, measures_actual, _, _, _ = reaper.TimeMap2_timeToBeats( 0, play+0.1 )
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

-- Looper A Functions 
function msg(value, line)
	if console == 1 then
		reaper.ShowConsoleMsg(tostring(value))
		if line == 0 then
			reaper.ShowConsoleMsg("\n")
		else
			reaper.ShowConsoleMsg("\n-----\n")
		end
	end
end

function IsProjectSaved()
	if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then 
		separator = "\\" 
	else 
		separator = "/" 
	end
	local _, project_path_name = reaper.EnumProjects(-1, "")
	if project_path_name ~= "" then
		dir = project_path_name:match("(.*"..separator..")")
		project_saved = true
		return project_saved, dir, separator
	else
		local message = "You need to save the project to execute Nabla Looper."
		local display = reaper.ShowMessageBox(message, "File Export", 1)
		if display == 1 then
			reaper.Main_OnCommand(40022, 0) -- SAVE AS PROJECT
			return IsProjectSaved()
		end
	end
end

function errorHandler(errObject)
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

function saveTrackSelection()
	reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_SAVETRACK'), 0)
end

function restoreTrackSelection()
	reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_RESTORETRACK'), 0)
end

function setActionState(state)
	local _, _, sec, cmd, _, _, _ = reaper.get_action_context()
	reaper.SetToggleCommandState( sec, cmd, state )
	reaper.RefreshToolbar2( sec, cmd )
end

function GetSetNablaConfigs()
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

function GetItemType( item, getsectiontype )
	local take   = reaper.GetActiveTake(item)
	if not take then return false, "UNKNOW" end
	local itemSource = reaper.GetMediaItemTake_Source(take)
	local sourceType = reaper.GetMediaSourceType(itemSource, "")
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

function GetItemAction(itemCode)
	retval, itemAction = reaper.GetSetMediaItemInfo_String(itemCode, 'P_EXT:ITEM_ACTION', '', false)
	if retval then 
		return itemAction 
	else
		return ''
	end
end

function CreateTableAllItems()
	local count = reaper.CountMediaItems(proj)
	for i = 0, count - 1 do
		local itemCode           = reaper.GetMediaItem(proj, i)
		local section, itemType  = GetItemType( itemCode, true )
		if itemType ~= "UNKNOW" and itemType ~= "RPP_PROJECT" and itemType ~= "VIDEO" and itemType ~= "CLICK" and itemType ~= "LTC" and itemType ~= "VIDEOEFFECT" then
			local itemStart       = tonumber(format("%.3f", reaper.GetMediaItemInfo_Value(itemCode,"D_POSITION")))
			local itemStartStr    = "i"..gsub(tostring(itemStart), "%.+","")
			local itemLength      = reaper.GetMediaItemInfo_Value(itemCode,"D_LENGTH")
			local itemEnd         = tonumber(format("%.3f", itemStart+itemLength))
			local itemEndStr      = "o"..gsub(tostring(itemEnd), "%.+","")
			local itemAction      = GetItemAction(itemCode)
			local itemLock        = reaper.GetMediaItemInfo_Value( itemCode, 'C_LOCK')
			local takeCode        = reaper.GetActiveTake( itemCode )
			local takeName        = match(reaper.GetTakeName(takeCode), '(.-)%sTK:%d+$') or reaper.GetTakeName(takeCode)
			local takeNameStr     = takeName:gsub("%s+", "")
			local takeIndex       = match(takeName, '%d+$')
			local trackCode       = reaper.GetMediaItem_Track( itemCode )
			local trackInput      = reaper.GetMediaTrackInfo_Value(trackCode, 'I_RECINPUT')
			local trackMode       = reaper.GetMediaTrackInfo_Value( trackCode, 'I_RECMODE' )
			local itemSource      = reaper.GetMediaItemTake_Source(takeCode)
			local _, _, _, itemMode = reaper.PCM_Source_GetSectionInfo( itemSource )
			local itemLengthQN    = reaper.TimeMap2_timeToQN( proj, itemLength ) * 960
			items[#items+1] = {
				itemCode     = itemCode, 
				itemStart    = itemStart, 
				itemEnd      = itemEnd, 
				itemStartStr = itemStartStr, 
				itemEndStr   = itemEndStr,
				itemAction   = itemAction,
				itemLength   = itemLength, 
				takeCode     = takeCode, 
				takeName     = takeName, 
				takeIndex    = takeIndex,
				trackCode    = trackCode,
				trackInput   = trackInput, 
				takeNameStr  = takeNameStr, 
				itemBuffer   = 0,
				itemMode     = itemMode,
				trackMode    = trackMode,
				itemType     = itemType,
				itemLock     = itemLock,
				itemSource   = itemSource,
			}
		end
	end
	table.sort(items, function(a,b) return a.itemStart < b.itemStart end) 
end

function AddToRecordingItemsTable(i, v)
	recItems[#recItems+1] = {
		idx = i, 
		itemStart = v.itemStart, 
		itemEnd = v.itemEnd, 
		takeName = v.takeName, 
		itemLength = v.itemLength, 
		itemLengthQN = v.itemLengthQN
	}
end

function CreateRecordItemsTable()
	for i = 1, #items do
		local v = items[i]
		if v.itemAction ~= '' and v.itemAction ~= 'monitor' then 
			AddToRecordingItemsTable(i, v) 
		end
	end
end

function SetIfBuffer(m, v)
	if v.takeName == m.takeName then
		if m.itemStart >= v.itemEnd-0.1 and m.itemStart <= v.itemEnd+0.1 then
			v.itemBuffer = 1
		end
	end
end

function AddToGroupItemsByNameTable(v)
	flags[v.takeNameStr] = true
	_G[ v.takeNameStr ] = {}
	for j = 1, #items do
		local m = items[j]
		if v.takeName == m.takeName then
			_G[ v.takeNameStr ][ #_G[ v.takeNameStr ] + 1 ] = {idx = j }
		end
	end
end

function AddToStartTimesTable()
	for i = 1, #startTimes do
		local itemStart  = startTimes[i].itemStart
		local itemStartStr = startTimes[i].itemStartStr
		_G[ itemStartStr ] = {}
		for j = 1, #items do
			if items[j].itemAction ~= "0" and items[j].itemAction ~= "" then
				if itemStart == items[j].itemStart then
					_G[ itemStartStr ][ #_G[ itemStartStr ] + 1 ] = { idx = j }
				end
			end
		end
	end
	-- Debug startTimes Tables
	for i = 1, #startTimes do
		local itemStartStr = startTimes[i].itemStartStr
		msg( "At start position: "..startTimes[i].itemStart, 0 )
		for j = 1, #_G[ itemStartStr ] do
			local index = items[ _G[itemStartStr][j].idx ]
			msg( "--> Arm: "..index.takeName, 0 )
		end
	end
end

function AddToEndTimesTable(v)
	for i = 1, #endTimes do
		local itemEnd  = endTimes[i].itemEnd
		local itemEndStr = endTimes[i].itemEndStr
		_G[ itemEndStr ] = {}
		for j = 1, #items do
			if items[j].itemAction ~= "0" and items[j].itemAction ~= "" then
				if itemEnd == items[j].itemEnd then
					_G[ itemEndStr ][ #_G[ itemEndStr ] + 1 ] = { idx = j }
				end
			end
		end
	end
	-- Debug endTimes Tables
	for i = 1, #endTimes do
		local itemEndStr = endTimes[i].itemEndStr
		msg( "At end position: "..endTimes[i].itemEnd, 0 )
		for j = 1, #_G[ itemEndStr ] do
			local index = items[ _G[itemEndStr][j].idx ]
			msg( "--> Unarm: "..index.takeName, 0 )
		end
	end
end

function AddToActionTimesTable(i, v)
	if not flags["sta"..v.itemStart] then
		flags["sta"..v.itemStart] = true
		startTimes[ #startTimes + 1 ]  = {
			idx = i, 
			itemStartStr = v.itemStartStr, 
			itemStart = v.itemStart 
		} 
	end
	if not flags["end"..v.itemEnd] then
		flags["end"..v.itemEnd] = true
		endTimes[ #endTimes + 1 ] = {
			idx = i, 
			itemEndStr = v.itemEndStr, 
			itemEnd = v.itemEnd 
		}
	end
end

function AddToActionTracksTable(v)
	if not flags[v.trackCode] then
		flags[v.trackCode] = true
		recTracks[ #recTracks + 1 ] = { 
			trackCode = v.trackCode, 
			trackInput = v.trackInput, 
			trackMode = v.trackMode, 
			itemAction = v.itemAction
		}
	end
end



function CreateActionsTables()
	for i = 1, #items do
		local v = items[i]
		if v.itemAction ~= '' and v.itemAction ~= 'monitor' then AddToRecordingItemsTable(i, v) end
		AddToActionTracksTable(v)
		AddToActionTimesTable(i, v)
		for j = 1, #items do
			local m = items[j]
			SetIfBuffer(m, v)
			if not flags[v.takeNameStr] then AddToGroupItemsByNameTable(v, m, j) end
		end
	end
	table.sort(startTimes, function(a,b) return a.itemStart < b.itemStart end) 
	table.sort(endTimes, function(a,b) return a.itemEnd < b.itemEnd end) 
	table.sort(recItems, function(a,b) return a.itemStart < b.itemStart end)
	AddToStartTimesTable()
	AddToEndTimesTable()
end

function toggleArm(trackCode, state)
	reaper.SetMediaTrackInfo_Value(trackCode, 'I_RECARM', state)
end

function toggleMonitor(trackCode, state)
	reaper.SetMediaTrackInfo_Value(trackCode, 'I_RECMON', state)
end

function toggleReaDelay(v, state)
	if v.trackInput < 4096 then
		local integerFx = reaper.TrackFX_AddByName( v.trackCode, 'Nabla ReaDelay', false, 0 )
		reaper.TrackFX_SetParam( v.trackCode, integerFx, 13, state )
	end
end

function toggleMute(trackCode, state)
	reaper.SetMediaTrackInfo_Value(trackCode, 'B_MUTE', state)
end

function setRecMode(trackCode, mode)
	reaper.SetMediaTrackInfo_Value(trackCode, 'I_RECMODE', mode)
end


function prepareRecordTrack(v)
	if v.trackMode >= 7 and v.trackMode <= 9 or v.trackMode == 16 then
		setRecMode(v.trackCode, 0)
	end       
	reaper.SetMediaTrackInfo_Value( v.trackCode, 'B_FREEMODE', 0 )
	reaper.SetMediaTrackInfo_Value( v.trackCode, 'I_RECMONITEMS', 1 )
	toggleMonitor(v.trackCode, 0)
	toggleArm(v.trackCode, 0)
end

function prepareRecordMuteTrack(v)
	if v.trackMode ~= 0 then
		setRecMode(v.trackCode, 0)
	end       
	reaper.SetMediaTrackInfo_Value( v.trackCode, 'B_FREEMODE', 0 )
	reaper.SetMediaTrackInfo_Value( v.trackCode, 'I_RECMONITEMS', 1 )
	toggleArm(v.trackCode, 0)
end

function prepareMonitorTrack(v)
	setRecMode(v.trackCode, 2)
	toggleMonitor(v.trackCode, 0)
	toggleArm(v.trackCode, 1)
end

function SetActionTracksConfig()
	for i = 1, #recTracks do
		local v = recTracks[i]
		if v.itemAction == 'record' then
			prepareRecordTrack(v)
		elseif v.itemAction == 'record mute' then
			prepareRecordMuteTrack(v)
		end
		if v.itemAction == 'monitor' then
			prepareMonitorTrack(v)
		end
	end
end

function SetReaperConfigs()
	for i = 1, #nablaConfigs do
		local v = nablaConfigs[i]
		local state = reaper.GetToggleCommandState( v.actionNumber )
		originalConfigs[i] = { actionNumber = v.actionNumber, state = state }
		if state == 1 and v.setstate == 'off' then
			reaper.Main_OnCommand(v.actionNumber, 0)
		elseif state == 0 and v.setstate == "on" then
			reaper.Main_OnCommand(v.actionNumber, 0)
		end
	end
end

function RestoreConfigs()
	for i = 1, #originalConfigs do
		local v = originalConfigs[i]
		local state = reaper.GetToggleCommandState( v.actionNumber )
		if v.state ~= state then
			reaper.Main_OnCommand(v.actionNumber, 0)
		end
	end
end

function GetIDByScriptName(scriptName)
	local file = io.open(reaper.GetResourcePath()..'/reaper-kb.ini','r'); 
	if not file then return -1 end
	local originalStr = gsub(scriptName, 'Script:%s+','')
	local pattern = "[%%%[%]%(%)%*%+%-%.%?%^%$]"
	local scrName = gsub(originalStr, pattern,function(s)return"%"..s;end);
	for var in file:lines() do;
		if match(var, scrName) then
			local id = "_" .. gsub(gsub(match(var, ".-%s+.-%s+.-%s+(.-)%s"),'"',""), "'","")
			return id
		end
	end
	return -1
end

-- Modified from X-Raym's itemAction: Insert CC linear ramp events between selected ones if consecutive
function GetCC(take, cc)
	return cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3
end

function ExportMidiFile(take_name, take, takeNameStr, newidx, strToStore) -- local (i, j, item, take, track)
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
				reaper.SetProjExtState(proj, takeNameStr, newidx, fn..strToStore) 
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

function SetFXName(track, fx, new_name)
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

function InsertReaDelay()
	reaper.Undo_BeginBlock()
	for i = 1, #recTracks do
		local v = recTracks[i]
		if v.itemAction ~= 'monitor' then
			if v.trackInput < 4096 then
				local isFx = reaper.TrackFX_AddByName( v.trackCode, 'ReaDelay', false, -1000 )
				reaper.TrackFX_SetParam( v.trackCode, isFx, 0, 1 )
				reaper.TrackFX_SetParam( v.trackCode, isFx, 1, 0 )
				reaper.TrackFX_SetParam( v.trackCode, isFx, 13, 0 )
				SetFXName(v.trackCode, isFx, 'Nabla ReaDelay')
			end
		end
	end
	reaper.Undo_EndBlock("Insert Nabla ReaDelay", -1)
end

function SetPDC( set )
	reaper.Undo_BeginBlock()
	local tableStringRec = {}
	for i = 1, #recTracks do
		local v = recTracks[i]
		if v.itemAction ~= 'monitor' then
			local r, trChunk = reaper.GetTrackStateChunk(v.trackCode, '', false)
			local strRec = match(trChunk, 'REC%s+.-[%\n]')
			for substring in gmatch(strRec, "%S+") do insert(tableStringRec, substring) end

			function set_pdc( str )
				local new_strRec = gsub(trChunk, 'REC%s+.-[%\n]', str, 1)
				reaper.SetTrackStateChunk(v.trackCode, new_strRec, true)
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

function RemoveReaDelay()
	for i = 1, #recTracks do
		local v = recTracks[i]
		if v.trackInput < 4096 then
			local integerFx = reaper.TrackFX_AddByName( v.trackCode, 'Nabla ReaDelay', false, 0 )
			reaper.TrackFX_Delete( v.trackCode, integerFx)
		end
	end
end

function GetNumForLoopTakes( takeCode )
	local newKey = 0
	for i = 0, 1000 do
		local retval, key, val = reaper.EnumProjExtState( 0, takeCode, i )
		if retval == false then return tonumber(newKey) + 1 end
		newKey = key
	end
end

function restoreRecordTracks()
	for i = 1, #recTracks do
		local v = recTracks[i]
		if v.trackMode ~= 2 then
			toggleMonitor(v.trackCode, 1)
			setRecMode(v.trackCode, v.trackMode)
			toggleArm(v.trackCode, 0)
		end
	end
end

function callClearScript()
	for j = 1, #practice do os.remove(practice[j]) end
	local scriptName = "Script: Nabla Looper A - ITEM Clear.lua"
	local idbyscript = GetIDByScriptName(scriptName)
	reaper.Main_OnCommand(reaper.NamedCommandLookup(idbyscript),0)
end

function AtExitActions()
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

function SetFxParam(trackCode, integerFx, integerParam, numberValue)
end

function SetReaDelayTime(trackCode, itemLength, trackInput)
	local integerFx = reaper.TrackFX_AddByName( trackCode, 'Nabla ReaDelay', false, 0 )
	local integerParam = 4 
	local numberValue = (reaper.TimeMap_timeToQN_abs( 0, itemLength )*2)/256
	reaper.TrackFX_SetParam( trackCode, integerFx, integerParam, numberValue)
end

function OnReaDelay(trackCode)
	local integerFx = reaper.TrackFX_AddByName( trackCode, 'Nabla ReaDelay', false, 0 )
	local integerParam = 13 
	local numberValue = 1
	reaper.TrackFX_SetParam( trackCode, integerFx, integerParam, numberValue )
end

function OffReaDelayDefer(itemEndStr, redItemEnd)
	xpcall( function()
		if itemEndStr then
			newsiEnd = itemEndStr
			sredItemEnd = redItemEnd
		end
		if reaper.GetPlayPosition() > sredItemEnd then
			for i = 1, #_G[ newsiEnd ] do
				reaper.Undo_BeginBlock()
				local v = items[ _G[newsiEnd][i].idx ]
				if v.itemBuffer == 1 then
					local integerFx = reaper.TrackFX_AddByName( v.trackCode, 'Nabla ReaDelay', false, 0 )
					local integerParam = 13 
					local numberValue = 0
					reaper.TrackFX_SetParam( v.trackCode, integerFx, integerParam, numberValue )
				end
				reaper.Undo_EndBlock("End itemBuffer: " .. v.takeName, -1)
			end
			return
		end
		if reaper.GetPlayState() == 0 then return else reaper.defer(OffReaDelayDefer) end
	end, errorHandler)
end

function SetItemReverseMode(v)
	reaper.SelectAllMediaItems(proj, false)
	reaper.SetMediaItemSelected(v.itemCode, true)
	reaper.Main_OnCommand(41051, 0) -- Item properties: Toggle take reverse
	reaper.SetMediaItemTakeInfo_Value( v.takeCode, 'D_STARTOFFS', 0 )
end

function CreateNewSourceForItem(v, section, takeName, takeIndex)
	local pcm_section = reaper.PCM_Source_CreateFromType("SECTION")
	reaper.SetMediaItemTake_Source(v.takeCode, pcm_section)
	local r, chunk = reaper.GetItemStateChunk(v.itemCode, "", false) 
	local new_chunk   = gsub(chunk, '<SOURCE%s+.->', section .. "\n>" )
	reaper.SetItemStateChunk(v.itemCode, new_chunk, true) 
	local takeString = takeName.." TK:"..takeIndex
	reaper.GetSetMediaItemTakeInfo_String( v.takeCode, 'P_NAME', takeString, true )
end

function PropagateAudio(takeNameStr, section, takeName, takeIndex)
	for i = 1, #_G[takeNameStr] do
		local v = items[ _G[takeNameStr][i].idx ]
		if v.itemLock ~= 1 then
			CreateNewSourceForItem(v, section, takeName, takeIndex)
			if v.itemMode then SetItemReverseMode(v) end
			if v.itemSource then reaper.PCM_Source_Destroy(v.itemSource) end
		end
	end
	reaper.Main_OnCommand(40047, 0) -- Peaks: Build any missing peaks
end

function PropagateMIDI(takeNameStr, section, newidx)
	for i = 1, #_G[takeNameStr] do
		local v = items[ _G[takeNameStr][i].idx ]
		local pcm_section = reaper.PCM_Source_CreateFromType("MIDI")
		reaper.SetMediaItemTake_Source(v.takeCode, pcm_section)
		local r, chunk = reaper.GetItemStateChunk(v.itemCode, "", false) 
		local new_chunk   = gsub(chunk, '<SOURCE%s+.->', section .. "\n>" )
		reaper.SetItemStateChunk( v.itemCode, new_chunk, true)
		local takeString = v.takeName.." TK:"..format("%d", newidx)
		reaper.GetSetMediaItemTakeInfo_String(v.takeCode, 'P_NAME', takeString, true )
		if v.itemSource then reaper.PCM_Source_Destroy(v.itemSource) end
	end
end

function WaitForEnd()
	if reaper.GetPlayState() == 0 then return else reaper.defer(WaitForEnd) end
end

function ArmTracksByGroupTimes( itemStartStr )
	for i = 1, #_G[ itemStartStr ] do
		reaper.Undo_BeginBlock()
		local v = items[ _G[itemStartStr][i].idx ]
		reaper.SetMediaTrackInfo_Value( v.trackCode, 'I_RECMON', 0 )
		reaper.SetMediaTrackInfo_Value( v.trackCode, 'I_RECARM', 1 )
		if safeMode == 'true' then SetReaDelayTime( v.trackCode, v.itemLength, v.trackInput) end
		reaper.Undo_EndBlock("Recording: "..v.takeName, -1)
	end
end

function ActivateRecording()
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

function ArmTrackMonitorGroupMIDI(itemStartStr)
	for i = 1, #_G[ itemStartStr ] do
		local v = items[ _G[itemStartStr][i].idx ]
		if v.trackInput >= 4096 then
			reaper.Undo_BeginBlock()
			if v.itemAction == 'record' or v.itemAction == 'monitor' then
				toggleMonitor(v.trackCode, 1)
			elseif v.itemAction == 'record mute' then
				toggleMute(v.trackCode, 1)
				toggleMonitor(v.trackCode, 1)
			end
			reaper.Undo_EndBlock("On Monitor: "..v.takeName, -1)
		end
	end
end

function ArmTrackMonitorGroupAudio(itemStartStr)
	for i = 1, #_G[ itemStartStr ] do
		local v = items[ _G[itemStartStr][i].idx ]
		if v.trackInput < 4096 then
			reaper.Undo_BeginBlock()
			if v.itemAction == 'record' or v.itemAction == 'monitor' then
				toggleMonitor(v.trackCode, 1)
			elseif v.itemAction == 'record mute' then
				toggleMute(v.trackCode, 1)
				toggleMonitor(v.trackCode, 1)
			end
			reaper.Undo_EndBlock("On Monitor: "..v.takeName, -1)
		end
	end
end

function ActivateMonitorMIDI()
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

function ActivateMonitorAUDIO()
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

function WorkWithNewAudioLoop(v, addedItem)
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
	reaper.DeleteTrackMediaItem( v.trackCode, addedItem )
	reaper.PreventUIRefresh(-1)
	PropagateAudio(v.takeNameStr, section, v.takeName, GetNumForLoopTakes( v.takeNameStr ))
	if practiceMode == 'false' then
		local strToStore = filename..","..addedSoffs..","..v.itemLength..",AUDIO,"..v.takeName.." TK:"..GetNumForLoopTakes( v.takeNameStr) .. ",_"
		reaper.SetProjExtState(proj, v.takeNameStr, format("%03d",GetNumForLoopTakes( v.takeNameStr )), strToStore)
	else
		practice[#practice+1] = filename
	end
end

function WorkWithNewMIDILoop(v, addedItem)
	reaper.PreventUIRefresh(1)
	reaper.SetMediaItemInfo_Value( addedItem, 'B_LOOPSRC', 0) 
	reaper.SplitMediaItem( addedItem, v.itemStart )
	reaper.DeleteTrackMediaItem( v.trackCode, addedItem )
	local addedItem = reaper.GetSelectedMediaItem(0, 0)
	reaper.SplitMediaItem( addedItem, v.itemEnd )
	local delSplitItem = reaper.GetSelectedMediaItem(0, 1)
	if delSplitItem then
		reaper.DeleteTrackMediaItem( v.trackCode, delSplitItem ) 
	end
	reaper.SetMediaItemInfo_Value( addedItem, 'B_LOOPSRC', 1)
	reaper.SetMediaItemSelected(addedItem, true)
	local takeCode  = reaper.GetActiveTake(addedItem)
	local newidx = format("%03d",GetNumForLoopTakes( v.takeNameStr ))
	local r, chunk    = reaper.GetItemStateChunk(addedItem, "", false)
	local section     = match(chunk, '<SOURCE%s+.->')
	PropagateMIDI( v.takeNameStr, section, newidx ) 
	reaper.GetSetMediaItemTakeInfo_String( takeCode, 'P_NAME', v.takeNameStr.." "..newidx, true )
	local strToStore = ",_,"..v.itemLength..",MIDI,"..v.takeName.." TK:"..GetNumForLoopTakes( v.takeNameStr ) .. ",_"
	ExportMidiFile(v.takeNameStr.." "..newidx, takeCode, v.takeNameStr, newidx, strToStore )
	reaper.PreventUIRefresh(-1)
end

function AddNewLoop(v)
	reaper.SetMediaTrackInfo_Value( v.trackCode, 'I_RECARM', 0 )
	reaper.SelectAllMediaItems( 0, false )
	reaper.Main_OnCommand(40670, 0) -- Record: Add recorded media to project
	return reaper.GetSelectedMediaItem(0, 0)
end

function DeactivateRecording()
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
					if v.itemAction == 'record' or v.itemAction == 'record mute' then
						local addedItem = AddNewLoop(v)
						if addedItem then
							if v.trackInput < 4096 then
								WorkWithNewAudioLoop(v, addedItem)
							else
								WorkWithNewMIDILoop(v, addedItem)
							end
						end
						reaper.Undo_EndBlock("Propagate: "..v.takeName .. " TK:" .. GetNumForLoopTakes( v.takeNameStr ), -1)
					end
				end
			end
		end
		if reaper.GetPlayState() == 0 then return else reaper.defer(DeactivateRecording) end
	end, errorHandler) 
end

function DeactivateMonitor()
	xpcall( function()
		local pPos = reaper.GetPlayPosition()
		if idxEndMon == nil or idxEndMon > #endTimes then return end
		local itemEnd  = endTimes[idxEndMon].itemEnd
		if pPos >= itemEnd-0.1 then 
			local itemEndStr = endTimes[idxEndMon].itemEndStr
			if not flags[itemEndStr.."endMon"] then
				flags[itemEndStr.."endMon"] = true
				idxEndMon = idxEndMon + 1
				for i = 1, #_G[ itemEndStr ] do
					reaper.Undo_BeginBlock()
					local v = items[ _G[itemEndStr][i].idx ]
					if safeMode == 'true' then
						if v.itemBuffer == 1 then
							if v.itemAction == 'record' then
								toggleReaDelay(v, 1)
								toggleMonitor(v.trackCode, 0)
								OffReaDelayDefer( v.itemEndStr, v.itemEnd + bufferTime, v.trackCode )
							elseif v.itemAction == 'record mute' then
								toggleReaDelay(v, 1)
								toggleMute(v.trackCode, 0)
								OffReaDelayDefer( v.itemEndStr, v.itemEnd + bufferTime, v.trackCode )
							elseif v.itemAction == 'monitor' then
								toggleMonitor(v.trackCode, 0)
								setRecMode(v.trackCode, 2)
							end
						else
							if v.itemAction == 'record' or v.itemAction == 'record mute' then
								toggleMonitor(v.trackCode, 0)
							elseif v.itemAction == 'monitor' then
								toggleMonitor(v.trackCode, 0)
								setRecMode(v.trackCode, 2)
							end
						end
					else
						if v.itemAction == 'record' then
							toggleMonitor(v.trackCode, 0)
						elseif v.itemAction == 'record mute' then
							toggleMute(v.trackCode, 0)
						elseif v.itemAction == 'monitor' then
							toggleMonitor(v.trackCode, 0)
							setRecMode(v.trackCode, 2)
						end
					end
					reaper.Undo_EndBlock("Off Monitor: "..v.takeName, -1)
				end
			end
		end
		if reaper.GetPlayState() == 0 then return else reaper.defer(DeactivateMonitor) end
	end, errorHandler) 
end

function setIdxSatart()
	for i = 1, #startTimes do
		local itemStart  = startTimes[i].itemStart
		if itemStart - 0.1 > reaper.GetCursorPosition() then
			idxStart         = i
			idxStartMonMIDI  = i
			idxStartMonAUDIO = i
			break
		end
	end
end

function setIdxEnd()
	for i = 1, #endTimes do
		local itemEnd  = endTimes[i].itemEnd
		if itemEnd - 0.1 > reaper.GetCursorPosition() then
			idxEnd    = i
			idxEndMon = i
			break
		end
	end
end
-- End Looper A Functions
