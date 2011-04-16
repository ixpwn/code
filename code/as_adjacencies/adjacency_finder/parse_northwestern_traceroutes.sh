#!/bin/bash

alltracefile=~/tmpdir/northwestern/traceRouteHops-dropHops-2010-${1}-${2}
bunzip2 $alltracefile.bz2

tmpfile=~/tmpdir/${1}.${2}.northwestern
~/tmpdir/northwestern/convert_northwestern $alltracefile >$tmpfile

adjacencydir=~/tmpdir/as_adjacencies/
javac FindBorderRouters.java
java -ea FindBorderRouters origin_as_mapping.txt ip_to_as_mapping.txt $tmpfile | sort -u >>$adjacencydir/${1}.${2}.adjacencies.northwestern

rm $tmpfile
