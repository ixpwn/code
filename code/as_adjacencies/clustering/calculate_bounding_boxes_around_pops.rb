#!/usr/bin/ruby

clust_id = -1
coords = []

File.open(ARGV[0]).each{|line|
    vals = line.chomp.split
    curr_clust_id = vals[3].to_i
    if(curr_clust_id != clust_id && clust_id != -1) then
            vert = 0
            horiz = 0

            coords.sort!{|x,y| x[0] - y[0]}
#            puts "INSPECT: #{coords.inspect}"           
            #Find latitude distance 
            
            vert = coords.last[0] - coords.first[0]
 #           puts "VERT #{vert}"
            distance = 0
            bestidx = -1

            if(coords.size > 1) then
                idx = 0
                while(idx < coords.size - 1) 
                    delta = coords[idx + 1][0] - coords[idx][0]
    #                puts "#{idx} #{coords.size} #{delta} #{coords[idx + 1].inspect} #{coords[idx].inspect}"
                    bestidx = idx if delta > distance
                    distance = delta if delta > distance
                    idx += 1
                end

                altvert = (90 + coords[bestidx][0]) + (90 - coords[bestidx + 1][0])
                vert = altvert if altvert < vert
            end
            #horizontal
            coords.sort!{|x,y| x[1] - y[1]}
            horiz = coords.last[1] - coords.first[1]

            if(coords.size > 1) then
                idx = 0
                distance = 0
                bestidx = 0
     
                while(idx < coords.size - 1)
                    delta = coords[idx + 1][1] - coords[idx][1]
                    bestidx = idx if delta > distance
                    distance = delta if delta > distance
                    idx += 1                
                end

                althoriz = (180 - coords[bestidx + 1][1] + (180 + coords[bestidx][1]))
                horiz = althoriz if althoriz < horiz 
            end

            puts "#{clust_id} #{"%f" % vert} #{"%f" % horiz} #{"%f" % (vert * horiz)} #{coords.inspect}" 
            coords = []
        end
        clust_id = curr_clust_id
        coords << [vals[1].to_f, vals[2].to_f]
}
