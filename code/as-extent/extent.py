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

    assert d>=0, "distance is negative!"
    return d

def bearing (origin, destination):
    lat1, lon1 = origin
    lat2, lon2 = destination
    radius = 6371 # km

    lat1 = math.radians(lat1)
    lon1 = math.radians(lon1)
    lat2 = math.radians(lat2)
    lon2 = math.radians(lon2)

    dlon = lon2 - lon1
    y = math.sin(dlon) * math.cos(lat2)
    x = math.cos(lat1)*math.sin(lat2) - math.sin(lat1)*math.cos(lat2)*math.cos(dlon)

    #bearing = (math.degrees(math.atan2(y,x)) + 360) % 360
    bearing = -math.degrees(math.atan2(y,x))
    return bearing
    
def crosstrack_distance(point, endpoint1, endpoint2):
    radius = 6371 # km
    d_e1p = distance(endpoint1,point)
    b_e1p = math.radians(bearing(endpoint1,point))
    b_e1e2 = math.radians(bearing(endpoint1,endpoint2))

    d = math.asin(math.sin(d_e1p/radius) * math.sin(b_e1p-b_e1e2)) * radius

    return d

def alongtrack_distance(point, endpoint1, endpoint2):
    radius = 6371 # km
    d_e1p = distance(endpoint1,point)
    b_e1p = math.radians(bearing(endpoint1,point))
    b_e1e2 = math.radians(bearing(endpoint1,endpoint2))

    xtd = math.asin(math.sin(d_e1p/radius) * math.sin(b_e1p-b_e1e2))
    atd = math.acos(math.cos(d_e1p/radius)/math.cos(xtd))

    return atd * radius

def point_within_threshold(point, endpoint1, endpoint2, threshold):
    d_e1e2 = distance(endpoint1, endpoint2)
    d_e1p = distance(endpoint1, point)
    d_e2p = distance(endpoint2, point)

    c = d_e1e2 * d_e1e2
    a = d_e1p * d_e1p
    b = d_e2p * d_e2p

    if d_e1p < threshold or d_e2p < threshold:
        return True

    if abs(crosstrack_distance(point, endpoint1, endpoint2)) < threshold:
        if c - (b+a) > 0:
            return True

    return False

    

# This is from Dinu C. Gherman's code 
def _myDet(p, q, r):
    """Calc. determinant of a special matrix with three 2D points.

    The sign, "-" or "+", determines the side, right or left,
    respectivly, on which the point r lies, when measured against
    a directed vector from p to q.
    """

    # We use Sarrus' Rule to calculate the determinant.
    # (could also use the Numeric package...)
    sum1 = q[0]*r[1] + p[0]*q[1] + r[0]*p[1]
    sum2 = q[0]*p[1] + r[0]*q[1] + p[0]*r[1]

    return sum1 - sum2


def _isRightTurn((p, q, r)):
    "Do the vectors pq:qr form a right turn, or not?"

    assert p != q and q != r and p != r
            
    if _myDet(p, q, r) < 0:
	return 1
    else:
        return 0


def _isPointInPolygon(r, P):
    "Is point r inside a given polygon P?"

    # We assume the polygon is a list of points, listed clockwise!
    for i in xrange(len(P[:-1])):
        p, q = P[i], P[i+1]
        if not _isRightTurn((p, q, r)):
            return 0 # Out!        

    return 1 # It's within!

def convexHull(P):
    "Calculate the convex hull of a set of points."

    # Get a local list copy of the points and sort them lexically.
    points = map(None, P)
    points.sort()

    # Build upper half of the hull.
    upper = [points[0], points[1]]
    for p in points[2:]:
	upper.append(p)
	while len(upper) > 2 and not _isRightTurn(upper[-3:]):
	    del upper[-2]

    # Build lower half of the hull.
    points.reverse()
    lower = [points[0], points[1]]
    for p in points[2:]:
	lower.append(p)
	while len(lower) > 2 and not _isRightTurn(lower[-3:]):
	    del lower[-2]

    # Remove duplicates.
    del lower[0]
    del lower[-1]

    # Concatenate both halfs and return.
    return tuple(upper + lower)

# End Dinu C. Gherman's code


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
        if len(c) > 10:
            hull = convexHull(c)
            if _isPointInPolygon(pt,hull):
                c.append(pt)
                return True
            else:
                # check all the edges
                last_p = hull[-1]
                for p in hull:
                    if point_within_threshold(pt,last_p,p,threshold):
                        c.append(pt)
                        return True

                    last_p = p
        else:
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
        if len(c) > 2:
            hull = convexHull(c)
            

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

        # always show at least the points in the cluster
        for pt in c:
            print "RESULT %f %f %d" % (pt[1], pt[0], asn) 

        # fill the bounding box, but only keep those in the hull
        for ln in xrange(int(min_lon*10),int(max_lon*10 + 0.5)+1):
            for lt in xrange(int(min_lat*10),int(max_lat*10 + 0.5)+1):
                lon = ln/10.
                lat = lt/10.

                if len(c) < 3:
                    print "RESULT %f %f %d" % (lon, lat, asn) 
                else:
                    if (lat,lon) in c:
                        continue # already got it
                    if _isPointInPolygon((lat,lon),hull):
                        print "RESULT %f %f %d" % (lon, lat, asn) 


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
            
        current_asn_pts.append((lat,lon))

    clusters = generate_clusters(current_asn_pts,threshold)
    fill_in_clusters(clusters,current_asn,threshold)
