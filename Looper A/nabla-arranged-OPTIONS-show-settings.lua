--====================================================================== 
--[[ 
* ReaScript Name: Nabla Looper Arranged Settings. 
* Version: 0.1.0
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

local gsub      = string.gsub
local match     = string.match
local floor     = math.floor

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

local vars = { 
  {'safeMode',    'SAFE_MODE',    'true'  }, 
  {'startTime',   'START_TIME',   '1'     }, 
  {'bufferTime',  'BUFFER_TIME',  '1'     },
  {'preservePDC', 'PRESERVE_PDC', 'true'  }, 
  {'performance', 'PERFORMANCE',  '1'     }, 
  {'recordFdbk',  'RECORD_FDBK',  '3'     }, 
  {'recColor',    'REC_COLOR',    '1,0,0' }, 
  {'monColor',    'MON_COLOR',    '0,0,1' }, 
  {'tkMrkColor',  'TKMRK_COLOR',  '0,1,0' },
  {'practiceMode','PRACTICE_MOD', 'false' },
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

local color     = {recColor:match("^([^,]+),([^,]+),([^,]+)$")}
local mon_color = {monColor:match("^([^,]+),([^,]+),([^,]+)$")}
local mrkColor  = {tkMrkColor:match("^([^,]+),([^,]+),([^,]+)$")}
------------------------------------------------------------------

local libPathNabla = reaper.GetExtState("Scythe v3 for Nabla", "libPathNabla")
loadfile(libPathNabla .. "scythe.lua")()

local GUI   = require("gui.core")
local Frame = require("gui.elements.Frame")
local Label = require("gui.elements.Label")
local Table = require("public.table")
local Radio = require("gui.elements.Radio")

local window
------------------------------------------------------------------
--  TO BOOLEAN
------------------------------------------------------------------
--- asign to local
local type = type;
local assert = assert;
local strformat = string.format;
--- constants
local TRUE = {
    ['1'] = true,
    ['t'] = true,
    ['T'] = true,
    ['true'] = true,
    ['TRUE'] = true,
    ['True'] = true,
};
local FALSE = {
    ['0'] = false,
    ['f'] = false,
    ['F'] = false,
    ['false'] = false,
    ['FALSE'] = false,
    ['False'] = false,
};
local function toboolean( str )
    assert( type( str ) == 'string', 'str must be string' )
    if TRUE[str] == true then
        return true;
    elseif FALSE[str] == false then
        return false;
    else
        return false, strformat( 'cannot convert %q to boolean', str );
    end
end
------------------------------------------------------------------
-- SET NEW COLORS
------------------------------------------------------------------
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

function DelSetTakeMarker( action, cTake, rT, gT, bT, state )
  local numTkMarkers =  reaper.GetNumTakeMarkers( cTake )
  local startoffs = reaper.GetMediaItemTakeInfo_Value( cTake, 'D_STARTOFFS' )
  -- Set take marker
  if action == 'set' then

    for j=0, numTkMarkers-1 do

      local  _, name, _ = reaper.GetTakeMarker( cTake, j )
      if name == "Record" then

        reaper.DeleteTakeMarker( cTake, j )

	  elseif name == "Monitor" then

	  	reaper.DeleteTakeMarker( cTake, j )

      end

    end

    reaper.SetTakeMarker( cTake, -1, state, startoffs, reaper.ColorToNative(rT, gT, bT )|0x1000000 )

  -- Del take marker
  elseif action == 'del' then

    for j=0, numTkMarkers-1 do

      local  _, name, _ = reaper.GetTakeMarker( cTake, j )

      if name == "Record" or name == "Monitor" then
        reaper.DeleteTakeMarker( cTake, j )
      end

    end

  end

end

function SetNewColors(mode, r, g, b, R, G, B, mR, mG, mB)
  reaper.Undo_BeginBlock()
  local rI,gI,bI = floor((r * 255) + 0.5), floor((g * 255) + 0.5), floor((b * 255) + 0.5)
  local rM,gM,bM = floor((mR * 255) + 0.5), floor((mG * 255) + 0.5), floor((mB * 255) + 0.5)
  local rT,gT,bT = floor((R * 255) + 0.5), floor((G * 255) + 0.5), floor((B * 255) + 0.5)
  local sItems = reaper.CountMediaItems(proj)
  for i=0, sItems-1 do
    local cItem = reaper.GetMediaItem(proj, i)
    local cTake = reaper.GetMediaItemTake(cItem, 0)
    if not cTake then 
    	goto next
    end

    local startoffs = reaper.GetMediaItemTakeInfo_Value( cTake, 'D_STARTOFFS' )
    -- local _,state = reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_RECORDING', '', false)
    -- local _,stateMon = reaper.GetSetMediaItemInfo_String(cItem, 'P_EXT:ITEM_MON', '', false)
    local action = GetItemAction(cItem)

    if action == "1" then
      local numTkMarkers =  reaper.GetNumTakeMarkers( cTake )
      ------------------------------------------------------------------
      if mode == 1 then
        -- Cahnge Item color and Remove take marker
        reaper.SetMediaItemInfo_Value( cItem, 'I_CUSTOMCOLOR', reaper.ColorToNative(rI, gI, bI )|0x1000000 )
        DelSetTakeMarker( 'del', cTake)
      elseif mode == 2 then
        -- Change take marker and Remove item color
        DelSetTakeMarker( 'set', cTake, rT, gT, bT, 'Record' )
        reaper.SetMediaItemInfo_Value( cItem, 'I_CUSTOMCOLOR', 0 )
      elseif mode == 3 then
        -- Change item and take colors
        reaper.SetMediaItemInfo_Value( cItem, 'I_CUSTOMCOLOR', reaper.ColorToNative(rI, gI, bI )|0x1000000 )
        DelSetTakeMarker( 'set', cTake, rT, gT, bT, 'Record' )
      end
      ------------------------------------------------------------------

  	elseif action == "3" then
  		local numTkMarkers =  reaper.GetNumTakeMarkers( cTake )
  		------------------------------------------------------------------
  		if mode == 1 then
  		  -- Cahnge Item color and Remove take marker
  		  reaper.SetMediaItemInfo_Value( cItem, 'I_CUSTOMCOLOR', reaper.ColorToNative(rM, gM, bM )|0x1000000 )
  		  DelSetTakeMarker( 'del', cTake)
  		elseif mode == 2 then
  		  -- Change take marker and Remove item color
  		  DelSetTakeMarker( 'set', cTake, rT, gT, bT, 'Monitor' )
  		  reaper.SetMediaItemInfo_Value( cItem, 'I_CUSTOMCOLOR', 0 )
  		elseif mode == 3 then
  		  -- Change item and take colors
  		  reaper.SetMediaItemInfo_Value( cItem, 'I_CUSTOMCOLOR', reaper.ColorToNative(rM, gM, bM )|0x1000000 )
  		  DelSetTakeMarker( 'set', cTake, rT, gT, bT, 'Monitor' )
  		end
  		------------------------------------------------------------------
  		
    end  
    ::next::
  end ---
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Toggle Recording Item", -1)
end
------------------------------------------------------------------
-- SAVE CONFIGURATIONS
------------------------------------------------------------------
local function btn_click()
reaper.Undo_BeginBlock()
  local newMode = GUI.Val("optFoods")
  local opts = GUI.Val("chk_opts")
  local mode = GUI.Val("mnu_mode")
  local newcolor = GUI.Val("item_color")
  local newMonColor = GUI.Val("mon_picker_color")
  local newTkcolor = GUI.Val("tkMrk_color")
  local startTime = GUI.Val("pre_record")
  if startTime <= 0.3 then
    startTime = 0.3
  end
  Msg( newMode, 0 )
  local newvars = { 
    {'safeMode',    'SAFE_MODE',    opts[1]                }, 
    {'preservePDC', 'PRESERVE_PDC', opts[2]                }, 
    {'practiceMode','PRACTICE_MOD', opts[3]                },
    {'startTime',   'START_TIME',   startTime              }, 
    {'bufferTime',  'BUFFER_TIME',  GUI.Val("buffer")      },
    {'performance', 'PERFORMANCE',  newMode                }, 
    {'recordFdbk',  'RECORD_FDBK',  mode                   }, 
    {'recColor',    'REC_COLOR',    newcolor[1]..","..newcolor[2]..","..newcolor[3]        }, 
    {'monColor',    'MON_COLOR',    newMonColor[1]..","..newMonColor[2]..","..newMonColor[3]        }, 
    {'tkMrkColor',  'TKMRK_COLOR',  newTkcolor[1]..","..newTkcolor[2]..","..newTkcolor[3]  },
  }
  for i=1, #newvars do
    reaper.SetExtState( 'NABLA_LOOPER_ARRANGED', newvars[i][2], tostring(newvars[i][3]), true )
  end
  SetNewColors(mode, newcolor[1], newcolor[2], newcolor[3], newTkcolor[1], newTkcolor[2], newTkcolor[3],newMonColor[1] ,newMonColor[2] ,newMonColor[3] )
  reaper.Undo_EndBlock("Set configurations", 0)
  Scythe.quit = true
end
------------------------------------
-------- Window settings -----------
------------------------------------
window = GUI.createWindow({
  name = "Arranged Mode Settings",
  x = 0, y = 0, w = 222, h = 485,
  anchor = "mouse",
  corner = "C",
})
------------------------------------
-------- GUI Elements --------------
------------------------------------
local layer_3 = GUI.createLayer({name = "Layer_3", z = 3})
layer_3:addElements( GUI.createElements(
  
  {
    name = "frmDivider",
    type = "Frame",
    x = 20,
    y = 20,
    w = window.w-40,
    h = window.h-40,
  }
  
  ))

local layer_2 = GUI.createLayer({name = "Layer_2", z = 2})
layer_2:addElements( GUI.createElements(
  
  --    {
  --   name = "frm_Divider",
  --   type = "Frame",
  --   x = 32,
  --   y = 280,
  --   w = 93,
  --   h = 24,
  -- },
  {
    name = "lab_header",
    type = "Label",
    x = 70,
    y = 10,
    w = 82,
    h = 20,
    font = 2,
    --color = {mrkColor[1],mrkColor[2],mrkColor[3]},
    caption = "  Options  ",
  }
  
  ))
local layer = GUI.createLayer({name = "Layer1"})
layer:addElements( GUI.createElements(
  -- {
  --   name = "optFoods",
  --   type = "Radio",
  --   x = 32,
  --   y = 32,
  --   w = 160,
  --   h = 80,
  --   caption = "",
  --   options = {"Performance Mode 1","Performance Mode 2" },
  --   frame = false,

  --   dir = "v",
  --   swap = false,
  --   --tooltip = "Well hey there!"
  -- },
  {
    name = "chk_opts",
    type =  "Checklist",
    x = 32, y = 42, w = 160, h = 80,
    caption = "",
    options = {"Safe Mode", "Preserve PDC", "Practice Mode"},
    selectedOptions = { toboolean( safeMode ), toboolean(preservePDC), toboolean(practiceMode)},
    frame = false,
    dir = "v",
    pad = 6
  },
  {
    name = "pre_record",
    type = "Slider",
    x = 50, y = 177, w = 122,
    caption = "Pre Recording Time:",
    min = 0,
    max = 2,
    defaults = 0,
    inc = 0.1,
    dir = "h",
    output = "%val% s",
  },
  {
    name = "buffer",
    type = "Slider",
    x = 50, y = 237, w = 122,
    caption = "Buffer Time:",
    min = 0,
    max = 4,
    defaults = 0,
    inc = 0.1,
    dir = "h",
    output = "%val% s",
  },
  {
    name = "mnu_mode",
    type =  "Menubox",
    x = 125, y = 282, w = 70, h = 20,
    caption = "Item Appearance:",
    options = {"Color","Take Marker","Color/Marker"},
    retval = recordFdbk,
  },
  {
    name = "item_color",
    type = "ColorPicker",
    x = 150, y = 322, w = 24, h = 24,
    color = {color[1],color[2],color[3]},
    caption = "Record Item Color:",
  },
  {
    name = "mon_picker_color",
    type = "ColorPicker",
    x = 150, y = 357, w = 24, h = 24,
    color = {mon_color[1],mon_color[2],mon_color[3]},
    caption = "Monitor Item Color:",
  },
  {
    name = "tkMrk_color",
    type = "ColorPicker",
    x = 150, y = 395, w = 24, h = 24,
    color = {mrkColor[1],mrkColor[2],mrkColor[3]},
    caption = "Take Marker Color:",
  },
  {
    name = "btn_go",
    type = "Button",
    x = 79, y = 430, w = 64, h = 24,
    caption = "Save",
    textColor = 'textMenu',
    fillColor = 'backgroundMenu',
    func = btn_click
  }
))

------------------------------------
-------- Main functions ------------
------------------------------------
local function Main()
  if window.state.resized then
    window:reopen({w = window.w, h = window.h})
  end
end

window:addLayers(layer_3)
window:addLayers(layer_2)
window:addLayers(layer)
GUI.Val("pre_record", startTime*10)
GUI.Val("buffer", bufferTime*10)
GUI.Val("optFoods", tonumber(performance))
window:open()
GUI.func = Main
GUI.funcTime = 0
GUI.Main()