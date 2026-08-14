#!/bin/sh
date +%s > /traces/blocking-start.txt
sleep 2
date +%s > /traces/blocking-end.txt
exit 0
