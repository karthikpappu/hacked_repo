job {

	name ( 'slingshot-ingest-secret' )

	logRotator( -1, 100, -1, 100 )

	parameters {
		fileParam('upload_file', '')
		stringParam ( 'secret_name', '', '' )
		stringParam ( 'PRODUCT', '', '' )
		stringParam ( 'COMPONENT', '', '' )
		stringParam ( 'source_repo', 'SBG-TAC/TAC_AWS_Platform', '' )
		stringParam ( 'source_repo_branch', 'master', '' )
		choiceParam ( 'region', ['us-west-2','us-west-1','us-east-1', 'sa-east-1'], '' )
		stringParam ( 'profile', '', '' )
		choiceParam ( 'environment', ['ci','dev','qa','e2e','perf','stage','prod'], '' )
		choiceParam ( 'role', ['app','web','admin','rds_mysql','rds_oracle'], '' )
	}

	label ( 'slingshot' )

	scm {
		git {
			remote {
				url ( 'git@github.intuit.com:${source_repo}.git' ) // use either url or github
				// CJB!!
				// These credentials will need to be set up separately (and renamed if not set up the same way)
				//
				credentials ( 'scmbuild@all-jenkins-slaves' )
			}
			branches ( '*/${source_repo_branch}' ) // the branches to build, multiple calls are accumulated, defaults to **
			createTag ( true ) // create a tag for every build, optional, defaults to false
			wipeOutWorkspace ( true ) // wipe out workspace and force clone, optional, defaults to false
		}
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
