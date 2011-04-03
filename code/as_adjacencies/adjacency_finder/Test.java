
public class Test {
	public static void main(String[] args){

		
        System.out.println(new Prefix("254.0.0.0/32").bitString());                
        Prefix p = new Prefix("216.47.128.0/18");
        System.out.println(p.isMatch(Prefix.aton("216.47.159.241")));
        System.out.println(new Prefix("216.47.128.0/32").bitString());
        System.out.println(new Prefix("216.47.159.241/32").bitString());
        System.exit(-1);

	}
}
