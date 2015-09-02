job {

 	_snip ( 'scm', delegate )
	label('slingshot')

 	steps {

    	shell (
"""
#!/bin/bash

branch=`echo \${full_branch} | sed 's#*/##g' | sed 's#[./]#-#g' | sed 's#release#rel#' | sed 's#hotfix#hot#' | sed 's#feature#feat#'`
echo prod_url=s3://\${profile_production}-\${region}/\$(basename \${artifact_url})>\${WORKSPACE}/injected.vars.txt

cd platform/scripts
bash ./store_prod.sh -r \${region} -p \${profile_production} -P \${profile} -s \${artifact_url} -e \${env}
"""
    	)

		environmentVariables {
			propertiesFile("\${WORKSPACE}/injected.vars.txt")
		}

	}
}
