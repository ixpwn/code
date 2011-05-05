#!/usr/bin/ruby

onlyGenGraphs = false

#Check input
if (ARGV.size < 7 or ARGV[0].include?("h"))
  print "Usage: #{$0} -[zyxwvtm] [-h] [-u] [-b] "
  print "-a <fp as file> "
  print "-l <fp location file> "
  print "-j <Justine's AS file> "
  print "[-e <edit distance threshold>] "
  print "[-d <degree threshold>] "
  print "[-g <geo distance threshold>] "
  print "[-o <output>] "
  puts ""
  puts "----- What files to generate -----"
  puts "    z CDF of edit distance"
  puts "    y CDF of geo distance"
  puts "    x CDF size of unmatched failure points"
  puts "    w Scatter plot of edit vs geo"
  puts "    v Sanity check file"
  puts "    t Histogram number of clusters used x time of times"
  puts "    m Matching file b.fp_id j.fp_id"
  puts "---- Options -----"
  puts "    a Failure point to AS file"
  puts "    b One Brice point to many Justine (default: One Justine to many Brice), file name will include '_bj' if used"
  puts "    d Cut off for the failure point degree (default 1), file name will include _d# if defined"
  puts "    e edit distance threshold for the graphs (default 0.0)"
  puts "    g geo distance threshold for the graphs (default 20000)"
  puts "    h print this text for help"
  puts "    j Justine's AS cluster file"
  puts "    l Failure point location information file"
  puts "    o Front part to use for the output files (default \"\")"
  puts "    u Use Justine distance (default is Jaccard), file name will include '_jd' if used"
  exit
end

#Parse input
bGenCdfEdit = ARGV[0].include?("z")
bGenCdfGeo = ARGV[0].include?("y")
bGenCdfSize = ARGV[0].include?("x")
bGenScatter = ARGV[0].include?("w")
bGenSanityFile = ARGV[0].include?("v")
bGenMatchingFile = ARGV[0].include?("m")
bGenHistUsedClust = ARGV[0].include?("t")

if !(bGenCdfEdit or bGenCdfGeo or bGenCdfSize or bGenScatter or
     bGenSanityFile or bGenMatchingFile or bGenHistUsedClust)
  puts "No file to generate specified!"
  exit
end

i = 1

fpLocFilename = ""
fpAsFilename = ""
justineFilename = ""
outHeader = ""
geoThresh = 20000
editThresh = 0.0
jDegThresh = 1
useJacDist = true
useJtoB = true
while i < ARGV.size
  if ARGV[i] == '-a'
    fpAsFilename = ARGV[i+1]
  elsif ARGV[i] == '-j'
    justineFilename = ARGV[i+1]
  elsif ARGV[i] == '-o'
    outHeader = "#{ARGV[i+1]}_"
  elsif ARGV[i] == '-l'
    fpLocFilename = ARGV[i+1]
  elsif ARGV[i] == '-g'
    geoThresh = ARGV[i+1].to_f
  elsif ARGV[i] == '-e'
    editThresh = ARGV[i+1].to_f
  elsif ARGV[i] == '-d'
    jDegThresh = ARGV[i+1].to_i
  elsif ARGV[i] == '-u'
    useJacDist = false
    i-=1
  elsif ARGV[i] == '-b'
    useJtoB = false
    i-=1
  end

  i+=2
end

if fpLocFilename == "" or fpAsFilename == "" or justineFilename == ""
  print "One of the needed file names given is empty loc:#{fpLocFilename} "
  puts "AS:#{fpAsFilename} Justine:#{justineFilename}"
  exit
end

if !useJacDist
  outHeader += "jd_"
end

if !useJtoB
  outHeader += "bj_"
end

if jDegThresh != 1
  outHeader += "d#{jDegThresh}_"
end

if !onlyGenGraphs
#Struct need
LatLng = Struct.new(:lat, :lng)
FPInfo = Struct.new(:fp_id, :lat, :lng, :as_set)

#Needed variables
hshJfpInfo = Hash.new
hshBfpInfo = Hash.new
hshFPASSet = Hash.new{|h,k| h[k] = Hash.new(false)}
hshFPLatLng = Hash.new
delim = "\t"

#Function: Create beginning of fp_id based on lat and long
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

#Function: return edit distance between two sets
def editDist(hshJ, hshB, jac)
  inter = 0.0
  hshJ.each_key{|k|
    if hshB.has_key?(k)
      inter+=1.0
    end
  }

  if jac
    cUnion = hshJ.size+hshB.size-inter
  else
    cUnion = hshJ.size
  end

  (inter/cUnion)
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
  if v.size > jDegThresh
    hshBfpInfo[k] = FPInfo.new(k, latlng.lat, latlng.lng, v)
  end
}

#Parse through justine's file
puts "Parsing: #{justineFilename}"
c = 0
justineFile.each{|line|
  c+=1
  aryLine = line.split(" ")
  fp_id = aryLine[0]
  lat = aryLine[1].to_f
  lng = aryLine[2].to_f
  i = 3
  hsh = Hash.new(false)
  while i < aryLine.size
    hsh[aryLine[i]] = true
    i+=1
  end

  if hsh.size > jDegThresh
    hshJfpInfo[fp_id] = FPInfo.new(fp_id, lat, lng, hsh)
  end
}
puts "Parsing done of #{c} lines: #{justineFilename}"

#Find best editand geo distance within threshold
EditGeoDist = Struct.new(:j_fp_id, :b_fp_id, :edit, :geo)
FPValuePair = Struct.new(:fp_id, :value)
FPDegree = Struct.new(:lat, :lng, :fp_id, :degree)
aryBestEGPair = Array.new
usedJClusters = Hash.new(0)
usedBClusters = Hash.new(0)

#Collect statistics
puts "Collecting statistics"
print "  getting edit and geo distance stats"
puts " O(NM) N=#{hshJfpInfo.size} M=#{hshBfpInfo.size}"

if useJtoB
  hshJfpInfo.each{ |kj, j|
    maxEDist = 0.0
    aryFpGeoDist = Array.new
    
    hshBfpInfo.each{|kb, b|
      eDist = editDist(j.as_set, b.as_set, useJacDist)
      gDist = geoDist(j.lat, j.lng, b.lat, b.lng)
      
      if eDist >= editThresh and gDist <= geoThresh
        if eDist == maxEDist
          aryFpGeoDist.push(FPValuePair.new(b.fp_id, gDist))
        elsif eDist > maxEDist
          maxEDist = eDist
          aryFpGeoDist.clear
          aryFpGeoDist.push(FPValuePair.new(b.fp_id, gDist))
        end
      end
    }
    
    if aryFpGeoDist.size > 0
      minFp_id = aryFpGeoDist[0].fp_id
      minGeoDist = aryFpGeoDist[0].value
      aryFpGeoDist.each{|p|
        if p.value < minGeoDist
          minGeoDist_ = p.value
          minFp_id = p.fp_id
        end
      }
      aryBestEGPair.push(EditGeoDist.new(j.fp_id, minFp_id, maxEDist, minGeoDist))
      
      usedJClusters[j.fp_id]+=1
      usedBClusters[minFp_id]+=1
    end
  }
else
  hshBfpInfo.each{ |kb, b|
    maxEDist = 0.0
    aryFpGeoDist = Array.new
    
    hshJfpInfo.each{|kj, j|
      eDist = editDist(j.as_set, b.as_set, useJacDist)
      gDist = geoDist(j.lat, j.lng, b.lat, b.lng)
      
      if eDist >= editThresh and gDist <= geoThresh
        if eDist == maxEDist
          aryFpGeoDist.push(FPValuePair.new(j.fp_id, gDist))
        elsif eDist > maxEDist
          maxEDist = eDist
          aryFpGeoDist.clear
          aryFpGeoDist.push(FPValuePair.new(j.fp_id, gDist))
        end
      end
  }
    
    if aryFpGeoDist.size > 0
      minFp_id = aryFpGeoDist[0].fp_id
      minGeoDist = aryFpGeoDist[0].value
      aryFpGeoDist.each{|p|
        if p.value < minGeoDist
          minGeoDist_ = p.value
          minFp_id = p.fp_id
        end
      }
      aryBestEGPair.push(EditGeoDist.new(minFp_id, b.fp_id, maxEDist, minGeoDist))
      
      usedJClusters[minFp_id]+=1
      usedBClusters[b.fp_id]+=1
    end
  }
end

#Get FP degree for unused failure points in Justine data
puts "  getting fp degree stats"
aryJFPDegree = Array.new
aryBFPDegree = Array.new

hshJfpInfo.each{|kj, j|
  if !usedJClusters.has_key?(j.fp_id)
    c = 0
    j.as_set.each{|k,v| if v then c+=1 end}
    aryJFPDegree.push(FPDegree.new(j.lat, j.lng, "#{j.lat}#{j.lng}", c))
  end
}
hshBfpInfo.each{|kb, b|
  if !usedBClusters.has_key?(b.fp_id)
    c = 0
    b.as_set.each{|k,v| if v then c+=1 end}
    aryBFPDegree.push(FPDegree.new(b.lat, b.lng, b.fp_id, c))
  end
}
puts "Done collecting statistics"

#Generate manual text file
def getASAry(set)
  ary = Array.new
  set.each{|k,v|
    if v then ary.push(k.to_i) end
  }
  ary.sort!
end

if bGenSanityFile
  puts "Creating sanity checking file"
  output = File.new("#{outHeader}sanity_check_#{editThresh}_#{geoThresh}.txt", "w+")
  aryBestEGPair.sort!{|a,b| a.edit <=> b.edit}
  aryBestEGPair.each{|e|
    b = hshBfpInfo[e.b_fp_id]
    j = hshJfpInfo[e.j_fp_id]
    output.puts "B(#{b.lat},#{b.lng}) J(#{j.lat},#{j.lng})"
    output.puts "B.fp_id #{e.b_fp_id} J.fp_id #{e.j_fp_id}"
    output.puts "edit #{e.edit} geo #{e.geo}"
    output.print "B:"
    getASAry(b.as_set).each{|i| output.print " #{i}"}
    output.puts ""
    output.print "J:"
    getASAry(j.as_set).each{|i| output.print " #{i}"}
    output.puts ""
    output.puts ""
  }
  output.close
  puts "Done creating sanity check file"
end

if bGenMatchingFile
  puts "Creating matching file"
  output = File.new("#{outHeader}matching_#{editThresh}_#{geoThresh}.txt", "w+")
  aryBestEGPair.each{|e|
    output.puts "#{e.b_fp_id} #{e.j_fp_id}"
  }
  puts "Done creating matching file"
end

end #onlyGenGraphs

#Generate CDF of edit distance
puts "Creating data files and graphs"
if bGenCdfEdit
  fname = "thresh_edit_#{editThresh}_#{geoThresh}"
  puts "  making #{fname}"
  if !onlyGenGraphs
    output = File.new("#{outHeader}#{fname}.data", "w+")
    aryBestEGPair.sort!{|a,b| a.edit <=> b.edit}
    c = 0.0
    size = aryBestEGPair.size
    aryBestEGPair.each{|e|
      output.puts("#{e.edit} #{c/size}")
      c+=1.0
    }
    output.close
  end
  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Best Edit Distance with Threshold Edit:#{editThresh} Geo:#{geoThresh}\""
  gnu.puts "set xlabel \"Edit Distance\""
  gnu.puts "set ylabel \"CDF\""
  gnu.puts "set xrange [0:1]"
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 with lines notitle"
  gnu.puts plot
  gnu.close
end

if bGenHistUsedClust
  fname = "hist_clust_use_#{editThresh}_#{geoThresh}"
  puts "  making #{fname}"
  if !onlyGenGraphs
    HistPoint = Struct.new(:count, :j_count, :b_count)
    output = File.new("#{outHeader}#{fname}.data", "w+")
    hshJHist = Hash.new(0)
    hshBHist = Hash.new(0)
    max = 0
    jMax = 0
    usedJClusters.each{|k,v|
      if v > max then max = v end
      if v > jMax then jMax = v end
      hshJHist[v]+=1
      hshBHist[v] = 0
    }
    bMax = 0
    usedBClusters.each{|k,v|
      if v > max then max = v end
      if v > bMax then bMax = v end
      hshBHist[v]+=1
    }

    ary = Array.new
    hshBHist.each{|k,v|
      ary.push(HistPoint.new(k, hshJHist[k], v))      
    }
    ary.sort!{|a,b| a.count <=> b.count}
    ary.each{|e|
      output.puts("#{e.count} #{e.j_count} #{e.b_count}")
    }
    # max.times{|j|
    #   i = j+1
    #   output.puts("#{i} #{hshJHist[i]} #{hshBHist[i]}")
    # }
  end
  output.close
  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Histogram Number of Clusters Used X times:#{editThresh} Geo:#{geoThresh}\""
  gnu.puts "set xlabel \"Number of times matched\""
  gnu.puts "set style data histogram"
  gnu.puts "set style histogram cluster gap 1"
  gnu.puts "set xtic rotate by -45"
  plot = "plot "
  if jMax > 1
    plot += "\"#{outHeader}#{fname}.data\" using 2:xtic(1) title \"Justine Data\""
  end
  if bMax > 1
    if jMax > 1
      plot += ", "
    end
    plot += "\"#{outHeader}#{fname}.data\" using 3:xtic(1) title \"Brice Data\""
  end
  gnu.puts plot
  gnu.close
end

if bGenCdfGeo
  fname = "thresh_geo_#{editThresh}_#{geoThresh}"
  puts "  making #{fname}"
  if !onlyGenGraphs
    aryBestEGPair.sort!{|a,b| a.geo <=> b.geo}
    output = File.new("#{outHeader}#{fname}.data", "w+")
    c = 0.0
    size = aryBestEGPair.size
    aryBestEGPair.each{|e|
      output.puts("#{e.geo} #{c/size}")
      c+=1.0
    }
    output.close
  end
  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Geo Distance with Threshold Edit:#{editThresh} Geo:#{geoThresh}\""
  gnu.puts "set xlabel \"Geo Distance (km)\""
  gnu.puts "set ylabel \"CDF\""
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 with lines notitle"
  gnu.puts plot
  gnu.close
end

if bGenScatter
  fname = "thresh_scatter_#{editThresh}_#{geoThresh}"
  puts "  making #{fname}"
  if !onlyGenGraphs
    aryBestEGPair.sort!{|a,b| a.geo <=> b.geo}
    output = File.new("#{outHeader}#{fname}.data", "w+")
    aryBestEGPair.each{|e|
      output.puts("#{e.edit} #{e.geo}")
      c+=1.0
    }
    output.close
  end

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Scatter plot with Threshold Edit:#{editThresh} Geo:#{geoThresh}\""
  gnu.puts "set xlabel \"Edit Distance\""
  gnu.puts "set ylabel \"Geo Distance (km)\""
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 notitle"
  gnu.puts plot
  gnu.close
end

#Generate CDF of size of clusters not matched
if bGenCdfSize
  fname = "cdf_size_#{editThresh}_#{geoThresh}"
  puts "  making #{fname}"
  if aryJFPDegree.size > 0 or aryBFPDegree.size > 0
    if !onlyGenGraphs
      aryJFPDegree.sort!{|a,b| a.degree <=> b.degree}
      output = File.new("#{outHeader}#{fname}_j.data", "w+")
      c = 0.0
      size = aryJFPDegree.size
      aryJFPDegree.each{|e|
        output.puts("#{e.degree} #{c/size}")
        c+=1.0
      }
      output.close
      aryBFPDegree.sort!{|a,b| a.degree <=> b.degree}
      output = File.new("#{outHeader}#{fname}_b.data", "w+")
      c = 0.0
      size = aryBFPDegree.size
      aryBFPDegree.each{|e|
        output.puts("#{e.degree} #{c/size}")
        c+=1.0
      }
      output.close
    end
    
    gnu = Kernel.open("| gnuplot", "w+")
    gnu.puts "set terminal postscript eps color font \"Times, 22\""
    gnu.puts "set output \"#{outHeader}#{fname}.ps\""
    gnu.puts "set title \"Degree of Unused Failure Points\""
    gnu.puts "set xlabel \"FP Degree\""
    gnu.puts "set ylabel \"CDF\""
    gnu.puts "set logscale x"
    plot = "plot "
#    if aryJFPDegree.size > 0
    plot << "\"#{outHeader}#{fname}_j.data\" using 1:2 with lines "
    plot << "title \"Justine data\""
#    end
#    if aryBFPDegree.size > 0
#      if aryJFPDegree.size > 0
    plot << ", "
#      end
    plot << "\"#{outHeader}#{fname}_b.data\" using 1:2 with lines "
    plot << "title \"Brice data\""
#    end
    gnu.puts plot
    gnu.close
  else
    puts "    Both sets of points were all used."
  end
end

puts "Done creating data files and graphs"

#Close files
if !onlyGenGraphs
fpLocFile.close
fpAsFile.close
justineFile.close
end
