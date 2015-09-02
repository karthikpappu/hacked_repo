#!/bin/bash -x


export BUILD_NUMER=$1
export JSON_FILE=cf-docker-jmeter2.json

export ZONE=us-west-2a
export KEY_NAME=intuit-perf
export SEC_GROUP_ID=sg-07dc4762
export VPC_ID=vpc-52c2d830
export SUBNET_ID=subnet-b603e3d3
export STACK_GROUP=sbg-continuous-perf-demo

export S3_BUCKET=df-docker-registry
export S3_PERF_BUCKET=sbg-performance
export PROXY_SERVER=qy1prdproxy01.pprod.ie.intuit.net:80
export NON_PROXY_HOSTS=none
export JMX_FILE=Edge_cluster/jenkins_qbo_edge.jmx
export JMETER_POOL_SIZE=1
export JMETER_OPTIONS='-JFile=/scripts/Edge_cluster/c1_companies.csv'
export EC2_POOL_SIZE=1

export CD_OFFERING_NAME=revak
export CD_COMPONENT_NAME=test

export TERMINATE_STACK_ON_FINISH=true
export NEW_PERF_CLOUD_ON_DEMAND=true

stack_name=${CD_OFFERING_NAME}-${CD_COMPONENT_NAME}-$1

aws s3 cp s3://${S3_BUCKET}/bootstrap/build2.sh .
chmod 755 build2.sh
./build2.sh
