#!/usr/bin/env bash

usage() {
cat << EOF
usage: $0 options 

This script create PEM files for SSL tunneling purpose
OPTIONS:
   -h 		show this message
   -v 		days of validify. Default 1826
   -s 		key size. Default: 2048
   -f 		output file. Required
   -2		create one key file and one cert file instead of a single file
   -c 		cname field. Default: intuit.com
EOF
}

function init() {
  file=''
  valid=1826
  key_size=2048
  cname='intuit.com'
  two_file=false
}

function get_cmd_opts () {
   while getopts "hv:s:f:c:2" OPTION
   do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         f) file=$OPTARG ;;
         v) valid=$OPTARG ;;
         s) key_size=$OPTARG ;;
		 2) two_file=true ;;
		 c) cname=$OPTARG ;;
         ?) usage ;;
     esac
   done
   if [[ -z "$file" ]];then
      usage
      exit 1
   fi
}

function create_pem_file() {
	openssl genrsa -out ${file}.key ${key_size}
	openssl req -new -x509 -key ${file}.key -subj "/C=US/ST=California/L=San Diego/O=Intuit/OU=Technology Operations/CN=${cname}" -out ${file}.cert -days ${valid}
	if [[ "$two_file" == true ]];then
		chmod 640 ${file}.key ${file}.cert 
		echo "Created key file ${file}.key and cert file ${file}.cert"
	else
		cat ${file}.key ${file}.cert > ${file}
		chmod 640 ${file}
		rm -f ${file}.key ${file}.cert
		echo "Created pem file ${file}"
	fi
}

##### Main calls

init
get_cmd_opts $@
create_pem_file

exit 0
