exec(open('/tmp/test34.py').read().split('print("Einstellungen:"')[0])
la.execute('''
CALLS={}
local function mk()
  local d={}
  function d:CreateTitle(t) table.insert(CALLS,"T:"..t) end
  function d:CreateButton(t,f) table.insert(CALLS,"B:"..t); d["b_"..t]=f end
  function d:CreateDivider() end
  function d:CreateCheckbox(t,g,s) table.insert(CALLS,"C:"..t.."="..tostring(g())); d["c_"..t]={g,s} end
  return d
end
ROOT=mk()
MenuUtil={CreateContextMenu=function(o,gen) gen(o,ROOT) end}
''')
run('Minimap=Minimap or CreateFrame("Frame","Minimap") Minimap.GetWidth=Minimap.GetWidth or function() return 140 end IsShiftKeyDown=IsShiftKeyDown or function() return false end CBAS.Standards.CreateMinimapButton()')
print("btn:", la.eval('CBASMinimapButton ~= nil'))
print(run('CBASMinimapButton:GetScript("OnClick")(CBASMinimapButton,"RightButton")'))
for v in la.globals().CALLS.values(): print("  ", v)
print(run('''
local c=ROOT["c_Layerwechsel im Chat melden"]; local a=c[1](); c[2](); assert(a==false and CBASDB.settings.layerChat==true)
local e=ROOT["c_Englisch mit EN kennzeichnen"]; e[2](); assert(CBASDB.settings.flagEN==false)
local p=ROOT["c_Can-I-have-it-Popup"]; p[2](); assert(CBASDB.settings.cihi.popup==false); p[2](); assert(CBASDB.settings.cihi.popup==true)
local got; local S=CBASMinimapButton and select(2, nil) ; 
return "OK"'''))
print(run('CBAS_OnCompartmentClick("CBAS","RightButton",UIParent) return #CALLS'))
