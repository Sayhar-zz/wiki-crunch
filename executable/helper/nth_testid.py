#! /usr/bin/env python
# Show the nth test in the google doc


import json
import gspread
import pdb 
from os.path import commonprefix
import argparse

parser = argparse.ArgumentParser(description="Finds the Nth latest testid")
parser.add_argument('-n', dest="n", type=int, help="How far back should we look? (1 = latest)",  default=1)

nth = parser.parse_args().n

config = json.load(open('config.json'))

email = config['email']
password = config['password']
key = config['key']

gc = gspread.login(email, password)
wks = gc.open_by_key(key).sheet1

rows = wks.get_all_values()
rows.append(['',''])
rows.reverse()

#pdb.set_trace()

i = 1
test = []
collect = False
for row in rows:
	if row[0] == '':
		if i == nth:
			collect = True
			i += 1
		elif i > nth:
			break
		else:
			i += 1
	else:
		if collect:
			test.append(row)

banners = [x[0] for x in test]
print commonprefix(banners).strip("_")




