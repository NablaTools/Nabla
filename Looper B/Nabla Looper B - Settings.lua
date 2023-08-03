-- Nabla Looper Manual Settings
local gsub      = string.gsub
local match     = string.match
local reaper = reaper
local proj = proj

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
-- GET/SET CONFIGURATIONS
------------------------------------------------------------------
local vars = { 
  {'safeMode',       'SAFE_MODE',      'true'   },
  {'startTime',      'START_TIME',     '1'     	},
  {'bufferTime',     'BUFFER_TIME',    '1'     	},
  {'preservePDC',    'PRESERVE_PDC',   'true'   },
  {'linkTriggers',   'LINK_TRIGGERS',  'true'   },
  {'hotkey',         'HOTKEY_VAL',     '0'     	},
  {'hotkeyName',     'HOTKEY_NAME',     ' '     },
}

for i=1, #vars do
  local varName = vars[i][1] 
  _G[varName] = reaper.GetExtState( 'NABLA_LOOPER_B', vars[i][2] )
  if _G[varName] == "" or _G[varName] == nil then
    reaper.SetExtState( 'NABLA_LOOPER_B', vars[i][2], vars[i][3], true )
    _G[varName] = vars[i][3]
  end
end
------------------------------------------------------------------

loadfile(libPathNabla .. "scythe.lua")()

local GUI   = require("gui.core")
local Frame = require("gui.elements.Frame")
local Label = require("gui.elements.Label")
local Table = require("public.table")
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
-- SAVE CONFIGURATIONS
------------------------------------------------------------------
local function btn_click()
  reaper.Undo_BeginBlock()
  local opts = GUI.Val("chk_opts")
  local startTime = GUI.Val("pre_record")
  if startTime <= 0.3 then
    startTime = 0.3
  end
  local newvars = {
    {'safeMode',       'SAFE_MODE',      opts[1]                },
    {'startTime',      'START_TIME',     startTime              },
    {'bufferTime',     'BUFFER_TIME',    GUI.Val("buffer")      },
    {'preservePDC',    'PRESERVE_PDC',   opts[2]                },
    {'linkTriggers',   'LINK_TRIGGERS',  opts[3]     			},
  }
  for i=1, #newvars do
    reaper.SetExtState( 'NABLA_LOOPER_B', newvars[i][2], tostring(newvars[i][3]), true )
  end
  reaper.Undo_EndBlock("Set configurations", 0)
  Scythe.quit = true
end

function getHotkey()
  -- Scythe.quit = true
  -- local scriptName = "Script: Nabla Looper Manual Keyboard Shortcut (Nabla Looper).lua"
  -- local idbyscript = GetIDByScriptName(scriptName)
  -- reaper.Main_OnCommand(reaper.NamedCommandLookup(idbyscript),0)
end
------------------------------------
-------- Window settings -----------
------------------------------------
window = GUI.createWindow({
  name = "Manual Mode Settings",
  x = 0, y = 0, w = 222, h = 380,
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

  {
    name = "frm_Divider",
    type = "Frame",
    x = 32,
    y = 280,
    w = 93,
    h = 24,
  },
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

local layer = GUI.createLayer({name = "Layer_1", z = 1})
layer:addElements( GUI.createElements(
  {
    name = "chk_opts",
    type =  "Checklist",
    x = 32, y = 32, w = 160, h = 100,
    caption = "",
    frame = false,
    options = {"Safe Mode", "Preserve PDC", "Link Triggers"},
    selectedOptions = { toboolean( safeMode ), toboolean(preservePDC), toboolean(linkTriggers)},
    dir = "v",
    pad = 6
  },
  {
    name = "pre_record",
    type = "Slider",
    x = 50, y = 155, w = 122,
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
    x = 50, y = 215, w = 122,
    caption = "Buffer Time:",
    min = 0,
    max = 4,
    defaults = 0,
    inc = 0.1,
    dir = "h",
    output = "%val% s",
  },
  {
    name = "label_shortcut",
    type = "Label",
    x = 42, 
    y = 260, 
    --w = 24, 
    h = 24,
    font = 3,
    --color = {mrkColor[1],mrkColor[2],mrkColor[3]},
    caption = "Actual Keyboard Shortcut:",
  }, 
  {
    name = "label_val",
    type = "Label",
    x = 38,
    y = 284,
    w = 90,
    h = 20,
    font = 3,
    --color = {mrkColor[1],mrkColor[2],mrkColor[3]},
    caption = " "..hotkeyName,
  },
  {
    name = "btn_hotkey",
    type = "Button",
    x = 130, y = 282, 
    w = 60, 
    h = 20,
    caption = 'Change',
    func = getHotkey,
  },

  {
    name = "btn_go",
    type = "Button",
    x = 81, y = 324, 
    w = 64, h = 24,
    caption = 'Save',
    textColor = 'textMenu',
    fillColor = 'backgroundMenu',
    func = btn_click,
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

window:open()

GUI.func = Main
GUI.funcTime = 0
GUI.Main()
