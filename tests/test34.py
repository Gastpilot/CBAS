exec(open('/tmp/test31.py').read().split('print("Eigenes Land:"')[0])
CF='CBAS.ChatFlags'
la.execute('NOWT=NOWT+20 FIRE("CHAT_MSG_SAY","hey guys we are looking for a tank for the dungeon","Tom-Qt") NOWT=NOWT+20 FIRE("CHAT_MSG_SAY","we are ready and the healer is here with us","Tom-Qt")')
print("Englisch:", la.eval(CF+'.CountryOf("Tom-Qt")'), la.eval(CF+'.Icon("EN")'))
la.execute('CBAS.db.settings.flagEN=false'); print("EN aus:", la.eval(CF+'.CountryOf("Tom-Qt")')); la.execute('CBAS.db.settings.flagEN=nil')
# Gruppensuche
la.execute('''
RESULTS={1,2}
INFO={[1]={leaderName="Pierre-Dubois",numMembers=2,name="BWL",comment=""},[2]={leaderName="Klaus-Meier",numMembers=1,name="Suche Heiler für Strath",comment="wir suchen noch einen Heiler und sind schnell durch, bitte melden"}}
MEMB={[1]={{name="Pierre-Dubois"},{name="Jean-Luc"}},[2]={{name="Klaus-Meier"}}}
C_LFGList={Search=function() end,GetSearchResults=function() return #RESULTS,RESULTS end,
 GetSearchResultInfo=function(id) return INFO[id] end,GetSearchResultPlayerInfo=function(id,i) return MEMB[id][i] end,
 GetDefaultLanguageSearchFilter=function() return {deDE=true} end}
hooksecurefunc=function(t,k,f) if type(t)=="table" then local o=t[k] t[k]=function(...) local r={o(...)} f(...) return table.unpack(r) end else local o=_G[t] _G[t]=function(...) local r={o(...)} k(...) return table.unpack(r) end end end
''')
la.execute('for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"PLAYER_LOGIN") end end')
la.execute('RESULTS={1} C_LFGList.Search(2,0,0,{frFR=true})')
la.execute('FIRE("LFG_LIST_SEARCH_RESULTS_RECEIVED")')
for f in list(la.globals().TIMERS.values()): f()
print("Suche nur Französisch:", la.eval(CF+'.CountryOf("Pierre Dubois")'), la.eval(CF+'.CountryOf("Jean Luc")'))
la.execute('RESULTS={1,2} C_LFGList.Search(2,0,0,{deDE=true,enUS=true})')
la.execute('FIRE("LFG_LIST_SEARCH_RESULTS_RECEIVED")')
for f in list(la.globals().TIMERS.values()): f()
la.execute('C_LFGList.Search(2,0,0,{deDE=true,enUS=true}) FIRE("LFG_LIST_SEARCH_RESULTS_RECEIVED")')
for f in list(la.globals().TIMERS.values()): f()
print("gemischte Suche, deutscher Anzeigentext:", la.eval(CF+'.CountryOf("Klaus Meier")'), la.eval('CBAS.db.country["Klaus Meier"] and CBAS.db.country["Klaus Meier"].v and CBAS.db.country["Klaus Meier"].v.DE'))
print("Einstellungen:", run('CBAS.Suite:Select("settings")'), la.eval('CBAS.ChatFlags.box.en:GetChecked()'))
