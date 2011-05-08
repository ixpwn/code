#!/usr/bin/ruby

def assert(value, str)
  if !value
    puts "ASSERT Fail: #{str}"
    exit
  end
end

if !(ARGV.size == 7 or ARGV.size == 9)
  print "Usage: #{$0} "
  print "-[zy]"
  print "-t <adjacency lat/lng to triangle lat/lng file> "
  print "-a <asn adjacency to lat/lng file> "
  print "-i <file of tier1 asns> "
  print "-o <output header> "
  puts ""
  puts "-----"
  puts "    z Scatter plot of an AS's triangle count to neighbor count"
  puts "    y CCDF of number of triangles for AS peering pairs"
  exit
end

bScatterTriNeigh = ARGV[0].include?("z")
bCcdfTriPair = ARGV[0].include?("y")

triFilename = ""
adjFilename = ""
tierFilename = ""
outHeader = ""
i = 1
while i < ARGV.size
  if ARGV[i] == "-t"
    triFilename = ARGV[i+1]
  elsif ARGV[i] == "-a"
    adjFilename = ARGV[i+1]
  elsif ARGV[i] == "-i"
    tierFilename = ARGV[i+1]
  elsif ARGV[i] == "-o"
    outHeader = ARGV[i+1] + "_"
  end
  i+=2
end

if triFilename == "" or adjFilename == ""
  print "Missing file triangle:#{triFilename} adj:#{adjFilename} "
  puts "out:#{outFilename}"
  exit
end

if bCcdfTriPair and tierFilename == ""
  print "Need the tier1 file to creat the CCDF of number of triangles for "
  puts "AS peering pairs"
  exit
end

LatLng = Struct.new(:lat, :lng)
AsnPair = Struct.new(:asn1, :asn2)
hshLocTri = Hash.new
hshAsnNeighSet = Hash.new{|h,k| h[k] = Hash.new(false)}
hshAsnTriSet = Hash.new{|h,k| h[k] = Hash.new(false)}
hshPairTriSet = Hash.new{|h,k| h[k] = Hash.new(false)}
aryTier = Array.new

puts "Parse: #{triFilename}"
triFile = File.open(triFilename)
c = 0
triFile.each{|line|
  c += 1
  if line =~ /^(.+) (.+) (.+) (.+)/
    aLat = $1.to_f
    aLng = $2.to_f
    tLat = $3.to_f
    tLng = $4.to_f

    assert(!$1.include?(" "), "Adjacency lat includes a space! #{$1}")
    assert(!$2.include?(" "), "Adjacency lng includes a space! #{$2}")
    assert(!$3.include?(" "), "Triangle lat includes a space! #{$3}")
    assert(!$4.include?(" "), "Triangle lat includes a space! #{$4}")

    hshLocTri[LatLng.new(aLat,aLng)] = LatLng.new(tLat,tLng)
  else
    assert(false, "Not match: #{line}")
  end
}
triFile.close
puts "DONE Parse #{c} lines: #{triFilename}"

puts "Parse: #{adjFilename}"
cMissingLatLng = 0
c = 0
adjFile = File.open(adjFilename)
adjFile.each{|line|
  c += 1
  
  if line =~ /^(.+) (.+) (.+) (.+)/
    asn1 = $1.to_i
    asn2 = $2.to_i
    lat = $3.to_f
    lng = $4.to_f

    latLng = LatLng.new(lat,lng)

    tLatLng = hshLocTri[latLng]

    if tLatLng != nil
      hshAsnNeighSet[asn1][asn2] = true
      hshAsnNeighSet[asn2][asn1] = true
      hshAsnTriSet[asn1][tLatLng] = true
      hshAsnTriSet[asn2][tLatLng] = true
      
      if bCcdfTriPair
        if asn1 > asn2
          t = asn2
          asn2 = asn1
          asn1 = t
        end
        p = AsnPair.new(asn1, asn2)
        hshPairTriSet[p][tLatLng] = true
      end
    else
      cMissingLatLng += 1
    end
    
  else
    assert(false, "Not match: #{line}")
  end
}
adjFile.close
puts "DONE Parse: #{adjFilename}"

if bCcdfTriPair
  puts "Parse: #{tierFilename}"
  input = File.open(tierFilename)
  c = 0
  input.each{|line|
    c += 1
    if line =~ /^(.+)$/
      tier = $1.to_i

      aryTier.push(tier)
    else
      assert(false, "Not match: #{line}")
    end
  }
  input.close
  puts "DONE Parse #{c} lines: #{tierFilename}"
end

puts "Creating data files and graphs"

if bScatterTriNeigh
  fname = "scatter_tri_neigh"
  puts "  making #{fname}"
  output = File.new("#{outHeader}#{fname}.data","w+")
  hshAsnNeighSet.each{|asn,neighSet|
    cNeigh = 0
    neighSet.each{|k,v| if v then cNeigh+=1 end}
    cTri = 0
    hshAsnTriSet[asn].each{|k,v| if v then cTri+=1 end}
    
    output.puts("#{cTri} #{cNeigh}")
  }
  output.close
  
  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  #Figure out trendline
  gnu.puts "f(x) = m*x+b"
  gnu.puts "fit f(x) \"#{outHeader}#{fname}.data\" using 1:2 via m,b"
  #Plot the graph
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Scatter plot of ASN information\""
  gnu.puts "set xlabel \"Triangles an ASN is in\""
  gnu.puts "set ylabel \"Number of Neighbors\""
  gnu.puts "set logscale x"
  gnu.puts "set logscale y"
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 notitle with points"
  plot += ", f(x) notitle"
  gnu.puts plot
  gnu.close
end

if bCcdfTriPair
  fname = "ccdf_tri_peering"
  puts "  making #{fname}"

  ary11 = Array.new
  ary12 = Array.new
  ary22 = Array.new
  ary0 = Array.new
  
  hshPairTriSet.each{|pair, triSet|
    c = 0
    triSet.each{|k,v| if v then c+= 1 end}
    ary0.push(c)
    if aryTier.include?(pair.asn1) and aryTier.include?(pair.asn2)
      ary11.push(c)
    elsif aryTier.include?(pair.asn1) or aryTier.include?(pair.asn2)
      ary12.push(c)
    else
      ary22.push(c)
    end
  }

  ary11.sort!
  ary12.sort!
  ary22.sort!
  ary0.sort!

  output11 = File.new("#{outHeader}#{fname}_t11.data","w+")
  output12 = File.new("#{outHeader}#{fname}_t12.data","w+")
  output22 = File.new("#{outHeader}#{fname}_t22.data","w+")
  output0 = File.new("#{outHeader}#{fname}_t0.data","w+")

  size = ary11.size*1.0
  ary11.size.times{|i|
    output11.puts("#{ary11[i]} #{1-(i/size)}")
  }
  size = ary12.size*1.0
  ary12.size.times{|i|
    output12.puts("#{ary12[i]} #{1-(i/size)}")
  }
  size = ary22.size*1.0
  ary22.size.times{|i|
    output22.puts("#{ary22[i]} #{1-(i/size)}")
  }
  size = ary0.size*1.0
  ary0.size.times{|i|
    output0.puts("#{ary0[i]} #{1-(i/size)}")
  }

  output11.close
  output12.close
  output22.close
  output0.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Number of Triangles a ASN pair peer in\""
  gnu.puts "set xlabel \"Number of Triangles a ASN pair peer in\""
  gnu.puts "set ylabel \"CCDF\""
  gnu.puts "set logscale x"
  gnu.puts "set logscale y"
  plot = "plot"
  plot += " \"#{outHeader}#{fname}_t11.data\" using 1:2 title \"T1 to T1\" with lines"
  plot += ","
  plot += " \"#{outHeader}#{fname}_t12.data\" using 1:2 title \"T1 to T2\" with lines"
  plot += ","
  plot += " \"#{outHeader}#{fname}_t22.data\" using 1:2 title \"T2 to T2\" with lines"
  plot += ","
  plot += " \"#{outHeader}#{fname}_t0.data\" using 1:2 title \"All\" with lines"
  gnu.puts plot
  gnu.close
end
