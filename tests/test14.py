src=open('/tmp/test12.py').read().split('GW=ns.Geier')[0].replace(
 'GetRealZoneText=function() return "Geschmolzener Kern" end',
 '''INST=false ZONE="Orgrimmar"
GetRealZoneText=function() return ZONE end
IsInInstance=function() return INST, INST and "raid" or "none" end
GetInstanceInfo=function() return ZONE, "raid", 9, "40 Spieler" end
UnitIsGroupLeader=function(u) return u=="party1" end
C_PartyInfo={GetLootMethod=function() return "group" end}''')
exec(src)
GW=ns.Geier; L=lua.eval('L')
fire=lua.eval('function(msg) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"CHAT_MSG_LOOT",msg) end end end')
ev=lua.eval('function(e) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,e) end end; for _,f in ipairs(TIMERS) do f() end; TIMERS={} end')
# Run 1: MC
lua.execute('INST=true ZONE="Geschmolzener Kern"'); ev("PLAYER_ENTERING_WORLD")
fire("Bob wählt 'Bedarf' für: "+L(1)); fire("Pia wählt 'Bedarf' für: "+L(21)); fire("Rex wählt 'Bedarf' für: "+L(11))
lua.execute('INST=false ZONE="Brennende Steppe"'); ev("PLAYER_ENTERING_WORLD")
# Run 2: draussen in der Welt, andere Gruppe
lua.execute('GROUP={party1={"Kai","HUNTER",60},party2={"Lea","MAGE",60}} ROLES={}')
fire("Kai wählt 'Bedarf' für: "+L(3)); fire("Lea wählt 'Bedarf' für: "+L(2))
print("=== Runs ===")
for r in GW.db().runs.values():
    print("  #%s %-20s inst=%s würfe=%s auffällig=%s spieler=%s methode=%s leiter=%s ende=%s"%(r.id, r.zone, r.instance, r.rolls, r.susp, r.size, r.lootMethod, r.leader, r.endReason))
print("Würfe je Run:", [(h.player.split('-')[0], h.run) for h in GW.db().history.values()])
run=lua.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
print("=== UI ===")
print("öffnen:", run('SlashCmdList["CBAS"]("geier")'), "|", ns.Geier.UI.runBtn.GetText(ns.Geier.UI.runBtn))
print("Menü:", run('CBAS.Geier.UI:ToggleRunMenu()'), [ns.Geier.UI.runMenu.lines[i].fs.GetText(ns.Geier.UI.runMenu.lines[i].fs) for i in range(1,4)])
print("MC wählen:", run('local m=CBAS.Geier.UI.runMenu; m.lines[3]._scripts.OnClick(m.lines[3])'))
U=ns.Geier.UI
print("  Knopf:", U.runBtn.GetText(U.runBtn)); print("  Zeilen:", len(U.list), "| Spieler:", [e.full.split('-')[0] for e in U.plist.values()])
print("  Zusammenfassung:", U.hint.GetText(U.hint))
print("Blättern <:", run('CBAS.Geier.UI:StepRun(-1)'), U.runBtn.GetText(U.runBtn), len(U.list), "Zeilen", [e.full.split('-')[0] for e in U.plist.values()])
print("Bob im Run-Detail:", run('CBAS.Geier.UI:StepRun(1); CBAS.Geier.UI.selected="Bob-Treoninka"; CBAS.Geier.UI:Refresh()'), [l for l in U.det.GetText(U.det).split("\n") if "Run" in l])
print("alle:", run('CBAS.Geier.UI:StepRun(-1); CBAS.Geier.UI:StepRun(-1)'), U.runBtn.GetText(U.runBtn), len(U.list))
