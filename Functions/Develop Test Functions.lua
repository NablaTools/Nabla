local function msg(str)
  reaper.ShowConsoleMsg(tostring(str).."\n")
end
function reaperCMD(id)
  if type(id) == "string" then
    reaper.Main_OnCommand(reaper.NamedCommandLookup(id),0)
  else
    reaper.Main_OnCommand(id, 0)
  end
end
--------------------------------------------------------------
function GetIDByScriptName(scriptName);
  if type(scriptName)~="string"then 
    error("expects a 'string', got "..type(scriptName),2) 
  end;
  local file = io.open(reaper.GetResourcePath()..'/reaper-kb.ini','r'); 
  if not file then 
    return -1 
  end;
  local scrName = scriptName:gsub('Script:%s+',''):gsub("[%%%[%]%(%)%*%+%-%.%?%^%$]",function(s)return"%"..s;end);
  for var in file:lines() do;
    if string.match(var, scrName) then
      id = "_"..var:match(".-%s+.-%s+.-%s+(.-)%s"):gsub('"',""):gsub("'","")
      return id
    else
    end
  end;
  return -1;
end;
--------------------------------------------------------------
local scriptName = "Script: Nabla Fill to Main A.lua"
idbyscript=GetIDByScriptName(scriptName)
msg(idbyscript)
--------------------------------------------------------------
