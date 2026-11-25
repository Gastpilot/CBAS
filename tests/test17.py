exec(open('/tmp/test15.py').read().split('print("=== Lootsystem-Hinweise ===")')[0].replace('print(','(lambda *a: None)('))
run=lua.eval('function(code) local f=load(code) local ok,e=xpcall(f, debug.traceback) return ok and "OK" or e end')
print("öffnen:", run('SlashCmdList["CBAS"]("gscout")'))
print("Köpfe:", [lua.eval('function(i) return CBAS.UI.headers[i].fs:GetText() end')(i) for i in range(1,10)])
for r in range(1,3):
    print("Zeile %d:"%r, [lua.eval('function(r,i) return CBAS.UI.rows[r].cells[i]:GetText() end')(r,i) for i in range(1,10)])
print("nach 60ern sortieren:", run('CBAS.UI.headers[5]._scripts.OnClick()'), ns.UI.sortKey, [e.g.name for e in ns.UI.list.values()])
