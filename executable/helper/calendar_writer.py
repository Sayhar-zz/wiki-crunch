#! /usr/bin/env python

# This is calendar_writer.py

#What is does - given a test_id, write or update the correct event on the calendar. 

import gspread
import json
import argparse
import calendar_helper as ch
import pdb
import dochelper as dh

parser = argparse.ArgumentParser(description="Given a testid find the start and end times of that test.")
parser.add_argument("id", help="Use this test")
args = parser.parse_args()
inid = args.id

config = json.load(open('config.json'))
email = config['email']
password = config['password']
key = config['key']
idc = int(config['idcolumn'])
start_location = int(config['startcolumn'])
end_location = int(config['endcolumn'])
gc = gspread.login(email, password)
ws = gc.open_by_key(key).sheet1

if ';' in inid:
	print inid
	print "ERROR. ATTEMPTED SQL INJECTION?"
	raise SystemExit(0)

rows = dh.get_test(inid, ws, idc)

ch.easyinsert(rows)
