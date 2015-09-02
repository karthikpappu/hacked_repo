#!/usr/bin/env bash

usage() {
cat << EOF
usage: $0   options action

This script deploys the egress at an account level
ACTIONS:
    create
    destroy
    rotate
    config (show configuration)
OPTIONS:
   -h       show this message
   -r       region
   -p       AWS/JSD environment
EOF
}

function get_cmd_opts () {
   while getopts "p:r:e:P:" OPTION
   do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p) profile=$OPTARG ;;
         r) region=$OPTARG ;;
         ?) usage ;;
     esac
   done
   shift $(($OPTIND - 1))
   action=$1
   if [[ -z "$action" ]];then
      usage
      exit 1
   fi
   #Verify we have required options, we can also do additional validation
   if ! [ -n "${profile}" ]; then
      echo "Error: required options not provided -p"
      usage;
      exit 2
   fi
}


function init() {
   region=us-west-2
   profile=slingshot-preprod
   if [[ -n "$proxy" ]];then
    JAVA_OPTIONS="-Dhttp.proxyHost=${proxy} -Dhttps.proxyHost=${proxy} -Dhttp.proxyPort=80 -Dhttps.proxyPort=80" 
   fi
}

function init_env() {
     check_inputs=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -S`
     if [[ "$check_inputs" != "inputs:CREATE_COMPLETE" ]];then
        echo "inputs stack is not ready."
        exit 2
     fi
     AMIid=$(curl -s "http://amiquery.corp.intuit.net/amis?region=${region}&tag=virtualization:hvm&tag=status:available&tag=relatedTechnology:linux" | jq '[.[]] | max_by(.tags.creationDate) | .id' -r )
     ProxySubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$" -o ProxySubnet1Id`
     ProxySubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$" -o ProxySubnet2Id`
     BastionSubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$" -o BastionSubnet1Id`
     BastionSubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$" -o BastionSubnet2Id`
     VpcId=`./query_stack.py -r ${region} -p ${profile} -s "^inputs$" -o VpcId`
     BastionRange1=$(aws --profile ${profile} ec2 describe-subnets --subnet-ids=${BastionSubnet1Id} | jq '.Subnets| .[] | .CidrBlock' -r)
     BastionRange2=$(aws --profile ${profile} ec2 describe-subnets --subnet-ids=${BastionSubnet2Id} | jq '.Subnets| .[] | .CidrBlock' -r)
     PermittedSquidRange=$(aws --profile ${profile} ec2 describe-vpcs --vpc-ids=${VpcId} | jq '.Vpcs| .[] | .CidrBlock' -r)
     VpcId=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o VpcId`
     KeyName=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o KeyName`
     OperatorEmail=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o OperatorEmail`
     JSD_OPTIONS="-a VpcId=${VpcId} -a OperatorEmail=${OperatorEmail} -a KeyName=${KeyName}"
     # Load env settings
     if [[ "$profile" =~ "-prod" ]];then
        env="prod"
     else
        env="preprod"
     fi
     if [[ ! -f "../../platform/settings/aws-${env}.conf" ]];then
        echo "missing settings file platform/settings/aws-${env}.conf"
        exit 2      
     fi
     . "../../platform/settings/aws-${env}.conf"
     if [[ -n "$egress_dns_zone" ]]; then
      dns_zone="$egress_dns_zone"
     else
      dns_zone="${profile}.a.intuit.com"
     fi
     DNS_NAME="slingshot-egress"
}

function migrate_egress() {
  egress_stack=`aws --profile ${profile} --region ${region} cloudformation describe-stacks | grep StackName | grep -egress- | awk -F '"' '{ print $4 }' | sort -r | head -1`
  if [[ -z "$egress_stack" ]];then
    echo "No egress stack found."
    exit 1
  fi
  ELBName=`./query_stack.py -r ${region} -p ${profile} -s "^${egress_stack}\$" -o ProxyELB`
  DNS=`./query_stack.py -r ${region} -p ${profile} -s "^${egress_stack}\$" -o ProxyHost`
  EXISTING_DNS=`./query_stack.py -r ${region} -p ${profile} -s "^dns-${profile}-${region}-egress\$" -o WebLoadBalancerDNSName`
  echo "Exsiting ELB Name: ${EXISTING_ELBName}"
  elb_status=FALSE
  elb_status_command="aws --profile ${profile} --region ${region} elb describe-instance-health --load-balancer-name ${ELBName}"
  ELBInService=`$elb_status_command | grep InService | wc -l`
  ELBOutService=`$elb_status_command | grep -e OutOfService -e Unknown | wc -l`
  echo "ELB Status: $ELBInService instances in services | $ELBOutService out of service"
  if [[ "$ELBInService" -gt 0 && "$ELBOutService" -eq 0 ]];then
    if [[ -z "$EXISTING_DNS" ]]; then
      ACTION="create"
      java $JAVA_OPTIONS -jar JSD-App.jar ${ACTION} -e ${profile} -t ../../platform/cloudformation/5.dns.json \
          $JSD_OPTIONS \
          -i inputs \
          -a WebLoadBalancerDNSName=$DNS \
          -a WebLoadBalancerName=$ELBName \
          -a DNSName=$DNS_NAME \
          -a ZoneName=$dns_zone \
          -a TTL=30 \
          -n dns-${profile}-${region}-egress
      echo "Creating CNAME ${DNS_NAME}.${dns_zone} to $ELB"
    else
      ACTION="update"  
      if [[ "${DNS_NAME}.${dns_zone}" == "$EXISTING_DNS" ]]; then
          echo "$EXISTING_DNS already up to date."
          exit 0
      else
          aws --profile ${profile} --region ${region} cloudformation update-stack \
            --template-body file://../../platform/cloudformation/5.dns.json \
            --stack-name dns-${profile}-${region}-egress --parameters \
            ParameterKey=WebLoadBalancerDNSName,ParameterValue=$DNS \
            ParameterKey=WebLoadBalancerName,ParameterValue=$ELBName \
            ParameterKey=DNSName,ParameterValue=$DNS_NAME \
            ParameterKey=TTL,ParameterValue=30 \
            ParameterKey=ZoneName,ParameterValue=${dns_zone}
      fi
    fi
    wait_for_stack_completion dns-${profile}-${region}-egress
  else
    echo "Not all instances are in service in ${ELBName}"
    exit 1
  fi
}

function create_egress() {
  TAG_DATE=`date +"%Y%m%d-%H%M"`
  egress_stack="${profile}-${region}-egress-${TAG_DATE}"
  java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/0.egress.json \
        $JSD_OPTIONS \
        -a AMIid=${AMIid} \
        -a SubnetIDsForSquidProxy="${ProxySubnet1Id},${ProxySubnet2Id}" \
        -a BastionRange1=${BastionRange1} \
        -a BastionRange2=${BastionRange2}  \
        -a ASGDesired=${egress_asg_size} \
        -a ASGMin=${egress_asg_size} \
        -a ASGMax=${egress_asg_size} \
        -a InstanceType=${egress_instance_type} \
        -a PermittedSquidRange=${PermittedSquidRange} \
        -a SecurityMonitoringEndpointPort=${SecurityMonitoringEndpointPort} \
        -a ProxyPort=${egress_port} \
        -i inputs \
        -n "${egress_stack}"
  wait_for_stack_completion "${egress_stack}"
  ELBName=`./query_stack.py -r ${region} -p ${profile} -s "^${egress_stack}\$" -o ProxyELB`
  elb_status_command="aws --profile ${profile} --region ${region} elb describe-instance-health --load-balancer-name ${ELBName}"
  ELBInService=`$elb_status_command | grep InService | wc -l`
  COUNTER=0
  while [[ "$ELBInService" -eq 0 ]]; do
    echo "Waiting for egress to be available..."
    sleep 20
    ELBInService=`$elb_status_command | grep InService | wc -l`
    let COUNTER=COUNTER+1 
    if [[ "$COUNTER" -gt 30 ]];then
      echo "egress creation failed on stack $egress_stack"
      exit 1
    fi
  done
}

function delete_stack() {
    stack_name=$1
    java $JAVA_OPTIONS -jar JSD-App.jar delete -e ${profile} -n $stack_name 
}

function delete_egress {
  delete_stack "dns-${profile}-${region}-egress"
  for s in `aws --profile ${profile} --region ${region} cloudformation describe-stacks | grep StackName | grep -egress- | awk -F '"' '{ print $4 }' | sort -r`; do
    delete_stack "$s"
  done
}

function rotate_egress {
  current_egress_stack=`aws --profile ${profile} --region ${region} cloudformation describe-stacks | grep StackName | grep -egress- | awk -F '"' '{ print $4 }' | sort -r | head -1`
  if [[ -z "$current_egress_stack" ]];then
    echo "no egress stack found."
    exit 1
  fi
  create_egress
  migrate_egress
  delete_stack "$current_egress_stack"
}

function show_config_egress() {
  current_egress_stack=`aws --profile ${profile} --region ${region} cloudformation describe-stacks | grep StackName | grep -egress- | awk -F '"' '{ print $4 }' | sort -r | head -1`
  if [[ -z "$current_egress_stack" ]];then
    echo "no egress stack found."
    exit 1
  fi
  EXISTING_DNS=`./query_stack.py -r ${region} -p ${profile} -s "^dns-${profile}-${region}-egress\$" -o WebLoadBalancerDNSName`
  if [[ -z "$EXISTING_DNS" ]];then
    echo "no dns egress stack found."
    exit 1
  fi
  echo "ProxyPort=${egress_port}"
  echo "ProxyHost=${DNS_NAME}.${dns_zone}"
}

function wait_for_stack_completion () {
stack_name=$1
  cfn_status=`./query_stack.py -r ${region} -p ${profile} -s "$stack_name" -n -S | awk -F ':' '{ print $2}' 2>/dev/null;`
  #sleep until cloud formation completes
  while ! [[ "$cfn_status" == "CREATE_COMPLETE" || "$cfn_status" == "UPDATE_COMPLETE"  ]]
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

containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

##### Main calls

init
get_cmd_opts $@
init_env

case "$action" in
    config)
        show_config_egress
        ;;
    create)
        egress_stack=`aws --profile ${profile} --region ${region} cloudformation describe-stacks | grep StackName | grep -egress- | awk -F '"' '{ print $4 }' | head -1`
        if [[ -n "$egress_stack" ]]; then
            echo "Egress stack already exists. Try rotating..."
            exit 1
        fi
        create_egress
        migrate_egress
        ;;
    delete)
        delete_egress
        ;;
    rotate)
        egress_stack=`aws --profile ${profile} --region ${region} cloudformation describe-stacks | grep StackName | grep -egress- | awk -F '"' '{ print $4 }' | head -1`
        if [[ -z "$egress_stack" ]]; then
            echo "Egress stack doest not exists. Creating ..."
            create_egress
            migrate_egress           
        else
            rotate_egress
        fi
        ;;
    *)
      usage
      exit 1
esac


