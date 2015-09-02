job {

 	_snip ( 'scm', delegate )
  label('slingshot')

 	steps {
     shell (
"""
#!/bin/bash

export http_proxy=http://\${proxy}:80/
export https_proxy=\${http_proxy}
export no_proxy='fmsscm.corp.intuit.net,.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'

function wait_for_stack_completion () {
stack_name=\$1
delete_stack=\$2
desired_stack_state="CREATE_COMPLETE"
  if [[ \${delete_stack} == "true" ]]; then
    desired_stack_state="DELETE_COMPLETE"
  fi
  cfn_status=`./query_stack.py -r \${region} -p \${profile} -s "^\${stack_name}\$" -S | awk -F ':' '{ print \$2}' 2>/dev/null;`
  #sleep until cloud formation completes

  while [ "\$cfn_status" != \${desired_stack_state} ]
  do
    cfn_status=`./query_stack.py -r \${region} -p \${profile} -s "^\${stack_name}\$" -S | awk -F ':' '{ print \$2}' 2>/dev/null;`
    echo "\$stack_name \$cfn_status"

    if [[ "\$cfn_status" == "CREATE_FAILED" || "\$cfn_status" == "ROLLBACK_COMPLETE" || "\$cfn_status" == "DELETE_FAILED" ]]; then
      echo "Error: CloudFormation Stack Creation Failed"
      exit 1
    fi

    sleep 20
  done
}

cd platform/scripts
if [[ "\${DELETE}" == "true" ]]; then
  aws --profile \${profile} cloudformation delete-stack --stack-name inputs
  sleep 30
else
  stack_name=inputs
  if [ `aws --profile \${profile} cloudformation list-stacks --stack-status-filter CREATE_COMPLETE | grep StackName | grep \${stack_name} > /dev/null 2>&1; echo \$?` -eq 0 ]; then
    echo "[INFO] Stack: \${stack_name} already exists - noop"
    echo "[INFO] Rerun with DELETE flag if you want to regenerate it"
    exit 0
  fi
fi

keyname=\${profile}
wget -nv http://fmsscm.corp.intuit.net/fms-build/view/TAC/job/CI-devops-JSD-trunk/lastSuccessfulBuild/artifact/JSD-App/target/JSD-App.jar
#TODO: \${SecretsEncryptionKey} \${SecretsS3Bucket} \${kms_ebs_key}
export kms_ebs_key=\$(./kms.py -r \${region} -p \${profile} -D "EBS Keys" create)
export SecretsEncryptionKey=\$(./kms.py -r \${region} -p \${profile} -D "KMS Keys" create)
export SecretsS3Bucket=iss-\${profile}-secrets-\${region}
bash -x ./inputs.setup.sh -r \${region} -p \${profile} -e \${operator_email} -k \${profile}-\${region} -b \${profile}-\${region} -K \${kms_ebs_key} -S \${SecretsEncryptionKey} -B \${SecretsS3Bucket}
sleep 15
./query_stack.py -r \${region} -p \${profile} -s "^inputs\$"
"""
     )
  }
}
