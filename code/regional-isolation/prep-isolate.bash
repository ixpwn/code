#!/bin/bash

# This script generates the inputs you'll need to run the isolation script.
# This assumes that cluster2ixps.py does the right thing for your input
# format. The output file names seen here are HARD CODED in isolate.py.
# 
# The CLUSTERS file should be one of the .grid "final clusters" files; I have
# been using caida_itdk_adjacencies_and_brice.grid8. The EXTENT file should be
# one of the geoloc-samples-...-.flat.sorted.uniq-cells files. The extent files
# are in the /data/as-extent folder.
CLUSTERS=$1
EXTENT=$2

# create sorted file of number of failure points per ASN
cat $CLUSTERS | python cluster2ixps.py | sort | uniq | cut -f1 -d" " | sort -n | uniq -c | sort -n > fp-per-asn

# sort extent file by ASN
cat $EXTENT | sort -n -k3 -n -k4 > cells.sorted

# create file of each ASN's failure points, sorted in order of ASN
cat $CLUSTERS | python cluster2ixps.py | sort -n > asn-fps
