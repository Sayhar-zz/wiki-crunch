#! /usr/bin/env bash

[ -z $1 ] && echo "need a testid"
[ -z $1 ] && exit



cd executable &&
source lenv/bin/activate &&
echo 'downloading files'
./doc_downloader.sh && 
echo 'writing SQL' &&
cd helper &&
./easyParse.py -t $1 --mysql &&
cd .. && #executable 
cd ../output &&
echo 'querying db' &&
mysql < banners.sql &&
mysql < donors.sql &&
cd ..  &&
#you're at RBOX again
./crunch.sh $1 > /dev/null || ( echo "ERROR CRUNCHING TEST" && exit 1 ) &&
cat report/$1*/ecom.tsv
testnames=$(ls report | grep $1)
#for var in $testnames
#do
#	echo "Created folder $var"
#done
for var in $testnames; 
do
    echo "URL: https://reports.frdev.wikimedia.org/reports/$var/show.html"
done
