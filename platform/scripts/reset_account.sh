#!/usr/bin/env bash

# Reset an account to PCC state

usage() {
cat << EOF
usage: $0   options action

This script reset an AWS account to PCC account state
OPTIONS:
   -h       show this message
   -p       AWS/JSD environment
   -r       region
   -y       assume yes
   -d       debug
EOF
}

function get_cmd_opts () {
   while getopts "p:r:hyd" OPTION
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
   if ! [ -n "${profile}" -a -n "${region}" ]; then
      echo "Error: required options not provided -p, -r"
      usage;
      exit 2
   fi
}

function init() {
  profile=slingshot-preprod
  region=us-west-2
  assumeyes=false
  debug=false
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

function reset_s3() {
   for b in `aws s3 ls --profile ${profile} --region ${region} --output text | grep ${region} | awk '{ print $3 }'`; do
    echo "Cleaning bucket ${b}"
    $DEBUG aws s3api put-bucket-logging --profile ${profile} --region ${region} --bucket ${b} --bucket-logging-status "{}"
    $DEBUG aws s3api put-bucket-versioning --profile ${profile}  --versioning-configuration Status=Suspended --bucket ${b}
    $DEBUG aws s3api put-bucket-acl --profile ${profile} --region ${region} --acl bucket-owner-full-control --acl log-delivery-write --bucket ${b}
    echo "Getting list of deleted objects to clean up in bucket ${b}..."
    aws s3api  --profile ${profile} --region ${region} list-object-versions --bucket ${b} --output text | grep DELETEMARKERS | awk '{ print $3" "$5 }' > /tmp/bucket_cleanup_${b}.text
    cat /tmp/bucket_cleanup_${b}.text | while read key version; do
        $DEBUG aws s3api --profile ${profile} --region ${region} delete-object --bucket ${b} --key ${key} --version-id ${version}
    done
    echo "Getting list of objects to clean up in bucket ${b}..."
    aws s3api  --profile ${profile} --region ${region} list-object-versions --bucket ${b} --output text | grep VERS | awk '{ print $4" "$8 }' > /tmp/bucket_cleanup_${b}.text
    cat /tmp/bucket_cleanup_${b}.text | while read key version; do
        $DEBUG aws s3api --profile ${profile} --region ${region} delete-object --bucket ${b} --key ${key} --version-id ${version}
    done
    rm -f /tmp/bucket_cleanup_${b}.text
    $DEBUG aws s3 --profile ${profile} --region ${region} rb s3://${b} --force
  done
  sleep 5
  echo "Cleaning Cloudformation S3 bucket related stacks..."
  for s in `aws cloudformation --profile ${profile} --region ${region} list-stacks --stack-status-filter CREATE_COMPLETE ROLLBACK_COMPLETE --output text | grep -e "${profile}-.*-bucket" | awk '{print $4}'`; do
    echo "deleting stack ${s}..."
    $DEBUG aws cloudformation --profile ${profile} --region ${region} delete-stack --stack-name ${s}
  done
}

function reset_rds() {
  for r in $(aws rds describe-db-instances --region ${region} --profile ${profile} | grep '"DBInstanceIdentifier"' | cut -d\" -f4); do
    echo "Deleting RDS ${r}"
    $DEBUG aws rds delete-db-instance --region ${region} --profile ${profile} --skip-final-snapshot --db-instance-identifier ${r}
  done
}

function reset_keypair() {
  for k in `aws ec2 describe-key-pairs --profile ${profile} --region ${region} --output text | awk '{ print $3 }'`; do
    $DEBUG aws ec2 --profile ${profile} --region ${region} delete-key-pair --key-name "${k}"
  done
}

function reset_kms() {
  for k in `aws kms list-keys --profile ${profile} --region ${region} --output text | awk '{ print $2 }'`; do
    $DEBUG aws kms --profile ${profile} --region ${region} disable-key --key-id "${k}"
  done
}

function reset_route53() {
  for d in `aws route53 list-hosted-zones --profile ${profile} --region ${region} --output text | awk '{print $3}'`; do
    for r in `aws route53 list-resource-record-sets --profile ${profile} --region ${region} --hosted-zone-id ${d} --output text | grep -e "\tCNAME$" | awk '{print $2}'`; do
      cname_dest=`aws route53  list-resource-record-sets --profile ${profile} --region ${region} --hosted-zone-id ${d} --output text | grep -e "RESOURCERECORDSETS\t${r}" -A 1 | tail -1 | awk '{print $2 }'`
      ttl=`aws route53 list-resource-record-sets --profile ${profile} --region ${region} --hosted-zone-id ${d} --output text | grep -e "\tCNAME$" | grep -e "\t${r}\t" | awk '{print $3}'`
      route53_string="{
  \"Comment\": \"removal of record ${r}\",
  \"Changes\": [
    {
      \"Action\": \"DELETE\",
      \"ResourceRecordSet\": {
        \"Name\": \"${r}\",
        \"Type\": \"CNAME\",
        \"TTL\": $ttl,
        \"ResourceRecords\": [
          {
            \"Value\": \"${cname_dest}\"
          }
        ]
      }
    }
  ]
}"
      route53_string=`echo $route53_string`
      echo "Removing DNS CNAME $r"
      $DEBUG aws route53 change-resource-record-sets --profile ${profile} --region ${region} --hosted-zone-id ${d} --change-batch "${route53_string}"
    done
  done
}

function clean_ebs_volumes() {
  for v in `aws ec2 describe-volumes --profile ${profile} --region ${region} --output text | grep available | grep -v TAGS | awk '{ print $8 }'`; do
    echo "Deleting volume ${v}"   
    $DEBUG aws ec2 --profile ${profile} --region ${region} delete-volume --volume-id ${v}
  done
}

function reset_stacks() {
  $DEBUG ./cleanup_stacks.py -r ${region} -s '.*' -p ${profile} -y
}

function reset_account() {
  echo "Resetting account ${profile}:"
  reset_s3
  reset_rds
  reset_keypair
  reset_kms
  reset_route53
  reset_stacks
  clean_ebs_volumes
}

init
get_cmd_opts $@
init_env
confirmation=true
if [[ "$assumeyes" == false ]];then
  confirmation=""
  while [[ -z "$confirmation" ]]; do
    echo -n "Are you ready to reset profile ${profile} (yes/NO):"
    read confirmation
    if [[ "$confirmation" == "yes" ]];then
      confirmation=true
    else
      confirmation=false
    fi
  done
fi
if [[ "$confirmation" == true ]];then
  reset_account
fi

