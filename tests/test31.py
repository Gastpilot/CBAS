exec(open('/tmp/test30.py').read().split('print("Einstellungen:"')[0])
la.execute('GetLocale=function() return "deDE" end NOWT=1000 GetTime=function() return NOWT end')
CF='CBAS.ChatFlags'
print("Eigenes Land:", la.eval(CF+'.My()'))
# Chatzeile wie Blizzard: [Gruppe] Name: text
line='|Hchannel:PARTY|h[Gruppe]|h |Hplayer:Bob-Qt:12:PARTY|h[Bob]|h: hallo'
print("ohne Wissen:", la.eval(CF+'.Decorate')(line)==line)
la.execute('FIRE("CHAT_MSG_PARTY","Wir gehen jetzt noch in die Instanz und machen das fertig","Bob-Qt")')
NOWT=['NOWT=(NOWT or 1000)+20']
la.execute('NOWT=(NOWT or 1000)+20')
la.execute('FIRE("CHAT_MSG_PARTY","Ich bin auch noch dabei und wir sind fast fertig mit der Quest","Bob-Qt")')
print("nach 2 deutschen Sätzen:", la.eval(CF+'.CountryOf("Bob-Qt")'))
print(la.eval(CF+'.Decorate')(line))
la.execute('NOWT=NOWT+20 FIRE("CHAT_MSG_SAY","hey guys, I am from Sweden actually","Sven-Qt")')
print("eigene Angabe:", la.eval(CF+'.CountryOf("Sven-Qt")'))
la.execute('FIRE("CHAT_MSG_ADDON","CBASv","C:AT","GUILD","Anna2-Qt")')
print("CBAS-Spieler:", la.eval(CF+'.CountryOf("Anna2-Qt")'))
la.execute('NOWT=NOWT+20 FIRE("CHAT_MSG_SAY","lol ok see you later in the dungeon guys","Tom-Qt")')
print("Englisch -> keine Flagge:", la.eval(CF+'.CountryOf("Tom-Qt")'))
print("ich selbst:", la.eval(CF+'.CountryOf(CBAS.NormFull("Anna"))'))
print("geheimer Text:", run('issecretvalue=function(x) return x=="GEHEIM" end; assert(CBAS.ChatFlags.Decorate("GEHEIM")=="GEHEIM")'))
print("Einstellungen:", run('CBAS.Suite:Select("settings")'), la.eval('CBAS.ChatFlags.box.cur:GetText()'))
print("Land ändern:", run('SlashCmdList["CBAS"]("land at")'), la.eval(CF+'.My()'), list(la.globals().SENT.values())[-1:])
print("aus:", run('SlashCmdList["CBAS"]("land aus")'), la.eval('CBAS.db.settings.chatFlags'))
