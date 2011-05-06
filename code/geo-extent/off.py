import isea
import sys

''' 
    world gonna know mike jones
    mike jones gonna know the world
'''
class MikeJones:
    def __init__(self, filename):
        first_line = True
        vert_state = False
        face_state = False

        vert_num = 0
        face_num = 0
        vert = dict()

        self.verts = list()
        self.faces = list()
        off_file = open(filename,"r")
        for line in off_file:
            line = line.rstrip()
            try:
                if first_line:
                    if line.startswith("OFF"):
                        continue
                    verts,faces,edges = line.split()
                    verts = int(verts)
                    faces = int(faces)
                    edges = int(edges)
                    first_line = False
                    vert_state = True

                elif vert_state:
                    x,y,z = line.split()
                    x = float(x)
                    y = float(y)
                    z = float(z)
                    v = isea.Vertex(x,y,z)
                    vert[str(vert_num)] = v
                    self.verts.append(v)
                    vert_num += 1
                    if vert_num > verts:
                        vert_state = False
                        face_state = True

                if face_state:
                    a,b,c = line.split()
                    v1 = vert[a]
                    v2 = vert[b]
                    v3 = vert[c]
                    f = isea.Face(v1,v2,v3)
                    f.old_inflate(isea.EARTH)
                    self.faces.append(f)
            except:
                print line
                raise

if __name__ == "__main__":
    filename = sys.argv[1].rstrip()
    mikejones = MikeJones(filename)
    for face in mikejones.faces:
        print face.area()

