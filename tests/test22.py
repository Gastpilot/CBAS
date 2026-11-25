exec(open('/tmp/test21.py').read().split('print("=== AH-Kaufhilfe ===")')[0].replace('print(','(lambda *a: None)('))
la.execute('''
AuctionHouseFrame={IsShown=function() return true end}
LOG={}
RES={}
C_AuctionHouse={
  MakeItemKey=function(id) return {itemID=id} end,
  SendSearchQuery=function(key) table.insert(LOG,"search "..key.itemID) LASTKEY=key end,
  GetNumCommoditySearchResults=function(id) return #RES end, GetCommoditySearchResultInfo=function(id,i) return RES[i] end,
  StartCommoditiesPurchase=function(id,q) table.insert(LOG,"start "..id.."x"..q) end,
  ConfirmCommoditiesPurchase=function(id,q) table.insert(LOG,"confirm "..id.."x"..q) end,
  CancelCommoditiesPurchase=function() table.insert(LOG,"cancel") end,
  GetNumItemSearchResults=function() return #IRES end, GetItemSearchResultInfo=function(k,i) return IRES[i] end,
  PlaceBid=function(a,b) table.insert(LOG,"bid "..a.." "..b) end,
}
Enum=Enum or {} Enum.AuctionHouseSortOrder={Price=0}
function FIRE(e,...) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,e,...) end end end
''')
step=lambda: run('CBAS.Flip.Step()')
log=lambda: list(la.globals().LOG.values())
ov=lambda: la.eval('CBASFlipOverlay and CBASFlipOverlay.text:GetText() or ""').split("\n")[-1]
btn=lambda: la.eval('CBASFlipOverlay.btn:GetText()')
la.execute('FIRE("AUCTION_HOUSE_SHOW")')
for f in list(la.globals().TIMERS.values()): f()
la.globals().TIMERS=la.table()
print("Start:", ov())
print("1. Druck:", step(), log()[-1], "|", btn())
la.execute('RES={{unitPrice=5800,quantity=10},{unitPrice=6000,quantity=20},{unitPrice=14000,quantity=5}} FIRE("COMMODITY_SEARCH_RESULTS_UPDATED",7076)')
print("   Ergebnis:", ov(), "|", btn())
print("2. Druck:", step(), log()[-1], "|", btn())
la.execute('FIRE("COMMODITY_PRICE_UPDATED", 5933, 178000)')
print("   Preis da:", ov(), "|", btn())
print("3. Druck:", step(), log()[-1])
la.execute('FIRE("COMMODITY_PURCHASE_SUCCEEDED")')
print("   Buchhaltung:", [(e.kind,e.id,e.qty,e.total) for e in A.Flip.db().ledger.values()])
print("4. Druck:", step(), log()[-1])
la.execute('RES={{unitPrice=3000,quantity=4}} FIRE("COMMODITY_SEARCH_RESULTS_UPDATED",8838)')
print("5. Druck:", step(), log()[-1])
la.execute('FIRE("COMMODITY_PRICE_UPDATED", 4000, 16000)')   # Preis gestiegen
print("   ->", log()[-1])
print("6. Druck:", step(), log()[-1])
# Einzelgegenstaende
la.execute('IRES={{auctionID=11,buyoutAmount=300,quantity=1},{auctionID=12,buyoutAmount=320,quantity=1},{auctionID=13,buyoutAmount=900,quantity=1}} FIRE("ITEM_SEARCH_RESULTS_UPDATED",{itemID=LASTKEY.itemID})')
for i in range(4): print("Druck Item:", step(), log()[-1])
print("ohne AH:", run('AuctionHouseFrame={IsShown=function() return false end} CBAS.Flip.Step()'))
print("=== Post ===")
la.execute('''
MailFrame={IsShown=function() return true end} InboxFrame={IsVisible=function() return true end}
MAILS={
 {sender="Auktionshaus",money=53000,cod=0,item=false,inv={"seller","Erdessenz",nil,60000,60000,0,3000}},
 {sender="Auktionshaus",money=0,cod=0,item=true},
 {sender="Bob",money=10000,cod=0,item=false},
 {sender="Betrüger",money=0,cod=50000,item=true},
}
GetInboxNumItems=function() return #MAILS end
GetInboxHeaderInfo=function(i) local m=MAILS[i] return nil,nil,m.sender,"x",m.money,m.cod,nil,m.item end
GetInboxInvoiceInfo=function(i) local m=MAILS[i] if m.inv then return unpack(m.inv) end end
unpack=unpack or table.unpack
TakeInboxMoney=function(i) table.insert(LOG,"money "..i) MAILS[i].money=0 end
AutoLootMailItem=function(i) table.insert(LOG,"item "..i) table.remove(MAILS,i) end
C_Container=C_Container or {} C_Container.GetContainerNumFreeSlots=function() return 10 end
FIRE("MAIL_SHOW")
''')
la.execute('LOG={}')
print("Knopf:", run('CBAS.Flip.Mail.button._scripts.OnClick()'))
for _ in range(10):
    T=list(la.globals().TIMERS.values()); la.globals().TIMERS=la.table()
    for f in T: f()
print("Aktionen:", log(), "| verbleibend:", [m.sender for m in la.globals().MAILS.values()])
print("Rechnung:", [(e.kind,e.name,e.total) for e in A.Flip.db().ledger.values()][:1])
