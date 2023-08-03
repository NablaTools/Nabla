--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - ITEM Select Take
* Version: 0.3
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]] 
--======================================================================

console = 0
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
local gsub      = string.gsub
local gmatch    = string.gmatch
local match     = string.match
local format    = string.format
local insert    = table.insert

local cItem = reaper.GetSelectedMediaItem(proj, 0)

if not cItem then return reaper.defer(function () end) end

local takes   = {} 
local tStrRec = {}
local items = {}
local cTake        = reaper.GetActiveTake( cItem )
local name         = reaper.GetTakeName( cTake )
local subTkName    = match(name, '(.-)%sTK:%d+$')
local tkName       = subTkName or name
local sTkName      = tkName:gsub("%s+", "")
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
			local tkIdx       = match(name, '%d+$')
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
				tkIdx       = tkIdx,
				iLock       = iLock ,
				isRecord    = isRecord,
				isRecMute   = isRecMute,
				lenQN       = lenQN,
				type        = type,
				mode        = mode,
			}
		end
	end
end

local function PropagateAudio(sTkName, oldSource, oldSoffs, oldLen, key)
	reaper.Undo_BeginBlock()
	for i = 1, #items do
		local v = items[i]
		if v.tkName == sTkName then
			if v.iLock ~= 1 then
				local r, iChunk = reaper.GetItemStateChunk(v.cItem, "", false)
				if v.mode then
					local new_chunk = gsub(iChunk, '<SOURCE%s+.->', "<SOURCE SECTION\n".."LENGTH "..oldLen.."\n".."STARTPOS "..oldSoffs.."\n".."MODE  ".."2".."\n".."<SOURCE WAVE\n".."FILE ".."\""..oldSource.."\"".."\n>\n", 1)
					reaper.SetItemStateChunk(v.cItem, new_chunk, true) 
					reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName.." TK:"..format("%d",key), true )
				else
					local new_chunk = gsub(iChunk, '<SOURCE%s+.->', "<SOURCE SECTION\n".."LENGTH "..oldLen.."\n".."STARTPOS "..oldSoffs.."\n".."<SOURCE WAVE\n".."FILE ".."\""..oldSource.."\"".."\n>\n", 1)
					reaper.SetItemStateChunk(v.cItem, new_chunk, true)
					reaper.GetSetMediaItemTakeInfo_String( v.cTake, 'P_NAME', v.tkName.." TK:"..format("%d",key), true )
				end
			end      
		end
	end
	reaper.Undo_EndBlock("Propagate Audio", -1)
end

local function PropagateMIDI(tkName, source, key, cItem)
	reaper.Undo_BeginBlock()
	reaper.Main_OnCommand(41238, 0) -- Selection set: Save set #10
	reaper.Main_OnCommand(reaper.NamedCommandLookup("_BR_SAVE_CURSOR_POS_SLOT_16"), 0) -- SWS/BR: Save edit cursor position, slot 16
	reaper.SetOnlyTrackSelected(reaper.GetMediaItem_Track(cItem))
	reaper.SelectAllMediaItems(proj, 0)
	reaper.InsertMedia(source, 0)

	local cItem = reaper.GetSelectedMediaItem(proj, 0)
	if not cItem then return end
	local _, storedChunk = reaper.GetItemStateChunk(cItem, '', true)

	reaper.DeleteTrackMediaItem( reaper.GetMediaItem_Track(cItem), cItem )

	local new_chunk = match(storedChunk, '<SOURCE%s+.->[\r]-[%\n]')
	for i = 1, #items do
		local v = items[i]
		if v.isLock ~= 1 then
			if tkName == v.tkName then
				local _, iChunk = reaper.GetItemStateChunk(v.cItem, '', true)
				local setChunk = gsub(iChunk, '<SOURCE%s+.->', new_chunk, 1)
				reaper.SetItemStateChunk(v.cItem, setChunk, true) 
				reaper.GetSetMediaItemTakeInfo_String(v.cTake, 'P_NAME', tkName.." TK:"..format("%d", key), true )
			end
		end
	end

	reaper.Main_OnCommand(41248, 0) -- Selection set: Load set #10
	reaper.Main_OnCommand(reaper.NamedCommandLookup("_BR_RESTORE_CURSOR_POS_SLOT_16"), 0) -- SWS/BR: Restore edit cursor position, slot 16
	reaper.Undo_EndBlock("Propagate MIDI", -1)

end

local function GetNumForLoopTakes( cTake )
	for i = 0, 1000 do
		retval, key, val = reaper.EnumProjExtState( 0, cTake, i )
		if retval == false then return i+1 end
		takes[i+1] = val
		--reaper.ShowConsoleMsg(key.." -- "..val.."\n\n")
	end
end

function drawMenu(x,y, str)
	local retval = gfx.showmenu(str)
	if retval > 0 then
		local _, key, str_val = reaper.EnumProjExtState( 0, sTkName, string.format("%.0f", retval-1 ) )
		for substring in gmatch(str_val, '([^,]+)') do insert(tStrRec, substring) end
		if tStrRec[4] == "AUDIO" then
			PropagateAudio(tkName, tStrRec[1], tStrRec[2], tStrRec[3], key)
		elseif tStrRec[4] == "MIDI" then
			PropagateMIDI(tkName, tStrRec[1], key, cItem)
		end
	end
end

CreateTableAllItems()

local SHIFT_X = -50;
local SHIFT_Y = 15;
local x,y = reaper.GetMousePosition();
local x,y =  x+(SHIFT_X or 0),y+(SHIFT_Y or 0);

gfx.init('Select take',150,30,0,x,y)

local str = ''

for i = 0, 1000 do
	retval, key, val = reaper.EnumProjExtState( 0, sTkName, i )
	if retval == false then break end
	str = str.."|"..tkName.." - Take "..string.format("%d", key )
end

drawMenu(x,y,str)
