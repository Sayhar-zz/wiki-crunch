#! /usr/bin/env bash

[ -z $1 ] && echo "need a testid (numerical)"
[ -z $1 ] && exit


#chmod 770 data/easyform.tsv
cd executable &&
source lenv/bin/activate &&
./doc_downloader.sh 2> /dev/null
cd helper &&
./easyParse.py -t $1 --mysql &&
cd .. && #executable 
cd ../output &&
#chmod 770 banners.sql 
#chmod 770 donors.sql 
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
	echo "URL: https://lutetium.wikimedia.org/reports/$var/show.html"
done
