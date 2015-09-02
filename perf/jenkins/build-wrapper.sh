#!/bin/bash -x

aws s3 cp s3://qbo-performance/bootstrap/build.sh .
chmod 755 build.sh
./build.sh
