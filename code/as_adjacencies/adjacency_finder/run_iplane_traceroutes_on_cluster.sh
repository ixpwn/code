#!/bin/bash

rnodes='r37 r21 r22 r23 r24'

for i in {10..11}
do 
    ran=0
    while([ $ran -eq 0 ]) 
        do
        for rnode in $rnodes 
            do
            if [ `echo "ps aux | grep parse_iplane | grep -v grep | wc -l" | ssh ${rnode}.millennium.berkeley.edu` -eq 0 ] 
                then
                echo "cd $(pwd); echo './parse_iplane_traceroutes 06 $i' | at now" | ssh $rnode
                echo "IPLANE PARSING FOR 6/$i RUNNING ON $rnode"
                ran=1
                break
            fi 
        done
       
        if [ $ran -eq 0 ] 
            then
            sleep 20s
        fi 
    done 

done
