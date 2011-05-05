#!/usr/bin/ruby

#Check input
if (ARGV.size < 2)
  print "Usage: #{$0} "
  print "[-a <fp as file formatted>] "
  print "[-d <degree threshold>] "
  print "[-j <Justine as file formatted>]"
  print "[-o <output>] "
  puts ""
  puts "-----"
  puts "    a Failure point to AS file, format: <fp_id> <asn>"
  puts "    d Cut off for the failure point degree (default 1), file name will include _d# if defined"
  puts "    j Justine's AS cluster file, format: <fp_id> <asn_1> ... <asn_k>"
  puts "    o Front part to use for the output files (default \"\")"
  exit
end

#Allow two different formats, check which and parse
fpAsFilename = ""
justineFilename = ""
outHeader = "input"
degThresh = 1
i = 0
while i < ARGV.size
  if ARGV[i] == '-a'
    fpAsFilename = ARGV[i+1]
  elsif ARGV[i] == '-j'
    justineFilename = ARGV[i+1]
  elsif ARGV[i] == '-d'
    degThresh = ARGV[i+1].to_i
  elsif ARGV[i] == '-o'
    tmp = ARGV[i+1]
    if File.directory?(tmp)
      outHeader = tmp + "input"
    else
      outHeader = tmp;
    end
  end

  i+=2
end

if fpAsFilename == "" and justineFilename == ""
  puts "Need a file to parse"
  exit
end

if degThresh != 1
  outHeader += "_d#{degThresh}"
end

#Needed variables
hshASN = Hash.new(false)
hshFPASSet = Hash.new{|h,k| h[k] = Hash.new(false)}
delim = "[ \t]"

if fpAsFilename != ""
  puts "Parsing: #{fpAsFilename}"
  input = File.open(fpAsFilename)
  c = 0
  input.each{|line|
    c+=1
    if line =~ /(.+)#{delim}(.+)/
      fp_id = $1.strip
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
      v.each_key{|asn|
        hshASN[asn] = true
      }
    else
      puts "#{k}"
    end
  }
  hshFPASSet = tmp
  input.close
  puts "Parsing done of #{c} lines: #{fpAsFilename}"
else
  puts "Parsing: #{justineFilename}"
  input = File.open(justineFilename)
  c = 0
  input.each{|line|
    c+=1
    aryLine = line.split(" ")
    fp_id = aryLine[0]
#    lat = aryLine[1].to_f
#    lng = aryLine[2].to_f
    i = 3
    hsh = Hash.new(false)
    while i < aryLine.size
      hsh[aryLine[i].to_i] = true
      i+=1
    end
    
    if hsh.size > degThresh
      hshFPASSet[fp_id] = hsh
      hsh.each_key{|asn|
        hshASN[asn] = true
      }
    end
  }
  input.close
  puts "Parsing done of #{c} lines: #{justineFilename}"
end

#Create ASN -> incrementing ID
puts "Creating ASN -> incrementing ID file"
aryASN = hshASN.keys
aryASN.sort!
hshASNIncID = Hash.new
asnIncOut = File.new("#{outHeader}.aid", "w+")
aryASN.size.times{|j|
  i = j+1
  asnIncOut.puts "#{aryASN[j]} #{i}"
  hshASNIncID[aryASN[j]] = i
}
asnIncOut.close
puts "Done creating ASN -> incrementing ID file"

#Create metis output file
puts "Creating hmetis output file"
hgrOut = File.new("#{outHeader}.hgr", "w+")
hgrOut.puts "#{hshFPASSet.size} #{aryASN.size}"
hshFPASSet.each{|k,set|
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

