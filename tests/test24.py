src=open('/tmp/test22.py').read().split('la.execute(\'FIRE("AUCTION_HOUSE_SHOW")\')')[0]
exec(src)
la.execute('''
TICKS={} C_Timer.NewTicker=function(s,f) local t={f=f,Cancel=function(self) self.dead=true end} table.insert(TICKS,t) return t end
SOUNDS=0 PlaySound=function() SOUNDS=SOUNDS+1 end
NOW=100 GetTime=function() return NOW end
''')
la.execute('FIRE("AUCTION_HOUSE_SHOW")')
for f in list(la.globals().TIMERS.values()): f()
def tick(n=1):
    for _ in range(n):
        la.execute('NOW=NOW+0.3 for _,t in ipairs(TICKS) do if not t.dead then t.f() end end')
print("an:", run('CBAS.Flip.Snipe.Toggle(true)'))
tick(); print("1. Suche:", log()[-1], "|", la.eval('CBAS.Flip.Snipe.Status()'))
first=log()[-1].split()[1]
la.execute('RES={} FIRE("COMMODITY_SEARCH_RESULTS_UPDATED",%s)'%first)
tick(3); print("2. Suche:", log()[-1], "| geprüft", la.eval('CBAS.Flip.Snipe.checked'))
second=int(log()[-1].split()[1])
la.execute('RES={{unitPrice=10,quantity=10}} FIRE("COMMODITY_SEARCH_RESULTS_UPDATED",%d)'%second)
print("Treffer:", la.eval('CBAS.Flip.Snipe.Status()'), "Ton:", la.globals().SOUNDS)
n=len(log()); tick(5); print("wartet (keine neue Suche):", len(log())==n)
print("Taste:", step(), log()[-1])
la.execute('FIRE("COMMODITY_PRICE_UPDATED", 10, 100)')
print("Taste:", step(), log()[-1])
la.execute('FIRE("COMMODITY_PURCHASE_SUCCEEDED")')
tick(3); print("weiter:", log()[-1])
la.execute('FIRE("ADDON_ACTION_BLOCKED","CBAS","C_AuctionHouse.SendSearchQuery()")')
print("Handbetrieb:", la.eval('CBAS.Flip.Snipe.Status()'))
print("aus:", run('CBAS.Flip.Snipe.Toggle(false)'))
print("dbg:", la.eval('(function() local r=CBAS.Flip.EvaluateListings(2243,{{unit=10,qty=10}}); return r and r.qty end)()'), la.eval('CBAS.Flip.Targets(2243,2243).ahMax'), la.eval('CBAS.Flip.ItemInfo(2243)'))
