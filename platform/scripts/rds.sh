#!/usr/bin/env bash

usage() {
cat << EOF
usage: $0   options action

This script deploys a full RDS to AWS using CF stacks
ACTIONS:
    create
    delete
    rotate (master credentials)
OPTIONS:
   -h       show this message
   -p       AWS/JSD environment
   -r       region
   -P       product
   -e       environment
   -b       branch
   -x       prefix
   -t       type [ mysql | oracle ]
EOF
}

function get_cmd_opts () {
   while getopts "p:r:P:e:b:x:t:" OPTION
   do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p) profile=$OPTARG ;;
         r) region=$OPTARG ;;
         P) product=$OPTARG ;;
         e) env=$OPTARG ;;
         b) branch=$OPTARG ;;
         x) prefix=$OPTARG ;;
         t) rdstype=$OPTARG ;;
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
   if ! [ -n "${profile}" -a -n "${region}" -a -n "${product}" -a -n "${env}" -a -n "${branch}" -a -n "${rdstype}" ]; then
      echo "Error: required options not provided -p, -r, -P, -e, -b, -t"
      usage;
      exit 2
   fi
}


function init() {
  profile=slingshot-preprod
  region=us-west-2
  rdstype=mysql
  RDS_OPTS=""
  if [[ -n "$proxy" ]];then
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
  RDS_NAME="rds-${rdstype}-${product}-${env}-${branch}"
  POSTFIX="${branch}"
  if [ ! -z "${prefix}" ]; then
    RDS_NAME="${RDS_NAME}-${prefix}"
    POSTFIX="${POSTFIX}_${prefix}"
  fi
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
  . "../../platform/settings/${env}.conf"
  if [[ -n "$dns_zone" ]]; then
    HostedZone="$dns_zone"
  else
    HostedZone="${profile}.a.intuit.com"
  fi
  ebs_kms_key=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o EbsEncryptionKey`
  secretss3bucket=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o SecretsS3bucket`
  s3_secrets_key=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o SecretsEncryptionKey`
  if [[ "$rdstype" == "mysql" ]]; then
    if [ ! -z "${rds_mysql_engine}" ]; then RDS_OPTS="${RDS_OPTS} --engine ${rds_mysql_engine}" ; fi
    if [ ! -z "${rds_mysql_engine_version}" ]; then RDS_OPTS="${RDS_OPTS} --engine-version ${rds_mysql_engine_version}" ; fi
    if [ ! -z "${rds_mysql_instance_type}" ]; then RDS_OPTS="${RDS_OPTS} --db-instance-class ${rds_mysql_instance_type}" ; fi
    if [ ! -z "${rds_mysql_storage_type}" ]; then RDS_OPTS="${RDS_OPTS} --storage-type ${rds_mysql_storage_type}" ; fi
    if [ ! -z "${rds_mysql_ebs_size}" ]; then RDS_OPTS="${RDS_OPTS} --allocated-storage ${rds_mysql_ebs_size}" ; fi
    if [ "${rds_mysql_storage_type}" == "io1" ]; then RDS_OPTS="${RDS_OPTS} --iops ${rds_mysql_iops}" ; fi
    if [ ! -z "${rds_mysql_master_username}" ]; then RDS_OPTS="${RDS_OPTS} --master-username ${rds_mysql_master_username}" ; fi
    if [ ! -z "${rds_mysql_db_name}" ]; then RDS_OPTS="${RDS_OPTS} --db-name ${rds_mysql_db_name}" ; fi
    if [ ! -z "${rds_mysql_port}" ]; then RDS_OPTS="${RDS_OPTS} --port ${rds_mysql_port}" ; RDSIgressPort=${rds_mysql_port} ; fi
    rds_parameter_group=${rds_mysql_parameter_group}
  elif [[ "$rdstype" == "oracle" ]]; then
    if [ ! -z "${rds_oracle_engine}" ]; then RDS_OPTS="${RDS_OPTS} --engine ${rds_oracle_engine}" ; fi
    if [ ! -z "${rds_oracle_engine_version}" ]; then RDS_OPTS="${RDS_OPTS} --engine-version ${rds_oracle_engine_version}" ; fi
    if [ ! -z "${rds_oracle_instance_type}" ]; then RDS_OPTS="${RDS_OPTS} --db-instance-class ${rds_oracle_instance_type}" ; fi
    if [ ! -z "${rds_oracle_storage_type}" ]; then RDS_OPTS="${RDS_OPTS} --storage-type ${rds_oracle_storage_type}" ; fi
    if [ ! -z "${rds_oracle_ebs_size}" ]; then RDS_OPTS="${RDS_OPTS} --allocated-storage ${rds_oracle_ebs_size}" ; fi
    if [ "${rds_oracle_storage_type}" == "io1" ]; then RDS_OPTS="${RDS_OPTS} --iops ${rds_oracle_iops}" ; fi
    if [ ! -z "${rds_oracle_master_username}" ]; then RDS_OPTS="${RDS_OPTS} --master-username ${rds_oracle_master_username}" ; fi
    if [ ! -z "${rds_oracle_db_name}" ]; then RDS_OPTS="${RDS_OPTS} --db-name ${rds_oracle_db_name}" ; fi
    if [ ! -z "${rds_oracle_port}" ]; then RDS_OPTS="${RDS_OPTS} --port ${rds_oracle_port}" ; RDSIgressPort=${rds_oracle_port} ; fi
    rds_parameter_group=${rds_oracle_parameter_group}
  fi
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

function create_passwd_file() {
  passwd_file=$1
  folder=$2
  override=$3
  # check if password exists
  if [[ "$override" == true ]];then
    check_file="0"
  else
    check_file=`aws s3 ls --profile ${profile} s3://${secretss3bucket}/${folder}/${passwd_file} | wc -l`
  fi
  if [[ "$check_file" -eq "0" ]]; then
    ./secrets-wrapper.sh -p ${profile} -n ${passwd_file} -f --genpass -P "${folder}" put
  fi
}

function create_rds() {
  # check if rds exists
  echo -e "\n************************************************************************"
  echo    "Checking if Amazon RDS DB Instance already exists"
  echo -e "************************************************************************"
  rds_check=`aws rds --region ${region} --profile ${profile} describe-db-instances --db-instance-identifier ${RDS_NAME}`
  if [[ "$?" -eq "255" ]]; then
    # Create rds alarms
    echo -e "\n************************************************************************"
    echo    "Creating Amazon CloudWatch Alarms"
    echo -e "************************************************************************"
    java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/2.alarm.actions.json \
     -i inputs \
     -n alarms-${RDS_NAME}
    wait_for_stack_completion alarms-${RDS_NAME}
    # Get settings
    DbSubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o DbSubnet1Id`
    DbSubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o DbSubnet2Id`
    AppSubnet1Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AppSubnet1Id`
    AppSubnet2Id=`./query_stack.py -r ${region} -p ${profile} -s "inputs" -n -o AppSubnet2Id`
    AppSubnetAZ1CIDR=`aws ec2 describe-subnets --profile ${profile} --subnet-ids ${AppSubnet1Id} | grep CidrBlock | cut -d\" -f4`
    AppSubnetAZ2CIDR=`aws ec2 describe-subnets --profile ${profile} --subnet-ids ${AppSubnet2Id} | grep CidrBlock | cut -d\" -f4`
    echo -e "\n************************************************************************"
    echo    "Creating prerequisites for Amazon RDS"
    echo -e "************************************************************************"
    java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/6.rds.cli.json \
        $JSD_OPTIONS \
        -a SubnetIds="$DbSubnet1Id,$DbSubnet2Id" \
        -a Family=${rds_parameter_group} \
        -a AppSubnetAZ1CIDR=${AppSubnetAZ1CIDR} \
        -a AppSubnetAZ2CIDR=${AppSubnetAZ2CIDR} \
        -a RDSIgressPort=${RDSIgressPort} \
        -i inputs \
        -i alarms-${RDS_NAME} \
        -n $RDS_NAME
    # create master password
    echo -e "\n************************************************************************"
    echo    "Creating Amazon RDS Master Password"
    echo -e "************************************************************************"
    passwd_file="master_${POSTFIX}"
    create_passwd_file  "$passwd_file" "${product}/${env}/rds_${rdstype}" false
    ./secrets-wrapper.sh -p ${profile} -n "${product}/${env}/rds_${rdstype}/${passwd_file}" -f ${passwd_file} get
    RDS_PASSWD=`cat ${passwd_file}`
    rm -f ${passwd_file}
    DBParameterGroupName=`./query_stack.py -r ${region} -p ${profile} -s ${RDS_NAME} -n -o DBParameterGroupName`
    DBSubnetGroup=`./query_stack.py -r ${region} -p ${profile} -s ${RDS_NAME} -n -o DBSubnetGroup`
    DBSecGrp=`./query_stack.py -r ${region} -p ${profile} -s ${RDS_NAME} -n -o DBSecGrp`
    RDSviaSAG=`./query_stack.py -r ${region} -p ${profile} -s ${RDS_NAME} -n -o RDSviaSAG`
    DBSecGrps="${DBSecGrp} ${RDSviaSAG}"
    # create rds instance 
    echo -e "\n************************************************************************"
    echo    "Creating Amazon RDS DB Instance"
    echo -e "************************************************************************"
    aws rds create-db-instance --region ${region} --profile ${profile} \
            ${RDS_OPTS} \
            --db-instance-identifier ${RDS_NAME} \
            --master-user-password ${RDS_PASSWD} \
            --db-parameter-group-name ${DBParameterGroupName} \
            --db-subnet-group-name ${DBSubnetGroup} \
            --vpc-security-group-ids ${DBSecGrps} \
            --storage-encrypted \
            --multi-az \
            --kms-key-id ${ebs_kms_key}
  else
    echo -e "RDS: ${RDS_NAME} already exists"
    exit 1
  fi
}

function delete_rds() {
  echo -e "\n************************************************************************"
  echo    "Deleting Amazon RDS DB Instance"
  echo -e "************************************************************************"
  aws rds delete-db-instance --region ${region} --profile ${profile} \
      --skip-final-snapshot \
      --db-instance-identifier ${RDS_NAME}
  echo -e "\n************************************************************************"
  echo    "Deleting CloudFormation Stacks"
  echo -e "************************************************************************"
  delete_stack ${RDS_NAME}
  delete_stack alarms-${RDS_NAME}
  delete_stack dns-${RDS_NAME}
}

function delete_stack() {
    stack_name=$1
    java $JAVA_OPTIONS -jar JSD-App.jar delete -e ${profile} -n $stack_name 
}

function rotate_credentials() {
  echo -e "\n************************************************************************"
  echo    "Updating Amazon RDS Master Password"
  echo -e "************************************************************************"
  passwd_file="master_${POSTFIX}"
  create_passwd_file  "$passwd_file" "${product}/${env}/rds_${rdstype}" true
  ./secrets-wrapper.sh -p ${profile} -n "${product}/${env}/rds_${rdstype}/${passwd_file}" -f ${passwd_file} get
  RDS_PASSWD=`cat ${passwd_file}`
  rm -f ${passwd_file}
  rds_check=`aws rds --region ${region} --profile ${profile} describe-db-instances --db-instance-identifier ${RDS_NAME}`
  if [[ "$?" -eq "0" ]]; then
    aws rds modify-db-instance --region ${region} --profile ${profile} \
                              --db-instance-identifier ${RDS_NAME} \
                              --master-user-password ${RDS_PASSWD} \
                              --apply-immediately
  fi
}

function list_rds() {
  echo -e "\n************************************************************************"
  echo    "Listing Amazon RDS DB Instances"
  echo -e "************************************************************************"
  aws rds --region ${region} --profile ${profile} describe-db-instances | grep DBInstanceIdentifier | grep -v ReadReplicaDBInstanceIdentifiers | cut -d\" -f4
}

function wait_for_rds() {
  RDS_READY=false
  RDS_SLEEP=30
  badstatus=("storage-full" "failed" "incompatible-network" "incompatible-option-group" "incompatible-parameters" "incompatible-restore")
  RDS_DESC_INST="aws rds --region ${region} --profile ${profile} describe-db-instances --db-instance-identifier ${RDS_NAME}"
  STATUS=`$RDS_DESC_INST`
  if [[ "$?" == "0" ]];then
    while [[ "$RDS_READY" == false ]]; do
      echo "Waiting for RDS ${RDS_NAME} to be ready..."
      sleep $RDS_SLEEP
      STATUS=`$RDS_DESC_INST | grep DBInstanceStatus | sed 's/.*: \"\(.*\)\",[\ \t]*/\1/'`
      if [[ "$STATUS" =~ "available" ]]; then
        RDS_READY=true
      else
        containsElement "$STATUS" "${badstatus[@]}"
        if [[ "$?" != "0" ]];then
          echo "${RDS_NAME} has status ${STATUS}"
        else
          echo "${RDS_NAME} is in bad state ${STATUS}. Exiting..."
          RDS_READY=true
        fi
      fi
    done
  else
    echo "Failed to get status on RDS ${RDS_NAME}"
  fi
}

containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

function create_dns () {
  DNS=`aws rds describe-db-instances  --profile ${profile} --db-instance-identifier ${RDS_NAME} | grep Address | cut -d\" -f4`
  echo -e "\n************************************************************************"
  echo    "Creating Amazon Route 53 for RDS"
  echo    "  RDS Endpoint: ${RDS_NAME}.${HostedZone}:${RDSIgressPort}"
  echo -e "************************************************************************"
  java $JAVA_OPTIONS -jar JSD-App.jar create -e ${profile} -t ../../platform/cloudformation/5.dns.json \
      $JSD_OPTIONS \
      -i inputs \
      -a WebLoadBalancerDNSName=${DNS} \
      -a WebLoadBalancerName=${RDS_NAME} \
      -a DNSName=${RDS_NAME} \
      -a ZoneName=${HostedZone} \
      -a TTL=30 \
      -n dns-${RDS_NAME}
}

##### Main calls

init
get_jsd
get_cmd_opts $@
init_env

if [[ "$rdstype" == "mysql" ]] || [[ "$rdstype" == "oracle" ]]; then
  case "$action" in
      create)
          create_rds
          sleep 5
          wait_for_rds
          rotate_credentials
          create_dns
          ;;
      delete)
          delete_rds
          ;;
      rotate)
          rotate_credentials
          ;;
      list)
          list_rds
          ;;
      wait)
          wait_for_rds
          ;;
      *)
        usage
        exit 1
  esac
fi
