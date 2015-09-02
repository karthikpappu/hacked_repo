#!/bin/sh

usage() {
cat << EOF
usage: $0   options

This script copies a directory from a src bucket to production bucket
OPTIONS
   -h       show this message
   -r       region
   -P       aws preprod profile
   -p       aws profile
   -e       environment
   -s       source s3 artifacts url
EOF
}

function get_cmd_opts () {
   while getopts "r:p:P:e:s:?" OPTION
   do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         r) region=$OPTARG ;;
         p) profile=$OPTARG ;;
         P) preprod_profile=$OPTARG ;;
         e) env=$OPTARG ;;
         s) src_url=$OPTARG ;;
         ?) usage ;;
     esac
   done
   #Verify we have required options, we can also do additional validation
   if ! [ -n "${region}" -a -n "${profile}" -a -n "${preprod_profile}" -a -n "${env}" -a -n "${src_url}" ]; then
      echo "Error: required options not provided, -r, -p, -P, -e, -s"
      usage;
      exit 2
   fi
}


function init() {
  region=us-west-2
  profile=""
  preprod_profile=""
  env=""
  src_url=""
  if [[ -n "$proxy" ]];then
    export http_proxy=http://${proxy}:80/
    export https_proxy=${http_proxy}
    export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'
    JAVA_OPTIONS="-Dhttp.proxyHost=${proxy} -Dhttps.proxyHost=${proxy} -Dhttp.proxyPort=80 -Dhttps.proxyPort=80"
  fi
}

function init_env() {
   check_inputs=`./query_stack.py -r ${region} -p ${profile} -s "^inputs\$" -S`
   if ! [ "$check_inputs" == "inputs:CREATE_COMPLETE" ] || [ "$check_inputs" == "inputs:UPDATE_COMPLETE" ]; then
      echo "inputs stack is not ready."
      exit 2
   fi
   # Load env settings
   if [[ ! -f "../../platform/settings/${env}.conf" ]];then
      echo "missing settings file platform/settings/${env}.conf"
      exit 2      
   fi
   source "../../platform/settings/${env}.conf"
   #if [[ -n "$dns_zone" ]]; then
    #zone="$dns_zone"
   #fi
}

function s3_sync() {
  bucket_name=$(basename ${src_url})
  prod_url=s3://${profile}-${region}/${bucket_name}
  # sync from preprod to prod
  echo -e "\n************************************************************************"
  echo    "Copying ${bucket_name} from ${preprod_profile} to ${profile}"
  echo -e "************************************************************************"
  aws s3 sync --profile ${profile} ${src_url} ${prod_url}
  if [ $? -ne 0 ]; then
    echo "s3 transfers failed"
    exit 1
  fi
#  # sync from preprod to local directory
#  echo -e "\n************************************************************************"
#  echo    "Copying ${bucket_name} from ${preprod_profile} to a local directory"
#  echo -e "************************************************************************"
#  aws s3 sync --profile ${preprod_profile} ${src_url} ./${bucket_name}
#  # sync from local directory to prod and delete from local
#  echo -e "\n************************************************************************"
#  echo    "Copying ${bucket_name} from a local directory to ${profile}"
#  echo -e "************************************************************************"
#  aws s3 sync --profile ${profile} ./${bucket_name} ${prod_url}
#  # clean up local directory
#  echo -e "\n************************************************************************"
#  echo    "Cleaning up the local directory"
#  echo -e "************************************************************************"
#  rm -f ./${bucket_name}/*
}

function test_sync() {
  echo test aws s3 sync --profile ${profile} ${src_url} ${prod_url}
}

init
get_cmd_opts $@
init_env
s3_sync
#test_sync
exit 0
