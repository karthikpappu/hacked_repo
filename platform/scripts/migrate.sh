#!/bin/sh

usage() {
cat << EOF
usage: $0   options

This script updates DNS from one ELB to an other for stack migration
OPTIONS
   -h       show this message
   -r       region
   -p       aws profile
   -P       product
   -V       build version
   -e       environment
   -z       dns zone 
   -b       branch
   -d       delete previous stack
   -c       cleanup stack
   -l       stack history
   -w       whitelisted stacks
EOF
}

function get_cmd_opts () {
   while getopts "dcp:r:e:V:P:z:b:l:w:?" OPTION
   do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p) profile=$OPTARG ;;
         r) region=$OPTARG ;;
         P) product=$OPTARG ;;
         V) version=$OPTARG ;;
         e) env=$OPTARG ;;
         d) destroy_stacks=true ;;
         z) zone=$OPTARG ;;
         b) branch=$OPTARG ;;
         c) cleanup_stacks=true ;;
         l) history=$OPTARG ;;
         w) whitelist=$OPTARG ;;
         ?) usage ;;
     esac
   done
   #Verify we have required options, we can also do additional validation
   if ! [ -n "${profile}" -a -n "${product}" -a -n "${version}" -a -n "${env}" -a -n "$zone" -a -n "$branch" ]; then
      echo "Error: required options not provided, -p, -P, -V, -e, -z, -b"
      usage;
      exit 2
   fi
}


function init() {
   type=tomcat
   region=us-west-2
   profile=sbfs-slingshot-preprod-preprod
   history=0
   whitelist=''
   if [[ -n "$proxy" ]];then
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
   if [[ -n "$dns_zone" ]]; then
    zone="$dns_zone"
   fi
   if [[ "$blue_green_deployment" == "false" ]]; then
      version=`./query_stack.py -r ${region} -p ${profile} -s "^elb-${product}-${branch}-.*-${env}" -S | awk -F ':' '{ print $1 }' | sed -n "s/.*-\([0-9]\+\)-${env}$/\1/p"`
      if [[ -z "$version" ]];then
        echo "Error: No deployed version found for ${product}-${branch} on ${env}"
        exit 2
      fi
   fi
   check_elb=`./query_stack.py -r ${region} -p ${profile} -s "^elb-${product}-${branch}-${version}-${env}\$" -S`
   if ! [[ "$check_elb" == "elb-${product}-${branch}-${version}-${env}:CREATE_COMPLETE" || "$check_elb" == "elb-${product}-${branch}-${version}-${env}:UPDATE_COMPLETE" ]];then
      echo "Error: elb stack is not ready."
      exit 2
   fi
}

function wait_for_stack_completion () { 
  stack_name=$1
  cfn_status=`./query_stack.py -r ${region} -p ${profile} -s "^$stack_name\$" -S | awk -F ':' '{ print $2}' 2>/dev/null;`
  #sleep until cloud formation completes
  while ! [[ "$cfn_status" == "CREATE_COMPLETE" || "$cfn_status" == "UPDATE_COMPLETE"  ]]
  do
    cfn_status=`./query_stack.py -r ${region} -p ${profile} -s "^$stack_name\$" -S | awk -F ':' '{ print $2}' 2>/dev/null;`
    echo "$stack_name $cfn_status"
    sleep 30
  done
}

function get_current_elb () {
  # Get current ELB status
  EXISTING_ELBName=`./query_stack.py -r ${region} -p ${profile} -s "^dns-${product}-${branch}-${env}\$" -o WebLoadBalancerName`
  EXISTING_DNS=`./query_stack.py -r ${region} -p ${profile} -s "^dns-${product}-${branch}-${env}\$" -o WebLoadBalancerDNSName`
  echo "Exsiting ELB Name: ${EXISTING_ELBName}"
  echo "DNS: $EXISTING_DNS"
  DNS_NAME="${env}-${branch}-${product}"

  # TODO: do we really need this, this probably will fail on the first run of DNS
  #if [ -z "$EXISTING_ELBName" -o -z "$EXISTING_DNS" ];then
      #echo "Failed to query the stack dns-${product}-${branch}-${env}"
      #exit 1
  #fi

}
function migrate() {
  ELBName=`./query_stack.py -r ${region} -p ${profile} -s "^elb-${product}-${branch}-${version}-${env}\$" -o WebLoadBalancerName`
  DNS=`./query_stack.py -r ${region} -p ${profile} -s "^elb-${product}-${branch}-${version}-${env}\$" -o WebLoadBalancerDNSName`
  EXISTING_DNS=`./query_stack.py -r ${region} -p ${profile} -s "^dns-${product}-${branch}-${env}\$" -o WebLoadBalancerDNSName`
  echo "Existing ELB Name: ${EXISTING_ELBName}"
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
          -a ZoneName=$zone \
          -a TTL=30 \
          -n dns-${product}-${branch}-${env}
      echo "Creating CNAME ${DNS_NAME}.${zone} to $ELB"
    else
      ACTION="update"  
      if [[ "${DNS_NAME}.${zone}" == "$EXISTING_DNS" ]]; then
          echo "$EXISTING_DNS already up to date."
          exit 0
      else
          aws --profile ${profile} --region ${region} cloudformation update-stack \
            --template-body file://../../platform/cloudformation/5.dns.json \
            --stack-name dns-${product}-${branch}-${env} --parameters \
            ParameterKey=WebLoadBalancerDNSName,ParameterValue=$DNS \
            ParameterKey=WebLoadBalancerName,ParameterValue=$ELBName \
            ParameterKey=DNSName,ParameterValue=$DNS_NAME \
            ParameterKey=TTL,ParameterValue=30 \
            ParameterKey=ZoneName,ParameterValue=${zone}
      fi
    fi
    wait_for_stack_completion dns-${product}-${branch}-${env}    
  else
    echo "Not all instances are in service in ${ELBName}"
    exit 1
  fi
}

function test_dns () {
  #should verify DNS is updated
  dig_output=`dig @dns_server +noall +answer ${DNS_NAME}.${zone}`
  if ! [[ ${dig_output} == *"${ELBName}"* ]]
  then
    echo "DNS not set to ${ELBName}"
    echo "dig: ${dig_output}"
    exit 4
  fi
}

function destroy_prev_stacks () {
  #destroy previous elb
  if [[ -n "${destroy_stacks}" ]]
  then
    elb_tag_command="aws --profile ${profile} --region ${region} elb describe-tags --load-balancer-name ${EXISTING_ELBName}"
    elb_cf_stack=`${elb_tag_command} | jq '.TagDescriptions[] |.Tags[] | select(.Key == "aws:cloudformation:stack-name") | .Value' | tr -d \"`
    stack_suffix=$( cut -d '-' -f 2- <<< "$elb_cf_stack" ); echo $stack_suffix
    stacks="admin appasg webasg elb ilb alarms sg"
    for stack in $stacks
    do
      delete_cf_stack $stack $stack_suffix
    done
  fi
}

function delete_cf_stack () {
  if [[ -n "$1" || -n $2 ]]
  then
    echo "deleting stack: $1-$2"
    java $JAVA_OPTIONS -jar JSD-App.jar delete -e ${profile} -n $1-$2
  else
    echo "ERROR: stack information not set, unable to delete stack"
  fi
}

function cleanup_stacks () {
  # cleanup old stacks
  if [[ -n "${cleanup_stacks}" && "$version" -gt "$history" ]]; then
    old_stacks=`./cleanup_stacks.py -l -r $region -p $profile -s .*-${product}-${branch}-[0-9]+-${env} | grep $product | awk 'BEGIN {FS="-"} {print $(NF-1)}' | sort -u`
    whitelist=",${whitelist},"
    for i in $old_stacks; do
      if [[ "$i" -lt "$((version - history))" && ! "$whitelist" =~ ",${i}," ]]; then
        ./cleanup_stacks.py -r $region -p $profile -s .*-${product}-${branch}-${i}-${env} -y
      fi
    done
  fi
}

init
get_cmd_opts $@
init_env
get_current_elb
migrate
#test_dns
destroy_prev_stacks
cleanup_stacks
exit 0

