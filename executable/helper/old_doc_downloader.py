#! /usr/bin/env python
#doc_downloader.py
#needs gspread package

import csv
import gspread
import json

config = json.load(open('config.json'))
email = config['email']
password = config['password']
gc = gspread.login(email, password)

threeFiles = {"testForm.tsv":"0ArMJ6Soyh6dxdGllR0k2ZTVNN0kwZkltbk96QTQxLVE", "TLBVVCL.tsv":"0ArMJ6Soyh6dxdDAtZ0pSZ1UyNzB4OVAwbkJvRnlwVlE","screenshots.tsv":"0ArMJ6Soyh6dxdDhCZzB3ZXFKZ3FUdThzenp0U0pUUnc"}

for f in threeFiles:
	filename = "../../data/" + f
	sh = gc.open_by_key(threeFiles[f])
	ws = sh.get_worksheet(0)
	with open(filename, 'wb') as ff:
		writer = csv.writer(ff, dialect="excel-tab")
		writer.writerows(ws.get_all_values())
		print "written to " + filename