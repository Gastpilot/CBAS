# 2.27.0: Mage-Dienste (Portale, Wasser & Essen), Lage-Zeilen Mage + Addons, GScout "Weiter scannen"
exec(open('/tmp/test34.py').read().split('print("Einstellungen:"')[0])
run=la.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
ev=la.eval
la.execute('''
UnitClass=function(u) return "Magier","MAGE" end
UnitExists=function(u) return u=="player" end
KNOWN={[11416]=true,[11417]=true,[10140]=true,[10145]=true}
IsPlayerSpell=function(id) return KNOWN[id] or false end
ITEMS={[8079]=40,[8076]=0,[17032]=3}
GetItemCount=function(id) return ITEMS[id] or 0 end
InCombatLockdown=function() return false end
OPENED=nil ChatFrame_OpenChat=function(t) OPENED=t end
ChatFrame_SendTell=nil
INVITED=nil C_PartyInfo={InviteUnit=function(n) INVITED=n end, LeaveParty=function() LEFT=true end}
GetChannelList=function() return 1,"Allgemein",false,2,"Handel - Stadt",false end
TRADEMONEY=0 GetTargetTradeMoney=function() return TRADEMONEY end
ACCEPTED=false AcceptTrade=function() ACCEPTED=true end
TRADED=nil InitiateTrade=function(u) TRADED=u end
TRADEITEMS={} GetTradePlayerItemInfo=function(i) return TRADEITEMS[i] end
BAG={[0]={[1]=8079,[2]=8079,[3]=8076}}
C_Container={GetContainerNumSlots=function(b) return BAG[b] and 3 or 0 end,
  GetContainerItemID=function(b,s) return BAG[b] and BAG[b][s] end,
  PickupContainerItem=function(b,s) CURSOR=BAG[b][s] end}
ClickTradeButton=function(i) TRADEITEMS[i]="item"..tostring(CURSOR) end
ERR_TRADE_COMPLETE="Handel abgeschlossen."
''')
# Login-Ereignis erneut fuer das Mage-Modul (jetzt als Magier)
la.execute('for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"PLAYER_LOGIN") end end')
MG='CBAS.Mage'
print("Magier:", ev(MG+'.IsMage()'), "| Taste:", ev(MG+'.button ~= nil'))
for txt, w in [("WTB port to IF pls", False), ("suche Portal nach Orgrimmar", False), ("any mage for water?", False),
               ("WTS port to IF 1g", False), ("port sw?", True), ("lol port", False), ("brauche essen und wasser bitte", False)]:
    r = la.eval('function(t,w) local r='+MG+'.Parse(t,w) return r and (r.kind..":"..tostring(r.dest)..(r.food and "+essen" or "")) or "-" end')(txt, w)
    print("  Parse:", repr(txt), "->", r)
st=ev(MG+'.Stock()')
print("Vorrat:", st.water, st.food, st.runes, [p.key for p in st.portals.values()])
# Ohne Kunden: Essen fehlt -> zaubern; Wasser 40 < 6 Stacks -> zuerst Wasser
print("Schritt leer:", ev(MG+'.Next().text'), "| cast:", ev(MG+'.Next().cast'))
la.execute('ITEMS[8079]=200 ITEMS[8076]=60 '+MG+'.Dirty()')
print("Schritt Vorrat voll:", ev(MG+'.Next().text'))
print("Werbung:", run(MG+'.Step()'), ev('OPENED'))
print("danach:", ev(MG+'.Next().text'))
# Kunde im Handelschat
la.execute('FIRE("CHAT_MSG_CHANNEL","WTB port to Ironforge pls","Kunde-Eins","","2. Handel - Stadt","","",0,2,"Handel - Stadt")')
print("Kunden:", ev('#'+MG+'.customers'), ev(MG+'.customers[1].full'), ev(MG+'.customers[1].dest'), ev(MG+'.customers[1].src'))
print("1:", ev(MG+'.Next().text'), run(MG+'.Step()'), ev('OPENED'))
print("2:", ev(MG+'.Next().text'), run(MG+'.Step()'), ev('INVITED'))
print("3:", ev(MG+'.Next().text'))
la.execute('IsInGroup=function() return true end UnitExists=function(u) return u=="party1" or u=="player" end '
           'local on=UnitName UnitName=function(u) if u=="party1" or u=="NPC" then return "Kunde","Eins" end return on(u) end')
print("4 (in Gruppe, erst zahlen):", ev(MG+'.Next().text'), run(MG+'.Step()'), ev('TRADED'))
la.execute('TradeFrame=CreateFrame("Frame") TradeFrame:Show() FIRE("TRADE_SHOW")')
print("5 Handel ohne Gold:", ev(MG+'.Next().text'))
la.execute('TRADEMONEY=10000 FIRE("TRADE_MONEY_CHANGED")')
print("6:", ev(MG+'.Next().text'), run(MG+'.Step()'), ev('ACCEPTED'))
la.execute('TradeFrame:Hide() FIRE("TRADE_CLOSED") FIRE("UI_INFO_MESSAGE",0,"Handel abgeschlossen.")')
print("7:", ev(MG+'.Next().text'), "| cast:", ev(MG+'.Next().cast'))
# sichere Taste: PreClick setzt den Zauber
b='CBASMageButton'
print("Taste PreClick:", run(b+'._scripts.PreClick('+b+')'), "| Ziel:", ev(MG+'.pending and '+MG+'.pending.cast'))
la.execute(b+'._scripts.PostClick('+b+') FIRE("UNIT_SPELLCAST_SUCCEEDED","player","x",11416)')
print("8:", ev(MG+'.Next().text'), run(MG+'.Step()'), ev('LEFT'), "| Kunden:", ev('#'+MG+'.customers'))
print("Heute:", [x for x in la.eval('function() return {'+MG+'.Today()} end')().values()])
# Wasser-Kunde per Fluestern, Handel befuellen
la.execute('FIRE("CHAT_MSG_WHISPER","hast du wasser?","Kunde-Eins")')
c=MG+'.customers[1]'
la.execute(c+'.state="group" TRADEITEMS={} TRADEMONEY=0 TradeFrame:Show() FIRE("TRADE_SHOW")')
print("Wasser 1:", ev(MG+'.Next().text'), run(MG+'.Step()'), [x for x in la.globals().TRADEITEMS.values()])
print("Wasser 2:", ev(MG+'.Next().text'))
la.execute('TRADEMONEY=10000')
print("Wasser 3:", ev(MG+'.Next().text'))
# Oberflaeche
print("Tab:", run('CBAS.Suite:Toggle("mage")'), ev('CBAS.Suite.titleText:GetText()'), "|", ev(MG+'.UI.step:GetText()'))
print("Zeilen:", run(MG+'.UI:Refresh()'), ev('CBAS.Mage.UI.rows[1].name:GetText()'), "|", ev('CBAS.Mage.UI.rows[1].what:GetText()'))
print("Art umschalten:", run('CBAS.Mage.UI.kindBtn._scripts.OnClick()'), ev(c+'.kind'))
print("Preis ändern:", run('local e=CBAS.Mage.UI.edits[1] e:SetText("2,5") e._scripts.OnEnterPressed(e)'), ev(MG+'.db().portalPrice'))
print("Seitenleiste:", sorted(la.eval('CBAS.Suite.tabs').keys()))
# Lage
print("Lage:", run('CBAS.Suite:Select("home") CBAS.Home:Refresh()'))
for i in range(1,8):
    r=ev('CBAS.Home.rows[%d].r'%i)
    if r: print("  ", r.prio, r.state, r.cat, "|", r.title)
# Einstellungen
print("Einstellungen Mage:", run('CBAS.Suite:Select("settings") CBAS.Settings.SelectCat("mage")'), ev('CBAS.Settings.panel.cat'))
# GScout: Weiter scannen
la.execute('NOWT=(NOWT or 0) GetTime=function() return NOWT end C_FriendList={SendWho=function(q) LASTQ=q end,GetNumWhoResults=function() return 0 end,GetWhoInfo=function() end}')
for i in range(6):
    la.execute('NOWT=NOWT+10')
    print("  Scan:", ev('CBAS.SmartScanLabel()'), "->", run('CBAS.SmartScanStep()'), ev('LASTQ'))
print("Sperre:", run('CBAS.SmartScanStep()'), ev('CBAS.UI.nextBtn:GetText()'))
print("Menü:", run('CBAS.UI:ToggleScanMenu()'), ev('CBAS.UI.scanMenu:IsShown()'), ev('CBAS.UI.zoneBtn:GetText()'))
# 2.29.0: "Liste scannen" - angezeigte Liste von oben nach unten
la.execute('for _,n in ipairs({"Alpha","Bravo","Charlie","Delta"}) do CBAS.GetGuild(n, nil, true, "test") end')
la.execute('CBAS.UI:HideScanMenu() CBAS.Suite:Select("gscout") CBAS.UI.instFilter=nil CBAS.UI.sortKey="name" CBAS.UI.sortDesc=false if CBAS.UI.cbBlacklist then CBAS.UI.cbBlacklist:SetChecked(false) end CBAS.UI:Refresh() CBAS.db.settings.listScan=nil for _,g in pairs(CBAS.db.guilds) do g.whoScanT=nil end')
n=ev('#CBAS.UI.list')
print("Liste:", n, ev('CBAS.UI.listBtn:GetText()'))
names=[ev('CBAS.UI.list[%d].g.name'%i) for i in range(1,min(n,4)+1)]
got=[]
for i in range(min(n,4)):
    la.execute('NOWT=NOWT+10')
    run('CBAS.UI:ListScanStep()')
    got.append((ev('LASTQ'), ev('CBAS.UI.selected and CBAS.db.guilds[CBAS.UI.selected] and CBAS.db.guilds[CBAS.UI.selected].name'), ev('CBAS.UI:ListScanLabel()')))
print("Reihenfolge Liste:", names)
print("Gescannt:", got)
la.execute('NOWT=NOWT+1')
print("Sperre:", run('CBAS.UI:ListScanStep()'), ev('CBAS.UI.listBtn:GetText()'))
# alles frisch gescannt -> Meldung statt /who
la.execute('for _,g in pairs(CBAS.db.guilds) do g.whoScanT=time() end NOWT=NOWT+10 LASTQ=nil')
print("alles frisch:", run('CBAS.UI:ListScanStep()'), ev('LASTQ'))
print("Slash:", run('CBAS.db.settings.listScan=nil for _,g in pairs(CBAS.db.guilds) do g.whoScanT=nil end NOWT=NOWT+10 SlashCmdList.CBAS("liste")'), ev('LASTQ'))
