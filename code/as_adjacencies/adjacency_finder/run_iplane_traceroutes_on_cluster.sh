#!/bin/bash

rnodes='r22 r23 r24 r25 r26 r27 r28 r29'
month='07'

for i in {1..31}
do 
    i=`printf %02d $i`
    ran=0
    while([ $ran -eq 0 ]) 
        do
        for rnode in $rnodes 
            do
            if [ `echo "ps aux | grep parse_iplane | grep -v grep | wc -l" | ssh ${rnode}.millennium.berkeley.edu` -eq 0 ] 
                then
                echo "cd $(pwd); echo './parse_iplane_traceroutes.sh $month $i 2>>$month.$i.$rnode.log 1>>$month.$i.$rnode.log' | at now" | ssh $rnode
                echo "running now!" | mail -s "IPLANE PARSING FOR $month/$i RUNNING ON $rnode" justine@cs.berkeley.edu 
                echo "IPLANE PARSING FOR $month/$i RUNNING ON $rnode" 
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
