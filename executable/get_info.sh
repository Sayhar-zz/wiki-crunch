#! /usr/bin/env bash
# Name: get_info.sh

# Given a testid, return to the shell the info string from the google doc

[ -z $1 ] && echo "need a testid"
[ -z $1 ] && exit

source lenv/bin/activate &&
cd helper &&
python get_info.py $1