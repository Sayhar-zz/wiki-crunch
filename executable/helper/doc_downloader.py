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

w_id = config['w_id']
key = config['key']

sh = gc.open_by_key(key)
ws = sh.get_worksheet(0)

with open("../../data/easyform.tsv", 'wb') as f:
	writer = csv.writer(f, dialect="excel-tab")
	writer.writerows(ws.get_all_values())
	print "written to ../../data/easyform.tsv"