--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper A - ITEM Start Stop
* Version: 0.3.0
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]] 
--======================================================================
nablaConfigs = {
	{ actionNumber = 40036, setstate = "on" }, -- View: Toggle auto-view-scroll during playback
	{ actionNumber = 41817, setstate = "on" }, -- View: Continuous scrolling during playback
	{ actionNumber = 41078, setstate = "off" }, -- FX: Auto-float new FX windows
	{ actionNumber = 40041, setstate = "off"}, -- Options: Toggle auto-crossfades
	{ actionNumber = 41117, setstate = "off"}, -- Options: Toggle trim behind items when editing
	{ actionNumber = 41330, setstate = "__" }, -- Options: New recording splits existing items and creates new takes (default)
	{ actionNumber = 41186, setstate = "__" }, -- Options: New recording trims existing items behind new recording (tape mode)
	{ actionNumber = 41329, setstate = "on" }, -- Options: New recording creates new media items in separate lanes (layers)
}
--======================================================================
console = 0
title = 'Nabla Looper A - ITEM Start Stop.lua'
version = "v.0.3.0"
info   = debug.getinfo(1,'S');
script_path  = info.source:match[[^@?(.*[\/])[^\/]-$]]
format    = string.format
match     = string.match
gsub      = string.gsub
gmatch    = string.gmatch
find      = string.find
sub       = string.sub
concat    = table.concat
insert    = table.insert
items      = {}
recTracks  = {}
flags      = {}
startTimes = {}
endTimes   = {}
practice   = {}
originalConfigs = {}
recItems   = {}
selected = false -- new notes are selected
--======================================================================
package.path = reaper.GetResourcePath().. package.config:sub(1,1) .. '?.lua;' .. package.path
require 'Scripts.Nabla.Functions.Nabla_Functions'
--======================================================================
saved, dir, sep = IsProjectSaved()
setActionState(1)
if reaper.GetPlayState() ~= 5 then
	CreateTableAllItems()
	CreateActionsTables()
	SetActionTracksConfig()
	GetSetNablaConfigs()
	SetReaperConfigs()
	SetPDC( preservePDC )
	if safeMode == "true" then xpcall( InsertReaDelay, errorHandler) end
	setIdxSatart()
	setIdxEnd()
	reaper.Main_OnCommand(40252, 0)
	reaper.CSurf_OnRecord()
	-- Defer Functions --
	ActivateRecording()
	ActivateMonitorMIDI()
	ActivateMonitorAUDIO()
	DeactivateMonitor()
	DeactivateRecording()
	WaitForEnd()
end
reaper.atexit(AtExitActions)
