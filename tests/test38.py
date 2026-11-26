# 2.26.0: Warn-Symbole in der Ergebnisliste der Gruppensuche
exec(open('/tmp/test35.py').read().split('la.execute(\'FIRE("ADDON_LOADED"')[0])
la.execute('''
INFO[4]={leaderName="Anna-Sauber",numMembers=1,name="ZG",comment=""}
MEMB[4]={{name="Anna-Sauber",classFilename="MAGE"}}
INFO[5]={leaderName="Hans-Frag",numMembers=1,name="Strat",comment=""}
MEMB[5]={{name="Hans-Frag",classFilename="WARRIOR"}}
-- Blizzard-Zeilen: Update-Funktion vorhanden, bevor die Gruppensuche geladen ist
function LFGBrowseSearchEntry_Update(row) end
-- EnumerateFrames ueber alle Mock-Frames
EnumerateFrames=function(cur) local i=0 if cur then for k,f in ipairs(FRAMES) do if f==cur then i=k end end end return FRAMES[i+1] end
-- fragwuerdiger Bedarf fuer Hans Frag
table.insert(CBAS.Geier.db().history, {player="Hans Frag", verdict="frag", kind="need"})
''')
la.execute('FIRE("ADDON_LOADED","Blizzard_LFGBrowse")')
print("Haken gesetzt:", run('assert(CBAS.LFGInfo and CBAS.LFGInfo.Evaluate)'))
print("Urteile:", [tuple(la.eval('function(id) return {CBAS.LFGInfo.Evaluate(id)} end')(i).values()) for i in (3,4,5)])
# Blizzard-Liste: Update-Haken markiert sofort
la.execute('ROWB=CreateFrame("Button",nil,UIParent) ROWB.resultID=3 LFGBrowseSearchEntry_Update(ROWB)')
print("Blizzard-Zeile:", la.eval('rawget(ROWB,"cbasBadge") and rawget(ROWB,"cbasBadge"):IsShown()'), la.eval('rawget(ROWB,"cbasBadge") and "ok"'))
# fremde Liste (LFGForever): Zeilen nur mit resultID, gefunden nach der Suche
la.execute('''LIST=CreateFrame("Frame",nil,UIParent)
R1=CreateFrame("Button",nil,LIST) R1.resultID=4
R2=CreateFrame("Button",nil,LIST) R2.resultID=5
R3=CreateFrame("Button",nil,LIST) R3.resultID=3
TIMERS={}''')
la.execute('FIRE("LFG_LIST_SEARCH_RESULTS_RECEIVED")')
for f in list(la.globals().TIMERS.values()): f()
for r in ("R1","R2","R3"):
    print('  ', r, la.eval(r+'.resultID'), 'Symbol:', la.eval('rawget('+r+',"cbasBadge") and rawget('+r+',"cbasBadge"):IsShown() or false'))
print("Anzahl rot R3:", la.eval('rawget(R3,"cbasBadge").count._text'))
# Scrollen: Zeile zeigt andere Gruppe -> Waechter zeichnet neu
la.execute('R1.resultID=3 R3.resultID=4')
print("Waechter:", run('for _,f in ipairs(FRAMES) do local u=f._scripts and f._scripts.OnUpdate if u and f~=CBAS.Home.panel then u(f, 1) end end'))
print("nach Scrollen: R1", la.eval('rawget(R1,"cbasBadge") and rawget(R1,"cbasBadge"):IsShown() or false'), "R3", la.eval('rawget(R3,"cbasBadge"):IsShown()'))
# Schalter aus -> Symbole weg
print("aus:", run('CBAS.db.settings.lfgBadges=false CBAS.LFGInfo.RefreshRows()'), la.eval('rawget(R1,"cbasBadge"):IsShown()'), la.eval('rawget(R2,"cbasBadge"):IsShown()'))
la.execute('CBAS.db.settings.lfgBadges=nil')
print("wieder an:", run('CBAS.LFGInfo.OnResults()'), la.eval('rawget(R1,"cbasBadge"):IsShown()'))
# Einzel-Update verwirft nur eine Gruppe
print("Einzel-Update:", run('FIRE("LFG_LIST_SEARCH_RESULT_UPDATED", 5)'))
# Einstellungen
print("Einstellungen:", run('CBAS.Suite:Select("settings") CBAS.Settings.SelectCat("chat")'), la.eval('CBAS.ChatFlags.box.lb:GetChecked()'))
print("Schalter klicken:", run('local b=CBAS.ChatFlags.box.lb b:SetChecked(false) b._scripts.OnClick(b) assert(CBAS.db.settings.lfgBadges==false)'))
# Cache waechst nicht unbegrenzt
print("Cache-Grenze:", run('for i=100,520 do INFO[i]={leaderName="X-Y",numMembers=0} CBAS.LFGInfo.Evaluate(i) end'))
