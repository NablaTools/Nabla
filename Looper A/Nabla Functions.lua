
local function GetSectionProperties(item)

	if not item then return false end

	local take   = reaper.GetActiveTake(item)

	if not take then return false end

	local source = reaper.GetMediaItemTake_Source(take)
	local type   = reaper.GetMediaSourceType(source, "")

	if type == "SECTION" then
		local retval, startpos, length, mode = reaper.PCM_Source_GetSectionInfo( source )
		return true, length, startpos, mode
	else
		return false
	end
end

local function GetSectionParam(section_chunk, param)
	local value = match(section_chunk, param..'%s+(.-)[\r]-[%\n]')
	if value then return value else return "" end
end

local function NT_GetSectionProperties(item)

	if not item then return false end

	local take   = reaper.GetActiveTake(item)

	if not take then return false end

	local source = reaper.GetMediaItemTake_Source(take)
	local type   = reaper.GetMediaSourceType(source, "")

	if type == "SECTION" then
		local r, chunk = reaper.GetItemStateChunk(item, "", false)
		local section = match(chunk, '<SOURCE%s+.->[\r]-[%\n]')
		local length   = GetSectionParam(section, "LENGTH")
		local startpos = GetSectionParam(section, "STARTPOS")
		local overlap  = GetSectionParam(section, "OVERLAP")
		local mode     = GetSectionParam(section, "MODE")
		return true, length, startpos, overlap, mode
	else
		return false
	end
end

local function SetSectionParam( section, key, param )
	local section    = gsub( section, '[%\n]' .. key .. '%s+(.-)[%\n]', param)
	return section
end

local function SetTakeSourceFromFile(take, filename, inProjectData, keepSourceProperties)

	if take and file_exists(filename) then

		local oldSource =  reaper.GetMediaItemTake_Source( take )
		local properties = false

		if keepSourceProperties then

			local properties, length, startpos, reverse = GetSectionProperties( reaper.GetMediaItemTake_Item(take) )
			if properties then
				SetMediaSourceProperties(take, section, start, len, fade, reverse)
			end

			local newSource = PCM_Source_CreateFromFileEx(filename, inProjectData)
			reaper.SetMediaItemTake_Source( take, newSource )
			reaper.PCM_Source_Destroy( oldSource )

			return true

		else

			local newSource = PCM_Source_CreateFromFileEx(filename, inProjectData)
			reaper.SetMediaItemTake_Source( take, newSource )
			reaper.PCM_Source_Destroy( oldSource )
			

			return true

		end
	
	else

		return false

	end

end
------------------------------------------------------------------
-- ITEMS
------------------------------------------------------------------
local function GetItemType( item, getsectiontype ) -- MediaItem* item, boolean* getsectiontype

	local take   = reaper.GetActiveTake(item)
	if not take then return false, "UNKNOW" end
	local source = reaper.GetMediaItemTake_Source(take)
	local type   = reaper.GetMediaSourceType(source, "")

	-- Return: boolean isSection, if getsectiontype then return string SECTION TYPE, if not then return "SECTION".
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

local function TrimItem (item, start, endpos )

	if not item then return false end

	if start > endpos then
		start, endpos = endpos, start
	end

	if start <= 0 then
		start = 0
	end

	local newlen = endpos - start

	if newlen <= 0 then
		return false
	end

	local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
	local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

	local itemLooped = reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC")

	local activeTake = reaper.GetActiveTake(item)

	if start ~= itemPos or newlen ~= itemLen then

		local startDif = start - itemPos
		reaper.SetMediaItemInfo_Value(item, "D_LENGTH", newlen)
		reaper.SetMediaItemInfo_Value(item, "D_POSITION", start)

		for i = 0, reaper.CountTakes(item)-1 do
			local take = reaper.GetTake(item, i)
			local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
			local offset   = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
			reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", offset + playrate*startDif);

			if reaper.TakeIsMIDI(take) then

				reaper.SetActiveTake(take)

				if not itemLooped then
					reaper.MIDI_SetItemExtents(item, reaper.TimeMap_timeToQN(start), reaper.TimeMap_timeToQN(endpos))
				end

			end

		end

		reaper.SetActiveTake(activeTake)
		return true

	end

	return false

end
------------------------------------------------------------------
-- TABLA ALL TRACKS
------------------------------------------------------------------
local function CreateTableAllTracks()

	local count = reaper.GetNumTracks()

	for i = 0, count - 1 do

		local track 		 = reaper.CSurf_TrackFromID(i, false)
		local _, name  = reaper.GetTrackName( track )
		local trRecInput = reaper.GetMediaTrackInfo_Value( track, 'I_RECINPUT' )
		local trRecMode  = reaper.GetMediaTrackInfo_Value( track, 'I_RECMODE'  )

		tracks[i+1] = {
			track      = track,
			name       = name,
			trRecInput = trRecInput,
			trRecMode  = trRecMode,
		}

	end
end
------------------------------------------------------------------
-- TABLA ALL ITEMS
------------------------------------------------------------------
local function CreateTableAllItems()

	local count = reaper.CountMediaItems(proj)

	for i = 0, count - 1 do

		local cItem           = reaper.GetMediaItem(proj, i)
		local _, type         = GetItemType( cItem, true )

		if type ~= "UNKNOW" and type ~= "RPP_PROJECT" and type ~= "VIDEO" and type ~= "CLICK" and type ~= "LTC" and type ~= "VIDEOEFFECT" then

			local iPos          = tonumber(format("%.3f", reaper.GetMediaItemInfo_Value(cItem,"D_POSITION")))
			local siPos         = "i"..gsub(tostring(iPos), "%.+","")
			local iLen          = reaper.GetMediaItemInfo_Value(cItem,"D_LENGTH")
			local iEnd          = tonumber(format("%.3f", iPos+iLen))
			local siEnd         = "o"..gsub(tostring(iEnd), "%.+","")
			local r, isRec      = reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_RECORDING', '', false)
			local r, isMon      = reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_MON', '', false)
			local r, isRecMute  = reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_RECMUTE', '', false)
			local cTake         = reaper.GetActiveTake( cItem )
			local name          = reaper.GetTakeName( cTake )
			local subTkName     = match(name, '(.-)%sTK:%d+$')
			local tkName        = subTkName or name
			local sTkName       = tkName:gsub("%s+", "")
			local tkIdx         = match(tkName, '%d+$')
			local cTrack        = reaper.GetMediaItem_Track( cItem )
			local trRecInput    = reaper.GetMediaTrackInfo_Value(cTrack, 'I_RECINPUT')
			local trRecMode     = reaper.GetMediaTrackInfo_Value( cTrack, 'I_RECMODE' )
			local itemLock      = reaper.GetMediaItemInfo_Value( cItem, 'C_LOCK')
			local source 				= reaper.GetMediaItemTake_Source(cTake)
			local _, _, _, mode = reaper.PCM_Source_GetSectionInfo( source )

			items[#items+1] = {
				cItem        = cItem, 
				iPos         = iPos, 
				iEnd         = iEnd, 
				siPos        = siPos, 
				siEnd        = siEnd,
				isRec        = isRec,
				isMon        = isMon,
				isRecMute    = isRecMute,
				iLen         = iLen, 
				cTake        = cTake, 
				tkName       = tkName, 
				tkIdx        = tkIdx,
				cTrack       = cTrack,
				trRecInput   = trRecInput, 
				sTkName      = sTkName, 
				buffer       = 0,
				record       = 0,
				mode         = mode,
				trRecMode    = trRecMode,
				type         = type,
				itemLock     = itemLock,
			}

		end
	end

	table.sort(items, function(a,b) return a.iPos < b.iPos end) 

end