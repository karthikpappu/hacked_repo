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

vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

compver() { 
    local op
    vercomp $1 $3
    case $? in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac
    [[ $2 == *$op* ]] && return 0 || return 1
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
  status=PASS
  region=us-west-2
  profile=slingshot-preprod
  aws_min_version='1.7.20'
  if [[ -n "$proxy" ]]; then
    export http_proxy=http://${proxy}:80/
    export https_proxy=${http_proxy}
    export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'
    JAVA_OPTIONS="-Dhttp.proxyHost=${proxy} -Dhttps.proxyHost=${proxy} -Dhttp.proxyPort=80 -Dhttps.proxyPort=80"
  fi

  # Subnets
  pcc_subnet="PrivateAppSubnetAZ1 PrivateAppSubnetAZ2 PrivateWebSubnetAZ1 PrivateWebSubnetAZ2 PrivateDBSubnetAZ1 PrivateDBSubnetAZ2 PrivateSecuritySubnetAZ1 PrivateSecuritySubnetAZ2 PublicVyattaSubnetAZ1 PublicVyattaSubnetAZ2 PublicBastionSubnetAZ1 PublicBastionSubnetAZ2 PublicELBSubnetAZ1 PublicELBSubnetAZ2 PublicProxySubnetAZ1 PublicProxySubnetAZ2"

  # Security Groups
  pcc_secgrp="SAG-SSH-security-group"

  # Check AWS CLI version
  AWS_VERSION=`aws --version 2>&1| sed 's#aws-cli/\([0-9.]\+\ \).*#\1#'`
  if [[ -z "$AWS_VERSION" ]];then
    echo "Could not get aws cli version...."
    exit 1
  else
    if compver "$AWS_VERSION" '<' "$aws_min_version"; then
      echo "Your AWS CLI version is too old. Installed version is ${AWS_VERSION}. You need to upgrade to at least ${aws_min_version}...."
      exit 1
    fi
  fi
}

function init_env() {
    DEBUG=""
    if [[ "$debug" == true ]];then
      DEBUG="echo "
    fi
}

function check_subnet() {
  printf "Checking for $1 ... "
  if grep -q $1 $cache_file; then
    echo 'ok'
  else
    echo 'not found'
    status=FAIL
  fi
}

function check_secgrp() {
  printf "Checking for $1 ... "
  if grep -q $1 $cache_file; then
    echo 'ok'
  else
    echo 'not found'
#    status=FAIL
  fi
}

function check_pcc() {
  # create temp file
  cache_file=/tmp/onboarding_check_${profile}.txt
  aws ec2 --profile ${profile} --region ${region} describe-tags --output text 2>/dev/null \
    | grep Name | grep -e subnet -e security-group -e vpc \
    | awk '{print $3" "$4" "$5 }' > ${cache_file}

  # check api key
  if [ ! -s "${cache_file}" ]; then
    echo 'AuthFailure: AWS was not able to validate the provided access credentials'
    exit 1
  else
    # start checks
    echo -e "\nValidating PCC Setup"
    echo    "========================"
  
    # check subnets
    echo -e "\n************************************************************************"
    echo    "Subnets for profile ${profile}"
    echo -e "************************************************************************"
    for i in $pcc_subnet
    do
      check_subnet "$i"
    done
  
    # check security groups
    echo -e "\n************************************************************************"
    echo    "Security Groups for profile ${profile}"
    echo -e "************************************************************************"
    for i in $pcc_secgrp
    do
      check_secgrp "$i"
    done
  
    # Result
    echo -e "\nValidation Result"
    echo    "========================"
    echo $status
  fi

  # remove temp file
  rm -f ${cache_file}
}

function rename_tags() {
  if [ "$status" = "FAIL" ]; then
    sh ./upgrade_tag_names.sh -p ${profile} -r ${region} -y
  fi
}

init
get_cmd_opts $@
init_env
confirmation=true
if [[ "$assumeyes" == false ]];then
  confirmation=""
  while [[ -z "$confirmation" ]]; do
    echo -n "Are you ready to validate your profile ${profile} (yes/NO):"
    read confirmation
    if [[ "$confirmation" == "yes" ]];then
      confirmation=true
    else
      confirmation=false
    fi
  done
fi
if [[ "$confirmation" == true ]];then
  check_pcc
  rename_tags
fi
