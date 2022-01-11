--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper Manual Trigger Actions. 
* Version: 0.2.4
* Author: Esteban Morales
* Author URI: https://forum.cockos.com/member.php?u=133640
--]] 
--====================================================================== 
version = 'v0.2.4'
console = 0

local function Msg(value, line)
	if console == 1 then
		reaper.ShowConsoleMsg(tostring(value))
		if line == 0 then
			--reaper.ShowConsoleMsg()
		else
			reaper.ShowConsoleMsg("\n")
			--reaper.ShowConsoleMsg("\n-----\n")
		end
	end
end

local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
reaper.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
reaper.RefreshToolbar2( sec, cmd )

reaper.SetProjExtState(proj, "NABLA", "STATE", 0)
reaper.SetProjExtState(proj, "NABLA", "DELETE", 0)

local function off_state()

	local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
	reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set ON
	reaper.RefreshToolbar2( sec, cmd )
	reaper.SetProjExtState(proj, "NABLA", "STATE", 0)
	reaper.SetProjExtState(proj, "NABLA", "DELETE", 0)

end
------------------------------------------------------------------
-- GET CONFIG
------------------------------------------------------------------
local vars = { 
	{	'safeMode',    'SAFE_MODE',    'true'	}, 
	{	'startTime',   'START_TIME',   '1'   	}, 
	{	'bufferTime',  'BUFFER_TIME',  '1'   	},
	{	'preservePDC', 'PRESERVE_PDC', 'true'	}, 
	{	'hotkey',      'HOTKEY_VAL',   '0'   	}, 
	{	'hotkeyName',  'HOTKEY_NAME',   '0'   }, 
}

for i = 1, #vars do

	local varName = vars[i][1]
	local section = vars[i][2]
	local id      = vars[i][3]

	_G[varName] = reaper.GetExtState( 'NABLA_LOOPER_MANUAL', section )

	if _G[varName] == "" or _G[varName] == nil then

		reaper.SetExtState( 'NABLA_LOOPER_MANUAL', section, id, true )

		_G[varName] = id

	end

end

Msg("Shortcut value: " .. hotkey, 1)
Msg("Shortcut name: " .. hotkeyName, 1)
------------------------------------------------------------------

local timeToPressKey = 10
local format    = string.format
local match     = string.match
local gsub      = string.gsub
local gmatch    = string.gmatch
local find      = string.find
local sub       = string.sub
local concat    = table.concat
local insert    = table.insert
local oneMeas   = reaper.TimeMap2_beatsToTime( proj, 0, 1 )
------------------------------------------------------------------
-- TABLAS
------------------------------------------------------------------
local tToArm         = {}
local tToUnarm       = {}
local tAddedItems    = {}
local tSelectedItems = {}
local flags          = {}
local tReaDelay      = {}
local tReaDelay_Off  = {}
local tMonitor       = {}
------------------------------------------------------------------
local function errorHandler(errObject)

	reaper.OnStopButton()
	reaper.Main_OnCommand(40668) -- Stop and delete media

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
------------------------------------------------------------------
function OffReaDelayDefer( getBuffer )

	if getBuffer then 

		endBuffer = getBuffer 

	end

	if reaper.GetPlayPosition() > endBuffer then

		for i = 1, #tReaDelay_Off do

			-- reaper.ShowConsoleMsg("Off ReaDelay\n")
			local fxIdx = reaper.TrackFX_AddByName( tReaDelay_Off[i].cTrack, 'Nabla ReaDelay', false, 0 )
			reaper.TrackFX_SetParam( tReaDelay_Off[i].cTrack, fxIdx, 13, 0 )
			reaper.TrackFX_SetParam( tReaDelay_Off[i].cTrack, reaper.TrackFX_AddByName( tReaDelay_Off[i].cTrack, 'Nabla ReaDelay', false, 0 ), 4, 1 )

		end

		for i=1, #tReaDelay_Off do tReaDelay_Off[i] = nil end

		return

	end

	if reaper.GetPlayState() == 0 then return else reaper.defer(OffReaDelayDefer) end

end 
------------------------------------------------------------------
local function AddAndTrimRecordedMedia()

	reaper.Undo_BeginBlock()

	local numSelItems = reaper.CountSelectedMediaItems(proj)

	-- EMPTY tAddedItems TABLE
	for i=1, #tAddedItems do tAddedItems[i] = nil end
	for i=1, #tSelectedItems do tSelectedItems[i] = nil end
	---- FILL tAddedItems TABLE

	for i=0, numSelItems-1 do
		local cItem = reaper.GetSelectedMediaItem(proj, i)
		local cTrack = reaper.GetMediaItemTrack(cItem)
		local r, trName = reaper.GetTrackName( cTrack )
		local trType = reaper.GetMediaTrackInfo_Value(cTrack, 'I_RECINPUT')
		tAddedItems[i+1] = {
			cItem      = cItem,
			cTrack     = cTrack,
			trType     = trType,
			trName     = trName
		}
	end
	------------------------------------------------------------------
	reaper.SelectAllMediaItems(proj, false)
	--if #tAddedItems > 0 then
		-- for i=1, #tAddedItems do
	for i = 1, #tAddedItems do

		local v = tAddedItems[i]

		if v.trType < 4096 then

			reaper.PreventUIRefresh(1)

			reaper.SetMediaItemSelected(v.cItem, true)
			reaper.ApplyNudge( 0, 2, 1, 16, 0.1, 0, 0 )
			reaper.ApplyNudge( 0, 2, 3, 16, 0.1, 1, 0 )
			reaper.Main_OnCommand(41295, 0) -- Item: Duplicate items
			local addedItem = reaper.GetSelectedMediaItem(proj, 0)
			tSelectedItems[i] = addedItem
			local r, old_chunk = reaper.GetItemStateChunk(addedItem, "", false) -- coppy item chunk
			local oldSource = match(old_chunk, '(<SOURCE%s+.->)[\r]-[%\n]')
			local oldLen = match(old_chunk, 'LENGTH'..'%s+(.-)[\r]-[%\n]')
			local oldSoffs = match(old_chunk, 'SOFFS'..'%s+(.-)[%s-%a+]')
			local new_chunk = gsub( old_chunk, '<SOURCE%s+.->', "<SOURCE SECTION\n".."LENGTH "..oldLen.."\n".."STARTPOS "..oldSoffs.."\n"..oldSource.."\n>", 1)
			local cTake = reaper.GetMediaItemTake(addedItem, 0)
			reaper.SetItemStateChunk(addedItem, new_chunk, true) 
			reaper.SetMediaItemTakeInfo_Value( cTake, 'D_STARTOFFS', 0 )
			local addedItmPos = reaper.GetMediaItemInfo_Value(addedItem,"D_POSITION")
			local addedItemLen = reaper.GetMediaItemInfo_Value(addedItem,"D_LENGTH")
			reaper.SetMediaItemInfo_Value(addedItem,"D_POSITION", addedItmPos-addedItemLen)
			reaper.SetMediaItemInfo_Value(addedItem,"D_LENGTH", addedItemLen+oneMeas)
			reaper.DeleteTrackMediaItem( v.cTrack, v.cItem)
			reaper.GetSetMediaItemTakeInfo_String( cTake, 'P_NAME', v.trName, true )
			reaper.SetMediaItemSelected(addedItem, false)

			reaper.PreventUIRefresh(-1)

		else

			reaper.PreventUIRefresh(1)

			reaper.SetMediaItemSelected(v.cItem, true)
			
			reaper.SetMediaItemInfo_Value( v.cItem, 'B_LOOPSRC', 0) 
			local iPos = reaper.GetMediaItemInfo_Value(v.cItem,"D_POSITION")
			local retval, startMeas, cml, fullbeats, _ = reaper.TimeMap2_timeToBeats( proj, iPos )
			local iLen = reaper.GetMediaItemInfo_Value(v.cItem,"D_LENGTH")
			local iEnd = iPos+iLen  
			local retval, endMeas, cml, fullbeats, _ = reaper.TimeMap2_timeToBeats( proj, iEnd )                    
			reaper.SplitMediaItem( v.cItem, reaper.TimeMap2_beatsToTime(proj, 0, startMeas+1) )
			reaper.DeleteTrackMediaItem( v.cTrack, v.cItem)
			local addedItem = reaper.GetSelectedMediaItem(0, 0)
			tSelectedItems[addedItem] = addedItem
			reaper.SplitMediaItem( addedItem, reaper.TimeMap2_beatsToTime(proj, 0, endMeas) )
			local delSplitItem = reaper.GetSelectedMediaItem(0, 1)
			if delSplitItem then
				reaper.DeleteTrackMediaItem(  v.cTrack, delSplitItem ) 
			end
			reaper.SetMediaItemInfo_Value( addedItem, 'B_LOOPSRC', 1)

			local iLen = reaper.GetMediaItemInfo_Value(addedItem,"D_LENGTH")
			reaper.SetMediaItemInfo_Value(addedItem,"D_LENGTH", iLen+oneMeas)
			local cTake = reaper.GetMediaItemTake(addedItem, 0)
			reaper.GetSetMediaItemTakeInfo_String( cTake, 'P_NAME', v.trName, true )
			reaper.SetMediaItemSelected(addedItem, false)

			reaper.PreventUIRefresh(-1)
		end
	end

	reaper.PreventUIRefresh(1)

	reaper.SelectAllMediaItems(proj, true)
	reaper.Main_OnCommand(40645, 0) -- Item: Auto-reposition items in free item positioning mode
	reaper.SelectAllMediaItems(proj, false)

	reaper.PreventUIRefresh(-1)


	for i = 1, #tSelectedItems do 

		reaper.SetMediaItemSelected(tSelectedItems[i], true) 

	end

	reaper.Undo_EndBlock("Add loop to time line", -1)
	
end

function start_mon_on_next_measure(measure)

	if measure ~= nil then storedMeasure = measure end

	local _, deltaMeasure, _, _, _ = reaper.TimeMap2_timeToBeats( proj, reaper.GetPlayPosition() + 0.1 )

	if storedMeasure ~= deltaMeasure then

		for i = 1 , #tMonitor do

			-- reaper.ShowConsoleMsg("---> On Monitor\n")
			reaper.SetMediaTrackInfo_Value( tMonitor[i].cTrack, 'I_RECMON', 1 )

		end

		for i=1, #tMonitor do 

			tMonitor[i] = nil 

		end

		return

	end
	------------------------------------------------------------------
	if reaper.GetPlayState() == 0 then return else reaper.defer(start_mon_on_next_measure) end

end

function start_rec_on_next_measure(measure)

	if measure ~= nil then storedMeasure = measure end

	local _, deltaMeasure, _, _, _ = reaper.TimeMap2_timeToBeats( proj, reaper.GetPlayPosition() + startTime )

	if storedMeasure ~= deltaMeasure then

		reaper.SelectAllMediaItems(proj, false)

		for i = 1 , #tToArm do

			-- reaper.ShowConsoleMsg("---> Start Record\n")
			reaper.SetMediaTrackInfo_Value( tToArm[i].cTrack, 'I_RECMON', 0 )
			reaper.SetMediaTrackInfo_Value( tToArm[i].cTrack, 'I_RECARM', 1 )
			tReaDelay[i] = {cTrack = tToArm[i].cTrack, measure = storedMeasure}

		end

		for i=1, #tToArm do tToArm[i] = nil end

		return

	end
	------------------------------------------------------------------
	if reaper.GetPlayState() == 0 then return else reaper.defer(start_rec_on_next_measure) end
end

function stop_rec_on_next_measure(measure)

	if measure ~= nil then 

		storedMeasure = measure 

		for i = 1 , #tReaDelay do

			-- reaper.ShowConsoleMsg("---> Set ReaDelay Time\n")
			---- reaper.ShowConsoleMsg(tReaDelay[i].cTrack.."Measures\n")
			local fxIdx = reaper.TrackFX_AddByName( tReaDelay[i].cTrack, 'Nabla ReaDelay', false, 0 )
			local _, pPosMeas, _, _, _ = reaper.TimeMap2_timeToBeats( proj, reaper.GetPlayPosition() )
			local val   =  (((pPosMeas - tReaDelay[i].measure ) * 8) * 0.00390625) -- x * 0.00390625 equivalent to x/256
			reaper.TrackFX_SetParam( tReaDelay[i].cTrack, fxIdx, 4, val ) 
			tReaDelay_Off[i] = {cTrack = tReaDelay[i].cTrack, measure = tReaDelay[i].measure}

		end

		for i=1, #tReaDelay do tReaDelay[i] = nil end

	end

	local _, actualMeasure, _, _, _  = reaper.TimeMap2_timeToBeats( proj, reaper.GetPlayPosition() )

	if actualMeasure > storedMeasure then

		reaper.PreventUIRefresh(1)

		for i = 1 , #tToUnarm do

			-- reaper.ShowConsoleMsg("---> On ReaDelay Time\n")
			reaper.TrackFX_SetParam( tToUnarm[i].cTrack, reaper.TrackFX_AddByName( tToUnarm[i].cTrack, 'Nabla ReaDelay', false, 0 ), 13, 1 ) -- OnReaDelay
			-- reaper.ShowConsoleMsg("---> Stop Rec\n")
			reaper.SetMediaTrackInfo_Value( tToUnarm[i].cTrack, 'I_RECARM', 0 )
			reaper.SetMediaTrackInfo_Value( tToUnarm[i].cTrack, 'I_RECMON', 0 )

		end

		for i=1, #tToUnarm do tToUnarm[i] = nil end

		reaper.Main_OnCommand(40670, 0)
		reaper.PreventUIRefresh(-1)    
		AddAndTrimRecordedMedia()
		OffReaDelayDefer( reaper.GetPlayPosition() + bufferTime )

		return

	end
	------------------------------------------------------------------
	if reaper.GetPlayState() == 0 then return else reaper.defer(stop_rec_on_next_measure) end

end

function StartStopRecording()

	local _, measure, _, _, _ = reaper.TimeMap2_timeToBeats( proj, reaper.GetPlayPosition() )
	-- Iterate over all tracks for adding ARMED tracks to Unarm table
	local numTracks = reaper.GetNumTracks()
	local inc       = 0

	for i=0, numTracks-1 do

		local cTrack        = reaper.GetTrack(proj, i)
		local armState      = reaper.GetMediaTrackInfo_Value( cTrack, 'I_RECARM' )
		local trRecMode     = reaper.GetMediaTrackInfo_Value( cTrack, 'I_RECMODE' )

		if trRecMode ~= 2 then

			if armState == 1 then

				tToUnarm[inc+1] = {cTrack = cTrack, measure = measure}
				inc = inc + 1

			end
		end
	end

	if #tToUnarm ~= 0 then 
		stop_rec_on_next_measure(measure) 
	end
	-- Iterate over selected track for adding UNARMED to Arm table
	local inc          = 0
	local numSelTracks = reaper.CountSelectedTracks(proj)

	for i = 0, numSelTracks-1 do

		local cTrack        = reaper.GetSelectedTrack(proj, i)
		local armState      = reaper.GetMediaTrackInfo_Value( cTrack, 'I_RECARM' )
		local trRecMode     = reaper.GetMediaTrackInfo_Value( cTrack, 'I_RECMODE' )

		if trRecMode ~= 2 then

			if armState == 0 then

				tToArm[inc+1] = {cTrack = cTrack }
				tMonitor[inc+1] = {cTrack = cTrack }
				inc = inc + 1

			end
		end
	end

	if #tToArm ~= 0 then 

		start_rec_on_next_measure(measure)
		start_mon_on_next_measure(measure)

	end
end
------------------------------------------------------------------
-- OLD SHORTCUT SYSTEM JS_ReaSciptAPI
------------------------------------------------------------------
local timePress = 0 
local hitCount = 0 
local deferCount = 0

function GetTimesKeyPressed()

	xpcall( function()

		local is_new_value, filename, sectionID, cmdID, mode, resolution, value = reaper.get_action_context()
		local state, val = reaper.JS_VKeys_GetState(0.1)

		if value  > 120 or state:byte(hotkey) ~= 0 then -- Tecla 1

			timePress = timePress+1 -- Count-- Ciclos mientras se presiona la tecla
			-- Msg(value)
			-- Msg(state:byte(hotkey))
			Msg(".",0)

		else

			if timePress > 0 and timePress < 10 then 

				hitCount = hitCount+1
				deferCount = 0
				Msg("\nCycles: " .. timePress, 1)

			else

				if deferCount == timeToPressKey then

					if hitCount >= 1 then -- ONE PRESS (Revisar esta función)

						Msg("-> Single Press", 1)
						local _, measure, _, _, _ = reaper.TimeMap2_timeToBeats( proj, reaper.GetPlayPosition() )

						if not flags[ "mea"..measure] then

							Msg("--> Run Action", 1)
							flags[ "mea"..measure] = true
							StartStopRecording()

						end

						hitCount = 0 
						deferCount = 0
						-- elseif timePress == 2 then -- TWO PRESS
					else

							hitCount = 0 
							deferCount = 0 

					end
				end
			end

			if timePress > 20 then -- LONG PRESS 

				Msg("\n--> Long Press")

				deferCount = 0
				reaper.ClearAllRecArmed()
				reaper.Main_OnCommand(40670, 0) -- Record: Add recorded media to project
				reaper.Main_OnCommand(40006, 0) -- Delete items
				reaper.Main_OnCommand(41817, 0) reaper.Main_OnCommand(41817, 0)-- View: Continuous scrolling during playback
				reaper.Main_OnCommand(40036, 0) reaper.Main_OnCommand(40036, 0) -- View: Toggle auto-view-scroll during playback

			end

			timePress = 0 

		end
			------------------------------------------------------------------
		if deferCount == timeToPressKey then

			deferCount = 0 

		end

		deferCount = deferCount + 1 
		------------------------------------------------------------------
		if reaper.GetPlayState() == 0 then off_state() else reaper.defer(GetTimesKeyPressed) end

	end, errorHandler)

end
------------------------------------------------------------------
-- NEW SHORTCUT SYSTEM
------------------------------------------------------------------
local newDeferCount = 0

function NewDeferActions()
	xpcall( function()
			-- reaper.ClearConsole()
			-- reaper.ShowConsoleMsg(newDeferCount.."\n")

			if newDeferCount == timeToPressKey then


				local r, value = reaper.GetProjExtState(proj, "NABLA", "STATE")
				local d, delete = reaper.GetProjExtState(proj, "NABLA", "DELETE")

				-- reaper.ShowConsoleMsg(tostring(value))

				if value ~= nil and tonumber(value) == 1 then -- ONE PRESS (Revisar esta función)

					Msg("-> Single Press", 1)
					local _, measure, _, _, _ = reaper.TimeMap2_timeToBeats( proj, reaper.GetPlayPosition() )

					if not flags[ "mea"..measure] then

						Msg("--> Run Action", 1)
						flags[ "start_stop"..measure] = true
						StartStopRecording()

					end

					newDeferCount = 0
					reaper.SetProjExtState(proj, "NABLA", "STATE", 0)

				elseif delete ~= nil and delete == "1" then

					local _, measure, _, _, _ = reaper.TimeMap2_timeToBeats( proj, reaper.GetPlayPosition() )

					if not flags[ "delete"..measure] then
						
						reaper.ClearAllRecArmed()
						reaper.Main_OnCommand(40670, 0) -- Record: Add recorded media to project
						reaper.Main_OnCommand(40006, 0) -- Delete items
						reaper.Main_OnCommand(41817, 0) reaper.Main_OnCommand(41817, 0)-- View: Continuous scrolling during playback
						reaper.Main_OnCommand(40036, 0) reaper.Main_OnCommand(40036, 0) -- View: Toggle auto-view-scroll during playback

					end

						newDeferCount = 0
						reaper.SetProjExtState(proj, "NABLA", "DELETE", 0)

				end

				reaper.SetProjExtState(proj, "NABLA", "STATE", 0)
				reaper.SetProjExtState(proj, "NABLA", "DELETE", 0)

			end

		------------------------------------------------------------------
		if newDeferCount == timeToPressKey then
	
				newDeferCount = 0 
	
			end
	
			newDeferCount = newDeferCount + 1 
			------------------------------------------------------------------
		if reaper.GetPlayState() == 0 then off_state() else reaper.defer(NewDeferActions) end

	end, errorHandler)

end

local state = reaper.GetPlayState()

if state ~= 0 then

	 NewDeferActions()
	 GetTimesKeyPressed()

end

reaper.atexit( off_state )
