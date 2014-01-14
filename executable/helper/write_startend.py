#! /usr/bin/env python

# given a testid, find the start and end times of that test
# then write them to the doc


import gspread
import json
import argparse
from dochelper import *
from subprocess import Popen, PIPE
import time
from datetime import datetime

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

#Okay now we have:
# inid = the testid to look up
# ws = worksheet we are using

if ';' in inid:
	print inid
	print "ERROR. ATTEMPTED SQL INJECTION?"
	raise SystemExit(0)


#So we want to:
# Open mysql and run a command to give us the start and end donation in that test
# IF there are results AND 
# IF the end donation is > 2 hours ago
# THEN find that row in the doc
# AND write the end time at that end donation. 



#1. Open mysql 
# Not going to perform any validation or error checking. SQL Injection is totally possible here.
# The justification: if you can run this script, you can just access mysql directly.
SQL = "select min(unixtime), max(unixtime) from fr_test.banners where test_id = '{}' and imps > 100;".format(inid)
args = ['echo', SQL]
p1 = Popen(args, stdout=PIPE)
p2 = Popen(['mysql', '--skip-column-names'], stdin=p1.stdout, stdout=PIPE)
times = p2.communicate()
try:
	times = times[0]
	times = times.strip()
	times = times.split("\t")
	start = float(times[0])
	end = float(times[1])

except:
	print "error! (probably no data in database for " + inid + ")"
	raise SystemExit(0)

#2. IFs

realend = ""
now = time.time()
if end < now - 60*60*2: #if the last banner was more than 2 hours ago:
	end = end + 60*5
	realend = datetime.fromtimestamp(end).strftime('%Y%m%d%H%M00')

realstart = datetime.fromtimestamp(start).strftime('%Y%m%d%H%M00')

print " to ".join([realstart, realend])
#3. Then find that row in the doc
#Assumes that the ID field is filled out!
cell_list = ws.findall(inid)
rows = []
for cell in cell_list:
	rows.append(cell.row)

#4. write to doc
for row in rows:
	#5! Only if there isn't something there already!
	if(ws.cell(row, start_location).value == None):	
		ws.update_cell(row, start_location, realstart)

	if(ws.cell(row, end_location).value == None):
		ws.update_cell(row, end_location, realend)
