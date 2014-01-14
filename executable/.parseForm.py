#!/usr/bin/env python

#Sahar Massachi for wikimedia
#GPL3
#April 23 - May 20, 2013

#Given 
#   1. the downloaded google doc with tests to run reports for
#   2. the downloaded TBBV file
#   3. the downloaded screenshot file 
#Output: 
#   A. SQL queries for banners, landing, and donors (*.sql)
#   B. Rows to append to the TBBV google doc that serve as a basis for editing (addTBV.tsv)
#   C. additional empty rows for the screenshot file
import csv
import sqlhelper as sb
import time
import sys
import calendar
import re
import os
import pdb   #pdb.set_trace()
import argparse

parser = argparse.ArgumentParser(description="Takes test definitions and outputs edits to other files to ../output")
parser.add_argument('-t', metavar='TestID', dest="testid", type=int, help="What is the testid we're looking for?", nargs=1, default=-1)
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

toreturn = False

with open(os.path.expanduser("../data/testForm.tsv"), "rb") as tsv:
    with open("../output/banners.sql", "wb+") as bout:
        with open("../output/donors.sql", "wb+") as dout:
            with open("../output/landing.sql", 'wb+') as lout:
                with open('../output/addTBBV.tsv', 'wb+') as tout:
                    with open(os.path.expanduser("../data/TLBVVCL.tsv"), "rb") as tin:
                        with open(os.path.expanduser("../data/screenshots.tsv"), "rb") as sin: 
                            with open('../output/addshots.tsv', 'wb+') as sout:
                                tinreader = csv.reader(tin, dialect="excel-tab")
                                sinreader = csv.reader(sin, dialect="excel-tab")
                                tinreader.next()#skip header
                                sinreader.next()
                                lines = list(tinreader)
                                ziplines = zip(*lines)
                                tinAlreadyWritten = ziplines[0]
                                tin.close()
                                
                                lines = list(sinreader)
                                ziplines = zip(*lines)
                                sinAlreadyWritten = ziplines[0]
                                sin.close()
                                
                                reader = csv.reader(tsv, dialect="excel-tab")
                                TBBVwriter = csv.writer(tout, dialect='excel-tab')
                                screenWriter = csv.writer(sout, dialect='excel-tab')
                                
                                reader.next() #skipping header
                                for line in reader:
                                    if(line[0] == ''):
                                        #print "SKIP blank line"
                                        continue #aka skip this iteration.
                                
                                    testid = calendar.timegm(time.strptime(line[0], "%m/%d/%Y %H:%M:%S")) #The time it was imputted to the google form. I figure this is unique and not very changeable.
                                    if(str(targetid) != "-1" and str(testid) != str(targetid)):
                                        #print 'testid   = ' + str(testid)
                                        #print 'targetid = ' + str(targetid) 
                                        continue #aka only do the targetid if given
                                    thisclause = [] 
                                    #the components of the where clause
                                    tc = "WHERE \n\t"
                                    #tc = "Top of clause"
                                    comment = ""
                                    bannernames = []
                                    campaignnames = []
                                    landingnames = []
                                    landingregexp = ""
                                    testname = ""
                                    starttime = ""


                                    #need to single out banner and campaign names because we need them to auto-generate a test-name
                                    if(line[1]):
                                        #comment : calendar name
                                        comment = "-- " + line[1] + "\n"

                                    if(line[2]):
                                        #testname: what we want to call the test from now on. blank for now.
                                        testname = str(line[2]).replace("'","").replace('"','')

                                    if(line[3]):
                                        #timestamp >=
                                        thisclause.append("timestamp >= '" + line[3] + "'")
                                        starttime = line[3]
                                    if(line[4]):
                                        #timestamp <=
                                        thisclause.append("timestamp <= '" + line[4] + "'")
                                        if(starttime == ""):
                                            starttime = line[4]

                                    #NOTE how landing is different than how banner is treated. This is because landing data shows up in donors (and linadingpageimpression, of course), but NOT in banner at all. 
                                    if(line[5]):
                                        if(line[5].find('|') > 0):
                                            landingnames.extend(line[5].strip("'").strip('"').strip('(').strip(')').strip("'").strip('"').split("|"))
                                        else:
                                            landingnames.append(line[5])
                                    if(line[6]):
                                        if(line[6].find('|') > 0):
                                            landingnames.extend(line[6].strip("'").strip('"').strip('(').strip(')').strip("'").strip('"').split("|"))
                                        else:
                                            landingnames.append(line[6])

                                    if(line[7]):
                                        if(line[7].find('|') > 0):
                                            bannernames.extend(line[7].strip("'").strip('"').strip('(').strip(')').strip("'").strip('"').split("|"))
                                        else:
                                            bannernames.append(line[7])
                                    if(line[8]):
                                       if(line[8].find('|') > 0):
                                           bannernames.extend(line[8].strip("'").strip('"').strip('(').strip(')').strip("'").strip('"').split("|"))
                                       else:
                                           bannernames.append(line[8])
                                    if(line[9]):
                                        #campaign
                                        thisclause.append("campaign regexp '"  + line[9]+ "'")
                                        campaignnames.append(line[9])
                                    
                                    #Putting this here because we don't want the banners in line[10] to join bannerclause (because they'll already be added to tc)
                                    bannernames = map(str.strip, bannernames)
                                    bannerclause = "banner regexp '(" + "$|".join(bannernames) + "$)'"
                                    thisclause.append(bannerclause)
                                    
                                    if(line[10]):
                                        #This is the OTHER clause AKA additional sql
                                        l10 = line[10].strip().strip("where").strip("WHERE").strip().strip("and").strip("AND").strip()
                                        thisclause.append(l10)
                                        m = re.search("banner regexp .*?($| and)", l10)
                                        if(m):
                                            m = m.group(0)
                                            m = m.strip("banner regexp ").strip(" and").strip("'").strip('"').strip(")").strip("(")
                                            m = m.split("|")
                                            bannernames.extend(map(str.strip, m))

                                    tc += " and \n\t".join(thisclause)
                                    landingnames = map(str.strip, landingnames)
                                    landingregexp = "'(" + "$|".join(landingnames) + "$)'"
                                    
                                   
                                    
                                    if(testname == ""):
                                        testname = "".join(campaignnames)
                                        testname += "__" + "__vs__".join(bannernames)
                                    #testname is <campaign name(s)>__<the similarity in banner names>


                                    bannersql = comment + sb.banner(testid, testname ,tc, starttime)
                                    donorsql = comment + sb.donor(testid, testname, tc, bannernames, landingregexp)
                                    landingsql = comment + sb.landing(testid, testname, tc, landingregexp, bannernames, starttime)
                                    if args.mysql:
                                        bannersql = sb.mysql_prefix(MYSQL_DB, MYSQL_BANNERTABLE, testid) + bannersql
                                        donorsql = sb.mysql_prefix(MYSQL_DB, MYSQL_CLICKTABLE, testid) + donorsql
                                        landingsql = sb.mysql_prefix(MYSQL_DB, MYSQL_LANDINGTABLE, testid) + landingsql
                                        
                                    
                                    if(targetid != -1 and testid == targetid):
                                        
                                        bout = open("../output/tmpBanner.sql", "wb+")
                                        dout = open("../output/tmpClick.sql", "wb+")
                                        lout = open("../output/tmpLanding.sql", "wb+")            

                                        #bout2.write(bannersql + "\n\n\n")
                                        #dout2.write(donorsql + "\n\n\n")
                                        #lout2.write(landingsql + "\n\n\n")

                                        #bout2.close()
                                        #dout2.close()
                                        #lout2.close()
                                    #else:
                                    bout.write(bannersql + "\n\n\n")
                                    dout.write(donorsql + "\n\n\n")
                                    lout.write(landingsql + "\n\n\n")
                                    toreturn = True
                                    if(str(testid) not in tinAlreadyWritten):
                                        if(len(bannernames) > 1):
                                            for b in bannernames: 
                                                TBBVwriter.writerow([testid, b, '', 'banner', b])
                                        if(len(landingnames) > 1):
                                            for l in landingnames:
                                                TBBVwriter.writerow([testid, '', l, 'landing', l])

                                    
                                    if(str(testid) not in sinAlreadyWritten):

                                        if(len(campaignnames) == 1):
                                            c = campaignnames[0]
                                        else:
                                            c = ''
                                            
                                        if(len(bannernames) > 1):
                                            for b in bannernames:
                                                screenWriter.writerow([testid, b, c, ''])
                                        if(len(landingnames) > 1):
                                            for l in landingnames:
                                                screenWriter.writerow([testid, l, c, ''])
                
tsv.close()
bout.close()
dout.close()
lout.close()
sout.close()

if(toreturn == False):
    sys.exit(1)
