#!/usr/bin/env python

import argparse
import os.path 
import csv
from glob import glob
import pdb
import re

parser = argparse.ArgumentParser(description="Turns the txt and png output of AllReports.R into an html file")
parser.add_argument('-p', metavar='Path', dest="path", type=str, help="Which is the path to turn .txt report into into html?", nargs=1)
parser.add_argument('-t', metavar='Title', dest="title", type=str, help="What is the title of this test?", nargs=1, default="")
parser.add_argument('-r', action='store_true', help="Should we make the html more portable? ", default=False)
parser.add_argument('-n', metavar='Name', dest="name", type=str, help="What is the official testname?  AKA what is the name of the dir that the pngs are in?", nargs=1, default="")


#parser.add_argument('-w', action='store_true')

args = parser.parse_args()
tables = []
testdir = args.path[0]




reportpaths = glob(os.path.join(os.path.expanduser(testdir), 'report*.html'))
reportpaths.sort()
for path in reportpaths:
    tmp = open(path,'r')
    tables.append("<div class='diagnostic-table'>"+tmp.read()+"</div>")
    tmp.close()

diagnosticpaths2 = glob(os.path.join(os.path.expanduser(testdir), 'diagnostic*.html'))
diagnosticpaths2.sort()
for path in diagnosticpaths2:
    tmp = open(path, "r")
    tables.append(tmp.read())
    tmp.close()

tables = "<br />".join(tables)
screenshots = open(os.path.expanduser(args.path[0]) + '/screenshots.csv', 'r')

screenshotHTMLs = []
reader = csv.reader(screenshots)
reader.next() #skip header
for row in reader:
    var = row[1]
    link = row[3]
    if(link != 'NA'):
        img = "<h3>" + var + "</h3><br \><img src=" + link + ' style="' + """ 
        margin-right: auto;
        margin-left: auto;
        width: 90%;
        display: block;
    """ + '">'
        screenshotHTMLs.append(img)

diagnosticHTMLs = []
diagnosticpaths = glob(os.path.join(os.path.expanduser(testdir), 'diagnostic*.jpeg'))
diagnosticpaths.sort()
for path in diagnosticpaths:
    img = '<h2>'+ os.path.basename(path) + '</h2><br/>'+ '<img src="' + os.path.basename(path) + '" style="' +""" margin-right: auto;
        margin-left: auto;
        width: 90%;
        """ + '"> </img>'
    diagnosticHTMLs.append(img)



htmltop = """<!DOCTYPE html>
<html>
 <head>
 <link href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css" rel="stylesheet">
 <script src="//netdna.bootstrapcdn.com/bootstrap/3.0.2/js/bootstrap.min.js"></script>
 <style>
 
 </style>
  <meta charset="UTF-8">
  <title>""" + args.title[0] +  """
  </title>
 </head>
 <body>


"""

pamplona = """<img src='./pamplona.jpeg' style="
    margin-right: auto;
    margin-left: auto;
    width: 90%;
" \>"""

htmlbottom = """ 

<br \>
<img src='./bannerviews.jpeg' style="
    margin-right: auto;
    margin-left: auto;
    width: 90%;
"\>
<br \>

 
 </body>
</html>"""


shots = "<br \><br \>".join(screenshotHTMLs)
diagnostics = "<br \><br \>".join(diagnosticHTMLs)

if(args.r):
    htmlbottom = re.sub(r"\'(.+)jpeg", r"'ARGSPATH\1jpeg", htmlbottom)
    htmlbottom = htmlbottom.replace("ARGSPATH", "../" + args.name[0] + '/')
    diagnostics = re.sub(r'src=\"(.+)jpeg', r'src="ARGSPATH\1jpeg', diagnostics)
    diagnostics = diagnostics.replace("ARGSPATH", "../" + args.name[0] + '/')

    pamplona = re.sub(r"src=\'(.+)jpeg", r"src='ARGSPATH\1jpeg", pamplona)
    pamplona = pamplona.replace("ARGSPATH", "../" + args.name[0] + '/')
    #re.sub('.+\.jpeg', '\.\./' + args.name[0] + '\1', htmlbottom)
    #htmlbottom = htmlbottom.replace("./bannerviews.jpeg", "../" + args.name[0] + "/bannerviews.jpeg").replace('./pamplona.jpeg', "../" + args.name[0] + '/pamplona.jpeg')

re.sub(r"\'(.+)jpeg", "HELLO", diagnostics)

print(htmltop  + tables+ pamplona + shots+ diagnostics +  htmlbottom )