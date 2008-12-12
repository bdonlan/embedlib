#!/bin/sh

ulimit -c 0
echo "Note: This demo assumes you're on x86_64..."
perl ../../embedlib.pl --templatedir ../.. --static --o libnullsub.a --header nullsub.h null-sub.x64
gcc -o nullsub-test crashme.c -L. -I. -lnullsub
./nullsub-test || echo "Test successful! (probably)"
