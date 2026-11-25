exec(open('/tmp/test9.py').read().split('print("Zurück zu GScout:"')[0].replace('print(','(lambda *a: None)('))
la=lua
la.execute('''SENT={} C_ChatInfo=C_ChatInfo or {} C_ChatInfo.SendAddonMessage=function(p,m,c) table.insert(SENT,p.." "..m.." "..c) return 0 end
C_ChatInfo.RegisterAddonMessagePrefix=function() return true end
IsInInstance=function() return false end IsInGuild=function() return true end
function FIRE(e,...) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,e,...) end end end''')
print("Einstellungen:", run('CBAS.Suite:Select("settings")'))
st=lambda: la.eval('CBAS.Version.box.status:GetText()')
print(st()); print("Link:", la.eval('CBAS.Version.box.link:GetText()'))
print("Link schreibgeschützt:", run('local e=CBAS.Version.box.link; e:SetText("x"); e:GetScript("OnTextChanged")(e,true)'), la.eval('CBAS.Version.box.link:GetText()')==la.eval('CBAS.Version.URL'))
print("Ältere Meldung:", run('FIRE("CHAT_MSG_ADDON","CBASv","V:2.16.0","GUILD","Bob-Qt")'), la.eval('CBAS.Version.Latest()'))
for f in list(la.globals().TIMERS.values()): f()
print("Antwort gesendet:", list(la.globals().SENT.values()))
print("Neuere Meldung:", run('FIRE("CHAT_MSG_ADDON","CBASv","V:2.18.1","PARTY","Carl-Qt")'), la.eval('CBAS.Version.Latest()'))
print(st())
print("Badge:", la.eval('CBAS.Suite.gearBadge and CBAS.Suite.gearBadge:IsShown()'))
print("Unsinn ignoriert:", run('FIRE("CHAT_MSG_ADDON","CBASv","V:abc","PARTY","Eve")'), la.eval('CBAS.Version.Latest()'))
print("/crap version:", run('SlashCmdList["CBAS"]("version")'))
print("Vergleich:", la.eval('CBAS.Version.Newer("2.10.0","2.9.9")'), la.eval('CBAS.Version.Newer("2.17.0","2.17.0")'))
