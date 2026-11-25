exec(open('/tmp/test10.py').read().split('GW=ns.Geier')[0].replace(
 'SendChatMessage=function(m,c) SENT={m,c} end',
 '''SendChatMessage=function(m,c) SENT={m,c} end
ITEMS[20]={"Schild der Wacht",4,66,"INVTYPE_SHIELD",4,6,1,{ITEM_MOD_STAMINA_SHORT=10},{"Schild der Wacht","Anlegen: Erhöht die Verteidigung um 7."}}
ITEMS[21]={"Robe der Heilung",4,66,"INVTYPE_ROBE",4,1,1,{ITEM_MOD_INTELLECT_SHORT=15},{"Robe der Heilung","Anlegen: Erhöht durch Zauber und Effekte verursachte Heilung um bis zu 40."}}
ITEMS[22]={"Robe der Zerstörung",4,66,"INVTYPE_ROBE",4,1,1,{ITEM_MOD_INTELLECT_SHORT=15},{"Robe der Zerstörung","Anlegen: Erhöht durch Zauber und magische Effekte verursachten Schaden um bis zu 30."}}
ITEMS[23]={"Bärenfell-Weste",4,66,"INVTYPE_CHEST",4,2,1,{ITEM_MOD_AGILITY_SHORT=20,ITEM_MOD_STAMINA_SHORT=20},{"Bärenfell-Weste","Anlegen: Erhöht die Ausweichchance um 1%."}}
ROLES={party1="TANK",party2="DAMAGER",party3="HEALER",party4="DAMAGER"}
UnitGroupRolesAssigned=function(u) return ROLES[u] or "NONE" end
GROUP.party1={"Bob","WARRIOR",60} GROUP.party3={"Pia","PRIEST",60}
GROUP.party2={"Dru","DRUID",60}
NOW=1000 GetTime=function() return NOW end
UnitGUID=function(u) return "G-"..u end
UnitIsConnected=function() return true end
CanInspect=function() return true end
CheckInteractDistance=function() return true end
NotifyInspect=function(u) INSPECTED=u end
GetInspectSpecialization=function(u) return ({party2=103})[u] or 0 end
GetSpecializationInfoByID=function(id) if id==103 then return 103,"Wilder Kampf","",0,"DAMAGER" end end
GetGuildInfo=function() return nil end
IsInGroup=function() return true end
'''))
GW=ns.Geier
L=lua.eval('L')
fire=lua.eval('function(msg) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"CHAT_MSG_LOOT",msg) end end end')
print("=== Item-Rollen ===")
for i in [1,2,3,4,20,21,22,23,11]:
    res=GW.Evaluate(L(i),"DRUID",60); ex=res[2]
    print("%-22s -> %s"%(lua.globals().ITEMS[i][1], GW.RoleList(ex.roles) if ex else "-"))
print("=== Gruppen-Inspektion ===")
ns.Inspect.TryGroup(ns.Inspect); print("inspiziert:", lua.globals().INSPECTED)
ns.Inspect.OnReady(ns.Inspect, "G-"+lua.globals().INSPECTED)
lua.execute('NOW=1010'); ns.Inspect.TryGroup(ns.Inspect); print("nächster:", lua.globals().INSPECTED)
ns.Inspect.OnReady(ns.Inspect, "G-"+lua.globals().INSPECTED)
print("=== Würfe ===")
fire("Bob wählt 'Bedarf' für: "+L(20))   # Krieger Tank -> Schild Tank = Main
fire("Bob wählt 'Bedarf' für: "+L(2))    # Plattenhose STR -> Tank/PHYS
fire("Dru wählt 'Bedarf' für: "+L(23))   # Druide Wilder Kampf (PHYS main) -> Tank-Leder: Off
fire("Dru wählt 'Bedarf' für: "+L(21))   # Heilrobe -> Off (Heal)
fire("Pia wählt 'Bedarf' für: "+L(22))   # Priester Heiler -> Schadensrobe = Off (Caster)
fire("Pia wählt 'Bedarf' für: "+L(21))   # Heilrobe = Main
for h in GW.db().history.values():
    print("  %-14s %-22s %-6s fit=%-8s %s"%(h.player, lua.globals().ITEMS[int(h.link.split('item:')[1].split(':')[0])][1], h.verdict, GW.RoleFit(h.itemRoles,h.player,h['class']), h.reason))
print("=== Spieler-Rollen ===")
for full in ["Bob-Treoninka","Dru-Treoninka","Pia-Treoninka"]:
    r=GW.PlayerRoles(full)
    print("  %-14s Main=%s (%s) Off=%s (%s) möglich=%s"%(full, r[0], r[1], list(r[2].values()), r[3], list(r[4].values())))
print("=== MS>OS-Regel ===")
ns.db.settings.lootMSOS=True
fire("Pia wählt 'Bedarf' für: "+L(22).replace("item:22","item:22")+" ")  # gleiche Meldung leicht anders
lua.execute('NOW=2000')
h=GW.db().history[1]; print("  ", h.player, h.verdict, h.reason)
print("=== UI ===")
run=lua.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
print("öffnen:", run('SlashCmdList["CBAS"]("geier")'))
print("Dru wählen:", run('CBAS.Geier.UI.selected="Dru-Treoninka"; CBAS.Geier.UI:Refresh()'))
print("Detail:", ns.Geier.UI.det.GetText(ns.Geier.UI.det).split("\n")[1:4])
print("Spielerzeilen:", [ns.Geier.UI.prows[i].a.GetText(ns.Geier.UI.prows[i].a) for i in range(1,4)])
print("Tooltip-Zeile:", run('CBAS.Geier.UI.rows[1]._scripts.OnEnter(CBAS.Geier.UI.rows[1])'))
print("Melden:", run('CBAS.Geier.UI.reportBtn._scripts.OnClick()'), lua.globals().SENT[1])
print("Knopf danach:", ns.Geier.UI.reportBtn.GetText(ns.Geier.UI.reportBtn), "aktiv:", ns.Geier.UI.reportBtn._enabled if False else "")
lua.execute('SENT=nil'); print("nochmal melden (gesperrt):", run('CBAS.Geier.UI:Report()'), "gesendet:", lua.globals().SENT)
lua.execute('NOW=2006'); run('CBAS.Geier.UI.frame._scripts.OnUpdate(CBAS.Geier.UI.frame,0.2)')
print("nach 6s:", ns.Geier.UI.reportBtn.GetText(ns.Geier.UI.reportBtn))
lua.execute('NOW=2011'); run('CBAS.Geier.UI.frame._scripts.OnUpdate(CBAS.Geier.UI.frame,0.2)')
print("nach 11s:", ns.Geier.UI.reportBtn.GetText(ns.Geier.UI.reportBtn))
print("Einstellungen:", run('SlashCmdList["CBAS"]("settings")'))
