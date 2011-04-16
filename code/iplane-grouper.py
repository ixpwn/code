import sys
import fileinput

''' 
This script runs through the ip_to_pop_with_latlons.txt file from iPlane and
tries to fill in missing location entries by checking to see if there are any
IPs in the same POP for which we already know the location (i.e., if we don't
know A's location, but it's in the same POP as some address B for which we know
the location, we can set A's location to that of B).

It also checks to see if we have conflicting locations for a particular POP
(which would be "bad").
'''

bubba = {} # a queensland grouper famous as the first fish to undergo chemo

def fix_single_pop(item, lat, lng):
    if item[2] > 180: # fix unknown entries
        #print "fixing %s" % pop
        item[2] = lat
        item[3] = lng
    else:
        if item[2] != lat or item[3] != lng:
            print "error! mismatch of lat/long! existing: %s, %s new: %s, %s" % (item[0],item[1],ip,pop) 
            exit()

for line in fileinput.input():
    entries = line.rstrip().split(' ')
    if not len(entries) == 4:
        continue
    ip, pop, lat, lng = entries

    try:
        # make sure all of bubba[pop] has same lat/long
        bubba[pop].append([ip, pop, lat, lng])
        if not lat > 180 and not lng > 180:
            map(lambda x: fix_single_pop(x, lat, lng), bubba[pop])
    except KeyError:
        # we haven't seen this pop before
        bubba[pop] = list()
        bubba[pop].append([ip, pop, lat, lng])

for pop, lines in bubba.iteritems():
    for l in lines:
        print "%s %s %s %s" % (l[0], l[1], l[2], l[3])
        #print l
