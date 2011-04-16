#!/bin/bash
mytracedir=~/tmpdir/${1}.${2}.iplane

mkdir $mytracedir

alltracefile=${1}.${2}.alltraces
for file in $mytracedir/*
    do
    echo $file
    readouttraces $file 0 
done

#rm -r $mytracedir

adjacencydir=~/tmpdir/as_adjacencies/
javac FindBorderRouters.java
java -ea FindBorderRouters origin_as_mapping.txt ip_to_as_mapping.txt $alltracefile >>$adjacencydir/${1}.${2}.adjacencies
