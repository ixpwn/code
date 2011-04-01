import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;


public class FindBorderRouters {
	public static void main(String[] args) throws FileNotFoundException{
		assert(args.length == 3);
		
		Scanner prefixMap = new Scanner(new File(args[0]));
		Scanner IPMap = new Scanner(new File(args[1]));
		
		ASMap map = new ASMap(prefixMap, IPMap);
		
		Scanner IPsToMap = new Scanner(new File(args[2]));
		
		while(IPsToMap.hasNextLine()){
			Scanner traceroute = new Scanner(IPsToMap.nextLine());
			String prevIP = traceroute.next();
			int prevASN = map.getASN(new Prefix(prevIP + "/32"));
			while(traceroute.hasNext()){
				String curIP = traceroute.next().trim();
				//System.out.println("[" + curIP + "]");
				int curASN = map.getASN(new Prefix(curIP + "/32"));
				if(curASN != prevASN && curASN != 0 && prevASN != 0){
					System.out.println(prevASN + " " + curASN + " " + prevIP + " " + curIP);
				}
				prevIP = curIP;
				prevASN = curASN;
			}
		}
	}
}