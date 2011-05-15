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

    # in a sibling line, asn1 is a "canonical" form; map all asn2 to asn1
    # unless something already maps to asn2
#    elif rel==2:
#        #if asn2 in siblings and not siblings[asn2] == asn1:
#        if asn2 in siblings:
#            # it already maps to something!
#            print "SIB ERROR %d %d" % (asn2, asn1)
#        siblings[asn2] = asn1
#        
#    elif rel==2:
#       try:
#            low = min(asn1,asn2)
#            high = max(asn1,asn2)
#
#
#            if not high in siblings[low]:
#                siblings[high] = siblings[low]
#                siblings[low].append(high)
#        except:
#            siblings[low] = list()
#            siblings[high] = siblings[low]
#            siblings[low].append(high)

for k in replacements:
    print "%d: %s" % (k, str(replacements[k]))

#for k in siblings:
#    print "SIB %d: %s" % (k, str(siblings[k]))

#rev_sibs = dict()
#for k in siblings:
#    print siblings[k]
#    for v in siblings[k]:
#        if v in rev_sibs:
#            raise ValueError
#        rev_sibs[v] = k
#
#for k in rev_sibs:
#    print "SIB %d: %s" % (k, str(rev_sibs[k]))
#

