--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - ITEM Clear
* Version: 0.3
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]] 
--======================================================================
------------------------------------------------------------------
-- Debug
------------------------------------------------------------------
local console = 0
local version = "0.3"

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
------------------------------------------------------------------
-- RECODE SCRIPT
------------------------------------------------------------------
local info   = debug.getinfo(1,'S');
script_path  = info.source:match[[^@?(.*[\/])[^\/]-$]]

reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_SAVETRACK'), 0)

local match  = string.match
local gmatch = string.gmatch
local gsub   = string.gsub
local insert = table.insert

local source = script_path.."clean_audio.wav"

local flags    = {}
local items    = {}
local recItems = {}

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
			local iLock       = reaper.GetMediaItemInfo_Value(cItem,"C_LOCK")
			local iLen        = reaper.GetMediaItemInfo_Value(cItem,"D_LENGTH")
			local lenQN       = reaper.TimeMap2_timeToQN( proj, iLen ) * 960
			local action        = GetItemAction(cItem)
			local source                     = reaper.GetMediaItemTake_Source(cTake)
			local _, _, _, mode = reaper.PCM_Source_GetSectionInfo( source )

			items[#items+1] = { 
				cItem       = cItem, 
				cTake       = cTake, 
				tkName      = tkName , 
				iLock       = iLock ,
				isRecord    = isRecord,
				isRecMute   = isRecMute,
				lenQN       = lenQN,
				type        = type,
				mode        = mode,
				special     = special,
			}

			if action == '1' or action == '2' then

				recItems[#recItems+1] = {  tkName = tkName, iLen = iLen, lenQN = lenQN }

			end

		end

	end
end
------------------------------------------------------------------
-- MAIN FUNCTION
------------------------------------------------------------------
function cleanUp()
	reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_RESTORETRACK'), 0)
end

function errorHandler(errObject)

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

function Main()
	reaper.Undo_BeginBlock()

	if #recItems <= 0 then return end
	for i = 1, #recItems do

		for j = 1, #items do

			local v = items[j]

			if not flags[v.cItem] then

				if recItems[i].tkName == v.tkName then

					flags[v.cItem] = true

					if v.iLock ~= 1 then

						if v.type == "MIDIPOOL" then

							local _, chunk    = reaper.GetItemStateChunk(v.cItem, '', false)
							local new_chunk = gsub(chunk, '<SOURCE%s+.->[\r]-[%\n]', "<SOURCE MIDIPOOL\n".."E "..string.format("%.0f",recItems[i].lenQN).." b0 7b 00".."\n>\n", 1)
							reaper.SetItemStateChunk(v.cItem, new_chunk, true) 
							reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )

						elseif v.type == "MIDI" then

							local _, chunk    = reaper.GetItemStateChunk(v.cItem, '', false)
							local new_chunk = gsub(chunk, '<SOURCE%s+.->[\r]-[%\n]', "<SOURCE MIDI\n".."E "..string.format("%.0f",recItems[i].lenQN).." b0 7b 00".."\n>\n", 1)
							reaper.SetItemStateChunk(v.cItem, new_chunk, true) 
							reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )

						else -- If AUDIO ANY TYPE

							local _, chunk    = reaper.GetItemStateChunk(v.cItem, '', false)

							if not match(chunk, '[%\n](SM%s+.-)[%\n]') then sm = false else sm = true end

							if v.mode then

								if v.special ~= '1' then

									if sm then

										local new_chunk = gsub(chunk, '[%\n]SM%s+.-[\r]-[%\n]', '\n', 1)
										reaper.SetItemStateChunk(v.cItem, new_chunk, true)

									end

									reaper.BR_SetTakeSourceFromFile2( v.cTake, source, false, true )
									reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )
									reaper.BR_SetMediaSourceProperties( v.cTake, true, 0, recItems[i].iLen, 0, true )
									reaper.SetMediaItemTakeInfo_Value( v.cTake, 'D_PLAYRATE', 1 )

								elseif v.special == '1' then

									reaper.BR_SetTakeSourceFromFile2( v.cTake, source, false, true )
									reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )
									reaper.BR_SetMediaSourceProperties( v.cTake, true, 0, recItems[i].iLen, 0, true )

								end

							else

								if v.special ~= '1' then

									if sm then

										local new_chunk = gsub(chunk, '[%\n]SM%s+.-[\r]-[%\n]', '\n', 1)
										reaper.SetItemStateChunk(v.cItem, new_chunk, true)

									end

									reaper.BR_SetTakeSourceFromFile2( v.cTake, source, false, true )
									reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )
									reaper.SetMediaItemTakeInfo_Value( v.cTake, 'D_PLAYRATE', 1 )

								elseif v.special == '1' then

									reaper.BR_SetTakeSourceFromFile2( v.cTake, source, false, true )
									reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName, true )

								end

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

CreateTableAllItems()
xpcall(Main, errorHandler)
reaper.atexit( cleanUp )
