console = 0
reaper.ClearConsole()

function Msg(value, line)
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

local lower = string.lower
local match = string.match
local recTracks = {}

local function GetTrackLoopMode(track)

	if not track then return false end

	local _, name  = reaper.GetTrackName(track)
	local name     = lower(name)
	local action   = match(name, '^%[(.-)%]')

	if not action then return false end

	return action

end

local function SetTrackLoopMode( track, mode, new )

	if not track then return false end

	if new then

		local _, name  = reaper.GetTrackName(track)
		local newname  = "[" .. mode .. "] " .. name
		reaper.GetSetMediaTrackInfo_String( track, 'P_NAME', newname, true )

	else

		if mode == "disable" then
			local _, name  = reaper.GetTrackName(track)
			local name     = match(name, '%[.-%]%s?(.*)') or name
			-- Msg(name, 1)
			local newname  = name
			reaper.GetSetMediaTrackInfo_String( track, 'P_NAME', newname, true )
		else
			local _, name  = reaper.GetTrackName(track)
			local name     = match(name, '%[.-%]%s?(.*)')
			-- Msg(name, 1)
			local newname  = "[" .. mode .. "] " .. name
			reaper.GetSetMediaTrackInfo_String( track, 'P_NAME', newname, true )
		end

	end

end

local function SetLoopQN()
	local numSelTracks = reaper.CountSelectedTracks(proj)
	if numSelTracks == 0 then return end
	local r, lenQN = reaper.GetUserInputs("Set loop length in quarter notes", 1, "Quarter Notes: ?extrawidth=150", "")
	if not r then return end
	local lenQN = tonumber(lenQN)
	if type(lenQN) == "number" then

		for i = 0, numSelTracks-1 do
			local track = reaper.GetSelectedTrack(proj, i)
			local mode  = GetTrackLoopMode(track)
			
			if not mode then
				SetTrackLoopMode( track, lenQN, true )
			elseif mode == "r" or mode == "o" then
				SetTrackLoopMode( track, lenQN, false )
			else
				SetTrackLoopMode( track, lenQN, false )
			end

		end

	end
end

SetLoopQN()