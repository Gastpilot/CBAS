# Erzeugt kleine Flaggen als TGA (32x32, Flagge oben 32x21) fuer den WoW-Chat.
import struct, math, os, sys
OUT=sys.argv[1]
W,H=32,21
def C(h): return tuple(int(h[i:i+2],16) for i in (0,2,4))
def new(bg): return [[bg for _ in range(W)] for _ in range(H)]
def rect(img,x0,y0,x1,y1,c):
    for y in range(max(0,int(y0)),min(H,int(math.ceil(y1)))):
        for x in range(max(0,int(x0)),min(W,int(math.ceil(x1)))): img[y][x]=c
def hbands(cols,weights=None):
    weights=weights or [1]*len(cols); tot=sum(weights); img=new(cols[0]); y=0
    for c,w in zip(cols,weights):
        rect(img,0,round(y),W,round(y+H*w/tot),c); y+=H*w/tot
    return img
def vbands(cols,weights=None):
    weights=weights or [1]*len(cols); tot=sum(weights); img=new(cols[0]); x=0
    for c,w in zip(cols,weights):
        rect(img,round(x),0,round(x+W*w/tot),H,c); x+=W*w/tot
    return img
def nordic(bg,cross,inner=None):
    img=new(bg); cx=10
    rect(img,cx-3,0,cx+3,H,cross); rect(img,0,H/2-3,W,H/2+3,cross)
    if inner: rect(img,cx-1.5,0,cx+1.5,H,inner); rect(img,0,H/2-1.5,W,H/2+1.5,inner)
    return img
def line(img,x0,y0,x1,y1,w,c):
    for y in range(H):
        for x in range(W):
            px,py=x+.5,y+.5; dx,dy=x1-x0,y1-y0; L=dx*dx+dy*dy
            t=max(0,min(1,((px-x0)*dx+(py-y0)*dy)/L)); qx,qy=x0+t*dx,y0+t*dy
            if (px-qx)**2+(py-qy)**2<=(w/2)**2: img[y][x]=c
def circle(img,cx,cy,r,c):
    for y in range(H):
        for x in range(W):
            if (x+.5-cx)**2+(y+.5-cy)**2<=r*r: img[y][x]=c
R,Wh,B,K,Y,G=C('d0202a'),C('ffffff'),C('1f3f9e'),C('000000'),C('ffce00'),C('15924a')
F={}
F['de']=hbands([K,C('dd0000'),Y])
F['at']=hbands([C('ed2939'),Wh,C('ed2939')])
F['nl']=hbands([C('ae1c28'),Wh,C('21468b')])
F['ru']=hbands([Wh,C('0039a6'),C('d52b1e')])
F['hu']=hbands([C('ce2939'),Wh,C('477050')])
F['lt']=hbands([C('fdb913'),C('006a44'),C('c1272d')])
F['pl']=hbands([Wh,C('dc143c')])
F['ua']=hbands([C('0057b7'),C('ffd700')])
F['fr']=vbands([C('0055a4'),Wh,C('ef4135')])
F['it']=vbands([C('009246'),Wh,C('ce2b37')])
F['be']=vbands([K,C('fdda24'),C('ef3340')])
F['ie']=vbands([C('169b62'),Wh,C('ff883e')])
F['ro']=vbands([C('002b7f'),C('fcd116'),C('ce1126')])
F['es']=hbands([C('aa151b'),C('f1bf00'),C('aa151b')],[1,2,1])
F['pt']=vbands([C('006600'),C('ff0000')],[2,3]); circle(F['pt'],W*0.4,H/2,4,C('ffcc00'))
F['se']=nordic(C('006aa7'),C('fecc00'))
F['dk']=nordic(C('c8102e'),Wh)
F['no']=nordic(C('ba0c2f'),Wh,C('00205b'))
F['fi']=nordic(Wh,C('002f6c'))
ch=new(C('da291c')); rect(ch,W/2-2,H/2-7,W/2+2,H/2+7,Wh); rect(ch,W/2-7,H/2-2,W/2+7,H/2+2,Wh); F['ch']=ch
gb=new(C('012169'))
line(gb,0,0,W,H,5,Wh); line(gb,0,H,W,0,5,Wh); line(gb,0,0,W,H,1.6,C('c8102e')); line(gb,0,H,W,0,1.6,C('c8102e'))
rect(gb,W/2-3.5,0,W/2+3.5,H,Wh); rect(gb,0,H/2-3.5,W,H/2+3.5,Wh)
rect(gb,W/2-2,0,W/2+2,H,C('c8102e')); rect(gb,0,H/2-2,W,H/2+2,C('c8102e')); F['gb']=gb
us=new(Wh)
for i in range(13):
    if i%2==0: rect(us,0,i*H/13,W,(i+1)*H/13,C('b22234'))
rect(us,0,0,W*0.4,H*7/13,C('3c3b6e'))
for yy in range(1,6,2):
    for xx in range(1,12,3): us[yy][xx]=Wh
F['us']=us
cz=hbands([Wh,C('d7141a')])
for y in range(H):
    for x in range(W):
        if x+.5 <= 16*(1-abs((y+.5)-H/2)/(H/2)): cz[y][x]=C('11457e')
F['cz']=cz
gr=new(C('0d5eaf'))
for i in range(9):
    if i%2==1: rect(gr,0,i*H/9,W,(i+1)*H/9,Wh)
rect(gr,0,0,W*0.37,H*5/9,C('0d5eaf')); rect(gr,W*0.37/2-1,0,W*0.37/2+1,H*5/9,Wh); rect(gr,0,H*5/18-1,W*0.37,H*5/18+1,Wh)
F['gr']=gr
tr=new(C('e30a17')); circle(tr,12,H/2,6,Wh); circle(tr,13.6,H/2,4.8,C('e30a17')); circle(tr,19.5,H/2,2,Wh); F['tr']=tr
br=new(C('009c3b'))
for y in range(H):
    for x in range(W):
        if abs(x+.5-W/2)/(W/2-2)+abs(y+.5-H/2)/(H/2-2)<=1: br[y][x]=C('ffdf00')
circle(br,W/2,H/2,4.6,C('002776')); F['br']=br
def save(name,img):
    # TGA 32x32, 32 Bit BGRA, unkomprimiert, Ursprung unten links; Flagge in den oberen 21 Zeilen
    hdr=struct.pack('<BBBHHBHHHHBB',0,0,2,0,0,0,0,0,32,32,32,8)
    rows=[]
    full=[[None]*32 for _ in range(32)]
    for y in range(H):
        for x in range(W): full[y][x]=img[y][x]
    data=bytearray()
    for y in range(31,-1,-1):
        for x in range(32):
            p=full[y][x]
            if p is None: data+=bytes((0,0,0,0))
            else:
                # 1-Pixel-Rand leicht abdunkeln, damit helle Flaggen auf hellem Chat-Hintergrund lesbar bleiben
                edge = x in (0,W-1) or y in (0,H-1)
                r,g,b=p
                if edge: r,g,b=int(r*.6),int(g*.6),int(b*.6)
                data+=bytes((b,g,r,255))
    open(os.path.join(OUT,name+'.tga'),'wb').write(hdr+bytes(data))
for k,v in F.items(): save(k,v)
print(len(F),"Flaggen:",", ".join(sorted(F)))
# Vorschau
try:
    from PIL import Image
    sheet=Image.new('RGB',(len(F)*40,30),(40,40,40))
    for i,k in enumerate(sorted(F)):
        im=Image.open(os.path.join(OUT,k+'.tga')).convert('RGBA').crop((0,0,32,21))
        sheet.paste(im,(i*40+4,4),im)
    sheet=sheet.resize((sheet.width*3,sheet.height*3),Image.NEAREST); sheet.save('/tmp/flags_preview.png')
except Exception as e: print("keine Vorschau:",e)
