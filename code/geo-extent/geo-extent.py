'''
The goal here is to determine the geographic extent of an AS, given a sampling of locations of IPs that it covers. 

First, we need to generate a ...

get the grid item that contains a particular lat/lon

we can generate a series of points that correspond to the center points of
a icosahedron tiling of the globe. We need a generator function for these. 

the generator could behave as follows. Consider the 20 faces of a regular
icosahedron. The sphere incscribed in the icosahedron (tangent to the faces) is
our Earth. We can state that one "origin" tangent point is at 0/0. We then
subdivide the triangles to achieve our desired resolution. We start with the 20
faces, then divide each block of our list into 4 pieces for each extra level of
resolution we want until we have achieved desired resolution.

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
    7                   327k        ??                      104
    8                   1.3m        ??                      ??
    9                   5.2m        ??                      ??

Once we have completed the levels of subdivision we want we can blow up the
sphere to the desired radius. 

we can use kristin's method for mapping a lat/lon to a grid point quickly for
doing lookups. 
'''
#import psyco
#psyco.full()

import sys
import math


PHI = ( 1 + math.sqrt(5) ) * 0.5 # 1.61803...

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

class Face:
    def __init__(self,v1, v2, v3):
        self.v1 = v1
        self.v2 = v2
        self.v3 = v3
        self.centroid = self._calc_centroid()
        self.e1 = Edge(v1,v2)
        self.e2 = Edge(v1,v3)
        self.e3 = Edge(v2,v3)

    def centroid(self):
        return centroid

    def _calc_centroid(self):
        cx = (self.v1.x + self.v2.x + self.v3.x) / 3
        cy = (self.v1.y + self.v2.y + self.v3.y) / 3
        cz = (self.v1.z + self.v2.z + self.v3.z) / 3

    def subdivide(self):
        f1 = Face(self.v1, self.e1.midpoint(), self.e2.midpoint())
        f2 = Face(self.e2.midpoint(), self.e3.midpoint(), self.v3)
        f3 = Face(self.e1.midpoint(), self.v2, self.e3.midpoint())
        f4 = Face(self.e1.midpoint(), self.e2.midpoint(), self.e3.midpoint())
        return [f1, f2, f3, f4]

    # blow up all the edges (basically do a new init, with scaled verts)
    # for this particular application we don't need to recalc centroid
    def inflate(self,desired_radius):
        self.v1.scale(desired_radius)
        self.v2.scale(desired_radius)
        self.v3.scale(desired_radius)
        self.centroid = self._calc_centroid()
        self.e1 = Edge(self.v1,self.v2)
        self.e2 = Edge(self.v1,self.v3)
        self.e3 = Edge(self.v2,self.v3)

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

class ISEAGrid:
    global PHI

    def __init__(self):
        i = Icosahedron()
        self.verts = i.verts
        self.faces = i.faces
        self.radius = i.verts[0].length # all the same to start with...
        self.subdivision_level = 0 # number of times triangles were divided

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
    def subdivide(self,iterations):
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
                    % ( count,self.area_of_cell(6378,i), \
                        self.side_of_cell_length(6378,i))

        self.faces = new_faces
        self.subdivision_level += iterations
            

if __name__ == "__main__":
    i = ISEAGrid()
    i.subdivide(8)
    print len(i.faces)
