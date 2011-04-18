import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.util.Set;
import java.util.TreeSet;

public class ASMapClusters {
	public static void main(String[] args) throws FileNotFoundException{
		assert(args.length == 3);

		Scanner prefixMap = new Scanner(new File(args[0]));
		Scanner IPMap = new Scanner(new File(args[1]));
		
		ASMap map = new ASMap(prefixMap, IPMap);
		
		Scanner IPsToMap = new Scanner(new File(args[2]));

                Set<Integer> ASNs = new TreeSet<Integer>();
		while(IPsToMap.hasNextLine()){
			
			Scanner line = new Scanner(IPsToMap.nextLine());
		        String latlons = line.next() + " " + line.next() + " ";
                        while(line.hasNext()){
                            String str = line.next();
                            ASNs.add(map.getASN(new Prefix(str + "/32")));
                        }
                        if(ASNs.size() > 1){
                            System.out.print(latlons);
                            for(int asn : ASNs){
                                System.out.print(asn + " ");
                            }
                            System.out.println();
                        }
                        ASNs = new TreeSet<Integer>();
                }
	}
}
