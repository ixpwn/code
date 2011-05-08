'''
Given an ASN, this will determine its geographic extent. For now, this means
running a sample of IPs from the AS's advertised prefixes against MaxMind, and
then spitting out a file that shows the location of each geoloc'd IP address in
the following format:

<asn> <lat> <lon> <ip>

TODO: Figure out how to actually represent "geographic extent" in a meaningful
way. Probably bounding polygons with some separation threshold... Maybe output
kml.
'''
import sys
import argparse
import GeoIP

import random
import socket
import struct

# This class provides an AS-to-prefix-list mapping
class bgpParse:
    bgptable = dict()

    # read in the bgp table
    def __init__(self, filename):
        try:
            bgpfile = open(filename,"r")
            for line in bgpfile:
                try:
                    # ignore non-route lines
                    if not line.startswith("*"): continue

                    # only look at the line for an entry that contains a prefix
                    if not "/" in line: continue

                    # at this point we only have lines with prefixes, so we grab the
                    # prefix and final AS number and keep track of them.
                    entries = line.split()
                    prefix = entries[1]
                    try:
                        origin_asn = str(int(entries[-2]))
                    except ValueError:
                        # The second to last entry is in form {N} or {N,M,...}
                        # so we just pick first one as the origin asn.
                        if not "*" in entries[-2]:
                            origin_asn = entries[-2].strip('{}').split(',')[0]
                            int(origin_asn) # should be an integer

                    try:
                        self.bgptable[origin_asn].append(prefix)
                    except KeyError:
                        self.bgptable[origin_asn] = list()
                        self.bgptable[origin_asn].append(prefix)
                except IndexError:
                    # sometimes the input is just funky, ignore it
                    pass
            bgpfile.close()
        except: # 2,343,021
            print "Died!"
            bgpfile.close()

    # returns a random ip address from a prefix
    def _random_ip_from_prefix(self, prefix):
        prefix,mask = prefix.split("/")
        mask = int(mask)

        prefix = struct.unpack('L',socket.inet_aton(prefix))[0]
        suffix = random.getrandbits(32-mask) << mask
        ip_addr = socket.inet_ntoa(struct.pack('L',(prefix+suffix)&0xffffffff))

        return ip_addr

    # the value of ip MUST be in the range of the prefix or else behavior is
    # undefined.
    def _ip_from_prefix(self, prefix,ip):
        prefix,mask = prefix.split("/")
        mask = int(mask)

        prefix = struct.unpack('L',socket.inet_aton(prefix))[0]
        suffix = ip << mask
        ip_addr = socket.inet_ntoa(struct.pack('L',(prefix+suffix)&0xffffffff))

        return ip_addr

    def as_block_size(self, asn):
        asn = str(int(asn)) # should be an integer
        block = self.bgptable[asn]
        block_size = 0
        for prefix in block:
            prefix,mask = prefix.split("/")
            block_size += pow(2,(32-int(mask)))
        return block_size

    def random_ips_from_as(self, asn, sample_ratio, maxsize=100000, pack=False):
        size = self.as_block_size(str(int(asn))) # should be an integer
        block = self.bgptable[asn]

        # always sample at least 1, but never more than maxsize (100k takes ~225 sec)
        if maxsize > 0:
            sample_size = min(int(size * sample_ratio + 1.5), maxsize)
        else:
            sample_size = int(size * sample_ratio + 1.5) 

        sample_nums = random.sample(xrange(0,size), sample_size)
        sample = list()
        for item in sample_nums:
            for prefix in block:
                pre,mask = prefix.split("/")
                if item >= pow(2,int(mask)):
                    # selection is in a different prefix
                    item -= pow(2,int(mask))
                    continue
                else:
                    # selection is in this prefix
                    # We select like this to sample without replacement
                    if pack:
                        sample.append(struct.unpack('L',socket.inet_aton(self._ip_from_prefix(prefix,item)))[0])
                    else:
                        sample.append(self._ip_from_prefix(prefix,item))
                    break
        return sample

# the ip address needs to be in packed form
# rounds to save memory
#err_count = 0
def geoloc_an_ip(ip,be_frugal=True):
    global gi,err_count
    ip_str = socket.inet_ntoa(struct.pack('L',ip&0xffffffff))
    gir = gi.record_by_addr(ip_str)
    try:
        if be_frugal:
            lat = int(gir['latitude']+0.5)
            lon = int(gir['longitude']+0.5)
        else:
            lat = gir['latitude']
            lon = gir['longitude']
    except:
        #err_count += 1
        #print "Error! %d" % (err_count)
        return (None,None,ip)
    return (lat,lon,ip)

# print an ip address (unpack if necessary)
def print_ip(ip):
    try:
        int(ip) # test if it's packed
        return socket.inet_ntoa(struct.pack('L',ip&0xffffffff))
    except:
        return str(ip)

# take a sample of IP's and return the dict.
def do_one_sample(bgp, sample_size, maxsize=100000):
    count = 0
    num_ases = len(bgp.bgptable)
    geoloc_ip_sample = dict()

    print "Sampling IP addresses from %d ASes" % (len(bgp.bgptable))
    for asn in bgp.bgptable:
        count += 1
        #print "(%d of %d) %s: %d" % (count, num_ases, asn, int(bgp.as_block_size(asn)))
        rand_ips = bgp.random_ips_from_as(asn,sample_size,maxsize=maxsize,pack=True)
        geoloc_ip_sample[asn] = [geoloc_an_ip(x) for x in rand_ips]
    print "Done!"

    return geoloc_ip_sample

def do_print(geoloc_ip_sample, output_filename): 
    print "Writing sample to output file...",
    try:
        outfile = open(output_filename, 'a')
        for asn in geoloc_ip_sample:
            for mark in geoloc_ip_sample[asn]:
                output_str = "%s %s %s %s\n" % (str(asn), str(mark[0]), str(mark[1]), print_ip(mark[2]))
                outfile.write(output_str)
        outfile.close()
        print "Done!"
    except:
        print "Error generating output!"
        outfile.close()
        raise

# This prints the geoloc'd results for each AS as it computes them. This works
# fine if your sample size is relatively small. For very small samples, you
# should hold the sample in memory and then print it after it has been fully
# calculated.
def do_sample_and_print(bgp, sample_size, output_filename, maxsize=-1):
    count = 0
    num_ases = len(bgp.bgptable)
    try:
        outfile = open(output_filename, 'a')
        for asn in bgp.bgptable:
            count += 1
            print "(%d of %d) %s: %d" % (count, num_ases, asn, int(bgp.as_block_size(asn)))
            rand_ips = bgp.random_ips_from_as(asn,sample_size,maxsize=maxsize,pack=True)
            geoloc_ip_sample = [geoloc_an_ip(x,False) for x in rand_ips]
            for mark in geoloc_ip_sample:
                output_str = "%s %s %s %s\n" % (str(asn), str(mark[0]), str(mark[1]), print_ip(mark[2]))
                outfile.write(output_str)

        outfile.close()
        print "Done!"
    except:
        print "Error generating output!"
        outfile.close()
        raise

# This is my solution to taking very large samples where even a single AS's
# samples won't easily fit in memory. We basically select a "target" sample and
# repeatedly sample smaller ones. This is pretty much the only way to take
# samples of very large percentages of the IP addresses. If you just want to
# sample 10-20% it's probably faster to use sample_and_print.
def do_multiple_sampling(bgp, tot_sample_size, incr_sample_size, output_filename):
    cumulative_sample = 0
    while cumulative_sample < tot_sample_size:
        sample = do_one_sample(bgp,incr_sample_size)
        do_print(sample,output_filename)
        cumulative_sample += incr_sample_size

parser = argparse.ArgumentParser(description="Determines the geographic extent of an AS.")
parser.add_argument("-g", "--geodb", help="MaxMind Geolocation DB, uses \
GeoLiteCity.dat in local folder by default")
parser.add_argument("-b", "--bgptable", required=True, help="BGP Table file")
parser.add_argument("-o", "--output", help="output file location")
parser.add_argument("-s", "--sample_size", help="Percent of addresses to sample (default: 0.05)")
#parser.add_argument("-m", "--max_sample", help="Maximum number of addresses to sample from an AS")
args = parser.parse_args()

if not args.geodb==None:
    geoloc_filename = args.geodb
else:
    geoloc_filename = "GeoLiteCity.dat"
if not args.output==None:
    output_filename = args.output
else:
    output_filename = "output.txt"
if not args.sample_size==None:
    try:
        sample_size = float(args.sample_size)
    except:
        sample_size = 0.05
else:
    sample_size = 0.05

bgptable_filename = args.bgptable

print "Reading bgptable... ",
bgp = bgpParse(bgptable_filename)
print "done."

gi = GeoIP.open(geoloc_filename, GeoIP.GEOIP_STANDARD)


# create a dict of a sample of IP's owned by each ASN
if sample_size < 0.005:
    sample = do_one_sample(bgp, sample_size)
    do_print(sample, output_filename)
elif sample_size < 0.4:
    do_sample_and_print(bgp, sample_size, output_filename)
else:
    do_multiple_sampling(bgp, sample_size, 0.005, output_filename)
#count = 0
#num_ases = len(bgp.bgptable)
#print "Sampling IP addresses from %d ASes" % (len(bgp.bgptable))
#try:
#    outfile = open(output_filename, 'w')
#    for asn in bgp.bgptable:
#        count += 1
#        print "(%d of %d) %s: %d" % (count, num_ases, asn, int(bgp.as_block_size(asn)))
#        rand_ips = bgp.random_ips_from_as(asn,sample_size,pack=True)
#        geoloc_ip_sample[asn] = [geoloc_an_ip(x) for x in rand_ips]
#        for mark in geoloc_ip_sample[asn]:
#            output_str = "%s %s %s %s\n" % (str(asn), str(mark[0]), str(mark[1]), print_ip(mark[2]))
#            outfile.write(output_str)
#
#    outfile.close()
#    print "Done!"
#except:
#    print "Error generating output!"
#    outfile.close()
