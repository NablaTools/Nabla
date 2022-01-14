--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - ITEM Clear
* Version: 0.3.0
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]] 
--======================================================================
console = 0
title = 'Nabla Looper A - ITEM Clear.lua'
version = "v.0.3.0"
info   = debug.getinfo(1,'S');
script_path  = info.source:match[[^@?(.*[\/])[^\/]-$]]
match  = string.match
gmatch = string.gmatch
gsub   = string.gsub
insert = table.insert
format    = string.format
cleanAudioSource = script_path.."clean_audio.wav"
flags    = {}
items    = {}
recItems = {}
--======================================================================
package.path = reaper.GetResourcePath().. package.config:sub(1,1) .. '?.lua;' .. package.path
require 'Scripts.Nabla.Functions.Nabla_Functions'
--======================================================================
function Main()
	reaper.Undo_BeginBlock()
	if #recItems <= 0 then return end
	for i = 1, #recItems do
		for j = 1, #items do
			local v = items[j]
			if not flags[v.itemCode] then
				if recItems[i].takeName == v.takeName then
					flags[v.itemCode] = true
					if v.itemLock == 1 then return end
					if v.itemType == "MIDIPOOL" then
						local _, chunk    = reaper.GetItemStateChunk(v.itemCode, '', false)
						local new_chunk = gsub(chunk, '<SOURCE%s+.->[\r]-[%\n]', "<SOURCE MIDIPOOL\n".."E "..string.format("%.0f",recItems[i].itemLengthQN).." b0 7b 00".."\n>\n", 1)
						reaper.SetItemStateChunk(v.itemCode, new_chunk, true) 
						reaper.GetSetMediaItemTakeInfo_String( v.takeCode, 'P_NAME', v.takeName, true )
					elseif v.itemType == "MIDI" then
						local _, chunk    = reaper.GetItemStateChunk(v.itemCode, '', false)
						local new_chunk = gsub(chunk, '<SOURCE%s+.->[\r]-[%\n]', "<SOURCE MIDI\n".."E "..string.format("%.0f",recItems[i].itemLengthQN).." b0 7b 00".."\n>\n", 1)
						reaper.SetItemStateChunk(v.itemCode, new_chunk, true) 
						reaper.GetSetMediaItemTakeInfo_String( v.takeCode, 'P_NAME', v.takeName, true )
					else
						local _, chunk    = reaper.GetItemStateChunk(v.itemCode, '', false)
						if not match(chunk, '[%\n](SM%s+.-)[%\n]') then sm = false else sm = true end
						if v.itemMode then
							if v.special ~= '1' then
								if sm then
									local new_chunk = gsub(chunk, '[%\n]SM%s+.-[\r]-[%\n]', '\n', 1)
									reaper.SetItemStateChunk(v.itemCode, new_chunk, true)
								end
								reaper.BR_SetTakeSourceFromFile2( v.takeCode, cleanAudioSource, false, true )
								reaper.GetSetMediaItemTakeInfo_String( v.takeCode, 'P_NAME', v.takeName, true )
								reaper.BR_SetMediaSourceProperties( v.takeCode, true, 0, recItems[i].itemLength, 0, true )
								reaper.SetMediaItemTakeInfo_Value( v.takeCode, 'D_PLAYRATE', 1 )
							elseif v.special == '1' then
								reaper.BR_SetTakeSourceFromFile2( v.takeCode, cleanAudioSource, false, true )
								reaper.GetSetMediaItemTakeInfo_String( v.takeCode, 'P_NAME', v.takeName, true )
								reaper.BR_SetMediaSourceProperties( v.takeCode, true, 0, recItems[i].itemLength, 0, true )
							end
						else
							if v.special ~= '1' then
								if sm then
									local new_chunk = gsub(chunk, '[%\n]SM%s+.-[\r]-[%\n]', '\n', 1)
									reaper.SetItemStateChunk(v.itemCode, new_chunk, true)
								end
								reaper.BR_SetTakeSourceFromFile2( v.takeCode, cleanAudioSource, false, true )
								reaper.GetSetMediaItemTakeInfo_String( v.takeCode, 'P_NAME', v.takeName, true )
								reaper.SetMediaItemTakeInfo_Value( v.takeCode, 'D_PLAYRATE', 1 )
							elseif v.special == '1' then
								reaper.BR_SetTakeSourceFromFile2( v.takeCode, cleanAudioSource, false, true )
								reaper.GetSetMediaItemTakeInfo_String( v.takeCode, 'P_NAME', v.takeName, true )
							end
						end
					end
				end
			end
		end --
	end
	reaper.Main_OnCommand(40047, 0)
	reaper.UpdateArrange()
	reaper.Undo_EndBlock("Clear items", -1)
end

saveTrackSelection()
CreateTableAllItems()
CreateRecordItemsTable()
xpcall(Main, errorHandler)
reaper.atexit( restoreTrackSelection )
