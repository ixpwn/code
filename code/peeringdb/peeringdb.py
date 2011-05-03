# This assumes you have the PeeringDB database in a local MySQL DB

import MySQLdb as db
import MySQLdb.cursors
import sys
import time


# this is all straight out of the geo.py code
import urllib, urllib2

root_url = "http://maps.google.com/maps/geo?"
return_codes = {'200':'SUCCESS',
                '400':'BAD REQUEST',
                '500':'SERVER ERROR',
                '601':'MISSING QUERY',
                '602':'UNKOWN ADDRESS',
                '603':'UNAVAILABLE ADDRESS',
                '604':'UNKOWN DIRECTIONS',
                '610':'BAD KEY',
                '620':'TOO MANY QUERIES'
               }

class GeocodingException(Exception):
    """This is raised whenever Google returns an unexpected result"""
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)

def geocode(addr):
    """This function will perform a single geocoding, and return (lat, lng)
    
    This function will resolve 'address' into a latitude and longitude.
    Latitude and Longitude are returned as a tuple (lat, lng).  This
    function uses urllib and the Google maps api to perform the geocoding.

    Any errors that occur in this function will raise a GeocodingException.
    The GeocodingException will have the error message set to the value
    attribute of the Exception.

    This function was inspired by:
        http://snipplr.com/view/15270/python-geocode-address-via-urllib/

    Arguments:
    addr -- The address to be geocoded, a string

    """
    values = {'q' : addr, 'output':'csv'}
    data = urllib.urlencode(values)
    #set up our request
    url = root_url+data
    req = urllib2.Request(url)
    #make request and read response
    response = urllib2.urlopen(req)
    geodat = response.read().split(',')
    response.close()
    #handle the data returned from google
    code = return_codes[geodat[0]]
    if code == 'SUCCESS':
        code, precision, lat, lng = geodat
        return (float(lat), float(lng))
    else:
        raise GeocodingException(code)

# this generates a location string for all the facilities in the db
def get_geoloc_string_for_all_facilities():
    global conn

    result = dict()

    q = "SELECT `id`, `address1`, `address2`, `city`, `state`, `country` FROM \
        `mgmtFacilities` WHERE `approved`='Y'"
    
    c = conn.cursor()
    c.execute(q)
    rows = c.fetchall()

    for r in rows:
        if r["state"] == r["country"]:
            r["state"] = None
        for item in r: 
            r[item] = r[item] or ""
        result[str(r["id"])] = "%s %s %s %s %s" % (r["address1"], r["address2"], r["city"], r["state"], r["country"])

    return result

# geocodes location string for each facility, then assigns fpid based on
# existing brice data.
def generate_fp_pdb_file(result_list, list_of_locs):
    fp_pdb_file = open("fp_pdb.txt", "w")
    for fac_id in result_list:
        geoloc_string = result_list[fac_id]
        print str(geoloc_string)
        try:
            lat, lon = geocode(geoloc_string)
        except:
            continue
        latlon_key = "%03d%03d" % (int(lat+90.5),int(lon+180.5))

        if latlon_key in list_of_locs:
            list_of_locs[latlon_key] += 1
        else:
            list_of_locs[latlon_key] = 0
            
        val = list_of_locs[latlon_key]

        fp_id = "%s%d" % (latlon_key, val)
        print "%s %s" % (fp_id, str(fac_id))
        fp_pdb_file.write("%s %s\n" % (fp_id, str(fac_id)))
        time.sleep(0.1) # rate limiting

    fp_pdb_file.close()
    return list_of_locs

# parses the fp_id file for facilities
def get_priv_fac_fpids():
    fp_pdb_file = open("fp_pdb.txt", "r")
    res = dict()
    for line in fp_pdb_file:
        fpid, fac_id = line.rstrip().split()
        res[fac_id] = fpid
    
    fp_pdb_file.close()
    return res

# generates the current fpid for a lat/lon pair
def seed_latlon_list_from_brice(brice_name):
    list_of_locs = dict()
    try:
        brice_file = open(brice_name, "r")
    except:
        print "couldn't open that brice file, exiting"
        exit()


    for line in brice_file:
        line = line.rstrip()
        fp_id = line.split("\t")[0]
        latlon_key = fp_id[:6]
        value = int(fp_id[6])

        if latlon_key in list_of_locs:
            list_of_locs[latlon_key] = max(list_of_locs[latlon_key],value)
        else:
            list_of_locs[latlon_key] = value

    brice_file.close()

    return list_of_locs


#########

# creative naming
conn = db.connect( host="localhost", 
                   user="peeringdb", 
                   passwd="peeringdb",
                   db="peeringdb", cursorclass=db.cursors.DictCursor)

try:
    f = open("fp_pdb.txt","r")
    f.close()
except:
    # we need to generate the fpid file
    # first read in the list of brice IXP fpid's so we can avoid duplication
    brice_name = sys.argv[1].rstrip()
    loc_list = seed_latlon_list_from_brice(brice_name)
    res = get_geoloc_string_for_all_facilities()
    generate_fp_pdb_file(res,loc_list)

# at this point we are gauranteed to have the right fp_id for every private
# facility in the fp_pdb.txt file.
# 3) do the query in the peerParticipantsPrivates table to get the list of ASNs
#       for the facility id.
# 4) print that shit out.
facilities = get_priv_fac_fpids()
c = conn.cursor()
for fac_id in facilities:
    q = "SELECT `local_asn` FROM `peerParticipantsPrivates` WHERE `facility_id`=%s" % fac_id 
    c.execute(q)
    rows = c.fetchall()
    if len(rows) < 2:
        # ignore facilities w/ 0 or 1 known ASNs
        continue
    for r in rows:
        print "%s %s" % (facilities[fac_id], r["local_asn"])
