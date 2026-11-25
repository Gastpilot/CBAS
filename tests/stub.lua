string.join=function(sep,...) return table.concat({...},sep) end
tostringall=function(...) local t={...} for i=1,select('#',...) do t[i]=tostring(t[i]) end return table.unpack(t,1,select('#',...)) end
wipe=function(t) for k in pairs(t) do t[k]=nil end return t end
time=os.time; GetTime=os.clock; date=os.date
TIMERS={}
C_Timer={After=function(d,f) table.insert(TIMERS,f) end}
FRAMES={}
CreateFrame=function() local fr={RegisterEvent=function() end} fr.SetScript=function(self,k,f) self.h=f end table.insert(FRAMES,fr) return fr end
GetNormalizedRealmName=function() return "Forever" end
IsInInstance=function() return false end
InCombatLockdown=function() return false end
IsInRaid=function() return false end
IsInGroup=function() return true end
UnitName=function() return PNAME end
GetPlayerInfoByGUID=function() end
OUTBOX={}
C_ChatInfo={RegisterAddonMessagePrefix=function() end, SendAddonMessage=function(p,m,c) table.insert(OUTBOX,m) return 0 end}
GetLocale=function() return "deDE" end
FriendsFrame=nil
