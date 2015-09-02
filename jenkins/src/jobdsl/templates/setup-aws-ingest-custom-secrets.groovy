job {


	logRotator( -1, 100, -1, 100 )


	label ( 'slingshot' )
	_snip ( 'scm', delegate )
       
        parameters {
                fileParam('upload_file', '')
        }

	wrappers {
		preBuildCleanup ( )
	}

	steps {
		shell (
"""
#!/bin/bash

export http_proxy=http://qy1prdproxy01.ie.intuit.net:80/
export https_proxy=http://qy1prdproxy01.ie.intuit.net:80/
export 'no_proxy=.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'

targetbucketname=iss-\${profile}-secrets-\${region}

cd platform/scripts

# checks if secret bucket is setup in new format
if [ `aws --profile \${profile} s3 ls s3://iss-\${profile}-secrets-\${region}/\${PRODUCT}-\${COMPONENT}/ >/dev/null 2>&1; echo \$?` -eq 0 ]; then
  echo "[INFO] New secret setup with roles"
  for e in \${environment}; do
    ./secrets-wrapper.sh -b \${targetbucketname} -r \${region} -p \${profile} -P \${PRODUCT}-\${COMPONENT}/\${e}/\${role} -n \${secret_name} -f \${WORKSPACE}/upload_file put
  done
else
  echo "[INFO] OLD secret setup with just environment"
  for e in \${environment}; do
    ./secrets-wrapper.sh -b \${targetbucketname} -r \${region} -p \${profile} -P \${e} -n \${secret_name} -f \${WORKSPACE}/upload_file put
  done
fi

rm \${WORKSPACE}/upload_file
"""
		)
	}
}
