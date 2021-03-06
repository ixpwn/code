#!/usr/bin/ruby

if !(ARGV.size == 9 or ARGV.size == 7)
  print "Usage: #{$0} -[zyxwvutsrd] -l <fp location file> -a <fp as file>"
  puts " -j <Justine's AS file> [-o <output>] "
  puts "-----"
  puts "    z CDF best edit distance b/t Justine's failure point and a Brice"
  puts "    y CDF best geo distance b/t Justine's failure point and a Brice"
  puts "    x CDF geo distance b/t pairs in graph z"
  puts "    w CDF edit distance b/t pairs in graph y"
  puts "    v Scatter plot of geo distance and best edit distance in graph z"
  puts "    u Scatter plot of geo distance and best edit distance in graph y"
  puts "    t CDF failure point degree"
  puts "    s CDF AS degree"
  puts "    r CDF of filure point degree in Justine's top biggest clusters, same number as Brice"
  puts "    d Use delete distance rather than edit distance"
  puts "    a fp_as.txt file"
  puts "    j Justine's AS cluster file"
  puts "    l fp_loc.txt file"
  puts "    o Front part to use for the output files. (Optional)"
  exit
end

#parse input
cdfED = ARGV[0].include?("z")
cdfGD = ARGV[0].include?("y")
cdfGDofED = ARGV[0].include?("x")
cdfEDofGD = ARGV[0].include?("w")
scatterGDvsED = ARGV[0].include?("v")
scatterEDvsGD = ARGV[0].include?("u")
cdfFPDegree = ARGV[0].include?("t")
cdfASDegree = ARGV[0].include?("s")
cdfFPTopDegree = ARGV[0].include?("r")
useDelDist = ARGV[0].include?("d")

i = 1

fpLocFilename = ""
fpAsFilename = ""
justineFilename = ""
outHeader = ""
while i < ARGV.size
  if ARGV[i] == '-a'
    fpAsFilename = ARGV[i+1]
  elsif ARGV[i] == '-j'
    justineFilename = ARGV[i+1]
  elsif ARGV[i] == '-o'
    outHeader = "#{ARGV[i+1]}_"
  elsif ARGV[i] == '-l'
    fpLocFilename = ARGV[i+1]
  end

  i+=2
end

if fpLocFilename == "" or fpAsFilename == "" or justineFilename == ""
  print "One of the needed file names given is empty loc:#{fpLocFilename} "
  puts "AS:#{fpAsFilename} Justine:#{justineFilename}"
  exit
end

#Struct need
LatLng = Struct.new(:lat, :lng)
FPInfo = Struct.new(:fp_id, :lat, :lng, :as_set)

#Needed variables
aryJfpInfo = Array.new
aryBfpInfo = Array.new
hshFPASSet = Hash.new{|h,k| h[k] = Hash.new(false)}
hshFPLatLng = Hash.new
delim = "\t"

#Open files
fpLocFile = File.open(fpLocFilename)
fpAsFile = File.open(fpAsFilename)
justineFile = File.open(justineFilename)

#Parse through fp_loc.txt
puts "Parsing: #{fpLocFilename}"
c = 0
fpLocFile.each{|line|
  c+=1
  if line =~ /^(.+)#{delim}.+#{delim}.+#{delim}(.+)#{delim}(.+)$/
    fp_id = $1
    lat = $2.to_f
    lng = $3.to_f

    hshFPLatLng[fp_id] = LatLng.new(lat,lng)
  else
    puts "SOMETHING WRONG! #{line}"
    exit
  end
}
puts "Parsing done of #{c} lines: #{fpLocFilename}"

#Parse through fp_as.txt
puts "Parsing: #{fpAsFilename}"
c = 0
fpAsFile.each{|line|
  c+=1
  if line =~ /(.+)#{delim}(.+)/
    fp_id = $1
    asn = $2

    hshFPASSet[fp_id][asn] = true
  else
    puts "Something wrong: #{line}"
    exit
  end
}
puts "Parsing done of #{c} lines: #{fpAsFilename}"

#Create Array of BfpInfo
hshFPASSet.each{|k,v|
  latlng = hshFPLatLng[k]
  aryBfpInfo.push(FPInfo.new(k, latlng.lat, latlng.lng, v))
}

def LatLongToString(lat, lng)
  lat = "#{lat.round + 90}"
  lng = "#{lng.round + 180}"

  if lat.size < 3
    (3 - lat.size).times{ lat = '0'+lat }
  end

  if lng.size < 3
    (3 - lng.size).times{ lng = '0'+lng }
  end

  lat+lng
end

#Parse through justine's file
puts "Parsing: #{justineFilename}"
latLngCount = Hash.new(0)
c = 0
justineFile.each{|line|
  c+=1
  aryLine = line.split(" ")
  lat = aryLine[0].to_f
  lng = aryLine[1].to_f
  i = 2
  hsh = Hash.new(false)
  while i < aryLine.size
    hsh[aryLine[i]] = true
    i+=1
  end

  latLng = LatLongToString(lat, lng)
  fp_id = "#{latLng}#{latLngCount[latLng]}"
  latLngCount[latLng]+=1

  aryJfpInfo.push(FPInfo.new(fp_id, lat, lng, hsh))
}
puts "Parsing done of #{c} lines: #{justineFilename}"

# latLngCount.each{|k,v| print "#{k} => #{v} "
#  if v > 9 then print "\n" end}
# puts aryJfpInfo
# exit

#Function: return edit distance between two sets
def editDist(hsh1, hsh2)
  dist = 0
  hsh1.each_key{|k|
    if !hsh2.has_key?(k)
      dist+=1
    end
  }
  hsh2.each_key{|k|
    if !hsh1.has_key?(k)
      dist+=1
    end
  }

  dist
end

#Function: return deletion distance from first set to second set
def deleteDist(hsh1, hsh2)
  dist = 0
  hsh1.each_key{|k|
    if !hsh2.has_key?(k)
      dist+=1
    end
  }

  dist
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

#Needed stat variables
EditGeoDist = Struct.new(:j_fp_id, :b_fp_id, :edit, :geo)
FPDegree = Struct.new(:lat, :lng, :fp_id, :degree)
ASDegree = Struct.new(:as, :degree)
FPValuePair = Struct.new(:fp_id, :value)
aryEDist = Array.new
aryGDist = Array.new
aryJFPDegree = Array.new
aryBFPDegree = Array.new
aryJASDegree = Array.new
aryBASDegree = Array.new

#Collect statistics
puts "Collecting statistics"
if cdfFPDegree or cdfFPTopDegree
  puts "  getting fp degree stats"
  aryJfpInfo.each{|j|
    c = 0
    j.as_set.each{|k,v| if v then c+=1 end}
    aryJFPDegree.push(FPDegree.new(j.lat, j.lng, "#{j.lat}#{j.lng}", c))
  }
  aryBfpInfo.each{|b|
    c = 0
    b.as_set.each{|k,v| if v then c+=1 end}
    aryBFPDegree.push(FPDegree.new(b.lat, b.lng, b.fp_id, c))
  }
end

if cdfASDegree
  puts "  getting as degree stats"
  hshASToSetJ = Hash.new{|h,k| h[k] = Hash.new(false)}
  hshASToSetB = Hash.new{|h,k| h[k] = Hash.new(false)}
  
  aryJfpInfo.each{|j|
    j.as_set.each{|k,v|
      if v
        hshASToSetJ[k][j.fp_id] = true
      end
    }
  }
  hshASToSetJ.each{|k,v|
    aryJASDegree.push(ASDegree.new(k, v.size))
  }

  aryBfpInfo.each{|b|
    b.as_set.each{|k,v|
      if v
        hshASToSetB[k][b.fp_id] = true
      end
    }
  }
  hshASToSetB.each{|k,v|
    aryBASDegree.push(ASDegree.new(k, v.size))
  }
end

if cdfED or cdfGD or cdfGDofED or cdfEDofGD or scatterGDvsED or scatterEDvsGD
  print "  getting edit and geo distance stats"
  puts " O(NM) N=#{aryJfpInfo.size} M=#{aryBfpInfo.size}"
  aryJfpInfo.each{ |j|
    minEDist = 99999.0
    minEGDistAry = Array.new
    minGDist = 20000 #Farthest two points on earth can be in km
    minGEDistAry = Array.new
    
    aryBfpInfo.each{|b|
      eDist = nil;
      if useDelDist
        eDist = deleteDist(j.as_set, b.as_set)
      else
        eDist = editDist(j.as_set, b.as_set)
      end
      gDist = geoDist(j.lat, j.lng, b.lat, b.lng)
      if eDist == minEDist
        minEGDistAry.push(FPValuePair.new(b.fp_id, gDist))
      elsif eDist < minEDist
        minEDist = eDist
        minEGDistAry.clear
        minEGDistAry.push(FPValuePair.new(b.fp_id, gDist))
      end

      if gDist == minGDist
        minGEDistAry.push(FPValuePair.new(b.fp_id, eDist))
      elsif gDist < minGDist
        minGDist = gDist
        minGEDistAry.clear
        minGEDistAry.push(FPValuePair.new(b.fp_id, eDist))
      end
    }

    minEGBFp_id = minEGDistAry[0].fp_id
    minEGDist = minEGDistAry[0].value
    minEGDistAry.each{|p|
      if p.value < minEGDist
        minEGDist = p.value
        minEGBFp_id = p.fp_id
      end
    }

    minGBFp_id = minGEDistAry[0].fp_id
    minGEDist = minGEDistAry[0].value
    minGEDistAry.each{|p|
      if p.value < minGEDist
        minGEDist = p.value
        minGBFp_id = p.fp_id
      end
    }

    aryEDist.push(EditGeoDist.new(j.fp_id, minEGBFp_id, minEDist, minEGDist))
    aryGDist.push(EditGeoDist.new(j.fp_id, minGBFp_id, minGEDist, minGDist))
  }
end
puts "Done collecting statistics"

#Create graphs
puts "Creating data files and graphs"
edDist = if useDelDist then "Delete" else "Edit" end
edfname = if useDelDist then "d" else "e" end
if cdfED
  fname = "cdf_#{edfname}d"
  puts "  making #{fname}"
  aryEDist.sort!{|a,b| a.edit <=> b.edit}
  output = File.new("#{outHeader}#{fname}.data", "w+")
  c = 0.0
  size = aryEDist.size
  aryEDist.each{|e|
    output.puts("#{e.edit} #{c/size}")
    c+=1.0
  }
  output.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Best #{edDist} Distance between a Justine to Brice failure point\""
  gnu.puts "set xlabel \"#{edDist} Distance\""
  gnu.puts "set ylabel \"CDF\""
  gnu.puts "set logscale x"
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 with lines notitle"
  gnu.puts plot
  gnu.close
end

if cdfGD
  fname = "cdf_gd"
  puts "  making #{fname}"
  aryGDist.sort!{|a,b| a.geo <=> b.geo}
  output = File.new("#{outHeader}#{fname}.data", "w+")
  c = 0.0
  size = aryGDist.size
  aryGDist.each{|e|
    output.puts("#{e.geo} #{c/size}")
    c+=1.0
  }
  output.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Best Geo Distance between a Justine to Brice failure point\""
  gnu.puts "set xlabel \"Geo Distance (kilometers)\""
  gnu.puts "set ylabel \"CDF\""
  gnu.puts "set logscale x"
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 with lines notitle"
  gnu.puts plot
  gnu.close
end

if cdfGDofED
  fname = "cdf_gd_of_#{edfname}d"
  puts "  making #{fname}"
  aryEDist.sort!{|a,b| a.geo <=> b.geo}
  output = File.new("#{outHeader}#{fname}.data", "w+")
  c = 0.0
  size = aryEDist.size
  aryEDist.each{|e|
    output.puts("#{e.geo} #{c/size}")
    c+=1.0
  }
  output.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Geo Distance of Best #{edDist} Distance\""
  gnu.puts "set xlabel \"Geo Distance (kilomters)\""
  gnu.puts "set ylabel \"CDF\""
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 with lines notitle"
  gnu.puts plot
  gnu.close
end

if cdfEDofGD
  fname = "cdf_#{edfname}d_of_gd"
  puts "  making #{fname}"
  aryGDist.sort!{|a,b| a.edit <=> b.edit}
  output = File.new("#{outHeader}#{fname}.data", "w+")
  c = 0.0
  size = aryGDist.size
  aryGDist.each{|e|
    output.puts("#{e.edit} #{c/size}")
    c+=1.0
  }
  output.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"#{edDist} Distance of Best Geo Distance\""
  gnu.puts "set xlabel \"#{edDist} Distance\""
  gnu.puts "set ylabel \"CDF\""
  gnu.puts "set logscale x"
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 with lines notitle"
  gnu.puts plot
  gnu.close
end

if scatterGDvsED
  fname = "scatter_gd_#{edfname}d"
  puts "  making #{fname}"
  output = File.new("#{outHeader}#{fname}.data", "w+")
  c = 0.0
  size = aryEDist.size
  aryEDist.each{|e|
    output.puts("#{e.edit+(rand*0.9)} #{e.geo}")
    c+=1.0
  }
  output.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Geo Distance of Best #{edDist} Distance\""
  gnu.puts "set xlabel \"#{edDist} Distance (with jitter)\""
  gnu.puts "set ylabel \"Geo Distance (kilometers)\""
  gnu.puts "set logscale x"
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 notitle"
  gnu.puts plot
  gnu.close
end

if scatterEDvsGD
  fname = "scatter_#{edfname}d_gd"
  puts "  making #{fname}"
  output = File.new("#{outHeader}#{fname}.data", "w+")
  c = 0.0
  size = aryGDist.size
  aryGDist.each{|e|
    output.puts("#{e.geo} #{e.edit+(rand)}")
    c+=1.0
  }
  output.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"#{edDist} Distance of Best Geo Distance\""
  gnu.puts "set xlabel \"Geo Distance (kilometers)\""
  gnu.puts "set ylabel \"#{edDist} Distance (with jitter)\""
  gnu.puts "set logscale x"
  gnu.puts "set logscale y"
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 notitle"
  gnu.puts plot
  gnu.close
end

if cdfFPDegree
  fname = "cdf_fp_degree"
  puts "  making #{fname}"
  aryJFPDegree.sort!{|a,b| a.degree <=> b.degree}
  outputJ = File.new("#{outHeader}#{fname}_j.data", "w+")
  c = 0.0
  size = aryJFPDegree.size
  aryJFPDegree.each{|e|
    outputJ.puts("#{e.degree} #{c/size}")
    c+=1.0
  }
  outputJ.close

  aryBFPDegree.sort!{|a,b| a.degree <=> b.degree}
  outputB = File.new("#{outHeader}#{fname}_b.data", "w+")
  c = 0.0
  size = aryBFPDegree.size
  aryBFPDegree.each{|e|
    outputB.puts("#{e.degree} #{c/size}")
    c+=1.0
  }
  outputB.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Failure Point Degree\""
  gnu.puts "set xlabel \"Failure Point Degree\""
  gnu.puts "set ylabel \"CDF\""
  gnu.puts "set logscale x"
  plot = "plot \"#{outHeader}#{fname}_j.data\" using 1:2 with lines "
  plot << "title \"Justine data\""
  plot << ", \"#{outHeader}#{fname}_b.data\" using 1:2 with lines "
  plot << "title \"Brice data\""
  gnu.puts plot
  gnu.close
end

if cdfASDegree
  fname = "cdf_as_degree"
  puts "  making #{fname}"
  aryJASDegree.sort!{|a,b| a.degree <=> b.degree}
  outputJ = File.new("#{outHeader}#{fname}_j.data", "w+")
  c = 0.0
  size = aryJASDegree.size
  aryJASDegree.each{|e|
    outputJ.puts("#{e.degree} #{c/size}")
    c+=1.0
  }
  outputJ.close

  aryBASDegree.sort!{|a,b| a.degree <=> b.degree}
  outputB = File.new("#{outHeader}#{fname}_b.data", "w+")
  c = 0.0
  size = aryBASDegree.size
  aryBASDegree.each{|e|
    outputB.puts("#{e.degree} #{c/size}")
    c+=1.0
  }
  outputB.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"AS Degree\""
  gnu.puts "set xlabel \"AS Degree\""
  gnu.puts "set ylabel \"CDF\""
  gnu.puts "set logscale x"
  plot = "plot \"#{outHeader}#{fname}_j.data\" using 1:2 with lines "
  plot << "title \"Justine data\""
  plot << ", \"#{outHeader}#{fname}_b.data\" using 1:2 with lines "
  plot << "title \"Brice data\""
  gnu.puts plot
  gnu.close
end

if cdfFPTopDegree
  fname = "cdf_fp_top_degree"
  puts "  making #{fname}"
  aryJFPDegree.sort!{|a,b| a.degree <=> b.degree}
  outputJ = File.new("#{outHeader}#{fname}_j.data", "w+")
  aryBFPDegree.sort!{|a,b| a.degree <=> b.degree}
  outputB = File.new("#{outHeader}#{fname}_b.data", "w+")
  c = 0.0
  size = aryBFPDegree.size
  offset = aryJFPDegree.size - size
  size.times{|i|
    outputB.puts("#{aryBFPDegree[i].degree} #{c/size}")
    outputJ.puts("#{aryJFPDegree[offset+i].degree} #{c/size}")
    c+=1.0
  }

  outputJ.close
  outputB.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Top Failure Point Degree in Justine's and All Brice\""
  gnu.puts "set xlabel \"Failure Point Degree\""
  gnu.puts "set ylabel \"CDF\""
  gnu.puts "set logscale x"
  plot = "plot \"#{outHeader}#{fname}_j.data\" using 1:2 with lines "
  plot << "title \"Justine data\""
  plot << ", \"#{outHeader}#{fname}_b.data\" using 1:2 with lines "
  plot << "title \"Brice data\""
  gnu.puts plot
  gnu.close

end

puts "Done creating data files and graphs"

#Close files
fpLocFile.close
fpAsFile.close
justineFile.close
