#! /bin/bash

#https://serverfault.com/questions/592260/add-a-custom-header-to-proxypass-requests


#this script just loops forever and outputs a random string
#every time it receives something on stdin

while read
do
        cat /dev/urandom|head -c12|base64
done