exec(open('/tmp/test14b.py').read().split('GW=ns.Geier')[0])
run=lua.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
chat=lua.eval('function(msg,sender) CBAS.OnChat("CHAT_MSG_CHANNEL", msg, sender) end')
print("=== Werbung + Fortschritt ===")
chat("<Nachtwache> sucht Verstärkung! BWL 6/8, MC farm, Loot über DKP. Semi-HC, Mi/Do 20 Uhr","Thrall-Treoninka")
chat("<Nachtwache> sucht Verstärkung! BWL 6/8, MC farm, Loot über DKP. Semi-HC, Mi/Do 20 Uhr","Thrall-Treoninka")  # Spam-Wiederholung
chat("<Bummelgilde> sucht nette Leute zum Leveln, Bedarf vor Gier","Opa-Treoninka")
g=ns.db.guilds["Nachtwache"]; b=ns.db.guilds["Bummelgilde"]
print("Fortschritt:", {k:(v.txt) for k,v in g.progress.items()})
# Mitglieder + Inspektion + Raid-Sichtung simulieren
lua.execute('''
local g=CBAS.db.guilds["Nachtwache"]
for i=1,25 do CBAS.AddMember(g,"Nachtwache","NW"..i.."-Treoninka",{level=60,class="WARRIOR",race="Orc"}) end
for i=1,8 do g.members["NW"..i.."-Treoninka"].ilvl=72+i; g.members["NW"..i.."-Treoninka"].inspT=os.time() end
g.members["NW1-Treoninka"].pvp="Blutgardist"
g.inspect={members=120,t=os.time()}
CBAS.NoteInstanceSighting(g,"BWL",14,os.time()) CBAS.NoteInstanceSighting(g,"MC",22,os.time()-3*86400)
local b=CBAS.db.guilds["Bummelgilde"]
for i=1,6 do CBAS.AddMember(b,"Bummelgilde","BG"..i.."-Treoninka",{level=20+i*5,class="MAGE",race="Orc"}) end
''')
for name in ["Nachtwache","Bummelgilde"]:
    gg=ns.db.guilds[name]
    res=ns.PerformanceScore(gg)
    print("%-12s Leistung=%s (%s) unsicher=%s"%(name,res[0],res[1],res[3]))
    for p in res[2].values(): print("     %-22s %5.1f/%-2d %s"%(p.name,p.v,p.max,p.txt))
print("=== Lootsystem-Hinweise ===")
chat("wer bietet mit? 50 dkp auf die Klinge","NW3-Treoninka")       # Chat eines Mitglieds
chat("wieder 30 dkp verloren lol","NW4-Treoninka")
chat("Loot Council hat entschieden","NW5-Treoninka")
# Run mit Plündermeister, Mehrheit Nachtwache
lua.execute('''
local d=CBAS.Geier.db()
d.runs={{id=99,start=os.time()-3600,last=os.time(),zone="Pechschwingenhort",instance=true,rolls=3,members={},lootMethod="Plündermeister"}}
for i=1,10 do d.runs[1].members["NW"..i.."-Treoninka"]="WARRIOR" end
d.runs[1].members["Gast-Treoninka"]="MAGE"
CBAS.Geier.EndRun("Test")
''')
print("Run-Gilde:", lua.eval('CBAS.Geier.db().runs[1].guild'), lua.eval('CBAS.Geier.db().runs[1].guildWhy'))
for l in ns.LootLines(g).values(): print("  Nachtwache:", l)
for l in ns.LootLines(b).values(): print("  Bummelgilde:", l)
print("Kurz:", ns.LootShort(g), "|", ns.LootShort(b))
print("=== Sync ===")
src=open('/tmp/test8.py').read()
la2=LuaRuntime(unpack_returned_tuples=True); la2.execute('PNAME="Bernd"'); la2.execute(open('/tmp/stub.lua').read())
la2.execute('UnitFullName=function() return "Bernd","Treoninka" end')
ns2=la2.table()
for f in [l.strip() for l in open('CBAS/CBAS.toc') if l.strip().endswith('.lua') and 'UI' not in l and 'Suite' not in l and 'Flipper' not in l]:
    la2.eval('function(ns,s) return load(s)("CBAS",ns) end')(ns2,open('CBAS/'+f,encoding='utf-8').read())
la2.eval('function(ns) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"ADDON_LOADED","CBAS") end end for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"PLAYER_LOGIN") end end end')(ns2)
lua.execute('OUTBOX={}'); ns.Sync.lastBroadcast=None; ns.Sync.active=False
lua.execute('IsInGroup=function() return true end')
ns.Sync.StartBroadcast(ns.Sync)
for i in range(400):
    T=list(lua.globals().TIMERS.values()); lua.globals().TIMERS=lua.table()
    if not T: break
    for f in T: f()
for m in lua.globals().OUTBOX.values(): ns2.Sync.OnAddonMessage(ns2.Sync,"GScout1",m,"PARTY","Anna-Treoninka")
g2=ns2.db.guilds["Nachtwache"]
print("Bernd sieht:", [l for l in ns2.LootLines(g2).values()], "| Fortschritt:", {k:v.txt for k,v in g2.progress.items()}, "| Leistung:", ns2.PerformanceScore(g2)[0])
print("=== UI ===")
print("öffnen:", run('SlashCmdList["CBAS"]("gscout")'))
print("High Performer:", run('CBAS.UI.cbTop:SetChecked(true); CBAS.UI.cbTop._scripts.OnClick(CBAS.UI.cbTop)'), [e.g.name for e in ns.UI.list.values()], ns.UI.sortKey)
print("Profil:", run('CBAS.UI.selected="Nachtwache"; CBAS.UI.tab="profile"; CBAS.UI:UpdateDetail()'))
txt=ns.UI.DetailText(ns.UI, g)
print("\n".join(txt.split("\n")[:14]))
print("Export:", run('SlashCmdList["CBAS"]("export")'), lua.eval('CBAS.UI.exportFrame.eb:GetText()').split("\n")[1][:110])
