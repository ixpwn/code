import sys
import isea
import off

mikejones = off.MikeJones("out6.off")
grid = isea.ISEAGrid(mikejones.verts,mikejones.faces,6,isea.EARTH,2.)
grid.init_lookup_table()

for line in sys.stdin:
    lat,lon = line.rstrip().split()

    lat = float(lat)
    lon = float(lon)

    try:
        face = grid.get(lat,lon)
        print "%f %f: %d %s" % (lat,lon,face.id,face.latlon())
    except:
        print "%f %f: FAILURE" % (lat,lon)

