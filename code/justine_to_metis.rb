#!/usr/bin/ruby

def assert(value, str)
  if !value
    puts "ASSERT Fail: #{str}"
    exit
  end
end

ignoreMissingLatLng = true

if !(ARGV.size == 6)
  print "Usage: #{$0} "
  print "-a <asn adjacency to lat/lng file> "
  print "-t <adjacency lat/lng to triangle lat/lng file> "
  print "-o <output file name> "
  puts ""
  exit
end

triFilename = ""
adjFilename = ""
outFilename = ""
i = 0
while i < ARGV.size
  if ARGV[i] == "-t"
    triFilename = ARGV[i+1]
  elsif ARGV[i] == "-a"
    adjFilename = ARGV[i+1]
  elsif ARGV[i] == "-o"
    outFilename = ARGV[i+1]
  end
  i+=2
end

if triFilename == "" or adjFilename == "" or outFilename == ""
  print "Missing file triangle:#{triFilename} adj:#{adjFilename} "
  puts "out:#{outFilename}"
  exit
end

LatLng = Struct.new(:lat, :lng)
hshTri = Hash.new(nil)
hshAdj = Hash.new{|h,v| h[v] = Hash.new(false)}
hshASN = Hash.new

puts "Parse: #{triFilename}"
triFile = File.open(triFilename)
triFile.each{|line|
  if line =~ /^(.+) (.+) (.+) (.+)/
    aLat = $1.to_f
    aLng = $2.to_f
#    aLat = $1
#    aLng = $2
    tLat = $3.to_f
    tLng = $4.to_f

    assert(!$1.include?(" "), "Adjacency lat includes a space! #{$1}")
    assert(!$2.include?(" "), "Adjacency lng includes a space! #{$2}")
    assert(!$3.include?(" "), "Triangle lat includes a space! #{$3}")
    assert(!$4.include?(" "), "Triangle lat includes a space! #{$4}")

#    puts "(#{aLat},#{aLng}) (#{tLat},#{tLng})"

    hshTri[LatLng.new(aLat,aLng)] = LatLng.new(tLat,tLng)
  else
    assert(false, "Not match: #{line}")
  end
}
triFile.close
puts "DONE Parse: #{triFilename}"

puts "Parse: #{adjFilename}"
cMissingLatLng = 0
c = 0
hshALatLng = Hash.new
adjFile = File.open(adjFilename)
adjFile.each{|line|
  if line =~ /^(\S+) (\S+) (\S+) (\S+)/
    asn1 = $1.to_i
    asn2 = $2.to_i
    lat = $3.to_f
    lng = $4.to_f
#    lat = $3
#    lng = $4

#    puts "(#{$1}) (#{$2}) (#{$3}) (#{$4})"

    c += 1

    latLng = LatLng.new(lat,lng)

    hshALatLng[latLng] = true

    tLatLng = hshTri[latLng]

    if tLatLng != nil
      hshAdj[tLatLng][asn1] = true
      hshAdj[tLatLng][asn2] = true
      hshASN[asn1] = true
      hshASN[asn2] = true
    else
      cMissingLatLng += 1
#      puts "(#{lat},#{lng})"
      if !ignoreMissingLatLng
        assert(false, "lat/lng with no triangle match")
      end
    end
    
  else
    assert(false, "Not match: #{line}")
  end
}
adjFile.close
puts "DONE Parse: #{adjFilename}"
puts "  Total adjacencies: #{c}"
puts "  Adjacencies missing a lat/lng: #{cMissingLatLng}"

cUnmatchedLatLng = 0
hshALatLng.each{|k,v|
  if v
    if hshTri[k] == nil
#      puts "#{k.lat} #{k.lng}"
      cUnmatchedLatLng += 1
    end
  end
}

puts "  Unmatched adj lat/lng: #{cUnmatchedLatLng}"
puts "  Total adj lat/lng: #{hshALatLng.size}"

#Create ASN -> incrementing ID
puts "Creating ASN -> incrementing ID file"
aryASN = hshASN.keys
aryASN.sort!
hshASNIncID = Hash.new
asnIncOut = File.new("#{outFilename}.aid", "w+")
aryASN.size.times{|j|
  i = j+1
  asnIncOut.puts "#{aryASN[j]} #{i}"
  hshASNIncID[aryASN[j]] = i
}
asnIncOut.close
puts "Done creating ASN -> incrementing ID file"

#Create metis output file
puts "Creating hmetis output file"
hgrOut = File.new("#{outFilename}.hgr", "w+")
hgrOut.puts "#{hshAdj.size} #{aryASN.size}"
hshAdj.each{|k,set|
  str = ""
  set.each{|asn, v|
    if v
      str += "#{hshASNIncID[asn]}"
      str += " "
    end
  }
  hgrOut.puts str.strip
}
hgrOut.close
puts "Done creating hmetis output file"

