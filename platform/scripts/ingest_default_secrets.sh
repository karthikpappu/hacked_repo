#!/usr/bin/env bash

usage() {
cat << EOF
usage: $0   options action

This script ingests default secrets for Slingshot project based
ACTIONS:
	ingest
	migrate (from old storage pattern ENV/secret to PRODUCT/ENV/ROLE/secret )

OPTIONS:
   -h       show this message
   -r       region
   -p       AWS/JSD environment
   -y       assume yes
   -P       product
   -R       roles (comma separated)
   -o       override secrets
   -d       debug
EOF
}

function get_cmd_opts () {
   while getopts "p:r:hydP:oR:" OPTION
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
		 P) product=$OPTARG ;;
		 o) override=true ;;
		 R) roles=$OPTARG ;;
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
   if ! [ -n "${profile}" -a -n "${product}" ]; then
      echo "Error: required options not provided -p, -P"
      usage;
      exit 2
   fi
}

function init() {
  override=false
  action="usage"
  debug=false
  assumeyes=false
  roles="web,app"
  region=us-west-2
  profile=slingshot-preprod
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
  source_region=us-west-2
  source_bucket_name=iss-slingshot-default-secrets-${source_region}
  source_kms_key="arn:aws:kms:us-west-2:728730759369:key/f2fea9a2-89f0-4a37-ab77-e59dda2e661b"
  target_bucket_name=iss-${profile}-secrets-${region}
  if [[ "${profile}" =~ "-prod" ]];then
    env="prod"
  else
    env="preprod"
  fi
  if [[ ! -f "../../platform/settings/aws-${env}.conf" ]];then
     echo "missing settings file platform/settings/aws-${env}.conf"
     exit 2      
  fi
  . "../../platform/settings/aws-${env}.conf"
  role_list=`echo ${roles} | sed 's/,/ /g'`
}

function migrate_secrets() {
  for r in  ${role_list}; do 
    echo $r
    # download and reupload secrets
    for e in ${environments}; do
      echo ${e}
      secret_list=`aws --profile ${profile} --region ${region} s3 ls s3://${target_bucket_name}/${e}/ | awk '{print $4}' | sed -e 's/.isec//' -e 's/.ikek//' | uniq`
      tmp_file=`mktemp sec_XXXXXXXXXXX`
      for s in ${secret_list}; do
        ./secrets-wrapper.sh -b ${target_bucket_name} -r ${source_region} -p ${profile} -n ${e}/${s} -f ${tmp_file} get
        if [ $? -ne 0 ]; then
          echo "Failed get operation."
          exit 1
        fi
        ./secrets-wrapper.sh -b ${target_bucket_name} -r ${region} -p ${profile} -P ${product}/${e}/${r} -n ${s} -f ${tmp_file} put
        if [ $? -ne 0 ]; then
          echo "Failed put operation."
          exit 1
        fi
      done
      rm -f ${tmp_file}
    done
  done
}

function ingest_default_secrets() {
  if [[ "${override}" == true ]]; then
    for e in ${environments}; do
      if [ `aws --profile ${profile} s3 ls s3://${target_bucket_name}/${product}/${e} >/dev/null 2>&1; echo $?` -eq 0 ]; then
        aws --profile ${profile} s3 rm --recursive s3://${target_bucket_name}/${product}/${e}/
      fi  
    done
    sleep 3
  fi
  for e in ${environments} ; do
    temp_folder=`mktemp -d /tmp/secrets_${e}_XXXXXXXXXXX`
    mkdir ${temp_folder}/archive ${temp_folder}/secrets
    if [ `aws --profile ${profile} s3 ls s3://${target_bucket_name}/${product}/${e}/ >/dev/null 2>&1; echo $?` -eq 0 ]; then
      echo "[INFO] The secrets for environment $e have already been ingested"
    else
      ./secrets-wrapper.sh -b ${source_bucket_name} -r ${source_region} -p ${profile} -n default-secrets-${e}.tgz -k ${source_kms_key} -f ${temp_folder}/archive/secrets.tgz get
      if [ $? -ne 0 ]; then
        echo "Failed get operation."
        exit 1
      fi
      tar xvfz ${temp_folder}/archive/secrets.tgz -C ${temp_folder}/secrets/ --strip-components 1
      for file in ${temp_folder}/secrets/*; do
        filename=`basename $file`
        for r in  ${role_list}; do
          ./secrets-wrapper.sh -b ${target_bucket_name} -r ${region} -p ${profile} -P "${product}/${e}/${r}" -n ${filename} -f ${file} put
          if [ $? -ne 0 ]; then
            echo "Failed put operation."
            exit 1
          fi
     	done
      done
    fi
    rm -rf ${temp_folder}
  done
}


init
get_cmd_opts $@
init_env
confirmation=true
if [[ "$assumeyes" == false ]];then
  confirmation=""
  while [[ -z "$confirmation" ]]; do
    echo -n "Are you ready to ingest default secrets to ${profile} (yes/NO):"
    read confirmation
    if [[ "$confirmation" == "yes" ]];then
      confirmation=true
    else
      confirmation=false
    fi
  done
fi
if [[ "$confirmation" == true ]];then
  case "$action" in
      ingest)
          ingest_default_secrets
          ;;
      migrate)
          migrate_secrets
          ;;
      *)
        usage
        exit 1
  esac 	
fi
