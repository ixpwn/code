import sys
import isea

NUM_SUBDIVISIONS = 1

grid = isea.ISEAGrid()
grid.subdivide(NUM_SUBDIVISIONS)
grid.init_lookup_table()

for line in sys.stdin:
    lat,lon = line.rstrip().split()

    lat = float(lat)
    lon = float(lon)

    try:
        face = grid.get(lat,lon)
        print "%.2f %.2f: %s" % (lat,lon,face.latlon())
    except:
        print "%.2f %.2f: FAILURE" % (lat,lon)

