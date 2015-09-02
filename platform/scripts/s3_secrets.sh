#!/usr/bin/env bash

usage() {
cat << EOF
usage: $0   options action

This script manages secrets s3 bucket
ACTIONS:
    create
    delete
OPTIONS:
   -h       show this message
   -p       AWS/JSD environment
   -r       region
   -P       product
EOF
}

function get_cmd_opts () {
   while getopts "p:r:P:" OPTION
   do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p) profile=$OPTARG ;;
         r) region=$OPTARG ;;
         P) product=$OPTARG ;;
         ?) usage ;;
     esac
   done
   shift $(($OPTIND - 1))
   action=$1
   if [[ -z "$action" ]];then
      usage
      exit 1
   fi
   # Verify we have required options, we can also do additional validation
   if ! [ -n "${profile}" -a -n "${region}" -a -n "${product}" ]; then
      echo "Error: required options not provided -p, -r, -P"
      usage;
      exit 2
   fi
}

function init() {
  profile=slingshot-preprod
  region=us-west-2
  if [[ -n "$proxy" ]]; then
    export http_proxy=http://${proxy}:80/
    export https_proxy=${http_proxy}
    export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'
  fi
}

function init_env() {
  stack_name="${profile}-secrets-bucket"
  bucket_name="iss-${profile}-secrets-${region}"
  CFN_OPTS="ParameterKey=Profile,ParameterValue=iss-${profile}-secrets"
}

function wait_for_stack_completion () { 
  stack_name=$1
  cfn_status=`./query_stack.py -r ${region} -p ${profile} -s "$stack_name" -n -S | awk -F ':' '{ print $2}' 2>/dev/null;`
  # sleep until cloud formation completes
  while [[ "$cfn_status" != "CREATE_COMPLETE" && "$cfn_status" != "UPDATE_COMPLETE" ]]
  do
    cfn_status=`./query_stack.py -r ${region} -p ${profile} -s "$stack_name" -n -S | awk -F ':' '{ print $2}' 2>/dev/null;`
    echo "$stack_name $cfn_status"

    if [[ "$cfn_status" == "CREATE_FAILED" || "$cfn_status" == "ROLLBACK_COMPLETE" || "$cfn_status" == "" ]]; then
      echo "Error: CloudFormation Stack Creation Failed"
      exit 1
    fi
    
    sleep 20
  done
}

function create_s3() {
  # check if stack exists
  echo -e "\n************************************************************************"
  echo    "Checking if Amazon S3 Bucket already exists"
  echo -e "************************************************************************"
  if [ `aws --profile ${profile} cloudformation list-stacks --stack-status-filter CREATE_COMPLETE | grep StackName | grep ${stack_name} > /dev/null 2>&1; echo $?` -eq 0 ]; then
    echo "[INFO] Stack: ${stack_name} already exists - noop"
    exit 1
  fi
  # create s3 bucket
  echo -e "\n************************************************************************"
  echo    "Creating Amazon S3 Bucket"
  echo -e "************************************************************************"
  aws --profile ${profile} cloudformation create-stack --stack-name ${stack_name} \
    --capabilities CAPABILITY_IAM  \
    --template-body file://../../platform/cloudformation/0.s3.json \
    --parameters ${CFN_OPTS}

  wait_for_stack_completion ${stack_name}

  # Enable Versioning
  echo -e "\n************************************************************************"
  echo    "Enabling Amazon S3 Versioning"
  echo -e "************************************************************************"
  aws --profile ${profile} s3api put-bucket-versioning \
    --versioning-configuration Status=Enabled \
    --bucket ${bucket_name}
  
  # Set ACL
  echo -e "\n************************************************************************"
  echo    "Setting Amazon S3 ACL"
  echo -e "************************************************************************"
  aws --profile ${profile} s3api put-bucket-acl \
    --acl bucket-owner-full-control --acl log-delivery-write \
    --bucket ${bucket_name}
  
  # Enable Logging
  echo -e "\n************************************************************************"
  echo    "Enabling Amazon S3 Bucket Logging"
  echo -e "************************************************************************"
  # Need to do this so variables are expanded. If passing JSON as value for aws cli, the variables don't expand due to single quote.
  cat <<JSON >> logging.json
{  "LoggingEnabled":{ "TargetBucket": "${bucket_name}", "TargetPrefix": "logs/S3/" } }
JSON
  
  aws --profile ${profile} s3api put-bucket-logging \
    --bucket ${bucket_name} \
    --bucket-logging-status file://logging.json
}

function delete_s3() {
  b="${bucket_name}"
  echo "Cleaning bucket ${b}"
  aws s3api put-bucket-logging --profile ${profile} --region ${region} --bucket ${b} --bucket-logging-status "{}"
  aws s3api put-bucket-versioning --profile ${profile}  --versioning-configuration Status=Suspended --bucket ${b}
  aws s3api put-bucket-acl --profile ${profile} --region ${region} --acl bucket-owner-full-control --acl log-delivery-write --bucket ${b}
  echo "Getting list of deleted objects to clean up in bucket ${b}..."
  aws s3api  --profile ${profile} --region ${region} list-object-versions --bucket ${b} --output text | grep DELETEMARKERS | awk '{ print $3" "$5 }' > /tmp/bucket_cleanup_${b}.text
  cat /tmp/bucket_cleanup_${b}.text | while read key version; do
    aws s3api --profile ${profile} --region ${region} delete-object --bucket ${b} --key ${key} --version-id ${version}
  done
  echo "Getting list of objects to clean up in bucket ${b}..."
  aws s3api  --profile ${profile} --region ${region} list-object-versions --bucket ${b} --output text | grep VERS | awk '{ print $4" "$8 }' > /tmp/bucket_cleanup_${b}.text
  cat /tmp/bucket_cleanup_${b}.text | while read key version; do
    aws s3api --profile ${profile} --region ${region} delete-object --bucket ${b} --key ${key} --version-id ${version}
  done
  rm -f /tmp/bucket_cleanup_${b}.text

  echo -e "\n************************************************************************"
  echo    "Deleting Amazon S3 Bucket"
  echo -e "************************************************************************"
  if [ `aws --profile ${profile} s3 ls s3://${bucket_name} >/dev/null 2>&1; echo $?` -eq 0 ]; then
    aws --profile ${profile} s3 rb s3://${bucket_name} --force
  fi
  aws --profile ${profile} cloudformation delete-stack --stack-name ${stack_name}
  sleep 20
}

##### Main calls

init
get_cmd_opts $@
init_env

case "$action" in
  create)
    create_s3
    ;;
  delete)
    delete_s3
    ;;
  *)
    usage
    exit 1
esac
