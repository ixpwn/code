import sys
import math
import random

threshold = 1000. # km

def distance(origin, destination):
    lat1, lon1 = origin
    lat2, lon2 = destination
    radius = 6371 # km

    dlat = math.radians(lat2-lat1)
    dlon = math.radians(lon2-lon1)
    a = math.sin(dlat/2) * math.sin(dlat/2) + math.cos(math.radians(lat1)) \
        * math.cos(math.radians(lat2)) * math.sin(dlon/2) * math.sin(dlon/2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    d = radius * c

    return d

# check the "best" cluster first
def add_to_cluster(clusters,pt):
    clusters_by_dist = dict()
    for c in clusters:
        dist = distance(pt, c[0])
        if dist in clusters_by_dist:
            dist += random.random()
        clusters_by_dist[dist] = c

    # keys should be in sorted order automatically
    for dist in sorted(clusters_by_dist.keys()):
        c = clusters_by_dist[dist]
        for item in c:
           if distance(item,pt) < threshold:
               c.append(item)
               return True
    return False

# agglomerative clustering
def generate_clusters(list_of_pts):
    clusters = list()
    for pt in list_of_pts:
        if add_to_cluster(clusters,pt):
            continue

        new_cluster = [pt]
        clusters.append(new_cluster)

    return clusters

# this assumes square bounding box for now, for simplicity
def fill_in_clusters(clusters,asn=-1):
    for c in clusters:
        lats = [i[0] for i in c]
        lons = [i[1] for i in c]

        min_lat = min(lats)
        min_lon = min(lons)
        max_lat = max(lats)
        max_lon = max(lons)

        #print "%.2f %.2f %.2f %.2f" % (min_lat, max_lat, min_lon, max_lon)

        for ln in xrange(int(min_lon*10),int(max_lon*10 + 0.5)+1):
            for lt in xrange(int(min_lat*10),int(max_lat*10 + 0.5)+1):
                print "%f %f %d" % (ln/10., lt/10., asn) 

def split_input(line):
    asn, lat, lon = line.split() 
    return [asn, lat, lon]

if __name__ == "__main__":
    current_asn = -1
    current_asn_pts = list()
    
    for line in sys.stdin:
        line = line.rstrip()

        if "None" in line:
            continue

        asn, lat, lon = split_input(line)
        asn = int(asn)
        lat = float(lat)
        lon = float(lon)

        if current_asn == -1:
            current_asn = asn

        if not asn == current_asn:
            print "old asn: %d new asn: %d" % (current_asn, asn)
            # finish current
            clusters = generate_clusters(current_asn_pts)
            print "clusters generated"
            fill_in_clusters(clusters,current_asn)
            print "done"
            # start processing over
            current_asn = asn
            current_asn_pts = list()
            
        # continue with processing
        current_asn_pts.append([lat,lon])

    print "done, last asn: %d" % current_asn
    clusters = generate_clusters(current_asn_pts)
    fill_in_clusters(clusters,current_asn)
