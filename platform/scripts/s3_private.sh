#!/usr/bin/env bash

usage() {
cat << EOF
usage: $0   options action

This script manages private s3 buckets
ACTIONS:
    create
    delete
    update
OPTIONS:
   -h       show this message
   -p       AWS/JSD environment
   -r       region
   -P       product
   -a       AWS account ID of the production account
EOF
}

function get_cmd_opts () {
   while getopts "p:r:P:a:" OPTION
   do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p) profile=$OPTARG ;;
         r) region=$OPTARG ;;
         P) product=$OPTARG ;;
         a) aws_id=$OPTARG ;;
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
  CFN_OPSS=""
  if [[ -n "$proxy" ]]; then
    export http_proxy=http://${proxy}:80/
    export https_proxy=${http_proxy}
    export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'
  fi
}

function init_env() {
  stack_name="${profile}-private-bucket"
  bucket_name="${profile}-${region}"
  CFN_OPTS="ParameterKey=Profile,ParameterValue=${profile}"
  if [ ! -z "${aws_id}" ]; then
    CFN_OPTS="${CFN_OPTS} ParameterKey=AccountId,ParameterValue=${aws_id}"
  fi
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
}

function delete_s3() {
  echo -e "\n************************************************************************"
  echo    "Deleting Amazon S3 Bucket"
  echo -e "************************************************************************"
  if [ `aws --profile ${profile} s3 ls s3://${bucket_name} >/dev/null 2>&1; echo $?` -eq 0 ]; then
    aws --profile ${profile} s3 rb s3://${bucket_name} --force
  fi
  aws --profile ${profile} cloudformation delete-stack --stack-name ${stack_name}
  sleep 20
}

function update_s3() {
  echo -e "\n************************************************************************"
  echo    "Updating Amazon S3 Bucket"
  echo -e "************************************************************************"
  aws --profile ${profile} cloudformation update-stack --stack-name ${stack_name} \
    --capabilities CAPABILITY_IAM  \
    --template-body file://../../platform/cloudformation/0.s3.json \
    --parameters ${CFN_OPTS}

  wait_for_stack_completion ${stack_name}
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
  update)
    update_s3
    ;;
  *)
    usage
    exit 1
esac
