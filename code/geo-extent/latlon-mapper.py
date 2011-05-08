import sys
import isea
import off

mikejones = off.MikeJones("out6.off")
grid = isea.ISEAGrid(mikejones.verts,mikejones.faces,6,isea.EARTH,2.)
grid.init_lookup_table()

for line in sys.stdin:
    items = line.rstrip().split(" ",2)

    lat = items[0]
    lon = items[1]
    notes = ""
    if len(items) > 2:
        notes = items[2]
    
    try:
        lat = float(lat)
        lon = float(lon)
    except ValueError:
        print line
        raise

    try:
        face = grid.get(lat,lon)
        print "%f %f: %d %s %s" % (lat,lon,face.id,face.latlon(),notes)
    except:
        print "%f %f: FAILURE FAILURE FAILURE %s" % (lat,lon,notes)

