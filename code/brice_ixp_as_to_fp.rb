#!/usr/bin/ruby

if !(ARGV.size == 6 or ARGV.size == 4)
  puts "Usage: #{$0} -b <fp brice ixp file> -p <brice ip peering> [-o <output>]"
  puts "  Output: File <output>fp_as.txt"
  puts "  Format: <fp_id> <AS#>"
  puts "-----"
  puts "    b fp_brice.txt file"
  puts "    p ixp-peerings.txt from Brice"
  puts "    o Front part to use for the output files. (Optional)"
  exit
end

#parse input
i = 0
briceFilename = ""
peeringFilename = ""
outputFilename = ""
while i < ARGV.size
  if ARGV[i] == '-b'
    briceFilename = ARGV[i+1]
  elsif ARGV[i] == '-p'
    peeringFilename = ARGV[i+1]
  elsif ARGV[i] == '-o'
    outputFilename = "#{ARGV[i+1]}fp_as.txt"
  end

  i+=2
end

if briceFilename == "" or peeringFilename == ""
  puts "Bad Inputs: Brice fp<->ixp or peering filenames"
  exit
end

#Hashmaps will need
map_ixp_fp = Hash.new
map_fp_as = Hash.new{|hash,key| hash[key] = Hash.new(false)}

#other variables
delim = "\t"

#Open files
briceFile = File.open(briceFilename)
peeringFile = File.open(peeringFilename)
outputFile = File.new(outputFilename, "w")

#Parse through fp_brice.txt
puts "Parsing: #{briceFilename}"
c = 0
briceFile.each{|line|
  if line =~ /(.+)#{delim}(.+)/
    fp_id = $1
    ixp_id = $2
    c+=1

    map_ixp_fp[ixp_id] = fp_id
  else
    puts "Something wrong: #{line}"
    exit
  end
}
puts "Parsing done of #{c} lines: #{briceFilename}"
#map_ixp_fp.each{|k,v| print "#{k}=>#{v} "}
#exit

#Parse through ixp-peerings.txt, add to map as need
puts "Parsing: #{peeringFilename}"
peeringFile.each{|line|
  if line =~ /(\S+) (\S+) (\S+).*/
    ixp_id = $1
    as1 = $2
    as2 = $3

    if map_ixp_fp.has_key?(ixp_id)
      if as1.to_i
        map_fp_as[map_ixp_fp[ixp_id]][as1] = true
      end
      if as2.to_i > 0
        map_fp_as[map_ixp_fp[ixp_id]][as2] = true
      end
    else
      puts "Peering has unknown ixp_id: #{ixp_id} line: #{line}"
      exit
    end
  else
    puts "Something wrong: #{line}"
    exit
  end
}
puts "Parsing done: #{peeringFilename}"

#Write to output file
puts "Writing: #{outputFilename}"
map_fp_as.each{|fp_id,set|
  set.each{|as,v|
    outputFile.puts("#{fp_id}#{delim}#{as}")
  }
}
puts "Writing done: #{outputFilename}"

#Close files
briceFile.close
peeringFile.close
outputFile.close
