import sys

try:
    budget = int(sys.argv[1])
except:
    print "usage: python isolate.py <budget>"
    exit()

assert budget > 0, "budget must be greater than 0, ya cheapskate"

fp_by_as = "fp-per-asn"
fp_as = open(fp_by_as,"r")


'''
We read the list of fp's per AS until we reach a line that exceeds our budget.
All the ASNs with fewer than budget interconnects are added to a list of ASNs
under consideration. We keep track of the interconnect cells for each ASN that
matches this criteria.

Once we have this list, we check a sorted list of cell_id's for the asn's that
match our budget. For each cell_id, we build a list of ASN's that serve it. As
soon as we find an ASN that is not in our list of candidate ASNs from the
previous step, we discard that cell_id as being invulnerable (it's served by an
ASN with more interconnects than our budget). Any cells that remain are added
to a list of potentially vulnerable cells.

After this step, we want to determine which cells would need to be cut to
isolate each of the potentially vulnerable cells. For each potentially
vulnerable cell, we check the ASNs that serve it. If the sum of the number of
interconnection points of the ANSs that serve it is less than our budget, the
cell is vulnerable, and we print out the cells that would need to be cut to
isolate it. 
'''

# get the candidate asn's that could be cut for our budget
candidate_asns = list()
for line in fp_as:
    num, asn = line.split()
    num = int(num)
    asn = int(asn)

    if num <= budget:
        candidate_asns.append(asn)
    else:
        fp_as.close()
        break

#print "Found candidate ASNs. There are %d." % (len(candidate_asns))

# determine where the candidate asn's interconnect to other asn's
failure_points = dict()
fp_file = open('asn-fps',"r")
curr_asn = -1
curr_asn_fps = list()
skip = False
for line in fp_file:
    asn, cell = line.split()
    asn = int(asn)
    cell = int(cell)

    if curr_asn < 0:
        curr_asn = asn

    if asn != curr_asn:
        if curr_asn in candidate_asns:
            failure_points[curr_asn] = curr_asn_fps
        curr_asn_fps = list()
        curr_asn = asn
        skip = False

    if not skip and asn in candidate_asns:
        curr_asn_fps.append(cell)
    else:
        skip = True

fp_file.close()

#print "Found failure points for candidate ASNs."

for asn in failure_points:
    assert asn in candidate_asns, "uh oh!"
    assert len(failure_points[asn]) > 0, "too short!"

# determine which cells are potentially vulnerable
cell_filename = "cells.sorted"
cell_file = open(cell_filename, "r")

cells = dict()
curr_cell_asns = list()
curr_cell = -1
invulnerable = False
for line in cell_file:
    a, b, cell, asn = line.split()
    cell = int(cell)
    asn = int(asn)

    if curr_cell < 0:
        curr_cell = cell

    if cell != curr_cell:
        # we found one!
        if not invulnerable:
            cells[curr_cell] = curr_cell_asns
        curr_cell = cell
        curr_cell_asns = list()
        invulnerable = False

    if not invulnerable and asn in candidate_asns:
        curr_cell_asns.append(asn) 
    else:
        invulnerable = True 

cell_file.close()

#print "Identified potentially vulnerable cells."

# for each vulnerable cell, determine if it's actually vulnerable, and print
# out the cells we'd need to cut (and asn's, while we're at it). A cell is
# actually vulnerable if its providers have fewer than budget of *unique*
# interconnect places.
for cell in cells:
    providers = cells[cell]
    fps = reduce(lambda x,y: x+y, [failure_points[i] for i in providers])
    fps = list(set(fps))
    if len(fps) <= budget:
        # this cell could be cut off!!
        print "%d %s %s" % (cell, str(providers), str(fps))
