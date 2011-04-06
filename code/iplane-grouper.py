import sys
import fileinput

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
        for item in bubba[pop]:
            if item[2] > 180: # fix unknown entries
                #print "fixing %s" % pop
                item[2] = lat
                item[3] = lng
            else:
                if item[2] != lat or item[3] != lng:
                    print "error! mismatch of lat/long! existing: %s, %s new: %s, %s" % (item[0],item[1],ip,pop) 
                    exit()
    except KeyError:
        # we haven't seen this pop before
        bubba[pop] = list()
        bubba[pop].append([ip, pop, lat, lng])

for pop, lines in bubba.iteritems():
    for l in lines:
        print "%s %s %s %s" % (l[0], l[1], l[2], l[3])
        #print l
