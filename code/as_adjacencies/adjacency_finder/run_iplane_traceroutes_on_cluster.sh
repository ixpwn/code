#!/bin/bash

rnodes='r21 r22 r23 r24'

for i in {1..5}
do 
    i=`printf %02d $i`
    ran=0
    while([ $ran -eq 0 ]) 
        do
        for rnode in $rnodes 
            do
            if [ `echo "ps aux | grep parse_iplane | grep -v grep | wc -l" | ssh ${rnode}.millennium.berkeley.edu` -eq 0 ] 
                then
                echo "cd $(pwd); echo './parse_iplane_traceroutes.sh 06 $i 2>>$i.$rnode.log 1>>$i.$rnode.log' | at now" | ssh $rnode
                echo "running now!" | mail -s "IPLANE PARSING FOR 6/$i RUNNING ON $rnode" justine@cs.berkeley.edu 
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
