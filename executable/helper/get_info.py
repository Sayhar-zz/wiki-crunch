#! /usr/bin/env python

# Name: get_info.py
# Purpose: Given a testid, look it up in the doc, and return the info strings

import dochelper as helper
import csv
import sys
import gspread
import json

config = json.load(open('config.json'))
email = config['email']
password = config['password']
key = config['key']
gc = gspread.login(email, password)
ws = gc.open_by_key(key).sheet1

idcolumn = int(config['idcolumn'])
tid = str(sys.argv[1])

test = helper.get_test(tid, ws, idcolumn)
info = []
for line in test:
	info.append(line['Extra info'])

while None in info: info.remove(None)
print "\n".join(info)