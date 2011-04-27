
	public class LatLon{
		public double lat;
		public double lon;
		
		public LatLon(double lat, double lon){
			this.lat = lat;
			this.lon = lon;
		}
		
		public double distance(LatLon other) {
			  double lat1 = this.lat;
			  double lat2 = other.lat;
			  double lon1 = this.lon;
			  double lon2 = other.lon;
			  double theta = lon1 - lon2;
			  double dist = Math.sin(deg2rad(lat1)) * Math.sin(deg2rad(lat2)) + Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) * Math.cos(deg2rad(theta));
			  dist = Math.acos(dist);
			  dist = rad2deg(dist);
			  dist = dist * 60 * 1.1515;
			  dist = dist * 1.609344;
			  return (dist);
		}
		
		/*:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
		/*::  This function converts decimal degrees to radians             :*/
		/*:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
		private double deg2rad(double deg) {
		  return (deg * Math.PI / 180.0);
		}

		/*:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
		/*::  This function converts radians to decimal degrees             :*/
		/*:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
		private double rad2deg(double rad) {
		  return (rad * 180.0 / Math.PI);
		}
		
		public String toString(){
			return this.lat + " " + this.lon;
		}
	
		public boolean equals(LatLon other){
			if(other == null) return false;
			return this.lat == other.lat && this.lon == other.lon;
		}
	}