#!/bin/bash

counter=100

while [ $counter -le 1000 ]
do
#  echo archive-0${counter}.tar.gz
  cat archive-${counter}.tar.gz |  tar xzvf -
  ((counter++))
done
