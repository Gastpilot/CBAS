exec(open('/tmp/test14b.py').read().split('GW=ns.Geier')[0])
run=lua.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
lua.execute('''NOW=1000 GetTime=function() return NOW end
GetMaxPlayerLevel=function() return 60 end
WHO={
 {fullName="Solo-Treoninka",fullGuildName="",level=60,filename="MAGE",raceStr="Orc",area="Orgrimmar"},
 {fullName="Wanderer",fullGuildName="",level=42,filename="HUNTER",raceStr="Tauren",area="Desolace"},
 {fullName="Treu",fullGuildName="Nachtwache",level=60,filename="WARRIOR",raceStr="Orc",area="Orgrimmar"},
}
C_FriendList={SendWho=function(q) LASTQ=q end, GetNumWhoResults=function() return #WHO end, GetWhoInfo=function(i) return WHO[i] end}
GetPlayerInfoByGUID=function(g) if g=="G9" then return "Priester","PRIEST","Untoter","Scourge" end end''')
print("who:", run('CBAS.OnWhoUpdate()'))
print("Gildenlose:", sorted(ns.db.unguilded.keys()))
chat=lua.eval('function(msg,sender,guid) CBAS.OnChat("CHAT_MSG_CHANNEL", msg, sender, nil,nil,nil,nil,nil,nil,"Suche nach Gruppe",nil,nil,guid) end')
chat("Heilpriester 60 sucht Gilde für MC/BWL, bin jeden Abend online","Heiler-Treoninka","G9")
chat("LF guild, raid exp, holy priest","Heiler2-Treoninka",None)
chat("<Nachtwache> sucht noch Spieler für MC","Thrall-Treoninka",None)   # Werbung: kein Sucher
u=ns.db.unguilded["Heiler-Treoninka"]; print("Sucher:", u['class'], u.race, u.faction, "|", u.seeking.text[:40], "| Kanal:", u.seeking.ch)
print("Werber nicht in Liste:", "Thrall-Treoninka" not in ns.db.unguilded)
# Gildenmitglied verlaesst Gilde (who meldet keine Gilde)
lua.execute('WHO={{fullName="Treu",fullGuildName="",level=60,filename="WARRIOR",raceStr="Orc",area="Orgrimmar"}}')
run('CBAS.OnWhoUpdate()')
print("Treu verlassen:", ns.db.unguilded["Treu-Treoninka"].leftGuild, "| noch Mitglied:", "Treu-Treoninka" in ns.db.guilds["Nachtwache"].members)
# Gildenloser tritt Gilde bei
lua.execute('WHO={{fullName="Wanderer",fullGuildName="Eisenfaust",level=43,filename="HUNTER",raceStr="Tauren",area="Desolace"}}')
run('CBAS.OnWhoUpdate()')
print("Wanderer jetzt in Gilde -> aus Liste:", "Wanderer-Treoninka" not in ns.db.unguilded)
# Sucher tritt Gilde bei -> bleibt mit Hinweis
lua.execute('WHO={{fullName="Heiler",fullGuildName="Eisenfaust",level=60,filename="PRIEST",raceStr="Scourge",area="Orgrimmar"}}')
run('CBAS.OnWhoUpdate()')
print("Sucher jetzt in Gilde:", ns.db.unguilded["Heiler-Treoninka"].inGuild)
# Einheit ohne Gilde mit Nachpruefung
lua.execute('''UnitExists=function() return true end UnitIsPlayer=function() return true end
UnitName=function(u) if u=="player" then return "Anna" end return "Fremd",nil end
UnitGUID=function() return "GX" end GetGuildInfo=function() return nil end
UnitClass=function() return "Schurke","ROGUE" end UnitRace=function() return "Troll","Troll" end
UnitLevel=function() return 58 end UnitFactionGroup=function() return "Horde" end UNKNOWNOBJECT="?"''')
ns.ScanUnit("mouseover")
print("vor Nachprüfung:", "Fremd-Treoninka" in ns.db.unguilded)
for f in list(lua.globals().TIMERS.values()): f()
lua.globals().TIMERS=lua.table()
print("nach Nachprüfung:", "Fremd-Treoninka" in ns.db.unguilded, ns.db.unguilded["Fremd-Treoninka"].src)
print("=== UI ===")
print("öffnen:", run('SlashCmdList["CBAS"]("gildenlos")'), ns.Suite.current, [m.name for m in ns.Suite.modules.values()])
G=ns.Gildenlos
print("Zähler:", G.count.GetText(G.count))
for i in range(1,4):
    r=G.rows[i]
    if r.full: print("  ", [r.cells[j].GetText(r.cells[j]) for j in range(1,9)])
print("nur Sucher:", run('CBAS.Gildenlos.cbSeek:SetChecked(true); CBAS.Gildenlos.cbSeek._scripts.OnClick()'), len(G.list))
print("auswählen:", run('CBAS.Gildenlos.selected="Heiler-Treoninka"; CBAS.Gildenlos:Refresh()'))
print("Detail:", G.det.GetText(G.det).replace("\n"," | ")[:260])
print("/who-Knopf:", run('CBAS.Gildenlos.whoBtn._scripts.OnClick()'), lua.globals().LASTQ, G.whoBtn.GetText(G.whoBtn))
print("Notiz:", run('local n=CBAS.Gildenlos.note; n:SetText("netter Heiler"); n._scripts.OnTextChanged(n,true)'), ns.db.unguilded["Heiler-Treoninka"].note)
print("Einstellungen:", run('SlashCmdList["CBAS"]("settings")'))
print("aufräumen:", run('CBAS.Purge(0)'))
