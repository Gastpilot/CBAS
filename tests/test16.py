exec(open('/tmp/test14b.py').read().split('GW=ns.Geier')[0])
run=lua.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
lua.execute('''NOW=1000 GetTime=function() return NOW end
GetMaxPlayerLevel=function() return 60 end
local CL={{"Krieger","WARRIOR"},{"Magier","MAGE"},{"Priester","PRIEST"}}
GetNumClasses=function() return #CL end
GetClassInfo=function(i) return CL[i][1],CL[i][2],i end
WHO={} for i=1,50 do WHO[i]={fullName="O"..i,fullGuildName=(i%2==0) and "Nachtwache" or "",level=60,filename="MAGE",raceStr="Orc",area="Orgrimmar"} end
C_FriendList={SendWho=function(q) LASTQ=q end, GetNumWhoResults=function() return #WHO end, GetWhoInfo=function(i) return WHO[i] end}
CX,CY=500,300 GetCursorPosition=function() return CX,CY end''')
lua.eval('function() CBAS.BuildScanSteps() end')()
print("öffnen:", run('SlashCmdList["CBAS"]("gscout")'))
tx=lambda n: lua.eval('function(n) return CBAS.UI[n]:GetText() end')(n)
print("Städte-Knopf:", tx("capBtn"))
print("Klick:", run('CBAS.UI.capBtn._scripts.OnClick()'), lua.globals().LASTQ, "| Knopf:", tx("capBtn"))
print("Ergebnis:", run('CBAS.OnWhoUpdate()'))
lua.execute('NOW=1006'); run('CBAS.UI.frame._scripts.OnUpdate(CBAS.UI.frame,0.2)')
print("nach Sperre:", tx("capBtn"), "| Teilabfragen:", len(ns.capQueue))
print("nächster Klick:", run('CBAS.WhoCapitalStep()'), lua.globals().LASTQ)
print("60er-Liste ohne Städte:", "Orgrimmar" not in list(ns.Zone60List().values()))
print("--- Größe")
G='CBAS.Suite.grip'
print("Griff ziehen:", run(G+'._scripts.OnMouseDown('+G+',"LeftButton"); CX,CY=715,160; '+G+'._scripts.OnUpdate('+G+'); '+G+'._scripts.OnMouseUp('+G+')'))
print("  Skalierung:", round(lua.eval('CBASFrame:GetScale()'),2), "gespeichert:", round(ns.db.settings.frameScale,2))
print("Einstellungen +:", run('SlashCmdList["CBAS"]("settings"); local p=CBAS.Suite.panels.settings; for _,c in ipairs({p:GetChildren()}) do end'))
print("  /crap groesse 150:", run('SlashCmdList["CBAS"]("groesse 150")'), round(lua.eval('CBASFrame:GetScale()'),2))
print("  /crap groesse 999:", run('SlashCmdList["CBAS"]("groesse 999")'), round(lua.eval('CBASFrame:GetScale()'),2))
print("  Label:", lua.eval('CBAS.Suite.panels.settings.sizeLbl:GetText()'))
print("  Rechtsklick Griff:", run(G+'._scripts.OnClick()'), lua.eval('CBASFrame:GetScale()'))
print("  reset:", run('SlashCmdList["CBAS"]("reset")'), ns.db.settings.frameScale)
