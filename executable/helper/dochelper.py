#! /usr/bin/env python

#This should be a module, not called directly.
from os.path import commonprefix

def get_test(tid, ws, idcolumn):
	#this only works if imported into something has has gspread set up!
	values_list = ws.col_values(idcolumn)
	indices = [i for i, x in enumerate(values_list) if x == tid]
	keys = ws.row_values(1)
	test = []
	for row in indices:
		values = ws.row_values(row+1)
		test.append(dict(zip(keys, values)))
	return test


def guess_var(testname):
	#find 2nd occurence of "_"
	try:
		title = testname
		index1 = title.find("_") +1
		title = title[index1:]
		index2 = title.find("_") +1
		index = index1 + index2
		var = testname[index:]
	except:
		var = "auto"
	var = "auto" if len(var) == 0 else var
	return var

def findbanners(test):
	#given testdict, return the list of banners in it
	banners = []
	for line in test:
		banners.append(line['Banner'])
	banners = map(str.strip, banners)
	return banners

def findtid(test):
	#given testdict, return the testid or testname
	tid = ""
	for line in test:
		writeid = line["ID"].strip()
		if tid == "":
			tid = writeid
		elif writeid != "":
			tid = writeid
	if tid != "":
		return tid

	#else, ID isn't set, so look it up.
	banners = findbanners(test)
	prefix = commonprefix(banners)
	tid = prefix.strip("_")
	return tid

def findextra(thistest, testname):
	extra = ""
	for line in thistest:
		writeextra = line['Extra SQL']
		if extra == "":
			extra = writeextra
		elif writeextra != "":
			extra = writeextra
	return extra




def manual_time(test, columnname):
	#given a testdict, return the manually entered start or end time
	starts = []
	for line in test:
		starts.append(line[columnname])
	starts = list(set(starts))
	if len(starts) == 1:
		if starts[0] == '' or starts[0] == None:
			return False
		else:
			return starts[0]
	else:
		#if you have multiple start times
		print "ERROR - conflict start times, defaulting to earliest"
		try:
			starts.remove('')
		except:
			pass
		starts.sort()
		return starts[0] #start at the earliest given time

def manual_start(test):
	return manual_time(test, 'Start time')

def manual_end(test):
	return manual_time(test, 'End time')


def readstart(test, testname, trymanual=True):
	#CRUDE
	#given testdict, and testname, guess a startime
	start = False
	if trymanual:
		start = manual_start(test)
	if not start:
		if testname[4:8].isdigit() and testname[0:2] == "B1":
			month = testname[4:6]
			day = testname[6:8]
			year = "20" + testname[1:3]
			start = year + month + day + "000000" #start at the beginning of the day
		else:
			start = "20130101000000" #known time before any test in this form
			print "ERROR - unclear start time, defaulting to " + start
	return start

def readend(test, testname, trymanual=True):
	#CRUDE
	#Just looks at name, and see if it's written in doc
	end = False
	if trymanual:
		end = manual_end(test)
	if not end:
		#if there's not a manual end, just end 1 year later
		start = readstart(test, testname, trymanual=trymanual)
		shortyear = int(start[0:4])
		shortyear += 1
		shortyear = str(shortyear)
		end = shortyear + start[4:]
	return end