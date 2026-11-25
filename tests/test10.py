from lupa import LuaRuntime
stub=open('/tmp/stub.lua').read()
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('PNAME="Anna"'); lua.execute(stub); lua.execute(open('/tmp/uimock.lua').read())
lua.execute('''
UnitFullName=function() return "Anna","Treoninka" end
GetMaxPlayerLevel=function() return 60 end
LOCALIZED_CLASS_NAMES_MALE={WARRIOR="Krieger",PALADIN="Paladin",HUNTER="Jäger",ROGUE="Schurke",PRIEST="Priester",SHAMAN="Schamane",MAGE="Magier",WARLOCK="Hexenmeister",DRUID="Druide"}
ITEM_CLASSES_ALLOWED="Klassen: %s"
ITEM_BIND_ON_EQUIP="Beim Anlegen gebunden"
LOOT_ROLL_NEED="%s wählt 'Bedarf' für: %s"
LOOT_ROLL_GREED="%s wählt 'Gier' für: %s"
LOOT_ROLL_WON="%s gewinnt: %s"
LOOT_ITEM="%s bekommt Beute: %s."
LOOT_ROLL_ROLLED_NEED="Bedarfswurf - %d für %s von %s"
LOOT_ROLL_NEED_SELF="Ihr habt für %s 'Bedarf' gewählt."
-- Testgegenstaende: id -> {name, quality, ilvl, equipLoc, classID, subclassID, bindType, stats, lines}
ITEMS={
 [1]={"Robe des Erzmagiers",4,66,"INVTYPE_ROBE",4,1,1,{ITEM_MOD_INTELLECT_SHORT=20,ITEM_MOD_SPIRIT_SHORT=10},{}},
 [2]={"Plattengamaschen",4,70,"INVTYPE_LEGS",4,4,1,{ITEM_MOD_STRENGTH_SHORT=20,ITEM_MOD_STAMINA_SHORT=15},{}},
 [3]={"Langbogen",3,60,"INVTYPE_RANGED",2,2,1,{ITEM_MOD_AGILITY_SHORT=8},{}},
 [4]={"Lederbrust",3,60,"INVTYPE_CHEST",4,2,1,{ITEM_MOD_AGILITY_SHORT=15},{}},
 [5]={"Kettenschultern",3,60,"INVTYPE_SHOULDER",4,3,1,{ITEM_MOD_INTELLECT_SHORT=12},{}},
 [6]={"Robe der Prophezeiung",4,66,"INVTYPE_ROBE",4,1,1,{ITEM_MOD_INTELLECT_SHORT=20},{"Klassen: Priester"}},
 [7]={"Ring der Stärke",3,60,"INVTYPE_FINGER",4,0,2,{ITEM_MOD_STRENGTH_SHORT=10},{"Beim Anlegen gebunden"}},
 [8]={"Umhang",3,60,"INVTYPE_CLOAK",4,1,1,{ITEM_MOD_AGILITY_SHORT=10},{}},
 [9]={"Buchband",3,60,"INVTYPE_RELIC",4,7,1,{},{"Anlegen: Erhöht durch Heilzauber verursachte Heilung"}},
 [10]={"Rezept: Trank",2,40,"",9,0,0,{},{}},
 [11]={"Zweihandaxt",3,60,"INVTYPE_2HWEAPON",2,1,2,{ITEM_MOD_STRENGTH_SHORT=20},{"Beim Anlegen gebunden"}},
 [12]={"Graues Zeug",0,10,"INVTYPE_CHEST",4,1,0,{},{}},
}
local function id(link) return tonumber(link:match("item:(%d+)")) end
C_Item={GetItemInfo=function(link) local d=ITEMS[id(link)] if not d then return nil end return d[1],link,d[2],d[3],1,"","",1,d[4],0,0,d[5],d[6],d[7] end,
        GetItemStats=function(link) return ITEMS[id(link)][8] end}
C_TooltipInfo={GetHyperlink=function(link) local l={} for _,t in ipairs(ITEMS[id(link)][9]) do l[#l+1]={leftText=t} end return {lines=l} end}
function L(i) return "|cffa335ee|Hitem:"..i.."::::::::60:::::|h["..ITEMS[i][1].."]|h|r" end
-- Gruppe
GROUP={party1={"Bob","WARRIOR",60},party2={"Mia","MAGE",60},party3={"Pia","PRIEST",60},party4={"Rex","ROGUE",35}}
UnitExists=function(u) return u=="player" or GROUP[u]~=nil end
UnitName=function(u) if u=="player" then return "Anna" end return GROUP[u][1],nil end
UnitClass=function(u) if u=="player" then return "Druide","DRUID" end return "x",GROUP[u][2] end
UnitLevel=function(u) if u=="player" then return 60 end return GROUP[u][3] end
IsInRaid=function() return false end
GetRealZoneText=function() return "Geschmolzener Kern" end
SendChatMessage=function(m,c) SENT={m,c} end
''')
ns=lua.table()
toc=[l.strip() for l in open('CBAS/CBAS.toc') if l.strip().endswith('.lua')]
for f in toc:
    src=open('CBAS/'+f,encoding='utf-8').read()
    lua.eval('function(ns,s,n) local c,e=load(s,n) if not c then error(e) end return c("CBAS",ns) end')(ns,src,f)
lua.eval('function(ns) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"ADDON_LOADED","CBAS") end end for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"PLAYER_LOGIN") end end end')(ns)
GW=ns.Geier
print("=== Regeltests ===")
cases=[(1,"WARRIOR",60),(1,"MAGE",60),(2,"MAGE",60),(2,"WARRIOR",35),(3,"PRIEST",60),(3,"HUNTER",60),(4,"ROGUE",60),
       (4,"WARRIOR",60),(5,"SHAMAN",60),(5,"HUNTER",30),(6,"MAGE",60),(6,"PRIEST",60),(7,"MAGE",60),(8,"ROGUE",60),(9,"DRUID",60),
       (9,"PALADIN",60),(10,"WARRIOR",60),(11,"ROGUE",60),(11,"WARRIOR",60)]
for i,c,lv in cases:
    res=GW.Evaluate(lua.eval("L")(i), c, lv); v,r=res[0],res[1]
    print("%-22s %-8s L%-2d -> %-6s %s"%(lua.globals().ITEMS[i][1][:22],c,lv,v,r))
print("=== Chat-Simulation ===")
fire=lua.eval('function(msg) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"CHAT_MSG_LOOT",msg) end end end')
L=lua.eval('L')
fire("Bob wählt 'Bedarf' für: "+L(1))
fire("Bedarfswurf - 87 für "+L(1)+" von Bob")
fire("Bob gewinnt: "+L(1))
fire("Bob bekommt Beute: "+L(1)+".")
fire("Mia wählt 'Bedarf' für: "+L(1))
fire("Rex wählt 'Bedarf' für: "+L(11))
fire("Pia wählt 'Gier' für: "+L(11))
fire("Bob wählt 'Bedarf' für: "+L(3))
fire("Bob bekommt Beute: "+L(12)+".")
fire("Ihr habt für "+L(4)+" 'Bedarf' gewählt.")
print("Verlauf:")
for h in GW.db().history.values():
    print("  %-16s %-8s %-6s roll=%s won=%s %s"%(h.player, h.kind, h.verdict, h.roll, h.won, h.reason))
print("Spieler:")
for k,p in GW.db().players.items():
    print("  ",k,p['class'],"needs",p.needs,"frag",p.frag,"geier",p.geier,GW.PlayerLabel(p))
print("=== UI ===")
run=lua.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
print("öffnen:", run('SlashCmdList["CBAS"]("geier")'), ns.Suite.current, [m.name for m in ns.Suite.modules.values()])
print("Spieler wählen:", run('CBAS.Geier.UI.selected="Bob-Treoninka"; CBAS.Geier.UI:Refresh()'))
print("markieren:", run('CBAS.Geier.UI.markBtn._scripts.OnClick()'), "markiert:", GW.db().marked["Bob-Treoninka"] is not None)
print("melden:", run('CBAS.Geier.UI:Report()'), lua.globals().SENT and lua.globals().SENT[1])
print("Detail:", ns.Geier.UI.det.GetText(ns.Geier.UI.det).replace("\n"," | ")[:300])
print("Status:", ns.Geier.UI.status.GetText(ns.Geier.UI.status))
print("Liste Zeilen:", len(ns.Geier.UI.list))
print("check-Befehl:", run('SlashCmdList["CBAS"]("check Krieger '+L(1).replace('"','\\"')+'")'))
print("Gruppenwarnung:", run('CBAS.Geier.CheckGroup()'))
