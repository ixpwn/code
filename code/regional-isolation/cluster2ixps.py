import sys

for line in sys.stdin:
    asn1, asn2, a, b, cell, d, e = line.split()
    print "%s %s" % (asn1, cell)
    print "%s %s" % (asn2, cell)
