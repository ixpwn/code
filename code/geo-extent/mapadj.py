'''
We want to read an adjacency file in the format:

as1 as2 lat lon

We want to do the following queries:

    - Given ASN, get faces that contain it (lat/lons)
    - Given ASN, get adjacencies
    - Given adjacency, get faces

'''
import sys
import isea
import off

class Adjacency:
    def __init__(self, as1, as2):
        # lower is always as1
        a1 = min(int(as1),int(as2))
        if a1 == as1:
            a2 = as2
        else:
            a2 = as1

        self.as1 = str(int(a1))
        self.as2 = str(int(a2))
        assert int(self.as1) and int(self.as2)

    def __str__(self):
        return "%s %s" % (self.as1, self.as2)

    def __cmp__(self, other):
        if self.__class__ is not other.__class__:
            return -1
        if self.as1 == other.as1 and self.as2 == other.as2:
            return 0
        if self.as1 == other.as2 and self.as2 == other. as1:
            return 0

        return 1

    def __hash__(self):
        value = 0x345678
        for item in [self.as1, self.as2]:
            value = c_mul(1000003, value) ^ hash(item)
        value = value ^ len([self.as1, self.as2])
        if value == -1:
            value = -2
        return value
        

# hashes are hard, let's go searching
def c_mul(a,b):
    return eval(hex((long(a) * b) & 0xFFFFFFFFL)[:-1])

class AS:
    def __init__(self, asn):
        self.asn = str(int(asn))

asns = dict()
asn_adjs = dict()
adjs = dict()

def add_asn_to_asns(asn,face):
    global asns
    try:
        asns[asn].append(face)
    except KeyError:
        asns[asn] = list()
        asns[asn].append(face)

def add_adj_to_asn_adjs(adj,face):
    global asn_adjs
    for asn in [adj.as1, adj.as2]:
        try:
            asn_adjs[asn].append(adj)
        except KeyError:
            asn_adjs[asn] = list()
            asn_adjs[asn].append(adj)

def add_adj_to_adjs(adj,face):
    global adjs
    try:
        adjs[adj].append(face)
    except KeyError:
        adjs[adj] = list()
        adjs[adj].append(face)

def add_adj(adj,face):
    add_asn_to_asns(adj.as1,face)
    add_asn_to_asns(adj.as2,face)
    add_adj_to_asn_adjs(adj,face)
    add_adj_to_adjs(adj,face)
    
if __name__ == "__main__":
    mikejones = off.MikeJones("out6.off")
    grid = isea.ISEAGrid(mikejones.verts,mikejones.faces,6,isea.EARTH,2.)
    #grid.subdivide(7)
    grid.init_lookup_table()
    grid.check_lookup_table()

#    isea.lats_seen.sort()
#    isea.lons_seen.sort()
#
#    for la in isea.lats_seen:
#        print la
#    for lo in isea.lons_seen:
#        print lo
#
#    exit()

    adj_filename = sys.argv[1].rstrip()
    adj_file = open(adj_filename,"r")

    #for face in grid.faces:
    #    print face.latlon()

#    exit()
    for line in adj_file:
        as1,as2,lat,lon = line.rstrip().split()
        lat = float(lat)
        lon = float(lon)
        adj = Adjacency(as1,as2)
        as1 = str(adj.as1)
        as2 = str(adj.as2)
        
        try:
            grid.put(adj,lat,lon)
            grid.put(as1,lat,lon)
            grid.put(as2,lat,lon)
            face = grid.get(lat,lon)
            add_adj(adj,face)
            print "good %f %f --> %s" % (lat,lon,str(face.latlon()))
        except AssertionError as e:
            print "bad %s" % str(e)

