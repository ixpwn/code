#!/bin/bash

cat $1 | while read line 
    do
    echo "$line $(host $line)"
done 
