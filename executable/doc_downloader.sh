#! /usr/bin/env bash
#google cl download script

source lenv/bin/activate
google docs get "Test - Banner - Variable - Value" ../data/TLBVVCL --format tsv -u fr.test.sandbox@gmail.com
google docs get "Screenshot table" ../data/screenshots --format tsv -u fr.test.sandbox@gmail.com
google docs get "Test Definitions" ../data/testForm --format tsv -u fr.test.sandbox@gmail.com
#google docs get "easy test definitions" ../data/easyform --format tsv -u fr.test.sandbox@gmail.com