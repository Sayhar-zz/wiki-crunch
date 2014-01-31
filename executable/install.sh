#! /usr/bin/env bash

source lenv/bin/activate
cd helper
Rscript install.R
python calendar_helper.py