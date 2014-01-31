#! /usr/bin/env bash
#Given a bannername:

[ -z $1 ] && echo "need a banner"
[ -z $1 ] && exit

URL=$(echo "http://en.wikipedia.org/wiki/Declaration_of_Rights_of_Man?force=1&banner=$1") &&
#echo $URL &&
cd ../ &&
cd ../output &&
webkit2png --delay=1 -F -o banner -W 1400 -H 800 $URL > /dev/null &&
mv banner-full.png banner.png &&
convert banner.png -crop 1400x170 thumb.png > /dev/null &&
mv thumb-0.png $1.png &&
rm thumb* &&
convert banner.png -crop 1400x500 thumb.png > /dev/null &&
mv thumb-0.png $1-full.png &&
rm thumb* &&
rm banner.png &&
s3cmd del s3://wikitoy/screenshots/$1.png > /dev/null
s3cmd del s3://wikitoy/screenshots/$1-full.png > /dev/null
s3cmd put $1.png s3://wikitoy/screenshots/$1.png --acl-public > /dev/null &&
s3cmd put $1-full.png s3://wikitoy/screenshots/$1-full.png --acl-public > /dev/null &&
S3URL=http://wikitoy.s3.amazonaws.com/screenshots/$1.png  > /dev/null &&
echo $S3URL

cd ../executable &&
cd ./helper


