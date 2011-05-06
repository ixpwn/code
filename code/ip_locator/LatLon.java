
	public class LatLon implements Comparable<LatLon>{
		public double lat;
		public double lon;
		
		public LatLon(double lat, double lon){
			this.lat = lat;
			this.lon = lon;
		}
		
		 public double distance(LatLon other) {
			 	double lat1 = this.lat;
			 	double lng1 = this.lon;
			 	double lat2 = other.lat;
			 	double lng2 = other.lon;
			    double earthRadius = 6371.00;
			    double dLat = Math.toRadians(lat2-lat1);
			    double dLng = Math.toRadians(lng2-lng1);
			    double a = Math.sin(dLat/2) * Math.sin(dLat/2) +
			               Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
			               Math.sin(dLng/2) * Math.sin(dLng/2);
			    double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
			    double dist = earthRadius * c;
			    if(dist == Double.NaN){
			    	System.err.println(this + " " + other);
			    }
			    return dist;
		 }
		
		public String toString(){
			return this.lat + " " + this.lon;
		}
	
		public boolean equals(LatLon other){
			if(other == null) return false;
			return this.lat == other.lat && this.lon == other.lon;
		}

		@Override
		public int compareTo(LatLon other) {
			if(this.lat < other.lat) return -1;
			if(this.lat > other.lat) return 1;
			if(this.lon < other.lon) return -1;
			if(this.lon > other.lon) return 1;
			return 0;
		}
	}