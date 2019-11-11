#!/bin/bash
lsof -n / | grep sess_ | awk '{print $9} END { if (!NR) print "0" }' | sort | uniq -c  | sort -nr
