src=open("/tmp/test10.py").read().split("GW=ns.Geier")[0].replace("SendChatMessage=function","Minimap=CreateFrame(\"Frame\",\"Minimap\")\nSendChatMessage=function",1)
exec(src)
lua.execute('''OPENED={} ChatFrame_OpenChat=function(t) table.insert(OPENED,t) end
ChatFrame_SendTell=function(n) table.insert(OPENED,"TELL:"..n) end
ChatEdit_GetActiveWindow=function() return {Insert=function(_,t) table.insert(OPENED,"  +"..t) end} end
GetLocale=function() return "deDE" end IsInGroup=function() return true end''')
CI=ns.CanIHave
def run(code):
    try: lua.execute(code); return "OK"
    except Exception as e: return "FEHLER "+str(e)[:200]
lua.execute('CBAS.CanIHave.db().main="HEAL"')
def chk(i):
    r=CI.Check(lua.eval("L")(i)); return r.state, r.why
print("Robe (Heil=Main):", chk(1))
print("Lederbrust für Krieger-Sicht n/a; Schild:", chk(2))
print("Plattengamaschen:", chk(2))
print("Lederbrust (Rex Schurke MS):", chk(4))
lua.execute('GROUP.party4=nil')
print("Lederbrust ohne Schurke:", chk(4))
print("Ring BoE:", chk(7))
print("Drop:", run('CBAS.CanIHave.OnDrop(L(4))'), lua.eval('CBASCanIHave:IsShown()'))
print("Popup-Knopf:", lua.eval('CBAS.CanIHave.popup.ask:GetText()'))
print("Begründung:", run('CBAS.CanIHave.Reason(CBAS.CanIHave.popup.e)'), list(lua.globals().OPENED.values())[-1])
print("Bob gewinnt:", run('CBAS.CanIHave.OnLoot("won", "Bob", L(4))'), lua.eval('CBAS.CanIHave.popup.e.winner'), lua.eval('CBAS.CanIHave.popup.e.canWhisper'))
print("Gewinner fragen:", run('CBAS.CanIHave.WhisperWinner(CBAS.CanIHave.popup.e)'), list(lua.globals().OPENED.values())[-2:])
print("Ich bekomme es:", run('CBAS.CanIHave.OnLoot("got", CBAS.playerFull, L(4))'), lua.eval('CBAS.CanIHave.popup.e.mine'))
print("Danke:", run('CBAS.CanIHave.Thanks(CBAS.CanIHave.popup.e)'), list(lua.globals().OPENED.values())[-1])
lua.execute('CBAS.CanIHave.db().lang="en"')
print("Englisch:", run('CBAS.CanIHave.Ask(CBAS.CanIHave.popup.e)'), list(lua.globals().OPENED.values())[-1])
print("Ansicht:", run('CBAS.Suite:Toggle("cihi")'), run('CBAS.CanIHave.UI.selected=CBAS.CanIHave.db and select(2,CBAS.CanIHave.db())[1]; CBAS.CanIHave.UI:Refresh()'))
print(lua.eval('CBAS.CanIHave.UI.det:GetText()'))
print("Unterknöpfe:", lua.eval('CBAS.Suite.subBtns.geier[1]:GetText()'), "|", lua.eval('CBAS.Suite.subBtns.geier[2]:GetText()'))
print("Minimap:", lua.eval('CBASMinimapButton ~= nil'), run('CBASMinimapButton:GetScript("OnClick")(CBASMinimapButton,"LeftButton")'), run('SlashCmdList["CBAS"]("minimap")'), lua.eval('CBAS.db.settings.minimapHide'))
print("Optionen-Panel:", lua.eval('CBAS.Standards.panel ~= nil'))
print("Tooltip Fach:", run('CBAS_OnCompartmentEnter(nil, UIParent)'))
