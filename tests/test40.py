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
