import csv
from os.path import commonprefix
import pdb
import gspread
import json
from dochelper import *

config = json.load(open('config.json'))
email = config['email']
password = config['password']
key = config['key']
gc = gspread.login(email, password)

ws = gc.open_by_key(key).sheet1



#given easyform, and given all_bannernames, match up bannernames (except those already in easyform)

#Write headers to outfile:
#with open('../outfile.tsv', 'w') as f:
#	row = ["banner" , "variable", "description", "screenshot", "extrascreenshot", "starttime", "endtime", "extrainfo"]
#	writer = csv.writer(f, dialect="excel-tab")
#	writer.writerow(row)

def matches(name, amount, latestname, latestamnt, thistestname, thistest):
	
	low = int(latestamnt) * .9
	high = int(latestamnt) * 1.1
	if amount > low and amount < high and len(commonprefix([thistestname, name])) > 8:
		return(True)
	else:
		#This is where *intelligence*. AKA kludges, go
		low = 2 * low
		high = 2 * high
		if amount > low and amount < high and name.find('_alt_') > 0 and latestname.find('_alt_') > 0:
			#see if it has _alt_ in the title
			return True
		low = low / 4
		high = high / 4
		if amount > low and amount < high and name.find('_alt_') > 0 and latestname.find('_alt_') > 0:
			#see if it has _alt_ in the title
			return True
	return False	

def write_to_file(testname, test):
	#actually write to cloud
	
	def find_val(bannername, testname, varname):
		if(bannername[-5] == "_"):
			bannername = bannername[0:-5]

		if(testname == "auto"):
			i = bannername.rfind("_") + 1
			possible = bannername[i:]
		else:
			possible = bannername[bannername.find(varname) + len(varname):].strip("_")
		return possible

	#with open('../outfile.tsv', 'a') as outfile:
		#writer = csv.writer(outfile, dialect="excel-tab")
	
	var = guess_var(testname)
	for line in test:
		name = line[0]
		val = find_val(name, testname, var)
		row = [name, var, val, "", "", "", "","", testname]
		#writer.writerow(row)
		print "appending! " + name
		ws.append_row(row)
	ws.append_row(['','',''])

def skipthis(testname):
	form = ws.get_all_values()
	#alreadywritten = open('../../data/easyform.tsv', 'r')
	skipthese = []
	#ardr = csv.reader(alreadywritten, dialect='excel-tab')
	#for line in ardr:
	for line in form:
		skipthese.append(line[0])
	#alreadywritten.close()
	#*INTELLIGENCE*	
	skipthese.append('B13_120502_bkup1_enYY')
	skipthese.append('B13_120502_bkup2_enYY')
	#/intelligence

	skipthese = list(set(skipthese))
	if "" in skipthese:
		skipthese.remove("")


	if testname in skipthese:
		return True
	if "_survey_" in testname:
		return True
	if "Blank" in testname:
		return True
	if "_WMDE_" in testname:
		return True
	if "B13_0701_" in testname:
		return True #*TEMPORARY*

	return False


f = open('../../data/all_bannernames.tsv','r')
reader = csv.reader(f, dialect='excel-tab')

testdict = {}
test_order = []
orphans = []
thistest = list()
latestname = ""
latestamnt = 0
thistestname = ""
for line in reader:
	name = line[0]
	amount = int(line[1])
	if skipthis(name):
		print "skipping " + name
		continue
	#if first line, set latest to this
	#if it matches the previous one, then append to thistest
	#if it doesn't match the previous one, maybe it does according to *intelligence*
	#if it really doesn't match the previous one 
		#then take everything before this and send to orphan or testdict
	if latestname == "":
		#if it's the first in the file
		thistestname = name
		thistest = [line]
		latestname = name
		latestamnt = amount
	else:
		#NORMALLY: 
		#IF it matches the previous one:
		if matches(name, amount, latestname, latestamnt, thistestname, thistest):
			#if they at least match B13_XXXX	
			print 'its a match'
			thistestname = commonprefix([thistestname, name])
			thistest.append(line)
		else:

		#IF they're not a match
			if len(thistest) == 0:
				print "ERROR THIS SHOULD NEVER HAPPEN"
			elif len(thistest) == 1:
			#EITHER send the orphan to orphans
				orphans.append(thistest)
				thistest = [line]
				latestname = name
				latestamnt = amount
				thistestname = name
			else:
			#OR send the previous good test to testdict
				thistestname = thistestname.strip("_")
				testdict[thistestname] = thistest
				test_order.append(thistestname)
				latestname = name
				latestamnt = amount
				thistestname = name
				thistest = [line]
	latestname = name
	latestamnt = amount

if len(thistest) == 0:
	print "No new tests to upload"
elif len(thistest) == 1:
#EITHER send the orphan to orphans
	orphans.append(thistest)
else:
#OR send the previous good test to testdict
	thistestname = thistestname.strip("_")
	testdict[thistestname] = thistest
	test_order.append(thistestname)
	latestname = name
	latestamnt = amount
	thistestname = name
	thistest = list()
#print "testdict"

for test in test_order:
	print test
	write_to_file(test, testdict[test])




#write_to_file(testdict)

print "\n\n" + str(len(orphans)) + " orphans. (Add these manually)"
with open("../../output/orphans.txt","w") as orphanfile:
	for o in orphans:
		print o
		orphanfile.write(str(o[0]))
		orphanfile.write("\n")
	
#f.close()
