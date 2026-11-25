src=open('/tmp/test22.py').read().split('la.execute(\'FIRE("AUCTION_HOUSE_SHOW")\')')[0]
exec(src)
la.execute('''
CBAS_CLAUDE=nil
local oldInfo=C_Item.GetItemInfo
local function iid(x) return type(x)=="number" and x or tonumber(tostring(x):match("item:(%d+)") or tostring(x)) end
C_Item.GetItemInfo=function(x) local i=iid(x) local d=i and ITEMS[i] if not d then return nil end
  return d[1],"|cffffffff|Hitem:"..i.."::::::::60:::::|h["..d[1].."]|h|r",d[3] or 2,50,50,"","",d[5] or 20,"",134400,d[2],d[4] or 7,0,0 end
ITEMS[9001]={"Ärmelloses Hemd",5,0,4,1}       -- grau
ITEMS[9002]={"Ausbalancierte Kriegsaxt",50,1,2,1} -- weiß, Waffe
BAGS={} C_Item.GetItemCount=function(i) return BAGS[i] or 0 end
C_Container={GetContainerNumSlots=function(b) return b==0 and 4 or 0 end,
  GetContainerItemID=function(b,s) local k=0 for i,n in pairs(BAGS) do if n>0 then k=k+1 if k==s then return i end end end end,
  GetContainerItemInfo=function() return {isBound=false} end}
ItemLocation={CreateFromBagAndSlot=function(_,b,s) return {b=b,s=s} end}
C_AuctionHouse.PostCommodity=function(loc,dur,q,p) table.insert(LOG,"postc "..q.." "..p.." d"..dur) end
C_AuctionHouse.PostItem=function(loc,dur,q,bid,p) table.insert(LOG,"posti "..p) end
local db=AUCTIONATOR_PRICE_DATABASE["Treoninka Horde"]
db["9001"]={m=10,h={[CBAS.Flip.Today()-3]=500,[CBAS.Flip.Today()-2]=500,[CBAS.Flip.Today()-1]=500}}
CBAS.Flip.db().suggest[9001]={ah=10,avg=500,profit=400,pct=80,days=10,cv=0.1,score=1}
CBAS.Flip.db().suggest[9002]={ah=10,avg=500,profit=400,pct=80,days=10,cv=0.1,score=1}
''')
la.execute('FIRE("AUCTION_HOUSE_SHOW")')
for f in list(la.globals().TIMERS.values()): f()
U=la.eval('CBAS.Flip.UI')
print("Flipper öffnen:", run('CBAS.Suite:Toggle("flipper")'), U.view)
names=lambda: [x.name for x in U.list.values()]
print("Kaufen-Liste:", names())
print("Quatsch weg:", "Ärmelloses Hemd" not in names() and "Ausbalancierte Kriegsaxt" not in names())
print("Kopfzeile:", U.src.GetText(U.src))
print("Ausblenden:", run('CBAS.Flip.UI.selected=13463; CBAS.Flip.UI.B.ignore:GetScript("OnClick")()'), "Traumblatt" not in names())
run('CBAS.Flip.db().ignore={}')
print("Modus 2h:", run('CBAS.Flip.UI.modeBtns["2h"]:GetScript("OnClick")()'), names())
run('CBAS.Flip.UI.modeBtns["alle"]:GetScript("OnClick")()')
# Kauf -> Lager
la.execute('CBAS.Flip.Log("buy",7076,10,58000) BAGS[7076]=10')
print("Lager:", run('CBAS.Flip.UI:SetView("lager")'), [(x.name,x.bags,x.status) for x in U.list.values()])
print("Overlay-Knopf:", la.eval('CBAS.Flip.PilotText()'))
# Autopilot: zuerst einstellen
print("Pilot 1:", run('CBAS.Flip.Pilot()'), log()[-1])
la.execute('RES={{unitPrice=14100,quantity=5,numOwnerItems=0},{unitPrice=14500,quantity=50}} FIRE("COMMODITY_SEARCH_RESULTS_UPDATED",7076)')
print("Preis:", la.eval('CBAS.Flip.Stock.Hint()'))
print("Pilot 2:", run('CBAS.Flip.Pilot()'), log()[-1])
la.execute('FIRE("AUCTION_HOUSE_AUCTION_CREATED")')
print("Lager danach:", [(x.name,x.bags,x.e.posted) for x in U.list.values()], "| Pilot jetzt:", la.eval('CBAS.Flip.PilotText()'))
# Markt zu billig
la.execute('CBAS.Flip.Log("buy",13463,5,50000) BAGS[13463]=5')
run('CBAS.Flip.Pilot()')
la.execute('RES={{unitPrice=9000,quantity=5}} FIRE("COMMODITY_SEARCH_RESULTS_UPDATED",13463)')
print("zu billig:", [x.status for x in U.list.values() if x.id==13463])
# Verkauf aus Post
la.execute('BAGS[7076]=0 CBAS.Flip.Log("sell",nil,10,133000,"Erdessenz")')
run('CBAS.Flip.UI:Build(true)')
print("verkauft:", [(x.name,x.status) for x in U.list.values()])
# Overlay verschieben + speichern
o=la.eval('CBASFlipOverlay')
print("Overlay verschiebbar:", run('CBASFlipOverlay:GetScript("OnDragStop")(CBASFlipOverlay)'), la.eval('CBAS.db.settings.flipOverlayPos ~= nil'))
print("andere Ansichten:", run('CBAS.Flip.UI:SetView("watch"); CBAS.Flip.UI:SetView("found"); CBAS.Flip.UI:SetView("kaufen")'))
