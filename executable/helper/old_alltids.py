#! /usr/bin/env python
#old_alltids.py
#needs gspread package

import csv
import gspread
import json

config = json.load(open('config.json'))
email = config['email']
password = config['password']
gc = gspread.login(email, password)

TLBVV = "0ArMJ6Soyh6dxdDAtZ0pSZ1UyNzB4OVAwbkJvRnlwVlE"

sh = gc.open_by_key(TLBVV)
ws = sh.get_worksheet(0)
tids = ws.col_values(1)
#delete header
tids = tids[1:]
#dedupe
tids = list(set(tids))
print " ".join(tids)
