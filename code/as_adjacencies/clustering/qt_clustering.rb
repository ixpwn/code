#!/usr/bin/ruby
# inputs
# ARGV[0] quality threshold for clusters
# ARGV[1] cluster file: <ip> <lat> <lon> <clusterid>


$threshold = ARGV[0].to_f

$cluster_id = 0
$new_cluster_id = 1

$ip_lat_lons = {}

def distance(l1,l2)
    Math.sqrt((l1[0] - l2[0])**2 + (l1[1] - l2[1])**2)
end

def num_addresses(x)
#    puts "CHECKING FOR #{x.inspect} #{$ip_lat_lons[x].inspect}"
    num_ips = 0
    x.each{|pair|
        num_ips += $ip_lat_lons[pair].size
    }
    return num_ips
end

def print_set(x)
    max = 0
    maxlatlon = nil
    x.each{|z| 
        if($ip_lat_lons[z].size > max) then
            maxlatlon = z
            max = $ip_lat_lons[z].size
        end
    }

    print maxlatlon.join(' ')
    x.each{|latlon|
        print " #{$ip_lat_lons[latlon].join(' ')}"
    }
    puts
end

def create_subclusters_and_clear
    locs = $ip_lat_lons.keys
    #puts locs.inspect

    while(locs.size > 0)
        subsets = []
        locs.size.times{|i|
            set = [locs[i]]
            locs.size.times{|j|
                if(i != j && distance(locs[i], locs[j]) <= $threshold) then
                    set << locs[j]
                end    
            }
            subsets << set
        }
#        puts subsets.inspect
        subsets.sort!{|x,y| num_addresses(y) - num_addresses(x)}
#        puts "Yooooooo!! #{subsets.first.inspect} #{$ip_lat_lons[subsets.first].inspect}"
        if(num_addresses(subsets.first) > 1) then
            print_set(subsets.first)
            subsets.first.each{|latlon|
                locs.delete(latlon)
            }
        end
        break if(num_addresses(subsets.first) == 1 || (subsets.size > 1 && num_addresses(subsets[1])) == 1)
    end

    #puts subsets.inspect

    $ip_lat_lons = {}
end

File.open(ARGV[1]).each{|line|
    vals = line.chomp.split
    current_cluster_id = vals.last.to_i
    if($cluster_id != current_cluster_id) then
        create_subclusters_and_clear if $cluster_id != 0
        $cluster_id = current_cluster_id
    end 
    latlon = [vals[1].to_f, vals[2].to_f]
    $ip_lat_lons[latlon] = [] if($ip_lat_lons[latlon] == nil)
    $ip_lat_lons[latlon] <<  vals[0]
}
