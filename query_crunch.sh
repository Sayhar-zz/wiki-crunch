#! /usr/bin/env bash

[ -z $1 ] && echo "need a testid "
[ -z $1 ] && exit

cd executable
source lenv/bin/activate &&
echo 'downloading files'
./doc_downloader.sh
echo 'writing SQL'
cd helper
./easyParse.py -t $1 --mysql
echo 'querying db' &&
cd .. &&
cd ../output &&
mysql < banners.sql &&
echo 'banners written' &&
mysql < donors.sql &&
echo 'clicks written' &&
cd ..  &&
#you're at RBOX again
echo 'crunching in R' &&
./crunch.sh $1
