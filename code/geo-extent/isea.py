'''
The goal here is to determine the geographic extent of an AS, given a sampling
of locations of IPs that it covers. 

Another approach is to have a polyhedron composed of faces (defined in turn by
points). We know the x,y,z coordinates of each vertex of a icosahedron. Given
the three corners of a triangle we can easily determine the coordinates of four
triangles that subdivide it: these are simply the midpoints of each edge of the
triangle. Once we have subdivided the faces of the triangle, we project the
vertices of each subdivided triangle to the radius of the circumscribed sphere.
We will know the cartesian coordinates of each subdivided triangle's vertices;
we just need to scale these to the size of the radius we want. We repeat this
process until the area of a triangle is less than our desired resolution. This
relationship is defined by:

    Area = [ sqrt(3) * R^2 / (phi * sqrt(5)) ] / 4^n

where R is the radius of the Earth (~6378km) and n is the number of times we
subdivide the original faces of the icosahedron. Note this is not an exact
measure; as we scale the subdivided triangles to the radius of the circumscribed
sphere their area slightly increases. 

The side length of each sub-face is given by:

    sqrt(4 * Area / sqrt(3))

Here is a table with some cell sizes:

# subdivisions      # triangles     cell area           cell side length
    6                   81k         19017 km^2              209 km
    7                   327k        4754                    104
    8                   1.3m        ??                      ??
    9                   5.2m        ??                      ??

Once we have completed the levels of subdivision we want we can blow up the
sphere to the desired radius. 

We use Kristin's method for mapping a lat/lon to a grid point quickly for doing
lookups. In particular, we maintain a 2-d "array" (really, a list of lists)
indexed by latitude and then longitude, in whole degree increments; this is our
lookup table. After we generate all our grid cells to the desired resolution,
we add each such cell to the lookup table by determining if the cell could
include the lat/lon point that element of the lookup table describes. The
current implementation does this by projecting a ray from the center of the
earth into 3-space, and then determining if that ray intersects a sphere around
the centroid of a face with radius equal to the distance between a vertex and
the centroid. To bound the number of rays we have to generate per face, we only
check the range of lat/lons that are between the three vertices of the grid
cell.
'''
import sys

import math


PHI = ( 1 + math.sqrt(5) ) * 0.5 # 1.61803...
EARTH = 6378. # km

# a ISEA-ish grid of the globe
class Vertex:
    def __init__(self, x, y, z=0.0):
        self.coords = [float(x),float(y),float(z)]
        self.x = self.coords[0]
        self.y = self.coords[1]
        self.z = self.coords[2]
        self.length = self.magnitude()

    # with regard to origin
    def magnitude(self):
        return math.sqrt(self.x*self.x + self.y*self.y + self.z*self.z) 

    # scale point to desired distance from origin
    def scale(self,desired_radius):
        curr_radius = self.magnitude()
        mult = desired_radius / curr_radius
        self.coords = [i*mult for i in self.coords]
        self.x = self.coords[0]
        self.y = self.coords[1]
        self.z = self.coords[2]

    def __str__(self):
        return "(%f, %f, %f)" % (self.x, self.y, self.z)

class Edge:
    def __init__(self, v1, v2):
        self.v1 = v1
        self.v2 = v2

    def length(self):
        dx = self.v2.x - self.v1.x
        dy = self.v2.y - self.v1.y
        dz = self.v2.z - self.v1.z
        return math.sqrt(dx*dx + dy*dy + dz*dz)

    def midpoint(self):
        mx = (self.v2.x + self.v1.x) * 0.5
        my = (self.v2.y + self.v1.y) * 0.5
        mz = (self.v2.z + self.v1.z) * 0.5
        return Vertex(mx, my, mz)

    def __str__(self):
        return "[%s %s]" % (str(self.v1), str(self.v2))

class Face:
    def __init__(self,v1, v2, v3):
        self.v1 = v1
        self.v2 = v2
        self.v3 = v3
        self.centroid = self._calc_centroid()
        self.e1 = Edge(v1,v2)
        self.e2 = Edge(v1,v3)
        self.e3 = Edge(v2,v3)
        self.stuff = list()

    def centroid(self):
        return centroid

    def latlon(self):
        return cartesian_to_latlon(self.centroid)

    def _calc_centroid(self):
        cx = (self.v1.x + self.v2.x + self.v3.x) / 3
        cy = (self.v1.y + self.v2.y + self.v3.y) / 3
        cz = (self.v1.z + self.v2.z + self.v3.z) / 3
        return Vertex(cx,cy,cz)

    def subdivide(self):
        f1 = Face(self.v1, self.e1.midpoint(), self.e2.midpoint())
        f2 = Face(self.e2.midpoint(), self.e3.midpoint(), self.v3)
        f3 = Face(self.e1.midpoint(), self.v2, self.e3.midpoint())
        f4 = Face(self.e1.midpoint(), self.e2.midpoint(), self.e3.midpoint())
        return [f1, f2, f3, f4]

    # blow up all the edges (basically do a new init, with scaled verts)
    def inflate(self,desired_radius):
        self.v1.scale(desired_radius)
        self.v2.scale(desired_radius)
        self.v3.scale(desired_radius)
        self.centroid = self._calc_centroid()
        self.e1 = Edge(self.v1,self.v2)
        self.e2 = Edge(self.v1,self.v3)
        self.e3 = Edge(self.v2,self.v3)

    # Draw a ray from center to vertex, see if it intersects this face. Because
    # I'm both lazy and stupid I define a sphere around the centroid and
    # project the ray (i.e., vertex) to the same distance as the centroid. If
    # the projected ray is within the sphere, then they "intersect". Close
    # enough. This assumes equal distance from a centroid to a vertex of the
    # face.
    def intersects(self,vertex):
        radius = Edge(self.centroid, self.v1).length()
        vertex.scale(self.centroid.magnitude()) 
        dist = Edge(self.centroid, vertex).length()
        if dist <= radius:
            return True
        else:
            return False

class Icosahedron:
    global PHI

    def __init__(self):
        verts = [   Vertex(0, PHI, 1), Vertex(0, -PHI, 1), 
                    Vertex(0,-PHI,-1), Vertex(0, PHI, -1), 
                    Vertex(1, 0, PHI), Vertex(1, 0, -PHI), 
                    Vertex(-1, 0, -PHI), Vertex(-1, 0, PHI), 
                    Vertex(PHI, 1, 0), Vertex(-PHI, 1, 0), 
                    Vertex(-PHI, -1, 0), Vertex(PHI, -1, 0) ]
        self.verts = verts

        self.faces = self._gen_faces(verts)
        
        
        
    def _gen_faces(self,verts):
        faces = [   Face(verts[11],verts[8],verts[4]),
                    Face(verts[11],verts[4],verts[1]),
                    Face(verts[11],verts[1],verts[2]),
                    Face(verts[11],verts[2],verts[5]),
                    Face(verts[11],verts[5],verts[8]),
                    Face(verts[8],verts[0],verts[4]),
                    Face(verts[4],verts[7],verts[1]),
                    Face(verts[1],verts[10],verts[2]),
                    Face(verts[2],verts[6],verts[5]),
                    Face(verts[5],verts[3],verts[8]),
                    Face(verts[4],verts[0],verts[7]),
                    Face(verts[1],verts[7],verts[10]),
                    Face(verts[2],verts[10],verts[6]),
                    Face(verts[5],verts[6],verts[3]),
                    Face(verts[8],verts[3],verts[0]),
                    Face(verts[0],verts[9],verts[7]),
                    Face(verts[7],verts[9],verts[10]),
                    Face(verts[10],verts[9],verts[6]),
                    Face(verts[6],verts[9],verts[3]),
                    Face(verts[3],verts[9],verts[0]) ]

        return faces

def latlon_to_cartesian(lat,lon,radius=EARTH):

    theta = math.radians(float(lat+90))
    phi = math.radians(float(lon))
    x = radius * math.sin(theta) * math.cos(phi)
    y = radius * math.sin(theta) * math.sin(phi)
    z = radius * math.cos(theta)

    return (x,y,z)

def cartesian_to_latlon(vertex):
    radius = Edge(Vertex(0,0,0),vertex).length()
    x = vertex.x
    y = vertex.y
    z = vertex.z

    lat = math.acos(z/radius)
    lon = math.atan2(y,x)
    lat = math.degrees(lat) - 90
    lon = math.degrees(lon) 
    assert (lat >= -90 and lat <= 90), "latitude out of bounds: %f" % lat
    assert (lon >= -180 and lat <= 180), "longitude out of bounds: %f" % lon
    return (lat,lon)

def get_latlon_for_face(grid,face):
    lat = math.acos(face.centroid.z/grid.radius)
    lon = math.atan2(face.centroid.y,face.centroid.x)
    lat = math.degrees(lat) - 90
    lon = math.degrees(lon) 
    assert (lat >= -90 and lat <= 90), "latitude out of bounds: %f" % lat
    assert (lon >= -180 and lat <= 180), "longitude out of bounds: %f" % lon
    return (lat,lon)
    
def add_face_to_table_cell(grid,face):
    latlon = get_latlon_for_face(grid,face)
    lat_index = int(latlon[0] + 0.5) + 90 - 1
    lon_index = int(latlon[1] + 0.5) + 180 - 1
    try:
        grid.lookup_table[lat_index][lon_index].append(face)
    except IndexError:
        print "%d %d" % (lat_index, lon_index)
        raise


lats_seen = list()
lons_seen = list()
coords_seen = list()
def add_face_to_table_cells(grid,face):
    global lats_seen, lons_seen
    latlon_v1 = cartesian_to_latlon(face.v1)
    latlon_v2 = cartesian_to_latlon(face.v2)
    latlon_v3 = cartesian_to_latlon(face.v3)

    lat_min = int(min(latlon_v1[0], latlon_v2[0], latlon_v3[0]))
    lat_max = int(max(latlon_v1[0], latlon_v2[0], latlon_v3[0]) + 0.5)
    lon_min = int(min(latlon_v1[1], latlon_v2[1], latlon_v3[1]))
    lon_max = int(max(latlon_v1[1], latlon_v2[1], latlon_v3[1]) + 0.5)

    for lat in xrange(lat_min,lat_max):
        for lon in xrange(lon_min, lon_max):
            v = latlon_to_cartesian(lat,lon)
            #if lat == 17 and lon == 78:
                #print "HERE IT IS!!!!"

# TODO: the above print statement shows up but no vertex with the given
# coordinates appears to pass the collision test. There is probably a problem
# with the collision detection routine that could be solved by bumping the
# radius up a little bit. Or maybe there is a distortion problem... Who
# knows...
            if face.intersects(Vertex(v[0],v[1],v[2])):
                #print "%d %d" % (lat,lon)
                #if not lat in lats_seen:
                #    lats_seen.append(lat)
                #if not lon in lons_seen:
                #    lons_seen.append(lon)
                grid.lookup_table[lat-1][lon-1].append(face)

class ISEAGrid:
    global PHI, EARTH

    def __init__(self):
        i = Icosahedron()
        self.verts = i.verts
        self.faces = i.faces
        self.radius = i.verts[0].length # all the same to start with...
        self.subdivision_level = 0 # number of times triangles were divided

        # index by lat, then lon
        self.lookup_table = [ [ [] for x in range(360) ] for i in range(180)]

    def area_of_cell(self,r=-1,iterations=-1):
        if r <=0:
            r = self.radius
        if iterations < 0:
            iterations = self.subdivision_level
        return (math.sqrt(3) * r*r / (PHI * math.sqrt(5))) / \
                math.pow(4, iterations)

    def side_of_cell_length(self,r=-1, iterations=-1):
        area = self.area_of_cell(r,iterations)
        return math.sqrt(4 * area / math.sqrt(3))


    # this is the real workhorse
    # can be parallelized easily (also uses absurd amounts of memory)
    def subdivide(self,iterations,hpy=None):
        old_faces = self.faces
        for i in range(0,iterations):
            new_faces = []
            count = 0
            for f in old_faces:
                subdivided_faces = f.subdivide()
                [face.inflate(self.radius) for face in subdivided_faces]
                new_faces += subdivided_faces
                count += 4
            
            old_faces = new_faces
            print "%d triangles (area: ~%.2f km^2/cell, len: ~%.2f km)" \
                    % ( count,self.area_of_cell(EARTH,i), \
                        self.side_of_cell_length(EARTH,i))

        self.faces = new_faces
        self.subdivision_level += iterations

    # this should be called after you do subdivision
    def init_lookup_table(self):
        map(lambda x: add_face_to_table_cells(self,x), self.faces)

    def put(self, item, lat, lon):
        assert item, "no item (don't waste my fucking time)"
        best_face = self.get(lat,lon)
        best_face.stuff.append(item)

    def get(self, lat, lon):
        assert (lat >= -90 and lat <= 90), "latitude invalid: %f" % lat
        assert (lon >= -180 and lat <= 180), "longitude invalid: %f" % lon

        lat_idx = int(lat + 0.5) - 1
        lon_idx = int(lon + 0.5) - 1

        x,y,z = latlon_to_cartesian(lat,lon)
        v = Vertex(x,y,z)

        faces = self.lookup_table[lat_idx][lon_idx]
        assert len(faces) > 0, "no faces in table for %f %f" % (lat,lon)

        best_face = None
        best_dist = -1

        for face in faces:
            mag = face.centroid.magnitude() # rescale to be fair
            v.scale(mag)
            dist = Edge(v,face.centroid).length() / mag # normalize
            if not best_face or dist < best_dist:
                best_face = face
                best_dist = dist

        assert best_face and best_dist >= 0, "no best face" 

        return best_face
        

def get_latlon_for_face(grid,face):
    lat = math.acos(face.centroid.z/grid.radius)
    lon = math.atan2(face.centroid.y,face.centroid.x)
    lat = math.degrees(lat) - 90
    lon = math.degrees(lon) 

if __name__ == "__main__":
    i = ISEAGrid()
    i.subdivide(6) # 7 is max for 32bit; 8 needs 18+ GB, 9 needs 25+ GB
    print len(i.faces)
    #map(lambda x: add_face_to_table_cells(i,x), i.faces)
    i.init_lookup_table()
    for lat in range(0,len(i.lookup_table)):
        for lon in range(0,len(i.lookup_table[lat])):
            print "In cell (%d,%d), containing %d faces" % (lat,lon,len(i.lookup_table[lat][lon]))
            for face in i.lookup_table[lat][lon]:
                print " | %s %f" % (face.centroid, face.centroid.magnitude())
    #for face in i.faces:
    #    print "%s %f" % (face.centroid, face.centroid.magnitude())
