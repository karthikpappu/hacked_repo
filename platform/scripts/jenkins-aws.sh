#!/bin/bash

# source this file in jenkins in order to have the Jenkins access keys loaded.

if [[ "$1" != "" ]]; then
	echo "ACCOUNT ALIAS set by parameter [$1]"
	ACCOUNT_ALIAS=$1
fi

if [[ "$ACCOUNT_ALIAS" = "" ]]; then
	echo "NO ACCOUNT ALIAS SET. ASSUMING DEVELOPMENT ACCOUNT"
	ACCOUNT_ALIAS='development'
fi

if [[ "$AWS_ACCESS_KEY_ID_DEVELOPMENT" = "" ]]; then
        echo "NO AWS ACCESS KEY SET, please make sure it is in your applications config file."
	exit 1
fi
if [[ "$AWS_SECRET_ACCESS_KEY_DEVELOPMENT" = "" ]]; then
        echo "NO AWS ACCESS KEY SET, please make sure it is in your applications config file."
        exit 1
fi
if [[ "$AWS_ACCESS_KEY_ID_PRODUCTION" = "" ]]; then
        echo "NO AWS ACCESS KEY SET, please make sure it is in your applications config file."
        exit 1
fi
if [[ "$AWS_SECRET_ACCESS_KEY_PRODUCTION" = "" ]]; then
        echo "NO AWS ACCESS KEY SET, please make sure it is in your applications config file."
        exit 1
fi


function setupAccessKeys {
	ACCOUNT=$1
	echo "Jenkins selecting account details for $ACCOUNT"
	case "$ACCOUNT" in

		'development')
			export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_DEVELOPMENT
			export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_DEVELOPMENT
	    ;;
		'production')
			export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_PRODUCTION
			export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_PRODUCTION
	    ;;
		*) 
			echo "ERROR: jenkins-aws.sh does not know about AWS account $ACCOUNT, please update script with your accounts jenkins user data."
			exit 1
		;;
	esac
}

setupAccessKeys $ACCOUNT_ALIAS
