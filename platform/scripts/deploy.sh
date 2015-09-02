#!/usr/bin/env bash

usage() {
cat << EOF
usage: $0   options action

This script deploys a full component to AWS using CF stacks
ACTIONS:
    create
    destroy
OPTIONS:
   -h       show this message
   -r       region
   -p       AWS/JSD environment
   -P       product
   -V       version
   -e       environment
   -u       s3 artifacts url
   -b       branch
   -t       type [ tomcat (default) / tomcat8 / nodejs ]
EOF
}

function get_cmd_opts () {
   while getopts "p:r:e:V:P:u:t:b:" OPTION
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
         u) url=$OPTARG ;;
         t) apptype=$OPTARG ;;
         b) branch=$OPTARG ;;
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
   if ! [ -n "${profile}" -a -n "${product}" -a -n "${env}" ]; then
      echo "Error: required options not provided -p, -P, -e"
      usage;
      exit 2
   fi
}


function init() {
  apptype=tomcat
  region=us-west-2
  profile=slingshot-preprod
  default_ami=ami-ad34119d
  web_ami=${default_ami}
  app_ami=${default_ami}
  admin_ami=${default_ami}
  if [[ -n "$proxy" ]]; then
   export http_proxy=http://${proxy}:80/
   export https_proxy=${http_proxy}
   export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'
   JAVA_OPTIONS="-Dhttp.proxyHost=${proxy} -Dhttps.proxyHost=${proxy} -Dhttp.proxyPort=80 -Dhttps.proxyPort=80"
  fi
}

function init_env() {
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
     # Load env settings
     if [[ ! -f "../../platform/settings/${env}.conf" ]];then
        echo "missing settings file platform/settings/${env}.conf"
        exit 2
     fi
     source "../../platform/settings/${env}.conf"
     detect_egress
}

function detect_egress() {
  ./egress.sh -r ${region} -p ${profile} config > egress_config
  source egress_config
  if [ -z "$ProxyPort" -o -z "$ProxyHost" ];then
    echo "egress is not configured properly. Please check your egress stacks."
    exit 1
  fi
}

function create_alarms() {
    java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/2.alarm.actions.json \
       -i inputs \
       -n alarms-${product}-${branch}-${version}-${env}
}

function create_security_groups() {
  java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/2.security_groups.json \
  -i inputs \
  -n sg-${product}-${branch}-${version}-${env}
}

function create_web_elb() {
    elb_type=$1

    if [[ "$elb_type" == "private" ]];then
    ElbSubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o WebSubnet1Id`
    ElbSubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o WebSubnet2Id`
    elb_scheme="internal"
    else
    ElbSubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o ElbSubnet1Id`
    ElbSubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o ElbSubnet2Id`
    elb_scheme="internet-facing"
    fi
    WebSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "sg-${product}-${branch}-${version}-${env}" -n -o WebSecGrp`
    ELBSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "sg-${product}-${branch}-${version}-${env}" -n -o ELBSecGrp`

   java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/3.web-elb.json \
        $JSD_OPTIONS \
        -a SubnetIds="$ElbSubnet1Id,$ElbSubnet2Id" \
        -a ElbScheme=$elb_scheme \
        -a WebElbAccessSecurityGroup=$ELBSecGrp \
        -a WebAccessSecurityGroup=$WebSecGrp \
        -n elb-${product}-${branch}-${version}-${env} &
}

function create_web_asg() {
    WebAvailabilityZone1=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AvailabilityZone1`
    WebAvailabilityZone2=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AvailabilityZone2`
    WebSubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o WebSubnet1Id`
    WebSubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o WebSubnet2Id`
    WebSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "sg-${product}-${branch}-${version}-${env}" -n -o WebSecGrp`
    SAGSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "sg-${product}-${branch}-${version}-${env}" -n -o SAGSecGrp`
    WebSecGrps=${WebSecGrp},${SAGSecGrp}
    Ilb=`./query_stack.py -r ${region} -p ${profile} -s ilb-${product}-${branch}-${version}-${env} -o AppLoadBalancerDNSName`
    Elb=`./query_stack.py -r ${region} -p ${profile} -s elb-${product}-${branch}-${version}-${env} -o WebLoadBalancerName`
    s3bucket=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o S3Bucket`
    ebs_kms_key=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o EbsEncryptionKey`
    secretss3bucket=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o SecretsS3bucket`
    s3_secrets_key=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o SecretsEncryptionKey`
    java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/4.asg.json \
        $JSD_OPTIONS \
        -a SecurityGroups=$WebSecGrps \
        -a ElasticLoadBalancer=$Elb \
        -a Role=web \
        -a S3bucket=${s3bucket} \
        -a EBSEncryptionKey="$ebs_kms_key" \
        -a SecretsS3bucket="$secretss3bucket" \
        -a SecretsEncryptionKey="$s3_secrets_key" \
        -a SecretsPrefix="${product}/${env}/web" \
        -a SubnetIds="$WebSubnet1Id,$WebSubnet2Id" \
        -a AvailabilityZones="$WebAvailabilityZone1,$WebAvailabilityZone2" \
        -a Environment=${env} \
        -a MinimumInstances=${web_asg_min_size} \
        -a MaximumInstances=${web_asg_max_size} \
        -a InstanceType=${web_instance_type} \
        -i inputs \
        -a ProxyHost=$ProxyHost \
        -a ProxyPort=$ProxyPort \
        -i alarms-${product}-${branch}-${version}-${env} \
        -a Version=${version} \
        -a Product=${product} \
        -a ArtifactUrl=${url} \
        -a RuntimeData="ilb_dns=${Ilb};ilb_port=8443;" \
        -a AMIId=${web_ami} \
        -n webasg-${product}-${branch}-${version}-${env} &
}

function update_asg() {
    asg_type=$1
    template=$2
    exiting_stack=`./query_stack.py -r ${region} -p ${profile} -s "${asg_type}-${product}-${branch}-\d+-${env}" -S | awk -F ':' '{ print $1 }'`
    echo "Updating stack ${exiting_stack} with version ${version}"
    java $JAVA_OPTIONS -jar JSD-App.jar update -e ${profile} -t ../../platform/cloudformation/${template} \
        -a Version=${version} \
        -a ArtifactUrl=${url} \
        -n ${exiting_stack} &
}

function create_app_ilb() {
    AppSubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AppSubnet1Id`
    AppSubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AppSubnet2Id`
    AppSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "sg-${product}-${branch}-${version}-${env}" -n -o AppSecGrp`
    ILBSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "sg-${product}-${branch}-${version}-${env}" -n -o ILBSecGrp`

    java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/3.app-ilb.json \
        $JSD_OPTIONS \
        -a SubnetIds="$AppSubnet1Id,$AppSubnet2Id" \
        -a AppAccessSecurityGroup=$AppSecGrp \
        -a AppIlbAccessSecurityGroup=$ILBSecGrp \
        -n ilb-${product}-${branch}-${version}-${env} &
}

function create_app_asg() {
    role=$1
    AppAvailabilityZone1=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AvailabilityZone1`
    AppAvailabilityZone2=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AvailabilityZone2`
    AppSubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AppSubnet1Id`
    AppSubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AppSubnet2Id`
    AppSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "sg-${product}-${branch}-${version}-${env}" -n -o AppSecGrp`
    SAGSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "sg-${product}-${branch}-${version}-${env}" -n -o SAGSecGrp`
    AppSecGrps=${AppSecGrp},${SAGSecGrp}
    Ilb=`./query_stack.py -r ${region} -p ${profile} -s ilb-${product}-${branch}-${version}-${env} -n -o AppLoadBalancerName`
    s3bucket=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o S3Bucket`
    ebs_kms_key=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o EbsEncryptionKey`
    secretss3bucket=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o SecretsS3bucket`
    s3_secrets_key=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o SecretsEncryptionKey`
    java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/4.asg.json \
        $JSD_OPTIONS \
        -a SecurityGroups=$AppSecGrps \
        -a ElasticLoadBalancer=$Ilb \
        -a Role=$role \
        -a S3bucket=${s3bucket} \
        -a EBSEncryptionKey="$ebs_kms_key" \
        -a SecretsS3bucket="$secretss3bucket" \
        -a SecretsEncryptionKey="$s3_secrets_key" \
        -a SecretsPrefix="${product}/${env}/app" \
        -a SubnetIds="$AppSubnet1Id,$AppSubnet2Id" \
        -a AvailabilityZones="$AppAvailabilityZone1,$AppAvailabilityZone2" \
        -a Environment=${env} \
        -a MinimumInstances=${app_asg_min_size} \
        -a MaximumInstances=${app_asg_max_size} \
        -a InstanceType=${app_instance_type} \
        -i inputs \
        -a ProxyHost=$ProxyHost \
        -a ProxyPort=$ProxyPort \
        -i alarms-${product}-${branch}-${version}-${env} \
        -a Version=${version} \
        -a Product=${product} \
        -a ArtifactUrl=${url} \
        -a AMIId=${app_ami} \
        -n appasg-${product}-${branch}-${version}-${env} &
}

function create_admin_asg() {
    role="admin"
    AppAvailabilityZone1=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AvailabilityZone1`
    AppAvailabilityZone2=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AvailabilityZone2`
    AppSubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AppSubnet1Id`
    AppSubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AppSubnet2Id`
    AppSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "sg-${product}-${branch}-${version}-${env}" -n -o AppSecGrp`
    SAGSecGrp=`./query_stack.py -r ${region} -p ${profile} -s "sg-${product}-${branch}-${version}-${env}" -n -o SAGSecGrp`
    AppSecGrps=${AppSecGrp},${SAGSecGrp}
    Ilb=`./query_stack.py -r ${region} -p ${profile} -s ilb-${product}-${branch}-${version}-${env} -n -o AppLoadBalancerName`
    s3bucket=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o S3Bucket`
    ebs_kms_key=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o EbsEncryptionKey`
    secretss3bucket=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o SecretsS3bucket`
    s3_secrets_key=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o SecretsEncryptionKey`
    java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/4.asg-noelb.json \
        $JSD_OPTIONS \
        -a SecurityGroups=$AppSecGrps \
        -a ElasticLoadBalancer=$Ilb \
        -a Role=$role \
        -a S3bucket=${s3bucket} \
        -a EBSEncryptionKey="$ebs_kms_key" \
        -a SecretsS3bucket="$secretss3bucket" \
        -a SecretsEncryptionKey="$s3_secrets_key" \
        -a SecretsPrefix="${product}/${env}/admin" \
        -a SubnetIds="$AppSubnet1Id,$AppSubnet2Id" \
        -a AvailabilityZones="$AppAvailabilityZone1,$AppAvailabilityZone2" \
        -a Environment=${env} \
        -a MinimumInstances=${admin_asg_min_size} \
        -a MaximumInstances=${admin_asg_max_size} \
        -a InstanceType=${admin_instance_type} \
        -i alarms-${product}-${branch}-${version}-${env} \
        -i inputs \
        -a ProxyHost=$ProxyHost \
        -a ProxyPort=$ProxyPort \
        -a Version=${version} \
        -a Product=${product} \
        -a ArtifactUrl=${url} \
        -a AMIId=${admin_ami} \
        -n admin-${product}-${branch}-${version}-${env}
}

function get_elb() {
    ELB=`./query_stack.py -r ${region} -p ${profile} -s "elb-${product}-${branch}-${version}-${env}" -n -o WebLoadBalancerDNSName`
    echo "elb name: ${ELB}"
}

function wait_for_stack_completion () {
stack_name=$1
  cfn_status=`./query_stack.py -r ${region} -p ${profile} -s "$stack_name" -n -S | awk -F ':' '{ print $2}' 2>/dev/null;`
  #sleep until cloud formation completes
  while [[ "$cfn_status" != "CREATE_COMPLETE"  &&  "$cfn_status" != "UPDATE_COMPLETE" ]]
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

function delete_stack() {
    stack_name=$1
    java $JAVA_OPTIONS -jar JSD-App.jar delete -e ${profile} -n $stack_name
}

function create_web_app() {
        create_alarms
        create_security_groups
        if [[ "$admin_enabled" == "true" ]];then
          create_admin
        fi
        create_web_elb "${web_elb_type}"
        create_app_ilb
        wait_for_stack_completion elb-${product}-${branch}-${version}-${env}
        wait_for_stack_completion ilb-${product}-${branch}-${version}-${env}
        create_web_asg
        create_app_asg "$apptype"
        wait_for_stack_completion webasg-${product}-${branch}-${version}-${env}
        wait_for_stack_completion appasg-${product}-${branch}-${version}-${env}
        get_elb
}

# check if existing stacks are present
# If present, run update of the asg stacks with new version
# If not present, run create_web_app
function update_web_app() {
        already_running_flag=true
        for s in appasg webasg; do
          stack_present=`./query_stack.py -r ${region} -p ${profile} -s "${s}-${product}-${branch}-\d+-${env}" -S | grep -e CREATE_COMPLETE -e UPDATE_COMPLETE | wc -l`
          if [[ "$stack_present" == "0" ]];then
            already_running_flag=false
          fi
        done
        if [[ "$already_running_flag" == true ]]; then
          if [[ "$admin_enabled" == "true" ]];then
            update_asg "admin" "4.asg-noelb.json"
          fi
          update_asg "webasg" "4.asg.json"
          update_asg "appasg" "4.asg.json"
          exiting_stack=`./query_stack.py -r ${region} -p ${profile} -s "webasg-${product}-${branch}-\d+-${env}" -S | awk -F ':' '{ print $1 }'`
          wait_for_stack_completion "${exiting_stack}"
          exiting_stack=`./query_stack.py -r ${region} -p ${profile} -s "appasg-${product}-${branch}-\d+-${env}" -S | awk -F ':' '{ print $1 }'`
          wait_for_stack_completion "${exiting_stack}"
        else
          create_web_app
        fi
}

function delete_web_app() {
  if [[ "$admin_enabled" == "true" ]];then
    delete_admin
  fi
  for s in appasg webasg elb ilb sg alarms; do
            delete_stack "${s}-${product}-${branch}-${version}-${env}"
  done
}

function create_admin() {
        create_admin_asg
}

function delete_admin() {
    delete_stack admin-${product}-${branch}-${version}-${env}
}

##### Main calls

init
get_cmd_opts $@
init_env

if ! [ -n "${version}" -a -n "${branch}" ]; then
  echo "Error: required options not provided -V, -b"
  usage;
  exit 2
fi

if [[ "$apptype" == "tomcat" || "$apptype" == "tomcat8" || "$apptype" == "nodejs" ]];then
  case "$action" in
      create)
          if [[ "$blue_green_deployment" == "true" ]]; then
            create_web_app
          else
            update_web_app
          fi
          ;;
      delete)
          delete_web_app
          ;;
      *)
        usage
        exit 1
  esac
fi
