#! /usr/bin/env bash
# runs query_and_crunch.sh on all tids
# Assume it starts from executable folder


source lenv/bin/activate &&
./doc_downloader.sh &&
cd helper &&
./easyParse.py &&
alltids=$(./alltids.py) &&
cd .. && #executable
cd .. && #RBOX
rm crunch.errors.txt 2> /dev/null
for var in $alltids 
do
    echo "$var"
    ./query_crunch.sh $var
done

