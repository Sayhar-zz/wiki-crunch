#! /usr/bin/env bash
# Name: to_cal.sh
# Takes in testid, writes it to calendar

#NOTE: This does not work for old tests!:

[ -z $1 ] && echo "need a testid"
[ -z $1 ] && exit

source lenv/bin/activate &&
cd helper &&
python calendar_writer.py $1
