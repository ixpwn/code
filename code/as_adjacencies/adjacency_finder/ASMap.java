import java.util.Arrays;
import java.util.HashMap;
import java.util.Scanner;


public class ASMap {

		private class PrefixNode{
			Prefix pfx;
			int ASN;
			PrefixNode one;
			PrefixNode zero;
		}
		
		private PrefixNode root;
		private HashMap<Integer, Integer> directMap;
		
		public ASMap(Scanner ASMapFile, Scanner IPASFile){
			root = new PrefixNode();
			directMap = new HashMap<Integer, Integer>();
			
			while(ASMapFile.hasNextLine()){
				String[] nextline = ASMapFile.nextLine().split(" ");
				assert(nextline.length == 2);
				
				Prefix pfx = new Prefix(nextline[0]);
				int ASN = 0;
				try{
					ASN = Integer.parseInt(nextline[1].split("_")[0]);
				}catch(NumberFormatException e){
					System.out.println(Arrays.toString(nextline));
					continue;
				}
				PrefixNode curNode = root;
				for(int i = 0; i < pfx.getPrefixLen(); i++){
					if(pfx.getBit(i) == 1){
						if(curNode.one == null) curNode.one = new PrefixNode();
						curNode = curNode.one;
					}else{
						if(curNode.zero == null) curNode.zero = new PrefixNode();
						curNode = curNode.zero;
					}
					if(curNode.pfx != null){
						System.out.println(pfx + " " + curNode.pfx);
						assert(curNode.pfx.isMatch(pfx.getipAddress()));
					}
				}
				curNode.pfx = pfx; 
				curNode.ASN = ASN;
			}
			
			while(IPASFile.hasNextLine()){
				String[] nextline = IPASFile.nextLine().split(" ");
				assert(nextline.length == 2);
				
				int address = Prefix.aton(nextline[0]);
				int ASN = Integer.parseInt(nextline[1]);
				directMap.put(address, ASN);
			}
		}
		
		public int getASN(Prefix pfx){
			Integer asn = directMap.get(pfx.getipAddress());
			if(asn != null){
				return asn;
			}else{
				int bestASN = 0;
				PrefixNode curNode = root;
				for(int i = 0; i < pfx.getPrefixLen() && curNode != null; i++){
					if(pfx.getBit(i) == 1){
						curNode = curNode.one;
					}else{
						curNode = curNode.zero;
					}
					if(curNode != null && curNode.pfx != null){
						assert(curNode.pfx.isMatch(pfx.getipAddress()));
						bestASN = curNode.ASN;
					}
					System.out.println(i + " " + pfx.getBit(i) + " " + bestASN);
				}
				//assert(bestASN != 0);
				return bestASN;
			}
		}
}
