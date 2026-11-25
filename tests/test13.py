exec(open('/tmp/test12.py').read().split('print("=== MS>OS-Regel ===")')[0].replace('print(','(lambda *a: None)('))
ns.db.settings.lootMSOS=True
lua.execute('wipe(CBAS.Geier.db().history)')
fire("Pia wählt 'Bedarf' für: "+L(22))
h=GW.db().history[1]; print("MS>OS an:", h.player, h.verdict, "|", h.reason)
