#!/usr/bin/env bash

usage() {
cat << EOF
usage: $0   options action

This script update the resources from PCC to their newest tag names

OPTIONS:
   -h       show this message
   -r       region
   -p       AWS/JSD environment
   -y       assume yes
   -d       debug
EOF
}

function get_cmd_opts () {
   while getopts "p:r:yd" OPTION
   do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p) profile=$OPTARG ;;
         r) region=$OPTARG ;;
         y) assumeyes=true ;;
         d) debug=true ;;
         ?) usage ;;
     esac
   done
   #Verify we have required options, we can also do additional validation
   if ! [ -n "${profile}" ]; then
      echo "Error: required options not provided -p"
      usage;
      exit 2
   fi
}

function init() {
   debug=false
   assumeyes=false
   region=us-west-2
   profile=slingshot-preprod
   if [[ -n "$proxy" ]];then
    JAVA_OPTIONS="-Dhttp.proxyHost=${proxy} -Dhttps.proxyHost=${proxy} -Dhttp.proxyPort=80 -Dhttps.proxyPort=80" 
   fi
}

function init_env() {
    DEBUG=""
    if [[ "$debug" == true ]];then
      DEBUG="echo "
    fi
}

function rename_resource() {
  id=$1
  new_name=$2
  echo "Updating name for resource $id to $new_name"
  $DEBUG aws ec2 --profile ${profile} --region ${region} create-tags --resources $id --tags "Key=Name,Value=$new_name"
}

function upgrade_tags() {
  echo -e "\n************************************************************************"
  echo    "Upgrading tags for profile ${profile}"
  echo -e "************************************************************************"
  cache_file=/tmp/upgrade_tags_${profile}.txt
  aws ec2 --profile ${profile} --region ${region} describe-tags --output text \
    | grep Name | grep -e subnet -e security-group -e vpc \
    | awk '{print $3" "$4" "$5 }' > ${cache_file}

  # check api key
  if [ ! -s "${cache_file}" ]; then
    echo 'AuthFailure: AWS was not able to validate the provided access credentials'
    exit 1
  else
    cat ${cache_file} | while read id type name; do
          case "$name" in
          *bastion-public-subnet-1)  
              rename_resource "$id" "PublicBastionSubnetAZ1"
              ;;
          *bastion-public-subnet-2)  
              rename_resource "$id" "PublicBastionSubnetAZ2"
              ;;
          *proxy-public-subnet-1)  
              rename_resource "$id" "PublicProxySubnetAZ1"
              ;;
          *proxy-public-subnet-2)  
              rename_resource "$id" "PublicProxySubnetAZ2"
              ;;
          *vyatta-public-subnet-1)  
              rename_resource "$id" "PublicVyattaSubnetAZ1"
              ;;
          *vyatta-public-subnet-2)  
              rename_resource "$id" "PublicVyattaSubnetAZ2"
              ;;
          *elb-public-subnet-1)  
              rename_resource "$id" "PublicELBSubnetAZ1"
              ;;
          *elb-public-subnet-2)  
              rename_resource "$id" "PublicELBSubnetAZ2"
              ;;
          *security-private-subnet-1)  
              rename_resource "$id" "PrivateSecuritySubnetAZ1"
              ;;
          *security-private-subnet-2)  
              rename_resource "$id" "PrivateSecuritySubnetAZ2"
              ;;
          *web-private-subnet-1)  
              rename_resource "$id" "PrivateWebSubnetAZ1"
              ;;
          *web-private-subnet-2)  
              rename_resource "$id" "PrivateWebSubnetAZ2"
              ;;
          *app-private-subnet-1)  
              rename_resource "$id" "PrivateAppSubnetAZ1"
              ;;
          *app-private-subnet-2)  
              rename_resource "$id" "PrivateAppSubnetAZ2"
              ;;
          *db-private-subnet-1)  
              rename_resource "$id" "PrivateDBSubnetAZ1"
              ;;
          *db-private-subnet-2)  
              rename_resource "$id" "PrivateDBSubnetAZ2"
              ;;
          *)
            continue
             ;;
          esac
    done
  fi

  # remove temp file
  rm -f ${cache_file}
}

init
get_cmd_opts $@
init_env
confirmation=true
if [[ "$assumeyes" == false ]];then
  confirmation=""
  while [[ -z "$confirmation" ]]; do
    echo -n "Are you ready to upgrade tags on profile ${profile} (yes/NO):"
    read confirmation
    if [[ "$confirmation" == "yes" ]];then
      confirmation=true
    else
      confirmation=false
    fi
  done
fi
if [[ "$confirmation" == true ]];then
  upgrade_tags
fi

