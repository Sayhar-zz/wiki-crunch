#! /usr/bin/env python

# This is calendar_writer.py

#What is does - given a test_id, write or update the correct event on the calendar. 

import gspread
import json
import argparse
import calendar_helper as ch
import pdb

parser = argparse.ArgumentParser(description="Given a testid find the start and end times of that test.")
parser.add_argument("id", help="Use this test")
args = parser.parse_args()
inid = args.id

config = json.load(open('config.json'))
email = config['email']
password = config['password']
key = config['key']
start_location = int(config['startcolumn'])
end_location = int(config['endcolumn'])
gc = gspread.login(email, password)
ws = gc.open_by_key(key).sheet1

if ';' in inid:
	print inid
	print "ERROR. ATTEMPTED SQL INJECTION?"
	raise SystemExit(0)

cell_list = ws.findall(inid)
rows = []
toprow = ws.row_values(1)
for cell in cell_list:
	line = ws.row_values(cell.row)
	rows.append( dict(zip(toprow, line)) )

ch.easyinsert(rows)
