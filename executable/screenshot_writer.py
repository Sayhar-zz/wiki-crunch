#! /usr/bin/env python
# Run on my machine - goes through the google doc and updates the correct images using screengrab.sh


import gspread
import csv
import pdb
import subprocess
import string
import sys
import json
import os


SCREENGRAB = "./screengrab.sh "
config = json.load(open('helper/config.json'))
email = config['email']
password = config['password']
gc = gspread.login(email, password)

w_id = config['w_id']
key = config['key']

sh = gc.open_by_key(key)
ws = sh.get_worksheet(0)


bannercol = int(config['bannercolumn'])
sscol = int(config['screenshotcolumn'])

rows = ws.col_values(bannercol)

for i, banner in enumerate(rows):
	if banner is not None:
		cellvalue = ws.cell(i + 1, sscol).value
		if cellvalue is None: 
			print "cell" + str(i+1) + "," + str(sscol) + "is missing screenshot for " + banner
			os.chdir("helper")
			bashCommand = SCREENGRAB + banner
			process = subprocess.Popen(bashCommand.split(), stdout=subprocess.PIPE)
			output = process.communicate()[0].strip()
			os.chdir('..')
			if output[:7] == "http://":
				screenshotURL = output
				ws.update_cell(i+1, sscol, screenshotURL)
		else:
			print banner + " is matched by " + cellvalue


#feed = gclient.GetCellsFeed(key, w_id)
#width = 0
#screenshotColumn = "Z"
#thisrow = 1
#lastbanner = ""
#row_has_shot = True
#for i, entry in enumerate(feed.entry):
#	title = entry.title.text
	#print title
#	if len(title) == 2 and title[1] == "1":
#		width += 1
#		if entry.content.text == "Screenshot":
#			screenshotColumn = title[0]
#	else:
#		if title[0] == "A":
			#start of a row
#			if not row_has_shot:
#				replacecell = screenshotColumn + str(thisrow)
#				replace_banner_cell = "A" + str(thisrow)
				#lookup the cell in replace_banner_cell, 
				#then run the script to replace the contents of 
				#replacecell with what screengrab.sh gives us
#				print "cell" + replacecell + "is missing screenshot for " + lastbanner
#				os.chdir("helper")
#				bashCommand = SCREENGRAB + lastbanner
#				process = subprocess.Popen(bashCommand.split(), stdout=subprocess.PIPE)
#				output = process.communicate()[0].strip()
#				os.chdir('..')
#				if output[:7] == "http://":
#					screenshotURL = output
#					numcol = string.lowercase.find(screenshotColumn.lower()) +1 
#					gclient.UpdateCell(row=str(thisrow), col=numcol, inputValue=screenshotURL, key=key, wksht_id=w_id)
#				

				
#			thisrow = title[1:]
#			row_has_shot = False
#			lastbanner = entry.content.text
#		if title[0] == screenshotColumn:
#			row_has_shot = True
#			print entry.title.text, entry.content.text
##last row needs to have this called again
#if not row_has_shot:
#	replacecell = screenshotColumn + str(thisrow)
#	replace_banner_cell = "A" + str(thisrow)
#	#lookup the cell in replace_banner_cell, 
	#then run the script to replace the contents of 
	#replacecell with what screengrab.sh gives us
#	print "cell" + replacecell + "is missing screenshot for " + lastbanner
#	os.chdir("helper")
#	bashCommand = SCREENGRAB + lastbanner
#	process = subprocess.Popen(bashCommand.split(), stdout=subprocess.PIPE)
#	output = process.communicate()[0].strip()
#	os.chdir('..')
#	if output[:7] == "http://":
#		screenshotURL = output
#		numcol = string.lowercase.find(screenshotColumn.lower()) +1 
#		gclient.UpdateCell(row=str(thisrow), col=numcol, inputValue=screenshotURL, key=key, wksht_id=w_id)
#		