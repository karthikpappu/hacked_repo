#!/usr/bin/env bash

usage() {
cat << EOF
usage: $0   options action

This script validates the slingshot prerequisites for onboarding

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
  status=PASS
  region=us-west-2
  profile=slingshot-preprod
  if [[ -n "$proxy" ]]; then
    export http_proxy=http://${proxy}:80/
    export https_proxy=${http_proxy}
    export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'
    JAVA_OPTIONS="-Dhttp.proxyHost=${proxy} -Dhttps.proxyHost=${proxy} -Dhttp.proxyPort=80 -Dhttps.proxyPort=80"
  fi
}

function init_env() {
    DEBUG=""
    if [[ "$debug" == true ]];then
      DEBUG="echo "
    fi
}

function check_route53() {
  echo -e "\n************************************************************************"
  echo    "Checking Amazon Route 53 Hosted Zone"
  echo    "  Hosted Zone: ${profile}.a.intuit.com"
  echo -e "************************************************************************"
  HOSTED_ZONE=$(aws route53 --profile ${profile} --region ${region} list-hosted-zones --output text | grep HOSTED | grep ${profile}.a.intuit.com | wc -l)
  if [[ "$HOSTED_ZONE" -lt 1 ]];then
    echo "Hosted Zone ${profile}.a.intuit.com is not configured"
    exit 1
  else
    echo "PASS"
  fi
  
  echo -e "\n************************************************************************"
  echo    "Checking DNS Zone Delegation for ${profile}.a.intuit.com"
  echo -e "************************************************************************"
  nameservers=$(nslookup -type=NS ${profile}.a.intuit.com | grep ${profile}.a.intuit.com | grep awsdns)
  nslookup -type=NS ${profile}.a.intuit.com | grep ${profile}.a.intuit.com | grep awsdns
  if [[ -z "$nameservers" ]]; then
    echo "Zone Delegation for ${profile}.a.intuit.com is not configured"
    exit 1
  else
    echo "PASS"
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
  check_route53
fi
