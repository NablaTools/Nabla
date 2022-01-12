--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - ITEM Clear
* Version: 0.3
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]] 
--======================================================================
local console = 0
local version = "0.3.0"

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


reaper.Main_OnCommand(reaper.NamedCommandLookup('_SWS_SAVETRACK'), 0)

local info   = debug.getinfo(1,'S');
local script_path  = info.source:match[[^@?(.*[\/])[^\/]-$]]
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
	local itemType   = reaper.GetMediaSourceType(source, "")
	if itemType ~= "SECTION" then
		return false, itemType
	else
		if not getsectiontype then
			return true, itemType
		else
			local r, chunk     = reaper.GetItemStateChunk(item, "", false)
			for itemType in  gmatch(chunk, '<SOURCE%s+(.-)[\r]-[%\n]') do
				if itemType ~= "SECTION" then
					return true, itemType
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

local function CreateTableAllItems()
	local count = reaper.CountMediaItems( proj )
	for i = 0, count - 1 do
		local codeItem       = reaper.GetMediaItem(proj, i)
		local _, itemType    = GetItemType( codeItem, true )
		if itemType ~= "UNKNOW" and itemType ~= "RPP_PROJECT" and itemType ~= "VIDEO" and itemType ~= "CLICK" and itemType ~= "LTC" and itemType ~= "VIDEOEFFECT" then
			local codeTake    = reaper.GetMediaItemTake(codeItem, 0)
			local takeName        = match(reaper.GetTakeName(codeTake), '(.-)%sTK:%d+$') or reaper.GetTakeName(codeTake)
			local iLock       = reaper.GetMediaItemInfo_Value(codeItem,"C_LOCK")
			local iLen        = reaper.GetMediaItemInfo_Value(codeItem,"D_LENGTH")
			local lenQN       = reaper.TimeMap2_timeToQN( proj, iLen ) * 960
			local action      = GetItemAction(codeItem)
			local source      = reaper.GetMediaItemTake_Source(codeTake)
			local _, _, _, mode = reaper.PCM_Source_GetSectionInfo( source )
			items[#items+1] = { 
				codeItem       = codeItem, 
				codeTake       = codeTake, 
				takeName      = takeName , 
				iLock       = iLock ,
				isRecord    = isRecord,
				isRecMute   = isRecMute,
				lenQN       = lenQN,
				itemType    = itemType,
				mode        = mode,
				special     = special,
			}
			if action == 'record' or action == 'record mute' then
				recItems[#recItems+1] = {  takeName = takeName, iLen = iLen, lenQN = lenQN }
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
			if not flags[v.codeItem] then
				if recItems[i].takeName == v.takeName then
					flags[v.codeItem] = true
					if v.iLock ~= 1 then
						if v.itemType == "MIDIPOOL" then
							local _, chunk    = reaper.GetItemStateChunk(v.codeItem, '', false)
							local new_chunk = gsub(chunk, '<SOURCE%s+.->[\r]-[%\n]', "<SOURCE MIDIPOOL\n".."E "..string.format("%.0f",recItems[i].lenQN).." b0 7b 00".."\n>\n", 1)
							reaper.SetItemStateChunk(v.codeItem, new_chunk, true) 
							reaper.GetSetMediaItemTakeInfo_String( v.codeTake, 'P_NAME', v.takeName, true )
						elseif v.itemType == "MIDI" then
							local _, chunk    = reaper.GetItemStateChunk(v.codeItem, '', false)
							local new_chunk = gsub(chunk, '<SOURCE%s+.->[\r]-[%\n]', "<SOURCE MIDI\n".."E "..string.format("%.0f",recItems[i].lenQN).." b0 7b 00".."\n>\n", 1)
							reaper.SetItemStateChunk(v.codeItem, new_chunk, true) 
							reaper.GetSetMediaItemTakeInfo_String( v.codeTake, 'P_NAME', v.takeName, true )
						else -- If AUDIO ANY itemType
							local _, chunk    = reaper.GetItemStateChunk(v.codeItem, '', false)
							if not match(chunk, '[%\n](SM%s+.-)[%\n]') then sm = false else sm = true end
							if v.mode then
								if v.special ~= '1' then
									if sm then
										local new_chunk = gsub(chunk, '[%\n]SM%s+.-[\r]-[%\n]', '\n', 1)
										reaper.SetItemStateChunk(v.codeItem, new_chunk, true)
									end
									reaper.BR_SetTakeSourceFromFile2( v.codeTake, source, false, true )
									reaper.GetSetMediaItemTakeInfo_String( v.codeTake, 'P_NAME', v.takeName, true )
									reaper.BR_SetMediaSourceProperties( v.codeTake, true, 0, recItems[i].iLen, 0, true )
									reaper.SetMediaItemTakeInfo_Value( v.codeTake, 'D_PLAYRATE', 1 )
								elseif v.special == '1' then
									reaper.BR_SetTakeSourceFromFile2( v.codeTake, source, false, true )
									reaper.GetSetMediaItemTakeInfo_String( v.codeTake, 'P_NAME', v.takeName, true )
									reaper.BR_SetMediaSourceProperties( v.codeTake, true, 0, recItems[i].iLen, 0, true )
								end
							else
								if v.special ~= '1' then
									if sm then
										local new_chunk = gsub(chunk, '[%\n]SM%s+.-[\r]-[%\n]', '\n', 1)
										reaper.SetItemStateChunk(v.codeItem, new_chunk, true)
									end
									reaper.BR_SetTakeSourceFromFile2( v.codeTake, source, false, true )
									reaper.GetSetMediaItemTakeInfo_String( v.codeTake, 'P_NAME', v.takeName, true )
									reaper.SetMediaItemTakeInfo_Value( v.codeTake, 'D_PLAYRATE', 1 )
								elseif v.special == '1' then
									reaper.BR_SetTakeSourceFromFile2( v.codeTake, source, false, true )
									reaper.GetSetMediaItemTakeInfo_String( v.codeTake, 'P_NAME', v.takeName, true )
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
