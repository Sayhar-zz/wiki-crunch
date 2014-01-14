#! /usr/bin/env python

import json
import gspread
from dochelper import *
import pdb

config = json.load(open('config.json'))
email = config['email']
password = config['password']
key = config['key']
bannerc = int(config['bannercolumn'])
idc = int(config['idcolumn'])
gc = gspread.login(email, password)

ws = gc.open_by_key(key).sheet1

def guessTID(banners):
	prefix = commonprefix(banners)
	tid = prefix.strip("_")
	return tid

# Go through the sheet, parsing it into tests
# For each test, find its testid, then write it

banners = ws.col_values(1)
this_test_names = []
this_test_rows = []
for i, banner in enumerate(banners):
	i += 1
	if i == 1:
		continue
	if banner != None:
		this_test_names.append(banner)
		this_test_rows.append(i)
	else:
		testid = guessTID(this_test_names)
		#pdb.set_trace()
		for row in this_test_rows:
			if ws.cell(row, idc).value == None:
				print "updating: " + str(row) + ',' + str(idc) + ": " + testid
				ws.update_cell(row,idc, testid)
		this_test_names = []
		this_test_rows = []

