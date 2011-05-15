import sys

filename = sys.argv[1]
asrel = open(filename,"r")

'''
If an ASN is the customer of another ASN, we want to replace all the records of
the first ASN with that of the second. The same goes for ASNs that are
siblings. 

For each ASN, we need to build a "replacement list". 

Input file MUST be sorted in increasing order of relationship.  
'''
replacements = dict()

for line in asrel:
    if line.startswith("#"):
        continue

    line = line.rstrip()
    asn1, asn2, rel = line.split()
    asn1 = int(asn1)
    asn2 = int(asn2)
    rel = int(rel)
   
    # asn1 is asn2's provider
    if rel==1:
        if asn1 in replacements:
            del replacements[asn1]

    # if they are peers, these are not stub as's
    elif rel==0:
        if asn1 in replacements:
            del replacements[asn1]
        if asn2 in replacements:
            del replacements[asn2]

    # asn1 is asn2's customer   
    elif rel==-1:
        try:
            replacements[asn1].append(asn2)
        except:
            replacements[asn1] = list()
            replacements[asn1].append(asn2)

for line in sys.stdin:
    line = line.rstrip()
    a,b,c,asn,d,e = line.split()

    asn = int(asn)

    if asn in replacements:
        for provider in replacements[asn]:
            print "%s %s %s %d %s %s" % (a,b,c,provider,d,e)
    else:
        print line
