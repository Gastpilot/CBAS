exec(open('/tmp/test9.py').read().split('print("Zurück zu GScout:"')[0].replace('print(','(lambda *a: None)('))
la=lua
S=la.eval('CBAS.Suite')
print("Reiter:", sorted(S.tabs.keys()))
print("Gildenlos über GScout:", run('CBAS.Suite:Select("gildenlos")'), S.current, la.eval('CBAS.Suite.subBtns.gscout[2]:IsShown()'))
print("GScout-Reiter merkt Unteransicht:", run('CBAS.Suite:Select("flipper"); CBAS.Suite.tabs.gscout:GetScript("OnClick")()'), S.current)
print("Zahnrad:", run('CBAS.Suite.gear:GetScript("OnClick")()'), S.current, "->", run('CBAS.Suite.gear:GetScript("OnClick")()'), S.current)
print("Unterknöpfe im Flipper versteckt:", run('CBAS.Suite:Select("flipper")'), la.eval('CBAS.Suite.subBtns.gscout[1]:IsShown()'))
print("/crap gildenlos:", run('CBAS.Suite:Toggle("gildenlos")'), S.current)
