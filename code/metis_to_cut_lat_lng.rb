#!/usr/bin/ruby

def assert(value, str)
  if !value
    puts "ASSERT Fail: #{str}"
    exit
  end
end

if !(ARGV.size == 8)
  print "Usage: #{$0} "
  print "-g <giant long file>"
  print "-i <asn to incremented id file> "
  print "-p <partition file from hmetis> "
  print "-o <output filename> "
  puts ""
  puts "-----"
  puts "    g Giant file of format: <asn1> <asn2> <lat> <lng> <cell ID> <cell lat> <cell lng>"
  puts "    i File with mapping from asn to the incremented id used by hmetis: <asn> <incremented id>"
  puts "    o Name of file to output to"
  puts "    p The partition file hmetis outputed"
  exit
end

bigFilename = ""
partFilename = ""
asnIncFilename = ""
outFilename = ""
i = 0
while i < ARGV.size
  if ARGV[i] == '-g'
    bigFilename = ARGV[i+1]
  elsif ARGV[i] == '-i'
    asnIncFilename = ARGV[i+1]
  elsif ARGV[i] == '-p'
    partFilename = ARGV[i+1]
  elsif ARGV[i] == '-o'
    outFilename = ARGV[i+1]
  end

  i+=2
end

if bigFilename == "" or partFilename == "" or
    asnIncFilename == "" or outFilename == ""
  puts "Missing a needed file:"
  puts "big:#{bigFilename}"
  puts "part:#{partFilename}"
  puts "aid:#{asnIncFilename}"
  puts "out:#{outFilename}"
  exit
end

#Needed variables
LatLng = Struct.new(:lat, :lng)
hshAdjAsnSet = Hash.new{|h,k| h[k] = Hash.new(false)}
hshAdjTri = Hash.new
hshTriID = Hash.new
hshIncIDAsn = Hash.new
hshAsnIncID = Hash.new
hshAsnPart = Hash.new

puts "Parsing: #{bigFilename}"
input = File.open(bigFilename)
c = 0
input.each{|line|
  c+=1
  if line =~ /^(.+) (.+) (.+) (.+) (.+) (.+) (.+)$/
    asn1 = $1.to_i
    asn2 = $2.to_i
    aLatLng = LatLng.new($3.to_f, $4.to_f)
    cid = $5.to_i
    cLatLng = LatLng.new($6.to_f, $7.to_f)

    hshAdjAsnSet[aLatLng][asn1] = true
    hshAdjAsnSet[aLatLng][asn2] = true
    hshAdjTri[aLatLng] = cLatLng
    hshTriID[cLatLng] = cid
  else
    assert(false, "Line not parse: #{line}")
  end
}
input.close
puts "Done Parsing #{c} lines: #{bigFilename}"

cMatches = 0
cMisses = 0
hshAdjAsnSet.each{|adjLatLng,v|
  if hshAdjTri.has_key?(adjLatLng)
    cMatches+=1
  else
    cMisses += 1
  end
}
if cMisses > 0
  puts "MISSING lat/lng's!! matched:#{cMatches} misses:#{cMisses}"
end

#Parse through asn to incremented id
puts "Parsing #{asnIncFilename}"
input = File.open(asnIncFilename)
c = 0
inc_id = 0
input.each{|line|
  c+=1
  if line =~ /^(.+) (.+)$/
    asn = $1.to_i
    inc_id = $2.to_i
    hshIncIDAsn[inc_id] = asn
    hshAsnIncID[asn] = inc_id
  else
    assert(false, "Line not parse: #{line}")
  end
}
puts "Parsing done of #{c} lines: #{asnIncFilename}"

#Parse through partition file
puts "Parsing #{partFilename}"
input = File.open(partFilename)
c = 0
inc_id = 1
input.each{|line|
  c+=1
  hshAsnPart[hshIncIDAsn[inc_id]] = line.strip.to_i
  inc_id+=1
}
puts "Parsing done of #{c} lines: #{partFilename}"

puts "Creating output file"
output = File.new("#{outFilename}", "w+")
#outputSanity = File.new("#{outFilename}.sanity", "w+")
cMissingTri = 0
c = 0
hshPrintTri = Hash.new
hshAdjAsnSet.each{|adjLatLng, set|
  shouldPrint = false;
  c += 1

  i = 0
  while !set.keys[i]
    i+=1
  end
  partition = hshAsnPart[set.keys[i]]
  set.each{|asn, v|
    if v
      if partition != hshAsnPart[asn]
        shouldPrint = true
        break
      end
    end
  }

  if shouldPrint
    # set.each{|asn,v|
    #   if v
    #     outputSanity.print "#{asn}(#{hshAsnIncID[asn]}) "
    #   end
    # }
    # outputSanity.puts ""

    triLatLng =  hshAdjTri[adjLatLng]
    if triLatLng != nil
      hshPrintTri[triLatLng] = true
#      output.puts "#{triLatLng.lat} #{triLatLng.lng}"
    else
#      puts  "#{adjLatLng.lat} #{adjLatLng.lng}"
      cMissingTri += 1
    end
  end
}

hshPrintTri.each{|triLatLng, v|
  if v
    output.puts "#{hshTriID[triLatLng]} #{triLatLng.lat} #{triLatLng.lng}"
  end
}

output.close
#outputSanity.close
puts "Done creating output file of #{c} hyperedges"
puts "Missing triangles: #{cMissingTri}"
