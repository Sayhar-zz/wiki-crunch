#! /usr/bin/env python
# This is alltids.py
#Take in google doc and return a list of testids
import csv

with open('../../data/TLBVVCL.tsv', 'rb') as csvfile:
	unduped_list = []
	reader = csv.DictReader(csvfile, dialect="excel-tab")
	for line in reader:
		tid = line['test_id']
		if tid is not None and tid not in unduped_list:
			unduped_list.append(tid)

print " ".join(unduped_list)