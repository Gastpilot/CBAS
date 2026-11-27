# 2.28.0: Tracker unter Lage (heute / diese Woche)
exec(open('/tmp/test34.py').read().split('print("Einstellungen:"')[0])
run=la.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
ev=la.eval
la.execute('''
GetQuestResetTime=function() return 5*3600 end
C_DateAndTime=C_DateAndTime or {} C_DateAndTime.GetSecondsUntilWeeklyReset=function() return 3*86400 end
SAVED={ {"Geschmolzener Kern",1,4*86400,9,true,false,0,true,40,"40",10,10},
        {"Pechschwingenhort",2,4*86400,9,true,false,0,true,40,"40",8,3},
        {"Zul'Gurub",3,86400,9,false,false,0,true,20,"20",10,10} }
GetNumSavedInstances=function() return #SAVED end
GetSavedInstanceInfo=function(i) return table.unpack(SAVED[i]) end
RequestRaidInfo=function() end
''')
la.execute('for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"PLAYER_LOGIN") end end')
TR='CBAS.Tracker'
def items():
    d,w,c=la.eval('function() return '+TR+'.Items() end')()
    f=lambda l: [(e.text, bool(e.done), e.detail) for e in l.values()]
    return f(d), f(w)
print("Start:", run(TR+'.db()'))
d,w=items(); print(" heute:", d); print(" woche:", w)
print("eigene:", run(TR+'.AddTask("Kochen skillen","day") '+TR+'.AddTask("Ony-Kopf abgeben","week") '+TR+'.AddTask("   ","day")'))
print("leer abgelehnt:", [x for x in la.eval('function() return {'+TR+'.AddTask("  ","day")} end')().values()])
la.execute(TR+'.ToggleTask(1) local _,c='+TR+'.db() c.ah=time()')
print("Scans:", run('for i=1,3 do CBAS.SendWho("x"..i) NOWT=(NOWT or 0)+10 end'))
d,w=items(); print(" heute:", d); print(" woche:", w)
print("Raid verfolgen:", run(TR+'.ToggleRaid("NAXX")'), items()[1][-2:])
print("Lage-Zeile:", ev(TR+'.HomeRow().title'), "|", ev(TR+'.HomeRow().detail'), ev(TR+'.HomeRow().prio'))
# Tages-Reset: Haken fuer taegliche Aufgaben und Zaehler weg, woechentliche bleiben
la.execute(TR+'.ToggleTask(2) local _,c='+TR+'.db() c.dayEnd=time()-1')
d,w=items(); print("nach Tages-Reset heute:", d); print("  woche:", [x for x in w if x[0]=="Ony-Kopf abgeben"])
la.execute('local _,c='+TR+'.db() c.weekEnd=time()-1')
print("nach Wochen-Reset:", [x for x in items()[1] if x[0]=="Ony-Kopf abgeben"])
# kurz vor Reset: warn
la.execute('local _,c='+TR+'.db() c.dayEnd=time()+1800')
print("kurz vor Reset:", ev(TR+'.HomeRow().state'), ev(TR+'.HomeRow().prio'), "|", ev(TR+'.HomeRow().detail'))
# Ansicht
print("Ansicht:", run('CBAS.Suite:Toggle("tracker")'), ev('CBAS.Suite.titleText:GetText()'))
print("Spalten:", ev(TR+'.UI.day.big:GetText()'), ev(TR+'.UI.week.big:GetText()'), "|", ev(TR+'.UI.day.reset:GetText()'))
print("Zeile 1:", ev(TR+'.UI.day.rows[1].name:GetText()'), "|", ev(TR+'.UI.day.rows[1].det:GetText()'))
print("Klick abhaken:", run('local r for _,x in ipairs('+TR+'.UI.day.rows) do if x.e and x.e.task then r=x end end r._scripts.OnClick()'), items()[0][-1])
print("Hinzufügen per Feld:", run('local u='+TR+'.UI u.perBtn._scripts.OnClick() u.edit:SetText("Ruf farmen") u.addBtn._scripts.OnClick()'), [x[0] for x in items()[1]])
print("Löschen:", run('local r for _,x in ipairs('+TR+'.UI.week.rows) do if x.e and x.e.task and x.e.text=="Ruf farmen" then r=x end end r.x._scripts.OnClick()'), [x[0] for x in items()[1]])
print("Scan-Ziel +:", run('for _,f in ipairs(FRAMES) do end'), ev(TR+'.db().scanGoal'))
print("Seitenleiste Lage:", [ev('CBAS.Suite.subBtns.home[%d].label:GetText()'%i) for i in (1,2)])
print("Lage:", run('CBAS.Suite:Select("home")'), [ev('CBAS.Home.rows[%d].r and CBAS.Home.rows[%d].r.cat'%(i,i)) for i in range(1,8)])
print("Grenze 20:", run('for i=1,30 do '+TR+'.AddTask("t"..i,"day") end'), ev('#'+TR+'.db().tasks'))
# 2.28.1: Quests (Beutebucht-Weekly, angenommene Daily/Weekly, Quest-ID im Feld), neue Forever-Raids
la.execute('''
LEVEL=60 UnitLevel=function() return LEVEL end
DONEQ={} LOGQ={} INFO={}
C_QuestLog={IsQuestFlaggedCompleted=function(id) return DONEQ[id] or false end,
  GetLogIndexForQuestID=function(id) return LOGQ[id] end,
  GetInfo=function(i) return INFO[i] end,
  GetTitleForQuestID=function(id) return ({[96076]="In Demand - Ancient Elven Curiosities",[555]="Fische für Booty Bay"})[id] end}
table.insert(SAVED,{"Hyjal Summit",9,5*86400,9,true,false,0,true,20,"20",6,2})
''')
la.execute('local t='+TR+'.db() t.tasks={} '+TR+'.DirtyRaids()')
w=[x for x in items()[1]]
print("Woche (60, Stand-Woche):", [x for x in w if "Pix" in x[0] or x[0] in ("Versunkener Tempel","Blackmaw Hold","Terrasse des Formers")][:4])
print("Hyjal:", [x for x in w if "Hyjal" in x[0]])
print("Zählung ohne Unterzeilen:", [x for x in la.eval('function() local d,w=CBAS.Tracker.Items() return {CBAS.Tracker.Count(w)} end')().values()])
la.execute('PIXSEEN=CBAS.Tracker.PIX_SEEN CBAS.Tracker.PIX_SEEN={}')
print("ohne Wissen:", [x for x in items()[1] if "Pix" in x[0]])
# Gespraech mit Pix: angebotene Quest (neue Woche: Plague Records)
la.execute('local on=UnitName UnitName=function(u) if u=="npc" then return "Pix Xizzix" end return on(u) end GetQuestID=function() return 96087 end FIRE("QUEST_DETAIL")')
print("gelernt:", [x for x in items()[1] if "Pix" in x[0] or "Scholo" in x[0] or "Strat" in x[0]])
# Quest angenommen, Ziele: 1 von 3
la.execute('LOGQ[96087]=8 C_QuestLog.GetQuestObjectives=function(id) return {{text="Headmaster\'s Records: 1/1",finished=true},{text="Grain Shipment Records: 0/1",finished=false},{text="Dathrohan\'s Correspondence: 0/1",finished=false}} end FIRE("QUEST_ACCEPTED",96087)')
print("im Log:", [x for x in items()[1] if "Pix" in x[0] or "Scholo" in x[0] or "Strat" in x[0]])
print("kein Doppel-Eintrag:", ev(TR+'.FindQuestTask(96087) == nil'))
la.execute('DONEQ[96087]=true LOGQ[96087]=nil')
print("abgegeben:", [x for x in items()[1] if "Pix" in x[0]][:1], "| Unterzeilen erledigt:", all(x[1] for x in items()[1] if x[0].startswith("Strat") or x[0]=="Scholomance"))
la.execute('LEVEL=40')
print("Stufe 40:", [x for x in items()[1] if "Pix" in x[0]])
la.execute('LEVEL=60 DONEQ[96087]=nil')
# unbekannte neue Version von Pix
la.execute('GetQuestID=function() return 96099 end GetTitleText=function() return "In Demand - Gnomish Gadgets" end FIRE("QUEST_DETAIL")')
print("neue Version:", [x for x in items()[1] if "Pix" in x[0]])
la.execute('LOGQ[96099]=9 C_QuestLog.GetQuestObjectives=function(id) return {{text="Zahnrad: 0/1",finished=false},{text="Feder: 1/1",finished=true}} end FIRE("QUEST_ACCEPTED",96099)')
print("neue Version mit Zielen:", [x for x in items()[1] if "Pix" in x[0] or "Zahnrad" in x[0] or "Feder" in x[0]])
la.execute('LOGQ[96099]=nil UnitName=function(u) if u=="npc" then return nil end return "Ich" end')
# Daily angenommen -> automatisch im Tracker
la.execute('LOGQ[555]=3 INFO[3]={frequency=1} FIRE("QUEST_ACCEPTED",555)')
print("Daily angenommen:", [x for x in items()[0] if "Fische" in x[0]])
la.execute('FIRE("QUEST_ACCEPTED",3,555)')
print("doppelt?:", len([x for x in items()[0] if "Fische" in x[0]]))
la.execute('LOGQ[777]=4 INFO[4]={frequency=0} FIRE("QUEST_ACCEPTED",777)')
print("normale Quest ignoriert:", ev('#'+TR+'.db().tasks'))
la.execute('DONEQ[555]=true')
print("Daily abgegeben:", [x for x in items()[0] if "Fische" in x[0]])
print("Klick auf Quest-Aufgabe ändert nichts:", run('local t='+TR+'.FindQuestTask(555) local _,c='+TR+'.db() '+TR+'.UI:Refresh() for _,x in ipairs('+TR+'.UI.day.rows) do if x.e and x.e.task==t then x._scripts.OnClick() end end assert(not c.done[t.id])'))
# Quest-ID / Wowhead-Link im Eingabefeld
print("Link:", [x for x in la.eval('function() return {'+TR+'.AddTask("https://www.wowhead.com/forever/quest=12345/irgendwas","week")} end')().values()][:1], ev(TR+'.FindQuestTask(12345).text'))
print("Pix-Quest abgelehnt:", [x for x in la.eval('function() return {'+TR+'.AddTask("96076","week")} end')().values()])
print("Ansicht:", run(TR+'.UI:Refresh()'), ev(TR+'.UI.week.big:GetText()'))
