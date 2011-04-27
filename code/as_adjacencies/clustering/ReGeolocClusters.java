import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Scanner;
import java.util.Set;
import java.util.TreeSet;

import com.maxmind.geoip.Location;
import com.maxmind.geoip.LookupService;


public class ReGeolocClusters {
	  public static void main(String[] args) throws IOException {
			//try {
			    String sep = System.getProperty("file.separator");

			    // Uncomment for windows
			    // String dir = System.getProperty("user.dir"); 

			    // Uncomment for Linux
			    String dir = "~/tmpdir";

			    String dbfile = dir + sep + "GeoLiteCity.dat"; 
			    // You should only call LookupService once, especially if you use
			    // GEOIP_MEMORY_CACHE mode, since the LookupService constructor takes up
			    // resources to load the GeoIP.dat file into memory
			    LookupService cl = new LookupService(dbfile,LookupService.GEOIP_STANDARD);
			    //LookupService cl = new LookupService(dbfile,LookupService.GEOIP_MEMORY_CACHE);
			    
			    File inputFile = new File(args[0]);
			    Scanner s = new Scanner(inputFile);
			    
			    HashMap<Integer, Set<Integer>> idToIPSet = new HashMap<Integer, Set<Integer>>();
			    HashMap<Integer, LatLon> idToLoc = new HashMap<Integer, LatLon>();
			    
			    while(s.hasNextLine()){
			    	String[] split = s.nextLine().split(" ");
			    	int curid = Integer.parseInt(split[1]);
			    	if(idToIPSet.get(curid) == null) idToIPSet.put(curid, new TreeSet<Integer>());
			    	idToIPSet.get(curid).add(Prefix.aton(split[0]));

			    	if(Double.parseDouble(split[2]) < 180){
			    		if(idToLoc.get(curid) == null) idToLoc.put(curid, new LatLon(Double.parseDouble(split[2]), Double.parseDouble(split[3]))); 
			    	}
			    }

			    for(int clusterID : idToIPSet.keySet()){
			    	if(idToLoc.get(clusterID) != null){
			    		for(int ip : idToIPSet.get(clusterID)){
			    			System.out.println(Prefix.ntoa(ip) + " " + clusterID + " " + idToLoc.get(clusterID));
			    		}
			    	}else{ //maxmindmapit
			    		List<LatLon> locs = new ArrayList<LatLon>();
			    		for(int ip : idToIPSet.get(clusterID)){
			    			Location l = cl.getLocation(Prefix.ntoa(ip));
			    			LatLon ll = new LatLon(l.latitude, l.longitude);
			    			locs.add(ll);
			    		}
			    		LatLon avg = averageLoc(locs);
			    		
			    		for(int ip : idToIPSet.get(clusterID)){
			    			System.out.println(Prefix.ntoa(ip) + " " + clusterID + " " + avg);
			    		}
			    		
			    	}
			    }

			    cl.close();
		    }
	  
	  		public static LatLon averageLoc(List<LatLon> locs){
	  			double lat = 0;
	  			double lon = 0;
	  			for(LatLon l : locs){
	  				lat += l.lat;
	  				lon += l.lon;
	  			}
	  			lat = lat / locs.size();
	  			lon = lon / locs.size();
	  			return new LatLon(lat, lon);
	  		}
}
