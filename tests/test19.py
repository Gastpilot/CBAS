from lupa import LuaRuntime
stub=open('/tmp/stub.lua').read()
def client(name, extra=""):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('PNAME="%s"'%name); lua.execute(stub); lua.execute(open('/tmp/uimock.lua').read())
    lua.execute('''UnitFullName=function() return "%s","Treoninka" end
    GetRealmName=function() return "CAMWOW EU4 Realm 7" end
    ZONE="Orgrimmar" GetRealZoneText=function() return ZONE end
    NPCGUID="Creature-0-4469-0-11-3310-000012ABCD"
    UnitExists=function() return true end
    UnitIsPlayer=function(u) return false end
    UnitGUID=function(u) return NPCGUID end
    strsplit=function(sep,s) local t={} for p in (s..sep):gmatch("(.-)"..sep:gsub("%%-","%%%%-")) do t[#t+1]=p end return table.unpack(t) end
    FRIENDS={} C_FriendList={GetFriendInfo=function(n) return FRIENDS[n] end}
    SENTL={} C_ChatInfo.SendAddonMessage=function(p,m,c,t) if p=="GScoutL" then table.insert(SENTL,{m=m,t=t}) end return 0 end
    NOW=1000 GetTime=function() return NOW end
    '''%name + extra)
    ns=lua.table()
    for f in [l.strip() for l in open('CBAS/CBAS.toc') if l.strip().endswith('.lua')]:
        lua.eval('function(ns,s,n) local c,e=load(s,n) if not c then error(e) end return c("CBAS",ns) end')(ns,open('CBAS/'+f.replace(chr(92),'/'),encoding='utf-8').read(),f)
    lua.eval('function(ns) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"ADDON_LOADED","CBAS") end end for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,"PLAYER_LOGIN") end end end')(ns)
    return lua, ns
la,A=client("Anna")
lb,B=client("Bernd")
ev=lambda lua,e,*a: lua.eval('function(e,...) for _,fr in ipairs(FRAMES) do if fr.h then fr.h(fr,e,...) end end end')(e,*a)
print("=== Erkennung ===")
print("vorher:", A.Layer.HeaderText(A.Layer))
ev(la,"UPDATE_MOUSEOVER_UNIT")
print("NPC gesehen:", A.Layer.HeaderText(A.Layer), "| ID:", A.Layer.cur.key)
# anderer Layer bekannt machen (z.B. später gewechselt)
la.execute('NPCGUID="Creature-0-4469-0-17-3310-000012ABCD"'); ev(la,"PLAYER_TARGET_CHANGED")
print("gewechselt:", A.Layer.HeaderText(A.Layer))
la.execute('NPCGUID="Creature-0-4469-0-11-3310-000012ABCD"'); ev(la,"PLAYER_TARGET_CHANGED")
print("zurück:", A.Layer.HeaderText(A.Layer))
# Spieler/Haustiere zaehlen nicht
la.execute('NPCGUID="Player-1234-ABCDEF"'); ev(la,"PLAYER_TARGET_CHANGED"); print("Spieler-GUID ignoriert:", A.Layer.cur.key)
la.execute('ZONE="Brachland"'); ev(la,"ZONE_CHANGED_NEW_AREA"); print("Zone gewechselt:", A.Layer.HeaderText(A.Layer))
la.execute('ZONE="Orgrimmar" NPCGUID="Creature-0-4469-0-11-3310-000012ABCD"'); ev(la,"UPDATE_MOUSEOVER_UNIT")
print("=== Partner ===")
la.execute('FRIENDS["Bernd"]={connected=true} FRIENDS["Carl"]={connected=false}')
A.Layer.AddPartner("Bernd"); A.Layer.AddPartner("Carl"); A.Layer.AddPartner("Dora")
print("an:", [x.t for x in la.globals().SENTL.values()])
# Bernd auf Layer 17 in Orgrimmar
lb.execute('NPCGUID="Creature-0-4469-0-17-3310-000012ABCD"'); ev(lb,"UPDATE_MOUSEOVER_UNIT")
for m in la.globals().SENTL.values():
    if m.t.startswith("Bernd"): ev(lb,"CHAT_MSG_ADDON","GScoutL",m.m,"WHISPER","Anna-Treoninka")
for m in lb.globals().SENTL.values(): ev(la,"CHAT_MSG_ADDON","GScoutL",m.m,"WHISPER","Bernd-Treoninka")
for x in A.Layer.PeerLines(A.Layer).values(): print("  Anna sieht:", x)
print("  Kopf:", A.Layer.HeaderText(A.Layer))
# Bernd wechselt auf Annas Layer
lb.execute('SENTL={} NPCGUID="Creature-0-4469-0-11-3310-000012ABCD"'); ev(lb,"PLAYER_TARGET_CHANGED")
for m in lb.globals().SENTL.values(): ev(la,"CHAT_MSG_ADDON","GScoutL",m.m,"WHISPER","Bernd-Treoninka")
print("  nach Wechsel:", A.Layer.HeaderText(A.Layer))
print("  ", [x for x in A.Layer.PeerLines(A.Layer).values()][0])
print("=== UI ===")
run=la.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
print("öffnen:", run('SlashCmdList["CBAS"]("gscout")'), "| Kopf:", la.eval('CBAS.Suite.layerText:GetText()'))
print("Status:", la.eval('CBAS.UI.status:GetText()').split("\n")[0])
print("Kopf-Tooltip:", run('local lh=CBAS.Suite.layerText._parent; lh._scripts.OnEnter(lh)'))
print("/crap layer:", run('SlashCmdList["CBAS"]("layer")'))
print("Einstellungen:", run('SlashCmdList["CBAS"]("settings")'), la.eval('CBAS.Suite.panels.settings.partnerEdit:GetText()'))
la.execute('WHO={{fullName="X",fullGuildName="Nachtwache",level=60,filename="MAGE",raceStr="Orc",area="Orgrimmar"}} C_FriendList.SendWho=function() end C_FriendList.GetNumWhoResults=function() return 1 end C_FriendList.GetWhoInfo=function(i) return WHO[i] end')
run('CBAS.OnWhoUpdate()')
print("Gilde Layer:", run('CBAS.UI.selected="Nachtwache"; CBAS.UI:UpdateDetail()'), [l for l in A.UI.DetailText(A.UI, A.db.guilds["Nachtwache"]).split("\n") if "Layer" in l])
