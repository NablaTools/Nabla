--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper Arranged Settings. 
* Version: 0.1.0
* Author: Esteban Morales
* Author URI: http://forum.cockos.com/member.php?u=105939 
--]] 
--======================================================================
local gsub      = string.gsub
local gmatch    = string.gmatch
local match     = string.match
local format    = string.format
local insert    = table.insert
local lower     = string.lower

function GetIDByScriptName(scriptName)

	if type(scriptName)~="string"then 

		error("expects a 'string', got "..type(scriptName),2) 

	end;

	local file = io.open(reaper.GetResourcePath()..'/reaper-kb.ini','r'); 

	if not file then 
		return -1 
	end;

	local scrName = gsub(gsub(scriptName, 'Script:%s+',''), "[%%%[%]%(%)%*%+%-%.%?%^%$]",function(s)return"%"..s;end);

	for var in file:lines() do;

		if match(var, scrName) then

			id = "_"..gsub(gsub(match(var, ".-%s+.-%s+.-%s+(.-)%s"),'"',""), "'","")
			return id

		else

		end

	end;
	return -1;
end

local libPathNabla = reaper.GetExtState("Scythe v3 for Nabla", "libPathNabla")

if not libPathNabla or libPathNabla == "" then

	local scriptName = "Script: Scythe_Nabla library path.lua"
	local idbyscript = GetIDByScriptName(scriptName)
	reaper.Main_OnCommand(reaper.NamedCommandLookup(idbyscript),0)

end
------------------------------------------------------------------
-- GET/SET CONFIGURATION
------------------------------------------------------------------
local cItem = reaper.GetSelectedMediaItem(0, 0)
if not cItem then
	return
end
------------------------------------------------------------------
local vars = { 
	{'recordFdbk',  'RECORD_FDBK',  '1'     }, 
	{'recColor',    'REC_COLOR',    '1,0,0' }, 
	{'tkMrkColor',  'TKMRK_COLOR',  '0,1,0' },
}

for i = 1, #vars do

	local varName = vars[i][1]
	local section = vars[i][2]
	local value   = vars[i][3]

	_G[varName] = reaper.GetExtState( 'NABLA_LOOPER_ARRANGED', section )

	if _G[varName] == "" or _G[varName] == nil then

		reaper.SetExtState( 'NABLA_LOOPER_ARRANGED', section, value, true )

		_G[varName] = value

	end
end
------------------------------------------------------------------
local cTake = reaper.GetTake(cItem, 0)
if not cTake then return end
r, tkName = reaper.GetSetMediaItemTakeInfo_String( cTake, 'P_NAME', "", false ) 

local libPathNabla = reaper.GetExtState("Scythe v3 for Nabla", "libPathNabla")
loadfile(libPathNabla .. "scythe.lua")()

local GUI = require("gui.core")
local Frame = require("gui.elements.Frame")
local Label = require("gui.elements.Label")
local Table = require("public.table")
local Menubar = require("gui.elements.Menubar")
local window

local value = {}
local val_list = {}
local presets = {}
local numlist = {}
local val_set_new = {}
local name_exist = {}
local val_exist = {}

local retval = reaper.GetExtState( 'NABLA_PRESETS', 'PRESETS', "Loop" )

if retval == "" then
	reaper.SetExtState('NABLA_PRESETS', 'PRESETS', 'Loop', true)
	reaper.SetExtState('NABLA_PRESETS', 'NUMLIST', '20', true)
end

function AddPreset( ... )

	Scythe.quit = true
	
	retval, str = reaper.GetUserInputs("Add new preset", 2, "New preset name: , # Items in the list:, ?extrawidth=100", "New Name , 10")

	if retval == false then return end

	for substring in gmatch(str, '([^,]+)') do insert(val_set_new, substring) end


	local str_presets = reaper.GetExtState('NABLA_PRESETS', 'PRESETS')
	local str_list = reaper.GetExtState('NABLA_PRESETS', 'NUMLIST')
	if str_presets == "" or str_list == "" then return end

	for substring in gmatch(str_presets, '([^,]+)') do insert(name_exist, substring) end
	for substring in gmatch(str_list, '([^,]+)') do insert(val_exist, substring) end

	for i = 1 , #name_exist do

		--if name_exist[i] ~= nil then

			if lower( name_exist[i] ) == lower( val_set_new[1] ) then

				name_exist[i] = val_set_new[1]
				val_exist[i]  = val_set_new[2]

				strpresets = table.concat(name_exist, ",")
				strlist    = table.concat(val_exist, ",")

				reaper.SetExtState('NABLA_PRESETS', 'PRESETS', strpresets, true)
				reaper.SetExtState('NABLA_PRESETS', 'NUMLIST', strlist, true)

				val_set_new[1] = nil
				val_set_new[2] = nil

				return

			else

				if i == #name_exist then

					reaper.SetExtState('NABLA_PRESETS', 'PRESETS', str_presets .. "," .. val_set_new[1], true)
					reaper.SetExtState('NABLA_PRESETS', 'NUMLIST', str_list .. "," .. val_set_new[2], true)

					val_set_new[1] = nil
					val_set_new[2] = nil

					return
				end

			end

		--end

	end

end

function DeletePreset( ... )

	Scythe.quit = true
	
	retval, str = reaper.GetUserInputs("Delete preset", 1, "Preset name to delete: , ?extrawidth=100", "Name")

	if retval == false then return end

	for substring in gmatch(str, '([^,]+)') do insert(val_set_new, substring) end


	local str_presets = reaper.GetExtState('NABLA_PRESETS', 'PRESETS')
	local str_list = reaper.GetExtState('NABLA_PRESETS', 'NUMLIST')
	-- if str_presets == "" or str_list == "" then return end

	for substring in gmatch(str_presets, '([^,]+)') do insert(name_exist, substring) end
	for substring in gmatch(str_list, '([^,]+)') do insert(val_exist, substring) end

	for i = 1 , #name_exist do


		if name_exist[i] ~= nil then

			if lower( name_exist[i] ) == lower( val_set_new[1] ) and lower( name_exist[i] ) ~= "loop" then

				name_exist[i] = ""
				val_exist[i]  = ""

				str_presets = table.concat(name_exist, ",")
				str_list    = table.concat(val_exist, ",")

				reaper.SetExtState('NABLA_PRESETS', 'PRESETS', str_presets, true)
				reaper.SetExtState('NABLA_PRESETS', 'NUMLIST', str_list, true)

				-- val_set_new[1] = nil
				-- val_set_new[2] = nil

				return

			else

				--
				
			end

		end

	end

end




	local val = reaper.GetExtState('NABLA_PRESETS', 'PRESETS')
	local str_list = reaper.GetExtState('NABLA_PRESETS', 'NUMLIST')

	for substring in gmatch(val, '([^,]+)') do insert(value, substring) end
	for i = 1, #value do
		presets[i] = value[i]
	end

	for substring in gmatch(str_list, '([^,]+)') do insert(val_list, substring) end
	for i = 1, #val_list do
		numlist[i] = tonumber(val_list[i])
	end


set_new_name = function(self, str)
if str then
	a = str
else
	a = GUI.Val("textbox")
end
reaper.Undo_BeginBlock()
local numItems = reaper.CountSelectedMediaItems(0)
for i=0, numItems do
	local cItem = reaper.GetSelectedMediaItem(0, i)
	if cItem then
		local cTake = reaper.GetActiveTake( cItem )
		reaper.GetSetMediaItemTakeInfo_String( cTake, 'P_NAME', a, true ) 
	end
end
reaper.Undo_EndBlock("Rename Item: " ..a, -1)
Scythe.quit = true
end 
------------------------------------------------------------------
-- CREATE MENU STRING
------------------------------------------------------------------
menus = {
	{title = "                        --> Presets <--                        ", 
		options = {
			--
		}
	}
}

for i=1, #presets do
	
	local var_caption = presets[i]
	
	insert(menus[1].options, {caption = ">"..var_caption})
	
	for j=1, tonumber(numlist[i]) do
		
		if j < tonumber(numlist[i]) then
			
			insert(menus[1].options, {caption = var_caption.." "..j, func = set_new_name, params = {var_caption.." "..j}})
			
		else
			
			insert(menus[1].options, {caption = "<"..var_caption.." "..j, func = set_new_name, params = {var_caption.." "..j}})
			
		end

	end

	if i == #presets then
		insert(menus[1].options, {caption = "" })
		insert(menus[1].options, {caption = "Add New", func = AddPreset })
		insert(menus[1].options, {caption = "Delete", func = DeletePreset })
	end
end
------------------------------------
-------- Window settings -----------
------------------------------------
window = GUI.createWindow({
	name = "Rename Item(s)",
	x = 0, y = 0, w = 310, h = 120,
	anchor = "mouse",
	corner = "C",
})
------------------------------------
-------- GUI Elements --------------
------------------------------------
local layer = GUI.createLayer({name = "Layer1"})
layer:addElements( GUI.createElements(
{
	name = "mnu_menu",
	type = "Menubar",
	x = 0,
	y = 0,
	w = 310,
	h = 24,
	menus = menus,
	backgroundColor = "backgroundMenu",
	textColor = "textMenu", 
},
{ 
	name = "label_input",
	type = "Label",
	x = 20,
	y = 40,
	w = 120,
	h = 20,
	caption = "Input Name:",
},
{
	name = "textbox",
	type = "Textbox",
	x = 20,
	y = 70,
	w = 200,
	h = 20,
	caption = "",
	retval = tkName,
	caret = string.len( tkName ),
	selectionStart = 0,
	selectionEnd = string.len( tkName ),
	focus = "true",
},
{
	name = "btn_go",
	type = "Button",
	x = 230, y = 70, w = 60, h = 20,
	caption = "Set",
	func = set_new_name,
}
))


window:addLayers(layer)
window:open()
local finder = GUI.findElementByName("textbox")
window.state.focusedElm = finder
GUI.Main()