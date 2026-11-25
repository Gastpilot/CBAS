exec(open('/tmp/test34.py').read().split('print("Einstellungen:"')[0])
la.execute('''
GameTooltip_Hide=GameTooltip_Hide or function() end
LFGBrowseSearchEntryTooltip=CreateFrame("Frame","LFGBrowseSearchEntryTooltip")
function LFGBrowseSearchEntryTooltip_UpdateAndShow(tt,id) tt:Show() end
INFO[3]={leaderName="Klaus-Meier",numMembers=3,name="MC",comment=""}
MEMB[3]={{name="Klaus-Meier",classFilename="WARRIOR"},{name="Pierre-Dubois",classFilename="MAGE"},{name="Tom-Qt",classFilename="PRIEST"}}
CBAS.Geier.Mark("Pierre Dubois", true, "würfelt Bedarf auf alles")
''')
la.execute('FIRE("ADDON_LOADED","Blizzard_LFGBrowse")')
print("Hover:", run('LFGBrowseSearchEntryTooltip_UpdateAndShow(LFGBrowseSearchEntryTooltip, 3)'))
t=la.eval('CBASLFGTooltip')
print("Tooltip:", la.eval('CBASLFGTooltip and CBASLFGTooltip:IsShown()'))
lines=la.eval('CBASLFGTooltip and CBASLFGTooltip.lines')
if lines:
    for k,v in lines.items(): print("  ", v)
la.execute('LINES={} CBASLFGTooltip.AddLine=function(_,t) table.insert(LINES,t) end')
run('LFGBrowseSearchEntryTooltip_UpdateAndShow(LFGBrowseSearchEntryTooltip, 3)')
import re
for v in la.globals().LINES.values(): print("  ", re.sub(r"\|c[0-9a-f]{8}|\|r|\|T[^|]*\|t","",v))
