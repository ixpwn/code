#!/usr/bin/ruby

def assert(value, str)
  if !value
    puts "ASSERT Fail: #{str}"
    exit
  end
end

if !(ARGV.size == 12)
  print "Usage: #{$0} "
  print "-m <hmetis command location> "
  print "-p <partition max> "
  print "-n <number of times run hmetis> "
  print "-h <.hgr file> "
  print "-b <ubfactor min> <ubfactor max> <ubfactor increment> "
  puts ""
  puts "-----"
  puts "    b Range and step take for ubfactor"
  puts "    h File to give hmetis"
  puts "    m Use as the hmetis command"
  puts "    n Number of experiments to run per ubfactor"
  puts "    p Will run hmetis from 2 to p partitions"
  exit
end

hmetisCmd = ""
partMax = -1
nExpRun = -1
hmetisFile = ""
bMin = -1
bMax = -1
bStep = -1
i = 0
while i < ARGV.size
  if ARGV[i] == "-m"
    hmetisCmd = ARGV[i+1]
  elsif ARGV[i] == "-p"
    partMax = ARGV[i+1].to_i
  elsif ARGV[i] == "-n"
    nExpRun = ARGV[i+1].to_i
  elsif ARGV[i] == "-h"
    hmetisFile = ARGV[i+1]
  elsif ARGV[i] == "-b"
    bMin = ARGV[i+1].to_i
    bMax = ARGV[i+2].to_i
    bStep = ARGV[i+3].to_i
    i+=2
  end

  i+=2
end

if hmetisCmd == "" or partMax == -1 or nExpRun == -1 or hmetisFile == "" or
    bMin == -1 or bMax == -1 or bStep == -1
  puts "Bad input"
  exit
end

bCurr = bMin
while bCurr <= bMax
  iP = 2
  while iP <= partMax
    nExpRun.times{|i|
      cmd = "#{hmetisCmd} #{hmetisFile} #{iP} #{bCurr}"
      output = `#{cmd}`
      `mv #{hmetisFile}.part.#{iP} #{hmetisFile}.part.#{iP}.#{bCurr}.#{i}`
      outFile = File.new("#{hmetisFile}.part.#{iP}.#{bCurr}.#{i}.out","w+")
      outFile.puts output
      outFile.close
    }
    iP += 1
  end    
  bCurr += bStep
end

exit
############################

bCurr = bMin
bHeader = ""
while bCurr <= bMax
  bHeader += "#{bCurr}"
  bHeader += "\t\t"
  bCurr += bStep
end

iP = 2
while iP <= partMax
  puts "Partition: #{iP}"
  puts bHeader
  bCurr = bMin
  while bCurr <= bMax
    print "min: #{hshStatsBPC[bCurr][iP].min}\t"
    bCurr += bStep
  end
  puts ""
  bCurr = bMin
  while bCurr <= bMax
    print "max: #{hshStatsBPC[bCurr][iP].max}\t"
    bCurr += bStep
  end
  puts ""
  bCurr = bMin
  while bCurr <= bMax
    print "avg: #{hshStatsBPC[bCurr][iP].sum/hshStatsBPC[bCurr][iP].count}\t"
    bCurr += bStep
  end
  puts ""
  iP+=1
end
