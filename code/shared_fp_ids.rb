#!/usr/bin/ruby

#Check input
if (ARGV.size < 3)
  print "Usage: #{$0} <asn1> <asn2> "
  print "[-a <fp as file> -l <fp loc file>] "
  print "[-d <degree threshold>] "
  print "[-j <Justine's AS file>] "
  print "[-o <output>] "
  puts ""
  puts "Outputs how many failure points are between asn1 and asn2."
  puts "----"
  puts "    a Brice or Peerdingdb failure point to AS file"
  puts "    d Cut off for the failure point degree (default 1), file name will include _d# if defined"
  puts "    j Justine's AS cluster file"
  puts "    l Failure point location information file"
  puts "    o If present will output the fp_id's that are between asn1 and asn2 to this output file"
  exit
end

asn1 = ARGV[0].to_i
asn2 = ARGV[1].to_i
fpAsFilename = ""
fpLocFilename = ""
justineFilename = ""
outHeader = ""
bMakeOutfile = false
degThresh = 1
i = 2
while i < ARGV.size
  if ARGV[i] == '-a'
    fpAsFilename = ARGV[i+1]
  elsif ARGV[i] == '-d'
    degThresh = ARGV[i+1].to_i
  elsif ARGV[i] == '-j'
    justineFilename = ARGV[i+1]
  elsif ARGV[i] == '-l'
    fpLocFilename = ARGV[i+1]
  elsif ARGV[i] == '-o'
    outHeader = "#{ARGV[i+1]}"
    bMakeOutfile = true
  end

  i+=2
end

if (fpAsFilename == "" or fpLocFilename == "") and justineFilename == ""
  puts "Need a file to parse"
  exit
end

if degThresh != 1
  outHeader += "_d#{jDegThresh}"
end

#Parse input
#Needed variables
LatLng = Struct.new(:lat, :lng)
hshASN1FPSet = Hash.new(false)
hshASN2FPSet = Hash.new(false)
hshFPLatLng = Hash.new
delim = "\t"

#Parse through fp_loc.txt
if fpLocFilename != ""
  puts "Parsing: #{fpLocFilename}"
  c = 0
  fpLocFile = File.open(fpLocFilename)
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
end

if fpAsFilename != ""
  puts "Parsing fp_as: #{fpAsFilename}"
  hshFPASSet = Hash.new{|h,k| h[k] = Hash.new(false)}
  input = File.open(fpAsFilename)
  c = 0
  input.each{|line|
    c+=1
    if line =~ /^([^#{delim}]+)#{delim}([^#{delim}]+)$/
      fp_id = $1
      asn = $2.to_i

      hshFPASSet[fp_id][asn] = true
    else
      puts "Something wrong: #{line}"
      exit
    end
  }

  tmp = Hash.new
  hshFPASSet.each{|k,v|
    if v.size > degThresh
      tmp[k] = v
    end
  }
  hshFPASSet = tmp

  hshFPASSet.each{|fp_id, set|
    set.each{|asn, v|
      if v
        if asn == asn1
          hshASN1FPSet[fp_id] = true
        elsif asn == asn2
          hshASN2FPSet[fp_id] = true
        end
      end
    }
  }

  input.close
  puts "Parsing done of #{c} lines: #{fpAsFilename}"
else
  puts "Parsing Justine: #{justineFilename}"
  input = File.open(justineFilename)
  c = 0
  input.each{|line|
    c+=1
    aryLine = line.split(" ")
    fp_id = aryLine[0]
    lat = aryLine[1].to_f
    lng = aryLine[2].to_f
    i = 3
    hsh = Hash.new(false)
    while i < aryLine.size
      hsh[aryLine[i].to_i] = true
      i+=1
    end
    
    if hsh.size > degThresh
      hshFPLatLng[fp_id] = LatLng.new(lat,lng)
      hsh.each{|asn, v|
        if v
          if asn == asn1
            hshASN1FPSet[fp_id] = true
          elsif asn == asn2 
            hshASN2FPSet[fp_id] = true
          end
        end
      }
    end
  }
  input.close
  puts "Parsing done of #{c} lines: #{justineFilename}"
end

#Check asns
if hshASN1FPSet.size == 0
  puts "#{asn1} is not in the graph"
end
if hshASN2FPSet.size == 0
  puts "#{asn2} is not in the graph"
end

#Compare two sets
arySharedFP = Array.new
hshASN1FPSet.each{|fp_id, v|
  if v
    if hshASN2FPSet[fp_id]
      arySharedFP.push(fp_id)
    end
  end
}

puts "SHARED FAILURE POINTS: #{arySharedFP.size}"

#Output file if specified
if bMakeOutfile
puts "Making output file"
  output = File.new("#{outHeader}.shared_fp","w+")
  arySharedFP.each{|i|
    output.puts "#{i} #{hshFPLatLng[i].lat} #{hshFPLatLng[i].lng}"
  }
  output.close
puts "Done making output file"
end
