#! /usr/bin/env python

# Name: any_ecomprepare.py
# Given a testid, return the string you need for ecom

import dochelper as helper
import csv
import sys
from os.path import commonprefix
import gspread
import json

config = json.load(open('config.json'))
idcolumn = int(config['idcolumn'])
tid = str(sys.argv[1])

email = config['email']
password = config['password']
key = config['key']
gc = gspread.login(email, password)

ws = gc.open_by_key(key).sheet1

test = helper.get_test(tid, ws, idcolumn)

start = helper.readstart(test, tid, trymanual=True)
end = helper.readend(test, tid, trymanual=True)

banners = helper.findbanners(test)

prefix = commonprefix(banners)
prefix = prefix.strip("_")

print " -s " + start + " -e " + end + " --sub " + prefix + " -g b --raw"