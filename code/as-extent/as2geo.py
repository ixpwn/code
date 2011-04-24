'''
Given an ASN, this will determine its geographic extent. For now, this means
running a sample of IPs from the AS's advertised prefixes against MaxMind, and
then spitting out a kml that shows the location of each geoloc'd IP address.

TODO: Figure out how to actually represent "geographic extent" in a meaningful
way. Probably bounding polygons with some separation threshold...
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
                        origin_asn = entries[-2].strip('{}').split(',')[0]

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
    def random_ip_from_prefix(prefix):
        prefix,mask = prefix.split("/")
        mask = int(mask)

        prefix = struct.unpack('L',socket.inet_aton(prefix))[0]
        suffix = random.getrandbits(32-mask) << mask
        ip_addr = socket.inet_ntoa(struct.pack('L',prefix+suffix))

        return ip_addr
       

parser = argparse.ArgumentParser(description="Determines the geographic extent of an AS.")
parser.add_argument("-g", "--geodb", help="MaxMind Geolocation DB, uses \
GeoLiteCity.dat in local folder by default")
parser.add_argument("-b", "--bgptable", required=True, help="BGP Table file")
parser.add_argument("-o", "--output", help="kml output file location")
args = parser.parse_args()

if not args.geodb==None:
    geoloc_filename = args.geodb
else:
    geoloc_filename = "GeoLiteCity.dat"
if not args.output==None:
    output_filename = args.output
else:
    output_filename = "output.kml"

bgptable_filename = args.bgptable

print "Reading bgptable... ",
bgp = bgpParse(bgptable_filename)
print "done."

gi = GeoIP.open(geoloc_filename, GeoIP.GEOIP_STANDARD)

sample_size = 0.1

# create a dict of a sample of IP's owned by each ASN
for asn in bgp.bgptable:
    print "%s: %s" % (asn, str(bgp.bgptable[asn]))
