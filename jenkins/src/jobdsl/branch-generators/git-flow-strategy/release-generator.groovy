job {

	def gitBranchType = 'release'
	def pipelineName = "java_app_${gitBranchType}_workflow"

	name ( "create-${PRODUCT}-${COMPONENT}-${gitBranchType}-pipeline" )

	logRotator( -1, 100, -1, 100 )
	
	parameters {
        choiceParam ( 'PRODUCT', [ "${PRODUCT}" ], '' )
        choiceParam ( 'COMPONENT', [ "${COMPONENT}" ], '' )
		choiceParam ( 'COMPONENT_TYPE', ["${COMPONENT_TYPE}"], '' )
        stringParam ( 'PIPELINE', pipelineName, '' )
        choiceParam ( 'SOURCE_REPOSITORY', [ "${SOURCE_REPOSITORY}" ], '' )
        stringParam ( 'RELEASE_BRANCH', '', '' )
		booleanParam ( 'enableSauceConnect', Boolean.valueOf ( "${enableSauceConnect}" ), '' )
		stringParam ( 'sauce_username', "${sauce_username}", '' )
		stringParam ( 'sauce_access_api_key', "${sauce_access_api_key}", '' )
		stringParam ( 'contact_email_or_dl', "${contact_email_or_dl}", '' )
        stringParam ( 'profile', "${profile}"	, '' )
		stringParam ( 'profile_production', "${profile_production}", '' )
	}

    label ( 'slingshot' )

	steps {
		downstreamParameterized {		
			trigger ( 'create-git-branch', 'ALWAYS', false,
						["buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE"] ) {

				predefinedProps ( [ "GIT_REPO" : "\${SOURCE_REPOSITORY}",
									"GIT_SOURCE_BRANCH" : "develop",
									"GIT_TARGET_BRANCH" : "${gitBranchType}/\${RELEASE_BRANCH}",
									"BASELINE_NAME" : "baseline-\${RELEASE_BRANCH}-0001" ] )
			}
		}

		downstreamParameterized {		
			trigger ( 'slingshot-pipeline-generator', 'ALWAYS', false,
						["buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE"] ) {

				predefinedProps ( [ "PRODUCT" : "\${PRODUCT}",
									"COMPONENT" : "\${COMPONENT}",
									"COMPONENT_TYPE" : "\${COMPONENT_TYPE}",
									"PIPELINE" : "\${PIPELINE}",
									"SOURCE_REPOSITORY" : "\${SOURCE_REPOSITORY}",
									"FULL_BRANCH_PATH" : "${gitBranchType}/\${RELEASE_BRANCH}",
									"enableSauceConnect" : "\${enableSauceConnect}",
									"sauce_username" : "\${sauce_username}",
									"sauce_access_api_key" : "\${sauce_access_api_key}",
									"contact_email_or_dl" : "\${contact_email_or_dl}",
									"profile" : "\${profile}",
									"profile_production" : "\${profile_production}" ] )									
			}
		}
	}
}

