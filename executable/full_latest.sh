#! /usr/bin/env bash

#show the results of the latest test.
#assuming you start in the root folder:

./easydoc_writer.sh > /dev/null &&
#./doc_downloader.sh 2> /dev/null &&
cd helper &&
TID=$(cd ../ && source lenv/bin/activate && cd helper && python nth_testid.py -n 1) &&
cd ../../ &&
./easy_crunch.sh $TID
