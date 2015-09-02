#!/bin/sh

trap "exit 1" TERM
export TOP_PID=$$

usage() {
cat << EOF
usage: $0 options

This script create an inputs CF stack, used to abstact subnet and vpc information via JSD
e.x. $0 -r us-west-2 -p slingshot-preprod -k myawsec2key -e myemail@intuit.com
OPTIONS:
   -h       show this message
   -r       region
   -d       debug
   -p       AWS/JSD envrionment
   -k       AWS Keyname
   -e       operator email
   -v       vpc prefix
   -K       KMS EBS key
   -b       s3 bucket for artifacts
   -S       KMS Secrets key
   -B       s3 bucket for secrets
EOF
}

function get_cmd_opts () {
   while getopts "dp:r:e:k:v:K:b:B:S:" OPTION
   do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p) profile=$OPTARG ;;
         r) region=$OPTARG ;;
         d) debug="echo " ;;
         e) operator_email=$OPTARG ;;
         k) key_name=$OPTARG ;;
         v) vpc_prefix=$OPTARG ;;
         K) EbsEncryptionKey=$OPTARG ;;
         b) S3Bucket=$OPTARG ;;
         S) SecretsEncryptionKey=$OPTARG ;;
         B) SecretsS3Bucket=$OPTARG ;;
         ?) usage ;;
     esac
   done
   # Verify we have required options, we can also do additional validation
   if ! [ -n "${profile}" -a -n "${region}" -a -n "${operator_email}" -a -n "${key_name}" -a -n "${EbsEncryptionKey}" -a -n "${S3Bucket}" -a -n "${SecretsEncryptionKey}" -a -n "${SecretsS3Bucket}" ]; then
      echo "Error: required options not provided, -p, -r, -k, -K, -b, -e, -S and -B"
      usage;
      exit 2
   fi
}

function init() {
   debug=""
   
   region=us-west-2
   profile=slingshot-preprod
   vpc_prefix=vpc-1
   if [[ -n "$proxy" ]];then
    JAVA_OPTIONS="-Dhttp.proxyHost=${proxy} -Dhttps.proxyHost=${proxy} -Dhttp.proxyPort=80 -Dhttps.proxyPort=80"
   fi
}

function aws_describe() {
  func_name=$1
  res_name=$2
  key_name=$3
  exit_on_error=$4
  local result=`aws ec2 ${func_name} --region ${region} --profile ${profile} \
                --filters "Name=tag-key,Values=Name,Name=tag-value,Values=${res_name}" \
               | /usr/bin/env python -c "import json,sys;obj=json.load(sys.stdin); print obj${key_name}"`
  if [[ "$exit_on_error" == true && -z "$result" ]]; then
    echo "Failed to get resource id for $res_name" >&2
    kill -s TERM $TOP_PID
  fi
  echo "$result"
}

function query_vpc() {
  vpc_name=$1
  key_name='["Vpcs"][0]["VpcId"]'
  local result=$(aws_describe "describe-vpcs" "$vpc_name" "$key_name" true )
  echo "$result"
}

function query_subnet() {
  subnet_name=$1
  key_name='["Subnets"][0]["SubnetId"]'
  local result=$(aws_describe "describe-subnets" "$subnet_name" "$key_name" false )
  echo "$result"
}

function query_az() {
  subnet_name=$1
  key_name='["Subnets"][0]["AvailabilityZone"]'
  local result=$(aws_describe "describe-subnets" "$subnet_name" "$key_name" true )
  echo "$result" 
}

function query_sg() {
  sg_name=$1
  key_name='["SecurityGroups"][0]["GroupId"]'
  local result=$(aws_describe "describe-security-groups" "$sg_name" "$key_name" true )
  echo "$result" 
}

function query_stacks() {
    VpcId=$(query_vpc *${vpc_prefix})
    echo "VpcId=$VpcId"
    sleep 2
    AvailabilityZone1=$(query_az "PublicELBSubnetAZ1")
    echo "AvailabilityZone1=$AvailabilityZone1"
    sleep 2
    AvailabilityZone2=$(query_az "PublicELBSubnetAZ2")
    echo "AvailabilityZone2=$AvailabilityZone2"
    sleep 2
    ElbSubnet1Id=$(query_subnet PublicELBSubnetAZ1)
    echo "ElbSubnet1Id=$ElbSubnet1Id"
    sleep 2
    ElbSubnet2Id=$(query_subnet PublicELBSubnetAZ2)
    echo "ElbSubnet2Id=$ElbSubnet2Id"
    sleep 2
    WebSubnet1Id=$(query_subnet PrivateWebSubnetAZ1)
    echo "WebSubnet1Id=$WebSubnet1Id"
    sleep 2
    WebSubnet2Id=$(query_subnet PrivateWebSubnetAZ2)
    echo "WebSubnet2Id=$WebSubnet2Id"
    sleep 2
    AppSubnet1Id=$(query_subnet PrivateAppSubnetAZ1)
    echo "AppSubnet1Id=$AppSubnet1Id"
    sleep 2
    AppSubnet2Id=$(query_subnet PrivateAppSubnetAZ2)
    echo "AppSubnet2Id=$AppSubnet2Id"
    sleep 2
    DbSubnet1Id=$(query_subnet PrivateDBSubnetAZ1)
    echo "DbSubnet1Id=$DbSubnet1Id"
    sleep 2
    DbSubnet2Id=$(query_subnet PrivateDBSubnetAZ2)
    echo "DbSubnet2Id=$DbSubnet2Id"
    sleep 2
    ProxySubnet1Id=$(query_subnet PublicProxySubnetAZ1)
    echo "ProxySubnet1Id=$ProxySubnet1Id"
    sleep 2
    ProxySubnet2Id=$(query_subnet PublicProxySubnetAZ2)
    echo "ProxySubnet2Id=$ProxySubnet2Id"
    sleep 2
    BastionSubnet1Id=$(query_subnet PublicBastionSubnetAZ1)
    echo "BastionSubnet1Id=$BastionSubnet1Id"
    sleep 2
    BastionSubnet2Id=$(query_subnet PublicBastionSubnetAZ2)
    echo "BastionSubnet2Id=$BastionSubnet2Id"
    sleep 2
    SAGSecGrp=$(query_sg "*-intuit-SAG-SSH-security-group")
    echo "SAGSecGrp=$SAGSecGrp"
    sleep 2
}

function create_input_cf() {
    inputs_created=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$"`
    if [ -n "${inputs_created}" ]; then
        java ${JAVA_OPTIONS} -jar JSD-App.jar delete -e ${profile} -n inputs
        sleep 10
    fi
    $debug java ${JAVA_OPTIONS} -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/1.inputs.json -a VpcId=${VpcId} -a AvailabilityZone1=${AvailabilityZone1} -a ElbSubnet1Id=${ElbSubnet1Id} -a WebSubnet1Id=${WebSubnet1Id} -a AppSubnet1Id=${AppSubnet1Id} -a DbSubnet1Id=${DbSubnet1Id} -a BastionSubnet1Id=${BastionSubnet1Id} -a ProxySubnet1Id=${ProxySubnet1Id} -a SAGSecGrp=${SAGSecGrp} -a AvailabilityZone2=${AvailabilityZone2} -a ElbSubnet2Id=${ElbSubnet2Id} -a WebSubnet2Id=${WebSubnet2Id} -a AppSubnet2Id=${AppSubnet2Id} -a DbSubnet2Id=${DbSubnet2Id} -a ProxySubnet2Id=${ProxySubnet2Id} -a BastionSubnet2Id=${BastionSubnet2Id} -a EbsEncryptionKey=${EbsEncryptionKey} -a S3Bucket=${S3Bucket} -a SecretsEncryptionKey=${SecretsEncryptionKey} -a SecretsS3Bucket=${SecretsS3Bucket} -a OperatorEmail=${operator_email} -a KeyName=${key_name} -n inputs
}

init
get_cmd_opts $@
query_stacks
create_input_cf
