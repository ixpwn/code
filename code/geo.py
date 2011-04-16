import urllib, urllib2
import sys

''' 
By default, this takes a string as an argument in the following format:

IXP_ID, CITY, COUNTRY

where IXP_ID is from the Brice data, but could be any number really. It spits
out:

IXP_ID, LAT, LONG

If you want to use this to get lat/lons from something like the Brice IXP list,
do this:

cat ixp-list.txt | perl -pe 's/\t+/,/g' | cut -f1,4,5 -d"," | grep "," | xargs
-l {} python geo.py {} 

You can trivially modify this to take any location string as an argument and
spit out the lat/long to full degree precision using the Gmaps API.

geo.py RULEZ, create_loc_pop_brice.rb DROOLZ!!!
'''

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

if __name__ == "__main__":
    try:
        entry = sys.argv[1]
        ixp_id,foo,city = entry.partition(",")
        lat,lon = geocode(city)
        print "%s,%s,%s,%s" % (ixp_id,city, str(int(lat)), str(int(lon)))
    except:
        print "ERROR: %s,%s" % (ixp_id,city)
        exit()
