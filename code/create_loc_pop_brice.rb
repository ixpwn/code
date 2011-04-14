#!/usr/bin/ruby

require 'net/http'

if !(ARGV.size == 4 or ARGV.size == 2)
  puts "Usage: #{$0} -b <brice ixp-list> [-o <output>]"
  print "  Output: Creates two files. <output>fp_loc.txt and"
  puts "<output>fp_brice.txt"
  puts "   Formats:"
  puts "     fp_id: <lat+90><long+180> // 6 digits with leading zeros"
  puts "     fp_loc.txt: fp_id city country lat long"
  puts "     fp_brice.txt: fp_id ixp_id"
  puts "-----"
  puts "    b ixp-list.txt file from Brice"
  puts "    o Front part to use for the output files. (Optional)"
  exit
end

#various regex will need
validLatLng = /-?\d+\.?\d*/

http = Net::HTTP.new('maps.googleapis.com')
delim = "\t"

#structs need
LatLng = Struct.new(:lat, :lng)
CityCountry = Struct.new(:city, :country)
FPInfo = Struct.new(:city, :country, :lat, :lng)

#parse input
i = 0
briceFilename = ""
outputFilename = ""
while i < ARGV.size
  if ARGV[i] == '-b'
    briceFilename = ARGV[i+1]
  elsif ARGV[i] == '-o'
    outputFilename = ARGV[i+1]
  end

  i+=2
end

if briceFilename == ""
  puts "Bad Brice filename input"
  exit
end

#hash map of fp_id to info struct
map_fp_info = Hash.new{|hash,key| hash[key] = Array.new}
map_ixp_fp = Hash.new

#open input files and process if output files already have something
briceFile = File.open(briceFilename)
outLocFile = nil
outBriceFile = nil

if File.exists?("#{outputFilename}fp_loc.txt")
  outLocFile = File.new("#{outputFilename}fp_loc.txt", "r+")
  puts "Preprocessing fp_loc.txt"
  outLocFile.each{ |line|
    if line =~ /^(.+)#{delim}(.+)#{delim}(.+)#{delim}(.+)#{delim}(.+)$/
      fp_id = $1
      city = $2
      country = $3
      lat = $4
      lng = $5

      if fp_id =~ /(\d{6,6})(\d)/
        latlng = $1
        num = $2.to_i
        map_fp_id[latlng][num] = FPInfo.new(city, country, lat, lng)
      end
    else
      puts "BAD FORMAT fp_loc.txt: #{line}"
    end
  }
else
  outLocFile = File.new("#{outputFilename}fp_loc.txt", "w")
end

if File.exists?("#{outputFilename}fp_brice.txt")
  outBriceFile = File.new("#{outputFilename}fp_brice.txt", "r+")
  puts "Preprocessing fp_brice.txt"
  outBriceFile.each{ |line|
    if line =~ /(.+)#{delim}(.+)/
      fp_id = $1
      ixp_id = $2

      map_ixp_fp[ixp_id] = fp_id
    else
      puts "BAD FORMAT fp_brice.txt: #{line}"
    end
  }
else
  outBriceFile = File.new("#{outputFilename}fp_brice.txt", "w")
end

#get lat long function
def getLatLng(city, country, http)
  puts "getLatLng(#{city}, #{country}, http)"
  validLatLng = /-?\d+\.?\d*/
  responseLoc = /.*\"lat\": (#{validLatLng}).*\"lng\": (#{validLatLng}).*/m
  lat = ""
  lng = ""
  
  cityAry = city.split(' ')
  subRequest = cityAry[0]
  (cityAry.size-1).times{ |i|
    subRequest += '+'
    subRequest += cityAry[i+1]
  }
  
  subRequest += ','
  
  countryAry = country.split(' ')
  subRequest += countryAry[0]
  (countryAry.size-1).times{ |i|
    subRequest += '+'
    subRequest += countryAry[i+1]
  }
  
  request = "/maps/api/geocode/json?address=#{subRequest}&sensor=false"
  # puts "request: #{request}"
  response = http.request_get(request)
  
  if response.body =~ responseLoc
    lat = $1
    lng = $2
  end
  
  if lat == "" or lng == ""
    LatLng.new(-200,-200)
    puts "TROUBLE! #{request}"
    puts response.body
  else
    LatLng.new(lat.to_f.round, lng.to_f.round)
  end
end

def getCityCountry(latlng, http)
  puts "getCityCountry(#{latlng}, http)"
  validTxt = /[ \w]+/
  responseCity = /\"(#{validTxt})\",\s*\"types\": \[ \"locality\".*/m
  responseCountry = /\"(#{validTxt})\",\s*\"types\": \[ \"country\".*/m
  lat = latlng.lat
  lng = latlng.lng
  city = ""
  country = ""
  
  request = "/maps/api/geocode/json?latlng=#{lat},#{lng}&sensor=false"
  #      puts "request: #{request}"
  response = http.request_get(request)
  
  if response.body =~ responseCity
    city = $1
  end
  if response.body =~ responseCountry
    country = $1
  end
  
  CityCountry.new(city, country)
end

def LatLongToString(latlng)
  lat = "#{latlng.lat + 90}"
  lng = "#{latlng.lng + 180}"

  if lat.size < 3
    (3 - lat.size).times{ lat = '0'+lat }
  end

  if lng.size < 3
    (3 - lng.size).times{ lng = '0'+lng }
  end

  lat+lng
end

#parse through Brice data, add to fp_id_info map, add to fp_brice.txt
puts "PARSE: Brice data"

briceFile.each{ |line|
  if line =~ /^([^\t]+)\t[^\t]*\t[^\t]+\t([^\t]+)\t([^\t\n]+)\t?[^\t\n]*$/
    ixp_id = $1
    city = $2
    country = $3

    if !map_ixp_fp.has_key?(ixp_id)

      loc = getLatLng(city, country, http)

      if loc.lat >= -90 and loc.lng >= -180
        fp_id = LatLongToString(loc)
      
        map_fp_info[fp_id][map_fp_info[fp_id].size] =
          FPInfo.new(city, country, loc.lat, loc.lng)

        outBriceFile.puts("#{fp_id}#{map_fp_info[fp_id].size-1}#{delim}#{ixp_id}")
        map_ixp_fp[ixp_id] = fp_id
      else
        puts "BAD CITY COUNTRY Brice:(#{city}) (#{country}) #{line}"
        exit
      end
    end
  else
    puts "BAD INPUT LINE Brice: #{line}"
  end
}

puts "DONE PARSE: Brice data"

map_fp_info.each {|k, v|
  v.size.times{|i|
    outLocFile.print("#{k}#{i}#{delim}")
    outLocFile.print("#{v[i].city}#{delim}")
    outLocFile.print("#{v[i].country}#{delim}")
    outLocFile.print("#{v[i].lat}#{delim}")
    outLocFile.puts("#{v[i].lng}")
  }
}

briceFile.close
outLocFile.close
outBriceFile.close
