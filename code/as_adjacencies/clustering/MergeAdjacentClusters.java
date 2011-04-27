import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Scanner;
import java.util.Set;
import java.util.TreeSet;

import com.maxmind.geoip.Location;
import com.maxmind.geoip.LookupService;


public class MergeAdjacentClusters{
	
	private static HashMap<Integer, Integer> ipToClusterID;
	private static HashMap<Integer, Integer> clusterIDToParent;
	private static HashMap<Integer, LatLon> clusterIDToLoc;
	private static Set<Integer> dnsLocClusters;
	private static LookupService maxMind;
	private static ArrayList<Adjacency>[] adjacency_table;
	
	// Fraction of adjacencies to merge an un-geoloc'd cluster to another
	private static final int ADJACENCY_MERGER_THRESHOLD = 80;

	//Distance (in kilometers) to consider "same" re: MaxMind locs.
	private static final double MAXMIND_DISTANCE_MERGER_THRESHOLD = 10;

	private static final int NUM_CLUSTERS = 44407;
	
	public static int getClusterID(int ip){
		Integer id = ipToClusterID.get(ip);
		if(id == null) return -1;
		while(clusterIDToParent.get(id) != null) id = clusterIDToParent.get(id);
		return id;
	}
	
	public static LatLon generateMaxMindLoc(Set<Integer> cluster){
		return null;
	}
	
	public static void printAdjacencies(){
		for(int i = 0; i < adjacency_table.length; i++){
			if(clusterIDToLoc.get(i) == null) continue;
			System.err.print(clusterIDToLoc.get(i) + " " + i + " ");
			if(adjacency_table[i] != null){
				for(Adjacency a : adjacency_table[i]){
					System.err.print(a + " ");
				}
			}
		}
	}
	
	public static int mergeClusters(int c1, int c2){
		System.err.println("Merging " + c1 + " and " + c2);
		if(c1 == c2) return c1;
		int parent; 
		int child;
		if(clusterIDToParent.get(c1) != null && clusterIDToParent.get(c2) == null){
			parent = c1;
			child = c2;
		}else if(clusterIDToParent.get(c2) != null && clusterIDToParent.get(c1) == null){
			parent = c2;
			child = c1;
		}else if(dnsLocClusters.contains(c1)){
			parent = c1;
			child = c2;
		}else if(dnsLocClusters.contains(c2)){
			parent = c2;
			child = c1;
		}else if(c1 < c2){
			parent = c1;
			child = c2;
		}else{
			parent = c2;
			child = c1;
		}
		
		clusterIDToParent.put(child, parent);
		for(Adjacency a : adjacency_table[child]){
			if(a.cluster1 == parent || a.cluster2 == parent){
				adjacency_table[parent].remove(a);
				continue;
			}
			
			int other;
			if(a.cluster1 == child){
				other = a.cluster2;
			}else other = a.cluster1;
		
			if(hasAdjacency(parent, other)){
				getAdjacency(parent,other).counts += a.counts;
				adjacency_table[other].remove(a);
			}else{
				if(a.cluster1 == child){
					a.cluster1 = parent;
				}else a.cluster2 = parent;
				adjacency_table[parent].add(a);
			}
		}
		
		adjacency_table[child] = null;
		clusterIDToLoc.remove(child);
		return parent;
	}
	
	public static boolean hasAdjacency(int c1, int c2){
		if(adjacency_table[c1] == null || adjacency_table[c2] == null) return false;
		for(Adjacency a : adjacency_table[c1]){
			if(a.cluster1 == c2 || a.cluster2 == c2){
				return true;
			}
		}
		return false;
	}
	
	public static Adjacency getAdjacency(int c1, int c2){
		if(adjacency_table[c1] == null) adjacency_table[c1] = new ArrayList<Adjacency>();
		if(adjacency_table[c2] == null) adjacency_table[c2] = new ArrayList<Adjacency>();

		for(Adjacency a : adjacency_table[c1]){
			if(a.cluster1 == c2 || a.cluster2 == c2){
				return a;
			}
		}
	//	System.err.println("Creating adjacency between " + c1 + " and " + c2);
		Adjacency a = new Adjacency(c1, c2);
		adjacency_table[c1].add(a);
		adjacency_table[c2].add(a);
		return a;
	}
	
	public static void addOneToAdjacency(int c1, int c2){
		Adjacency a = getAdjacency(c1,c2);
		a.counts++;
	}
	

	private static class Adjacency implements Comparable<Adjacency>{
		private int cluster1, cluster2, counts;
		public Adjacency(int cluster1, int cluster2){
			assert(cluster1 != cluster2);
			if(cluster2 < cluster1){
				int tmp = cluster2;
				cluster2 = cluster1;
				cluster1 = tmp;
			}
			this.cluster1 = cluster1;
			this.cluster2 = cluster2;
			counts = 0;
		}
		@Override
		public int compareTo(Adjacency o) {
			if(this.cluster1 == o.cluster1){
				return this.cluster2 - o.cluster2;
			}else return this.cluster1 - o.cluster1;
		}
		
		public String toString(){
			String s = "[" + cluster1 + " " + clusterIDToLoc.get(cluster1);
			s += " " + cluster2 + " " + clusterIDToLoc.get(cluster2);
			s += " " + counts;
			s += "]";
			return s;
		}
		
		public boolean equals(Adjacency o){
			return this.cluster1 == o.cluster1 && this.cluster2 == o.cluster2;
		}
	}
	
	public static void main(String[] args) throws IOException{
		init(args[0]);
			
		//Foreach adjacency file  
		for(int i = 1; i < args.length; i++){
			System.err.println("Reading " + args[i]);
			File adjacencyFile = new File(args[i]);
			Scanner adjacencies = new Scanner(adjacencyFile);
			 
			while(adjacencies.hasNextLine()){
				String line = adjacencies.nextLine();
				String[] vals = line.split(" ");
				if(vals.length < 2){
					System.err.println("ERR " + line);
				}
				int ip1 = Prefix.aton(vals[0]);
				int ip1Cluster = getClusterID(ip1);
				int ip2 = Prefix.aton(vals[1]);
				int ip2Cluster = getClusterID(ip2);
				if(ip1Cluster == -1 || ip2Cluster == -1 || ip1Cluster == ip2Cluster) continue;
				
				addOneToAdjacency(ip1Cluster, ip2Cluster);
			}
		}
		
		System.err.println("Done reading adjacencies");
		System.err.println("BANANDARAMFJAD:");
		//ipToClusterID.clear();
	//	printAdjacencies();
		
		//Merge where both have a DNS loc and there is an adjacency
		mergeWhereLocSameAndAdjacent();
		
		//For those without locations, if all their neighbors with locs are the same loc, just merge those.
		mergeWhereNoLocButAllNeighborsSameLoc();
		
		//Merge clusters of nodes that are adjacent and within a distance of eachother
		mergeWhereMaxMindLocCloseAndAdjacent();
		
		System.err.println("NUMBER OF LOC CLUSTERS " + clusterIDToLoc.keySet().size());
		int z = 0;
		for(int y = 0; y < adjacency_table.length; y++){
			if(adjacency_table[y] != null){
				z++;
			}
		}
		System.err.println("NUMBER OF CLUSTERS WITH ADJACENCIES: " + z);
		
		for(int i : ipToClusterID.keySet()){
			System.out.println(Prefix.ntoa(i) + " " + getClusterID(i) + " " + clusterIDToLoc.get(getClusterID(i)));
		}
	}
	
	public static void mergeWhereLocSameAndAdjacent(){
		boolean mergers = false;
		do{			
			mergers = false;
			Set<Integer> clustersWithLocs = new TreeSet<Integer>();
			clustersWithLocs.addAll(clusterIDToLoc.keySet());
			for(int i: clustersWithLocs){
				if(clusterIDToLoc.get(i) == null) continue;
				for(int j: clustersWithLocs){
					if(clusterIDToLoc.get(j) == null) continue;
					//System.err.println(i + " " + j + " " + (i != j) + " " + clusterIDToLoc.get(i).equals(clusterIDToLoc.get(j)) + " " + hasAdjacency(i,j));
					if(i != j && clusterIDToLoc.get(i).equals(clusterIDToLoc.get(j)) &&  hasAdjacency(i,j)){
						mergeClusters(i,j);
						mergers = true;
						break;
					}
				}
			}
		}while(mergers);
	}
	
	public static void mergeWhereNoLocButAllNeighborsSameLoc(){
		boolean mergers = false;
		do{
			mergers = false;
			for(int i = 0; i < adjacency_table.length; i++){
				//If this has a location (we already merged those) or if it has a parent (it no longer exists)
				if(clusterIDToParent.get(i) != null || clusterIDToLoc.get(i) != null) continue;
				if(adjacency_table[i] != null){
					ArrayList<Adjacency> neighbors = adjacency_table[i];
					
					if(neighbors.size() == 1){
						Adjacency a = neighbors.get(0);
						mergeClusters(a.cluster1, a.cluster2);
						continue;
					}
					
					Set<Integer> latlonneighbors = new HashSet<Integer>();
					for(Adjacency a : neighbors){
						int neighbor;
						if(a.cluster1 == i){
							neighbor = a.cluster2;
						}else neighbor = a.cluster1;
						
						if(clusterIDToLoc.get(neighbor) != null) latlonneighbors.add(neighbor);
					}
					
					if(latlonneighbors.size() > 1 || neighbors.size() == 1){
						LatLon first = null;
						for(Integer a : latlonneighbors){
							if(first == null) first = clusterIDToLoc.get(a);
							else if(clusterIDToLoc.get(a) != first) return; //didn't match can't merge
						}
						
						//Great they all were the same. Merge time.
						mergers = true;
						int parent = i;
						for(int mergeneighbor : latlonneighbors){
							parent = mergeClusters(parent, mergeneighbor);
						}
					}
				}
			}
			
		}while(mergers);
	}
	
	
	public static void mergeWhereMaxMindLocCloseAndAdjacent(){
		boolean mergers = false;
		addMaxMindLocsToDNSLocs();

		
		do{
			mergers = false;
			for(int i = 0; i < adjacency_table.length; i++){
				if(adjacency_table[i] == null) continue;
				Set<Integer> clustersWithinThreshold = new TreeSet<Integer>();
				for(Adjacency a : adjacency_table[i]){
					int neighbor;
					if(a.cluster1 == i){
						neighbor = a.cluster2;
					}else neighbor = a.cluster1;
					if(clusterIDToLoc.get(neighbor).distance(clusterIDToLoc.get(i)) < MAXMIND_DISTANCE_MERGER_THRESHOLD){
						clustersWithinThreshold.add(neighbor);
						mergers = true;
					}
				}
				int parent = i;
				for(int mergeneighbor : clustersWithinThreshold){
					parent = mergeClusters(parent, mergeneighbor);
				}
			}
			
			
		}while(mergers);
	}
		
	public static void addMaxMindLocsToDNSLocs(){
		HashMap<Integer, TreeSet<Integer>> clusterIDToIPSet = new HashMap<Integer, TreeSet<Integer>>();
		for(int ip : ipToClusterID.keySet()){
			int clust = ipToClusterID.get(ip);
			if(clusterIDToLoc.get(clust) == null){
				if(clusterIDToIPSet.get(clust) == null) clusterIDToIPSet.put(clust, new TreeSet<Integer>());
				clusterIDToIPSet.get(clust).add(ip);
			}
		}
		
		for(int id : clusterIDToIPSet.keySet()){
    		List<LatLon> locs = new ArrayList<LatLon>();
    		for(int ip : clusterIDToIPSet.get(id)){
    			Location l = maxMind.getLocation(Prefix.ntoa(ip));
    			if(l == null) continue;
    			LatLon ll = new LatLon(l.latitude, l.longitude);
    			locs.add(ll);
    		}
    		LatLon avg = ReGeolocClusters.averageLoc(locs);
    		clusterIDToLoc.put(id, avg);
		}
		
		
	}
	
	public static void init(String iPlaneClusters) throws IOException{

		/**
		 * Set up maxmind lookups.
		 */
		String sep = System.getProperty("file.separator");
	    String dir = "/work/justine";
	    String dbfile = dir + sep + "GeoLiteCity.dat"; 
	    maxMind = new LookupService(dbfile,LookupService.GEOIP_STANDARD);
	    //LookupService cl = new LookupService(dbfile,LookupService.GEOIP_MEMORY_CACHE);
	    
		ipToClusterID = new HashMap<Integer, Integer>();
		clusterIDToParent = new HashMap<Integer, Integer>();
		clusterIDToLoc = new HashMap<Integer, LatLon>();
		
		/**
		 * Set up clusters with DNS lookup geolocs (output by iPlane clustering)
		 */
		File clusterFile = new File(iPlaneClusters);
		Scanner ipClusterScanner = new Scanner(clusterFile);
		
		while(ipClusterScanner.hasNextLine()){
			String line = ipClusterScanner.nextLine();
			String[] vals = line.trim().split(" ");
			assert(vals.length == 4);
			int ip = Prefix.aton(vals[0]);
			int clusterID = Integer.parseInt(vals[1]);
			double lat = Double.parseDouble(vals[2]);
			double lon = Double.parseDouble(vals[3]);
			
			if(lat < 90 && lon < 180){
				clusterIDToLoc.put(clusterID, new LatLon(lat, lon));
			}
			
			ipToClusterID.put(ip,clusterID);
		}
		ipClusterScanner.close();
		
		dnsLocClusters = new TreeSet<Integer>();
		dnsLocClusters.addAll(clusterIDToLoc.keySet());
		
		adjacency_table = new ArrayList[NUM_CLUSTERS];

	    
	}
}
