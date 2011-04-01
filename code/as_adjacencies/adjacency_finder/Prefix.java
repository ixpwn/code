/**
 * Cool kids write their own IP Address classes rather than using the Java built-ins.
 * @author justine@eecs.berkeley.edu
 */
public class Prefix implements Comparable<Prefix>{
	private int ipAddress;
	private int prefix;
	
	/*
	 * In bass-ackwards format as created by Prefix.aton (sorry)
	 */
	public Prefix(int ipAddress, int prefix){
		this.ipAddress = ipAddress;
		this.prefix = prefix;
	}
	
	/*
	 * From standard string format: 1.2.3.4/32
	 */
	public Prefix(String pfx){
		String[] pfxparts = pfx.split("/");
		ipAddress = aton(pfxparts[0]);
		prefix = Integer.parseInt(pfxparts[1]); 
	}
	
	public Prefix(String ip, int prefix){
		this.ipAddress = aton(ip);
		if(prefix > 32) throw new IllegalArgumentException(prefix + " is not a legit v4 prefix!");
		this.prefix = prefix;
	}
	
	public int getipAddress(){
		return ipAddress;
	}
	
	public int getPrefixLen(){
		return prefix;
	}
	
	public boolean isMatch(int address){
		return ((address ^ ipAddress) << (32 - prefix)) == 0;
	}

	//network order is big-endian, java is little-endian, oh well fuck.
	public static int aton(String ip){
		//System.out.println(ip);
		int ipAddress = 0;
		String[] octets = ip.split("\\.");
		if(octets.length != 4) throw new IllegalArgumentException(ip + " is not an IP address, " + octets.length + "octets!");
		for(int i = 0; i < 4; i++){
			String octet = octets[i];
			int c = Integer.parseInt(octet);
			if(c > 255) throw new IllegalArgumentException(ip + " is not an IP address!");
			ipAddress += (c << (i * 8)); 
		}
		return ipAddress;
	}
	
	public static String ntoa(int ip){
		String address = "";
		for(int i = 0; i < 4; i++){
			address = address + (ip & 0x000000FF);
			ip = ip >>> 8;
			if(i < 3) address = address + ".";
		}
		return address;
	}
	
	public int getBit(int idx){
		//System.out.println(idx/8);
		if(idx > prefix) throw new IllegalArgumentException("You suck!");
		//return Math.abs((ipAddress >>> (idx)) % 2);
		return Math.abs(((ipAddress >>> ((idx / 8) * 8)) >>> (7 - (idx % 8))) % 2);
	}
	
	public boolean equals(Prefix other){
		if(other == null) return false;
		return isMatch(other.ipAddress) && this.prefix == other.prefix;
	}
	
	public String toString(){
		return ntoa(ipAddress) + "/" + prefix;
	}

	@Override
	public int compareTo(Prefix o) {
		
		return 0;
	}
}