# 2.25.0: neues Fenster (Seitenleiste, Kopfzeile), Einstellungen mit Bereichen, Startseite "Lage"
exec(open('/tmp/test34.py').read().split('print("Einstellungen:"')[0])
run=la.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
print("öffnen:", run('CBAS.Suite:Toggle("home")'), la.eval('CBAS.Suite.current'))
print("Titel:", la.eval('CBAS.Suite.titleText:GetText()'), "|", la.eval('CBAS.Suite.descText:GetText()'))
print("Seitenleiste:", sorted(la.eval('CBAS.Suite.tabs').keys()))
print("Lage-Zeilen:", run('CBAS.Home:Refresh()'))
for i in range(1,7):
    r=la.eval('CBAS.Home.rows[%d].r'%i)
    if r: print("  ", r.prio, r.state, r.cat, "|", r.title, "|", (r.detail or "")[:70])
print("Jetzt:", la.eval('CBAS.Home.what:GetText()'), "|", la.eval('CBAS.Home.where:GetText()'), "|", la.eval('CBAS.Home.sum:GetText()'))
# Gruppe mit Blacklist-Spieler
la.execute('''IsInGroup=function() return true end IsInRaid=function() return false end
UnitExists=function(u) return u=="party1" or u=="player" end
local oldName=UnitName
UnitName=function(u) if u=="party1" then return "Thrall","Treoninka" end return oldName(u) end
UnitClass=UnitClass or function() return "Krieger","WARRIOR" end''')
la.execute('local k=CBAS.db.players["Thrall Treoninka"] if k then CBAS.db.guilds[k].blacklist=true end')
print("Gruppe:", run('CBAS.Home:Refresh()'), la.eval('CBAS.Home.rows[1].r.title'), "|", la.eval('CBAS.Home.rows[1].r.detail'))
print("Zeile anklicken:", run('CBAS.Home.rows[1]:GetScript("OnClick")(CBAS.Home.rows[1])'), la.eval('CBAS.Suite.current'), la.eval('CBAS.Suite.titleText:GetText()'))
print("Unteransicht:", run('CBAS.Suite:Select("cihi")'), la.eval('CBAS.Suite.titleText:GetText()'))
print("Einstellungen:", run('CBAS.Suite:Select("settings")'), la.eval('CBAS.Settings.panel.cat'))
for c in ["general","gscout","geier","flipper","chat","layer","data"]:
    print("  Bereich", c, run('CBAS.Settings.SelectCat("%s")'%c), la.eval('CBAS.Settings.panel.cat'))
print("Schalter:", la.eval('#CBAS.Settings.panel.checks'))
print("Minimap-Schalter:", run('''local p=CBAS.Settings.panel local cb for _,c in ipairs(p.checks) do if c.get and c.label:GetText():find("Minimap") then cb=c end end
cb:SetChecked(false) cb._scripts.OnClick(cb) assert(CBAS.db.settings.minimapHide==true,"minimap") cb:SetChecked(true) cb._scripts.OnClick(cb) assert(not CBAS.db.settings.minimapHide)'''))
print("CIHI-Popup-Schalter:", run('''local p=CBAS.Settings.panel local cb for _,c in ipairs(p.checks) do if c.get and c.label:GetText():find("Popup") then cb=c end end
cb:SetChecked(false) cb._scripts.OnClick(cb) assert(CBAS.db.settings.cihi.popup==false) cb:SetChecked(true) cb._scripts.OnClick(cb) assert(CBAS.db.settings.cihi.popup==true)'''))
print("Partner mit Leerzeichen:", run('local e=CBAS.Settings.panel.partnerEdit e:SetText("Fdtd Wächter, Bob Stein") e._scripts.OnEnterPressed(e)'), [x for x in la.eval('CBAS.Layer.Partners()').values()])
print("Statistik:", la.eval('CBAS.Settings.panel.stats:GetText()'))
print("Update-Zeile:", run('CBAS.db.settings.newestVersion="9.9.9" CBAS.db.settings.newestT=time() CBAS.Suite:Select("home")'), [la.eval('CBAS.Home.rows[%d].r and CBAS.Home.rows[%d].r.title'%(i,i)) for i in range(1,7)])
print("Skin läuft:", run('CBAS.T.Skin(CBASFrame)'), run('local b=CBAS.T.Button(UIParent,"x",50,20,"primary") b:LockHighlight() b:UnlockHighlight() b:Disable()'))
print("Zahnrad:", run('CBAS.Suite.gear:GetScript("OnClick")()'), la.eval('CBAS.Suite.current'))
