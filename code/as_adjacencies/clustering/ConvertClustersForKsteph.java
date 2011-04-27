import java.io.File;
import java.io.FileNotFoundException;
import java.util.HashMap;
import java.util.Scanner;
import java.util.Set;
import java.util.TreeSet;


public class ConvertClustersForKsteph {
	public static void main(String[] args) throws FileNotFoundException{
	    
		File inputFile = new File(args[2]);
	    Scanner s = new Scanner(inputFile);
	    
	    HashMap<Integer, Set<Integer>> idToIPSet = new HashMap<Integer, Set<Integer>>();
	    HashMap<Integer, LatLon> idToLoc = new HashMap<Integer, LatLon>();
	    
	    while(s.hasNextLine()){
	    	String[] split = s.nextLine().split(" ");
	    	int curid = Integer.parseInt(split[1]);
	    	if(idToIPSet.get(curid) == null) idToIPSet.put(curid, new TreeSet<Integer>());
	    	idToIPSet.get(curid).add(Prefix.aton(split[0]));
	    	if(idToLoc.get(curid) == null) idToLoc.put(curid, new LatLon(Double.parseDouble(split[2]), Double.parseDouble(split[3]))); 
	    }
	    
	    ASMap asmap = new ASMap(new Scanner(new File(args[0])), new Scanner(new File(args[1])));
	    
	    for(int id : idToIPSet.keySet()){
	    	Set<Integer> asns = new TreeSet<Integer>();
	    	
	    	for(int ip : idToIPSet.get(id)){
	    		asns.add(asmap.getASN(new Prefix(ip, 32)));
	    	}
	    	if(asns.size() > 1){
	    		System.err.println(asns.size());
	    		System.out.println(idToLoc.get(id) + " " + asns.toString());
	    	}
	    }
	}
}
