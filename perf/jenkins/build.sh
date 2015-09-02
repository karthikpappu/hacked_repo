#!/bin/bash 

SLEEP_TIME=90

function validate() {
  if [[ -z $JMETER_OPTIONS ]]; then
    JMETER_OPTIONS='none'
  fi

  if [[ -z $JMX_FILE ]]; then
    echo "Missing JMX_FILE. Please specify which JMeter test to execute"
    exit 1
  fi

}

validate

# Armor against whitespaces in JMX_FILE and JMETER_OPTIONS
JMX_FILE=${JMX_FILE//_/__}
JMX_FILE=${JMX_FILE// /_}

JMETER_OPTIONS=${JMETER_OPTIONS//_/__}
JMETER_OPTIONS=${JMETER_OPTIONS// /_}

echo "Running JMeter test : ${JMX_FILE} ${JMETER_OPTIONS}"

rm -f *.jtl
rm -f *.jmeter.log

if [ `uname -s` == 'Darwin' ]; then
  RANDOM_UUID=`od -vAn -N4 -tu < /dev/urandom | sed -e 's: ::g'`
else
  RANDOM_UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
fi

datestamp=`date -u +"%Y%m%dT%H%M%S"`

stack_name=${STACK_GROUP}-${datestamp}

build_uuid=${STACK_GROUP}-${RANDOM_UUID}

JSON_FILE=cf-docker-jmeter.json

# print some identifiable information about the group of perf stacks
aws ec2 describe-instances \
       --output text \
       --filters "Name=tag-value, Values=${STACK_GROUP}*" \
       --query 'Reservations[*].Instances[*].[PrivateIpAddress,InstanceId,Tags[?Key==`aws:cloudformation:stack-name`].Value[],Tags[?Key==`aws:cloudformation:stack-id`].Value[]]'


ip_addresses=`aws ec2 describe-instances \
       --output text \
       --filters "Name=tag-value, Values=${STACK_GROUP}*" \
       --query 'Reservations[*].Instances[*].[PrivateIpAddress]' |egrep -iv None`


if [[ "X${NEW_PERF_CLOUD_ON_DEMAND}" == "Xtrue" ]] || [[ -z $ip_addresses ]]; then
  echo "Creating stack : ${stack_name}"
  aws cloudformation create-stack \
	--stack-name    $stack_name \
        --tags          Key=stack_group,Value=${STACK_GROUP} \
	--template-url  https://s3.amazonaws.com/${S3_PERF_BUCKET}/bootstrap/${JSON_FILE} \
	--parameters    ParameterKey=BuildUUID,ParameterValue=${build_uuid} \
			ParameterKey=AvailabilityZones,ParameterValue=${ZONE} \
			ParameterKey=KeyName,ParameterValue=${KEY_NAME} \
			ParameterKey=AdminSecurityGroup,ParameterValue=${SEC_GROUP_ID} \
			ParameterKey=VpcId,ParameterValue=${VPC_ID} \
			ParameterKey=Subnets,ParameterValue=${SUBNET_ID} \
			ParameterKey=S3Bucket,ParameterValue=${S3_BUCKET} \
			ParameterKey=S3PerfBucket,ParameterValue=${S3_PERF_BUCKET} \
			ParameterKey=ProxyServer,ParameterValue=${PROXY_SERVER} \
			ParameterKey=NonProxyHosts,ParameterValue=\'${NON_PROXY_HOSTS}\' \
			ParameterKey=EC2PoolSize,ParameterValue=${EC2_POOL_SIZE} \
			ParameterKey=JMeterPoolSize,ParameterValue=${JMETER_POOL_SIZE} \
			ParameterKey=JMXFile,ParameterValue=${JMX_FILE} \
			ParameterKey=JMeterOptions,ParameterValue=${JMETER_OPTIONS} \
			ParameterKey=OfferingName,ParameterValue=${CD_OFFERING_NAME} \
			ParameterKey=ComponentName,ParameterValue=${CD_COMPONENT_NAME} \
	--capabilities CAPABILITY_IAM
    cf_exit_code=$?


  while true;
  do
    ip_addresses=`aws ec2 describe-instances \
       --output text \
       --filters "Name=tag-value, Values=${stack_name}*" \
       --query 'Reservations[*].Instances[*].[PrivateIpAddress]' |egrep -iv None`
    count=`echo $ip_addresses |wc -w`
    if [  $cf_exit_code == 0 ] && [ $count == $EC2_POOL_SIZE ]; then
       echo "New stack has ip address(es) : $ip_addresses"
       break;
    else
      echo "Polling for complete list of ip addresses"
    fi
    sleep $SLEEP_TIME;
  done

else
  echo "Re-using stack group : ${STACK_GROUP}"
  for ip in $ip_addresses;
  do
    echo "Executing perf tests on ${ip} from stack group ${STACK_GROUP}"
    jmeter_up_cmd="sudo sh /var/tmp/jmeter-up -n ${JMETER_POOL_SIZE} -s \"${JMX_FILE}\" -P ${PROXY_SERVER} -N ${NON_PROXY_HOSTS} -u ${build_uuid} -b ${S3_PERF_BUCKET} -o ${CD_OFFERING_NAME} -c ${CD_COMPONENT_NAME} -j \"${JMETER_OPTIONS}\""
    echo "jmeter-up command : $jmeter_up_cmd"
    ssh -i ~/.ssh/intuit-perf.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ec2-user@$ip $jmeter_up_cmd &
  done
fi


for ip in $ip_addresses;
do
  while true;
  do
    check_job_cmd="aws s3 ls s3://${S3_PERF_BUCKET}/logs/${CD_OFFERING_NAME}/${CD_COMPONENT_NAME}/${build_uuid}/${ip}.fin"
    echo $check_job_cmd
    results=`$check_job_cmd`
    if [[ ! -z $results ]]; then
      aws s3 cp s3://${S3_PERF_BUCKET}/jtl/${CD_OFFERING_NAME}/${CD_COMPONENT_NAME}/${build_uuid}/${ip}.jtl .
      cat ${ip}.jtl >> ${CD_OFFERING_NAME}-${CD_COMPONENT_NAME}.jtl && rm ${ip}.jtl
      aws s3 cp s3://${S3_PERF_BUCKET}/logs/${CD_OFFERING_NAME}/${CD_COMPONENT_NAME}/${build_uuid}/${ip}.jmeter.log .
      cat ${ip}.jmeter.log >> ${CD_OFFERING_NAME}-${CD_COMPONENT_NAME}.jmeter.log && rm ${ip}.jmeter.log
      break;
    fi;
    sleep $SLEEP_TIME;
  done
done


if [[ "X${TERMINATE_STACK_ON_FINISH}" == "Xtrue" ]]; then
    echo "Terminating Stack ${stack_name}"
    aws cloudformation delete-stack --stack-name ${stack_name}
else
    echo "Leaving Stack ${stack_name} running"
fi
