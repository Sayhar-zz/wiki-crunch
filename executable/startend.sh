#! /usr/bin/env bash

# Name: startend.sh
# Given tid

[ -z $1 ] && echo "need a testid"
[ -z $1 ] && exit

source lenv/bin/activate &&
cd helper &&
python write_startend.py $1