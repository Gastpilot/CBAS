exec(open('/tmp/test9.py').read().split('print("Zurück zu GScout:"')[0].replace('print(','(lambda *a: None)('))
la=lua
la.execute('''
local now=time()
for i,n in ipairs({"Alpha","Beta","Gamma","Delta","Epsilon"}) do
  local g=CBAS.GetGuild(n, nil, true, "manual")
  g.memberCount=i*8
  g.instances={MC={max=i*3,groups=i,seen=now}}
  g.tags=g.tags or {}
  if i>=4 then g.tags["Ambitioniert"]=true end
  if i==5 then g.lastRecruit=now g.recruitSeen=now end
end
GameTooltip.AddDoubleLine=GameTooltip.AddDoubleLine or function() end
''')
print("Liste:", run('CBAS.Suite:Select("gscout"); CBAS.UI:Refresh()'))
print("Kurve:", run('CBAS.GuildChart.Toggle()'))
f=la.eval('CBASGuildChart')
bars=[b for b in la.eval('CBASGuildChart.bars').values() if b.IsShown(b)]
print("Balken:", len(bars), [ (b.e.g.name, b.e.s) for b in bars])
print(la.eval('CBASGuildChart.info:GetText()'))
print("Tooltip:", run('local b=CBASGuildChart.bars[1]; b:GetScript("OnEnter")(b)'))
print("Klick:", run('local b=CBASGuildChart.bars[1]; b:GetScript("OnClick")(b)'), la.eval('CBAS.UI.selected'))
la.execute('local d=math.floor(time()/86400) for k,g in pairs(CBAS.db.guilds) do g.sh={[d-7]=10,[d-3]=20} end')
print("Verlauf:", run('CBASGuildChart.bHist:GetScript("OnClick")()'))
print(la.eval('CBASGuildChart.info:GetText()'))
print("Speichern:", run('CBAS.GuildChart.Record()'))
