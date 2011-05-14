#!/usr/bin/ruby

def assert(value, str)
  if !value
    puts "ASSERT Fail: #{str}"
    exit
  end
end

if !(ARGV.size == 3 or ARGV.size == 5 or ARGV.size == 7)
  print "Usage: #{$0} "
  print "-[zy]"
  print "-g <giant long file>"
  print "[-i <file of tier1 asns>] "
  print "[-o <output header>] "
  puts ""
  puts "-----"
  puts "    g Giant file of format: <asn1> <asn2> <lat> <lng> <cell ID> <cell lat> <cell lng>"
  puts "    i List of Tier 1 asns, format per line: <asn>"
  puts "    o Header of the output files"
  puts "-----"
  puts "    z Scatter plot of an AS's cell count to neighbor count"
  puts "    y CDF of number of cells for AS peering pairs"
  exit
end

bScatterCellNeigh = ARGV[0].include?("z")
bCdfCellPair = ARGV[0].include?("y")

bigFilename = ""
tierFilename = ""
outHeader = ""
i = 1
while i < ARGV.size
  if ARGV[i] == "-g"
    bigFilename = ARGV[i+1]
  elsif ARGV[i] == "-i"
    tierFilename = ARGV[i+1]
  elsif ARGV[i] == "-o"
    outHeader = ARGV[i+1] + "_"
  end
  i+=2
end

if bigFilename == ""
  puts "Missing file giant file:#{bigFilename}"
  exit
end

if bCdfCellPair and tierFilename == ""
  print "Need the tier1 file to creat the CDF of number of cells for "
  puts "AS peering pairs"
  exit
end

LatLng = Struct.new(:lat, :lng)
AsnPair = Struct.new(:asn1, :asn2)
hshAsnNeighSet = Hash.new{|h,k| h[k] = Hash.new(false)}
hshAsnCellSet = Hash.new{|h,k| h[k] = Hash.new(false)}
hshPairCellSet = Hash.new{|h,k| h[k] = Hash.new(false)}
aryTier = Array.new
aryBackbone = Array.new

puts "Parse: #{bigFilename}"
c = 0
bigFile = File.open(bigFilename)
bigFile.each{|line|
  c += 1
  
  if line =~ /^(.+) (.+) (.+) (.+) (.+) (.+) (.+)/
    asn1 = $1.to_i
    asn2 = $2.to_i
    aLatLng = LatLng.new($3.to_f, $4.to_f)
    cid = $5.to_i
    cLatLng = LatLng.new($6.to_f, $7.to_f)

    hshAsnNeighSet[asn1][asn2] = true
    hshAsnNeighSet[asn2][asn1] = true
    hshAsnCellSet[asn1][cLatLng] = true
    hshAsnCellSet[asn2][cLatLng] = true
    
    if bCdfCellPair
      if asn1 > asn2
        t = asn2
        asn2 = asn1
        asn1 = t
      end
      p = AsnPair.new(asn1, asn2)
      hshPairCellSet[p][cLatLng] = true
    end
  else
    assert(false, "Not match: #{line}")
  end
}
bigFile.close
puts "DONE Parse: #{bigFilename}"

if bCdfCellPair
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

  hshAsnNeighSet.each{|asn, set|
    if set.size >= 250
      if !aryTier.include?(asn)
        aryBackbone.push(asn)
      end
    end
  }
end

puts "Creating data files and graphs"

assert(hshAsnNeighSet.size > 0, "Asn to neighbor set is emtpy")
assert(hshAsnCellSet.size > 0, "Asn to cell set is empty")

if bScatterCellNeigh
  fname = "scatter_cell_neigh"
  puts "  making #{fname}"

  hshCCellNeigh = Hash.new(0)
  Pair = Struct.new(:cell, :neigh)
  
  hshAsnNeighSet.each{|asn,neighSet|
    cNeigh = 0
    neighSet.each{|k,v| if v then cNeigh+=1 end}
    cCell = 0
    hshAsnCellSet[asn].each{|k,v| if v then cCell+=1 end}
    
    hshCCellNeigh[Pair.new(cCell, cNeigh)] += 1
  }
  
  output = File.new("#{outHeader}#{fname}.data","w+")
  hshCCellNeigh.each{|pair,count|
    output.puts("#{pair.cell} #{pair.neigh} #{count}")
  }
  output.close

  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  #Figure out trendline
  gnu.puts "f(x) = m*x+b"
  gnu.puts "fit f(x) \"#{outHeader}#{fname}.data\" using 1:2 via m,b"
  gnu.puts "g(x) = x"
  #Plot the graph
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Scatter plot of ASN information\""
  gnu.puts "set xlabel \"Cells an ASN is in\""
  gnu.puts "set ylabel \"Number of Neighbors\""
  gnu.puts "set logscale x"
  gnu.puts "set logscale y"#; set yrange [0.1:10000]"
  plot = "plot \"#{outHeader}#{fname}.data\" using 1:2 notitle with points"
  plot += ", f(x) title \"Best fit\""
  plot += ", g(x) title \"x = y\""
  gnu.puts plot
  gnu.close
end

if bCdfCellPair
  fname = "cdf_cell_peering"
  puts "  making #{fname}"

  ary11 = Array.new
  arybb = Array.new
  aryb2 = Array.new
  ary22 = Array.new
  ary0 = Array.new
  
  hshPairCellSet.each{|pair, cellSet|
    c = 0
    cellSet.each{|k,v| if v then c+= 1 end}
    ary0.push(c)

    a1IsT1 = aryTier.include?(pair.asn1)
    a1IsB = aryBackbone.include?(pair.asn1) or a1IsT1
    a1IsT2 = !(a1IsT1 or a1IsB)

    a2IsT1 = aryTier.include?(pair.asn2)
    a2IsB = aryBackbone.include?(pair.asn2) or a2IsT1
    a2IsT2 = !(a2IsT1 or a2IsB)

    if a1IsT1 and a2IsT1
      ary11.push(c)
    elsif a1IsB and a2IsB
      arybb.push(c)
    elsif a1IsT2 and a1IsT2
      ary22.push(c)
    elsif (a1IsB and a2IsT2) or (a1IsT2 and a2IsB)
      aryb2.push(c)
    end
  }

  ary11.sort!
  arybb.sort!
  aryb2.sort!
  ary22.sort!
  ary0.sort!

  output11 = File.new("#{outHeader}#{fname}_t11.data","w+")
  outputbb = File.new("#{outHeader}#{fname}_tbb.data","w+")
  outputb2 = File.new("#{outHeader}#{fname}_tb2.data","w+")
  output22 = File.new("#{outHeader}#{fname}_t22.data","w+")
  output0 = File.new("#{outHeader}#{fname}_t0.data","w+")

  size = ary11.size*1.0
  ary11.size.times{|i|
    output11.puts("#{ary11[i]} #{i/size}")
  }
  size = arybb.size*1.0
  arybb.size.times{|i|
    outputbb.puts("#{arybb[i]} #{i/size}")
  }
  size = aryb2.size*1.0
  aryb2.size.times{|i|
    outputb2.puts("#{aryb2[i]} #{i/size}")
  }
  size = ary22.size*1.0
  ary22.size.times{|i|
    output22.puts("#{ary22[i]} #{i/size}")
  }
  size = ary0.size*1.0
  ary0.size.times{|i|
    output0.puts("#{ary0[i]} #{i/size}")
  }

  output11.close
  output22.close
  outputb2.close
  outputbb.close
  output0.close


  gnu = Kernel.open("| gnuplot", "w+")
  gnu.puts "set terminal postscript eps color font \"Times, 22\""
  gnu.puts "set output \"#{outHeader}#{fname}.ps\""
  gnu.puts "set title \"Number of Cells a ASN pair peer in\""
  gnu.puts "set xlabel \"Number of Cells a ASN pair peer in\""
  gnu.puts "set ylabel \"CDF\""
  gnu.puts "set logscale x 2"
#  gnu.puts "set logscale y"
  plot = "plot"
  plot += " \"#{outHeader}#{fname}_t11.data\" using 1:2 title \"T1 to T1\" with lines"
  plot += ","
  plot += " \"#{outHeader}#{fname}_tbb.data\" using 1:2 title \"B to B\" with lines"
  plot += ","
  plot += " \"#{outHeader}#{fname}_tb2.data\" using 1:2 title \"B to T2\" with lines"
  plot += ","
  plot += " \"#{outHeader}#{fname}_t22.data\" using 1:2 title \"T2 to T2\" with lines"
  plot += ","
  plot += " \"#{outHeader}#{fname}_t0.data\" using 1:2 title \"All\" with lines"
  gnu.puts plot
  gnu.close
end
