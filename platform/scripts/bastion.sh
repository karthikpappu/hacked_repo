#!/usr/bin/env bash

usage() {
cat << EOF
usage: $0   options action

This script deploys a bastion host to AWS using CF stacks
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
    JAVA_OPTIONS="-Dhttp.proxyHost=${proxy} -Dhttps.proxyHost=${proxy} -Dhttp.proxyPort=80 -Dhttps.proxyPort=80"
  fi
}

function get_jsd() {
  if [[ ! -f JSD-App.jar ]]; then
    echo -e "\n************************************************************************"
    echo    "Downloading Java Simple Deploy"
    echo -e "************************************************************************"
    wget -nv http://fmsscm.corp.intuit.net/fms-build/view/TAC/job/CI-devops-JSD-trunk/lastSuccessfulBuild/artifact/JSD-App/target/JSD-App.jar
  fi
}

function init_env() {
  BASTION_NAME="bastion-${product}"
  HostedZone="${profile}.a.intuit.com"
  check_inputs=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -S`
  if [[ "$check_inputs" != "inputs:CREATE_COMPLETE" ]];then
     echo "inputs stack is not ready."
     exit 2
  fi
  VpcId=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o VpcId`
  KeyName=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o KeyName`
  OperatorEmail=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o OperatorEmail`
  echo "$VpcId $KeyName $OperatorEmail"
  JSD_OPTIONS="-a VpcId=${VpcId} -a OperatorEmail=${OperatorEmail} -a KeyName=${KeyName}"
}

function wait_for_stack_completion () { 
stack_name=$1
  cfn_status=`./query_stack.py -r ${region} -p ${profile} -s "$stack_name" -n -S | awk -F ':' '{ print $2}' 2>/dev/null;`
  # sleep until cloud formation completes
  while [ "$cfn_status" != "CREATE_COMPLETE" ]
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

function create_bastion() {
  # check if bastion exists
  echo -e "\n************************************************************************"
  echo    "Checking if Bastion Host already exists"
  echo -e "************************************************************************"
  if [ `aws --profile ${profile} cloudformation list-stacks --stack-status-filter CREATE_COMPLETE | grep StackName | grep ${BASTION_NAME} > /dev/null 2>&1; echo $?` -eq 0 ]; then
    echo -e "Bastion Host: ${BASTION_NAME} already exists"
    exit 1
  else
    # Get settings
    AMIid=$(curl -s "http://amiquery.corp.intuit.net/amis?region=${region}&tag=virtualization:hvm&tag=status:available&tag=relatedTechnology:linux" | jq '[.[]] | max_by(.tags.creationDate) | .id' -r )
    SAGSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$" -o SAGSecGrp`
    BastionSubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$" -o BastionSubnet1Id`
    BastionSubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$" -o BastionSubnet2Id`
    AvailabilityZone1=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$" -o AvailabilityZone1`
    AvailabilityZone2=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$" -o AvailabilityZone2`
    echo -e "\n************************************************************************"
    echo    "Creating a Bastion Host"
    echo -e "************************************************************************"
    java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/0.bastion_host_public.json \
        $JSD_OPTIONS \
        -a AMIid=${AMIid} \
        -a SAGSecurityGroup=${SAGSecGrp} \
        -a BastionSubnet1=${BastionSubnet1Id} \
        -a BastionSubnet2=${BastionSubnet2Id} \
        -a AvailabilityZone1=${AvailabilityZone1} \
        -a AvailabilityZone2=${AvailabilityZone2} \
        -i inputs \
        -n ${BASTION_NAME}
    wait_for_stack_completion ${BASTION_NAME}
  fi
}

function delete_bastion() {
  echo -e "\n************************************************************************"
  echo    "Deleting CloudFormation Stacks"
  echo -e "************************************************************************"
  delete_stack ${BASTION_NAME}
  delete_stack dns-${BASTION_NAME}

}

function delete_stack() {
    stack_name=$1
    java $JAVA_OPTIONS -jar JSD-App.jar delete -e ${profile} -n $stack_name 
}

function create_dns () {
  DNS=`aws ec2 describe-instances --profile ${profile} --filters Name=instance-state-name,Values=running Name=tag-value,Values=BastionASG | grep PublicIpAddress | cut -d\" -f4`
  echo -e "\n************************************************************************"
  echo    "Creating Amazon Route 53 for Bastion Host"
  echo    "  Host Alias: ${BASTION_NAME}.${HostedZone}"
  echo -e "************************************************************************"
  java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/5.dns.json \
      $JSD_OPTIONS \
      -i inputs \
      -a WebLoadBalancerDNSName=${DNS} \
      -a WebLoadBalancerName=${BASTION_NAME} \
      -a DNSName=${BASTION_NAME} \
      -a ZoneName=${HostedZone} \
      -a TTL=30 \
      -a RecordType=A \
      -n dns-${BASTION_NAME}
}

##### Main calls

init
get_jsd
get_cmd_opts $@
init_env

case "$action" in
    create)
        create_bastion
        sleep 5
        create_dns
        ;;
    delete)
        delete_bastion
        ;;
    *)
      usage
      exit 1
esac
