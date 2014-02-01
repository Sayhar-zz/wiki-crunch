#! /usr/bin/env python
# This is alltids.py
#Take in google doc and return a list of testids
import csv
import json
import gspread
from os.path import commonprefix
import pdb

config = json.load(open('config.json'))
email = config['email']
password = config['password']
key = config['key']
gc = gspread.login(email, password)
tcol = int(config['idcolumn'])

ws = gc.open_by_key(key).sheet1
rows = ws.get_all_values()


raw_list = ws.col_values(tcol)
raw_list.reverse()
raw_list.pop() #get rid of header
unduped_list = []
for tid in raw_list:
	if tid is not None and tid not in unduped_list:
		unduped_list.append(tid)

print " ".join(unduped_list)