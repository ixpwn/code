#!/bin/bash

dirurl=http://iplane.cs.washington.edu/data/iplane_logs/2010/${1}/${2}/

indexfile=${1}.${2}.html

wget $dirurl -O $indexfile

tracefile=${1}.${2}.traces
grep -o "trace.out.[^\"<>]*" $indexfile | sort | uniq >$tracefile
rm $indexfile

mytracedir=~/tmpdir/${1}.${2}.iplane
mkdir $mytracedir
cat $tracefile | while read line
    do
    wget $dirurl/$line -O $mytracedir/$line 2>/dev/null >/dev/null
    gunzip $mytracedir/$line
done    

alltracefile=~/tmpdir/${1}.${2}.alltraces
for file in $mytracedir/*
    do
    echo $file
    ~/tools/readouttraces $file 0 | sed 's/^[^ ]* [^ ]* [^ ]* [^ ]* //g' >>$alltracefile 
done

rm -r $mytracedir

adjacencydir=~/tmpdir/as_adjacencies/
javac FindBorderRouters.java
java -ea FindBorderRouters origin_as_mapping.txt ip_to_as_mapping.txt $alltracefile | sort -u >>$adjacencydir/${1}.${2}.adjacencies

rm $alltracefile
