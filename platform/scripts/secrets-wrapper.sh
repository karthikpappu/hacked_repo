#!/usr/bin/env bash

SECRETS_CLI_PATH="/opt/intuit/secrets-cli/secrets"

usage() {
cat << EOF
usage: $0  options action

This script put and list secrets stored in S3 using the secrets-cli
ACTIONS:
    get
    put
    list
    rm
    cp
    cleanup
OPTIONS:
   -h       show this message
   -b       bucket
   -r       region
   -p       AWS profile
   -n       secret name
   -f 	    secret file (--genpass to generate a password)
   -d       secret new name (cp command)
   -k       kms key
   -P       prefix (multiple prefix separated via comma)
EOF
}

function get_cmd_opts () {
   while getopts "p:r:P:n:f:b:k:d:" OPTION
   do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         b) SecretsS3bucket=$OPTARG ;;
         p) profile=$OPTARG ;;
         r) region=$OPTARG ;;
         P) prefix=$OPTARG ;;
    		 n) secret_name=$OPTARG ;;
    		 f) secret_file=$OPTARG ;;
         d) secret_dest=$OPTARG ;;
         k) SecretsEncryptionKey=$OPTARG ;;
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
      echo "Error: required options not provided, -p"
      usage;
      exit 2
   fi
}


function init() {
   region=us-west-2
   profile=slingshot-preprod
   SecretsS3bucket=""
   SecretsEncryptionKey=""
   prefix=""
   if [[ -n "$proxy" ]];then
    JAVA_OPTIONS="-Dhttp.proxyHost=${proxy} -Dhttps.proxyHost=${proxy} -Dhttp.proxyPort=80 -Dhttps.proxyPort=80" 
   fi
}

function init_env() {
    if [ -z "$SecretsS3bucket" -o -z "$SecretsEncryptionKey" ];then
      check_inputs=`./query_stack.py -r ${region} -p ${profile} -s "^inputs\$" -S`
      if [[ "$check_inputs" != "inputs:CREATE_COMPLETE" ]];then
         echo "inputs stack is not ready."
         exit 2
      fi
      if [[ -z "$SecretsS3bucket" ]];then
        SecretsS3bucket=`./query_stack.py -r ${region} -p ${profile} -s "^inputs\$" -o SecretsS3bucket`
      fi
      if [[ -z "$SecretsEncryptionKey" ]];then
        SecretsEncryptionKey=`./query_stack.py -r ${region} -p ${profile} -s "^inputs\$" -o SecretsEncryptionKey | sed 's#.*key/##'`
      fi
    fi
}

init
get_cmd_opts $@
init_env

secrets_cli_command="$SECRETS_CLI_PATH  --profile ${profile} ${action} --s3-bucket $SecretsS3bucket --region $region --kms-cmk-id $SecretsEncryptionKey"
case "$action" in
    put)
		for opt in secret_name secret_file; do
			if [[ "\$$opt" == '' ]];then
	        	echo "\$$opt is required."
	        	usage
	        	exit 1
	        fi
		done
        if [[ "${secret_file}" == "--genpass" ]];then
          secret_value="--generate-password --password-length 12"
        elif [[ ! -f "${secret_file}" ]];then
        	echo "${secret_file} does not exists or is unaccessible"
        	exit 1
        else
          secret_value="--secret-value file://${secret_file}"
        fi
        echo "Putting secrets $secret_name to $SecretsS3bucket"
       	if [[ "${prefix}" != "" ]];then
       		IFS=","
			declare -a elements=( $prefix )
			#show contents
			for (( i=0 ; i < ${#elements[@]}; i++ )); do
			    prefix_arg="${elements[$i]}"
			    eval $secrets_cli_command --secret-names "${prefix_arg}/${secret_name}" ${secret_value}
			done
	 	else
	 		$secrets_cli_command --secret-names ${secret_name} ${secret_value}
	 	fi
      ;;
    get)
        for opt in secret_name secret_file; do
          if [[ "\$$opt" == '' ]];then
                echo "\$$opt is required."
                usage
                exit 1
              fi
        done
        if [[ "${prefix}" != "" ]];then
          echo "Cannot use prefix option with 'get' action."
          exit 1
        else
          echo "Getting secret $secret_name from $SecretsS3bucket to ${secret_file}"
          eval $secrets_cli_command --secret-name ${secret_name} --output ${secret_file}
        fi
        ;;
    cp)
        for opt in secret_name secret_dest; do
          if [[ "\$$opt" == '' ]];then
                echo "\$$opt is required."
                usage
                exit 1
              fi
        done
        echo "Copying secret $secret_name to $secret_dest in bucket $SecretsS3bucket"
        secrets_cli_command="$SECRETS_CLI_PATH  --profile ${profile} get --s3-bucket $SecretsS3bucket --region $region --kms-cmk-id $SecretsEncryptionKey"
        secret_file=`mktemp '/tmp/sec_XXXXXXXXXXXX'`
        eval $secrets_cli_command --secret-name ${secret_name} --output ${secret_file}
        secrets_cli_command="$SECRETS_CLI_PATH  --profile ${profile} put --s3-bucket $SecretsS3bucket --region $region --kms-cmk-id $SecretsEncryptionKey"
        eval $secrets_cli_command --secret-names ${secret_dest} --secret-value file://${secret_file}
        rm -f ${secret_file}
        ;;
    list)
        echo "Listing secrets on $SecretsS3bucket"
       	if [[ "${prefix}" != "" ]];then
       		IFS=","
			declare -a elements=( $prefix )
			#show contents
			for (( i=0 ; i < ${#elements[@]}; i++ )); do
			    prefix_arg=" --filter ${elements[$i]}/"
			    eval $secrets_cli_command $prefix_arg
			done
	 	else
	 		$secrets_cli_command
	 	fi
        ;;
    rm)
      if [[ "$secret_name" == '' ]];then
            echo "\$$opt is required."
            usage
            exit 1
      fi
      
      if [[ "${prefix}" != "" ]];then
          IFS=","
          declare -a elements=( $prefix )
          #show contents
          for (( i=0 ; i < ${#elements[@]}; i++ )); do
              echo "Removing secrets $secret_name from $SecretsS3bucket/${prefix_arg}"
              prefix_arg="${elements[$i]}"
              aws s3 rm --profile ${profile} "s3://${SecretsS3bucket}/${prefix_arg}/${secret_name}"
          done
      else
        aws s3 rm --profile ${profile} "s3://${SecretsS3bucket}/${secret_name}"
      fi
        ;;
    cleanup)
        aws s3 rm --profile ${profile} "s3://${SecretsS3bucket}/" --recursive
        ;;
    *)
      usage
      exit 1
esac

exit $?
