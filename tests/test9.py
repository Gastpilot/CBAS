from lupa import LuaRuntime
stub=open('/tmp/stub.lua').read()
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('PNAME="Anna"'); lua.execute(stub); lua.execute(open('/tmp/uimock.lua').read())
lua.execute('UnitFullName=function() return "Anna","Treoninka" end')
ns=lua.table()
toc=[l.strip() for l in open('CBAS/CBAS.toc') if l.strip().endswith('.lua')]
print("Ladereihenfolge:", toc)
for f in toc:
    src=open('CBAS/'+f,encoding='utf-8').read()
    lua.eval('function(ns,s,n) local c,e=load(s,n) if not c then error(e) end return c("CBAS",ns) end')(ns,src,f)
lua.eval('function(ns) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"ADDON_LOADED","CBAS") end end for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"PLAYER_LOGIN") end end end')(ns)
# Daten
ns.OnChat("CHAT_MSG_CHANNEL","<Nachtwache> DE/AT/CH Gilde sucht noch Spieler für MC, Loot DKP, Mi/Do 20 Uhr","Thrall-Treoninka")
ns.OnChat("CHAT_MSG_CHANNEL","Wir suchen noch aktive Mitglieder für unsere Raids","Bob-Treoninka")
g=ns.db.guilds["Nachtwache"]
ns.AddMember(g,"Nachtwache","Thrall-Treoninka",lua.table_from({"level":60,"class":"WARRIOR","rank":"GM","rankIndex":0,"race":"Orc","pvp":"Blutgardist"}))
run=lua.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
print("Fenster öffnen (/crap):", run('SlashCmdList["CBAS"]("")'))
print("Suite sichtbar:", lua.eval('CBASFrame:IsShown()'), "| aktiver Reiter:", ns.Suite.current)
print("Reiter:", [m.name for m in ns.Suite.modules.values()])
print("Liste:", run('CBAS.UI:Refresh()'), "Einträge:", len(ns.UI.list))
print("Gilde wählen:", run('CBAS.UI.selected="Nachtwache"; CBAS.UI:UpdateDetail()'))
for tab in ["profile","members","chat"]:
    print(" Tab",tab,":", run('CBAS.UI.tab="%s"; CBAS.UI:UpdateDetail()'%tab))
print("Platzhalter wählen:", run('CBAS.UI.selected="pending:Bob-Treoninka"; CBAS.UI:UpdateDetail()'))
print("Instanzfilter:", run('CBAS.UI:ToggleInstMenu(); CBAS.UI:SetInstFilter("MC")'), len(ns.UI.list), "Einträge")
print("Einstellungen:", run('SlashCmdList["CBAS"]("settings")'), "| Reiter:", ns.Suite.current)
print("Zurück zu GScout:", run('CBAS.Suite:Select("gscout")'))
print("Export:", run('SlashCmdList["CBAS"]("export")'))
print("Chat-Log:", run('SlashCmdList["CBAS"]("log")'))
print("Hilfe:", run('SlashCmdList["CBAS"]("help")').splitlines()[0][:20])
print("Schließen:", run('SlashCmdList["CBAS"]("")'), "sichtbar:", lua.eval('CBASFrame:IsShown()'))
print("Profiltext-Auszug:")
print(ns.UI.DetailText(ns.UI, g)[:600])
print("--- Einstellungen-Klick")
print(run('''SlashCmdList["CBAS"]("settings")
local p = CBAS.Suite.panels.settings
local cb
for _, c in ipairs(p.checks) do if c.key == "sync" then cb = c end end
assert(cb:GetChecked() == true, "sync sollte an sein")
cb:SetChecked(false); cb._scripts.OnClick(cb)
assert(CBAS.db.settings.sync == false, "sync nicht gespeichert")
print("sync jetzt:", CBAS.db.settings.sync, "| Statuszeile:", p.stats:GetText())'''))
