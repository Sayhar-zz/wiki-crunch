#! /usr/bin/env python
#doc_downloader.py
#needs gspread package
#WARNING - doesn't work due to unicode. Sorry!
import pdb
import csv
import gspread
import json
import codecs
import cStringIO

config = json.load(open('config.json'))
email = config['email']
password = config['password']
gc = gspread.login(email, password)

threeFiles = {"testForm.tsv":"0ArMJ6Soyh6dxdGllR0k2ZTVNN0kwZkltbk96QTQxLVE", "TLBVVCL.tsv":"0ArMJ6Soyh6dxdDAtZ0pSZ1UyNzB4OVAwbkJvRnlwVlE","screenshots.tsv":"0ArMJ6Soyh6dxdDhCZzB3ZXFKZ3FUdThzenp0U0pUUnc"}
#threeFiles = {"testForm.tsv":"0ArMJ6Soyh6dxdGllR0k2ZTVNN0kwZkltbk96QTQxLVE", "screenshots.tsv":"0ArMJ6Soyh6dxdDhCZzB3ZXFKZ3FUdThzenp0U0pUUnc"}



for f in threeFiles:
#	print f
	filename = "../../data/" + f
	sh = gc.open_by_key(threeFiles[f])
	ws = sh.get_worksheet(0)
	ff = codecs.open(filename, mode='wb', encoding='utf-8', errors="replace")
	writer = csv.writer(ff, dialect="excel-tab")
	
	rows = ws.get_all_values()
	for row in rows:
		try:
			writer.writerow(row)
		except:
			print "\tERROR! Test " + row[12] + " did not download! (Probably because unicode)" 
	print "written to " + filename
