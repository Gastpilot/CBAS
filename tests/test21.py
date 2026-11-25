src=open('/tmp/test20.py').read().split("la,A=client()")[0]
exec(src)
la,A=client()
F=A.Flip; L=la.eval('L')
run=la.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
la.execute('''
ITEMS[7076]={"Erdessenz",500} ITEMS[13463]={"Traumblatt",25} ITEMS[8838]={"Sonnengras",20} ITEMS[4338]={"Magiestoff",100}
local db=AUCTIONATOR_PRICE_DATABASE["Treoninka Horde"]
local function hist(base,spread) local h={} for d=1,14 do h[100+d]=base+((d%3)-1)*spread end return h end
db["7076"]={m=6000,h=hist(15000,600)}           -- Erdessenz: jetzt 60s, Schnitt 1,5g -> Top
db["13463"]={m=9000,h=hist(10000,200)}          -- Traumblatt: nur 10 % drunter -> kein Vorschlag
db["8838"]={m=3000,h={[105]=9000,[110]=3000,[112]=15000}}  -- Sonnengras: stark schwankend, nur 3 Tage
db["4338"]={m=50,h=hist(1500,50)}               -- Magiestoff: viel zu billig -> "?" + Haendler-Flip
''')
A.Flip.db().settings.minVendorProfit=5
print("=== Analyse ===")
print(run('SlashCmdList["CBAS"]("flip find")'))
for _ in range(6):
    T=list(la.globals().TIMERS.values()); la.globals().TIMERS=la.table()
    for f in T: f()
for k,v in F.db().suggest.items(): print("  Vorschlag", k, v.ah, v.avg, v.profit, round(v.pct), v.days, round(v.cv,2), round(v.score), v.odd)
print("  Händler-Flips:", sorted(F.db().found.keys()))
U=F.UI
print("Ansicht:", U.view, "| Status:", U.src.GetText(U.src))
for r in range(1,4):
    row=U.rows[r]
    if row.id: print("  ", [row.cells[j].GetText(row.cells[j]) for j in range(1,10)])
print("Detail:", run('CBAS.Flip.UI.selected=7076; CBAS.Flip.UI:Build(true)'), U.det.GetText(U.det)[:160])
print("=== AH-Kaufhilfe ===")
la.execute('''
AuctionHouseFrame={IsShown=function() return true end}
RES={{unitPrice=5800,quantity=10},{unitPrice=6000,quantity=20},{unitPrice=9000,quantity=40},{unitPrice=14000,quantity=5}}
C_AuctionHouse={GetNumCommoditySearchResults=function(id) return #RES end, GetCommoditySearchResultInfo=function(id,i) return RES[i] end}
local fire=function(e,a) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,e,a) end end end
fire("COMMODITY_SEARCH_RESULTS_UPDATED",7076)
''')
print(la.eval('CBASFlipOverlay.text:GetText()'))
F.db().settings.maxSpend=200000
la.execute('for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"COMMODITY_SEARCH_RESULTS_UPDATED",7076) end end')
print("mit Budget 20g:", la.eval('CBASFlipOverlay.text:GetText()').split("\n")[1:3])
F.db().settings.maxSpend=0
la.execute('RES={{unitPrice=40,quantity=200},{unitPrice=95,quantity=50},{unitPrice=99,quantity=50},{unitPrice=120,quantity=10}} for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"COMMODITY_SEARCH_RESULTS_UPDATED",4338) end end')
print("Magiestoff:", la.eval('CBASFlipOverlay.text:GetText()').replace("\n"," | "))
print("für Händler markiert:", F.IsVendorMarked(4338))
print("=== Händler ===")
F.MarkVendor(4338, True, True)
la.execute('''
BAGS={[0]={{itemID=4338,stackCount=20},{itemID=14047,stackCount=20},{itemID=4338,stackCount=5}}}
C_Container={GetContainerNumSlots=function(b) return BAGS[b] and #BAGS[b] or 0 end,
  GetContainerItemInfo=function(b,s) return BAGS[b] and BAGS[b][s] end,
  UseContainerItem=function(b,s) SOLD=(SOLD or 0)+BAGS[b][s].stackCount; BAGS[b][s]=nil end}
MerchantFrame={IsShown=function() return true end}
for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"MERCHANT_SHOW") end end
''')
for _ in range(8):
    T=list(la.globals().TIMERS.values()); la.globals().TIMERS=la.table()
    for f in T: f()
print("verkauft:", la.globals().SOLD, "Stück (nur Magiestoff, Runenstoff bleibt)")
print("Knopf Händler-Verkauf:", run('CBAS.Flip.UI.view="found"; CBAS.Flip.UI.selected=14047; CBAS.Flip.UI:Build(); CBAS.Flip.UI.vendBtn._scripts.OnClick()'), F.IsVendorMarked(14047))
print("budget-Befehl:", run('SlashCmdList["CBAS"]("flip budget 300")'), F.db().settings.maxSpend)
print("Einstellungen:", run('SlashCmdList["CBAS"]("settings")'))
