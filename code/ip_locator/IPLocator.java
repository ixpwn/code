import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Scanner;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

import com.maxmind.geoip.Location;
import com.maxmind.geoip.LookupService;


public class IPLocator {
	private HashMap<Integer, LatLon> dnsLocs = new HashMap<Integer, LatLon>();
	private LookupService maxMind;
	private HashMap<Integer, Integer> ipToAliasID;
	private HashMap<Integer, Set<Integer>> aliasIDToIPs;
	private HashMap<Integer, LatLon> aliasIDToLoc;
	
	public IPLocator(String dnsFile, String aliasFile){
		aliasIDToLoc = new HashMap<Integer, LatLon>();
		ipToAliasID = new HashMap<Integer, Integer>();
		aliasIDToIPs = new HashMap<Integer, Set<Integer>>();
		aliasIDToLoc = new HashMap<Integer, LatLon>();
		
		String sep = System.getProperty("file.separator");
	    String dir = "/work/justine";
	    String dbfile = dir + sep + "GeoLiteCity.dat"; 
	    try{
	    	maxMind = new LookupService(dbfile,LookupService.GEOIP_MEMORY_CACHE);
	    }catch(IOException e){
	    	throw new IllegalStateException();
	    }
	    
	    Scanner dns = null;
	    try{
	    	dns= new Scanner(new File(dnsFile));
	    }catch(IOException e){
	    	throw new IllegalArgumentException("DNS file not found.");
	    }
	    while(dns.hasNextLine()){
	    	String vals[] = dns.nextLine().split(" ");
	    	double lat = Double.parseDouble(vals[1]);
	    	double lon = Double.parseDouble(vals[2]);
	    	dnsLocs.put(Prefix.aton(vals[0]), new LatLon(lat, lon));
	    }
	    
	    Scanner alias = null;
	    try{
	    	alias = new Scanner(new File(aliasFile));
	    }catch(IOException e){
	    	throw new IllegalArgumentException("Alias file not found");
	    }
	    int i = 0;
	    while(alias.hasNextLine()){
	    	i++;
	    	Set<Integer> ipset = new TreeSet<Integer>();
	    	String[] vals = alias.nextLine().trim().split(" ");
	    	for(int j = 0; j < vals.length; j++){
	    		int ip = Prefix.aton(vals[j]);
	    		ipset.add(ip);
	    		ipToAliasID.put(ip, i);
	    	}
	    	aliasIDToIPs.put(i, ipset); 	
	    }
	}
	
	public LatLon getLoc(int ip){
		Integer aliasID = ipToAliasID.get(ip);
		if(aliasID == null){
			
			LatLon dnsLoc = dnsLocs.get(ip);
			if(dnsLoc != null) return dnsLoc;
			
			Location l = maxMind.getLocation(Prefix.ntoa(ip));
			if(l == null) return null;
			//int lat = Math.round(l.latitude);
			//int lon = Math.round(l.longitude);
			double lat = l.latitude;
			double lon = l.longitude;
			return new LatLon(lat, lon);
			
		}else{
			LatLon aliasLoc = aliasIDToLoc.get(aliasID);
			if(aliasLoc != null) return aliasLoc;
			
			
			TreeMap<LatLon, Integer> locCounts = new TreeMap<LatLon, Integer>();
			
			
			for(int aliasIP : aliasIDToIPs.get(aliasID)){
				LatLon loc = dnsLocs.get(aliasIP);
				if(loc == null) continue;
				if(locCounts.get(loc) == null) locCounts.put(loc, 0);
				locCounts.put(loc,locCounts.get(loc) + 1);
			}
			if(locCounts.keySet().size() != 0){
				LatLon finalLoc = electLoc(locCounts);
				aliasIDToLoc.put(aliasID, finalLoc);
				return finalLoc;
			}
			
			for(int aliasIP : aliasIDToIPs.get(aliasID)){
				Location l = maxMind.getLocation(Prefix.ntoa(ip));
				if(l == null) continue;
				//int lat = Math.round(l.latitude);
				//int lon = Math.round(l.longitude);
				double lat = l.latitude;
				double lon = l.longitude;
				LatLon loc = new LatLon(lat, lon);
				if(locCounts.get(loc) == null) locCounts.put(loc, 0);
				locCounts.put(loc,locCounts.get(loc) + 1);
			}
			if(locCounts.keySet().size() != 0){
				LatLon finalLoc = electLoc(locCounts);
				aliasIDToLoc.put(aliasID, finalLoc);
				return finalLoc;
			}
		}
		return null;
	}
	
	private LatLon electLoc(TreeMap<LatLon, Integer> locCounts){
	//	System.err.println(locCounts.keySet());
		if(locCounts == null || locCounts.keySet().size() == 0) return null;
		int best = 0;
		Set<LatLon> bestLocs = new TreeSet<LatLon>();
		int tot = 0;
		for(LatLon l : locCounts.keySet()){
			tot += locCounts.get(l);
			if(locCounts.get(l) > best){
				best = locCounts.get(l);
				bestLocs = new TreeSet<LatLon>();
				bestLocs.add(l);
			}else if(locCounts.get(l) == best){
				bestLocs.add(l);
			}
		}
		
		if(bestLocs.size() == 1){
			for(LatLon loc : bestLocs) return loc;
		}
		
		double bestDTot = 200000;
		LatLon bestLoc = null;
		for(LatLon l1 : locCounts.keySet()){
			double dtot = 0;
			for(LatLon l2 : locCounts.keySet()){
				double distance = l1.distance(l2);
				dtot += distance * locCounts.get(l2);
			}
			dtot = dtot / tot;
			if(dtot < bestDTot){
				bestDTot = dtot;
				bestLoc = l1;
			}
		}
		return bestLoc;
		
	}
	
	
}
