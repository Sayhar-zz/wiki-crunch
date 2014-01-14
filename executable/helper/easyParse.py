#! /usr/bin/env python

#This reads the easyform.tsv file and turns it into test definitions.
assumptions = """

		I ASSUME:

* There is a blank line between every test
* Only banners are tested
* Banners start with B13_, B14_, ...B19_
* After B13_, banners have 4 digits representing month/day, then an underscore
* Banners aren't ever reused
* Banners in the same test have the same prefix
* Banners in the same test have a unique common prefix
* Test starts on the month/day in the banner name
* Tests always last less than a year
"""

import csv
import os
import sqlhelper as sb
import pdb
import argparse
import json
import gspread
from dochelper import *

parser = argparse.ArgumentParser(description="Takes test definitions and outputs SQL at ../output/")
parser.add_argument('-t', metavar='TestID', dest="testid", type=str, help="What is the testid we're looking for?", nargs=1, default="none")
parser.add_argument("-m", "--mysql", help="write statements in the fr_test db, instead of as tsv files",
                    action="store_true")
args = parser.parse_args()
targetid = args.testid
try:
    targetid = targetid[0]
except:
    pass

MYSQL_DB = "fr_test"
MYSQL_BANNERTABLE = "banners"
MYSQL_CLICKTABLE = "clicks"
MYSQL_LANDINGTABLE = "landings"


config = json.load(open('config.json'))
email = config['email']
password = config['password']
key = config['key']
gc = gspread.login(email, password)

ws = gc.open_by_key(key).sheet1
#rows = ws.get_all_values()




#did we actually create new SQL?
toreturn = False


def parseTest(test):
	#Everything up till now is one distinct test
	
	banners = findbanners(thistest)
	testid = findtid(thistest)
	testname = testid
	start = readstart(thistest, testname)
	end = readend(thistest, testname)
	extra = findextra(thistest, testname)
	bannersql, donorsql = composeSQL(testid, start, end, banners, extra)

	dout.write(donorsql  + "\n\n\n")
	bout.write(bannersql + "\n\n\n")



def add_id(test):
	testid = findtid(thistest)
	for line in test:
		if line['ID'] is None or line['ID'] is "":
			line['test_id'] = testid
		else:
			line['test_id'] = line['ID']




def composeSQL(testid, starttime, endtime, banners, extra):
	whereclause = "WHERE \n\t"
	clauselist  =  ["timestamp >= '" + starttime + "' "]
	clauselist.append("timestamp <= '" + endtime + "' ")
	clauselist.append( "banner regexp '(" + "|".join(banners) + ")'")
	if len(extra) > 0:
		clauselist.append(extra.strip().strip("where").strip("WHERE").strip().strip("and").strip("AND").strip())
	
	whereclause += " and \n\t".join(clauselist)
	
	bannersql = sb.banner(testid, testid ,whereclause, starttime)
	donorsql = sb.donor(testid, testid, whereclause, banners, "")
	if args.mysql:
	    bannersql = sb.mysql_prefix(MYSQL_DB, MYSQL_BANNERTABLE, testid) + bannersql
	    donorsql = sb.mysql_prefix(MYSQL_DB, MYSQL_CLICKTABLE, testid) + donorsql
	
	return bannersql, donorsql



with open('../../data/easyform.tsv','r') as form:
	rewrite_tests = []
	with open("../../output/donors.sql", "wb+") as dout:
		with open("../../output/banners.sql", "wb+") as bout:
			#os.chmod(os.path.abspath(form.name), 0o770)
			#os.chmod(os.path.abspath(dout.name), 0o770)
			#os.chmod(os.path.abspath(bout.name), 0o770)
			csvfile = csv.DictReader(form, dialect="excel-tab")
			fieldnames = csvfile.fieldnames
			if 'test_id' not in fieldnames:
				fieldnames.append("test_id")
			thistest = []
			for line in csvfile:
				if line['Banner'] != '':
					thistest.append(line)
				else:
					add_id(thistest)
					testid = findtid(thistest)
					if(targetid == "n" or testid == targetid):
						parseTest(thistest)
						toreturn = True
					#clear for next test
					rewrite_tests.append(thistest)
					thistest = []
			if thistest != []:
				add_id(thistest)
				testid = findtid(thistest)
				if(targetid == "n" or testid == targetid):
					parseTest(thistest)
					toreturn = True
				rewrite_tests.append(thistest)	

with open('../../data/easyform.tsv','w') as form:
	blankline = dict()
	for field in fieldnames:
		blankline[field] = ''
	writer = csv.DictWriter(form, fieldnames, dialect="excel-tab")
	writer.writeheader()
	for test in rewrite_tests:
		for line in test:
			writer.writerow(line)
		writer.writerow(blankline)