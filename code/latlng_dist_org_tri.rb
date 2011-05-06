#!/usr/bin/ruby

def assert(value, str)
  if !value
    puts "ASSERT Fail: #{str}"
    exit
  end
end

if !(ARGV.size == 4)
  print "Usage: #{$0} "
  print "-t <adjacency lat/lng to triangle lat/lng file> "
  print "-o <output file name header> "
  puts
  exit
end

triFilename = ""
outHeader = ""
i = 0
while i < ARGV.size
  if ARGV[i] == '-t'
    triFilename = ARGV[i+1]
  elsif ARGV[i] == '-o'
    outHeader = "#{ARGV[i+1]}_"
  end

  i+=2
end

if triFilename == ""
  puts "I need a file here."
  exit
end


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

def xyDist(x1,y1,x2,y2)
  xd = x1-x2
  yd = y1-y2

  Math.sqrt((xd*xd)+(yd*yd))
end

aryGeoDist = Array.new
aryLLDist = Array.new

puts "Parse: #{triFilename}"
triFile = File.open(triFilename)
triFile.each{|line|
  if line =~ /^(.+) (.+) (.+) (.+)/
    aLat = $1.to_f
    aLng = $2.to_f
    tLat = $3.to_f
    tLng = $4.to_f

    assert(!$1.include?(" "), "Adjacency lat includes a space! #{$1}")
    assert(!$2.include?(" "), "Adjacency lng includes a space! #{$2}")
    assert(!$3.include?(" "), "Triangle lat includes a space! #{$3}")
    assert(!$4.include?(" "), "Triangle lat includes a space! #{$4}")

    aryGeoDist.push(geoDist(aLat,aLng,tLat,tLng))
    aryLLDist.push(xyDist(aLat,aLng,tLat,tLng))
  else
    assert(false, "Not match: #{line}")
  end
}
triFile.close
puts "DONE Parse: #{triFilename}"

fname = "org_tri_geo"
puts "Creating #{fname}"
output = File.new("#{outHeader}#{fname}.data","w+")
aryGeoDist.sort!
c = 0.0
size = aryGeoDist.size
aryGeoDist.each{|e|
  output.puts "#{e} #{c/size}"
  c+=1.0
}
output.close
gnu = Kernel.open("| gnuplot", "w+")
gnu.puts "set terminal postscript eps color font \"Times, 22\""
gnu.puts "set output \"#{outHeader}#{fname}.ps\""
gnu.puts "set title \"Geo Distance between original point and triangle center\""
gnu.puts "set xlabel \"Geo Distance (km)\""
gnu.puts "set ylabel \"CDF\""
plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 with lines notitle"
gnu.puts plot
gnu.close
puts "Done creating #{fname}"

fname = "org_tri_xy"
puts "Creating #{fname}"
output = File.new("#{outHeader}#{fname}.data","w+")
aryLLDist.sort!
c = 0.0
size = aryLLDist.size
aryLLDist.each{|e|
  output.puts "#{e} #{c/size}"
  c+=1.0
}
output.close
gnu = Kernel.open("| gnuplot", "w+")
gnu.puts "set terminal postscript eps color font \"Times, 22\""
gnu.puts "set output \"#{outHeader}#{fname}.ps\""
gnu.puts "set title \"XY Distance between original point and triangle center\""
gnu.puts "set xlabel \"XY Distance\""
gnu.puts "set ylabel \"CDF\""
plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 with lines notitle"
gnu.puts plot
gnu.close
puts "Done creating #{fname}"
