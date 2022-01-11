-- Nabla Looper Manual Kerboard Shortcut (Nabla Looper)
local tValues = {"Space", "!", "«", "#", "$", "%", "&", "‘", "(", ")", "*", "+", ",", "–", ".", "/", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";", "<", "=", ">", "?", "@", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "[", "=", "]", "^", "_", "`", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "{", "|", "}", "~"}
local name, x, y, w, h = "Set shortcut", 300, 60, 200, 200

if reaper.GetExtState( 'NABLA_LOOPER_MANUAL', 'HOTKEY_VAL') == "" then
	reaper.SetExtState( 'NABLA_LOOPER_MANUAL', 'HOTKEY_VAL', 0, true )
end

------------------------------------------------------------------
local gsub      = string.gsub
local match     = string.match

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

local libPathNabla = reaper.GetExtState("Scythe v3 for Nabla", "libPathNabla")
loadfile(libPathNabla .. "scythe.lua")()

local GUI   = require("gui.core")
local Frame = require("gui.elements.Frame")
local Label = require("gui.elements.Label")
local Table = require("public.table")
local window

local char
local valor = "0"
local str = reaper.GetExtState( 'NABLA_LOOPER_MANUAL', 'HOTKEY_NAME')
------------------------------------------------------------------
window = GUI.createWindow({
  name = "Keyboard Input",
  x = 0, y = 0, w = 222, h = 118,
  anchor = "mouse",
  corner = "C",
})

local layer_2 = GUI.createLayer({name = "Layer_2", z = 2})
layer_2:addElements( GUI.createElements(
  
  {
    name = "frmDivider",
    type = "Frame",
    x = 20,
    y = 20,
    w = window.w-40,
    h = window.h-40,
  }
  
  ))

local layer = GUI.createLayer({name = "Layer1", z = 1})
layer:addElements( GUI.createElements(
	{
	  name = "label",
	  type = "Label",
	  x = 48, y = 10, 
	  --w = 24, 
	  h = 24,
	  caption = "<< Type a key >>",
	},
  {
    name = "textbox",
    type = "Textbox",
    caption = "Actual Shortcut:",
    x = 70,
    y = 64,
    w = 80,
    h = 24,
    captionPosition = "top",
    retval = str,
  }



))



-- local strChar = string.char

local function GetChar()

	char = gfx.getchar(0)

	if char == 27 or char == -1 then

		return 0

	elseif char >= 32 and char <= 127 then

		if char >= 97 and  char <= 122 then

			char = char-32
			valor = tValues[char-31]

		else

			valor = tValues[char-31]

		end

		reaper.SetExtState( 'NABLA_LOOPER_MANUAL', 'HOTKEY_VAL', char, true )
		reaper.SetExtState( 'NABLA_LOOPER_MANUAL', 'HOTKEY_NAME', valor, true )
		gfx.quit()
		reaper.ShowMessageBox("Set the same shortcut for \"Script: Nabla Looper Manual Shortcut (Action List)\" into the action list.", "You set \""..valor.."\" as shortcut", 0)
		
		local state = reaper.GetToggleCommandState(40605)

		if state == 0 then
			reaper.Main_OnCommand(40605, 0)
		end

		return 0

	elseif char == 13 then

		reaper.SetExtState( 'NABLA_LOOPER_MANUAL', 'HOTKEY_VAL', char, true )
		reaper.SetExtState( 'NABLA_LOOPER_MANUAL', 'HOTKEY_NAME', "Enter", true )
		gfx.quit()
		reaper.ShowMessageBox("Set the same shortcut for \"Script: Nabla Looper Manual Shortcut (Action List)\" into the action list.", "You set \"".."Enter".."\" as shortcut", 0)

		local state = reaper.GetToggleCommandState(40605)

		if state == 0 then
			reaper.Main_OnCommand(40605, 0)
		end

	end
	--gfx.x, gfx.y = 32, 20
	--gfx.setfont("Arial", 80, 0 )
	
	--gfx.drawstr(str)
	--gfx.update()
	reaper.defer(GetChar)
end

------------------------------------
-------- Main functions ------------
------------------------------------
local function Main()

  if window.state.resized then
    window:reopen({w = window.w, h = window.h})
  end

end

window:addLayers(layer_2)
window:addLayers(layer)
window:open()
GUI.func = Main

-- How often (in seconds) to run GUI.func. 0 = every loop.
GUI.funcTime = 0
GetChar()
GUI.Main()

