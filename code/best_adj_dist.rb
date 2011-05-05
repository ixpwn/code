#!/usr/bin/ruby


def assert(value, str)
  if !value
    puts "ASSERT Fail: #{str}"
    exit
  end
end

#Files need: fp_as, fp_loc, justine's
if !(ARGV.size == 8 or ARGV.size == 10)
  print "Usage: #{$0} -l <fp location file> -i <ixp peering file>"
  print "-f <fp_id to ixp file> "
  puts " -j Justine's asn pair and (lat,lng)> [-o <output>] "
  puts "-----"
  puts "    f fp_brice.txt file"
  puts "    i ixp-peering.txt file"
  puts "    l fp_loc.txt file"
  puts "    j Justine's AS cluster file"
  puts "    o Front part to use for the output files. (Optional)"
  exit
end

fpBriceFilename = ""
fpLocFilename = ""
peeringFilename = ""
justineFilename = ""
outHeader = ""
i = 0
while i < ARGV.size
  if ARGV[i] == '-i'
    peeringFilename = ARGV[i+1]
  elsif ARGV[i] == '-j'
    justineFilename = ARGV[i+1]
  elsif ARGV[i] == '-f'
    fpBriceFilename = ARGV[i+1]
  elsif ARGV[i] == '-o'
    outHeader = "#{ARGV[i+1]}_"
  elsif ARGV[i] == '-l'
    fpLocFilename = ARGV[i+1]
  end

  i+=2
end

if fpLocFilename == "" or peeringFilename == "" or justineFilename == "" or
    fpBriceFilename == ""
  print "One of the needed file names given is empty loc:#{fpLocFilename} "
  puts "AS:#{peeringFilename} Brice:#{fpBriceFilename} Justine:#{justineFilename}"
  exit
end

#Structs
IdLatLng = Struct.new(:ident, :lat, :lng)
BJLatLngDist = Struct.new(:b_id, :b_lat, :b_lng, :j_id, :j_lat, :j_lng, :dist)
IdAsnDist = Struct.new(:b_id, :j_id, :asn1, :asn2, :dist)

#Variables
cUnmatchedJ = 0  #Count number of justince points not match anything
hshBLatLng = Hash.new
hshFpIxp = Hash.new
hshBAsn = Hash.new{|h,k| h[k] = Hash.new(false)}
hshBAsnPLatLng = Hash.new{|h,k| h[k] = Hash.new{|h2,k2| h2[k2] = Array.new}}
hshJAsnPLatLng = Hash.new{|h,k| h[k] = Hash.new{|h2,k2| h2[k2] = Array.new}}
aryBestDistAsnP = Array.new

#Parse through fp_loc make: fp_id -> (fp_id,lat,lng)
puts "Parsing: #{fpLocFilename}"
c = 0
delim = "\t"
fpLocFile = File.open(fpLocFilename)
fpLocFile.each{|line|
  c+=1
  if line =~ /^(.+)#{delim}.+#{delim}.+#{delim}(.+)#{delim}(.+)$/
    fp_id = $1.strip
    lat = $2.to_f
    lng = $3.to_f

    hshBLatLng[fp_id] = IdLatLng.new(fp_id,lat,lng)
  else
    puts "SOMETHING WRONG! line #{c} #{line}"
    exit
  end
}
fpLocFile.close
puts "Parsing done of #{c} lines: #{fpLocFilename}"

puts "Parsing: #{fpBriceFilename}"
fpBriceFile = File.open(fpBriceFilename)
c = 0
fpBriceFile.each{|line|
  c+=1
  if line =~ /(.+)#{delim}(.+)/
    fp_id = $1.strip
    ixp_id = $2.strip

    hshFpIxp[ixp_id] = fp_id
  else
    assert(false, "Bad parse: #{line}")
  end
}
puts "Parsing done of #{c} lines: #{fpBriceFilename}"

#Use Brice/PeeringDb data and make (asn1,asn2) -> [(fp_id,lat,lng)...]
puts "Parsing: #{peeringFilename}"
c = 0
delim = " "
peeringFile = File.open(peeringFilename)
peeringFile.each{|line|
  c+=1
  if line =~ /^(\S+)#{delim}(\S+)#{delim}(\S+)#{delim}.+/
    ixp_id = $1.strip
    asn1 = $2.to_i
    asn2 = $3.to_i

    fp_id = hshFpIxp[ixp_id]
    assert(fp_id != nil, "#{ixp_id} doesn't match to anything.")
    hshBAsnPLatLng[asn1][asn2].push(hshBLatLng[fp_id])
    hshBAsnPLatLng[asn2][asn1].push(hshBLatLng[fp_id])
  else
    assert(false, "Bad parse: #{line}")
  end
}
puts "Parsing done of #{c} lines: #{peeringFilename}"
#hshBAsnPLatLng.each{|asn1,h| h.each{|asn2,l| l.each{|e| puts "#{asn1} #{asn2} #{e.lat} #{e.lng}"}}}

#Parse through Justine's file and make (asn1,asn2) -> [(inc_id,lat,lng)...]
puts "Parsing: #{justineFilename}"
justineFile = File.open(justineFilename)
c = 0
inc_id = 0
justineFile.each{|line|
  c+=1
  delim = " "
  if line =~ /^(.+)#{delim}(.+)#{delim}(.+)#{delim}(.+)$/
    asn1 = $1.to_i
    asn2 = $2.to_i
    lat = $3.to_f
    lng = $4.to_f

    hshJAsnPLatLng[asn1][asn2].push(IdLatLng.new(inc_id, lat, lng))
    
    inc_id += 1
  else
    puts "SOMETHING WRONG line #{c} : #{line}"
    exit
  end
}
justineFile.close
jLen = c
puts "Parsing done of #{c} lines: #{justineFilename}"

#Function: return geo distance
RAD_PER_DEG = 0.017453293
Rmiles = 3956
Rkm = 6371

def geoDist(lat1,lng1,lat2,lng2)
  dlng = lng2 - lng1
  dlat = lat2 - lat1

  dlng_rad = dlng * RAD_PER_DEG
  dlat_rad = dlat * RAD_PER_DEG
 
  lat1_rad = lat1 * RAD_PER_DEG
  lng1_rad = lng1 * RAD_PER_DEG
 
  lat2_rad = lat2 * RAD_PER_DEG
  lng2_rad = lng2 * RAD_PER_DEG

  a = (Math.sin(dlat_rad/2))**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) *
    (Math.sin(dlng_rad/2))**2
  c = 2 * Math.atan2( Math.sqrt(a), Math.sqrt(1-a))

  dMi = Rmiles * c          # delta between the two points in miles
  dKm = Rkm * c             # delta in kilometers
end

#Go through Justine list
print "Finding best distance of everything! This may take a while: N*? "
puts "N(#{jLen}) ?(?)"
hshJAsnPLatLng.each{|asn1,h1|
  h1.each{|asn2,listJ|
    listB = hshBAsnPLatLng[asn1][asn2]
    if listB.size > 0
      distList = Array.new
      #Creat Hash of ids
      hshJ = Hash.new(false)
      hshB = Hash.new(false)
      listB.each{|b| hshB[b.ident] = true}
      #Find geo distance between all (lat,lng) pairs
      # list [(fp_id,latF,lngF, inc_id, latJ, lngJ, dist)...]
      listJ.each{|j|
        hshJ[j.ident] = true
        listB.each{|b|
          distList.push(BJLatLngDist.new(b.ident,b.lat,b.lng,
                                         j.ident,j.lat,j.lng,
                                         geoDist(b.lat,b.lng,j.lat,j.lng)))
        }
      }

      #Sort by dist
      distList.sort!{|a,b| a.dist <=> b.dist}
      
      #Go through list, remove from Hashmaps of IDs when have unused pairs,
      # add to list [(fp_id,inc_id,dist,asn1,asn2)...]
      c = 0
      distList.each{|d|
        if hshB[d.b_id] and hshJ[d.j_id]
          aryBestDistAsnP.push(IdAsnDist.new(d.b_id,d.j_id,asn1,asn2,d.dist))
          hshB[d.b_id] = false
          hshJ[d.j_id] = false
          c+=1
          if c >= listJ.size
            break
          end
        end
      }
    end
  }
}
puts "Done finding data"

puts "Making CDF graphs"
fname = "cdf_adj_dist"
aryBestDistAsnP.sort!{|a,b| a.dist <=> b.dist}
output = File.new("#{outHeader}#{fname}.data", "w+")
size = aryBestDistAsnP.size
c = 0.0
aryBestDistAsnP.each{|e|
  output.puts("#{e.dist} #{c/size}")
  c+=1.0
}
output.close

gnu = Kernel.open("| gnuplot", "w+")
gnu.puts "set terminal postscript eps color font \"Times, 22\""
gnu.puts "set output \"#{outHeader}#{fname}.ps\""
gnu.puts "set title \"Best Geo Distance between Adjacent points to Brice\""
gnu.puts "set xlabel \"Geo Distance (kilometers)\""
gnu.puts "set ylabel \"CDF\""
gnu.puts "set logscale x"
#gnu.puts "set logscale y"
plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 with lines notitle"
gnu.puts plot
gnu.close
puts "Done making graph"
