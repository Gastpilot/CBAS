import sys
from lupa import LuaRuntime
stub=open('/tmp/stub.lua').read()
def client(with_addons=True):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('PNAME="Anna"'); lua.execute(stub); lua.execute(open('/tmp/uimock.lua').read())
    lua.execute('''UnitFullName=function() return "Anna","Treoninka" end
    GetRealmName=function() return "Treoninka" end
    -- id -> name, sellPrice
    ITEMS={[2589]={"Leinenstoff",13},[14047]={"Runenstoff",400},[12359]={"Thoriumbarren",250},[19019]={"Donnerzorn",0}}
    local function id(x) if type(x)=="number" then return x end return tonumber(tostring(x):match("item:(%d+)")) end
    function L(i) return "|cffffffff|Hitem:"..i.."::::::::60:::::|h["..ITEMS[i][1].."]|h|r" end
    C_Item={GetItemInfo=function(x) local d=ITEMS[id(x)] if not d then return nil end return d[1],L(id(x)),2,50,50,"","",20,"",134400,d[2] end,
            RequestLoadItemDataByID=function() end}
    GetCursorInfo=function() return CURSOR_KIND, CURSOR_ID, CURSOR_LINK end ClearCursor=function() CURSOR_KIND=nil end
    ''')
    if with_addons:
        lua.execute('''
        ATR={[2589]=8,[14047]=380,[12359]=900,[19019]=1500000}
        Auctionator={API={v1={
          GetAuctionPriceByItemLink=function(c,l) return ATR[tonumber(l:match("item:(%d+)"))] end,
          GetAuctionAgeByItemLink=function(c,l) return 1 end,
          MultiSearchExact=function(c,names) SEARCHED=names end }}}
        TSMP={dbmarket={[12359]=1400,[19019]=2200000},dbregionsalerate={[12359]=0.31,[19019]=0.02},dbminbuyout={}}
        TSM_API={ToItemString=function(l) return "i:"..l:match("item:(%d+)") end,
          GetCustomPriceValue=function(src,s) local t=TSMP[src] return t and t[tonumber(s:match("i:(%d+)"))] end}
        AUCTIONATOR_PRICE_DATABASE={__dbversion=6,["Treoninka Horde"]={["2589"]={m=8,h={[101]=9}},["14047"]={m=380,h={[100]=520,[101]=480,[102]=500}},["12359"]={m=900},["99999"]={m=1}}}
        ''')
    ns=lua.table()
    for f in [l.strip() for l in open('CBAS/CBAS.toc') if l.strip().endswith('.lua')]:
        lua.eval('function(ns,s,n) local c,e=load(s,n) if not c then error(e) end return c("CBAS",ns) end')(ns,open('CBAS/'+f.replace(chr(92),'/'),encoding='utf-8').read(),f)
    lua.eval('function(ns) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"ADDON_LOADED","CBAS") end end for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"PLAYER_LOGIN") end end end')(ns)
    return lua, ns
la,A=client()
F=A.Flip; L=la.eval('L')
run=la.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
print("=== Rechnung ===")
for i in [12359,19019,2589,14047]:
    p=F.Prices(L(i)); af=F.AHFlip(p); vf=F.VendorFlip(p)
    print("%-13s ahMin=%s markt=%s händler=%s | AH: kauf bis %s, %s%%, deal=%s | Händler: %s deal=%s"%(
        p.info.name, p.ahMin, p.market, p.vendor, af and af.buyUpTo, af and af.pct and round(af.pct), af and af.deal, vf and vf.profit, vf and vf.deal))
print("=== Merkliste & UI ===")
for i in [12359,19019,2589]: F.Add(L(i))
la.execute('CURSOR_KIND="item" CURSOR_ID=14047 CURSOR_LINK=L(14047)')
print("öffnen:", run('SlashCmdList["CBAS"]("flip")'), A.Suite.current, [m.name for m in A.Suite.modules.values()])
print("Drag&Drop:", run('local d; for _,c in ipairs(FRAMES) do if c._scripts and c._scripts.OnReceiveDrag then d=c end end d._scripts.OnReceiveDrag(d)'), len(list(F.db().watch.keys())), "auf Liste")
U=F.UI
print("Quellen:", U.src.GetText(U.src))
for r in range(1,5):
    row=U.rows[r]
    if row.id: print("  ", [row.cells[j].GetText(row.cells[j]) for j in range(1,10)])
print("wählen + eigener Kaufpreis:", run('CBAS.Flip.UI.view="watch"; CBAS.Flip.UI.selected=12359; CBAS.Flip.UI:Build(); local e=CBAS.Flip.UI.buyEdit; e:SetText("10s"); e._scripts.OnTextChanged(e,true)'), F.db().watch[12359].buyAt)
print("Detail:", U.det.GetText(U.det).replace("\n"," | ")[:300])
la.execute('AuctionHouseFrame={IsShown=function() return true end}')
print("AH suchen:", run('CBAS.Flip.UI:SearchSelected()'), list(la.globals().SEARCHED.values()))
print("Alle Schnäppchen:", run('CBAS.Flip.UI:SearchDeals()'), list(la.globals().SEARCHED.values()))
print("=== Händler-Flips finden ===")
A.Flip.db().settings.minVendorProfit=5
print(run('SlashCmdList["CBAS"]("flip find")'))
for _ in range(5):
    T=list(la.globals().TIMERS.values()); la.globals().TIMERS=la.table()
    for f in T: f()
print("gefunden:", {k:(v.ah,v.vendor,v.profit) for k,v in F.db().found.items()}, "| Ansicht:", U.view)
for r in range(1,3):
    row=U.rows[r]
    if row.id: print("  ", [row.cells[j].GetText(row.cells[j]) for j in range(1,7)])
print("auf Merkliste:", run('CBAS.Flip.UI.selected=14047; CBAS.Flip.UI.toWatchBtn._scripts.OnClick()'))
print("=== Tooltip ===")
la.execute('TT={lines={}} function TT:GetItem() return "Thorium", L(12359) end function TT:AddLine(t) table.insert(self.lines,t) end')
print(run('local fns={} for _,fr in ipairs(FRAMES) do end'), "")
la.execute('TooltipDataProcessor={AddTooltipPostCall=function(t,f) POST=POST or {} table.insert(POST,f) end} Enum=Enum or {} Enum.TooltipDataType={Unit=0,Item=1}')
la.eval('function(ns) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"PLAYER_LOGIN") end end end')(A)
la.execute('for _,f in ipairs(POST) do pcall(f, TT, {}) end')
print([l for l in la.globals().TT.lines.values() if "Flip" in l])
print("=== ohne Auctionator/TSM ===")
lb,B=client(False)
rb=lb.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
B.Flip.Add(lb.eval('L')(12359))
print("öffnen:", rb('SlashCmdList["CBAS"]("flip")'), "| Quellen:", B.Flip.UI.src.GetText(B.Flip.UI.src))
print("suchen:", rb('SlashCmdList["CBAS"]("flip find")'))
