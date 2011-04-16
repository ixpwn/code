#!/usr/bin/ruby

require 'net/http'

# line = STDIN.gets
# while line != nil
#   puts line
#   line = STDIN.gets
# end
# exit

if ARGV.size != 1 || ((ARGV[0] =~ /-[lc]/) == nil)
  puts "Usage: #{$0} -[lc]"
  puts "  Input and output is comma separated"
  puts "  Expected input: \"<city>,<country>\" OR \"<lat>,<long>\""
  puts "  Always outputs: \"<city>,<country>,<lat>,<long>\""
  puts "    l Convert \"<lat> <long>\" to \"<city> <country>\""
  puts "    c Convert \"<city> <country>\" to \"<lat> <long>\""
  exit
end

validLatLng = /-?\d+\.?\d*/
validTxt = /[ \w]+/
responseCity = /\"(#{validTxt})\",\s*\"types\": \[ \"locality\".*/m
responseCountry = /\"(#{validTxt})\",\s*\"types\": \[ \"country\".*/m
responseLoc = /.*\"lat\": (#{validLatLng}).*\"lng\": (#{validLatLng}).*/m
http = Net::HTTP.new('maps.googleapis.com')

badInput = Array.new
badResponse = Array.new

if ARGV[0] =~ /-l/

  line = STDIN.gets

  while line != nil
    if line =~ /^\s*(#{validLatLng}),(#{validLatLng})\s*$/
      lat = $1
      lng = $2
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

      if city == "" or country == ""
        badResponse.push(line)
      else
        puts "#{city},#{country},#{lat},#{lng}"
      end
    else
      badInput.push(line)
    end

    line = STDIN.gets
  end

  if line != nil
    puts "SOMETHING WAS WRONG WITH THE INPUT: #{line}"
  end
else
  line = STDIN.gets
  
  while line != nil
    if line =~ /^\s*(#{validTxt}),(#{validTxt})\s*$/
      city = $1
      country = $2
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
        badResponse.push(line)
      else
        puts "#{city},#{country},#{lat},#{lng}"
      end
    else
      badInput.push(line)
    end
    line = STDIN.gets
  end

  if line != nil
    puts "SOMETHING WAS WRONG WITH THE INPUT: #{line}"
  end
end

badInput.each{|i|
  puts "Bad Input: #{i}"
}
badResponse.each{|i|
  puts "Bad Response: #{i}"
}

exit
