#! /usr/bin/env python
# Run on my machine - goes through the google doc and updates the correct images using screengrab.sh

from gdata.spreadsheet.service import SpreadsheetsService
from gdata.spreadsheet.text_db import Record
import csv
import pdb
import subprocess
import string
import sys
import json
import os


config = json.load(open('helper/config.json'))

SCREENGRAB = "./screengrab.sh "
#setup
gclient = SpreadsheetsService()
gclient.email = config['email']
gclient.password = config['password']
gclient.ProgrammaticLogin()
w_id = config['w_id']
key = config['key']

feed = gclient.GetCellsFeed(key, w_id)
width = 0
screenshotColumn = "Z"
thisrow = 1
lastbanner = ""
row_has_shot = True
for i, entry in enumerate(feed.entry):
	title = entry.title.text
	#print title
	if len(title) == 2 and title[1] == "1":
		width += 1
		if entry.content.text == "Screenshot":
			screenshotColumn = title[0]
	else:
		if title[0] == "A":
			#start of a row
			if not row_has_shot:
				replacecell = screenshotColumn + str(thisrow)
				replace_banner_cell = "A" + str(thisrow)
				#lookup the cell in replace_banner_cell, 
				#then run the script to replace the contents of 
				#replacecell with what screengrab.sh gives us
				print "cell" + replacecell + "is missing screenshot for " + lastbanner
				os.chdir("helper")
				bashCommand = SCREENGRAB + lastbanner
				process = subprocess.Popen(bashCommand.split(), stdout=subprocess.PIPE)
				output = process.communicate()[0].strip()
				os.chdir('..')
				if output[:7] == "http://":
					screenshotURL = output
					numcol = string.lowercase.find(screenshotColumn.lower()) +1 
					gclient.UpdateCell(row=str(thisrow), col=numcol, inputValue=screenshotURL, key=key, wksht_id=w_id)
				

				
			thisrow = title[1:]
			row_has_shot = False
			lastbanner = entry.content.text
		if title[0] == screenshotColumn:
			row_has_shot = True
			print entry.title.text, entry.content.text
#last row needs to have this called again
if not row_has_shot:
	replacecell = screenshotColumn + str(thisrow)
	replace_banner_cell = "A" + str(thisrow)
	#lookup the cell in replace_banner_cell, 
	#then run the script to replace the contents of 
	#replacecell with what screengrab.sh gives us
	print "cell" + replacecell + "is missing screenshot for " + lastbanner
	os.chdir("helper")
	bashCommand = SCREENGRAB + lastbanner
	process = subprocess.Popen(bashCommand.split(), stdout=subprocess.PIPE)
	output = process.communicate()[0].strip()
	os.chdir('..')
	if output[:7] == "http://":
		screenshotURL = output
		numcol = string.lowercase.find(screenshotColumn.lower()) +1 
		gclient.UpdateCell(row=str(thisrow), col=numcol, inputValue=screenshotURL, key=key, wksht_id=w_id)
		

	
