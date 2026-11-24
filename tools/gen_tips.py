import sys, json, math, statistics, datetime, time
from lupa import LuaRuntime
import cbor2
src = sys.argv[1] if len(sys.argv)>1 else 'Auctionator.lua'
out = sys.argv[2] if len(sys.argv)>2 else 'ClaudeTips.lua'
DAY0=datetime.date(2020,1,1)
la=LuaRuntime(encoding=None); la.execute(open(src,'rb').read()); G=la.globals()
db=None; realm=None
for k,v in G.AUCTIONATOR_PRICE_DATABASE.items():
    if k!=b'__dbversion':
        realm=k.decode(); db=cbor2.loads(v) if isinstance(v,bytes) else {kk:vv for kk,vv in v.items()}
dec=lambda x: x.decode() if isinstance(x,bytes) else x
today=max(int(dk) for v in db.values() if isinstance(v,dict) for dk in (v.get(b'h') or {}))
AHCUT=0.05; MARGIN=0.15; MINPROFIT=2000  # 20s pro Stueck
WD=['Mo','Di','Mi','Do','Fr','Sa','So']
def money(c):
    g,s=int(c//10000),int(c//100%100)
    return (f"{g}g " if g else "")+f"{s}s"
def slope_of(xs,ys):
    if len(xs)<3: return None
    mx=statistics.mean(xs); my=statistics.mean(ys); den=sum((x-mx)**2 for x in xs)
    if den<=0 or my<=0: return 0
    return max(-0.25,min(0.25,sum((x-mx)*(y-my) for x,y in zip(xs,ys))/den/my))
def sse(xs,ys):
    mx=statistics.mean(xs); my=statistics.mean(ys); den=sum((x-mx)**2 for x in xs)
    m=sum((x-mx)*(y-my) for x,y in zip(xs,ys))/den if den else 0
    return sum((y-(my+m*(x-mx)))**2 for x,y in zip(xs,ys))
def pct(s): return f"{s*100:+.1f}%"
tips=[]; stats={'items':0,'hist':0}
for key,e in db.items():
    if not isinstance(e,dict): continue
    key=dec(key)
    if not key.isdigit(): continue
    stats['items']+=1
    iid=int(key)
    h={int(d):p for d,p in (e.get(b'h') or {}).items() if p and p>0}
    a={int(d):n for d,n in (e.get(b'a') or {}).items()}
    m=e.get(b'm')
    past={d:p for d,p in h.items() if d<today and d>today-21}
    if len(past)<5 or not m: continue
    stats['hist']+=1
    xs=sorted(past); ys=[past[d] for d in xs]; n=len(xs)
    avg=statistics.mean(ys); med=statistics.median(ys); cv=statistics.pstdev(ys)/avg
    mx=statistics.mean(xs); den=sum((x-mx)**2 for x in xs) or 1
    slope=max(-0.2,min(0.2,sum((x-mx)*(y-avg) for x,y in zip(xs,ys))/den/avg))
    recent=[past[d] for d in xs if d>xs[-1]-7]
    base=statistics.median(recent if len(recent)>=2 else ys)
    last=xs[-1]
    tr={w:slope_of([x for x in xs if x>last-w],[past[x] for x in xs if x>last-w]) for w in (3,7,14,21)}
    brk=None
    if n>=7:
        whole=sse(xs,ys); best=None
        for k in range(3,n-2):
            e=sse(xs[:k],ys[:k])+sse(xs[k:],ys[k:])
            if best is None or e<best[0]: best=(e,k)
        if best and whole>0 and best[0]<whole*0.6:
            k=best[1]; s1=slope_of(xs[:k],ys[:k]); s2=slope_of(xs[k:],ys[k:])
            l1=statistics.mean(ys[:k]); l2=statistics.mean(ys[k:])
            if abs(s1-s2)>=0.02 or abs(l2/l1-1)>=0.12: brk=dict(day=xs[k],before=s1,after=s2)
    if not brk and n>=5:
        def lv(seg):
            m=statistics.mean(seg); return sum((y-m)**2 for y in seg), m
        lin=sse(xs,ys); best=None
        for k in range(2,n-1):
            e1,m1=lv(ys[:k]); e2,m2=lv(ys[k:])
            if best is None or e1+e2<best[0]: best=(e1+e2,k,m1,m2)
        if best and lin>0 and best[0]<lin*0.5 and abs(best[3]/best[2]-1)>=0.10:
            k=best[1]
            brk=dict(kind='step',day=xs[k],before=0,after=(slope_of(xs[k:],ys[k:]) if n-k>=3 else 0),lb=best[2],la=best[3])
    level=med
    if brk:
        seg=[past[x] for x in xs if x>=brk['day']]
        if len(seg)>=2: level=statistics.median(seg); base=level
    fslope=(brk and brk['after']) if brk else (tr[7] if tr[7] is not None else slope)
    slope=fslope
    fc=[max(1,base*(1+fslope*k)) for k in (1,2,3)]
    worst=min(tr[3] or 0,fslope) if brk else min(tr[3] or 0,tr[7] or 0,fslope)
    sell=level if worst>=0 else min(level,base*(1+worst*3))
    diverge = (not brk) and tr[3] is not None and (tr[14] or tr[7]) is not None and ((tr[3]>0.015 and (tr[14] or tr[7])<-0.015) or (tr[3]<-0.015 and (tr[14] or tr[7])>0.015))
    liq=n/min(21,xs[-1]-xs[0]+1)
    avails=[a.get(d,0) for d in xs]; availAvg=statistics.mean(avails) if avails else 0
    curA=a.get(today) if today in h else None
    net=sell*(1-AHCUT); buyUpTo=net*(1-MARGIN); profit=net-buyUpTo
    quick = availAvg>=20 and liq>=0.8 and cv<=0.25 and fslope>-0.02 and (tr[3] or 0)>-0.05
    if profit<(500 if quick else MINPROFIT) or cv>0.5 or liq<0.6 or availAvg<2: continue
    # Sicherheit: Tage, Stabilitaet, Absatz, Trend
    conf=min(1,n/14)*0.35+max(0,1-cv/0.5)*0.3+min(1,liq)*0.2+(0.15 if slope>-0.02 else 0.05 if slope>-0.06 else 0)
    flood = curA is not None and availAvg>0 and curA>2.5*availAvg
    if flood: conf*=0.8
    if diverge: conf*=0.85
    if brk and brk['after']<-0.02: conf*=0.8
    if brk and brk.get('kind')=='step': conf*=0.85   # neues Niveau erst wenige Tage alt
    curDeal = today in h and m<=buyUpTo
    # erwarteter Ertrag: Gewinn pro Stueck x verkaufbare Menge (vorsichtig: 30 % des ueblichen Angebots)
    maxQty=max(1,int(availAvg*0.3))
    value=profit*maxQty*conf
    if curDeal: value*=1.5
    wd={}
    for d,p in past.items():
        wd.setdefault((DAY0+datetime.timedelta(days=d)).weekday(),[]).append(p/med)
    wdf={w:statistics.mean(v) for w,v in wd.items()}
    rs=[]
    rs.append(f"{n} Tage Verlauf, Median {money(med)}, Schwankung {cv*100:.0f}%")
    rs.append("Trend 3T "+(pct(tr[3]) if tr[3] is not None else "-")+" / 7T "+(pct(tr[7]) if tr[7] is not None else "-")+" / 14T "+(pct(tr[14]) if tr[14] is not None else "-"))
    if brk and brk.get('kind')=='step': rs.append(f"Preissprung {(DAY0+datetime.timedelta(days=brk['day'])).strftime('%d.%m.')}: {money(brk['lb'])} -> {money(brk['la'])} ({(brk['la']/brk['lb']-1)*100:+.0f}%), seitdem {pct(brk['after'])}/Tag - gerechnet mit dem neuen Niveau")
    elif brk: rs.append(f"Trendwende {(DAY0+datetime.timedelta(days=brk['day'])).strftime('%d.%m.')}: {pct(brk['before'])} -> {pct(brk['after'])}/Tag")
    if diverge: rs.append("kurz- und langfristiger Trend widersprechen sich")
    if worst<-0.015: rs.append("fallend - Verkaufswert vorsichtig angesetzt")
    if n>=7 and len(wdf)>=4:
        lo=min(wdf,key=wdf.get); hi=max(wdf,key=wdf.get)
        if wdf[hi]-wdf[lo]>=0.06: rs.append(f"billig {WD[lo]}, teuer {WD[hi]}")
    rs.append(f"Ø {availAvg:.0f} im AH")
    if flood: rs.append(f"heute Überangebot ({curA} Stück)")
    tips.append(dict(quick=quick,t3=tr[3],t7=tr[7],t14=tr[14],id=iid,buyUpTo=int(buyUpTo),sellAt=int(sell),profit=int(profit),slope=round(slope,4),liq=round(liq,2),
        conf=round(conf,2),maxQty=maxQty,forecast=[int(x) for x in fc],value=value,deal=curDeal,reason=" · ".join(rs)))
tips.sort(key=lambda t:-t['value'])
tips=[t for t in tips if t['quick']][:60]+[t for t in tips if not t['quick']][:60]
tips.sort(key=lambda t:-t['value'])
for i,t in enumerate(tips,1): t['rank']=i
deals=sum(t['deal'] for t in tips)
gen=int(time.time())
nq=sum(t['quick'] for t in tips)
summary=f"{nq} Schnell-Flips (2h) und {len(tips)-nq} Lang-Flips aus {stats['hist']} Gegenständen mit Verlauf, {deals} davon jetzt unter Kaufziel. Mindestens 15 % Spanne nach AH-Gebühr, höchstens 30 % des üblichen Angebots kaufen."
def lstr(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
L=["-- Erzeugt von Claude aus deinen Auctionator-Scans ("+realm+"). Nicht von Hand bearbeiten.",
   f"CBAS_CLAUDE = {{ generated = {gen}, days = {len({d for v in db.values() if isinstance(v,dict) for d in (v.get(b'h') or {})})}, realm = {lstr(realm)},",
   f"  summary = {{ text = {lstr(summary)} }},", "  items = {"]
for t in tips:
    L.append(f"    [{t['id']}] = {{ rank = {t['rank']}, buyUpTo = {t['buyUpTo']}, sellAt = {t['sellAt']}, profit = {t['profit']}, quick = {'true' if t['quick'] else 'false'}, slope = {t['slope']}, t3 = {round(t['t3'] or 0,4)}, t7 = {round(t['t7'] or 0,4)}, t14 = {round(t['t14'] or 0,4)}, liq = {t['liq']}, conf = {t['conf']}, maxQty = {t['maxQty']}, forecast = {{ {', '.join(map(str,t['forecast']))} }}, reason = {lstr(t['reason'])} }},")
L+=["  },","}",""]
open(out,'w',encoding='utf-8').write("\n".join(L))
print(summary); print("heute:",DAY0+datetime.timedelta(days=today))
for t in tips[:15]: print(t['rank'],t['id'],money(t['buyUpTo']),'->',money(t['sellAt']),t['maxQty'],t['conf'],t['reason'])
