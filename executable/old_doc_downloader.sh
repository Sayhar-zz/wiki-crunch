#! /usr/bin/env bash
#google cl download script

source venv/bin/activate 2> /dev/null
#google docs get "Test - Banner - Variable - Value" ../data/TLBVVCL --format tsv -u fr.test.sandbox@gmail.com
#google docs get "Screenshot table" ../data/screenshots --format tsv -u fr.test.sandbox@gmail.com
#google docs get "Test Definitions" ../data/testForm --format tsv -u fr.test.sandbox@gmail.com
google docs get "easy test definitions" ../data/easyform --format tsv -u fr.test.sandbox@gmail.com
