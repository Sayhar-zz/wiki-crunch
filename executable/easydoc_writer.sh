#! /usr/bin/env bash
# Find possible tests, then use guessTests to guess them, then they'll be written to outfile.tsv

#start out in executable folder
source lenv/bin/activate &&
#./doc_downloader.sh &&
cd helper &&
echo "querying mysql. (This will take a while)" &&
mysql --skip-column-names < fundraiser_banners.sql  > ../../data/all_bannernames.tsv &&
echo "query done. now running guessTests.py" &&
python guessTests.py &&
rm ../../data/all_bannernames.tsv
#cd ../ #back to executable
#mv outfile.tsv ../output/add_to_easylist.tsv
#echo "look in ../output/add_to_easylist.tsv"
#cd helper
#./docWriter.py
#cd ../ #back to executable
