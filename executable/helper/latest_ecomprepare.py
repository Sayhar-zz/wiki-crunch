#! /usr/bin/env python
#find the testid name of the last test in TestForm
import dochelper as helper
import csv
import pdb
from os.path import commonprefix

with open('../../data/latest2.tsv') as infile:
	csvfile = csv.reader(infile, dialect="excel-tab")
	banners = []
	csvfile.next()
	for line in csvfile:
		banners.append(line[0])

	prefix = commonprefix(banners)
	tid = prefix.strip("_")
	start = helper.readstart([], tid, trymanual=False)
	end = helper.readend([], tid, trymanual=False)

print " -s " + start + " -e " + end + " --sub " + tid + " -g b --raw"

#with open('../../data/easyform.tsv','r') as form:
#	csvfile = csv.DictReader(form, dialect="excel-tab")
#	fieldnames = csvfile.fieldnames
#	thistest = []
#	lasttest = []
#	for line in csvfile:
#		if line['Banner'] != '':
#			thistest.append(line)
#		else:
#			lasttest = thistest
#			thistest = []
#	#pdb.set_trace()
#	if(len(thistest) != 0):
#		testid = eparse.findtid(thistest)
#	else:
#		testid = eparse.findtid(lasttest)

#print testid


