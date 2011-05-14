import sys
import math
import random

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

# check the "closest" cluster first: this speeds things up significantly for AS's
# with large prefix samples.
def add_to_cluster(clusters,pt,threshold):
    clusters_by_dist = dict()

    for c in clusters:
        dist = distance(pt, c[0])
        if dist in clusters_by_dist:
            dist += random.random()
        clusters_by_dist[dist] = c

    # keys may be in sorted order automatically, but just to be sure...
    for dist in sorted(clusters_by_dist.keys()):
        c = clusters_by_dist[dist]
        for item in c:
           if distance(item,pt) < threshold:
               c.append(pt)
               return True
    return False

# Agglomerative clustering: if a point is within threshold of some point in an
# existing cluster, add it to that cluster. Otherwise start a new one with the
# point as a seed.
#
# This has a bug: it's sensitive to ordering, but it doesn't majorly affect our
# application. Consider three points, where d(p1,p2) < thresh, and d(p2,p3) <
# thresh, but d(p1,p3) is not. If we see points in the order [p1,p2,p3], we'll
# have one cluster. But, if they come in the order [p1, p3, p2], we'll have
# two. I think the fact we sort the points first mitigates this issue.
def generate_clusters(list_of_pts,threshold):
    clusters = list()
    for pt in list_of_pts:
        if add_to_cluster(clusters,pt,threshold):
            continue

        new_cluster = [pt]
        clusters.append(new_cluster)

    return clusters

# this assumes square bounding box for now, for simplicity
def fill_in_clusters(clusters,asn,threshold):
    for c in clusters:
        lats = [i[0] for i in c]
        lons = [i[1] for i in c]

        min_lat = min(lats)
        min_lon = min(lons)
        max_lat = max(lats)
        max_lon = max(lons)
   
        if min_lat!=max_lat or min_lon!=max_lon:
            print "c_size: %d thresh: %d asn: %d | %.2f %.2f %.2f %.2f *" \
                % (len(c), threshold, asn, min_lat, max_lat, min_lon, max_lon)
        else:
            print "c_size: %d thresh: %d asn: %d | %.2f %.2f %.2f %.2f" \
                % (len(c), threshold, asn, min_lat, max_lat, min_lon, max_lon)


        for ln in xrange(int(min_lon*10),int(max_lon*10 + 0.5)+1):
            for lt in xrange(int(min_lat*10),int(max_lat*10 + 0.5)+1):
                print "RESULT %f %f %d" % (ln/10., lt/10., asn) 

def split_input(line):
    asn, lat, lon = line.split() 
    return [asn, lat, lon]

if __name__ == "__main__":
    threshold = sys.argv[1]
    threshold = int(threshold)

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
            # finish current
            clusters = generate_clusters(current_asn_pts,threshold)
            fill_in_clusters(clusters,current_asn,threshold)

            # start processing over
            current_asn = asn
            current_asn_pts = list()
            
        current_asn_pts.append([lat,lon])

    clusters = generate_clusters(current_asn_pts,threshold)
    fill_in_clusters(clusters,current_asn,threshold)
